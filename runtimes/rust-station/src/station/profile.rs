//! Session profile save/load (JSON; not binary closed *.ssn).

use crate::config::{
    default_settings, StationSettings, DEFAULT_AUDIO_PORT, DEFAULT_CONTROL_PORT, DEFAULT_VIDEO_PORT,
};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::BTreeMap;
use std::fs;
use std::net::Ipv4Addr;
use std::path::{Path, PathBuf};
use thiserror::Error;

mod ssn;

pub use ssn::*;

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub enum SessionProfileSource {
    #[default]
    Unspecified,
    OpenJson,
    LastSsnIni,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SessionProfile {
    #[serde(default = "default_remote")]
    pub remote_ip: String,
    #[serde(default = "default_local")]
    pub local_ip: String,
    #[serde(default = "default_ctrl")]
    pub control_port: u16,
    #[serde(default = "default_aud")]
    pub audio_port: u16,
    #[serde(default = "default_vid")]
    pub video_port: u16,
    #[serde(default = "default_sid")]
    pub session_id: i64,
    #[serde(default = "default_mode")]
    pub camera_mode_id: String,
    #[serde(default)]
    pub compression: bool,
    #[serde(default = "default_jq")]
    pub jpeg_quality: u8,
    #[serde(default = "default_sr")]
    pub sample_rate: u32,
    #[serde(default = "default_ch")]
    pub channels: u16,
    #[serde(default = "default_bind")]
    pub bind_ip: String,
    #[serde(default)]
    pub nic_name: String,
    #[serde(default = "default_queue_depth", alias = "audio_buffers")]
    pub audio_receive_queue_depth: u32,
    #[serde(default)]
    pub audio_receive_prefill: u32,
    #[serde(default = "default_queue_depth", alias = "video_buffers")]
    pub video_receive_queue_depth: u32,
    #[serde(default)]
    pub video_receive_prefill: u32,
    #[serde(default)]
    pub remote_audio_channel_offset: i32,
    #[serde(default)]
    pub extra: BTreeMap<String, Value>,
    #[serde(skip)]
    pub source: SessionProfileSource,
}

fn default_remote() -> String {
    "127.0.0.1".into()
}
fn default_local() -> String {
    "127.0.0.1".into()
}
fn default_ctrl() -> u16 {
    DEFAULT_CONTROL_PORT
}
fn default_aud() -> u16 {
    DEFAULT_AUDIO_PORT
}
fn default_vid() -> u16 {
    DEFAULT_VIDEO_PORT
}
fn default_sid() -> i64 {
    1
}
fn default_mode() -> String {
    "009".into()
}
fn default_jq() -> u8 {
    80
}
fn default_sr() -> u32 {
    44_100
}
fn default_ch() -> u16 {
    2
}
fn default_bind() -> String {
    "0.0.0.0".into()
}
fn default_queue_depth() -> u32 {
    1
}

impl Default for SessionProfile {
    fn default() -> Self {
        Self {
            remote_ip: default_remote(),
            local_ip: default_local(),
            control_port: DEFAULT_CONTROL_PORT,
            audio_port: DEFAULT_AUDIO_PORT,
            video_port: DEFAULT_VIDEO_PORT,
            session_id: 1,
            camera_mode_id: "009".into(),
            compression: false,
            jpeg_quality: 80,
            sample_rate: 44_100,
            channels: 2,
            bind_ip: "0.0.0.0".into(),
            nic_name: String::new(),
            audio_receive_queue_depth: 1,
            audio_receive_prefill: 0,
            video_receive_queue_depth: 1,
            video_receive_prefill: 0,
            remote_audio_channel_offset: 0,
            extra: BTreeMap::new(),
            source: SessionProfileSource::Unspecified,
        }
    }
}

impl SessionProfile {
    pub fn try_from_dict(d: &Value) -> Result<Self, ProfileError> {
        if !d.is_object() {
            return Err(ProfileError::NotObject);
        }
        let mut p = SessionProfile {
            source: SessionProfileSource::OpenJson,
            ..SessionProfile::default()
        };
        apply_top_level_fields(&mut p, d)?;
        apply_network_aliases(&mut p, d)?;
        apply_video_aliases(&mut p, d)?;
        copy_extra_fields(&mut p, d);
        p.validate()?;
        Ok(p)
    }

    fn validate(&self) -> Result<(), ProfileError> {
        for (name, value) in [
            ("remote_ip", &self.remote_ip),
            ("local_ip", &self.local_ip),
            ("bind_ip", &self.bind_ip),
        ] {
            value
                .parse::<Ipv4Addr>()
                .map_err(|_| ProfileError::Invalid(format!("{name} must be an IPv4 address")))?;
        }
        Ok(())
    }
}

fn apply_top_level_fields(profile: &mut SessionProfile, value: &Value) -> Result<(), ProfileError> {
    assign_optional_string(&mut profile.remote_ip, value, "remote_ip")?;
    assign_optional_string(&mut profile.local_ip, value, "local_ip")?;
    assign_optional_port(&mut profile.control_port, value, "control_port")?;
    assign_optional_port(&mut profile.audio_port, value, "audio_port")?;
    assign_optional_port(&mut profile.video_port, value, "video_port")?;
    assign_optional_session_id(&mut profile.session_id, value, "session_id", "session_id")?;
    assign_optional_string(&mut profile.camera_mode_id, value, "camera_mode_id")?;
    assign_optional_bool(&mut profile.compression, value, "compression")?;
    assign_optional_u8(&mut profile.jpeg_quality, value, "jpeg_quality", 1, 100)?;
    assign_optional_u32(
        &mut profile.sample_rate,
        value,
        "sample_rate",
        8_000,
        384_000,
    )?;
    assign_optional_bounded_u16(&mut profile.channels, value, "channels", 1, 64)?;
    assign_optional_string(&mut profile.bind_ip, value, "bind_ip")?;
    assign_optional_string(&mut profile.nic_name, value, "nic_name")?;
    assign_receive_buffers(profile, value, "audio_receive", "audio_buffers")?;
    assign_receive_buffers(profile, value, "video_receive", "video_buffers")?;
    if let Some(offset) = optional_i64(value, "remote_audio_channel_offset")? {
        profile.remote_audio_channel_offset = i32::try_from(offset).map_err(|_| {
            ProfileError::Invalid("remote_audio_channel_offset must fit i32".into())
        })?;
    }
    Ok(())
}

fn assign_optional_string(
    destination: &mut String,
    value: &Value,
    field: &str,
) -> Result<(), ProfileError> {
    if let Some(string) = optional_string(value, field)? {
        *destination = string.into();
    }
    Ok(())
}

fn assign_optional_bool(
    destination: &mut bool,
    value: &Value,
    field: &str,
) -> Result<(), ProfileError> {
    if let Some(boolean) = optional_bool(value, field)? {
        *destination = boolean;
    }
    Ok(())
}

fn assign_optional_port(
    destination: &mut u16,
    value: &Value,
    field: &str,
) -> Result<(), ProfileError> {
    if let Some(number) = optional_u64(value, field)? {
        *destination = bounded_u16(field, number, 1, u16::MAX)?;
    }
    Ok(())
}

fn assign_optional_bounded_u16(
    destination: &mut u16,
    value: &Value,
    field: &str,
    min: u16,
    max: u16,
) -> Result<(), ProfileError> {
    if let Some(number) = optional_u64(value, field)? {
        *destination = bounded_u16(field, number, min, max)?;
    }
    Ok(())
}

fn assign_optional_u8(
    destination: &mut u8,
    value: &Value,
    field: &str,
    min: u8,
    max: u8,
) -> Result<(), ProfileError> {
    if let Some(number) = optional_u64(value, field)? {
        *destination = bounded_u8(field, number, min, max)?;
    }
    Ok(())
}

fn assign_optional_u32(
    destination: &mut u32,
    value: &Value,
    field: &str,
    min: u32,
    max: u32,
) -> Result<(), ProfileError> {
    if let Some(number) = optional_u64(value, field)? {
        *destination = bounded_u32(field, number, min, max)?;
    }
    Ok(())
}

fn assign_optional_session_id(
    destination: &mut i64,
    value: &Value,
    source_field: &str,
    error_field: &str,
) -> Result<(), ProfileError> {
    if let Some(number) = optional_i64(value, source_field)? {
        *destination = bounded_session_id(error_field, number)?;
    }
    Ok(())
}

fn bounded_session_id(field: &str, value: i64) -> Result<i64, ProfileError> {
    if !(0..=i64::from(u32::MAX)).contains(&value) {
        return Err(ProfileError::Invalid(format!(
            "{field} must fit an unsigned 32-bit SID"
        )));
    }
    Ok(value)
}

fn assign_receive_buffers(
    profile: &mut SessionProfile,
    value: &Value,
    prefix: &str,
    alias: &str,
) -> Result<(), ProfileError> {
    let (depth, prefill) = if prefix == "audio_receive" {
        (
            &mut profile.audio_receive_queue_depth,
            &mut profile.audio_receive_prefill,
        )
    } else {
        (
            &mut profile.video_receive_queue_depth,
            &mut profile.video_receive_prefill,
        )
    };
    let depth_field = format!("{prefix}_queue_depth");
    if let Some(number) = optional_alias_u64(value, &depth_field, alias)? {
        *depth = bounded_u32(&depth_field, number, 1, 4096)?;
    }
    let prefill_field = format!("{prefix}_prefill");
    if let Some(number) = optional_u64(value, &prefill_field)? {
        *prefill = bounded_u32(&prefill_field, number, 0, *depth)?;
    }
    Ok(())
}

fn apply_network_aliases(profile: &mut SessionProfile, value: &Value) -> Result<(), ProfileError> {
    let Some(network) = value.get("network") else {
        return Ok(());
    };
    if !network.is_object() {
        return Err(ProfileError::Invalid("network must be an object".into()));
    }
    if profile.remote_ip == default_remote() {
        assign_optional_string(&mut profile.remote_ip, network, "remote_ip")?;
    }
    assign_optional_session_id(
        &mut profile.session_id,
        network,
        "session_id",
        "network.session_id",
    )?;
    assign_optional_string(&mut profile.bind_ip, network, "bind_ip")
}

fn apply_video_aliases(profile: &mut SessionProfile, value: &Value) -> Result<(), ProfileError> {
    let Some(video) = value.get("video") else {
        return Ok(());
    };
    if !video.is_object() {
        return Err(ProfileError::Invalid("video must be an object".into()));
    }
    assign_optional_string(&mut profile.camera_mode_id, video, "camera_mode_id")
}

fn copy_extra_fields(profile: &mut SessionProfile, value: &Value) {
    let Some(extra) = value.get("extra").and_then(Value::as_object) else {
        return;
    };
    for (key, entry) in extra {
        profile.extra.insert(key.clone(), entry.clone());
    }
}

fn optional_string<'a>(value: &'a Value, field: &str) -> Result<Option<&'a str>, ProfileError> {
    value.get(field).map_or(Ok(None), |value| {
        value
            .as_str()
            .map(Some)
            .ok_or_else(|| ProfileError::Invalid(format!("{field} must be a string")))
    })
}

fn optional_bool(value: &Value, field: &str) -> Result<Option<bool>, ProfileError> {
    value.get(field).map_or(Ok(None), |value| {
        value
            .as_bool()
            .map(Some)
            .ok_or_else(|| ProfileError::Invalid(format!("{field} must be a boolean")))
    })
}

fn optional_u64(value: &Value, field: &str) -> Result<Option<u64>, ProfileError> {
    value.get(field).map_or(Ok(None), |value| {
        value
            .as_u64()
            .map(Some)
            .ok_or_else(|| ProfileError::Invalid(format!("{field} must be an unsigned integer")))
    })
}

fn optional_alias_u64(
    value: &Value,
    field: &str,
    alias: &str,
) -> Result<Option<u64>, ProfileError> {
    match (value.get(field), value.get(alias)) {
        (Some(_), Some(_)) => Err(ProfileError::Invalid(format!(
            "{field} and {alias} cannot both be set"
        ))),
        (Some(_), None) => optional_u64(value, field),
        (None, Some(_)) => optional_u64(value, alias),
        (None, None) => Ok(None),
    }
}

fn optional_i64(value: &Value, field: &str) -> Result<Option<i64>, ProfileError> {
    value.get(field).map_or(Ok(None), |value| {
        value
            .as_i64()
            .map(Some)
            .ok_or_else(|| ProfileError::Invalid(format!("{field} must be an integer")))
    })
}

fn bounded_u8(field: &str, value: u64, min: u8, max: u8) -> Result<u8, ProfileError> {
    let value =
        u8::try_from(value).map_err(|_| ProfileError::Invalid(format!("{field} exceeds u8")))?;
    (min..=max)
        .contains(&value)
        .then_some(value)
        .ok_or_else(|| ProfileError::Invalid(format!("{field} must be {min}..={max}")))
}

fn bounded_u16(field: &str, value: u64, min: u16, max: u16) -> Result<u16, ProfileError> {
    let value =
        u16::try_from(value).map_err(|_| ProfileError::Invalid(format!("{field} exceeds u16")))?;
    (min..=max)
        .contains(&value)
        .then_some(value)
        .ok_or_else(|| ProfileError::Invalid(format!("{field} must be {min}..={max}")))
}

fn bounded_u32(field: &str, value: u64, min: u32, max: u32) -> Result<u32, ProfileError> {
    let value =
        u32::try_from(value).map_err(|_| ProfileError::Invalid(format!("{field} exceeds u32")))?;
    (min..=max)
        .contains(&value)
        .then_some(value)
        .ok_or_else(|| ProfileError::Invalid(format!("{field} must be {min}..={max}")))
}

#[derive(Debug, Error)]
pub enum ProfileError {
    #[error("io: {0}")]
    Io(#[from] std::io::Error),
    #[error("json: {0}")]
    Json(#[from] serde_json::Error),
    #[error("session profile must be a JSON object")]
    NotObject,
    #[error("not found: {0}")]
    NotFound(String),
    #[error("invalid session profile: {0}")]
    Invalid(String),
}

pub fn save_session_profile(
    path: impl AsRef<Path>,
    profile: &SessionProfile,
) -> Result<PathBuf, ProfileError> {
    let p = path.as_ref();
    if p.extension()
        .is_some_and(|extension| extension.eq_ignore_ascii_case("ssn"))
    {
        return ssn::save_session_ssn(p, profile);
    }
    if let Some(parent) = p.parent() {
        fs::create_dir_all(parent)?;
    }
    let text = serde_json::to_string_pretty(profile)?;
    crate::config::file_store::atomic_write(p, format!("{text}\n").as_bytes())?;
    Ok(p.to_path_buf())
}

pub fn load_session_profile(path: impl AsRef<Path>) -> Result<SessionProfile, ProfileError> {
    let p = path.as_ref();
    if p.extension()
        .is_some_and(|extension| extension.eq_ignore_ascii_case("ssn"))
    {
        return ssn::load_session_ssn(p);
    }
    load_json_session_profile(p)
}

/// Fallible session input loader. `.ssn` uses the strict Open-Lola/LastSsn path;
/// every other extension is an Open-Lola JSON profile.
pub fn load_session_input(path: impl AsRef<Path>) -> Result<SessionProfile, ProfileError> {
    load_session_profile(path)
}

fn load_json_session_profile(path: &Path) -> Result<SessionProfile, ProfileError> {
    if !path.is_file() {
        return Err(ProfileError::NotFound(path.display().to_string()));
    }
    let text = crate::config::file_store::read_text(path)?;
    let data: Value = serde_json::from_str(&text)?;
    if !data.is_object() {
        return Err(ProfileError::NotObject);
    }
    SessionProfile::try_from_dict(&data)
}

pub fn profile_to_settings(profile: &SessionProfile) -> StationSettings {
    let mut settings = default_settings();
    settings.network.remote_ip = profile.remote_ip.clone();
    settings.network.local_ip = profile.local_ip.clone();
    settings.network.control_port = profile.control_port;
    settings.network.audio_port = profile.audio_port;
    settings.network.video_port = profile.video_port;
    settings.network.session_id = profile.session_id;
    if !profile.bind_ip.trim().is_empty() {
        settings.network.bind_ip = profile.bind_ip.clone();
    }
    if let Some(b) = profile.extra.get("bind_ip").and_then(|v| v.as_str()) {
        if !b.trim().is_empty() {
            settings.network.bind_ip = b.to_string();
        }
    }
    if !profile.nic_name.is_empty() {
        settings.network.nic_name = profile.nic_name.clone();
    }
    settings.video.camera_mode_id = profile.camera_mode_id.clone();
    settings.video.compression = profile.compression;
    settings.video.jpeg_quality = profile.jpeg_quality;
    settings.audio.sample_rate = profile.sample_rate;
    settings.audio.channels = profile.channels;
    settings.network.audio_receive_queue_depth = profile.audio_receive_queue_depth.max(1);
    settings.network.audio_receive_prefill = profile.audio_receive_prefill;
    settings.network.video_receive_queue_depth = profile.video_receive_queue_depth.max(1);
    settings.network.video_receive_prefill = profile.video_receive_prefill;
    settings
}

pub fn apply_profile_to_settings(settings: &mut StationSettings, profile: &SessionProfile) {
    if profile.source == SessionProfileSource::LastSsnIni {
        settings.network.remote_ip = profile.remote_ip.clone();
        settings.network.audio_receive_queue_depth = profile.audio_receive_queue_depth.max(1);
        settings.network.audio_receive_prefill = profile.audio_receive_prefill;
        settings.network.video_receive_queue_depth = profile.video_receive_queue_depth.max(1);
        settings.network.video_receive_prefill = profile.video_receive_prefill;
    } else {
        *settings = profile_to_settings(profile);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn nested_profile_aliases_preserve_existing_precedence() {
        let profile = SessionProfile::try_from_dict(&json!({
            "remote_ip": "127.0.0.1",
            "session_id": 4,
            "network": {
                "remote_ip": "10.0.0.2",
                "session_id": 7,
                "bind_ip": "10.0.0.1"
            },
            "video": { "camera_mode_id": "013" },
            "audio_buffers": 3,
            "audio_receive_prefill": 2
        }))
        .unwrap();

        assert_eq!(profile.remote_ip, "10.0.0.2");
        assert_eq!(profile.session_id, 7);
        assert_eq!(profile.bind_ip, "10.0.0.1");
        assert_eq!(profile.camera_mode_id, "013");
        assert_eq!(profile.audio_receive_queue_depth, 3);
        assert_eq!(profile.audio_receive_prefill, 2);
    }

    #[test]
    fn profile_field_validators_keep_their_error_identity() {
        assert!(matches!(
            SessionProfile::try_from_dict(&json!({ "channels": 0 })),
            Err(ProfileError::Invalid(message)) if message == "channels must be 1..=64"
        ));
        assert!(matches!(
            SessionProfile::try_from_dict(&json!({ "network": { "session_id": -1 } })),
            Err(ProfileError::Invalid(message)) if message == "network.session_id must fit an unsigned 32-bit SID"
        ));
    }
}
