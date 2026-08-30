//! rusty-lola command-line entry — full productive surface.

use crate::audio::split_wav;
use crate::config::{
    default_settings, AudioBackend, MediaTransportKind, VideoBackend, DEFAULT_AUDIO_PORT,
    DEFAULT_CONTROL_PORT, DEFAULT_VIDEO_PORT,
};
use crate::net::check_reachable;
use crate::station::{
    find_emulation_mode, list_emulation_modes, run_emulation, run_multi_sid, run_reject_session,
    run_session, save_session_profile, SessionOptions, SessionProfile,
};
use crate::ui::{run_interactive_ui, StationUIController};
use crate::video::{convert_path, BayerPattern, ConvertMode};
use crate::{IDENTITY, VERSION};
use clap::{Parser, Subcommand, ValueEnum};
use std::path::PathBuf;

mod operator;
mod station;
use operator::run_operator_command;
pub use operator::{CliPeerMode, OperatorSessionArgs};
use station::load_station_settings;
#[derive(Clone, Copy, Debug, ValueEnum)]
pub enum CliAudioBackend {
    #[value(name = "portaudio-asio", alias = "portaudio", alias = "asio")]
    PortAudioAsio,
    #[value(alias = "software")]
    Diagnostic,
}

impl From<CliAudioBackend> for AudioBackend {
    fn from(value: CliAudioBackend) -> Self {
        match value {
            CliAudioBackend::PortAudioAsio => Self::PortAudioAsio,
            CliAudioBackend::Diagnostic => Self::Diagnostic,
        }
    }
}

#[derive(Clone, Copy, Debug, ValueEnum)]
pub enum CliVideoBackend {
    #[value(alias = "xiapi")]
    Ximea,
    #[value(alias = "software")]
    Diagnostic,
}

impl From<CliVideoBackend> for VideoBackend {
    fn from(value: CliVideoBackend) -> Self {
        match value {
            CliVideoBackend::Ximea => Self::Ximea,
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

#[derive(Subcommand, Debug)]
pub enum Commands {
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
        #[arg(long)]
        mode: Option<String>,
        #[arg(long, default_value_t = 3)]
        frames: u32,
        #[arg(long, default_value_t = 5.0)]
        timeout: f64,
        #[arg(long)]
        compress: bool,
        #[arg(long)]
        list_modes: bool,
    },
    /// Alias of emulate
    Tester {
        #[arg(long)]
        mode: Option<String>,
        #[arg(long, default_value_t = 3)]
        frames: u32,
        #[arg(long, default_value_t = 5.0)]
        timeout: f64,
        #[arg(long)]
        compress: bool,
        #[arg(long)]
        list_modes: bool,
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

    match cli.cmd {
        None => {
            println!("{IDENTITY} v{VERSION}");
            println!(
                "default ports control={DEFAULT_CONTROL_PORT} audio={DEFAULT_AUDIO_PORT} video={DEFAULT_VIDEO_PORT}"
            );
            println!(
                "commands: identity | station | connect | listen | emulate | tester | convert | wavsplit | ui | check-remote | session-profile | multi-sid"
            );
            0
        }
        Some(Commands::Identity) => {
            println!("{IDENTITY} v{VERSION}");
            0
        }
        Some(Commands::CheckRemote {
            host,
            timeout_ms,
            count,
        }) => {
            let r = check_reachable(&host, timeout_ms, count);
            println!("{}", serde_json::to_string_pretty(&r.to_json()).unwrap());
            if r.ok {
                0
            } else {
                1
            }
        }
        Some(Commands::Station {
            timeout,
            compress,
            no_extras,
            reject,
            frames,
            record,
            preview,
            settings,
            session,
            pcap,
            camera_backend,
            audio_backend,
            peer_mode,
            duration,
            interleaved,
            preview_all,
            pcap_raw,
            pcap_device,
            precheck_reachable,
            reachable_timeout_ms,
            catalog,
            camera_mode_id,
        }) => {
            let mut s = match load_station_settings(settings.as_deref(), session.as_deref()) {
                Ok(settings) => settings,
                Err(error) => {
                    eprintln!("station configuration error: {error}");
                    return 1;
                }
            };
            if let Some(mode) = camera_mode_id {
                s.video.camera_mode_id = mode;
            }
            if let Some(backend) = camera_backend {
                s.video.backend = backend.into();
            }
            if let Some(backend) = audio_backend {
                s.audio.backend = backend.into();
            }
            if compress {
                s.video.compression = true;
            }
            if let Some(dir) = &record {
                s.recording.enabled = true;
                s.recording.path = dir.display().to_string();
            }

            let result = if reject {
                run_reject_session(s, timeout)
            } else {
                let mut opts = SessionOptions::demo();
                opts.stream_frames = frames.unwrap_or(3).max(1);
                opts.control_extras = !no_extras;
                opts.record = s.recording.enabled;
                opts.record_dir = s
                    .recording
                    .enabled
                    .then(|| PathBuf::from(&s.recording.path));
                opts.preview_dir = preview;
                opts.preview_all_frames = preview_all;
                opts.peer_mode = peer_mode.as_str().into();
                opts.duration_sec = duration;
                opts.interleaved_av = interleaved;
                opts.camera_backend = s.video.backend;
                opts.audio_backend = s.audio.backend;
                opts.media_transport = Some(if pcap || pcap_raw {
                    MediaTransportKind::Npcap
                } else {
                    s.network.media_transport
                });
                opts.pcap_device = pcap_device;
                opts.precheck_reachable = precheck_reachable.then_some(true);
                opts.reachability_timeout_ms = reachable_timeout_ms;
                if let Some(c) = catalog {
                    opts.catalog_path = Some(c);
                }
                run_session(s, timeout, opts)
            };
            println!(
                "{}",
                serde_json::to_string_pretty(&result.to_json()).unwrap()
            );
            if result.ok {
                0
            } else {
                eprintln!("station failed: {}", result.error);
                1
            }
        }
        Some(Commands::Connect { remote_ip, options }) => {
            run_operator_command(Some(remote_ip), "remote", options)
        }
        Some(Commands::Listen { options }) => run_operator_command(None, "listen", options),
        Some(Commands::Emulate {
            mode,
            frames,
            timeout,
            compress,
            list_modes,
        })
        | Some(Commands::Tester {
            mode,
            frames,
            timeout,
            compress,
            list_modes,
        }) => {
            if list_modes {
                for m in list_emulation_modes() {
                    println!(
                        "{} {}x{} {} — {}",
                        m.mode_id, m.width, m.height, m.pixel_format, m.description
                    );
                }
                return 0;
            }
            match run_emulation(mode.as_deref(), timeout, frames, compress) {
                Ok(r) => {
                    println!("{}", serde_json::to_string_pretty(&r.to_json()).unwrap());
                    if r.ok {
                        0
                    } else {
                        1
                    }
                }
                Err(e) => {
                    eprintln!("{e}");
                    // still validate mode exists for unknown
                    if find_emulation_mode(mode.as_deref()).is_err() {
                        2
                    } else {
                        1
                    }
                }
            }
        }
        Some(Commands::Ui {
            headless,
            run_check,
            run_connect,
            timeout,
            frames,
            allow_multiple: _,
            camera_backend,
            audio_backend,
        }) => {
            if headless || run_check || run_connect {
                let mut settings = default_settings();
                if let Some(backend) = camera_backend {
                    settings.video.backend = backend.into();
                }
                if settings.video.backend == VideoBackend::Diagnostic {
                    // Keep the headless diagnostic lane deterministic and
                    // small enough for its bounded loopback UDP queues. The
                    // interactive UI still exposes the configured dimensions.
                    settings.video.width = 160;
                    settings.video.height = 120;
                    settings.video.camera_mode_id = "diagnostic-160x120".into();
                }
                if let Some(backend) = audio_backend {
                    settings.audio.backend = backend.into();
                }
                let mut ctrl = StationUIController::new(Some(settings));
                let report = ctrl.run_headless(run_check, run_connect, timeout, frames);
                println!("{}", serde_json::to_string_pretty(&report).unwrap());
                if report.get("ok").and_then(|v| v.as_bool()).unwrap_or(false) {
                    0
                } else {
                    1
                }
            } else {
                match run_interactive_ui() {
                    Ok(()) => 0,
                    Err(e) => {
                        eprintln!("{e}");
                        1
                    }
                }
            }
        }
        Some(Commands::Convert {
            mode,
            input,
            output,
            pattern,
            bayer,
            quality,
            jpeg_quality,
        }) => {
            let mode = match ConvertMode::parse(&mode) {
                Some(m) => m,
                None => {
                    eprintln!("unknown mode {mode}; use debayer|bgr2rgb|bmp2jpeg");
                    return 2;
                }
            };
            let pat = bayer.as_deref().unwrap_or(&pattern);
            let pattern = BayerPattern::parse(pat).unwrap_or(BayerPattern::Bggr);
            let q = jpeg_quality.unwrap_or(quality);
            match convert_path(&input, &output, mode, pattern, q) {
                Ok(paths) => {
                    for p in paths {
                        println!("{}", p.display());
                    }
                    0
                }
                Err(e) => {
                    eprintln!("convert error: {e}");
                    1
                }
            }
        }
        Some(Commands::Wavsplit {
            in_file,
            src,
            out,
            out_dir,
        }) => {
            let source = in_file.or(src);
            let Some(source) = source else {
                eprintln!("wavsplit requires --in or positional src");
                return 2;
            };
            let out = out_dir.or(out);
            match split_wav(&source, out.as_deref()) {
                Ok(paths) => {
                    for p in paths {
                        println!("{}", p.display());
                    }
                    0
                }
                Err(e) => {
                    eprintln!("wavsplit error: {e}");
                    1
                }
            }
        }
        Some(Commands::SessionProfile {
            out,
            remote,
            camera_mode_id,
            sid,
        }) => {
            let p = SessionProfile {
                remote_ip: remote,
                camera_mode_id,
                session_id: sid,
                ..SessionProfile::default()
            };
            match save_session_profile(&out, &p) {
                Ok(path) => {
                    println!("{}", path.display());
                    0
                }
                Err(e) => {
                    eprintln!("session-profile error: {e}");
                    1
                }
            }
        }
        Some(Commands::MultiSid {
            sids,
            timeout,
            frames,
            concurrent,
            remote,
        }) => {
            let parsed: Result<Vec<i64>, _> =
                sids.split(',').map(|s| s.trim().parse::<i64>()).collect();
            let ids = match parsed {
                Ok(v) if !v.is_empty() => v,
                _ => {
                    eprintln!("invalid --sids {sids}");
                    return 2;
                }
            };
            match run_multi_sid(&ids, &remote, timeout, frames, concurrent) {
                Ok(r) => {
                    println!("{}", serde_json::to_string_pretty(&r.to_json()).unwrap());
                    if r.ok {
                        0
                    } else {
                        1
                    }
                }
                Err(e) => {
                    eprintln!("multi-sid error: {e}");
                    1
                }
            }
        }
    }
}
