use super::{SessionOptions, SessionResult, SessionRuntimeControl};
use crate::config::{ControlDialect, StationSettings};
use crate::net::{
    parse_mac_address, resolve_direct_lan_mac_via_ip_helper, resolve_mac_via_ip_helper,
    TransportError, Udp,
};
use crate::protocol::{
    build_control_datagram, build_osc15_control_datagram, unescape_txt_field,
    MediaSettings as ProtocolMediaSettings, MESG_CHAT, MESG_REJECT,
};
use crate::station::bounded::push_bounded;
use crate::station::sync::lock_unpoison;
use crate::station::SessionError;
use std::net::{SocketAddr, ToSocketAddrs};
use std::sync::Mutex;
use std::time::{Duration, Instant};

pub(super) const STATUS_REPLY_KINDS: &[&str] = &["/MESG_CHECKLOLASTATUS_ACK"];

/// Minimum spacing between re-sent acknowledgements. The initiator repeats
/// QUICKCONN every 500 ms, so this only suppresses bursts and duplicates.
const ACK_RESEND_INTERVAL: Duration = Duration::from_millis(100);

/// The encoded `/MESG_QUICKCONN_ACK` kept so a lost acknowledgement can be
/// repeated while media is already flowing. Without it the initiator keeps
/// re-sending QUICKCONN until its deadline while the responder streams to a
/// peer that never joined.
pub(crate) struct QuickconnAckCache {
    bytes: Vec<u8>,
    last_resend: Mutex<Option<Instant>>,
}

impl QuickconnAckCache {
    pub(crate) fn new(bytes: Vec<u8>) -> Self {
        Self {
            bytes,
            last_resend: Mutex::new(None),
        }
    }

    fn claim_resend(&self) -> bool {
        let mut last = lock_unpoison(&self.last_resend);
        let now = Instant::now();
        if last.is_some_and(|sent| now.duration_since(sent) < ACK_RESEND_INTERVAL) {
            return false;
        }
        *last = Some(now);
        true
    }

    /// Re-sends the cached acknowledgement and records it in the session result.
    /// A failed re-send is not a session failure: the initiator repeats its
    /// request and the next attempt answers it.
    pub(crate) fn resend_into(&self, socket: &Udp, peer: SocketAddr, result: &mut SessionResult) {
        if self.resend(socket, peer) {
            push_bounded(&mut result.messages_sent, "/MESG_QUICKCONN_ACK".into());
        }
    }

    /// Resends the cached ACK when allowed; true when it went out.
    pub(crate) fn resend(&self, socket: &Udp, peer: SocketAddr) -> bool {
        self.claim_resend() && send_control_datagram(socket, &self.bytes, peer).is_ok()
    }
}
pub(super) const QUICKCONN_REPLY_KINDS: &[&str] = &["/MESG_QUICKCONN_ACK", "/MESG_REJECT"];

pub(super) fn send_queued_controls(
    socket: &Udp,
    peer: SocketAddr,
    settings: &StationSettings,
    options: &SessionOptions,
    result: &mut SessionResult,
) -> Result<(), SessionError> {
    let Some(control) = options.runtime_control.as_ref() else {
        return Ok(());
    };
    for command in control.drain() {
        let encoded = match encode_queued_control(settings, &command) {
            Ok(encoded) => encoded,
            // A command that cannot be encoded is dropped; later commands and the session go on.
            Err(SessionError::Protocol(reason) | SessionError::ControlHandshake(reason)) => {
                push_bounded(
                    &mut result.skipped_controls,
                    format!("queued control skipped: {reason}"),
                );
                continue;
            }
            Err(error) => return Err(error),
        };
        if !send_control_datagram_or_drop(socket, &encoded, peer)? {
            push_bounded(
                &mut result.skipped_controls,
                "queued control skipped: send dropped".into(),
            );
            continue;
        }
        push_bounded(
            &mut result.messages_sent,
            command
                .strip_prefix("chat:")
                .map_or_else(
                    || command.split(';').next().unwrap_or("/MESG_UNKNOWN"),
                    |_| "/MESG_CHAT",
                )
                .to_string(),
        );
    }
    Ok(())
}

/// Rejects a queued control that the session could not encode (for example a
/// chat whose escaped text overflows the datagram), using the real encoder.
pub(crate) fn check_queued_control(
    settings: &StationSettings,
    command: &str,
) -> Result<(), SessionError> {
    encode_queued_control(settings, command).map(|_| ())
}

fn encode_queued_control(
    settings: &StationSettings,
    command: &str,
) -> Result<Vec<u8>, SessionError> {
    Ok(if let Some(text) = command.strip_prefix("chat:") {
        build_session_control(
            settings,
            MESG_CHAT,
            &settings.network.local_ip,
            &settings.network.remote_ip,
            text,
            None,
        )
        .map_err(|error| SessionError::ControlHandshake(error.to_string()))?
    } else if command.starts_with("/MESG_") {
        if settings.network.control_dialect != ControlDialect::Ascii {
            return Err(SessionError::Protocol(
                "serialized /MESG_* controls require the ASCII control dialect".into(),
            ));
        }
        let mut bytes = command.as_bytes().to_vec();
        if bytes.len() > crate::protocol::CONTROL_DATAGRAM_SIZE {
            return Err(SessionError::Protocol(
                "queued control message exceeds 1024 bytes".into(),
            ));
        }
        let decoded = crate::protocol::decode_mesg(&bytes)
            .map_err(|error| SessionError::Protocol(error.to_string()))?;
        let expected_sid = settings.network.session_id.to_string();
        if decoded.fields.get("SRCIP") != Some(&settings.network.local_ip)
            || decoded.fields.get("DSTIP") != Some(&settings.network.remote_ip)
            || decoded.fields.get("SID") != Some(&expected_sid)
        {
            return Err(SessionError::Protocol(
                "queued control source, destination, or SID does not match this session".into(),
            ));
        }
        bytes.resize(crate::protocol::CONTROL_DATAGRAM_SIZE, 0);
        bytes
    } else {
        return Err(SessionError::Protocol(
            "queued control must be `chat:text` or a /MESG_* datagram".into(),
        ));
    })
}

pub(super) fn send_control_datagram(
    socket: &Udp,
    encoded: &[u8],
    peer: SocketAddr,
) -> Result<(), SessionError> {
    let sent = socket
        .send_to(encoded, peer)
        .map_err(|error| SessionError::Transport(error.to_string()))?;
    if sent != encoded.len() {
        return Err(SessionError::Transport(
            "partial control datagram send".into(),
        ));
    }
    Ok(())
}

/// Returns `Ok(false)` when the datagram was dropped for a transient reason
/// (`WouldBlock` or a transient OS fault) rather than failing the session.
pub(super) fn send_control_datagram_or_drop(
    socket: &Udp,
    encoded: &[u8],
    peer: SocketAddr,
) -> Result<bool, SessionError> {
    match socket
        .send_to(encoded, peer)
        .map_err(TransportError::from_io)
    {
        Ok(sent) if sent == encoded.len() => Ok(true),
        Ok(_) => Err(SessionError::Transport(
            "partial control datagram send".into(),
        )),
        Err(TransportError::WouldBlock | TransportError::Transient(_)) => Ok(false),
        Err(error) => Err(SessionError::Transport(error.to_string())),
    }
}

pub(super) fn protocol_media_settings(settings: &StationSettings) -> ProtocolMediaSettings {
    ProtocolMediaSettings {
        sample_rate: settings.audio.sample_rate,
        bits_per_sample: u32::from(settings.audio.bits_per_sample),
        channels: u32::from(settings.audio.channels),
        fps: settings.video.fps,
        bits_per_pixel: settings.video.bpp,
        width: settings.video.width,
        height: settings.video.height,
        compression: u32::from(settings.video.compression),
        bayer: settings.video.bayer,
    }
}

pub(super) fn verify_quickconn_ack_audio(
    message: &crate::protocol::Mesg,
    requested: &ProtocolMediaSettings,
) -> Result<(), SessionError> {
    let acknowledged = ProtocolMediaSettings::from_fields(&message.fields, None)
        .map_err(|error| SessionError::ControlHandshake(error.to_string()))?;
    if acknowledged.sample_rate != requested.sample_rate
        || acknowledged.bits_per_sample != requested.bits_per_sample
        || acknowledged.channels != requested.channels
    {
        return Err(SessionError::ControlHandshake(
            "QUICKCONN_ACK audio settings do not match the request".into(),
        ));
    }
    Ok(())
}

/// Longest REJECT reason sent to a peer; escaping can triple it and the datagram is fixed size.
const MAX_REJECT_REASON_CHARS: usize = 120;

/// Reduce a REJECT reason to printable ASCII of a bounded length so that building the
/// REJECT cannot fail with `NonAscii` or `TooLong`, whatever the local error said.
fn sanitize_reject_reason(reason: &str) -> String {
    reason
        .chars()
        .map(|c| {
            if c.is_ascii() && !c.is_ascii_control() {
                c
            } else {
                '?'
            }
        })
        .take(MAX_REJECT_REASON_CHARS)
        .collect()
}

pub(super) fn build_session_control(
    settings: &StationSettings,
    kind: &str,
    src: &str,
    dst: &str,
    txt: &str,
    media: Option<&ProtocolMediaSettings>,
) -> Result<Vec<u8>, crate::protocol::ProtocolError> {
    let sanitized;
    let txt = if kind == MESG_REJECT {
        sanitized = sanitize_reject_reason(txt);
        sanitized.as_str()
    } else {
        txt
    };
    match settings.network.control_dialect {
        ControlDialect::Ascii => build_control_datagram(
            kind,
            src,
            dst,
            settings.network.session_id as u32,
            media,
            txt,
        ),
        ControlDialect::Osc15 => build_osc15_control_datagram(
            kind,
            src,
            dst,
            settings.network.session_id as u32,
            media,
            txt,
            None,
        ),
    }
}

pub(super) fn resolve_peer_ipv4(host: &str, port: u16) -> Result<SocketAddr, SessionError> {
    (host, port)
        .to_socket_addrs()
        .map_err(|error| SessionError::Transport(format!("resolve peer {host}: {error}")))?
        .find(SocketAddr::is_ipv4)
        .ok_or_else(|| SessionError::Transport(format!("peer {host} has no IPv4 address")))
}

pub(super) fn resolve_session_mac(
    environment_key: &str,
    target: std::net::Ipv4Addr,
    source: std::net::Ipv4Addr,
) -> Result<[u8; 6], SessionError> {
    if let Ok(value) = std::env::var(environment_key) {
        return parse_mac_address(&value).map_err(SessionError::Configuration);
    }
    resolve_mac_via_ip_helper(target, Some(source)).map_err(|error| {
        SessionError::Transport(format!(
            "{error}; set {environment_key} to an explicit MAC address for controlled diagnostics"
        ))
    })
}

/// Resolve the local adapter MAC after the capture adapter is selected. Peer
/// resolution deliberately remains SendARP-based in `resolve_session_mac`.
pub(super) fn resolve_local_session_mac(
    environment_key: &str,
    local_ip: std::net::Ipv4Addr,
    peer_ip: std::net::Ipv4Addr,
    device: &str,
) -> Result<[u8; 6], SessionError> {
    let resolved =
        resolve_direct_lan_mac_via_ip_helper(local_ip, peer_ip, Some(device)).map_err(|error| {
            SessionError::Transport(format!(
                "{error}; use UDP for routed peers or select the adapter that owns {local_ip}"
            ))
        })?;
    if let Ok(value) = std::env::var(environment_key) {
        return parse_mac_address(&value).map_err(SessionError::Configuration);
    }
    Ok(resolved)
}

/// Polls `socket` in short cancellable steps until `accept` takes a datagram.
/// `Ok(None)` means the caller-owned deadline elapsed first.
pub(super) fn recv_control_until<T>(
    socket: &Udp,
    deadline: Instant,
    runtime_control: Option<&SessionRuntimeControl>,
    cancelled: &str,
    mut accept: impl FnMut(&[u8], SocketAddr) -> Option<T>,
) -> Result<Option<T>, SessionError> {
    const POLL: Duration = Duration::from_millis(10);
    loop {
        if runtime_control.is_some_and(SessionRuntimeControl::is_cancelled) {
            return Err(SessionError::PeerDisconnect(cancelled.into()));
        }
        let now = Instant::now();
        if now >= deadline {
            return Ok(None);
        }
        socket
            .set_timeout((deadline - now).min(POLL).as_secs_f64())
            .map_err(|error| SessionError::Transport(error.to_string()))?;
        match socket.recv_vec() {
            Ok((data, sender)) => {
                if let Some(accepted) = accept(&data, sender) {
                    return Ok(Some(accepted));
                }
            }
            Err(error)
                if matches!(
                    error.kind(),
                    std::io::ErrorKind::WouldBlock
                        | std::io::ErrorKind::TimedOut
                        | std::io::ErrorKind::Interrupted
                ) => {}
            Err(error) => return Err(SessionError::Transport(error.to_string())),
        }
    }
}

/// Wait for a validated control reply. This deliberately preserves the
/// existing SR/BPS/CH-only QUICKCONN matching performed after the reply is decoded.
pub(super) fn recv_valid_control_until(
    socket: &Udp,
    expected_sender: SocketAddr,
    settings: &StationSettings,
    deadline: Instant,
    runtime_control: Option<&SessionRuntimeControl>,
    accepted_kinds: &[&str],
) -> Result<crate::protocol::Mesg, SessionError> {
    let mut discarded = 0_u64;
    recv_control_until(
        socket,
        deadline,
        runtime_control,
        "session cancelled while waiting for control reply",
        |data, sender| {
            if sender != expected_sender {
                return None;
            }
            let message = crate::protocol::decode_mesg(data).ok().filter(|message| {
                validate_incoming_control(message, sender, settings, Some(expected_sender), false)
                    .is_ok()
                    && accepted_kinds.contains(&message.name.as_str())
            });
            discarded += u64::from(message.is_none());
            message
        },
    )?
    .ok_or_else(|| {
        SessionError::Timeout(format!(
            "control reply deadline elapsed after discarding {discarded} invalid control datagrams"
        ))
    })
}

pub(super) fn is_stream_control(message: &crate::protocol::Mesg) -> bool {
    matches!(
        message.name.as_str(),
        "/MESG_SWITCH_ON_BB"
            | "/MESG_SWITCH_OFF_BB"
            | "/MESG_CHAT"
            | "/MESG_SEND_AUDIO_SIGNAL"
            | "/MESG_STOP_AUDIO_SIGNAL"
            | "/MESG_DISCONNECT"
    )
}

/// Checks a decoded control datagram against the session peer. `pin_sender_ip`
/// additionally requires the sender and `SRCIP` to equal the configured remote
/// IP (listener side); the initiator already matches the exact resolved peer.
pub(super) fn validate_incoming_control(
    message: &crate::protocol::Mesg,
    sender: SocketAddr,
    settings: &StationSettings,
    expected_sender: Option<SocketAddr>,
    pin_sender_ip: bool,
) -> Result<(), SessionError> {
    if let Some(expected) = expected_sender {
        if sender != expected {
            return Err(SessionError::Protocol(format!(
                "control source mismatch: expected {expected}, got {sender}"
            )));
        }
    }
    if pin_sender_ip && sender.ip().to_string() != settings.network.remote_ip {
        return Err(SessionError::Protocol(
            "incoming control sender IP is not pinned to the configured peer".into(),
        ));
    }
    if settings.network.control_dialect != ControlDialect::Ascii {
        return (message.fields.get("SRCIP") == Some(&settings.network.remote_ip))
            .then_some(())
            .ok_or_else(|| {
                SessionError::Protocol("OSC15 control source does not match the peer".into())
            });
    }
    let expected_sid = settings.network.session_id.to_string();
    if (pin_sender_ip && message.fields.get("SRCIP") != Some(&sender.ip().to_string()))
        || message.fields.get("SRCIP") != Some(&settings.network.remote_ip)
        || message.fields.get("DSTIP") != Some(&settings.network.local_ip)
        || message.fields.get("SID") != Some(&expected_sid)
    {
        return Err(SessionError::Protocol(
            "control source, destination, or SID does not match the peer".into(),
        ));
    }
    Ok(())
}

pub(super) fn apply_stream_control(
    message: &crate::protocol::Mesg,
    result: &mut SessionResult,
    runtime_control: Option<&SessionRuntimeControl>,
) -> bool {
    push_bounded(&mut result.messages_received, message.name.clone());
    result.control_messages_received += 1;
    match message.name.as_str() {
        "/MESG_SWITCH_ON_BB" => result.bounce_back = Some(true),
        "/MESG_SWITCH_OFF_BB" => result.bounce_back = Some(false),
        "/MESG_CHAT" => {
            if let Some(text) = message.fields.get("TXT") {
                push_bounded(&mut result.chat_messages, unescape_txt_field(text));
            }
        }
        "/MESG_SEND_AUDIO_SIGNAL" => result.audio_signal_active = Some(true),
        "/MESG_STOP_AUDIO_SIGNAL" => result.audio_signal_active = Some(false),
        "/MESG_DISCONNECT" => {
            if let Some(control) = runtime_control {
                control.cancel();
            }
            return true;
        }
        _ => {}
    }
    false
}

/// Drains up to 64 pending control datagrams from the pinned peer. Stream
/// controls go to `handle`, which returns whether the peer disconnected; a
/// repeated `/MESG_QUICKCONN` (the initiator never saw the acknowledgement)
/// is passed to it too so the caller can answer it again.
pub(super) fn pump_control_from(
    mut receive: impl FnMut() -> std::io::Result<Option<(Vec<u8>, SocketAddr)>>,
    expected_sender: SocketAddr,
    settings: &StationSettings,
    pin_sender_ip: bool,
    mut handle: impl FnMut(&crate::protocol::Mesg) -> bool,
) -> Result<bool, SessionError> {
    for _ in 0..64 {
        match receive() {
            Ok(Some((data, sender))) => {
                if sender != expected_sender {
                    continue;
                }
                let Ok(message) = crate::protocol::decode_mesg(&data) else {
                    continue;
                };
                if validate_incoming_control(
                    &message,
                    sender,
                    settings,
                    Some(expected_sender),
                    pin_sender_ip,
                )
                .is_err()
                {
                    continue;
                }
                if (message.name == "/MESG_QUICKCONN" || is_stream_control(&message))
                    && handle(&message)
                {
                    return Ok(true);
                }
            }
            Ok(None) => return Ok(false),
            Err(error) => return Err(SessionError::Transport(error.to_string())),
        }
    }
    Ok(false)
}

/// Services inbound stream controls, answering a repeated QUICKCONN from
/// `quickconn_ack` when the responder holds one.
pub(super) fn pump_control(
    socket: &Udp,
    expected_sender: SocketAddr,
    settings: &StationSettings,
    result: &mut SessionResult,
    runtime_control: Option<&SessionRuntimeControl>,
    quickconn_ack: Option<&QuickconnAckCache>,
) -> Result<bool, SessionError> {
    pump_control_from(
        || socket.try_recv_vec(),
        expected_sender,
        settings,
        false,
        |message| {
            if message.name == "/MESG_QUICKCONN" {
                if let Some(ack) = quickconn_ack {
                    ack.resend_into(socket, expected_sender, result);
                }
                return false;
            }
            apply_stream_control(message, result, runtime_control)
        },
    )
}

#[cfg(test)]
mod chat_tests {
    use super::*;

    #[test]
    fn incoming_chat_text_is_unescaped() {
        let message = crate::protocol::Mesg {
            name: "/MESG_CHAT".into(),
            fields: [("TXT".to_string(), "hi%3A there%3B 100%25".to_string())].into(),
        };
        let mut result = SessionResult::default();
        assert!(!apply_stream_control(&message, &mut result, None));
        assert_eq!(result.chat_messages, vec!["hi: there; 100%".to_string()]);
    }
}
