//! Software camera: synthetic frames for CI / no-hardware path.

use crate::config::CameraMode;

/// Approximate SMPTE / EBU color-bar primaries (RGB 8-bit). Manual §4.12.
const SMPTE_BARS_RGB: [(u8, u8, u8); 8] = [
    (180, 180, 180), // white/gray
    (180, 180, 16),  // yellow
    (16, 180, 180),  // cyan
    (16, 180, 16),   // green
    (180, 16, 180),  // magenta
    (180, 16, 16),   // red
    (16, 16, 180),   // blue
    (16, 16, 16),    // black
];

/// Generate SMPTE-style vertical color bars for A/V test signal (manual §4.12).
/// When `mono8` is true, returns Gray8 luminance of the bars.
pub fn generate_smpte_bars(width: u32, height: u32, mono8: bool) -> Result<Vec<u8>, String> {
    if width == 0 || height == 0 {
        return Err("invalid dimensions".into());
    }
    let n = SMPTE_BARS_RGB.len() as u32;
    let bpp = if mono8 { 1 } else { 3 };
    let mut out = vec![0u8; (width * height * bpp) as usize];
    for y in 0..height {
        for x in 0..width {
            let bar = ((x * n) / width).min(n - 1) as usize;
            let (r, g, b) = SMPTE_BARS_RGB[bar];
            if mono8 {
                // Rec.601-ish luminance
                out[(y * width + x) as usize] =
                    ((77u32 * u32::from(r) + 150u32 * u32::from(g) + 29u32 * u32::from(b)) >> 8)
                        as u8;
            } else {
                let i = ((y * width + x) * 3) as usize;
                out[i] = r;
                out[i + 1] = g;
                out[i + 2] = b;
            }
        }
    }
    Ok(out)
}

#[derive(Debug, Clone)]
pub struct SoftwareCamera {
    pub width: u32,
    pub height: u32,
    pub pixel_format: String,
    pub frame: u32,
    opened: bool,
}

impl Default for SoftwareCamera {
    fn default() -> Self {
        Self {
            width: 160,
            height: 120,
            pixel_format: "Mono8".into(),
            frame: 0,
            opened: false,
        }
    }
}

impl SoftwareCamera {
    pub fn open(&mut self, mode: &CameraMode) {
        self.width = mode.width;
        self.height = mode.height;
        self.pixel_format = mode.pixel_format.clone();
        self.opened = true;
        self.frame = 0;
    }

    pub fn open_dims(&mut self, width: u32, height: u32, pixel_format: &str) {
        self.width = width;
        self.height = height;
        self.pixel_format = pixel_format.to_string();
        self.opened = true;
        self.frame = 0;
    }

    pub fn start(&mut self) {
        self.frame = 0;
    }

    pub fn stop(&mut self) {}

    /// Grab one frame; returns (pixels, pixel_format).
    pub fn grab(&mut self) -> (Vec<u8>, String) {
        let w = self.width.max(1);
        let h = self.height.max(1);
        let fmt = self.pixel_format.clone();
        let f = self.frame;
        self.frame = self.frame.wrapping_add(1);
        if fmt.eq_ignore_ascii_case("RGB24") || fmt.eq_ignore_ascii_case("RGB") {
            let mut px = vec![0u8; (w * h * 3) as usize];
            for y in 0..h {
                for x in 0..w {
                    let i = ((y * w + x) * 3) as usize;
                    px[i] = ((x + f) % 256) as u8;
                    px[i + 1] = ((y + f) % 256) as u8;
                    px[i + 2] = ((x + y + f) % 256) as u8;
                }
            }
            (px, "RGB24".into())
        } else {
            let mut px = vec![0u8; (w * h) as usize];
            for y in 0..h {
                for x in 0..w {
                    px[(y * w + x) as usize] =
                        ((x.wrapping_mul(3) + y.wrapping_mul(5) + f) % 256) as u8;
                }
            }
            (px, "Mono8".into())
        }
    }
}

/// Nearest-neighbour resize for Mono8 or RGB24.
pub fn resize_nn(
    pixels: &[u8],
    src_w: u32,
    src_h: u32,
    dst_w: u32,
    dst_h: u32,
    bpp: u32,
) -> Vec<u8> {
    if dst_w == 0 || dst_h == 0 || src_w == 0 || src_h == 0 {
        return Vec::new();
    }
    let bpp = bpp.max(1) as usize;
    let mut out = vec![0u8; (dst_w * dst_h) as usize * bpp];
    for y in 0..dst_h {
        let sy = y * src_h / dst_h;
        for x in 0..dst_w {
            let sx = x * src_w / dst_w;
            let si = (sy * src_w + sx) as usize * bpp;
            let di = (y * dst_w + x) as usize * bpp;
            out[di..di + bpp].copy_from_slice(&pixels[si..si + bpp]);
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn smpte_bars_rgb_size_and_distinct() {
        let bars = generate_smpte_bars(64, 32, false).unwrap();
        assert_eq!(bars.len(), 64 * 32 * 3);
        assert_eq!(&bars[0..3], &[180, 180, 180]);
        let last = ((32 - 1) * 64 + (64 - 1)) * 3;
        assert_eq!(&bars[last..last + 3], &[16, 16, 16]);
        let mid = (16 * 64 + 32) * 3;
        assert_ne!(&bars[mid..mid + 3], &[180, 180, 180]);
    }

    #[test]
    fn smpte_bars_mono_luma() {
        let bars = generate_smpte_bars(16, 8, true).unwrap();
        assert_eq!(bars.len(), 16 * 8);
        assert!(bars[0] > bars[15]);
    }
}
