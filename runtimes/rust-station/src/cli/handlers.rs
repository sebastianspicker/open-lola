//! Private typed handlers for the stable rusty-lola command surface.

use super::{
    station::load_station_settings, CliAudioBackend, CliPeerMode, CliVideoBackend, Commands,
    EmulationArgs,
};
use crate::audio::split_wav;
use crate::config::{
    default_settings, MediaTransportKind, VideoBackend, DEFAULT_AUDIO_PORT, DEFAULT_CONTROL_PORT,
    DEFAULT_VIDEO_PORT,
};
use crate::net::check_reachable;
use crate::station::{
    find_emulation_mode, list_emulation_modes, run_emulation, run_multi_sid, run_reject_session,
    run_session, save_session_profile, SessionOptions, SessionProfile,
};
use crate::ui::{run_interactive_ui, StationUIController};
use crate::video::{convert_path, BayerPattern, ConvertMode};
use crate::IDENTITY;
use crate::VERSION;
use std::path::PathBuf;

use super::operator::run_operator_command;

pub(super) fn run_command(command: Option<Commands>) -> i32 {
    match command {
        Some(Commands::Status {
            peer,
            local_ip,
            sid,
            port,
            timeout,
        }) => super::diagnostics::print_result(super::diagnostics::status(
            &peer, &local_ip, sid, port, timeout,
        )),
        Some(Commands::Selftest { duration }) => {
            super::diagnostics::print_result(super::diagnostics::selftest(duration))
        }
        Some(Commands::DecodePcap { input }) => super::diagnostics::print_result(
            crate::tools::capture::decode_capture(&input).and_then(|summary| {
                serde_json::to_value(summary).map_err(|error| error.to_string())
            }),
        ),
        Some(Commands::Devices) => super::diagnostics::print_result(super::diagnostics::devices()),
        None => default_command(),
        Some(Commands::Identity) => identity_command(),
        Some(Commands::CheckRemote {
            host,
            timeout_ms,
            count,
        }) => check_remote_command(host, timeout_ms, count),
        Some(command @ Commands::Station { .. }) => station_command(command),
        Some(Commands::Connect { remote_ip, options }) => {
            run_operator_command(Some(remote_ip), "remote", options)
        }
        Some(Commands::Listen { options }) => run_operator_command(None, "listen", options),
        Some(Commands::Emulate { args }) | Some(Commands::Tester { args }) => {
            emulation_command(args)
        }
        Some(command @ Commands::Ui { .. }) => ui_command(command),
        Some(command @ Commands::Convert { .. }) => convert_command(command),
        Some(command @ Commands::Wavsplit { .. }) => wavsplit_command(command),
        Some(command @ Commands::SessionProfile { .. }) => session_profile_command(command),
        Some(command @ Commands::MultiSid { .. }) => multi_sid_command(command),
    }
}

fn default_command() -> i32 {
    println!("{IDENTITY} v{VERSION}");
    println!(
        "default ports control={DEFAULT_CONTROL_PORT} audio={DEFAULT_AUDIO_PORT} video={DEFAULT_VIDEO_PORT}"
    );
    println!(
        "commands: identity | station | connect | listen | emulate | tester | convert | wavsplit | ui | check-remote | session-profile | multi-sid"
    );
    0
}

fn identity_command() -> i32 {
    println!("{IDENTITY} v{VERSION}");
    0
}

fn check_remote_command(host: String, timeout_ms: u32, count: u32) -> i32 {
    let report = check_reachable(&host, timeout_ms, count);
    println!(
        "{}",
        serde_json::to_string_pretty(&report.to_json()).unwrap()
    );
    i32::from(!report.ok)
}

fn station_command(command: Commands) -> i32 {
    let Commands::Station {
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
    } = command
    else {
        unreachable!("station handler receives only the station command");
    };
    let mut settings = match load_station_settings(settings.as_deref(), session.as_deref()) {
        Ok(settings) => settings,
        Err(error) => {
            eprintln!("station configuration error: {error}");
            return 1;
        }
    };
    apply_station_overrides(
        &mut settings,
        camera_mode_id,
        camera_backend,
        audio_backend,
        compress,
        record.as_ref(),
    );
    let result = if reject {
        run_reject_session(settings, timeout)
    } else {
        run_station_session(
            settings,
            timeout,
            frames,
            no_extras,
            preview,
            peer_mode,
            duration,
            interleaved,
            preview_all,
            pcap || pcap_raw,
            pcap_device,
            precheck_reachable,
            reachable_timeout_ms,
            catalog,
        )
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

fn apply_station_overrides(
    settings: &mut crate::config::StationSettings,
    camera_mode_id: Option<String>,
    camera_backend: Option<CliVideoBackend>,
    audio_backend: Option<CliAudioBackend>,
    compress: bool,
    record: Option<&PathBuf>,
) {
    if let Some(mode) = camera_mode_id {
        settings.video.camera_mode_id = mode;
    }
    if let Some(backend) = camera_backend {
        settings.video.backend = backend.into();
    }
    if let Some(backend) = audio_backend {
        settings.audio.backend = backend.into();
    }
    if compress {
        settings.video.compression = true;
    }
    if let Some(directory) = record {
        settings.recording.enabled = true;
        settings.recording.path = directory.display().to_string();
    }
}

#[allow(clippy::too_many_arguments)]
fn run_station_session(
    settings: crate::config::StationSettings,
    timeout: f64,
    frames: Option<u32>,
    no_extras: bool,
    preview: Option<PathBuf>,
    peer_mode: CliPeerMode,
    duration: Option<f64>,
    interleaved: bool,
    preview_all: bool,
    use_pcap: bool,
    pcap_device: Option<String>,
    precheck_reachable: bool,
    reachable_timeout_ms: Option<u32>,
    catalog: Option<PathBuf>,
) -> crate::station::SessionResult {
    let mut options = SessionOptions::demo();
    options.stream_frames = frames.unwrap_or(3).max(1);
    options.control_extras = !no_extras;
    options.record = settings.recording.enabled;
    options.record_dir = settings
        .recording
        .enabled
        .then(|| PathBuf::from(&settings.recording.path));
    options.preview_dir = preview;
    options.preview_all_frames = preview_all;
    options.peer_mode = peer_mode.as_str().into();
    options.duration_sec = duration;
    options.interleaved_av = interleaved;
    options.camera_backend = settings.video.backend;
    options.audio_backend = settings.audio.backend;
    options.media_transport = Some(if use_pcap {
        MediaTransportKind::Npcap
    } else {
        settings.network.media_transport
    });
    options.pcap_device = pcap_device;
    options.precheck_reachable = precheck_reachable.then_some(true);
    options.reachability_timeout_ms = reachable_timeout_ms;
    options.catalog_path = catalog;
    run_session(settings, timeout, options)
}

fn emulation_command(args: EmulationArgs) -> i32 {
    let EmulationArgs {
        mode,
        frames,
        timeout,
        compress,
        list_modes,
    } = args;
    if list_modes {
        for mode in list_emulation_modes() {
            println!(
                "{} {}x{} {} — {}",
                mode.mode_id, mode.width, mode.height, mode.pixel_format, mode.description
            );
        }
        return 0;
    }
    match run_emulation(mode.as_deref(), timeout, frames, compress) {
        Ok(report) => {
            println!(
                "{}",
                serde_json::to_string_pretty(&report.to_json()).unwrap()
            );
            i32::from(!report.ok)
        }
        Err(error) => {
            eprintln!("{error}");
            i32::from(find_emulation_mode(mode.as_deref()).is_err()) + 1
        }
    }
}

fn ui_command(command: Commands) -> i32 {
    let Commands::Ui {
        headless,
        run_check,
        run_connect,
        timeout,
        frames,
        allow_multiple: _,
        camera_backend,
        audio_backend,
    } = command
    else {
        unreachable!("UI handler receives only the UI command");
    };
    if headless || run_check || run_connect {
        return headless_ui_command(
            run_check,
            run_connect,
            timeout,
            frames,
            camera_backend,
            audio_backend,
        );
    }
    match run_interactive_ui() {
        Ok(()) => 0,
        Err(error) => {
            eprintln!("{error}");
            1
        }
    }
}

fn headless_ui_command(
    run_check: bool,
    run_connect: bool,
    timeout: f64,
    frames: u32,
    camera_backend: Option<CliVideoBackend>,
    audio_backend: Option<CliAudioBackend>,
) -> i32 {
    let mut settings = default_settings();
    if let Some(backend) = camera_backend {
        settings.video.backend = backend.into();
    }
    if settings.video.backend == VideoBackend::Diagnostic {
        settings.video.width = 160;
        settings.video.height = 120;
        settings.video.camera_mode_id = "diagnostic-160x120".into();
    }
    if let Some(backend) = audio_backend {
        settings.audio.backend = backend.into();
    }
    let mut controller = StationUIController::new(Some(settings));
    let report = controller.run_headless(run_check, run_connect, timeout, frames);
    println!("{}", serde_json::to_string_pretty(&report).unwrap());
    i32::from(
        !report
            .get("ok")
            .and_then(|value| value.as_bool())
            .unwrap_or(false),
    )
}

fn convert_command(command: Commands) -> i32 {
    let Commands::Convert {
        mode,
        input,
        output,
        pattern,
        bayer,
        quality,
        jpeg_quality,
    } = command
    else {
        unreachable!("convert handler receives only the convert command");
    };
    let Some(mode) = ConvertMode::parse(&mode) else {
        eprintln!("unknown mode {mode}; use debayer|bgr2rgb|bmp2jpeg");
        return 2;
    };
    let pattern =
        BayerPattern::parse(bayer.as_deref().unwrap_or(&pattern)).unwrap_or(BayerPattern::Bggr);
    match convert_path(
        &input,
        &output,
        mode,
        pattern,
        jpeg_quality.unwrap_or(quality),
    ) {
        Ok(paths) => {
            for path in paths {
                println!("{}", path.display());
            }
            0
        }
        Err(error) => {
            eprintln!("convert error: {error}");
            1
        }
    }
}

fn wavsplit_command(command: Commands) -> i32 {
    let Commands::Wavsplit {
        in_file,
        src,
        out,
        out_dir,
    } = command
    else {
        unreachable!("wavsplit handler receives only the wavsplit command");
    };
    let Some(source) = in_file.or(src) else {
        eprintln!("wavsplit requires --in or positional src");
        return 2;
    };
    match split_wav(&source, out_dir.or(out).as_deref()) {
        Ok(paths) => {
            for path in paths {
                println!("{}", path.display());
            }
            0
        }
        Err(error) => {
            eprintln!("wavsplit error: {error}");
            1
        }
    }
}

fn session_profile_command(command: Commands) -> i32 {
    let Commands::SessionProfile {
        out,
        remote,
        camera_mode_id,
        sid,
    } = command
    else {
        unreachable!("session-profile handler receives only the session-profile command");
    };
    let profile = SessionProfile {
        remote_ip: remote,
        camera_mode_id,
        session_id: sid,
        ..SessionProfile::default()
    };
    match save_session_profile(&out, &profile) {
        Ok(path) => {
            println!("{}", path.display());
            0
        }
        Err(error) => {
            eprintln!("session-profile error: {error}");
            1
        }
    }
}

fn multi_sid_command(command: Commands) -> i32 {
    let Commands::MultiSid {
        sids,
        timeout,
        frames,
        concurrent,
        remote,
    } = command
    else {
        unreachable!("multi-sid handler receives only the multi-sid command");
    };
    let ids = match parse_session_ids(&sids) {
        Some(ids) => ids,
        None => {
            eprintln!("invalid --sids {sids}");
            return 2;
        }
    };
    match run_multi_sid(&ids, &remote, timeout, frames, concurrent) {
        Ok(report) => {
            println!(
                "{}",
                serde_json::to_string_pretty(&report.to_json()).unwrap()
            );
            i32::from(!report.ok)
        }
        Err(error) => {
            eprintln!("multi-sid error: {error}");
            1
        }
    }
}

fn parse_session_ids(value: &str) -> Option<Vec<i64>> {
    value
        .split(',')
        .map(|part| part.trim().parse::<i64>())
        .collect::<Result<Vec<_>, _>>()
        .ok()
        .filter(|ids| !ids.is_empty())
}
