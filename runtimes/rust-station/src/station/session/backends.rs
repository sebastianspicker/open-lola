use super::SessionOptions;
use crate::audio::alsa::{AlsaAudio, AlsaConfig};
use crate::audio::{open_portaudio_strict, PortAudioConfig, SoftwareAudio, StrictPortAudio};
use crate::config::{AudioBackend, CameraMode, StationSettings, VideoBackend};
use crate::station::SessionError;
use crate::video::v4l2::{V4l2Camera, V4l2Config};
use crate::video::{open_ximea_strict, SoftwareCamera, StrictXimeaCamera, XimeaConfig};
use std::time::Duration;

pub(super) enum SessionCameraBackend {
    Diagnostic(SoftwareCamera),
    Ximea(StrictXimeaCamera),
    V4l2(V4l2Camera),
}

impl SessionCameraBackend {
    pub(super) fn synthetic_mode(settings: &StationSettings, mode_id: String) -> CameraMode {
        CameraMode {
            mode_id,
            vendor: "Software".into(),
            model: "Synthetic".into(),
            width: settings.video.width,
            height: settings.video.height,
            pixel_format: if settings.video.bpp >= 24 {
                "RGB24".into()
            } else {
                "Mono8".into()
            },
            max_fps: settings.video.fps,
            raw_line: String::new(),
        }
    }

    pub(super) fn open(
        settings: &StationSettings,
        options: &SessionOptions,
        mode: &CameraMode,
    ) -> Result<Self, SessionError> {
        let requested = options.camera_backend;
        match requested {
            VideoBackend::Diagnostic => {
                let mut camera = SoftwareCamera::default();
                camera.open(mode);
                camera.start();
                Ok(Self::Diagnostic(camera))
            }
            VideoBackend::V4l2 => {
                let config = V4l2Config {
                    device: if settings.video.device.is_empty() {
                        format!("/dev/video{}", settings.video.local_camera_index)
                    } else {
                        settings.video.device.clone()
                    },
                    width: settings.video.width,
                    height: settings.video.height,
                    fps: settings.video.fps,
                    pixel_format: if settings.video.pixel_format.is_empty() {
                        if settings.video.bpp == 8 {
                            "GREY"
                        } else {
                            "RGB3"
                        }
                        .into()
                    } else {
                        settings.video.pixel_format.clone()
                    },
                };
                let mut camera = V4l2Camera::open(config)
                    .map_err(|error| SessionError::VideoBackend(error.to_string()))?;
                camera
                    .start()
                    .map_err(|error| SessionError::VideoBackend(error.to_string()))?;
                Ok(Self::V4l2(camera))
            }
            VideoBackend::Ximea => {
                let config = XimeaConfig::from_mode(settings.video.local_camera_index, mode);
                let mut camera = open_ximea_strict(config)
                    .map_err(|error| SessionError::VideoBackend(error.to_string()))?;
                camera
                    .start()
                    .map_err(|error| SessionError::VideoBackend(error.to_string()))?;
                Ok(Self::Ximea(camera))
            }
        }
    }

    pub(super) fn name(&self) -> &'static str {
        match self {
            Self::Diagnostic(_) => "DiagnosticCamera (synthetic)",
            Self::Ximea(_) => "Ximea",
            Self::V4l2(_) => "V4L2",
        }
    }

    pub(super) fn grab(&mut self) -> Result<(Vec<u8>, String), SessionError> {
        match self {
            Self::Diagnostic(camera) => Ok(camera.grab()),
            Self::V4l2(camera) => camera
                .grab()
                .map_err(|error| SessionError::VideoBackend(error.to_string())),
            Self::Ximea(camera) => camera
                .grab()
                .map(|frame| (frame.pixels, frame.pixel_format))
                .map_err(|error| SessionError::VideoBackend(error.to_string())),
        }
    }

    pub(super) fn cancellation_handle(&self) -> Option<crate::video::v4l2::V4l2Cancellation> {
        match self {
            Self::V4l2(camera) => Some(camera.cancellation_handle()),
            _ => None,
        }
    }

    pub(super) fn stop(&mut self) -> Result<(), SessionError> {
        match self {
            Self::Diagnostic(camera) => {
                camera.stop();
                Ok(())
            }
            Self::V4l2(camera) => camera
                .stop()
                .map_err(|error| SessionError::Cleanup(format!("video backend: {error}"))),
            Self::Ximea(camera) => camera
                .stop()
                .map_err(|error| SessionError::Cleanup(format!("video backend: {error}"))),
        }
    }
}

pub(super) enum SessionAudioBackend {
    Inactive,
    Alsa {
        audio: AlsaAudio,
        capture: Vec<u8>,
    },
    Diagnostic {
        audio: SoftwareAudio,
        capture: Vec<u8>,
    },
    PortAudio {
        audio: StrictPortAudio,
        capture: Vec<u8>,
    },
}

impl SessionAudioBackend {
    pub(super) fn open(
        settings: &StationSettings,
        options: &SessionOptions,
    ) -> Result<Self, SessionError> {
        if !options.stream_tx_audio && !options.stream_rx_audio {
            return Ok(Self::Inactive);
        }
        let requested = options.audio_backend;
        match requested {
            AudioBackend::Diagnostic => {
                let mut audio = SoftwareAudio::default();
                audio.open(
                    settings.audio.sample_rate,
                    settings.audio.channels,
                    settings.audio.bits_per_sample,
                    settings.audio.buffer_samples,
                );
                audio.start();
                Ok(Self::Diagnostic {
                    audio,
                    capture: Vec::new(),
                })
            }
            AudioBackend::Alsa => {
                let config = AlsaConfig {
                    capture_enabled: options.stream_tx_audio,
                    playback_enabled: options.stream_rx_audio,
                    capture_device: if settings.audio.input_device.is_empty() {
                        "hw:0".into()
                    } else {
                        settings.audio.input_device.clone()
                    },
                    playback_device: if settings.audio.output_device.is_empty() {
                        "hw:0".into()
                    } else {
                        settings.audio.output_device.clone()
                    },
                    sample_rate: settings.audio.sample_rate,
                    channels: settings.audio.channels,
                    bits_per_sample: settings.audio.bits_per_sample,
                    frames_per_buffer: settings.audio.buffer_samples,
                };
                let capacity = config.frames_per_buffer as usize
                    * config.channels as usize
                    * usize::from(config.bits_per_sample / 8);
                let mut audio = AlsaAudio::open(config)
                    .map_err(|error| SessionError::AudioBackend(error.to_string()))?;
                audio
                    .start()
                    .map_err(|error| SessionError::AudioBackend(error.to_string()))?;
                Ok(Self::Alsa {
                    audio,
                    capture: Vec::with_capacity(capacity),
                })
            }
            AudioBackend::PortAudioAsio => {
                let config = PortAudioConfig::from_settings(&settings.audio);
                let mut audio = open_portaudio_strict(config)
                    .map_err(|error| SessionError::AudioBackend(error.to_string()))?;
                audio
                    .start()
                    .map_err(|error| SessionError::AudioBackend(error.to_string()))?;
                Ok(Self::PortAudio {
                    audio,
                    capture: Vec::new(),
                })
            }
        }
    }

    pub(super) fn name(&self) -> &'static str {
        match self {
            Self::Inactive => "",
            Self::Diagnostic { .. } => "DiagnosticAudio (synthetic)",
            Self::PortAudio { .. } => "PortAudio ASIO",
            Self::Alsa { .. } => "ALSA",
        }
    }

    pub(super) fn buffer_samples(&self) -> u32 {
        match self {
            Self::Inactive => 0,
            Self::Diagnostic { audio, .. } => audio.buffer_samples,
            Self::PortAudio { audio, .. } => audio.config().frames_per_buffer,
            Self::Alsa { audio, .. } => audio.config().frames_per_buffer,
        }
    }

    pub(super) fn read_pcm(&mut self) -> Result<&[u8], SessionError> {
        match self {
            Self::Inactive => Err(SessionError::Configuration(
                "audio streams are disabled".into(),
            )),
            Self::Diagnostic { audio, capture } => {
                audio.read_pcm_into(capture);
                Ok(capture)
            }
            Self::Alsa { audio, capture } => {
                audio
                    .read_pcm_into(capture)
                    .map_err(|error| SessionError::AudioBackend(error.to_string()))?;
                Ok(capture)
            }
            Self::PortAudio { audio, capture } => {
                let callback_period = f64::from(audio.config().frames_per_buffer)
                    / f64::from(audio.config().sample_rate.max(1));
                let timeout = Duration::from_secs_f64((callback_period * 4.0).clamp(0.002, 0.02));
                audio
                    .read_pcm_timeout_into(timeout, capture)
                    .map_err(|error| SessionError::AudioBackend(error.to_string()))?;
                Ok(capture)
            }
        }
    }

    pub(super) fn play_pcm(&mut self, pcm: &[u8]) -> Result<(), SessionError> {
        match self {
            Self::Inactive => Err(SessionError::Configuration(
                "audio streams are disabled".into(),
            )),
            Self::Diagnostic { .. } => Ok(()),
            Self::Alsa { audio, .. } => audio
                .write_pcm(pcm)
                .map_err(|error| SessionError::AudioBackend(error.to_string())),
            Self::PortAudio { audio, .. } => audio
                .write_pcm(pcm)
                .map_err(|error| SessionError::AudioBackend(error.to_string())),
        }
    }

    pub(super) fn xruns(&self) -> Option<u64> {
        match self {
            Self::Alsa { audio, .. } => Some(audio.xruns()),
            _ => None,
        }
    }

    pub(super) fn stop(&mut self) -> Result<(), SessionError> {
        match self {
            Self::Inactive => Ok(()),
            Self::Diagnostic { audio, .. } => {
                audio.stop();
                Ok(())
            }
            Self::Alsa { audio, .. } => audio
                .stop()
                .map_err(|error| SessionError::Cleanup(format!("audio backend: {error}"))),
            Self::PortAudio { audio, .. } => audio
                .stop()
                .map_err(|error| SessionError::Cleanup(format!("audio backend: {error}"))),
        }
    }
}
