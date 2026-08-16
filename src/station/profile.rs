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
        if let Some(s) = optional_string(d, "remote_ip")? {
            p.remote_ip = s.into();
        }
        if let Some(s) = optional_string(d, "local_ip")? {
            p.local_ip = s.into();
        }
        if let Some(n) = optional_u64(d, "control_port")? {
            p.control_port = bounded_u16("control_port", n, 1, u16::MAX)?;
        }
        if let Some(n) = optional_u64(d, "audio_port")? {
            p.audio_port = bounded_u16("audio_port", n, 1, u16::MAX)?;
        }
        if let Some(n) = optional_u64(d, "video_port")? {
            p.video_port = bounded_u16("video_port", n, 1, u16::MAX)?;
        }
        if let Some(n) = optional_i64(d, "session_id")? {
            if !(0..=i64::from(u32::MAX)).contains(&n) {
                return Err(ProfileError::Invalid(
                    "session_id must fit an unsigned 32-bit SID".into(),
                ));
            }
            p.session_id = n;
        }
        if let Some(s) = optional_string(d, "camera_mode_id")? {
            p.camera_mode_id = s.into();
        }
        if let Some(b) = optional_bool(d, "compression")? {
            p.compression = b;
        }
        if let Some(n) = optional_u64(d, "jpeg_quality")? {
            p.jpeg_quality = bounded_u8("jpeg_quality", n, 1, 100)?;
        }
        if let Some(n) = optional_u64(d, "sample_rate")? {
            p.sample_rate = bounded_u32("sample_rate", n, 8_000, 384_000)?;
        }
        if let Some(n) = optional_u64(d, "channels")? {
            p.channels = bounded_u16("channels", n, 1, 64)?;
        }
        if let Some(s) = optional_string(d, "bind_ip")? {
            p.bind_ip = s.into();
        }
        if let Some(s) = optional_string(d, "nic_name")? {
            p.nic_name = s.into();
        }
        if let Some(n) = optional_alias_u64(d, "audio_receive_queue_depth", "audio_buffers")? {
            p.audio_receive_queue_depth = bounded_u32("audio_receive_queue_depth", n, 1, 4096)?;
        }
        if let Some(n) = optional_u64(d, "audio_receive_prefill")? {
            p.audio_receive_prefill =
                bounded_u32("audio_receive_prefill", n, 0, p.audio_receive_queue_depth)?;
        }
        if let Some(n) = optional_alias_u64(d, "video_receive_queue_depth", "video_buffers")? {
            p.video_receive_queue_depth = bounded_u32("video_receive_queue_depth", n, 1, 4096)?;
        }
        if let Some(n) = optional_u64(d, "video_receive_prefill")? {
            p.video_receive_prefill =
                bounded_u32("video_receive_prefill", n, 0, p.video_receive_queue_depth)?;
        }
        if let Some(n) = optional_i64(d, "remote_audio_channel_offset")? {
            p.remote_audio_channel_offset = i32::try_from(n).map_err(|_| {
                ProfileError::Invalid("remote_audio_channel_offset must fit i32".into())
            })?;
        }
        // nested aliases
        if let Some(net) = d.get("network") {
            if !net.is_object() {
                return Err(ProfileError::Invalid("network must be an object".into()));
            }
            if p.remote_ip == default_remote() {
                if let Some(s) = optional_string(net, "remote_ip")? {
                    p.remote_ip = s.into();
                }
            }
            if let Some(n) = optional_i64(net, "session_id")? {
                if !(0..=i64::from(u32::MAX)).contains(&n) {
                    return Err(ProfileError::Invalid(
                        "network.session_id must fit an unsigned 32-bit SID".into(),
                    ));
                }
                p.session_id = n;
            }
            if let Some(s) = optional_string(net, "bind_ip")? {
                p.bind_ip = s.into();
            }
        }
        if let Some(vid) = d.get("video") {
            if !vid.is_object() {
                return Err(ProfileError::Invalid("video must be an object".into()));
            }
            if let Some(s) = optional_string(vid, "camera_mode_id")? {
                p.camera_mode_id = s.into();
            }
        }
        if let Some(obj) = d.get("extra").and_then(|v| v.as_object()) {
            for (k, v) in obj {
                p.extra.insert(k.clone(), v.clone());
            }
        }
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
        return crate::config::save_session_ssn(p, profile);
    }
    if let Some(parent) = p.parent() {
        fs::create_dir_all(parent)?;
    }
    let text = serde_json::to_string_pretty(profile)?;
    fs::write(p, format!("{text}\n"))?;
    Ok(p.to_path_buf())
}

pub fn load_session_profile(path: impl AsRef<Path>) -> Result<SessionProfile, ProfileError> {
    let p = path.as_ref();
    if p.extension()
        .is_some_and(|extension| extension.eq_ignore_ascii_case("ssn"))
    {
        return crate::config::load_session_ssn(p);
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
    let text = fs::read_to_string(path)?;
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
    use tempfile::tempdir;

    #[test]
    fn roundtrip_profile() {
        let dir = tempdir().unwrap();
        let path = dir.path().join("p.json");
        let p = SessionProfile {
            remote_ip: "10.0.0.5".into(),
            camera_mode_id: "009".into(),
            session_id: 2,
            ..SessionProfile::default()
        };
        save_session_profile(&path, &p).unwrap();
        let loaded = load_session_profile(&path).unwrap();
        assert_eq!(loaded.remote_ip, "10.0.0.5");
        assert_eq!(loaded.session_id, 2);
        let s = profile_to_settings(&loaded);
        assert_eq!(s.network.remote_ip, "10.0.0.5");
        assert_eq!(s.network.session_id, 2);
    }

    #[test]
    fn rejects_overflowing_or_out_of_range_json_numbers() {
        for (field, value) in [
            ("control_port", "65536"),
            ("jpeg_quality", "256"),
            ("sample_rate", "4294967296"),
            ("channels", "65536"),
            ("audio_receive_queue_depth", "4294967296"),
        ] {
            let json: Value = serde_json::from_str(&format!("{{\"{field}\":{value}}}")).unwrap();
            assert!(SessionProfile::try_from_dict(&json).is_err(), "{field}");
        }
    }
}
