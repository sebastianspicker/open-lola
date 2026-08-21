//! Explicit operator-facing connect/listen command mapping.

use super::{CliAudioBackend, CliVideoBackend};
use crate::config::{default_settings, load_settings, StationSettings};
use crate::station::{
    apply_profile_to_settings, load_session_input, run_session, SessionConfig, SessionOptions,
    SessionResult, SessionRuntime,
};
use clap::{Args, ValueEnum};
use std::path::PathBuf;
use std::{thread, time::Duration};

#[derive(Clone, Copy, Debug, ValueEnum)]
pub enum CliPeerMode {
    Loopback,
    Remote,
    Listen,
}

impl CliPeerMode {
    pub(super) const fn as_str(self) -> &'static str {
        match self {
            Self::Loopback => "loopback",
            Self::Remote => "remote",
            Self::Listen => "listen",
        }
    }
}

/// Shared operator controls for a direct LoLa initiator or responder.
#[derive(Args, Debug, Clone)]
pub struct OperatorSessionArgs {
    #[arg(long, default_value_t = 5.0)]
    timeout: f64,
    #[arg(long, default_value_t = 3)]
    frames: u32,
    #[arg(long)]
    duration: Option<f64>,
    /// Keep one negotiated lifecycle active. With --duration it is stopped
    /// through SessionRuntime after that bounded interval.
    #[arg(long)]
    continuous: bool,
    #[arg(long)]
    settings: Option<PathBuf>,
    /// Open-Lola JSON session or documented recoverable LastSsn `.ssn` input.
    #[arg(long)]
    session: Option<PathBuf>,
    #[arg(long)]
    camera_backend: Option<CliVideoBackend>,
    #[arg(long)]
    audio_backend: Option<CliAudioBackend>,
    #[arg(long)]
    no_extras: bool,
    /// Receive streams only; disables both transmit streams.
    #[arg(long, alias = "rx")]
    receive_only: bool,
    #[arg(long)]
    audio_only: bool,
    /// When any per-stream flag is supplied, only the named streams are enabled.
    #[arg(long)]
    tx_audio: bool,
    #[arg(long)]
    rx_audio: bool,
    #[arg(long)]
    tx_video: bool,
    #[arg(long)]
    rx_video: bool,
}

pub(super) fn run_operator_command(
    remote_ip: Option<String>,
    peer_mode: &str,
    args: OperatorSessionArgs,
) -> i32 {
    let mut settings =
        match load_operator_settings(args.settings.as_deref(), args.session.as_deref()) {
            Ok(settings) => settings,
            Err(error) => {
                eprintln!("settings load error: {error}");
                return 1;
            }
        };
    settings = apply_operator_overrides(settings, remote_ip, &args);
    let options = match session_options(&args, peer_mode, &settings) {
        Ok(options) => options,
        Err(error) => {
            eprintln!("operator options error: {error}");
            return 2;
        }
    };
    let result = if args.continuous {
        run_continuous(settings, args.timeout, args.duration, options)
    } else {
        run_session(settings, args.timeout, options)
    };
    println!(
        "{}",
        serde_json::to_string_pretty(&result.to_json()).unwrap()
    );
    i32::from(!result.ok)
}

fn apply_operator_overrides(
    mut settings: StationSettings,
    remote_ip: Option<String>,
    args: &OperatorSessionArgs,
) -> StationSettings {
    if let Some(remote_ip) = remote_ip {
        settings.network.remote_ip = remote_ip;
    }
    if let Some(backend) = args.camera_backend {
        settings.video.backend = backend.into();
    }
    if let Some(backend) = args.audio_backend {
        settings.audio.backend = backend.into();
    }
    settings
}

fn load_operator_settings(
    settings_path: Option<&std::path::Path>,
    session_path: Option<&std::path::Path>,
) -> Result<StationSettings, String> {
    let mut settings = match settings_path {
        Some(path) if path.is_file() => load_settings(path).map_err(|error| error.to_string()),
        Some(path) => Err(format!("settings file does not exist: {}", path.display())),
        None => Ok(default_settings()),
    }?;
    if let Some(path) = session_path {
        let profile = load_session_input(path).map_err(|error| error.to_string())?;
        apply_profile_to_settings(&mut settings, &profile);
    }
    Ok(settings)
}

fn session_options(
    args: &OperatorSessionArgs,
    peer_mode: &str,
    settings: &StationSettings,
) -> Result<SessionOptions, String> {
    if args.receive_only && (args.tx_audio || args.tx_video) {
        return Err("--receive-only cannot be combined with a transmit stream flag".into());
    }
    if args.audio_only && (args.tx_video || args.rx_video) {
        return Err("--audio-only cannot be combined with a video stream flag".into());
    }
    let mut options = SessionOptions::demo();
    options.peer_mode = peer_mode.into();
    options.stream_frames = args.frames.max(1);
    options.duration_sec = args.duration;
    options.control_extras = !args.no_extras;
    options.camera_backend = settings.video.backend;
    options.audio_backend = settings.audio.backend;
    options.audio_only = args.audio_only;
    if args.receive_only {
        options.stream_tx_audio = false;
        options.stream_tx_video = false;
    }
    if args.tx_audio || args.rx_audio || args.tx_video || args.rx_video {
        options.stream_tx_audio = args.tx_audio;
        options.stream_rx_audio = args.rx_audio;
        options.stream_tx_video = args.tx_video;
        options.stream_rx_video = args.rx_video;
    }
    if options.audio_only {
        options.stream_tx_video = false;
        options.stream_rx_video = false;
    }
    if !options.stream_tx_audio
        && !options.stream_rx_audio
        && !options.stream_tx_video
        && !options.stream_rx_video
    {
        return Err("at least one stream direction must be enabled".into());
    }
    options
        .validate_duration()
        .map_err(|error| error.to_string())?;
    Ok(options)
}

fn run_continuous(
    settings: StationSettings,
    timeout: f64,
    duration: Option<f64>,
    options: SessionOptions,
) -> SessionResult {
    let Some(duration) = duration else {
        return SessionResult {
            error: "--continuous requires --duration so the CLI owns a bounded shutdown".into(),
            failure: Some(crate::station::SessionError::Configuration(
                "continuous CLI session requires a duration".into(),
            )),
            ..Default::default()
        };
    };
    if !duration.is_finite() || duration <= 0.0 {
        return SessionResult {
            error: format!("duration must be finite and greater than zero, got {duration}"),
            failure: Some(crate::station::SessionError::Configuration(
                "invalid continuous duration".into(),
            )),
            ..Default::default()
        };
    }
    let runtime = SessionRuntime::new();
    let handle = match runtime.start(SessionConfig::new(settings, timeout, options)) {
        Ok(handle) => handle,
        Err(error) => {
            return SessionResult {
                error: error.to_string(),
                failure: Some(error),
                ..Default::default()
            }
        }
    };
    thread::sleep(Duration::from_secs_f64(duration));
    handle.stop();
    let snapshot = handle.wait();
    snapshot.result.unwrap_or_else(|| SessionResult {
        error: snapshot
            .error
            .unwrap_or_else(|| "session runtime exited without a result".into()),
        failure: snapshot.failure,
        ..Default::default()
    })
}
