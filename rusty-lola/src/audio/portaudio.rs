//! Strict PortAudio/ASIO backend, probe, and shipping helpers.
//!
//! PortAudio is process-global and not thread-safe for concurrent LoadLibrary /
//! Pa_Initialize / FreeLibrary. The extracted modules retain its never-unloaded
//! singleton and serialize every entry point behind `pa_lock`.

use libloading::Library;
use serde_json::{json, Value};
use std::cell::UnsafeCell;
use std::ffi::CStr;
use std::hint::spin_loop;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, AtomicU64, AtomicUsize, Ordering};
use std::sync::{Arc, Mutex, MutexGuard, OnceLock};
use thiserror::Error;

mod asio;
mod callback;
mod devices;
mod diagnostic;
mod ffi;
mod strict;

pub use callback::PortAudioCallbackStats;
pub use devices::{load_portaudio, probe_portaudio};
pub use devices::{
    AudioBackendInfo, PortAudioConfig, PortAudioDeviceInfo, PortAudioDeviceSelector,
    PortAudioError, PortAudioLibrary, PortAudioResult, PortAudioTransferMode,
};
pub use diagnostic::ensure_shipped_portaudio_dll;
pub use strict::{open_portaudio_strict, StrictPortAudio};

#[cfg(test)]
mod tests;
