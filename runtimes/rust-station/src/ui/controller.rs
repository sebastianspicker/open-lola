//! Pure-logic station UI controller — fully testable without GUI.

use crate::config::{
    default_settings, load_settings, save_settings, AudioBackend, ControlDialect,
    MediaTransportKind, StationSettings, VideoBackend,
};
use crate::net::check_reachable;
use crate::station::live_session::LiveStationService;
use crate::station::monitor::NetworkMonitor;
use crate::station::tabs::SessionTabBoard;
use crate::ui::state::StationUIState;
use serde_json::{json, Value};
use std::path::{Path, PathBuf};
use std::sync::mpsc::{self, Receiver, TryRecvError};

mod connection;
mod productivity;
mod signal_desk;
pub use signal_desk::*;
pub struct RecordingSetup<'a> {
    pub mode: &'a str,
    pub path: &'a str,
    pub local_audio: bool,
    pub remote_audio: bool,
    pub local_video: bool,
    pub remote_video: bool,
    pub video_format: &'a str,
    pub enabled: Option<bool>,
}

/// Pure logic controller — binds to real run_session / settings / live service.
pub struct StationUIController {
    settings: StationSettings,
    state: StationUIState,
    session_board: SessionTabBoard,
    monitor: NetworkMonitor,
    live: LiveStationService,
    settings_path: Option<PathBuf>,
    reachability_rx: Option<Receiver<Value>>,
    check_in_progress: bool,
    ready_fingerprint: Option<u64>,
    armed_fingerprint: Option<u64>,
    signal_phase: SessionPhase,
    readiness_detail: String,
    device_snapshot: DeviceSnapshot,
    device_inventory_rx: Option<Receiver<InventoryResult>>,
    device_inventory_generation: u64,
    device_inventory_fingerprint: Option<u64>,
}

impl Default for StationUIController {
    fn default() -> Self {
        Self::new(None)
    }
}

impl StationUIController {
    pub fn new(settings: Option<StationSettings>) -> Self {
        let settings = settings.unwrap_or_else(default_settings);
        let live = LiveStationService::new(Some(settings.clone()));
        let mut ctrl = Self {
            settings,
            state: StationUIState::default(),
            session_board: SessionTabBoard::new(),
            monitor: NetworkMonitor::new(),
            live,
            settings_path: None,
            reachability_rx: None,
            check_in_progress: false,
            ready_fingerprint: None,
            armed_fingerprint: None,
            signal_phase: SessionPhase::Setup,
            readiness_detail: "Setup has not been validated".into(),
            device_snapshot: DeviceSnapshot {
                audio: InventoryState::NotMeasured,
                video: InventoryState::NotMeasured,
            },
            device_inventory_rx: None,
            device_inventory_generation: 0,
            device_inventory_fingerprint: None,
        };
        ctrl.sync_state_from_settings();
        ctrl
    }

    fn sync_state_from_settings(&mut self) {
        let s = &self.settings;
        self.state.remote_ip = s.network.remote_ip.clone();
        self.state.local_ip = s.network.local_ip.clone();
        self.state.bind_ip = s.network.bind_ip.clone();
        self.state.control_port = s.network.control_port;
        self.state.audio_port = s.network.audio_port;
        self.state.video_port = s.network.video_port;
        self.state.video_packet_size = s.network.video_packet_size;
        self.state.session_id = s.network.session_id;
        self.state.camera_mode_id = s.video.camera_mode_id.clone();
        self.state.compression = s.video.compression;
        self.state.jpeg_quality = s.video.jpeg_quality;
        self.state.video_width = s.video.width;
        self.state.video_height = s.video.height;
        self.state.video_fps = s.video.fps;
        self.state.video_bpp = s.video.bpp;
        self.state.video_bayer = s.video.bayer;
        self.state.record_enabled = s.recording.enabled;
        self.state.record_path = s.recording.path.clone();
        self.state.camera_backend = s.video.backend.to_string();
        self.state.video_device = s.video.device.clone();
        self.state.video_pixel_format = s.video.pixel_format.clone();
        self.state.audio_backend = s.audio.backend.to_string();
        self.state.buffer_samples = s.audio.buffer_samples;
        self.state.input_device = s.audio.input_device.clone();
        self.state.output_device = s.audio.output_device.clone();
        self.state.bits_per_sample = s.audio.bits_per_sample;
        self.state.catalog_file = s.video.catalog_file.clone();
        self.state.pcap_device = s.network.pcap_device.clone();
        self.state.vlan_tag = s.network.vlan_tag;
        self.state.control_dialect = match s.network.control_dialect {
            ControlDialect::Ascii => "ascii",
            ControlDialect::Osc15 => "osc15",
        }
        .into();
        self.state.raw_media_plane = s.network.media_transport == MediaTransportKind::Npcap;
        self.state.precheck_reachable = s.network.precheck_reachable;
        self.state.reachability_timeout_ms = s.network.reachability_timeout_ms;
        self.state.record_local_audio = s.recording.record_local_audio;
        self.state.record_remote_audio = s.recording.record_remote_audio;
        self.state.record_local_video = s.recording.record_local_video;
        self.state.record_remote_video = s.recording.record_remote_video;
        self.state.audio_channels = s.audio.channels;
        self.state.sample_rate = s.audio.sample_rate;
        self.state.bayer_pattern = s.video.bayer_pattern.clone();
        self.state.auto_bayer = s.video.auto_bayer;
        self.state.tx_audio_level = s.audio.tx_audio_level;
        self.state.input_offset = s.audio.input_offset;
        self.state.local_audio_loop = s.audio.local_audio_loop;
        self.state.incomplete_frame_threshold_pct = s.video.incomplete_frame_threshold_pct;
        self.state.local_camera_index = s.video.local_camera_index;
        self.state.audio_only = s.video.audio_only;
        self.state.record_mode = s.recording.mode.clone();
        self.state.record_video_format = s.recording.video_format.clone();
        self.state.audio_receive_queue_depth = s.network.audio_receive_queue_depth;
        self.state.audio_receive_prefill = s.network.audio_receive_prefill;
        self.state.video_receive_queue_depth = s.network.video_receive_queue_depth;
        self.state.video_receive_prefill = s.network.video_receive_prefill;
        self.state.session_tabs = self.session_board.to_dict();
    }

    pub fn get_state(&self) -> &StationUIState {
        &self.state
    }

    pub fn state_mut(&mut self) -> &mut StationUIState {
        &mut self.state
    }

    pub fn set_remote_ip(&mut self, ip: &str) {
        if self.settings_are_locked() {
            return;
        }
        self.state.remote_ip = if ip.trim().is_empty() {
            "127.0.0.1".into()
        } else {
            ip.trim().into()
        };
        self.settings.network.remote_ip = self.state.remote_ip.clone();
    }

    pub fn set_settings_from_state(&mut self) -> &StationSettings {
        if self.settings_are_locked() {
            return &self.settings;
        }
        let st = &self.state;
        let s = &mut self.settings;
        s.network.remote_ip = st.remote_ip.clone();
        s.network.local_ip = st.local_ip.clone();
        s.network.bind_ip = st.bind_ip.clone();
        s.network.control_port = st.control_port;
        s.network.audio_port = st.audio_port;
        s.network.video_port = st.video_port;
        s.network.video_packet_size = st.video_packet_size;
        s.network.session_id = st.session_id;
        s.video.camera_mode_id = st.camera_mode_id.clone();
        s.video.compression = st.compression;
        s.video.jpeg_quality = st.jpeg_quality;
        s.video.width = st.video_width;
        s.video.height = st.video_height;
        s.video.fps = st.video_fps;
        s.video.bpp = st.video_bpp;
        s.video.bayer = st.video_bayer;
        s.recording.enabled = st.record_enabled;
        s.recording.path = st.record_path.clone();
        s.video.backend = match st.camera_backend.trim().to_ascii_lowercase().as_str() {
            "software" | "diagnostic" => VideoBackend::Diagnostic,
            "v4l2" => VideoBackend::V4l2,
            _ => VideoBackend::Ximea,
        };
        s.audio.backend = match st.audio_backend.trim().to_ascii_lowercase().as_str() {
            "software" | "diagnostic" => AudioBackend::Diagnostic,
            "alsa" => AudioBackend::Alsa,
            _ => AudioBackend::PortAudioAsio,
        };
        s.video.device = st.video_device.clone();
        s.video.pixel_format = st.video_pixel_format.clone();
        s.audio.buffer_samples = st.buffer_samples;
        s.audio.input_device = st.input_device.clone();
        s.audio.output_device = st.output_device.clone();
        s.audio.bits_per_sample = st.bits_per_sample;
        s.video.catalog_file = st.catalog_file.clone();
        s.network.pcap_device = st.pcap_device.clone();
        s.network.vlan_tag = st.vlan_tag;
        s.network.control_dialect = match st.control_dialect.trim().to_ascii_lowercase().as_str() {
            "osc15" | "osc_15" => ControlDialect::Osc15,
            _ => ControlDialect::Ascii,
        };
        s.network.media_transport = if st.raw_media_plane {
            MediaTransportKind::Npcap
        } else {
            MediaTransportKind::Udp
        };
        s.network.raw_media_plane = false;
        s.network.use_raw_pcap = false;
        s.network.precheck_reachable = st.precheck_reachable;
        s.network.reachability_timeout_ms = st.reachability_timeout_ms;
        s.recording.record_local_audio = st.record_local_audio;
        s.recording.record_remote_audio = st.record_remote_audio;
        s.recording.record_local_video = st.record_local_video;
        s.recording.record_remote_video = st.record_remote_video;
        s.audio.channels = st.audio_channels;
        s.audio.sample_rate = st.sample_rate;
        s.video.bayer_pattern = st.bayer_pattern.clone();
        s.video.auto_bayer = st.auto_bayer;
        s.audio.tx_audio_level = st.tx_audio_level;
        s.audio.input_offset = st.input_offset;
        s.audio.local_audio_loop = st.local_audio_loop;
        s.video.incomplete_frame_threshold_pct = st.incomplete_frame_threshold_pct;
        s.video.local_camera_index = st.local_camera_index;
        s.video.audio_only = st.audio_only;
        s.recording.mode = st.record_mode.clone();
        s.recording.video_format = st.record_video_format.clone();
        s.network.audio_receive_queue_depth = st.audio_receive_queue_depth;
        s.network.audio_receive_prefill = st.audio_receive_prefill;
        s.network.video_receive_queue_depth = st.video_receive_queue_depth;
        s.network.video_receive_prefill = st.video_receive_prefill;
        s
    }

    pub fn load_settings_file(&mut self, path: impl AsRef<Path>) -> Result<(), String> {
        if self.settings_are_locked() {
            return Err("runtime settings are locked while a session is active".into());
        }
        let loaded = load_settings(path.as_ref()).map_err(|e| e.to_string())?;
        self.settings = loaded.clone();
        self.settings_path = Some(path.as_ref().to_path_buf());
        self.sync_state_from_settings();
        self.live.update_settings(loaded);
        self.state.status = "settings_loaded".into();
        Ok(())
    }

    pub fn save_settings_file(&mut self, path: impl AsRef<Path>) -> Result<(), String> {
        self.set_settings_from_state();
        save_settings(path.as_ref(), &self.settings).map_err(|e| e.to_string())?;
        self.settings_path = Some(path.as_ref().to_path_buf());
        self.state.status = "settings_saved".into();
        Ok(())
    }

    pub fn send_chat(&mut self, text: &str) -> Value {
        let t = text.trim();
        if t.is_empty() {
            return json!({"ok": false, "error": "empty chat"});
        }
        self.state.chat_text = t.into();
        if !self.state.last_chat.contains(&t.to_string()) {
            self.state.last_chat.push(t.into());
        }
        if self.live.is_running() {
            self.live.send_chat(t);
        }
        json!({
            "ok": true,
            "queued": true,
            "chat_text": t,
            "status": self.state.status,
        })
    }

    pub fn set_record_enabled(&mut self, enabled: bool, path: Option<&str>) {
        if self.settings_are_locked() {
            return;
        }
        self.state.record_enabled = enabled;
        if let Some(p) = path {
            self.state.record_path = p.into();
        }
        self.settings.recording.enabled = enabled;
        if let Some(p) = path {
            self.settings.recording.path = p.into();
        }
    }

    pub fn select_tab(&mut self, tab_id: i32) -> Result<Value, String> {
        let tab_json = {
            let tab = self.session_board.select(tab_id)?;
            self.state.session_id = tab.session_id;
            self.state.remote_ip = tab.remote_ip.clone();
            self.settings.network.session_id = tab.session_id;
            self.settings.network.remote_ip = tab.remote_ip.clone();
            tab.to_json()
        };
        self.state.session_tabs = self.session_board.to_dict();
        Ok(tab_json)
    }

    pub fn enable_tab(&mut self, tab_id: i32, enabled: bool) -> Result<(), String> {
        self.session_board.set_enabled(tab_id, enabled)?;
        self.state.session_tabs = self.session_board.to_dict();
        Ok(())
    }

    pub fn probe_reachability(&mut self) -> Value {
        let r = check_reachable(&self.state.remote_ip, self.state.reachability_timeout_ms, 1);
        self.state.reachable = Some(r.ok);
        self.state.rtt_ms = r.rtt_ms;
        r.to_json()
    }

    /// Start a reachability probe without blocking the egui update thread.
    pub fn start_reachability_probe(&mut self) -> Value {
        if self.reachability_rx.is_some() {
            return json!({"ok": true, "pending": true});
        }
        let host = self.state.remote_ip.clone();
        let timeout_ms = self.state.reachability_timeout_ms;
        let (tx, rx) = mpsc::sync_channel(1);
        std::thread::spawn(move || {
            let _ = tx.send(check_reachable(&host, timeout_ms, 1).to_json());
        });
        self.reachability_rx = Some(rx);
        json!({"ok": true, "pending": true})
    }

    /// Poll the background reachability probe and apply its immutable result.
    pub fn poll_reachability(&mut self) -> Option<Value> {
        let result = match self.reachability_rx.as_ref()?.try_recv() {
            Ok(result) => result,
            Err(TryRecvError::Empty) => return None,
            Err(TryRecvError::Disconnected) => {
                self.reachability_rx = None;
                self.check_in_progress = false;
                return Some(
                    json!({"ok": false, "reason": "connection check worker disconnected"}),
                );
            }
        };
        self.reachability_rx = None;
        self.state.reachable = result.get("ok").and_then(Value::as_bool);
        self.state.rtt_ms = result.get("rtt_ms").and_then(Value::as_f64);
        if self.check_in_progress {
            self.check_in_progress = false;
            let ok = result.get("ok").and_then(Value::as_bool).unwrap_or(false);
            self.state.status = if ok {
                "check_passed_not_streaming"
            } else {
                "check_failed"
            }
            .into();
            let report = json!({
                "ok": ok,
                "check_kind": "control_handshake_only",
                "protocol_handshake": "completed",
                "production_ready": false,
                "peer_mode": self.state.peer_mode,
                "quickconn": "not_started",
                "media": "not_started",
                "native_backends": "not_started",
                "check_result": result,
            });
            self.state.last_result = Some(report.clone());
            return Some(report);
        }
        Some(result)
    }
}
