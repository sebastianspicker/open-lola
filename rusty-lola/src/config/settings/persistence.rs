use super::types::*;
use super::{
    MAX_AUDIO_PCM_BYTES, MAX_FRAME_BYTES, MAX_SESSION_QUEUE_BYTES, SETTINGS_SCHEMA_VERSION,
};
use serde::{Deserialize, Deserializer};
use std::fmt;
use std::fs;
use std::net::Ipv4Addr;
use std::path::Path;
use thiserror::Error;

#[derive(Deserialize)]
struct SettingsWire {
    #[serde(default)]
    schema_version: u32,
    #[serde(default)]
    audio: AudioSettings,
    #[serde(default)]
    video: VideoSettings,
    #[serde(default)]
    network: NetworkSettings,
    #[serde(default)]
    recording: RecordingSettings,
}

impl<'de> Deserialize<'de> for StationSettings {
    fn deserialize<D: Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        let wire = SettingsWire::deserialize(deserializer)?;
        // Version 0/1 had string backends. Their enum deserializers accept all
        // shipped spellings, and `auto` normalizes to the explicit backend on
        // the next save.
        if wire.schema_version > SETTINGS_SCHEMA_VERSION {
            return Err(serde::de::Error::custom(format!(
                "settings schema {} is newer than supported schema {SETTINGS_SCHEMA_VERSION}",
                wire.schema_version
            )));
        }
        let mut audio = wire.audio;
        if audio.input_device.is_empty() {
            audio.input_device.clone_from(&audio.device);
        }
        if audio.output_device.is_empty() {
            audio.output_device.clone_from(&audio.device);
        }
        audio.device.clear();

        let mut network = wire.network;
        if network.pcap_device.is_empty() {
            network.pcap_device.clone_from(&network.nic_name);
        }
        network.nic_name.clear();
        if network.raw_media_plane || network.use_raw_pcap {
            network.media_transport = MediaTransportKind::Npcap;
        }
        network.raw_media_plane = false;
        network.use_raw_pcap = false;
        if network.receive_queue_depth > 0 {
            network.audio_receive_queue_depth = network.receive_queue_depth;
            network.video_receive_queue_depth = network.receive_queue_depth;
        }
        if network.receive_prefill > 0 {
            network.audio_receive_prefill = network.receive_prefill;
            network.video_receive_prefill = network.receive_prefill;
        }
        // The legacy UI used zero to request minimum latency.
        network.audio_receive_queue_depth = network.audio_receive_queue_depth.max(1);
        network.video_receive_queue_depth = network.video_receive_queue_depth.max(1);
        network.receive_queue_depth = 0;
        network.receive_prefill = 0;
        Ok(Self {
            schema_version: SETTINGS_SCHEMA_VERSION,
            audio,
            video: wire.video,
            network,
            recording: wire.recording,
        })
    }
}

impl StationSettings {
    pub fn validate(&self) -> Result<(), SettingsError> {
        let a = &self.audio;
        if !(8_000..=384_000).contains(&a.sample_rate) {
            return Err(SettingsError::Validation(
                "audio sample_rate must be 8000..=384000".into(),
            ));
        }
        if !(1..=64).contains(&a.channels) {
            return Err(SettingsError::Validation(
                "audio channels must be 1..=64".into(),
            ));
        }
        if u32::from(a.channels).saturating_add(a.input_offset) > 64 {
            return Err(SettingsError::Validation(
                "audio input_offset plus channels must not exceed 64".into(),
            ));
        }
        if !matches!(a.bits_per_sample, 8 | 16 | 24 | 32) {
            return Err(SettingsError::Validation(
                "audio bits_per_sample must be 8, 16, 24, or 32".into(),
            ));
        }
        if a.buffer_samples == 0 {
            return Err(SettingsError::Validation(
                "audio buffer_samples must be greater than zero".into(),
            ));
        }
        if !(1..=2).contains(&a.tx_audio_level) {
            return Err(SettingsError::Validation(
                "audio tx_audio_level must be 1 (0 dB) or 2 (+6 dB)".into(),
            ));
        }
        let audio_bytes =
            u64::from(a.buffer_samples) * u64::from(a.channels) * u64::from(a.bits_per_sample / 8);
        if audio_bytes > MAX_AUDIO_PCM_BYTES {
            return Err(SettingsError::Validation(
                "audio callback payload exceeds the 1066-byte LoLa datagram capacity".into(),
            ));
        }
        let v = &self.video;
        if v.width == 0 || v.height == 0 || v.fps == 0 {
            return Err(SettingsError::Validation(
                "video width, height, and fps must be greater than zero".into(),
            ));
        }
        if v.fps > 480 {
            return Err(SettingsError::Validation(
                "video fps must not exceed 480".into(),
            ));
        }
        if !matches!(v.bpp, 8 | 16 | 24 | 32) {
            return Err(SettingsError::Validation(
                "video bpp must be 8, 16, 24, or 32".into(),
            ));
        }
        if !(1..=100).contains(&v.jpeg_quality) {
            return Err(SettingsError::Validation(
                "video jpeg_quality must be 1..=100".into(),
            ));
        }
        if !matches!(v.bayer, 0 | 1) {
            return Err(SettingsError::Validation(
                "video bayer must be 0 or 1".into(),
            ));
        }
        if !matches!(
            v.bayer_pattern.trim().to_ascii_uppercase().as_str(),
            "BGGR" | "RGGB" | "GBRG" | "GRBG"
        ) {
            return Err(SettingsError::Validation(
                "video bayer_pattern must be BGGR, RGGB, GBRG, or GRBG".into(),
            ));
        }
        if !v.incomplete_frame_threshold_pct.is_finite()
            || !(0.0..=100.0).contains(&v.incomplete_frame_threshold_pct)
        {
            return Err(SettingsError::Validation(
                "video incomplete_frame_threshold_pct must be finite and 0..=100".into(),
            ));
        }
        let frame_bytes = u64::from(v.width) * u64::from(v.height) * u64::from(v.bpp / 8);
        if frame_bytes > MAX_FRAME_BYTES {
            return Err(SettingsError::Validation(
                "video frame exceeds the 16 MiB protocol limit".into(),
            ));
        }
        if !(128..=8_192).contains(&self.network.video_packet_size) {
            return Err(SettingsError::Validation(
                "network video_packet_size must be 128..=8192".into(),
            ));
        }
        let ports = [
            self.network.control_port,
            self.network.audio_port,
            self.network.video_port,
        ];
        if ports.contains(&0) {
            return Err(SettingsError::Validation(
                "network control, audio, and video ports must be nonzero".into(),
            ));
        }
        if ports[0] == ports[1] || ports[0] == ports[2] || ports[1] == ports[2] {
            return Err(SettingsError::Validation(
                "network control, audio, and video ports must be distinct".into(),
            ));
        }
        if !(0..=i64::from(u32::MAX)).contains(&self.network.session_id) {
            return Err(SettingsError::Validation(
                "network session_id must fit in an unsigned 32-bit SID".into(),
            ));
        }
        let bind_ip = parse_ipv4("bind_ip", &self.network.bind_ip)?;
        let local_ip = parse_ipv4("local_ip", &self.network.local_ip)?;
        let remote_ip = parse_ipv4("remote_ip", &self.network.remote_ip)?;
        if local_ip.is_unspecified() || local_ip.is_multicast() || local_ip.is_broadcast() {
            return Err(SettingsError::Validation(
                "network local_ip must identify a usable IPv4 interface".into(),
            ));
        }
        if remote_ip.is_unspecified() || remote_ip.is_multicast() || remote_ip.is_broadcast() {
            return Err(SettingsError::Validation(
                "network remote_ip must identify a usable IPv4 peer".into(),
            ));
        }
        if !bind_ip.is_unspecified() && bind_ip != local_ip {
            return Err(SettingsError::Validation(
                "network bind_ip must be 0.0.0.0 or match local_ip".into(),
            ));
        }
        if self
            .network
            .vlan_tag
            .is_some_and(|tag| !(1..=4_094).contains(&tag))
        {
            return Err(SettingsError::Validation(
                "network vlan_tag must be 1..=4094 when set".into(),
            ));
        }
        if self.network.media_transport == MediaTransportKind::Npcap
            && self.network.pcap_device.trim().is_empty()
        {
            return Err(SettingsError::Validation(
                "network pcap_device must name an explicit adapter for Npcap".into(),
            ));
        }
        if self.network.reachability_timeout_ms == 0 {
            return Err(SettingsError::Validation(
                "network reachability_timeout_ms must be greater than zero".into(),
            ));
        }
        for (kind, depth, prefill) in [
            (
                "audio",
                self.network.audio_receive_queue_depth,
                self.network.audio_receive_prefill,
            ),
            (
                "video",
                self.network.video_receive_queue_depth,
                self.network.video_receive_prefill,
            ),
        ] {
            if !(1..=4096).contains(&depth) {
                return Err(SettingsError::Validation(format!(
                    "network {kind}_receive_queue_depth must be 1..=4096"
                )));
            }
            if prefill > depth {
                return Err(SettingsError::Validation(format!(
                    "network {kind}_receive_prefill must not exceed its queue depth"
                )));
            }
        }
        let queue_bytes = audio_bytes * u64::from(self.network.audio_receive_queue_depth)
            + frame_bytes * u64::from(self.network.video_receive_queue_depth);
        if queue_bytes > MAX_SESSION_QUEUE_BYTES {
            return Err(SettingsError::Validation(
                "configured receive queues exceed the 256 MiB session budget".into(),
            ));
        }
        if !matches!(
            self.recording.mode.trim().to_ascii_lowercase().as_str(),
            "av" | "audio" | "video"
        ) {
            return Err(SettingsError::Validation(
                "recording mode must be av, audio, or video".into(),
            ));
        }
        if !matches!(
            self.recording
                .video_format
                .trim()
                .to_ascii_lowercase()
                .as_str(),
            "jpg" | "jpeg" | "png" | "bmp" | "raw" | "bin"
        ) {
            return Err(SettingsError::Validation(
                "recording video_format must be jpg, jpeg, png, bmp, raw, or bin".into(),
            ));
        }
        if self.recording.enabled && self.recording.path.trim().is_empty() {
            return Err(SettingsError::Validation(
                "recording path must be set when recording is enabled".into(),
            ));
        }
        Ok(())
    }
}

fn parse_ipv4(field: &str, value: &str) -> Result<Ipv4Addr, SettingsError> {
    value.parse().map_err(|_| {
        SettingsError::Validation(format!("network {field} must be a numeric IPv4 address"))
    })
}

pub fn default_settings() -> StationSettings {
    StationSettings::default()
}

#[derive(Debug, Error)]
pub enum SettingsError {
    #[error("io: {0}")]
    Io(#[from] std::io::Error),
    #[error("json: {0}")]
    Json(#[from] serde_json::Error),
    #[error("invalid settings: {0}")]
    Validation(String),
}

pub fn load_settings(path: impl AsRef<Path>) -> Result<StationSettings, SettingsError> {
    let text = fs::read_to_string(path)?;
    let settings: StationSettings = serde_json::from_str(&text)?;
    settings.validate()?;
    Ok(settings)
}

pub fn save_settings(
    path: impl AsRef<Path>,
    settings: &StationSettings,
) -> Result<(), SettingsError> {
    settings.validate()?;
    if let Some(parent) = path.as_ref().parent() {
        fs::create_dir_all(parent)?;
    }
    fs::write(path, serde_json::to_string_pretty(settings)?)?;
    Ok(())
}

impl fmt::Display for AudioBackend {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(match self {
            Self::PortAudioAsio => "port_audio_asio",
            Self::Diagnostic => "diagnostic",
        })
    }
}

impl fmt::Display for VideoBackend {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(match self {
            Self::Ximea => "ximea",
            Self::Diagnostic => "diagnostic",
        })
    }
}
