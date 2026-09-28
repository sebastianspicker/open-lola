use super::client::client_session;
use super::control::{
    build_session_control, recv_valid_control_until, resolve_peer_ipv4, send_control_datagram,
    STATUS_REPLY_KINDS,
};
use super::peer::{peer_session_body, peer_thread, PeerPorts, PeerSockets};
use super::types::{resolve_mode, session_lock};
use super::{PeerRole, SessionOptions, SessionResult};
use crate::config::{default_settings, StationSettings};
use crate::net::{check_reachable, Udp};
use crate::protocol::MESG_CHECKLOLASTATUS;
use crate::station::sync::lock_unpoison;
use serde_json::json;
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

/// Run a station session (loopback / remote / listen).
pub fn run_session(
    mut settings: StationSettings,
    timeout: f64,
    options: SessionOptions,
) -> SessionResult {
    if !timeout.is_finite() || !(0.001..=86400.0).contains(&timeout) {
        return *failed_result(crate::station::SessionError::Configuration(
            "timeout must be finite and between 0.001 and 86400 seconds".into(),
        ));
    }
    let peer_role = match validate_session_start(&options) {
        Ok(role) => role,
        Err(result) => return *result,
    };
    let _guard = if options.serialize_loopback && peer_role == PeerRole::Loopback {
        Some(lock_unpoison(session_lock()))
    } else {
        None
    };
    let mut result = initial_result(peer_role);
    if let Err(error) = configure_session_mode(&mut settings, &options, &mut result) {
        result.error = error.to_string();
        result.failure = Some(error);
        return result;
    }
    if !apply_reachability_precheck(&settings, &options, peer_role, &mut result) {
        return result;
    }
    if peer_role == PeerRole::Listen {
        return run_listening_session(settings, timeout, options, result);
    }
    run_initiator_session(settings, timeout, options, peer_role, result)
}

fn validate_session_start(options: &SessionOptions) -> Result<PeerRole, Box<SessionResult>> {
    options.validate_duration().map_err(failed_result)?;
    if options.persistent && options.runtime_control.is_none() {
        return Err(failed_result(crate::station::SessionError::Configuration(
            "persistent sessions require SessionRuntime ownership".into(),
        )));
    }
    PeerRole::parse(&options.peer_mode).map_err(failed_result)
}

fn failed_result(error: crate::station::SessionError) -> Box<SessionResult> {
    Box::new(SessionResult {
        error: error.to_string(),
        failure: Some(error),
        ..Default::default()
    })
}

fn initial_result(peer_role: PeerRole) -> SessionResult {
    let mut result = SessionResult {
        camera_backend: String::new(),
        audio_backend: String::new(),
        media_transport: "udp".into(),
        peer_mode: peer_role.as_str().into(),
        network_monitor_report: json!({}),
        ..Default::default()
    };
    result.states.push("IDLE".into());
    result
}

fn configure_session_mode(
    settings: &mut StationSettings,
    options: &SessionOptions,
    result: &mut SessionResult,
) -> Result<(), crate::station::SessionError> {
    if let Some(mode) = resolve_mode(settings, options)? {
        settings.video.width = mode.width;
        settings.video.height = mode.height;
        settings.video.fps = mode.max_fps;
        settings.video.bpp = if mode.pixel_format == "RGB24" { 24 } else { 8 };
        result.camera_mode_id = mode.mode_id;
    } else {
        result.camera_mode_id = settings.video.camera_mode_id.clone();
    }
    result.media_transport = "udp".into();
    result.raw_plane_used = false;
    Ok(())
}

fn apply_reachability_precheck(
    settings: &StationSettings,
    options: &SessionOptions,
    peer_role: PeerRole,
    result: &mut SessionResult,
) -> bool {
    if let Err(error) = record_reachability_precheck(settings, options, peer_role, result) {
        result.error = error.to_string();
        result.failure = Some(error);
        return false;
    }
    true
}

fn record_reachability_precheck(
    settings: &StationSettings,
    options: &SessionOptions,
    peer_role: PeerRole,
    result: &mut SessionResult,
) -> Result<(), crate::station::SessionError> {
    let enabled = options
        .precheck_reachable
        .unwrap_or(settings.network.precheck_reachable);
    if !enabled || peer_role == PeerRole::Loopback {
        return Ok(());
    }
    let timeout_ms = options
        .reachability_timeout_ms
        .unwrap_or(settings.network.reachability_timeout_ms);
    let reachability = check_reachable(&settings.network.remote_ip, timeout_ms, 1);
    result.reachable = Some(reachability.ok);
    result.rtt_ms = reachability.rtt_ms;
    if reachability.ok {
        return Ok(());
    }
    Err(crate::station::SessionError::Transport(format!(
        "reachability precheck failed: {}",
        reachability.reason
    )))
}

fn run_listening_session(
    settings: StationSettings,
    timeout: f64,
    options: SessionOptions,
    mut result: SessionResult,
) -> SessionResult {
    let shared = Arc::new(Mutex::new(SessionResult::default()));
    let outcome = peer_session_body(
        settings.clone(),
        PeerPorts {
            control: settings.network.control_port,
            audio: settings.network.audio_port,
            video: settings.network.video_port,
        },
        options.clone(),
        shared.clone(),
        timeout.max(5.0),
    );
    merge_listener_result(&mut result, lock_unpoison(&shared).clone());
    finish_listener_outcome(&mut result, &options, outcome);
    result
}

fn merge_listener_result(result: &mut SessionResult, peer_result: SessionResult) {
    let states = std::mem::take(&mut result.states);
    let camera_mode_id = std::mem::take(&mut result.camera_mode_id);
    let peer_mode = result.peer_mode.clone();
    let reachable = result.reachable;
    let rtt_ms = result.rtt_ms;
    *result = peer_result;
    result.states = states;
    result.peer_mode = peer_mode;
    result.reachable = reachable;
    result.rtt_ms = rtt_ms;
    if result.camera_mode_id.is_empty() {
        result.camera_mode_id = camera_mode_id;
    }
}

fn finish_listener_outcome(
    result: &mut SessionResult,
    options: &SessionOptions,
    outcome: Result<(), crate::station::SessionError>,
) {
    match outcome {
        Ok(()) if result.rejected => finish_rejection(result, options),
        Ok(()) => {
            result.ok = media_stream_complete(result, options);
            result.states.push("STREAMING".into());
            result.states.push("IDLE".into());
        }
        Err(error @ crate::station::SessionError::PeerDisconnect(_)) => {
            finish_listener_disconnect(result, options, error)
        }
        Err(error) => {
            if result.error.is_empty() {
                result.error = error.to_string();
            }
            if result.failure.is_none() {
                result.failure = Some(error);
            }
        }
    }
}

struct InitiatorPeer {
    control: u16,
    audio: u16,
    video: u16,
    host: String,
    loopback: Option<(thread::JoinHandle<()>, Arc<Mutex<SessionResult>>)>,
}

fn run_initiator_session(
    settings: StationSettings,
    timeout: f64,
    options: SessionOptions,
    peer_role: PeerRole,
    mut result: SessionResult,
) -> SessionResult {
    let peer = match establish_initiator_peer(&settings, &options, timeout, peer_role) {
        Ok(peer) => peer,
        Err(error) => {
            result.error = error.to_string();
            result.failure = Some(error);
            return result;
        }
    };
    let client_outcome = client_session(
        &settings,
        &options,
        &mut result,
        timeout,
        peer.control,
        peer.audio,
        peer.video,
        &peer.host,
    );
    apply_client_outcome(&mut result, client_outcome);
    if let Some((handle, shared)) = peer.loopback {
        let _ = handle.join();
        merge_loopback_peer(&mut result, &lock_unpoison(&shared));
    }
    finish_initiator_result(&mut result, &options);
    result
}

fn establish_initiator_peer(
    settings: &StationSettings,
    options: &SessionOptions,
    timeout: f64,
    peer_role: PeerRole,
) -> Result<InitiatorPeer, crate::station::SessionError> {
    if peer_role == PeerRole::Remote {
        return Ok(InitiatorPeer {
            control: settings.network.control_port,
            audio: settings.network.audio_port,
            video: settings.network.video_port,
            host: settings.network.remote_ip.clone(),
            loopback: None,
        });
    }
    let bind = settings.network.bind_ip.clone();
    let (sockets, ports) = PeerSockets::bind_ephemeral(&bind)?;
    let shared = Arc::new(Mutex::new(SessionResult::default()));
    let thread_settings = settings.clone();
    let thread_options = options.clone();
    let thread_shared = shared.clone();
    let handle = thread::spawn(move || {
        peer_thread(
            thread_settings,
            sockets,
            thread_options,
            thread_shared,
            timeout.max(5.0),
        )
    });
    let host = if bind == "0.0.0.0" {
        "127.0.0.1".into()
    } else {
        settings.network.local_ip.clone()
    };
    Ok(InitiatorPeer {
        control: ports.control,
        audio: ports.audio,
        video: ports.video,
        host,
        loopback: Some((handle, shared)),
    })
}

fn apply_client_outcome(
    result: &mut SessionResult,
    outcome: Result<(), crate::station::SessionError>,
) {
    if let Err(error) = outcome {
        if result.error.is_empty() {
            result.error = error.to_string();
            result.failure = Some(error);
        }
    }
}

fn merge_loopback_peer(result: &mut SessionResult, peer: &SessionResult) {
    if result.bounce_back.is_none() {
        result.bounce_back = peer.bounce_back;
    }
    if result.chat_messages.is_empty() {
        result.chat_messages = peer.chat_messages.clone();
    }
    if result.audio_signal_active.is_none() {
        result.audio_signal_active = peer.audio_signal_active;
    }
    if peer.rejected {
        result.rejected = true;
        result.reject_text = peer.reject_text.clone();
    }
    if result.failure.is_none() {
        if let Some(failure) = peer.failure.clone() {
            result.error = peer.error.clone();
            result.failure = Some(failure);
        }
    }
}

fn finish_initiator_result(result: &mut SessionResult, options: &SessionOptions) {
    if result.rejected {
        finish_rejection(result, options);
        return;
    }
    if result.error.is_empty() && media_stream_complete(result, options) {
        result.ok = true;
    }
    if result.ok && result.states.last().map(String::as_str) != Some("IDLE") {
        result.states.push("IDLE".into());
    }
}

fn finish_listener_disconnect(
    result: &mut SessionResult,
    options: &SessionOptions,
    error: crate::station::SessionError,
) {
    result.states.push("STOPPED".into());
    result.states.push("IDLE".into());
    if media_stream_complete(result, options) {
        result.ok = true;
        return;
    }
    result.error = error.to_string();
    result.failure = Some(error);
}

fn finish_rejection(result: &mut SessionResult, options: &SessionOptions) {
    if !result.states.iter().any(|state| state == "REJECTED") {
        result.states.push("REJECTED".into());
    }
    if options.expected_rejection {
        result.ok = true;
    } else {
        result.ok = false;
        result.error = if result.reject_text.is_empty() {
            "peer rejected QUICKCONN".into()
        } else {
            format!("peer rejected QUICKCONN: {}", result.reject_text)
        };
        result.failure = Some(crate::station::SessionError::ControlHandshake(
            result.error.clone(),
        ));
    }
    if result.states.last().map(String::as_str) != Some("IDLE") {
        result.states.push("IDLE".into());
    }
}

fn media_stream_complete(result: &SessionResult, options: &SessionOptions) -> bool {
    let expected_frames = u64::from(options.stream_frames.max(1));
    let video_enabled = !options.audio_only;
    let tx_complete =
        (!options.stream_tx_video || !video_enabled || result.video_frames_sent >= expected_frames)
            && (!options.stream_tx_audio || result.audio_frames_sent >= expected_frames);
    let rx_complete = (!options.stream_rx_video
        || !video_enabled
        || result.video_frames_received >= expected_frames)
        && (!options.stream_rx_audio || result.audio_frames_received >= expected_frames);
    tx_complete && rx_complete
}

/// Perform only the control-plane availability check. No media transport,
/// camera, audio backend, or QUICKCONN negotiation is opened from this API.
pub fn run_check_only(
    mut settings: StationSettings,
    timeout: f64,
    options: SessionOptions,
) -> SessionResult {
    let peer_role = match PeerRole::parse(&options.peer_mode) {
        Ok(role) => role,
        Err(error) => {
            return SessionResult {
                error: error.to_string(),
                failure: Some(error),
                ..Default::default()
            }
        }
    };
    let peer_mode = peer_role.as_str();
    let mut result = SessionResult {
        media_transport: "udp".into(),
        peer_mode: peer_mode.into(),
        network_monitor_report: json!({}),
        ..Default::default()
    };
    result.states.push("IDLE".into());
    let mode = match resolve_mode(&settings, &options) {
        Ok(mode) => mode,
        Err(error) => {
            result.error = error.to_string();
            result.failure = Some(error);
            return result;
        }
    };
    if let Some(mode) = mode {
        settings.video.width = mode.width;
        settings.video.height = mode.height;
        result.camera_mode_id = mode.mode_id;
    } else {
        result.camera_mode_id = settings.video.camera_mode_id.clone();
    }
    if !timeout.is_finite() || timeout <= 0.0 {
        result.error = "check timeout must be finite and greater than zero".into();
        result.failure = Some(crate::station::SessionError::Configuration(
            result.error.clone(),
        ));
        return result;
    }
    if let Err(error) = record_reachability_precheck(&settings, &options, peer_role, &mut result) {
        result.error = error.to_string();
        result.failure = Some(error);
        return result;
    }
    if super::types::session_cancelled(&options) {
        result.error = "session cancelled before status check".into();
        result.failure = Some(crate::station::SessionError::PeerDisconnect(
            result.error.clone(),
        ));
        return result;
    }
    let bind_port = if peer_role == PeerRole::Remote {
        settings.network.control_port
    } else {
        0
    };
    let socket = match Udp::bind(&settings.network.bind_ip, bind_port) {
        Ok(socket) => socket,
        Err(error) => {
            result.error = error.to_string();
            result.failure = Some(crate::station::SessionError::Transport(
                result.error.clone(),
            ));
            return result;
        }
    };
    let peer = match resolve_peer_ipv4(&settings.network.remote_ip, settings.network.control_port) {
        Ok(peer) => peer,
        Err(error) => {
            result.error = error.to_string();
            result.failure = Some(error);
            return result;
        }
    };
    let check = match build_session_control(
        &settings,
        MESG_CHECKLOLASTATUS,
        &settings.network.local_ip,
        &settings.network.remote_ip,
        "",
        None,
    ) {
        Ok(check) => check,
        Err(error) => {
            result.error = error.to_string();
            result.failure = Some(crate::station::SessionError::ControlHandshake(
                result.error.clone(),
            ));
            return result;
        }
    };
    result.states.push("WAITING_STATUS".into());
    let started = Instant::now();
    let outcome = send_control_datagram(&socket, &check, peer).and_then(|()| {
        result.messages_sent.push("/MESG_CHECKLOLASTATUS".into());
        recv_valid_control_until(
            &socket,
            peer,
            &settings,
            started + Duration::from_secs_f64(timeout),
            options.runtime_control.as_ref(),
            STATUS_REPLY_KINDS,
        )
    });
    match outcome {
        Ok(message) if message.name == "/MESG_CHECKLOLASTATUS_ACK" => {
            result.rtt_ms = Some(started.elapsed().as_secs_f64() * 1000.0);
            result.messages_received.push(message.name);
            result.states.push("READY".into());
            result.states.push("IDLE".into());
            result.ok = true;
        }
        Ok(message) => {
            result.error = format!("expected STATUS_ACK got {}", message.name);
            result.failure = Some(crate::station::SessionError::ControlHandshake(
                result.error.clone(),
            ));
        }
        Err(error) => {
            result.error = error.to_string();
            result.failure = Some(error);
        }
    }
    result
}

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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reachability_precheck_keeps_loopback_off_the_network() {
        let mut options = SessionOptions::demo();
        options.precheck_reachable = Some(true);
        let mut result = SessionResult::default();

        record_reachability_precheck(
            &default_settings(),
            &options,
            PeerRole::Loopback,
            &mut result,
        )
        .expect("loopback precheck is skipped");

        assert_eq!(result.reachable, None);
        assert_eq!(result.rtt_ms, None);
    }
}
