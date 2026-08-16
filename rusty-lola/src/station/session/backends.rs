use super::SessionOptions;
use crate::audio::{open_portaudio_strict, PortAudioConfig, SoftwareAudio, StrictPortAudio};
use crate::config::{AudioBackend, CameraMode, StationSettings, VideoBackend};
use crate::station::SessionError;
use crate::video::{open_ximea_strict, SoftwareCamera, StrictXimeaCamera, XimeaConfig};
use std::time::Duration;

pub(super) enum SessionCameraBackend {
    Diagnostic(SoftwareCamera),
    Ximea(StrictXimeaCamera),
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
        }
    }

    pub(super) fn grab(&mut self) -> Result<(Vec<u8>, String), SessionError> {
        match self {
            Self::Diagnostic(camera) => Ok(camera.grab()),
            Self::Ximea(camera) => camera
                .grab()
                .map(|frame| (frame.pixels, frame.pixel_format))
                .map_err(|error| SessionError::VideoBackend(error.to_string())),
        }
    }

    pub(super) fn stop(&mut self) -> Result<(), SessionError> {
        match self {
            Self::Diagnostic(camera) => {
                camera.stop();
                Ok(())
            }
            Self::Ximea(camera) => camera
                .stop()
                .map_err(|error| SessionError::Cleanup(format!("video backend: {error}"))),
        }
    }
}

pub(super) enum SessionAudioBackend {
    Diagnostic(SoftwareAudio),
    PortAudio(StrictPortAudio),
}

impl SessionAudioBackend {
    pub(super) fn open(
        settings: &StationSettings,
        options: &SessionOptions,
    ) -> Result<Self, SessionError> {
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
                Ok(Self::Diagnostic(audio))
            }
            AudioBackend::PortAudioAsio => {
                let config = PortAudioConfig::from_settings(&settings.audio);
                let mut audio = open_portaudio_strict(config)
                    .map_err(|error| SessionError::AudioBackend(error.to_string()))?;
                audio
                    .start()
                    .map_err(|error| SessionError::AudioBackend(error.to_string()))?;
                Ok(Self::PortAudio(audio))
            }
        }
    }

    pub(super) fn name(&self) -> &'static str {
        match self {
            Self::Diagnostic(_) => "DiagnosticAudio (synthetic)",
            Self::PortAudio(_) => "PortAudio ASIO",
        }
    }

    pub(super) fn buffer_samples(&self) -> u32 {
        match self {
            Self::Diagnostic(audio) => audio.buffer_samples,
            Self::PortAudio(audio) => audio.config().frames_per_buffer,
        }
    }

    pub(super) fn read_pcm(&mut self) -> Result<Vec<u8>, SessionError> {
        match self {
            Self::Diagnostic(audio) => Ok(audio.read_pcm()),
            Self::PortAudio(audio) => {
                let callback_period = f64::from(audio.config().frames_per_buffer)
                    / f64::from(audio.config().sample_rate.max(1));
                let timeout = Duration::from_secs_f64((callback_period * 4.0).clamp(0.002, 0.02));
                audio
                    .read_pcm_timeout(timeout)
                    .map_err(|error| SessionError::AudioBackend(error.to_string()))
            }
        }
    }

    pub(super) fn play_pcm(&mut self, pcm: &[u8]) -> Result<(), SessionError> {
        match self {
            Self::Diagnostic(_) => Ok(()),
            Self::PortAudio(audio) => audio
                .write_pcm(pcm)
                .map_err(|error| SessionError::AudioBackend(error.to_string())),
        }
    }

    pub(super) fn stop(&mut self) -> Result<(), SessionError> {
        match self {
            Self::Diagnostic(audio) => {
                audio.stop();
                Ok(())
            }
            Self::PortAudio(audio) => audio
                .stop()
                .map_err(|error| SessionError::Cleanup(format!("audio backend: {error}"))),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::config::default_settings;

    #[test]
    fn explicit_diagnostic_backends_directly_use_software_implementations() {
        let settings = default_settings();
        let options = SessionOptions::demo();
        let mode = SessionCameraBackend::synthetic_mode(&settings, "009".into());

        let mut camera = SessionCameraBackend::open(&settings, &options, &mode).unwrap();
        assert!(matches!(camera, SessionCameraBackend::Diagnostic(_)));
        assert!(!camera.grab().unwrap().0.is_empty());

        let mut audio = SessionAudioBackend::open(&settings, &options).unwrap();
        assert!(matches!(audio, SessionAudioBackend::Diagnostic(_)));
        assert!(!audio.read_pcm().unwrap().is_empty());
    }
}
