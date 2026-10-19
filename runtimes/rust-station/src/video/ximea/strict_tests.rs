//! The strict XIMEA session's configuration order and frame checks, without
//! the xiAPI library.
use super::*;
use crate::config::CameraMode;

fn config() -> XimeaConfig {
    XimeaConfig::from_mode(
        0,
        &CameraMode {
            mode_id: "001".into(),
            vendor: "XIMEA".into(),
            model: "MQ013".into(),
            width: 8,
            height: 4,
            pixel_format: "Mono8".into(),
            max_fps: 30,
            raw_line: String::new(),
        },
    )
}

#[test]
fn configuration_sets_geometry_first_then_format_timing_and_exposure() {
    let mut applied = Vec::new();
    apply_configuration(&config(), |name, value| {
        applied.push((name, value));
        Ok(())
    })
    .unwrap();
    assert_eq!(
        applied,
        [
            ("offsetX", 0),
            ("offsetY", 0),
            ("width", 8),
            ("height", 4),
            ("imgdataformat", XI_MONO8),
            ("acq_timing_mode", XI_ACQ_TIMING_MODE_FRAME_RATE),
            ("framerate", 30),
            ("exposure", 10_000),
        ]
    );
}

#[test]
fn a_failing_parameter_stops_the_configuration() {
    let mut applied = Vec::new();
    let error = apply_configuration(&config(), |name, _| {
        applied.push(name);
        if name == "imgdataformat" {
            return Err(XimeaError::Native {
                operation: "xiSetParam",
                detail: name.into(),
            });
        }
        Ok(())
    })
    .unwrap_err();
    assert!(error.to_string().contains("imgdataformat"), "{error}");
    assert_eq!(applied.last(), Some(&"imgdataformat"));
    assert_eq!(applied.len(), 5);
}

#[test]
fn frames_must_match_the_configured_geometry_format_and_size() {
    let config = config();
    let good = vec![0; 32];
    validate_frame(&config, &good, 8, 4, "Mono8").unwrap();
    let cases: [(&[u8], u32, u32, &str, &str); 4] = [
        (&good, 4, 4, "Mono8", "returned 4x4, configured 8x4"),
        (&good, 8, 4, "RGB24", "returned RGB24, configured Mono8"),
        (&good[..31], 8, 4, "Mono8", "returned 31 bytes; expected 32"),
        (&good, 8, 5, "Mono8", "returned 8x5, configured 8x4"),
    ];
    for (pixels, width, height, format, reason) in cases {
        let error = validate_frame(&config, pixels, width, height, format)
            .unwrap_err()
            .to_string();
        assert!(error.contains(reason), "{reason}: {error}");
    }
}
