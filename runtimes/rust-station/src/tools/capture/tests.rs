use super::*;
use crate::net::build_ethernet_ipv4_udp_frame;
use crate::protocol::build_video_payloads;
fn wire(payload: &[u8]) -> Vec<u8> {
    build_ethernet_ipv4_udp_frame(
        [1; 6],
        [2; 6],
        "127.0.0.1".parse().unwrap(),
        "127.0.0.2".parse().unwrap(),
        19798,
        19798,
        payload,
        None,
    )
    .unwrap()
}
fn pcap(packets: &[Vec<u8>]) -> Vec<u8> {
    let mut bytes = vec![0xd4, 0xc3, 0xb2, 0xa1, 2, 0, 4, 0];
    bytes.extend([0; 8]);
    bytes.extend(65535_u32.to_le_bytes());
    bytes.extend(1_u32.to_le_bytes());
    for packet in packets {
        bytes.extend([0; 8]);
        for _ in 0..2 {
            bytes.extend((packet.len() as u32).to_le_bytes());
        }
        bytes.extend(packet);
    }
    bytes
}
fn block(kind: u32, mut body: Vec<u8>) -> Vec<u8> {
    while !body.len().is_multiple_of(4) {
        body.push(0);
    }
    let length = (body.len() + 12) as u32;
    let mut result = kind.to_le_bytes().to_vec();
    result.extend(length.to_le_bytes());
    result.extend(body);
    result.extend(length.to_le_bytes());
    result
}
fn pcapng(packets: &[Vec<u8>]) -> Vec<u8> {
    let mut section = vec![0x4d, 0x3c, 0x2b, 0x1a, 1, 0, 0, 0];
    section.extend([255; 8]);
    let mut bytes = block(0x0a0d0d0a, section);
    let mut interface = vec![1, 0, 0, 0];
    interface.extend(65535_u32.to_le_bytes());
    bytes.extend(block(1, interface));
    for packet in packets {
        let mut body = vec![0; 12];
        for _ in 0..2 {
            body.extend((packet.len() as u32).to_le_bytes());
        }
        body.extend(packet);
        bytes.extend(block(6, body));
    }
    bytes
}
#[test]
fn both_containers_preserve_preludes_fragments_duplicates_and_endpoints() {
    let payloads = build_video_payloads(7, &[9; 1024], Some(42), 500);
    let mut packets: Vec<_> = payloads.iter().map(|payload| wire(payload)).collect();
    packets.push(packets[1].clone());
    for capture in [pcap(&packets), pcapng(&packets)] {
        let summary = decode_bytes(&capture).unwrap();
        assert_eq!(summary.prelude_total, 1);
        assert_eq!(summary.frames.len(), 1);
        let frame = summary.frames.values().next().unwrap();
        assert!(frame.complete);
        assert_eq!(frame.duplicate_fragments, 1);
        assert_eq!(frame.bytes, 1032);
    }
}
#[test]
fn container_truncation_and_lengths_fail_without_panics() {
    let packets = [wire(&build_video_payloads(1, &[1; 100], None, 500)[1])];
    for capture in [pcap(&packets), pcapng(&packets)] {
        for length in 0..capture.len() {
            let _ = decode_bytes(&capture[..length]);
        }
        assert!(decode_bytes(&capture[..capture.len() - 1]).is_err());
    }
    assert!(decode_bytes(&[0; 24]).is_err());
}
#[test]
fn malformed_packet_does_not_hide_subsequent_valid_frame() {
    let mut packets = vec![wire(b"bad payload")];
    packets.extend(
        build_video_payloads(1, &[1; 100], None, 500)
            .iter()
            .map(|payload| wire(payload)),
    );
    let summary = decode_bytes(&pcap(&packets)).unwrap();
    assert_eq!(summary.malformed_drops, 1);
    assert!(summary.frames.values().next().unwrap().complete);
}

#[test]
fn repeated_prelude_ids_never_merge_occurrences() {
    let payloads = build_video_payloads(7, &[9; 700], Some(42), 500);
    assert_eq!(payloads.len(), 3);
    let packets = [
        wire(&payloads[0]),
        wire(&payloads[1]),
        wire(&payloads[0]),
        wire(&payloads[2]),
    ];
    let summary = decode_bytes(&pcap(&packets)).unwrap();
    assert_eq!(summary.frames.len(), 2);
    assert!(summary.frames.values().all(|frame| !frame.complete));
}
#[test]
fn conflicting_duplicate_prevents_complete_evidence() {
    let payloads = build_video_payloads(7, &[9; 100], Some(42), 500);
    let mut duplicate = payloads[1].clone();
    *duplicate.last_mut().unwrap() ^= 1;
    let summary = decode_bytes(&pcap(&[
        wire(&payloads[0]),
        wire(&payloads[1]),
        wire(&duplicate),
    ]))
    .unwrap();
    let frame = summary.frames.values().next().unwrap();
    assert!(!frame.complete);
    assert_eq!(frame.conflicting_fragments, 1);
}
