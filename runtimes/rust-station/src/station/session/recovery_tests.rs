//! Regression oracles retained from the retired connector's receive policy.
use super::backends::SessionAudioBackend;
use super::media::{ReceivePrefillQueue, SessionMediaTransport};
use super::*;
use crate::config::default_settings;
use crate::net::Udp;
use crate::protocol::{build_audio_payload, FrameReassembler};
use crate::station::monitor::NetworkMonitor;
use std::net::UdpSocket;
use std::time::{Duration, Instant};

#[test]
fn malformed_audio_then_valid_and_reordered_packets_preserve_session() {
    let socket = Udp::bind("127.0.0.1", 0).unwrap();
    let destination = socket.local_addr().unwrap();
    let video = Udp::bind("127.0.0.1", 0).unwrap();
    let sender = UdpSocket::bind("127.0.0.1:0").unwrap();
    let peer = sender.local_addr().unwrap();
    let mut transport = SessionMediaTransport::diagnostic_udp(socket, video);
    let mut audio =
        SessionAudioBackend::open(&default_settings(), &SessionOptions::demo()).unwrap();
    let mut result = SessionResult::default();
    let mut monitor = NetworkMonitor::new();
    let mut reassembler = FrameReassembler::new();
    let mut queue = ReceivePrefillQueue::new(1, 0);
    let mut record = None;
    let mut malformed = build_audio_payload(1, &[1; 256], None).unwrap();
    malformed[16] = 2;
    for packet in [
        malformed,
        build_audio_payload(10, &[1; 256], Some(7)).unwrap(),
        build_audio_payload(9, &[1; 256], Some(99)).unwrap(),
    ] {
        sender.send_to(&packet, destination).unwrap();
        let before = transport.stats().received_datagrams;
        let deadline = Instant::now() + Duration::from_secs(1);
        while transport.stats().received_datagrams == before && Instant::now() < deadline {
            super::audio::receive_audio_datagram_step(
                &mut audio,
                &mut transport,
                peer,
                &mut reassembler,
                &mut result,
                &mut record,
                &mut monitor,
                &mut queue,
            )
            .unwrap();
        }
        assert!(transport.stats().received_datagrams > before);
    }
    assert_eq!(result.audio_frames_received, 1);
    assert_eq!(result.audio_malformed_drops, 1);
    assert_eq!(monitor.drops, 2);
    audio.stop().unwrap();
}

#[test]
fn audio_freshness_wraps_and_configuration_queue_remains_bounded() {
    let mut queue = ReceivePrefillQueue::new(2, 2);
    assert!(queue.admit_sequence(u32::MAX));
    assert!(queue.admit_sequence(0));
    assert!(!queue.admit_sequence(u32::MAX));
    assert!(!queue.admit_sequence(0));
    assert_eq!(queue.push(1), (None, false));
    assert_eq!(queue.push(2), (Some(1), false));
    assert_eq!(queue.push(3), (Some(2), false));
}

#[test]
fn raw_video_admission_preserves_geometry_and_exact_length_contract() {
    use crate::protocol::VideoFrame;
    for (width, height, bpp, length) in [
        (0, 1, 24, 0),
        (1, 0, 24, 0),
        (1, 1, 7, 1),
        (1, 1, 0, 0),
        (2, 2, 24, 11),
        (2, 2, 24, 13),
        (u32::MAX, 2, 24, 0),
    ] {
        let frame = VideoFrame {
            sequence: 1,
            compressed: false,
            payload: vec![0; length],
        };
        assert!(super::video::validate_received_video(frame, width, height, bpp).is_err());
    }
    let frame = VideoFrame {
        sequence: 1,
        compressed: false,
        payload: vec![0; 12],
    };
    assert!(super::video::validate_received_video(frame, 2, 2, 24).is_ok());
    let corrupt = VideoFrame {
        sequence: 1,
        compressed: true,
        payload: vec![0; 12],
    };
    assert!(super::video::validate_received_video(corrupt, 2, 2, 24).is_err());
}

#[test]
fn failed_start_cleanup_is_once_per_resource_and_restart_has_fresh_ownership() {
    use super::lifecycle::{CleanupFinalizer, CleanupReport};
    use std::cell::Cell;
    let primary = crate::station::SessionError::VideoBackend("open failed".into());
    let audio_calls = Cell::new(0);
    let socket_calls = Cell::new(0);
    for _ in 0..2 {
        let mut cleanup = CleanupReport::default();
        let mut audio = || {
            audio_calls.set(audio_calls.get() + 1);
            Err(crate::station::SessionError::Cleanup(
                "audio stop failed".into(),
            ))
        };
        let mut socket = || {
            socket_calls.set(socket_calls.get() + 1);
            Err(crate::station::SessionError::Cleanup(
                "socket close failed".into(),
            ))
        };
        let mut finalizers: [CleanupFinalizer<'_>; 2] =
            [("audio", &mut audio), ("socket", &mut socket)];
        assert_eq!(
            cleanup.finalize(Some(primary.clone()), &mut finalizers),
            Err(primary.clone())
        );
        assert_eq!(cleanup.warnings.len(), 2);
        assert!(cleanup.finalize(None, &mut finalizers).is_ok());
    }
    assert_eq!(audio_calls.get(), 2);
    assert_eq!(socket_calls.get(), 2);
}

#[test]
fn mismatched_claimed_control_source_cannot_enable_audio_signal() {
    let socket = Udp::bind("127.0.0.1", 0).unwrap();
    let peer = UdpSocket::bind("127.0.0.1:0").unwrap();
    peer.set_nonblocking(true).unwrap();
    let mut settings = default_settings();
    settings.network.local_ip = "127.0.0.1".into();
    settings.network.remote_ip = "127.0.0.1".into();
    let packet = crate::protocol::build_control_datagram(
        "MESG_SEND_AUDIO_SIGNAL",
        "192.0.2.10",
        "127.0.0.1",
        settings.network.session_id.try_into().unwrap(),
        None,
        "",
    )
    .unwrap();
    peer.send_to(&packet, socket.local_addr().unwrap()).unwrap();
    let mut result = SessionResult::default();
    for _ in 0..10 {
        assert!(!super::control::pump_control(
            &socket,
            peer.local_addr().unwrap(),
            &settings,
            &mut result,
            None
        )
        .unwrap());
        std::thread::sleep(Duration::from_millis(1));
    }
    assert!(result.audio_signal_active != Some(true));
    assert!(result.messages_received.is_empty());
    let mut reply = [0; 1024];
    assert_eq!(
        peer.recv_from(&mut reply).unwrap_err().kind(),
        std::io::ErrorKind::WouldBlock
    );
}

#[test]
fn video_only_session_does_not_open_an_audio_device() {
    let mut options = SessionOptions::demo();
    options.stream_tx_audio = false;
    options.stream_rx_audio = false;
    options.audio_backend = crate::config::AudioBackend::Alsa;
    let mut audio = SessionAudioBackend::open(&default_settings(), &options).unwrap();
    assert!(audio.name().is_empty());
    assert_eq!(audio.xruns(), None);
    assert!(audio.read_pcm().is_err());
    audio.stop().unwrap();
    let mut settings = default_settings();
    settings.video.width = 64;
    settings.video.height = 48;
    settings.video.bpp = 24;
    settings.video.bayer = 0;
    options.use_catalog_geometry = false;
    options.interleaved_av = true;
    let result = run_session(settings, 2.0, options);
    assert!(result.ok, "{}", result.error);
    assert!(result.video_frames_received > 0);
    assert_eq!(result.audio_frames_sent, 0);
    assert_eq!(result.audio_lateness_p95_upper_us, None);
}
