use super::{
    serialize_media_frame, MediaError, AUDIO_UDP_PAYLOAD_SIZE, FRAGMENT_HEADER_SIZE,
    FRAGMENT_MAGIC, FRAGMENT_SENTINEL, VIDEO_PRELUDE_SENTINEL, VIDEO_PRELUDE_SIZE,
};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Fragment {
    pub frame_id: u32,
    pub fragment_count: u32,
    pub fragment_index: u32,
    pub original_offset: u32,
    pub fragment_length: u32,
    pub flags: u8,
    pub data: Vec<u8>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct VideoPrelude {
    pub frame_id: u32,
    pub expected_size: u32,
    pub fragment_count: u32,
}

pub fn clamp_packet_size(packet_size: usize) -> usize {
    packet_size.clamp(0x80, 0x2000)
}

fn fragment_packet(frame_id: u32, count: u32, index: u32, offset: usize, data: &[u8]) -> Vec<u8> {
    let mut out = Vec::with_capacity(FRAGMENT_HEADER_SIZE + data.len());
    out.extend_from_slice(&FRAGMENT_MAGIC);
    out.extend_from_slice(&FRAGMENT_SENTINEL);
    out.extend_from_slice(&frame_id.to_le_bytes());
    out.extend_from_slice(&count.to_le_bytes());
    out.extend_from_slice(&index.to_le_bytes());
    out.extend_from_slice(&(offset as u32).to_le_bytes());
    out.extend_from_slice(&(data.len() as u32).to_le_bytes());
    out.push(u8::from(index + 1 == count));
    out.extend_from_slice(data);
    out
}

pub fn fragment_serialized(serialized: &[u8], frame_id: u32, packet_size: usize) -> Vec<Vec<u8>> {
    let packet_size = clamp_packet_size(packet_size);
    let capacity = packet_size - FRAGMENT_HEADER_SIZE;
    let count = serialized.len().max(1).div_ceil(capacity) as u32;
    (0..count)
        .map(|index| {
            let offset = index as usize * capacity;
            let end = (offset + capacity).min(serialized.len());
            fragment_packet(frame_id, count, index, offset, &serialized[offset..end])
        })
        .collect()
}

pub fn parse_fragment(payload: &[u8]) -> Result<Fragment, MediaError> {
    if payload.len() < FRAGMENT_HEADER_SIZE
        || payload[..8] != FRAGMENT_MAGIC
        || payload[8..12] != FRAGMENT_SENTINEL
    {
        return Err(MediaError::BadFragment);
    }
    let u32_at =
        |at: usize| u32::from_le_bytes(payload[at..at + 4].try_into().expect("checked header"));
    let frame_id = u32_at(0x0c);
    let fragment_count = u32_at(0x10);
    let fragment_index = u32_at(0x14);
    let original_offset = u32_at(0x18);
    let fragment_length = u32_at(0x1c);
    let end = FRAGMENT_HEADER_SIZE
        .checked_add(fragment_length as usize)
        .ok_or(MediaError::FragmentTruncated)?;
    if end > payload.len() {
        return Err(MediaError::FragmentTruncated);
    }
    Ok(Fragment {
        frame_id,
        fragment_count,
        fragment_index,
        original_offset,
        fragment_length,
        flags: payload[0x20],
        data: payload[FRAGMENT_HEADER_SIZE..end].to_vec(),
    })
}

pub fn build_video_prelude(frame_id: u32, expected_size: u32, fragment_count: u32) -> Vec<u8> {
    let mut out = vec![0; VIDEO_PRELUDE_SIZE];
    out[..8].copy_from_slice(&FRAGMENT_MAGIC);
    out[8..12].copy_from_slice(&VIDEO_PRELUDE_SENTINEL);
    out[0x10..0x14].copy_from_slice(&frame_id.to_le_bytes());
    out[0x14..0x18].copy_from_slice(&expected_size.to_le_bytes());
    out[0x1c..0x20].copy_from_slice(&fragment_count.to_le_bytes());
    out
}

pub fn parse_video_prelude(payload: &[u8]) -> Option<VideoPrelude> {
    if payload.len() != VIDEO_PRELUDE_SIZE
        || payload[..8] != FRAGMENT_MAGIC
        || payload[8..12] != VIDEO_PRELUDE_SENTINEL
    {
        return None;
    }
    Some(VideoPrelude {
        frame_id: u32::from_le_bytes(payload[0x10..0x14].try_into().ok()?),
        expected_size: u32::from_le_bytes(payload[0x14..0x18].try_into().ok()?),
        fragment_count: u32::from_le_bytes(payload[0x1c..0x20].try_into().ok()?),
    })
}

pub fn build_audio_payload(
    sequence: u32,
    pcm: &[u8],
    frame_id: Option<u32>,
) -> Result<Vec<u8>, MediaError> {
    let frame_id = frame_id.unwrap_or_else(|| sequence.wrapping_add(1));
    let serialized = serialize_media_frame(sequence, pcm);
    let mut packets = fragment_serialized(&serialized, frame_id, AUDIO_UDP_PAYLOAD_SIZE);
    if packets.len() != 1 {
        return Err(MediaError::ShortPayload(
            serialized.len(),
            AUDIO_UDP_PAYLOAD_SIZE - FRAGMENT_HEADER_SIZE,
        ));
    }
    packets[0].resize(AUDIO_UDP_PAYLOAD_SIZE, 0);
    Ok(packets.remove(0))
}

pub fn expected_audio_payload_size(
    channels: u16,
    bits_per_sample: u16,
    frames_per_callback: u16,
) -> usize {
    channels as usize * frames_per_callback as usize * (bits_per_sample as usize / 8)
}

pub fn build_video_payloads(
    sequence: u32,
    payload: &[u8],
    frame_id: Option<u32>,
    packet_size: usize,
) -> Vec<Vec<u8>> {
    let frame_id = frame_id.unwrap_or(sequence);
    let serialized = serialize_media_frame(sequence, payload);
    let fragments = fragment_serialized(&serialized, frame_id, packet_size);
    let mut out = Vec::with_capacity(fragments.len() + 1);
    out.push(build_video_prelude(
        frame_id,
        serialized.len() as u32,
        fragments.len() as u32,
    ));
    out.extend(fragments);
    out
}

pub fn parse_media_payload(data: &[u8]) -> Result<Option<Fragment>, MediaError> {
    if parse_video_prelude(data).is_some() {
        return Ok(None);
    }
    parse_fragment(data).map(Some)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn audio_is_1066_and_uses_seq_plus_one() {
        let packet = build_audio_payload(7, &[1; 128], None).unwrap();
        assert_eq!(packet.len(), 1066);
        let fragment = parse_fragment(&packet).unwrap();
        assert_eq!(fragment.frame_id, 8);
        assert_eq!(fragment.fragment_count, 1);
    }
}
