use rusty_lola::config::{
    load_settings, save_settings, AudioBackend, MediaTransportKind, StationSettings, VideoBackend,
    SETTINGS_SCHEMA_VERSION,
};
use std::fs;
use tempfile::tempdir;

#[test]
fn legacy_backend_strings_migrate_to_typed_schema() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("legacy.json");
    fs::write(
        &path,
        r#"{"audio":{"backend":"auto"},"video":{"backend":"xiapi"},"network":{"raw_media_plane":true,"nic_name":"Npcap Adapter"}}"#,
    )
    .unwrap();
    let settings = load_settings(&path).unwrap();
    assert_eq!(settings.schema_version, SETTINGS_SCHEMA_VERSION);
    assert_eq!(settings.audio.backend, AudioBackend::PortAudioAsio);
    assert_eq!(settings.video.backend, VideoBackend::Ximea);
    assert_eq!(settings.network.media_transport, MediaTransportKind::Npcap);
    assert_eq!(settings.network.pcap_device, "Npcap Adapter");
    save_settings(&path, &settings).unwrap();
    let saved = fs::read_to_string(path).unwrap();
    assert!(saved.contains("\"schema_version\": 2"));
    assert!(saved.contains("\"port_audio_asio\""));
    assert!(saved.contains("\"media_transport\": \"npcap\""));
    assert!(!saved.contains("raw_media_plane"));
    assert!(!saved.contains("use_raw_pcap"));
}

#[test]
fn validation_rejects_unsupported_sample_format_and_frame_memory() {
    let mut settings = StationSettings::default();
    settings.audio.bits_per_sample = 12;
    assert!(settings.validate().is_err());
    settings.audio.bits_per_sample = 16;
    settings.video.width = 100_000;
    settings.video.height = 100_000;
    assert!(settings.validate().is_err());
    settings.video.backend = VideoBackend::Diagnostic;
    assert_eq!(settings.video.backend.as_preference(), "diagnostic");
}

#[test]
fn packet_size_is_exactly_validated_instead_of_silently_clamped() {
    let mut settings = StationSettings::default();
    settings.network.video_packet_size = 127;
    assert!(settings.validate().is_err());
    settings.network.video_packet_size = 128;
    assert!(settings.validate().is_ok());
    settings.network.video_packet_size = 8_193;
    assert!(settings.validate().is_err());
}

#[test]
fn recording_direction_selection_round_trips_for_audio_and_video() {
    let mut settings = StationSettings::default();
    settings.recording.record_local_audio = false;
    settings.recording.record_remote_video = false;
    let encoded = serde_json::to_string(&settings).unwrap();
    let decoded: StationSettings = serde_json::from_str(&encoded).unwrap();
    assert!(!decoded.recording.record_local_audio);
    assert!(decoded.recording.record_remote_audio);
    assert!(decoded.recording.record_local_video);
    assert!(!decoded.recording.record_remote_video);
}

#[test]
fn legacy_device_and_zero_queue_values_migrate_explicitly() {
    let settings: StationSettings = serde_json::from_str(
        r#"{
            "audio":{"device":"ASIO Device"},
            "network":{"receive_queue_depth":0,"receive_prefill":0}
        }"#,
    )
    .unwrap();
    assert_eq!(settings.audio.input_device, "ASIO Device");
    assert_eq!(settings.audio.output_device, "ASIO Device");
    assert_eq!(settings.network.audio_receive_queue_depth, 1);
    assert_eq!(settings.network.video_receive_queue_depth, 1);
    assert_eq!(settings.network.audio_receive_prefill, 0);
    assert_eq!(settings.network.video_receive_prefill, 0);
}

#[test]
fn input_channel_offset_is_bounded_with_selected_channels() {
    let mut settings = StationSettings::default();
    settings.audio.channels = 2;
    settings.audio.input_offset = 63;
    assert!(settings.validate().is_err());
    settings.audio.input_offset = 2;
    assert!(settings.validate().is_ok());
}

#[test]
fn legacy_nic_name_migrates_to_the_productive_pcap_adapter_field() {
    let settings: StationSettings =
        serde_json::from_str(r#"{"network":{"nic_name":"Npcap Adapter"}}"#).unwrap();
    assert_eq!(settings.network.pcap_device, "Npcap Adapter");
    assert!(settings.network.nic_name.is_empty());
    assert!(!serde_json::to_string(&settings)
        .unwrap()
        .contains("nic_name"));
}
