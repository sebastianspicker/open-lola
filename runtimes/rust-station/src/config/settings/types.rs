use super::{
    DEFAULT_AUDIO_PORT, DEFAULT_CONTROL_PORT, DEFAULT_VIDEO_PORT, SETTINGS_SCHEMA_VERSION,
};
use serde::{Deserialize, Deserializer, Serialize};

/// Audio implementation requested by a station session.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum AudioBackend {
    PortAudioAsio,
    Alsa,
    Diagnostic,
}

impl AudioBackend {
    pub fn as_preference(self) -> &'static str {
        match self {
            Self::PortAudioAsio => "portaudio_asio",
            Self::Alsa => "alsa",
            Self::Diagnostic => "diagnostic",
        }
    }
}

impl<'de> Deserialize<'de> for AudioBackend {
    fn deserialize<D: Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        let value = String::deserialize(deserializer)?;
        match value.trim().to_ascii_lowercase().as_str() {
            "native" | "auto" => Ok(Self::default()),
            "portaudio" | "asio" | "portaudio_asio" | "port_audio_asio" => Ok(Self::PortAudioAsio),
            "alsa" => Ok(Self::Alsa),
            "software" | "diagnostic" => Ok(Self::Diagnostic),
            other => Err(serde::de::Error::custom(format!(
                "unknown audio backend `{other}`"
            ))),
        }
    }
}

/// Camera implementation requested by a station session.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum VideoBackend {
    Ximea,
    V4l2,
    Diagnostic,
}

impl VideoBackend {
    pub fn as_preference(self) -> &'static str {
        match self {
            Self::Ximea => "ximea",
            Self::V4l2 => "v4l2",
            Self::Diagnostic => "diagnostic",
        }
    }
}

impl<'de> Deserialize<'de> for VideoBackend {
    fn deserialize<D: Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        let value = String::deserialize(deserializer)?;
        match value.trim().to_ascii_lowercase().as_str() {
            "native" | "auto" => Ok(Self::default()),
            "ximea" | "xiapi" => Ok(Self::Ximea),
            "v4l2" => Ok(Self::V4l2),
            "software" | "diagnostic" => Ok(Self::Diagnostic),
            other => Err(serde::de::Error::custom(format!(
                "unknown video backend `{other}`"
            ))),
        }
    }
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum MediaTransportKind {
    #[default]
    Udp,
    Npcap,
}

impl<'de> Deserialize<'de> for MediaTransportKind {
    fn deserialize<D: Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        match String::deserialize(deserializer)?
            .trim()
            .to_ascii_lowercase()
            .as_str()
        {
            "udp" => Ok(Self::Udp),
            "pcap" | "npcap" | "raw" => Ok(Self::Npcap),
            other => Err(serde::de::Error::custom(format!(
                "unknown media transport `{other}`"
            ))),
        }
    }
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ControlDialect {
    #[default]
    Ascii,
    Osc15,
}

impl<'de> Deserialize<'de> for ControlDialect {
    fn deserialize<D: Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        match String::deserialize(deserializer)?
            .trim()
            .to_ascii_lowercase()
            .as_str()
        {
            "ascii" | "lola" | "legacy" => Ok(Self::Ascii),
            "osc15" | "osc_15" => Ok(Self::Osc15),
            other => Err(serde::de::Error::custom(format!(
                "unknown control dialect `{other}`"
            ))),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AudioSettings {
    /// Legacy single-device setting. It is accepted on load but not persisted.
    #[serde(default)]
    #[serde(skip_serializing)]
    pub device: String,
    #[serde(default)]
    pub input_device: String,
    #[serde(default)]
    pub output_device: String,
    #[serde(default = "default_sr")]
    pub sample_rate: u32,
    #[serde(default = "default_ch")]
    pub channels: u16,
    #[serde(default = "default_bps")]
    pub bits_per_sample: u16,
    #[serde(default = "default_buf")]
    pub buffer_samples: u32,
    #[serde(default)]
    pub backend: AudioBackend,
    #[serde(default = "default_tx_level")]
    pub tx_audio_level: u8,
    #[serde(default)]
    pub input_offset: u32,
    #[serde(default)]
    pub local_audio_loop: bool,
}

fn default_tx_level() -> u8 {
    1
}
fn default_sr() -> u32 {
    44_100
}
fn default_ch() -> u16 {
    2
}
fn default_bps() -> u16 {
    16
}
fn default_buf() -> u32 {
    64
}

impl Default for AudioSettings {
    fn default() -> Self {
        Self {
            device: String::new(),
            input_device: String::new(),
            output_device: String::new(),
            sample_rate: default_sr(),
            channels: default_ch(),
            bits_per_sample: default_bps(),
            buffer_samples: default_buf(),
            backend: AudioBackend::default(),
            tx_audio_level: 1,
            input_offset: 0,
            local_audio_loop: false,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VideoSettings {
    /// Native Linux V4L2 device node. Empty selects /dev/video{local_camera_index}.
    #[serde(default)]
    pub device: String,
    /// V4L2 FOURCC; empty chooses GREY for mono or RGB3 for color.
    #[serde(default)]
    pub pixel_format: String,
    #[serde(default = "default_mode")]
    pub camera_mode_id: String,
    #[serde(default)]
    pub compression: bool,
    #[serde(default = "default_jq")]
    pub jpeg_quality: u8,
    #[serde(default = "default_w")]
    pub width: u32,
    #[serde(default = "default_h")]
    pub height: u32,
    #[serde(default = "default_fps")]
    pub fps: u32,
    #[serde(default = "default_bpp")]
    pub bpp: u32,
    #[serde(default = "default_bayer")]
    pub bayer: u32,
    #[serde(default)]
    pub backend: VideoBackend,
    #[serde(default)]
    pub catalog_file: String,
    #[serde(default = "default_bayer_pat")]
    pub bayer_pattern: String,
    #[serde(default = "default_true")]
    pub auto_bayer: bool,
    #[serde(default)]
    pub audio_only: bool,
    #[serde(default)]
    pub local_camera_index: u32,
    #[serde(default)]
    pub incomplete_frame_threshold_pct: f64,
}

fn default_bayer_pat() -> String {
    "BGGR".into()
}
fn default_true() -> bool {
    true
}
fn default_mode() -> String {
    "009".into()
}
fn default_jq() -> u8 {
    80
}
fn default_w() -> u32 {
    1280
}
fn default_h() -> u32 {
    720
}
fn default_fps() -> u32 {
    60
}
fn default_bpp() -> u32 {
    8
}
fn default_bayer() -> u32 {
    if cfg!(target_os = "linux") {
        0
    } else {
        1
    }
}

impl Default for VideoSettings {
    fn default() -> Self {
        Self {
            device: String::new(),
            pixel_format: String::new(),
            camera_mode_id: default_mode(),
            compression: false,
            jpeg_quality: default_jq(),
            width: default_w(),
            height: default_h(),
            fps: default_fps(),
            bpp: default_bpp(),
            bayer: default_bayer(),
            backend: VideoBackend::default(),
            catalog_file: String::new(),
            bayer_pattern: default_bayer_pat(),
            auto_bayer: true,
            audio_only: false,
            local_camera_index: 0,
            incomplete_frame_threshold_pct: 0.0,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NetworkSettings {
    #[serde(default = "default_ctrl")]
    pub control_port: u16,
    #[serde(default = "default_aud_p")]
    pub audio_port: u16,
    #[serde(default = "default_vid_p")]
    pub video_port: u16,
    #[serde(default = "default_pkt")]
    pub video_packet_size: u32,
    #[serde(default = "default_bind")]
    pub bind_ip: String,
    #[serde(default = "default_local")]
    pub local_ip: String,
    #[serde(default = "default_local")]
    pub remote_ip: String,
    #[serde(default = "default_sid")]
    pub session_id: i64,
    #[serde(default, skip_serializing)]
    pub nic_name: String,
    #[serde(default)]
    pub pcap_device: String,
    /// Optional IEEE 802.1Q VLAN identifier for direct-LAN Npcap sessions.
    #[serde(default)]
    pub vlan_tag: Option<u16>,
    /// Legacy boolean retained only while deserializing schema v0/v1.
    #[serde(default, skip_serializing)]
    pub raw_media_plane: bool,
    #[serde(default)]
    pub media_transport: MediaTransportKind,
    #[serde(default)]
    pub control_dialect: ControlDialect,
    #[serde(default)]
    pub precheck_reachable: bool,
    #[serde(default = "default_reach_ms")]
    pub reachability_timeout_ms: u32,
    /// Legacy combined queue settings, accepted only for schema migration.
    #[serde(default, skip_serializing)]
    pub receive_queue_depth: u32,
    #[serde(default, skip_serializing)]
    pub receive_prefill: u32,
    #[serde(default = "default_audio_receive_queue_depth")]
    pub audio_receive_queue_depth: u32,
    #[serde(default = "default_receive_prefill")]
    pub audio_receive_prefill: u32,
    #[serde(default = "default_receive_queue_depth")]
    pub video_receive_queue_depth: u32,
    #[serde(default = "default_receive_prefill")]
    pub video_receive_prefill: u32,
    /// Legacy boolean retained only while deserializing schema v0/v1.
    #[serde(default, skip_serializing)]
    pub use_raw_pcap: bool,
}

fn default_reach_ms() -> u32 {
    1000
}
/// Audio blocks the receiver may hold before presenting the oldest one. Four
/// 64-frame blocks bound the latency a jitter burst can add to about 5.8 ms at
/// 44.1 kHz; the queue returns that latency once arrivals settle.
fn default_audio_receive_queue_depth() -> u32 {
    4
}
/// Video keeps only the newest frame unless the operator asks for buffering.
fn default_receive_queue_depth() -> u32 {
    1
}
fn default_receive_prefill() -> u32 {
    0
}
fn default_ctrl() -> u16 {
    DEFAULT_CONTROL_PORT
}
fn default_aud_p() -> u16 {
    DEFAULT_AUDIO_PORT
}
fn default_vid_p() -> u16 {
    DEFAULT_VIDEO_PORT
}
fn default_pkt() -> u32 {
    1000
}
fn default_bind() -> String {
    "0.0.0.0".into()
}
fn default_local() -> String {
    "127.0.0.1".into()
}
fn default_sid() -> i64 {
    1
}

impl Default for NetworkSettings {
    fn default() -> Self {
        Self {
            control_port: default_ctrl(),
            audio_port: default_aud_p(),
            video_port: default_vid_p(),
            video_packet_size: default_pkt(),
            bind_ip: default_bind(),
            local_ip: default_local(),
            remote_ip: default_local(),
            session_id: default_sid(),
            nic_name: String::new(),
            pcap_device: String::new(),
            vlan_tag: None,
            raw_media_plane: false,
            media_transport: MediaTransportKind::Udp,
            control_dialect: ControlDialect::Ascii,
            precheck_reachable: false,
            reachability_timeout_ms: default_reach_ms(),
            receive_queue_depth: 0,
            receive_prefill: 0,
            audio_receive_queue_depth: default_audio_receive_queue_depth(),
            audio_receive_prefill: default_receive_prefill(),
            video_receive_queue_depth: default_receive_queue_depth(),
            video_receive_prefill: default_receive_prefill(),
            use_raw_pcap: false,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RecordingSettings {
    #[serde(default)]
    pub enabled: bool,
    #[serde(default)]
    pub path: String,
    #[serde(default = "default_true")]
    pub record_local_audio: bool,
    #[serde(default = "default_true")]
    pub record_remote_audio: bool,
    #[serde(default = "default_true")]
    pub record_local_video: bool,
    #[serde(default = "default_true")]
    pub record_remote_video: bool,
    #[serde(default = "default_rec_mode")]
    pub mode: String,
    #[serde(default = "default_vid_fmt")]
    pub video_format: String,
}
fn default_rec_mode() -> String {
    "av".into()
}
fn default_vid_fmt() -> String {
    "jpg".into()
}
impl Default for RecordingSettings {
    fn default() -> Self {
        Self {
            enabled: false,
            path: String::new(),
            record_local_audio: true,
            record_remote_audio: true,
            record_local_video: true,
            record_remote_video: true,
            mode: default_rec_mode(),
            video_format: default_vid_fmt(),
        }
    }
}

#[derive(Debug, Clone, Serialize)]
pub struct StationSettings {
    pub schema_version: u32,
    pub audio: AudioSettings,
    pub video: VideoSettings,
    pub network: NetworkSettings,
    pub recording: RecordingSettings,
}

impl Default for StationSettings {
    fn default() -> Self {
        Self {
            schema_version: SETTINGS_SCHEMA_VERSION,
            audio: AudioSettings::default(),
            video: VideoSettings::default(),
            network: NetworkSettings::default(),
            recording: RecordingSettings::default(),
        }
    }
}

impl Default for AudioBackend {
    fn default() -> Self {
        if cfg!(target_os = "linux") {
            Self::Alsa
        } else {
            Self::PortAudioAsio
        }
    }
}
impl Default for VideoBackend {
    fn default() -> Self {
        if cfg!(target_os = "linux") {
            Self::V4l2
        } else {
            Self::Ximea
        }
    }
}
