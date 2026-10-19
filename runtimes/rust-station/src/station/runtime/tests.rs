use super::*;

#[test]
fn runtime_config_rejects_invalid_optional_duration() {
    for duration in [f64::NAN, f64::INFINITY, 0.0, -1.0] {
        let mut config = SessionConfig::default();
        config.options.duration_sec = Some(duration);
        assert!(matches!(
            config.validate(),
            Err(SessionError::Configuration(_))
        ));
    }
}

#[test]
fn cleanup_failure_remains_failed_after_a_stop_request() {
    let result = SessionResult {
        failure: Some(SessionError::Cleanup("transport close".into())),
        error: "transport close".into(),
        ok: false,
        ..Default::default()
    };
    assert_eq!(terminal_state(&result), SessionState::Failed);
}

#[test]
fn requested_stop_normalizes_only_peer_disconnect_cancellation() {
    let mut cancelled = SessionResult {
        failure: Some(SessionError::PeerDisconnect("session cancelled".into())),
        error: "peer disconnected: session cancelled".into(),
        ..Default::default()
    };
    normalize_requested_stop(&mut cancelled, true);
    assert!(cancelled.ok);
    assert!(cancelled.failure.is_none());

    let mut cleanup = SessionResult {
        failure: Some(SessionError::Cleanup("transport close".into())),
        cleanup_warnings: vec!["transport close".into()],
        ..Default::default()
    };
    normalize_requested_stop(&mut cleanup, true);
    assert!(!cleanup.ok);
    assert!(matches!(cleanup.failure, Some(SessionError::Cleanup(_))));
}

#[test]
fn diagnostic_backend_names_remain_synthetic_evidence() {
    let mut snapshot = SessionSnapshot::default();
    let result = SessionResult {
        audio_backend: "Diagnostic Audio".into(),
        ..Default::default()
    };
    populate_session_evidence(&mut snapshot, &result);

    assert_eq!(
        snapshot.active_audio_backend,
        Some(AudioBackend::Diagnostic)
    );
    assert_eq!(snapshot.evidence, EvidenceClassification::Synthetic);
}

#[test]
fn status_snapshot_omits_pixels_while_public_preview_boundary_materializes_them() {
    let runtime = SessionRuntime::new();
    let control = SessionRuntimeControl::default();
    control.publish_remote_video(1, 1, &[1, 2, 3], "RGB24");
    let (lock, _) = &*runtime.inner;
    lock_unpoison(lock).session_control = Some(control);

    assert!(runtime.status_snapshot().latest_video.is_none());
    assert_eq!(
        runtime.snapshot().latest_video.expect("public preview").rgb,
        [1, 2, 3]
    );
    let VideoPreviewUpdate::Changed(frame) = runtime.latest_video_update(None) else {
        panic!("first generation");
    };
    lock_unpoison(lock).snapshot.state = SessionState::Stopped;
    assert!(matches!(
        runtime.latest_video_update(Some(frame.generation)),
        VideoPreviewUpdate::Unchanged
    ));
}

fn failing_session_config() -> SessionConfig {
    let mut config = SessionConfig::default();
    config.options.peer_mode = "no-such-peer-mode".into();
    config
}

#[test]
fn wait_inactive_until_returns_as_soon_as_the_session_fails() {
    let runtime = SessionRuntime::new();
    let started = std::time::Instant::now();
    let handle = runtime.start(failing_session_config()).expect("start");
    assert!(handle.wait_inactive_until(started + std::time::Duration::from_secs(30)));
    assert!(started.elapsed() < std::time::Duration::from_secs(2));
    assert_eq!(handle.wait().state, SessionState::Failed);
}

#[test]
fn wait_inactive_until_times_out_while_the_session_stays_active() {
    let runtime = SessionRuntime::new();
    let handle = SessionHandle {
        inner: Arc::clone(&runtime.inner),
    };
    let (lock, _) = &*runtime.inner;
    lock_unpoison(lock).snapshot.state = SessionState::Streaming;
    let deadline = std::time::Instant::now() + std::time::Duration::from_millis(50);
    assert!(!handle.wait_inactive_until(deadline));
    assert!(std::time::Instant::now() >= deadline);
}

#[test]
fn worker_panic_becomes_a_failed_terminal_state_and_allows_a_restart() {
    let runtime = SessionRuntime::new();
    let handle = runtime
        .start_with(SessionConfig::default(), |_| panic!("boom in worker"))
        .expect("start");
    let snapshot = handle.wait();
    assert_eq!(snapshot.state, SessionState::Failed);
    assert!(!snapshot.is_active());
    let error = snapshot.error.expect("panic message");
    assert!(
        error.contains("session worker panicked: boom in worker"),
        "{error}"
    );
    runtime
        .start_with(SessionConfig::default(), |_| SessionResult {
            ok: true,
            ..Default::default()
        })
        .expect("restart after panic")
        .wait();
}

#[test]
fn guard_reports_string_and_non_string_panic_payloads() {
    let formatted = guard::run_guarded(|| panic!("code {}", 7));
    assert!(formatted.error.contains("code 7"), "{}", formatted.error);
    let opaque = guard::run_guarded(|| std::panic::panic_any(5_u8));
    assert!(opaque.error.contains("non-string panic payload"));
    assert!(guard::run_guarded(SessionResult::default).error.is_empty());
}

#[test]
fn reported_video_backend_names_the_real_camera_backend() {
    for (name, expected) in [
        ("Ximea", Some(VideoBackend::Ximea)),
        ("V4L2", Some(VideoBackend::V4l2)),
        ("Media Foundation", Some(VideoBackend::MediaFoundation)),
        (
            "DiagnosticCamera (synthetic)",
            Some(VideoBackend::Diagnostic),
        ),
        ("", None),
        ("SomethingElse", None),
    ] {
        assert_eq!(reported_video_backend(name), expected, "{name}");
    }
}

#[test]
fn reported_audio_backend_names_the_real_audio_backend() {
    for (name, expected) in [
        ("PortAudio ASIO", Some(AudioBackend::PortAudioAsio)),
        ("ALSA", Some(AudioBackend::Alsa)),
        (
            "DiagnosticAudio (synthetic)",
            Some(AudioBackend::Diagnostic),
        ),
        ("", None),
        ("SomethingElse", None),
    ] {
        assert_eq!(reported_audio_backend(name), expected, "{name}");
    }
}
