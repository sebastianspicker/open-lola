//! Native Linux V4L2 camera capture with bounded memory-mapped streaming.

#[cfg(any(target_os = "linux", test))]
mod color;
#[cfg(any(target_os = "linux", test))]
mod convert;
#[cfg(target_os = "linux")]
mod inventory;
#[cfg(any(target_os = "linux", test))]
mod lifecycle;
#[cfg(target_os = "linux")]
mod linux;
#[cfg(not(target_os = "linux"))]
mod nonlinux;
#[cfg(target_os = "linux")]
mod uapi;

use serde::Serialize;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::Duration;
#[cfg(any(target_os = "linux", test))]
use std::time::Instant;
use thiserror::Error;

#[cfg(target_os = "linux")]
use linux as platform;
#[cfg(not(target_os = "linux"))]
use nonlinux as platform;

const MAX_DIMENSION: u32 = crate::protocol::MAX_DIMENSION_PIXELS;
const MAX_NORMALIZED_FRAME_BYTES: usize = crate::protocol::MAX_MEDIA_FRAME_SIZE;
const MAX_FPS: u32 = 1_000;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct V4l2Config {
    pub device: String,
    pub width: u32,
    pub height: u32,
    pub fps: u32,
    pub pixel_format: String,
}

impl Default for V4l2Config {
    fn default() -> Self {
        Self {
            device: "/dev/video0".into(),
            width: 640,
            height: 480,
            fps: 30,
            pixel_format: "RGB24".into(),
        }
    }
}

impl V4l2Config {
    fn validate(&self) -> V4l2Result<NativeFormat> {
        if self.device.is_empty() {
            return Err(V4l2Error::InvalidConfig("device path is empty".into()));
        }
        let pixels = u64::from(self.width) * u64::from(self.height);
        if self.width == 0
            || self.height == 0
            || self.width > MAX_DIMENSION
            || self.height > MAX_DIMENSION
        {
            return Err(V4l2Error::InvalidConfig(format!(
                "dimensions {}x{} are outside the capture bounds",
                self.width, self.height
            )));
        }
        if self.fps == 0 || self.fps > MAX_FPS {
            return Err(V4l2Error::InvalidConfig(format!(
                "fps {} is outside 1..={MAX_FPS}",
                self.fps
            )));
        }
        let format = NativeFormat::parse(&self.pixel_format)?;
        format.minimum_row_bytes(self.width)?;
        let normalized = format.normalized_frame_bytes(pixels)?;
        if normalized > MAX_NORMALIZED_FRAME_BYTES {
            return Err(V4l2Error::InvalidConfig(format!(
                "normalized frame size {normalized} exceeds {MAX_NORMALIZED_FRAME_BYTES} bytes"
            )));
        }
        Ok(format)
    }

    fn frame_timeout(&self) -> Duration {
        Duration::from_millis((3_000u64 / u64::from(self.fps.max(1))).clamp(100, 5_000))
    }
}

#[derive(Debug, Error)]
pub enum V4l2Error {
    #[error("V4L2 camera capture is supported only on Linux")]
    UnsupportedPlatform,
    #[error("invalid V4L2 configuration: {0}")]
    InvalidConfig(String),
    #[error("unsupported V4L2 pixel format {0:?}; use RGB24, BGR24, YUYV, Mono8/GREY, or MJPEG")]
    UnsupportedPixelFormat(String),
    #[error("{operation}: {source}")]
    Io {
        operation: &'static str,
        #[source]
        source: std::io::Error,
    },
    #[error("device lacks required V4L2 capability: {0}")]
    MissingCapability(&'static str),
    #[error("V4L2 negotiation changed {field}: requested {requested}, received {actual}")]
    NegotiationMismatch {
        field: &'static str,
        requested: String,
        actual: String,
    },
    #[error("V4L2 frame readiness timed out after {0:?}")]
    Timeout(Duration),
    #[error("V4L2 frame capture was cancelled")]
    Cancelled,
    #[error("invalid V4L2 frame: {0}")]
    InvalidFrame(String),
    #[error("V4L2 frame conversion failed: {0}")]
    Conversion(String),
    #[error("V4L2 cleanup failed: {0}")]
    Cleanup(String),
    #[error("V4L2 inventory limit reached: {0}")]
    InventoryLimit(String),
}

pub type V4l2Result<T> = Result<T, V4l2Error>;

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct V4l2Capabilities {
    pub raw: u32,
    pub device_raw: u32,
    pub video_capture: bool,
    pub video_capture_mplane: bool,
    pub streaming: bool,
    pub read_write: bool,
    pub metadata_capture: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub enum V4l2FrameSize {
    Discrete {
        width: u32,
        height: u32,
    },
    Range {
        continuous: bool,
        min_width: u32,
        max_width: u32,
        step_width: u32,
        min_height: u32,
        max_height: u32,
        step_height: u32,
    },
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub enum V4l2FrameInterval {
    Discrete {
        numerator: u32,
        denominator: u32,
    },
    Range {
        continuous: bool,
        min_numerator: u32,
        min_denominator: u32,
        max_numerator: u32,
        max_denominator: u32,
        step_numerator: u32,
        step_denominator: u32,
    },
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct V4l2Mode {
    pub size: V4l2FrameSize,
    pub intervals: Vec<V4l2FrameInterval>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct V4l2FormatInfo {
    pub pixel_format: String,
    pub description: String,
    pub compressed: bool,
    pub emulated: bool,
    pub modes: Vec<V4l2Mode>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct V4l2DeviceInfo {
    pub device: String,
    pub driver: String,
    pub card: String,
    pub bus_info: String,
    pub version: u32,
    pub capabilities: V4l2Capabilities,
    pub formats: Vec<V4l2FormatInfo>,
}

#[derive(Debug, Clone)]
pub struct V4l2Cancellation {
    cancelled: Arc<AtomicBool>,
}

impl V4l2Cancellation {
    pub fn cancel(&self) {
        self.cancelled.store(true, Ordering::Release);
    }

    pub fn is_cancelled(&self) -> bool {
        self.cancelled.load(Ordering::Acquire)
    }
}

pub struct V4l2Camera {
    config: V4l2Config,
    cancellation: Arc<AtomicBool>,
    inner: platform::Camera,
}

impl std::fmt::Debug for V4l2Camera {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        formatter
            .debug_struct("V4l2Camera")
            .field("config", &self.config)
            .field("cancelled", &self.cancellation.load(Ordering::Relaxed))
            .finish_non_exhaustive()
    }
}

impl V4l2Camera {
    pub fn open(config: V4l2Config) -> V4l2Result<Self> {
        let native_format = config.validate()?;
        let cancellation = Arc::new(AtomicBool::new(false));
        let inner = platform::Camera::open(&config, native_format, Arc::clone(&cancellation))?;
        Ok(Self {
            config,
            cancellation,
            inner,
        })
    }

    pub fn config(&self) -> &V4l2Config {
        &self.config
    }

    pub fn cancellation_handle(&self) -> V4l2Cancellation {
        V4l2Cancellation {
            cancelled: Arc::clone(&self.cancellation),
        }
    }

    pub fn start(&mut self) -> V4l2Result<()> {
        self.cancellation.store(false, Ordering::Release);
        self.inner.start()
    }

    pub fn grab(&mut self) -> V4l2Result<(Vec<u8>, String)> {
        if self.cancellation.load(Ordering::Acquire) {
            return Err(V4l2Error::Cancelled);
        }
        self.inner.grab(self.config.frame_timeout())
    }

    pub fn stop(&mut self) -> V4l2Result<()> {
        self.cancellation.store(true, Ordering::Release);
        self.inner.stop()
    }

    pub fn inventory() -> V4l2Result<Vec<V4l2DeviceInfo>> {
        platform::inventory()
    }

    pub fn inventory_device(device: &str) -> V4l2Result<V4l2DeviceInfo> {
        platform::inventory_device(device)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum NativeFormat {
    Rgb24,
    Bgr24,
    Yuyv,
    Gray8,
    Mjpeg,
}

impl NativeFormat {
    fn parse(value: &str) -> V4l2Result<Self> {
        match value.trim().to_ascii_uppercase().as_str() {
            "RGB" | "RGB24" | "RGB3" => Ok(Self::Rgb24),
            "BGR" | "BGR24" | "BGR3" => Ok(Self::Bgr24),
            "YUYV" | "YUY2" => Ok(Self::Yuyv),
            "MONO8" | "GRAY8" | "GREY" => Ok(Self::Gray8),
            "MJPEG" | "MJPG" => Ok(Self::Mjpeg),
            _ => Err(V4l2Error::UnsupportedPixelFormat(value.into())),
        }
    }

    #[cfg(target_os = "linux")]
    fn fourcc(self) -> u32 {
        match self {
            Self::Rgb24 => fourcc(*b"RGB3"),
            Self::Bgr24 => fourcc(*b"BGR3"),
            Self::Yuyv => fourcc(*b"YUYV"),
            Self::Gray8 => fourcc(*b"GREY"),
            Self::Mjpeg => fourcc(*b"MJPG"),
        }
    }

    #[cfg(target_os = "linux")]
    fn fourcc_name(self) -> &'static str {
        match self {
            Self::Rgb24 => "RGB3",
            Self::Bgr24 => "BGR3",
            Self::Yuyv => "YUYV",
            Self::Gray8 => "GREY",
            Self::Mjpeg => "MJPG",
        }
    }

    fn minimum_row_bytes(self, width: u32) -> V4l2Result<usize> {
        if self == Self::Mjpeg {
            return Ok(0);
        }
        if self == Self::Yuyv && !width.is_multiple_of(2) {
            return Err(V4l2Error::InvalidConfig(
                "YUYV capture requires an even width".into(),
            ));
        }
        let channels = match self {
            Self::Rgb24 | Self::Bgr24 => 3,
            Self::Yuyv => 2,
            Self::Gray8 => 1,
            Self::Mjpeg => unreachable!(),
        };
        (width as usize)
            .checked_mul(channels)
            .ok_or_else(|| V4l2Error::InvalidConfig("frame row size overflow".into()))
    }

    fn normalized_frame_bytes(self, pixels: u64) -> V4l2Result<usize> {
        let channels = if self == Self::Gray8 { 1 } else { 3 };
        usize::try_from(pixels)
            .ok()
            .and_then(|value| value.checked_mul(channels))
            .ok_or_else(|| V4l2Error::InvalidConfig("normalized frame size overflow".into()))
    }
}

#[cfg(target_os = "linux")]
const fn fourcc(bytes: [u8; 4]) -> u32 {
    u32::from_le_bytes(bytes)
}

#[cfg(target_os = "linux")]
fn fourcc_string(value: u32) -> String {
    value
        .to_le_bytes()
        .iter()
        .map(|byte| {
            if byte.is_ascii_graphic() || *byte == b' ' {
                char::from(*byte)
            } else {
                '.'
            }
        })
        .collect()
}

#[cfg(any(target_os = "linux", test))]
fn require_exact<T>(field: &'static str, requested: T, actual: T) -> V4l2Result<()>
where
    T: Eq + ToString,
{
    if requested == actual {
        Ok(())
    } else {
        Err(V4l2Error::NegotiationMismatch {
            field,
            requested: requested.to_string(),
            actual: actual.to_string(),
        })
    }
}

#[cfg(any(target_os = "linux", test))]
fn require_exact_interval(
    requested_numerator: u32,
    requested_denominator: u32,
    actual_numerator: u32,
    actual_denominator: u32,
) -> V4l2Result<()> {
    let requested = format!("{requested_numerator}/{requested_denominator} seconds");
    let actual = format!("{actual_numerator}/{actual_denominator} seconds");
    if actual_numerator == 0
        || actual_denominator == 0
        || u64::from(requested_numerator) * u64::from(actual_denominator)
            != u64::from(actual_numerator) * u64::from(requested_denominator)
    {
        return Err(V4l2Error::NegotiationMismatch {
            field: "frame interval",
            requested,
            actual,
        });
    }
    Ok(())
}

#[cfg(any(target_os = "linux", test))]
const POLL_SLICE: Duration = Duration::from_millis(25);

#[cfg(any(target_os = "linux", test))]
fn next_poll_timeout(
    cancelled: &AtomicBool,
    deadline: Instant,
    now: Instant,
    full_timeout: Duration,
) -> V4l2Result<Duration> {
    if cancelled.load(Ordering::Acquire) {
        return Err(V4l2Error::Cancelled);
    }
    let remaining = deadline
        .checked_duration_since(now)
        .filter(|value| !value.is_zero())
        .ok_or(V4l2Error::Timeout(full_timeout))?;
    Ok(remaining.min(POLL_SLICE))
}

#[cfg(any(target_os = "linux", test))]
fn wait_for_readiness(
    cancelled: &AtomicBool,
    deadline: Instant,
    full_timeout: Duration,
    mut now: impl FnMut() -> Instant,
    mut attempt: impl FnMut(Duration) -> V4l2Result<bool>,
) -> V4l2Result<()> {
    loop {
        let timeout = next_poll_timeout(cancelled, deadline, now(), full_timeout)?;
        if attempt(timeout)? {
            return Ok(());
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn configuration_rejects_invalid_bounds_and_formats() {
        for config in [
            V4l2Config {
                width: 0,
                ..V4l2Config::default()
            },
            V4l2Config {
                fps: 0,
                ..V4l2Config::default()
            },
            V4l2Config {
                width: 641,
                pixel_format: "YUYV".into(),
                ..V4l2Config::default()
            },
            V4l2Config {
                width: 8_193,
                ..V4l2Config::default()
            },
            V4l2Config {
                width: 8_192,
                height: 8_192,
                pixel_format: "RGB24".into(),
                ..V4l2Config::default()
            },
        ] {
            assert!(matches!(
                config.validate(),
                Err(V4l2Error::InvalidConfig(_))
            ));
        }
        let config = V4l2Config {
            pixel_format: "NV12".into(),
            ..V4l2Config::default()
        };
        assert!(matches!(
            config.validate(),
            Err(V4l2Error::UnsupportedPixelFormat(_))
        ));
    }

    #[test]
    fn cancellation_token_is_deterministic() {
        let cancelled = Arc::new(AtomicBool::new(false));
        let token = V4l2Cancellation {
            cancelled: Arc::clone(&cancelled),
        };
        token.cancel();
        assert!(token.is_cancelled());
        assert!(cancelled.load(Ordering::Acquire));
    }

    #[test]
    fn exact_negotiation_rejects_driver_adjustments() {
        assert!(require_exact("width", 640, 640).is_ok());
        assert!(matches!(
            require_exact("width", 640, 800),
            Err(V4l2Error::NegotiationMismatch { field: "width", .. })
        ));
        assert!(require_exact_interval(1, 30, 2, 60).is_ok());
        assert!(matches!(
            require_exact_interval(1, 30, 1, 25),
            Err(V4l2Error::NegotiationMismatch {
                field: "frame interval",
                ..
            })
        ));
    }

    #[test]
    fn poll_wait_is_bounded_and_cancellable() {
        let cancelled = AtomicBool::new(false);
        let now = Instant::now();
        let timeout = Duration::from_secs(1);
        assert_eq!(
            next_poll_timeout(&cancelled, now + timeout, now, timeout).unwrap(),
            POLL_SLICE
        );
        cancelled.store(true, Ordering::Release);
        assert!(matches!(
            next_poll_timeout(&cancelled, now + timeout, now, timeout),
            Err(V4l2Error::Cancelled)
        ));
        cancelled.store(false, Ordering::Release);
        assert!(matches!(
            next_poll_timeout(&cancelled, now, now + POLL_SLICE, timeout),
            Err(V4l2Error::Timeout(value)) if value == timeout
        ));
    }

    #[test]
    fn repeated_interrupted_waits_reach_the_original_deadline() {
        let cancelled = AtomicBool::new(false);
        let start = Instant::now();
        let timeout = Duration::from_millis(10);
        let times = [start, start + Duration::from_millis(5), start + timeout];
        let mut next = times.into_iter();
        let mut attempts = 0;
        let error = wait_for_readiness(
            &cancelled,
            start + timeout,
            timeout,
            || next.next().unwrap(),
            |_| {
                attempts += 1;
                Ok(false)
            },
        )
        .unwrap_err();
        assert!(matches!(error, V4l2Error::Timeout(value) if value == timeout));
        assert_eq!(attempts, 2);
    }

    #[cfg(not(target_os = "linux"))]
    #[test]
    fn unsupported_platform_fails_explicitly() {
        assert!(matches!(
            V4l2Camera::open(V4l2Config::default()),
            Err(V4l2Error::UnsupportedPlatform)
        ));
        assert!(matches!(
            V4l2Camera::inventory(),
            Err(V4l2Error::UnsupportedPlatform)
        ));
    }
}
