//! Bounded device-inventory work kept off the Signal Desk update thread.

use super::{DeviceChoice, InventoryState};
use crate::audio::alsa::inventory_alsa_devices;
use crate::audio::portaudio::load_portaudio;
use crate::config::{AudioBackend, VideoBackend};
use crate::video::v4l2::V4l2Camera;

pub(crate) struct InventoryResult {
    pub(super) generation: u64,
    pub(super) fingerprint: u64,
    pub(super) audio: InventoryState,
    pub(super) video: InventoryState,
}

pub(super) fn collect(
    generation: u64,
    fingerprint: u64,
    audio_backend: AudioBackend,
    video_backend: VideoBackend,
) -> InventoryResult {
    InventoryResult {
        generation,
        fingerprint,
        audio: audio_devices(audio_backend),
        video: video_devices(video_backend),
    }
}

fn audio_devices(backend: AudioBackend) -> InventoryState {
    match backend {
        AudioBackend::Alsa => match inventory_alsa_devices() {
            Ok(devices) => InventoryState::Available(
                devices
                    .into_iter()
                    .filter(|device| device.name == "hw" || device.name.starts_with("hw:"))
                    .map(|device| DeviceChoice {
                        label: device.description.unwrap_or_else(|| device.name.clone()),
                        id: device.name,
                        supports_input: device.supports_capture,
                        supports_output: device.supports_playback,
                        formats: Vec::new(),
                    })
                    .collect(),
            ),
            Err(error) => InventoryState::Error(error.to_string()),
        },
        AudioBackend::PortAudioAsio => {
            match load_portaudio(None).and_then(|library| library.devices()) {
                Ok(devices) => InventoryState::Available(
                    devices
                        .into_iter()
                        .map(|device| DeviceChoice {
                            id: device.name.clone(),
                            label: format!("{} · {} Hz", device.name, device.default_sample_rate),
                            supports_input: device.max_input_channels > 0,
                            supports_output: device.max_output_channels > 0,
                            formats: Vec::new(),
                        })
                        .collect(),
                ),
                Err(error) => InventoryState::Error(format!("PortAudio/ASIO: {error}")),
            }
        }
        AudioBackend::Diagnostic => InventoryState::Available(vec![DeviceChoice {
            id: String::new(),
            label: "Built-in diagnostic signal".into(),
            supports_input: true,
            supports_output: true,
            formats: Vec::new(),
        }]),
    }
}

fn video_devices(backend: VideoBackend) -> InventoryState {
    match backend {
        VideoBackend::V4l2 => match V4l2Camera::inventory() {
            Ok(devices) => InventoryState::Available(
                devices
                    .into_iter()
                    .map(|device| DeviceChoice {
                        id: device.device.clone(),
                        label: format!("{} · {}", device.device, device.card),
                        supports_input: true,
                        supports_output: false,
                        formats: device
                            .formats
                            .into_iter()
                            .map(|format| format.pixel_format)
                            .collect(),
                    })
                    .collect(),
            ),
            Err(error) => InventoryState::Error(error.to_string()),
        },
        VideoBackend::Diagnostic => InventoryState::Available(vec![DeviceChoice {
            id: String::new(),
            label: "Built-in diagnostic camera".into(),
            supports_input: true,
            supports_output: false,
            formats: Vec::new(),
        }]),
        VideoBackend::Ximea => InventoryState::NotMeasured,
    }
}
