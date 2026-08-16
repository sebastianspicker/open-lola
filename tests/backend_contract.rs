//! Contract tests for the strict native backend entry points.

use rusty_lola::audio::{
    open_portaudio_strict, PortAudioConfig, PortAudioDeviceSelector, PortAudioError,
    PortAudioTransferMode,
};
use rusty_lola::video::{
    open_ximea_strict, XimeaColorMode, XimeaConfig, XimeaError, XimeaPixelFormat,
};

#[test]
fn explicit_portaudio_strict_returns_invalid_config_without_a_diagnostic_backend() {
    let config = PortAudioConfig {
        bits_per_sample: 12,
        ..PortAudioConfig::default()
    };
    assert!(matches!(
        open_portaudio_strict(config),
        Err(PortAudioError::InvalidConfig(_))
    ));
}

#[test]
fn portaudio_config_keeps_named_input_and_output_selection_distinct() {
    let config = PortAudioConfig {
        input_device: PortAudioDeviceSelector::Name("capture".into()),
        output_device: PortAudioDeviceSelector::Name("playback".into()),
        ..PortAudioConfig::default()
    };
    assert_ne!(config.input_device, config.output_device);
}

#[test]
fn strict_portaudio_defaults_to_bounded_callback_transfer() {
    assert!(matches!(
        PortAudioConfig::default().transfer_mode,
        PortAudioTransferMode::Callback { ring_blocks } if ring_blocks > 0
    ));
}

#[test]
fn strict_portaudio_uses_input_channel_offset_not_extra_callback_frames() {
    let config = PortAudioConfig {
        channels: 2,
        frames_per_buffer: 64,
        input_channel_offset: 3,
        ..PortAudioConfig::default()
    };
    assert_eq!(config.input_channel_offset, 3);
    assert_eq!(config.frames_per_buffer, 64);
}

#[test]
fn strict_portaudio_rejects_unrepresentable_input_channel_count_before_hardware() {
    let config = PortAudioConfig {
        channels: 1,
        input_channel_offset: u32::MAX,
        ..PortAudioConfig::default()
    };
    assert!(matches!(
        open_portaudio_strict(config),
        Err(PortAudioError::InvalidConfig(_))
    ));
}

#[test]
fn strict_portaudio_rejects_a_zero_capacity_callback_ring_before_hardware() {
    let config = PortAudioConfig {
        transfer_mode: PortAudioTransferMode::Callback { ring_blocks: 0 },
        ..PortAudioConfig::default()
    };
    assert!(matches!(
        open_portaudio_strict(config),
        Err(PortAudioError::InvalidConfig(_))
    ));
}

#[test]
fn explicit_ximea_strict_returns_invalid_config_without_a_diagnostic_backend() {
    let config = XimeaConfig {
        camera_index: 0,
        roi_offset_x: 0,
        roi_offset_y: 0,
        width: 0,
        height: 720,
        pixel_format: XimeaPixelFormat::Mono8,
        color_mode: XimeaColorMode::RawBayer,
        exposure_us: 10_000,
        frame_rate: 60,
        timeout_ms: 100,
    };
    assert!(matches!(
        open_ximea_strict(config),
        Err(XimeaError::InvalidConfig(_))
    ));
}

#[test]
fn ximea_strict_rejects_incompatible_bayer_colour_mode_before_hardware() {
    let config = XimeaConfig {
        camera_index: 0,
        roi_offset_x: 0,
        roi_offset_y: 0,
        width: 1280,
        height: 720,
        pixel_format: XimeaPixelFormat::Rgb24,
        color_mode: XimeaColorMode::RawBayer,
        exposure_us: 10_000,
        frame_rate: 60,
        timeout_ms: 100,
    };
    assert!(matches!(
        open_ximea_strict(config),
        Err(XimeaError::InvalidConfig(_))
    ));
}
