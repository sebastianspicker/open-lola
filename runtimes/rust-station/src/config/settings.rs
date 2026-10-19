//! Versioned station settings and compatibility loading for older JSON files.

pub const SETTINGS_SCHEMA_VERSION: u32 = 2;
pub const DEFAULT_CONTROL_PORT: u16 = 7000;
pub const DEFAULT_AUDIO_PORT: u16 = 19788;
pub const DEFAULT_VIDEO_PORT: u16 = 19798;
const MAX_FRAME_BYTES: u64 = 16 * 1024 * 1024;
const MAX_AUDIO_PCM_BYTES: u64 = 1_025;
const MAX_SESSION_QUEUE_BYTES: u64 = 256 * 1024 * 1024;

mod persistence;
mod types;

pub use persistence::{default_settings, load_settings, save_settings, SettingsError};
pub use types::*;

#[cfg(test)]
mod tests;
