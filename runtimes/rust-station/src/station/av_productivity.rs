//! A/V productivity helpers: bandwidth, TX gain, match, scale, priority, layout.

use crate::video::resize_nn;
use serde_json::{json, Value};
use std::str::FromStr;

/// Estimate per-session TX bandwidth in Mbit/s.
///
/// Uncompressed: width * height * bytes_per_pixel * fps * 8 / 1e6.
/// JPEG: approximate fraction of uncompressed scaled by quality.
pub fn estimate_tx_bandwidth_mbps(
    width: u32,
    height: u32,
    fps: f64,
    bpp: u32,
    compression: bool,
    jpeg_quality: u8,
) -> f64 {
    let w = width.max(1) as f64;
    let h = height.max(1) as f64;
    let f = fps.max(0.1);
    let mut bytes_pp = if bpp >= 8 { (bpp / 8).max(1) } else { 1 };
    if bpp == 24 {
        bytes_pp = 3;
    } else if bpp == 16 {
        bytes_pp = 2;
    }
    let raw_mbps = (w * h * f64::from(bytes_pp) * f * 8.0) / 1_000_000.0;
    if !compression {
        return (raw_mbps * 1000.0).round() / 1000.0;
    }
    let q = jpeg_quality.clamp(1, 100) as f64;
    let frac = 0.02 + (q / 100.0) * 0.06;
    ((raw_mbps * frac) * 1000.0).round() / 1000.0
}

/// Apply TX preamp. level 1 = 0 dB, level 2 = +6 dB (~×2.0 linear).
pub fn apply_tx_audio_level(pcm: &[u8], level: f64, bits: u16) -> Vec<u8> {
    if pcm.is_empty() {
        return Vec::new();
    }
    if level <= 1.0 {
        return pcm.to_vec();
    }
    let gain = if level >= 2.0 { 2.0 } else { level.max(1.0) };
    if bits == 16 {
        let n = pcm.len() / 2;
        let mut out = vec![0u8; n * 2];
        for i in 0..n {
            let sample = i16::from_le_bytes([pcm[i * 2], pcm[i * 2 + 1]]);
            let mut v = (f64::from(sample) * gain).round() as i32;
            v = v.clamp(-32768, 32767);
            let b = (v as i16).to_le_bytes();
            out[i * 2] = b[0];
            out[i * 2 + 1] = b[1];
        }
        return out;
    }
    if bits == 8 {
        let mut out = vec![0u8; pcm.len()];
        for (i, &b) in pcm.iter().enumerate() {
            let s = i16::from(b) - 128;
            let v = ((f64::from(s) * gain).round() as i32 + 128).clamp(0, 255) as u8;
            out[i] = v;
        }
        return out;
    }
    pcm.to_vec()
}

/// Manual §4.4: audio stream parameters must match exactly.
pub fn audio_params_match(
    a_rate: u32,
    a_ch: u16,
    a_bits: u16,
    b_rate: u32,
    b_ch: u16,
    b_bits: u16,
) -> bool {
    a_rate == b_rate && a_ch == b_ch && a_bits == b_bits
}

/// Scale frame so camera content stays centered (FEAT-110-centered-scale).
///
/// When aspect ratios differ, center-crop the source then resize to destination.
pub fn centered_crop_or_scale(
    data: &[u8],
    src_w: u32,
    src_h: u32,
    dst_w: u32,
    dst_h: u32,
    pixel_format: &str,
) -> Result<Vec<u8>, String> {
    if src_w == 0 || src_h == 0 || dst_w == 0 || dst_h == 0 {
        return Err("invalid dimensions".into());
    }
    let fmt = pixel_format.to_ascii_uppercase();
    let bpp: u32 = if matches!(fmt.as_str(), "RGB24" | "RGB") {
        3
    } else {
        1
    };
    let expected = (src_w * src_h * bpp) as usize;
    if data.len() < expected {
        return Err(format!("buffer too short: {} < {}", data.len(), expected));
    }

    let src_aspect = f64::from(src_w) / f64::from(src_h);
    let dst_aspect = f64::from(dst_w) / f64::from(dst_h);
    let mut crop_w = src_w;
    let mut crop_h = src_h;
    let mut x0 = 0u32;
    let mut y0 = 0u32;
    if (src_aspect - dst_aspect).abs() > 1e-6 {
        if src_aspect > dst_aspect {
            crop_w = ((f64::from(src_h) * dst_aspect).round() as u32).max(1);
            x0 = (src_w - crop_w) / 2;
        } else {
            crop_h = ((f64::from(src_w) / dst_aspect).round() as u32).max(1);
            y0 = (src_h - crop_h) / 2;
        }
    }

    if x0 == 0 && y0 == 0 && crop_w == src_w && crop_h == src_h {
        return Ok(resize_nn(data, src_w, src_h, dst_w, dst_h, bpp));
    }

    let mut cropped = vec![0u8; (crop_w * crop_h * bpp) as usize];
    for row in 0..crop_h {
        let src_off = (((y0 + row) * src_w + x0) * bpp) as usize;
        let dst_off = (row * crop_w * bpp) as usize;
        let row_bytes = (crop_w * bpp) as usize;
        cropped[dst_off..dst_off + row_bytes].copy_from_slice(&data[src_off..src_off + row_bytes]);
    }
    Ok(resize_nn(&cropped, crop_w, crop_h, dst_w, dst_h, bpp))
}

/// Whether an incomplete uncompressed frame may be rendered.
///
/// threshold 0% → require all packets; 1–10% allow missing fraction.
pub fn incomplete_frame_ok(received_packets: u32, total_packets: u32, threshold_pct: f64) -> bool {
    let total = total_packets;
    let got = received_packets;
    if total == 0 {
        return true;
    }
    let thr = threshold_pct.clamp(0.0, 100.0);
    if thr <= 0.0 {
        return got >= total;
    }
    let need = f64::from(total) * (1.0 - thr / 100.0);
    f64::from(got) + 1e-9 >= need
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ProcessPriority {
    Normal,
    AboveNormal,
    High,
    Idle,
}

impl ProcessPriority {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Normal => "normal",
            Self::AboveNormal => "above_normal",
            Self::High => "high",
            Self::Idle => "idle",
        }
    }

    #[cfg(windows)]
    fn windows_class(self) -> u32 {
        match self {
            Self::Normal => 0x0000_0020,
            Self::AboveNormal => 0x0000_8000,
            Self::High => 0x0000_0080,
            Self::Idle => 0x0000_0040,
        }
    }
}

impl FromStr for ProcessPriority {
    type Err = &'static str;

    fn from_str(value: &str) -> Result<Self, Self::Err> {
        match value.trim().to_ascii_lowercase().replace(' ', "_").as_str() {
            "normal" => Ok(Self::Normal),
            "above_normal" => Ok(Self::AboveNormal),
            "high" => Ok(Self::High),
            "idle" => Ok(Self::Idle),
            _ => Err("priority must be normal, above_normal, high, or idle"),
        }
    }
}

/// Set process priority. Returns the applied level, `unsupported`, or
/// `invalid`; invalid values never coerce to a different priority.
pub fn set_process_priority(level: &str) -> String {
    let Ok(priority) = ProcessPriority::from_str(level) else {
        return "invalid".into();
    };
    #[cfg(windows)]
    {
        // SAFETY: GetCurrentProcess returns a pseudo-handle; SetPriorityClass is safe with it.
        #[link(name = "kernel32")]
        extern "system" {
            fn GetCurrentProcess() -> *mut std::ffi::c_void;
            fn SetPriorityClass(h: *mut std::ffi::c_void, class: u32) -> i32;
        }
        // SAFETY: both functions are process-local Win32 APIs; the pseudo-
        // handle returned by GetCurrentProcess is valid for SetPriorityClass.
        unsafe {
            let handle = GetCurrentProcess();
            if SetPriorityClass(handle, priority.windows_class()) == 0 {
                return "unsupported".into();
            }
        }
        priority.as_str().into()
    }
    #[cfg(not(windows))]
    {
        let _ = priority;
        "unsupported".into()
    }
}

/// Window layout rects for local/remote (manual §4.13).
/// mode: tile_v | tile_h | max_remote
pub fn layout_geometry(mode: &str, screen_w: u32, screen_h: u32) -> Value {
    let w = screen_w.max(100);
    let h = screen_h.max(100);
    let m = mode.trim().to_ascii_lowercase();
    if matches!(m.as_str(), "tile_h" | "horizontal" | "tile_horizontally") {
        let half = w / 2;
        return json!({
            "mode": "tile_h",
            "local": {"x": 0, "y": 0, "w": half, "h": h},
            "remote": {"x": half, "y": 0, "w": w - half, "h": h},
        });
    }
    if matches!(m.as_str(), "max_remote" | "maximize_remote" | "max") {
        return json!({
            "mode": "max_remote",
            "local": {"x": 0, "y": 0, "w": (w / 5).max(160), "h": (h / 5).max(90)},
            "remote": {"x": 0, "y": 0, "w": w, "h": h},
        });
    }
    let half = h / 2;
    json!({
        "mode": "tile_v",
        "local": {"x": 0, "y": 0, "w": w, "h": half},
        "remote": {"x": 0, "y": half, "w": w, "h": h - half},
    })
}

/// Clamp local camera index to 0..max_cameras-1.
pub fn multi_camera_index(index: i32, max_cameras: u32) -> u32 {
    let n = max_cameras.max(1) as i32;
    index.clamp(0, n - 1) as u32
}
