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

fn resolve_gains(
    colors: Option<&ColorSettings>,
    overrides: (Option<i32>, Option<i32>, Option<i32>),
    baseline: i32,
) -> Result<(i32, i32, i32), String> {
    let (mut red, mut green, mut blue) =
        colors.map_or((baseline, baseline, baseline), gains_from_colors);
    if let Some(value) = overrides.0 {
        red = value;
    }
    if let Some(value) = overrides.1 {
        green = value;
    }
    if let Some(value) = overrides.2 {
        blue = value;
    }
    if colors.is_none() && overrides.0.is_none() && overrides.1.is_none() && overrides.2.is_none() {
        return Err("provide colors and/or channel gains".into());
    }
    Ok((red, green, blue))
}

fn pixel_count(width: u32, height: u32) -> Result<usize, String> {
    if width == 0 || height == 0 {
        return Err("invalid dimensions".into());
    }
    Ok((width as usize) * (height as usize))
}

fn apply_mono(
    pixels: &[u8],
    count: usize,
    gain: i32,
    baseline: i32,
    width: u32,
    height: u32,
) -> Result<Vec<u8>, String> {
    if pixels.len() != count {
        return Err(format!(
            "Mono8 buffer length {} != {} ({}x{})",
            pixels.len(),
            count,
            width,
            height
        ));
    }
    if gain == baseline {
        return Ok(pixels.to_vec());
    }
    Ok(pixels
        .iter()
        .map(|&value| scale_channel(value, gain, baseline))
        .collect())
}

fn apply_rgb(
    pixels: &[u8],
    count: usize,
    gains: (i32, i32, i32),
    baseline: i32,
    width: u32,
    height: u32,
) -> Result<Vec<u8>, String> {
    let expected = count * 3;
    if pixels.len() != expected {
        return Err(format!(
            "RGB24 buffer length {} != {} ({}x{})",
            pixels.len(),
            expected,
            width,
            height
        ));
    }
    if gains == (baseline, baseline, baseline) {
        return Ok(pixels.to_vec());
    }
    Ok(pixels
        .as_chunks::<3>()
        .0
        .iter()
        .flat_map(|pixel| {
            [
                scale_channel(pixel[0], gains.0, baseline),
                scale_channel(pixel[1], gains.1, baseline),
                scale_channel(pixel[2], gains.2, baseline),
            ]
        })
        .collect())
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
    if baseline <= 0 {
        return Err("baseline must be positive".into());
    }
    let (red, green, blue) = resolve_gains(colors, (red_gain, green_gain, blue_gain), baseline)?;
    let fmt = pixel_format.trim().to_ascii_uppercase();
    let count = pixel_count(width, height)?;
    match fmt.as_str() {
        "MONO8" | "GRAY8" | "GREY8" | "L" => {
            apply_mono(pixels, count, green, baseline, width, height)
        }
        "RGB24" | "RGB" => apply_rgb(pixels, count, (red, green, blue), baseline, width, height),
        _ => Err(format!("unsupported pixel_format {pixel_format}")),
    }
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
