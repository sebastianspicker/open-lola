use super::{MediaKind, MediaTransport, ReceivedDatagram, TransportError, TransportStats};
use crate::net::pcap::{
    build_ethernet_ipv4_udp_frame, parse_ethernet_ipv4_udp_frame, ParsedUdpPacket, RawMediaPlane,
};
use std::collections::VecDeque;
use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use std::time::SystemTime;

pub struct NpcapMediaTransport {
    plane: Option<RawMediaPlane>,
    source_ip: Ipv4Addr,
    peer_ip: Ipv4Addr,
    source_mac: [u8; 6],
    peer_mac: [u8; 6],
    audio_port: u16,
    video_port: u16,
    vlan_tag: Option<u16>,
    pending_audio: VecDeque<ReceivedDatagram>,
    pending_video: VecDeque<ReceivedDatagram>,
    audio_queue_depth: usize,
    video_queue_depth: usize,
    stats: TransportStats,
}

impl NpcapMediaTransport {
    #[allow(clippy::too_many_arguments)]
    pub fn open(
        device: &str,
        source_ip: Ipv4Addr,
        peer_ip: Ipv4Addr,
        source_mac: [u8; 6],
        peer_mac: [u8; 6],
        audio_port: u16,
        video_port: u16,
        vlan_tag: Option<u16>,
    ) -> Result<Self, String> {
        if source_ip.is_loopback() || peer_ip.is_loopback() {
            return Err("Npcap is limited to direct non-loopback IPv4 LAN peers".into());
        }
        if source_mac == [0; 6] || peer_mac == [0; 6] {
            return Err("Npcap requires resolved local and peer MAC addresses".into());
        }
        if audio_port == 0 || video_port == 0 || audio_port == video_port {
            return Err("audio/video ports must be distinct and nonzero".into());
        }
        let plane = RawMediaPlane::try_open(Some(device))?;
        plane.install_filter(peer_ip, source_ip, audio_port, video_port, vlan_tag)?;
        Ok(Self {
            plane: Some(plane),
            source_ip,
            peer_ip,
            source_mac,
            peer_mac,
            audio_port,
            video_port,
            vlan_tag,
            pending_audio: VecDeque::with_capacity(1),
            pending_video: VecDeque::with_capacity(1),
            audio_queue_depth: 1,
            video_queue_depth: 1,
            stats: TransportStats::default(),
        })
    }

    /// Applies the negotiated L2/L3/L4 receive contract to a parsed frame.
    ///
    /// `RawMediaPlane::receive` reports parse failures as `Ok(None)`, alongside
    /// capture timeouts, so those parser failures cannot be counted here without
    /// widening that lower-level API. This method counts malformed fields that
    /// are observable after parsing and classifies peer and port mismatches.
    fn receive_parsed(
        &mut self,
        packet: ParsedUdpPacket,
        timestamp: SystemTime,
    ) -> Option<ReceivedDatagram> {
        if packet.source_port == 0 || packet.destination_port == 0 {
            self.stats.malformed_drops += 1;
            return None;
        }
        if packet.source_mac != self.peer_mac
            || packet.destination_mac != self.source_mac
            || packet.source_ip != self.peer_ip
            || packet.destination_ip != self.source_ip
            || packet.vlan_tag != self.vlan_tag
        {
            self.stats.wrong_peer_drops += 1;
            return None;
        }
        let kind = if packet.source_port == self.audio_port
            && packet.destination_port == self.audio_port
        {
            MediaKind::Audio
        } else if packet.source_port == self.video_port
            && packet.destination_port == self.video_port
        {
            MediaKind::Video
        } else {
            self.stats.wrong_port_drops += 1;
            return None;
        };
        self.stats.received_datagrams += 1;
        self.stats.received_bytes += packet.payload.len() as u64;
        Some(ReceivedDatagram {
            kind,
            peer: SocketAddr::new(IpAddr::V4(packet.source_ip), packet.source_port),
            source_port: packet.source_port,
            received_at: timestamp,
            payload: packet.payload,
        })
    }

    fn pending(&mut self, kind: MediaKind) -> &mut VecDeque<ReceivedDatagram> {
        match kind {
            MediaKind::Audio => &mut self.pending_audio,
            MediaKind::Video => &mut self.pending_video,
        }
    }

    pub fn set_queue_depths(&mut self, audio: usize, video: usize) -> Result<(), String> {
        if audio == 0 || video == 0 {
            return Err("media receive queue depths must be positive".into());
        }
        self.audio_queue_depth = audio;
        self.video_queue_depth = video;
        while self.pending_audio.len() > audio {
            self.pending_audio.pop_front();
            self.stats.queue_replacement_drops += 1;
        }
        while self.pending_video.len() > video {
            self.pending_video.pop_front();
            self.stats.queue_replacement_drops += 1;
        }
        Ok(())
    }

    fn retain_latest(&mut self, datagram: ReceivedDatagram) {
        let depth = match datagram.kind {
            MediaKind::Audio => self.audio_queue_depth,
            MediaKind::Video => self.video_queue_depth,
        };
        let replaced = {
            let queue = self.pending(datagram.kind);
            let replaced = (queue.len() >= depth) && queue.pop_front().is_some();
            queue.push_back(datagram);
            replaced
        };
        if replaced {
            self.stats.queue_replacement_drops += 1;
        }
    }

    /// Receives one datagram of `kind` without discarding a valid datagram for
    /// the other media stream. The other stream retains only its newest packet
    /// to preserve the low-latency contract under scheduling pressure.
    pub fn receive_kind(
        &mut self,
        kind: MediaKind,
    ) -> Result<Option<ReceivedDatagram>, TransportError> {
        if let Some(datagram) = self.pending(kind).pop_front() {
            return Ok(Some(datagram));
        }
        loop {
            let Some(datagram) = self.receive()? else {
                return Ok(None);
            };
            if datagram.kind == kind {
                return Ok(Some(datagram));
            }
            self.retain_latest(datagram);
        }
    }
}

impl MediaTransport for NpcapMediaTransport {
    fn send(&mut self, kind: MediaKind, payload: &[u8]) -> Result<(), TransportError> {
        let port = match kind {
            MediaKind::Audio => self.audio_port,
            MediaKind::Video => self.video_port,
        };
        let frame = build_ethernet_ipv4_udp_frame(
            self.source_mac,
            self.peer_mac,
            self.source_ip,
            self.peer_ip,
            port,
            port,
            payload,
            self.vlan_tag,
        )
        .map_err(TransportError::Configuration)?;
        self.plane
            .as_ref()
            .ok_or(TransportError::Closed)?
            .send(&frame)
            .map_err(TransportError::Npcap)?;
        self.stats.sent_datagrams += 1;
        self.stats.sent_bytes += payload.len() as u64;
        Ok(())
    }

    fn receive(&mut self) -> Result<Option<ReceivedDatagram>, TransportError> {
        let plane = self.plane.as_ref().ok_or(TransportError::Closed)?;
        let Some((frame, timestamp)) = plane.receive_frame().map_err(TransportError::Npcap)? else {
            self.stats.kernel_drops = plane.kernel_drop_count().map_err(TransportError::Npcap)?;
            return Ok(None);
        };
        self.stats.kernel_drops = plane.kernel_drop_count().map_err(TransportError::Npcap)?;
        let Some(packet) = parse_ethernet_ipv4_udp_frame(&frame) else {
            self.stats.malformed_drops += 1;
            return Ok(None);
        };
        Ok(self.receive_parsed(packet, timestamp))
    }

    fn stats(&self) -> TransportStats {
        self.stats
    }

    fn shutdown(&mut self) -> Result<(), TransportError> {
        self.plane.take();
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const LOCAL_IP: Ipv4Addr = Ipv4Addr::new(192, 0, 2, 10);
    const PEER_IP: Ipv4Addr = Ipv4Addr::new(192, 0, 2, 20);
    const LOCAL_MAC: [u8; 6] = [0, 1, 2, 3, 4, 5];
    const PEER_MAC: [u8; 6] = [6, 7, 8, 9, 10, 11];
    const AUDIO_PORT: u16 = 19_788;
    const VIDEO_PORT: u16 = 19_798;

    fn in_memory_npcap() -> NpcapMediaTransport {
        NpcapMediaTransport {
            plane: None,
            source_ip: LOCAL_IP,
            peer_ip: PEER_IP,
            source_mac: LOCAL_MAC,
            peer_mac: PEER_MAC,
            audio_port: AUDIO_PORT,
            video_port: VIDEO_PORT,
            vlan_tag: None,
            pending_audio: VecDeque::with_capacity(1),
            pending_video: VecDeque::with_capacity(1),
            audio_queue_depth: 1,
            video_queue_depth: 1,
            stats: TransportStats::default(),
        }
    }

    fn packet(source_port: u16, destination_port: u16) -> ParsedUdpPacket {
        ParsedUdpPacket {
            source_mac: PEER_MAC,
            destination_mac: LOCAL_MAC,
            vlan_tag: None,
            source_ip: PEER_IP,
            destination_ip: LOCAL_IP,
            source_port,
            destination_port,
            payload: b"media".to_vec(),
        }
    }

    #[test]
    fn parsed_receive_requires_negotiated_peer_and_port_parity() {
        let mut transport = in_memory_npcap();
        let received = transport
            .receive_parsed(packet(AUDIO_PORT, AUDIO_PORT), SystemTime::UNIX_EPOCH)
            .expect("matching audio frame");
        assert_eq!(received.kind, MediaKind::Audio);
        assert_eq!(
            received.peer,
            SocketAddr::new(IpAddr::V4(PEER_IP), AUDIO_PORT)
        );

        let mut wrong_source_mac = packet(AUDIO_PORT, AUDIO_PORT);
        wrong_source_mac.source_mac = [9; 6];
        assert!(transport
            .receive_parsed(wrong_source_mac, SystemTime::UNIX_EPOCH)
            .is_none());

        let mut wrong_destination_mac = packet(AUDIO_PORT, AUDIO_PORT);
        wrong_destination_mac.destination_mac = [8; 6];
        assert!(transport
            .receive_parsed(wrong_destination_mac, SystemTime::UNIX_EPOCH)
            .is_none());

        let mut wrong_source_ip = packet(AUDIO_PORT, AUDIO_PORT);
        wrong_source_ip.source_ip = Ipv4Addr::new(192, 0, 2, 98);
        assert!(transport
            .receive_parsed(wrong_source_ip, SystemTime::UNIX_EPOCH)
            .is_none());

        let mut wrong_destination_ip = packet(AUDIO_PORT, AUDIO_PORT);
        wrong_destination_ip.destination_ip = Ipv4Addr::new(192, 0, 2, 99);
        assert!(transport
            .receive_parsed(wrong_destination_ip, SystemTime::UNIX_EPOCH)
            .is_none());

        assert!(transport
            .receive_parsed(packet(AUDIO_PORT, VIDEO_PORT), SystemTime::UNIX_EPOCH)
            .is_none());
        assert!(transport
            .receive_parsed(packet(0, AUDIO_PORT), SystemTime::UNIX_EPOCH)
            .is_none());

        assert_eq!(
            transport.stats(),
            TransportStats {
                received_datagrams: 1,
                received_bytes: 5,
                malformed_drops: 1,
                wrong_peer_drops: 4,
                wrong_port_drops: 1,
                ..TransportStats::default()
            }
        );
    }

    #[test]
    fn parsed_receive_accepts_video_only_with_matching_ports() {
        let mut transport = in_memory_npcap();
        let received = transport
            .receive_parsed(packet(VIDEO_PORT, VIDEO_PORT), SystemTime::UNIX_EPOCH)
            .expect("matching video frame");
        assert_eq!(received.kind, MediaKind::Video);
    }

    #[test]
    fn other_kind_queue_retains_only_the_latest_datagram() {
        let mut transport = in_memory_npcap();
        let first = transport
            .receive_parsed(packet(VIDEO_PORT, VIDEO_PORT), SystemTime::UNIX_EPOCH)
            .unwrap();
        let mut second = transport
            .receive_parsed(packet(VIDEO_PORT, VIDEO_PORT), SystemTime::UNIX_EPOCH)
            .unwrap();
        second.payload = b"latest".to_vec();
        transport.retain_latest(first);
        transport.retain_latest(second);
        assert_eq!(
            transport
                .pending(MediaKind::Video)
                .pop_front()
                .unwrap()
                .payload,
            b"latest"
        );
        assert_eq!(transport.stats.queue_replacement_drops, 1);
    }

    #[test]
    fn requested_npcap_fails_instead_of_falling_back_to_udp() {
        let error = match NpcapMediaTransport::open(
            "missing",
            Ipv4Addr::LOCALHOST,
            Ipv4Addr::LOCALHOST,
            [1; 6],
            [2; 6],
            19_788,
            19_798,
            None,
        ) {
            Ok(_) => panic!("loopback Npcap must fail"),
            Err(error) => error,
        };
        assert!(error.contains("direct"));
    }
}
