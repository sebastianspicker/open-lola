//! Characterization test for the `.ssn` session-profile save/load path.
//!
//! This pins the exact on-disk text and load behaviour before
//! `config::ssn` moves to become a child module of `station::profile`, so a
//! regression in the move is caught immediately.

use rusty_lola::station::profile::{load_session_profile, save_session_profile, SessionProfile};

const EXPECTED_SSN_TEXT: &str = "# open-lola-ssn v1
{
  \"audio_port\": 19788,
  \"audio_receive_prefill\": 1,
  \"audio_receive_queue_depth\": 4,
  \"bind_ip\": \"0.0.0.0\",
  \"camera_mode_id\": \"013\",
  \"channels\": 2,
  \"compression\": false,
  \"control_port\": 7000,
  \"extra\": {
    \"note\": \"characterization\"
  },
  \"format\": \"open-lola-ssn\",
  \"jpeg_quality\": 55,
  \"local_ip\": \"127.0.0.1\",
  \"nic_name\": \"\",
  \"remote_audio_channel_offset\": -3,
  \"remote_ip\": \"10.1.2.3\",
  \"sample_rate\": 48000,
  \"session_id\": 42,
  \"version\": 1,
  \"video_port\": 19798,
  \"video_receive_prefill\": 2,
  \"video_receive_queue_depth\": 8
}
";

fn characterization_profile() -> SessionProfile {
    let mut profile = SessionProfile {
        remote_ip: "10.1.2.3".into(),
        session_id: 42,
        camera_mode_id: "013".into(),
        jpeg_quality: 55,
        sample_rate: 48_000,
        audio_receive_queue_depth: 4,
        audio_receive_prefill: 1,
        video_receive_queue_depth: 8,
        video_receive_prefill: 2,
        remote_audio_channel_offset: -3,
        ..SessionProfile::default()
    };
    profile
        .extra
        .insert("note".into(), serde_json::json!("characterization"));
    profile
}

#[test]
fn well_formed_ssn_round_trips_through_the_exact_pinned_text() {
    let directory = tempfile::tempdir().expect("temporary session directory");
    let path = directory.path().join("profile.ssn");

    save_session_profile(&path, &characterization_profile()).expect("save .ssn profile");

    let text = std::fs::read_to_string(&path).expect("read saved .ssn profile");
    assert_eq!(text, EXPECTED_SSN_TEXT);

    let loaded = load_session_profile(&path).expect("load .ssn profile");
    assert_eq!(loaded.remote_ip, "10.1.2.3");
    assert_eq!(loaded.local_ip, "127.0.0.1");
    assert_eq!(loaded.control_port, 7000);
    assert_eq!(loaded.audio_port, 19788);
    assert_eq!(loaded.video_port, 19798);
    assert_eq!(loaded.session_id, 42);
    assert_eq!(loaded.camera_mode_id, "013");
    assert!(!loaded.compression);
    assert_eq!(loaded.jpeg_quality, 55);
    assert_eq!(loaded.sample_rate, 48_000);
    assert_eq!(loaded.channels, 2);
    assert_eq!(loaded.bind_ip, "0.0.0.0");
    assert_eq!(loaded.nic_name, "");
    assert_eq!(loaded.audio_receive_queue_depth, 4);
    assert_eq!(loaded.audio_receive_prefill, 1);
    assert_eq!(loaded.video_receive_queue_depth, 8);
    assert_eq!(loaded.video_receive_prefill, 2);
    assert_eq!(loaded.remote_audio_channel_offset, -3);
    assert_eq!(
        loaded.extra.get("note").and_then(|value| value.as_str()),
        Some("characterization")
    );
}

#[test]
fn malformed_ssn_yields_the_same_last_ssn_ini_error() {
    let directory = tempfile::tempdir().expect("temporary session directory");
    let path = directory.path().join("malformed.ssn");
    std::fs::write(&path, "not json at all").expect("write malformed .ssn file");

    let error = load_session_profile(&path).expect_err("malformed .ssn must fail to load");
    assert_eq!(
        error.to_string(),
        "invalid session profile: LastSsn line 1: expected key=value"
    );
}
