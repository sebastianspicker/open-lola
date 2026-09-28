//! In-memory JPEG encode/decode (quality clamped 40–100 like closed UI).

use image::{DynamicImage, GenericImageView, Rgba};
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

struct BorrowedJpegView<'a> {
    pixels: &'a [u8],
    width: u32,
    height: u32,
    grayscale: bool,
}

impl GenericImageView for BorrowedJpegView<'_> {
    type Pixel = Rgba<u8>;

    fn dimensions(&self) -> (u32, u32) {
        (self.width, self.height)
    }

    fn get_pixel(&self, x: u32, y: u32) -> Self::Pixel {
        let index = y as usize * self.width as usize + x as usize;
        if self.grayscale {
            let value = self.pixels[index];
            Rgba([value, value, value, u8::MAX])
        } else {
            let offset = index * 3;
            Rgba([
                self.pixels[offset],
                self.pixels[offset + 1],
                self.pixels[offset + 2],
                u8::MAX,
            ])
        }
    }
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
    let mut out = Cursor::new(Vec::new());
    let mut encoder = image::codecs::jpeg::JpegEncoder::new_with_quality(&mut out, q);
    let image = BorrowedJpegView {
        pixels: &pixels[..expected],
        width,
        height,
        grayscale: mode == "L",
    };
    encoder
        .encode_image(&image)
        .map_err(|error| JpegError::Image(error.to_string()))?;
    Ok(out.into_inner())
}

pub fn decode_jpeg(data: &[u8]) -> Result<DecodedImage, JpegError> {
    if data.is_empty() {
        return Err(JpegError::Empty);
    }
    if data.len() > crate::protocol::MAX_MEDIA_FRAME_SIZE {
        return Err(JpegError::Dims);
    }
    let mut reader = image::ImageReader::with_format(Cursor::new(data), image::ImageFormat::Jpeg);
    let mut limits = image::Limits::default();
    limits.max_image_width = Some(8192);
    limits.max_image_height = Some(8192);
    limits.max_alloc = Some(64 * 1024 * 1024);
    reader.limits(limits);
    let img = reader
        .decode()
        .map_err(|e| JpegError::Image(e.to_string()))?;
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

#[cfg(test)]
mod tests {
    use super::*;
    use image::{GrayImage, ImageBuffer, Rgb};

    fn owned_snapshot_encoder(
        pixels: &[u8],
        width: u32,
        height: u32,
        mode: &str,
        quality: u8,
    ) -> Vec<u8> {
        let expected = width as usize * height as usize * if mode == "L" { 1 } else { 3 };
        let image = if mode == "L" {
            DynamicImage::ImageLuma8(
                GrayImage::from_raw(width, height, pixels[..expected].to_vec()).unwrap(),
            )
        } else {
            let mut buffer = ImageBuffer::<Rgb<u8>, Vec<u8>>::new(width, height);
            for (index, pixel) in buffer.pixels_mut().enumerate() {
                let offset = index * 3;
                *pixel = Rgb([pixels[offset], pixels[offset + 1], pixels[offset + 2]]);
            }
            DynamicImage::ImageRgb8(buffer)
        };
        let mut out = Cursor::new(Vec::new());
        image::codecs::jpeg::JpegEncoder::new_with_quality(&mut out, quality)
            .encode_image(&image)
            .unwrap();
        out.into_inner()
    }

    #[test]
    fn borrowed_rgb_and_grayscale_views_preserve_exact_encoded_bytes() {
        let rgb = (0..17 * 9 * 3)
            .map(|value| (value * 37) as u8)
            .collect::<Vec<_>>();
        let gray = (0..17 * 9)
            .map(|value| (value * 19) as u8)
            .collect::<Vec<_>>();
        for (pixels, mode) in [(&rgb[..], "RGB"), (&gray[..], "L")] {
            assert_eq!(
                encode_jpeg(pixels, 17, 9, mode, 83).unwrap(),
                owned_snapshot_encoder(pixels, 17, 9, mode, 83)
            );
        }
    }

    #[test]
    fn grayscale_frame_expansion_preserves_exact_encoded_bytes() {
        let gray = (0..13 * 7)
            .map(|value| (value * 23) as u8)
            .collect::<Vec<_>>();
        let expanded = gray_to_rgb(&gray, 13, 7).unwrap();
        assert_eq!(
            encode_frame_jpeg(&gray, 13, 7, "Mono8", 97).unwrap(),
            owned_snapshot_encoder(&expanded, 13, 7, "RGB", 97)
        );
    }
}
