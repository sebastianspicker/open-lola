//! XIMEA configuration logic that needs neither the xiAPI library nor a camera.
use super::types::*;
use crate::config::CameraMode;

fn mode(pixel_format: &str) -> CameraMode {
    CameraMode {
        mode_id: "001".into(),
        vendor: "XIMEA".into(),
        model: "MQ013".into(),
        width: 1280,
        height: 720,
        pixel_format: pixel_format.into(),
        max_fps: 60,
        raw_line: String::new(),
    }
}

#[test]
fn pixel_formats_parse_case_insensitively_and_carry_their_xiapi_values() {
    for (text, format, code, bytes, name) in [
        ("Mono8", XimeaPixelFormat::Mono8, XI_MONO8, 1, "Mono8"),
        ("mono8", XimeaPixelFormat::Mono8, XI_MONO8, 1, "Mono8"),
        ("RGB24", XimeaPixelFormat::Rgb24, XI_RGB24, 3, "RGB24"),
        ("rgb", XimeaPixelFormat::Rgb24, XI_RGB24, 3, "RGB24"),
    ] {
        let parsed = XimeaPixelFormat::from_mode(text).unwrap();
        assert_eq!(parsed, format, "{text}");
        assert_eq!(
            (parsed.xiapi_code(), parsed.bytes_per_pixel(), parsed.name()),
            (code, bytes, name),
            "{text}"
        );
    }
    let error = XimeaPixelFormat::from_mode("YUV422")
        .unwrap_err()
        .to_string();
    assert_eq!(
        error,
        "invalid XIMEA configuration: unsupported pixel format `YUV422`; expected Mono8 or RGB24"
    );
}

#[test]
fn a_camera_mode_selects_the_matching_colour_output() {
    for (format, color_mode, pixel_format) in [
        ("Mono8", XimeaColorMode::RawBayer, XimeaPixelFormat::Mono8),
        ("RGB24", XimeaColorMode::Rgb24, XimeaPixelFormat::Rgb24),
    ] {
        let config = XimeaConfig::from_mode(2, &mode(format));
        assert_eq!(config.camera_index, 2);
        assert_eq!((config.width, config.height), (1280, 720));
        assert_eq!(
            (config.color_mode, config.pixel_format),
            (color_mode, pixel_format)
        );
        assert_eq!((config.roi_offset_x, config.roi_offset_y), (0, 0));
        assert_eq!(config.frame_rate, 60);
        assert_eq!(config.pixel_format_code(), pixel_format.xiapi_code());
        config.validate().unwrap();
    }
}

#[test]
fn invalid_configurations_are_refused_with_the_reason() {
    type Break = fn(&mut XimeaConfig);
    let positive = "width, height, exposure_us, frame_rate, and timeout_ms must be positive";
    let cases: [(Break, &str); 10] = [
        (|c| c.width = 0, positive),
        (|c| c.height = 0, positive),
        (|c| c.exposure_us = 0, positive),
        (|c| c.frame_rate = 0, positive),
        (|c| c.timeout_ms = 0, positive),
        (
            |c| c.pixel_format = XimeaPixelFormat::Rgb24,
            "RawBayer colour mode requires Mono8",
        ),
        (
            |c| {
                c.color_mode = XimeaColorMode::Rgb24;
            },
            "Rgb24 colour mode requires RGB24",
        ),
        (
            |c| c.width = i32::MAX as u32 + 1,
            "width exceeds xiAPI's signed integer range",
        ),
        (|c| c.roi_offset_x = u32::MAX, "roi_offset_x exceeds"),
        (|c| c.frame_rate = u32::MAX, "frame_rate exceeds"),
    ];
    for (index, (spoil, reason)) in cases.into_iter().enumerate() {
        let mut config = XimeaConfig::from_mode(0, &mode("Mono8"));
        spoil(&mut config);
        let error = config.validate().unwrap_err().to_string();
        assert!(error.contains(reason), "case {index}: {error}");
    }
}

#[test]
fn error_messages_name_the_failed_operation() {
    let native = XimeaError::Native {
        operation: "xiOpenDevice",
        detail: "no camera".into(),
    };
    assert_eq!(native.to_string(), "XIMEA xiOpenDevice failed: no camera");
    assert_eq!(
        XimeaError::NotStarted.to_string(),
        "XIMEA acquisition is not started"
    );
}
