use rusty_lola::config::{AudioBackend, VideoBackend};
use rusty_lola::station::{MultiSidRuntime, SessionConfig, SessionError, SessionState};
use std::thread;
use std::time::{Duration, Instant};

fn loopback_config(sid: i64, port_base: u16) -> SessionConfig {
    let mut config = SessionConfig::default();
    config.settings.network.session_id = sid;
    config.settings.network.control_port = port_base;
    config.settings.network.audio_port = port_base + 1;
    config.settings.network.video_port = port_base + 2;
    config.settings.audio.backend = AudioBackend::Diagnostic;
    config.settings.video.backend = VideoBackend::Diagnostic;
    config.settings.video.width = 64;
    config.settings.video.height = 48;
    config.timeout_secs = 5.0;
    config.options.stream_frames = 1;
    config.options.control_extras = false;
    config
}

fn wait_for_streaming(runtime: &MultiSidRuntime, sid: i64) {
    let deadline = Instant::now() + Duration::from_secs(12);
    while runtime.snapshot(sid).unwrap().state != SessionState::Streaming
        && Instant::now() < deadline
    {
        thread::sleep(Duration::from_millis(10));
    }
    assert_eq!(
        runtime.snapshot(sid).unwrap().state,
        SessionState::Streaming
    );
}

#[test]
fn persistent_sids_keep_independent_workers_controls_and_terminal_results() {
    let mut runtime = MultiSidRuntime::new();
    runtime
        .start(vec![
            loopback_config(101, 31_001),
            loopback_config(202, 31_011),
        ])
        .unwrap();

    wait_for_streaming(&runtime, 101);
    wait_for_streaming(&runtime, 202);
    runtime.send_control(101, "chat:one").unwrap();
    runtime.send_control(202, "chat:two").unwrap();
    assert_eq!(runtime.snapshot(101).unwrap().controls, vec!["chat:one"]);
    assert_eq!(runtime.snapshot(202).unwrap().controls, vec!["chat:two"]);

    runtime.stop(101).unwrap();
    let deadline = Instant::now() + Duration::from_secs(6);
    while runtime.snapshot(101).unwrap().is_active() && Instant::now() < deadline {
        thread::sleep(Duration::from_millis(10));
    }
    assert!(!runtime.snapshot(101).unwrap().is_active());
    assert_eq!(
        runtime.snapshot(202).unwrap().state,
        SessionState::Streaming
    );
    assert!(
        runtime
            .snapshot(202)
            .unwrap()
            .counters
            .get("audio_frames_sent")
            .copied()
            .unwrap_or_default()
            > 0
    );

    let first_stop = runtime.stop_all();
    let second_stop = runtime.stop_all();
    assert!(first_stop.values().all(|snapshot| snapshot.stop_requested));
    assert!(second_stop.values().all(|snapshot| snapshot.stop_requested));
    let terminal = runtime.wait_all();
    assert_eq!(terminal.len(), 2);
    for (sid, snapshot) in terminal {
        assert!(matches!(
            snapshot.state,
            SessionState::Stopped | SessionState::Failed
        ));
        assert!(
            snapshot.result.is_some(),
            "SID {sid} has one terminal result"
        );
    }
}

#[test]
fn preflight_rejects_collisions_without_starting_any_worker() {
    let mut runtime = MultiSidRuntime::new();
    let error = runtime
        .start(vec![loopback_config(1, 31_101), loopback_config(2, 31_101)])
        .unwrap_err();
    assert!(matches!(error, SessionError::Configuration(_)));
    assert!(runtime.session_ids().is_empty());
    assert!(matches!(runtime.snapshot(1), Err(SessionError::NotActive)));

    let error = runtime
        .start(vec![loopback_config(3, 31_111), loopback_config(3, 31_121)])
        .unwrap_err();
    assert!(matches!(error, SessionError::Configuration(_)));
    assert!(runtime.session_ids().is_empty());
}
