use super::{MediaKind, MediaTransport, ReceivedDatagram, TransportError, TransportStats};
use crate::net::pcap::{
    build_ethernet_ipv4_udp_frame, parse_ethernet_ipv4_udp_frame_borrowed, BorrowedUdpPacket,
    RawMediaPlane,
};
use std::collections::VecDeque;
use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use std::time::SystemTime;

/// The minimal internal capture surface used by the transport. Keeping this
/// private lets unit tests exercise receive policy without exposing a new
/// operator-facing transport or Npcap abstraction.
trait CapturePlane {
    fn send(&self, frame: &[u8]) -> Result<(), String>;
    fn receive_with(
        &self,
        inspect: &mut dyn FnMut(&[u8], SystemTime) -> Option<ReceivedDatagram>,
    ) -> Result<Option<ReceivedDatagram>, String>;
    fn kernel_drop_snapshot(&self) -> Result<u64, String>;
    fn finalize(self: Box<Self>) -> Result<u64, String>;
}

impl CapturePlane for RawMediaPlane {
    fn send(&self, frame: &[u8]) -> Result<(), String> {
        Self::send(self, frame)
    }

    fn receive_with(
        &self,
        inspect: &mut dyn FnMut(&[u8], SystemTime) -> Option<ReceivedDatagram>,
    ) -> Result<Option<ReceivedDatagram>, String> {
        Self::receive_with(self, |frame, timestamp| inspect(frame, timestamp)).map(Option::flatten)
    }

    fn kernel_drop_snapshot(&self) -> Result<u64, String> {
        Self::kernel_drop_snapshot(self)
    }

    fn finalize(self: Box<Self>) -> Result<u64, String> {
        RawMediaPlane::finalize(*self)
    }
}

#[derive(Clone, Copy)]
struct ReceiveContract {
    source_ip: Ipv4Addr,
    peer_ip: Ipv4Addr,
    source_mac: [u8; 6],
    peer_mac: [u8; 6],
    audio_port: u16,
    video_port: u16,
    vlan_tag: Option<u16>,
}

pub struct NpcapMediaTransport {
    plane: Option<Box<dyn CapturePlane>>,
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
            plane: Some(Box::new(plane)),
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
    /// Captured bytes stay borrowed while parsing and peer admission runs.
    /// Malformed frames are counted without allocating an owned packet.
    fn receive_contract(&self) -> ReceiveContract {
        ReceiveContract {
            source_ip: self.source_ip,
            peer_ip: self.peer_ip,
            source_mac: self.source_mac,
            peer_mac: self.peer_mac,
            audio_port: self.audio_port,
            video_port: self.video_port,
            vlan_tag: self.vlan_tag,
        }
    }

    fn merge_received_stats(&mut self, observed: TransportStats) {
        self.stats.received_datagrams += observed.received_datagrams;
        self.stats.received_bytes += observed.received_bytes;
        self.stats.malformed_drops += observed.malformed_drops;
        self.stats.wrong_peer_drops += observed.wrong_peer_drops;
        self.stats.wrong_port_drops += observed.wrong_port_drops;
    }

    fn receive_parsed(
        contract: ReceiveContract,
        packet: BorrowedUdpPacket<'_>,
        _timestamp: SystemTime,
        observed: &mut TransportStats,
    ) -> Option<ReceivedDatagram> {
        if packet.source_port == 0 || packet.destination_port == 0 {
            observed.malformed_drops += 1;
            return None;
        }
        if packet.source_mac != contract.peer_mac
            || packet.destination_mac != contract.source_mac
            || packet.source_ip != contract.peer_ip
            || packet.destination_ip != contract.source_ip
            || packet.vlan_tag != contract.vlan_tag
        {
            observed.wrong_peer_drops += 1;
            return None;
        }
        let kind = if packet.source_port == contract.audio_port
            && packet.destination_port == contract.audio_port
        {
            MediaKind::Audio
        } else if packet.source_port == contract.video_port
            && packet.destination_port == contract.video_port
        {
            MediaKind::Video
        } else {
            observed.wrong_port_drops += 1;
            return None;
        };
        observed.received_datagrams += 1;
        observed.received_bytes += packet.payload.len() as u64;
        Some(ReceivedDatagram {
            kind,
            peer: SocketAddr::new(IpAddr::V4(packet.source_ip), packet.source_port),
            source_port: packet.source_port,
            payload: packet.payload.to_vec(),
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

    /// Services one capture packet, yielding immediately to the other stream.
    /// Keeping fragment admission separate from frame freshness prevents a
    /// video burst from being overwritten while the caller polls for audio.
    pub fn receive_kind(
        &mut self,
        kind: MediaKind,
    ) -> Result<Option<ReceivedDatagram>, TransportError> {
        if let Some(datagram) = self.pending(kind).pop_front() {
            return Ok(Some(datagram));
        }
        let Some(datagram) = self.receive()? else {
            return Ok(None);
        };
        if datagram.kind == kind {
            return Ok(Some(datagram));
        }
        self.retain_latest(datagram);
        Ok(None)
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
        let contract = self.receive_contract();
        let mut observed = TransportStats::default();
        let mut inspect = |frame: &[u8], timestamp| {
            let Some(packet) = parse_ethernet_ipv4_udp_frame_borrowed(frame) else {
                observed.malformed_drops += 1;
                return None;
            };
            Self::receive_parsed(contract, packet, timestamp, &mut observed)
        };
        let received = plane
            .receive_with(&mut inspect)
            .map_err(TransportError::Npcap)?;
        self.merge_received_stats(observed);
        Ok(received)
    }

    fn stats(&self) -> TransportStats {
        self.stats
    }

    fn stats_snapshot(&mut self) -> Result<TransportStats, TransportError> {
        if let Some(plane) = self.plane.as_ref() {
            self.stats.kernel_drops = plane
                .kernel_drop_snapshot()
                .map_err(TransportError::Npcap)?;
        }
        Ok(self.stats)
    }

    fn shutdown(&mut self) -> Result<(), TransportError> {
        if let Some(plane) = self.plane.take() {
            self.stats.kernel_drops = plane.finalize().map_err(TransportError::Npcap)?;
        }
        Ok(())
    }
}

#[cfg(test)]
#[path = "npcap/tests.rs"]
mod tests;
