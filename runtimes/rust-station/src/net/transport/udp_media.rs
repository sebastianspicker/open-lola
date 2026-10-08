use super::{
    DatagramPoll, MediaKind, MediaTransport, ReceivedDatagram, TransportError, TransportStats,
};
use crate::net::udp::Udp;
use std::io;
use std::net::{IpAddr, SocketAddr};
use std::time::{Duration, Instant};

/// How long every send may keep failing with a transient fault before the
/// fault is treated as a dead path rather than a passing one.
const SUSTAINED_SEND_FAULT_LIMIT: Duration = Duration::from_secs(2);

pub struct UdpMediaTransport {
    audio: Udp,
    video: Udp,
    peer_ip: IpAddr,
    audio_port: u16,
    video_port: u16,
    stats: TransportStats,
    shutdown: bool,
    /// When the current run of consecutive transient send faults began.
    send_faults_since: Option<Instant>,
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
            send_faults_since: None,
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
            send_faults_since: None,
        })
    }

    /// A transient fault is a per-datagram drop until it has persisted for
    /// `SUSTAINED_SEND_FAULT_LIMIT` without a single successful send; a path
    /// that stays down (firewall deny, dead route) then fails the session
    /// instead of silently dropping all media.
    fn classify_send_error(&mut self, error: io::Error) -> TransportError {
        let classified = TransportError::from_io(error);
        let TransportError::Transient(detail) = &classified else {
            return classified;
        };
        let since = *self.send_faults_since.get_or_insert_with(Instant::now);
        if since.elapsed() >= SUSTAINED_SEND_FAULT_LIMIT {
            return TransportError::Io(format!(
                "media sends have failed for {:?}: {detail}",
                SUSTAINED_SEND_FAULT_LIMIT
            ));
        }
        classified
    }

    fn socket(&self, kind: MediaKind) -> (&Udp, u16) {
        match kind {
            MediaKind::Audio => (&self.audio, self.audio_port),
            MediaKind::Video => (&self.video, self.video_port),
        }
    }

    fn receive_one(&mut self, kind: MediaKind) -> Result<DatagramPoll, TransportError> {
        let (socket, expected_port) = self.socket(kind);
        let peer_ip = self.peer_ip;
        let mut observed = TransportStats::default();
        // One datagram per call for both streams. Audio freshness and jitter
        // absorption are decided by the session receive queue, which sees
        // every block; draining to the newest block here would turn ordinary
        // arrival clustering into audible drops. Video freshness is a
        // frame-level decision owned by the reassembler.
        // `Some(None)` is a datagram the classifier rejected; `None` is an
        // empty socket. The caller must keep draining after a rejection.
        let received = socket.try_recv(|payload: &[u8], peer| {
            Some(classify_datagram(
                kind,
                payload,
                peer,
                peer_ip,
                expected_port,
                &mut observed,
            ))
        });
        self.stats.transient_receive_errors += socket.take_transient_receive_errors();
        let poll = match received {
            Ok(Some(Some(datagram))) => DatagramPoll::Datagram(datagram),
            Ok(Some(None)) => DatagramPoll::Discarded,
            Ok(None) => DatagramPoll::Empty,
            Err(error)
                if matches!(
                    error.kind(),
                    io::ErrorKind::WouldBlock
                        | io::ErrorKind::TimedOut
                        | io::ErrorKind::ConnectionReset
                ) =>
            {
                self.stats.transient_receive_errors +=
                    u64::from(error.kind() == io::ErrorKind::ConnectionReset);
                return Ok(DatagramPoll::Empty);
            }
            Err(error) => return Err(TransportError::from_io(error)),
        };
        self.stats.received_datagrams += observed.received_datagrams;
        self.stats.received_bytes += observed.received_bytes;
        self.stats.malformed_drops += observed.malformed_drops;
        self.stats.wrong_peer_drops += observed.wrong_peer_drops;
        self.stats.wrong_port_drops += observed.wrong_port_drops;
        Ok(poll)
    }

    /// Receives only the requested stream, retaining independent audio/video
    /// sockets instead of consuming an unrelated datagram. Exactly one
    /// datagram is returned per call so neither audio blocks nor video
    /// fragment coverage are discarded below the session queues.
    pub fn receive_kind(&mut self, kind: MediaKind) -> Result<DatagramPoll, TransportError> {
        if self.shutdown {
            return Ok(DatagramPoll::Empty);
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
            let sent = match socket.send_to(payload, destination) {
                Ok(sent) => sent,
                Err(error) => return Err(self.classify_send_error(error)),
            };
            (sent, payload.len())
        };
        self.send_faults_since = None;
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
        if let DatagramPoll::Datagram(datagram) = self.receive_one(MediaKind::Audio)? {
            return Ok(Some(datagram));
        }
        Ok(match self.receive_one(MediaKind::Video)? {
            DatagramPoll::Datagram(datagram) => Some(datagram),
            DatagramPoll::Discarded | DatagramPoll::Empty => None,
        })
    }

    fn stats(&self) -> TransportStats {
        self.stats
    }

    fn shutdown(&mut self) -> Result<(), TransportError> {
        self.shutdown = true;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::net::UdpSocket;

    #[test]
    fn rejected_datagrams_are_discarded_not_reported_as_an_empty_socket() {
        let audio = Udp::bind("127.0.0.1", 0).unwrap();
        let video = Udp::bind("127.0.0.1", 0).unwrap();
        let audio_port = audio.local_addr().unwrap().port();
        let video_port = video.local_addr().unwrap().port();
        let mut transport = UdpMediaTransport::from_bound_sockets(
            audio,
            video,
            IpAddr::from([127, 0, 0, 1]),
            audio_port,
            video_port,
        )
        .unwrap();
        // An ephemeral sender never uses the negotiated source port.
        let stranger = UdpSocket::bind("127.0.0.1:0").unwrap();
        stranger
            .send_to(b"stray", ("127.0.0.1", audio_port))
            .unwrap();
        stranger
            .send_to(b"stray", ("127.0.0.1", audio_port))
            .unwrap();

        let mut discarded = 0;
        let mut polls = 0;
        while polls < 1000 && discarded < 2 {
            polls += 1;
            match transport.receive_kind(MediaKind::Audio).unwrap() {
                DatagramPoll::Discarded => discarded += 1,
                DatagramPoll::Empty => std::thread::sleep(std::time::Duration::from_millis(1)),
                DatagramPoll::Datagram(_) => panic!("wrong-port datagram was accepted"),
            }
        }
        assert_eq!(discarded, 2);
        assert_eq!(transport.stats().wrong_port_drops, 2);
        assert_eq!(
            transport.receive_kind(MediaKind::Audio).unwrap(),
            DatagramPoll::Empty
        );
    }
}
