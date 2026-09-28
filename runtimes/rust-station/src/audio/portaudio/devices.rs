use super::ffi::*;
use super::*;
pub struct AudioBackendInfo {
    pub name: String,
    pub available: bool,
    pub library_path: Option<PathBuf>,
    pub reason: String,
    pub device_count: Option<i32>,
    pub loaded: bool,
    pub initialized: bool,
}

#[derive(Debug, Clone, PartialEq)]
pub struct PortAudioDeviceInfo {
    pub index: i32,
    pub name: String,
    pub max_input_channels: i32,
    pub max_output_channels: i32,
    pub default_sample_rate: f64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum PortAudioDeviceSelector {
    Default,
    Index(i32),
    Name(String),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PortAudioConfig {
    pub input_device: PortAudioDeviceSelector,
    pub output_device: PortAudioDeviceSelector,
    pub sample_rate: u32,
    pub channels: u16,
    pub bits_per_sample: u16,
    pub frames_per_buffer: u32,
    /// Number of leading input-device channels skipped before capture.
    pub input_channel_offset: u32,
    pub local_audio_loop: bool,
    pub transfer_mode: PortAudioTransferMode,
}

/// I/O model selected for the strict native stream. Callback mode is the
/// session default; blocking mode remains available for compatibility tools.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum PortAudioTransferMode {
    Blocking,
    Callback { ring_blocks: usize },
}

impl Default for PortAudioConfig {
    fn default() -> Self {
        Self {
            input_device: PortAudioDeviceSelector::Default,
            output_device: PortAudioDeviceSelector::Default,
            sample_rate: 44_100,
            channels: 2,
            bits_per_sample: 16,
            frames_per_buffer: 64,
            input_channel_offset: 0,
            local_audio_loop: false,
            transfer_mode: PortAudioTransferMode::Callback { ring_blocks: 8 },
        }
    }
}

impl PortAudioConfig {
    pub fn from_settings(settings: &crate::config::AudioSettings) -> Self {
        let input_device = if settings.input_device.trim().is_empty() {
            PortAudioDeviceSelector::Default
        } else {
            PortAudioDeviceSelector::Name(settings.input_device.trim().to_owned())
        };
        let output_device = if settings.output_device.trim().is_empty() {
            PortAudioDeviceSelector::Default
        } else {
            PortAudioDeviceSelector::Name(settings.output_device.trim().to_owned())
        };
        Self {
            input_device,
            output_device,
            sample_rate: settings.sample_rate,
            channels: settings.channels,
            bits_per_sample: settings.bits_per_sample,
            frames_per_buffer: settings.buffer_samples,
            input_channel_offset: settings.input_offset,
            local_audio_loop: settings.local_audio_loop,
            transfer_mode: PortAudioTransferMode::Callback { ring_blocks: 8 },
        }
    }

    pub(super) fn sample_format(&self) -> Result<PaSampleFormat, PortAudioError> {
        match self.bits_per_sample {
            8 => Ok(PA_INT8),
            16 => Ok(PA_INT16),
            24 => Ok(PA_INT24),
            32 => Ok(PA_INT32),
            bits => Err(PortAudioError::InvalidConfig(format!(
                "unsupported bits_per_sample {bits}; expected 8, 16, 24, or 32"
            ))),
        }
    }

    pub(super) fn native_frames_per_buffer(&self) -> PaFramesPerBuffer {
        PaFramesPerBuffer::from(self.frames_per_buffer)
    }

    pub(super) fn validate(&self) -> Result<(), PortAudioError> {
        self.sample_format()?;
        self.input_channels()?;
        if self.sample_rate == 0 || self.channels == 0 || self.frames_per_buffer == 0 {
            return Err(PortAudioError::InvalidConfig(
                "sample_rate, channels, and frames_per_buffer must be positive".into(),
            ));
        }
        if matches!(
            self.transfer_mode,
            PortAudioTransferMode::Callback { ring_blocks: 0 }
        ) {
            return Err(PortAudioError::InvalidConfig(
                "callback ring_blocks must be positive".into(),
            ));
        }
        Ok(())
    }

    pub(super) fn input_channels(&self) -> PortAudioResult<i32> {
        u32::from(self.channels)
            .checked_add(self.input_channel_offset)
            .and_then(|channels| i32::try_from(channels).ok())
            .ok_or_else(|| {
                PortAudioError::InvalidConfig(
                    "input channel offset plus selected channels exceeds PortAudio limits".into(),
                )
            })
    }
}

#[derive(Debug, Error)]
pub enum PortAudioError {
    #[error("invalid PortAudio configuration: {0}")]
    InvalidConfig(String),
    #[error("PortAudio {operation} failed: {detail}")]
    Native {
        operation: &'static str,
        detail: String,
    },
    #[error("PortAudio stream is not started")]
    NotStarted,
    #[error("PCM payload length {actual} does not match {expected} bytes")]
    InvalidPayload { expected: usize, actual: usize },
    #[error("PortAudio callback capture ring has no complete block available")]
    CaptureUnavailable,
    #[error("PortAudio callback playback ring is full")]
    PlaybackQueueFull,
    #[error(
        "PortAudio {direction} device {device} is hosted by API type {host_api_type}, not ASIO"
    )]
    NotAsioDevice {
        direction: &'static str,
        device: i32,
        host_api_type: i32,
    },
}

pub type PortAudioResult<T> = Result<T, PortAudioError>;

impl AudioBackendInfo {
    pub fn to_json(&self) -> Value {
        json!({
            "name": self.name,
            "available": self.available,
            "library_path": self.library_path.as_ref().map(|p| p.display().to_string()),
            "reason": self.reason,
            "device_count": self.device_count,
            "loaded": self.loaded,
            "initialized": self.initialized,
        })
    }
}

/// Public view of the process-wide PortAudio binding (no owned Library → no unload).
pub struct PortAudioLibrary {
    path: PathBuf,
}

impl PortAudioLibrary {
    pub fn path(&self) -> &Path {
        &self.path
    }

    pub fn error_text(&self, code: i32) -> String {
        let _g = pa_lock();
        with_pa_fns_locked(|fns| error_text_fns(fns, code))
            .unwrap_or_else(|_| format!("PortAudio error {code}"))
    }

    pub fn initialize(&mut self) -> Result<(), String> {
        let _g = pa_lock();
        ensure_pa_ready_locked()
    }

    /// No-op: we never terminate the process-global PA instance (safe under tests).
    pub fn terminate(&mut self) {}

    pub fn device_count(&self) -> Result<i32, String> {
        let _g = pa_lock();
        with_pa_fns_locked(|fns| {
            // SAFETY: the surrounding PortAudio ownership and pointer checks establish the operation preconditions.
            let n = unsafe { (fns.get_device_count)() };
            if n < 0 {
                Err(format!("Pa_GetDeviceCount: {}", error_text_fns(fns, n)))
            } else {
                Ok(n)
            }
        })?
    }

    pub fn default_input_device(&self) -> i32 {
        let _g = pa_lock();
        with_pa_fns_locked(|fns| {
            if let Some(f) = fns.get_default_input {
                // SAFETY: the surrounding PortAudio ownership and pointer checks establish the operation preconditions.
                unsafe { f() }
            } else {
                0
            }
        })
        .unwrap_or(0)
    }

    pub fn default_output_device(&self) -> Result<i32, String> {
        let _g = pa_lock();
        with_pa_fns_locked(|fns| match fns.get_default_output {
            Some(f) => {
                // SAFETY: the surrounding PortAudio ownership and pointer checks establish the operation preconditions.
                let device = unsafe { f() };
                if device < 0 {
                    Err(format!(
                        "Pa_GetDefaultOutputDevice: {}",
                        error_text_fns(fns, device)
                    ))
                } else {
                    Ok(device)
                }
            }
            None => Err("Pa_GetDefaultOutputDevice not bound".into()),
        })?
    }

    pub fn devices(&self) -> Result<Vec<PortAudioDeviceInfo>, String> {
        let _g = pa_lock();
        with_pa_fns_locked(|fns| enumerate_devices_locked(fns))?
    }
}

pub(super) fn enumerate_devices_locked(fns: &PaFns) -> Result<Vec<PortAudioDeviceInfo>, String> {
    let get_info = fns
        .get_device_info
        .ok_or_else(|| "Pa_GetDeviceInfo not bound".to_string())?;
    // SAFETY: the surrounding PortAudio ownership and pointer checks establish the operation preconditions.
    let count = unsafe { (fns.get_device_count)() };
    if count < 0 {
        return Err(format!("Pa_GetDeviceCount: {}", error_text_fns(fns, count)));
    }
    let mut devices = Vec::with_capacity(count as usize);
    for index in 0..count {
        // `Pa_GetDeviceInfo` returns a PortAudio-owned immutable pointer whose
        // lifetime is the initialized process-global library.
        // SAFETY: the surrounding PortAudio ownership and pointer checks establish the operation preconditions.
        let info = unsafe { get_info(index) };
        if info.is_null() {
            return Err(format!("Pa_GetDeviceInfo({index}) returned null"));
        }
        // SAFETY: the surrounding PortAudio ownership and pointer checks establish the operation preconditions.
        let info = unsafe { &*info };
        let name = if info.name.is_null() {
            format!("device-{index}")
        } else {
            // SAFETY: the surrounding PortAudio ownership and pointer checks establish the operation preconditions.
            unsafe { CStr::from_ptr(info.name) }
                .to_string_lossy()
                .into_owned()
        };
        devices.push(PortAudioDeviceInfo {
            index,
            name,
            max_input_channels: info.max_input_channels,
            max_output_channels: info.max_output_channels,
            default_sample_rate: info.default_sample_rate,
        });
    }
    Ok(devices)
}

pub(super) fn select_device_locked(
    fns: &PaFns,
    selector: &PortAudioDeviceSelector,
    is_input: bool,
) -> PortAudioResult<i32> {
    let operation = if is_input {
        "input device selection"
    } else {
        "output device selection"
    };
    let default = if is_input {
        fns.get_default_input
            // SAFETY: the surrounding PortAudio ownership and pointer checks establish the operation preconditions.
            .map(|f| unsafe { f() })
            .ok_or_else(|| PortAudioError::Native {
                operation,
                detail: "Pa_GetDefaultInputDevice not bound".into(),
            })?
    } else {
        fns.get_default_output
            // SAFETY: the surrounding PortAudio ownership and pointer checks establish the operation preconditions.
            .map(|f| unsafe { f() })
            .ok_or_else(|| PortAudioError::Native {
                operation,
                detail: "Pa_GetDefaultOutputDevice not bound".into(),
            })?
    };
    match selector {
        PortAudioDeviceSelector::Default => {
            if default < 0 {
                Err(PortAudioError::Native {
                    operation,
                    detail: error_text_fns(fns, default),
                })
            } else {
                Ok(default)
            }
        }
        PortAudioDeviceSelector::Index(index) => Ok(*index),
        PortAudioDeviceSelector::Name(name) => enumerate_devices_locked(fns)
            .map_err(|detail| PortAudioError::Native { operation, detail })?
            .into_iter()
            .find(|device| {
                device.name.eq_ignore_ascii_case(name)
                    && if is_input {
                        device.max_input_channels > 0
                    } else {
                        device.max_output_channels > 0
                    }
            })
            .map(|device| device.index)
            .ok_or_else(|| PortAudioError::Native {
                operation,
                detail: format!("named device `{name}` not found"),
            }),
    }
}

/// Load/bind the process-wide PortAudio singleton (never unloads).
/// Safe under concurrent callers; all work is under `pa_lock`.
pub fn load_portaudio(dll_path: Option<&Path>) -> Result<PortAudioLibrary, String> {
    let _g = pa_lock();
    // Optional explicit path: only used on first load if global empty
    if dll_path.is_some() {
        let slot = pa_global().lock().unwrap_or_else(|e| e.into_inner());
        if slot.is_none() {
            // Force path as first candidate by temporarily trying it
            drop(slot);
            if let Some(p) = dll_path {
                // SAFETY: the surrounding PortAudio ownership and pointer checks establish the operation preconditions.
                if let Ok(lib) = unsafe { crate::native_loader::load(p) } {
                    // If path works, seed via normal ensure after putting file first
                    let _ = lib; // drop this temp load — ensure_pa will load properly
                                 // Prefer explicit path by prepending: re-implement quick bind
                    if let Ok(()) = try_load_path_locked(p) {
                        ensure_pa_ready_locked()?;
                        let path = pa_path_locked()?;
                        return Ok(PortAudioLibrary { path });
                    }
                }
            }
        }
    }
    ensure_pa_ready_locked()?;
    let path = pa_path_locked()?;
    Ok(PortAudioLibrary { path })
}

pub(super) fn try_load_path_locked(path: &Path) -> Result<(), String> {
    let mut slot = pa_global().lock().unwrap_or_else(|e| e.into_inner());
    if slot.is_some() {
        return Ok(());
    }
    // SAFETY: the surrounding PortAudio ownership and pointer checks establish the operation preconditions.
    let lib = unsafe { crate::native_loader::load(path) }
        .map_err(|e| format!("load {}: {e}", path.display()))?;
    let bindings = bind_pa_symbols(&lib)?;
    let _leaked: &'static Library = Box::leak(Box::new(lib));
    let path_resolved = path.canonicalize().unwrap_or_else(|_| path.to_path_buf());
    *slot = Some(PaGlobal::Ready(Box::new(PaFns::from_bindings(
        path_resolved,
        bindings,
    ))));
    Ok(())
}

pub(super) fn pa_path_locked() -> Result<PathBuf, String> {
    let slot = pa_global().lock().unwrap_or_else(|e| e.into_inner());
    match slot.as_ref() {
        Some(PaGlobal::Ready(fns)) => Ok(fns.path.clone()),
        Some(PaGlobal::Failed(e)) => Err(e.clone()),
        None => Err("PortAudio not loaded".into()),
    }
}

/// Probe: available only when DLL loads, symbols bind, and Pa_Initialize succeeds.
pub fn probe_portaudio() -> AudioBackendInfo {
    let _g = pa_lock();
    match ensure_pa_ready_locked() {
        Ok(()) => {
            let path = pa_path_locked().ok();
            let device_count = with_pa_fns_locked(|fns| {
                // SAFETY: the surrounding PortAudio ownership and pointer checks establish the operation preconditions.
                let n = unsafe { (fns.get_device_count)() };
                if n < 0 {
                    None
                } else {
                    Some(n)
                }
            })
            .ok()
            .flatten();
            let path_disp = path
                .as_ref()
                .map(|p| p.display().to_string())
                .unwrap_or_default();
            AudioBackendInfo {
                name: "portaudio".into(),
                available: true,
                library_path: path,
                reason: match device_count {
                    Some(0) => format!("loaded+init {path_disp}; 0 devices"),
                    Some(n) => format!("loaded+init {path_disp}; {n} device(s)"),
                    None => format!("loaded+init {path_disp}; device enum failed"),
                },
                device_count,
                loaded: true,
                initialized: true,
            }
        }
        Err(e) => {
            let loaded = ensure_pa_loaded_locked().is_ok();
            let library_path = if loaded { pa_path_locked().ok() } else { None };
            AudioBackendInfo {
                name: "portaudio".into(),
                available: false,
                library_path,
                reason: e,
                device_count: None,
                loaded,
                initialized: false,
            }
        }
    }
}
