//! Integration tests driving shipped rusty_lola library/CLI entry points.

use rusty_lola::audio::probe_portaudio;
use rusty_lola::audio::write_pcm_fixture;
use rusty_lola::cli::run as cli_run;
use rusty_lola::config::{
    default_settings, AudioBackend, VideoBackend, DEFAULT_AUDIO_PORT, DEFAULT_CONTROL_PORT,
    DEFAULT_VIDEO_PORT,
};
use rusty_lola::net::{check_reachable, probe_pcap, MediaKind};
use rusty_lola::station::{
    apply_tx_audio_level, audio_params_match, centered_crop_or_scale, create_sid_profiles,
    estimate_tx_bandwidth_mbps, incomplete_frame_ok, layout_geometry, list_emulation_modes,
    load_session_profile, multi_camera_index, run_default_session, run_emulation, run_multi_sid,
    run_reject_session, run_sequential_sessions, run_session, save_session_profile,
    set_process_priority, LiveStationService, NetworkMonitor, SessionOptions, SessionProfile,
    SessionTabBoard,
};
use rusty_lola::ui::StationUIController;
use rusty_lola::video::{apply_color_gains, probe_ximea};
use rusty_lola::{IDENTITY, VERSION};
use std::fs;
use std::thread;
use std::time::Duration;
use tempfile::tempdir;

fn diagnostic_controller() -> StationUIController {
    let mut settings = default_settings();
    settings.audio.backend = AudioBackend::Diagnostic;
    settings.video.backend = VideoBackend::Diagnostic;
    settings.video.width = 64;
    settings.video.height = 48;
    settings.video.camera_mode_id = "diagnostic-64x48".into();
    StationUIController::new(Some(settings))
}

fn wait_for_live_streaming(controller: &StationUIController) {
    let deadline = std::time::Instant::now() + Duration::from_secs(8);
    while std::time::Instant::now() < deadline {
        if controller.live_report()["status"] == "streaming" {
            return;
        }
        thread::sleep(Duration::from_millis(20));
    }
    panic!(
        "live runtime did not reach streaming: {}",
        controller.live_report()
    );
}

#[path = "full_parity/native_probes.rs"]
mod native_probes;
#[path = "full_parity/session_runtime.rs"]
mod session_runtime;
#[path = "full_parity/ui_cli.rs"]
mod ui_cli;
