use super::*;

#[test]
fn identity_and_ports() {
    assert_eq!(IDENTITY, "rusty-lola");
    assert!(!VERSION.is_empty());
    assert_eq!(DEFAULT_CONTROL_PORT, 7000);
    assert_eq!(DEFAULT_AUDIO_PORT, 19788);
    assert_eq!(DEFAULT_VIDEO_PORT, 19798);
}

#[test]
fn station_loopback_monitor_color_bayer() {
    let mut settings = default_settings();
    settings.video.bayer = 1;
    settings.video.bpp = 8;
    let mut opts = SessionOptions::demo();
    opts.stream_frames = 3;
    opts.control_extras = true;
    opts.apply_color = true;
    opts.auto_bayer = true;
    let r = run_session(settings, 5.0, opts);
    assert!(r.ok, "err={}", r.error);
    assert!(r.states.iter().any(|s| s == "STREAMING"));
    assert!(r.video_frames_received >= 3);
    assert!(r.audio_frames_received >= 3);
    assert!(r.messages_sent.iter().any(|m| m == "/MESG_DISCONNECT"));
    assert!(!r.network_monitor.is_empty());
    assert!(r.network_monitor.get("video_sent").copied().unwrap_or(0) >= 3);
    assert!(r.bayer_applied);
    assert!(r.color_applied);
    assert_eq!(r.peer_mode, "loopback");
}

#[test]
fn station_reject_and_jpeg() {
    let jpeg = run_default_session(4.0, 2, true, true);
    assert!(jpeg.ok, "{}", jpeg.error);
    assert!(jpeg.compression_used);
    assert!(jpeg.jpeg_decoded_ok);

    let rej = run_reject_session(default_settings(), 3.0);
    assert!(rej.ok, "{}", rej.error);
    assert!(rej.rejected);
}

#[test]
fn dual_record_paths() {
    let dir = tempdir().unwrap();
    let rec = dir.path().join("rec");
    let mut opts = SessionOptions::demo();
    opts.stream_frames = 2;
    opts.control_extras = false;
    opts.record = true;
    opts.record_dir = Some(rec.clone());
    opts.preview_dir = Some(dir.path().join("prev"));
    let r = run_session(default_settings(), 5.0, opts);
    assert!(r.ok, "{}", r.error);
    assert!(!r.record_paths.is_empty());
    assert!(r
        .record_paths
        .iter()
        .any(|p| p.contains("_Local") || p.contains("local")));
    assert!(!r.preview_paths.is_empty());
}

#[test]
fn multi_sid_sequential_and_concurrent() {
    let seq = run_multi_sid(&[1, 2], "127.0.0.1", 5.0, 2, false).unwrap();
    assert!(seq.ok, "seq err={}", seq.error);
    assert_eq!(seq.session_ids, vec![1, 2]);
    assert!(seq.results.iter().all(|r| r.ok));

    let conc = run_multi_sid(&[1, 2], "127.0.0.1", 8.0, 2, true).unwrap();
    assert!(conc.ok, "conc err={}", conc.error);
    assert_eq!(conc.results.len(), 2);
}

#[test]
fn session_profile_roundtrip() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("prof.json");
    let p = SessionProfile {
        remote_ip: "10.1.2.3".into(),
        camera_mode_id: "009".into(),
        session_id: 2,
        ..SessionProfile::default()
    };
    save_session_profile(&path, &p).unwrap();
    let loaded = load_session_profile(&path).unwrap();
    assert_eq!(loaded.remote_ip, "10.1.2.3");
    assert_eq!(loaded.session_id, 2);
}

#[test]
fn emulation_modes_e01_e08() {
    let modes = list_emulation_modes();
    assert_eq!(modes.len(), 8);
    let r = run_emulation(Some("E01"), 4.0, 2, false).unwrap();
    assert!(r.ok, "E01 err={}", r.error);
}

#[test]
fn reachability_localhost() {
    let r = check_reachable("127.0.0.1", 800, 1);
    assert!(r.ok, "reason={}", r.reason);
}

#[test]
fn sid_profiles_create() {
    let p = create_sid_profiles(&[1, 2, 3], "127.0.0.1", "127.0.0.1", "009").unwrap();
    assert_eq!(p.len(), 3);
    let r = run_sequential_sessions(&p[..2], 5.0, None).unwrap();
    assert!(r.ok, "{}", r.error);
}

#[test]
fn live_continuous_accumulates_and_clean_stop() {
    let mut settings = default_settings();
    settings.audio.backend = AudioBackend::Diagnostic;
    settings.video.backend = VideoBackend::Diagnostic;
    settings.video.width = 64;
    settings.video.height = 48;
    settings.video.camera_mode_id = "diagnostic-64x48".into();
    let svc = LiveStationService::new(Some(settings));
    assert!(!svc.is_running());
    svc.start(5.0, 2, false, true, None).unwrap();
    let deadline = std::time::Instant::now() + Duration::from_secs(8);
    while svc.get_report()["status"] != "streaming" && std::time::Instant::now() < deadline {
        thread::sleep(Duration::from_millis(20));
    }
    thread::sleep(Duration::from_millis(1200));
    let report = svc.stop(8.0);
    assert_eq!(report["ok"], true, "{report}");
    let vf = report
        .get("video_frames_sent")
        .and_then(|v| v.as_u64())
        .unwrap_or(0);
    assert!(vf >= 2, "video_frames_sent={vf} report={report}");
    assert!(!svc.is_running(), "must not remain running after stop");
    // Restart must work (no permanent already-running hang)
    svc.start(5.0, 2, false, true, None).unwrap();
    let deadline = std::time::Instant::now() + Duration::from_secs(8);
    while svc.get_report()["status"] != "streaming" && std::time::Instant::now() < deadline {
        thread::sleep(Duration::from_millis(20));
    }
    thread::sleep(Duration::from_millis(800));
    let r2 = svc.stop(8.0);
    assert_eq!(r2["ok"], true, "{r2}");
    assert!(!svc.is_running());
}

#[test]
fn av_productivity_helpers_shipped() {
    let full = estimate_tx_bandwidth_mbps(1280, 720, 60.0, 8, false, 60);
    assert!((full - 442.368).abs() < 0.01, "full={full}");
    let jpg = estimate_tx_bandwidth_mbps(1280, 720, 30.0, 24, true, 60);
    let raw = estimate_tx_bandwidth_mbps(1280, 720, 30.0, 24, false, 60);
    assert!(jpg < raw && jpg > 0.0);

    let pcm = 1000i16.to_le_bytes();
    let out = apply_tx_audio_level(&pcm, 2.0, 16);
    assert_eq!(i16::from_le_bytes([out[0], out[1]]), 2000);
    assert!(audio_params_match(48000, 2, 16, 48000, 2, 16));
    assert!(!audio_params_match(44100, 2, 16, 48000, 2, 16));
    assert!(incomplete_frame_ok(9, 10, 10.0));
    assert!(!incomplete_frame_ok(9, 10, 0.0));

    let data: Vec<u8> = (0..32).map(|i| i as u8).collect();
    let scaled = centered_crop_or_scale(&data, 8, 4, 4, 4, "Mono8").unwrap();
    assert_eq!(scaled.len(), 16);

    let geom = layout_geometry("tile_v", 1920, 1080);
    assert_eq!(geom["mode"], "tile_v");
    assert_eq!(geom["local"]["h"], 540);
    assert_eq!(multi_camera_index(5, 4), 3);
    let prio = set_process_priority("normal");
    assert!(!prio.is_empty());
}

#[test]
fn test_signal_mode_smpte_and_tone_on_stream_path() {
    // Drive shipped run_session with test_signal_mode=send — must apply real SMPTE+tone.
    let mut opts = SessionOptions::demo();
    opts.stream_frames = 2;
    opts.control_extras = false;
    opts.apply_color = false;
    opts.auto_bayer = false;
    opts.test_signal_mode = "send".into();
    let r = run_session(default_settings(), 5.0, opts);
    assert!(r.ok, "err={}", r.error);
    assert!(
        r.test_signal_applied,
        "test signal must mark applied on stream path"
    );
    assert_eq!(r.test_signal_mode, "send");
    assert!(r.video_frames_sent >= 2);
    assert!(r.audio_frames_sent >= 2);
    assert_eq!(r.audio_signal_active, Some(true));

    // SMPTE generator itself produces structured bars (not flat software noise)
    let bars = rusty_lola::video::generate_smpte_bars(64, 32, false).unwrap();
    assert_eq!(bars.len(), 64 * 32 * 3);
    assert_eq!(&bars[0..3], &[180, 180, 180]);

    // Tone energy at −12 dBFS class
    let pcm = rusty_lola::audio::generate_pcm_tone(
        1,
        48000,
        16,
        480,
        rusty_lola::audio::TEST_TONE_HZ_PRIMARY,
        rusty_lola::audio::TEST_TONE_AMPLITUDE,
        0,
    );
    let mut peak = 0i16;
    for i in 0..480 {
        let s = i16::from_le_bytes([pcm[i * 2], pcm[i * 2 + 1]]);
        peak = peak.max(s.abs());
    }
    assert!(peak > 7000 && peak < 10000, "peak={peak}");
}
