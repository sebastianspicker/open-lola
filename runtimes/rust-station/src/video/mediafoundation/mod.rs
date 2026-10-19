//! Windows camera capture through Media Foundation's synchronous source reader.
//!
//! Generic USB/UVC webcams appear here as video capture devices. The FFI is
//! hand-declared (`com`) and the DLLs are loaded at runtime from System32
//! (`api`), so the binary still starts on Windows editions without Media
//! Foundation. Mode selection and pixel conversion are platform independent.

#[cfg(windows)]
mod api;
#[cfg(windows)]
mod capture;
#[cfg(any(windows, test))]
mod com;
mod convert;
#[cfg(windows)]
mod device;
mod modes;
#[cfg(not(windows))]
mod nonwindows;

pub use convert::{convert_frame, MfFrameLayout};
pub use modes::{
    mismatch_hint, offered_modes, select_mode, MfMode, MfModeRequest, MfOutput, MfRatio,
    MfSelection, MfSubtype,
};

use crate::config::VideoSettings;
use serde::Serialize;
use serde_json::{json, Value};
use thiserror::Error;

#[cfg(windows)]
use capture as platform;
#[cfg(not(windows))]
use nonwindows as platform;

const MAX_DIMENSION: u32 = crate::protocol::MAX_DIMENSION_PIXELS;
const MAX_FRAME_BYTES: usize = crate::protocol::MAX_MEDIA_FRAME_SIZE;
const MAX_FPS: u32 = 1_000;

#[derive(Debug, Error)]
pub enum MfError {
    #[error("Media Foundation camera capture is supported only on Windows")]
    UnsupportedPlatform,
    #[error("invalid Media Foundation configuration: {0}")]
    InvalidConfig(String),
    #[error(
        "unsupported Media Foundation pixel format {0:?}; use NV12, YUY2 or RGB32, or leave it \
         empty to pick one"
    )]
    UnsupportedPixelFormat(String),
    #[error("Media Foundation is unavailable: {0}")]
    Unavailable(String),
    #[error("{operation} failed with HRESULT 0x{code:08X}")]
    Call { operation: &'static str, code: u32 },
    #[error("{0}")]
    NoDevice(String),
    #[error("Media Foundation mode not offered: {0}")]
    ModeNotOffered(String),
    #[error("invalid Media Foundation frame: {0}")]
    InvalidFrame(String),
    #[error("Media Foundation capture is stopped")]
    Stopped,
}

pub type MfResult<T> = Result<T, MfError>;

/// One capture device, with its native modes when the device could be opened.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct MfDeviceInfo {
    pub name: String,
    pub symbolic_link: String,
    pub modes: Vec<MfMode>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub modes_error: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MfConfig {
    /// Symbolic link or friendly name; empty selects the `index`th camera.
    pub device: String,
    pub index: u32,
    pub width: u32,
    pub height: u32,
    pub fps: u32,
    /// Native subtype to insist on; `None` picks NV12, YUY2 or RGB32.
    pub subtype: Option<MfSubtype>,
    pub output: MfOutput,
}

impl MfConfig {
    /// Maps station video settings: bpp 8 delivers Mono8, bpp 24 delivers RGB24.
    pub fn from_settings(video: &VideoSettings) -> MfResult<Self> {
        let output = match video.bpp {
            8 if video.bayer != 0 => {
                return Err(MfError::InvalidConfig(
                    "Media Foundation delivers luma, not a Bayer mosaic; set bayer to 0 \
                     (--bayer 0 or video.bayer)"
                        .into(),
                ))
            }
            8 => MfOutput::Mono8,
            24 => MfOutput::Rgb24,
            other => {
                return Err(MfError::InvalidConfig(format!(
                    "bpp {other} is not delivered; use 8 (Mono8) or 24 (RGB24)"
                )))
            }
        };
        let config = Self {
            device: video.device.trim().to_string(),
            index: video.local_camera_index,
            width: video.width,
            height: video.height,
            fps: video.fps,
            subtype: parse_subtype(&video.pixel_format)?,
            output,
        };
        config.validate()?;
        Ok(config)
    }

    fn validate(&self) -> MfResult<()> {
        if self.width == 0
            || self.height == 0
            || self.width > MAX_DIMENSION
            || self.height > MAX_DIMENSION
        {
            return Err(MfError::InvalidConfig(format!(
                "dimensions {}x{} are outside the capture bounds",
                self.width, self.height
            )));
        }
        if self.fps == 0 || self.fps > MAX_FPS {
            return Err(MfError::InvalidConfig(format!(
                "fps {} is outside 1..={MAX_FPS}",
                self.fps
            )));
        }
        let channels = if self.output == MfOutput::Mono8 { 1 } else { 3 };
        let bytes = self.width as usize * self.height as usize * channels;
        if bytes > MAX_FRAME_BYTES {
            return Err(MfError::InvalidConfig(format!(
                "frame size {bytes} exceeds {MAX_FRAME_BYTES} bytes"
            )));
        }
        Ok(())
    }

    pub fn request(&self) -> MfModeRequest {
        MfModeRequest {
            width: self.width,
            height: self.height,
            fps: self.fps,
            subtype: self.subtype.clone(),
            output: self.output,
        }
    }
}

/// `video.pixel_format` names a native subtype; station output names mean "any".
fn parse_subtype(value: &str) -> MfResult<Option<MfSubtype>> {
    match value.trim().to_ascii_uppercase().as_str() {
        "" | "AUTO" | "GREY" | "GRAY8" | "MONO8" | "RGB" | "RGB24" | "RGB3" => Ok(None),
        "NV12" => Ok(Some(MfSubtype::Nv12)),
        "YUY2" | "YUYV" => Ok(Some(MfSubtype::Yuy2)),
        "RGB32" | "BGRX" | "BGRA" => Ok(Some(MfSubtype::Rgb32)),
        _ => Err(MfError::UnsupportedPixelFormat(value.into())),
    }
}

/// A device's (friendly name, symbolic link), or why it could not be described.
#[cfg_attr(not(windows), allow(dead_code))]
type MfDeviceEntry = Result<(String, String), String>;

/// Chooses the device by symbolic link or friendly name, else by index, and returns its
/// index and friendly name. A device that could not be described is skipped by name and
/// link lookup and listed in the failure message; only selecting that device by index
/// fails with its reason.
#[cfg_attr(not(windows), allow(dead_code))]
fn pick_device<'a>(devices: &'a [MfDeviceEntry], config: &MfConfig) -> MfResult<(usize, &'a str)> {
    let found = if config.device.is_empty() {
        Some(config.index as usize).filter(|index| *index < devices.len())
    } else {
        devices.iter().position(|entry| {
            entry.as_ref().is_ok_and(|(name, link)| {
                link.eq_ignore_ascii_case(&config.device)
                    || name.eq_ignore_ascii_case(&config.device)
            })
        })
    };
    if let Some(index) = found {
        return match &devices[index] {
            Ok((name, _)) => Ok((index, name)),
            Err(reason) => Err(MfError::NoDevice(format!(
                "camera index {index} could not be read: {reason}"
            ))),
        };
    }
    Err({
        let wanted = if config.device.is_empty() {
            format!("camera index {}", config.index)
        } else {
            format!("`{}`", config.device)
        };
        let listed: Vec<String> = devices
            .iter()
            .enumerate()
            .map(|(index, entry)| match entry {
                Ok((name, link)) => format!("[{index}] {name} ({link})"),
                Err(reason) => format!("[{index}] unreadable ({reason})"),
            })
            .collect();
        let available = if listed.is_empty() {
            "no video capture devices found".to_string()
        } else {
            listed.join("; ")
        };
        MfError::NoDevice(format!(
            "no Media Foundation camera matches {wanted}; available: {available}. Choose one \
             with video.device (name or symbolic link) or video.local_camera_index"
        ))
    })
}

pub struct MfCamera {
    config: MfConfig,
    inner: platform::Camera,
}

impl std::fmt::Debug for MfCamera {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        formatter
            .debug_struct("MfCamera")
            .field("config", &self.config)
            .finish_non_exhaustive()
    }
}

impl MfCamera {
    /// Opens the camera and sets the exact requested native mode.
    pub fn open(config: MfConfig) -> MfResult<Self> {
        config.validate()?;
        let inner = platform::Camera::open(&config)?;
        Ok(Self { config, inner })
    }

    pub fn config(&self) -> &MfConfig {
        &self.config
    }

    /// Blocks for the next frame and returns it as `(pixels, "Mono8" | "RGB24")`.
    pub fn grab(&mut self) -> MfResult<(Vec<u8>, String)> {
        let pixels = self.inner.grab(self.config.output)?;
        Ok((pixels, self.config.output.pixel_format().into()))
    }

    /// Releases the reader and shuts the device source down; idempotent.
    pub fn stop(&mut self) -> MfResult<()> {
        self.inner.stop()
    }

    pub fn inventory() -> MfResult<Vec<MfDeviceInfo>> {
        platform::inventory()
    }
}

/// The `rusty-lola devices` entry for this backend.
pub fn inventory_json() -> Value {
    match MfCamera::inventory() {
        Ok(devices) => json!({"backend": "mediafoundation", "devices": devices}),
        Err(error) => {
            json!({"backend": "mediafoundation", "devices": [], "error": error.to_string()})
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::config::VideoBackend;

    fn settings(bpp: u32, bayer: u32, pixel_format: &str) -> VideoSettings {
        VideoSettings {
            bpp,
            bayer,
            pixel_format: pixel_format.into(),
            width: 640,
            height: 480,
            fps: 30,
            ..VideoSettings::default()
        }
    }

    #[test]
    fn settings_map_bpp_to_output_and_pixel_format_to_subtype() {
        let mono = MfConfig::from_settings(&settings(8, 0, "")).unwrap();
        assert_eq!((mono.output, mono.subtype), (MfOutput::Mono8, None));
        let rgb = MfConfig::from_settings(&settings(24, 1, "yuyv")).unwrap();
        assert_eq!(
            (rgb.output, rgb.subtype),
            (MfOutput::Rgb24, Some(MfSubtype::Yuy2))
        );
        assert_eq!(
            MfConfig::from_settings(&settings(8, 0, "GREY"))
                .unwrap()
                .subtype,
            None
        );
        for (bpp, bayer, format) in [(8, 1, ""), (16, 0, ""), (8, 0, "MJPG")] {
            assert!(MfConfig::from_settings(&settings(bpp, bayer, format)).is_err());
        }
        let mut huge = settings(24, 0, "");
        huge.width = 8_193;
        assert!(matches!(
            MfConfig::from_settings(&huge),
            Err(MfError::InvalidConfig(_))
        ));
    }

    #[test]
    fn devices_are_picked_by_link_name_or_index() {
        let devices = vec![
            Ok((
                "Integrated Camera".to_string(),
                r"\\?\usb#vid_1".to_string(),
            )),
            Ok(("USB Cam".to_string(), r"\\?\usb#vid_2".to_string())),
        ];
        let mut config = MfConfig::from_settings(&settings(8, 0, "")).unwrap();
        config.index = 1;
        assert_eq!(pick_device(&devices, &config).unwrap(), (1, "USB Cam"));
        config.device = "usb cam".into();
        assert_eq!(pick_device(&devices, &config).unwrap().0, 1);
        config.device = r"\\?\USB#VID_1".into();
        assert_eq!(pick_device(&devices, &config).unwrap().0, 0);
        config.device = "missing".into();
        let error = pick_device(&devices, &config).unwrap_err().to_string();
        assert!(error.contains("[1] USB Cam"), "{error}");
        config.device.clear();
        config.index = 0;
        let error = pick_device(&[], &config).unwrap_err().to_string();
        assert!(error.contains("no video capture devices found"), "{error}");
    }

    #[test]
    fn a_broken_device_does_not_block_a_good_one() {
        let devices = vec![
            Err("HRESULT 0x80070490".to_string()),
            Ok(("USB Cam".to_string(), r"\\?\usb#vid_2".to_string())),
        ];
        let mut config = MfConfig::from_settings(&settings(8, 0, "")).unwrap();
        config.index = 1;
        assert_eq!(pick_device(&devices, &config).unwrap(), (1, "USB Cam"));
        config.device = "USB Cam".into();
        assert_eq!(pick_device(&devices, &config).unwrap(), (1, "USB Cam"));
        // Only selecting the broken device itself fails, naming why.
        config.device.clear();
        config.index = 0;
        let error = pick_device(&devices, &config).unwrap_err().to_string();
        assert!(
            error.contains("could not be read: HRESULT 0x80070490"),
            "{error}"
        );
        // A miss records the unreadable device in the listing.
        config.device = "missing".into();
        let error = pick_device(&devices, &config).unwrap_err().to_string();
        assert!(
            error.contains("[0] unreadable (HRESULT 0x80070490)"),
            "{error}"
        );
        assert!(error.contains("[1] USB Cam"), "{error}");
    }

    #[test]
    fn settings_and_cli_accept_the_backend_name_and_alias() {
        for name in ["mediafoundation", "media_foundation", "mf", "MF"] {
            let parsed: VideoBackend = serde_json::from_value(json!(name)).unwrap();
            assert_eq!(parsed, VideoBackend::MediaFoundation);
        }
        assert_eq!(
            serde_json::to_value(VideoBackend::MediaFoundation).unwrap(),
            json!("mediafoundation")
        );
        assert_eq!(
            VideoBackend::MediaFoundation.to_string(),
            VideoBackend::MediaFoundation.as_preference()
        );
        use clap::Parser;
        for name in ["mediafoundation", "mf"] {
            let cli = crate::cli::Cli::try_parse_from([
                "rusty-lola",
                "station",
                "--camera-backend",
                name,
            ])
            .unwrap();
            let Some(crate::cli::Commands::Station { camera_backend, .. }) = cli.cmd else {
                panic!("expected station");
            };
            assert_eq!(
                camera_backend.map(VideoBackend::from),
                Some(VideoBackend::MediaFoundation)
            );
        }
    }

    #[cfg(not(windows))]
    #[test]
    fn unsupported_platform_fails_explicitly() {
        let config = MfConfig::from_settings(&settings(8, 0, "")).unwrap();
        assert!(matches!(
            MfCamera::open(config),
            Err(MfError::UnsupportedPlatform)
        ));
        assert!(matches!(
            MfCamera::inventory(),
            Err(MfError::UnsupportedPlatform)
        ));
        let report = inventory_json();
        assert_eq!(report["backend"], "mediafoundation");
        assert!(report["error"]
            .as_str()
            .unwrap()
            .contains("only on Windows"));
    }
}
