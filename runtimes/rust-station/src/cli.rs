//! rusty-lola command-line entry — full productive surface.

use crate::config::{AudioBackend, VideoBackend};
use crate::VERSION;
use clap::{Args, Parser, Subcommand, ValueEnum};
use std::path::PathBuf;

mod diagnostics;
mod handlers;
mod operator;
mod station;
pub use operator::{CliPeerMode, OperatorSessionArgs};
#[derive(Clone, Copy, Debug, ValueEnum)]
pub enum CliAudioBackend {
    #[value(name = "portaudio-asio", alias = "portaudio", alias = "asio")]
    PortAudioAsio,
    Alsa,
    #[value(alias = "software")]
    Diagnostic,
}

impl From<CliAudioBackend> for AudioBackend {
    fn from(value: CliAudioBackend) -> Self {
        match value {
            CliAudioBackend::PortAudioAsio => Self::PortAudioAsio,
            CliAudioBackend::Alsa => Self::Alsa,
            CliAudioBackend::Diagnostic => Self::Diagnostic,
        }
    }
}

#[derive(Clone, Copy, Debug, ValueEnum)]
pub enum CliVideoBackend {
    #[value(alias = "xiapi")]
    Ximea,
    V4l2,
    #[value(alias = "software")]
    Diagnostic,
}

impl From<CliVideoBackend> for VideoBackend {
    fn from(value: CliVideoBackend) -> Self {
        match value {
            CliVideoBackend::Ximea => Self::Ximea,
            CliVideoBackend::V4l2 => Self::V4l2,
            CliVideoBackend::Diagnostic => Self::Diagnostic,
        }
    }
}

#[derive(Parser, Debug)]
#[command(
    name = "rusty-lola",
    about = "rusty-lola (Rust) — LoLa-compatible low-latency A/V station",
    version = VERSION
)]
pub struct Cli {
    #[command(subcommand)]
    pub cmd: Option<Commands>,
}

/// Shared options for the equivalent `emulate` and `tester` lab commands.
#[derive(Args, Debug)]
pub struct EmulationArgs {
    #[arg(long)]
    pub mode: Option<String>,
    #[arg(long, default_value_t = 3)]
    pub frames: u32,
    #[arg(long, default_value_t = 5.0)]
    pub timeout: f64,
    #[arg(long)]
    pub compress: bool,
    #[arg(long)]
    pub list_modes: bool,
}

#[derive(Subcommand, Debug)]
pub enum Commands {
    /// Query LoLa control reachability without opening media devices.
    Status {
        peer: String,
        #[arg(long, default_value = "127.0.0.1")]
        local_ip: String,
        #[arg(long, default_value_t = 1)]
        sid: u32,
        #[arg(long, default_value_t = 7000)]
        port: u16,
        #[arg(long, default_value_t = 1.0)]
        timeout: f64,
    },
    /// Bounded synthetic bidirectional localhost UDP test.
    Selftest {
        #[arg(long, default_value_t = 0.25)]
        duration: f64,
    },
    /// Decode bounded offline PCAP or PCAPNG capture metadata.
    DecodePcap { input: PathBuf },
    /// Enumerate native audio/video capabilities without starting a session.
    Devices,
    /// Print identity/version
    Identity,
    /// ICMP/TCP reachability probe of a remote host
    CheckRemote {
        host: String,
        #[arg(long = "timeout-ms", default_value_t = 1000)]
        timeout_ms: u32,
        #[arg(long, default_value_t = 3)]
        count: u32,
    },
    /// CHECK→QUICKCONN→A/V→extras→DISCONNECT session
    Station {
        #[arg(long, default_value_t = 3.0)]
        timeout: f64,
        #[arg(long)]
        compress: bool,
        #[arg(long)]
        no_extras: bool,
        #[arg(long)]
        reject: bool,
        #[arg(long)]
        frames: Option<u32>,
        #[arg(long)]
        record: Option<PathBuf>,
        #[arg(long)]
        preview: Option<PathBuf>,
        #[arg(long)]
        settings: Option<PathBuf>,
        #[arg(long)]
        session: Option<PathBuf>,
        #[arg(long)]
        pcap: bool,
        #[arg(long)]
        camera_backend: Option<CliVideoBackend>,
        #[arg(long)]
        audio_backend: Option<CliAudioBackend>,
        #[arg(long, value_enum, default_value_t = CliPeerMode::Loopback)]
        peer_mode: CliPeerMode,
        #[arg(long)]
        duration: Option<f64>,
        #[arg(long)]
        interleaved: bool,
        #[arg(long)]
        preview_all: bool,
        #[arg(long)]
        pcap_raw: bool,
        #[arg(long)]
        pcap_device: Option<String>,
        #[arg(long)]
        precheck_reachable: bool,
        #[arg(long)]
        reachable_timeout_ms: Option<u32>,
        #[arg(long)]
        catalog: Option<PathBuf>,
        #[arg(long)]
        camera_mode_id: Option<String>,
    },
    /// Initiate one LoLa session to a remote IPv4 address on fixed LoLa ports.
    Connect {
        remote_ip: String,
        #[command(flatten)]
        options: OperatorSessionArgs,
    },
    /// Listen as the LoLa responder on the fixed LoLa ports.
    Listen {
        #[command(flatten)]
        options: OperatorSessionArgs,
    },
    /// Lab emulation (software modes E01–E08)
    Emulate {
        #[command(flatten)]
        args: EmulationArgs,
    },
    /// Alias of emulate
    Tester {
        #[command(flatten)]
        args: EmulationArgs,
    },
    /// Interactive station UI (or --headless controller)
    Ui {
        #[arg(long)]
        headless: bool,
        #[arg(long)]
        run_check: bool,
        #[arg(long)]
        run_connect: bool,
        #[arg(long, default_value_t = 5.0)]
        timeout: f64,
        #[arg(long, default_value_t = 3)]
        frames: u32,
        #[arg(long)]
        allow_multiple: bool,
        #[arg(long)]
        camera_backend: Option<CliVideoBackend>,
        #[arg(long)]
        audio_backend: Option<CliAudioBackend>,
    },
    /// Offline frame convert
    Convert {
        #[arg(long)]
        mode: String,
        #[arg(long = "in")]
        input: PathBuf,
        #[arg(long = "out")]
        output: PathBuf,
        #[arg(long, default_value = "BGGR")]
        pattern: String,
        #[arg(long = "bayer")]
        bayer: Option<String>,
        #[arg(long, default_value_t = 80)]
        quality: u8,
        #[arg(long = "jpeg-quality")]
        jpeg_quality: Option<u8>,
    },
    /// Split multichannel WAV into mono tracks
    Wavsplit {
        #[arg(long = "in")]
        in_file: Option<PathBuf>,
        /// Positional source (compat with earlier rust CLI)
        src: Option<PathBuf>,
        #[arg(long)]
        out: Option<PathBuf>,
        #[arg(long = "out-dir")]
        out_dir: Option<PathBuf>,
    },
    /// Create an Open-Lola JSON session profile
    SessionProfile {
        #[arg(long)]
        out: PathBuf,
        #[arg(long, default_value = "127.0.0.1")]
        remote: String,
        #[arg(long = "mode", default_value = "009")]
        camera_mode_id: String,
        #[arg(long, default_value_t = 1)]
        sid: i64,
    },
    /// Multi-SID software sessions (sequential or concurrent)
    MultiSid {
        #[arg(long, default_value = "1,2")]
        sids: String,
        #[arg(long, default_value_t = 5.0)]
        timeout: f64,
        #[arg(long, default_value_t = 2)]
        frames: u32,
        #[arg(long)]
        concurrent: bool,
        #[arg(long, default_value = "127.0.0.1")]
        remote: String,
    },
}

pub fn run(argv: Option<Vec<String>>) -> i32 {
    let cli = if let Some(args) = argv {
        match Cli::try_parse_from(args) {
            Ok(c) => c,
            Err(e) => {
                let _ = e.print();
                return if e.use_stderr() { 2 } else { 0 };
            }
        }
    } else {
        Cli::parse()
    };

    handlers::run_command(cli.cmd)
}

#[cfg(test)]
mod tests {
    use super::*;
    use clap::CommandFactory;
    use std::collections::BTreeSet;

    #[test]
    fn emulate_and_tester_accept_the_same_emulation_options() {
        for command in ["emulate", "tester"] {
            let parsed = Cli::try_parse_from([
                "rusty-lola",
                command,
                "--mode",
                "E05",
                "--frames",
                "4",
                "--timeout",
                "1.5",
                "--compress",
                "--list-modes",
            ])
            .expect("parse emulation alias");
            let args = match parsed.cmd.expect("subcommand") {
                Commands::Emulate { args } | Commands::Tester { args } => args,
                _ => panic!("expected emulation command"),
            };
            assert_eq!(args.mode.as_deref(), Some("E05"));
            assert_eq!(args.frames, 4);
            assert_eq!(args.timeout, 1.5);
            assert!(args.compress);
            assert!(args.list_modes);
        }
    }

    #[test]
    fn emulate_and_tester_help_expose_the_same_option_set() {
        let command = Cli::command();
        let argument_ids = |name: &str| -> BTreeSet<String> {
            command
                .find_subcommand(name)
                .expect("emulation subcommand")
                .get_arguments()
                .map(|argument| argument.get_id().to_string())
                .collect()
        };
        assert_eq!(argument_ids("emulate"), argument_ids("tester"));
    }
}
