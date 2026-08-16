use rusty_lola::config::default_settings;
use rusty_lola::station::{run_reject_session, run_session, SessionError, SessionOptions};

#[test]
fn direct_sessions_reject_invalid_optional_durations() {
    for duration in [f64::NAN, f64::INFINITY, 0.0, -1.0] {
        let mut options = SessionOptions::demo();
        options.duration_sec = Some(duration);
        let result = run_session(default_settings(), 1.0, options);
        assert!(!result.ok);
        assert!(matches!(
            result.failure,
            Some(SessionError::Configuration(_))
        ));
        assert!(result.error.contains("duration_sec"));
    }
}

#[test]
fn normal_quickconn_rejection_is_not_success() {
    let mut options = SessionOptions::demo();
    options.peer_reject = true;
    options.control_extras = false;
    let result = run_session(default_settings(), 3.0, options);
    assert!(result.rejected);
    assert!(!result.ok);
    assert!(matches!(
        result.failure,
        Some(SessionError::ControlHandshake(_))
    ));
}

#[test]
fn expected_rejection_diagnostic_remains_successful() {
    let result = run_reject_session(default_settings(), 3.0);
    assert!(result.rejected);
    assert!(result.ok, "{}", result.error);
    assert!(result.failure.is_none());
}
