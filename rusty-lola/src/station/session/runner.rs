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
    if let Err(error) = options.validate_duration() {
        return SessionResult {
            error: error.to_string(),
            failure: Some(error),
            ..Default::default()
        };
    }
    if options.persistent && options.runtime_control.is_none() {
        return SessionResult {
            error: "persistent sessions require SessionRuntime ownership".into(),
            failure: Some(crate::station::SessionError::Configuration(
                "persistent sessions require SessionRuntime ownership".into(),
            )),
            ..Default::default()
        };
    }
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
    let _guard = if options.serialize_loopback && peer_role == PeerRole::Loopback {
        Some(lock_unpoison(session_lock()))
    } else {
        None
    };

    let mut result = SessionResult {
        camera_backend: String::new(),
        audio_backend: String::new(),
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
        settings.video.fps = mode.max_fps;
        settings.video.bpp = if mode.pixel_format == "RGB24" { 24 } else { 8 };
        result.camera_mode_id = mode.mode_id.clone();
    } else {
        result.camera_mode_id = settings.video.camera_mode_id.clone();
    }

    result.media_transport = "udp".into();
    result.raw_plane_used = false;

    // Reachability precheck
    let precheck = options
        .precheck_reachable
        .unwrap_or(settings.network.precheck_reachable);
    if precheck && peer_role != PeerRole::Loopback {
        let ms = options
            .reachability_timeout_ms
            .unwrap_or(settings.network.reachability_timeout_ms);
        let r = check_reachable(&settings.network.remote_ip, ms, 1);
        result.reachable = Some(r.ok);
        result.rtt_ms = r.rtt_ms;
        if !r.ok {
            result.error = format!("reachability precheck failed: {}", r.reason);
            result.failure = Some(crate::station::SessionError::Transport(
                result.error.clone(),
            ));
            return result;
        }
    }

    // listen mode: server only on fixed settings ports
    if peer_role == PeerRole::Listen {
        let shared = Arc::new(Mutex::new(SessionResult::default()));
        let listen_result = peer_session_body(
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
        let peer_result = lock_unpoison(&shared).clone();
        let initial_states = std::mem::take(&mut result.states);
        let configured_mode = std::mem::take(&mut result.camera_mode_id);
        let reachable = result.reachable;
        let rtt_ms = result.rtt_ms;
        result = peer_result;
        result.states = initial_states;
        result.peer_mode = peer_mode.into();
        result.reachable = reachable;
        result.rtt_ms = rtt_ms;
        if result.camera_mode_id.is_empty() {
            result.camera_mode_id = configured_mode;
        }
        match listen_result {
            Ok(()) => {
                if result.rejected {
                    finish_rejection(&mut result, &options);
                } else {
                    result.ok = media_stream_complete(&result, &options);
                    result.states.push("STREAMING".into());
                    result.states.push("IDLE".into());
                }
            }
            Err(error @ crate::station::SessionError::PeerDisconnect(_)) => {
                finish_listener_disconnect(&mut result, &options, error);
            }
            Err(e) => {
                if result.error.is_empty() {
                    result.error = e.to_string();
                }
                if result.failure.is_none() {
                    result.failure = Some(e);
                }
            }
        }
        return result;
    }

    let (peer_control, peer_audio, peer_video, peer_host, handle) = if peer_role == PeerRole::Remote
    {
        (
            settings.network.control_port,
            settings.network.audio_port,
            settings.network.video_port,
            settings.network.remote_ip.clone(),
            None,
        )
    } else {
        // loopback
        let bind = settings.network.bind_ip.clone();
        let (peer_sockets, peer_ports) = match PeerSockets::bind_ephemeral(&bind) {
            Ok(bound) => bound,
            Err(error) => {
                result.error = error.to_string();
                result.failure = Some(error);
                return result;
            }
        };
        let peer_control = peer_ports.control;
        let peer_audio = peer_ports.audio;
        let peer_video = peer_ports.video;
        let shared = Arc::new(Mutex::new(SessionResult::default()));
        let peer_settings = settings.clone();
        let peer_options = options.clone();
        let peer_timeout = timeout.max(5.0);
        let shared_peer = shared.clone();
        let handle = thread::spawn(move || {
            peer_thread(
                peer_settings,
                peer_sockets,
                peer_options,
                shared_peer,
                peer_timeout,
            );
        });
        let host = if bind == "0.0.0.0" {
            "127.0.0.1".to_string()
        } else {
            settings.network.local_ip.clone()
        };
        (
            peer_control,
            peer_audio,
            peer_video,
            host,
            Some((handle, shared)),
        )
    };

    let outcome = client_session(
        &settings,
        &options,
        &mut result,
        timeout,
        peer_control,
        peer_audio,
        peer_video,
        &peer_host,
    );
    if let Err(e) = outcome {
        if result.error.is_empty() {
            result.error = e.to_string();
            result.failure = Some(e);
        }
    }

    if let Some((handle, shared)) = handle {
        let _ = handle.join();
        let peer_r = lock_unpoison(&shared);
        if result.bounce_back.is_none() {
            result.bounce_back = peer_r.bounce_back;
        }
        if result.chat_messages.is_empty() {
            result.chat_messages = peer_r.chat_messages.clone();
        }
        if result.audio_signal_active.is_none() {
            result.audio_signal_active = peer_r.audio_signal_active;
        }
        if peer_r.rejected {
            result.rejected = true;
            result.reject_text = peer_r.reject_text.clone();
        }
        if result.failure.is_none() {
            if let Some(failure) = peer_r.failure.clone() {
                result.error = peer_r.error.clone();
                result.failure = Some(failure);
            }
        }
    }

    if result.rejected {
        finish_rejection(&mut result, &options);
        return result;
    }

    if result.error.is_empty() && media_stream_complete(&result, &options) {
        result.ok = true;
    }

    if result.ok && result.states.last().map(|s| s.as_str()) != Some("IDLE") {
        result.states.push("IDLE".into());
    }
    result
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
    let precheck = options
        .precheck_reachable
        .unwrap_or(settings.network.precheck_reachable);
    if precheck && peer_role != PeerRole::Loopback {
        let reachability = check_reachable(
            &settings.network.remote_ip,
            options
                .reachability_timeout_ms
                .unwrap_or(settings.network.reachability_timeout_ms),
            1,
        );
        result.reachable = Some(reachability.ok);
        result.rtt_ms = reachability.rtt_ms;
        if !reachability.ok {
            result.error = format!("reachability precheck failed: {}", reachability.reason);
            result.failure = Some(crate::station::SessionError::Transport(
                result.error.clone(),
            ));
            return result;
        }
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
    use crate::config::{default_settings, MediaTransportKind};
    use crate::station::SessionError;

    #[test]
    fn invalid_loopback_npcap_keeps_its_configuration_category() {
        let mut options = SessionOptions::demo();
        options.media_transport = Some(MediaTransportKind::Npcap);
        let result = run_session(default_settings(), 1.0, options);
        assert!(matches!(
            result.failure,
            Some(SessionError::Configuration(_))
        ));
        assert!(!result.error.is_empty());
    }

    #[test]
    fn tx_only_loopback_completes_without_waiting_for_media_receives() {
        let mut options = SessionOptions::demo();
        options.control_extras = false;
        options.stream_frames = 1;
        options.stream_rx_video = false;
        options.stream_rx_audio = false;
        let result = run_session(default_settings(), 3.0, options);
        assert!(
            result.ok,
            "typed failure: {:?}; text: {}",
            result.failure, result.error
        );
        assert_eq!(result.video_frames_received, 0);
        assert_eq!(result.audio_frames_received, 0);
        assert!(result.video_frames_sent > 0);
        assert!(result.audio_frames_sent > 0);
    }

    #[test]
    fn malformed_video_drop_cannot_complete_a_receive_stream() {
        let mut options = SessionOptions::demo();
        options.stream_frames = 1;
        options.stream_tx_video = false;
        options.stream_tx_audio = false;
        options.stream_rx_audio = false;
        let result = SessionResult {
            video_malformed_drops: 1,
            ..Default::default()
        };
        assert!(!media_stream_complete(&result, &options));
    }

    #[test]
    fn listener_disconnect_before_enabled_media_is_a_failed_stop() {
        let mut options = SessionOptions::demo();
        options.stream_frames = 1;
        options.stream_tx_audio = false;
        options.stream_tx_video = false;
        options.stream_rx_audio = false;
        let mut result = SessionResult::default();
        finish_listener_disconnect(
            &mut result,
            &options,
            SessionError::PeerDisconnect("remote closed before video".into()),
        );
        assert!(!result.ok);
        assert!(matches!(
            result.failure,
            Some(SessionError::PeerDisconnect(_))
        ));
        assert_eq!(result.states, ["STOPPED", "IDLE"]);
    }

    #[test]
    fn explicit_catalog_failure_is_a_typed_configuration_error() {
        let mut options = SessionOptions::demo();
        options.use_catalog_geometry = true;
        options.catalog_path = Some(std::path::PathBuf::from("missing-camera-catalog.ini"));
        let result = run_session(default_settings(), 1.0, options);
        assert!(matches!(
            result.failure,
            Some(SessionError::Configuration(_))
        ));
        assert!(result.error.contains("camera catalog"));
    }
}
