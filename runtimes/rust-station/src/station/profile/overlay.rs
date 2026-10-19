//! Overlay a session profile onto existing settings, touching only the keys the profile set.

use super::{profile_to_settings, SessionProfile};
use crate::config::StationSettings;
use serde_json::Value;
use std::collections::BTreeSet;

/// Top-level key, then the nested objects and aliases that may also carry it.
const FIELD_KEYS: &[(&str, &[&str])] = &[
    ("remote_ip", &["network.remote_ip"]),
    ("local_ip", &[]),
    ("control_port", &[]),
    ("audio_port", &[]),
    ("video_port", &[]),
    ("session_id", &["network.session_id"]),
    ("bind_ip", &["network.bind_ip", "extra.bind_ip"]),
    ("nic_name", &[]),
    ("camera_mode_id", &["video.camera_mode_id"]),
    ("compression", &[]),
    ("jpeg_quality", &[]),
    ("sample_rate", &[]),
    ("channels", &[]),
    ("audio_receive_queue_depth", &["audio_buffers"]),
    ("audio_receive_prefill", &[]),
    ("video_receive_queue_depth", &["video_buffers"]),
    ("video_receive_prefill", &[]),
];

fn has_key(dict: &Value, path: &str) -> bool {
    let mut current = dict;
    for part in path.split('.') {
        match current.get(part) {
            Some(next) => current = next,
            None => return false,
        }
    }
    true
}

/// Names of the profile fields a JSON profile actually specified.
pub(super) fn present_fields(dict: &Value) -> BTreeSet<&'static str> {
    FIELD_KEYS
        .iter()
        .filter(|(name, aliases)| has_key(dict, name) || aliases.iter().any(|a| has_key(dict, a)))
        .map(|(name, _)| *name)
        .collect()
}

/// Apply `profile` over `settings`, replacing only the fields it specified. A profile
/// built in code (no recorded presence) specifies every field.
pub(super) fn overlay_profile(settings: &mut StationSettings, profile: &SessionProfile) {
    let full = profile_to_settings(profile);
    let set = |name: &str| profile.present.as_ref().is_none_or(|p| p.contains(name));
    let (n, f) = (&mut settings.network, &full.network);
    if set("remote_ip") {
        n.remote_ip.clone_from(&f.remote_ip);
    }
    if set("local_ip") {
        n.local_ip.clone_from(&f.local_ip);
    }
    if set("control_port") {
        n.control_port = f.control_port;
    }
    if set("audio_port") {
        n.audio_port = f.audio_port;
    }
    if set("video_port") {
        n.video_port = f.video_port;
    }
    if set("session_id") {
        n.session_id = f.session_id;
    }
    if set("bind_ip") {
        n.bind_ip.clone_from(&f.bind_ip);
    }
    if set("nic_name") {
        n.nic_name.clone_from(&f.nic_name);
    }
    overlay_receive_queues(settings, &full, &set);
    overlay_media(settings, &full, &set);
}

/// Depth and prefill of one stream are validated together (prefill <= depth), so a
/// profile that sets either one applies the profile's pair as a unit.
fn overlay_receive_queues(
    settings: &mut StationSettings,
    full: &StationSettings,
    set: &dyn Fn(&str) -> bool,
) {
    let (n, f) = (&mut settings.network, &full.network);
    if set("audio_receive_queue_depth") || set("audio_receive_prefill") {
        n.audio_receive_queue_depth = f.audio_receive_queue_depth;
        n.audio_receive_prefill = f.audio_receive_prefill;
    }
    if set("video_receive_queue_depth") || set("video_receive_prefill") {
        n.video_receive_queue_depth = f.video_receive_queue_depth;
        n.video_receive_prefill = f.video_receive_prefill;
    }
}

fn overlay_media(
    settings: &mut StationSettings,
    full: &StationSettings,
    set: &dyn Fn(&str) -> bool,
) {
    if set("camera_mode_id") {
        settings
            .video
            .camera_mode_id
            .clone_from(&full.video.camera_mode_id);
    }
    if set("compression") {
        settings.video.compression = full.video.compression;
    }
    if set("jpeg_quality") {
        settings.video.jpeg_quality = full.video.jpeg_quality;
    }
    if set("sample_rate") {
        settings.audio.sample_rate = full.audio.sample_rate;
    }
    if set("channels") {
        settings.audio.channels = full.audio.channels;
    }
}

#[cfg(test)]
mod tests {
    use super::super::apply_profile_to_settings;
    use super::*;
    use crate::config::{default_settings, AudioBackend};
    use serde_json::json;

    fn customised_settings() -> StationSettings {
        let mut settings = default_settings();
        settings.audio.backend = AudioBackend::Diagnostic;
        settings.audio.input_device = "Studio In".into();
        settings.audio.channels = 6;
        settings.recording.enabled = true;
        settings
    }

    #[test]
    fn profile_keys_overlay_settings_and_leave_other_values_alone() {
        let mut settings = customised_settings();
        let profile = SessionProfile::try_from_dict(&json!({ "remote_ip": "10.0.0.9" })).unwrap();
        apply_profile_to_settings(&mut settings, &profile);
        assert_eq!(settings.network.remote_ip, "10.0.0.9");
        assert_eq!(settings.audio.backend, AudioBackend::Diagnostic);
        assert_eq!(settings.audio.input_device, "Studio In");
        assert_eq!(settings.audio.channels, 6);
        assert!(settings.recording.enabled);
    }

    #[test]
    fn present_profile_key_overrides_the_settings_value() {
        let mut settings = customised_settings();
        let profile = SessionProfile::try_from_dict(&json!({
            "channels": 2,
            "network": { "session_id": 9 }
        }))
        .unwrap();
        apply_profile_to_settings(&mut settings, &profile);
        assert_eq!(settings.audio.channels, 2);
        assert_eq!(settings.network.session_id, 9);
        assert_eq!(settings.audio.input_device, "Studio In");
    }

    #[test]
    fn a_profile_queue_depth_keeps_a_valid_prefill() {
        let mut settings = default_settings();
        settings.network.audio_receive_queue_depth = 8;
        settings.network.audio_receive_prefill = 6;
        let profile = SessionProfile::try_from_dict(&json!({ "audio_buffers": 3 })).unwrap();
        apply_profile_to_settings(&mut settings, &profile);
        assert_eq!(settings.network.audio_receive_queue_depth, 3);
        assert!(settings.network.audio_receive_prefill <= 3);
        settings.validate().expect("overlaid settings stay valid");
    }

    #[test]
    fn every_accepted_profile_key_is_recorded_as_present() {
        let cases = [
            (json!({ "remote_ip": "10.0.0.2" }), "remote_ip"),
            (
                json!({ "network": { "remote_ip": "10.0.0.2" } }),
                "remote_ip",
            ),
            (json!({ "local_ip": "10.0.0.1" }), "local_ip"),
            (json!({ "control_port": 7100 }), "control_port"),
            (json!({ "audio_port": 7101 }), "audio_port"),
            (json!({ "video_port": 7102 }), "video_port"),
            (json!({ "session_id": 4 }), "session_id"),
            (json!({ "network": { "session_id": 4 } }), "session_id"),
            (json!({ "bind_ip": "0.0.0.0" }), "bind_ip"),
            (json!({ "extra": { "bind_ip": "0.0.0.0" } }), "bind_ip"),
            (json!({ "nic_name": "en0" }), "nic_name"),
            (json!({ "camera_mode_id": "009" }), "camera_mode_id"),
            (
                json!({ "video": { "camera_mode_id": "009" } }),
                "camera_mode_id",
            ),
            (json!({ "compression": true }), "compression"),
            (json!({ "jpeg_quality": 80 }), "jpeg_quality"),
            (json!({ "sample_rate": 48000 }), "sample_rate"),
            (json!({ "channels": 2 }), "channels"),
            (
                json!({ "audio_receive_queue_depth": 4 }),
                "audio_receive_queue_depth",
            ),
            (json!({ "audio_buffers": 4 }), "audio_receive_queue_depth"),
            (
                json!({ "audio_receive_prefill": 1 }),
                "audio_receive_prefill",
            ),
            (
                json!({ "video_receive_queue_depth": 4 }),
                "video_receive_queue_depth",
            ),
            (json!({ "video_buffers": 4 }), "video_receive_queue_depth"),
            (
                json!({ "video_receive_prefill": 1 }),
                "video_receive_prefill",
            ),
        ];
        for (dict, field) in cases {
            let profile =
                SessionProfile::try_from_dict(&dict).unwrap_or_else(|e| panic!("{dict}: {e:?}"));
            let present = profile.present.expect("parsed profiles record presence");
            assert!(present.contains(field), "{dict} must mark {field} present");
        }
    }

    #[test]
    fn profiles_built_in_code_specify_every_field() {
        let mut settings = customised_settings();
        let profile = SessionProfile::default();
        apply_profile_to_settings(&mut settings, &profile);
        assert_eq!(settings.audio.channels, 2);
        assert_eq!(settings.audio.input_device, "Studio In");
    }
}
