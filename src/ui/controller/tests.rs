use super::*;
use crate::config::{default_settings, AudioBackend, VideoBackend};
use crate::net::Udp;
use std::thread;
use std::time::Duration;

fn diagnostic_controller() -> StationUIController {
    let mut settings = default_settings();
    let mut ports = Vec::with_capacity(3);
    while ports.len() < 3 {
        let port = Udp::free_port("127.0.0.1").unwrap();
        if !ports.contains(&port) {
            ports.push(port);
        }
    }
    settings.network.control_port = ports[0];
    settings.network.audio_port = ports[1];
    settings.network.video_port = ports[2];
    settings.audio.backend = AudioBackend::Diagnostic;
    settings.video.backend = VideoBackend::Diagnostic;
    settings.video.width = 64;
    settings.video.height = 48;
    settings.video.camera_mode_id = "diagnostic-64x48".into();
    let mut controller = StationUIController::new(Some(settings));
    controller
        .set_peer_mode("loopback")
        .expect("diagnostic tests select loopback explicitly");
    controller
}

fn wait_for_live_streaming(controller: &StationUIController) {
    let deadline = std::time::Instant::now() + Duration::from_secs(8);
    while std::time::Instant::now() < deadline {
        if controller.live_report()["status"] == "streaming" {
            return;
        }
        thread::sleep(Duration::from_millis(20));
    }
    panic!(
        "live runtime did not reach streaming: {}",
        controller.live_report()
    );
}

#[test]
fn check_and_connect_loopback() {
    let mut c = diagnostic_controller();
    c.set_remote_ip("127.0.0.1");
    let check = c.check_status(4.0);
    assert_eq!(check["ok"], true, "check={check}");
    let conn = c.connect(4.0, 2, false);
    assert_eq!(conn["ok"], true, "connect={conn}");
    assert_eq!(c.get_state().status, "connected");
    let d = c.disconnect();
    assert_eq!(d["ok"], true);
}

#[test]
fn gui_session_options_normalize_explicit_peer_modes() {
    let mut c = diagnostic_controller();
    for mode in ["remote", "listen", "loopback"] {
        c.set_peer_mode(mode).unwrap();
        let options = c.session_options(1, false, false).unwrap();
        assert_eq!(options.peer_mode, mode);
    }
    assert!(c.set_peer_mode("demo").is_err());
    c.state_mut().peer_mode = "unexpected".into();
    assert!(c.session_options(1, false, false).is_err());
}

#[test]
fn gui_check_returns_immediately_without_claiming_streaming_readiness() {
    let mut c = diagnostic_controller();
    c.set_peer_mode("remote").unwrap();
    let started = std::time::Instant::now();
    let report = c.start_check(5.0);
    assert!(
        started.elapsed() < Duration::from_millis(250),
        "check blocked for {:?}",
        started.elapsed()
    );
    assert_eq!(report["pending"], true);
    assert_eq!(report["check_kind"], "control_handshake_only");
    assert_eq!(report["quickconn"], "not_started");
    assert_eq!(report["media"], "not_started");
    assert_eq!(report["native_backends"], "not_started");
    assert_eq!(report["production_ready"], false);
}

#[test]
fn gui_connect_and_listen_commands_return_without_running_on_the_ui_thread() {
    let mut c = diagnostic_controller();
    c.set_peer_mode("loopback").unwrap();
    let started = std::time::Instant::now();
    let _ = c.start_connect(5.0, 1, false, true);
    assert!(
        started.elapsed() < Duration::from_millis(250),
        "connect blocked for {:?}",
        started.elapsed()
    );
    let _ = c.request_stop_live();
    let _ = c.stop_live(8.0);

    let started = std::time::Instant::now();
    let _ = c.start_listen(5.0, false);
    assert!(
        started.elapsed() < Duration::from_millis(250),
        "listen blocked for {:?}",
        started.elapsed()
    );
    let _ = c.request_stop_live();
    let _ = c.stop_live(8.0);
}

#[test]
fn chat_pre_connect_and_tabs() {
    let mut c = diagnostic_controller();
    let r = c.send_chat("hello-ui");
    assert_eq!(r["ok"], true);
    assert!(c.get_state().last_chat.iter().any(|m| m == "hello-ui"));
    c.select_tab(2).unwrap();
    assert_eq!(c.get_state().session_id, 2);
    c.enable_tab(2, true).unwrap();
    assert_eq!(c.board().led(2).unwrap().as_str(), "yellow");
}

#[test]
fn headless_check_connect_json() {
    let mut c = diagnostic_controller();
    let r = c.run_headless(true, true, 4.0, 2);
    assert_eq!(r["ok"], true, "{r}");
    assert_eq!(r["check"]["ok"], true);
    assert_eq!(r["connect"]["ok"], true);
}

#[test]
fn live_continuous_start_stop() {
    let mut c = diagnostic_controller();
    let r = c.start_live(5.0, 2, false, true);
    assert!(
        c.live_running() || r.get("ok").and_then(|v| v.as_bool()).unwrap_or(false),
        "start={r}"
    );
    wait_for_live_streaming(&c);
    thread::sleep(Duration::from_millis(1000));
    let stop = c.stop_live(8.0);
    assert!(!c.live_running());
    let vf = stop
        .get("video_frames_sent")
        .and_then(|v| v.as_u64())
        .unwrap_or(0);
    assert!(
        stop.get("ok").and_then(|v| v.as_bool()).unwrap_or(false) || vf >= 2,
        "stop={stop}"
    );
    assert!(vf >= 2 || stop["ok"] == true, "vf={vf} stop={stop}");
}

#[test]
fn productivity_bandwidth_and_layout() {
    let mut c = diagnostic_controller();
    let mbps = c.estimate_bandwidth();
    assert!(mbps > 0.0);
    assert_eq!(c.get_state().estimated_tx_mbps, mbps);
    let geom = c.layout_windows("tile_h");
    assert_eq!(geom["mode"], "tile_h");
    c.set_tx_audio_level(2);
    assert_eq!(c.get_state().tx_audio_level, 2);
    assert_eq!(c.set_local_camera(9), 3);
    let _ = c.set_stream_toggle("tx", "video", false);
    assert_eq!(c.get_state().stream_toggles.get("tx_video"), Some(&false));
}

#[test]
fn start_test_signals_applies_real_media() {
    let mut c = diagnostic_controller();
    let out = c.start_test_signals(true);
    assert_eq!(out["ok"], true, "{out}");
    assert_eq!(out["applies_to"], "next_session");
    let _ = c.start_live(5.0, 2, false, true);
    wait_for_live_streaming(&c);
    thread::sleep(Duration::from_millis(1500));
    let media = c.stop_live(8.0);
    assert_eq!(media["test_signal_applied"], true, "{media}");
    assert_eq!(media["test_signal_mode"], "send");
    c.stop_test_signals();
    assert!(!c.get_state().test_signal_active);
}

#[test]
fn settings_load_save_roundtrip() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("station.json");
    let mut c = StationUIController::new(None);
    c.set_remote_ip("10.1.2.3");
    c.save_settings_file(&path).unwrap();
    let mut c2 = StationUIController::new(None);
    c2.load_settings_file(&path).unwrap();
    assert_eq!(c2.get_state().remote_ip, "10.1.2.3");
    assert_eq!(c2.get_state().status, "settings_loaded");
}

#[test]
fn persisted_settings_inventory_roundtrips_through_state_and_report() {
    let mut c = StationUIController::new(None);
    {
        let state = c.state_mut();
        state.input_device = "ASIO Input".into();
        state.output_device = "ASIO Output".into();
        state.sample_rate = 48_000;
        state.audio_channels = 2;
        state.bits_per_sample = 24;
        state.buffer_samples = 64;
        state.input_offset = 1;
        state.local_audio_loop = true;
        state.tx_audio_level = 2;
        state.video_width = 640;
        state.video_height = 480;
        state.video_fps = 30;
        state.video_bpp = 8;
        state.video_bayer = 2;
        state.local_camera_index = 1;
        state.compression = true;
        state.jpeg_quality = 75;
        state.audio_only = false;
        state.incomplete_frame_threshold_pct = 15.0;
        state.bind_ip = "0.0.0.0".into();
        state.local_ip = "127.0.0.1".into();
        state.remote_ip = "127.0.0.2".into();
        state.control_port = 7_001;
        state.audio_port = 19_789;
        state.video_port = 19_799;
        state.video_packet_size = 1_200;
        state.session_id = 42;
        state.raw_media_plane = true;
        state.pcap_device = "adapter-1".into();
        state.vlan_tag = Some(99);
        state.control_dialect = "osc15".into();
        state.audio_receive_queue_depth = 2;
        state.audio_receive_prefill = 1;
        state.video_receive_queue_depth = 2;
        state.video_receive_prefill = 1;
        state.record_enabled = true;
        state.record_path = "captures".into();
        state.record_local_audio = false;
        state.record_remote_audio = true;
        state.record_local_video = true;
        state.record_remote_video = false;
        state.record_mode = "video".into();
        state.record_video_format = "png".into();
    }
    c.set_settings_from_state();
    let settings = c.settings();
    assert_eq!(settings.audio.input_device, "ASIO Input");
    assert_eq!(settings.audio.bits_per_sample, 24);
    assert_eq!(settings.video.width, 640);
    assert_eq!(settings.video.bayer, 2);
    assert_eq!(settings.network.bind_ip, "0.0.0.0");
    assert_eq!(settings.network.vlan_tag, Some(99));
    assert_eq!(settings.recording.video_format, "png");
    let reloaded = StationUIController::new(Some(settings.clone()));
    assert_eq!(reloaded.get_state().input_device, "ASIO Input");
    assert_eq!(reloaded.get_state().video_width, 640);
    assert_eq!(reloaded.get_state().video_bayer, 2);
    assert_eq!(reloaded.get_state().vlan_tag, Some(99));
    assert_eq!(reloaded.get_state().record_video_format, "png");
    let report = reloaded.get_report();
    let state = &report["state"];
    assert_eq!(state["input_device"], "ASIO Input");
    assert_eq!(state["video_width"], 640);
    assert_eq!(state["vlan_tag"], 99);
    assert_eq!(state["control_dialect"], "osc15");
    assert_eq!(state["record_remote_video"], false);
    // This inventory deliberately follows the persisted schema, excluding
    // deserialization-only legacy fields (device, nic_name, raw flags, and
    // combined receive queue values). A missing field is a UI/report gap.
    let inventory = [
        (
            "audio",
            &[
                "input_device",
                "output_device",
                "sample_rate",
                "channels",
                "bits_per_sample",
                "buffer_samples",
                "backend",
                "tx_audio_level",
                "input_offset",
                "local_audio_loop",
            ][..],
        ),
        (
            "video",
            &[
                "camera_mode_id",
                "compression",
                "jpeg_quality",
                "width",
                "height",
                "fps",
                "bpp",
                "bayer",
                "backend",
                "catalog_file",
                "bayer_pattern",
                "auto_bayer",
                "audio_only",
                "local_camera_index",
                "incomplete_frame_threshold_pct",
            ][..],
        ),
        (
            "network",
            &[
                "control_port",
                "audio_port",
                "video_port",
                "video_packet_size",
                "bind_ip",
                "local_ip",
                "remote_ip",
                "session_id",
                "pcap_device",
                "vlan_tag",
                "media_transport",
                "control_dialect",
                "precheck_reachable",
                "reachability_timeout_ms",
                "audio_receive_queue_depth",
                "audio_receive_prefill",
                "video_receive_queue_depth",
                "video_receive_prefill",
            ][..],
        ),
        (
            "recording",
            &[
                "enabled",
                "path",
                "record_local_audio",
                "record_remote_audio",
                "record_local_video",
                "record_remote_video",
                "mode",
                "video_format",
            ][..],
        ),
    ];
    let persisted = &state["persisted_settings"];
    for (section, fields) in inventory {
        for field in fields {
            assert!(
                persisted[section].get(*field).is_some(),
                "missing persisted state field {section}.{field}"
            );
        }
    }
}
