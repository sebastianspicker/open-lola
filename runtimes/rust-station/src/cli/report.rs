//! Operator-facing run output: result JSON, report file, failure line and progress line.

use super::interrupt;
use crate::station::runtime::normalize_requested_stop;
use crate::station::SessionResult;
use std::collections::BTreeMap;
use std::path::Path;

/// `connect` / `listen` name for the session's peer mode.
pub(super) fn command_name(peer_mode: &str) -> &str {
    if peer_mode == "remote" {
        "connect"
    } else {
        peer_mode
    }
}

/// One stderr line explaining a failed run, worded like `station failed: ...`.
pub(super) fn failure_line(command: &str, result: &SessionResult) -> Option<String> {
    if result.ok {
        return None;
    }
    let error = if result.error.is_empty() && result.rejected {
        &result.reject_text
    } else {
        &result.error
    };
    Some(format!("{command} failed: {}", printable(error)))
}

/// Replace control characters (terminal escapes, newlines) in peer- or device-supplied
/// text before it reaches stderr; the JSON on stdout is escaped by serde instead.
pub(super) fn printable(text: &str) -> String {
    text.chars()
        .map(|c| if c.is_control() { '?' } else { c })
        .collect()
}

/// Compact periodic status from a runtime snapshot's counters.
pub(super) fn progress_line(counters: &BTreeMap<String, u64>, elapsed_secs: u64) -> String {
    let get = |key: &str| counters.get(key).copied().unwrap_or(0);
    format!(
        "[{elapsed_secs}s] audio sent/received {}/{}, video sent/received {}/{}",
        get("audio_frames_sent"),
        get("audio_frames_received"),
        get("video_frames_sent"),
        get("video_frames_received"),
    )
}

/// Write the result JSON atomically to `path`.
pub(super) fn write_report(path: &Path, json: &str) -> Result<(), String> {
    crate::config::file_store::atomic_write(path, format!("{json}\n").as_bytes())
        .map_err(|error| format!("report write error: {path}: {error}", path = path.display()))
}

/// Print the result, honour `--report`, explain failures, and pick the exit code.
pub(super) fn finish_run(command: &str, result: SessionResult, report: Option<&Path>) -> i32 {
    finish_with_signal(command, result, report, interrupt::signal())
}

/// A requested stop turns a cancellation into success (as the runtime worker does);
/// a failure that predates the interrupt is kept.
fn finish_with_signal(
    command: &str,
    mut result: SessionResult,
    report: Option<&Path>,
    signal: Option<i32>,
) -> i32 {
    if signal.is_some() {
        normalize_requested_stop(&mut result, true);
    }
    result.ensure_failure_message();
    let mut json = result.to_json();
    let stopped_by = signal.filter(|_| result.ok).map(interrupt::signal_name);
    if let Some(name) = stopped_by {
        json["stopped_by"] = serde_json::json!(name);
        json["note"] = serde_json::json!(format!("stopped by operator ({name})"));
        eprintln!("stopped by operator ({name})");
    } else if result.ok && result.peer_disconnected() {
        json["note"] = serde_json::json!("peer disconnected");
        eprintln!("peer disconnected");
    }
    let json = serde_json::to_string_pretty(&json).unwrap();
    println!("{json}");
    let mut code = match signal {
        Some(signal) if result.ok => interrupt::exit_code_for(signal),
        _ => i32::from(!result.ok),
    };
    if let Some(line) = failure_line(command, &result) {
        eprintln!("{line}");
    }
    if let Some(error) = report.and_then(|path| write_report(path, &json).err()) {
        eprintln!("{error}");
        if code == 0 {
            code = 1;
        }
    }
    code
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::station::SessionError;

    #[test]
    fn failure_line_matches_the_station_wording() {
        let failed = SessionResult {
            error: "timeout".into(),
            ..Default::default()
        };
        assert_eq!(
            failure_line(command_name("remote"), &failed).as_deref(),
            Some("connect failed: timeout")
        );
        assert_eq!(
            failure_line(command_name("listen"), &failed).as_deref(),
            Some("listen failed: timeout")
        );
        let ok = SessionResult {
            ok: true,
            ..Default::default()
        };
        assert_eq!(failure_line("connect", &ok), None);
    }

    #[test]
    fn failure_line_neutralises_terminal_control_characters() {
        let rejected = SessionResult {
            rejected: true,
            reject_text: "busy\u{1b}]0;owned\u{7}\nnext".into(),
            ..Default::default()
        };
        let line = failure_line("connect", &rejected).unwrap();
        assert_eq!(line, "connect failed: busy?]0;owned??next");
        assert!(!line.chars().any(char::is_control), "{line:?}");
    }

    #[test]
    fn progress_line_reports_media_counters() {
        let counters = BTreeMap::from([
            ("audio_frames_sent".to_string(), 10),
            ("video_frames_received".to_string(), 3),
        ]);
        assert_eq!(
            progress_line(&counters, 5),
            "[5s] audio sent/received 10/0, video sent/received 0/3"
        );
    }

    #[test]
    fn report_is_written_atomically_and_errors_are_reported() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("run.json");
        write_report(&path, "{\"ok\": true}").unwrap();
        assert_eq!(std::fs::read_to_string(&path).unwrap(), "{\"ok\": true}\n");
        let error = write_report(&path.join("nested.json"), "{}").unwrap_err();
        assert!(error.starts_with("report write error:"), "{error}");
    }

    #[test]
    fn failed_run_with_report_error_keeps_a_nonzero_exit_code() {
        let dir = tempfile::tempdir().unwrap();
        let file = dir.path().join("file");
        std::fs::write(&file, "x").unwrap();
        let bad = file.join("run.json");
        let ok = SessionResult {
            ok: true,
            ..Default::default()
        };
        assert_eq!(finish_run("connect", ok.clone(), Some(&bad)), 1);
        assert_eq!(finish_run("connect", ok, None), 0);
    }

    fn cancelled() -> SessionResult {
        SessionResult {
            error: "peer disconnected: session cancelled during listener negotiation".into(),
            failure: Some(SessionError::PeerDisconnect("session cancelled".into())),
            ..Default::default()
        }
    }

    #[test]
    fn interrupted_run_is_reported_as_stopped_by_the_operator() {
        assert_eq!(
            finish_with_signal("listen", cancelled(), None, Some(2)),
            130
        );
        assert_eq!(
            finish_with_signal("listen", cancelled(), None, Some(15)),
            143
        );
        assert_eq!(finish_with_signal("listen", cancelled(), None, None), 1);
    }

    #[test]
    fn failure_before_the_interrupt_is_kept() {
        let failed = SessionResult {
            error: "bind failed".into(),
            failure: Some(SessionError::Transport("bind failed".into())),
            ..Default::default()
        };
        assert_eq!(finish_with_signal("listen", failed, None, Some(2)), 1);
    }

    #[test]
    fn stopped_by_note_is_written_to_the_report() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("run.json");
        finish_with_signal("listen", cancelled(), Some(&path), Some(15));
        let report: serde_json::Value =
            serde_json::from_str(&std::fs::read_to_string(&path).unwrap()).unwrap();
        assert_eq!(report["ok"], true);
        assert_eq!(report["stopped_by"], "SIGTERM");
        assert_eq!(report["note"], "stopped by operator (SIGTERM)");
    }

    #[test]
    fn peer_disconnect_is_a_successful_end_with_a_note() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("run.json");
        let ended = SessionResult {
            ok: true,
            messages_received: vec!["/MESG_DISCONNECT".into()],
            ..Default::default()
        };
        assert_eq!(finish_with_signal("listen", ended, Some(&path), None), 0);
        let report: serde_json::Value =
            serde_json::from_str(&std::fs::read_to_string(&path).unwrap()).unwrap();
        assert_eq!(report["ok"], true);
        assert_eq!(report["note"], "peer disconnected");
    }

    #[test]
    fn a_failure_without_a_message_is_reported_with_one() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("run.json");
        assert_eq!(
            finish_with_signal("listen", SessionResult::default(), Some(&path), None),
            1
        );
        let report: serde_json::Value =
            serde_json::from_str(&std::fs::read_to_string(&path).unwrap()).unwrap();
        assert_eq!(report["ok"], false);
        assert!(!report["error"].as_str().unwrap().is_empty(), "{report}");
    }

    #[test]
    fn exit_codes_follow_the_signal_number() {
        assert_eq!(interrupt::exit_code_for(2), 130);
        assert_eq!(interrupt::exit_code_for(15), 143);
        assert_eq!(interrupt::signal_name(15), "SIGTERM");
        assert_eq!(interrupt::signal_name(2), "SIGINT");
    }
}
