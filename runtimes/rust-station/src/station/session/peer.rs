use super::control::{
    apply_stream_control, build_session_control, send_control_datagram, validate_incoming_control,
    QuickconnAckCache,
};
use super::media::SessionMediaTransport;
use super::{SessionOptions, SessionResult};
use crate::config::{MediaTransportKind, StationSettings};
use crate::net::Udp;
use crate::protocol::{
    decode_mesg, MediaSettings as ProtocolMediaSettings, MESG_CHECKLOLASTATUS_ACK,
    MESG_QUICKCONN_ACK, MESG_REJECT,
};
use crate::station::sync::lock_unpoison;
use crate::station::SessionError;
use serde_json::Value;
use std::net::SocketAddr;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

mod handshake;
mod listen;
#[cfg(test)]
#[path = "peer/negotiation_tests.rs"]
mod negotiation_tests;
mod relay;

use handshake::pump_peer_control;
#[cfg(test)]
use handshake::pump_peer_control_from;
use handshake::{quickconn_capabilities, video_negotiated};

const INITIAL_NEGOTIATION_KINDS: &[&str] = &["/MESG_CHECKLOLASTATUS", "/MESG_QUICKCONN"];

#[derive(Clone, Copy)]
pub(super) struct PeerPorts {
    pub(super) control: u16,
    pub(super) audio: u16,
    pub(super) video: u16,
}

pub(super) struct PeerSockets {
    control: Udp,
    audio: Udp,
    video: Udp,
}

impl PeerSockets {
    fn bind(host: &str, ports: PeerPorts) -> Result<Self, SessionError> {
        let bind = |port| {
            Udp::bind(host, port).map_err(|error| SessionError::Transport(error.to_string()))
        };
        Ok(Self {
            control: bind(ports.control)?,
            audio: bind(ports.audio)?,
            video: bind(ports.video)?,
        })
    }

    pub(super) fn bind_ephemeral(host: &str) -> Result<(Self, PeerPorts), SessionError> {
        let sockets = Self::bind(
            host,
            PeerPorts {
                control: 0,
                audio: 0,
                video: 0,
            },
        )?;
        let ports = sockets.ports()?;
        Ok((sockets, ports))
    }

    fn ports(&self) -> Result<PeerPorts, SessionError> {
        let local_port = |socket: &Udp| {
            socket
                .local_addr()
                .map(|address| address.port())
                .map_err(|error| SessionError::Transport(error.to_string()))
        };
        Ok(PeerPorts {
            control: local_port(&self.control)?,
            audio: local_port(&self.audio)?,
            video: local_port(&self.video)?,
        })
    }
}

pub(super) fn peer_thread(
    settings: StationSettings,
    sockets: PeerSockets,
    options: SessionOptions,
    shared: Arc<Mutex<SessionResult>>,
    timeout: f64,
) {
    if let Err(e) =
        peer_session_body_with_sockets(settings, sockets, options, shared.clone(), timeout)
    {
        if matches!(e, SessionError::PeerDisconnect(_)) {
            return;
        }
        let mut r = lock_unpoison(&shared);
        if r.error.is_empty() {
            r.error = e.to_string();
            r.failure = Some(e);
        }
    }
}
pub(super) fn peer_session_body(
    settings: StationSettings,
    ports: PeerPorts,
    options: SessionOptions,
    shared: Arc<Mutex<SessionResult>>,
    timeout: f64,
) -> Result<(), SessionError> {
    let sockets = PeerSockets::bind(&settings.network.bind_ip, ports)?;
    peer_session_body_with_sockets(settings, sockets, options, shared, timeout)
}

fn peer_session_body_with_sockets(
    settings: StationSettings,
    sockets: PeerSockets,
    options: SessionOptions,
    shared: Arc<Mutex<SessionResult>>,
    timeout: f64,
) -> Result<(), SessionError> {
    let ports = sockets.ports()?;
    let PeerSockets {
        control: ctrl,
        audio,
        video,
    } = sockets;
    let to = timeout.max(5.0);
    ctrl.set_timeout(to).ok();
    let media_timeout = if options.persistent { 0.1 } else { to };
    audio.set_timeout(media_timeout).ok();
    video.set_timeout(media_timeout).ok();
    let negotiation = negotiate_peer(
        &settings,
        &options,
        &shared,
        &ctrl,
        listener_negotiation_deadline(&options, Duration::from_secs_f64(to)),
    )?;
    let Some(negotiation) = negotiation else {
        return Ok(());
    };
    if receive_peer_control_extras(&ctrl, &settings, &options, &shared, negotiation.addr)? {
        return Ok(());
    }
    ctrl.set_timeout(0.001)
        .map_err(|error| SessionError::Transport(error.to_string()))?;
    let packet_size = settings.network.video_packet_size as usize;
    let n_frames = options.stream_frames.max(1);
    let mut media_transport =
        open_peer_media_transport(&settings, &options, audio, video, negotiation.addr, ports)?;
    if options.peer_mode.eq_ignore_ascii_case("listen") {
        return run_listen_peer_media(
            &settings,
            &options,
            &shared,
            &ctrl,
            negotiation,
            ports,
            packet_size,
            n_frames,
            &mut media_transport,
        );
    }
    relay::run_peer_relay(
        &settings,
        &options,
        &shared,
        &ctrl,
        negotiation,
        ports,
        packet_size,
        n_frames,
        &mut media_transport,
    )
}

struct PeerNegotiation {
    addr: SocketAddr,
    ack_media: ProtocolMediaSettings,
    ack: QuickconnAckCache,
}

/// A persistent listener waits for its peer until the operator cancels it;
/// its receive loop polls cancellation every 10 ms. Finite diagnostic runs
/// keep the caller's timeout.
fn listener_negotiation_deadline(options: &SessionOptions, timeout: Duration) -> Instant {
    let now = Instant::now();
    if options.persistent {
        return now
            .checked_add(Duration::from_secs(365 * 86_400))
            .unwrap_or(now + timeout);
    }
    now + timeout
}

fn negotiate_peer(
    settings: &StationSettings,
    options: &SessionOptions,
    shared: &Arc<Mutex<SessionResult>>,
    control_socket: &Udp,
    deadline: Instant,
) -> Result<Option<PeerNegotiation>, SessionError> {
    let (mut message, mut addr) = recv_peer_control_until(
        control_socket,
        settings,
        options,
        None,
        deadline,
        INITIAL_NEGOTIATION_KINDS,
    )?;
    let control_peer = addr;
    lock_unpoison(shared)
        .messages_received
        .push(message.name.clone());
    // The initiator re-sends an unanswered status check. Every repeat is
    // acknowledged again so a lost acknowledgement cannot stall the handshake.
    while message.name == "/MESG_CHECKLOLASTATUS" {
        acknowledge_status(control_socket, settings, shared, addr)?;
        (message, addr) = recv_peer_control_until(
            control_socket,
            settings,
            options,
            Some(control_peer),
            deadline,
            INITIAL_NEGOTIATION_KINDS,
        )?;
        lock_unpoison(shared)
            .messages_received
            .push(message.name.clone());
    }
    if message.name != "/MESG_QUICKCONN" {
        return Err(SessionError::ControlHandshake(format!(
            "peer expected QUICKCONN got {}",
            message.name
        )));
    }
    let capabilities = match quickconn_capabilities(&message, options) {
        Ok(capabilities) => capabilities,
        Err(error) => {
            let reason = format!("invalid media settings: {error}");
            reject_peer(control_socket, settings, shared, addr, &reason)?;
            return Ok(None);
        }
    };
    lock_unpoison(shared).capabilities = capabilities.clone();
    if let Some(reason) = peer_rejection_reason(settings, options, &capabilities) {
        reject_peer(control_socket, settings, shared, addr, reason)?;
        return Ok(None);
    }
    let ack_media = peer_ack_media(&capabilities);
    let ack = build_session_control(
        settings,
        MESG_QUICKCONN_ACK,
        &settings.network.local_ip,
        &settings.network.remote_ip,
        "",
        Some(&ack_media),
    )
    .map_err(|error| SessionError::ControlHandshake(error.to_string()))?;
    send_control_datagram(control_socket, &ack, addr)?;
    lock_unpoison(shared)
        .messages_sent
        .push("/MESG_QUICKCONN_ACK".into());
    Ok(Some(PeerNegotiation {
        addr,
        ack_media,
        ack: QuickconnAckCache::new(ack),
    }))
}

fn acknowledge_status(
    control_socket: &Udp,
    settings: &StationSettings,
    shared: &Arc<Mutex<SessionResult>>,
    peer: SocketAddr,
) -> Result<(), SessionError> {
    let ack = build_session_control(
        settings,
        MESG_CHECKLOLASTATUS_ACK,
        &settings.network.local_ip,
        &settings.network.remote_ip,
        "",
        None,
    )
    .map_err(|error| SessionError::ControlHandshake(error.to_string()))?;
    send_control_datagram(control_socket, &ack, peer)?;
    lock_unpoison(shared)
        .messages_sent
        .push("/MESG_CHECKLOLASTATUS_ACK".into());
    Ok(())
}

fn peer_rejection_reason(
    settings: &StationSettings,
    options: &SessionOptions,
    capabilities: &std::collections::BTreeMap<String, Value>,
) -> Option<&'static str> {
    if options.peer_reject {
        return Some("busy");
    }
    let audio_matches = capabilities.get("SR").and_then(Value::as_i64)
        == Some(i64::from(settings.audio.sample_rate))
        && capabilities.get("BPS").and_then(Value::as_i64)
            == Some(i64::from(settings.audio.bits_per_sample))
        && capabilities.get("CHNLS").and_then(Value::as_i64)
            == Some(i64::from(settings.audio.channels));
    if !audio_matches {
        return Some("audio settings mismatch");
    }
    if !video_negotiated(options) {
        return None;
    }
    if capabilities.get("FPS").and_then(Value::as_i64) != Some(i64::from(settings.video.fps)) {
        return Some("video frame rate mismatch");
    }
    let compressed = capabilities.get("COMP").and_then(Value::as_i64) == Some(1);
    let (output_bpp, output_bayer) =
        super::video::negotiated_output_format(settings, options, compressed);
    if capabilities.get("BPP").and_then(Value::as_i64) != Some(i64::from(output_bpp)) {
        return Some("video pixel format mismatch");
    }
    if capabilities.get("BAYER").and_then(Value::as_i64) != Some(i64::from(output_bayer)) {
        return Some("video Bayer format mismatch");
    }
    None
}

fn reject_peer(
    control_socket: &Udp,
    settings: &StationSettings,
    shared: &Arc<Mutex<SessionResult>>,
    peer: SocketAddr,
    reason: &str,
) -> Result<(), SessionError> {
    let rejection = build_session_control(
        settings,
        MESG_REJECT,
        &settings.network.local_ip,
        &settings.network.remote_ip,
        reason,
        None,
    )
    .map_err(|error| SessionError::ControlHandshake(error.to_string()))?;
    send_control_datagram(control_socket, &rejection, peer)?;
    let mut result = lock_unpoison(shared);
    result.messages_sent.push("/MESG_REJECT".into());
    result.rejected = true;
    result.reject_text = reason.into();
    Ok(())
}

fn peer_ack_media(
    capabilities: &std::collections::BTreeMap<String, Value>,
) -> ProtocolMediaSettings {
    let value = |key| capabilities.get(key).and_then(Value::as_i64).unwrap_or(0) as u32;
    ProtocolMediaSettings {
        sample_rate: value("SR"),
        bits_per_sample: value("BPS"),
        channels: value("CHNLS"),
        fps: value("FPS"),
        bits_per_pixel: value("BPP"),
        width: value("X"),
        height: value("Y"),
        compression: value("COMP"),
        bayer: value("BAYER"),
    }
}

fn receive_peer_control_extras(
    control_socket: &Udp,
    settings: &StationSettings,
    options: &SessionOptions,
    shared: &Arc<Mutex<SessionResult>>,
    peer: SocketAddr,
) -> Result<bool, SessionError> {
    control_socket.set_timeout(0.15).ok();
    let deadline = Instant::now()
        + if options.control_extras {
            Duration::from_millis(400)
        } else {
            Duration::ZERO
        };
    while Instant::now() < deadline {
        let Ok((data, sender)) = control_socket.recv_vec() else {
            break;
        };
        let Ok(message) = decode_mesg(&data) else {
            continue;
        };
        if validate_incoming_control(&message, sender, settings, Some(peer)).is_err() {
            continue;
        }
        let disconnected = {
            let mut result = lock_unpoison(shared);
            apply_stream_control(&message, &mut result, options.runtime_control.as_ref())
        };
        if disconnected {
            return Ok(true);
        }
    }
    Ok(false)
}

#[allow(clippy::too_many_arguments)]
fn open_peer_media_transport(
    settings: &StationSettings,
    options: &SessionOptions,
    audio: Udp,
    video: Udp,
    peer: SocketAddr,
    ports: PeerPorts,
) -> Result<SessionMediaTransport, SessionError> {
    let requested_npcap = options
        .media_transport
        .unwrap_or(settings.network.media_transport)
        == MediaTransportKind::Npcap;
    if requested_npcap {
        return super::npcap::open_npcap_media_transport(
            settings,
            options,
            peer,
            ports.audio,
            ports.video,
        );
    }
    if options.peer_mode.eq_ignore_ascii_case("loopback") {
        return Ok(SessionMediaTransport::diagnostic_udp(audio, video));
    }
    SessionMediaTransport::udp_from_bound_sockets(audio, video, peer.ip(), ports.audio, ports.video)
}

#[allow(clippy::too_many_arguments)]
fn run_listen_peer_media(
    settings: &StationSettings,
    options: &SessionOptions,
    shared: &Arc<Mutex<SessionResult>>,
    control_socket: &Udp,
    negotiation: PeerNegotiation,
    ports: PeerPorts,
    packet_size: usize,
    n_frames: u32,
    media_transport: &mut SessionMediaTransport,
) -> Result<(), SessionError> {
    let primary = listen::run_listen_media(
        settings,
        options,
        shared,
        control_socket,
        negotiation.addr,
        ports.audio,
        ports.video,
        packet_size,
        n_frames,
        &negotiation.ack_media,
        media_transport,
        Some(&negotiation.ack),
    );
    let cleanup = media_transport.shutdown();
    {
        let mut result = lock_unpoison(shared);
        super::lifecycle::record_cached_transport_stats(&mut result, media_transport.stats());
    }
    if let Err(error) = &cleanup {
        lock_unpoison(shared)
            .cleanup_warnings
            .push(format!("media transport: {error}"));
    }
    primary.and(cleanup)
}

fn recv_peer_control_until(
    socket: &Udp,
    settings: &StationSettings,
    options: &SessionOptions,
    expected_sender: Option<SocketAddr>,
    deadline: Instant,
    accepted_kinds: &[&str],
) -> Result<(crate::protocol::Mesg, SocketAddr), SessionError> {
    const POLL: Duration = Duration::from_millis(10);
    let mut discarded = 0_u64;
    loop {
        if options
            .runtime_control
            .as_ref()
            .is_some_and(super::SessionRuntimeControl::is_cancelled)
        {
            return Err(SessionError::PeerDisconnect(
                "session cancelled during listener negotiation".into(),
            ));
        }
        let now = Instant::now();
        if now >= deadline {
            return Err(SessionError::Timeout(format!(
                "listener control negotiation deadline elapsed after discarding {discarded} invalid control datagrams"
            )));
        }
        socket
            .set_timeout((deadline - now).min(POLL).as_secs_f64())
            .map_err(|error| SessionError::Transport(error.to_string()))?;
        match socket.recv_vec() {
            Ok((data, sender)) => {
                if expected_sender.is_some_and(|expected| sender != expected)
                    || sender.ip().to_string() != settings.network.remote_ip
                    || (!options.peer_mode.eq_ignore_ascii_case("loopback")
                        && sender.port() != settings.network.control_port)
                {
                    continue;
                }
                let Ok(message) = decode_mesg(&data) else {
                    discarded += 1;
                    continue;
                };
                if validate_incoming_control(&message, sender, settings, expected_sender).is_err()
                    || !accepted_kinds.contains(&message.name.as_str())
                {
                    discarded += 1;
                    continue;
                }
                return Ok((message, sender));
            }
            Err(error)
                if matches!(
                    error.kind(),
                    std::io::ErrorKind::WouldBlock | std::io::ErrorKind::TimedOut
                ) => {}
            Err(error) => return Err(SessionError::Transport(error.to_string())),
        }
    }
}
