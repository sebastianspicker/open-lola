//! Integration tests driving the shipped rusty_lola library (not reimplemented here).

use rusty_lola::audio::{split_wav, write_pcm_fixture};
use rusty_lola::config::{
    default_settings, find_mode, load_camera_modes, load_ximea_colors, DEFAULT_AUDIO_PORT,
    DEFAULT_CONTROL_PORT, DEFAULT_VIDEO_PORT,
};
use rusty_lola::protocol::{
    decode_mesg, encode_check_status, encode_quickconn, parse_quickconn_fields, parse_video_frame,
    serialize_media_frame, KNOWN_MESSAGES,
};
use rusty_lola::station::{run_default_session, run_reject_session, run_session, SessionOptions};
use rusty_lola::video::{convert_path, demosaic_mono8, BayerPattern, ConvertMode};
use rusty_lola::{shipped_ximea_colors, shipped_ximea_ini, IDENTITY, VERSION};
use tempfile::tempdir;

#[test]
fn identity_constants() {
    assert_eq!(IDENTITY, "rusty-lola");
    assert!(!VERSION.is_empty());
}

#[test]
fn default_ports_match_closed() {
    assert_eq!(DEFAULT_CONTROL_PORT, 7000);
    assert_eq!(DEFAULT_AUDIO_PORT, 19788);
    assert_eq!(DEFAULT_VIDEO_PORT, 19798);
    let s = default_settings();
    assert_eq!(s.network.control_port, 7000);
    assert_eq!(s.network.audio_port, 19788);
    assert_eq!(s.network.video_port, 19798);
}

#[test]
fn mesg_production_roundtrip_and_known_set() {
    assert!(KNOWN_MESSAGES.contains(&"/MESG_CHECKLOLASTATUS"));
    assert!(KNOWN_MESSAGES.contains(&"/MESG_QUICKCONN"));
    assert!(KNOWN_MESSAGES.contains(&"/MESG_ACCEPT"));
    let s = encode_check_status("127.0.0.1", "10.0.0.2", 1).unwrap();
    let prefix = "/MESG_CHECKLOLASTATUS;SRCIP:127.0.0.1;DSTIP:10.0.0.2;SID:1;";
    assert_eq!(s.len(), 1024);
    assert!(s.starts_with(prefix));
    assert!(s.as_bytes()[prefix.len()..].iter().all(|byte| *byte == 0));
    let m = decode_mesg(s.as_bytes()).unwrap();
    assert_eq!(m.name, "/MESG_CHECKLOLASTATUS");

    let qc = encode_quickconn(
        "1.1.1.1", "2.2.2.2", 1, 48000, 16, 2, 60, 8, 1280, 720, 1, 1,
    )
    .unwrap();
    let m = decode_mesg(qc).unwrap();
    let caps = parse_quickconn_fields(&m).unwrap();
    assert_eq!(caps["COMP"], 1);
    assert_eq!(caps["X"], 1280);
}

#[test]
fn real_ximea_catalog_mode_009() {
    let path = shipped_ximea_ini();
    assert!(path.is_file(), "missing {}", path.display());
    let modes = load_camera_modes(&path).unwrap();
    let m = find_mode(&modes, "009").expect("009");
    assert_eq!(m.width, 1280);
    assert_eq!(m.height, 720);
    assert_eq!(m.pixel_format, "Mono8");
}

#[test]
fn real_ximea_colors() {
    let c = load_ximea_colors(shipped_ximea_colors()).unwrap();
    assert_eq!(c.red_gain, 68);
    assert_eq!(c.blue_gain, 130);
}

#[test]
fn olav_media_roundtrip() {
    let px = vec![7u8; 64];
    let packed = serialize_media_frame(9, &px);
    let frame = parse_video_frame(&packed, false).unwrap();
    assert_eq!(frame.sequence, 9);
    assert_eq!(frame.payload, px);
    assert!(!frame.compressed);
}

#[test]
fn station_loopback_e2e() {
    let r = run_default_session(4.0, 3, false, true);
    assert!(r.ok, "err={}", r.error);
    assert!(r.states.iter().any(|s| s == "STREAMING"));
    assert!(r.video_frames_sent >= 3);
    assert!(r.video_frames_received >= 3);
    assert!(r.audio_frames_received >= 3);
    assert_eq!(r.camera_mode_id, "009");
    assert_eq!(r.media_transport, "udp");
    assert!(
        r.messages_sent.iter().any(|m| m == "/MESG_DISCONNECT"),
        "DISCONNECT must be sent; got {:?}",
        r.messages_sent
    );
    assert!(
        r.messages_sent.iter().any(|m| m == "/MESG_CHECKLOLASTATUS")
            && r.messages_sent.iter().any(|m| m == "/MESG_QUICKCONN")
    );
}

#[test]
fn station_jpeg_and_reject() {
    let jpeg = run_default_session(4.0, 2, true, true);
    assert!(jpeg.ok, "jpeg err={}", jpeg.error);
    assert!(jpeg.compression_used);
    assert!(jpeg.jpeg_decoded_ok);

    let rej = run_reject_session(default_settings(), 3.0);
    assert!(rej.ok, "reject err={}", rej.error);
    assert!(rej.rejected);
}

#[test]
fn station_with_record_and_preview() {
    let dir = tempdir().unwrap();
    let rec = dir.path().join("rec");
    let prev = dir.path().join("prev");
    let mut opts = SessionOptions::demo();
    opts.stream_frames = 2;
    opts.control_extras = false;
    opts.record = true;
    opts.record_dir = Some(rec.clone());
    opts.preview_dir = Some(prev.clone());
    let r = run_session(default_settings(), 4.0, opts);
    assert!(r.ok, "err={}", r.error);
    assert!(!r.record_paths.is_empty());
    assert!(!r.preview_paths.is_empty());
}

#[test]
fn wavsplit_track_naming() {
    let dir = tempdir().unwrap();
    let src = dir.path().join("session.wav");
    write_pcm_fixture(&src, 3, 48000, 0.02, 2).unwrap();
    let out = split_wav(&src, Some(dir.path())).unwrap();
    assert_eq!(out.len(), 3);
    assert!(out[0]
        .file_name()
        .unwrap()
        .to_str()
        .unwrap()
        .ends_with("session_Track_1.wav"));
}

#[test]
fn convert_debayer_writes_output() {
    let dir = tempdir().unwrap();
    let src = dir.path().join("frame.png");
    // 8x8 gray PNG via image crate
    let img = image::GrayImage::from_fn(8, 8, |x, y| image::Luma([((x + y) % 256) as u8]));
    img.save(&src).unwrap();
    let out_dir = dir.path().join("out");
    let written =
        convert_path(&src, &out_dir, ConvertMode::Debayer, BayerPattern::Bggr, 80).unwrap();
    assert_eq!(written.len(), 1);
    assert!(written[0].is_file());
    let rgb = demosaic_mono8(img.as_raw(), 8, 8, BayerPattern::Bggr).unwrap();
    assert_eq!(rgb.len(), 8 * 8 * 3);
}

#[test]
fn cli_identity_and_station_exit_codes() {
    let code = rusty_lola::cli::run(Some(vec!["rusty-lola".into(), "identity".into()]));
    assert_eq!(code, 0);

    let code = rusty_lola::cli::run(Some(vec![
        "rusty-lola".into(),
        "station".into(),
        "--timeout".into(),
        "4".into(),
        "--frames".into(),
        "2".into(),
        "--no-extras".into(),
        "--camera-backend".into(),
        "diagnostic".into(),
        "--audio-backend".into(),
        "diagnostic".into(),
    ]));
    assert_eq!(code, 0, "station CLI should succeed");
}
