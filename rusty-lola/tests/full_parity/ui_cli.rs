use super::*;

#[test]
fn ui_controller_headless_check_connect() {
    let mut c = diagnostic_controller();
    let report = c.run_headless(true, true, 5.0, 2);
    assert_eq!(report["ok"], true, "{report}");
    assert_eq!(report["check"]["ok"], true);
    assert_eq!(report["connect"]["ok"], true);
    c.send_chat("pre-connect-chat");
    assert!(c
        .get_state()
        .last_chat
        .iter()
        .any(|m| m == "pre-connect-chat"));
    c.select_tab(1).unwrap();
    c.set_record_enabled(true, Some("rec"));
    let d = c.disconnect();
    assert_eq!(d["ok"], true);
}

#[test]
fn tab_led_state_machine() {
    let mut board = SessionTabBoard::new();
    assert_eq!(board.led(1).unwrap().as_str(), "yellow");
    board.set_connected(1, true).unwrap();
    assert_eq!(board.led(1).unwrap().as_str(), "green");
    board.set_enabled(2, true).unwrap();
    assert_eq!(board.led(2).unwrap().as_str(), "yellow");
}

#[test]
fn network_monitor_fields() {
    let mut m = NetworkMonitor::new();
    m.note_send(MediaKind::Video);
    m.note_recv(MediaKind::Video, Some(1));
    m.note_rtt(5.0);
    let r = m.to_report();
    assert!(r.get("video_fps").is_some());
    assert!(r.get("jitter_class").is_some());
    assert_eq!(r["rtt_ms"], 5.0);
}

#[test]
fn color_apply_shipped_api() {
    let px = vec![64u8; 4];
    let out = apply_color_gains(&px, 2, 2, "Mono8", None, None, Some(128), None, 64).unwrap();
    assert_eq!(out, vec![128, 128, 128, 128]);
}

#[test]
fn cli_identity_and_session_profile() {
    let code = cli_run(Some(vec!["rusty-lola".into(), "identity".into()]));
    assert_eq!(code, 0);

    let dir = tempdir().unwrap();
    let out = dir.path().join("p.json");
    let code = cli_run(Some(vec![
        "rusty-lola".into(),
        "session-profile".into(),
        "--out".into(),
        out.display().to_string(),
        "--remote".into(),
        "127.0.0.1".into(),
        "--mode".into(),
        "009".into(),
    ]));
    assert_eq!(code, 0);
    assert!(out.is_file());
    let text = fs::read_to_string(&out).unwrap();
    assert!(text.contains("127.0.0.1"));
    assert!(text.contains("009"));
}

#[test]
fn cli_station_reject_multi_sid() {
    let code = cli_run(Some(vec![
        "rusty-lola".into(),
        "station".into(),
        "--timeout".into(),
        "5".into(),
        "--frames".into(),
        "2".into(),
        "--no-extras".into(),
        "--camera-backend".into(),
        "diagnostic".into(),
        "--audio-backend".into(),
        "diagnostic".into(),
    ]));
    assert_eq!(code, 0);

    let code = cli_run(Some(vec![
        "rusty-lola".into(),
        "station".into(),
        "--reject".into(),
        "--timeout".into(),
        "3".into(),
    ]));
    assert_eq!(code, 0);

    let code = cli_run(Some(vec![
        "rusty-lola".into(),
        "multi-sid".into(),
        "--sids".into(),
        "1,2".into(),
        "--frames".into(),
        "2".into(),
        "--timeout".into(),
        "6".into(),
    ]));
    assert_eq!(code, 0);
}

#[test]
fn cli_ui_headless() {
    let code = cli_run(Some(vec![
        "rusty-lola".into(),
        "ui".into(),
        "--headless".into(),
        "--run-check".into(),
        "--run-connect".into(),
        "--timeout".into(),
        "5".into(),
        "--frames".into(),
        "2".into(),
        "--camera-backend".into(),
        "diagnostic".into(),
        "--audio-backend".into(),
        "diagnostic".into(),
    ]));
    assert_eq!(code, 0);
}

#[test]
fn cli_emulate_list_and_run() {
    let code = cli_run(Some(vec![
        "rusty-lola".into(),
        "emulate".into(),
        "--list-modes".into(),
    ]));
    assert_eq!(code, 0);

    let code = cli_run(Some(vec![
        "rusty-lola".into(),
        "emulate".into(),
        "--mode".into(),
        "E03".into(),
        "--frames".into(),
        "2".into(),
        "--timeout".into(),
        "5".into(),
    ]));
    assert_eq!(code, 0);
}

#[test]
fn cli_convert_wavsplit() {
    let dir = tempdir().unwrap();
    let mono = dir.path().join("in");
    fs::create_dir_all(&mono).unwrap();
    // Write a real Mono8 PNG so convert CLI has a valid image input
    {
        use image::{GrayImage, Luma};
        let mut img = GrayImage::new(8, 8);
        for (x, y, p) in img.enumerate_pixels_mut() {
            *p = Luma([((x * 3 + y * 5) % 256) as u8]);
        }
        img.save(mono.join("frame.png")).unwrap();
    }
    use rusty_lola::video::{convert_path, BayerPattern, ConvertMode};
    let out = dir.path().join("out");
    // Drive convert via shipped API first — must produce real output files
    let written = convert_path(&mono, &out, ConvertMode::Debayer, BayerPattern::Bggr, 80)
        .expect("convert_path must succeed on Mono8 PNG");
    assert!(!written.is_empty());
    for p in &written {
        assert!(p.is_file(), "missing convert output {}", p.display());
        assert!(fs::metadata(p).unwrap().len() > 0);
    }

    // CLI path must also succeed and write files
    let out2 = dir.path().join("out_cli");
    let code = cli_run(Some(vec![
        "rusty-lola".into(),
        "convert".into(),
        "--mode".into(),
        "debayer".into(),
        "--in".into(),
        mono.display().to_string(),
        "--out".into(),
        out2.display().to_string(),
        "--pattern".into(),
        "BGGR".into(),
    ]));
    assert_eq!(code, 0, "convert CLI must exit 0 on valid PNG input");
    let cli_outs: Vec<_> = fs::read_dir(&out2)
        .unwrap()
        .filter_map(|e| e.ok())
        .map(|e| e.path())
        .filter(|p| p.is_file())
        .collect();
    assert!(!cli_outs.is_empty(), "convert CLI wrote no files");

    // bmp2jpeg via library + CLI
    let bmp_dir = dir.path().join("bmp_in");
    fs::create_dir_all(&bmp_dir).unwrap();
    {
        use image::{Rgb, RgbImage};
        let mut img = RgbImage::new(4, 4);
        for p in img.pixels_mut() {
            *p = Rgb([200, 100, 50]);
        }
        img.save(bmp_dir.join("frame.bmp")).unwrap();
    }
    let jpg_out = dir.path().join("jpg_out");
    let code = cli_run(Some(vec![
        "rusty-lola".into(),
        "convert".into(),
        "--mode".into(),
        "bmp2jpeg".into(),
        "--in".into(),
        bmp_dir.display().to_string(),
        "--out".into(),
        jpg_out.display().to_string(),
        "--quality".into(),
        "80".into(),
    ]));
    assert_eq!(code, 0, "bmp2jpeg CLI must exit 0");
    assert!(
        fs::read_dir(&jpg_out)
            .unwrap()
            .filter_map(|e| e.ok())
            .any(|e| e.path().extension().and_then(|x| x.to_str()) == Some("jpg")),
        "bmp2jpeg must write .jpg"
    );

    // wavsplit CLI path fully
    let wav = dir.path().join("session.wav");
    write_pcm_fixture(&wav, 2, 48000, 0.02, 2).unwrap();
    let code = cli_run(Some(vec![
        "rusty-lola".into(),
        "wavsplit".into(),
        "--in".into(),
        wav.display().to_string(),
        "--out-dir".into(),
        dir.path().display().to_string(),
    ]));
    assert_eq!(code, 0);
    let tracks: Vec<_> = fs::read_dir(dir.path())
        .unwrap()
        .filter_map(|e| e.ok())
        .map(|e| e.file_name().to_string_lossy().into_owned())
        .filter(|n| n.contains("Track_"))
        .collect();
    assert!(!tracks.is_empty(), "tracks={tracks:?}");
}

#[test]
fn controller_start_test_signals_drives_media() {
    let mut c = diagnostic_controller();
    let out = c.start_test_signals(true);
    assert_eq!(out["ok"], true, "{out}");
    assert_eq!(out["test_signal_active"], true);
    assert_eq!(out["applies_to"], "next_session");
    let live = c.start_live(5.0, 2, false, true);
    assert!(
        c.live_running() || live.get("ok").and_then(|v| v.as_bool()).unwrap_or(false),
        "live={live}"
    );
    wait_for_live_streaming(&c);
    thread::sleep(Duration::from_millis(1500));
    let stop = c.stop_live(8.0);
    assert!(!c.live_running());
    assert_eq!(stop["test_signal_applied"], true, "stop={stop}");
    assert_eq!(stop["test_signal_mode"], "send");
    c.stop_test_signals();
    assert!(!c.get_state().test_signal_active);
}

#[test]
fn ui_controller_live_and_productivity() {
    let mut c = diagnostic_controller();
    let mbps = c.estimate_bandwidth();
    assert!(mbps > 0.0);
    c.set_tx_audio_level(2);
    assert_eq!(c.get_state().tx_audio_level, 2);
    assert_eq!(c.set_local_camera(2), 2);
    let geom = c.layout_windows("max_remote");
    assert_eq!(geom["mode"], "max_remote");
    let _ = c.set_stream_toggle("rx", "audio", false);
    assert_eq!(c.get_state().stream_toggles.get("rx_audio"), Some(&false));

    let start = c.start_live(5.0, 2, false, true);
    assert!(
        c.live_running()
            || start
                .get("status")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .contains("stream")
            || start.get("ok").and_then(|v| v.as_bool()).unwrap_or(false),
        "start={start}"
    );
    wait_for_live_streaming(&c);
    thread::sleep(Duration::from_millis(900));
    let stop = c.stop_live(8.0);
    assert!(!c.live_running());
    let vf = stop
        .get("video_frames_sent")
        .and_then(|v| v.as_u64())
        .unwrap_or(0);
    assert!(
        vf >= 2 || stop.get("ok").and_then(|v| v.as_bool()).unwrap_or(false),
        "stop={stop}"
    );
}
