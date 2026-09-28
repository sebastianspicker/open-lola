use super::{NativeFormat, V4l2Error, V4l2Result};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(super) enum YuvMatrix {
    Bt601,
    Bt709,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(super) enum YuvRange {
    Limited,
    Full,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(super) struct YuyvColorProfile {
    pub matrix: YuvMatrix,
    pub range: YuvRange,
}

impl Default for YuyvColorProfile {
    fn default() -> Self {
        Self {
            matrix: YuvMatrix::Bt601,
            range: YuvRange::Limited,
        }
    }
}

fn copy_rows(source: &[u8], height: u32, row_bytes: usize, stride: usize) -> V4l2Result<Vec<u8>> {
    if stride < row_bytes {
        return Err(V4l2Error::InvalidFrame(format!(
            "reported row stride {stride} is shorter than {row_bytes}"
        )));
    }
    let required = stride
        .checked_mul(height as usize - 1)
        .and_then(|prefix| prefix.checked_add(row_bytes))
        .ok_or_else(|| V4l2Error::InvalidFrame("strided frame size overflow".into()))?;
    if source.len() < required {
        return Err(V4l2Error::InvalidFrame(format!(
            "truncated frame: {} bytes, need at least {required}",
            source.len()
        )));
    }
    let capacity = row_bytes
        .checked_mul(height as usize)
        .ok_or_else(|| V4l2Error::InvalidFrame("packed frame size overflow".into()))?;
    let mut output = Vec::with_capacity(capacity);
    for row in 0..height as usize {
        let start = row * stride;
        output.extend_from_slice(&source[start..start + row_bytes]);
    }
    Ok(output)
}

pub(super) fn normalize_frame(
    source: &[u8],
    format: NativeFormat,
    width: u32,
    height: u32,
    bytes_per_line: u32,
    yuyv_color: YuyvColorProfile,
) -> V4l2Result<(Vec<u8>, String)> {
    if format == NativeFormat::Mjpeg {
        let decoded = super::super::decode_jpeg(source)
            .map_err(|error| V4l2Error::Conversion(error.to_string()))?;
        if decoded.width != width || decoded.height != height {
            return Err(V4l2Error::NegotiationMismatch {
                field: "decoded MJPEG dimensions",
                requested: format!("{width}x{height}"),
                actual: format!("{}x{}", decoded.width, decoded.height),
            });
        }
        return match decoded.mode.as_str() {
            "L" => {
                // MJPG is negotiated as RGB24 regardless of JPEG component count.
                let pixels = decoded
                    .pixels
                    .into_iter()
                    .flat_map(|value| [value; 3])
                    .collect();
                Ok((pixels, "RGB24".into()))
            }
            "RGB" => Ok((decoded.pixels, "RGB24".into())),
            mode => Err(V4l2Error::Conversion(format!(
                "JPEG decoder returned unsupported mode {mode:?}"
            ))),
        };
    }

    let row_bytes = format.minimum_row_bytes(width)?;
    let stride = if bytes_per_line == 0 {
        row_bytes
    } else {
        bytes_per_line as usize
    };
    let packed = copy_rows(source, height, row_bytes, stride)?;
    match format {
        NativeFormat::Rgb24 => Ok((packed, "RGB24".into())),
        NativeFormat::Gray8 => Ok((packed, "Mono8".into())),
        NativeFormat::Bgr24 => {
            let mut rgb = packed;
            for pixel in rgb.as_chunks_mut::<3>().0 {
                pixel.swap(0, 2);
            }
            Ok((rgb, "RGB24".into()))
        }
        NativeFormat::Yuyv => {
            let output_len = (width as usize)
                .checked_mul(height as usize)
                .and_then(|pixels| pixels.checked_mul(3))
                .ok_or_else(|| V4l2Error::InvalidFrame("RGB frame size overflow".into()))?;
            let mut rgb = Vec::with_capacity(output_len);
            for pair in packed.as_chunks::<4>().0 {
                let u = i32::from(pair[1]);
                let v = i32::from(pair[3]);
                rgb.extend_from_slice(&yuv_to_rgb(i32::from(pair[0]), u, v, yuyv_color));
                rgb.extend_from_slice(&yuv_to_rgb(i32::from(pair[2]), u, v, yuyv_color));
            }
            Ok((rgb, "RGB24".into()))
        }
        NativeFormat::Mjpeg => unreachable!(),
    }
}

fn yuv_to_rgb(y: i32, u: i32, v: i32, profile: YuyvColorProfile) -> [u8; 3] {
    let d = u - 128;
    let e = v - 128;
    let clamp = |value: i32| ((value + 128) >> 8).clamp(0, 255) as u8;
    let (y_term, red_v, green_u, green_v, blue_u) = match (profile.range, profile.matrix) {
        (YuvRange::Limited, YuvMatrix::Bt601) => (298 * (y - 16), 409, 100, 208, 516),
        (YuvRange::Limited, YuvMatrix::Bt709) => (298 * (y - 16), 459, 55, 136, 541),
        (YuvRange::Full, YuvMatrix::Bt601) => (256 * y, 359, 88, 183, 454),
        (YuvRange::Full, YuvMatrix::Bt709) => (256 * y, 403, 48, 120, 475),
    };
    [
        clamp(y_term + red_v * e),
        clamp(y_term - green_u * d - green_v * e),
        clamp(y_term + blue_u * d),
    ]
}

/// Return the dequeued buffer even if validation/conversion fails.
pub(super) fn process_then_requeue<T>(
    process: impl FnOnce() -> V4l2Result<T>,
    requeue: impl FnOnce() -> V4l2Result<()>,
) -> V4l2Result<T> {
    match (process(), requeue()) {
        (Ok(value), Ok(())) => Ok(value),
        (Err(primary), Ok(())) => Err(primary),
        (Ok(_), Err(cleanup)) => Err(cleanup),
        (Err(primary), Err(cleanup)) => Err(V4l2Error::Cleanup(format!(
            "{cleanup}; original frame error: {primary}"
        ))),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use image::{ImageBuffer, Rgb};
    use std::cell::Cell;
    use std::io::Cursor;

    fn normalize(
        source: &[u8],
        format: NativeFormat,
        width: u32,
        height: u32,
        bytes_per_line: u32,
    ) -> V4l2Result<(Vec<u8>, String)> {
        normalize_frame(
            source,
            format,
            width,
            height,
            bytes_per_line,
            YuyvColorProfile::default(),
        )
    }

    #[test]
    fn rgb_and_gray_remove_driver_row_padding() {
        let rgb = [1, 2, 3, 4, 5, 6, 99, 99, 7, 8, 9, 10, 11, 12];
        assert_eq!(
            normalize(&rgb, NativeFormat::Rgb24, 2, 2, 8).unwrap(),
            (vec![1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], "RGB24".into())
        );
        let gray = [3, 4, 99, 5, 6];
        assert_eq!(
            normalize(&gray, NativeFormat::Gray8, 2, 2, 3).unwrap(),
            (vec![3, 4, 5, 6], "Mono8".into())
        );
    }

    #[test]
    fn bgr_is_normalized_to_rgb24() {
        assert_eq!(
            normalize(&[30, 20, 10, 60, 50, 40], NativeFormat::Bgr24, 2, 1, 6).unwrap(),
            (vec![10, 20, 30, 40, 50, 60], "RGB24".into())
        );
    }

    #[test]
    fn yuyv_normalizes_shared_chroma_to_rgb24() {
        assert_eq!(
            normalize(&[16, 128, 235, 128], NativeFormat::Yuyv, 2, 1, 4).unwrap(),
            (vec![0, 0, 0, 255, 255, 255], "RGB24".into())
        );
        assert_eq!(
            normalize(&[81, 90, 81, 240], NativeFormat::Yuyv, 2, 1, 4)
                .unwrap()
                .0,
            vec![255, 0, 0, 255, 0, 0]
        );
    }

    #[test]
    fn yuyv_supports_full_and_limited_601_and_709() {
        let profiles = [
            (YuvRange::Limited, YuvMatrix::Bt601, [81, 90, 81, 240]),
            (YuvRange::Full, YuvMatrix::Bt601, [76, 85, 76, 255]),
            (YuvRange::Limited, YuvMatrix::Bt709, [63, 102, 63, 240]),
            (YuvRange::Full, YuvMatrix::Bt709, [54, 99, 54, 255]),
        ];
        for (range, matrix, frame) in profiles {
            let (pixels, _) = normalize_frame(
                &frame,
                NativeFormat::Yuyv,
                2,
                1,
                4,
                YuyvColorProfile { matrix, range },
            )
            .unwrap();
            for pixel in pixels.as_chunks::<3>().0 {
                assert!(pixel[0] >= 253 && pixel[1] <= 2 && pixel[2] <= 2);
            }
        }
    }

    #[test]
    fn mjpeg_is_decoded_and_dimension_checked() {
        let image = ImageBuffer::from_pixel(2, 1, Rgb([10u8, 20, 30]));
        let mut encoded = Cursor::new(Vec::new());
        image::codecs::jpeg::JpegEncoder::new_with_quality(&mut encoded, 100)
            .encode_image(&image)
            .unwrap();
        let (pixels, format) = normalize(encoded.get_ref(), NativeFormat::Mjpeg, 2, 1, 0).unwrap();
        assert_eq!((pixels.len(), format.as_str()), (6, "RGB24"));
        assert!(matches!(
            normalize(encoded.get_ref(), NativeFormat::Mjpeg, 1, 2, 0),
            Err(V4l2Error::NegotiationMismatch { .. })
        ));
    }

    #[test]
    fn grayscale_mjpeg_keeps_negotiated_rgb_output() {
        let image = ImageBuffer::from_pixel(2, 1, image::Luma([87u8]));
        let mut encoded = Vec::new();
        image::codecs::jpeg::JpegEncoder::new_with_quality(&mut encoded, 100)
            .encode_image(&image)
            .unwrap();
        let (pixels, format) = normalize(&encoded, NativeFormat::Mjpeg, 2, 1, 0).unwrap();
        assert_eq!(format, "RGB24");
        assert_eq!(pixels.len(), 6);
        assert!(pixels
            .as_chunks::<3>()
            .0
            .iter()
            .all(|pixel| pixel[0] == pixel[1] && pixel[1] == pixel[2]));
    }

    #[test]
    fn truncated_and_error_frames_requeue_exactly_once() {
        let calls = Cell::new(0);
        let error = process_then_requeue(
            || normalize(&[0; 3], NativeFormat::Yuyv, 2, 1, 4),
            || {
                calls.set(calls.get() + 1);
                Ok(())
            },
        )
        .unwrap_err();
        assert!(matches!(error, V4l2Error::InvalidFrame(_)));
        assert_eq!(calls.get(), 1);
        assert!(matches!(
            normalize(b"not a jpeg", NativeFormat::Mjpeg, 2, 1, 0),
            Err(V4l2Error::Conversion(_))
        ));
    }

    #[test]
    fn requeue_failure_is_never_hidden() {
        let error = process_then_requeue::<()>(
            || Err(V4l2Error::InvalidFrame("bad frame".into())),
            || Err(V4l2Error::Cleanup("queue failed".into())),
        )
        .unwrap_err();
        assert!(matches!(error, V4l2Error::Cleanup(_)));
        assert!(error.to_string().contains("original frame error"));
    }
}
