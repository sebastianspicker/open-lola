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
