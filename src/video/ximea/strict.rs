use super::ffi::{load_xiapi, xi_lock, XiApiLibrary};
use super::types::*;

pub(super) struct XiHandle {
    pub(super) lib: XiApiLibrary,
    pub(super) handle: *mut std::ffi::c_void,
    pub(super) acquiring: bool,
}

impl Drop for XiHandle {
    fn drop(&mut self) {
        if self.acquiring {
            self.lib.stop_acquisition(self.handle);
        }
        self.lib.close_device(self.handle);
    }
}

impl XiHandle {
    pub(super) fn start_checked(&mut self) -> XimeaResult<()> {
        if self.acquiring {
            return Ok(());
        }
        self.lib
            .start_acquisition(self.handle)
            .map_err(|detail| XimeaError::Native {
                operation: "xiStartAcquisition",
                detail,
            })?;
        self.acquiring = true;
        Ok(())
    }

    pub(super) fn stop_checked(&mut self) -> XimeaResult<()> {
        if !self.acquiring {
            return Ok(());
        }
        self.lib.stop_acquisition_checked(self.handle)?;
        self.acquiring = false;
        Ok(())
    }

    pub(super) fn close_checked(&mut self) -> XimeaResult<()> {
        if self.handle.is_null() {
            return Ok(());
        }
        self.lib.close_device_checked(self.handle)?;
        self.handle = std::ptr::null_mut();
        self.acquiring = false;
        Ok(())
    }
}

const CONFIGURATION_ORDER: [&str; 8] = [
    "offsetX",
    "offsetY",
    "width",
    "height",
    "imgdataformat",
    "acq_timing_mode",
    "framerate",
    "exposure",
];

/// Applies the full, geometry-first xiAPI configuration before acquisition.
///
/// Kept independent of a loaded library so the order and failure behaviour can
/// be tested deterministically without a camera or vendor DLL.
fn apply_configuration(
    config: &XimeaConfig,
    mut set_parameter: impl FnMut(&'static str, i32) -> XimeaResult<()>,
) -> XimeaResult<()> {
    let values = [
        config.roi_offset_x,
        config.roi_offset_y,
        config.width,
        config.height,
        config.pixel_format_code() as u32,
        XI_ACQ_TIMING_MODE_FRAME_RATE as u32,
        config.frame_rate,
        config.exposure_us,
    ];
    for (name, value) in CONFIGURATION_ORDER.into_iter().zip(values) {
        set_parameter(name, value as i32)?;
    }
    Ok(())
}

fn validate_frame(
    config: &XimeaConfig,
    pixels: &[u8],
    width: u32,
    height: u32,
    pixel_format: &str,
) -> XimeaResult<()> {
    let expected_format = config.pixel_format.name();
    if width != config.width || height != config.height {
        return Err(XimeaError::InvalidFrame(format!(
            "returned {width}x{height}, configured {}x{}",
            config.width, config.height
        )));
    }
    if pixel_format != expected_format {
        return Err(XimeaError::InvalidFrame(format!(
            "returned {pixel_format}, configured {expected_format}"
        )));
    }
    let expected_len = (width as usize)
        .checked_mul(height as usize)
        .and_then(|pixels| pixels.checked_mul(config.pixel_format.bytes_per_pixel()))
        .ok_or_else(|| {
            XimeaError::InvalidFrame(format!(
                "returned dimensions {width}x{height} overflow the expected payload size"
            ))
        })?;
    if pixels.len() != expected_len {
        return Err(XimeaError::InvalidFrame(format!(
            "returned {} bytes; expected {expected_len} for {width}x{height} {expected_format}",
            pixels.len()
        )));
    }
    Ok(())
}

/// Strict xiAPI camera session. Native failures are terminal to the caller and
/// never replaced by synthetic frames.
pub struct StrictXimeaCamera {
    xi: XiHandle,
    config: XimeaConfig,
}

impl StrictXimeaCamera {
    pub fn open(config: XimeaConfig) -> XimeaResult<Self> {
        config.validate()?;
        let _guard = xi_lock().lock().unwrap_or_else(|e| e.into_inner());
        let lib = load_xiapi(None).map_err(|detail| XimeaError::Native {
            operation: "xiAPI load",
            detail,
        })?;
        let count = lib
            .get_number_devices()
            .map_err(|detail| XimeaError::Native {
                operation: "xiGetNumberDevices",
                detail,
            })?;
        if config.camera_index >= count {
            return Err(XimeaError::Native {
                operation: "xiOpenDevice",
                detail: format!(
                    "camera index {} out of range for {count} discovered device(s)",
                    config.camera_index
                ),
            });
        }
        let handle = lib
            .open_device(config.camera_index)
            .map_err(|detail| XimeaError::Native {
                operation: "xiOpenDevice",
                detail,
            })?;
        let xi = XiHandle {
            lib,
            handle,
            acquiring: false,
        };
        // Every setting is mandatory in the strict path. A failed setting
        // immediately drops this sole-owner handle and can never yield a
        // diagnostic or synthetic frame.
        apply_configuration(&config, |name, value| {
            xi.lib.set_param_int_checked(xi.handle, name, value)
        })?;
        Ok(Self { xi, config })
    }

    pub fn config(&self) -> &XimeaConfig {
        &self.config
    }
    pub fn start(&mut self) -> XimeaResult<()> {
        let _guard = xi_lock().lock().unwrap_or_else(|e| e.into_inner());
        self.xi.start_checked()
    }

    pub fn grab(&mut self) -> XimeaResult<XimeaFrame> {
        if !self.xi.acquiring {
            return Err(XimeaError::NotStarted);
        }
        let _guard = xi_lock().lock().unwrap_or_else(|e| e.into_inner());
        let (pixels, width, height, pixel_format) = self
            .xi
            .lib
            .get_image(self.xi.handle, self.config.timeout_ms)
            .map_err(|detail| XimeaError::Native {
                operation: "xiGetImage",
                detail,
            })?;
        validate_frame(&self.config, &pixels, width, height, &pixel_format)?;
        Ok(XimeaFrame {
            pixels,
            width,
            height,
            pixel_format,
        })
    }

    pub fn stop(&mut self) -> XimeaResult<()> {
        let _guard = xi_lock().lock().unwrap_or_else(|e| e.into_inner());
        self.xi.stop_checked()
    }
    pub fn close(mut self) -> XimeaResult<()> {
        let _guard = xi_lock().lock().unwrap_or_else(|e| e.into_inner());
        let stop_result = self.xi.stop_checked();
        let close_result = self.xi.close_checked();
        stop_result.and(close_result)
    }
}

/// Open the strict native path. This is the session-integration entry point.
pub fn open_ximea_strict(config: XimeaConfig) -> XimeaResult<StrictXimeaCamera> {
    StrictXimeaCamera::open(config)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn config() -> XimeaConfig {
        XimeaConfig {
            camera_index: 0,
            roi_offset_x: 12,
            roi_offset_y: 8,
            width: 640,
            height: 480,
            pixel_format: XimeaPixelFormat::Mono8,
            color_mode: XimeaColorMode::RawBayer,
            exposure_us: 5_000,
            frame_rate: 60,
            timeout_ms: 100,
        }
    }

    #[test]
    fn configuration_applies_every_native_parameter_in_order() {
        let mut seen = Vec::new();
        apply_configuration(&config(), |name, value| {
            seen.push((name, value));
            Ok(())
        })
        .expect("mock accepts configuration");
        assert_eq!(
            seen,
            vec![
                ("offsetX", 12),
                ("offsetY", 8),
                ("width", 640),
                ("height", 480),
                ("imgdataformat", XI_MONO8),
                ("acq_timing_mode", XI_ACQ_TIMING_MODE_FRAME_RATE),
                ("framerate", 60),
                ("exposure", 5_000),
            ]
        );
    }

    #[test]
    fn configuration_stops_at_the_exact_failing_parameter() {
        let mut seen = Vec::new();
        let error = apply_configuration(&config(), |name, _| {
            seen.push(name);
            if name == "imgdataformat" {
                Err(XimeaError::Native {
                    operation: "xiSetParamInt",
                    detail: "mock rejection".into(),
                })
            } else {
                Ok(())
            }
        })
        .expect_err("mock rejects imgdataformat");
        assert!(matches!(
            error,
            XimeaError::Native {
                operation: "xiSetParamInt",
                ..
            }
        ));
        assert_eq!(seen, CONFIGURATION_ORDER[..5]);
    }

    #[test]
    fn frame_validation_rejects_mock_dimension_and_payload_mismatches() {
        let config = config();
        let pixels = vec![0; 640 * 480];
        assert!(matches!(
            validate_frame(&config, &pixels, 639, 480, "Mono8"),
            Err(XimeaError::InvalidFrame(_))
        ));
        assert!(matches!(
            validate_frame(&config, &pixels[..pixels.len() - 1], 640, 480, "Mono8"),
            Err(XimeaError::InvalidFrame(_))
        ));
        assert!(matches!(
            validate_frame(&config, &pixels, 640, 480, "xiAPI(99)"),
            Err(XimeaError::InvalidFrame(_))
        ));
    }
}
