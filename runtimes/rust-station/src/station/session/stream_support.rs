//! Small helpers for the interleaved stream loop, kept out of `stream.rs` to
//! bound its size.

use super::backends::SessionAudioBackend;
use super::realtime::raise_media_thread_priority;
use super::SessionResult;

/// Raises the media thread priority and records the outcome. A refusal is
/// reported, never fatal: the stream runs correctly at normal priority.
pub(super) fn note_realtime_priority(result: &mut SessionResult) {
    result.realtime_priority = Some(match raise_media_thread_priority() {
        Ok(applied) => applied,
        Err(error) => format!("unavailable: {error}"),
    });
}

/// Copies the audio backend's device-side counters into the session result.
pub(super) fn record_audio_backend_counters(
    result: &mut SessionResult,
    audio: Option<&SessionAudioBackend>,
) {
    result.audio_device_xruns = audio.and_then(SessionAudioBackend::xruns);
    if let Some(audio) = audio {
        result.audio_capture_backlog_drops = audio.capture_backlog_drops();
        result.audio_capture_timeouts = audio.capture_timeouts();
    }
}
