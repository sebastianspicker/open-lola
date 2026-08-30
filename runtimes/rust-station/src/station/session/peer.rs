use super::control::{
    apply_stream_control, build_session_control, is_stream_control, resolve_local_session_mac,
    resolve_session_mac, send_control_datagram, validate_incoming_control,
};
use super::media::{
    recv_media, send_audio_media, send_video_media, should_stream_more, SessionMediaTransport,
};
use super::{SessionOptions, SessionResult};
use crate::config::{MediaTransportKind, StationSettings};
use crate::net::{NpcapMediaTransport, Udp};
use crate::protocol::{
    decode_mesg, parse_audio_frame, parse_quickconn_fields, parse_video_frame, FrameReassembler,
    MediaSettings as ProtocolMediaSettings, MESG_CHECKLOLASTATUS_ACK, MESG_QUICKCONN_ACK,
    MESG_REJECT,
};
use crate::station::sync::lock_unpoison;
use crate::station::SessionError;
use serde_json::Value;
use std::net::SocketAddr;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

mod listen;

const INITIAL_NEGOTIATION_KINDS: &[&str] = &["/MESG_CHECKLOLASTATUS", "/MESG_QUICKCONN"];
const QUICKCONN_NEGOTIATION_KINDS: &[&str] = &["/MESG_QUICKCONN"];

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
    let packet_size = settings.network.video_packet_size as usize;
    let negotiation_deadline = Instant::now() + Duration::from_secs_f64(to);
    let (mut msg, mut addr) = recv_peer_control_until(
        &ctrl,
        &settings,
        &options,
        None,
        negotiation_deadline,
        INITIAL_NEGOTIATION_KINDS,
    )?;
    let control_peer = addr;
    {
        let mut r = lock_unpoison(&shared);
        r.messages_received.push(msg.name.clone());
    }
    if msg.name == "/MESG_CHECKLOLASTATUS" {
        let ack = build_session_control(
            &settings,
            MESG_CHECKLOLASTATUS_ACK,
            &settings.network.local_ip,
            &settings.network.remote_ip,
            "",
            None,
        )
        .map_err(|e| SessionError::ControlHandshake(e.to_string()))?;
        send_control_datagram(&ctrl, &ack, addr)?;
        {
            let mut r = lock_unpoison(&shared);
            r.messages_sent.push("/MESG_CHECKLOLASTATUS_ACK".into());
        }
        let (quickconn, quickconn_addr) = recv_peer_control_until(
            &ctrl,
            &settings,
            &options,
            Some(control_peer),
            negotiation_deadline,
            QUICKCONN_NEGOTIATION_KINDS,
        )?;
        msg = quickconn;
        addr = quickconn_addr;
        lock_unpoison(&shared)
            .messages_received
            .push(msg.name.clone());
    }
    if msg.name != "/MESG_QUICKCONN" {
        return Err(SessionError::ControlHandshake(format!(
            "peer expected QUICKCONN got {}",
            msg.name
        )));
    }
    let caps =
        parse_quickconn_fields(&msg).map_err(|e| SessionError::ControlHandshake(e.to_string()))?;
    {
        let mut r = lock_unpoison(&shared);
        r.capabilities = caps.clone();
    }
    if options.peer_reject {
        let rej = build_session_control(
            &settings,
            MESG_REJECT,
            &settings.network.local_ip,
            &settings.network.remote_ip,
            "busy",
            None,
        )
        .map_err(|e| SessionError::ControlHandshake(e.to_string()))?;
        send_control_datagram(&ctrl, &rej, addr)?;
        let mut r = lock_unpoison(&shared);
        r.messages_sent.push("/MESG_REJECT".into());
        r.rejected = true;
        r.reject_text = "busy".into();
        return Ok(());
    }
    let audio_matches = caps.get("SR").and_then(Value::as_i64)
        == Some(i64::from(settings.audio.sample_rate))
        && caps.get("BPS").and_then(Value::as_i64)
            == Some(i64::from(settings.audio.bits_per_sample))
        && caps.get("CHNLS").and_then(Value::as_i64) == Some(i64::from(settings.audio.channels));
    if !audio_matches {
        let rejection = build_session_control(
            &settings,
            MESG_REJECT,
            &settings.network.local_ip,
            &settings.network.remote_ip,
            "audio settings mismatch",
            None,
        )
        .map_err(|error| SessionError::ControlHandshake(error.to_string()))?;
        send_control_datagram(&ctrl, &rejection, addr)?;
        let mut result = lock_unpoison(&shared);
        result.messages_sent.push("/MESG_REJECT".into());
        result.rejected = true;
        result.reject_text = "audio settings mismatch".into();
        return Ok(());
    }
    let get_i = |k: &str| -> i64 { caps.get(k).and_then(|v| v.as_i64()).unwrap_or(0) };
    let ack_media = ProtocolMediaSettings {
        sample_rate: get_i("SR") as u32,
        bits_per_sample: get_i("BPS") as u32,
        channels: get_i("CHNLS") as u32,
        fps: get_i("FPS") as u32,
        bits_per_pixel: get_i("BPP") as u32,
        width: get_i("X") as u32,
        height: get_i("Y") as u32,
        compression: get_i("COMP") as u32,
        bayer: get_i("BAYER") as u32,
    };
    let qack = build_session_control(
        &settings,
        MESG_QUICKCONN_ACK,
        &settings.network.local_ip,
        &settings.network.remote_ip,
        "",
        Some(&ack_media),
    )
    .map_err(|e| SessionError::ControlHandshake(e.to_string()))?;
    send_control_datagram(&ctrl, &qack, addr)?;
    {
        let mut r = lock_unpoison(&shared);
        r.messages_sent.push("/MESG_QUICKCONN_ACK".into());
    }

    ctrl.set_timeout(0.15).ok();
    let deadline = Instant::now()
        + if options.control_extras {
            Duration::from_millis(400)
        } else {
            Duration::ZERO
        };
    while Instant::now() < deadline {
        match ctrl.recv_vec() {
            Ok((data, sender)) => {
                let message = decode_mesg(&data)
                    .map_err(|error| SessionError::Protocol(error.to_string()))?;
                validate_incoming_control(&message, sender, &settings, Some(addr))?;
                let disconnected = {
                    let mut result = lock_unpoison(&shared);
                    apply_stream_control(&message, &mut result, options.runtime_control.as_ref())
                };
                if disconnected {
                    return Ok(());
                }
            }
            Err(_) => break,
        }
    }
    ctrl.set_timeout(0.001)
        .map_err(|error| SessionError::Transport(error.to_string()))?;

    let n_frames = options.stream_frames.max(1);
    let video_compressed = ack_media.compression == 1;
    let mut v_re = FrameReassembler::strict_video();
    let mut a_re =
        FrameReassembler::with_limit(settings.network.audio_receive_queue_depth.max(1) as usize);
    let requested_npcap = options
        .media_transport
        .unwrap_or(settings.network.media_transport)
        == MediaTransportKind::Npcap;
    let mut media_transport = if requested_npcap {
        if options.peer_mode.eq_ignore_ascii_case("loopback") {
            return Err(SessionError::Configuration(
                "Npcap cannot be used for loopback sessions".into(),
            ));
        }
        let source_ip = settings.network.local_ip.parse().map_err(|_| {
            SessionError::Configuration("Npcap requires a concrete local IPv4 address".into())
        })?;
        let peer_ip = match addr.ip() {
            std::net::IpAddr::V4(ip) => ip,
            std::net::IpAddr::V6(_) => {
                return Err(SessionError::Configuration(
                    "Npcap requires an IPv4 peer".into(),
                ))
            }
        };
        let device = options
            .pcap_device
            .as_deref()
            .filter(|value| !value.is_empty())
            .or_else(|| {
                (!settings.network.pcap_device.is_empty())
                    .then_some(settings.network.pcap_device.as_str())
            })
            .ok_or_else(|| {
                SessionError::Configuration("Npcap requires an explicitly selected adapter".into())
            })?;
        let source_mac =
            resolve_local_session_mac("RUSTY_LOLA_LOCAL_MAC", source_ip, peer_ip, device)?;
        let peer_mac = resolve_session_mac("RUSTY_LOLA_PEER_MAC", peer_ip, source_ip)?;
        let mut transport = NpcapMediaTransport::open(
            device,
            source_ip,
            peer_ip,
            source_mac,
            peer_mac,
            ports.audio,
            ports.video,
            settings.network.vlan_tag,
        )
        .map_err(SessionError::Transport)?;
        transport
            .set_queue_depths(
                settings.network.audio_receive_queue_depth as usize,
                settings.network.video_receive_queue_depth as usize,
            )
            .map_err(SessionError::Transport)?;
        SessionMediaTransport::npcap(transport)
    } else if options.peer_mode.eq_ignore_ascii_case("loopback") {
        SessionMediaTransport::diagnostic_udp(audio, video)
    } else {
        SessionMediaTransport::udp_from_bound_sockets(
            audio,
            video,
            addr.ip(),
            ports.audio,
            ports.video,
        )?
    };
    if options.peer_mode.eq_ignore_ascii_case("listen") {
        let primary = listen::run_listen_media(
            &settings,
            &options,
            &shared,
            &ctrl,
            addr,
            ports.audio,
            ports.video,
            packet_size,
            n_frames,
            video_compressed,
            ack_media.bits_per_pixel,
            &mut media_transport,
        );
        let transport_cleanup = media_transport.shutdown();
        if let Err(error) = &transport_cleanup {
            lock_unpoison(&shared)
                .cleanup_warnings
                .push(format!("media transport: {error}"));
        }
        return match primary {
            Err(error) => Err(error),
            Ok(()) => transport_cleanup,
        };
    }
    let do_video = (options.stream_tx_video || options.stream_rx_video) && !options.audio_only;
    let do_audio = options.stream_tx_audio || options.stream_rx_audio;
    let t0 = Instant::now();
    let expected_video_peer = (!options.peer_mode.eq_ignore_ascii_case("loopback"))
        .then(|| SocketAddr::new(addr.ip(), ports.video));
    let expected_audio_peer = (!options.peer_mode.eq_ignore_ascii_case("loopback"))
        .then(|| SocketAddr::new(addr.ip(), ports.audio));
    let mut media_control_pump = || pump_peer_control(&ctrl, addr, &settings, &options, &shared);

    if options.interleaved_av {
        let mut frame_i = 0u32;
        while should_stream_more(frame_i, n_frames, t0, options.duration_sec, &options) {
            if pump_peer_control(&ctrl, addr, &settings, &options, &shared)? {
                return Ok(());
            }
            if do_audio {
                let (frame, dest) = recv_media(
                    &mut media_transport,
                    &mut a_re,
                    expected_audio_peer,
                    true,
                    0.0,
                    options.runtime_control.as_ref(),
                    Some(&mut media_control_pump),
                )?;
                let frame = parse_audio_frame(&frame)
                    .map_err(|error| SessionError::Protocol(error.to_string()))?;
                send_audio_media(&mut media_transport, &frame, dest)?;
                let mut result = lock_unpoison(&shared);
                result.audio_frames_received += 1;
                result.audio_frames_sent += 1;
                result.media_frames_received += 1;
                result.media_frames_sent += 1;
            }
            if do_video {
                let (frame, dest) = recv_media(
                    &mut media_transport,
                    &mut v_re,
                    expected_video_peer,
                    false,
                    options.incomplete_frame_threshold_pct,
                    options.runtime_control.as_ref(),
                    Some(&mut media_control_pump),
                )?;
                let frame = parse_video_frame(&frame, video_compressed)
                    .map_err(|error| SessionError::Protocol(error.to_string()))?;
                send_video_media(&mut media_transport, &frame, dest, packet_size)?;
                let mut result = lock_unpoison(&shared);
                result.video_frames_received += 1;
                result.video_frames_sent += 1;
                result.media_frames_received += 1;
                result.media_frames_sent += 1;
            }
            frame_i += 1;
        }
    } else {
        let mut planned = n_frames;
        if do_video {
            let mut frame_i = 0u32;
            while should_stream_more(frame_i, n_frames, t0, options.duration_sec, &options) {
                if pump_peer_control(&ctrl, addr, &settings, &options, &shared)? {
                    return Ok(());
                }
                let (frame, dest) = recv_media(
                    &mut media_transport,
                    &mut v_re,
                    expected_video_peer,
                    false,
                    options.incomplete_frame_threshold_pct,
                    options.runtime_control.as_ref(),
                    Some(&mut media_control_pump),
                )?;
                let frame = parse_video_frame(&frame, video_compressed)
                    .map_err(|error| SessionError::Protocol(error.to_string()))?;
                send_video_media(&mut media_transport, &frame, dest, packet_size)?;
                let mut result = lock_unpoison(&shared);
                result.video_frames_received += 1;
                result.video_frames_sent += 1;
                result.media_frames_received += 1;
                result.media_frames_sent += 1;
                frame_i += 1;
            }
            planned = frame_i.max(n_frames);
        }
        if do_audio {
            for _ in 0..planned {
                if pump_peer_control(&ctrl, addr, &settings, &options, &shared)? {
                    return Ok(());
                }
                let (frame, dest) = recv_media(
                    &mut media_transport,
                    &mut a_re,
                    expected_audio_peer,
                    true,
                    0.0,
                    options.runtime_control.as_ref(),
                    Some(&mut media_control_pump),
                )?;
                let frame = parse_audio_frame(&frame)
                    .map_err(|error| SessionError::Protocol(error.to_string()))?;
                send_audio_media(&mut media_transport, &frame, dest)?;
                let mut result = lock_unpoison(&shared);
                result.audio_frames_received += 1;
                result.audio_frames_sent += 1;
                result.media_frames_received += 1;
                result.media_frames_sent += 1;
            }
        }
    }

    media_transport.shutdown()?;
    Ok(())
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

fn pump_peer_control(
    socket: &Udp,
    expected_sender: SocketAddr,
    settings: &StationSettings,
    options: &SessionOptions,
    shared: &Arc<Mutex<SessionResult>>,
) -> Result<bool, SessionError> {
    loop {
        match socket.try_recv_vec() {
            Ok(Some((data, sender))) => {
                if sender != expected_sender {
                    continue;
                }
                let Ok(message) = decode_mesg(&data) else {
                    continue;
                };
                if validate_incoming_control(&message, sender, settings, Some(expected_sender))
                    .is_err()
                    || !is_stream_control(&message)
                {
                    continue;
                }
                let mut result = lock_unpoison(shared);
                if apply_stream_control(&message, &mut result, options.runtime_control.as_ref()) {
                    return Ok(true);
                }
            }
            Ok(None) => return Ok(false),
            Err(error) => return Err(SessionError::Transport(error.to_string())),
        }
    }
}
