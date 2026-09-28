use super::devices::*;
use super::ffi::*;
use super::*;
pub(super) struct CallbackSlot {
    sequence: AtomicUsize,
    data: Box<[UnsafeCell<u8>]>,
}

// SAFETY: slot ownership is guarded by the documented atomic sequence protocol.
unsafe impl Sync for CallbackSlot {}

pub(super) struct CallbackRing {
    slots: Box<[CallbackSlot]>,
    capacity: usize,
    block_bytes: usize,
    enqueue: AtomicUsize,
    dequeue: AtomicUsize,
}

impl CallbackRing {
    pub(super) fn new(capacity: usize, block_bytes: usize) -> PortAudioResult<Self> {
        if capacity == 0 || block_bytes == 0 {
            return Err(PortAudioError::InvalidConfig(
                "callback ring capacity and block size must be positive".into(),
            ));
        }
        let mut slots = Vec::with_capacity(capacity);
        for sequence in 0..capacity {
            let data = (0..block_bytes)
                .map(|_| UnsafeCell::new(0u8))
                .collect::<Vec<_>>()
                .into_boxed_slice();
            slots.push(CallbackSlot {
                sequence: AtomicUsize::new(sequence),
                data,
            });
        }
        Ok(Self {
            slots: slots.into_boxed_slice(),
            capacity,
            block_bytes,
            enqueue: AtomicUsize::new(0),
            dequeue: AtomicUsize::new(0),
        })
    }

    /// Returns whether an already complete oldest block was discarded. The
    /// producer may discard only a slot it claims first, so it never races a
    /// session read that has already claimed the same block.
    pub(super) fn push_from_ptr(&self, src: *const u8) -> bool {
        let (slot, position, discarded) = self.claim_producer_slot();
        // SAFETY: enqueue CAS grants exclusive ownership of this slot until
        // the release store in `publish_producer_slot` publishes it. The
        // surrounding PortAudio ownership and pointer checks establish the
        // source and destination operation preconditions.
        unsafe {
            std::ptr::copy_nonoverlapping(
                src,
                slot.data.as_ptr().cast::<u8>() as *mut u8,
                self.block_bytes,
            );
        }
        self.publish_producer_slot(slot, position);
        discarded
    }

    pub(super) fn push_selected_channels_from_ptr(
        &self,
        source: *const u8,
        frames: usize,
        source_bytes_per_frame: usize,
        channel_offset_bytes: usize,
    ) -> bool {
        debug_assert!(frames > 0);
        debug_assert_eq!(self.block_bytes % frames, 0);
        let (slot, position, discarded) = self.claim_producer_slot();
        // SAFETY: enqueue CAS grants exclusive ownership until publication.
        // The input and slot are valid for their respective complete callback
        // blocks under the surrounding PortAudio pointer checks.
        unsafe {
            let destination = slot.data.as_ptr().cast::<u8>() as *mut u8;
            let selected_bytes_per_frame = self.block_bytes / frames;
            for frame in 0..frames {
                std::ptr::copy_nonoverlapping(
                    source.add(frame * source_bytes_per_frame + channel_offset_bytes),
                    destination.add(frame * selected_bytes_per_frame),
                    selected_bytes_per_frame,
                );
            }
        }
        self.publish_producer_slot(slot, position);
        discarded
    }

    pub(super) fn pop_into_ptr(&self, destination: *mut u8) -> bool {
        let Some((slot, position)) = self.claim_consumer_slot() else {
            return false;
        };
        // SAFETY: dequeue CAS claims this published slot before its release to
        // a subsequent writer, so copying cannot overlap a mutation.
        // SAFETY: the surrounding PortAudio ownership and pointer checks establish the operation preconditions.
        unsafe {
            std::ptr::copy_nonoverlapping(
                slot.data.as_ptr().cast::<u8>(),
                destination,
                self.block_bytes,
            );
        }
        self.release_consumer_slot(slot, position);
        true
    }

    pub(super) fn pop_into(&self, block: &mut [u8]) -> PortAudioResult<bool> {
        if block.len() != self.block_bytes {
            return Err(PortAudioError::InvalidPayload {
                expected: self.block_bytes,
                actual: block.len(),
            });
        }
        Ok(self.pop_into_ptr(block.as_mut_ptr()))
    }

    pub(super) fn discard_oldest(&self) -> bool {
        let Some((slot, position)) = self.claim_consumer_slot() else {
            return false;
        };
        self.release_consumer_slot(slot, position);
        true
    }

    fn claim_producer_slot(&self) -> (&CallbackSlot, usize, bool) {
        let mut discarded = false;
        loop {
            let position = self.enqueue.load(Ordering::Relaxed);
            let slot = &self.slots[position % self.capacity];
            let sequence = slot.sequence.load(Ordering::Acquire);
            let difference = sequence as isize - position as isize;
            if difference == 0 {
                if self
                    .enqueue
                    .compare_exchange_weak(
                        position,
                        position.wrapping_add(1),
                        Ordering::Relaxed,
                        Ordering::Relaxed,
                    )
                    .is_ok()
                {
                    return (slot, position, discarded);
                }
            } else if difference < 0 {
                if self.discard_oldest() {
                    discarded = true;
                }
            } else {
                spin_loop();
            }
        }
    }

    fn publish_producer_slot(&self, slot: &CallbackSlot, position: usize) {
        slot.sequence
            .store(position.wrapping_add(1), Ordering::Release);
    }

    fn claim_consumer_slot(&self) -> Option<(&CallbackSlot, usize)> {
        let position = self.dequeue.load(Ordering::Relaxed);
        let slot = &self.slots[position % self.capacity];
        if slot.sequence.load(Ordering::Acquire) != position.wrapping_add(1) {
            return None;
        }
        self.dequeue
            .compare_exchange(
                position,
                position.wrapping_add(1),
                Ordering::Relaxed,
                Ordering::Relaxed,
            )
            .is_ok()
            .then_some((slot, position))
    }

    fn release_consumer_slot(&self, slot: &CallbackSlot, position: usize) {
        slot.sequence
            .store(position.wrapping_add(self.capacity), Ordering::Release);
    }

    pub(super) fn queued_blocks(&self) -> usize {
        self.enqueue
            .load(Ordering::Acquire)
            .saturating_sub(self.dequeue.load(Ordering::Acquire))
            .min(self.capacity)
    }
}

pub(super) struct CallbackState {
    pub(super) capture: CallbackRing,
    pub(super) playback: CallbackRing,
    callback_bytes: usize,
    callback_frames: PaFramesPerBuffer,
    bytes_per_frame: usize,
    input_bytes_per_frame: usize,
    input_channel_offset_bytes: usize,
    bits_per_sample: u16,
    capture_overflow_blocks: AtomicU64,
    playback_underflow_callbacks: AtomicU64,
    portaudio_input_overflow_callbacks: AtomicU64,
    portaudio_output_underflow_callbacks: AtomicU64,
    in_flight: AtomicUsize,
    closing: AtomicBool,
    local_audio_loop: bool,
}

impl CallbackState {
    pub(super) fn new(config: &PortAudioConfig) -> PortAudioResult<Arc<Self>> {
        let bytes_per_frame = config.channels as usize * (config.bits_per_sample as usize / 8);
        let callback_frames = config.native_frames_per_buffer();
        let callback_bytes = usize::try_from(callback_frames)
            .ok()
            .and_then(|frames| frames.checked_mul(bytes_per_frame))
            .ok_or_else(|| {
                PortAudioError::InvalidConfig(
                    "callback buffer size exceeds addressable memory".into(),
                )
            })?;
        let PortAudioTransferMode::Callback { ring_blocks } = &config.transfer_mode else {
            unreachable!("callback state is created only for callback mode");
        };
        Ok(Arc::new(Self {
            capture: CallbackRing::new(*ring_blocks, callback_bytes)?,
            playback: CallbackRing::new(*ring_blocks, callback_bytes)?,
            callback_bytes,
            callback_frames,
            bytes_per_frame,
            input_bytes_per_frame: usize::try_from(config.input_channels()?)
                .expect("PortAudio channel count is positive")
                * (config.bits_per_sample as usize / 8),
            input_channel_offset_bytes: config.input_channel_offset as usize
                * (config.bits_per_sample as usize / 8),
            bits_per_sample: config.bits_per_sample,
            capture_overflow_blocks: AtomicU64::new(0),
            playback_underflow_callbacks: AtomicU64::new(0),
            portaudio_input_overflow_callbacks: AtomicU64::new(0),
            portaudio_output_underflow_callbacks: AtomicU64::new(0),
            in_flight: AtomicUsize::new(0),
            closing: AtomicBool::new(false),
            local_audio_loop: config.local_audio_loop,
        }))
    }

    pub(super) fn quiesce(&self) {
        self.closing.store(true, Ordering::Release);
        while self.in_flight.load(Ordering::Acquire) != 0 {
            spin_loop();
        }
    }

    pub(super) fn stats(&self) -> PortAudioCallbackStats {
        PortAudioCallbackStats {
            capture_overflow_blocks: self.capture_overflow_blocks.load(Ordering::Relaxed),
            playback_underflow_callbacks: self.playback_underflow_callbacks.load(Ordering::Relaxed),
            portaudio_input_overflow_callbacks: self
                .portaudio_input_overflow_callbacks
                .load(Ordering::Relaxed),
            portaudio_output_underflow_callbacks: self
                .portaudio_output_underflow_callbacks
                .load(Ordering::Relaxed),
            capture_queued_blocks: self.capture.queued_blocks(),
            playback_queued_blocks: self.playback.queued_blocks(),
        }
    }
}

pub(super) fn copy_selected_channels(
    destination: &mut [u8],
    source: &[u8],
    source_bytes_per_frame: usize,
    channel_offset_bytes: usize,
) {
    let selected_bytes_per_frame = destination.len() / (source.len() / source_bytes_per_frame);
    for (source, destination) in source
        .chunks_exact(source_bytes_per_frame)
        .zip(destination.chunks_exact_mut(selected_bytes_per_frame))
    {
        destination.copy_from_slice(
            &source[channel_offset_bytes..channel_offset_bytes + selected_bytes_per_frame],
        );
    }
}

pub(super) fn mix_pcm_saturating(output: &mut [u8], input: &[u8], bits_per_sample: u16) {
    if output.len() != input.len() {
        return;
    }
    match bits_per_sample {
        8 => output.iter_mut().zip(input).for_each(|(dst, src)| {
            *dst = ((*dst as i8 as i16) + (*src as i8 as i16)).clamp(i8::MIN as i16, i8::MAX as i16)
                as i8 as u8;
        }),
        16 => output
            .as_chunks_mut::<2>()
            .0
            .iter_mut()
            .zip(input.as_chunks::<2>().0)
            .for_each(|(dst, src)| {
                let mixed = i32::from(i16::from_le_bytes([dst[0], dst[1]]))
                    + i32::from(i16::from_le_bytes([src[0], src[1]]));
                dst.copy_from_slice(
                    &(mixed.clamp(i16::MIN as i32, i16::MAX as i32) as i16).to_le_bytes(),
                );
            }),
        24 => output
            .as_chunks_mut::<3>()
            .0
            .iter_mut()
            .zip(input.as_chunks::<3>().0)
            .for_each(|(dst, src)| {
                let decode = |bytes: &[u8]| {
                    let value = i32::from(bytes[0])
                        | (i32::from(bytes[1]) << 8)
                        | (i32::from(bytes[2]) << 16);
                    if value & 0x0080_0000 != 0 {
                        value | !0x00ff_ffff
                    } else {
                        value
                    }
                };
                let mixed = (i64::from(decode(dst)) + i64::from(decode(src)))
                    .clamp(-8_388_608, 8_388_607) as i32;
                let encoded = mixed.to_le_bytes();
                dst.copy_from_slice(&encoded[..3]);
            }),
        32 => output
            .as_chunks_mut::<4>()
            .0
            .iter_mut()
            .zip(input.as_chunks::<4>().0)
            .for_each(|(dst, src)| {
                let mixed =
                    i64::from(i32::from_le_bytes(*dst)) + i64::from(i32::from_le_bytes(*src));
                dst.copy_from_slice(
                    &(mixed.clamp(i32::MIN as i64, i32::MAX as i64) as i32).to_le_bytes(),
                );
            }),
        _ => {}
    }
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct PortAudioCallbackStats {
    /// Application capture-ring blocks discarded because the consumer lagged.
    pub capture_overflow_blocks: u64,
    /// Application callbacks that had no queued remote playback block.
    pub playback_underflow_callbacks: u64,
    /// PortAudio callbacks marked with `paInputOverflow` by the host API.
    pub portaudio_input_overflow_callbacks: u64,
    /// PortAudio callbacks marked with `paOutputUnderflow` by the host API.
    pub portaudio_output_underflow_callbacks: u64,
    pub capture_queued_blocks: usize,
    pub playback_queued_blocks: usize,
}

pub(super) unsafe extern "C" fn portaudio_callback(
    input: *const std::ffi::c_void,
    output: *mut std::ffi::c_void,
    frames: PaFramesPerBuffer,
    _time_info: *const PaStreamCallbackTimeInfo,
    flags: PaStreamCallbackFlags,
    user_data: *mut std::ffi::c_void,
) -> i32 {
    // SAFETY: `user_data` comes from `Arc::as_ptr` and stays alive through
    // `Pa_StopStream` plus callback quiescence; PortAudio pointer checks hold.
    let state = unsafe { &*(user_data as *const CallbackState) };
    state.in_flight.fetch_add(1, Ordering::Acquire);
    note_host_callback_flags(state, flags);
    let output_bytes = usize::try_from(frames)
        .ok()
        .and_then(|count| count.checked_mul(state.bytes_per_frame));
    if state.closing.load(Ordering::Acquire) {
        // SAFETY: PortAudio owns this callback's output region.
        unsafe { clear_callback_output(output, output_bytes) };
        state.in_flight.fetch_sub(1, Ordering::Release);
        return PA_CONTINUE;
    }
    let Some(callback_bytes) = valid_callback_bytes(state, frames, output_bytes) else {
        // SAFETY: output, when non-null, has this callback's checked length.
        unsafe { clear_callback_output(output, output_bytes) };
        note_invalid_callback_block(state);
        state.in_flight.fetch_sub(1, Ordering::Release);
        return PA_CONTINUE;
    };
    debug_assert_eq!(callback_bytes, state.callback_bytes);
    if !input.is_null() {
        let dropped = state.capture.push_selected_channels_from_ptr(
            input.cast(),
            callback_bytes / state.bytes_per_frame,
            state.input_bytes_per_frame,
            state.input_channel_offset_bytes,
        );
        if dropped {
            state
                .capture_overflow_blocks
                .fetch_add(1, Ordering::Relaxed);
        }
    }
    let had_remote_playback = !output.is_null() && state.playback.pop_into_ptr(output.cast());
    if !had_remote_playback && !output.is_null() {
        // SAFETY: PortAudio owns the output region for this callback and the
        // callback frame count established its exact writable byte length.
        unsafe { std::ptr::write_bytes(output, 0, state.callback_bytes) };
    }
    let mixed_local = state.local_audio_loop && !input.is_null() && !output.is_null();
    if mixed_local {
        // SAFETY: PortAudio supplies disjoint input/output regions valid for
        // `callback_bytes` for output and input's wider device-frame layout
        // throughout this callback invocation.
        let (input, output) = unsafe {
            (
                std::slice::from_raw_parts(
                    input.cast::<u8>(),
                    callback_bytes / state.bytes_per_frame * state.input_bytes_per_frame,
                ),
                std::slice::from_raw_parts_mut(output.cast::<u8>(), state.callback_bytes),
            )
        };
        for (input, output) in input
            .chunks_exact(state.input_bytes_per_frame)
            .zip(output.chunks_exact_mut(state.bytes_per_frame))
        {
            mix_pcm_saturating(
                output,
                &input[state.input_channel_offset_bytes
                    ..state.input_channel_offset_bytes + state.bytes_per_frame],
                state.bits_per_sample,
            );
        }
    }
    if !had_remote_playback && !mixed_local {
        state
            .playback_underflow_callbacks
            .fetch_add(1, Ordering::Relaxed);
    }
    state.in_flight.fetch_sub(1, Ordering::Release);
    PA_CONTINUE
}

fn note_host_callback_flags(state: &CallbackState, flags: PaStreamCallbackFlags) {
    if flags & PA_INPUT_OVERFLOW != 0 {
        state
            .portaudio_input_overflow_callbacks
            .fetch_add(1, Ordering::Relaxed);
    }
    if flags & PA_OUTPUT_UNDERFLOW != 0 {
        state
            .portaudio_output_underflow_callbacks
            .fetch_add(1, Ordering::Relaxed);
    }
}

fn valid_callback_bytes(
    state: &CallbackState,
    frames: PaFramesPerBuffer,
    output_bytes: Option<usize>,
) -> Option<usize> {
    (frames == state.callback_frames)
        .then_some(output_bytes)
        .flatten()
}

fn note_invalid_callback_block(state: &CallbackState) {
    state
        .capture_overflow_blocks
        .fetch_add(1, Ordering::Relaxed);
    state
        .playback_underflow_callbacks
        .fetch_add(1, Ordering::Relaxed);
}

/// Zero the PortAudio callback output. SAFETY: pointer and length share one callback.
unsafe fn clear_callback_output(output: *mut std::ffi::c_void, bytes: Option<usize>) {
    if let (false, Some(bytes)) = (output.is_null(), bytes) {
        // SAFETY: upheld by this helper's caller contract.
        unsafe { std::ptr::write_bytes(output, 0, bytes) };
    }
}

pub(super) struct PaStreamHandle {
    pub(super) stream: *mut std::ffi::c_void,
    pub(super) started: bool,
    pub(super) callback: Option<Arc<CallbackState>>,
}

impl Drop for PaStreamHandle {
    fn drop(&mut self) {
        let _g = pa_lock();
        let stream = self.stream;
        let started = self.started;
        let _ = with_pa_fns_locked(|fns| {
            if started && !stream.is_null() {
                // SAFETY: the surrounding PortAudio ownership and pointer checks establish the operation preconditions.
                let _ = unsafe { (fns.stop_stream)(stream) };
            }
            if let Some(callback) = self.callback.as_ref() {
                callback.quiesce();
            }
            if !stream.is_null() {
                // SAFETY: the surrounding PortAudio ownership and pointer checks establish the operation preconditions.
                let _ = unsafe { (fns.close_stream)(stream) };
            }
        });
        self.stream = std::ptr::null_mut();
        self.started = false;
    }
}

impl PaStreamHandle {
    pub(super) fn stop_checked(&mut self) -> PortAudioResult<()> {
        if !self.started {
            return Ok(());
        }
        let _guard = pa_lock();
        let stream = self.stream;
        let result = with_pa_fns_locked(|fns| {
            // SAFETY: the surrounding PortAudio ownership and pointer checks establish the operation preconditions.
            let code = unsafe { (fns.stop_stream)(stream) };
            if code < PA_NO_ERROR {
                Err(PortAudioError::Native {
                    operation: "Pa_StopStream",
                    detail: error_text_fns(fns, code),
                })
            } else {
                Ok(())
            }
        })
        .map_err(|detail| PortAudioError::Native {
            operation: "Pa_StopStream",
            detail,
        })?;
        result?;
        if let Some(callback) = self.callback.as_ref() {
            callback.quiesce();
        }
        self.started = false;
        Ok(())
    }

    pub(super) fn close_checked(&mut self) -> PortAudioResult<()> {
        if self.stream.is_null() {
            return Ok(());
        }
        let _guard = pa_lock();
        let stream = self.stream;
        let result = with_pa_fns_locked(|fns| {
            // SAFETY: the surrounding PortAudio ownership and pointer checks establish the operation preconditions.
            let code = unsafe { (fns.close_stream)(stream) };
            if code < PA_NO_ERROR {
                Err(PortAudioError::Native {
                    operation: "Pa_CloseStream",
                    detail: error_text_fns(fns, code),
                })
            } else {
                Ok(())
            }
        })
        .map_err(|detail| PortAudioError::Native {
            operation: "Pa_CloseStream",
            detail,
        })?;
        result?;
        self.stream = std::ptr::null_mut();
        self.started = false;
        Ok(())
    }
}
