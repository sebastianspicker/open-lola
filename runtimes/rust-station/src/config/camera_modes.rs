//! Parse LoLa-compatible camera mode catalog lines (CAMERAFILES/*.ini).

use crate::protocol::{MAX_DIMENSION_PIXELS, MAX_FRAME_RATE};
use std::fs;
use std::path::Path;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum CatalogError {
    #[error("invalid camera mode line: {0}")]
    InvalidLine(String),
    #[error("invalid {field} value {value:?} in camera mode line: {line}")]
    InvalidNumber {
        field: &'static str,
        value: String,
        line: String,
    },
    #[error("camera mode {field} value {value} is outside 1..={maximum}: {line}")]
    OutOfRange {
        field: &'static str,
        value: u32,
        maximum: u32,
        line: String,
    },
    #[error("io: {0}")]
    Io(#[from] std::io::Error),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CameraMode {
    pub mode_id: String,
    pub vendor: String,
    pub model: String,
    pub width: u32,
    pub height: u32,
    pub pixel_format: String,
    pub max_fps: u32,
    pub raw_line: String,
}

impl CameraMode {
    pub fn is_bayer_mono8(&self) -> bool {
        self.pixel_format == "Mono8"
    }
}

struct ModeFields<'a> {
    id: &'a str,
    vendor: &'a str,
    model: &'a str,
    width: &'a str,
    height: &'a str,
    format: &'a str,
    fps: &'a str,
}

/// Splits `NNN-Vendor-Model-WxH-(Mono8|RGB24)-FpsN`; vendor and model contain no `-`.
fn split_mode_line(s: &str) -> Option<ModeFields<'_>> {
    let mut parts = s.splitn(6, '-');
    let (id, vendor, model, size, format, fps) = (
        parts.next()?,
        parts.next()?,
        parts.next()?,
        parts.next()?,
        parts.next()?,
        parts.next()?.strip_prefix("Fps")?,
    );
    let (width, height) = size.split_once('x')?;
    let digits = |t: &str| !t.is_empty() && t.bytes().all(|b| b.is_ascii_digit());
    let word = |t: &str, extra: bool| {
        !t.is_empty()
            && t.bytes()
                .all(|b| b.is_ascii_alphanumeric() || (extra && b == b'_'))
    };
    let valid = id.len() == 3
        && digits(id)
        && word(vendor, false)
        && word(model, true)
        && digits(width)
        && digits(height)
        && matches!(format, "Mono8" | "RGB24")
        && digits(fps);
    valid.then_some(ModeFields {
        id,
        vendor,
        model,
        width,
        height,
        format,
        fps,
    })
}

pub fn parse_mode_line(line: &str) -> Result<Option<CameraMode>, CatalogError> {
    let s = line.trim();
    if s.is_empty() || s.starts_with('#') || s.starts_with(';') {
        return Ok(None);
    }
    let m = split_mode_line(s).ok_or_else(|| CatalogError::InvalidLine(line.to_string()))?;
    let width = parse_catalog_number(m.width, "width", s, MAX_DIMENSION_PIXELS)?;
    let height = parse_catalog_number(m.height, "height", s, MAX_DIMENSION_PIXELS)?;
    let max_fps = parse_catalog_number(m.fps, "fps", s, MAX_FRAME_RATE)?;
    Ok(Some(CameraMode {
        mode_id: m.id.to_string(),
        vendor: m.vendor.to_string(),
        model: m.model.to_string(),
        width,
        height,
        pixel_format: m.format.to_string(),
        max_fps,
        raw_line: s.to_string(),
    }))
}

fn parse_catalog_number(
    value: &str,
    field: &'static str,
    line: &str,
    maximum: u32,
) -> Result<u32, CatalogError> {
    let parsed = value
        .parse::<u32>()
        .map_err(|_| CatalogError::InvalidNumber {
            field,
            value: value.into(),
            line: line.into(),
        })?;
    if !(1..=maximum).contains(&parsed) {
        return Err(CatalogError::OutOfRange {
            field,
            value: parsed,
            maximum,
            line: line.into(),
        });
    }
    Ok(parsed)
}

pub fn load_camera_modes(path: impl AsRef<Path>) -> Result<Vec<CameraMode>, CatalogError> {
    let text = fs::read_to_string(path)?;
    let mut modes = Vec::new();
    for line in text.lines() {
        if let Some(mode) = parse_mode_line(line)? {
            modes.push(mode);
        }
    }
    Ok(modes)
}

pub fn find_mode<'a>(modes: &'a [CameraMode], mode_id: &str) -> Option<&'a CameraMode> {
    modes.iter().find(|m| m.mode_id == mode_id)
}
