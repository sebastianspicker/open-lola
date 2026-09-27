use super::convert::{YuvMatrix, YuvRange, YuyvColorProfile};
use super::{V4l2Error, V4l2Result};

const COLORSPACE_DEFAULT: u32 = 0;
const COLORSPACE_SMPTE170M: u32 = 1;
const COLORSPACE_REC709: u32 = 3;
const COLORSPACE_JPEG: u32 = 7;
const COLORSPACE_SRGB: u32 = 8;
const COLORSPACE_DCI_P3: u32 = 12;
const YCBCR_ENCODING_DEFAULT: u32 = 0;
const YCBCR_ENCODING_601: u32 = 1;
const YCBCR_ENCODING_709: u32 = 2;
const QUANTIZATION_DEFAULT: u32 = 0;
const QUANTIZATION_FULL_RANGE: u32 = 1;
const QUANTIZATION_LIMITED_RANGE: u32 = 2;

pub(super) fn resolve_yuyv_color(
    color_space: u32,
    ycbcr_encoding: u32,
    quantization: u32,
    extended: bool,
) -> V4l2Result<YuyvColorProfile> {
    let encoding = if extended {
        ycbcr_encoding
    } else {
        YCBCR_ENCODING_DEFAULT
    };
    let quantization = if extended {
        quantization
    } else {
        QUANTIZATION_DEFAULT
    };
    let matrix = match encoding {
        YCBCR_ENCODING_601 => YuvMatrix::Bt601,
        YCBCR_ENCODING_709 => YuvMatrix::Bt709,
        YCBCR_ENCODING_DEFAULT => match color_space {
            COLORSPACE_REC709 | COLORSPACE_DCI_P3 => YuvMatrix::Bt709,
            COLORSPACE_DEFAULT | COLORSPACE_SMPTE170M | COLORSPACE_JPEG | COLORSPACE_SRGB => {
                YuvMatrix::Bt601
            }
            value => return Err(unsupported("default YCbCr encoding", value)),
        },
        value => return Err(unsupported("YCbCr encoding", value)),
    };
    let range = match quantization {
        QUANTIZATION_FULL_RANGE => YuvRange::Full,
        QUANTIZATION_LIMITED_RANGE => YuvRange::Limited,
        QUANTIZATION_DEFAULT if color_space == COLORSPACE_JPEG => YuvRange::Full,
        QUANTIZATION_DEFAULT => YuvRange::Limited,
        value => return Err(unsupported("quantization", value)),
    };
    Ok(YuyvColorProfile { matrix, range })
}

fn unsupported(field: &'static str, value: u32) -> V4l2Error {
    V4l2Error::InvalidConfig(format!(
        "driver negotiated unsupported YUYV {field} value {value}"
    ))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn defaults_follow_colorspace_and_explicit_values_override_them() {
        assert_eq!(
            resolve_yuyv_color(COLORSPACE_DEFAULT, 99, 99, false).unwrap(),
            YuyvColorProfile::default()
        );
        assert_eq!(
            resolve_yuyv_color(
                COLORSPACE_JPEG,
                YCBCR_ENCODING_DEFAULT,
                QUANTIZATION_DEFAULT,
                true,
            )
            .unwrap()
            .range,
            YuvRange::Full
        );
        assert_eq!(
            resolve_yuyv_color(
                COLORSPACE_REC709,
                YCBCR_ENCODING_DEFAULT,
                QUANTIZATION_DEFAULT,
                true,
            )
            .unwrap()
            .matrix,
            YuvMatrix::Bt709
        );
        assert_eq!(
            resolve_yuyv_color(
                COLORSPACE_DEFAULT,
                YCBCR_ENCODING_709,
                QUANTIZATION_FULL_RANGE,
                true,
            )
            .unwrap(),
            YuyvColorProfile {
                matrix: YuvMatrix::Bt709,
                range: YuvRange::Full,
            }
        );
        assert!(matches!(
            resolve_yuyv_color(COLORSPACE_DEFAULT, 99, QUANTIZATION_DEFAULT, true),
            Err(V4l2Error::InvalidConfig(_))
        ));
    }
}
