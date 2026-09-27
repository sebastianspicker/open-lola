use super::{MediaKind, MediaTransport, ReceivedDatagram, TransportError, TransportStats};
use crate::net::udp::Udp;
use std::io;
use std::net::{IpAddr, SocketAddr};
use std::time::SystemTime;

pub struct UdpMediaTransport {
    audio: Udp,
    video: Udp,
    peer_ip: IpAddr,
    audio_port: u16,
    video_port: u16,
    stats: TransportStats,
    shutdown: bool,
}

impl UdpMediaTransport {
    /// Creates the production UDP media transport from already-bound fixed
    /// audio/video sockets. This preserves LoLa's source/destination port
    /// parity without a second bind race after control negotiation.
    pub fn from_bound_sockets(
        audio: Udp,
        video: Udp,
        peer_ip: IpAddr,
        audio_port: u16,
        video_port: u16,
    ) -> Result<Self, String> {
        if audio_port == 0 || video_port == 0 || audio_port == video_port {
            return Err("audio/video ports must be distinct and nonzero".into());
        }
        let actual_audio = audio
            .local_addr()
            .map_err(|error| error.to_string())?
            .port();
        let actual_video = video
            .local_addr()
            .map_err(|error| error.to_string())?
            .port();
        if actual_audio != audio_port || actual_video != video_port {
            return Err(format!(
                "UDP media source ports must match negotiated ports: {actual_audio}/{actual_video} != {audio_port}/{video_port}"
            ));
        }
        audio
            .configure_media_nonblocking()
            .map_err(|error| error.to_string())?;
        video
            .configure_media_nonblocking()
            .map_err(|error| error.to_string())?;
        Ok(Self {
            audio,
            video,
            peer_ip,
            audio_port,
            video_port,
            stats: TransportStats::default(),
            shutdown: false,
        })
    }

    pub fn bind_fixed(
        bind_ip: &str,
        peer_ip: IpAddr,
        audio_port: u16,
        video_port: u16,
        timeout_seconds: f64,
    ) -> Result<Self, String> {
        if audio_port == 0 || video_port == 0 || audio_port == video_port {
            return Err("audio/video ports must be distinct and nonzero".into());
        }
        let audio = Udp::bind(bind_ip, audio_port).map_err(|error| error.to_string())?;
        let video = Udp::bind(bind_ip, video_port).map_err(|error| error.to_string())?;
        audio
            .set_timeout(timeout_seconds)
            .map_err(|error| error.to_string())?;
        video
            .set_timeout(timeout_seconds)
            .map_err(|error| error.to_string())?;
        audio
            .configure_media_nonblocking()
            .map_err(|error| error.to_string())?;
        video
            .configure_media_nonblocking()
            .map_err(|error| error.to_string())?;
        Ok(Self {
            audio,
            video,
            peer_ip,
            audio_port,
            video_port,
            stats: TransportStats::default(),
            shutdown: false,
        })
    }

    fn socket(&self, kind: MediaKind) -> (&Udp, u16) {
        match kind {
            MediaKind::Audio => (&self.audio, self.audio_port),
            MediaKind::Video => (&self.video, self.video_port),
        }
    }

    fn receive_one(&mut self, kind: MediaKind) -> Result<Option<ReceivedDatagram>, TransportError> {
        let (socket, expected_port) = self.socket(kind);
        let peer_ip = self.peer_ip;
        let mut observed = TransportStats::default();
        let received = match kind {
            // Audio is one complete callback block per datagram, so stale
            // blocks can be replaced safely at the datagram boundary.
            MediaKind::Audio => socket.try_recv_latest(|payload: &[u8], peer| {
                classify_datagram(kind, payload, peer, peer_ip, expected_port, &mut observed)
            }),
            // Video freshness is a frame-level decision. Draining to the newest
            // fragment would discard coverage required by the reassembler.
            MediaKind::Video => socket
                .try_recv(|payload: &[u8], peer| {
                    classify_datagram(kind, payload, peer, peer_ip, expected_port, &mut observed)
                })
                .map(|received| (received, 0)),
        };
        let (datagram, replacements) = match received {
            Ok(received) => received,
            Err(error)
                if matches!(
                    error.kind(),
                    io::ErrorKind::WouldBlock | io::ErrorKind::TimedOut
                ) =>
            {
                return Ok(None)
            }
            Err(error) => return Err(TransportError::from_io(error)),
        };
        self.stats.received_datagrams += observed.received_datagrams;
        self.stats.received_bytes += observed.received_bytes;
        self.stats.malformed_drops += observed.malformed_drops;
        self.stats.wrong_peer_drops += observed.wrong_peer_drops;
        self.stats.wrong_port_drops += observed.wrong_port_drops;
        self.stats.queue_replacement_drops += replacements;
        Ok(datagram)
    }

    /// Receives only the requested stream, retaining independent audio/video
    /// sockets instead of consuming an unrelated datagram. Once a valid packet
    /// arrives, audio may drain complete stale callback blocks. Video returns
    /// exactly one fragment so frame reassembly coverage is never discarded.
    pub fn receive_kind(
        &mut self,
        kind: MediaKind,
    ) -> Result<Option<ReceivedDatagram>, TransportError> {
        if self.shutdown {
            return Ok(None);
        }
        self.receive_one(kind)
    }
}

fn classify_datagram(
    kind: MediaKind,
    payload: &[u8],
    peer: SocketAddr,
    peer_ip: IpAddr,
    expected_port: u16,
    observed: &mut TransportStats,
) -> Option<ReceivedDatagram> {
    if payload.is_empty() {
        observed.malformed_drops += 1;
        return None;
    }
    if peer.ip() != peer_ip {
        observed.wrong_peer_drops += 1;
        return None;
    }
    if peer.port() != expected_port {
        observed.wrong_port_drops += 1;
        return None;
    }
    observed.received_datagrams += 1;
    observed.received_bytes += payload.len() as u64;
    Some(ReceivedDatagram {
        kind,
        peer,
        source_port: peer.port(),
        received_at: SystemTime::now(),
        payload: payload.to_vec(),
    })
}

impl MediaTransport for UdpMediaTransport {
    fn send(&mut self, kind: MediaKind, payload: &[u8]) -> Result<(), TransportError> {
        if self.shutdown {
            return Err(TransportError::Closed);
        }
        let (sent, expected) = {
            let (socket, port) = self.socket(kind);
            let destination = SocketAddr::new(self.peer_ip, port);
            (
                socket
                    .send_to(payload, destination)
                    .map_err(TransportError::from_io)?,
                payload.len(),
            )
        };
        if sent != expected {
            self.stats.backpressure_drops += 1;
            return Err(TransportError::Backpressure(format!(
                "partial UDP datagram send: {sent}/{expected}"
            )));
        }
        self.stats.sent_datagrams += 1;
        self.stats.sent_bytes += sent as u64;
        Ok(())
    }

    fn receive(&mut self) -> Result<Option<ReceivedDatagram>, TransportError> {
        if self.shutdown {
            return Ok(None);
        }
        if let Some(datagram) = self.receive_one(MediaKind::Audio)? {
            return Ok(Some(datagram));
        }
        self.receive_one(MediaKind::Video)
    }

    fn stats(&self) -> TransportStats {
        self.stats
    }

    fn shutdown(&mut self) -> Result<(), TransportError> {
        self.shutdown = true;
        Ok(())
    }
}
