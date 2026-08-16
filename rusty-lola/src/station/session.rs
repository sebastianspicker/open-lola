//! Station control and media session facade.
//!
//! The public session API remains here; implementation details are divided by
//! transport, peer, media, backend, and stream responsibilities.

mod audio;
mod backends;
mod capture;
mod client;
mod client_cleanup;
mod client_media;
mod control;
mod lifecycle;
mod media;
mod peer;
mod runner;
mod scheduler;
mod stream;
mod types;
mod video;

pub use runner::{run_check_only, run_default_session, run_reject_session, run_session};
pub use types::{
    PeerRole, RuntimeActivity, SessionOptions, SessionPhase, SessionResult, SessionRuntimeControl,
    VideoPreview,
};

#[cfg(test)]
mod tests {
    use super::*;
    use crate::config::default_settings;
    use crate::station::SessionError;

    #[test]
    fn loopback_raw_session() {
        let r = run_default_session(3.0, 3, false, true);
        assert!(r.ok, "session failed: {}", r.error);
        assert!(r.video_frames_received >= 3);
        assert!(r.audio_frames_received >= 3);
        assert!(r.messages_sent.iter().any(|m| m == "/MESG_CHECKLOLASTATUS"));
        assert!(r.messages_sent.iter().any(|m| m == "/MESG_QUICKCONN"));
        assert_eq!(r.camera_mode_id, "009");
        assert!(!r.network_monitor.is_empty());
        assert!(r.color_applied || r.bayer_applied);
    }

    #[test]
    fn loopback_jpeg_session() {
        let r = run_default_session(3.0, 2, true, true);
        assert!(r.ok, "jpeg session failed: {}", r.error);
        assert!(r.compression_used);
        assert!(r.jpeg_decoded_ok);
    }

    #[test]
    fn color_and_bayer_on_stream() {
        let mut settings = default_settings();
        settings.video.bayer = 1;
        settings.video.bpp = 8;
        let mut opts = SessionOptions::demo();
        opts.stream_frames = 2;
        opts.control_extras = false;
        opts.apply_color = true;
        opts.auto_bayer = true;
        let r = run_session(settings, 4.0, opts);
        assert!(r.ok, "err={}", r.error);
        assert!(r.bayer_applied, "bayer should apply on Mono8 stream");
        assert!(r.color_applied, "color gains should apply on stream");
        assert!(r.network_monitor.get("video_sent").copied().unwrap_or(0) >= 2);
    }

    #[test]
    fn unknown_peer_role_is_a_configuration_error_not_loopback() {
        let mut options = SessionOptions::demo();
        options.peer_mode = "not-a-peer-role".into();
        let result = run_session(default_settings(), 1.0, options);
        assert!(!result.ok);
        assert!(matches!(
            result.failure,
            Some(SessionError::Configuration(_))
        ));
        assert!(result.error.contains("unknown peer mode"));
    }
}
