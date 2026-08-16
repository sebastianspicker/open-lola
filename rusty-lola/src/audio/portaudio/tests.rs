use super::*;
#[cfg(test)]
mod portaudio_tests {
    use crate::audio::SoftwareAudio;

    use super::super::callback::{
        copy_selected_channels, mix_pcm_saturating, portaudio_callback, CallbackRing, CallbackState,
    };
    use super::super::ffi::{
        PaFramesPerBuffer, PaSampleFormat, PaStreamCallback, PaStreamCallbackFlags, PaStreamFlags,
        PA_CONTINUE, PA_INPUT_OVERFLOW, PA_OUTPUT_UNDERFLOW,
    };
    use super::*;
    use std::ffi::c_ulong;

    #[test]
    pub(super) fn callback_abi_uses_c_unsigned_long_scalars() {
        assert_eq!(
            std::mem::size_of::<PaFramesPerBuffer>(),
            std::mem::size_of::<c_ulong>()
        );
        assert_eq!(
            std::mem::size_of::<PaSampleFormat>(),
            std::mem::size_of::<c_ulong>()
        );
        assert_eq!(
            std::mem::size_of::<PaStreamFlags>(),
            std::mem::size_of::<c_ulong>()
        );
        assert_eq!(
            std::mem::size_of::<PaStreamCallbackFlags>(),
            std::mem::size_of::<c_ulong>()
        );
        let _: PaStreamCallback = portaudio_callback;
    }

    #[test]
    pub(super) fn diagnostic_software_audio_works_without_portaudio_selection() {
        let mut a = SoftwareAudio::default();
        a.open(48000, 2, 16, 64);
        a.start();
        let pcm = a.read_pcm();
        assert!(!pcm.is_empty());
    }

    #[test]
    pub(super) fn probe_loads_and_initializes_via_ffi() {
        let p = probe_portaudio();
        if p.available {
            assert!(p.loaded);
            assert!(p.initialized);
            // load_portaudio returns singleton handle — no second LoadLibrary unload
            let mut lib = load_portaudio(p.library_path.as_deref()).expect("singleton");
            lib.initialize().expect("Pa_Initialize");
            let n = lib.device_count().expect("device count");
            assert!(n >= 0);
        } else {
            assert!(!p.reason.is_empty());
        }
    }

    #[test]
    pub(super) fn parallel_safe_probe_and_diagnostic_software() {
        // Stress the lock from this thread (full parallel is cargo harness)
        for _ in 0..8 {
            let _ = probe_portaudio();
            let mut a = SoftwareAudio::default();
            a.open(48000, 2, 16, 64);
            a.start();
            assert!(!a.read_pcm().is_empty());
        }
    }

    #[test]
    pub(super) fn callback_capture_ring_drops_the_oldest_complete_block() {
        let ring = CallbackRing::new(2, 2).unwrap();
        assert!(!ring.push_from_ptr([1, 1].as_ptr()));
        assert!(!ring.push_from_ptr([2, 2].as_ptr()));
        assert!(ring.push_from_ptr([3, 3].as_ptr()));
        assert_eq!(ring.pop_vec(), Some(vec![2, 2]));
        assert_eq!(ring.pop_vec(), Some(vec![3, 3]));
        assert_eq!(ring.pop_vec(), None);
    }

    #[test]
    pub(super) fn callback_extracts_offset_channels_into_capture_ring() {
        let config = PortAudioConfig {
            channels: 1,
            bits_per_sample: 16,
            frames_per_buffer: 2,
            input_channel_offset: 1,
            transfer_mode: PortAudioTransferMode::Callback { ring_blocks: 2 },
            ..PortAudioConfig::default()
        };
        let state = CallbackState::new(&config).unwrap();
        let input = [9u8, 8, 1, 2, 7, 6, 3, 4];
        let mut output = [0xFFu8; 4];
        // SAFETY: the surrounding PortAudio ownership and pointer checks establish the operation preconditions.
        let result = unsafe {
            portaudio_callback(
                input.as_ptr().cast(),
                output.as_mut_ptr().cast(),
                PaFramesPerBuffer::from(2u32),
                std::ptr::null(),
                0,
                Arc::as_ptr(&state) as *mut std::ffi::c_void,
            )
        };
        assert_eq!(result, PA_CONTINUE);
        assert_eq!(state.capture.pop_vec(), Some(vec![1, 2, 3, 4]));
        assert_eq!(output, [0; 4]);
        assert_eq!(state.stats().playback_underflow_callbacks, 1);
    }

    #[test]
    pub(super) fn callback_tracks_portaudio_status_flags_separately_from_ring_counters() {
        let config = PortAudioConfig {
            channels: 1,
            bits_per_sample: 16,
            frames_per_buffer: 1,
            transfer_mode: PortAudioTransferMode::Callback { ring_blocks: 2 },
            ..PortAudioConfig::default()
        };
        let state = CallbackState::new(&config).unwrap();
        let input = [1u8, 2];
        let mut output = [0u8; 2];
        // SAFETY: test buffers match the one-frame callback configuration and
        // the callback state remains alive for the complete invocation.
        unsafe {
            portaudio_callback(
                input.as_ptr().cast(),
                output.as_mut_ptr().cast(),
                PaFramesPerBuffer::from(1u32),
                std::ptr::null(),
                PA_INPUT_OVERFLOW | PA_OUTPUT_UNDERFLOW,
                Arc::as_ptr(&state) as *mut std::ffi::c_void,
            );
        }
        let stats = state.stats();
        assert_eq!(stats.portaudio_input_overflow_callbacks, 1);
        assert_eq!(stats.portaudio_output_underflow_callbacks, 1);
        assert_eq!(stats.capture_overflow_blocks, 0);
        assert_eq!(stats.playback_underflow_callbacks, 1);
    }

    #[test]
    pub(super) fn blocking_capture_extraction_keeps_only_selected_channels() {
        let source = [9u8, 8, 1, 2, 7, 6, 3, 4];
        let mut selected = [0u8; 4];
        copy_selected_channels(&mut selected, &source, 4, 2);
        assert_eq!(selected, [1, 2, 3, 4]);
    }

    #[test]
    pub(super) fn callback_playback_queue_uses_selected_channel_blocks() {
        let config = PortAudioConfig {
            channels: 1,
            bits_per_sample: 16,
            frames_per_buffer: 2,
            input_channel_offset: 1,
            transfer_mode: PortAudioTransferMode::Callback { ring_blocks: 2 },
            ..PortAudioConfig::default()
        };
        let state = CallbackState::new(&config).unwrap();
        assert!(!state.playback.push_from_ptr([1, 2, 3, 4].as_ptr()));
        assert_eq!(state.playback.pop_vec(), Some(vec![1, 2, 3, 4]));
    }

    #[test]
    pub(super) fn callback_local_loop_mixes_with_remote_playback_saturating() {
        let config = PortAudioConfig {
            channels: 1,
            bits_per_sample: 16,
            frames_per_buffer: 1,
            input_channel_offset: 1,
            local_audio_loop: true,
            transfer_mode: PortAudioTransferMode::Callback { ring_blocks: 2 },
            ..PortAudioConfig::default()
        };
        let state = CallbackState::new(&config).unwrap();
        assert!(!state
            .playback
            .push_from_ptr(10_000i16.to_le_bytes().as_ptr()));
        let input = [0u8, 0, 0x30, 0x75];
        let mut output = [0u8; 2];
        // SAFETY: test buffers match the one-frame callback configuration and
        // the callback state remains alive for the complete invocation.
        unsafe {
            portaudio_callback(
                input.as_ptr().cast(),
                output.as_mut_ptr().cast(),
                PaFramesPerBuffer::from(1u32),
                std::ptr::null(),
                0,
                Arc::as_ptr(&state) as *mut std::ffi::c_void,
            );
        }
        assert_eq!(i16::from_le_bytes(output), i16::MAX);
        assert_eq!(state.stats().playback_underflow_callbacks, 0);
    }

    #[test]
    pub(super) fn local_loop_mixes_all_supported_pcm_widths_saturating() {
        let cases = [
            (8, vec![100], vec![100], vec![127]),
            (
                16,
                30_000i16.to_le_bytes().to_vec(),
                10_000i16.to_le_bytes().to_vec(),
                i16::MAX.to_le_bytes().to_vec(),
            ),
            (
                24,
                vec![0xff, 0xff, 0x7f],
                vec![1, 0, 0],
                vec![0xff, 0xff, 0x7f],
            ),
            (
                32,
                i32::MAX.to_le_bytes().to_vec(),
                1i32.to_le_bytes().to_vec(),
                i32::MAX.to_le_bytes().to_vec(),
            ),
        ];
        for (bits, input, mut output, expected) in cases.iter().cloned() {
            mix_pcm_saturating(&mut output, &input, bits);
            assert_eq!(output, expected, "{bits}-bit mix");
        }
    }

    #[test]
    pub(super) fn quiesced_callback_zeros_output_without_queuing_capture() {
        let config = PortAudioConfig {
            channels: 1,
            bits_per_sample: 16,
            frames_per_buffer: 1,
            transfer_mode: PortAudioTransferMode::Callback { ring_blocks: 1 },
            ..PortAudioConfig::default()
        };
        let state = CallbackState::new(&config).unwrap();
        state.quiesce();
        let input = [1u8, 2];
        let mut output = [0xffu8; 2];
        // SAFETY: test buffers match the callback configuration and state is alive.
        unsafe {
            portaudio_callback(
                input.as_ptr().cast(),
                output.as_mut_ptr().cast(),
                PaFramesPerBuffer::from(1u32),
                std::ptr::null(),
                0,
                Arc::as_ptr(&state) as *mut std::ffi::c_void,
            );
        }
        assert_eq!(output, [0; 2]);
        assert_eq!(state.capture.pop_vec(), None);
    }
}
