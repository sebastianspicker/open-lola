use super::sequence::{ReceiveSequenceGate, SequenceAdmission};
use super::{SessionOptions, SessionRuntimeControl};
use crate::net::{
    DatagramPoll, MediaKind, MediaTransport, NpcapMediaTransport, ReceivedDatagram, TransportError,
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

/// Outcome of polling one media socket. `Discarded` (wrong peer, wrong port,
/// empty) is distinct from `Empty` so a drain keeps reading past rejected
/// datagrams instead of ending early.
#[derive(Debug, Clone, PartialEq, Eq)]
pub(super) enum ReceiveOutcome {
    Datagram(ReceivedDatagram),
    Discarded,
    Empty,
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

    /// Returns `Ok(false)` when the datagram was dropped for a transient
    /// reason (`WouldBlock` or a transient OS fault) rather than failing.
    pub(super) fn send(
        &mut self,
        kind: MediaKind,
        payload: &[u8],
        destination: SocketAddr,
    ) -> Result<bool, SessionError> {
        match self.send_transport(kind, payload, destination) {
            Ok(()) => Ok(true),
            Err(TransportError::WouldBlock | TransportError::Transient(_)) => Ok(false),
            Err(error) => Err(transport_session_error(error)),
        }
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
            Err(
                TransportError::WouldBlock
                | TransportError::Backpressure(_)
                | TransportError::Transient(_),
            ) => Ok(VideoSendDisposition::WouldBlock),
            Err(error) => Err(transport_session_error(error)),
        }
    }

    pub(super) fn receive_kind(&mut self, kind: MediaKind) -> Result<ReceiveOutcome, SessionError> {
        match self {
            Self::DiagnosticUdp { .. } => match self.socket(kind).try_recv_vec() {
                Ok(Some((payload, peer))) => {
                    if let Self::DiagnosticUdp { stats, .. } = self {
                        stats.received_datagrams += 1;
                        stats.received_bytes += payload.len() as u64;
                    }
                    Ok(ReceiveOutcome::Datagram(ReceivedDatagram {
                        kind,
                        peer,
                        source_port: peer.port(),
                        payload,
                    }))
                }
                Ok(None) => Ok(ReceiveOutcome::Empty),
                Err(error) => Err(SessionError::Transport(error.to_string())),
            },
            Self::Udp(transport) => transport
                .receive_kind(kind)
                .map(|poll| match poll {
                    DatagramPoll::Datagram(datagram) => ReceiveOutcome::Datagram(datagram),
                    DatagramPoll::Discarded => ReceiveOutcome::Discarded,
                    DatagramPoll::Empty => ReceiveOutcome::Empty,
                })
                .map_err(transport_session_error),
            Self::Npcap(transport) => transport
                .receive_kind(kind)
                .map(|datagram| datagram.map_or(ReceiveOutcome::Empty, ReceiveOutcome::Datagram))
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

/// Bounded presentation queue shared by audio blocks and video frames.
///
/// Every admitted unit is stored (replacing the oldest when the depth bound is
/// reached), and at most one unit leaves per presentation deadline. The depth
/// bound therefore caps the latency a jitter burst can add, while `prefill`
/// decides how many units must be queued before the first one is presented.
pub(super) struct ReceivePrefillQueue<T> {
    queue: VecDeque<T>,
    depth: usize,
    prefill: usize,
    started: bool,
    sequence: ReceiveSequenceGate,
}

impl<T> ReceivePrefillQueue<T> {
    pub(super) fn new(depth: u32, prefill: u32) -> Self {
        let depth = depth.max(1) as usize;
        Self {
            queue: VecDeque::with_capacity(depth),
            depth,
            prefill: (prefill as usize).min(depth),
            started: prefill == 0,
            sequence: ReceiveSequenceGate::default(),
        }
    }

    /// Admits newer sequences and clears queued media after a confirmed sender restart.
    pub(super) fn admit_sequence(&mut self, sequence: u32) -> bool {
        match self.sequence.admit(sequence) {
            SequenceAdmission::Rejected => false,
            SequenceAdmission::New => true,
            SequenceAdmission::Resynced => {
                self.queue.clear();
                self.started = self.prefill == 0;
                true
            }
        }
    }

    #[cfg(test)]
    pub(super) fn take_resyncs(&mut self) -> u64 {
        self.sequence.take_resyncs()
    }

    /// Stores one unit. Returns whether the oldest queued unit was discarded
    /// to respect the depth bound.
    pub(super) fn enqueue(&mut self, item: T) -> bool {
        let replaced = if self.queue.len() >= self.depth {
            self.queue.pop_front().is_some()
        } else {
            false
        };
        self.queue.push_back(item);
        if !self.started && self.queue.len() >= self.prefill {
            self.started = true;
        }
        replaced
    }

    /// Takes the next unit for presentation once the prefill target was met.
    pub(super) fn dequeue(&mut self) -> Option<T> {
        if !self.started {
            return None;
        }
        self.queue.pop_front()
    }

    /// Stores one unit and immediately offers the next presentable unit.
    pub(super) fn push(&mut self, item: T) -> (Option<T>, bool) {
        let replaced = self.enqueue(item);
        (self.dequeue(), replaced)
    }

    #[cfg(test)]
    pub(super) fn len(&self) -> usize {
        self.queue.len()
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
        // A transiently dropped fragment leaves the frame incomplete at the
        // receiver, which already tolerates partial frames.
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
) -> Result<bool, SessionError> {
    if pcm.is_empty() {
        return Err(SessionError::Protocol(MediaError::EmptyPcm.to_string()));
    }
    let datagram = writer
        .write(sequence, pcm, None)
        .map_err(|error| SessionError::Protocol(error.to_string()))?;
    transport.send(MediaKind::Audio, datagram, addr)
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
        let ReceiveOutcome::Datagram(datagram) = transport.receive_kind(expected_kind)? else {
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

#[cfg(test)]
mod tests {
    use super::super::sequence::SEQUENCE_RESYNC_REJECTIONS;
    use super::*;

    #[test]
    fn sequence_resyncs_after_consecutive_rejections() {
        let mut queue = ReceivePrefillQueue::<u8>::new(4, 2);
        assert!(queue.admit_sequence(1000));
        queue.enqueue(1);
        // A restarted sender repeats low sequences that are never "newer".
        for sequence in 0..SEQUENCE_RESYNC_REJECTIONS - 1 {
            assert!(!queue.admit_sequence(sequence));
        }
        assert_eq!(queue.take_resyncs(), 0);
        assert_eq!(queue.len(), 1);
        assert!(queue.admit_sequence(SEQUENCE_RESYNC_REJECTIONS - 1));
        assert_eq!(queue.take_resyncs(), 1);
        assert_eq!(queue.take_resyncs(), 0);
        assert_eq!(queue.len(), 0);
        // The new numbering is now authoritative.
        assert!(queue.admit_sequence(SEQUENCE_RESYNC_REJECTIONS));
        assert!(!queue.admit_sequence(SEQUENCE_RESYNC_REJECTIONS - 1));
    }

    #[test]
    fn an_accepted_sequence_restarts_the_rejection_count() {
        let mut queue = ReceivePrefillQueue::<u8>::new(4, 0);
        assert!(queue.admit_sequence(10));
        for _ in 0..SEQUENCE_RESYNC_REJECTIONS - 1 {
            assert!(!queue.admit_sequence(3));
        }
        assert!(queue.admit_sequence(11));
        for _ in 0..SEQUENCE_RESYNC_REJECTIONS - 1 {
            assert!(!queue.admit_sequence(3));
        }
        assert_eq!(queue.take_resyncs(), 0);
    }

    #[test]
    fn receive_kind_distinguishes_a_datagram_from_an_empty_socket() {
        let audio = Udp::bind("127.0.0.1", 0).unwrap();
        let video = Udp::bind("127.0.0.1", 0).unwrap();
        let destination = audio.local_addr().unwrap();
        let mut transport = SessionMediaTransport::diagnostic_udp(audio, video);
        assert_eq!(
            transport.receive_kind(MediaKind::Audio).unwrap(),
            ReceiveOutcome::Empty
        );
        assert!(transport
            .send(MediaKind::Audio, b"block", destination)
            .unwrap());
        let mut outcome = ReceiveOutcome::Empty;
        for _ in 0..1000 {
            outcome = transport.receive_kind(MediaKind::Audio).unwrap();
            if outcome != ReceiveOutcome::Empty {
                break;
            }
            thread::sleep(std::time::Duration::from_millis(1));
        }
        assert!(matches!(
            outcome,
            ReceiveOutcome::Datagram(datagram) if datagram.payload == b"block"
        ));
        assert_eq!(
            transport.receive_kind(MediaKind::Audio).unwrap(),
            ReceiveOutcome::Empty
        );
    }
}
