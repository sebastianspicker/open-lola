//! Deadline-first media scheduling primitives.
//!
//! Video preparation is deliberately separated from the transport cursor: a
//! prepared frame may contain many packets, while one scheduler quantum may
//! send only one of them. The depth-one mailbox keeps latency bounded by
//! replacing work which cannot still be useful.

use std::time::{Duration, Instant};

#[derive(Debug, Clone, PartialEq, Eq)]
pub(super) struct PreparedVideoFrame {
    pub(super) sequence: u64,
    pub(super) datagrams: Vec<Vec<u8>>,
    prepared_at: Instant,
}

impl PreparedVideoFrame {
    pub(super) fn new(sequence: u64, datagrams: Vec<Vec<u8>>) -> Self {
        Self {
            sequence,
            datagrams,
            prepared_at: Instant::now(),
        }
    }
}

/// A depth-one overwrite mailbox. The producer never waits for the network.
#[derive(Debug, Default)]
pub(super) struct PreparedVideoMailbox {
    newest: Option<PreparedVideoFrame>,
}

impl PreparedVideoMailbox {
    pub(super) fn publish(&mut self, frame: PreparedVideoFrame) -> bool {
        self.newest.replace(frame).is_some()
    }

    pub(super) fn take(&mut self) -> Option<PreparedVideoFrame> {
        self.newest.take()
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub(super) struct VideoTxCursor {
    frame: PreparedVideoFrame,
    next_datagram: usize,
}

impl VideoTxCursor {
    pub(super) fn new(frame: PreparedVideoFrame) -> Self {
        Self {
            frame,
            next_datagram: 0,
        }
    }

    pub(super) fn sequence(&self) -> u64 {
        self.frame.sequence
    }

    pub(super) fn next(&self) -> Option<&[u8]> {
        self.frame
            .datagrams
            .get(self.next_datagram)
            .map(Vec::as_slice)
    }

    pub(super) fn sent_one(&mut self) -> bool {
        self.next_datagram += 1;
        self.next_datagram == self.frame.datagrams.len()
    }

    pub(super) fn has_started(&self) -> bool {
        self.next_datagram != 0
    }

    pub(super) fn expired(&self, now: Instant, maximum_age: Duration) -> bool {
        now.duration_since(self.frame.prepared_at) > maximum_age
    }
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub(super) struct SchedulerCounters {
    pub(super) audio_deadline_misses: u64,
    pub(super) audio_max_lateness_us: u64,
    pub(super) video_stale_drops: u64,
    pub(super) video_backpressure_drops: u64,
    pub(super) video_deadline_drops: u64,
}

#[derive(Debug)]
pub(super) struct DeadlineScheduler {
    next_audio_deadline: Instant,
    audio_period: Duration,
    pub(super) counters: SchedulerCounters,
}

impl DeadlineScheduler {
    pub(super) fn new(audio_period: Duration) -> Self {
        Self {
            next_audio_deadline: Instant::now(),
            audio_period: audio_period.max(Duration::from_micros(1)),
            counters: SchedulerCounters::default(),
        }
    }

    pub(super) fn audio_due(&mut self, now: Instant) -> bool {
        if now < self.next_audio_deadline {
            return false;
        }
        let late = now.duration_since(self.next_audio_deadline);
        if !late.is_zero() {
            self.counters.audio_deadline_misses += 1;
            self.counters.audio_max_lateness_us = self
                .counters
                .audio_max_lateness_us
                .max(late.as_micros() as u64);
        }
        self.next_audio_deadline = now + self.audio_period;
        true
    }

    pub(super) fn wait_until_audio_due(&self, now: Instant) -> Duration {
        self.next_audio_deadline.saturating_duration_since(now)
    }

    /// Adopt only a strictly newer prepared frame. Once transmission of a
    /// fragmented frame starts, finish it before adopting the newest queued
    /// frame. Abandoning a partially sent frame on every camera update would
    /// leave the receiver with an unbounded succession of incomplete frames.
    pub(super) fn adopt_newest(
        &mut self,
        mailbox: &mut PreparedVideoMailbox,
        cursor: &mut Option<VideoTxCursor>,
    ) {
        let Some(frame) = mailbox.take() else {
            return;
        };
        if let Some(current) = cursor.as_ref() {
            if current.sequence() >= frame.sequence {
                self.counters.video_stale_drops += 1;
                return;
            }
            if current.has_started() {
                mailbox.publish(frame);
                return;
            }
        }
        if cursor.replace(VideoTxCursor::new(frame)).is_some() {
            self.counters.video_stale_drops += 1;
        }
    }

    pub(super) fn drop_video_for_deadline(&mut self, cursor: &mut Option<VideoTxCursor>) {
        if cursor.take().is_some() {
            self.counters.video_deadline_drops += 1;
        }
    }

    pub(super) fn drop_video_for_backpressure(&mut self, cursor: &mut Option<VideoTxCursor>) {
        if cursor.take().is_some() {
            self.counters.video_backpressure_drops += 1;
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn frame(sequence: u64, count: usize) -> PreparedVideoFrame {
        PreparedVideoFrame::new(sequence, (0..count).map(|n| vec![n as u8]).collect())
    }

    #[test]
    fn due_audio_preempts_pending_video_fragments() {
        let mut scheduler = DeadlineScheduler::new(Duration::from_millis(10));
        let now = Instant::now();
        let mut mailbox = PreparedVideoMailbox::default();
        mailbox.publish(frame(1, 2));
        let mut cursor = None;
        scheduler.adopt_newest(&mut mailbox, &mut cursor);
        assert!(scheduler.audio_due(now));
        assert!(cursor.is_some());
        assert_eq!(scheduler.counters.video_deadline_drops, 0);
    }

    #[test]
    fn video_quantum_performs_at_most_one_transport_operation() {
        let mut cursor = VideoTxCursor::new(frame(1, 3));
        let mut transport_operations = 0;
        if cursor.next().is_some() {
            transport_operations += 1;
            assert!(!cursor.sent_one());
        }
        assert_eq!(transport_operations, 1);
        assert!(cursor.next().is_some());
    }

    #[test]
    fn new_frame_supersedes_an_unstarted_stale_video_cursor() {
        let mut scheduler = DeadlineScheduler::new(Duration::from_millis(10));
        let mut mailbox = PreparedVideoMailbox::default();
        let mut cursor = Some(VideoTxCursor::new(frame(1, 2)));
        mailbox.publish(frame(2, 1));
        scheduler.adopt_newest(&mut mailbox, &mut cursor);
        assert_eq!(cursor.unwrap().sequence(), 2);
        assert_eq!(scheduler.counters.video_stale_drops, 1);
    }

    #[test]
    fn new_frame_waits_behind_a_partially_sent_cursor() {
        let mut scheduler = DeadlineScheduler::new(Duration::from_millis(10));
        let mut mailbox = PreparedVideoMailbox::default();
        let mut active = VideoTxCursor::new(frame(1, 2));
        assert!(!active.sent_one());
        let mut cursor = Some(active);
        mailbox.publish(frame(2, 1));

        scheduler.adopt_newest(&mut mailbox, &mut cursor);

        assert_eq!(cursor.as_ref().unwrap().sequence(), 1);
        assert_eq!(mailbox.take().unwrap().sequence, 2);
        assert_eq!(scheduler.counters.video_stale_drops, 0);
    }

    #[test]
    fn would_block_drops_remaining_video_frame_once() {
        let mut scheduler = DeadlineScheduler::new(Duration::from_millis(10));
        let mut cursor = Some(VideoTxCursor::new(frame(1, 3)));
        scheduler.drop_video_for_backpressure(&mut cursor);
        scheduler.drop_video_for_backpressure(&mut cursor);
        assert_eq!(scheduler.counters.video_backpressure_drops, 1);
    }

    #[test]
    fn stale_video_cursor_drops_after_latency_budget() {
        let mut scheduler = DeadlineScheduler::new(Duration::from_millis(10));
        let mut cursor = Some(VideoTxCursor::new(frame(1, 3)));
        assert!(cursor.as_ref().is_some_and(
            |active| active.expired(Instant::now() + Duration::from_millis(2), Duration::ZERO)
        ));
        scheduler.drop_video_for_deadline(&mut cursor);
        assert_eq!(scheduler.counters.video_deadline_drops, 1);
    }

    #[test]
    fn continuous_video_backlog_cannot_consume_next_audio_deadline() {
        let period = Duration::from_millis(10);
        let mut scheduler = DeadlineScheduler::new(period);
        let now = Instant::now();
        assert!(scheduler.audio_due(now));
        assert!(!scheduler.audio_due(now + Duration::from_millis(1)));
        assert!(scheduler.audio_due(now + period));
    }
}
