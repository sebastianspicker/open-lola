//! Wrapping media sequence admission and bounded sender-restart recovery.
use crate::protocol::serial_u32_is_newer;

pub(super) const SEQUENCE_RESYNC_REJECTIONS: u32 = 16;

#[derive(Default)]
pub(super) struct ReceiveSequenceGate {
    latest: Option<u32>,
    restart_candidate: Option<u32>,
    restart_progress: u32,
    resyncs: u64,
}

pub(super) enum SequenceAdmission {
    New,
    Resynced,
    Rejected,
}

impl ReceiveSequenceGate {
    pub(super) fn admit(&mut self, sequence: u32) -> SequenceAdmission {
        if self
            .latest
            .is_some_and(|last| !serial_u32_is_newer(sequence, last))
        {
            // A progressing stream below the previous serial window signals a
            // restart. Repeating one packet or replaying packets backwards must
            // never reset the queue to stale audio/video.
            self.restart_progress = if self
                .restart_candidate
                .is_some_and(|last| serial_u32_is_newer(sequence, last))
            {
                self.restart_progress + 1
            } else {
                1
            };
            self.restart_candidate = Some(sequence);
            if self.restart_progress < SEQUENCE_RESYNC_REJECTIONS {
                return SequenceAdmission::Rejected;
            }
            self.resyncs += 1;
            self.reset_candidate(sequence);
            return SequenceAdmission::Resynced;
        }
        self.reset_candidate(sequence);
        SequenceAdmission::New
    }

    fn reset_candidate(&mut self, sequence: u32) {
        self.latest = Some(sequence);
        self.restart_candidate = None;
        self.restart_progress = 0;
    }

    pub(super) fn take_resyncs(&mut self) -> u64 {
        std::mem::take(&mut self.resyncs)
    }
}
