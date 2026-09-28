mod activity;
use crate::config::{
    find_mode, load_camera_modes, AudioBackend, CameraMode, ColorSettings, MediaTransportKind,
    StationSettings, VideoBackend,
};
use crate::shipped_ximea_ini;
use crate::station::sync::lock_unpoison;
use crate::station::SessionError;
use serde_json::Value;
use std::collections::{BTreeMap, VecDeque};
use std::path::PathBuf;
#[cfg(any(feature = "gui", test))]
use std::sync::atomic::AtomicU64;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex, OnceLock};
use std::time::{SystemTime, UNIX_EPOCH};

/// The station's explicit relationship to its LoLa peer.
///
/// `SessionOptions` retains its string field for settings/profile compatibility,
/// but all session entry points parse it before opening sockets.  This prevents
/// a misspelled role from silently becoming a loopback session.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PeerRole {
    Loopback,
    Remote,
    Listen,
}

impl PeerRole {
    pub fn parse(value: &str) -> Result<Self, SessionError> {
        match value.trim().to_ascii_lowercase().as_str() {
            "loopback" => Ok(Self::Loopback),
            "remote" => Ok(Self::Remote),
            "listen" => Ok(Self::Listen),
            _ => Err(SessionError::Configuration(format!(
                "unknown peer mode `{value}`; expected loopback, remote, or listen"
            ))),
        }
    }

    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Loopback => "loopback",
            Self::Remote => "remote",
            Self::Listen => "listen",
        }
    }
}

/// Serialize loopback sessions so parallel tests do not thrash ephemeral UDP ports on Windows.
pub(super) fn session_lock() -> &'static Mutex<()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    LOCK.get_or_init(|| Mutex::new(()))
}

#[derive(Debug, Clone)]
pub struct SessionOptions {
    pub control_extras: bool,
    /// Mark a deliberate rejection diagnostic as its expected outcome.
    pub expected_rejection: bool,
    pub peer_reject: bool,
    pub stream_frames: u32,
    pub record: bool,
    pub record_dir: Option<PathBuf>,
    pub preview_dir: Option<PathBuf>,
    pub max_stream_width: u32,
    pub max_stream_height: u32,
    pub chat_text: String,
    pub catalog_path: Option<PathBuf>,
    pub use_catalog_geometry: bool,
    pub apply_color: bool,
    pub color_settings: Option<ColorSettings>,
    /// Persisted compatibility field, validated to [`PeerRole`] at session entry.
    pub peer_mode: String,
    pub duration_sec: Option<f64>,
    pub interleaved_av: bool,
    pub preview_all_frames: bool,
    pub media_transport: Option<MediaTransportKind>,
    pub pcap_device: Option<String>,
    pub precheck_reachable: Option<bool>,
    pub reachability_timeout_ms: Option<u32>,
    pub bayer_pattern: String,
    pub auto_bayer: bool,
    pub camera_backend: VideoBackend,
    pub audio_backend: AudioBackend,
    pub stream_tx_video: bool,
    pub stream_tx_audio: bool,
    pub stream_rx_video: bool,
    pub stream_rx_audio: bool,
    pub audio_only: bool,
    /// TX preamp: 1 = 0 dB, 2 = +6 dB.
    pub tx_audio_level: u8,
    /// Incomplete-frame render threshold percent (0 = require all packets).
    pub incomplete_frame_threshold_pct: f64,
    /// When true, use centered crop+scale for aspect-preserving resize.
    pub use_centered_scale: bool,
    /// Test signal mode: "none" | "send" | "receive" | "both" (manual §4.12 SMPTE + 689/750 Hz).
    pub test_signal_mode: String,
    /// When true (default), take global session lock for loopback port safety.
    pub serialize_loopback: bool,
    /// Keep the negotiated session alive until its runtime control is cancelled.
    pub(crate) persistent: bool,
    /// Shared cancellation and live-control queue for a persistent runtime.
    pub(crate) runtime_control: Option<SessionRuntimeControl>,
}

#[derive(Debug, Clone, Default)]
pub struct SessionRuntimeControl {
    cancelled: Arc<AtomicBool>,
    commands: Arc<Mutex<VecDeque<String>>>,
    phase: Arc<std::sync::atomic::AtomicU8>,
    active: Arc<Mutex<RuntimeActivity>>,
    latest_video: Arc<Mutex<Option<SharedVideoPreview>>>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VideoPreview {
    pub width: u32,
    pub height: u32,
    pub rgb: Vec<u8>,
}

#[derive(Debug, Clone)]
pub(crate) struct SharedVideoPreview {
    pub(crate) width: u32,
    pub(crate) height: u32,
    pub(crate) rgb: Arc<[u8]>,
    #[cfg(any(feature = "gui", test))]
    pub(crate) generation: u64,
}

#[cfg(any(feature = "gui", test))]
#[derive(Debug, Clone)]
pub(crate) enum VideoPreviewUpdate {
    Changed(SharedVideoPreview),
    Unchanged,
    Empty,
}

#[cfg(any(feature = "gui", test))]
static NEXT_PREVIEW_GENERATION: AtomicU64 = AtomicU64::new(1);

#[cfg(test)]
#[path = "types/tests.rs"]
mod tests;

#[derive(Debug, Clone, Copy, Default)]
pub struct RuntimeActivity {
    pub audio_backend: Option<AudioBackend>,
    pub video_backend: Option<VideoBackend>,
    pub transport: Option<MediaTransportKind>,
    pub synthetic: bool,
    pub media_frames_sent: u64,
    pub media_frames_received: u64,
    pub video_frames_sent: u64,
    pub video_frames_received: u64,
    pub audio_frames_sent: u64,
    pub audio_frames_received: u64,
    /// Observed native audio underruns/overruns; absent for uninstrumented backends.
    pub audio_device_xruns: Option<u64>,
    pub audio_deadline_misses: u64,
    pub audio_skipped_deadlines: u64,
    pub audio_max_lateness_us: u64,
    pub audio_lateness_p95_upper_us: Option<u64>,
    pub video_queue_age_p95_upper_us: Option<u64>,
    pub video_max_queue_age_us: u64,
    pub video_stale_drops: u64,
    pub video_backpressure_drops: u64,
    pub video_deadline_drops: u64,
    /// Completed video frames rejected before presentation or accounting.
    pub video_malformed_drops: u64,
    pub audio_malformed_drops: u64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SessionPhase {
    Idle,
    Checking,
    Negotiating,
    Streaming,
    Stopping,
}

impl SessionRuntimeControl {
    pub fn cancel(&self) {
        self.cancelled.store(true, Ordering::Release);
    }

    pub fn is_cancelled(&self) -> bool {
        self.cancelled.load(Ordering::Acquire)
    }

    pub fn send(&self, command: String) -> Result<(), String> {
        let mut commands = lock_unpoison(&self.commands);
        if commands.len() >= 64 {
            return Err("control queue is full".into());
        }
        commands.push_back(command);
        Ok(())
    }

    pub(super) fn drain(&self) -> Vec<String> {
        lock_unpoison(&self.commands).drain(..).collect()
    }

    pub fn phase(&self) -> SessionPhase {
        match self.phase.load(Ordering::Acquire) {
            1 => SessionPhase::Checking,
            2 => SessionPhase::Negotiating,
            3 => SessionPhase::Streaming,
            4 => SessionPhase::Stopping,
            _ => SessionPhase::Idle,
        }
    }

    pub fn activity(&self) -> RuntimeActivity {
        *lock_unpoison(&self.active)
    }

    pub fn latest_video(&self) -> Option<VideoPreview> {
        lock_unpoison(&self.latest_video)
            .as_ref()
            .map(|preview| VideoPreview {
                width: preview.width,
                height: preview.height,
                rgb: preview.rgb.to_vec(),
            })
    }

    #[cfg(any(feature = "gui", test))]
    pub(crate) fn latest_video_update(&self, generation: Option<u64>) -> VideoPreviewUpdate {
        let latest = lock_unpoison(&self.latest_video);
        match latest.as_ref() {
            None => VideoPreviewUpdate::Empty,
            Some(preview) if generation == Some(preview.generation) => {
                VideoPreviewUpdate::Unchanged
            }
            Some(preview) => VideoPreviewUpdate::Changed(preview.clone()),
        }
    }

    pub(crate) fn publish_video(&self, width: u32, height: u32, pixels: &[u8], format: &str) {
        let pixel_count = (width as usize).saturating_mul(height as usize);
        let rgb = if format.eq_ignore_ascii_case("RGB") || format.eq_ignore_ascii_case("RGB24") {
            let expected = pixel_count.saturating_mul(3);
            (pixels.len() >= expected).then(|| pixels[..expected].to_vec())
        } else {
            (pixels.len() >= pixel_count).then(|| {
                pixels[..pixel_count]
                    .iter()
                    .flat_map(|value| [*value; 3])
                    .collect()
            })
        };
        if let Some(rgb) = rgb {
            let mut latest = lock_unpoison(&self.latest_video);
            #[cfg(any(feature = "gui", test))]
            let generation = NEXT_PREVIEW_GENERATION.fetch_add(1, Ordering::Relaxed);
            *latest = Some(SharedVideoPreview {
                width,
                height,
                rgb: Arc::from(rgb),
                #[cfg(any(feature = "gui", test))]
                generation,
            });
        }
    }

    pub(super) fn set_activity(&self, result: &SessionResult) {
        *lock_unpoison(&self.active) = RuntimeActivity::from_result(result);
    }

    pub(super) fn set_phase(&self, phase: SessionPhase) {
        let value = match phase {
            SessionPhase::Idle => 0,
            SessionPhase::Checking => 1,
            SessionPhase::Negotiating => 2,
            SessionPhase::Streaming => 3,
            SessionPhase::Stopping => 4,
        };
        self.phase.store(value, Ordering::Release);
    }
}

impl Default for SessionOptions {
    fn default() -> Self {
        Self::demo()
    }
}

impl SessionOptions {
    pub fn demo() -> Self {
        Self {
            control_extras: true,
            expected_rejection: false,
            peer_reject: false,
            stream_frames: 3,
            record: false,
            record_dir: None,
            preview_dir: None,
            max_stream_width: 160,
            max_stream_height: 120,
            chat_text: "hello-rusty-lola".into(),
            catalog_path: None,
            use_catalog_geometry: true,
            apply_color: true,
            color_settings: None,
            peer_mode: "loopback".into(),
            duration_sec: None,
            interleaved_av: false,
            preview_all_frames: false,
            media_transport: None,
            pcap_device: None,
            precheck_reachable: None,
            reachability_timeout_ms: None,
            bayer_pattern: "BGGR".into(),
            auto_bayer: true,
            camera_backend: VideoBackend::Diagnostic,
            audio_backend: AudioBackend::Diagnostic,
            stream_tx_video: true,
            stream_tx_audio: true,
            stream_rx_video: true,
            stream_rx_audio: true,
            audio_only: false,
            tx_audio_level: 1,
            incomplete_frame_threshold_pct: 0.0,
            use_centered_scale: true,
            test_signal_mode: "none".into(),
            serialize_loopback: true,
            persistent: false,
            runtime_control: None,
        }
    }
}

impl SessionOptions {
    /// Validate an optional stream duration before it reaches a scheduler.
    pub fn validate_duration(&self) -> Result<(), SessionError> {
        if self
            .duration_sec
            .is_some_and(|duration| !duration.is_finite() || duration <= 0.0 || duration > 86400.0)
        {
            return Err(SessionError::Configuration(
                "duration_sec must be finite and greater than zero when set".into(),
            ));
        }
        Ok(())
    }

    /// True when test-signal mode should replace camera grab / audio with SMPTE + tone.
    pub fn test_signal_active(&self) -> bool {
        matches!(
            self.test_signal_mode.to_ascii_lowercase().as_str(),
            "send" | "receive" | "both"
        )
    }

    pub fn test_signal_send(&self) -> bool {
        matches!(
            self.test_signal_mode.to_ascii_lowercase().as_str(),
            "send" | "both"
        )
    }
}

pub(super) fn session_cancelled(options: &SessionOptions) -> bool {
    options
        .runtime_control
        .as_ref()
        .is_some_and(SessionRuntimeControl::is_cancelled)
}

#[derive(Debug, Clone, Default)]
pub struct SessionResult {
    pub states: Vec<String>,
    pub messages_sent: Vec<String>,
    pub messages_received: Vec<String>,
    pub media_frames_sent: u64,
    pub media_frames_received: u64,
    pub video_frames_sent: u64,
    pub video_frames_received: u64,
    pub audio_frames_sent: u64,
    pub audio_frames_received: u64,
    pub capabilities: BTreeMap<String, Value>,
    pub bounce_back: Option<bool>,
    pub chat_messages: Vec<String>,
    pub audio_signal_active: Option<bool>,
    pub rejected: bool,
    pub reject_text: String,
    pub compression_used: bool,
    pub jpeg_decoded_ok: bool,
    pub camera_mode_id: String,
    pub stream_frames: u32,
    pub camera_backend: String,
    pub audio_backend: String,
    pub media_transport: String,
    pub ok: bool,
    pub error: String,
    /// Typed terminal failure. `error` remains for CLI/JSON compatibility.
    pub failure: Option<SessionError>,
    pub preview_paths: Vec<String>,
    pub record_paths: Vec<String>,
    pub network_monitor: BTreeMap<String, i64>,
    pub network_monitor_report: Value,
    pub color_applied: bool,
    pub bayer_applied: bool,
    pub test_signal_applied: bool,
    pub test_signal_mode: String,
    pub reachable: Option<bool>,
    pub rtt_ms: Option<f64>,
    pub raw_plane_used: bool,
    pub peer_mode: String,
    /// Audio timing observations made by the deadline-first stream loop.
    /// Observed native audio underruns/overruns; absent for uninstrumented backends.
    pub audio_device_xruns: Option<u64>,
    pub audio_deadline_misses: u64,
    pub audio_skipped_deadlines: u64,
    pub audio_max_lateness_us: u64,
    pub audio_lateness_p95_upper_us: Option<u64>,
    pub video_queue_age_p95_upper_us: Option<u64>,
    pub video_max_queue_age_us: u64,
    pub video_stale_drops: u64,
    pub video_backpressure_drops: u64,
    pub video_deadline_drops: u64,
    /// Completed video frames rejected before presentation or accounting.
    pub video_malformed_drops: u64,
    pub audio_malformed_drops: u64,
    /// Cleanup failures retained alongside a primary session failure.
    pub cleanup_warnings: Vec<String>,
}

impl SessionResult {
    pub(super) fn peer_disconnected(&self) -> bool {
        self.messages_received
            .iter()
            .any(|message| message == "/MESG_DISCONNECT")
    }
}

pub(super) fn now_us() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_micros() as u64)
        .unwrap_or(0)
}

pub(super) fn stream_dims(full_w: u32, full_h: u32, options: &SessionOptions) -> (u32, u32) {
    let mut w = full_w;
    let mut h = full_h;
    if options.max_stream_width > 0 && w > options.max_stream_width {
        h = (h * options.max_stream_width / w).max(1);
        w = options.max_stream_width;
    }
    if options.max_stream_height > 0 && h > options.max_stream_height {
        w = (w * options.max_stream_height / h).max(1);
        h = options.max_stream_height;
    }
    (w.max(1), h.max(1))
}

pub(super) fn resolve_mode(
    settings: &StationSettings,
    options: &SessionOptions,
) -> Result<Option<CameraMode>, SessionError> {
    if !options.use_catalog_geometry {
        return Ok(None);
    }
    let path = options.catalog_path.clone().unwrap_or_else(|| {
        if settings.video.catalog_file.is_empty() {
            shipped_ximea_ini()
        } else {
            PathBuf::from(&settings.video.catalog_file)
        }
    });
    let modes = load_camera_modes(&path).map_err(|error| {
        SessionError::Configuration(format!("load camera catalog {}: {error}", path.display()))
    })?;
    find_mode(&modes, &settings.video.camera_mode_id)
        .cloned()
        .map(Some)
        .ok_or_else(|| {
            SessionError::Configuration(format!(
                "camera mode `{}` is not present in {}",
                settings.video.camera_mode_id,
                path.display()
            ))
        })
}
