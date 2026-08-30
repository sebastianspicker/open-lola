use crate::config::CameraMode;
use thiserror::Error;

pub(super) const XI_OK: i32 = 0;
pub(super) const XI_MONO8: i32 = 0;
pub(super) const XI_RGB24: i32 = 2;
pub(super) const XI_ACQ_TIMING_MODE_FRAME_RATE: i32 = 2;

pub(super) type XiGetNumberDevices = unsafe extern "C" fn(*mut u32) -> i32;
pub(super) type XiOpenDevice = unsafe extern "C" fn(u32, *mut *mut std::ffi::c_void) -> i32;
pub(super) type XiCloseDevice = unsafe extern "C" fn(*mut std::ffi::c_void) -> i32;
pub(super) type XiStartAcquisition = unsafe extern "C" fn(*mut std::ffi::c_void) -> i32;
pub(super) type XiStopAcquisition = unsafe extern "C" fn(*mut std::ffi::c_void) -> i32;
pub(super) type XiSetParamInt = unsafe extern "C" fn(*mut std::ffi::c_void, *const i8, i32) -> i32;
pub(super) type XiGetImage = unsafe extern "C" fn(*mut std::ffi::c_void, u32, *mut XiImg) -> i32;

/// Subset of public XI_IMG used by xiGetImage (layout matches xiApi.h V2+ prefix).
#[repr(C)]
pub(super) struct XiImg {
    pub(super) size: u32,
    pub(super) bp: *mut std::ffi::c_void,
    pub(super) bp_size: u32,
    pub(super) frm: i32,
    pub(super) width: u32,
    pub(super) height: u32,
    pub(super) nframe: u32,
    pub(super) ts_sec: u32,
    pub(super) ts_usec: u32,
    pub(super) gpi_level: u32,
    pub(super) black_level: u32,
    pub(super) padding_x: u32,
    pub(super) absolute_offset_x: u32,
    pub(super) absolute_offset_y: u32,
}

/// xiAPI image data formats supported by the strict backend.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum XimeaPixelFormat {
    Mono8,
    Rgb24,
}

impl XimeaPixelFormat {
    pub fn from_mode(value: &str) -> XimeaResult<Self> {
        if value.eq_ignore_ascii_case("Mono8") {
            Ok(Self::Mono8)
        } else if value.eq_ignore_ascii_case("RGB24") || value.eq_ignore_ascii_case("RGB") {
            Ok(Self::Rgb24)
        } else {
            Err(XimeaError::InvalidConfig(format!(
                "unsupported pixel format `{value}`; expected Mono8 or RGB24"
            )))
        }
    }

    pub(super) const fn xiapi_code(self) -> i32 {
        match self {
            Self::Mono8 => XI_MONO8,
            Self::Rgb24 => XI_RGB24,
        }
    }

    pub(super) const fn bytes_per_pixel(self) -> usize {
        match self {
            Self::Mono8 => 1,
            Self::Rgb24 => 3,
        }
    }

    pub(super) const fn name(self) -> &'static str {
        match self {
            Self::Mono8 => "Mono8",
            Self::Rgb24 => "RGB24",
        }
    }
}

/// Hardware colour output selected through xiAPI's `imgdataformat` parameter.
/// Bayer pattern selection remains a downstream demosaic concern: xiAPI exposes
/// the sensor's colour-filter array as device metadata, not a writable mode.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum XimeaColorMode {
    RawBayer,
    Rgb24,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct XimeaConfig {
    pub camera_index: u32,
    /// Region-of-interest origin in sensor pixels.
    pub roi_offset_x: u32,
    pub roi_offset_y: u32,
    /// Region-of-interest dimensions in sensor pixels.
    pub width: u32,
    pub height: u32,
    pub pixel_format: XimeaPixelFormat,
    /// Colour conversion mode represented by `pixel_format` in xiAPI.
    pub color_mode: XimeaColorMode,
    /// Exposure time in microseconds.
    pub exposure_us: u32,
    pub frame_rate: u32,
    pub timeout_ms: u32,
}

impl XimeaConfig {
    pub fn from_mode(camera_index: u32, mode: &CameraMode) -> Self {
        Self {
            camera_index,
            roi_offset_x: 0,
            roi_offset_y: 0,
            width: mode.width,
            height: mode.height,
            pixel_format: XimeaPixelFormat::from_mode(&mode.pixel_format)
                .expect("CameraMode only accepts Mono8 or RGB24"),
            color_mode: if mode.pixel_format.eq_ignore_ascii_case("Mono8") {
                XimeaColorMode::RawBayer
            } else {
                XimeaColorMode::Rgb24
            },
            exposure_us: 10_000,
            frame_rate: mode.max_fps,
            timeout_ms: 1_000,
        }
    }

    pub(super) const fn pixel_format_code(&self) -> i32 {
        self.pixel_format.xiapi_code()
    }

    pub(super) fn validate(&self) -> XimeaResult<()> {
        if self.width == 0
            || self.height == 0
            || self.exposure_us == 0
            || self.frame_rate == 0
            || self.timeout_ms == 0
        {
            return Err(XimeaError::InvalidConfig(
                "width, height, exposure_us, frame_rate, and timeout_ms must be positive".into(),
            ));
        }
        if matches!(self.color_mode, XimeaColorMode::RawBayer)
            && self.pixel_format != XimeaPixelFormat::Mono8
        {
            return Err(XimeaError::InvalidConfig(
                "RawBayer colour mode requires Mono8 pixel format".into(),
            ));
        }
        if matches!(self.color_mode, XimeaColorMode::Rgb24)
            && self.pixel_format != XimeaPixelFormat::Rgb24
        {
            return Err(XimeaError::InvalidConfig(
                "Rgb24 colour mode requires RGB24 pixel format".into(),
            ));
        }
        for (name, value) in [
            ("roi_offset_x", self.roi_offset_x),
            ("roi_offset_y", self.roi_offset_y),
            ("width", self.width),
            ("height", self.height),
            ("exposure_us", self.exposure_us),
            ("frame_rate", self.frame_rate),
        ] {
            if value > i32::MAX as u32 {
                return Err(XimeaError::InvalidConfig(format!(
                    "{name} exceeds xiAPI's signed integer range"
                )));
            }
        }
        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct XimeaFrame {
    pub pixels: Vec<u8>,
    pub width: u32,
    pub height: u32,
    pub pixel_format: String,
}

#[derive(Debug, Error)]
pub enum XimeaError {
    #[error("invalid XIMEA configuration: {0}")]
    InvalidConfig(String),
    #[error("XIMEA {operation} failed: {detail}")]
    Native {
        operation: &'static str,
        detail: String,
    },
    #[error("XIMEA acquisition is not started")]
    NotStarted,
    #[error("XIMEA frame validation failed: {0}")]
    InvalidFrame(String),
}

pub type XimeaResult<T> = Result<T, XimeaError>;
