//! Native ALSA duplex PCM for Linux.
//!
//! The backend loads `libasound` from trusted system directories at runtime.
//! PCM streams use nonblocking interleaved I/O with finite waits.

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
#[cfg(any(target_os = "linux", test))]
use std::time::{Duration, Instant};
use thiserror::Error;

#[cfg(any(target_os = "linux", test))]
mod inventory_budget;
#[cfg(any(target_os = "linux", test))]
mod transfer;
#[cfg(any(target_os = "linux", test))]
use transfer::drive_transfer;

#[cfg(any(target_os = "linux", test))]
const WAIT_SLICE_MS: i32 = 2;
#[cfg(any(target_os = "linux", test))]
const MAX_RECOVERIES: usize = 4;
#[cfg(any(target_os = "linux", test))]
const EAGAIN: i32 = 11;
#[cfg(any(target_os = "linux", test))]
const EINTR: i32 = 4;
#[cfg(any(target_os = "linux", test))]
const EPIPE: i32 = 32;
#[cfg(any(target_os = "linux", test))]
const ESTRPIPE: i32 = 86;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AlsaConfig {
    pub capture_device: String,
    pub playback_device: String,
    pub sample_rate: u32,
    pub channels: u16,
    pub bits_per_sample: u16,
    pub frames_per_buffer: u32,
    pub capture_enabled: bool,
    pub playback_enabled: bool,
}

impl Default for AlsaConfig {
    fn default() -> Self {
        Self {
            capture_device: "hw:0".into(),
            playback_device: "hw:0".into(),
            sample_rate: 44_100,
            channels: 2,
            bits_per_sample: 16,
            frames_per_buffer: 64,
            capture_enabled: true,
            playback_enabled: true,
        }
    }
}

impl AlsaConfig {
    fn validate(&self) -> AlsaResult<()> {
        if !self.capture_enabled && !self.playback_enabled {
            return Err(AlsaError::InvalidConfig(
                "at least one PCM direction must be enabled".into(),
            ));
        }
        if self.capture_enabled && self.capture_device.trim().is_empty() {
            return Err(AlsaError::InvalidConfig(
                "capture_device must not be empty when capture is enabled".into(),
            ));
        }
        if self.capture_enabled {
            validation::validate_hardware_device("capture_device", &self.capture_device)?;
        }
        if self.playback_enabled && self.playback_device.trim().is_empty() {
            return Err(AlsaError::InvalidConfig(
                "playback_device must not be empty when playback is enabled".into(),
            ));
        }
        if self.playback_enabled {
            validation::validate_hardware_device("playback_device", &self.playback_device)?;
        }
        if self.sample_rate == 0 || self.channels == 0 || self.frames_per_buffer == 0 {
            return Err(AlsaError::InvalidConfig(
                "sample_rate, channels, and frames_per_buffer must be positive".into(),
            ));
        }
        if !matches!(self.bits_per_sample, 8 | 16 | 24 | 32) {
            return Err(AlsaError::InvalidConfig(format!(
                "unsupported bits_per_sample {}; expected 8, 16, 24, or 32",
                self.bits_per_sample
            )));
        }
        self.block_bytes()?;
        Ok(())
    }

    fn frame_bytes(&self) -> AlsaResult<usize> {
        usize::from(self.channels)
            .checked_mul(usize::from(self.bits_per_sample / 8))
            .ok_or_else(|| AlsaError::InvalidConfig("PCM frame size overflows usize".into()))
    }

    fn block_bytes(&self) -> AlsaResult<usize> {
        self.frame_bytes()?
            .checked_mul(self.frames_per_buffer as usize)
            .ok_or_else(|| AlsaError::InvalidConfig("PCM block size overflows usize".into()))
    }

    #[cfg(any(target_os = "linux", test))]
    fn timeout(&self) -> Duration {
        let period = f64::from(self.frames_per_buffer) / f64::from(self.sample_rate.max(1));
        Duration::from_secs_f64((period * 4.0).clamp(0.004, 0.020))
    }
}

#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize)]
pub struct AlsaDeviceInfo {
    pub name: String,
    pub description: Option<String>,
    pub supports_capture: bool,
    pub supports_playback: bool,
}

#[derive(Debug, Error)]
pub enum AlsaError {
    #[error("ALSA inventory limit exceeded")]
    InventoryLimit,
    #[error("invalid ALSA configuration: {0}")]
    InvalidConfig(String),
    #[error("ALSA is supported only on Linux")]
    Unsupported,
    #[error("could not load ALSA: {0}")]
    Library(String),
    #[error("ALSA {operation} failed ({code}): {detail}")]
    Native {
        operation: &'static str,
        code: i32,
        detail: String,
    },
    #[error("ALSA {field} negotiation mismatch: requested {requested}, selected {actual}")]
    NegotiationMismatch {
        field: &'static str,
        requested: u64,
        actual: u64,
    },
    #[error("ALSA stream is not started")]
    NotStarted,
    #[error("ALSA {0} direction is disabled")]
    DirectionDisabled(&'static str),
    #[error("PCM payload length {actual} does not match {expected} bytes")]
    InvalidPayload { expected: usize, actual: usize },
    #[error("ALSA {operation} timed out")]
    Timeout { operation: &'static str },
    #[error("ALSA transfer was cancelled")]
    Cancelled,
}

pub type AlsaResult<T> = Result<T, AlsaError>;

#[derive(Clone, Debug)]
pub struct AlsaCancellation {
    cancelled: Arc<AtomicBool>,
}

impl AlsaCancellation {
    pub fn cancel(&self) {
        self.cancelled.store(true, Ordering::Release);
    }
}

#[cfg(any(target_os = "linux", test))]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(super) struct NegotiatedPcm {
    pub(super) sample_rate: u32,
    pub(super) channels: u16,
    pub(super) bits_per_sample: u16,
    pub(super) frames_per_buffer: u32,
}

#[cfg(any(target_os = "linux", test))]
impl From<&AlsaConfig> for NegotiatedPcm {
    fn from(config: &AlsaConfig) -> Self {
        Self {
            sample_rate: config.sample_rate,
            channels: config.channels,
            bits_per_sample: config.bits_per_sample,
            frames_per_buffer: config.frames_per_buffer,
        }
    }
}

#[cfg(any(target_os = "linux", test))]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(super) enum StreamDirection {
    Capture,
    Playback,
}

#[cfg(any(target_os = "linux", test))]
pub(super) trait PcmBackend {
    fn negotiated(&self, direction: StreamDirection) -> Option<NegotiatedPcm>;
    fn start(&mut self) -> AlsaResult<()>;
    fn stop(&mut self) -> AlsaResult<()>;
    fn read_frames(&mut self, destination: &mut [u8], frames: usize) -> Result<usize, i32>;
    fn write_frames(&mut self, source: &[u8], frames: usize) -> Result<usize, i32>;
    fn wait(&mut self, direction: StreamDirection, timeout_ms: i32) -> Result<bool, i32>;
    fn recover(&mut self, direction: StreamDirection, error: i32) -> Result<(), i32>;
    fn error_text(&self, error: i32) -> String;
}

#[cfg(any(target_os = "linux", test))]
struct AlsaDriver<B: PcmBackend> {
    config: AlsaConfig,
    backend: B,
    started: bool,
    xruns: u64,
    cancelled: Arc<AtomicBool>,
}

#[cfg(any(target_os = "linux", test))]
impl<B: PcmBackend> AlsaDriver<B> {
    fn new(config: AlsaConfig, backend: B) -> AlsaResult<Self> {
        config.validate()?;
        let expected = NegotiatedPcm::from(&config);
        for (enabled, direction) in [
            (config.capture_enabled, StreamDirection::Capture),
            (config.playback_enabled, StreamDirection::Playback),
        ] {
            if enabled {
                let actual = backend.negotiated(direction).ok_or_else(|| {
                    AlsaError::InvalidConfig("enabled ALSA direction was not opened".into())
                })?;
                verify_negotiation(expected, actual)?;
            }
        }
        Ok(Self {
            config,
            backend,
            started: false,
            xruns: 0,
            cancelled: Arc::new(AtomicBool::new(false)),
        })
    }

    fn start(&mut self) -> AlsaResult<()> {
        if self.started {
            return Ok(());
        }
        self.cancelled.store(false, Ordering::Release);
        self.backend.start()?;
        self.started = true;
        Ok(())
    }

    fn stop(&mut self) -> AlsaResult<()> {
        self.cancelled.store(true, Ordering::Release);
        if !self.started {
            return Ok(());
        }
        self.started = false;
        self.backend.stop()
    }

    fn read_pcm_into(&mut self, output: &mut Vec<u8>) -> AlsaResult<()> {
        self.ensure_started()?;
        if !self.config.capture_enabled {
            return Err(AlsaError::DirectionDisabled("capture"));
        }
        let block_bytes = self.config.block_bytes()?;
        let frame_bytes = self.config.frame_bytes()?;
        output.clear();
        output.resize(block_bytes, 0);
        let deadline = Instant::now() + self.config.timeout();
        let cancelled = Arc::clone(&self.cancelled);
        let result = drive_transfer(
            &mut self.backend,
            &cancelled,
            &mut self.xruns,
            StreamDirection::Capture,
            self.config.frames_per_buffer as usize,
            deadline,
            |backend, offset, remaining| {
                backend.read_frames(&mut output[offset * frame_bytes..], remaining)
            },
        );
        match result {
            Ok(()) => Ok(()),
            Err(AlsaError::Timeout { .. }) => {
                output.clear();
                Ok(())
            }
            Err(error) => {
                output.clear();
                Err(error)
            }
        }
    }

    fn write_pcm(&mut self, pcm: &[u8]) -> AlsaResult<()> {
        self.ensure_started()?;
        if !self.config.playback_enabled {
            return Err(AlsaError::DirectionDisabled("playback"));
        }
        let expected = self.config.block_bytes()?;
        if pcm.len() != expected {
            return Err(AlsaError::InvalidPayload {
                expected,
                actual: pcm.len(),
            });
        }
        let frame_bytes = self.config.frame_bytes()?;
        let deadline = Instant::now() + self.config.timeout();
        drive_transfer(
            &mut self.backend,
            &self.cancelled,
            &mut self.xruns,
            StreamDirection::Playback,
            self.config.frames_per_buffer as usize,
            deadline,
            |backend, offset, remaining| {
                backend.write_frames(&pcm[offset * frame_bytes..], remaining)
            },
        )
    }

    fn ensure_started(&self) -> AlsaResult<()> {
        self.started.then_some(()).ok_or(AlsaError::NotStarted)
    }
}

#[cfg(any(target_os = "linux", test))]
impl StreamDirection {
    fn label(self) -> &'static str {
        match self {
            Self::Capture => "capture",
            Self::Playback => "playback",
        }
    }
}

#[cfg(any(target_os = "linux", test))]
fn verify_negotiation(expected: NegotiatedPcm, actual: NegotiatedPcm) -> AlsaResult<()> {
    let values = [
        (
            "sample_rate",
            u64::from(expected.sample_rate),
            u64::from(actual.sample_rate),
        ),
        (
            "channels",
            u64::from(expected.channels),
            u64::from(actual.channels),
        ),
        (
            "bits_per_sample",
            u64::from(expected.bits_per_sample),
            u64::from(actual.bits_per_sample),
        ),
        (
            "frames_per_buffer",
            u64::from(expected.frames_per_buffer),
            u64::from(actual.frames_per_buffer),
        ),
    ];
    for (field, requested, selected) in values {
        if requested != selected {
            return Err(AlsaError::NegotiationMismatch {
                field,
                requested,
                actual: selected,
            });
        }
    }
    Ok(())
}

pub struct AlsaAudio {
    #[cfg(target_os = "linux")]
    driver: AlsaDriver<native::NativeBackend>,
}

impl AlsaAudio {
    pub fn open(config: AlsaConfig) -> AlsaResult<Self> {
        config.validate()?;
        #[cfg(target_os = "linux")]
        {
            let backend = native::NativeBackend::open(&config)?;
            Ok(Self {
                driver: AlsaDriver::new(config, backend)?,
            })
        }
        #[cfg(not(target_os = "linux"))]
        {
            let _ = config;
            Err(AlsaError::Unsupported)
        }
    }

    pub fn start(&mut self) -> AlsaResult<()> {
        platform_call!(self, start)
    }
    pub fn read_pcm_into(&mut self, output: &mut Vec<u8>) -> AlsaResult<()> {
        #[cfg(target_os = "linux")]
        {
            self.driver.read_pcm_into(output)
        }
        #[cfg(not(target_os = "linux"))]
        {
            let _ = output;
            Err(AlsaError::Unsupported)
        }
    }
    pub fn write_pcm(&mut self, pcm: &[u8]) -> AlsaResult<()> {
        #[cfg(target_os = "linux")]
        {
            self.driver.write_pcm(pcm)
        }
        #[cfg(not(target_os = "linux"))]
        {
            let _ = pcm;
            Err(AlsaError::Unsupported)
        }
    }
    pub fn stop(&mut self) -> AlsaResult<()> {
        platform_call!(self, stop)
    }
    pub fn config(&self) -> &AlsaConfig {
        #[cfg(target_os = "linux")]
        {
            &self.driver.config
        }
        #[cfg(not(target_os = "linux"))]
        {
            panic!("AlsaAudio cannot be constructed off Linux")
        }
    }
    pub fn xruns(&self) -> u64 {
        #[cfg(target_os = "linux")]
        {
            self.driver.xruns
        }
        #[cfg(not(target_os = "linux"))]
        {
            0
        }
    }
    pub fn cancellation(&self) -> AlsaCancellation {
        #[cfg(target_os = "linux")]
        {
            AlsaCancellation {
                cancelled: Arc::clone(&self.driver.cancelled),
            }
        }
        #[cfg(not(target_os = "linux"))]
        {
            AlsaCancellation {
                cancelled: Arc::new(AtomicBool::new(true)),
            }
        }
    }
}

macro_rules! platform_call {
    ($self:ident, $method:ident) => {{
        #[cfg(target_os = "linux")]
        {
            $self.driver.$method()
        }
        #[cfg(not(target_os = "linux"))]
        {
            Err(AlsaError::Unsupported)
        }
    }};
}
use platform_call;

#[cfg(target_os = "linux")]
impl Drop for AlsaAudio {
    fn drop(&mut self) {
        let _ = self.driver.stop();
    }
}

pub fn inventory_alsa_devices() -> AlsaResult<Vec<AlsaDeviceInfo>> {
    #[cfg(target_os = "linux")]
    {
        native::inventory()
    }
    #[cfg(not(target_os = "linux"))]
    {
        Err(AlsaError::Unsupported)
    }
}

pub fn alsa_device_inventory() -> AlsaResult<Vec<AlsaDeviceInfo>> {
    inventory_alsa_devices()
}

#[cfg(target_os = "linux")]
mod native;
#[cfg(test)]
mod tests;
mod validation;
