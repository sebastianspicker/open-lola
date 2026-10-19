use super::*;

fn parse(json: &str) -> Result<StationSettings, serde_json::Error> {
    serde_json::from_str(json)
}

#[test]
fn saved_settings_load_back_without_unknown_key_errors() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("settings.json");
    save_settings(&path, &default_settings()).unwrap();
    load_settings(&path).expect("a file the GUI/CLI wrote must load");
}

#[test]
fn unknown_top_level_and_section_keys_are_rejected_by_name() {
    let top = parse(r#"{"schema_version":2,"aduio":{}}"#)
        .unwrap_err()
        .to_string();
    assert!(top.contains("unknown field `aduio`"), "{top}");
    let nested = parse(r#"{"audio":{"sample_rte":48000}}"#)
        .unwrap_err()
        .to_string();
    assert!(nested.contains("unknown field `sample_rte`"), "{nested}");
    let network = parse(r#"{"network":{"remote_address":"10.0.0.1"}}"#)
        .unwrap_err()
        .to_string();
    assert!(network.contains("remote_address"), "{network}");
}

#[test]
fn known_legacy_keys_still_load() {
    let settings = parse(r#"{"audio":{"device":"hw:1"},"network":{"nic_name":"eth0"}}"#).unwrap();
    assert_eq!(settings.audio.input_device, "hw:1");
}

#[test]
fn peer_silence_timeout_defaults_to_five_seconds_and_validates() {
    let mut settings = default_settings();
    assert_eq!(settings.network.peer_silence_timeout_secs, 5.0);
    settings.network.peer_silence_timeout_secs = 0.0;
    assert!(settings.validate().is_ok(), "0 disables the watchdog");
    for bad in [-1.0, 3601.0, f64::NAN, f64::INFINITY] {
        settings.network.peer_silence_timeout_secs = bad;
        assert!(settings.validate().is_err(), "{bad}");
    }
    let parsed = parse(r#"{"network":{"peer_silence_timeout_secs":12}}"#).unwrap();
    assert_eq!(parsed.network.peer_silence_timeout_secs, 12.0);
}
