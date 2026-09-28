//! Open-Lola `.ssn` files and the documented recoverable LastSsn INI subset.

use super::{ProfileError, SessionProfile, SessionProfileSource};
use serde_json::{json, Value};
use std::fs;
use std::net::Ipv4Addr;
use std::path::{Path, PathBuf};

pub const FORMAT_TAG: &str = "open-lola-ssn";
pub const FORMAT_VERSION: u32 = 1;
pub const HEADER: &str = "# open-lola-ssn v1";
pub const LAST_SESSION_NAME: &str = "LastSsn.ssn";

#[derive(Clone, Copy)]
enum LastSsnSection {
    RemoteHost,
    AvBuffers,
}

#[derive(Default)]
struct LastSsnValues {
    remote_ip: Option<String>,
    audio: Option<(u32, u32)>,
    video: Option<(u32, u32)>,
}

pub fn save_session_ssn(
    path: impl AsRef<Path>,
    profile: &SessionProfile,
) -> Result<PathBuf, ProfileError> {
    let path = path.as_ref();
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    let mut payload = serde_json::to_value(profile)?;
    if let Some(object) = payload.as_object_mut() {
        object.insert("format".into(), json!(FORMAT_TAG));
        object.insert("version".into(), json!(FORMAT_VERSION));
    }
    let text = format!("{HEADER}\n{}\n", serde_json::to_string_pretty(&payload)?);
    crate::config::file_store::atomic_write(path, text.as_bytes())?;
    Ok(path.to_path_buf())
}

/// Load an explicitly tagged Open-Lola JSON `.ssn`, or the documented
/// recoverable Windows LastSsn INI fields. This never guesses from binary data.
pub fn load_session_ssn(path: impl AsRef<Path>) -> Result<SessionProfile, ProfileError> {
    let path = path.as_ref();
    if !path.is_file() {
        return Err(ProfileError::NotFound(path.display().to_string()));
    }
    let text = crate::config::file_store::read_text(path).map_err(|error| match error.kind() {
        std::io::ErrorKind::InvalidData => ProfileError::Invalid(".ssn must be UTF-8 text".into()),
        _ => ProfileError::Io(error),
    })?;
    let body = strip_header(&text);
    match serde_json::from_str::<Value>(&body) {
        Ok(value) => load_open_json(&value),
        Err(_) => parse_lastsnn_ini(&text),
    }
}

fn load_open_json(value: &Value) -> Result<SessionProfile, ProfileError> {
    let object = value.as_object().ok_or(ProfileError::NotObject)?;
    match object.get("format").and_then(Value::as_str) {
        Some(FORMAT_TAG) => {}
        Some(other) => {
            return Err(ProfileError::Invalid(format!(
                "unsupported .ssn format {other:?}"
            )));
        }
        None => {
            return Err(ProfileError::Invalid(
                "Open-Lola .ssn is missing its format tag".into(),
            ));
        }
    }
    match object.get("version").and_then(Value::as_u64) {
        Some(version) if version == u64::from(FORMAT_VERSION) => {
            SessionProfile::try_from_dict(value)
        }
        Some(version) => Err(ProfileError::Invalid(format!(
            "unsupported .ssn version {version}"
        ))),
        None => Err(ProfileError::Invalid(
            "Open-Lola .ssn is missing its version".into(),
        )),
    }
}

fn strip_header(text: &str) -> String {
    text.lines()
        .filter(|line| !line.trim_start().starts_with('#'))
        .collect::<Vec<_>>()
        .join("\n")
}

fn parse_lastsnn_ini(text: &str) -> Result<SessionProfile, ProfileError> {
    let mut section = None;
    let mut values = LastSsnValues::default();
    for (number, raw_line) in text.lines().enumerate() {
        parse_lastsnn_line(raw_line, number, &mut section, &mut values)?;
    }
    let (audio_depth, audio_prefill) = values
        .audio
        .ok_or_else(|| ProfileError::Invalid("LastSsn is missing RemoteAudioBuffers".into()))?;
    let (video_depth, video_prefill) = values
        .video
        .ok_or_else(|| ProfileError::Invalid("LastSsn is missing RemoteVideoBuffers".into()))?;
    Ok(SessionProfile {
        remote_ip: values
            .remote_ip
            .ok_or_else(|| ProfileError::Invalid("LastSsn is missing RemoteIpAddr".into()))?,
        audio_receive_queue_depth: audio_depth,
        audio_receive_prefill: audio_prefill,
        video_receive_queue_depth: video_depth,
        video_receive_prefill: video_prefill,
        source: SessionProfileSource::LastSsnIni,
        ..SessionProfile::default()
    })
}

fn parse_lastsnn_line(
    raw_line: &str,
    number: usize,
    section: &mut Option<LastSsnSection>,
    values: &mut LastSsnValues,
) -> Result<(), ProfileError> {
    let line = raw_line.trim();
    if line.is_empty() || line.starts_with(';') || line.starts_with('#') {
        return Ok(());
    }
    if line.starts_with('[') && line.ends_with(']') {
        *section = Some(parse_lastsnn_section(line, number)?);
        return Ok(());
    }
    let (key, value) = line
        .split_once('=')
        .ok_or_else(|| ini_error(number, "expected key=value"))?;
    store_lastsnn_value(*section, key.trim(), value, number, values)
}

fn parse_lastsnn_section(line: &str, number: usize) -> Result<LastSsnSection, ProfileError> {
    match &line[1..line.len() - 1] {
        "RemoteHost" => Ok(LastSsnSection::RemoteHost),
        "AVBuffers" => Ok(LastSsnSection::AvBuffers),
        other => Err(ini_error(number, format!("unknown section [{other}]"))),
    }
}

fn store_lastsnn_value(
    section: Option<LastSsnSection>,
    key: &str,
    value: &str,
    number: usize,
    values: &mut LastSsnValues,
) -> Result<(), ProfileError> {
    match (section, key) {
        (Some(LastSsnSection::RemoteHost), "RemoteIpAddr") if values.remote_ip.is_none() => {
            values.remote_ip = Some(parse_remote(value, number)?);
            Ok(())
        }
        (Some(LastSsnSection::AvBuffers), "RemoteAudioBuffers") if values.audio.is_none() => {
            values.audio = Some(parse_buffers(value, "RemoteAudioBuffers", number)?);
            Ok(())
        }
        (Some(LastSsnSection::AvBuffers), "RemoteVideoBuffers") if values.video.is_none() => {
            values.video = Some(parse_buffers(value, "RemoteVideoBuffers", number)?);
            Ok(())
        }
        (_, "RemoteIpAddr" | "RemoteAudioBuffers" | "RemoteVideoBuffers") => {
            Err(ini_error(number, "duplicate or misplaced key"))
        }
        (None, _) => Err(ini_error(number, "key appears before a section")),
        (_, unknown_key) => Err(ini_error(number, format!("unknown key {unknown_key}"))),
    }
}

fn parse_remote(value: &str, number: usize) -> Result<String, ProfileError> {
    let (peer, _) = value
        .trim()
        .split_once(';')
        .ok_or_else(|| ini_error(number, "RemoteIpAddr must be <peer>;<ignored>"))?;
    let peer = peer.trim();
    peer.parse::<Ipv4Addr>()
        .map_err(|_| ini_error(number, "RemoteIpAddr must contain an IPv4 address"))?;
    Ok(peer.into())
}

fn parse_buffers(value: &str, key: &str, number: usize) -> Result<(u32, u32), ProfileError> {
    let (depth, prefill) = value
        .trim()
        .split_once(';')
        .ok_or_else(|| ini_error(number, format!("{key} must be <depth>;<prefill>")))?;
    // Recovered LastSsn files use zero to mean no additional receive buffering.
    // The Rust runtime later normalizes that legacy value to its required
    // one-slot minimum while preserving the imported prefill decision.
    let depth = parse_bounded(depth, key, number, 0, 4096)?;
    let prefill = parse_bounded(prefill, key, number, 0, depth)?;
    Ok((depth, prefill))
}

fn parse_bounded(
    value: &str,
    key: &str,
    number: usize,
    min: u32,
    max: u32,
) -> Result<u32, ProfileError> {
    let parsed = value
        .trim()
        .parse::<u32>()
        .map_err(|_| ini_error(number, format!("{key} must contain an unsigned integer")))?;
    if !(min..=max).contains(&parsed) {
        return Err(ini_error(number, format!("{key} must be {min}..={max}")));
    }
    Ok(parsed)
}

fn ini_error(number: usize, message: impl std::fmt::Display) -> ProfileError {
    ProfileError::Invalid(format!("LastSsn line {}: {message}", number + 1))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_duplicate_or_misplaced_lastsnn_fields() {
        let duplicate = "[RemoteHost]\nRemoteIpAddr=127.0.0.1;x\nRemoteIpAddr=127.0.0.2;x";
        assert!(matches!(
            parse_lastsnn_ini(duplicate),
            Err(ProfileError::Invalid(message)) if message == "LastSsn line 3: duplicate or misplaced key"
        ));

        let misplaced = "RemoteIpAddr=127.0.0.1;x";
        assert!(matches!(
            parse_lastsnn_ini(misplaced),
            Err(ProfileError::Invalid(message)) if message == "LastSsn line 1: duplicate or misplaced key"
        ));
    }
}
