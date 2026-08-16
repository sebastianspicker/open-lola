//! TESTER / lab emulation path — software modes E01–E08.

use crate::config::{default_settings, StationSettings};
use crate::station::session::{run_session, SessionOptions, SessionResult};
use serde_json::{json, Value};

#[derive(Debug, Clone)]
pub struct EmulationMode {
    pub mode_id: String,
    pub width: u32,
    pub height: u32,
    pub pixel_format: String,
    pub description: String,
}

impl EmulationMode {
    pub fn to_json(&self) -> Value {
        json!({
            "mode_id": self.mode_id,
            "width": self.width,
            "height": self.height,
            "pixel_format": self.pixel_format,
            "description": self.description,
        })
    }
}

/// Closed TESTER-style software camera emulation modes.
pub fn emulation_modes() -> Vec<EmulationMode> {
    vec![
        EmulationMode {
            mode_id: "E01".into(),
            width: 320,
            height: 240,
            pixel_format: "RGB24".into(),
            description: "320x240 RGB24 emulation".into(),
        },
        EmulationMode {
            mode_id: "E02".into(),
            width: 640,
            height: 480,
            pixel_format: "RGB24".into(),
            description: "640x480 RGB24 emulation".into(),
        },
        EmulationMode {
            mode_id: "E03".into(),
            width: 160,
            height: 120,
            pixel_format: "RGB24".into(),
            description: "160x120 RGB24 emulation".into(),
        },
        EmulationMode {
            mode_id: "E04".into(),
            width: 1280,
            height: 720,
            pixel_format: "RGB24".into(),
            description: "1280x720 RGB24 emulation".into(),
        },
        EmulationMode {
            mode_id: "E05".into(),
            width: 320,
            height: 240,
            pixel_format: "Mono8".into(),
            description: "320x240 Mono8/Bayer emulation".into(),
        },
        EmulationMode {
            mode_id: "E06".into(),
            width: 640,
            height: 480,
            pixel_format: "Mono8".into(),
            description: "640x480 Mono8/Bayer emulation".into(),
        },
        EmulationMode {
            mode_id: "E07".into(),
            width: 1280,
            height: 720,
            pixel_format: "Mono8".into(),
            description: "1280x720 Mono8/Bayer emulation".into(),
        },
        EmulationMode {
            mode_id: "E08".into(),
            width: 1024,
            height: 768,
            pixel_format: "Mono8".into(),
            description: "1024x768 Mono8/Bayer emulation".into(),
        },
    ]
}

pub fn list_emulation_modes() -> Vec<EmulationMode> {
    emulation_modes()
}

pub fn find_emulation_mode(mode_id: Option<&str>) -> Result<EmulationMode, String> {
    let modes = emulation_modes();
    let key = mode_id.unwrap_or("").trim();
    if key.is_empty() {
        return Ok(modes[0].clone());
    }
    for m in &modes {
        if m.mode_id.eq_ignore_ascii_case(key) {
            return Ok(m.clone());
        }
    }
    if let Ok(idx) = key.parse::<usize>() {
        if idx < modes.len() {
            return Ok(modes[idx].clone());
        }
    }
    Err(format!(
        "unknown emulation mode_id {key:?}; known: {:?}",
        modes.iter().map(|m| m.mode_id.as_str()).collect::<Vec<_>>()
    ))
}

fn settings_for_emulation(
    settings: Option<StationSettings>,
    mode: &EmulationMode,
    compress: bool,
) -> StationSettings {
    let mut s = settings.unwrap_or_else(default_settings);
    if s.network.local_ip.is_empty() {
        s.network.local_ip = "127.0.0.1".into();
    }
    if s.network.remote_ip.is_empty() {
        s.network.remote_ip = "127.0.0.1".into();
    }
    s.video.camera_mode_id = mode.mode_id.clone();
    s.video.width = mode.width;
    s.video.height = mode.height;
    s.video.bpp = if mode.pixel_format == "RGB24" { 24 } else { 8 };
    s.video.bayer = if mode.pixel_format == "Mono8" { 1 } else { 0 };
    s.video.compression = compress;
    s
}

/// Run no-hardware emulation session for mode E01–E08.
pub fn run_emulation(
    mode_id: Option<&str>,
    timeout: f64,
    frames: u32,
    compress: bool,
) -> Result<SessionResult, String> {
    let mode = find_emulation_mode(mode_id)?;
    let settings = settings_for_emulation(None, &mode, compress);
    let mut opts = SessionOptions::demo();
    opts.stream_frames = frames.max(1);
    opts.control_extras = true;
    opts.use_catalog_geometry = false; // geometry forced by emulation mode
    opts.apply_color = mode.pixel_format == "RGB24" || mode.pixel_format == "Mono8";
    opts.auto_bayer = mode.pixel_format == "Mono8";
    let mut result = run_session(settings, timeout, opts);
    // Annotate capabilities with emulation mode
    result
        .capabilities
        .insert("EMULATION_MODE".into(), json!(mode.mode_id));
    Ok(result)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn lists_eight_modes() {
        let m = list_emulation_modes();
        assert_eq!(m.len(), 8);
        assert_eq!(m[0].mode_id, "E01");
        assert_eq!(m[7].mode_id, "E08");
    }

    #[test]
    fn find_by_id() {
        let m = find_emulation_mode(Some("E05")).unwrap();
        assert_eq!(m.pixel_format, "Mono8");
        assert_eq!(m.width, 320);
    }
}
