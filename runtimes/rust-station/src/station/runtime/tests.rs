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
