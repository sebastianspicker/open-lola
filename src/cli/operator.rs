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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::cli::{Cli, Commands};
    use crate::config::save_settings;
    use clap::Parser;
    use tempfile::tempdir;

    #[test]
    fn connect_parser_maps_remote_role_and_receive_audio_only() {
        let cli = Cli::try_parse_from([
            "rusty-lola",
            "connect",
            "192.0.2.44",
            "--rx",
            "--audio-only",
            "--duration",
            "2.5",
        ])
        .unwrap();
        let Some(Commands::Connect { remote_ip, options }) = cli.cmd else {
            panic!("connect command did not parse");
        };
        assert_eq!(remote_ip, "192.0.2.44");
        let mapped = session_options(&options, "remote", &default_settings()).unwrap();
        assert_eq!(mapped.peer_mode, "remote");
        assert_eq!(mapped.duration_sec, Some(2.5));
        assert!(!mapped.stream_tx_audio);
        assert!(!mapped.stream_tx_video);
        assert!(mapped.stream_rx_audio);
        assert!(mapped.audio_only);
        assert!(!mapped.stream_tx_video && !mapped.stream_rx_video);
    }

    #[test]
    fn listen_parser_supports_explicit_stream_selection_and_continuous() {
        let cli = Cli::try_parse_from([
            "rusty-lola",
            "listen",
            "--continuous",
            "--duration",
            "1",
            "--rx-audio",
            "--tx-video",
        ])
        .unwrap();
        let Some(Commands::Listen { options }) = cli.cmd else {
            panic!("listen command did not parse");
        };
        assert!(options.continuous);
        let mapped = session_options(&options, "listen", &default_settings()).unwrap();
        assert_eq!(mapped.peer_mode, "listen");
        assert!(!mapped.stream_tx_audio);
        assert!(mapped.stream_rx_audio);
        assert!(mapped.stream_tx_video);
        assert!(!mapped.stream_rx_video);
    }

    #[test]
    fn conflicting_operator_direction_flags_are_rejected() {
        let cli = Cli::try_parse_from([
            "rusty-lola",
            "connect",
            "192.0.2.44",
            "--receive-only",
            "--tx-audio",
        ])
        .unwrap();
        let Some(Commands::Connect { options, .. }) = cli.cmd else {
            panic!("connect command did not parse");
        };
        assert!(session_options(&options, "remote", &default_settings()).is_err());
    }

    #[test]
    fn noncontinuous_cli_rejects_invalid_duration() {
        let cli = Cli::try_parse_from(["rusty-lola", "connect", "192.0.2.44", "--duration", "0"])
            .unwrap();
        let Some(Commands::Connect { options, .. }) = cli.cmd else {
            panic!("connect command did not parse");
        };
        let error = session_options(&options, "remote", &default_settings()).unwrap_err();
        assert!(error.contains("duration_sec must be finite and greater than zero"));
    }

    #[test]
    fn continuous_cli_requires_a_bounded_duration() {
        let mut options = SessionOptions::demo();
        options.peer_mode = "remote".into();
        let result = run_continuous(default_settings(), 1.0, None, options);
        assert!(matches!(
            result.failure,
            Some(crate::station::SessionError::Configuration(_))
        ));
    }

    #[test]
    fn operator_session_import_precedes_settings_and_positional_peer_wins_last() {
        let dir = tempdir().unwrap();
        let settings_path = dir.path().join("settings.json");
        let session_path = dir.path().join("LastSsn.ssn");
        let mut configured = default_settings();
        configured.network.remote_ip = "192.0.2.10".into();
        configured.video.camera_mode_id = "custom-mode".into();
        save_settings(&settings_path, &configured).unwrap();
        std::fs::write(
            &session_path,
            "[RemoteHost]\nRemoteIpAddr=192.0.2.44;0.0.0.0\n[AVBuffers]\nRemoteAudioBuffers=8;1\nRemoteVideoBuffers=0;0\n",
        )
        .unwrap();

        let settings = load_operator_settings(Some(&settings_path), Some(&session_path)).unwrap();
        assert_eq!(settings.network.remote_ip, "192.0.2.44");
        assert_eq!(settings.video.camera_mode_id, "custom-mode");
        assert_eq!(settings.network.audio_receive_queue_depth, 8);
        assert_eq!(settings.network.video_receive_queue_depth, 1);
        let cli = Cli::try_parse_from(["rusty-lola", "listen"]).unwrap();
        let Some(Commands::Listen { options }) = cli.cmd else {
            panic!("listen command did not parse");
        };
        let settings = apply_operator_overrides(settings, Some("192.0.2.99".into()), &options);
        assert_eq!(settings.network.remote_ip, "192.0.2.99");
    }

    #[test]
    fn connect_and_listen_accept_session_input() {
        let connect =
            Cli::try_parse_from(["rusty-lola", "connect", "192.0.2.44", "--session", "x.ssn"])
                .unwrap();
        let Some(Commands::Connect { options, .. }) = connect.cmd else {
            panic!("connect command did not parse");
        };
        assert_eq!(
            options.session.as_deref(),
            Some(std::path::Path::new("x.ssn"))
        );
        assert!(Cli::try_parse_from(["rusty-lola", "listen", "--session", "x.ssn"]).is_ok());
    }
}
