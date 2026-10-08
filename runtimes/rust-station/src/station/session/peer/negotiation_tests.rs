use super::*;
use crate::protocol::{parse_video_frame, FrameReassembler, MediaSettings};
use crate::station::session::backends::SessionCameraBackend;
use crate::station::session::scheduler::VideoTxCursor;
use crate::station::session::video::prepare_video_capture;
use crate::video::BayerPattern;

fn capabilities(media: &MediaSettings) -> std::collections::BTreeMap<String, Value> {
    [
        ("SR", media.sample_rate),
        ("BPS", media.bits_per_sample),
        ("CHNLS", media.channels),
        ("FPS", media.fps),
        ("BPP", media.bits_per_pixel),
        ("X", media.width),
        ("Y", media.height),
        ("COMP", media.compression),
        ("BAYER", media.bayer),
    ]
    .into_iter()
    .map(|(key, value)| (key.into(), serde_json::json!(value)))
    .collect()
}

fn requested(settings: &StationSettings, width: u32, height: u32) -> MediaSettings {
    MediaSettings {
        sample_rate: settings.audio.sample_rate,
        bits_per_sample: u32::from(settings.audio.bits_per_sample),
        channels: u32::from(settings.audio.channels),
        fps: settings.video.fps,
        bits_per_pixel: 24,
        width,
        height,
        compression: 0,
        bayer: settings.video.bayer,
    }
}

#[test]
fn listener_accepts_asymmetric_geometry_it_scales_to() {
    let mut settings = crate::config::default_settings();
    settings.video.width = 640;
    settings.video.height = 480;
    settings.video.bpp = 8;
    settings.video.bayer = 1;
    let options = SessionOptions::demo();
    let mut media = requested(&settings, 320, 180);
    media.bayer = 0;
    assert_eq!(
        peer_rejection_reason(&settings, &options, &capabilities(&media)),
        None
    );
    let ack = peer_ack_media(&capabilities(&media));
    assert_eq!((ack.width, ack.height), (320, 180));
    assert_eq!(
        u64::from(ack.width) * u64::from(ack.height) * u64::from(ack.bits_per_pixel / 8),
        320 * 180 * 3
    );
    assert_eq!((settings.video.width, settings.video.height), (640, 480));

    let mode = SessionCameraBackend::synthetic_mode(&settings, "asymmetric-test".into());
    let mut camera = SessionCameraBackend::open(&settings, &options, &mode).unwrap();
    let prepared = prepare_video_capture(
        &mut camera,
        512,
        ack.width,
        ack.height,
        settings.video.width,
        settings.video.height,
        settings.video.jpeg_quality,
        settings.video.bayer,
        &options,
        None,
        BayerPattern::Bggr,
        false,
        7,
        0,
        0,
    )
    .unwrap();
    let mut cursor = VideoTxCursor::new(prepared.transport);
    let mut reassembler = FrameReassembler::strict_video();
    let mut reconstructed = None;
    while let Some(datagram) = cursor.next() {
        if let Some(frame) = reassembler.feed(datagram).unwrap() {
            reconstructed = Some(frame);
        }
        cursor.sent_one();
    }
    let frame = parse_video_frame(&reconstructed.unwrap(), false).unwrap();
    assert_eq!(frame.payload.len(), (ack.width * ack.height * 3) as usize);
    camera.stop().unwrap();
}

#[test]
fn listener_rejects_video_rates_and_formats_it_cannot_emit() {
    let mut settings = crate::config::default_settings();
    settings.video.bpp = 8;
    settings.video.bayer = 0;
    let mut options = SessionOptions::demo();
    options.auto_bayer = false;
    let mut media = requested(&settings, 320, 180);
    media.bits_per_pixel = 8;
    media.fps += 1;
    assert_eq!(
        peer_rejection_reason(&settings, &options, &capabilities(&media)),
        Some("video frame rate mismatch")
    );
    media.fps = settings.video.fps;
    media.bits_per_pixel = 24;
    assert_eq!(
        peer_rejection_reason(&settings, &options, &capabilities(&media)),
        Some("video pixel format mismatch")
    );
}

#[test]
fn listener_accounts_for_auto_bayer_output() {
    let mut settings = crate::config::default_settings();
    settings.video.bpp = 8;
    settings.video.bayer = 1;
    let mut options = SessionOptions::demo();
    options.auto_bayer = true;
    let mut media = requested(&settings, 320, 180);
    media.bayer = 0;
    assert_eq!(
        super::super::video::negotiated_output_format(&settings, &options, false),
        (24, 0)
    );
    assert_eq!(
        peer_rejection_reason(&settings, &options, &capabilities(&media)),
        None
    );
    media.bayer = 1;
    assert_eq!(
        peer_rejection_reason(&settings, &options, &capabilities(&media)),
        Some("video Bayer format mismatch")
    );
}

#[test]
fn listener_requires_rgb_tuple_for_compressed_output() {
    let mut settings = crate::config::default_settings();
    settings.video.bpp = 8;
    settings.video.bayer = 1;
    let mut options = SessionOptions::demo();
    options.auto_bayer = false;
    let mut media = requested(&settings, 320, 180);
    media.compression = 1;
    media.bayer = 0;
    assert_eq!(
        peer_rejection_reason(&settings, &options, &capabilities(&media)),
        None
    );
    media.bits_per_pixel = 8;
    assert_eq!(
        peer_rejection_reason(&settings, &options, &capabilities(&media)),
        Some("video pixel format mismatch")
    );
}

#[test]
fn listener_acknowledges_every_repeated_status_check_before_quickconn() {
    use crate::config::default_settings;
    use crate::protocol::{decode_mesg, MESG_CHECKLOLASTATUS, MESG_QUICKCONN};
    use std::net::UdpSocket;
    use std::thread;
    use std::time::Duration;

    let mut settings = default_settings();
    settings.network.local_ip = "127.0.0.1".into();
    settings.network.remote_ip = "127.0.0.1".into();
    let mut options = SessionOptions::demo();
    options.peer_mode = "loopback".into();
    options.audio_only = true;
    let control = Udp::bind("127.0.0.1", 0).unwrap();
    let listener = control.local_addr().unwrap();
    let initiator = UdpSocket::bind("127.0.0.1:0").unwrap();
    initiator
        .set_read_timeout(Some(Duration::from_secs(5)))
        .unwrap();
    let status = build_session_control(
        &settings,
        MESG_CHECKLOLASTATUS,
        &settings.network.remote_ip,
        &settings.network.local_ip,
        "",
        None,
    )
    .unwrap();
    let quickconn = build_session_control(
        &settings,
        MESG_QUICKCONN,
        &settings.network.remote_ip,
        &settings.network.local_ip,
        "",
        Some(&super::super::control::protocol_media_settings(&settings)),
    )
    .unwrap();
    let initiator_thread = thread::spawn(move || {
        let mut buffer = [0; 2048];
        let mut replies = Vec::new();
        // Two status checks, as an initiator whose first acknowledgement was
        // lost would send, then the connection request.
        for _ in 0..2 {
            initiator.send_to(&status, listener).unwrap();
            let (size, _) = initiator.recv_from(&mut buffer).unwrap();
            replies.push(decode_mesg(&buffer[..size]).unwrap().name);
        }
        initiator.send_to(&quickconn, listener).unwrap();
        let (size, _) = initiator.recv_from(&mut buffer).unwrap();
        replies.push(decode_mesg(&buffer[..size]).unwrap().name);
        replies
    });
    let shared = Arc::new(Mutex::new(SessionResult::default()));
    let negotiation = negotiate_peer(
        &settings,
        &options,
        &shared,
        &control,
        Instant::now() + Duration::from_secs(5),
    )
    .unwrap()
    .expect("accepted");
    assert_eq!(
        negotiation.ack_media.sample_rate,
        settings.audio.sample_rate
    );
    assert_eq!(
        initiator_thread.join().unwrap(),
        vec![
            "/MESG_CHECKLOLASTATUS_ACK",
            "/MESG_CHECKLOLASTATUS_ACK",
            "/MESG_QUICKCONN_ACK"
        ]
    );
    let result = lock_unpoison(&shared);
    assert_eq!(
        result
            .messages_sent
            .iter()
            .filter(|name| name.as_str() == "/MESG_CHECKLOLASTATUS_ACK")
            .count(),
        2
    );
}

#[test]
fn persistent_listener_waits_beyond_the_finite_timeout() {
    let mut options = SessionOptions::demo();
    let finite = listener_negotiation_deadline(&options, Duration::from_secs(5));
    assert!(finite <= Instant::now() + Duration::from_secs(5));
    options.persistent = true;
    let persistent = listener_negotiation_deadline(&options, Duration::from_secs(5));
    assert!(persistent > Instant::now() + Duration::from_secs(86_400));
}

fn loopback_settings() -> StationSettings {
    let mut settings = crate::config::default_settings();
    settings.network.local_ip = "127.0.0.1".into();
    settings.network.remote_ip = "127.0.0.1".into();
    settings
}

fn quickconn_datagram(settings: &StationSettings, media: &MediaSettings) -> Vec<u8> {
    build_session_control(
        settings,
        crate::protocol::MESG_QUICKCONN,
        &settings.network.remote_ip,
        &settings.network.local_ip,
        "",
        Some(media),
    )
    .unwrap()
}

fn zero_video(media: &mut MediaSettings) {
    media.fps = 0;
    media.bits_per_pixel = 0;
    media.width = 0;
    media.height = 0;
}

/// Runs `negotiate_peer` against a one-shot initiator that sends `quickconn`
/// and returns the listener outcome plus the first reply it received.
fn negotiate_against(
    settings: &StationSettings,
    options: &SessionOptions,
    quickconn: Vec<u8>,
) -> (
    Result<Option<PeerNegotiation>, SessionError>,
    crate::protocol::Mesg,
) {
    use std::net::UdpSocket;
    let control = Udp::bind("127.0.0.1", 0).unwrap();
    let listener = control.local_addr().unwrap();
    let initiator = UdpSocket::bind("127.0.0.1:0").unwrap();
    initiator
        .set_read_timeout(Some(Duration::from_secs(5)))
        .unwrap();
    let thread = std::thread::spawn(move || {
        let mut buffer = [0; 2048];
        initiator.send_to(&quickconn, listener).unwrap();
        let (size, _) = initiator.recv_from(&mut buffer).unwrap();
        decode_mesg(&buffer[..size]).unwrap()
    });
    let shared = Arc::new(Mutex::new(SessionResult::default()));
    let outcome = negotiate_peer(
        settings,
        options,
        &shared,
        &control,
        Instant::now() + Duration::from_secs(5),
    );
    (outcome, thread.join().unwrap())
}

#[test]
fn invalid_quickconn_media_is_rejected_instead_of_failing_the_listener() {
    let settings = loopback_settings();
    let mut options = SessionOptions::demo();
    options.peer_mode = "loopback".into();
    options.audio_only = false;
    options.stream_tx_video = true;
    let mut media = super::super::control::protocol_media_settings(&settings);
    zero_video(&mut media);
    let datagram = quickconn_datagram(&settings, &media);
    let (outcome, reply) = negotiate_against(&settings, &options, datagram);
    assert!(outcome.unwrap().is_none());
    assert_eq!(reply.name, "/MESG_REJECT");
    let reason = reply.fields.get("TXT").cloned().unwrap_or_default();
    assert!(
        crate::protocol::unescape_txt_field(&reason).starts_with("invalid media settings: "),
        "{reason}"
    );
}

#[test]
fn audio_only_listener_tolerates_zeroed_video_fields() {
    let settings = loopback_settings();
    let mut options = SessionOptions::demo();
    options.peer_mode = "loopback".into();
    options.audio_only = true;
    let mut media = super::super::control::protocol_media_settings(&settings);
    zero_video(&mut media);
    let datagram = quickconn_datagram(&settings, &media);
    let (outcome, reply) = negotiate_against(&settings, &options, datagram);
    let negotiation = outcome.unwrap().expect("accepted");
    assert_eq!(reply.name, "/MESG_QUICKCONN_ACK");
    assert_eq!(
        negotiation.ack_media.sample_rate,
        settings.audio.sample_rate
    );
    assert_eq!(
        (negotiation.ack_media.fps, negotiation.ack_media.width),
        (0, 0)
    );

    // Broken audio fields are still refused with a REJECT.
    media.sample_rate = 0;
    let datagram = quickconn_datagram(&settings, &media);
    let (outcome, reply) = negotiate_against(&settings, &options, datagram);
    assert!(outcome.unwrap().is_none());
    assert_eq!(reply.name, "/MESG_REJECT");
}

#[test]
fn repeated_quickconn_during_streaming_resends_the_ack_once() {
    use std::net::UdpSocket;
    let settings = loopback_settings();
    let options = SessionOptions::demo();
    let media = super::super::control::protocol_media_settings(&settings);
    let quickconn = quickconn_datagram(&settings, &media);
    let initiator = UdpSocket::bind("127.0.0.1:0").unwrap();
    initiator
        .set_read_timeout(Some(Duration::from_millis(300)))
        .unwrap();
    let peer = initiator.local_addr().unwrap();
    let socket = Udp::bind("127.0.0.1", 0).unwrap();
    let ack = QuickconnAckCache::new(b"cached-ack".to_vec());
    let shared = Arc::new(Mutex::new(SessionResult::default()));
    let mut queued =
        std::collections::VecDeque::from(vec![(quickconn.clone(), peer), (quickconn, peer)]);
    let disconnected = pump_peer_control_from(
        || Ok(queued.pop_front()),
        &socket,
        &ack,
        peer,
        &settings,
        &options,
        &shared,
    )
    .unwrap();
    assert!(!disconnected);
    let mut buffer = [0; 64];
    let (size, _) = initiator.recv_from(&mut buffer).unwrap();
    assert_eq!(&buffer[..size], b"cached-ack");
    assert!(initiator.recv_from(&mut buffer).is_err(), "second ACK sent");
    assert_eq!(
        lock_unpoison(&shared)
            .messages_sent
            .iter()
            .filter(|name| name.as_str() == "/MESG_QUICKCONN_ACK")
            .count(),
        1
    );
}
