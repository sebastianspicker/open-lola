use rusty_lola::config::{
    load_settings, save_settings, AudioBackend, MediaTransportKind, VideoBackend,
};

#[test]
fn legacy_settings_migrate_and_persist_as_current_schema() {
    let directory = tempfile::tempdir().expect("temporary settings directory");
    let legacy_path = directory.path().join("legacy.json");
    std::fs::write(
        &legacy_path,
        r#"{
            "schema_version": 1,
            "audio": {"device": "Legacy ASIO", "backend": "auto"},
            "video": {"backend": "software"},
            "network": {
                "local_ip": "192.0.2.10",
                "remote_ip": "198.51.100.20",
                "nic_name": "Ethernet 3",
                "raw_media_plane": true,
                "receive_queue_depth": 2,
                "receive_prefill": 1
            }
        }"#,
    )
    .expect("write legacy settings");

    let settings = load_settings(&legacy_path).expect("load migrated legacy settings");
    assert_eq!(settings.audio.input_device, "Legacy ASIO");
    assert_eq!(settings.audio.output_device, "Legacy ASIO");
    assert_eq!(settings.audio.backend, AudioBackend::default());
    assert_eq!(settings.video.backend, VideoBackend::Diagnostic);
    assert_eq!(settings.network.media_transport, MediaTransportKind::Npcap);
    assert_eq!(settings.network.pcap_device, "Ethernet 3");
    assert_eq!(settings.network.audio_receive_queue_depth, 2);
    assert_eq!(settings.network.video_receive_queue_depth, 2);
    assert_eq!(settings.network.audio_receive_prefill, 1);
    assert_eq!(settings.network.video_receive_prefill, 1);

    let current_path = directory.path().join("current/settings.json");
    save_settings(&current_path, &settings).expect("save current settings");
    let saved = std::fs::read_to_string(&current_path).expect("read current settings");
    assert!(saved.contains("\"schema_version\": 2"));
    let document: serde_json::Value = serde_json::from_str(&saved).unwrap();
    assert!(document["audio"].get("device").is_none());
    assert!(!saved.contains("\"raw_media_plane\""));
    assert!(!saved.contains("\"nic_name\""));

    let reloaded = load_settings(current_path).expect("load saved current settings");
    assert_eq!(reloaded.audio.input_device, "Legacy ASIO");
    assert_eq!(reloaded.network.pcap_device, "Ethernet 3");
    assert_eq!(reloaded.network.media_transport, MediaTransportKind::Npcap);
}
