//! Station UI state dataclass.

use serde::Serialize;
use serde_json::{json, Map, Value};
use std::collections::BTreeMap;

#[derive(Debug, Clone)]
pub struct StationUIState {
    pub remote_ip: String,
    pub local_ip: String,
    pub bind_ip: String,
    /// Validated by `StationUIController::set_peer_mode` before a session starts.
    pub peer_mode: String,
    pub control_port: u16,
    pub audio_port: u16,
    pub video_port: u16,
    pub video_packet_size: u32,
    pub session_id: i64,
    pub camera_mode_id: String,
    pub compression: bool,
    pub jpeg_quality: u8,
    pub video_width: u32,
    pub video_height: u32,
    pub video_fps: u32,
    pub video_bpp: u32,
    pub video_bayer: u32,
    pub record_enabled: bool,
    pub record_path: String,
    pub preview_dir: String,
    pub apply_color: bool,
    pub chat_text: String,
    pub last_chat: Vec<String>,
    pub network_monitor: BTreeMap<String, Value>,
    pub last_result: Option<Value>,
    pub status: String,
    pub bounce_back: Option<bool>,
    pub camera_backend: String,
    pub video_device: String,
    pub video_pixel_format: String,
    pub audio_backend: String,
    pub buffer_samples: u32,
    pub input_device: String,
    pub output_device: String,
    pub bits_per_sample: u16,
    pub catalog_file: String,
    pub pcap_device: String,
    pub vlan_tag: Option<u16>,
    pub control_dialect: String,
    pub raw_media_plane: bool,
    pub precheck_reachable: bool,
    pub reachability_timeout_ms: u32,
    pub record_local_audio: bool,
    pub record_remote_audio: bool,
    pub record_local_video: bool,
    pub record_remote_video: bool,
    pub reachable: Option<bool>,
    pub rtt_ms: Option<f64>,
    pub audio_channels: u16,
    pub sample_rate: u32,
    pub bayer_pattern: String,
    pub auto_bayer: bool,
    pub session_tabs: Value,
    pub stream_toggles: BTreeMap<String, bool>,
    // Productivity fields
    pub tx_audio_level: u8,
    pub input_offset: u32,
    pub local_audio_loop: bool,
    pub incomplete_frame_threshold_pct: f64,
    pub local_camera_index: u32,
    pub audio_only: bool,
    pub record_mode: String,
    pub record_video_format: String,
    pub estimated_tx_mbps: f64,
    pub audio_receive_queue_depth: u32,
    pub audio_receive_prefill: u32,
    pub video_receive_queue_depth: u32,
    pub video_receive_prefill: u32,
    pub process_priority: String,
    pub layout_mode: String,
    pub layout_geometry: Value,
    pub test_signal_active: bool,
    pub test_signal_send: bool,
    pub continuous_live: bool,
    /// Settings are immutable for the duration of an active runtime lifecycle.
    pub settings_locked: bool,
}

macro_rules! insert_state {
    ($map:ident, $state:ident, $($field:ident),+ $(,)?) => {
        $(
            $map.insert(stringify!($field).into(), json_value(&$state.$field));
        )+
    };
}

impl Default for StationUIState {
    fn default() -> Self {
        let mut stream_toggles = BTreeMap::new();
        stream_toggles.insert("tx_video".into(), true);
        stream_toggles.insert("tx_audio".into(), true);
        stream_toggles.insert("rx_video".into(), true);
        stream_toggles.insert("rx_audio".into(), true);
        Self {
            remote_ip: "127.0.0.1".into(),
            local_ip: "127.0.0.1".into(),
            bind_ip: "0.0.0.0".into(),
            // Controller-only and headless tests retain an explicit diagnostic
            // loopback default. `StationApp` selects remote for the production GUI.
            peer_mode: "loopback".into(),
            control_port: 7000,
            audio_port: 19788,
            video_port: 19798,
            video_packet_size: 1000,
            session_id: 1,
            camera_mode_id: "009".into(),
            compression: false,
            jpeg_quality: 80,
            video_width: 1280,
            video_height: 720,
            video_fps: 60,
            video_bpp: 8,
            video_bayer: 1,
            record_enabled: false,
            record_path: String::new(),
            preview_dir: String::new(),
            apply_color: true,
            chat_text: String::new(),
            last_chat: Vec::new(),
            network_monitor: BTreeMap::new(),
            last_result: None,
            status: "idle".into(),
            bounce_back: None,
            camera_backend: "auto".into(),
            video_device: String::new(),
            video_pixel_format: String::new(),
            audio_backend: "auto".into(),
            buffer_samples: 64,
            input_device: String::new(),
            output_device: String::new(),
            bits_per_sample: 16,
            catalog_file: String::new(),
            pcap_device: String::new(),
            vlan_tag: None,
            control_dialect: "ascii".into(),
            raw_media_plane: false,
            precheck_reachable: false,
            reachability_timeout_ms: 1000,
            record_local_audio: true,
            record_remote_audio: true,
            record_local_video: true,
            record_remote_video: true,
            reachable: None,
            rtt_ms: None,
            audio_channels: 2,
            sample_rate: 44_100,
            bayer_pattern: "BGGR".into(),
            auto_bayer: true,
            session_tabs: json!({}),
            stream_toggles,
            tx_audio_level: 1,
            input_offset: 0,
            local_audio_loop: false,
            incomplete_frame_threshold_pct: 0.0,
            local_camera_index: 0,
            audio_only: false,
            record_mode: "av".into(),
            record_video_format: "jpg".into(),
            estimated_tx_mbps: 0.0,
            audio_receive_queue_depth: 4,
            audio_receive_prefill: 0,
            video_receive_queue_depth: 1,
            video_receive_prefill: 0,
            process_priority: "normal".into(),
            layout_mode: "tile_v".into(),
            layout_geometry: json!({}),
            test_signal_active: false,
            test_signal_send: true,
            continuous_live: false,
            settings_locked: false,
        }
    }
}

impl StationUIState {
    pub fn to_json(&self) -> Value {
        let mut state = Map::new();
        insert_state!(
            state,
            self,
            remote_ip,
            local_ip,
            bind_ip,
            peer_mode,
            control_port,
            audio_port,
            video_port,
            video_packet_size,
            session_id
        );
        insert_state!(
            state,
            self,
            camera_mode_id,
            compression,
            jpeg_quality,
            video_width,
            video_height,
            video_fps,
            video_bpp,
            video_bayer
        );
        insert_state!(
            state,
            self,
            record_enabled,
            record_path,
            preview_dir,
            apply_color,
            chat_text,
            last_chat,
            network_monitor,
            last_result,
            status,
            bounce_back
        );
        insert_state!(
            state,
            self,
            camera_backend,
            video_device,
            video_pixel_format,
            audio_backend,
            input_device,
            output_device,
            bits_per_sample,
            buffer_samples,
            audio_channels,
            sample_rate,
            input_offset,
            local_audio_loop
        );
        insert_state!(
            state,
            self,
            session_tabs,
            reachable,
            rtt_ms,
            bayer_pattern,
            auto_bayer,
            catalog_file,
            pcap_device,
            vlan_tag,
            control_dialect,
            precheck_reachable,
            reachability_timeout_ms
        );
        insert_state!(
            state,
            self,
            tx_audio_level,
            estimated_tx_mbps,
            local_camera_index,
            stream_toggles,
            layout_mode,
            process_priority,
            record_mode,
            record_video_format
        );
        insert_state!(
            state,
            self,
            record_local_audio,
            record_remote_audio,
            record_local_video,
            record_remote_video,
            audio_only,
            incomplete_frame_threshold_pct,
            continuous_live,
            test_signal_active,
            settings_locked
        );
        insert_state!(
            state,
            self,
            audio_receive_queue_depth,
            audio_receive_prefill,
            video_receive_queue_depth,
            video_receive_prefill
        );
        state.insert(
            "media_transport".into(),
            json_value(if self.raw_media_plane { "npcap" } else { "udp" }),
        );
        state.insert("persisted_settings".into(), self.persisted_settings_json());
        Value::Object(state)
    }

    pub(crate) fn configuration_json(&self) -> Value {
        json!({
            "persisted_settings": self.persisted_settings_json(),
            "peer_mode": self.peer_mode,
            "preview_dir": self.preview_dir,
            "apply_color": self.apply_color,
            "stream_toggles": self.stream_toggles,
            "test_signal_active": self.test_signal_active,
            "test_signal_send": self.test_signal_send,
        })
    }

    fn persisted_settings_json(&self) -> Value {
        let mut root = Map::new();
        root.insert("audio".into(), self.audio_settings_json());
        root.insert("video".into(), self.video_settings_json());
        root.insert("network".into(), self.network_settings_json());
        root.insert("recording".into(), self.recording_settings_json());
        Value::Object(root)
    }

    fn audio_settings_json(&self) -> Value {
        let mut section = Map::new();
        insert_state!(
            section,
            self,
            input_device,
            output_device,
            sample_rate,
            bits_per_sample,
            buffer_samples,
            audio_backend,
            tx_audio_level,
            input_offset,
            local_audio_loop
        );
        section.insert("channels".into(), json_value(&self.audio_channels));
        section.insert("backend".into(), json_value(&self.audio_backend));
        Value::Object(section)
    }

    fn video_settings_json(&self) -> Value {
        let mut section = Map::new();
        insert_state!(
            section,
            self,
            camera_mode_id,
            compression,
            jpeg_quality,
            camera_backend,
            catalog_file,
            bayer_pattern,
            auto_bayer,
            audio_only,
            local_camera_index,
            incomplete_frame_threshold_pct
        );
        section.insert("width".into(), json_value(&self.video_width));
        section.insert("height".into(), json_value(&self.video_height));
        section.insert("fps".into(), json_value(&self.video_fps));
        section.insert("bpp".into(), json_value(&self.video_bpp));
        section.insert("bayer".into(), json_value(&self.video_bayer));
        section.insert("backend".into(), json_value(&self.camera_backend));
        section.insert("device".into(), json_value(&self.video_device));
        section.insert("pixel_format".into(), json_value(&self.video_pixel_format));
        Value::Object(section)
    }

    fn network_settings_json(&self) -> Value {
        let mut section = Map::new();
        insert_state!(
            section,
            self,
            control_port,
            audio_port,
            video_port,
            video_packet_size,
            bind_ip,
            local_ip,
            remote_ip,
            session_id,
            pcap_device,
            vlan_tag,
            control_dialect,
            precheck_reachable,
            reachability_timeout_ms,
            audio_receive_queue_depth,
            audio_receive_prefill,
            video_receive_queue_depth,
            video_receive_prefill
        );
        section.insert(
            "media_transport".into(),
            json_value(if self.raw_media_plane { "npcap" } else { "udp" }),
        );
        Value::Object(section)
    }

    fn recording_settings_json(&self) -> Value {
        let mut section = Map::new();
        insert_state!(
            section,
            self,
            record_enabled,
            record_path,
            record_local_audio,
            record_remote_audio,
            record_local_video,
            record_remote_video,
            record_mode
        );
        section.insert("enabled".into(), json_value(&self.record_enabled));
        section.insert("path".into(), json_value(&self.record_path));
        section.insert("mode".into(), json_value(&self.record_mode));
        section.insert("video_format".into(), json_value(&self.record_video_format));
        Value::Object(section)
    }
}

fn json_value<T: Serialize + ?Sized>(value: &T) -> Value {
    serde_json::to_value(value).unwrap_or(Value::Null)
}
