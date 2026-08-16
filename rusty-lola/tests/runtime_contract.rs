use rusty_lola::config::{AudioBackend, ControlDialect, VideoBackend};
use rusty_lola::station::{SessionConfig, SessionRuntime, SessionState};
use std::thread;
use std::time::{Duration, Instant};

#[test]
fn runtime_handle_exposes_snapshot_control_and_idempotent_stop() {
    let runtime = SessionRuntime::new();
    let mut config = SessionConfig::default();
    config.settings.audio.backend = AudioBackend::Diagnostic;
    config.settings.video.backend = VideoBackend::Diagnostic;
    config.settings.video.width = 64;
    config.settings.video.height = 48;
    config.timeout_secs = 5.0;
    config.options.stream_frames = 1;
    config.options.control_extras = false;
    let handle = runtime.start(config).unwrap();
    // Loopback sessions intentionally serialize their fixed UDP media ports.
    // Leave enough time for a concurrently scheduled contract test to finish.
    let deadline = Instant::now() + Duration::from_secs(12);
    while handle.snapshot().state != SessionState::Streaming && Instant::now() < deadline {
        thread::sleep(Duration::from_millis(10));
    }
    let streaming_snapshot = handle.snapshot();
    assert_eq!(
        streaming_snapshot.state,
        SessionState::Streaming,
        "runtime never reached streaming: {streaming_snapshot:?}"
    );
    thread::sleep(Duration::from_millis(1000));
    let live = handle.snapshot();
    assert_eq!(
        live.state,
        SessionState::Streaming,
        "persistent sessions must not stop at stream_frames: {live:?}"
    );
    assert!(
        live.counters
            .get("audio_frames_sent")
            .copied()
            .unwrap_or_default()
            > 0,
        "streaming snapshots must publish live media counters"
    );
    let preview = live.latest_video.expect("latest session video preview");
    assert_eq!(
        preview.rgb.len(),
        (preview.width * preview.height * 3) as usize
    );
    handle.send_control("chat:contract").unwrap();
    thread::sleep(Duration::from_millis(150));
    let first_stop = handle.stop();
    let second_stop = handle.stop();
    assert!(first_stop.stop_requested && second_stop.stop_requested);
    let final_snapshot = handle.wait();
    assert!(matches!(
        final_snapshot.state,
        SessionState::Stopped | SessionState::Failed
    ));
    assert!(final_snapshot.stop_requested);
    let result = final_snapshot.result.expect("terminal result");
    assert_eq!(
        result
            .messages_sent
            .iter()
            .filter(|message| message.as_str() == "/MESG_QUICKCONN")
            .count(),
        1,
        "one persistent lifecycle must negotiate exactly once"
    );
    assert_eq!(
        result
            .messages_sent
            .iter()
            .filter(|message| message.as_str() == "/MESG_DISCONNECT")
            .count(),
        1
    );
    assert!(result
        .messages_sent
        .iter()
        .any(|message| message == "/MESG_CHAT"));
}

#[test]
fn osc15_runtime_negotiates_and_streams() {
    let runtime = SessionRuntime::new();
    let mut config = SessionConfig::default();
    config.settings.audio.backend = AudioBackend::Diagnostic;
    config.settings.video.backend = VideoBackend::Diagnostic;
    config.settings.network.control_dialect = ControlDialect::Osc15;
    config.settings.video.width = 64;
    config.settings.video.height = 48;
    config.timeout_secs = 5.0;
    config.options.control_extras = false;
    let handle = runtime.start(config).unwrap();
    let deadline = Instant::now() + Duration::from_secs(12);
    while handle.snapshot().state != SessionState::Streaming && Instant::now() < deadline {
        thread::sleep(Duration::from_millis(10));
    }
    assert_eq!(handle.snapshot().state, SessionState::Streaming);
    handle.stop();
    let snapshot = handle.wait();
    assert_eq!(snapshot.state, SessionState::Stopped, "{snapshot:?}");
    let result = snapshot.result.expect("terminal result");
    assert!(result
        .messages_received
        .iter()
        .any(|message| message == "/MESG_QUICKCONN_ACK"));
}
