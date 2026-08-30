//! Parse XimeaColors.ini-style color correction settings.

use std::collections::HashMap;
use std::fs;
use std::path::Path;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum ColorsError {
    #[error("missing [Colors] section in {0}")]
    MissingSection(String),
    #[error("missing key {0} in {1}")]
    MissingKey(String, String),
    #[error("io: {0}")]
    Io(#[from] std::io::Error),
    #[error("invalid int for {0}")]
    BadInt(String),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ColorSettings {
    pub red_gain: i32,
    pub green_gain: i32,
    pub blue_gain: i32,
    pub gain_all: i32,
    pub luminosity: i32,
    pub chromaticity: i32,
    pub bad_pixels_correction: i32,
    pub raw_color_correction: i32,
}

/// Minimal INI parser for `[Colors]` section (case-preserving keys).
fn parse_ini_section(text: &str, section: &str) -> HashMap<String, String> {
    let mut map = HashMap::new();
    let mut in_section = false;
    for line in text.lines() {
        let s = line.trim();
        if s.is_empty() || s.starts_with('#') || s.starts_with(';') {
            continue;
        }
        if s.starts_with('[') && s.ends_with(']') {
            in_section = s[1..s.len() - 1] == *section;
            continue;
        }
        if !in_section {
            continue;
        }
        if let Some((k, v)) = s.split_once('=') {
            map.insert(k.trim().to_string(), v.trim().to_string());
        }
    }
    map
}

pub fn load_ximea_colors(path: impl AsRef<Path>) -> Result<ColorSettings, ColorsError> {
    let path_s = path.as_ref().display().to_string();
    let text = fs::read_to_string(&path)?;
    let c = parse_ini_section(&text, "Colors");
    if c.is_empty() && !text.contains("[Colors]") {
        return Err(ColorsError::MissingSection(path_s));
    }
    let req = |key: &str| -> Result<i32, ColorsError> {
        let v = c
            .get(key)
            .ok_or_else(|| ColorsError::MissingKey(key.to_string(), path_s.clone()))?;
        v.parse::<i32>()
            .map_err(|_| ColorsError::BadInt(key.to_string()))
    };
    Ok(ColorSettings {
        red_gain: req("m_RedGain")?,
        green_gain: req("m_GreenGain")?,
        blue_gain: req("m_BlueGain")?,
        gain_all: req("m_GainAll")?,
        luminosity: req("m_Luminosity")?,
        chromaticity: req("m_Chromaticity")?,
        bad_pixels_correction: req("m_BadPixelsCorrection")?,
        raw_color_correction: req("m_RawColorCorrection")?,
    })
}
