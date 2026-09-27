//! Typed session observations shared by runtime snapshots and report counters.
use super::*;

impl RuntimeActivity {
    pub(crate) fn from_result(result: &SessionResult) -> Self {
        let synthetic_audio = result.audio_backend.contains("synthetic");
        let synthetic_video = result.camera_backend.contains("synthetic");
        Self {
            audio_backend: (!result.audio_backend.is_empty()).then_some(if synthetic_audio {
                AudioBackend::Diagnostic
            } else if result.audio_backend == "ALSA" {
                AudioBackend::Alsa
            } else {
                AudioBackend::PortAudioAsio
            }),
            video_backend: (!result.camera_backend.is_empty()).then_some(if synthetic_video {
                VideoBackend::Diagnostic
            } else if result.camera_backend == "V4L2" {
                VideoBackend::V4l2
            } else {
                VideoBackend::Ximea
            }),
            transport: Some(if result.media_transport == "npcap" {
                MediaTransportKind::Npcap
            } else {
                MediaTransportKind::Udp
            }),
            synthetic: synthetic_audio || synthetic_video,
            media_frames_sent: result.media_frames_sent,
            media_frames_received: result.media_frames_received,
            video_frames_sent: result.video_frames_sent,
            video_frames_received: result.video_frames_received,
            audio_frames_sent: result.audio_frames_sent,
            audio_frames_received: result.audio_frames_received,
            audio_device_xruns: result.audio_device_xruns,
            audio_deadline_misses: result.audio_deadline_misses,
            audio_skipped_deadlines: result.audio_skipped_deadlines,
            audio_max_lateness_us: result.audio_max_lateness_us,
            audio_lateness_p95_upper_us: result.audio_lateness_p95_upper_us,
            video_queue_age_p95_upper_us: result.video_queue_age_p95_upper_us,
            video_max_queue_age_us: result.video_max_queue_age_us,
            video_stale_drops: result.video_stale_drops,
            video_backpressure_drops: result.video_backpressure_drops,
            video_deadline_drops: result.video_deadline_drops,
            video_malformed_drops: result.video_malformed_drops,
            audio_malformed_drops: result.audio_malformed_drops,
        }
    }

    pub(crate) fn counters(&self) -> BTreeMap<String, u64> {
        let observed = [
            ("media_frames_sent", Some(self.media_frames_sent)),
            ("media_frames_received", Some(self.media_frames_received)),
            ("video_frames_sent", Some(self.video_frames_sent)),
            ("video_frames_received", Some(self.video_frames_received)),
            ("audio_frames_sent", Some(self.audio_frames_sent)),
            ("audio_frames_received", Some(self.audio_frames_received)),
            ("audio_deadline_misses", Some(self.audio_deadline_misses)),
            (
                "audio_skipped_deadlines",
                Some(self.audio_skipped_deadlines),
            ),
            ("audio_max_lateness_us", Some(self.audio_max_lateness_us)),
            ("audio_device_xruns", self.audio_device_xruns),
            (
                "audio_lateness_p95_upper_us",
                self.audio_lateness_p95_upper_us,
            ),
            (
                "video_queue_age_p95_upper_us",
                self.video_queue_age_p95_upper_us,
            ),
            ("video_max_queue_age_us", Some(self.video_max_queue_age_us)),
            ("video_stale_drops", Some(self.video_stale_drops)),
            (
                "video_backpressure_drops",
                Some(self.video_backpressure_drops),
            ),
            ("video_deadline_drops", Some(self.video_deadline_drops)),
            ("video_malformed_drops", Some(self.video_malformed_drops)),
            ("audio_malformed_drops", Some(self.audio_malformed_drops)),
        ];
        observed
            .into_iter()
            .filter_map(|(key, value)| value.map(|value| (key.into(), value)))
            .collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn native_and_scheduler_observations_survive_live_snapshot_conversion() {
        let mut result = SessionResult::default();
        assert!(!RuntimeActivity::from_result(&result)
            .counters()
            .contains_key("audio_device_xruns"));
        result.audio_device_xruns = Some(3);
        result.audio_lateness_p95_upper_us = Some(100);
        result.audio_skipped_deadlines = 2;
        let counters = RuntimeActivity::from_result(&result).counters();
        assert_eq!(counters["audio_device_xruns"], 3);
        assert_eq!(counters["audio_lateness_p95_upper_us"], 100);
        assert_eq!(counters["audio_skipped_deadlines"], 2);
    }
}
