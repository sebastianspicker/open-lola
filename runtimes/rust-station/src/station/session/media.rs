use super::{SessionOptions, SessionRuntimeControl};
use crate::net::{
    MediaKind, MediaTransport, NpcapMediaTransport, ReceivedDatagram, TransportError,
    TransportStats, Udp, UdpMediaTransport,
};
use crate::protocol::{
    build_video_payloads, AudioDatagramWriter, FrameReassembler, MediaError, VideoFrame,
    AUDIO_UDP_PAYLOAD_SIZE,
};
use crate::station::SessionError;
use std::collections::VecDeque;
use std::net::SocketAddr;
use std::thread;
use std::time::Instant;

/// Session-owned media plane. Production remote/listen sessions use a real
/// `MediaTransport`; only diagnostic loopback retains its ephemeral UDP path.
pub(super) enum SessionMediaTransport {
    DiagnosticUdp {
        audio: Udp,
        video: Udp,
        stats: TransportStats,
    },
    Udp(UdpMediaTransport),
    Npcap(Box<NpcapMediaTransport>),
}

/// Scheduler-facing result for one video datagram send. Transport-specific
/// errors are normalized here so scheduling never interprets error text.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(super) enum VideoSendDisposition {
    Sent,
    WouldBlock,
}

impl SessionMediaTransport {
    pub(super) fn diagnostic_udp(audio: Udp, video: Udp) -> Self {
        Self::DiagnosticUdp {
            audio,
            video,
            stats: TransportStats::default(),
        }
    }

    pub(super) fn udp_from_bound_sockets(
        audio: Udp,
        video: Udp,
        peer_ip: std::net::IpAddr,
        audio_port: u16,
        video_port: u16,
    ) -> Result<Self, SessionError> {
        UdpMediaTransport::from_bound_sockets(audio, video, peer_ip, audio_port, video_port)
            .map(Self::Udp)
            .map_err(SessionError::Transport)
    }

    pub(super) fn npcap(transport: NpcapMediaTransport) -> Self {
        Self::Npcap(Box::new(transport))
    }

    fn socket(&self, kind: MediaKind) -> &Udp {
        match self {
            Self::DiagnosticUdp { audio, video, .. } => match kind {
                MediaKind::Audio => audio,
                MediaKind::Video => video,
            },
            Self::Udp(_) | Self::Npcap(_) => {
                unreachable!("production transport has no direct socket")
            }
        }
    }

    pub(super) fn send(
        &mut self,
        kind: MediaKind,
        payload: &[u8],
        destination: SocketAddr,
    ) -> Result<(), SessionError> {
        self.send_transport(kind, payload, destination)
            .map_err(transport_session_error)
    }

    fn send_transport(
        &mut self,
        kind: MediaKind,
        payload: &[u8],
        destination: SocketAddr,
    ) -> Result<(), TransportError> {
        match self {
            Self::DiagnosticUdp { .. } => {
                let sent = self
                    .socket(kind)
                    .send_to(payload, destination)
                    .map_err(TransportError::from_io)?;
                if sent != payload.len() {
                    return Err(TransportError::Backpressure(format!(
                        "partial UDP datagram send: {sent}/{}",
                        payload.len()
                    )));
                }
                if let Self::DiagnosticUdp { stats, .. } = self {
                    stats.sent_datagrams += 1;
                    stats.sent_bytes += sent as u64;
                }
                Ok(())
            }
            Self::Udp(transport) => transport.send(kind, payload),
            Self::Npcap(transport) => transport.send(kind, payload),
        }
    }

    pub(super) fn send_video_datagram(
        &mut self,
        payload: &[u8],
        destination: SocketAddr,
    ) -> Result<VideoSendDisposition, SessionError> {
        match self.send_transport(MediaKind::Video, payload, destination) {
            Ok(()) => Ok(VideoSendDisposition::Sent),
            Err(TransportError::WouldBlock | TransportError::Backpressure(_)) => {
                Ok(VideoSendDisposition::WouldBlock)
            }
            Err(error) => Err(transport_session_error(error)),
        }
    }

    pub(super) fn receive_kind(
        &mut self,
        kind: MediaKind,
    ) -> Result<Option<ReceivedDatagram>, SessionError> {
        match self {
            Self::DiagnosticUdp { .. } => match self.socket(kind).try_recv_vec() {
                Ok(Some((payload, peer))) => {
                    if let Self::DiagnosticUdp { stats, .. } = self {
                        stats.received_datagrams += 1;
                        stats.received_bytes += payload.len() as u64;
                    }
                    Ok(Some(ReceivedDatagram {
                        kind,
                        peer,
                        source_port: peer.port(),
                        received_at: std::time::SystemTime::now(),
                        payload,
                    }))
                }
                Ok(None) => Ok(None),
                Err(error) => Err(SessionError::Transport(error.to_string())),
            },
            Self::Udp(transport) => transport
                .receive_kind(kind)
                .map_err(transport_session_error),
            Self::Npcap(transport) => transport
                .receive_kind(kind)
                .map_err(transport_session_error),
        }
    }

    pub(super) fn stats(&self) -> TransportStats {
        match self {
            Self::DiagnosticUdp { stats, .. } => *stats,
            Self::Udp(transport) => transport.stats(),
            Self::Npcap(transport) => transport.stats(),
        }
    }

    pub(super) fn stats_snapshot(&mut self) -> Result<TransportStats, SessionError> {
        match self {
            Self::DiagnosticUdp { stats, .. } => Ok(*stats),
            Self::Udp(transport) => transport.stats_snapshot().map_err(transport_session_error),
            Self::Npcap(transport) => transport.stats_snapshot().map_err(transport_session_error),
        }
    }

    pub(super) fn shutdown(&mut self) -> Result<(), SessionError> {
        match self {
            Self::DiagnosticUdp { .. } => Ok(()),
            Self::Udp(transport) => transport
                .shutdown()
                .map_err(|error| SessionError::Cleanup(error.to_string())),
            Self::Npcap(transport) => transport
                .shutdown()
                .map_err(|error| SessionError::Cleanup(error.to_string())),
        }
    }
}

fn transport_session_error(error: TransportError) -> SessionError {
    SessionError::Transport(error.to_string())
}

pub(super) struct ReceivePrefillQueue<T> {
    queue: VecDeque<T>,
    depth: usize,
    prefill: usize,
    started: bool,
    latest_sequence: Option<u32>,
}

impl<T> ReceivePrefillQueue<T> {
    pub(super) fn new(depth: u32, prefill: u32) -> Self {
        let depth = depth.max(1) as usize;
        Self {
            queue: VecDeque::with_capacity(depth),
            depth,
            prefill: (prefill as usize).min(depth),
            started: prefill == 0,
            latest_sequence: None,
        }
    }

    pub(super) fn admit_sequence(&mut self, sequence: u32) -> bool {
        if self
            .latest_sequence
            .is_some_and(|last| !crate::protocol::serial_u32_is_newer(sequence, last))
        {
            return false;
        }
        self.latest_sequence = Some(sequence);
        true
    }

    pub(super) fn push(&mut self, item: T) -> (Option<T>, bool) {
        let replaced = if self.queue.len() >= self.depth {
            self.queue.pop_front().is_some()
        } else {
            false
        };
        self.queue.push_back(item);
        if !self.started && self.queue.len() >= self.prefill {
            self.started = true;
        }
        (
            self.started.then(|| self.queue.pop_front()).flatten(),
            replaced,
        )
    }
}
pub(super) fn send_video_media(
    transport: &mut SessionMediaTransport,
    frame: &VideoFrame,
    addr: SocketAddr,
    packet_size: usize,
) -> Result<(), SessionError> {
    // Validate the typed body before fragmenting it. The `compressed` bit is
    // negotiated context and intentionally does not change LoLa body bytes.
    frame
        .serialize()
        .map_err(|error| SessionError::Protocol(error.to_string()))?;
    for datagram in build_video_payloads(frame.sequence, &frame.payload, None, packet_size) {
        transport.send(MediaKind::Video, &datagram, addr)?;
    }
    Ok(())
}

pub(super) fn send_audio_media(
    transport: &mut SessionMediaTransport,
    sequence: u32,
    pcm: &[u8],
    addr: SocketAddr,
    writer: &mut AudioDatagramWriter,
) -> Result<(), SessionError> {
    if pcm.is_empty() {
        return Err(SessionError::Protocol(MediaError::EmptyPcm.to_string()));
    }
    let datagram = writer
        .write(sequence, pcm, None)
        .map_err(|error| SessionError::Protocol(error.to_string()))?;
    transport.send(MediaKind::Audio, datagram, addr)?;
    Ok(())
}

#[allow(clippy::too_many_arguments)]
pub(super) fn recv_media(
    transport: &mut SessionMediaTransport,
    reasm: &mut FrameReassembler,
    expected_peer: Option<SocketAddr>,
    require_audio_size: bool,
    incomplete_frame_threshold_pct: f64,
    runtime_control: Option<&SessionRuntimeControl>,
    mut control_pump: Option<&mut dyn FnMut() -> Result<bool, SessionError>>,
    malformed_drops: &mut u64,
) -> Result<(Vec<u8>, SocketAddr), SessionError> {
    // This retry adapter is used only by sequential diagnostic exchange.
    // Native sessions use one-datagram scheduler steps.
    let deadline = Instant::now() + std::time::Duration::from_secs(5);
    let mut last_media_peer = None;
    loop {
        if runtime_control.is_some_and(SessionRuntimeControl::is_cancelled) {
            return Err(SessionError::PeerDisconnect("session cancelled".into()));
        }
        if Instant::now() >= deadline {
            return Err(SessionError::Timeout(
                "diagnostic media receive exceeded five seconds".into(),
            ));
        }
        if let Some(pump) = control_pump.as_mut() {
            if (**pump)()? {
                return Err(SessionError::PeerDisconnect("peer disconnected".into()));
            }
        }
        let expected_kind = if require_audio_size {
            MediaKind::Audio
        } else {
            MediaKind::Video
        };
        let Some(datagram) = transport.receive_kind(expected_kind)? else {
            if !require_audio_size {
                if let (Some(frame), Some(peer)) = (
                    reasm.take_expired_partial(incomplete_frame_threshold_pct),
                    last_media_peer,
                ) {
                    return Ok((frame, peer));
                }
            }
            if let Some(pump) = control_pump.as_mut() {
                if (**pump)()? {
                    return Err(SessionError::PeerDisconnect("peer disconnected".into()));
                }
            }
            if runtime_control.is_some_and(SessionRuntimeControl::is_cancelled) {
                return Err(SessionError::PeerDisconnect("session cancelled".into()));
            }
            thread::yield_now();
            continue;
        };
        let (data, peer) = (datagram.payload, datagram.peer);
        if expected_peer.is_some_and(|expected| peer != expected) {
            continue;
        }
        last_media_peer = Some(peer);
        if require_audio_size && data.len() != AUDIO_UDP_PAYLOAD_SIZE {
            *malformed_drops += 1;
            continue;
        }
        match reasm.feed(&data) {
            Ok(Some(frame)) => return Ok((frame, peer)),
            Ok(None) => continue,
            Err(_) => {
                *malformed_drops += 1;
                continue;
            }
        }
    }
}

pub(super) fn should_stream_more(
    frame_i: u32,
    n_frames: u32,
    t0: Instant,
    duration: Option<f64>,
    options: &SessionOptions,
) -> bool {
    if options
        .runtime_control
        .as_ref()
        .is_some_and(SessionRuntimeControl::is_cancelled)
    {
        return false;
    }
    if options.persistent {
        return true;
    }
    if frame_i < n_frames {
        return true;
    }
    if let Some(d) = duration {
        return t0.elapsed().as_secs_f64() < d;
    }
    false
}
