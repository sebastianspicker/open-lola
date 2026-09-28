//! Bounded offline PCAP/PCAPNG LoLa metadata inspection.
//! Capture checksums are observations, not admission gates: transmit captures
//! can precede NIC checksum offload. Live transport validation remains separate.
use crate::protocol::{
    parse_fragment, parse_video_prelude, MAX_MEDIA_FRAGMENT_COUNT, MAX_MEDIA_FRAME_SIZE,
};
use serde::Serialize;
use std::collections::{BTreeMap, BTreeSet};
use std::io::{self, Read};
use std::path::Path;
mod container;

const MAX_CAPTURE_BYTES: u64 = 256 * 1024 * 1024;
const MAX_FRAMES: usize = 4096;
const MAX_PACKETS: usize = 1_000_000;

#[derive(Default, Serialize)]
pub struct CaptureSummary {
    pub packets: usize,
    pub ignored_packets: usize,
    pub malformed_drops: usize,
    pub frame_limit_drops: usize,
    pub fragment_total: usize,
    pub prelude_total: usize,
    pub frames: BTreeMap<String, FrameSummary>,
    #[serde(skip)]
    active: BTreeMap<String, String>,
}

#[derive(Default, Serialize)]
pub struct FrameSummary {
    pub expected_fragments: u32,
    pub expected_bytes: Option<u32>,
    pub fragment_packets: usize,
    pub unique_fragments: usize,
    pub duplicate_fragments: usize,
    pub bytes: usize,
    pub flags: BTreeSet<u8>,
    pub complete: bool,
    pub conflicting_fragments: usize,
    #[serde(skip)]
    parts: BTreeMap<u32, (u32, u32, Vec<u8>)>,
}

pub fn decode_capture(path: &Path) -> Result<CaptureSummary, String> {
    let mut options = std::fs::OpenOptions::new();
    options.read(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.custom_flags(libc::O_NONBLOCK | libc::O_CLOEXEC | libc::O_NOCTTY);
    }
    let file = options.open(path).map_err(|e| e.to_string())?;
    if !file.metadata().map_err(|e| e.to_string())?.is_file() {
        return Err("capture must be a regular file".into());
    }
    let mut bytes = Vec::new();
    file.take(MAX_CAPTURE_BYTES + 1)
        .read_to_end(&mut bytes)
        .map_err(|e| e.to_string())?;
    if bytes.len() as u64 > MAX_CAPTURE_BYTES {
        return Err("capture exceeds 256 MiB".into());
    }
    decode_bytes(&bytes)
}

pub fn decode_bytes(bytes: &[u8]) -> Result<CaptureSummary, String> {
    if bytes.len() as u64 > MAX_CAPTURE_BYTES {
        return Err("capture exceeds 256 MiB".into());
    }
    let mut summary = CaptureSummary::default();
    container::packets(bytes, |linktype, packet| {
        if summary.packets >= MAX_PACKETS {
            return Err("capture exceeds one million packets".into());
        }
        summary.packets += 1;
        match udp_payload(linktype, packet) {
            Some((endpoints, payload)) => summary.observe(endpoints, payload),
            None => summary.ignored_packets += 1,
        }
        Ok(())
    })?;
    for frame in summary.frames.values_mut() {
        frame.complete = frame.is_complete();
    }
    Ok(summary)
}

impl CaptureSummary {
    fn observe(&mut self, endpoints: String, payload: &[u8]) {
        if let Some(prelude) = parse_video_prelude(payload) {
            if prelude.expected_size as usize > MAX_MEDIA_FRAME_SIZE
                || prelude.fragment_count > MAX_MEDIA_FRAGMENT_COUNT
            {
                self.malformed_drops += 1;
                return;
            }
            self.prelude_total += 1;
            let base = format!("{endpoints}/{}", prelude.frame_id);
            if self.frames.len() >= MAX_FRAMES {
                self.frame_limit_drops += 1;
                return;
            }
            // Each prelude starts a new occurrence, even when the wire ID repeats.
            let key = format!("{base}/generation-{}", self.prelude_total);
            self.active.insert(base, key.clone());
            if let Some(frame) = self.frame(key) {
                frame.expected_fragments = prelude.fragment_count;
                frame.expected_bytes = Some(prelude.expected_size);
            }
            return;
        }
        let fragment = match parse_fragment(payload) {
            Ok(fragment) => fragment,
            Err(_) => {
                self.malformed_drops += 1;
                return;
            }
        };
        if fragment.fragment_count == 0
            || fragment.fragment_count > MAX_MEDIA_FRAGMENT_COUNT
            || fragment.fragment_index >= fragment.fragment_count
            || u64::from(fragment.original_offset) + u64::from(fragment.fragment_length)
                > MAX_MEDIA_FRAME_SIZE as u64
        {
            self.malformed_drops += 1;
            return;
        }
        self.fragment_total += 1;
        let base = format!("{endpoints}/{}", fragment.frame_id);
        let key = self.active.get(&base).cloned().unwrap_or(base);
        let Some(frame) = self.frame(key) else {
            return;
        };
        if frame.expected_fragments != 0 && frame.expected_fragments != fragment.fragment_count {
            frame.conflicting_fragments += 1;
            self.malformed_drops += 1;
            return;
        }
        frame.expected_fragments = fragment.fragment_count;
        frame.fragment_packets += 1;
        frame.flags.insert(fragment.flags);
        if let std::collections::btree_map::Entry::Vacant(entry) =
            frame.parts.entry(fragment.fragment_index)
        {
            entry.insert((
                fragment.original_offset,
                fragment.fragment_length,
                fragment.data,
            ));
            frame.unique_fragments += 1;
            frame.bytes += fragment.fragment_length as usize;
        } else {
            frame.duplicate_fragments += 1;
            if frame.parts.get(&fragment.fragment_index)
                != Some(&(
                    fragment.original_offset,
                    fragment.fragment_length,
                    fragment.data,
                ))
            {
                frame.conflicting_fragments += 1;
                self.malformed_drops += 1;
            }
        }
    }
    fn frame(&mut self, key: String) -> Option<&mut FrameSummary> {
        if !self.frames.contains_key(&key) && self.frames.len() >= MAX_FRAMES {
            self.frame_limit_drops += 1;
            return None;
        }
        Some(self.frames.entry(key).or_default())
    }
}
impl FrameSummary {
    fn is_complete(&self) -> bool {
        if self.conflicting_fragments != 0
            || self.expected_fragments == 0
            || self.unique_fragments != self.expected_fragments as usize
        {
            return false;
        }
        let mut parts: Vec<_> = self
            .parts
            .values()
            .map(|(offset, length, _)| (*offset, *length))
            .collect();
        parts.sort_unstable();
        let mut end = 0;
        for (offset, length) in parts {
            if offset != end {
                return false;
            }
            end += length;
        }
        self.expected_bytes.is_none_or(|expected| expected == end)
    }
}

fn udp_payload(linktype: u32, packet: &[u8]) -> Option<(String, &[u8])> {
    let (ip, udp) = ipv4_udp_packet(packet, ipv4_start(linktype, packet)?)?;
    Some((udp_endpoints(ip, udp), &udp[8..]))
}

fn ipv4_start(linktype: u32, packet: &[u8]) -> Option<usize> {
    match linktype {
        1 => {
            let ether = u16::from_be_bytes(packet.get(12..14)?.try_into().ok()?);
            if ether == 0x0800 {
                Some(14)
            } else if ether == 0x8100 && packet.get(16..18)? == [8, 0] {
                Some(18)
            } else {
                None
            }
        }
        101 | 228 => Some(0),
        113 if packet.get(14..16)? == [8, 0] => Some(16),
        276 if packet.get(..2)? == [8, 0] => Some(20),
        _ => None,
    }
}

fn ipv4_udp_packet(packet: &[u8], start: usize) -> Option<(&[u8], &[u8])> {
    let ip = packet.get(start..)?;
    if ip.len() < 20 || ip[0] >> 4 != 4 || ip[9] != 17 {
        return None;
    }
    let ihl = usize::from(ip[0] & 15) * 4;
    let total = usize::from(u16::from_be_bytes([ip[2], ip[3]]));
    if ihl < 20
        || total > ip.len()
        || total < ihl + 8
        || u16::from_be_bytes([ip[6], ip[7]]) & 0x3fff != 0
    {
        return None;
    }
    let udp = ip.get(ihl..total)?;
    let length = usize::from(u16::from_be_bytes([udp[4], udp[5]]));
    if length < 8 || length > udp.len() {
        return None;
    }
    Some((ip, &udp[..length]))
}

fn udp_endpoints(ip: &[u8], udp: &[u8]) -> String {
    let source = std::net::Ipv4Addr::new(ip[12], ip[13], ip[14], ip[15]);
    let destination = std::net::Ipv4Addr::new(ip[16], ip[17], ip[18], ip[19]);
    format!(
        "{source}:{}>{destination}:{}",
        u16::from_be_bytes([udp[0], udp[1]]),
        u16::from_be_bytes([udp[2], udp[3]])
    )
}

fn invalid(message: &str) -> String {
    io::Error::new(io::ErrorKind::InvalidData, message).to_string()
}
#[cfg(test)]
mod tests;
