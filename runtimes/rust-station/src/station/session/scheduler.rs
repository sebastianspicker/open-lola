//! Deadline-first media scheduling primitives.
//!
//! Video preparation is deliberately separated from the transport cursor: a
//! prepared frame may contain many packets, while one scheduler quantum may
//! send only one of them. The depth-one mailbox keeps latency bounded by
//! replacing work which cannot still be useful.

use std::time::{Duration, Instant};

use crate::protocol::StreamingVideoFragments;

#[derive(Debug, PartialEq, Eq)]
pub(super) struct PreparedVideoFrame {
    pub(super) sequence: u64,
    fragments: StreamingVideoFragments,
    prepared_at: Instant,
}

impl PreparedVideoFrame {
    pub(super) fn new(sequence: u64, fragments: StreamingVideoFragments) -> Self {
        Self {
            sequence,
            fragments,
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

#[derive(Debug, PartialEq, Eq)]
pub(super) struct VideoTxCursor {
    frame: PreparedVideoFrame,
    next_datagram: usize,
    scratch: Vec<u8>,
}

impl VideoTxCursor {
    pub(super) fn new(frame: PreparedVideoFrame) -> Self {
        let scratch_capacity = frame.fragments.maximum_datagram_size();
        Self {
            frame,
            next_datagram: 0,
            scratch: Vec::with_capacity(scratch_capacity),
        }
    }

    pub(super) fn sequence(&self) -> u64 {
        self.frame.sequence
    }

    pub(super) fn next(&mut self) -> Option<&[u8]> {
        self.frame
            .fragments
            .write_datagram(self.next_datagram, &mut self.scratch)
    }

    pub(super) fn sent_one(&mut self) -> bool {
        self.next_datagram += 1;
        self.next_datagram == self.frame.fragments.datagram_count()
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
    pub(super) audio_skipped_deadlines: u64,
    pub(super) audio_max_lateness_us: u64,
    pub(super) audio_lateness: super::timing::TimingHistogram,
    pub(super) video_queue_age: super::timing::TimingHistogram,
    pub(super) video_max_queue_age_us: u64,
    pub(super) video_stale_drops: u64,
    pub(super) video_backpressure_drops: u64,
    pub(super) video_deadline_drops: u64,
    /// Audio blocks serviced early because the capture device had one ready.
    pub(super) audio_device_paced_services: u64,
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
        self.counters
            .audio_lateness
            .observe(late.as_micros() as u64);
        if !late.is_zero() {
            self.counters.audio_deadline_misses += 1;
            self.counters.audio_max_lateness_us = self
                .counters
                .audio_max_lateness_us
                .max(late.as_micros() as u64);
        }
        // Keep the original sample clock under ordinary wake-up jitter. After
        // a stall, service one fresh block and skip past missed clock slots;
        // never burst stale blocks merely to catch the schedule up.
        let periods = late.as_nanos() / self.audio_period.as_nanos();
        self.counters.audio_skipped_deadlines = self
            .counters
            .audio_skipped_deadlines
            .saturating_add(u64::try_from(periods).unwrap_or(u64::MAX));
        let remainder = late.as_nanos() % self.audio_period.as_nanos();
        let remainder = Duration::new(
            (remainder / 1_000_000_000) as u64,
            (remainder % 1_000_000_000) as u32,
        );
        self.next_audio_deadline = now
            .checked_add(self.audio_period - remainder)
            .expect("validated audio period fits the monotonic clock");
        true
    }

    /// Lets a ready capture block pace the audio clock. Serviced before the
    /// wall-clock deadline, the next deadline is re-anchored one period after
    /// `now`, so the device clock rather than the wall clock drives audio.
    /// At or past the deadline this declines and `audio_due` handles it.
    pub(super) fn service_device_block(&mut self, now: Instant) -> bool {
        if now >= self.next_audio_deadline {
            return false;
        }
        self.next_audio_deadline = now + self.audio_period;
        self.counters.audio_device_paced_services += 1;
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
        let age = frame.prepared_at.elapsed().as_micros() as u64;
        self.counters.video_queue_age.observe(age);
        self.counters.video_max_queue_age_us = self.counters.video_max_queue_age_us.max(age);
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
    use crate::test_alloc::measure_allocations;

    fn frame(sequence: u64, payload_length: usize) -> PreparedVideoFrame {
        PreparedVideoFrame::new(
            sequence,
            StreamingVideoFragments::new(sequence as u32, &vec![0; payload_length], None, 128),
        )
    }

    #[test]
    fn audio_clock_preserves_phase_and_skips_stale_slots_without_bursts() {
        for (late_us, next_us, skipped) in [(100, 1000, 0), (3200, 4000, 3), (1000, 2000, 1)] {
            let mut scheduler = DeadlineScheduler::new(Duration::from_micros(1000));
            let origin = scheduler.next_audio_deadline;
            let now = origin + Duration::from_micros(late_us);
            assert!(scheduler.audio_due(now));
            assert_eq!(
                scheduler.next_audio_deadline,
                origin + Duration::from_micros(next_us)
            );
            assert_eq!(scheduler.counters.audio_skipped_deadlines, skipped);
            assert!(!scheduler.audio_due(now));
        }
        let mut scheduler = DeadlineScheduler::new(Duration::from_micros(1000));
        let origin = scheduler.next_audio_deadline;
        for tick in 0..100 {
            assert!(scheduler.audio_due(origin + Duration::from_micros(tick * 1000 + 100)));
        }
        assert_eq!(
            scheduler.next_audio_deadline,
            origin + Duration::from_millis(100)
        );
        assert_eq!(scheduler.counters.audio_skipped_deadlines, 0);
    }

    #[test]
    fn device_block_paces_audio_ahead_of_the_wall_clock() {
        let mut scheduler = DeadlineScheduler::new(Duration::from_millis(10));
        let origin = scheduler.next_audio_deadline;
        // Past the deadline the wall clock keeps ownership.
        assert!(!scheduler.service_device_block(origin));
        assert_eq!(scheduler.counters.audio_device_paced_services, 0);

        assert!(scheduler.audio_due(origin));
        let early = origin + Duration::from_millis(4);
        assert!(scheduler.service_device_block(early));
        assert_eq!(scheduler.counters.audio_device_paced_services, 1);
        assert_eq!(
            scheduler.next_audio_deadline,
            early + Duration::from_millis(10)
        );
        assert!(!scheduler.audio_due(early));
    }

    #[test]
    fn due_audio_preempts_pending_video_fragments() {
        let mut scheduler = DeadlineScheduler::new(Duration::from_millis(10));
        let now = Instant::now();
        let mut mailbox = PreparedVideoMailbox::default();
        mailbox.publish(frame(1, 100));
        let mut cursor = None;
        scheduler.adopt_newest(&mut mailbox, &mut cursor);
        assert!(scheduler.audio_due(now));
        assert!(cursor.is_some());
        assert_eq!(scheduler.counters.video_deadline_drops, 0);
    }

    #[test]
    fn new_frame_waits_behind_a_partially_sent_cursor() {
        let mut scheduler = DeadlineScheduler::new(Duration::from_millis(10));
        let mut mailbox = PreparedVideoMailbox::default();
        let mut active = VideoTxCursor::new(frame(1, 100));
        assert!(!active.sent_one());
        let mut cursor = Some(active);
        mailbox.publish(frame(2, 0));

        scheduler.adopt_newest(&mut mailbox, &mut cursor);

        assert_eq!(cursor.as_ref().unwrap().sequence(), 1);
        assert_eq!(mailbox.take().unwrap().sequence, 2);
        assert_eq!(scheduler.counters.video_stale_drops, 0);
    }

    #[test]
    fn would_block_drops_remaining_video_frame_once() {
        let mut scheduler = DeadlineScheduler::new(Duration::from_millis(10));
        let mut cursor = Some(VideoTxCursor::new(frame(1, 200)));
        scheduler.drop_video_for_backpressure(&mut cursor);
        scheduler.drop_video_for_backpressure(&mut cursor);
        assert_eq!(scheduler.counters.video_backpressure_drops, 1);
    }

    fn packetization_sample<F>(mut run: F) -> (Vec<f64>, u64, u64, usize)
    where
        F: FnMut() -> usize,
    {
        const WARMUP: usize = 5;
        const REPEATS: usize = 31;
        let expected_work = run();
        for _ in 1..WARMUP {
            assert_eq!(run(), expected_work);
        }
        let mut samples = Vec::with_capacity(REPEATS);
        for _ in 0..REPEATS {
            let started = Instant::now();
            assert_eq!(run(), expected_work);
            samples.push(started.elapsed().as_secs_f64() * 1000.0);
        }
        let (measured_work, memory) = measure_allocations(&mut run);
        assert_eq!(measured_work, expected_work);
        (samples, memory.calls, memory.bytes, expected_work)
    }

    fn sample_summary(samples: &[f64]) -> (f64, f64, f64, f64, f64, f64) {
        let mut sorted = samples.to_vec();
        let mean = samples.iter().sum::<f64>() / samples.len() as f64;
        let variance = samples
            .iter()
            .map(|sample| (sample - mean).powi(2))
            .sum::<f64>()
            / samples.len() as f64;
        sorted.sort_by(f64::total_cmp);
        (
            sorted[15],
            sorted[29],
            sorted[0],
            sorted[30],
            variance.sqrt(),
            variance.sqrt() / mean * 100.0,
        )
    }

    #[test]
    #[ignore = "manual release-mode session packetization benchmark"]
    fn streaming_cursor_reuses_storage_against_previous_eager_path() {
        let payload = vec![0x5a; 1920 * 1080 * 4];
        let eager = packetization_sample(|| {
            crate::protocol::build_video_payloads(7, &payload, None, 1400)
                .iter()
                .map(Vec::len)
                .sum()
        });
        let streaming = packetization_sample(|| {
            let frame =
                PreparedVideoFrame::new(7, StreamingVideoFragments::new(7, &payload, None, 1400));
            let mut cursor = VideoTxCursor::new(frame);
            let mut bytes = 0;
            while let Some(datagram) = cursor.next() {
                bytes += std::hint::black_box(datagram).len();
                cursor.sent_one();
            }
            bytes
        });
        assert_eq!(eager.3, streaming.3);
        for (name, result) in [("eager", eager), ("streaming", streaming)] {
            let summary = sample_summary(&result.0);
            let raw_samples = result
                .0
                .iter()
                .map(|sample| format!("{sample:.6}"))
                .collect::<Vec<_>>()
                .join(",");
            println!(
                "{{\"path\":\"{name}\",\"warmups\":5,\"samples\":31,\"median_ms\":{:.6},\"p95_ms\":{:.6},\"min_ms\":{:.6},\"max_ms\":{:.6},\"stddev_ms\":{:.6},\"cv_pct\":{:.3},\"alloc_calls_per_run\":{},\"alloc_bytes_per_run\":{},\"wire_bytes_per_frame\":{},\"samples_ms\":[{raw_samples}]}}",
                summary.0,
                summary.1,
                summary.2,
                summary.3,
                summary.4,
                summary.5,
                result.1,
                result.2,
                result.3
            );
        }
    }
}
