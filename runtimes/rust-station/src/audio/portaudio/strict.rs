use super::asio::require_asio_device_locked;
use super::callback::*;
use super::devices::*;
use super::ffi::*;
use super::*;
use std::time::{Duration, Instant};
/// Strict native duplex stream. It never invokes `SoftwareAudio`; every native
/// lifecycle and I/O failure is returned to the caller.
pub struct StrictPortAudio {
    stream: PaStreamHandle,
    config: PortAudioConfig,
}

impl StrictPortAudio {
    pub fn open(config: PortAudioConfig) -> PortAudioResult<Self> {
        config.validate()?;
        let callback = match &config.transfer_mode {
            PortAudioTransferMode::Blocking => None,
            PortAudioTransferMode::Callback { .. } => Some(CallbackState::new(&config)?),
        };
        let _guard = pa_lock();
        ensure_pa_ready_locked().map_err(|detail| PortAudioError::Native {
            operation: "Pa_Initialize",
            detail,
        })?;
        let stream = with_pa_fns_locked(|fns| open_duplex_stream_locked(fns, &config, callback))
            .map_err(|detail| PortAudioError::Native {
            operation: "Pa_OpenStream",
            detail,
        })??;
        Ok(Self { stream, config })
    }

    pub fn config(&self) -> &PortAudioConfig {
        &self.config
    }

    pub fn callback_stats(&self) -> Option<PortAudioCallbackStats> {
        self.stream.callback.as_ref().map(|state| state.stats())
    }

    pub fn start(&mut self) -> PortAudioResult<()> {
        if self.stream.started {
            return Ok(());
        }
        let _guard = pa_lock();
        let stream = self.stream.stream;
        let result = with_pa_fns_locked(|fns| {
            // SAFETY: the surrounding PortAudio ownership and pointer checks establish the operation preconditions.
            let code = unsafe { (fns.start_stream)(stream) };
            if code < PA_NO_ERROR {
                Err(PortAudioError::Native {
                    operation: "Pa_StartStream",
                    detail: error_text_fns(fns, code),
                })
            } else {
                Ok(())
            }
        })
        .map_err(|detail| PortAudioError::Native {
            operation: "Pa_StartStream",
            detail,
        })?;
        if let Err(error) = result {
            // Pa_StartStream can fail after Pa_OpenStream has allocated native
            // resources. Release the callback lock before rolling that stream
            // back through the same RAII close path.
            drop(_guard);
            let _ = self.stream.close_checked();
            return Err(error);
        }
        self.stream.started = true;
        Ok(())
    }

    pub fn read_pcm(&mut self) -> PortAudioResult<Vec<u8>> {
        if !self.stream.started {
            return Err(PortAudioError::NotStarted);
        }
        if let Some(callback) = self.stream.callback.as_ref() {
            let captured = callback
                .capture
                .pop_vec()
                .ok_or(PortAudioError::CaptureUnavailable)?;
            debug_assert_eq!(captured.len(), self.expected_pcm_bytes());
            return Ok(captured);
        }
        let input_bytes_per_frame = usize::try_from(self.config.input_channels()?)
            .expect("PortAudio channel count is positive")
            * (self.config.bits_per_sample as usize / 8);
        let read_frames = self.config.native_frames_per_buffer();
        let captured_bytes = usize::try_from(read_frames)
            .ok()
            .and_then(|frames| frames.checked_mul(input_bytes_per_frame))
            .ok_or_else(|| {
                PortAudioError::InvalidConfig(
                    "capture buffer size exceeds addressable memory".into(),
                )
            })?;
        let mut captured = vec![0; captured_bytes];
        let _guard = pa_lock();
        let stream = self.stream.stream;
        let result = with_pa_fns_locked(|fns| {
            let code =
    // SAFETY: the surrounding PortAudio ownership and pointer checks establish the operation preconditions.
                unsafe { (fns.read_stream)(stream, captured.as_mut_ptr().cast(), read_frames) };
            if code < PA_NO_ERROR {
                Err(PortAudioError::Native {
                    operation: "Pa_ReadStream",
                    detail: error_text_fns(fns, code),
                })
            } else {
                Ok(())
            }
        })
        .map_err(|detail| PortAudioError::Native {
            operation: "Pa_ReadStream",
            detail,
        })?;
        result?;
        let offset =
            self.config.input_channel_offset as usize * (self.config.bits_per_sample as usize / 8);
        let mut pcm = vec![0; self.expected_pcm_bytes()];
        copy_selected_channels(&mut pcm, &captured, input_bytes_per_frame, offset);
        drop(_guard);
        if self.config.local_audio_loop {
            self.write_pcm(&pcm)?;
        }
        Ok(pcm)
    }

    /// Waits for one complete callback capture block until `timeout` expires.
    /// Blocking-mode streams keep PortAudio's native blocking semantics.
    pub fn read_pcm_timeout(&mut self, timeout: Duration) -> PortAudioResult<Vec<u8>> {
        if self.stream.callback.is_none() {
            return self.read_pcm();
        }
        let deadline = Instant::now() + timeout;
        loop {
            match self.read_pcm() {
                Err(PortAudioError::CaptureUnavailable) if Instant::now() < deadline => {
                    std::thread::yield_now();
                }
                result => return result,
            }
        }
    }

    pub fn write_pcm(&mut self, pcm: &[u8]) -> PortAudioResult<()> {
        if !self.stream.started {
            return Err(PortAudioError::NotStarted);
        }
        let expected = self.config.frames_per_buffer as usize * self.bytes_per_frame();
        if pcm.len() != expected {
            return Err(PortAudioError::InvalidPayload {
                expected,
                actual: pcm.len(),
            });
        }
        if let Some(callback) = self.stream.callback.as_ref() {
            if callback.playback.push_from_ptr(pcm.as_ptr()) {
                return Err(PortAudioError::PlaybackQueueFull);
            }
            return Ok(());
        }
        let _guard = pa_lock();
        let stream = self.stream.stream;
        let frames = self.config.native_frames_per_buffer();
        with_pa_fns_locked(|fns| {
            // SAFETY: the surrounding PortAudio ownership and pointer checks establish the operation preconditions.
            let code = unsafe { (fns.write_stream)(stream, pcm.as_ptr().cast(), frames) };
            if code < PA_NO_ERROR {
                Err(PortAudioError::Native {
                    operation: "Pa_WriteStream",
                    detail: error_text_fns(fns, code),
                })
            } else {
                Ok(())
            }
        })
        .map_err(|detail| PortAudioError::Native {
            operation: "Pa_WriteStream",
            detail,
        })?
    }

    pub fn stop(&mut self) -> PortAudioResult<()> {
        self.stream.stop_checked()
    }

    pub fn close(mut self) -> PortAudioResult<()> {
        let stop_result = self.stream.stop_checked();
        let close_result = self.stream.close_checked();
        stop_result.and(close_result)
    }

    pub(super) fn bytes_per_frame(&self) -> usize {
        self.config.channels as usize * (self.config.bits_per_sample as usize / 8)
    }

    pub(super) fn expected_pcm_bytes(&self) -> usize {
        self.config.frames_per_buffer as usize * self.bytes_per_frame()
    }
}

/// Open the strict native path. This is the session-integration entry point.
pub fn open_portaudio_strict(config: PortAudioConfig) -> PortAudioResult<StrictPortAudio> {
    StrictPortAudio::open(config)
}

pub(super) fn open_duplex_stream_locked(
    fns: &PaFns,
    config: &PortAudioConfig,
    callback: Option<Arc<CallbackState>>,
) -> PortAudioResult<PaStreamHandle> {
    let input_device = select_device_locked(fns, &config.input_device, true)?;
    let output_device = select_device_locked(fns, &config.output_device, false)?;
    require_asio_device_locked(fns, input_device, "input")?;
    require_asio_device_locked(fns, output_device, "output")?;
    let sample_format = config.sample_format()?;
    let channels = i32::from(config.channels);
    let input = PaStreamParameters {
        device: input_device,
        channel_count: config.input_channels()?,
        sample_format,
        suggested_latency: 0.01,
        host_api_specific_stream_info: std::ptr::null_mut(),
    };
    let output = PaStreamParameters {
        device: output_device,
        channel_count: channels,
        sample_format,
        suggested_latency: 0.01,
        host_api_specific_stream_info: std::ptr::null_mut(),
    };
    let callback_function = if callback.is_some() {
        let callback: PaStreamCallback = portaudio_callback;
        callback as *const () as *mut std::ffi::c_void
    } else {
        std::ptr::null_mut()
    };
    let user_data = callback.as_ref().map_or(std::ptr::null_mut(), |state| {
        Arc::as_ptr(state) as *mut std::ffi::c_void
    });
    let frames_per_buffer = config.native_frames_per_buffer();
    let mut stream = std::ptr::null_mut();
    // SAFETY: the surrounding PortAudio ownership and pointer checks establish the operation preconditions.
    let code = unsafe {
        (fns.open_stream)(
            &mut stream,
            &input,
            &output,
            f64::from(config.sample_rate),
            frames_per_buffer,
            PA_NO_FLAG,
            callback_function,
            user_data,
        )
    };
    if code < PA_NO_ERROR || stream.is_null() {
        return Err(PortAudioError::Native {
            operation: "Pa_OpenStream",
            detail: error_text_fns(fns, code),
        });
    }
    Ok(PaStreamHandle {
        stream,
        started: false,
        callback,
    })
}
