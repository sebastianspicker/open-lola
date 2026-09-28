//! Thread-safe session runtime facade.
//!
//! The protocol/session implementation remains the authoritative owner of a
//! connection. This module owns lifecycle, immutable snapshots, cancellation,
//! and bounded control queuing so callers never run a session from a UI frame.

use crate::config::{
    default_settings, AudioBackend, MediaTransportKind, StationSettings, VideoBackend,
};
use crate::station::bounded::push_bounded;
#[cfg(any(feature = "gui", test))]
use crate::station::session::VideoPreviewUpdate;
use crate::station::session::{
    run_session, SessionOptions, SessionPhase, SessionResult, SessionRuntimeControl,
};
use crate::station::sync::lock_unpoison;
pub use crate::station::SessionError;
use std::collections::BTreeMap;
use std::sync::{Arc, Condvar, Mutex};
use std::thread::{self, JoinHandle};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SessionState {
    Idle,
    Checking,
    Negotiating,
    Streaming,
    Stopping,
    Stopped,
    Rejected,
    Failed,
}

#[derive(Debug, Clone)]
pub struct SessionConfig {
    pub settings: StationSettings,
    pub timeout_secs: f64,
    pub options: SessionOptions,
}

impl Default for SessionConfig {
    fn default() -> Self {
        Self {
            settings: default_settings(),
            timeout_secs: 5.0,
            options: SessionOptions::demo(),
        }
    }
}

impl SessionConfig {
    pub fn new(settings: StationSettings, timeout_secs: f64, options: SessionOptions) -> Self {
        Self {
            settings,
            timeout_secs,
            options,
        }
    }

    fn validate(&self) -> Result<(), SessionError> {
        self.settings
            .validate()
            .map_err(|e| SessionError::Configuration(e.to_string()))?;
        if !self.timeout_secs.is_finite() || self.timeout_secs <= 0.0 {
            return Err(SessionError::Configuration(
                "timeout_secs must be finite and greater than zero".into(),
            ));
        }
        self.options.validate_duration()?;
        Ok(())
    }
}

#[derive(Debug, Clone)]
pub struct SessionSnapshot {
    pub state: SessionState,
    pub stop_requested: bool,
    pub controls: Vec<String>,
    pub result: Option<SessionResult>,
    pub error: Option<String>,
    pub failure: Option<SessionError>,
    pub requested_audio_backend: AudioBackend,
    pub active_audio_backend: Option<AudioBackend>,
    pub requested_video_backend: VideoBackend,
    pub active_video_backend: Option<VideoBackend>,
    pub requested_transport: MediaTransportKind,
    pub active_transport: Option<MediaTransportKind>,
    pub counters: BTreeMap<String, u64>,
    pub warnings: Vec<String>,
    pub negotiated_media: BTreeMap<String, String>,
    pub evidence: EvidenceClassification,
    pub latest_video: Option<crate::station::session::VideoPreview>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EvidenceClassification {
    Unknown,
    Synthetic,
    NativeUnvalidated,
}

impl SessionSnapshot {
    pub fn is_active(&self) -> bool {
        matches!(
            self.state,
            SessionState::Checking
                | SessionState::Negotiating
                | SessionState::Streaming
                | SessionState::Stopping
        )
    }
}

impl Default for SessionSnapshot {
    fn default() -> Self {
        Self {
            state: SessionState::Idle,
            stop_requested: false,
            controls: Vec::new(),
            result: None,
            error: None,
            failure: None,
            requested_audio_backend: AudioBackend::PortAudioAsio,
            active_audio_backend: None,
            requested_video_backend: VideoBackend::Ximea,
            active_video_backend: None,
            requested_transport: MediaTransportKind::Udp,
            active_transport: None,
            counters: BTreeMap::new(),
            warnings: Vec::new(),
            negotiated_media: BTreeMap::new(),
            evidence: EvidenceClassification::Unknown,
            latest_video: None,
        }
    }
}

struct RuntimeInner {
    snapshot: SessionSnapshot,
    worker: Option<JoinHandle<()>>,
    session_control: Option<SessionRuntimeControl>,
}

#[derive(Clone)]
pub struct SessionRuntime {
    inner: Arc<(Mutex<RuntimeInner>, Condvar)>,
}

#[derive(Clone)]
pub struct SessionHandle {
    inner: Arc<(Mutex<RuntimeInner>, Condvar)>,
}

impl Default for SessionRuntime {
    fn default() -> Self {
        Self::new()
    }
}

impl SessionRuntime {
    pub fn new() -> Self {
        Self {
            inner: Arc::new((
                Mutex::new(RuntimeInner {
                    snapshot: SessionSnapshot::default(),
                    worker: None,
                    session_control: None,
                }),
                Condvar::new(),
            )),
        }
    }

    pub fn snapshot(&self) -> SessionSnapshot {
        snapshot(&self.inner, true)
    }

    pub fn is_active(&self) -> bool {
        snapshot(&self.inner, false).is_active()
    }

    pub(crate) fn status_snapshot(&self) -> SessionSnapshot {
        snapshot(&self.inner, false)
    }

    pub fn latest_video(&self) -> Option<crate::station::session::VideoPreview> {
        let (lock, _) = &*self.inner;
        lock_unpoison(lock)
            .session_control
            .as_ref()
            .and_then(SessionRuntimeControl::latest_video)
    }

    #[cfg(any(feature = "gui", test))]
    pub(crate) fn latest_video_update(&self, generation: Option<u64>) -> VideoPreviewUpdate {
        let (lock, _) = &*self.inner;
        lock_unpoison(lock)
            .session_control
            .as_ref()
            .map_or(VideoPreviewUpdate::Empty, |control| {
                control.latest_video_update(generation)
            })
    }

    pub fn start(&self, mut config: SessionConfig) -> Result<SessionHandle, SessionError> {
        config.validate()?;
        let (lock, _) = &*self.inner;
        {
            let mut inner = lock_unpoison(lock);
            if inner.snapshot.is_active() {
                return Err(SessionError::AlreadyActive);
            }
            if let Some(worker) = inner.worker.take() {
                // Finished workers are reaped before a new lifecycle begins.
                drop(inner);
                let _ = worker.join();
                inner = lock_unpoison(lock);
            }
            inner.snapshot = SessionSnapshot {
                state: SessionState::Checking,
                stop_requested: false,
                controls: Vec::new(),
                result: None,
                error: None,
                failure: None,
                requested_audio_backend: config.settings.audio.backend,
                active_audio_backend: None,
                requested_video_backend: config.settings.video.backend,
                active_video_backend: None,
                requested_transport: config.settings.network.media_transport,
                active_transport: None,
                counters: BTreeMap::new(),
                warnings: Vec::new(),
                negotiated_media: BTreeMap::new(),
                evidence: EvidenceClassification::Unknown,
                latest_video: None,
            };
        }
        let shared = Arc::clone(&self.inner);
        let session_control = SessionRuntimeControl::default();
        config.options.persistent = true;
        config.options.interleaved_av = true;
        config.options.runtime_control = Some(session_control.clone());
        {
            let mut inner = lock_unpoison(lock);
            inner.session_control = Some(session_control);
        }
        let worker = thread::Builder::new()
            .name("station-runtime".into())
            .spawn(move || {
                let (lock, cvar) = &*shared;
                {
                    let mut inner = lock_unpoison(lock);
                    if inner.snapshot.stop_requested {
                        inner.snapshot.state = SessionState::Stopped;
                        cvar.notify_all();
                        return;
                    }
                    inner.snapshot.state = SessionState::Negotiating;
                    cvar.notify_all();
                }
                let mut result = run_session(config.settings, config.timeout_secs, config.options);
                let mut inner = lock_unpoison(lock);
                normalize_requested_stop(&mut result, inner.snapshot.stop_requested);
                inner.snapshot.state = terminal_state(&result);
                if result.rejected {
                    inner.snapshot.error = Some(result.reject_text.clone());
                } else if !result.ok {
                    inner.snapshot.error = Some(result.error.clone());
                    inner.snapshot.failure = result.failure.clone();
                }
                populate_session_evidence(&mut inner.snapshot, &result);
                inner.snapshot.result = Some(result);
                cvar.notify_all();
            })
            .map_err(|e| {
                let mut inner = lock_unpoison(lock);
                inner.snapshot.state = SessionState::Failed;
                inner.snapshot.error = Some(e.to_string());
                let error = SessionError::Transport(e.to_string());
                inner.snapshot.failure = Some(error.clone());
                error
            })?;
        let mut inner = lock_unpoison(lock);
        inner.worker = Some(worker);
        Ok(SessionHandle {
            inner: Arc::clone(&self.inner),
        })
    }
}

impl SessionHandle {
    pub fn snapshot(&self) -> SessionSnapshot {
        snapshot(&self.inner, true)
    }

    /// Queue a chat or serialized `/MESG_*` control for the active session.
    pub fn send_control(&self, message: impl Into<String>) -> Result<(), SessionError> {
        let message = message.into();
        validate_control_command(&message)?;
        let (lock, _) = &*self.inner;
        let mut inner = lock_unpoison(lock);
        if !inner.snapshot.is_active() {
            return Err(SessionError::NotActive);
        }
        let control = inner
            .session_control
            .clone()
            .ok_or(SessionError::NotActive)?;
        control
            .send(message.clone())
            .map_err(SessionError::Transport)?;
        push_bounded(&mut inner.snapshot.controls, message);
        Ok(())
    }

    /// Request shutdown. Repeated calls are deliberately harmless.
    pub fn stop(&self) -> SessionSnapshot {
        let (lock, cvar) = &*self.inner;
        let mut inner = lock_unpoison(lock);
        inner.snapshot.stop_requested = true;
        if let Some(control) = inner.session_control.clone() {
            control.cancel();
        }
        if inner.snapshot.is_active() {
            inner.snapshot.state = SessionState::Stopping;
        }
        cvar.notify_all();
        drop(inner);
        snapshot(&self.inner, true)
    }

    /// Join the worker and return its final immutable snapshot. This is safe
    /// after `stop` and is idempotent once the worker has been reaped.
    pub fn wait(&self) -> SessionSnapshot {
        let worker = {
            let (lock, _) = &*self.inner;
            lock_unpoison(lock).worker.take()
        };
        if let Some(worker) = worker {
            let _ = worker.join();
        }
        self.snapshot()
    }
}

fn validate_control_command(message: &str) -> Result<(), SessionError> {
    if message.trim().is_empty() {
        return Err(SessionError::Configuration(
            "control message must not be empty".into(),
        ));
    }
    if message.len() > crate::protocol::CONTROL_DATAGRAM_SIZE {
        return Err(SessionError::Configuration(
            "control message must not exceed 1024 bytes".into(),
        ));
    }
    if let Some(chat) = message.strip_prefix("chat:") {
        if chat.is_empty() || !chat.is_ascii() {
            return Err(SessionError::Configuration(
                "chat controls require non-empty ASCII text".into(),
            ));
        }
        return Ok(());
    }
    if message.starts_with("/MESG_") {
        crate::protocol::decode_mesg(message.as_bytes()).map_err(|error| {
            SessionError::Configuration(format!("invalid serialized control: {error}"))
        })?;
        return Ok(());
    }
    Err(SessionError::Configuration(
        "control must be `chat:text` or a serialized /MESG_* message".into(),
    ))
}

fn snapshot(
    shared: &Arc<(Mutex<RuntimeInner>, Condvar)>,
    include_latest_video: bool,
) -> SessionSnapshot {
    let (lock, _) = &**shared;
    let mut inner = lock_unpoison(lock);
    if inner.snapshot.is_active() && !inner.snapshot.stop_requested {
        if let Some(control) = inner.session_control.clone() {
            inner.snapshot.state = match control.phase() {
                SessionPhase::Idle | SessionPhase::Checking => SessionState::Checking,
                SessionPhase::Negotiating => SessionState::Negotiating,
                SessionPhase::Streaming => SessionState::Streaming,
                SessionPhase::Stopping => SessionState::Stopping,
            };
            let activity = control.activity();
            inner.snapshot.active_audio_backend = activity.audio_backend;
            inner.snapshot.active_video_backend = activity.video_backend;
            inner.snapshot.active_transport = activity.transport;
            inner.snapshot.counters = activity.counters();
            inner.snapshot.evidence = if activity.synthetic {
                EvidenceClassification::Synthetic
            } else if activity.audio_backend.is_some() || activity.video_backend.is_some() {
                EvidenceClassification::NativeUnvalidated
            } else {
                EvidenceClassification::Unknown
            };
        }
    }
    let mut snapshot = inner.snapshot.clone();
    if include_latest_video {
        snapshot.latest_video = inner
            .session_control
            .as_ref()
            .and_then(SessionRuntimeControl::latest_video);
    }
    snapshot
}

fn terminal_state(result: &SessionResult) -> SessionState {
    if result.rejected {
        SessionState::Rejected
    } else if result.ok {
        SessionState::Stopped
    } else {
        SessionState::Failed
    }
}

fn normalize_requested_stop(result: &mut SessionResult, stop_requested: bool) {
    if stop_requested
        && result.cleanup_warnings.is_empty()
        && (matches!(result.failure, Some(SessionError::PeerDisconnect(_)))
            || (result.failure.is_none() && result.error.is_empty()))
    {
        result.ok = true;
        result.error.clear();
        result.failure = None;
        if result.states.last().map(String::as_str) != Some("IDLE") {
            result.states.push("IDLE".into());
        }
    }
}

fn populate_session_evidence(snapshot: &mut SessionSnapshot, result: &SessionResult) {
    snapshot.counters = session_counters(result);
    snapshot
        .warnings
        .extend(result.cleanup_warnings.iter().cloned());
    extend_network_counters(snapshot, result);
    populate_backend_evidence(snapshot, result);
}

fn session_counters(result: &SessionResult) -> BTreeMap<String, u64> {
    super::session::RuntimeActivity::from_result(result).counters()
}

fn extend_network_counters(snapshot: &mut SessionSnapshot, result: &SessionResult) {
    snapshot
        .counters
        .extend(result.network_monitor.iter().filter_map(|(name, value)| {
            u64::try_from(*value)
                .ok()
                .map(|value| (name.clone(), value))
        }));
}

fn populate_backend_evidence(snapshot: &mut SessionSnapshot, result: &SessionResult) {
    snapshot.active_audio_backend = reported_audio_backend(&result.audio_backend);
    snapshot.active_video_backend = reported_video_backend(&result.camera_backend);
    snapshot.active_transport = reported_transport(&result.media_transport);
    for (name, value) in [
        ("transport", &result.media_transport),
        ("camera_backend", &result.camera_backend),
        ("audio_backend", &result.audio_backend),
        ("peer_mode", &result.peer_mode),
    ] {
        snapshot.negotiated_media.insert(name.into(), value.clone());
    }
    snapshot.evidence = classify_evidence(snapshot);
    match snapshot.evidence {
        EvidenceClassification::Synthetic => snapshot
            .warnings
            .push("diagnostic backend supplied synthetic media evidence".into()),
        EvidenceClassification::NativeUnvalidated => snapshot.warnings.push(
            "native backend activity is not physical Windows-LoLa interoperability evidence".into(),
        ),
        EvidenceClassification::Unknown => {}
    }
}

fn reported_audio_backend(name: &str) -> Option<AudioBackend> {
    if is_diagnostic_backend(name) {
        Some(AudioBackend::Diagnostic)
    } else if name.is_empty() {
        None
    } else {
        Some(AudioBackend::PortAudioAsio)
    }
}

fn reported_video_backend(name: &str) -> Option<VideoBackend> {
    if is_diagnostic_backend(name) {
        Some(VideoBackend::Diagnostic)
    } else if name.is_empty() {
        None
    } else {
        Some(VideoBackend::Ximea)
    }
}

fn is_diagnostic_backend(name: &str) -> bool {
    name.contains("Software") || name.contains("Diagnostic") || name.contains("synthetic")
}

fn reported_transport(name: &str) -> Option<MediaTransportKind> {
    match name {
        "udp" => Some(MediaTransportKind::Udp),
        "pcap" | "npcap" => Some(MediaTransportKind::Npcap),
        _ => None,
    }
}

fn classify_evidence(snapshot: &SessionSnapshot) -> EvidenceClassification {
    if matches!(
        snapshot.active_audio_backend,
        Some(AudioBackend::Diagnostic)
    ) || matches!(
        snapshot.active_video_backend,
        Some(VideoBackend::Diagnostic)
    ) {
        EvidenceClassification::Synthetic
    } else if snapshot.active_audio_backend.is_some() || snapshot.active_video_backend.is_some() {
        EvidenceClassification::NativeUnvalidated
    } else {
        EvidenceClassification::Unknown
    }
}
