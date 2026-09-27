use std::time::Duration;

use thiserror::Error;

pub const FRAGMENT_MAGIC: [u8; 8] = [0xfd, 0xfd, 0xfd, 0xfd, 0xdf, 0xdf, 0xdf, 0xdf];
pub const FRAGMENT_SENTINEL: [u8; 4] = [0xee; 4];
pub const VIDEO_PRELUDE_SENTINEL: [u8; 4] = [0xaa; 4];
pub const FRAGMENT_HEADER_SIZE: usize = 0x21;
pub const MEDIA_HEADER_OFFSET: usize = 0x0c;
pub const VIDEO_PRELUDE_SIZE: usize = 0x40;
pub const AUDIO_UDP_PAYLOAD_SIZE: usize = 0x42a;
pub const MAX_MEDIA_FRAME_SIZE: usize = 16 * 1024 * 1024;
pub const MAX_MEDIA_FRAGMENT_COUNT: u32 = 16_384;
/// Aggregate in-flight media allocation ceiling per reassembler.
pub const MAX_REASSEMBLY_BUFFERED_BYTES: usize = 256 * 1024 * 1024;
pub const REASSEMBLY_EXPIRY: Duration = Duration::from_secs(2);

#[derive(Debug, Error, PartialEq, Eq)]
pub enum MediaError {
    #[error("serialized LoLa media frame is shorter than 8 bytes")]
    TooShort,
    #[error("serialized LoLa media payload length mismatch")]
    LengthMismatch,
    #[error("empty media payload")]
    Empty,
    #[error("empty JPEG payload")]
    EmptyJpeg,
    #[error("empty PCM payload")]
    EmptyPcm,
    #[error("raw video payload too short: {0} < {1}")]
    ShortPayload(usize, usize),
    #[error("invalid LoLa media frame size: {0}")]
    InvalidFrameSize(usize),
    #[error("invalid LoLa fragment count: {0}")]
    InvalidFragmentCount(u32),
    #[error("fragment packet is malformed")]
    BadFragment,
    #[error("fragment length does not fit packet")]
    FragmentTruncated,
    #[error("fragment index {0} is outside declared count")]
    FragmentIndex(u32),
    #[error("fragment exceeds declared frame size: {0} > {1}")]
    FragmentExceeds(usize, usize),
    #[error("fragment overlaps declared frame range at offset {0}")]
    FragmentOverlap(usize),
    #[error("fragment gap in declared frame range: {0}..{1}")]
    FragmentGap(usize, usize),
    #[error("fragment coverage does not match declared frame size: {0} != {1}")]
    FragmentCoverage(usize, usize),
    #[error("duplicate fragment index {0}")]
    DuplicateFragment(u32),
    #[error("fragment count {received} does not match active frame count {expected}")]
    FragmentCountMismatch { expected: u32, received: u32 },
    #[error("active LoLa media bytes exceed bounded capacity: {received} > {limit}")]
    BufferedLimitExceeded { received: usize, limit: usize },
    #[error("too many active LoLa media frames")]
    TooManyActiveFrames,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AudioFrame {
    pub sequence: u32,
    pub pcm: Vec<u8>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VideoFrame {
    pub sequence: u32,
    pub payload: Vec<u8>,
    pub compressed: bool,
}

impl AudioFrame {
    pub(crate) fn validate(&self) -> Result<(), MediaError> {
        if self.pcm.is_empty() {
            return Err(MediaError::EmptyPcm);
        }
        Ok(())
    }

    /// Serialize the exact common LoLa media body used by audio datagrams.
    pub fn serialize(&self) -> Result<Vec<u8>, MediaError> {
        self.validate()?;
        Ok(serialize_media_frame(self.sequence, &self.pcm))
    }
}

impl VideoFrame {
    pub(crate) fn validate(&self) -> Result<(), MediaError> {
        if self.payload.is_empty() {
            return Err(if self.compressed {
                MediaError::EmptyJpeg
            } else {
                MediaError::Empty
            });
        }
        Ok(())
    }

    /// Serialize the exact common LoLa media body. Compression belongs to the
    /// negotiated stream context, not to the body itself.
    pub fn serialize(&self) -> Result<Vec<u8>, MediaError> {
        self.validate()?;
        Ok(serialize_media_frame(self.sequence, &self.payload))
    }
}

pub fn serialize_media_frame(sequence: u32, payload: &[u8]) -> Vec<u8> {
    let mut out = Vec::with_capacity(8 + payload.len());
    out.extend_from_slice(&sequence.to_le_bytes());
    out.extend_from_slice(&(payload.len() as u32).to_le_bytes());
    out.extend_from_slice(payload);
    out
}

pub fn parse_serialized_media(data: &[u8]) -> Result<(u32, Vec<u8>), MediaError> {
    if data.len() < 8 {
        return Err(MediaError::TooShort);
    }
    let sequence = u32::from_le_bytes(data[0..4].try_into().expect("slice length"));
    let length = u32::from_le_bytes(data[4..8].try_into().expect("slice length")) as usize;
    if data.len() != 8 + length {
        return Err(MediaError::LengthMismatch);
    }
    Ok((sequence, data[8..].to_vec()))
}

pub fn parse_audio_frame(data: &[u8]) -> Result<AudioFrame, MediaError> {
    let (sequence, pcm) = parse_serialized_media(data)?;
    Ok(AudioFrame { sequence, pcm })
}

pub fn parse_video_frame(data: &[u8], compressed: bool) -> Result<VideoFrame, MediaError> {
    let (sequence, payload) = parse_serialized_media(data)?;
    Ok(VideoFrame {
        sequence,
        payload,
        compressed,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn video_validation_preserves_serialize_errors_without_owning_payload() {
        for (compressed, expected) in [(false, MediaError::Empty), (true, MediaError::EmptyJpeg)] {
            let frame = VideoFrame {
                sequence: 1,
                payload: Vec::new(),
                compressed,
            };
            assert_eq!(frame.validate(), Err(expected));
            assert_eq!(frame.serialize(), frame.validate().map(|()| Vec::new()));
        }

        let frame = VideoFrame {
            sequence: 2,
            payload: vec![1, 2, 3],
            compressed: false,
        };
        let payload_ptr = frame.payload.as_ptr();
        frame.validate().unwrap();
        assert_eq!(frame.payload.as_ptr(), payload_ptr);
    }
}
