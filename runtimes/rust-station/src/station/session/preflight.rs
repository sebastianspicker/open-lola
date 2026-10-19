//! Device preflight: prove the configured native devices open before the peer is committed.
//!
//! Handles are not carried into the session. Audio and camera are opened by later stages
//! with the negotiated geometry and on the stream thread, so threading the handles through
//! both roles would be a much larger change; a short validation open/close is used instead.
//! Diagnostic backends need no hardware, and loopback sessions stay as they were.

use super::backends::{SessionAudioBackend, SessionCameraBackend};
use super::SessionOptions;
use crate::config::{AudioBackend, StationSettings, VideoBackend};
use crate::station::SessionError;

fn needs_audio(options: &SessionOptions) -> bool {
    (options.stream_tx_audio || options.stream_rx_audio)
        && options.audio_backend != AudioBackend::Diagnostic
}

fn needs_camera(options: &SessionOptions) -> bool {
    options.stream_tx_video
        && !options.audio_only
        && options.camera_backend != VideoBackend::Diagnostic
}

/// Run the openers the session will need; the first failure is returned unchanged.
pub(super) fn preflight_with(
    options: &SessionOptions,
    open_audio: impl FnOnce() -> Result<(), SessionError>,
    open_camera: impl FnOnce() -> Result<(), SessionError>,
) -> Result<(), SessionError> {
    if options.peer_mode.eq_ignore_ascii_case("loopback") {
        return Ok(());
    }
    if needs_audio(options) {
        open_audio()?;
    }
    if needs_camera(options) {
        open_camera()?;
    }
    Ok(())
}

/// Open and release the real audio and camera devices.
pub(super) fn preflight_devices(
    settings: &StationSettings,
    options: &SessionOptions,
) -> Result<(), SessionError> {
    preflight_with(
        options,
        || {
            let mut audio = SessionAudioBackend::open(settings, options)?;
            let _ = audio.stop();
            Ok(())
        },
        || {
            let mode = SessionCameraBackend::synthetic_mode(
                settings,
                settings.video.camera_mode_id.clone(),
            );
            let mut camera = SessionCameraBackend::open(settings, options, &mode)?;
            let _ = camera.stop();
            Ok(())
        },
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::cell::Cell;

    fn lan_options(audio: AudioBackend, video: VideoBackend) -> SessionOptions {
        let mut options = SessionOptions::demo();
        options.peer_mode = "remote".into();
        options.audio_only = false;
        options.stream_tx_video = true;
        options.audio_backend = audio;
        options.camera_backend = video;
        options
    }

    #[test]
    fn a_failing_audio_open_is_returned_before_the_camera_is_tried() {
        let options = lan_options(AudioBackend::Alsa, VideoBackend::V4l2);
        let camera_tried = Cell::new(false);
        let error = preflight_with(
            &options,
            || Err(SessionError::AudioBackend("no such device".into())),
            || {
                camera_tried.set(true);
                Ok(())
            },
        )
        .unwrap_err();
        assert_eq!(error, SessionError::AudioBackend("no such device".into()));
        assert!(!camera_tried.get());
    }

    #[test]
    fn a_failing_camera_open_is_returned() {
        let options = lan_options(AudioBackend::Diagnostic, VideoBackend::V4l2);
        let error = preflight_with(
            &options,
            || panic!("diagnostic audio needs no hardware"),
            || Err(SessionError::VideoBackend("bad format".into())),
        )
        .unwrap_err();
        assert_eq!(error, SessionError::VideoBackend("bad format".into()));
    }

    #[test]
    fn diagnostic_backends_and_loopback_open_nothing() {
        let touched = Cell::new(0);
        let count = || {
            touched.set(touched.get() + 1);
            Ok(())
        };
        let diagnostic = lan_options(AudioBackend::Diagnostic, VideoBackend::Diagnostic);
        preflight_with(&diagnostic, count, count).unwrap();
        let mut loopback = lan_options(AudioBackend::Alsa, VideoBackend::V4l2);
        loopback.peer_mode = "loopback".into();
        preflight_with(&loopback, count, count).unwrap();
        assert_eq!(touched.get(), 0);
    }

    #[test]
    fn audio_only_sessions_skip_the_camera() {
        let mut options = lan_options(AudioBackend::Alsa, VideoBackend::V4l2);
        options.audio_only = true;
        preflight_with(&options, || Ok(()), || panic!("camera not needed")).unwrap();
    }

    #[cfg(not(windows))]
    #[test]
    fn real_preflight_reports_a_missing_native_audio_backend() {
        // PortAudio/ASIO cannot load off Windows, so the real opener fails deterministically.
        let options = lan_options(AudioBackend::PortAudioAsio, VideoBackend::Diagnostic);
        let settings = crate::config::default_settings();
        assert!(matches!(
            preflight_devices(&settings, &options),
            Err(SessionError::AudioBackend(_))
        ));
    }
}
