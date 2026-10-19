use super::devices::*;
use super::ffi::PA_ASIO;

fn device(index: i32, name: &str, host: (&str, i32), channels: (i32, i32)) -> PortAudioDeviceInfo {
    PortAudioDeviceInfo {
        index,
        name: name.into(),
        max_input_channels: channels.0,
        max_output_channels: channels.1,
        default_sample_rate: 48_000.0,
        host_api: 0,
        host_api_type: host.1,
        host_api_name: host.0.into(),
    }
}

fn mixed_devices() -> Vec<PortAudioDeviceInfo> {
    vec![
        device(0, "Microphone", ("MME", 2), (2, 0)),
        device(1, "Speakers", ("MME", 2), (0, 2)),
        device(2, "Focusrite USB ASIO", ("ASIO", PA_ASIO), (8, 8)),
        device(3, "Other ASIO", ("ASIO", PA_ASIO), (2, 2)),
    ]
}

#[test]
fn asio_host_default_wins_over_the_global_default() {
    let devices = mixed_devices();
    assert_eq!(resolve_asio_default(&devices, Some(3), true), Ok(3));
    assert_eq!(resolve_asio_default(&devices, Some(3), false), Ok(3));
}

#[test]
fn unusable_asio_default_falls_back_to_the_first_asio_device() {
    let devices = mixed_devices();
    // A non-ASIO or missing host default must never be returned.
    assert_eq!(resolve_asio_default(&devices, Some(0), true), Ok(2));
    assert_eq!(resolve_asio_default(&devices, Some(-1), false), Ok(2));
    assert_eq!(resolve_asio_default(&devices, None, true), Ok(2));
}

#[test]
fn missing_asio_is_an_actionable_error() {
    let devices: Vec<_> = mixed_devices().into_iter().take(2).collect();
    let error = resolve_asio_default(&devices, None, true).unwrap_err();
    assert!(error.contains("no ASIO host API"), "{error}");
    assert!(error.contains("Install an ASIO driver"), "{error}");
    assert!(error.contains("--input-device"), "{error}");
    assert!(error.contains("rusty-lola devices"), "{error}");
    let output_only = vec![device(0, "Out", ("ASIO", PA_ASIO), (0, 2))];
    let error = resolve_asio_default(&output_only, Some(0), true).unwrap_err();
    assert!(
        error.contains("ASIO host API has no input device"),
        "{error}"
    );
}

#[test]
fn device_listing_names_host_api_channels_rate_and_marks_asio() {
    let devices = mixed_devices();
    assert_eq!(
        devices[0].summary(),
        "[0] Microphone | host API MME | in 2 / out 0 ch | 48000 Hz"
    );
    assert_eq!(
        devices[2].summary(),
        "[2] Focusrite USB ASIO | host API ASIO (ASIO) | in 8 / out 8 ch | 48000 Hz"
    );
    let json = devices[2].to_json();
    assert_eq!(json["asio"], true);
    assert_eq!(json["host_api"], "ASIO");
    assert_eq!(json["index"], 2);
    assert_eq!(json["name"], "Focusrite USB ASIO");
    assert_eq!(devices[0].to_json()["asio"], false);
}

#[test]
fn settings_select_named_devices_and_blank_names_select_the_default() {
    let settings = crate::config::AudioSettings {
        input_device: "  Focusrite USB ASIO ".into(),
        output_device: "   ".into(),
        sample_rate: 48_000,
        channels: 1,
        buffer_samples: 128,
        input_offset: 2,
        ..Default::default()
    };
    let config = PortAudioConfig::from_settings(&settings);
    assert_eq!(
        config.input_device,
        PortAudioDeviceSelector::Name("Focusrite USB ASIO".into())
    );
    assert_eq!(config.output_device, PortAudioDeviceSelector::Default);
    assert_eq!(
        (
            config.sample_rate,
            config.channels,
            config.frames_per_buffer
        ),
        (48_000, 1, 128)
    );
    assert_eq!(config.input_channels().unwrap(), 3);
    config.validate().unwrap();
}

#[test]
fn strict_configuration_refuses_what_portaudio_cannot_open() {
    type Break = fn(&mut PortAudioConfig);
    let cases: [(Break, &str); 6] = [
        (|c| c.bits_per_sample = 12, "unsupported bits_per_sample 12"),
        (|c| c.sample_rate = 0, "must be positive"),
        (|c| c.channels = 0, "must be positive"),
        (|c| c.frames_per_buffer = 0, "must be positive"),
        (
            |c| c.transfer_mode = PortAudioTransferMode::Callback { ring_blocks: 0 },
            "ring_blocks must be positive",
        ),
        (
            |c| c.input_channel_offset = u32::MAX,
            "exceeds PortAudio limits",
        ),
    ];
    for (spoil, reason) in cases {
        let mut config = PortAudioConfig::default();
        spoil(&mut config);
        let error = config.validate().unwrap_err().to_string();
        assert!(error.contains(reason), "{reason}: {error}");
    }
    for bits_per_sample in [8, 16, 24, 32] {
        let config = PortAudioConfig {
            bits_per_sample,
            ..PortAudioConfig::default()
        };
        config.validate().unwrap();
    }
}
