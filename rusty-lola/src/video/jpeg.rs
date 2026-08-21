//! In-memory JPEG encode/decode (quality clamped 40–100 like closed UI).

use image::{DynamicImage, GrayImage, ImageBuffer, Rgb};
use std::io::Cursor;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum JpegError {
    #[error("invalid dimensions")]
    Dims,
    #[error("pixel buffer too short: {0} < {1}")]
    Short(usize, usize),
    #[error("empty JPEG data")]
    Empty,
    #[error("image: {0}")]
    Image(String),
}

pub fn clamp_jpeg_quality(quality: u8) -> u8 {
    quality.clamp(40, 100)
}

#[derive(Debug, Clone)]
pub struct DecodedImage {
    pub width: u32,
    pub height: u32,
    pub mode: String, // "L" or "RGB"
    pub pixels: Vec<u8>,
}

pub fn encode_jpeg(
    pixels: &[u8],
    width: u32,
    height: u32,
    mode: &str,
    quality: u8,
) -> Result<Vec<u8>, JpegError> {
    if width == 0 || height == 0 {
        return Err(JpegError::Dims);
    }
    let mode = mode.to_ascii_uppercase();
    let mode = if mode == "GRAY8" {
        "L".to_string()
    } else {
        mode
    };
    let q = clamp_jpeg_quality(quality);
    let expected = width as usize * height as usize * (if mode == "L" { 1 } else { 3 });
    if pixels.len() < expected {
        return Err(JpegError::Short(pixels.len(), expected));
    }
    let img = if mode == "L" {
        let g = GrayImage::from_raw(width, height, pixels[..expected].to_vec())
            .ok_or(JpegError::Dims)?;
        DynamicImage::ImageLuma8(g)
    } else {
        let mut buf = ImageBuffer::<Rgb<u8>, Vec<u8>>::new(width, height);
        for (i, p) in buf.pixels_mut().enumerate() {
            let o = i * 3;
            *p = Rgb([pixels[o], pixels[o + 1], pixels[o + 2]]);
        }
        DynamicImage::ImageRgb8(buf)
    };
    let mut out = Cursor::new(Vec::new());
    let mut encoder = image::codecs::jpeg::JpegEncoder::new_with_quality(&mut out, q);
    encoder
        .encode_image(&img)
        .map_err(|e| JpegError::Image(e.to_string()))?;
    Ok(out.into_inner())
}

pub fn decode_jpeg(data: &[u8]) -> Result<DecodedImage, JpegError> {
    if data.is_empty() {
        return Err(JpegError::Empty);
    }
    let img = image::load_from_memory(data).map_err(|e| JpegError::Image(e.to_string()))?;
    match img {
        DynamicImage::ImageLuma8(g) => Ok(DecodedImage {
            width: g.width(),
            height: g.height(),
            mode: "L".into(),
            pixels: g.into_raw(),
        }),
        other => {
            let rgb = other.to_rgb8();
            Ok(DecodedImage {
                width: rgb.width(),
                height: rgb.height(),
                mode: "RGB".into(),
                pixels: rgb.into_raw(),
            })
        }
    }
}

pub fn gray_to_rgb(pixels: &[u8], width: u32, height: u32) -> Result<Vec<u8>, JpegError> {
    let expected = width as usize * height as usize;
    if pixels.len() < expected {
        return Err(JpegError::Short(pixels.len(), expected));
    }
    let mut out = Vec::with_capacity(expected * 3);
    for &v in &pixels[..expected] {
        out.push(v);
        out.push(v);
        out.push(v);
    }
    Ok(out)
}

/// Encode helper used when packing JPEG media: gray expanded to RGB if needed.
pub fn encode_frame_jpeg(
    pixels: &[u8],
    width: u32,
    height: u32,
    pixel_format: &str,
    quality: u8,
) -> Result<Vec<u8>, JpegError> {
    let fmt = pixel_format.to_ascii_uppercase();
    if fmt == "RGB24" || fmt == "RGB" {
        encode_jpeg(pixels, width, height, "RGB", quality)
    } else {
        // JPEG often wants RGB; expand gray
        let rgb = gray_to_rgb(pixels, width, height)?;
        encode_jpeg(&rgb, width, height, "RGB", quality)
    }
}
