//! Regression cases for complete finite replies and independently bounded streams.
use super::*;
use crate::config::default_settings;
use crate::protocol::{build_audio_payload, build_video_payloads};
use std::net::UdpSocket;

#[test]
fn finite_one_frame_relay_finishes_every_video_fragment() {
    let settings = default_settings();
    let mut options = SessionOptions::demo();
    options.duration_sec = None;
    options.interleaved_av = true;
    let shared = Arc::new(Mutex::new(SessionResult::default()));
    let control = Udp::bind("127.0.0.1", 0).unwrap();
    let audio = Udp::bind("127.0.0.1", 0).unwrap();
    let video = Udp::bind("127.0.0.1", 0).unwrap();
    let sender = UdpSocket::bind("127.0.0.1:0").unwrap();
    sender
        .set_read_timeout(Some(Duration::from_secs(1)))
        .unwrap();
    let destination = sender.local_addr().unwrap();
    sender
        .send_to(
            &build_audio_payload(1, &[0; 256], None).unwrap(),
            audio.local_addr().unwrap(),
        )
        .unwrap();
    let original = vec![17; 4096];
    let fragments = build_video_payloads(1, &original, None, 512);
    assert!(fragments.len() > 2);
    for packet in &fragments {
        sender.send_to(packet, video.local_addr().unwrap()).unwrap();
    }
    let mut transport = SessionMediaTransport::diagnostic_udp(audio, video);
    let relay = PeerRelay {
        settings: &settings,
        options: &options,
        shared: &shared,
        control_socket: &control,
        peer: destination,
        packet_size: 512,
        video_compressed: false,
        expected_video_peer: Some(destination),
        expected_audio_peer: Some(destination),
    };
    run(
        &relay,
        &mut transport,
        &mut FrameReassembler::strict_video(),
        1,
        Instant::now(),
    )
    .unwrap();
    let result = lock_unpoison(&shared);
    assert_eq!(result.video_frames_sent, 1);
    assert_eq!(result.audio_frames_sent, 1);
    assert_eq!(result.video_deadline_drops, 0);
    let mut reassembler = FrameReassembler::strict_video();
    let mut reconstructed = None;
    let mut buffer = [0; 2048];
    for _ in 0..fragments.len() + 1 {
        let size = sender.recv(&mut buffer).unwrap();
        if size == 1066 {
            continue;
        }
        if let Some(frame) = reassembler.feed(&buffer[..size]).unwrap() {
            reconstructed = Some(frame);
        }
    }
    assert_eq!(
        parse_video_frame(&reconstructed.unwrap(), false)
            .unwrap()
            .payload,
        original
    );
}

#[test]
fn finite_audio_cannot_keep_a_missing_video_stream_alive() {
    let options = SessionOptions::demo();
    let now = Instant::now();
    assert!(ensure_progress(&options, now, now - IDLE_LIMIT, now).is_err());
    assert!(ensure_progress(&options, now - IDLE_LIMIT, now, now).is_err());
    assert!(ensure_progress(&options, now, now, now).is_ok());
}

#[test]
fn control_flood_yields_with_packets_still_queued() {
    let settings = default_settings();
    let options = SessionOptions::demo();
    let shared = Arc::new(Mutex::new(SessionResult::default()));
    let sender = "127.0.0.1:5000".parse().unwrap();
    let mut queued = std::collections::VecDeque::from(vec![(b"invalid".to_vec(), sender); 65]);
    // UDP can drop or defer localhost packets. Inject an exact queue so the
    // assertion measures the control quantum independently of OS delivery.
    assert!(!super::super::super::pump_peer_control_from(
        || Ok(queued.pop_front()),
        sender,
        &settings,
        &options,
        &shared
    )
    .unwrap());
    assert_eq!(queued.len(), 1);
}
