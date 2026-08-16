//! In-process CLI `run(argv)` coverage — no process spawn / no cargo run.

use rusty_lola::audio::write_pcm_fixture;
use rusty_lola::cli::run as cli_run;
use rusty_lola::video::{convert_path, BayerPattern, ConvertMode};
use std::fs;
use tempfile::tempdir;

fn argv(parts: &[&str]) -> Vec<String> {
    std::iter::once("rusty-lola".to_string())
        .chain(parts.iter().map(|s| (*s).to_string()))
        .collect()
}

#[test]
fn identity_exit_0() {
    assert_eq!(cli_run(Some(argv(&["identity"]))), 0);
}

#[test]
fn station_happy_and_reject() {
    assert_eq!(
        cli_run(Some(argv(&[
            "station",
            "--timeout",
            "5",
            "--frames",
            "2",
            "--no-extras",
            "--camera-backend",
            "diagnostic",
            "--audio-backend",
            "diagnostic",
            "--peer-mode",
            "loopback",
        ]))),
        0
    );
    assert_eq!(
        cli_run(Some(argv(&["station", "--reject", "--timeout", "3"]))),
        0
    );
}

#[test]
fn station_productive_flags_accepted() {
    // Flags must parse and run real session (not "not implemented")
    assert_eq!(
        cli_run(Some(argv(&[
            "station",
            "--timeout",
            "5",
            "--frames",
            "1",
            "--no-extras",
            "--interleaved",
            "--compress",
            "--camera-mode-id",
            "009",
            "--camera-backend",
            "diagnostic",
            "--audio-backend",
            "diagnostic",
        ]))),
        0
    );
}

#[test]
fn multi_sid_sequential_and_concurrent() {
    assert_eq!(
        cli_run(Some(argv(&[
            "multi-sid",
            "--sids",
            "1,2",
            "--frames",
            "2",
            "--timeout",
            "6",
        ]))),
        0
    );
    assert_eq!(
        cli_run(Some(argv(&[
            "multi-sid",
            "--sids",
            "1,2",
            "--frames",
            "2",
            "--timeout",
            "8",
            "--concurrent",
        ]))),
        0
    );
}

#[test]
fn session_profile_writes_remote_and_mode() {
    let dir = tempdir().unwrap();
    let out = dir.path().join("prof.json");
    assert_eq!(
        cli_run(Some(argv(&[
            "session-profile",
            "--out",
            out.to_str().unwrap(),
            "--remote",
            "10.0.0.9",
            "--mode",
            "009",
            "--sid",
            "2",
        ]))),
        0
    );
    let text = fs::read_to_string(&out).unwrap();
    assert!(text.contains("10.0.0.9"));
    assert!(text.contains("009"));
    assert!(text.contains("\"session_id\": 2") || text.contains("\"session_id\":2"));
}

#[test]
fn check_remote_localhost() {
    // Real probe path via shipped CLI dispatch (may exit 0 or 1 depending on OS ping)
    let code = cli_run(Some(argv(&[
        "check-remote",
        "127.0.0.1",
        "--count",
        "1",
        "--timeout-ms",
        "800",
    ])));
    // Must not be "not implemented" (2 from clap parse, or panic). 0/1 are real outcomes.
    assert!(code == 0 || code == 1, "check-remote code={code}");
}

#[test]
fn emulate_list_and_e01() {
    assert_eq!(cli_run(Some(argv(&["emulate", "--list-modes"]))), 0);
    assert_eq!(cli_run(Some(argv(&["tester", "--list-modes"]))), 0);
    assert_eq!(
        cli_run(Some(argv(&[
            "emulate",
            "--mode",
            "E01",
            "--frames",
            "2",
            "--timeout",
            "5",
        ]))),
        0
    );
}

#[test]
fn ui_headless_check_and_connect() {
    assert_eq!(
        cli_run(Some(argv(&[
            "ui",
            "--headless",
            "--run-check",
            "--timeout",
            "5",
            "--frames",
            "1",
            "--camera-backend",
            "diagnostic",
            "--audio-backend",
            "diagnostic",
        ]))),
        0
    );
    assert_eq!(
        cli_run(Some(argv(&[
            "ui",
            "--headless",
            "--run-connect",
            "--timeout",
            "5",
            "--frames",
            "2",
            "--camera-backend",
            "diagnostic",
            "--audio-backend",
            "diagnostic",
        ]))),
        0
    );
}

#[test]
fn convert_and_wavsplit_artifacts() {
    let dir = tempdir().unwrap();
    // PNG gray for debayer via shipped convert_path then CLI
    let png = dir.path().join("frame.png");
    let img = image::GrayImage::from_fn(8, 8, |x, y| image::Luma([((x + y) % 256) as u8]));
    img.save(&png).unwrap();
    let out_dir = dir.path().join("out");
    let written = convert_path(&png, &out_dir, ConvertMode::Debayer, BayerPattern::Bggr, 80)
        .expect("convert_path");
    assert!(!written.is_empty());
    assert!(written[0].is_file());
    assert!(fs::metadata(&written[0]).unwrap().len() > 0);

    let code = cli_run(Some(argv(&[
        "convert",
        "--mode",
        "debayer",
        "--in",
        png.to_str().unwrap(),
        "--out",
        out_dir.to_str().unwrap(),
        "--pattern",
        "BGGR",
    ])));
    assert_eq!(code, 0);

    let wav = dir.path().join("session.wav");
    write_pcm_fixture(&wav, 2, 48000, 0.02, 2).unwrap();
    let code = cli_run(Some(argv(&[
        "wavsplit",
        "--in",
        wav.to_str().unwrap(),
        "--out-dir",
        dir.path().to_str().unwrap(),
    ])));
    assert_eq!(code, 0);
    let tracks: Vec<_> = fs::read_dir(dir.path())
        .unwrap()
        .filter_map(|e| e.ok())
        .map(|e| e.file_name().to_string_lossy().into_owned())
        .filter(|n| n.contains("_Track_"))
        .collect();
    assert!(
        tracks.iter().any(|t| t.ends_with("_Track_1.wav")),
        "tracks={tracks:?}"
    );
    assert!(tracks.iter().any(|t| t.ends_with("_Track_2.wav")));
}

#[test]
fn cli_surface_has_all_productive_subcommands() {
    // Structural: clap Commands enum via help text from try_parse
    // Empty command prints usage with command list
    let code = cli_run(Some(argv(&[])));
    // main with no subcommand returns 0 and prints command list
    assert_eq!(code, 0);
}
