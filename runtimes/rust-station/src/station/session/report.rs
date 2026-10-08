//! Compatible session report serialization, separate from runtime state values.
use super::SessionResult;
use serde_json::{json, Value};

impl SessionResult {
    pub fn to_json(&self) -> Value {
        let mut value = json!({
            "ok": self.ok,
            "error": self.error,
            "states": self.states,
            "messages_sent": self.messages_sent,
            "messages_received": self.messages_received,
            "media_frames_sent": self.media_frames_sent,
            "media_frames_received": self.media_frames_received,
            "video_frames_sent": self.video_frames_sent,
            "video_frames_received": self.video_frames_received,
            "audio_frames_sent": self.audio_frames_sent,
            "audio_frames_received": self.audio_frames_received,
            "audio_device_xruns": self.audio_device_xruns,
            "audio_skipped_deadlines": self.audio_skipped_deadlines,
            "capabilities": self.capabilities,
            "bounce_back": self.bounce_back,
            "chat_messages": self.chat_messages,
            "audio_signal_active": self.audio_signal_active,
            "rejected": self.rejected,
            "reject_text": self.reject_text,
            "compression_used": self.compression_used,
            "jpeg_decoded_ok": self.jpeg_decoded_ok,
            "camera_mode_id": self.camera_mode_id,
            "stream_frames": self.stream_frames,
            "camera_backend": self.camera_backend,
            "audio_backend": self.audio_backend,
            "media_transport": self.media_transport,
            "preview_paths": self.preview_paths,
            "record_paths": self.record_paths,
            "network_monitor": self.network_monitor,
            "network_monitor_report": self.network_monitor_report,
            "color_applied": self.color_applied,
            "bayer_applied": self.bayer_applied,
            "test_signal_applied": self.test_signal_applied,
            "test_signal_mode": self.test_signal_mode,
            "reachable": self.reachable,
            "rtt_ms": self.rtt_ms,
            "raw_plane_used": self.raw_plane_used,
            "peer_mode": self.peer_mode,
        });
        let object = value
            .as_object_mut()
            .expect("SessionResult JSON is always an object");
        object.insert(
            "audio_deadline_misses".into(),
            json!(self.audio_deadline_misses),
        );
        object.insert(
            "audio_max_lateness_us".into(),
            json!(self.audio_max_lateness_us),
        );
        object.insert(
            "audio_lateness_p95_upper_us".into(),
            json!(self.audio_lateness_p95_upper_us),
        );
        object.insert(
            "video_queue_age_p95_upper_us".into(),
            json!(self.video_queue_age_p95_upper_us),
        );
        object.insert(
            "video_max_queue_age_us".into(),
            json!(self.video_max_queue_age_us),
        );
        object.insert("video_stale_drops".into(), json!(self.video_stale_drops));
        object.insert(
            "video_backpressure_drops".into(),
            json!(self.video_backpressure_drops),
        );
        object.insert(
            "video_deadline_drops".into(),
            json!(self.video_deadline_drops),
        );
        object.insert(
            "video_malformed_drops".into(),
            json!(self.video_malformed_drops),
        );
        object.insert(
            "audio_malformed_drops".into(),
            json!(self.audio_malformed_drops),
        );
        for (name, value) in [
            (
                "audio_device_paced_services",
                self.audio_device_paced_services,
            ),
            (
                "audio_capture_backlog_drops",
                self.audio_capture_backlog_drops,
            ),
            ("audio_capture_timeouts", self.audio_capture_timeouts),
            ("audio_send_drops", self.audio_send_drops),
            ("audio_sequence_resyncs", self.audio_sequence_resyncs),
            ("video_out_of_order_drops", self.video_out_of_order_drops),
            (
                "video_superseded_incomplete_frames",
                self.video_superseded_incomplete_frames,
            ),
        ] {
            object.insert(name.into(), json!(value));
        }
        object.insert("realtime_priority".into(), json!(self.realtime_priority));
        object.insert("cleanup_warnings".into(), json!(self.cleanup_warnings));
        value
    }
}
