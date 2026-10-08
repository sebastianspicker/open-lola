use super::SessionOptions;
use crate::audio::alsa::{AlsaAudio, AlsaConfig};
use crate::audio::{
    open_portaudio_strict, PortAudioConfig, PortAudioError, SoftwareAudio, StrictPortAudio,
};
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
        playout: Vec<u8>,
    },
    Diagnostic {
        audio: SoftwareAudio,
        capture: Vec<u8>,
    },
    PortAudio {
        audio: StrictPortAudio,
        capture: Vec<u8>,
        playout: Vec<u8>,
        /// Capture blocks discarded to keep the device queue shallow.
        capture_backlog_drops: u64,
        /// Capture waits that expired without a block (sent as silence-skip).
        capture_timeouts: u64,
    },
}

/// Queued capture blocks above which the backlog is trimmed to one block, so
/// a stalled session thread does not add its stall to the capture latency.
const CAPTURE_BACKLOG_TRIM_ABOVE: usize = 2;

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
                    playout: Vec::with_capacity(capacity),
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
                    playout: Vec::new(),
                    capture_backlog_drops: 0,
                    capture_timeouts: 0,
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
            Self::Alsa { audio, capture, .. } => {
                audio
                    .read_pcm_into(capture)
                    .map_err(|error| SessionError::AudioBackend(error.to_string()))?;
                Ok(capture)
            }
            Self::PortAudio {
                audio,
                capture,
                capture_backlog_drops,
                capture_timeouts,
                ..
            } => {
                let queued = audio
                    .callback_stats()
                    .map_or(0, |stats| stats.capture_queued_blocks);
                if queued > CAPTURE_BACKLOG_TRIM_ABOVE {
                    *capture_backlog_drops += audio.discard_capture_backlog(1) as u64;
                }
                let callback_period = f64::from(audio.config().frames_per_buffer)
                    / f64::from(audio.config().sample_rate.max(1));
                let timeout = Duration::from_secs_f64((callback_period * 4.0).clamp(0.002, 0.02));
                match audio.read_pcm_timeout_into(timeout, capture) {
                    Ok(()) => {}
                    // A missed capture block is a skipped send, not a failure.
                    Err(PortAudioError::CaptureUnavailable) => {
                        *capture_timeouts += 1;
                        capture.clear();
                    }
                    Err(error) => return Err(SessionError::AudioBackend(error.to_string())),
                }
                Ok(capture)
            }
        }
    }

    /// Queues one remote block for playout. Returns whether an older queued
    /// block had to be displaced to make room, which the caller reports as a
    /// drop instead of a session failure: the device keeps the newest audio.
    pub(super) fn play_pcm(&mut self, pcm: &[u8]) -> Result<bool, SessionError> {
        match self {
            Self::Inactive => Err(SessionError::Configuration(
                "audio streams are disabled".into(),
            )),
            Self::Diagnostic { .. } => Ok(false),
            Self::Alsa { audio, playout, .. } => {
                let config = audio.config();
                let frame_bytes =
                    usize::from(config.channels) * usize::from(config.bits_per_sample / 8);
                let block_bytes = frame_bytes * config.frames_per_buffer as usize;
                write_reblocked(playout, pcm, block_bytes, frame_bytes, |block| {
                    audio
                        .write_pcm(block)
                        .map(|()| false)
                        .map_err(|error| SessionError::AudioBackend(error.to_string()))
                })
            }
            Self::PortAudio { audio, playout, .. } => {
                let config = audio.config();
                let frame_bytes = config.channels as usize * (config.bits_per_sample as usize / 8);
                let block_bytes = frame_bytes * config.frames_per_buffer as usize;
                write_reblocked(playout, pcm, block_bytes, frame_bytes, |block| {
                    match audio.write_pcm(block) {
                        Ok(()) => Ok(false),
                        // The ring already replaced its oldest block with this
                        // one; the session continues with the freshest audio.
                        Err(PortAudioError::PlaybackQueueFull) => Ok(true),
                        Err(error) => Err(SessionError::AudioBackend(error.to_string())),
                    }
                })
            }
        }
    }

    pub(super) fn xruns(&self) -> Option<u64> {
        match self {
            Self::Alsa { audio, .. } => Some(audio.xruns()),
            Self::PortAudio { audio, .. } => audio.callback_stats().map(|stats| {
                stats.capture_overflow_blocks
                    + stats.playback_underflow_callbacks
                    + stats.portaudio_input_overflow_callbacks
                    + stats.portaudio_output_underflow_callbacks
            }),
            _ => None,
        }
    }

    /// Complete capture blocks waiting in a callback-mode device queue;
    /// `None` when the backend has no device-side queue to pace from.
    pub(super) fn capture_blocks_ready(&self) -> Option<usize> {
        match self {
            Self::PortAudio { audio, .. } => audio
                .callback_stats()
                .map(|stats| stats.capture_queued_blocks),
            _ => None,
        }
    }

    pub(super) fn capture_backlog_drops(&self) -> u64 {
        match self {
            Self::PortAudio {
                capture_backlog_drops,
                ..
            } => *capture_backlog_drops,
            _ => 0,
        }
    }

    pub(super) fn capture_timeouts(&self) -> u64 {
        match self {
            Self::PortAudio {
                capture_timeouts, ..
            } => *capture_timeouts,
            _ => 0,
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

/// Re-blocks remote audio to the local device block before it reaches the
/// playout ring. LoLa negotiates sample rate, depth, and channels but not the
/// frames per packet, so a 32-frame peer feeding a 64-frame device (or the
/// reverse) must keep playing instead of failing the session. The staging
/// buffer never retains more than one incomplete device block.
fn write_reblocked(
    staging: &mut Vec<u8>,
    pcm: &[u8],
    block_bytes: usize,
    frame_bytes: usize,
    mut write: impl FnMut(&[u8]) -> Result<bool, SessionError>,
) -> Result<bool, SessionError> {
    if block_bytes == 0
        || frame_bytes == 0
        || pcm.is_empty()
        || !pcm.len().is_multiple_of(frame_bytes)
    {
        return Err(SessionError::Protocol(format!(
            "remote audio block of {} bytes is not a whole number of {frame_bytes}-byte frames",
            pcm.len()
        )));
    }
    if staging.is_empty() && pcm.len() == block_bytes {
        return write(pcm);
    }
    staging.extend_from_slice(pcm);
    let mut displaced = false;
    let mut offset = 0;
    while staging.len() - offset >= block_bytes {
        displaced |= write(&staging[offset..offset + block_bytes])?;
        offset += block_bytes;
    }
    staging.drain(..offset);
    Ok(displaced)
}

#[cfg(test)]
mod reblock_tests {
    use super::write_reblocked;

    #[test]
    fn exact_blocks_bypass_staging_and_partial_blocks_accumulate() {
        let mut staging = Vec::new();
        let mut written: Vec<Vec<u8>> = Vec::new();
        let block: Vec<u8> = (0..8).collect();
        write_reblocked(&mut staging, &block, 8, 2, |b| {
            written.push(b.to_vec());
            Ok(false)
        })
        .unwrap();
        assert_eq!(written, vec![block.clone()]);
        assert!(staging.is_empty());

        for half in [&block[..4], &block[4..]] {
            write_reblocked(&mut staging, half, 8, 2, |b| {
                written.push(b.to_vec());
                Ok(false)
            })
            .unwrap();
        }
        assert_eq!(written.len(), 2);
        assert_eq!(written[1], block);
        assert!(staging.is_empty());

        let double: Vec<u8> = (0..16).collect();
        write_reblocked(&mut staging, &double, 8, 2, |b| {
            written.push(b.to_vec());
            Ok(false)
        })
        .unwrap();
        assert_eq!(written.len(), 4);
        assert_eq!(written[3], double[8..]);
        assert!(staging.is_empty());

        write_reblocked(&mut staging, &double[..6], 8, 2, |_| Ok(false)).unwrap();
        assert_eq!(staging.len(), 6);
        assert!(write_reblocked(&mut staging, &double[..3], 8, 2, |_| Ok(false)).is_err());
        assert!(write_reblocked(&mut staging, &[], 8, 2, |_| Ok(false)).is_err());
    }
}
