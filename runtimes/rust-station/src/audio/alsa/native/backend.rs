use super::super::{
    AlsaConfig, AlsaError, AlsaResult, NegotiatedPcm, PcmBackend, StreamDirection, EAGAIN, EINTR,
    EPIPE, ESTRPIPE,
};
use super::ffi::*;
use std::ffi::{c_int, c_uint, CString};
use std::ptr::NonNull;
use std::sync::Arc;

pub(crate) struct NativeBackend {
    capture: Option<NativePcm>,
    playback: Option<NativePcm>,
}

struct NativePcm {
    api: Arc<AlsaApi>,
    handle: NonNull<PcmHandle>,
    negotiated: NegotiatedPcm,
}

impl NativeBackend {
    pub(crate) fn open(config: &AlsaConfig) -> AlsaResult<Self> {
        let api = Arc::new(AlsaApi::load()?);
        let capture = if config.capture_enabled {
            Some(NativePcm::open(
                Arc::clone(&api),
                &config.capture_device,
                StreamDirection::Capture,
                config,
            )?)
        } else {
            None
        };
        let playback = if config.playback_enabled {
            Some(NativePcm::open(
                api,
                &config.playback_device,
                StreamDirection::Playback,
                config,
            )?)
        } else {
            None
        };
        Ok(Self { capture, playback })
    }

    fn pcm(&self, direction: StreamDirection) -> Option<&NativePcm> {
        match direction {
            StreamDirection::Capture => self.capture.as_ref(),
            StreamDirection::Playback => self.playback.as_ref(),
        }
    }

    fn require_pcm(&self, direction: StreamDirection) -> &NativePcm {
        self.pcm(direction)
            .expect("driver validates every enabled ALSA direction")
    }
}

impl PcmBackend for NativeBackend {
    fn negotiated(&self, direction: StreamDirection) -> Option<NegotiatedPcm> {
        self.pcm(direction).map(|pcm| pcm.negotiated)
    }

    fn start(&mut self) -> AlsaResult<()> {
        if let Some(playback) = &self.playback {
            playback.call("prepare playback", playback.api.pcm_prepare)?;
        }
        if let Some(capture) = &self.capture {
            capture.call("prepare capture", capture.api.pcm_prepare)?;
            capture.call("start capture", capture.api.pcm_start)?;
        }
        Ok(())
    }

    fn stop(&mut self) -> AlsaResult<()> {
        let capture_error = self
            .capture
            .as_ref()
            .and_then(|pcm| pcm.call("drop capture", pcm.api.pcm_drop).err());
        let playback_error = self
            .playback
            .as_ref()
            .and_then(|pcm| pcm.call("drop playback", pcm.api.pcm_drop).err());
        capture_error.or(playback_error).map_or(Ok(()), Err)
    }

    fn read_frames(&mut self, destination: &mut [u8], frames: usize) -> Result<usize, i32> {
        let pcm = self.require_pcm(StreamDirection::Capture);
        let frames = PcmFrames::try_from(frames).map_err(|_| -libc::EOVERFLOW)?;
        // SAFETY: the stream is open; the caller supplies storage for the
        // requested interleaved frame count negotiated for this PCM.
        let result = unsafe {
            (pcm.api.pcm_readi)(pcm.handle.as_ptr(), destination.as_mut_ptr().cast(), frames)
        };
        frame_result(result)
    }

    fn write_frames(&mut self, source: &[u8], frames: usize) -> Result<usize, i32> {
        let pcm = self.require_pcm(StreamDirection::Playback);
        let frames = PcmFrames::try_from(frames).map_err(|_| -libc::EOVERFLOW)?;
        // SAFETY: the stream is open and `source` contains the requested
        // interleaved frame count in the negotiated format.
        let result =
            unsafe { (pcm.api.pcm_writei)(pcm.handle.as_ptr(), source.as_ptr().cast(), frames) };
        frame_result(result)
    }

    fn wait(&mut self, direction: StreamDirection, timeout_ms: i32) -> Result<bool, i32> {
        let pcm = self.require_pcm(direction);
        // SAFETY: the stream is open and the timeout is finite.
        let result = unsafe { (pcm.api.pcm_wait)(pcm.handle.as_ptr(), timeout_ms) };
        match result {
            value if value > 0 => Ok(true),
            0 => Ok(false),
            error => Err(error),
        }
    }

    fn recover(&mut self, direction: StreamDirection, error: i32) -> Result<(), i32> {
        let pcm = self.require_pcm(direction);
        match error {
            value if value == -EPIPE => pcm.raw_call(pcm.api.pcm_prepare),
            value if value == -ESTRPIPE => pcm.resume_or_prepare(),
            value if value == -EINTR => Ok(()),
            value => Err(value),
        }
    }

    fn error_text(&self, error: i32) -> String {
        self.capture
            .as_ref()
            .or(self.playback.as_ref())
            .map_or_else(
                || format!("ALSA error {error}"),
                |pcm| pcm.api.error_text(error),
            )
    }
}

impl NativePcm {
    fn open(
        api: Arc<AlsaApi>,
        device: &str,
        direction: StreamDirection,
        config: &AlsaConfig,
    ) -> AlsaResult<Self> {
        let name = CString::new(device).map_err(|_| {
            AlsaError::InvalidConfig(format!("{} device contains a NUL byte", direction.label()))
        })?;
        let mut raw = std::ptr::null_mut();
        let stream = match direction {
            StreamDirection::Capture => STREAM_CAPTURE,
            StreamDirection::Playback => STREAM_PLAYBACK,
        };
        // SAFETY: all pointers are valid and the returned handle is checked.
        let result = unsafe { (api.pcm_open)(&mut raw, name.as_ptr(), stream, NONBLOCK) };
        check_result(&api, "open PCM", result)?;
        let handle = NonNull::new(raw).ok_or_else(|| AlsaError::Native {
            operation: "open PCM",
            code: 0,
            detail: "ALSA returned a null handle".into(),
        })?;
        let mut pcm = Self {
            api,
            handle,
            negotiated: NegotiatedPcm::from(config),
        };
        pcm.negotiated = pcm.configure(config)?;
        Ok(pcm)
    }

    fn configure(&self, config: &AlsaConfig) -> AlsaResult<NegotiatedPcm> {
        let mut raw = std::ptr::null_mut();
        // SAFETY: output pointer is valid and initialized by ALSA on success.
        let result = unsafe { (self.api.hw_malloc)(&mut raw) };
        check_result(&self.api, "allocate hardware parameters", result)?;
        let params = NonNull::new(raw).ok_or_else(|| AlsaError::Native {
            operation: "allocate hardware parameters",
            code: 0,
            detail: "ALSA returned null hardware parameters".into(),
        })?;
        let guard = HwParamsGuard {
            api: &self.api,
            params,
        };
        self.apply_parameters(guard.params.as_ptr(), config)?;
        read_negotiated(&self.api, guard.params.as_ptr())
    }

    fn apply_parameters(&self, params: *mut HwParams, config: &AlsaConfig) -> AlsaResult<()> {
        self.call_hw("initialize hardware parameters", self.api.hw_any, params)?;
        self.call_hw_value(
            "set interleaved access",
            self.api.hw_set_access,
            params,
            ACCESS_RW_INTERLEAVED,
        )?;
        self.call_hw_value(
            "set sample format",
            self.api.hw_set_format,
            params,
            pcm_format(config)?,
        )?;
        self.call_hw_value(
            "set channel count",
            self.api.hw_set_channels,
            params,
            c_uint::from(config.channels),
        )?;
        // SAFETY: handle and parameters are live; `dir=0` requests the exact rate.
        let result =
            unsafe { (self.api.hw_set_rate)(self.handle.as_ptr(), params, config.sample_rate, 0) };
        check_result(&self.api, "set sample rate", result)?;
        // SAFETY: handle and parameters are live; `dir=0` requests the exact period.
        let result = unsafe {
            (self.api.hw_set_period)(
                self.handle.as_ptr(),
                params,
                PcmFrames::from(config.frames_per_buffer),
                0,
            )
        };
        check_result(&self.api, "set period size", result)?;
        self.call_hw("apply hardware parameters", self.api.hw_apply, params)
    }

    fn call(
        &self,
        operation: &'static str,
        function: unsafe extern "C" fn(*mut PcmHandle) -> c_int,
    ) -> AlsaResult<()> {
        self.raw_call(function)
            .map_err(|code| native_error(&self.api, operation, code))
    }

    fn raw_call(&self, function: unsafe extern "C" fn(*mut PcmHandle) -> c_int) -> Result<(), i32> {
        // SAFETY: `self.handle` remains open for the lifetime of this object.
        let result = unsafe { function(self.handle.as_ptr()) };
        if result < 0 {
            Err(result)
        } else {
            Ok(())
        }
    }

    fn resume_or_prepare(&self) -> Result<(), i32> {
        match self.raw_call(self.api.pcm_resume) {
            Ok(()) => Ok(()),
            Err(error) if error == -EAGAIN => self.raw_call(self.api.pcm_prepare),
            Err(_) => self.raw_call(self.api.pcm_prepare),
        }
    }

    fn call_hw(
        &self,
        operation: &'static str,
        function: unsafe extern "C" fn(*mut PcmHandle, *mut HwParams) -> c_int,
        params: *mut HwParams,
    ) -> AlsaResult<()> {
        // SAFETY: both pointers remain live throughout configuration.
        let result = unsafe { function(self.handle.as_ptr(), params) };
        check_result(&self.api, operation, result)
    }

    fn call_hw_value<T: Copy>(
        &self,
        operation: &'static str,
        function: unsafe extern "C" fn(*mut PcmHandle, *mut HwParams, T) -> c_int,
        params: *mut HwParams,
        value: T,
    ) -> AlsaResult<()> {
        // SAFETY: both pointers remain live and `value` matches the bound ABI.
        let result = unsafe { function(self.handle.as_ptr(), params, value) };
        check_result(&self.api, operation, result)
    }
}

impl Drop for NativePcm {
    fn drop(&mut self) {
        // SAFETY: the handle is owned by this object and closed exactly once.
        let _ = unsafe { (self.api.pcm_close)(self.handle.as_ptr()) };
    }
}

struct HwParamsGuard<'a> {
    api: &'a AlsaApi,
    params: NonNull<HwParams>,
}

impl Drop for HwParamsGuard<'_> {
    fn drop(&mut self) {
        // SAFETY: the allocation belongs to this guard and is freed once.
        unsafe { (self.api.hw_free)(self.params.as_ptr()) };
    }
}

fn pcm_format(config: &AlsaConfig) -> AlsaResult<c_int> {
    match config.bits_per_sample {
        8 => Ok(FORMAT_S8),
        16 => Ok(FORMAT_S16_LE),
        24 => Ok(FORMAT_S24_3LE),
        32 => Ok(FORMAT_S32_LE),
        bits => Err(AlsaError::InvalidConfig(format!(
            "unsupported bits_per_sample {bits}"
        ))),
    }
}

fn read_negotiated(api: &AlsaApi, params: *mut HwParams) -> AlsaResult<NegotiatedPcm> {
    let mut format = 0;
    let mut channels = 0;
    let mut rate = 0;
    let mut rate_dir = 0;
    let mut period = 0;
    let mut period_dir = 0;
    // SAFETY: the applied parameter object remains live and output pointers are valid.
    check_result(api, "read sample format", unsafe {
        (api.hw_get_format)(params, &mut format)
    })?;
    // SAFETY: same as above.
    check_result(api, "read channel count", unsafe {
        (api.hw_get_channels)(params, &mut channels)
    })?;
    // SAFETY: same as above.
    check_result(api, "read sample rate", unsafe {
        (api.hw_get_rate)(params, &mut rate, &mut rate_dir)
    })?;
    // SAFETY: same as above.
    check_result(api, "read period size", unsafe {
        (api.hw_get_period)(params, &mut period, &mut period_dir)
    })?;
    let _ = (rate_dir, period_dir);
    Ok(NegotiatedPcm {
        sample_rate: rate,
        channels: u16::try_from(channels).map_err(|_| invalid_negotiated("channels"))?,
        bits_per_sample: format_bits(format).ok_or_else(|| invalid_negotiated("sample format"))?,
        frames_per_buffer: u32::try_from(period).map_err(|_| invalid_negotiated("period size"))?,
    })
}

fn format_bits(format: c_int) -> Option<u16> {
    match format {
        FORMAT_S8 => Some(8),
        FORMAT_S16_LE => Some(16),
        FORMAT_S24_3LE => Some(24),
        FORMAT_S32_LE => Some(32),
        _ => None,
    }
}

fn frame_result(result: PcmSignedFrames) -> Result<usize, i32> {
    if result < 0 {
        Err(i32::try_from(result).unwrap_or(-libc::EIO))
    } else {
        usize::try_from(result).map_err(|_| -libc::EOVERFLOW)
    }
}

fn check_result(api: &AlsaApi, operation: &'static str, result: i32) -> AlsaResult<()> {
    if result < 0 {
        Err(native_error(api, operation, result))
    } else {
        Ok(())
    }
}

fn native_error(api: &AlsaApi, operation: &'static str, code: i32) -> AlsaError {
    AlsaError::Native {
        operation,
        code,
        detail: api.error_text(code),
    }
}

fn invalid_negotiated(field: &'static str) -> AlsaError {
    AlsaError::Native {
        operation: "read hardware parameters",
        code: 0,
        detail: format!("negotiated {field} is outside the supported range"),
    }
}
