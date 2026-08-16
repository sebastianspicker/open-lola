//! Deadline-first interleaved stream execution.

use super::audio::send_recv_audio_frame;
use super::backends::SessionAudioBackend;
use super::capture::CaptureWorker;
use super::control::{pump_control, send_queued_controls};
use super::media::{ReceivePrefillQueue, SessionMediaTransport, VideoSendDisposition};
use super::scheduler::{DeadlineScheduler, PreparedVideoMailbox, VideoTxCursor};
use super::video::{consume_prepared_capture, receive_video_datagram_step, ReceivedVideoFrame};
use super::{SessionOptions, SessionResult};
use crate::config::StationSettings;
use crate::net::{MediaKind, Udp};
use crate::protocol::FrameReassembler;
use crate::station::dual_recorder::DualStreamRecorder;
use crate::station::monitor::NetworkMonitor;
use crate::station::SessionError;
use std::net::SocketAddr;
use std::thread;
use std::time::{Duration, Instant};

#[allow(clippy::too_many_arguments)]
pub(super) fn run_interleaved_stream(
    capture: Option<&mut CaptureWorker>,
    mut audio: Option<&mut SessionAudioBackend>,
    transport: &mut SessionMediaTransport,
    settings: &StationSettings,
    options: &SessionOptions,
    result: &mut SessionResult,
    n_frames: u32,
    started: Instant,
    peer_audio: SocketAddr,
    peer_video: SocketAddr,
    control_socket: &Udp,
    control_peer: SocketAddr,
    packet_size: usize,
    video_compressed: bool,
    remote_video_bpp: u32,
    stream_w: u32,
    stream_h: u32,
    sid: u32,
    t0: u64,
    dual: &mut Option<DualStreamRecorder>,
    previews: &mut Vec<String>,
    monitor: &mut NetworkMonitor,
    audio_reassembler: &mut FrameReassembler,
    audio_queue: &mut ReceivePrefillQueue<Vec<u8>>,
    video_reassembler: &mut FrameReassembler,
    video_queue: &mut ReceivePrefillQueue<ReceivedVideoFrame>,
) -> Result<(), SessionError> {
    let period = Duration::from_secs_f64(
        f64::from(settings.audio.buffer_samples.max(1))
            / f64::from(settings.audio.sample_rate.max(1)),
    );
    let mut scheduler = DeadlineScheduler::new(period);
    let n_frames_u64 = u64::from(n_frames);
    let mut mailbox = PreparedVideoMailbox::default();
    let mut cursor: Option<VideoTxCursor> = None;
    let mut capture = capture;
    let mut audio_sequence = 0;
    let mut finite_drain_deadline = None;
    let needs_video_tx = options.stream_tx_video && !options.audio_only;
    loop {
        let now = Instant::now();
        let finite_tx_pending = (needs_video_tx && result.video_frames_sent < n_frames_u64)
            || (options.stream_tx_audio && result.audio_frames_sent < n_frames_u64)
            || cursor.is_some();
        let finite_rx_pending = (options.stream_rx_video
            && !options.audio_only
            && result.video_frames_received < n_frames_u64)
            || (options.stream_rx_audio && result.audio_frames_received < n_frames_u64);
        let continue_finite = if finite_tx_pending {
            finite_drain_deadline = None;
            true
        } else if finite_rx_pending {
            let deadline =
                *finite_drain_deadline.get_or_insert_with(|| now + Duration::from_secs(1));
            now < deadline
        } else {
            false
        };
        let continue_timed = options
            .duration_sec
            .is_some_and(|duration| started.elapsed().as_secs_f64() < duration);
        if !(options.persistent || continue_timed || continue_finite) {
            break;
        }
        if options
            .runtime_control
            .as_ref()
            .is_some_and(|control| control.is_cancelled())
        {
            break;
        }
        send_queued_controls(control_socket, control_peer, settings, options, result)?;
        if pump_control(
            control_socket,
            control_peer,
            settings,
            result,
            options.runtime_control.as_ref(),
        )? {
            break;
        }
        if cursor
            .as_ref()
            .is_some_and(|active| active.expired(now, Duration::from_millis(250)))
        {
            scheduler.drop_video_for_deadline(&mut cursor);
        }
        let audio_due = scheduler.audio_due(now);
        if audio_due {
            let timed_audio = options
                .duration_sec
                .is_some_and(|duration| started.elapsed().as_secs_f64() < duration);
            let transmit_audio = options.stream_tx_audio
                && (options.persistent || timed_audio || result.audio_frames_sent < n_frames_u64);
            let receive_audio = options.stream_rx_audio
                && (options.persistent
                    || timed_audio
                    || result.audio_frames_received < n_frames_u64);
            if transmit_audio || receive_audio {
                send_recv_audio_frame(
                    audio.as_deref_mut().ok_or_else(|| {
                        SessionError::AudioBackend(
                            "audio stream configured without an audio backend".into(),
                        )
                    })?,
                    transport,
                    peer_audio,
                    audio_reassembler,
                    packet_size,
                    settings.audio.channels,
                    settings.audio.sample_rate,
                    settings.audio.bits_per_sample,
                    options,
                    transmit_audio,
                    receive_audio,
                    sid,
                    audio_sequence,
                    t0,
                    result,
                    dual,
                    monitor,
                    audio_queue,
                )?;
                audio_sequence = audio_sequence.wrapping_add(1);
            }
            let timed_video_tx = options
                .duration_sec
                .is_some_and(|duration| started.elapsed().as_secs_f64() < duration);
            if needs_video_tx
                && (options.persistent || timed_video_tx || result.video_frames_sent < n_frames_u64)
            {
                if let Some(prepared) = capture.as_deref_mut().and_then(|worker| worker.take()) {
                    let prepared = prepared?;
                    if mailbox.publish(consume_prepared_capture(
                        prepared, options, result, dual, previews,
                    )) {
                        scheduler.counters.video_stale_drops += 1;
                    }
                }
                scheduler.adopt_newest(&mut mailbox, &mut cursor);
            }
        }

        // A scheduling quantum performs at most one video transport action,
        // then loops back to check the audio deadline. Sending between audio
        // callbacks lets large raw frames finish within their latency budget
        // instead of limiting video to one fragment per audio callback.
        let mut backpressured = false;
        if let Some(active_cursor) = cursor.as_mut() {
            let datagram = active_cursor
                .next()
                .expect("cursor always has a next datagram");
            match transport.send_video_datagram(datagram, peer_video) {
                Ok(VideoSendDisposition::Sent) => {
                    let complete = active_cursor.sent_one();
                    monitor.note_send(MediaKind::Video);
                    if complete {
                        result.video_frames_sent += 1;
                        result.media_frames_sent += 1;
                        cursor = None;
                    }
                }
                Ok(VideoSendDisposition::WouldBlock) => backpressured = true,
                Err(error) => return Err(error),
            }
        }
        // Full-duplex video must keep servicing receive while a transmit
        // cursor is active. Deferring receive until the complete local frame
        // has been sent lets loopback and fast peers accumulate partial remote
        // frames until the bounded reassembler rejects otherwise valid media.
        if options.stream_rx_video && !options.audio_only {
            receive_video_datagram_step(
                transport,
                peer_video,
                video_reassembler,
                stream_w,
                stream_h,
                settings.video.bayer,
                options,
                result,
                dual,
                monitor,
                video_compressed,
                remote_video_bpp,
                video_queue,
            )?;
        }
        if backpressured {
            scheduler.drop_video_for_backpressure(&mut cursor);
        }
        if !audio_due && cursor.is_none() {
            thread::sleep(
                scheduler
                    .wait_until_audio_due(now)
                    .min(Duration::from_millis(1)),
            );
        }
        result.audio_deadline_misses = scheduler.counters.audio_deadline_misses;
        result.audio_max_lateness_us = scheduler.counters.audio_max_lateness_us;
        result.video_stale_drops = scheduler.counters.video_stale_drops;
        result.video_backpressure_drops = scheduler.counters.video_backpressure_drops;
        result.video_deadline_drops = scheduler.counters.video_deadline_drops;
        if let Some(control) = options.runtime_control.as_ref() {
            control.set_activity(result);
        }
    }
    Ok(())
}
