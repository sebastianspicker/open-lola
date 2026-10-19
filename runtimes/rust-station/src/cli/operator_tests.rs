//! Operator flag mapping and settings precedence (defaults < `--settings` <
//! `--session` < CLI flags), exercised through the real loaders.
use super::tests::listen_args;
use super::*;
use crate::cli::station::load_station_settings;
use crate::config::{save_settings, ControlDialect};
use serde_json::{json, Value};
use std::collections::BTreeMap;
use std::path::Path;

type Snapshot = BTreeMap<&'static str, String>;

/// The settings the precedence layers disagree about, as comparable text.
fn snapshot(settings: &StationSettings) -> Snapshot {
    let network = &settings.network;
    [
        ("remote_ip", network.remote_ip.clone()),
        ("local_ip", network.local_ip.clone()),
        ("session_id", network.session_id.to_string()),
        ("control_port", network.control_port.to_string()),
        ("sample_rate", settings.audio.sample_rate.to_string()),
        ("jpeg_quality", settings.video.jpeg_quality.to_string()),
        ("width", settings.video.width.to_string()),
        ("channels", settings.audio.channels.to_string()),
    ]
    .into()
}

/// `base` with `changes` applied: the values a layer is expected to set.
fn with(base: &Snapshot, changes: &[(&'static str, &str)]) -> Snapshot {
    let mut next = base.clone();
    for (name, value) in changes {
        next.insert(name, (*value).to_owned());
    }
    next
}

/// A complete settings file and a partial JSON session profile. Each field
/// below is set by a different mix of layers.
fn layer_files(dir: &Path) -> (PathBuf, PathBuf) {
    let mut settings = default_settings();
    settings.network.remote_ip = "10.0.0.1".into();
    settings.network.local_ip = "10.0.0.11".into();
    settings.network.session_id = 5;
    settings.audio.sample_rate = 48_000;
    settings.video.jpeg_quality = 70;
    let settings_path = dir.join("settings.json");
    save_settings(&settings_path, &settings).unwrap();
    let session_path = dir.join("session.json");
    let profile = json!({
        "remote_ip": "10.0.0.2",
        "session_id": 6,
        "sample_rate": 32_000,
        "control_port": 7100,
    });
    std::fs::write(&session_path, profile.to_string()).unwrap();
    (settings_path, session_path)
}

#[test]
fn settings_precedence_is_defaults_then_settings_then_session_then_flags() {
    let dir = tempfile::tempdir().unwrap();
    let (settings_path, session_path) = layer_files(dir.path());
    let defaults = snapshot(&default_settings());
    assert_eq!(defaults["control_port"], "7000");

    let from_settings = with(
        &defaults,
        &[
            ("remote_ip", "10.0.0.1"),
            ("local_ip", "10.0.0.11"),
            ("session_id", "5"),
            ("sample_rate", "48000"),
            ("jpeg_quality", "70"),
        ],
    );
    let settings_only = load_operator_settings(Some(&settings_path), None).unwrap();
    assert_eq!(snapshot(&settings_only), from_settings);

    // The profile replaces only the keys it names; the rest stay as loaded.
    let from_session = with(
        &from_settings,
        &[
            ("remote_ip", "10.0.0.2"),
            ("session_id", "6"),
            ("sample_rate", "32000"),
            ("control_port", "7100"),
        ],
    );
    let layered = load_operator_settings(Some(&settings_path), Some(&session_path)).unwrap();
    assert_eq!(snapshot(&layered), from_session);
    let station = load_station_settings(Some(&settings_path), Some(&session_path)).unwrap();
    assert_eq!(snapshot(&station), from_session);

    let session_only = load_operator_settings(None, Some(&session_path)).unwrap();
    let expected = with(
        &defaults,
        &[
            ("remote_ip", "10.0.0.2"),
            ("session_id", "6"),
            ("sample_rate", "32000"),
            ("control_port", "7100"),
        ],
    );
    assert_eq!(snapshot(&session_only), expected);

    let args = listen_args(&["--sid", "7", "--sr", "22050", "--width", "640"]);
    let flagged = apply_operator_overrides(layered, Some("10.0.0.3".into()), &args);
    let from_flags = with(
        &from_session,
        &[
            ("remote_ip", "10.0.0.3"),
            ("session_id", "7"),
            ("sample_rate", "22050"),
            ("width", "640"),
        ],
    );
    assert_eq!(snapshot(&flagged), from_flags);
    flagged.validate().expect("the layered settings stay valid");
}

#[test]
fn missing_or_broken_layer_files_are_reported_not_skipped() {
    let dir = tempfile::tempdir().unwrap();
    let missing = dir.path().join("absent.json");
    let error = load_operator_settings(Some(&missing), None).unwrap_err();
    assert!(error.contains("does not exist"), "{error}");
    let broken = dir.path().join("session.json");
    std::fs::write(&broken, "[1, 2]").unwrap();
    assert!(load_operator_settings(None, Some(&broken)).is_err());
    assert!(load_operator_settings(None, Some(&missing)).is_err());
}

/// The flattened `section.field` values that differ from the defaults.
fn changed_settings(flags: &[&str]) -> Value {
    fn walk(before: &Value, after: &Value, path: &str, out: &mut serde_json::Map<String, Value>) {
        match (before, after) {
            (Value::Object(before), Value::Object(after)) => {
                for (key, value) in after {
                    let nested = format!("{path}{key}.");
                    walk(before.get(key).unwrap_or(&Value::Null), value, &nested, out);
                }
            }
            _ if before != after => {
                out.insert(path.trim_end_matches('.').to_owned(), after.clone());
            }
            _ => {}
        }
    }
    let args = listen_args(flags);
    let mapped = apply_operator_overrides(default_settings(), None, &args);
    let mut changes = serde_json::Map::new();
    let (before, after) = (
        serde_json::to_value(default_settings()).unwrap(),
        serde_json::to_value(mapped).unwrap(),
    );
    walk(&before, &after, "", &mut changes);
    Value::Object(changes)
}

#[test]
fn every_value_flag_maps_onto_its_setting() {
    let cases: Vec<(&[&str], Value)> = vec![
        (
            &["--local-ip", "10.1.1.1"],
            json!({"network.local_ip": "10.1.1.1"}),
        ),
        (
            &["--bind-ip", "10.1.1.2"],
            json!({"network.bind_ip": "10.1.1.2"}),
        ),
        (&["--sid", "9"], json!({"network.session_id": 9})),
        (
            &["--packet-size", "900"],
            json!({"network.video_packet_size": 900}),
        ),
        (
            &["--input-device", "In 1"],
            json!({"audio.input_device": "In 1"}),
        ),
        (
            &["--output-device", "Out 1"],
            json!({"audio.output_device": "Out 1"}),
        ),
        (&["--sr", "32000"], json!({"audio.sample_rate": 32000})),
        (&["--bps", "24"], json!({"audio.bits_per_sample": 24})),
        (&["--channels", "1"], json!({"audio.channels": 1})),
        (
            &["--audio-frames-per-callback", "256"],
            json!({"audio.buffer_samples": 256}),
        ),
        (
            &["--audio-backend", "software"],
            json!({"audio.backend": "diagnostic"}),
        ),
        (&["--video-device", "cam0"], json!({"video.device": "cam0"})),
        (
            &["--pixel-format", "RGB24"],
            json!({"video.pixel_format": "RGB24"}),
        ),
        (&["--width", "640"], json!({"video.width": 640})),
        (&["--height", "360"], json!({"video.height": 360})),
        (&["--fps", "30"], json!({"video.fps": 30})),
        (&["--bpp", "24"], json!({"video.bpp": 24})),
        (&["--bayer", "3"], json!({"video.bayer": 3})),
        (&["--compression", "1"], json!({"video.compression": true})),
        (&["--compression", "0"], json!({})),
        (
            &["--camera-backend", "diagnostic"],
            json!({"video.backend": "diagnostic"}),
        ),
        (
            &["--record", "/rec"],
            json!({"recording.enabled": true, "recording.path": "/rec"}),
        ),
    ];
    for (flags, expected) in cases {
        assert_eq!(changed_settings(flags), expected, "{flags:?}");
    }
}

fn mapped_options(flags: &[&str]) -> Result<SessionOptions, String> {
    let args = listen_args(flags);
    let settings = apply_operator_overrides(default_settings(), None, &args);
    session_options(&args, "listen", &settings)
}

#[test]
fn session_flags_map_onto_session_options() {
    type Check = fn(&SessionOptions) -> bool;
    let cases: Vec<(&[&str], Check)> = vec![
        (&["--frames", "7"], |o| o.stream_frames == 7),
        (&["--frames", "0"], |o| o.stream_frames == 1),
        (&["--duration", "2.5"], |o| o.duration_sec == Some(2.5)),
        (&["--no-extras"], |o| !o.control_extras),
        (&[], |o| o.control_extras),
        (&["--audio-only"], |o| o.audio_only),
        (&["--test-signal-mode", "both"], |o| {
            o.test_signal_mode == "both"
        }),
        (&["--camera-backend", "diagnostic"], |o| {
            o.camera_backend == crate::config::VideoBackend::Diagnostic
        }),
        (&["--audio-backend", "diagnostic"], |o| {
            o.audio_backend == crate::config::AudioBackend::Diagnostic
        }),
    ];
    for (flags, holds) in cases {
        let options = mapped_options(flags).unwrap();
        assert!(holds(&options), "{flags:?}: {options:?}");
        assert_eq!(options.peer_mode, "listen");
    }
}

/// Transmit/receive audio/video, in that order: no stream flag enables all
/// four, and naming any stream enables only the named ones.
#[test]
fn stream_direction_flags_select_only_the_named_streams() {
    const ALL: [bool; 4] = [true; 4];
    let cases: [(&[&str], [bool; 4]); 8] = [
        (&[], ALL),
        (&["--receive-only"], [false, true, false, true]),
        (&["--rx"], [false, true, false, true]),
        (&["--audio-only"], [true, true, false, false]),
        (&["--tx-audio"], [true, false, false, false]),
        (&["--rx-audio"], [false, true, false, false]),
        (&["--tx-video"], [false, false, true, false]),
        (&["--rx-video", "--tx-audio"], [true, false, false, true]),
    ];
    for (flags, expected) in cases {
        let o = mapped_options(flags).unwrap();
        let streams = [
            o.stream_tx_audio,
            o.stream_rx_audio,
            o.stream_tx_video,
            o.stream_rx_video,
        ];
        assert_eq!(streams, expected, "{flags:?}");
    }
}

#[test]
fn contradictory_or_invalid_flags_are_refused_with_a_reason() {
    let cases: [(&[&str], &str); 5] = [
        (
            &["--receive-only", "--tx-audio"],
            "--receive-only cannot be combined",
        ),
        (
            &["--receive-only", "--tx-video"],
            "--receive-only cannot be combined",
        ),
        (
            &["--audio-only", "--tx-video"],
            "--audio-only cannot be combined",
        ),
        (
            &["--audio-only", "--rx-video"],
            "--audio-only cannot be combined",
        ),
        (&["--duration", "0"], "duration_sec"),
    ];
    for (flags, reason) in cases {
        let error = mapped_options(flags).unwrap_err();
        assert!(error.contains(reason), "{flags:?}: {error}");
    }
}

#[test]
fn control_dialect_flag_selects_a_dialect_or_names_the_bad_value() {
    for (name, expected) in [
        ("ascii", ControlDialect::Ascii),
        ("osc15", ControlDialect::Osc15),
        ("legacy", ControlDialect::Ascii),
    ] {
        let mut settings = default_settings();
        settings.network.control_dialect = ControlDialect::Osc15;
        apply_control_dialect(&mut settings, Some(name)).unwrap();
        assert_eq!(settings.network.control_dialect, expected, "{name}");
    }
    let mut settings = default_settings();
    apply_control_dialect(&mut settings, None).unwrap();
    assert_eq!(settings.network.control_dialect, ControlDialect::Ascii);
    let error = apply_control_dialect(&mut settings, Some("morse")).unwrap_err();
    assert!(error.contains("unknown control dialect `morse`"), "{error}");
}

#[test]
fn continuous_runs_need_a_finite_positive_duration() {
    for (duration, reason) in [
        (None, "--continuous requires --duration"),
        (Some(0.0), "greater than zero"),
        (Some(f64::NAN), "greater than zero"),
    ] {
        let options = SessionOptions::demo();
        let result = run_continuous(default_settings(), 1.0, duration, options);
        assert!(!result.ok && result.error.contains(reason), "{result:?}");
    }
}
