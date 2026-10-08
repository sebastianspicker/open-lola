//! Non-blocking GUI connection commands and their session-option mapping.

use super::StationUIController;
use crate::config::{MediaTransportKind, VideoBackend};
#[cfg(feature = "gui")]
use crate::station::session::VideoPreviewUpdate;
use crate::station::session::{
    run_check_only, run_session, SessionOptions, SessionResult, VideoPreview,
};
use serde_json::{json, Value};
use std::path::PathBuf;
use std::sync::mpsc;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum GuiPeerMode {
    Remote,
    Listen,
    Loopback,
}

impl GuiPeerMode {
    fn parse(value: &str) -> Result<Self, String> {
        match value.trim().to_ascii_lowercase().as_str() {
            "remote" => Ok(Self::Remote),
            "listen" => Ok(Self::Listen),
            "loopback" => Ok(Self::Loopback),
            _ => Err("peer mode must be remote, listen, or loopback".into()),
        }
    }

    const fn as_str(self) -> &'static str {
        match self {
            Self::Remote => "remote",
            Self::Listen => "listen",
            Self::Loopback => "loopback",
        }
    }
}

impl StationUIController {
    /// Select the protocol role used by the next GUI session.
    pub fn set_peer_mode(&mut self, value: &str) -> Result<(), String> {
        if self.settings_are_locked() {
            return Err("runtime settings are locked while a session is active".into());
        }
        self.state.peer_mode = GuiPeerMode::parse(value)?.as_str().into();
        Ok(())
    }

    pub(super) fn session_options(
        &self,
        stream_frames: u32,
        control_extras: bool,
        apply_color: bool,
    ) -> Result<SessionOptions, String> {
        let st = &self.state;
        let mut opts = SessionOptions::demo();
        // Never inherit the demo's loopback role accidentally. This normalization
        // also prevents the station runner's unknown-mode fallback from activating.
        opts.peer_mode = GuiPeerMode::parse(&st.peer_mode)?.as_str().into();
        // GUI work is already isolated in its controller/runtime worker. A
        // process-wide diagnostic-loopback mutex would make Stop and unrelated
        // controllers wait behind another session instead of reporting a bind
        // conflict through the typed transport error path.
        opts.serialize_loopback = false;
        opts.control_extras = control_extras;
        // GUI sessions always use the deadline scheduler so a fragmented
        // video frame cannot monopolize audio or the controller thread.
        opts.interleaved_av = true;
        opts.stream_frames = stream_frames.max(1);
        // The configured capture geometry also bounds the transmitted stream.
        // The camera catalog may still choose a native capture mode, but this
        // prevents the GUI from silently retaining the demo's 160x120 cap.
        opts.max_stream_width = st.video_width;
        opts.max_stream_height = st.video_height;
        // Diagnostic cameras use the configured dimensions directly; their
        // synthetic mode IDs are intentionally absent from the Ximea catalog.
        opts.use_catalog_geometry = self.settings.video.backend == VideoBackend::Ximea;
        opts.record = st.record_enabled;
        opts.record_dir = (!st.record_path.is_empty()).then(|| PathBuf::from(&st.record_path));
        opts.preview_dir = (!st.preview_dir.is_empty()).then(|| PathBuf::from(&st.preview_dir));
        opts.apply_color = apply_color;
        let chat = st.chat_text.trim();
        opts.chat_text = if chat.is_empty() {
            st.last_chat
                .last()
                .cloned()
                .unwrap_or_else(|| "hello-rusty-lola".into())
        } else {
            chat.into()
        };
        if !st.catalog_file.is_empty() {
            opts.catalog_path = Some(PathBuf::from(&st.catalog_file));
        }
        opts.media_transport = Some(if st.raw_media_plane {
            MediaTransportKind::Npcap
        } else {
            MediaTransportKind::Udp
        });
        opts.pcap_device = (!st.pcap_device.is_empty()).then(|| st.pcap_device.clone());
        opts.precheck_reachable = Some(st.precheck_reachable);
        opts.reachability_timeout_ms = Some(st.reachability_timeout_ms);
        opts.bayer_pattern = st.bayer_pattern.clone();
        opts.auto_bayer = st.auto_bayer;
        opts.camera_backend = self.settings.video.backend;
        opts.audio_backend = self.settings.audio.backend;
        opts.stream_tx_video = *st.stream_toggles.get("tx_video").unwrap_or(&true);
        opts.stream_tx_audio = *st.stream_toggles.get("tx_audio").unwrap_or(&true);
        opts.stream_rx_video = *st.stream_toggles.get("rx_video").unwrap_or(&true);
        opts.stream_rx_audio = *st.stream_toggles.get("rx_audio").unwrap_or(&true);
        opts.audio_only = st.audio_only;
        opts.tx_audio_level = st.tx_audio_level.max(1);
        opts.incomplete_frame_threshold_pct = st.incomplete_frame_threshold_pct;
        opts.use_centered_scale = true;
        opts.test_signal_mode = if st.test_signal_active {
            if st.test_signal_send {
                "send".into()
            } else {
                "receive".into()
            }
        } else {
            "none".into()
        };
        Ok(opts)
    }

    fn apply_result(&mut self, result: &SessionResult, status: &str) -> Value {
        let report = result.to_json();
        self.state.last_result = Some(report.clone());
        if let Some(obj) = report
            .get("network_monitor")
            .and_then(|value| value.as_object())
        {
            self.state.network_monitor = obj.iter().map(|(k, v)| (k.clone(), v.clone())).collect();
        }
        self.state.bounce_back = result.bounce_back;
        self.state.status = if result.ok {
            status.into()
        } else {
            format!("error:{}", result.error)
        };
        for message in &result.chat_messages {
            if !self.state.last_chat.contains(message) {
                self.state.last_chat.push(message.clone());
            }
        }
        report
    }

    fn set_active_tab_connected(&mut self, connected: bool) {
        let tab_id = self.session_board.active_tab_id();
        let _ = self.session_board.set_connected(tab_id, connected);
        self.state.session_tabs = self.session_board.to_dict();
    }

    fn option_error(&mut self, error: String) -> Value {
        let report = json!({"ok": false, "error": error, "status": "configuration_error"});
        self.state.status = "configuration_error".into();
        self.state.last_result = Some(report.clone());
        report
    }

    /// Legacy synchronous diagnostic session, retained for headless callers.
    /// The GUI Check action deliberately uses `start_check`, not this method.
    pub fn check_status(&mut self, timeout: f64) -> Value {
        self.set_settings_from_state();
        self.state.status = "checking_protocol".into();
        let mut options = match self.session_options(1, false, false) {
            Ok(options) => options,
            Err(error) => return self.option_error(error),
        };
        // The synchronous headless compatibility check still performs the
        // complete CHECK/QUICKCONN exchange, but it must not start media.
        options.stream_tx_video = false;
        options.stream_rx_video = false;
        options.stream_tx_audio = false;
        options.stream_rx_audio = false;
        options.serialize_loopback = options.peer_mode.eq_ignore_ascii_case("loopback");
        let result = run_session(self.settings.clone(), timeout, options);
        self.apply_result(&result, if result.ok { "ready" } else { "check_failed" })
    }

    /// Begin a CHECK-only handshake and return immediately for an egui frame.
    /// The station hook verifies only the control plane: it does not negotiate
    /// QUICKCONN, open media, or initialize camera/audio backends.
    pub fn start_check(&mut self, timeout: f64) -> Value {
        if self.reachability_rx.is_some() {
            return json!({"ok": false, "pending": true, "error": "connection check is already running"});
        }
        if self.live.is_running() {
            return json!({"ok": false, "error": "live session is active"});
        }
        self.set_settings_from_state();
        let options = match self.session_options(1, false, false) {
            Ok(options) => options,
            Err(error) => return self.option_error(error),
        };
        let settings = self.settings.clone();
        let (sender, receiver) = mpsc::sync_channel(1);
        std::thread::spawn(move || {
            let _ = sender.send(run_check_only(settings, timeout, options).to_json());
        });
        self.reachability_rx = Some(receiver);
        self.check_in_progress = true;
        self.state.status = "checking_protocol".into();
        let report = json!({
            "ok": true,
            "pending": true,
            "check_kind": "control_handshake_only",
            "peer_mode": self.state.peer_mode,
            "quickconn": "not_started",
            "media": "not_started",
            "native_backends": "not_started",
            "production_ready": false,
        });
        self.state.last_result = Some(report.clone());
        report
    }

    pub fn check_pending(&self) -> bool {
        self.check_in_progress
    }

    /// Full connect via real run_session (blocking finite path).
    pub fn connect(&mut self, timeout: f64, frames: u32, extras: bool) -> Value {
        self.set_settings_from_state();
        self.state.status = "connecting".into();
        let mut options = match self.session_options(frames, extras, self.state.apply_color) {
            Ok(options) => options,
            Err(error) => return self.option_error(error),
        };
        options.serialize_loopback = options.peer_mode.eq_ignore_ascii_case("loopback");
        if !self.state.chat_text.trim().is_empty() {
            let text = self.state.chat_text.trim().to_string();
            options.chat_text = text.clone();
            if !self.state.last_chat.contains(&text) {
                self.state.last_chat.push(text);
            }
        }
        let result = run_session(self.settings.clone(), timeout, options);
        let report = self.apply_result(
            &result,
            if result.ok {
                "connected"
            } else {
                "connect_failed"
            },
        );
        self.set_active_tab_connected(result.ok);
        report
    }

    /// Start a background session without blocking the egui update thread.
    pub fn start_live(
        &mut self,
        timeout: f64,
        frames: u32,
        extras: bool,
        continuous: bool,
    ) -> Value {
        if self.check_in_progress {
            return self.option_error("a control-plane check is active".into());
        }
        self.set_settings_from_state();
        if self.live.is_running() {
            return self.live.get_report();
        }
        self.state.status = "connecting".into();
        self.state.continuous_live = continuous;
        self.state.settings_locked = true;
        self.live.update_settings(self.settings.clone());
        let options = match self.session_options(frames, extras, self.state.apply_color) {
            Ok(options) => options,
            Err(error) => {
                self.state.settings_locked = false;
                return self.option_error(error);
            }
        };
        match self
            .live
            .start(timeout, frames, extras, continuous, Some(options))
        {
            Ok(()) => {
                self.state.status = "connecting".into();
                self.set_active_tab_connected(true);
                self.live.get_report()
            }
            Err(error) => {
                let report = json!({"ok": false, "error": error, "status": "configuration_error"});
                self.state.status = "configuration_error".into();
                self.state.last_result = Some(report.clone());
                self.state.settings_locked = false;
                self.set_active_tab_connected(false);
                report
            }
        }
    }

    /// Start the configured remote or diagnostic loopback role asynchronously.
    pub fn start_connect(
        &mut self,
        timeout: f64,
        frames: u32,
        extras: bool,
        continuous: bool,
    ) -> Value {
        match GuiPeerMode::parse(&self.state.peer_mode) {
            Ok(GuiPeerMode::Listen) => self.option_error("use Listen for peer mode listen".into()),
            Ok(_) => self.start_live(timeout, frames, extras, continuous),
            Err(error) => self.option_error(error),
        }
    }

    /// Start a fixed-port listener asynchronously, regardless of the previous role.
    pub fn start_listen(&mut self, timeout: f64, extras: bool) -> Value {
        if let Err(error) = self.set_peer_mode("listen") {
            return self.option_error(error);
        }
        self.start_live(timeout, 1, extras, true)
    }

    /// Stop live session if running; otherwise mark disconnected.
    pub fn stop_live(&mut self, timeout: f64) -> Value {
        if self.live.is_running() {
            let report = self.live.stop(timeout);
            self.state.status = "disconnected".into();
            self.state.continuous_live = false;
            self.state.settings_locked = false;
            self.set_active_tab_connected(false);
            self.state.last_result = Some(report.clone());
            if let Some(monitor) = report
                .get("network_monitor")
                .and_then(|value| value.as_object())
            {
                self.state.network_monitor = monitor
                    .iter()
                    .map(|(k, v)| (k.clone(), v.clone()))
                    .collect();
            }
            return report;
        }
        self.disconnect()
    }

    /// Signal a stop without joining the worker. Intended for GUI callbacks.
    pub fn request_stop_live(&mut self) -> Value {
        let report = self.live.request_stop();
        self.state.status = "disconnecting".into();
        self.state.continuous_live = false;
        self.state.last_result = Some(report.clone());
        report
    }

    pub fn live_running(&self) -> bool {
        self.live.is_running()
    }

    pub fn live_report(&self) -> Value {
        self.live.get_report()
    }

    pub fn live_preview(&self) -> Option<VideoPreview> {
        self.live.latest_video()
    }

    #[cfg(feature = "gui")]
    pub(crate) fn live_local_preview_update(&self, generation: Option<u64>) -> VideoPreviewUpdate {
        self.live.latest_local_video_update(generation)
    }

    #[cfg(feature = "gui")]
    pub(crate) fn live_preview_update(&self, generation: Option<u64>) -> VideoPreviewUpdate {
        self.live.latest_video_update(generation)
    }

    /// Pull the runtime's immutable snapshot into display state. This does not
    /// start, stop, or otherwise mutate the transport worker.
    pub fn poll_live(&mut self) -> Value {
        let report = self.live.get_report();
        if let Some(status) = report.get("status").and_then(|value| value.as_str()) {
            self.state.status = status.into();
            if !self.live.is_running() {
                self.state.settings_locked = false;
                if status == "disconnected" {
                    self.set_active_tab_connected(false);
                }
            }
        }
        if let Some(result) = report.as_object() {
            self.state.last_result = Some(Value::Object(result.clone()));
        }
        report
    }

    pub fn settings_are_locked(&self) -> bool {
        self.check_in_progress || self.state.settings_locked || self.live.is_running()
    }

    pub fn disconnect(&mut self) -> Value {
        if self.live.is_running() {
            return self.stop_live(5.0);
        }
        self.state.status = "disconnected".into();
        self.state.continuous_live = false;
        self.state.settings_locked = false;
        self.set_active_tab_connected(false);
        json!({
            "ok": true,
            "status": "disconnected",
            "last_result": self.state.last_result,
        })
    }
}
