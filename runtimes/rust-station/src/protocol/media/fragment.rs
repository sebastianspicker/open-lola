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

fn write_fragment_packet(
    out: &mut Vec<u8>,
    frame_id: u32,
    count: u32,
    index: u32,
    offset: usize,
    data: &[u8],
) {
    out.clear();
    out.reserve(FRAGMENT_HEADER_SIZE + data.len());
    out.extend_from_slice(&FRAGMENT_MAGIC);
    out.extend_from_slice(&FRAGMENT_SENTINEL);
    out.extend_from_slice(&frame_id.to_le_bytes());
    out.extend_from_slice(&count.to_le_bytes());
    out.extend_from_slice(&index.to_le_bytes());
    out.extend_from_slice(&(offset as u32).to_le_bytes());
    out.extend_from_slice(&(data.len() as u32).to_le_bytes());
    out.push(u8::from(index + 1 == count));
    out.extend_from_slice(data);
}

fn fragment_packet(frame_id: u32, count: u32, index: u32, offset: usize, data: &[u8]) -> Vec<u8> {
    let mut out = Vec::with_capacity(FRAGMENT_HEADER_SIZE + data.len());
    write_fragment_packet(&mut out, frame_id, count, index, offset, data);
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
    write_video_prelude(&mut out, frame_id, expected_size, fragment_count);
    out
}

fn write_video_prelude(out: &mut Vec<u8>, frame_id: u32, expected_size: u32, fragment_count: u32) {
    out.clear();
    out.resize(VIDEO_PRELUDE_SIZE, 0);
    out[..8].copy_from_slice(&FRAGMENT_MAGIC);
    out[8..12].copy_from_slice(&VIDEO_PRELUDE_SENTINEL);
    out[0x10..0x14].copy_from_slice(&frame_id.to_le_bytes());
    out[0x14..0x18].copy_from_slice(&expected_size.to_le_bytes());
    out[0x1c..0x20].copy_from_slice(&fragment_count.to_le_bytes());
}

/// Session-only representation which owns one serialized frame and writes
/// each wire datagram into caller-owned scratch storage on demand.
#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct StreamingVideoFragments {
    serialized: Vec<u8>,
    frame_id: u32,
    fragment_count: u32,
    fragment_capacity: usize,
}

impl StreamingVideoFragments {
    pub(crate) fn new(
        sequence: u32,
        payload: &[u8],
        frame_id: Option<u32>,
        packet_size: usize,
    ) -> Self {
        let serialized = serialize_media_frame(sequence, payload);
        let fragment_capacity = clamp_packet_size(packet_size) - FRAGMENT_HEADER_SIZE;
        let fragment_count = serialized.len().max(1).div_ceil(fragment_capacity) as u32;
        Self {
            serialized,
            frame_id: frame_id.unwrap_or(sequence),
            fragment_count,
            fragment_capacity,
        }
    }

    pub(crate) fn datagram_count(&self) -> usize {
        self.fragment_count as usize + 1
    }

    pub(crate) fn maximum_datagram_size(&self) -> usize {
        VIDEO_PRELUDE_SIZE
            .max(FRAGMENT_HEADER_SIZE + self.serialized.len().min(self.fragment_capacity))
    }

    pub(crate) fn write_datagram<'a>(
        &self,
        datagram_index: usize,
        scratch: &'a mut Vec<u8>,
    ) -> Option<&'a [u8]> {
        if datagram_index == 0 {
            write_video_prelude(
                scratch,
                self.frame_id,
                self.serialized.len() as u32,
                self.fragment_count,
            );
            return Some(scratch);
        }
        let fragment_index = datagram_index - 1;
        if fragment_index >= self.fragment_count as usize {
            return None;
        }
        let offset = fragment_index * self.fragment_capacity;
        let end = (offset + self.fragment_capacity).min(self.serialized.len());
        write_fragment_packet(
            scratch,
            self.frame_id,
            self.fragment_count,
            fragment_index as u32,
            offset,
            &self.serialized[offset..end],
        );
        Some(scratch)
    }
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
    let mut packet = Vec::with_capacity(AUDIO_UDP_PAYLOAD_SIZE);
    write_audio_payload(&mut packet, sequence, pcm, frame_id)?;
    Ok(packet)
}

fn write_audio_payload(
    packet: &mut Vec<u8>,
    sequence: u32,
    pcm: &[u8],
    frame_id: Option<u32>,
) -> Result<(), MediaError> {
    let frame_id = frame_id.unwrap_or_else(|| sequence.wrapping_add(1));
    let serialized_len = 8usize
        .checked_add(pcm.len())
        .ok_or(MediaError::ShortPayload(
            usize::MAX,
            AUDIO_UDP_PAYLOAD_SIZE - FRAGMENT_HEADER_SIZE,
        ))?;
    let fragment_capacity = AUDIO_UDP_PAYLOAD_SIZE - FRAGMENT_HEADER_SIZE;
    if serialized_len > fragment_capacity {
        return Err(MediaError::ShortPayload(serialized_len, fragment_capacity));
    }
    packet.clear();
    packet.reserve(AUDIO_UDP_PAYLOAD_SIZE);
    packet.extend_from_slice(&FRAGMENT_MAGIC);
    packet.extend_from_slice(&FRAGMENT_SENTINEL);
    packet.extend_from_slice(&frame_id.to_le_bytes());
    packet.extend_from_slice(&1_u32.to_le_bytes());
    packet.extend_from_slice(&0_u32.to_le_bytes());
    packet.extend_from_slice(&0_u32.to_le_bytes());
    packet.extend_from_slice(&(serialized_len as u32).to_le_bytes());
    packet.push(1);
    packet.extend_from_slice(&sequence.to_le_bytes());
    packet.extend_from_slice(&(pcm.len() as u32).to_le_bytes());
    packet.extend_from_slice(pcm);
    packet.resize(AUDIO_UDP_PAYLOAD_SIZE, 0);
    Ok(())
}

/// Session-owned audio encoder which reuses one fixed-size wire datagram.
#[derive(Debug, Default)]
pub(crate) struct AudioDatagramWriter {
    packet: Vec<u8>,
}

impl AudioDatagramWriter {
    pub(crate) fn new() -> Self {
        Self {
            packet: Vec::with_capacity(AUDIO_UDP_PAYLOAD_SIZE),
        }
    }

    pub(crate) fn write(
        &mut self,
        sequence: u32,
        pcm: &[u8],
        frame_id: Option<u32>,
    ) -> Result<&[u8], MediaError> {
        write_audio_payload(&mut self.packet, sequence, pcm, frame_id)?;
        Ok(&self.packet)
    }
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
    use crate::test_alloc::{measure_allocations, samples, timing_json};
    use std::hint::black_box;

    #[test]
    fn audio_is_1066_and_uses_seq_plus_one() {
        let packet = build_audio_payload(7, &[1; 128], None).unwrap();
        assert_eq!(packet.len(), 1066);
        let fragment = parse_fragment(&packet).unwrap();
        assert_eq!(fragment.frame_id, 8);
        assert_eq!(fragment.fragment_count, 1);
    }

    #[test]
    fn reusable_audio_writer_is_byte_identical_and_keeps_storage() {
        let mut writer = AudioDatagramWriter::new();
        let cases = [
            (0_u32, 0_usize, None),
            (7, 128, None),
            (u32::MAX, 1025, Some(99)),
        ];
        let mut storage = None;
        for (sequence, pcm_len, frame_id) in cases {
            let pcm = (0..pcm_len).map(|value| value as u8).collect::<Vec<_>>();
            let serialized = serialize_media_frame(sequence, &pcm);
            let mut expected = fragment_serialized(
                &serialized,
                frame_id.unwrap_or_else(|| sequence.wrapping_add(1)),
                AUDIO_UDP_PAYLOAD_SIZE,
            )
            .remove(0);
            expected.resize(AUDIO_UDP_PAYLOAD_SIZE, 0);

            let actual = writer
                .write(sequence, &pcm, frame_id)
                .expect("audio packet");
            assert_eq!(actual, expected);
            assert_eq!(actual.len(), AUDIO_UDP_PAYLOAD_SIZE);
            let pointer = actual.as_ptr();
            assert_eq!(*storage.get_or_insert(pointer), pointer);
        }
    }

    #[test]
    fn reusable_audio_writer_preserves_oversize_error() {
        let pcm = vec![0; 1026];
        let mut writer = AudioDatagramWriter::new();
        assert_eq!(
            writer.write(1, &pcm, None),
            Err(MediaError::ShortPayload(1034, 1033))
        );
    }

    #[test]
    fn streaming_video_datagrams_are_byte_identical_to_eager_api() {
        let payload: Vec<u8> = (0..4097).map(|value| value as u8).collect();
        let expected = build_video_payloads(17, &payload, Some(99), 1400);
        let streaming = StreamingVideoFragments::new(17, &payload, Some(99), 1400);
        let mut scratch = Vec::new();
        let actual = (0..streaming.datagram_count())
            .map(|index| {
                streaming
                    .write_datagram(index, &mut scratch)
                    .expect("datagram")
                    .to_vec()
            })
            .collect::<Vec<_>>();
        assert_eq!(actual, expected);
        assert!(streaming
            .write_datagram(streaming.datagram_count(), &mut scratch)
            .is_none());
    }

    #[test]
    #[ignore = "manual release-mode internal audio writer benchmark"]
    fn reusable_audio_writer_has_zero_steady_state_allocations() {
        const OPERATIONS: u64 = 8_192;
        let output_path = std::env::var("RUSTY_LOLA_INTERNAL_AUDIO_BENCHMARK_OUTPUT")
            .expect("set an external benchmark output path");
        let pcm = vec![0x5a; 1_024];
        let mut writer = AudioDatagramWriter::new();
        writer.write(0, &pcm, None).expect("warm writer");
        let mut run = || {
            let mut bytes = 0_u64;
            let mut checksum = 0_u64;
            for sequence in 0..OPERATIONS as u32 {
                let packet = writer.write(sequence, &pcm, None).expect("audio packet");
                bytes += packet.len() as u64;
                checksum = checksum.wrapping_add(u64::from(packet[0x21]));
                black_box(packet);
            }
            (OPERATIONS, bytes, checksum)
        };
        let (elapsed, work) = samples(&mut run);
        let (measured_work, memory) = measure_allocations(&mut run);
        assert_eq!(measured_work, work);
        assert_eq!(memory.calls, 0);
        assert_eq!(memory.bytes, 0);
        let report = serde_json::json!({
            "workload": "internal_reusable_audio_writer",
            "timing": timing_json(elapsed),
            "memory": {"allocation_calls": memory.calls, "allocated_bytes": memory.bytes},
            "work": {"operations": work.0, "wire_bytes": work.1, "checksum": work.2},
        });
        std::fs::write(
            output_path,
            serde_json::to_vec_pretty(&report).expect("serialize benchmark"),
        )
        .expect("write benchmark output");
    }
}
