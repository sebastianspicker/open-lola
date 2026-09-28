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
