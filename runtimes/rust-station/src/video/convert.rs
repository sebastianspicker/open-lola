//! Offline frame conversion: debayer, BGR↔RGB, BMP→JPEG.

use super::jpeg::{clamp_jpeg_quality, encode_jpeg};
use image::{DynamicImage, ImageFormat, RgbImage};
use std::fs;
use std::path::{Path, PathBuf};
use thiserror::Error;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ConvertMode {
    Debayer,
    Bgr2Rgb,
    Bmp2Jpeg,
}

impl ConvertMode {
    pub fn parse(s: &str) -> Option<Self> {
        match s.to_ascii_lowercase().as_str() {
            "debayer" => Some(Self::Debayer),
            "bgr2rgb" => Some(Self::Bgr2Rgb),
            "bmp2jpeg" | "bmp2jpg" => Some(Self::Bmp2Jpeg),
            _ => None,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BayerPattern {
    Bggr,
    Gbrg,
    Rggb,
    Grbg,
}

impl BayerPattern {
    pub fn parse(s: &str) -> Option<Self> {
        match s.to_ascii_uppercase().as_str() {
            "BGGR" => Some(Self::Bggr),
            "GBRG" => Some(Self::Gbrg),
            "RGGB" => Some(Self::Rggb),
            "GRBG" => Some(Self::Grbg),
            _ => None,
        }
    }

    fn color_at(self, x: u32, y: u32) -> char {
        let phase = match self {
            Self::Bggr => [['B', 'G'], ['G', 'R']],
            Self::Gbrg => [['G', 'B'], ['R', 'G']],
            Self::Rggb => [['R', 'G'], ['G', 'B']],
            Self::Grbg => [['G', 'R'], ['B', 'G']],
        };
        phase[(y & 1) as usize][(x & 1) as usize]
    }
}

#[derive(Debug, Error)]
pub enum ConvertError {
    #[error("invalid dimensions")]
    Dims,
    #[error("Mono8 buffer too short: {0} < {1}")]
    Short(usize, usize),
    #[error("io: {0}")]
    Io(#[from] std::io::Error),
    #[error("image: {0}")]
    Image(String),
    #[error("unknown convert mode")]
    BadMode,
    #[error("unknown Bayer pattern")]
    BadPattern,
}

fn sample(src: &[u8], width: u32, height: u32, xx: i32, yy: i32) -> u8 {
    let xx = xx.clamp(0, width as i32 - 1) as u32;
    let yy = yy.clamp(0, height as i32 - 1) as u32;
    src[(yy * width + xx) as usize]
}

fn avg(vals: &[u8]) -> u8 {
    if vals.is_empty() {
        return 0;
    }
    (vals.iter().map(|&v| v as u32).sum::<u32>() / vals.len() as u32) as u8
}

/// Demosaic packed Mono8 Bayer to packed RGB24 (bilinear-style neighbour sampling).
pub fn demosaic_mono8(
    pixels: &[u8],
    width: u32,
    height: u32,
    pattern: BayerPattern,
) -> Result<Vec<u8>, ConvertError> {
    if width == 0 || height == 0 {
        return Err(ConvertError::Dims);
    }
    let expected = (width * height) as usize;
    if pixels.len() < expected {
        return Err(ConvertError::Short(pixels.len(), expected));
    }
    let src = &pixels[..expected];
    let mut out = vec![0u8; expected * 3];
    for y in 0..height {
        for x in 0..width {
            let c = pattern.color_at(x, y);
            let (r, g, b) = match c {
                'R' => {
                    let r = sample(src, width, height, x as i32, y as i32);
                    let g = avg(&[
                        sample(src, width, height, x as i32 - 1, y as i32),
                        sample(src, width, height, x as i32 + 1, y as i32),
                        sample(src, width, height, x as i32, y as i32 - 1),
                        sample(src, width, height, x as i32, y as i32 + 1),
                    ]);
                    let b = avg(&[
                        sample(src, width, height, x as i32 - 1, y as i32 - 1),
                        sample(src, width, height, x as i32 + 1, y as i32 - 1),
                        sample(src, width, height, x as i32 - 1, y as i32 + 1),
                        sample(src, width, height, x as i32 + 1, y as i32 + 1),
                    ]);
                    (r, g, b)
                }
                'B' => {
                    let b = sample(src, width, height, x as i32, y as i32);
                    let g = avg(&[
                        sample(src, width, height, x as i32 - 1, y as i32),
                        sample(src, width, height, x as i32 + 1, y as i32),
                        sample(src, width, height, x as i32, y as i32 - 1),
                        sample(src, width, height, x as i32, y as i32 + 1),
                    ]);
                    let r = avg(&[
                        sample(src, width, height, x as i32 - 1, y as i32 - 1),
                        sample(src, width, height, x as i32 + 1, y as i32 - 1),
                        sample(src, width, height, x as i32 - 1, y as i32 + 1),
                        sample(src, width, height, x as i32 + 1, y as i32 + 1),
                    ]);
                    (r, g, b)
                }
                _ => {
                    // Green
                    let g = sample(src, width, height, x as i32, y as i32);
                    // Horizontal vs vertical neighbours differ by pattern phase
                    let r = avg(&[
                        sample(src, width, height, x as i32 - 1, y as i32),
                        sample(src, width, height, x as i32 + 1, y as i32),
                    ]);
                    let b = avg(&[
                        sample(src, width, height, x as i32, y as i32 - 1),
                        sample(src, width, height, x as i32, y as i32 + 1),
                    ]);
                    // Swap R/B depending on row for correct BGGR etc.
                    if (y & 1) == 0 {
                        if (x & 1) == 0 {
                            // actual G on even row — use pattern-aware
                            let neighbors_h = [
                                sample(src, width, height, x as i32 - 1, y as i32),
                                sample(src, width, height, x as i32 + 1, y as i32),
                            ];
                            let neighbors_v = [
                                sample(src, width, height, x as i32, y as i32 - 1),
                                sample(src, width, height, x as i32, y as i32 + 1),
                            ];
                            match pattern {
                                BayerPattern::Bggr | BayerPattern::Rggb => {
                                    (avg(&neighbors_v), g, avg(&neighbors_h))
                                }
                                BayerPattern::Gbrg | BayerPattern::Grbg => {
                                    (avg(&neighbors_h), g, avg(&neighbors_v))
                                }
                            }
                        } else {
                            (r, g, b)
                        }
                    } else {
                        (r, g, b)
                    }
                }
            };
            let i = ((y * width + x) * 3) as usize;
            out[i] = r;
            out[i + 1] = g;
            out[i + 2] = b;
        }
    }
    Ok(out)
}

pub fn bgr_to_rgb(pixels: &[u8]) -> Vec<u8> {
    let mut out = pixels.to_vec();
    for chunk in out.as_chunks_mut::<3>().0 {
        chunk.swap(0, 2);
    }
    out
}

/// Convert a single image file according to mode; writes into out_dir.
pub fn convert_image_file(
    path: &Path,
    out_dir: &Path,
    mode: ConvertMode,
    pattern: BayerPattern,
    jpeg_quality: u8,
) -> Result<PathBuf, ConvertError> {
    fs::create_dir_all(out_dir)?;
    let stem = path.file_stem().and_then(|s| s.to_str()).unwrap_or("frame");
    match mode {
        ConvertMode::Bmp2Jpeg => {
            let img = image::open(path).map_err(|e| ConvertError::Image(e.to_string()))?;
            let rgb = img.to_rgb8();
            let jpeg = encode_jpeg(
                rgb.as_raw(),
                rgb.width(),
                rgb.height(),
                "RGB",
                clamp_jpeg_quality(jpeg_quality),
            )
            .map_err(|e| ConvertError::Image(e.to_string()))?;
            let out = out_dir.join(format!("{stem}.jpg"));
            fs::write(&out, jpeg)?;
            Ok(out)
        }
        ConvertMode::Bgr2Rgb => {
            let img = image::open(path).map_err(|e| ConvertError::Image(e.to_string()))?;
            let rgb = img.to_rgb8();
            let swapped = bgr_to_rgb(rgb.as_raw());
            let out_img =
                RgbImage::from_raw(rgb.width(), rgb.height(), swapped).ok_or(ConvertError::Dims)?;
            let out = out_dir.join(format!("{stem}_rgb.png"));
            DynamicImage::ImageRgb8(out_img)
                .save_with_format(&out, ImageFormat::Png)
                .map_err(|e| ConvertError::Image(e.to_string()))?;
            Ok(out)
        }
        ConvertMode::Debayer => {
            let img = image::open(path).map_err(|e| ConvertError::Image(e.to_string()))?;
            let gray = img.to_luma8();
            let rgb = demosaic_mono8(gray.as_raw(), gray.width(), gray.height(), pattern)?;
            let out_img =
                RgbImage::from_raw(gray.width(), gray.height(), rgb).ok_or(ConvertError::Dims)?;
            let out = out_dir.join(format!("{stem}_debayer.png"));
            DynamicImage::ImageRgb8(out_img)
                .save_with_format(&out, ImageFormat::Png)
                .map_err(|e| ConvertError::Image(e.to_string()))?;
            Ok(out)
        }
    }
}

/// Convert all image files in a directory (or a single file).
pub fn convert_path(
    input: impl AsRef<Path>,
    out_dir: impl AsRef<Path>,
    mode: ConvertMode,
    pattern: BayerPattern,
    jpeg_quality: u8,
) -> Result<Vec<PathBuf>, ConvertError> {
    let input = input.as_ref();
    let out_dir = out_dir.as_ref();
    fs::create_dir_all(out_dir)?;
    let mut paths = Vec::new();
    if input.is_file() {
        paths.push(input.to_path_buf());
    } else if input.is_dir() {
        for e in fs::read_dir(input)? {
            let p = e?.path();
            if let Some(ext) = p.extension().and_then(|e| e.to_str()) {
                let ext = ext.to_ascii_lowercase();
                if matches!(
                    ext.as_str(),
                    "bmp" | "png" | "jpg" | "jpeg" | "tif" | "tiff"
                ) {
                    paths.push(p);
                }
            }
        }
        paths.sort();
    }
    let mut written = Vec::new();
    for p in paths {
        written.push(convert_image_file(
            &p,
            out_dir,
            mode,
            pattern,
            jpeg_quality,
        )?);
    }
    Ok(written)
}
