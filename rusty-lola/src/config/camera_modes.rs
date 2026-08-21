//! Parse LoLa-compatible camera mode catalog lines (CAMERAFILES/*.ini).

use crate::protocol::{MAX_DIMENSION_PIXELS, MAX_FRAME_RATE};
use regex::Regex;
use std::collections::BTreeMap;
use std::fs;
use std::path::Path;
use std::sync::OnceLock;
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

fn mode_re() -> &'static Regex {
    static RE: OnceLock<Regex> = OnceLock::new();
    RE.get_or_init(|| {
        Regex::new(
            r"^(?P<id>\d{3})-(?P<vendor>[A-Za-z0-9]+)-(?P<model>[A-Za-z0-9_]+)-(?P<width>\d+)x(?P<height>\d+)-(?P<format>Mono8|RGB24)-Fps(?P<fps>\d+)\s*$",
        )
        .expect("mode regex")
    })
}

pub fn parse_mode_line(line: &str) -> Result<Option<CameraMode>, CatalogError> {
    let s = line.trim();
    if s.is_empty() || s.starts_with('#') || s.starts_with(';') {
        return Ok(None);
    }
    let m = mode_re()
        .captures(s)
        .ok_or_else(|| CatalogError::InvalidLine(line.to_string()))?;
    let width = parse_catalog_number(&m["width"], "width", s, MAX_DIMENSION_PIXELS)?;
    let height = parse_catalog_number(&m["height"], "height", s, MAX_DIMENSION_PIXELS)?;
    let max_fps = parse_catalog_number(&m["fps"], "fps", s, MAX_FRAME_RATE)?;
    Ok(Some(CameraMode {
        mode_id: m["id"].to_string(),
        vendor: m["vendor"].to_string(),
        model: m["model"].to_string(),
        width,
        height,
        pixel_format: m["format"].to_string(),
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

pub fn load_camera_catalogs(directory: impl AsRef<Path>) -> BTreeMap<String, Vec<CameraMode>> {
    let d = directory.as_ref();
    let mut catalogs = BTreeMap::new();
    if !d.is_dir() {
        return catalogs;
    }
    let mut paths: Vec<_> = match fs::read_dir(d) {
        Ok(rd) => rd.filter_map(|e| e.ok()).map(|e| e.path()).collect(),
        Err(_) => return catalogs,
    };
    paths.sort();
    for path in paths {
        if path.extension().and_then(|e| e.to_str()) != Some("ini") {
            continue;
        }
        // Skip colors-style files that are not mode catalogs
        if let Ok(modes) = load_camera_modes(&path) {
            if modes.is_empty() {
                continue;
            }
            if let Some(stem) = path.file_stem().and_then(|s| s.to_str()) {
                catalogs.insert(stem.to_string(), modes);
            }
        }
    }
    catalogs
}

pub fn find_mode_across<'a>(
    catalogs: &'a BTreeMap<String, Vec<CameraMode>>,
    mode_id: &str,
) -> Option<&'a CameraMode> {
    for modes in catalogs.values() {
        if let Some(m) = find_mode(modes, mode_id) {
            return Some(m);
        }
    }
    None
}

pub fn shipped_camera_catalogs() -> BTreeMap<String, Vec<CameraMode>> {
    load_camera_catalogs(crate::shipped_camera_modes_dir())
}
