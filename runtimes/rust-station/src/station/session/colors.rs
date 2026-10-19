//! Which colour gains a session may apply: XIMEA's shipped gains never reach other cameras.

use super::SessionOptions;
use crate::config::{load_ximea_colors, ColorSettings, VideoBackend};
use crate::shipped_ximea_colors;

/// Caller-supplied gains always apply; the shipped `XimeaColors.ini` gains apply only
/// to the XIMEA backend, so V4L2 and diagnostic cameras get no colour cast.
pub(super) fn session_color_settings(
    options: &SessionOptions,
    load_shipped: impl FnOnce() -> Option<ColorSettings>,
) -> Option<ColorSettings> {
    if !options.apply_color {
        return None;
    }
    options.color_settings.clone().or_else(|| {
        (options.camera_backend == VideoBackend::Ximea)
            .then(load_shipped)
            .flatten()
    })
}

/// The shipped XIMEA gains, when the file exists and parses.
pub(super) fn load_shipped_colors() -> Option<ColorSettings> {
    let path = shipped_ximea_colors();
    path.is_file()
        .then(|| load_ximea_colors(path).ok())
        .flatten()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn gains(red_gain: i32) -> ColorSettings {
        ColorSettings {
            red_gain,
            green_gain: 0,
            blue_gain: 0,
            gain_all: 0,
            luminosity: 0,
            chromaticity: 0,
            bad_pixels_correction: 0,
            raw_color_correction: 0,
        }
    }

    fn options(backend: VideoBackend, apply: bool) -> SessionOptions {
        let mut options = SessionOptions::demo();
        options.camera_backend = backend;
        options.apply_color = apply;
        options
    }

    #[test]
    fn shipped_gains_apply_only_to_the_ximea_backend() {
        let shipped = || Some(gains(7));
        assert_eq!(
            session_color_settings(&options(VideoBackend::Ximea, true), shipped),
            Some(gains(7))
        );
        for backend in [VideoBackend::V4l2, VideoBackend::Diagnostic] {
            assert_eq!(
                session_color_settings(&options(backend, true), shipped),
                None
            );
        }
    }

    #[test]
    fn explicit_gains_and_the_apply_flag_are_respected() {
        let mut explicit = options(VideoBackend::V4l2, true);
        explicit.color_settings = Some(gains(3));
        assert_eq!(session_color_settings(&explicit, || None), Some(gains(3)));
        let off = options(VideoBackend::Ximea, false);
        assert_eq!(session_color_settings(&off, || Some(gains(7))), None);
    }
}
