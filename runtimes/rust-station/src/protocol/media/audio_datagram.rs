//! One-pass admission for the fixed-size LoLa audio quantum.
use super::{
    AudioFrame, MediaError, AUDIO_UDP_PAYLOAD_SIZE, FRAGMENT_HEADER_SIZE, FRAGMENT_MAGIC,
    FRAGMENT_SENTINEL,
};

pub fn parse_audio_datagram(packet: &[u8]) -> Result<AudioFrame, MediaError> {
    if packet.len() != AUDIO_UDP_PAYLOAD_SIZE
        || packet[..8] != FRAGMENT_MAGIC
        || packet[8..12] != FRAGMENT_SENTINEL
    {
        return Err(MediaError::BadFragment);
    }
    let value = |at| u32::from_le_bytes(packet[at..at + 4].try_into().expect("fixed audio header"));
    if value(16) != 1 || value(20) != 0 || value(24) != 0 {
        return Err(MediaError::BadFragment);
    }
    let length = value(28) as usize;
    if length < 8 || length > packet.len() - FRAGMENT_HEADER_SIZE {
        return Err(MediaError::FragmentTruncated);
    }
    let sequence = value(FRAGMENT_HEADER_SIZE);
    let pcm_length = value(FRAGMENT_HEADER_SIZE + 4) as usize;
    if pcm_length == 0 || pcm_length + 8 != length {
        return Err(MediaError::LengthMismatch);
    }
    Ok(AudioFrame {
        sequence,
        pcm: packet[FRAGMENT_HEADER_SIZE + 8..FRAGMENT_HEADER_SIZE + length].to_vec(),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::protocol::build_audio_payload;
    #[test]
    fn sequence_and_fragment_id_are_independent_and_padding_is_not_pcm() {
        let packet = build_audio_payload(17, &[1; 256], Some(99)).unwrap();
        let decoded = parse_audio_datagram(&packet).unwrap();
        assert_eq!(decoded.sequence, 17);
        assert_eq!(decoded.pcm, [1; 256]);
    }
    #[test]
    fn malformed_shapes_are_rejected_before_payload_allocation() {
        let packet = build_audio_payload(1, &[1; 256], None).unwrap();
        for offset in [0, 8, 16, 20, 24, 28, 37] {
            let mut malformed = packet.clone();
            malformed[offset] = 255;
            assert!(parse_audio_datagram(&malformed).is_err(), "offset {offset}");
        }
        assert!(parse_audio_datagram(&packet[..packet.len() - 1]).is_err());
        assert!(parse_audio_datagram(&build_audio_payload(1, &[], None).unwrap()).is_err());
        assert!(parse_audio_datagram(&packet).is_ok());
    }
}
