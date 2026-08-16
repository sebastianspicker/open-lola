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
        let mut classify = |payload, peer| {
            classify_datagram(kind, payload, peer, peer_ip, expected_port, &mut observed)
        };
        let received = match kind {
            // Audio is one complete callback block per datagram, so stale
            // blocks can be replaced safely at the datagram boundary.
            MediaKind::Audio => socket.try_recv_vec_latest(&mut classify),
            // Video freshness is a frame-level decision. Draining to the newest
            // fragment would discard coverage required by the reassembler.
            MediaKind::Video => socket.try_recv_vec().map(|received| {
                (
                    received.and_then(|(payload, peer)| classify(payload, peer)),
                    0,
                )
            }),
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
    payload: Vec<u8>,
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
        payload,
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

#[cfg(test)]
mod tests {
    use super::*;
    use std::net::Ipv4Addr;

    fn media_transport() -> (UdpMediaTransport, Udp) {
        let audio_receiver = Udp::bind("127.0.0.1", 0).unwrap();
        audio_receiver.set_timeout(0.5).unwrap();
        let video_receiver = Udp::bind("127.0.0.1", 0).unwrap();
        let sender = Udp::bind("127.0.0.1", 0).unwrap();
        let sender_port = sender.local_addr().unwrap().port();
        let transport = UdpMediaTransport {
            audio: audio_receiver,
            video: video_receiver,
            peer_ip: IpAddr::V4(Ipv4Addr::LOCALHOST),
            audio_port: sender_port,
            video_port: 1,
            stats: TransportStats::default(),
            shutdown: false,
        };
        (transport, sender)
    }

    #[test]
    fn requested_kind_drains_udp_backlog_to_newest_datagram() {
        let _guard = crate::net::udp::UDP_TEST_LOCK
            .lock()
            .unwrap_or_else(|error| error.into_inner());
        let (mut transport, sender) = media_transport();
        let audio_destination = transport.audio.local_addr().unwrap();
        for payload in [b"stale-one".as_slice(), b"stale-two", b"latest"] {
            sender.send_to(payload, audio_destination).unwrap();
        }
        // Give the kernel a scheduling quantum to queue the complete burst;
        // the contract under test is stale-backlog replacement, not sender
        // and receiver thread scheduling.
        std::thread::sleep(std::time::Duration::from_millis(10));

        let deadline = std::time::Instant::now() + std::time::Duration::from_secs(2);
        let received = loop {
            if let Some(received) = transport.receive_kind(MediaKind::Audio).unwrap() {
                break Some(received);
            }
            if std::time::Instant::now() >= deadline {
                break None;
            }
        };
        assert!(
            received.is_some(),
            "queued audio datagram; stats={:?}; sender={:?}; destination={audio_destination:?}",
            transport.stats(),
            sender.local_addr()
        );
        let received = received.unwrap();

        assert_eq!(received.payload, b"latest");
        assert_eq!(transport.stats().received_datagrams, 3);
        assert_eq!(transport.stats().queue_replacement_drops, 2);
    }

    #[test]
    fn udp_requires_distinct_nonzero_media_ports() {
        let error = match UdpMediaTransport::bind_fixed(
            "127.0.0.1",
            IpAddr::V4(Ipv4Addr::LOCALHOST),
            19_788,
            19_788,
            0.0,
        ) {
            Ok(_) => panic!("ambiguous UDP media ports must fail before binding"),
            Err(error) => error,
        };
        assert!(error.contains("distinct and nonzero"));
    }

    #[test]
    fn video_receive_preserves_fragment_order_instead_of_draining_to_latest() {
        let _guard = crate::net::udp::UDP_TEST_LOCK
            .lock()
            .unwrap_or_else(|error| error.into_inner());
        let video_receiver = Udp::bind("127.0.0.1", 0).unwrap();
        video_receiver.set_timeout(0.5).unwrap();
        let audio_receiver = Udp::bind("127.0.0.1", 0).unwrap();
        let sender = Udp::bind("127.0.0.1", 0).unwrap();
        let sender_port = sender.local_addr().unwrap().port();
        let destination = video_receiver.local_addr().unwrap();
        let mut transport = UdpMediaTransport {
            audio: audio_receiver,
            video: video_receiver,
            peer_ip: IpAddr::V4(Ipv4Addr::LOCALHOST),
            audio_port: 1,
            video_port: sender_port,
            stats: TransportStats::default(),
            shutdown: false,
        };
        sender.send_to(b"fragment-one", destination).unwrap();
        sender.send_to(b"fragment-two", destination).unwrap();

        let receive_video = |transport: &mut UdpMediaTransport, label: &str| {
            let deadline = std::time::Instant::now() + std::time::Duration::from_secs(2);
            loop {
                if let Some(datagram) = transport.receive_kind(MediaKind::Video).unwrap() {
                    break datagram;
                }
                assert!(std::time::Instant::now() < deadline, "{label} fragment");
                std::thread::yield_now();
            }
        };
        let first = receive_video(&mut transport, "first");
        let second = receive_video(&mut transport, "second");
        assert_eq!(first.payload, b"fragment-one");
        assert_eq!(second.payload, b"fragment-two");
        assert_eq!(transport.stats().queue_replacement_drops, 0);
    }
}
