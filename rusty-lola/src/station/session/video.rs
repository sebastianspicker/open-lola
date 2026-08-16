use super::backends::SessionCameraBackend;
use super::control::pump_control;
use super::media::{recv_media, ReceivePrefillQueue, SessionMediaTransport};
use super::scheduler::PreparedVideoFrame;
use super::{SessionOptions, SessionResult, SessionRuntimeControl};
use crate::config::{ColorSettings, StationSettings};
use crate::net::{MediaKind, Udp};
use crate::protocol::{build_video_payloads, parse_video_frame, FrameReassembler, VideoFrame};
use crate::station::av_productivity::centered_crop_or_scale;
use crate::station::bounded::push_bounded;
use crate::station::dual_recorder::DualStreamRecorder;
use crate::station::monitor::NetworkMonitor;
use crate::station::SessionError;
use crate::video::{
    apply_colors, decode_jpeg, demosaic_mono8, encode_frame_jpeg, generate_smpte_bars, resize_nn,
    BayerPattern, DecodedImage,
};
use std::fs;
use std::net::SocketAddr;

/// A fully-prepared capture whose pixels remain available to the session
/// thread for preview, recording, and accounting. Camera ownership and all
/// expensive image work stay with the capture worker.
#[derive(Debug)]
pub(super) struct PreparedCapture {
    pub(super) transport: PreparedVideoFrame,
    pixels: Vec<u8>,
    width: u32,
    height: u32,
    format: String,
    bayer_applied: bool,
    color_applied: bool,
    test_signal: bool,
    frame_index: u32,
}

/// A received frame whose payload was checked before it can affect session state.
pub(super) enum ReceivedVideoFrame {
    Raw(VideoFrame),
    Jpeg {
        frame: VideoFrame,
        decoded: DecodedImage,
    },
}

impl ReceivedVideoFrame {
    fn sequence(&self) -> u32 {
        match self {
            Self::Raw(frame) | Self::Jpeg { frame, .. } => frame.sequence,
        }
    }
}

#[allow(clippy::too_many_arguments)]
pub(super) fn prepare_video_capture(
    camera: &mut SessionCameraBackend,
    packet_size: usize,
    stream_w: u32,
    stream_h: u32,
    full_w: u32,
    full_h: u32,
    jpeg_quality: u8,
    bayer_flag: u32,
    options: &SessionOptions,
    colors: Option<&ColorSettings>,
    bayer_pat: BayerPattern,
    use_jpeg: bool,
    sid: u32,
    frame_i: u32,
    t0: u64,
) -> Result<PreparedCapture, SessionError> {
    let mut bayer_applied = false;
    let mut color_applied = false;
    let mut test_signal = false;
    let (scaled, stream_fmt) = if options.test_signal_active() {
        let use_mono = bayer_flag != 0 || options.audio_only;
        let bars = generate_smpte_bars(stream_w, stream_h, use_mono)
            .map_err(|e| SessionError::VideoBackend(e.to_string()))?;
        test_signal = true;
        let _ = (camera, full_w, full_h, bayer_pat, colors);
        (bars, if use_mono { "Mono8" } else { "RGB24" }.to_string())
    } else {
        let (raw, pix_fmt) = camera.grab()?;
        let bpp = if pix_fmt == "RGB24" { 3 } else { 1 };
        let mut scaled = if stream_w != full_w || stream_h != full_h {
            if options.use_centered_scale {
                centered_crop_or_scale(&raw, full_w, full_h, stream_w, stream_h, &pix_fmt)
                    .unwrap_or_else(|_| resize_nn(&raw, full_w, full_h, stream_w, stream_h, bpp))
            } else {
                resize_nn(&raw, full_w, full_h, stream_w, stream_h, bpp)
            }
        } else {
            raw
        };
        if options.auto_bayer && pix_fmt == "Mono8" && bayer_flag != 0 {
            if let Ok(rgb) = demosaic_mono8(&scaled, stream_w, stream_h, bayer_pat) {
                scaled = rgb;
                bayer_applied = true;
            }
        }
        let format = if bayer_applied && scaled.len() == (stream_w * stream_h * 3) as usize {
            "RGB24".to_string()
        } else {
            pix_fmt
        };
        if let Some(colors) = colors {
            if let Ok(out) = apply_colors(&scaled, stream_w, stream_h, &format, colors) {
                scaled = out;
                color_applied = true;
            }
        }
        (scaled, format)
    };
    let _ = (sid, t0);
    let frame = encode_video_frame(
        &scaled,
        stream_w,
        stream_h,
        &stream_fmt,
        jpeg_quality,
        use_jpeg,
        frame_i + 1,
    )?;
    Ok(PreparedCapture {
        transport: PreparedVideoFrame::new(
            u64::from(frame.sequence),
            build_video_payloads(frame.sequence, &frame.payload, None, packet_size),
        ),
        pixels: scaled,
        width: stream_w,
        height: stream_h,
        format: stream_fmt,
        bayer_applied,
        color_applied,
        test_signal,
        frame_index: frame_i,
    })
}

pub(super) fn consume_prepared_capture(
    capture: PreparedCapture,
    options: &SessionOptions,
    result: &mut SessionResult,
    dual: &mut Option<DualStreamRecorder>,
    preview_paths: &mut Vec<String>,
) -> PreparedVideoFrame {
    if capture.test_signal {
        result.test_signal_applied = true;
        result.test_signal_mode = options.test_signal_mode.clone();
    }
    result.bayer_applied |= capture.bayer_applied;
    result.color_applied |= capture.color_applied;
    if let Some(control) = options.runtime_control.as_ref() {
        control.publish_video(
            capture.width,
            capture.height,
            &capture.pixels,
            &capture.format,
        );
    }
    if let Some(dir) = &options.preview_dir {
        if capture.frame_index == 0 || options.preview_all_frames {
            let path = dir.join(format!("preview_{:04}.raw", capture.frame_index));
            if fs::write(&path, &capture.pixels).is_ok() {
                push_bounded(preview_paths, path.display().to_string());
            }
        }
    }
    if let Some(recorder) = dual.as_mut() {
        recorder.write_video_frame("local", &capture.pixels, capture.width, capture.height);
    }
    capture.transport
}

#[allow(clippy::too_many_arguments)]
pub(super) fn receive_video_datagram_step(
    transport: &mut SessionMediaTransport,
    peer: SocketAddr,
    reassembler: &mut FrameReassembler,
    stream_w: u32,
    stream_h: u32,
    bayer_flag: u32,
    options: &SessionOptions,
    result: &mut SessionResult,
    dual: &mut Option<DualStreamRecorder>,
    monitor: &mut NetworkMonitor,
    compressed: bool,
    raw_bpp: u32,
    queue: &mut ReceivePrefillQueue<ReceivedVideoFrame>,
) -> Result<(), SessionError> {
    let Some(datagram) = transport.receive_kind(MediaKind::Video)? else {
        return Ok(());
    };
    if datagram.peer != peer {
        return Ok(());
    }
    let Some(frame) = reassembler
        .feed(&datagram.payload)
        .map_err(|error| SessionError::Protocol(error.to_string()))?
    else {
        return Ok(());
    };
    let frame = parse_video_frame(&frame, compressed)
        .map_err(|error| SessionError::Protocol(error.to_string()))?;
    present_received_video(
        frame, stream_w, stream_h, raw_bpp, bayer_flag, options, result, dual, monitor, queue,
    )
}

#[allow(clippy::too_many_arguments)]
fn present_received_video(
    frame: VideoFrame,
    stream_w: u32,
    stream_h: u32,
    raw_bpp: u32,
    bayer_flag: u32,
    options: &SessionOptions,
    result: &mut SessionResult,
    dual: &mut Option<DualStreamRecorder>,
    monitor: &mut NetworkMonitor,
    queue: &mut ReceivePrefillQueue<ReceivedVideoFrame>,
) -> Result<(), SessionError> {
    let frame = match validate_received_video(frame, stream_w, stream_h, raw_bpp) {
        Ok(frame) => frame,
        Err(()) => {
            result.video_malformed_drops += 1;
            monitor.note_drop(1);
            return Ok(());
        }
    };
    result.video_frames_received += 1;
    result.media_frames_received += 1;
    monitor.note_recv(MediaKind::Video, Some(frame.sequence()));
    let (display, replaced) = queue.push(frame);
    if replaced {
        monitor.note_drop(1);
    }
    if let Some(frame) = display {
        match frame {
            ReceivedVideoFrame::Jpeg { frame, decoded } => {
                result.jpeg_decoded_ok = true;
                if let Some(control) = options.runtime_control.as_ref() {
                    control.publish_video(
                        decoded.width,
                        decoded.height,
                        &decoded.pixels,
                        &decoded.mode,
                    );
                }
                if let Some(recorder) = dual.as_mut() {
                    recorder.write_video_frame("remote", &frame.payload, stream_w, stream_h);
                }
            }
            ReceivedVideoFrame::Raw(frame) => {
                if let Some(control) = options.runtime_control.as_ref() {
                    let format = if options.auto_bayer && bayer_flag != 0 {
                        "Mono8"
                    } else if raw_bpp == 24 {
                        "RGB24"
                    } else {
                        "Mono8"
                    };
                    control.publish_video(stream_w, stream_h, &frame.payload, format);
                }
                if let Some(recorder) = dual.as_mut() {
                    recorder.write_video_frame("remote", &frame.payload, stream_w, stream_h);
                }
            }
        }
    }
    Ok(())
}

fn validate_received_video(
    frame: VideoFrame,
    width: u32,
    height: u32,
    raw_bpp: u32,
) -> Result<ReceivedVideoFrame, ()> {
    if frame.compressed {
        let decoded = decode_jpeg(&frame.payload).map_err(|_| ())?;
        let channels = if decoded.mode == "RGB" { 3 } else { 1 };
        let expected = decoded
            .width
            .checked_mul(decoded.height)
            .and_then(|pixels| pixels.checked_mul(channels))
            .and_then(|bytes| usize::try_from(bytes).ok())
            .ok_or(())?;
        if decoded.width == 0 || decoded.height == 0 || decoded.pixels.len() != expected {
            return Err(());
        }
        return Ok(ReceivedVideoFrame::Jpeg { frame, decoded });
    }
    if raw_bpp == 0 || !raw_bpp.is_multiple_of(8) {
        return Err(());
    }
    let expected = width
        .checked_mul(height)
        .and_then(|pixels| pixels.checked_mul(raw_bpp / 8))
        .and_then(|bytes| usize::try_from(bytes).ok())
        .ok_or(())?;
    (frame.payload.len() == expected)
        .then_some(ReceivedVideoFrame::Raw(frame))
        .ok_or(())
}

fn encode_video_frame(
    pixels: &[u8],
    width: u32,
    height: u32,
    format: &str,
    jpeg_quality: u8,
    compressed: bool,
    sequence: u32,
) -> Result<VideoFrame, SessionError> {
    let payload = if compressed {
        encode_frame_jpeg(pixels, width, height, format, jpeg_quality)
            .map_err(|error| SessionError::VideoBackend(error.to_string()))?
    } else {
        pixels.to_vec()
    };
    let frame = VideoFrame {
        sequence,
        payload,
        compressed,
    };
    frame
        .serialize()
        .map_err(|error| SessionError::Protocol(error.to_string()))?;
    Ok(frame)
}

#[allow(clippy::too_many_arguments)]
pub(super) fn send_recv_video_frame(
    camera: Option<&mut SessionCameraBackend>,
    media_transport: &mut SessionMediaTransport,
    peer_video_addr: SocketAddr,
    v_re: &mut FrameReassembler,
    packet_size: usize,
    stream_w: u32,
    stream_h: u32,
    raw_bpp: u32,
    full_w: u32,
    full_h: u32,
    jpeg_quality: u8,
    bayer_flag: u32,
    options: &SessionOptions,
    colors: Option<&ColorSettings>,
    bayer_pat: BayerPattern,
    use_jpeg: bool,
    sid: u32,
    frame_i: u32,
    t0: u64,
    result: &mut SessionResult,
    dual: &mut Option<DualStreamRecorder>,
    preview_paths: &mut Vec<String>,
    monitor: &mut NetworkMonitor,
    control_socket: &Udp,
    control_peer: SocketAddr,
    control_settings: &StationSettings,
    receive_queue: &mut ReceivePrefillQueue<ReceivedVideoFrame>,
) -> Result<(), SessionError> {
    if options.stream_tx_video && !options.audio_only {
        let camera = camera.ok_or_else(|| {
            SessionError::VideoBackend("video transmission started without a camera backend".into())
        })?;
        let capture = prepare_video_capture(
            camera,
            packet_size,
            stream_w,
            stream_h,
            full_w,
            full_h,
            jpeg_quality,
            bayer_flag,
            options,
            colors,
            bayer_pat,
            use_jpeg,
            sid,
            frame_i,
            t0,
        )?;
        let prepared = consume_prepared_capture(capture, options, result, dual, preview_paths);
        for datagram in prepared.datagrams {
            media_transport.send(MediaKind::Video, &datagram, peer_video_addr)?;
        }
        result.video_frames_sent += 1;
        result.media_frames_sent += 1;
        monitor.note_send(MediaKind::Video);
    }
    if options.stream_rx_video {
        let received = {
            let mut control_pump = || {
                pump_control(
                    control_socket,
                    control_peer,
                    control_settings,
                    result,
                    options.runtime_control.as_ref(),
                )
            };
            recv_media(
                media_transport,
                v_re,
                Some(peer_video_addr),
                false,
                options.incomplete_frame_threshold_pct,
                options.runtime_control.as_ref(),
                Some(&mut control_pump),
            )
        };
        let (echo, _) = match received {
            Ok(received) => received,
            Err(SessionError::PeerDisconnect(_))
                if result.peer_disconnected()
                    || options
                        .runtime_control
                        .as_ref()
                        .is_some_and(SessionRuntimeControl::is_cancelled) =>
            {
                return Ok(());
            }
            Err(error) => return Err(error),
        };
        let frame = parse_video_frame(&echo, use_jpeg)
            .map_err(|error| SessionError::Protocol(error.to_string()))?;
        present_received_video(
            frame,
            stream_w,
            stream_h,
            raw_bpp,
            bayer_flag,
            options,
            result,
            dual,
            monitor,
            receive_queue,
        )?;
    }
    if let Some(control) = options.runtime_control.as_ref() {
        control.set_activity(result);
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::{present_received_video, ReceivedVideoFrame};
    use crate::protocol::VideoFrame;
    use crate::station::dual_recorder::DualStreamRecorder;
    use crate::station::monitor::NetworkMonitor;
    use crate::station::session::media::ReceivePrefillQueue;
    use crate::station::session::{SessionOptions, SessionResult};
    use crate::video::encode_jpeg;

    fn present(
        frame: VideoFrame,
        raw_bpp: u32,
        result: &mut SessionResult,
        monitor: &mut NetworkMonitor,
        queue: &mut ReceivePrefillQueue<ReceivedVideoFrame>,
    ) {
        present_received_video(
            frame,
            2,
            1,
            raw_bpp,
            0,
            &SessionOptions::demo(),
            result,
            &mut Option::<DualStreamRecorder>::None,
            monitor,
            queue,
        )
        .expect("malformed video is classified as a dropped frame");
    }

    #[test]
    fn malformed_raw_frame_does_not_advance_receive_success_before_valid_frame() {
        let mut result = SessionResult::default();
        let mut monitor = NetworkMonitor::new();
        let mut queue = ReceivePrefillQueue::new(1, 0);

        present(
            VideoFrame {
                sequence: 1,
                payload: vec![0; 3],
                compressed: false,
            },
            16,
            &mut result,
            &mut monitor,
            &mut queue,
        );
        assert_eq!(result.video_frames_received, 0);
        assert_eq!(result.media_frames_received, 0);
        assert_eq!(result.video_malformed_drops, 1);
        assert_eq!(monitor.video_received, 0);
        assert_eq!(monitor.drops, 1);

        present(
            VideoFrame {
                sequence: 2,
                payload: vec![0; 4],
                compressed: false,
            },
            16,
            &mut result,
            &mut monitor,
            &mut queue,
        );
        assert_eq!(result.video_frames_received, 1);
        assert_eq!(result.media_frames_received, 1);
        assert_eq!(result.video_malformed_drops, 1);
    }

    #[test]
    fn malformed_jpeg_does_not_advance_receive_success_before_valid_frame() {
        let mut result = SessionResult::default();
        let mut monitor = NetworkMonitor::new();
        let mut queue = ReceivePrefillQueue::new(1, 0);

        present(
            VideoFrame {
                sequence: 1,
                payload: b"not a jpeg".to_vec(),
                compressed: true,
            },
            0,
            &mut result,
            &mut monitor,
            &mut queue,
        );
        assert_eq!(result.video_frames_received, 0);
        assert!(!result.jpeg_decoded_ok);
        assert_eq!(result.video_malformed_drops, 1);

        let payload = encode_jpeg(&[0, 127, 255], 1, 1, "RGB", 80).expect("test JPEG");
        present(
            VideoFrame {
                sequence: 2,
                payload,
                compressed: true,
            },
            0,
            &mut result,
            &mut monitor,
            &mut queue,
        );
        assert_eq!(result.video_frames_received, 1);
        assert!(result.jpeg_decoded_ok);
        assert_eq!(result.video_malformed_drops, 1);
    }
}
