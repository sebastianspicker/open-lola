use super::{RecordingSetup, StationUIController};
use crate::config::StationSettings;
use crate::net::MediaKind;
use crate::station::av_productivity::{
    estimate_tx_bandwidth_mbps, layout_geometry, multi_camera_index, set_process_priority,
};
use crate::station::monitor::StreamDirection;
use crate::station::tabs::SessionTabBoard;
use serde_json::{json, Map, Value};

impl StationUIController {
    // ---- Productivity helpers -------------------------------------------

    pub fn estimate_bandwidth(&mut self) -> f64 {
        let s = &self.settings;
        let mbps = estimate_tx_bandwidth_mbps(
            s.video.width,
            s.video.height,
            f64::from(s.video.fps),
            s.video.bpp,
            s.video.compression,
            s.video.jpeg_quality,
        );
        self.state.estimated_tx_mbps = mbps;
        mbps
    }

    pub fn set_tx_audio_level(&mut self, level: u8) {
        if self.settings_are_locked() {
            return;
        }
        let lvl = level.clamp(1, 2);
        self.state.tx_audio_level = lvl;
        self.settings.audio.tx_audio_level = lvl;
    }

    pub fn set_local_camera(&mut self, index: i32) -> u32 {
        if self.settings_are_locked() {
            return self.state.local_camera_index;
        }
        let idx = multi_camera_index(index, 4);
        self.state.local_camera_index = idx;
        self.settings.video.local_camera_index = idx;
        idx
    }

    pub fn set_process_priority_level(&mut self, level: &str) -> String {
        let applied = set_process_priority(level);
        if applied == "invalid" {
            return applied;
        }
        let name = level.trim().to_ascii_lowercase().replace(' ', "_");
        let name = if matches!(name.as_str(), "normal" | "above_normal" | "high" | "idle") {
            name
        } else {
            "normal".into()
        };
        self.state.process_priority = if applied != "unsupported" {
            applied.clone()
        } else {
            name
        };
        self.state.process_priority.clone()
    }

    pub fn layout_windows(&mut self, mode: &str) -> Value {
        let geom = layout_geometry(mode, 1920, 1080);
        self.state.layout_mode = geom
            .get("mode")
            .and_then(|v| v.as_str())
            .unwrap_or(mode)
            .to_string();
        self.state.layout_geometry = geom.clone();
        geom
    }

    pub fn set_stream_toggle(
        &mut self,
        direction: &str,
        kind: &str,
        enabled: bool,
    ) -> Result<(), String> {
        if self.settings_are_locked() {
            return Err("runtime settings are locked while a session is active".into());
        }
        let direction: StreamDirection = direction.parse().map_err(str::to_owned)?;
        let kind = match kind.trim().to_ascii_lowercase().as_str() {
            "audio" => MediaKind::Audio,
            "video" => MediaKind::Video,
            _ => return Err("media kind must be audio or video".into()),
        };
        self.monitor.set_stream_enabled(direction, kind, enabled);
        let direction_name = match direction {
            StreamDirection::Transmit => "tx",
            StreamDirection::Receive => "rx",
        };
        let kind_name = match kind {
            MediaKind::Audio => "audio",
            MediaKind::Video => "video",
        };
        let key = format!("{direction_name}_{kind_name}");
        self.state.stream_toggles.insert(key, enabled);
        Ok(())
    }

    pub fn set_recording_setup(&mut self, setup: RecordingSetup<'_>) -> Value {
        let RecordingSetup {
            mode,
            path,
            local_audio,
            remote_audio,
            local_video,
            remote_video,
            video_format,
            enabled,
        } = setup;
        if self.settings_are_locked() {
            return json!({"ok": false, "error": "runtime settings are locked while a session is active"});
        }
        let mut m = mode.trim().to_ascii_lowercase();
        if m == "audio+video" {
            m = "av".into();
        }
        if m == "audio_only" {
            m = "audio".into();
        }
        if m == "video_only" {
            m = "video".into();
        }
        if !matches!(m.as_str(), "av" | "audio" | "video") {
            m = "av".into();
        }
        self.state.record_mode = m.clone();
        if !path.is_empty() {
            self.state.record_path = path.into();
        }
        self.state.record_local_audio = local_audio;
        self.state.record_remote_audio = remote_audio;
        self.state.record_local_video = local_video;
        self.state.record_remote_video = remote_video;
        let fmt = video_format.to_ascii_lowercase();
        self.state.record_video_format = fmt.clone();
        let en = enabled.unwrap_or(true);
        self.state.record_enabled = en;
        self.settings.recording.enabled = en;
        self.settings.recording.path = self.state.record_path.clone();
        self.settings.recording.record_local_audio = local_audio;
        self.settings.recording.record_remote_audio = remote_audio;
        self.settings.recording.record_local_video = local_video;
        self.settings.recording.record_remote_video = remote_video;
        self.settings.recording.mode = m.clone();
        self.settings.recording.video_format = fmt.clone();
        json!({
            "mode": m,
            "path": self.state.record_path,
            "record_local_audio": local_audio,
            "record_remote_audio": remote_audio,
            "record_local_video": local_video,
            "record_remote_video": remote_video,
            "video_format": fmt,
            "enabled": en,
        })
    }

    /// Enable A/V test-signal mode (689/750 Hz −12 dBFS + SMPTE on stream path).
    ///
    /// This only updates the configuration for the next session and therefore
    /// returns immediately. Runtime-affecting settings remain immutable while
    /// a session is active.
    pub fn start_test_signals(&mut self, send: bool) -> Value {
        if self.settings_are_locked() {
            return json!({
                "ok": false,
                "error": "runtime settings are locked while a session is active",
                "test_signal_active": self.state.test_signal_active,
            });
        }
        self.state.test_signal_active = true;
        self.state.test_signal_send = send;
        self.state.status = if send {
            "test_signals".into()
        } else {
            "test_signals_rx".into()
        };
        self.live.set_test_signals(send);
        json!({
            "ok": true,
            "test_signal_active": true,
            "send": send,
            "applies_to": "next_session",
        })
    }

    pub fn stop_test_signals(&mut self) -> Value {
        self.state.test_signal_active = false;
        if matches!(
            self.state.status.as_str(),
            "test_signals" | "test_signals_rx"
        ) {
            self.state.status = "idle".into();
        }
        self.live.clear_test_signals();
        json!({"ok": true, "test_signal_active": false})
    }

    pub fn productivity_report_fields(&self) -> Value {
        let leds: Map<String, Value> = [1i32, 2, 3]
            .into_iter()
            .filter_map(|id| {
                self.session_board
                    .led(id)
                    .ok()
                    .map(|led| (id.to_string(), json!(led.as_str())))
            })
            .collect();
        json!({
            "audio_channels": self.state.audio_channels,
            "input_offset": self.state.input_offset,
            "tx_audio_level": self.state.tx_audio_level,
            "sample_rate": self.state.sample_rate,
            "local_audio_loop": self.state.local_audio_loop,
            "bayer_pattern": self.state.bayer_pattern,
            "auto_bayer": self.state.auto_bayer,
            "incomplete_frame_threshold_pct": self.state.incomplete_frame_threshold_pct,
            "audio_receive_queue_depth": self.state.audio_receive_queue_depth,
            "audio_receive_prefill": self.state.audio_receive_prefill,
            "video_receive_queue_depth": self.state.video_receive_queue_depth,
            "video_receive_prefill": self.state.video_receive_prefill,
            "local_camera_index": self.state.local_camera_index,
            "estimated_tx_mbps": self.state.estimated_tx_mbps,
            "session_tabs": self.state.session_tabs,
            "stream_toggles": self.state.stream_toggles,
            "tab_leds": leds,
            "process_priority": self.state.process_priority,
            "layout_mode": self.state.layout_mode,
            "layout_geometry": self.state.layout_geometry,
            "audio_only": self.state.audio_only,
            "test_signal_active": self.state.test_signal_active,
            "record_mode": self.state.record_mode,
            "record_local_audio": self.state.record_local_audio,
            "record_remote_audio": self.state.record_remote_audio,
            "video_format": self.state.record_video_format,
            "record_video_format": self.state.record_video_format,
            "continuous_live": self.state.continuous_live,
            "live_running": self.live.is_running(),
        })
    }

    pub fn get_report(&self) -> Value {
        let mut base = json!({
            "ok": self.state.status == "connected"
                || self.state.status == "ready"
                || self.state.status == "streaming",
            "status": self.state.status,
            "state": self.state.to_json(),
            "last_result": self.state.last_result,
            "session_tabs": self.session_board.to_dict(),
        });
        if let Value::Object(ref mut m) = base {
            if let Value::Object(prod) = self.productivity_report_fields() {
                for (k, v) in prod {
                    m.insert(k, v);
                }
            }
        }
        base
    }

    pub fn settings(&self) -> &StationSettings {
        &self.settings
    }

    pub fn board(&self) -> &SessionTabBoard {
        &self.session_board
    }

    /// Headless CLI entry: run check and/or connect, emit JSON.
    pub fn run_headless(
        &mut self,
        run_check: bool,
        run_connect: bool,
        timeout: f64,
        frames: u32,
    ) -> Value {
        let mut out = Map::new();
        out.insert("headless".into(), json!(true));
        out.insert("remote_ip".into(), json!(self.state.remote_ip));
        if run_check {
            let r = self.check_status(timeout);
            out.insert("check".into(), r);
        }
        if run_connect {
            let r = self.connect(timeout, frames, true);
            out.insert("connect".into(), r);
        }
        if !run_check && !run_connect {
            out.insert("state".into(), self.state.to_json());
            out.insert("ok".into(), json!(true));
        } else {
            let check_ok = out
                .get("check")
                .and_then(|v| v.get("ok"))
                .and_then(|v| v.as_bool())
                .unwrap_or(true);
            let connect_ok = out
                .get("connect")
                .and_then(|v| v.get("ok"))
                .and_then(|v| v.as_bool())
                .unwrap_or(true);
            out.insert("ok".into(), json!(check_ok && connect_ok));
        }
        // Productivity snapshot always present
        out.insert("productivity".into(), self.productivity_report_fields());
        Value::Object(out)
    }
}
