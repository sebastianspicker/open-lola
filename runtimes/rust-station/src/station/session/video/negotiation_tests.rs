use super::*;

fn jpeg_frame(width: u32, height: u32, format: &str, sequence: u32) -> VideoFrame {
    let channels = if format == "RGB24" { 3 } else { 1 };
    let pixels = vec![127; (width * height * channels) as usize];
    let payload = if format == "RGB24" {
        crate::video::encode_frame_jpeg(&pixels, width, height, format, 90).unwrap()
    } else {
        let mut output = std::io::Cursor::new(Vec::new());
        image::codecs::jpeg::JpegEncoder::new_with_quality(&mut output, 90)
            .encode(&pixels, width, height, image::ExtendedColorType::L8)
            .unwrap();
        output.into_inner()
    };
    VideoFrame {
        sequence,
        payload,
        compressed: true,
    }
}

#[test]
fn compressed_frames_require_negotiated_geometry_and_channels() {
    assert!(validate_received_video(jpeg_frame(1, 1, "RGB24", 1), 2, 2, 24).is_err());
    assert!(validate_received_video(jpeg_frame(2, 2, "Mono8", 2), 2, 2, 24).is_err());
    assert!(validate_received_video(jpeg_frame(2, 2, "RGB24", 3), 2, 2, 8).is_err());
    assert!(validate_received_video(jpeg_frame(2, 2, "RGB24", 4), 2, 2, 24).is_ok());
    assert!(validate_received_video(jpeg_frame(2, 2, "Mono8", 5), 2, 2, 8).is_ok());
}

#[test]
fn malformed_compressed_geometry_drops_before_valid_frame_recovers() {
    let options = SessionOptions::demo();
    let mut result = SessionResult::default();
    let mut recorder = None;
    let mut monitor = NetworkMonitor::new();
    let mut queue = VideoReceiveQueue::new(1, 0);
    present_received_video(
        jpeg_frame(1, 1, "RGB24", 1),
        2,
        2,
        24,
        &options,
        &mut result,
        &mut recorder,
        &mut monitor,
        &mut queue,
    )
    .unwrap();
    assert_eq!(result.video_malformed_drops, 1);
    assert_eq!(result.video_frames_received, 0);

    present_received_video(
        jpeg_frame(2, 2, "RGB24", 2),
        2,
        2,
        24,
        &options,
        &mut result,
        &mut recorder,
        &mut monitor,
        &mut queue,
    )
    .unwrap();
    assert_eq!(result.video_malformed_drops, 1);
    assert_eq!(result.video_frames_received, 1);
    assert!(result.jpeg_decoded_ok);
}

#[test]
fn raw_presentation_format_follows_negotiated_byte_count() {
    assert_eq!(raw_video_format(8), "Mono8");
    assert_eq!(raw_video_format(24), "RGB24");
}

#[test]
fn older_video_sequence_is_dropped_before_presentation() {
    let options = SessionOptions::demo();
    let mut result = SessionResult::default();
    let mut recorder = None;
    let mut monitor = NetworkMonitor::new();
    let mut queue = VideoReceiveQueue::new(1, 0);
    for sequence in [5, 4, 6] {
        let frame = VideoFrame {
            sequence,
            payload: vec![0; 12],
            compressed: false,
        };
        present_received_video(
            frame,
            2,
            2,
            24,
            &options,
            &mut result,
            &mut recorder,
            &mut monitor,
            &mut queue,
        )
        .unwrap();
    }
    assert_eq!(result.video_out_of_order_drops, 1);
    assert_eq!(result.video_frames_received, 2);
    assert_eq!(result.video_malformed_drops, 0);
}

#[test]
fn malformed_video_does_not_poison_the_validated_sequence_clock() {
    for compressed in [false, true] {
        let options = SessionOptions::demo();
        let mut result = SessionResult::default();
        let mut recorder = None;
        let mut monitor = NetworkMonitor::new();
        let mut queue = VideoReceiveQueue::new(1, 0);
        for (sequence, valid) in [(5, true), (1000, false), (6, true)] {
            let frame = if compressed {
                jpeg_frame(if valid { 2 } else { 1 }, 2, "RGB24", sequence)
            } else {
                VideoFrame {
                    sequence,
                    payload: vec![0; if valid { 12 } else { 3 }],
                    compressed,
                }
            };
            present_received_video(
                frame,
                2,
                2,
                24,
                &options,
                &mut result,
                &mut recorder,
                &mut monitor,
                &mut queue,
            )
            .unwrap();
        }
        assert_eq!(result.video_frames_received, 2);
        assert_eq!(result.video_malformed_drops, 1);
        assert_eq!(result.video_out_of_order_drops, 0);
    }
}
