//! Platform-independent NV12 / YUY2 / RGB32 conversion to the station's Mono8 and RGB24.
//!
//! YUV input is treated as BT.601 limited range, which is what UVC webcams
//! deliver through Media Foundation unless they say otherwise. Luma is
//! expanded to full range with the same integer formula the RGB path uses
//! for neutral chroma, so Mono8 and RGB24 output agree on brightness.

use super::modes::{MfOutput, MfSubtype};

/// Geometry of one locked Media Foundation frame buffer.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MfFrameLayout {
    pub subtype: MfSubtype,
    pub width: u32,
    pub height: u32,
    /// `MF_MT_DEFAULT_STRIDE`: bytes per row; negative means bottom-up rows.
    pub stride: i32,
}

impl MfFrameLayout {
    /// Minimum bytes in one row of the first plane.
    pub fn row_bytes(&self) -> Option<usize> {
        let per_pixel = match self.subtype {
            MfSubtype::Nv12 => 1,
            MfSubtype::Yuy2 => 2,
            MfSubtype::Rgb32 => 4,
            MfSubtype::Other(_) => return None,
        };
        (self.width as usize).checked_mul(per_pixel)
    }

    /// The stride a buffer without `MF_MT_DEFAULT_STRIDE` uses: packed rows, with the
    /// direction Microsoft documents for the format family ("Image Stride" and
    /// `MF_MT_DEFAULT_STRIDE`, Media Foundation): uncompressed RGB is bottom-up (negative
    /// stride) and YUV (NV12, YUY2) is top-down (positive stride).
    pub fn default_stride(subtype: &MfSubtype, width: u32) -> Option<i32> {
        let layout = Self {
            subtype: subtype.clone(),
            width,
            height: 1,
            stride: 0,
        };
        let bytes = i32::try_from(layout.row_bytes()?).ok()?;
        match subtype {
            MfSubtype::Rgb32 => bytes.checked_neg(),
            _ => Some(bytes),
        }
    }

    /// Whether `current` (re-read after a media-type-changed flag) is still this layout.
    pub fn ensure_unchanged(&self, current: &Self) -> Result<(), String> {
        if self == current {
            return Ok(());
        }
        Err(format!(
            "the camera changed its media type mid-stream to {} {}x{} stride {} (selected {} {}x{} stride {})",
            current.subtype,
            current.width,
            current.height,
            current.stride,
            self.subtype,
            self.width,
            self.height,
            self.stride
        ))
    }
}

/// Converts one contiguous frame to the requested station format.
pub fn convert_frame(
    source: &[u8],
    layout: &MfFrameLayout,
    output: MfOutput,
) -> Result<Vec<u8>, String> {
    let rows = Rows::new(source, layout)?;
    let pixels = layout.width as usize * layout.height as usize;
    let channels = if output == MfOutput::Mono8 { 1 } else { 3 };
    let mut frame = Vec::with_capacity(pixels * channels);
    for row in 0..layout.height as usize {
        match (&layout.subtype, output) {
            (MfSubtype::Nv12, MfOutput::Mono8) => frame.extend(rows.row(row).iter().map(luma)),
            (MfSubtype::Nv12, MfOutput::Rgb24) => nv12_row_to_rgb(&rows, row, &mut frame),
            (MfSubtype::Yuy2, MfOutput::Mono8) => {
                frame.extend(rows.row(row).iter().step_by(2).map(luma))
            }
            (MfSubtype::Yuy2, MfOutput::Rgb24) => yuy2_row_to_rgb(rows.row(row), &mut frame),
            (MfSubtype::Rgb32, MfOutput::Mono8) => frame.extend(
                rows.row(row)
                    .as_chunks::<4>()
                    .0
                    .iter()
                    .map(|bgrx| rgb_luma(bgrx[2], bgrx[1], bgrx[0])),
            ),
            (MfSubtype::Rgb32, MfOutput::Rgb24) => {
                for bgrx in rows.row(row).as_chunks::<4>().0 {
                    frame.extend_from_slice(&[bgrx[2], bgrx[1], bgrx[0]]);
                }
            }
            (MfSubtype::Other(name), _) => {
                return Err(format!("subtype {name} is not converted by this backend"))
            }
        }
    }
    Ok(frame)
}

/// Row access over a strided (and possibly bottom-up) buffer, bounds-checked once.
struct Rows<'a> {
    source: &'a [u8],
    stride: usize,
    row_bytes: usize,
    height: usize,
    bottom_up: bool,
}

impl<'a> Rows<'a> {
    fn new(source: &'a [u8], layout: &MfFrameLayout) -> Result<Self, String> {
        let row_bytes = layout
            .row_bytes()
            .ok_or_else(|| format!("subtype {} is not converted", layout.subtype))?;
        validate_geometry(layout)?;
        let stride = layout.stride.unsigned_abs() as usize;
        if stride < row_bytes {
            return Err(format!(
                "stride {} is shorter than the {row_bytes}-byte row",
                layout.stride
            ));
        }
        let bottom_up = layout.stride < 0;
        if bottom_up && layout.subtype != MfSubtype::Rgb32 {
            return Err(format!(
                "negative stride {} is only valid for RGB32",
                layout.stride
            ));
        }
        let height = layout.height as usize;
        let plane_rows = if layout.subtype == MfSubtype::Nv12 {
            height + height / 2
        } else {
            height
        };
        let required = stride
            .checked_mul(plane_rows - 1)
            .and_then(|prefix| prefix.checked_add(row_bytes))
            .ok_or("frame size overflow")?;
        if source.len() < required {
            return Err(format!(
                "truncated {} frame: {} bytes, need at least {required}",
                layout.subtype,
                source.len()
            ));
        }
        Ok(Self {
            source,
            stride,
            row_bytes,
            height,
            bottom_up,
        })
    }

    /// Row `index` of the first plane, counted from the top of the image.
    fn row(&self, index: usize) -> &'a [u8] {
        let stored = if self.bottom_up {
            self.height - 1 - index
        } else {
            index
        };
        self.plane_row(stored)
    }

    /// Interleaved U/V row of an NV12 chroma plane for image row `index`.
    fn chroma_row(&self, index: usize) -> &'a [u8] {
        self.plane_row(self.height + index / 2)
    }

    fn plane_row(&self, stored: usize) -> &'a [u8] {
        let start = stored * self.stride;
        &self.source[start..start + self.row_bytes]
    }
}

fn validate_geometry(layout: &MfFrameLayout) -> Result<(), String> {
    if layout.width == 0 || layout.height == 0 {
        return Err(format!("empty {}x{} frame", layout.width, layout.height));
    }
    let even_width = matches!(layout.subtype, MfSubtype::Nv12 | MfSubtype::Yuy2);
    if even_width && !layout.width.is_multiple_of(2) {
        return Err(format!("{} requires an even width", layout.subtype));
    }
    if layout.subtype == MfSubtype::Nv12 && !layout.height.is_multiple_of(2) {
        return Err("NV12 requires an even height".into());
    }
    Ok(())
}

fn nv12_row_to_rgb(rows: &Rows<'_>, row: usize, frame: &mut Vec<u8>) {
    let luma_row = rows.row(row);
    let chroma = rows.chroma_row(row);
    for (pair, uv) in luma_row
        .as_chunks::<2>()
        .0
        .iter()
        .zip(chroma.as_chunks::<2>().0)
    {
        frame.extend_from_slice(&yuv_to_rgb(pair[0], uv[0], uv[1]));
        frame.extend_from_slice(&yuv_to_rgb(pair[1], uv[0], uv[1]));
    }
}

fn yuy2_row_to_rgb(row: &[u8], frame: &mut Vec<u8>) {
    for yuyv in row.as_chunks::<4>().0 {
        frame.extend_from_slice(&yuv_to_rgb(yuyv[0], yuyv[1], yuyv[3]));
        frame.extend_from_slice(&yuv_to_rgb(yuyv[2], yuyv[1], yuyv[3]));
    }
}

fn clamp_scaled(value: i32) -> u8 {
    ((value + 128) >> 8).clamp(0, 255) as u8
}

/// BT.601 limited-range luma expanded to 0..=255.
fn luma(y: &u8) -> u8 {
    clamp_scaled(298 * (i32::from(*y) - 16))
}

/// The weights the software camera uses for RGB to luma.
fn rgb_luma(red: u8, green: u8, blue: u8) -> u8 {
    ((77u32 * u32::from(red) + 150u32 * u32::from(green) + 29u32 * u32::from(blue)) >> 8) as u8
}

/// BT.601 limited-range YCbCr to RGB.
fn yuv_to_rgb(y: u8, u: u8, v: u8) -> [u8; 3] {
    let c = 298 * (i32::from(y) - 16);
    let d = i32::from(u) - 128;
    let e = i32::from(v) - 128;
    [
        clamp_scaled(c + 409 * e),
        clamp_scaled(c - 100 * d - 208 * e),
        clamp_scaled(c + 516 * d),
    ]
}

#[cfg(test)]
mod tests {
    use super::*;

    fn layout(subtype: MfSubtype, width: u32, height: u32, stride: i32) -> MfFrameLayout {
        MfFrameLayout {
            subtype,
            width,
            height,
            stride,
        }
    }

    #[test]
    fn nv12_to_mono8_expands_luma_and_skips_padding_and_chroma() {
        // 2x2 luma with one padding byte per row, then one U/V row.
        let frame = [16, 235, 99, 128, 0, 99, 128, 128, 99];
        let nv12 = layout(MfSubtype::Nv12, 2, 2, 3);
        assert_eq!(
            convert_frame(&frame, &nv12, MfOutput::Mono8).unwrap(),
            vec![0, 255, 130, 0]
        );
    }

    #[test]
    fn nv12_to_rgb24_shares_chroma_across_a_2x2_block() {
        let nv12 = layout(MfSubtype::Nv12, 2, 2, 2);
        let grey = [16, 235, 16, 235, 128, 128];
        assert_eq!(
            convert_frame(&grey, &nv12, MfOutput::Rgb24).unwrap(),
            vec![0, 0, 0, 255, 255, 255, 0, 0, 0, 255, 255, 255]
        );
        let red = [81, 81, 81, 81, 90, 240];
        assert_eq!(
            convert_frame(&red, &nv12, MfOutput::Rgb24).unwrap(),
            vec![255, 0, 0, 255, 0, 0, 255, 0, 0, 255, 0, 0]
        );
    }

    #[test]
    fn yuy2_to_mono8_takes_every_other_byte() {
        let frame = [16, 90, 235, 240, 128, 0, 0, 0];
        let yuy2 = layout(MfSubtype::Yuy2, 2, 2, 4);
        assert_eq!(
            convert_frame(&frame, &yuy2, MfOutput::Mono8).unwrap(),
            vec![0, 255, 130, 0]
        );
    }

    #[test]
    fn yuy2_to_rgb24_matches_bt601_limited() {
        let yuy2 = layout(MfSubtype::Yuy2, 2, 1, 4);
        assert_eq!(
            convert_frame(&[16, 128, 235, 128], &yuy2, MfOutput::Rgb24).unwrap(),
            vec![0, 0, 0, 255, 255, 255]
        );
        assert_eq!(
            convert_frame(&[81, 90, 81, 240], &yuy2, MfOutput::Rgb24).unwrap(),
            vec![255, 0, 0, 255, 0, 0]
        );
    }

    #[test]
    fn rgb32_is_read_as_bgrx() {
        let frame = [30, 20, 10, 0, 0, 0, 255, 0, 255, 255, 255, 7];
        let rgb32 = layout(MfSubtype::Rgb32, 3, 1, 12);
        assert_eq!(
            convert_frame(&frame, &rgb32, MfOutput::Rgb24).unwrap(),
            vec![10, 20, 30, 255, 0, 0, 255, 255, 255]
        );
        assert_eq!(
            convert_frame(&frame, &rgb32, MfOutput::Mono8).unwrap(),
            vec![18, 76, 255]
        );
    }

    #[test]
    fn negative_rgb32_stride_flips_bottom_up_rows() {
        let frame = [1, 1, 1, 0, 9, 9, 9, 0];
        let bottom_up = layout(MfSubtype::Rgb32, 1, 2, -4);
        assert_eq!(
            convert_frame(&frame, &bottom_up, MfOutput::Rgb24).unwrap(),
            vec![9, 9, 9, 1, 1, 1]
        );
        let yuy2 = layout(MfSubtype::Yuy2, 2, 1, -4);
        assert!(convert_frame(&[0; 4], &yuy2, MfOutput::Mono8).is_err());
    }

    #[test]
    fn truncated_odd_and_unknown_frames_are_rejected() {
        let nv12 = layout(MfSubtype::Nv12, 2, 2, 2);
        let error = convert_frame(&[0; 5], &nv12, MfOutput::Mono8).unwrap_err();
        assert!(error.contains("need at least 6"), "{error}");
        let odd = layout(MfSubtype::Yuy2, 3, 1, 6);
        assert!(convert_frame(&[0; 6], &odd, MfOutput::Mono8).is_err());
        let short_stride = layout(MfSubtype::Rgb32, 2, 1, 4);
        assert!(convert_frame(&[0; 8], &short_stride, MfOutput::Mono8).is_err());
        let mjpg = layout(MfSubtype::Other("MJPG".into()), 2, 1, 0);
        assert!(convert_frame(&[0; 8], &mjpg, MfOutput::Mono8).is_err());
    }

    #[test]
    fn default_stride_follows_the_documented_direction_per_format() {
        // RGB is bottom-up, YUV is top-down when MF_MT_DEFAULT_STRIDE is absent.
        assert_eq!(
            MfFrameLayout::default_stride(&MfSubtype::Rgb32, 640),
            Some(-2560)
        );
        assert_eq!(
            MfFrameLayout::default_stride(&MfSubtype::Yuy2, 640),
            Some(1280)
        );
        assert_eq!(
            MfFrameLayout::default_stride(&MfSubtype::Nv12, 640),
            Some(640)
        );
        assert_eq!(
            MfFrameLayout::default_stride(&MfSubtype::Other("MJPG".into()), 640),
            None
        );
        // A bottom-up default stride flips rows like an explicit negative stride.
        let stride = MfFrameLayout::default_stride(&MfSubtype::Rgb32, 1).unwrap();
        let bottom_up = layout(MfSubtype::Rgb32, 1, 2, stride);
        let frame = convert_frame(&[1, 2, 3, 0, 4, 5, 6, 0], &bottom_up, MfOutput::Rgb24).unwrap();
        assert_eq!(frame, [6, 5, 4, 3, 2, 1]);
    }

    #[test]
    fn a_media_type_flag_is_harmless_only_while_the_layout_is_unchanged() {
        let selected = layout(MfSubtype::Yuy2, 640, 480, 1280);
        assert!(selected.ensure_unchanged(&selected.clone()).is_ok());
        for changed in [
            layout(MfSubtype::Nv12, 640, 480, 1280),
            layout(MfSubtype::Yuy2, 320, 240, 1280),
            layout(MfSubtype::Yuy2, 640, 480, 1344),
        ] {
            let error = selected.ensure_unchanged(&changed).unwrap_err();
            assert!(error.contains("changed its media type"), "{error}");
        }
    }
}
