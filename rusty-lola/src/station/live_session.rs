//! Compatibility facade for the GUI's live controls.
//!
//! Unlike the former two-frame batch loop, one `start` maps to one worker
//! lifecycle. The runtime owns the worker and exposes snapshots instead
//! of mutable UI-thread state.

use crate::config::{default_settings, StationSettings, VideoBackend};
use crate::station::bounded::push_unique_bounded;
use crate::station::runtime::{
    EvidenceClassification, SessionConfig, SessionHandle, SessionRuntime, SessionSnapshot,
    SessionState,
};
use crate::station::session::SessionOptions;
use crate::station::sync::lock_unpoison;
use serde_json::{json, Map, Value};
use std::sync::Mutex;

#[derive(Debug)]
struct LiveConfig {
    settings: StationSettings,
    continuous: bool,
    pending_chat: String,
    chat_history: Vec<String>,
    test_signal_mode: String,
}

/// Threaded station session runner retained for callers of the original UI API.
pub struct LiveStationService {
    runtime: SessionRuntime,
    handle: Mutex<Option<SessionHandle>>,
    config: Mutex<LiveConfig>,
}

impl LiveStationService {
    pub fn new(settings: Option<StationSettings>) -> Self {
        Self {
            runtime: SessionRuntime::new(),
            handle: Mutex::new(None),
            config: Mutex::new(LiveConfig {
                settings: settings.unwrap_or_else(default_settings),
                continuous: false,
                pending_chat: String::new(),
                chat_history: Vec::new(),
                test_signal_mode: "none".into(),
            }),
        }
    }

    pub fn is_running(&self) -> bool {
        self.runtime.is_active()
    }

    /// Runtime configuration is immutable while a lifecycle is active.
    pub fn update_settings(&self, settings: StationSettings) {
        if self.is_running() {
            return;
        }
        lock_unpoison(&self.config).settings = settings;
    }

    pub fn set_test_signals(&self, send: bool) {
        if self.is_running() {
            return;
        }
        lock_unpoison(&self.config).test_signal_mode = if send { "send" } else { "receive" }.into();
    }

    pub fn clear_test_signals(&self) {
        if self.is_running() {
            return;
        }
        lock_unpoison(&self.config).test_signal_mode = "none".into();
    }

    pub fn send_chat(&self, text: &str) {
        let text = text.trim();
        if text.is_empty() {
            return;
        }
        let mut config = lock_unpoison(&self.config);
        config.pending_chat = text.into();
        push_unique_bounded(&mut config.chat_history, text.into());
        drop(config);
        if let Some(handle) = lock_unpoison(&self.handle).as_ref() {
            let _ = handle.send_control(format!("chat:{text}"));
        }
    }

    pub fn snapshot(&self) -> SessionSnapshot {
        self.runtime.snapshot()
    }

    pub fn latest_video(&self) -> Option<crate::station::session::VideoPreview> {
        self.runtime.snapshot().latest_video
    }

    pub fn get_report(&self) -> Value {
        let snapshot = self.runtime.snapshot();
        let config = lock_unpoison(&self.config);
        let mut report = Map::new();
        report.insert("status".into(), json!(status_name(&snapshot)));
        report.insert("running".into(), json!(snapshot.is_active()));
        report.insert("continuous".into(), json!(config.continuous));
        report.insert(
            "segments".into(),
            json!(usize::from(snapshot.result.is_some())),
        );
        report.insert("pending_chat".into(), json!(config.pending_chat));
        report.insert("chat_history".into(), json!(config.chat_history));
        report.insert("controls".into(), json!(snapshot.controls));
        report.insert(
            "requested_audio_backend".into(),
            json!(snapshot.requested_audio_backend.to_string()),
        );
        report.insert(
            "active_audio_backend".into(),
            json!(snapshot
                .active_audio_backend
                .map(|backend| backend.to_string())),
        );
        report.insert(
            "requested_video_backend".into(),
            json!(snapshot.requested_video_backend.to_string()),
        );
        report.insert(
            "active_video_backend".into(),
            json!(snapshot
                .active_video_backend
                .map(|backend| backend.to_string())),
        );
        report.insert(
            "requested_transport".into(),
            json!(format!("{:?}", snapshot.requested_transport).to_ascii_lowercase()),
        );
        report.insert(
            "active_transport".into(),
            json!(snapshot
                .active_transport
                .map(|transport| format!("{transport:?}").to_ascii_lowercase())),
        );
        report.insert("counters".into(), json!(snapshot.counters));
        report.insert("warnings".into(), json!(snapshot.warnings));
        report.insert("negotiated_media".into(), json!(snapshot.negotiated_media));
        report.insert(
            "failure_category".into(),
            json!(snapshot.failure.as_ref().map(session_error_category)),
        );
        report.insert(
            "evidence".into(),
            json!(match snapshot.evidence {
                EvidenceClassification::Unknown => "unknown",
                EvidenceClassification::Synthetic => "synthetic",
                EvidenceClassification::NativeUnvalidated => "native_unvalidated",
            }),
        );
        if let Some(result) = snapshot.result {
            if let Value::Object(values) = result.to_json() {
                report.extend(values);
            }
        }
        if let Some(error) = snapshot.error {
            report.insert("error".into(), json!(error));
            report.insert("ok".into(), json!(false));
        }
        Value::Object(report)
    }

    /// Start exactly one session lifecycle in a worker. `continuous` remains a
    /// UI compatibility flag; it no longer causes reconnecting two-frame loops.
    pub fn start(
        &self,
        timeout: f64,
        stream_frames: u32,
        control_extras: bool,
        continuous: bool,
        options: Option<SessionOptions>,
    ) -> Result<(), String> {
        if self.is_running() {
            return Err("LiveStationService is already running".into());
        }
        let (settings, test_signal_mode) = {
            let mut config = lock_unpoison(&self.config);
            config.continuous = continuous;
            (config.settings.clone(), config.test_signal_mode.clone())
        };
        let mut options = options.unwrap_or_else(SessionOptions::demo);
        options.control_extras = control_extras;
        options.stream_frames = stream_frames.max(1);
        options.camera_backend = settings.video.backend;
        options.audio_backend = settings.audio.backend;
        options.use_catalog_geometry = settings.video.backend != VideoBackend::Diagnostic;
        if test_signal_mode != "none" {
            options.test_signal_mode = test_signal_mode;
        }
        let handle = self
            .runtime
            .start(SessionConfig::new(settings, timeout, options))
            .map_err(|e| e.to_string())?;
        *lock_unpoison(&self.handle) = Some(handle);
        Ok(())
    }

    /// Request shutdown and wait for the worker when called by non-UI code.
    /// Egui uses `request_stop` and polls `get_report` instead.
    pub fn stop(&self, _join_timeout_sec: f64) -> Value {
        if let Some(handle) = lock_unpoison(&self.handle).as_ref().cloned() {
            handle.stop();
            handle.wait();
        }
        self.get_report()
    }

    /// Non-blocking stop signal suitable for the GUI update thread.
    pub fn request_stop(&self) -> Value {
        if let Some(handle) = lock_unpoison(&self.handle).as_ref() {
            handle.stop();
        }
        self.get_report()
    }
}

fn session_error_category(error: &crate::station::SessionError) -> &'static str {
    use crate::station::SessionError;
    match error {
        SessionError::AlreadyActive | SessionError::Configuration(_) | SessionError::NotActive => {
            "configuration"
        }
        SessionError::ControlHandshake(_) => "control_handshake",
        SessionError::Transport(_) => "transport",
        SessionError::AudioBackend(_) => "audio_backend",
        SessionError::VideoBackend(_) => "video_backend",
        SessionError::Protocol(_) => "protocol",
        SessionError::Timeout(_) => "timeout",
        SessionError::PeerDisconnect(_) => "peer_disconnect",
        SessionError::Cleanup(_) => "cleanup",
    }
}

fn status_name(snapshot: &SessionSnapshot) -> String {
    match snapshot.state {
        SessionState::Idle => "idle".into(),
        SessionState::Checking | SessionState::Negotiating => "connecting".into(),
        SessionState::Streaming => "streaming".into(),
        SessionState::Stopping => "disconnecting".into(),
        SessionState::Stopped => "disconnected".into(),
        SessionState::Rejected => "rejected".into(),
        SessionState::Failed => format!(
            "error:{}",
            snapshot.error.as_deref().unwrap_or("session_failed")
        ),
    }
}
