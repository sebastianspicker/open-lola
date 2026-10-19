use super::*;
use crate::config::default_settings;
use crate::station::monitor::NetworkMonitor;
use std::net::UdpSocket;

fn run_against_silent_peer(timeout_secs: f64) -> (Result<(), SessionError>, Duration) {
    let mut settings = default_settings();
    settings.network.peer_silence_timeout_secs = timeout_secs;
    let mut options = SessionOptions::demo();
    options.persistent = true;
    options.audio_only = true;
    options.stream_tx_audio = true;
    options.stream_rx_audio = true;
    options.stream_tx_video = false;
    options.stream_rx_video = false;
    let mut transport = SessionMediaTransport::diagnostic_udp(
        Udp::bind("127.0.0.1", 0).unwrap(),
        Udp::bind("127.0.0.1", 0).unwrap(),
    );
    let peer = UdpSocket::bind("127.0.0.1:0").unwrap();
    let peer_addr = peer.local_addr().unwrap();
    let control = Udp::bind("127.0.0.1", 0).unwrap();
    let mut audio = SessionAudioBackend::open(&settings, &options).unwrap();
    let mut result = SessionResult::default();
    let mut monitor = NetworkMonitor::new();
    let started = Instant::now();
    let outcome = run_interleaved_stream(
        None,
        Some(&mut audio),
        &mut transport,
        &settings,
        &options,
        &mut result,
        3,
        started,
        peer_addr,
        peer_addr,
        &control,
        peer_addr,
        1000,
        false,
        8,
        160,
        120,
        1,
        0,
        &mut None,
        &mut Vec::new(),
        &mut monitor,
        &mut FrameReassembler::new(),
        &mut AudioReceiveQueue::new(&settings),
        &mut FrameReassembler::strict_video(),
        &mut VideoReceiveQueue::new(1, 0),
        None,
    );
    let elapsed = started.elapsed();
    let _ = audio.stop();
    (outcome, elapsed)
}

#[test]
fn persistent_stream_ends_with_peer_silent_within_the_timeout_plus_slack() {
    let (outcome, elapsed) = run_against_silent_peer(0.3);
    let Err(SessionError::PeerDisconnect(message)) = outcome else {
        panic!("expected a peer-silent failure, got {outcome:?}");
    };
    assert!(message.starts_with("peer silent for "), "{message}");
    assert!(elapsed >= Duration::from_millis(300), "{elapsed:?}");
    assert!(elapsed < Duration::from_secs(3), "{elapsed:?}");
}
