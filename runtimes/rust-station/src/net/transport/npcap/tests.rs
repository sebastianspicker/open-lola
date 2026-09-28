use super::*;
use crate::net::pcap::build_ethernet_ipv4_udp_frame;
use std::cell::RefCell;
use std::collections::VecDeque;
use std::sync::{
    atomic::{AtomicUsize, Ordering},
    Arc,
};
use std::time::{Duration, UNIX_EPOCH};

const SOURCE_IP: Ipv4Addr = Ipv4Addr::new(192, 0, 2, 10);
const PEER_IP: Ipv4Addr = Ipv4Addr::new(192, 0, 2, 20);
const SOURCE_MAC: [u8; 6] = [0, 1, 2, 3, 4, 5];
const PEER_MAC: [u8; 6] = [6, 7, 8, 9, 10, 11];
const AUDIO_PORT: u16 = 19_788;
const VIDEO_PORT: u16 = 19_798;
type CapturedFrame = (Vec<u8>, SystemTime);
type CaptureResult = Result<Option<CapturedFrame>, String>;

struct FakeCapturePlane {
    frames: RefCell<VecDeque<CaptureResult>>,
    kernel_drops: u64,
    kernel_error: Option<String>,
    kernel_snapshot_calls: Arc<AtomicUsize>,
    drops: Arc<AtomicUsize>,
}

impl FakeCapturePlane {
    fn new(
        frames: impl IntoIterator<Item = CaptureResult>,
        kernel_drops: u64,
        kernel_snapshot_calls: Arc<AtomicUsize>,
        drops: Arc<AtomicUsize>,
    ) -> Self {
        Self {
            frames: RefCell::new(frames.into_iter().collect()),
            kernel_drops,
            kernel_error: None,
            kernel_snapshot_calls,
            drops,
        }
    }
}

impl Drop for FakeCapturePlane {
    fn drop(&mut self) {
        self.drops.fetch_add(1, Ordering::SeqCst);
    }
}

impl CapturePlane for FakeCapturePlane {
    fn send(&self, _frame: &[u8]) -> Result<(), String> {
        Ok(())
    }

    fn receive_with(
        &self,
        inspect: &mut dyn FnMut(&[u8], SystemTime) -> Option<ReceivedDatagram>,
    ) -> Result<Option<ReceivedDatagram>, String> {
        match self.frames.borrow_mut().pop_front().unwrap_or(Ok(None))? {
            Some((frame, timestamp)) => Ok(inspect(&frame, timestamp)),
            None => Ok(None),
        }
    }

    fn kernel_drop_snapshot(&self) -> Result<u64, String> {
        self.kernel_snapshot_calls.fetch_add(1, Ordering::SeqCst);
        if let Some(error) = &self.kernel_error {
            return Err(error.clone());
        }
        Ok(self.kernel_drops)
    }

    fn finalize(self: Box<Self>) -> Result<u64, String> {
        self.kernel_drop_snapshot()
    }
}

fn transport(
    frames: impl IntoIterator<Item = CaptureResult>,
    kernel_drops: u64,
    drops: Arc<AtomicUsize>,
) -> NpcapMediaTransport {
    transport_with_kernel_result(
        frames,
        kernel_drops,
        None,
        Arc::new(AtomicUsize::new(0)),
        drops,
    )
}

fn transport_with_kernel_result(
    frames: impl IntoIterator<Item = CaptureResult>,
    kernel_drops: u64,
    kernel_error: Option<String>,
    kernel_snapshot_calls: Arc<AtomicUsize>,
    drops: Arc<AtomicUsize>,
) -> NpcapMediaTransport {
    let mut plane = FakeCapturePlane::new(frames, kernel_drops, kernel_snapshot_calls, drops);
    plane.kernel_error = kernel_error;
    NpcapMediaTransport {
        plane: Some(Box::new(plane)),
        source_ip: SOURCE_IP,
        peer_ip: PEER_IP,
        source_mac: SOURCE_MAC,
        peer_mac: PEER_MAC,
        audio_port: AUDIO_PORT,
        video_port: VIDEO_PORT,
        vlan_tag: None,
        pending_audio: VecDeque::with_capacity(1),
        pending_video: VecDeque::with_capacity(1),
        audio_queue_depth: 1,
        video_queue_depth: 1,
        stats: TransportStats::default(),
    }
}

fn frame(source_port: u16, destination_port: u16, payload: &[u8]) -> Vec<u8> {
    build_ethernet_ipv4_udp_frame(
        PEER_MAC,
        SOURCE_MAC,
        PEER_IP,
        SOURCE_IP,
        source_port,
        destination_port,
        payload,
        None,
    )
    .expect("test frame is valid")
}

fn captured(frame: Vec<u8>) -> CaptureResult {
    Ok(Some((frame, UNIX_EPOCH + Duration::from_secs(1))))
}

#[test]
fn receive_polls_do_not_query_kernel_statistics() {
    let drops = Arc::new(AtomicUsize::new(0));
    let snapshot_calls = Arc::new(AtomicUsize::new(0));
    let mut transport = transport_with_kernel_result(
        [Ok(None), Ok(None)],
        3,
        None,
        Arc::clone(&snapshot_calls),
        Arc::clone(&drops),
    );

    assert_eq!(transport.receive().expect("empty poll"), None);
    assert_eq!(transport.receive().expect("second empty poll"), None);
    assert_eq!(transport.stats().kernel_drops, 0);
    assert_eq!(snapshot_calls.load(Ordering::SeqCst), 0);
    assert_eq!(drops.load(Ordering::SeqCst), 0);
}

#[test]
fn reporting_snapshot_refreshes_kernel_counter_once() {
    let drops = Arc::new(AtomicUsize::new(0));
    let snapshot_calls = Arc::new(AtomicUsize::new(0));
    let mut transport = transport_with_kernel_result(
        [captured(frame(AUDIO_PORT, AUDIO_PORT, b"accepted"))],
        7,
        None,
        Arc::clone(&snapshot_calls),
        drops,
    );

    transport.receive().expect("receive packet");
    assert_eq!(snapshot_calls.load(Ordering::SeqCst), 0);
    let stats = transport.stats_snapshot().expect("reporting snapshot");

    assert_eq!(stats.received_datagrams, 1);
    assert_eq!(stats.kernel_drops, 7);
    assert_eq!(snapshot_calls.load(Ordering::SeqCst), 1);
}

#[test]
fn reporting_snapshot_is_fallible_without_losing_software_counters() {
    let drops = Arc::new(AtomicUsize::new(0));
    let snapshot_calls = Arc::new(AtomicUsize::new(0));
    let mut transport = transport_with_kernel_result(
        [captured(frame(AUDIO_PORT, AUDIO_PORT, b"accepted"))],
        0,
        Some("stats unavailable".into()),
        Arc::clone(&snapshot_calls),
        drops,
    );

    transport.receive().expect("receive packet");
    let error = transport
        .stats_snapshot()
        .expect_err("reporting snapshot failure");

    assert!(error.to_string().contains("stats unavailable"));
    assert_eq!(transport.stats().received_datagrams, 1);
    assert_eq!(snapshot_calls.load(Ordering::SeqCst), 1);
}

#[test]
fn receive_accepts_matching_packets_and_rejects_wrong_peer_or_port() {
    let drops = Arc::new(AtomicUsize::new(0));
    let wrong_peer = build_ethernet_ipv4_udp_frame(
        PEER_MAC,
        SOURCE_MAC,
        Ipv4Addr::new(192, 0, 2, 99),
        SOURCE_IP,
        AUDIO_PORT,
        AUDIO_PORT,
        b"wrong-peer",
        None,
    )
    .expect("test frame is valid");
    let mut transport = transport(
        [
            captured(frame(AUDIO_PORT, AUDIO_PORT, b"accepted")),
            captured(wrong_peer),
            captured(frame(45_000, 45_000, b"wrong-port")),
        ],
        5,
        drops,
    );

    let accepted = transport
        .receive()
        .expect("accepted packet")
        .expect("packet");
    assert_eq!(accepted.kind, MediaKind::Audio);
    assert_eq!(accepted.payload, b"accepted");
    assert_eq!(transport.receive().expect("wrong peer"), None);
    assert_eq!(transport.receive().expect("wrong port"), None);
    assert_eq!(
        transport.stats(),
        TransportStats {
            received_datagrams: 1,
            received_bytes: 8,
            wrong_peer_drops: 1,
            wrong_port_drops: 1,
            kernel_drops: 0,
            ..TransportStats::default()
        }
    );
}

#[test]
fn receive_kind_preserves_each_opposite_stream_fragment() {
    let drops = Arc::new(AtomicUsize::new(0));
    let mut transport = transport(
        [
            captured(frame(VIDEO_PORT, VIDEO_PORT, b"old-video")),
            captured(frame(VIDEO_PORT, VIDEO_PORT, b"new-video")),
            Ok(None),
        ],
        0,
        drops,
    );

    assert_eq!(
        transport.receive_kind(MediaKind::Audio).expect("poll"),
        None
    );
    let video = transport
        .receive_kind(MediaKind::Video)
        .expect("pending video")
        .expect("latest video");
    assert_eq!(video.payload, b"old-video");
    assert!(transport.receive_kind(MediaKind::Audio).unwrap().is_none());
    assert_eq!(
        transport
            .receive_kind(MediaKind::Video)
            .unwrap()
            .unwrap()
            .payload,
        b"new-video"
    );
    assert_eq!(transport.stats().queue_replacement_drops, 0);
}

#[test]
fn shutdown_drops_capture_plane_once() {
    let drops = Arc::new(AtomicUsize::new(0));
    let snapshot_calls = Arc::new(AtomicUsize::new(0));
    let mut transport =
        transport_with_kernel_result([], 4, None, Arc::clone(&snapshot_calls), Arc::clone(&drops));

    transport.shutdown().expect("first shutdown");
    transport.shutdown().expect("second shutdown");

    assert_eq!(transport.stats().kernel_drops, 4);
    assert_eq!(snapshot_calls.load(Ordering::SeqCst), 1);
    assert_eq!(drops.load(Ordering::SeqCst), 1);
}

#[test]
fn shutdown_surfaces_final_kernel_snapshot_error_after_closing_plane() {
    let drops = Arc::new(AtomicUsize::new(0));
    let snapshot_calls = Arc::new(AtomicUsize::new(0));
    let mut transport = transport_with_kernel_result(
        [],
        0,
        Some("final stats unavailable".into()),
        Arc::clone(&snapshot_calls),
        Arc::clone(&drops),
    );

    let error = transport.shutdown().expect_err("final stats failure");

    assert!(error.to_string().contains("final stats unavailable"));
    assert_eq!(snapshot_calls.load(Ordering::SeqCst), 1);
    assert_eq!(drops.load(Ordering::SeqCst), 1);
    transport
        .shutdown()
        .expect("closed transport is idempotent");
}

#[test]
fn opposite_stream_flood_yields_after_one_quantum() {
    let mut frames: Vec<_> = (0..65)
        .map(|_| captured(frame(VIDEO_PORT, VIDEO_PORT, b"video")))
        .collect();
    frames.push(captured(frame(AUDIO_PORT, AUDIO_PORT, b"audio")));
    let mut transport = transport(frames, 0, Arc::new(AtomicUsize::new(0)));
    for index in 1..=65 {
        assert_eq!(transport.receive_kind(MediaKind::Audio).unwrap(), None);
        assert_eq!(transport.stats().received_datagrams, index);
        assert_eq!(
            transport
                .receive_kind(MediaKind::Video)
                .unwrap()
                .unwrap()
                .payload,
            b"video"
        );
    }
    assert_eq!(
        transport
            .receive_kind(MediaKind::Audio)
            .unwrap()
            .unwrap()
            .payload,
        b"audio"
    );
    assert_eq!(transport.stats().queue_replacement_drops, 0);
}
