use super::super::control::{
    build_session_control, protocol_media_settings, recv_valid_control_until,
    send_control_datagram, verify_quickconn_ack_audio, QUICKCONN_REPLY_KINDS, STATUS_REPLY_KINDS,
};
use super::super::{SessionOptions, SessionPhase, SessionResult};
use crate::config::StationSettings;
use crate::net::Udp;
use crate::protocol::{
    parse_quickconn_fields, unescape_txt_field, MediaSettings as ProtocolMediaSettings,
    MESG_CHECKLOLASTATUS, MESG_QUICKCONN,
};
use crate::station::monitor::NetworkMonitor;
use crate::station::SessionError;
use std::net::SocketAddr;
use std::time::{Duration, Instant};

pub(super) enum ClientNegotiation {
    Rejected,
    Accepted {
        remote_video_bpp: u32,
        capabilities: std::collections::BTreeMap<String, serde_json::Value>,
    },
}

#[allow(clippy::too_many_arguments)]
pub(super) fn negotiate_client(
    settings: &StationSettings,
    options: &SessionOptions,
    result: &mut SessionResult,
    control_socket: &Udp,
    peer_addr: SocketAddr,
    timeout: f64,
    monitor: &mut NetworkMonitor,
) -> Result<ClientNegotiation, SessionError> {
    set_client_phase(options, SessionPhase::Checking);
    result.states.push("WAITING_STATUS".into());
    let checked_at = Instant::now();
    let deadline = checked_at + Duration::from_secs_f64(timeout.max(0.01));
    let status = build_session_control(
        settings,
        MESG_CHECKLOLASTATUS,
        &settings.network.local_ip,
        &settings.network.remote_ip,
        "",
        None,
    )
    .map_err(|error| SessionError::ControlHandshake(error.to_string()))?;
    let status_reply = send_control_with_retries(
        control_socket,
        &status,
        peer_addr,
        settings,
        deadline,
        options.runtime_control.as_ref(),
        STATUS_REPLY_KINDS,
        &mut result.messages_sent,
        "/MESG_CHECKLOLASTATUS",
    )?;
    let rtt = checked_at.elapsed().as_secs_f64() * 1000.0;
    monitor.note_rtt(rtt);
    result.rtt_ms = Some(rtt);
    if status_reply.name != "/MESG_CHECKLOLASTATUS_ACK" {
        return Err(SessionError::ControlHandshake(format!(
            "expected STATUS_ACK got {}",
            status_reply.name
        )));
    }
    result.messages_received.push(status_reply.name);
    result.states.push("READY".into());

    set_client_phase(options, SessionPhase::Negotiating);
    result.states.push("NEGOTIATING".into());
    let requested_media = requested_client_media(settings, options);
    let quickconn = build_session_control(
        settings,
        MESG_QUICKCONN,
        &settings.network.local_ip,
        &settings.network.remote_ip,
        "",
        Some(&requested_media),
    )
    .map_err(|error| SessionError::ControlHandshake(error.to_string()))?;
    let reply = send_control_with_retries(
        control_socket,
        &quickconn,
        peer_addr,
        settings,
        deadline,
        options.runtime_control.as_ref(),
        QUICKCONN_REPLY_KINDS,
        &mut result.messages_sent,
        "/MESG_QUICKCONN",
    )?;
    result.messages_received.push(reply.name.clone());
    if reply.name == "/MESG_REJECT" {
        result.rejected = true;
        result.reject_text = reject_reason(&reply);
        result.states.push("REJECTED".into());
        return Ok(ClientNegotiation::Rejected);
    }
    if reply.name != "/MESG_QUICKCONN_ACK" {
        return Err(SessionError::ControlHandshake(format!(
            "expected QUICKCONN_ACK got {}",
            reply.name
        )));
    }
    let capabilities = parse_quickconn_fields(&reply)
        .map_err(|error| SessionError::ControlHandshake(error.to_string()))?;
    let acknowledged = ProtocolMediaSettings::from_fields(&reply.fields, None)
        .map_err(|error| SessionError::ControlHandshake(error.to_string()))?;
    let remote_video_bpp = capabilities
        .get("BPP")
        .and_then(serde_json::Value::as_u64)
        .and_then(|value| u32::try_from(value).ok())
        .unwrap_or(0);
    verify_quickconn_ack_audio(&reply, &requested_media)?;
    if !options.audio_only && (options.stream_tx_video || options.stream_rx_video) {
        verify_quickconn_ack_video(&requested_media, &acknowledged)?;
    }
    Ok(ClientNegotiation::Accepted {
        remote_video_bpp,
        capabilities,
    })
}

/// Interval after which an unanswered handshake datagram is sent again.
/// LoLa control runs over UDP without acknowledgement of the request itself,
/// so one lost datagram must not cost the whole negotiation window.
pub(super) const HANDSHAKE_RETRY_INTERVAL: Duration = Duration::from_millis(500);

/// Sends one handshake datagram and waits for an accepted reply, re-sending
/// the same datagram at every retry interval until the deadline. Replies are
/// validated by `recv_valid_control_until`. A re-sent status check is answered
/// again by the responder; a re-sent `QUICKCONN` is re-acknowledged by the
/// responder even after it has moved on to media.
#[allow(clippy::too_many_arguments)]
pub(super) fn send_control_with_retries(
    control_socket: &Udp,
    datagram: &[u8],
    peer_addr: SocketAddr,
    settings: &StationSettings,
    deadline: Instant,
    runtime_control: Option<&super::super::SessionRuntimeControl>,
    accepted_kinds: &[&str],
    messages_sent: &mut Vec<String>,
    message_name: &str,
) -> Result<crate::protocol::Mesg, SessionError> {
    loop {
        let now = Instant::now();
        if now >= deadline {
            return Err(SessionError::Timeout(format!(
                "no reply to {message_name} before the negotiation deadline"
            )));
        }
        send_control_datagram(control_socket, datagram, peer_addr)?;
        messages_sent.push(message_name.into());
        let attempt_deadline = deadline.min(now + HANDSHAKE_RETRY_INTERVAL);
        match recv_valid_control_until(
            control_socket,
            peer_addr,
            settings,
            attempt_deadline,
            runtime_control,
            accepted_kinds,
        ) {
            Err(SessionError::Timeout(_)) if attempt_deadline < deadline => continue,
            Err(SessionError::Timeout(_)) => {
                return Err(SessionError::Timeout(format!(
                    "no reply to {message_name} after {} attempt(s)",
                    messages_sent
                        .iter()
                        .filter(|name| name.as_str() == message_name)
                        .count()
                )))
            }
            other => return other,
        }
    }
}

/// The peer's REJECT reason with its ASCII TXT escapes decoded.
fn reject_reason(reply: &crate::protocol::Mesg) -> String {
    unescape_txt_field(reply.fields.get("TXT").map_or("", String::as_str))
}

pub(super) fn set_client_phase(options: &SessionOptions, phase: SessionPhase) {
    if let Some(control) = options.runtime_control.as_ref() {
        control.set_phase(phase);
    }
}

fn requested_client_media(
    settings: &StationSettings,
    options: &SessionOptions,
) -> ProtocolMediaSettings {
    let mut requested = protocol_media_settings(settings);
    (requested.width, requested.height) =
        super::super::types::stream_dims(settings.video.width, settings.video.height, options);
    (requested.bits_per_pixel, requested.bayer) = super::super::video::negotiated_output_format(
        settings,
        options,
        settings.video.compression,
    );
    requested
}

fn verify_quickconn_ack_video(
    requested: &ProtocolMediaSettings,
    acknowledged: &ProtocolMediaSettings,
) -> Result<(), SessionError> {
    let exact = requested.fps == acknowledged.fps
        && requested.bits_per_pixel == acknowledged.bits_per_pixel
        && requested.width == acknowledged.width
        && requested.height == acknowledged.height
        && requested.compression == acknowledged.compression
        && requested.bayer == acknowledged.bayer;
    if exact {
        Ok(())
    } else {
        Err(SessionError::ControlHandshake(
            "QUICKCONN_ACK video settings do not match the negotiated request".into(),
        ))
    }
}

pub(super) fn apply_cleanup_result(
    result: &mut SessionResult,
    cleanup: super::super::lifecycle::CleanupReport,
) {
    result.cleanup_warnings.extend(cleanup.warnings);
    if cleanup.stop_audio_signal_sent {
        result.messages_sent.push("/MESG_STOP_AUDIO_SIGNAL".into());
    }
    if cleanup.disconnect_sent {
        result.messages_sent.push("/MESG_DISCONNECT".into());
    }
}

#[cfg(test)]
#[path = "negotiation/geometry_tests.rs"]
mod geometry_tests;

#[cfg(test)]
#[path = "negotiation/retry_tests.rs"]
mod retry_tests;
