//! Apply XimeaColors-style channel gains to packed pixel buffers.

use crate::config::ColorSettings;

/// Closed / shipped XimeaColors treat this integer as unity white-balance.
pub const DEFAULT_GAIN_BASELINE: i32 = 64;

#[inline]
fn clamp_u8(v: i32) -> u8 {
    if v < 0 {
        0
    } else if v > 255 {
        255
    } else {
        v as u8
    }
}

/// Scale an 8-bit sample by gain/baseline and clamp to 0..255.
pub fn scale_channel(value: u8, gain: i32, baseline: i32) -> u8 {
    if baseline <= 0 {
        return value;
    }
    clamp_u8((i32::from(value) * gain + baseline / 2) / baseline)
}

pub fn gains_from_colors(colors: &ColorSettings) -> (i32, i32, i32) {
    (colors.red_gain, colors.green_gain, colors.blue_gain)
}

/// Apply channel gains to a packed Mono8 or RGB24 buffer.
///
/// Gains are relative to `baseline` (default 64 = unity). Mono8 uses green_gain.
#[allow(clippy::too_many_arguments)]
pub fn apply_color_gains(
    pixels: &[u8],
    width: u32,
    height: u32,
    pixel_format: &str,
    colors: Option<&ColorSettings>,
    red_gain: Option<i32>,
    green_gain: Option<i32>,
    blue_gain: Option<i32>,
    baseline: i32,
) -> Result<Vec<u8>, String> {
    if width == 0 || height == 0 {
        return Err("invalid dimensions".into());
    }
    if baseline <= 0 {
        return Err("baseline must be positive".into());
    }

    let (mut rg, mut gg, mut bg) = if let Some(c) = colors {
        gains_from_colors(c)
    } else {
        (baseline, baseline, baseline)
    };
    if let Some(v) = red_gain {
        rg = v;
    }
    if let Some(v) = green_gain {
        gg = v;
    }
    if let Some(v) = blue_gain {
        bg = v;
    }
    if colors.is_none() && red_gain.is_none() && green_gain.is_none() && blue_gain.is_none() {
        return Err("provide colors and/or channel gains".into());
    }

    let fmt = pixel_format.trim().to_ascii_uppercase();
    let n = (width as usize) * (height as usize);

    if matches!(fmt.as_str(), "MONO8" | "GRAY8" | "GREY8" | "L") {
        if pixels.len() != n {
            return Err(format!(
                "Mono8 buffer length {} != {} ({}x{})",
                pixels.len(),
                n,
                width,
                height
            ));
        }
        if gg == baseline {
            return Ok(pixels.to_vec());
        }
        let mut out = vec![0u8; n];
        for (i, &v) in pixels.iter().enumerate() {
            out[i] = scale_channel(v, gg, baseline);
        }
        return Ok(out);
    }

    if matches!(fmt.as_str(), "RGB24" | "RGB") {
        let expected = n * 3;
        if pixels.len() != expected {
            return Err(format!(
                "RGB24 buffer length {} != {} ({}x{})",
                pixels.len(),
                expected,
                width,
                height
            ));
        }
        if rg == baseline && gg == baseline && bg == baseline {
            return Ok(pixels.to_vec());
        }
        let mut out = vec![0u8; expected];
        for i in 0..n {
            let o = i * 3;
            out[o] = scale_channel(pixels[o], rg, baseline);
            out[o + 1] = scale_channel(pixels[o + 1], gg, baseline);
            out[o + 2] = scale_channel(pixels[o + 2], bg, baseline);
        }
        return Ok(out);
    }

    Err(format!("unsupported pixel_format {pixel_format}"))
}

/// Convenience: apply ColorSettings with default baseline.
pub fn apply_colors(
    pixels: &[u8],
    width: u32,
    height: u32,
    pixel_format: &str,
    colors: &ColorSettings,
) -> Result<Vec<u8>, String> {
    apply_color_gains(
        pixels,
        width,
        height,
        pixel_format,
        Some(colors),
        None,
        None,
        None,
        DEFAULT_GAIN_BASELINE,
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn scale_unity_and_double() {
        assert_eq!(scale_channel(100, 64, 64), 100);
        assert_eq!(scale_channel(100, 128, 64), 200);
        assert_eq!(scale_channel(200, 128, 64), 255);
    }

    #[test]
    fn mono_green_gain() {
        let px = vec![64u8; 4];
        let out = apply_color_gains(&px, 2, 2, "Mono8", None, None, Some(128), None, 64).unwrap();
        assert_eq!(out, vec![128, 128, 128, 128]);
    }

    #[test]
    fn rgb_channel_gains() {
        let px = vec![10u8, 20, 30, 10, 20, 30, 10, 20, 30, 10, 20, 30];
        let out =
            apply_color_gains(&px, 2, 2, "RGB24", None, Some(128), Some(64), Some(32), 64).unwrap();
        assert_eq!(out[0], 20);
        assert_eq!(out[1], 20);
        assert_eq!(out[2], 15);
    }
}
