use super::{SessionOptions, SessionResult, SessionRuntimeControl};
use crate::config::{ControlDialect, StationSettings};
use crate::net::{
    parse_mac_address, resolve_direct_lan_mac_via_ip_helper, resolve_mac_via_ip_helper, Udp,
};
use crate::protocol::{
    build_control_datagram, build_osc15_control_datagram, unescape_txt_field,
    MediaSettings as ProtocolMediaSettings, MESG_CHAT, MESG_DISCONNECT, MESG_STOP_AUDIO_SIGNAL,
};
use crate::station::bounded::push_bounded;
use crate::station::sync::lock_unpoison;
use crate::station::SessionError;
use std::net::{SocketAddr, ToSocketAddrs};
use std::sync::{Arc, Mutex};
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

    /// Re-sends the cached acknowledgement and records it in the shared result.
    /// A failed re-send is not a session failure: the initiator repeats its
    /// request and the next attempt answers it.
    pub(crate) fn resend(
        &self,
        socket: &Udp,
        peer: SocketAddr,
        shared: &Arc<Mutex<SessionResult>>,
    ) {
        if !self.claim_resend() || send_control_datagram(socket, &self.bytes, peer).is_err() {
            return;
        }
        push_bounded(
            &mut lock_unpoison(shared).messages_sent,
            "/MESG_QUICKCONN_ACK".into(),
        );
    }

    /// `resend` for callers that hold the session result directly.
    pub(crate) fn resend_into(&self, socket: &Udp, peer: SocketAddr, result: &mut SessionResult) {
        if !self.claim_resend() || send_control_datagram(socket, &self.bytes, peer).is_err() {
            return;
        }
        push_bounded(&mut result.messages_sent, "/MESG_QUICKCONN_ACK".into());
    }
}
pub(super) const QUICKCONN_REPLY_KINDS: &[&str] = &["/MESG_QUICKCONN_ACK", "/MESG_REJECT"];

/// Best-effort protocol cleanup for every successfully negotiated client session.
///
/// The normal path still reports checked sends. If a media/backend/recording
/// operation returns early, this guard keeps the peer from waiting indefinitely.
pub(super) struct ClientDisconnectGuard<'a> {
    socket: &'a Udp,
    peer: SocketAddr,
    stop_audio: Vec<u8>,
    disconnect: Vec<u8>,
    armed: bool,
}

impl<'a> ClientDisconnectGuard<'a> {
    pub(super) fn new(
        socket: &'a Udp,
        peer: SocketAddr,
        settings: &StationSettings,
    ) -> Result<Self, SessionError> {
        let encode = |kind| {
            build_session_control(
                settings,
                kind,
                &settings.network.local_ip,
                &settings.network.remote_ip,
                "",
                None,
            )
            .map_err(|error| SessionError::ControlHandshake(error.to_string()))
        };
        Ok(Self {
            socket,
            peer,
            stop_audio: encode(MESG_STOP_AUDIO_SIGNAL)?,
            disconnect: encode(MESG_DISCONNECT)?,
            armed: true,
        })
    }

    pub(super) fn disarm(&mut self) {
        self.armed = false;
    }
}

impl Drop for ClientDisconnectGuard<'_> {
    fn drop(&mut self) {
        if self.armed {
            let _ = send_control_datagram(self.socket, &self.stop_audio, self.peer);
            let _ = send_control_datagram(self.socket, &self.disconnect, self.peer);
        }
    }
}

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
        let encoded = if let Some(text) = command.strip_prefix("chat:") {
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
        };
        send_control_datagram(socket, &encoded, peer)?;
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

pub(super) fn build_session_control(
    settings: &StationSettings,
    kind: &str,
    src: &str,
    dst: &str,
    txt: &str,
    media: Option<&ProtocolMediaSettings>,
) -> Result<Vec<u8>, crate::protocol::ProtocolError> {
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

pub(super) fn validate_control_source(
    message: &crate::protocol::Mesg,
    sender: SocketAddr,
    expected_sender: SocketAddr,
    settings: &StationSettings,
) -> Result<(), SessionError> {
    if sender != expected_sender {
        return Err(SessionError::Protocol(format!(
            "control source mismatch: expected {expected_sender}, got {sender}"
        )));
    }
    if settings.network.control_dialect != ControlDialect::Ascii {
        return (message.fields.get("SRCIP") == Some(&settings.network.remote_ip))
            .then_some(())
            .ok_or_else(|| {
                SessionError::Protocol(
                    "OSC15 control source does not match the negotiated peer".into(),
                )
            });
    }
    let expected_sid = settings.network.session_id.to_string();
    if message.fields.get("SRCIP") != Some(&settings.network.remote_ip)
        || message.fields.get("DSTIP") != Some(&settings.network.local_ip)
        || message.fields.get("SID") != Some(&expected_sid)
    {
        return Err(SessionError::Protocol(
            "control SRCIP/DSTIP/SID does not match negotiated peer".into(),
        ));
    }
    Ok(())
}

/// Wait for a validated control reply in short, cancellable polls bounded by
/// one caller-owned deadline. This deliberately preserves the existing
/// SR/BPS/CH-only QUICKCONN matching performed after the reply is decoded.
pub(super) fn recv_valid_control_until(
    socket: &Udp,
    expected_sender: SocketAddr,
    settings: &StationSettings,
    deadline: Instant,
    runtime_control: Option<&SessionRuntimeControl>,
    accepted_kinds: &[&str],
) -> Result<crate::protocol::Mesg, SessionError> {
    const POLL: Duration = Duration::from_millis(10);
    let mut discarded = 0_u64;
    loop {
        if runtime_control.is_some_and(SessionRuntimeControl::is_cancelled) {
            return Err(SessionError::PeerDisconnect(
                "session cancelled while waiting for control reply".into(),
            ));
        }
        let now = Instant::now();
        if now >= deadline {
            return Err(SessionError::Timeout(format!(
                "control reply deadline elapsed after discarding {discarded} invalid control datagrams"
            )));
        }
        let poll = (deadline - now).min(POLL).as_secs_f64();
        socket
            .set_timeout(poll)
            .map_err(|error| SessionError::Transport(error.to_string()))?;
        match socket.recv_vec() {
            Ok((data, sender)) if sender == expected_sender => {
                let Ok(message) = crate::protocol::decode_mesg(&data) else {
                    discarded += 1;
                    continue;
                };
                if validate_control_source(&message, sender, expected_sender, settings).is_err()
                    || !accepted_kinds.contains(&message.name.as_str())
                {
                    discarded += 1;
                    continue;
                }
                return Ok(message);
            }
            Ok(_) => continue,
            Err(error)
                if matches!(
                    error.kind(),
                    std::io::ErrorKind::WouldBlock | std::io::ErrorKind::TimedOut
                ) =>
            {
                continue
            }
            Err(error) => return Err(SessionError::Transport(error.to_string())),
        }
    }
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

pub(super) fn validate_incoming_control(
    message: &crate::protocol::Mesg,
    sender: SocketAddr,
    settings: &StationSettings,
    expected_sender: Option<SocketAddr>,
) -> Result<(), SessionError> {
    if let Some(expected) = expected_sender {
        if sender != expected {
            return Err(SessionError::Protocol(format!(
                "control source mismatch: expected {expected}, got {sender}"
            )));
        }
    }
    if sender.ip().to_string() != settings.network.remote_ip {
        return Err(SessionError::Protocol(
            "incoming control sender IP is not pinned to the configured peer".into(),
        ));
    }
    if settings.network.control_dialect != ControlDialect::Ascii {
        return (message.fields.get("SRCIP") == Some(&settings.network.remote_ip))
            .then_some(())
            .ok_or_else(|| {
                SessionError::Protocol(
                    "OSC15 control source does not match the configured peer".into(),
                )
            });
    }
    let expected_sid = settings.network.session_id.to_string();
    if message.fields.get("SRCIP") != Some(&sender.ip().to_string())
        || message.fields.get("SRCIP") != Some(&settings.network.remote_ip)
        || message.fields.get("DSTIP") != Some(&settings.network.local_ip)
        || message.fields.get("SID") != Some(&expected_sid)
    {
        return Err(SessionError::Protocol(
            "incoming control source, destination, or SID is not pinned to the configured peer"
                .into(),
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

/// Services inbound stream controls. A repeated `/MESG_QUICKCONN` from the
/// pinned peer means the initiator never saw the acknowledgement; it is
/// answered again from `quickconn_ack` when the responder holds one.
pub(super) fn pump_control(
    socket: &Udp,
    expected_sender: SocketAddr,
    settings: &StationSettings,
    result: &mut SessionResult,
    runtime_control: Option<&SessionRuntimeControl>,
    quickconn_ack: Option<&QuickconnAckCache>,
) -> Result<bool, SessionError> {
    for _ in 0..64 {
        match socket.try_recv_vec() {
            Ok(Some((data, sender))) => {
                if sender != expected_sender {
                    continue;
                }
                let Ok(message) = crate::protocol::decode_mesg(&data) else {
                    continue;
                };
                if validate_control_source(&message, sender, expected_sender, settings).is_err() {
                    continue;
                }
                if message.name == "/MESG_QUICKCONN" {
                    if let Some(ack) = quickconn_ack {
                        ack.resend_into(socket, sender, result);
                    }
                    continue;
                }
                if !is_stream_control(&message) {
                    continue;
                }
                if apply_stream_control(&message, result, runtime_control) {
                    return Ok(true);
                }
            }
            Ok(None) => return Ok(false),
            Err(error) => return Err(SessionError::Transport(error.to_string())),
        }
    }
    Ok(false)
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
