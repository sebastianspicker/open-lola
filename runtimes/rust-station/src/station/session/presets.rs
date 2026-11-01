//! Ready-made session configurations: expected rejection and the default demo run.

use super::runner::run_session;
use super::{SessionOptions, SessionResult};
use crate::config::{default_settings, StationSettings};

pub fn run_reject_session(settings: StationSettings, timeout: f64) -> SessionResult {
    let mut options = SessionOptions::demo();
    options.expected_rejection = true;
    options.peer_reject = true;
    options.control_extras = false;
    options.stream_frames = 1;
    run_session(settings, timeout, options)
}

pub fn run_default_session(
    timeout: f64,
    frames: u32,
    compress: bool,
    extras: bool,
) -> SessionResult {
    let mut settings = default_settings();
    settings.video.compression = compress;
    let mut options = SessionOptions::demo();
    options.stream_frames = frames.max(1);
    options.control_extras = extras;
    run_session(settings, timeout, options)
}
