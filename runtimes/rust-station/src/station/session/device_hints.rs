//! Actionable device/format hints appended to V4L2 and ALSA open failures.

use crate::audio::alsa::{AlsaConfig, AlsaDeviceInfo, AlsaError};
use crate::video::v4l2::{
    V4l2Camera, V4l2Config, V4l2DeviceInfo, V4l2Error, V4l2FrameInterval, V4l2FrameSize,
};

const MAX_MODES_PER_FORMAT: usize = 8;

fn format_size(size: &V4l2FrameSize) -> String {
    match size {
        V4l2FrameSize::Discrete { width, height } => format!("{width}x{height}"),
        V4l2FrameSize::Range {
            min_width,
            max_width,
            min_height,
            max_height,
            ..
        } => format!("{min_width}x{min_height}..{max_width}x{max_height}"),
    }
}

fn format_fps(interval: &V4l2FrameInterval) -> String {
    match interval {
        V4l2FrameInterval::Discrete {
            numerator,
            denominator,
        } if *numerator > 0 => {
            let fps = f64::from(*denominator) / f64::from(*numerator);
            if (fps - fps.round()).abs() < 0.005 {
                format!("{fps:.0}")
            } else {
                format!("{fps:.2}")
            }
        }
        V4l2FrameInterval::Discrete { .. } => "?".into(),
        V4l2FrameInterval::Range { .. } => "range".into(),
    }
}

/// What the device offers, e.g. `GREY 1280x720 @ 60 fps; YUYV 640x480 @ 30/15 fps`.
pub(super) fn v4l2_offered_formats(device: &V4l2DeviceInfo) -> String {
    let mut entries = Vec::new();
    for format in &device.formats {
        for mode in format.modes.iter().take(MAX_MODES_PER_FORMAT) {
            let fps: Vec<String> = mode.intervals.iter().map(format_fps).collect();
            let fps = if fps.is_empty() {
                "unknown".to_string()
            } else {
                fps.join("/")
            };
            entries.push(format!(
                "{} {} @ {fps} fps",
                format.pixel_format,
                format_size(&mode.size)
            ));
        }
    }
    if entries.is_empty() {
        "no capture formats".into()
    } else {
        entries.join("; ")
    }
}

/// Explain an exact-format mismatch: requested vs offered, and which knobs to change.
pub(super) fn v4l2_mismatch_hint(config: &V4l2Config, device: &V4l2DeviceInfo) -> String {
    format!(
        "requested {} {}x{} @ {} fps; {} ({}) offers: {}. Only the exact requested format is \
         used (no automatic negotiation); set --width/--height/--fps/--pixel-format or the \
         settings video.width, video.height, video.fps, video.pixel_format to one of these, \
         or video.device to pick another camera. `v4l2-ctl --list-formats-ext` or \
         `rusty-lola devices` shows the same list",
        config.pixel_format,
        config.width,
        config.height,
        config.fps,
        device.device,
        device.card,
        v4l2_offered_formats(device)
    )
}

/// The error text, with the device's real formats appended for format mismatches.
pub(super) fn explain_v4l2_failure(error: &V4l2Error, config: &V4l2Config) -> String {
    let mismatch = matches!(
        error,
        V4l2Error::NegotiationMismatch { .. } | V4l2Error::UnsupportedPixelFormat(_)
    );
    match mismatch.then(|| V4l2Camera::inventory_device(&config.device)) {
        Some(Ok(device)) => format!("{error}; {}", v4l2_mismatch_hint(config, &device)),
        _ => error.to_string(),
    }
}

/// List the inventoried `hw:` devices and how to choose one.
pub(super) fn alsa_device_hint(config: &AlsaConfig, devices: &[AlsaDeviceInfo]) -> String {
    let listed: Vec<String> = devices
        .iter()
        .filter(|device| device.name.starts_with("hw:"))
        .map(|device| {
            let directions = match (device.supports_capture, device.supports_playback) {
                (true, true) => "capture+playback",
                (true, false) => "capture",
                (false, true) => "playback",
                (false, false) => "none",
            };
            match &device.description {
                Some(description) => format!("{} ({description}, {directions})", device.name),
                None => format!("{} ({directions})", device.name),
            }
        })
        .collect();
    let available = if listed.is_empty() {
        "no hw: devices found".to_string()
    } else {
        listed.join("; ")
    };
    format!(
        "tried capture `{}` / playback `{}` at {} Hz, {} ch, {}-bit, {} frames; available: {available}. \
         Only `hw:` devices are accepted (not plughw or default) and the exact format is required; \
         choose one with --input-device/--output-device or the settings audio.input_device, \
         audio.output_device",
        config.capture_device,
        config.playback_device,
        config.sample_rate,
        config.channels,
        config.bits_per_sample,
        config.frames_per_buffer
    )
}

/// The error text, with the inventoried `hw:` devices appended.
pub(super) fn explain_alsa_failure(error: &AlsaError, config: &AlsaConfig) -> String {
    match crate::audio::alsa::inventory_alsa_devices() {
        Ok(devices) => format!("{error}; {}", alsa_device_hint(config, &devices)),
        Err(_) => error.to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::video::v4l2::{V4l2Capabilities, V4l2FormatInfo, V4l2Mode};

    fn format(name: &str, modes: Vec<V4l2Mode>) -> V4l2FormatInfo {
        V4l2FormatInfo {
            pixel_format: name.into(),
            description: String::new(),
            compressed: false,
            emulated: false,
            modes,
        }
    }

    fn camera() -> V4l2DeviceInfo {
        let mode = |width, height, rates: &[u32]| V4l2Mode {
            size: V4l2FrameSize::Discrete { width, height },
            intervals: rates
                .iter()
                .map(|fps| V4l2FrameInterval::Discrete {
                    numerator: 1,
                    denominator: *fps,
                })
                .collect(),
        };
        V4l2DeviceInfo {
            device: "/dev/video0".into(),
            driver: "uvcvideo".into(),
            card: "USB Cam".into(),
            bus_info: String::new(),
            version: 0,
            capabilities: V4l2Capabilities {
                raw: 0,
                device_raw: 0,
                video_capture: true,
                video_capture_mplane: false,
                streaming: true,
                read_write: false,
                metadata_capture: false,
            },
            formats: vec![
                format("YUYV", vec![mode(640, 480, &[30, 15])]),
                format("MJPG", vec![mode(1280, 720, &[60])]),
            ],
        }
    }

    #[test]
    fn v4l2_hint_lists_offered_formats_and_the_knobs_to_change() {
        let config = V4l2Config {
            device: "/dev/video0".into(),
            width: 1280,
            height: 720,
            fps: 60,
            pixel_format: "GREY".into(),
        };
        let hint = v4l2_mismatch_hint(&config, &camera());
        assert!(hint.contains("requested GREY 1280x720 @ 60 fps"), "{hint}");
        assert!(
            hint.contains("YUYV 640x480 @ 30/15 fps; MJPG 1280x720 @ 60 fps"),
            "{hint}"
        );
        assert!(
            hint.contains("--width/--height/--fps/--pixel-format"),
            "{hint}"
        );
        assert!(hint.contains("video.pixel_format"), "{hint}");
        assert!(hint.contains("v4l2-ctl --list-formats-ext"), "{hint}");
    }

    #[test]
    fn v4l2_offered_formats_handles_ranges_fractions_and_empty_devices() {
        let mut device = camera();
        device.formats = vec![format(
            "GREY",
            vec![V4l2Mode {
                size: V4l2FrameSize::Range {
                    continuous: false,
                    min_width: 160,
                    max_width: 1920,
                    step_width: 16,
                    min_height: 120,
                    max_height: 1080,
                    step_height: 8,
                },
                intervals: vec![V4l2FrameInterval::Discrete {
                    numerator: 1001,
                    denominator: 30_000,
                }],
            }],
        )];
        assert_eq!(
            v4l2_offered_formats(&device),
            "GREY 160x120..1920x1080 @ 29.97 fps"
        );
        device.formats.clear();
        assert_eq!(v4l2_offered_formats(&device), "no capture formats");
    }

    #[test]
    fn alsa_hint_lists_only_hw_devices_and_names_the_options() {
        let device = |name: &str, description: Option<&str>, capture, playback| AlsaDeviceInfo {
            name: name.into(),
            description: description.map(Into::into),
            supports_capture: capture,
            supports_playback: playback,
        };
        let devices = vec![
            device("hw:CARD=USB,DEV=0", Some("USB Audio"), true, true),
            device("plughw:CARD=USB,DEV=0", None, true, true),
            device("hw:CARD=HDMI,DEV=3", None, false, true),
        ];
        let hint = alsa_device_hint(&AlsaConfig::default(), &devices);
        assert!(hint.contains("capture `hw:0`"), "{hint}");
        assert!(
            hint.contains("hw:CARD=USB,DEV=0 (USB Audio, capture+playback)"),
            "{hint}"
        );
        assert!(hint.contains("hw:CARD=HDMI,DEV=3 (playback)"), "{hint}");
        assert!(!hint.contains("plughw:CARD"), "{hint}");
        assert!(hint.contains("Only `hw:` devices are accepted"), "{hint}");
        assert!(hint.contains("--input-device/--output-device"), "{hint}");
        assert!(alsa_device_hint(&AlsaConfig::default(), &[]).contains("no hw: devices found"));
    }
}
