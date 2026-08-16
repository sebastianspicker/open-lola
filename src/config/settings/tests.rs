use super::*;

#[test]
fn legacy_auto_migrates_to_native() {
    let s: StationSettings =
        serde_json::from_str(r#"{"audio":{"backend":"auto"},"video":{"backend":"ximea"}}"#)
            .unwrap();
    assert_eq!(s.schema_version, SETTINGS_SCHEMA_VERSION);
    assert_eq!(s.audio.backend, AudioBackend::PortAudioAsio);
    assert_eq!(s.video.backend, VideoBackend::Ximea);
}

#[test]
fn validation_rejects_ambiguous_network_identity() {
    let mut settings = StationSettings::default();
    settings.network.control_port = 0;
    assert!(settings.validate().is_err());

    settings.network.control_port = DEFAULT_CONTROL_PORT;
    settings.network.audio_port = DEFAULT_CONTROL_PORT;
    assert!(settings.validate().is_err());

    settings.network.audio_port = DEFAULT_AUDIO_PORT;
    settings.network.session_id = -1;
    assert!(settings.validate().is_err());

    settings.network.session_id = i64::from(u32::MAX) + 1;
    assert!(settings.validate().is_err());

    settings.network.session_id = 1;
    settings.network.remote_ip = "localhost".into();
    assert!(settings.validate().is_err());

    settings.network.remote_ip = "127.0.0.1".into();
    settings.network.bind_ip = "127.0.0.2".into();
    assert!(settings.validate().is_err());

    settings.network.bind_ip = "0.0.0.0".into();
    settings.network.vlan_tag = Some(4_095);
    assert!(settings.validate().is_err());

    settings.network.vlan_tag = None;
    settings.network.media_transport = MediaTransportKind::Npcap;
    assert!(settings.validate().is_err());
}

#[test]
fn validation_rejects_invalid_media_controls() {
    let mut settings = StationSettings::default();
    settings.audio.tx_audio_level = 3;
    assert!(settings.validate().is_err());

    settings.audio.tx_audio_level = 1;
    settings.video.bayer = 2;
    assert!(settings.validate().is_err());

    settings.video.bayer = 1;
    settings.video.bayer_pattern = "invalid".into();
    assert!(settings.validate().is_err());

    settings.video.bayer_pattern = "BGGR".into();
    settings.video.incomplete_frame_threshold_pct = f64::NAN;
    assert!(settings.validate().is_err());
}
