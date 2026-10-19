//! One-line stderr notices that make demo and synthetic-media behaviour explicit.

use super::CliPeerMode;
use crate::config::{AudioBackend, VideoBackend};

/// `station` defaults to a loopback demo; say so and point to the LAN commands.
pub(super) fn station_demo_notice(peer_mode: CliPeerMode) -> Option<String> {
    matches!(peer_mode, CliPeerMode::Loopback).then(|| {
        "station: loopback demo (synthetic peer on this host, small stream cap); \
         use `connect <ip>` / `listen` for a LAN session"
            .to_string()
    })
}

/// Name the backends that produce synthetic media, whatever selected them (a flag,
/// `diagnostic`, or the settings alias `software`).
pub(super) fn synthetic_media_notice(
    command: &str,
    audio: AudioBackend,
    video: VideoBackend,
) -> Option<String> {
    let mut synthetic = Vec::new();
    if audio == AudioBackend::Diagnostic {
        synthetic.push("audio");
    }
    if video == VideoBackend::Diagnostic {
        synthetic.push("video");
    }
    (!synthetic.is_empty()).then(|| {
        format!(
            "{command}: {} media is synthetic (diagnostic backend), not captured from a device",
            synthetic.join(" and ")
        )
    })
}

/// `emulate`/`tester` always run software emulation modes.
pub(super) fn emulation_notice(command: &str) -> String {
    format!("{command}: runs synthetic software emulation; no device or peer media is involved")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn station_notice_appears_only_for_the_loopback_demo() {
        let notice = station_demo_notice(CliPeerMode::Loopback).expect("loopback demo notice");
        assert!(notice.contains("loopback demo"), "{notice}");
        assert!(
            notice.contains("connect") && notice.contains("listen"),
            "{notice}"
        );
        assert_eq!(station_demo_notice(CliPeerMode::Remote), None);
        assert_eq!(station_demo_notice(CliPeerMode::Listen), None);
    }

    #[test]
    fn synthetic_notice_names_the_diagnostic_directions() {
        let both = synthetic_media_notice(
            "connect",
            AudioBackend::Diagnostic,
            VideoBackend::Diagnostic,
        )
        .unwrap();
        assert!(
            both.contains("audio and video media is synthetic"),
            "{both}"
        );
        let video_only =
            synthetic_media_notice("listen", AudioBackend::Alsa, VideoBackend::Diagnostic).unwrap();
        assert!(
            video_only.starts_with("listen: video media"),
            "{video_only}"
        );
        assert_eq!(
            synthetic_media_notice("connect", AudioBackend::Alsa, VideoBackend::V4l2),
            None
        );
    }

    #[test]
    fn software_alias_in_settings_selects_diagnostic_and_is_reported() {
        let settings: crate::config::StationSettings = serde_json::from_str(
            r#"{"audio":{"backend":"software"},"video":{"backend":"software"}}"#,
        )
        .unwrap();
        assert!(
            synthetic_media_notice("station", settings.audio.backend, settings.video.backend)
                .is_some()
        );
    }

    #[test]
    fn emulation_notice_names_the_command() {
        assert!(emulation_notice("tester").starts_with("tester:"));
        assert!(emulation_notice("emulate").contains("synthetic"));
    }
}
