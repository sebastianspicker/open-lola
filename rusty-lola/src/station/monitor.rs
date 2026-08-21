//! Network monitor counters for station media send/recv/drop/FPS stats.

use crate::net::MediaKind;
use crate::protocol::serial_u32_is_newer;
use serde_json::{json, Value};
use std::str::FromStr;
use std::time::Instant;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum StreamDirection {
    Transmit,
    Receive,
}

impl FromStr for StreamDirection {
    type Err = &'static str;

    fn from_str(value: &str) -> Result<Self, Self::Err> {
        match value.trim().to_ascii_lowercase().as_str() {
            "tx" | "out" | "outbound" | "send" => Ok(Self::Transmit),
            "rx" | "in" | "inbound" | "receive" => Ok(Self::Receive),
            _ => Err("direction must be tx or rx"),
        }
    }
}

/// Track media frame counters for network monitoring (FPS/drops UI, reports).
#[derive(Debug, Clone)]
pub struct NetworkMonitor {
    pub frames_sent: u32,
    pub frames_received: u32,
    pub video_sent: u32,
    pub video_received: u32,
    pub audio_sent: u32,
    pub audio_received: u32,
    pub drops: u32,
    pub reordered: u32,
    pub rtt_ms: f64,
    pub jitter_ms: f64,
    pub video_fps: f64,
    pub audio_fps: f64,
    pub tx_video_enabled: bool,
    pub tx_audio_enabled: bool,
    pub rx_video_enabled: bool,
    pub rx_audio_enabled: bool,
    pub local_fps_settings: f64,
    pub remote_fps_settings: f64,
    pub realigned_buffers: u32,
    t0: Instant,
    last_recv_t: Option<Instant>,
    last_video_seq: Option<u32>,
    last_audio_seq: Option<u32>,
}

impl Default for NetworkMonitor {
    fn default() -> Self {
        Self::new()
    }
}

impl NetworkMonitor {
    pub fn new() -> Self {
        Self {
            frames_sent: 0,
            frames_received: 0,
            video_sent: 0,
            video_received: 0,
            audio_sent: 0,
            audio_received: 0,
            drops: 0,
            reordered: 0,
            rtt_ms: 0.0,
            jitter_ms: 0.0,
            video_fps: 0.0,
            audio_fps: 0.0,
            tx_video_enabled: true,
            tx_audio_enabled: true,
            rx_video_enabled: true,
            rx_audio_enabled: true,
            local_fps_settings: 0.0,
            remote_fps_settings: 0.0,
            realigned_buffers: 0,
            t0: Instant::now(),
            last_recv_t: None,
            last_video_seq: None,
            last_audio_seq: None,
        }
    }

    fn elapsed(&self) -> f64 {
        self.t0.elapsed().as_secs_f64().max(1e-6)
    }

    fn refresh_fps(&mut self) {
        let e = self.elapsed();
        self.video_fps = if self.video_received > 0 {
            f64::from(self.video_received) / e
        } else {
            f64::from(self.video_sent) / e
        };
        self.audio_fps = if self.audio_received > 0 {
            f64::from(self.audio_received) / e
        } else {
            f64::from(self.audio_sent) / e
        };
    }

    pub fn set_stream_enabled(
        &mut self,
        direction: StreamDirection,
        kind: MediaKind,
        enabled: bool,
    ) {
        match (direction, kind) {
            (StreamDirection::Transmit, MediaKind::Audio) => self.tx_audio_enabled = enabled,
            (StreamDirection::Transmit, MediaKind::Video) => self.tx_video_enabled = enabled,
            (StreamDirection::Receive, MediaKind::Audio) => self.rx_audio_enabled = enabled,
            (StreamDirection::Receive, MediaKind::Video) => self.rx_video_enabled = enabled,
        }
    }

    pub fn is_stream_enabled(&self, direction: StreamDirection, kind: MediaKind) -> bool {
        match (direction, kind) {
            (StreamDirection::Transmit, MediaKind::Audio) => self.tx_audio_enabled,
            (StreamDirection::Transmit, MediaKind::Video) => self.tx_video_enabled,
            (StreamDirection::Receive, MediaKind::Audio) => self.rx_audio_enabled,
            (StreamDirection::Receive, MediaKind::Video) => self.rx_video_enabled,
        }
    }

    pub fn note_send(&mut self, kind: MediaKind) {
        if !self.is_stream_enabled(StreamDirection::Transmit, kind) {
            return;
        }
        self.frames_sent += 1;
        match kind {
            MediaKind::Audio => self.audio_sent += 1,
            MediaKind::Video => self.video_sent += 1,
        }
        self.refresh_fps();
    }

    pub fn note_recv(&mut self, kind: MediaKind, seq: Option<u32>) {
        if !self.is_stream_enabled(StreamDirection::Receive, kind) {
            return;
        }
        let now = Instant::now();
        if let Some(last) = self.last_recv_t {
            let delta_ms = now.duration_since(last).as_secs_f64() * 1000.0;
            if self.jitter_ms <= 0.0 {
                self.jitter_ms = delta_ms;
            } else {
                self.jitter_ms = 0.8 * self.jitter_ms + 0.2 * (delta_ms - self.jitter_ms).abs();
            }
        }
        self.last_recv_t = Some(now);
        self.frames_received += 1;
        match kind {
            MediaKind::Audio => {
                self.audio_received += 1;
                if let Some(sequence) = seq {
                    Self::note_sequence(
                        &mut self.last_audio_seq,
                        sequence,
                        &mut self.drops,
                        &mut self.reordered,
                    );
                }
            }
            MediaKind::Video => {
                self.video_received += 1;
                if let Some(sequence) = seq {
                    Self::note_sequence(
                        &mut self.last_video_seq,
                        sequence,
                        &mut self.drops,
                        &mut self.reordered,
                    );
                }
            }
        }
        self.refresh_fps();
    }

    fn note_sequence(
        previous: &mut Option<u32>,
        candidate: u32,
        drops: &mut u32,
        reordered: &mut u32,
    ) {
        let Some(reference) = *previous else {
            *previous = Some(candidate);
            return;
        };
        if serial_u32_is_newer(candidate, reference) {
            let missing = candidate.wrapping_sub(reference).saturating_sub(1);
            *drops = drops.saturating_add(missing);
            *previous = Some(candidate);
        } else if candidate != reference {
            *reordered = reordered.saturating_add(1);
        }
    }

    pub fn note_rtt(&mut self, rtt_ms: f64) {
        self.rtt_ms = rtt_ms;
    }

    pub fn note_drop(&mut self, n: u32) {
        self.drops = self.drops.saturating_add(n);
    }

    /// Jitter class string for reports (stable buckets).
    pub fn jitter_class(&self) -> &'static str {
        if self.jitter_ms < 5.0 {
            "excellent"
        } else if self.jitter_ms < 20.0 {
            "good"
        } else if self.jitter_ms < 50.0 {
            "fair"
        } else {
            "poor"
        }
    }

    pub fn to_report(&self) -> Value {
        json!({
            "frames_sent": self.frames_sent,
            "frames_received": self.frames_received,
            "video_sent": self.video_sent,
            "video_received": self.video_received,
            "audio_sent": self.audio_sent,
            "audio_received": self.audio_received,
            "drops": self.drops,
            "reordered": self.reordered,
            "rtt_ms": self.rtt_ms,
            "jitter_ms": self.jitter_ms,
            "jitter_class": self.jitter_class(),
            "video_fps": self.video_fps,
            "audio_fps": self.audio_fps,
            "tx_video_enabled": self.tx_video_enabled,
            "tx_audio_enabled": self.tx_audio_enabled,
            "rx_video_enabled": self.rx_video_enabled,
            "rx_audio_enabled": self.rx_audio_enabled,
            "local_fps_settings": self.local_fps_settings,
            "remote_fps_settings": self.remote_fps_settings,
            "realigned_buffers": self.realigned_buffers,
        })
    }

    /// Integer-oriented map used by SessionResult.network_monitor in Python.
    pub fn to_int_map(&self) -> std::collections::BTreeMap<String, i64> {
        let mut m = std::collections::BTreeMap::new();
        m.insert("frames_sent".into(), self.frames_sent as i64);
        m.insert("frames_received".into(), self.frames_received as i64);
        m.insert("video_sent".into(), self.video_sent as i64);
        m.insert("video_received".into(), self.video_received as i64);
        m.insert("audio_sent".into(), self.audio_sent as i64);
        m.insert("audio_received".into(), self.audio_received as i64);
        m.insert("drops".into(), self.drops as i64);
        m.insert("reordered".into(), self.reordered as i64);
        m.insert("rtt_ms".into(), self.rtt_ms.round() as i64);
        m.insert("jitter_ms".into(), self.jitter_ms.round() as i64);
        m.insert("video_fps".into(), self.video_fps.round() as i64);
        m.insert("audio_fps".into(), self.audio_fps.round() as i64);
        m
    }
}
