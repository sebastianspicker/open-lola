//! Audio receive storage bounded and paced in local device frames.
//!
//! LoLa negotiates PCM format but not frames per datagram. Queue depth and
//! prefill therefore represent local device blocks, regardless of peer packet
//! size; a deadline combines small packets or splits a larger one.
use super::sequence::{ReceiveSequenceGate, SequenceAdmission};
use crate::config::StationSettings;
use std::collections::VecDeque;

pub(super) struct AudioReceiveQueue {
    packets: VecDeque<Vec<u8>>,
    front_offset: usize,
    queued_bytes: usize,
    block_bytes: usize,
    frame_bytes: usize,
    capacity_bytes: usize,
    prefill_bytes: usize,
    started: bool,
    sequence: ReceiveSequenceGate,
    excess_deadlines: u32,
}

impl AudioReceiveQueue {
    pub(super) fn new(settings: &StationSettings) -> Self {
        let frame_bytes =
            usize::from(settings.audio.channels) * usize::from(settings.audio.bits_per_sample / 8);
        let block_bytes = settings.audio.buffer_samples as usize * frame_bytes;
        Self::with_format(
            settings.network.audio_receive_queue_depth,
            settings.network.audio_receive_prefill,
            block_bytes,
            frame_bytes,
        )
    }

    fn with_format(depth: u32, prefill: u32, block_bytes: usize, frame_bytes: usize) -> Self {
        let depth = depth.max(1);
        Self {
            packets: VecDeque::new(),
            front_offset: 0,
            queued_bytes: 0,
            block_bytes,
            frame_bytes,
            capacity_bytes: depth as usize * block_bytes,
            prefill_bytes: prefill.min(depth) as usize * block_bytes,
            started: prefill == 0,
            sequence: ReceiveSequenceGate::default(),
            excess_deadlines: 0,
        }
    }

    pub(super) fn valid_pcm(&self, pcm: &[u8]) -> bool {
        self.frame_bytes > 0 && !pcm.is_empty() && pcm.len().is_multiple_of(self.frame_bytes)
    }

    pub(super) fn admit_sequence(&mut self, sequence: u32) -> bool {
        match self.sequence.admit(sequence) {
            SequenceAdmission::Rejected => false,
            SequenceAdmission::New => true,
            SequenceAdmission::Resynced => {
                self.packets.clear();
                self.front_offset = 0;
                self.queued_bytes = 0;
                self.started = self.prefill_bytes == 0;
                self.excess_deadlines = 0;
                true
            }
        }
    }

    pub(super) fn take_resyncs(&mut self) -> u64 {
        self.sequence.take_resyncs()
    }

    /// Retains the newest samples up to the configured local-block budget.
    pub(super) fn enqueue(&mut self, pcm: Vec<u8>) -> bool {
        debug_assert!(self.valid_pcm(&pcm));
        // One peer packet must fit even when it spans multiple local blocks.
        // Its unavoidable packetization burst is presented across deadlines.
        let capacity = self.capacity_bytes.max(pcm.len());
        self.queued_bytes += pcm.len();
        self.packets.push_back(pcm);
        let overflow = self.queued_bytes.saturating_sub(capacity);
        self.consume(overflow, None);
        if self.queued_bytes >= self.prefill_bytes {
            self.started = true;
        }
        overflow > 0
    }

    /// Offers exactly one local quantum, preserving all remaining peer samples.
    pub(super) fn dequeue(&mut self) -> Option<Vec<u8>> {
        if !self.started || self.block_bytes == 0 || self.queued_bytes < self.block_bytes {
            return None;
        }
        if self.front_offset == 0
            && self
                .packets
                .front()
                .is_some_and(|pcm| pcm.len() == self.block_bytes)
        {
            self.queued_bytes -= self.block_bytes;
            return self.packets.pop_front();
        }
        let mut block = Vec::with_capacity(self.block_bytes);
        self.consume(self.block_bytes, Some(&mut block));
        Some(block)
    }

    fn consume(&mut self, mut bytes: usize, mut output: Option<&mut Vec<u8>>) {
        while bytes > 0 {
            let pcm = self
                .packets
                .front()
                .expect("queued byte count matches packets");
            let taken = bytes.min(pcm.len() - self.front_offset);
            if let Some(output) = output.as_mut() {
                output.extend_from_slice(&pcm[self.front_offset..self.front_offset + taken]);
            }
            self.front_offset += taken;
            self.queued_bytes -= taken;
            bytes -= taken;
            if self.front_offset == pcm.len() {
                self.packets.pop_front();
                self.front_offset = 0;
            }
        }
    }

    pub(super) fn realign(&mut self, patience: u32) -> bool {
        if self.queued_bytes <= self.prefill_bytes {
            self.excess_deadlines = 0;
            return false;
        }
        self.excess_deadlines += 1;
        if self.excess_deadlines < patience.max(1) {
            return false;
        }
        self.excess_deadlines = 0;
        self.consume(
            self.block_bytes.min(self.queued_bytes - self.prefill_bytes),
            None,
        );
        true
    }

    #[cfg(test)]
    pub(super) fn len(&self) -> usize {
        self.packets.len()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn smaller_peer_packets_fill_each_local_deadline_without_extra_latency() {
        let mut queue = AudioReceiveQueue::with_format(1, 0, 8, 2);
        for pair in 0..20u8 {
            assert!(!queue.enqueue(vec![pair; 4]));
            assert!(
                queue.dequeue().is_none(),
                "half a local quantum waits for its other half"
            );
            assert!(
                !queue.enqueue(vec![pair + 1; 4]),
                "depth one holds one local quantum"
            );
            assert_eq!(
                queue.dequeue(),
                Some([vec![pair; 4], vec![pair + 1; 4]].concat())
            );
            assert_eq!(queue.queued_bytes, 0);
        }
    }

    #[test]
    fn larger_peer_packets_are_split_across_local_deadlines() {
        let mut queue = AudioReceiveQueue::with_format(1, 0, 4, 2);
        assert!(!queue.enqueue((0..8).collect()));
        assert_eq!(queue.dequeue(), Some(vec![0, 1, 2, 3]));
        assert_eq!(queue.dequeue(), Some(vec![4, 5, 6, 7]));
        assert_eq!(queue.dequeue(), None);
    }

    #[test]
    fn prefill_overflow_and_realign_use_local_sample_counts() {
        let mut queue = AudioReceiveQueue::with_format(3, 2, 8, 2);
        for value in 0..3 {
            assert!(!queue.enqueue(vec![value; 4]));
            assert!(queue.dequeue().is_none());
        }
        assert!(!queue.enqueue(vec![3; 4]));
        assert_eq!(queue.dequeue().unwrap(), [vec![0; 4], vec![1; 4]].concat());
        assert!(queue.enqueue(vec![4; 24]));
        assert_eq!(queue.queued_bytes, 24);
        assert!(queue.realign(1));
        assert_eq!(queue.queued_bytes, 16);
        assert!(!queue.realign(1));
        assert_eq!(queue.dequeue(), Some(vec![4; 8]));
    }

    #[test]
    fn duplicate_packets_do_not_trigger_restart_but_a_progressing_restart_does() {
        let mut queue = AudioReceiveQueue::with_format(2, 0, 8, 2);
        assert!(queue.admit_sequence(1000));
        queue.enqueue(vec![1; 4]);
        for _ in 0..64 {
            assert!(!queue.admit_sequence(1));
        }
        assert_eq!(queue.take_resyncs(), 0);
        for sequence in 2..16 {
            assert!(!queue.admit_sequence(sequence));
        }
        assert!(queue.admit_sequence(16));
        assert_eq!(queue.take_resyncs(), 1);
        assert_eq!(
            queue.queued_bytes, 0,
            "restart discards previous partial PCM"
        );
        assert!(!queue.valid_pcm(&[1, 2, 3]));
        assert!(queue.valid_pcm(&[1, 2, 3, 4]));
    }
}
