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
use crate::protocol::{AudioDatagramWriter, FrameReassembler};
use crate::station::monitor::NetworkMonitor;
use crate::station::recording_worker::SessionRecorder as DualStreamRecorder;
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
    let mut phase = StreamPhase::new(audio_period(settings), capture, n_frames);
    let mut audio_writer = AudioDatagramWriter::new();
    while phase.should_continue(options, result, started) {
        if stream_cancelled(options)
            || process_controls(control_socket, control_peer, settings, options, result)?
        {
            break;
        }
        let now = Instant::now();
        phase.expire_stale_video(now);
        let audio_due = phase.scheduler.audio_due(now);
        if audio_due {
            let audio_result = process_audio_deadline(
                &mut audio,
                transport,
                settings,
                options,
                result,
                started,
                peer_audio,
                packet_size,
                sid,
                t0,
                dual,
                monitor,
                audio_reassembler,
                audio_queue,
                &mut audio_writer,
                &mut phase,
            );
            result.audio_device_xruns = audio.as_ref().and_then(|audio| audio.xruns());
            audio_result?;
            prepare_video_capture(&mut phase, options, result, dual, previews)?;
        }
        let backpressured = send_video_step(transport, peer_video, result, monitor, &mut phase)?;
        receive_video_step(
            transport,
            options,
            peer_video,
            video_reassembler,
            stream_w,
            stream_h,
            result,
            dual,
            monitor,
            video_compressed,
            remote_video_bpp,
            video_queue,
        )?;
        phase.finish_quantum(audio_due, backpressured, result, options);
    }
    Ok(())
}

struct StreamPhase<'a> {
    scheduler: DeadlineScheduler,
    mailbox: PreparedVideoMailbox,
    cursor: Option<VideoTxCursor>,
    capture: Option<&'a mut CaptureWorker>,
    audio_sequence: u32,
    finite_drain_deadline: Option<Instant>,
    n_frames: u64,
}

impl<'a> StreamPhase<'a> {
    fn new(period: Duration, capture: Option<&'a mut CaptureWorker>, n_frames: u32) -> Self {
        Self {
            scheduler: DeadlineScheduler::new(period),
            mailbox: PreparedVideoMailbox::default(),
            cursor: None,
            capture,
            audio_sequence: 0,
            finite_drain_deadline: None,
            n_frames: u64::from(n_frames),
        }
    }
    fn should_continue(
        &mut self,
        options: &SessionOptions,
        result: &SessionResult,
        started: Instant,
    ) -> bool {
        let now = Instant::now();
        let tx = pending_transmit(options, result, self.n_frames, self.cursor.is_some());
        let rx = pending_receive(options, result, self.n_frames);
        options.persistent || duration_active(options, started) || self.continue_finite(now, tx, rx)
    }
    fn continue_finite(
        &mut self,
        now: Instant,
        transmit_pending: bool,
        receive_pending: bool,
    ) -> bool {
        if transmit_pending {
            self.finite_drain_deadline = None;
            return true;
        }
        if !receive_pending {
            return false;
        }
        now < *self
            .finite_drain_deadline
            .get_or_insert_with(|| now + Duration::from_secs(1))
    }
    fn expire_stale_video(&mut self, now: Instant) {
        if self
            .cursor
            .as_ref()
            .is_some_and(|cursor| cursor.expired(now, Duration::from_millis(250)))
        {
            self.scheduler.drop_video_for_deadline(&mut self.cursor);
        }
    }
    fn finish_quantum(
        &mut self,
        audio_due: bool,
        backpressured: bool,
        result: &mut SessionResult,
        options: &SessionOptions,
    ) {
        if backpressured {
            self.scheduler.drop_video_for_backpressure(&mut self.cursor);
        }
        if !audio_due && self.cursor.is_none() {
            thread::sleep(
                self.scheduler
                    .wait_until_audio_due(Instant::now())
                    .min(Duration::from_millis(1)),
            );
        }
        copy_scheduler_counters(result, &self.scheduler);
        if let Some(control) = options.runtime_control.as_ref() {
            control.set_activity(result);
        }
    }
}

fn audio_period(settings: &StationSettings) -> Duration {
    Duration::from_secs_f64(
        f64::from(settings.audio.buffer_samples.max(1))
            / f64::from(settings.audio.sample_rate.max(1)),
    )
}
fn duration_active(options: &SessionOptions, started: Instant) -> bool {
    options
        .duration_sec
        .is_some_and(|duration| started.elapsed().as_secs_f64() < duration)
}
fn stream_cancelled(options: &SessionOptions) -> bool {
    options
        .runtime_control
        .as_ref()
        .is_some_and(|control| control.is_cancelled())
}
fn pending_transmit(
    options: &SessionOptions,
    result: &SessionResult,
    frames: u64,
    cursor_active: bool,
) -> bool {
    (options.stream_tx_video && !options.audio_only && result.video_frames_sent < frames)
        || (options.stream_tx_audio && result.audio_frames_sent < frames)
        || cursor_active
}
fn pending_receive(options: &SessionOptions, result: &SessionResult, frames: u64) -> bool {
    (options.stream_rx_video && !options.audio_only && result.video_frames_received < frames)
        || (options.stream_rx_audio && result.audio_frames_received < frames)
}
fn process_controls(
    socket: &Udp,
    peer: SocketAddr,
    settings: &StationSettings,
    options: &SessionOptions,
    result: &mut SessionResult,
) -> Result<bool, SessionError> {
    send_queued_controls(socket, peer, settings, options, result)?;
    pump_control(
        socket,
        peer,
        settings,
        result,
        options.runtime_control.as_ref(),
    )
}

#[allow(clippy::too_many_arguments)]
fn process_audio_deadline(
    audio: &mut Option<&mut SessionAudioBackend>,
    transport: &mut SessionMediaTransport,
    settings: &StationSettings,
    options: &SessionOptions,
    result: &mut SessionResult,
    started: Instant,
    peer: SocketAddr,
    packet_size: usize,
    sid: u32,
    t0: u64,
    dual: &mut Option<DualStreamRecorder>,
    monitor: &mut NetworkMonitor,
    reassembler: &mut FrameReassembler,
    queue: &mut ReceivePrefillQueue<Vec<u8>>,
    audio_writer: &mut AudioDatagramWriter,
    phase: &mut StreamPhase<'_>,
) -> Result<(), SessionError> {
    let timed = duration_active(options, started);
    let transmit = options.stream_tx_audio
        && (options.persistent || timed || result.audio_frames_sent < phase.n_frames);
    let receive = options.stream_rx_audio
        && (options.persistent || timed || result.audio_frames_received < phase.n_frames);
    if transmit || receive {
        send_recv_audio_frame(
            audio.as_deref_mut().ok_or_else(|| {
                SessionError::AudioBackend(
                    "audio stream configured without an audio backend".into(),
                )
            })?,
            transport,
            peer,
            reassembler,
            packet_size,
            settings.audio.channels,
            settings.audio.sample_rate,
            settings.audio.bits_per_sample,
            options,
            transmit,
            receive,
            sid,
            phase.audio_sequence,
            t0,
            result,
            dual,
            monitor,
            queue,
            audio_writer,
        )?;
        phase.audio_sequence = phase.audio_sequence.wrapping_add(1);
    }
    Ok(())
}

fn prepare_video_capture(
    phase: &mut StreamPhase<'_>,
    options: &SessionOptions,
    result: &mut SessionResult,
    dual: &mut Option<DualStreamRecorder>,
    previews: &mut Vec<String>,
) -> Result<(), SessionError> {
    if !options.stream_tx_video || options.audio_only {
        return Ok(());
    }
    if let Some(prepared) = phase
        .capture
        .as_deref_mut()
        .and_then(|worker| worker.take())
    {
        if phase.mailbox.publish(consume_prepared_capture(
            prepared?, options, result, dual, previews,
        )) {
            phase.scheduler.counters.video_stale_drops += 1;
        }
    }
    phase
        .scheduler
        .adopt_newest(&mut phase.mailbox, &mut phase.cursor);
    Ok(())
}

fn send_video_step(
    transport: &mut SessionMediaTransport,
    peer: SocketAddr,
    result: &mut SessionResult,
    monitor: &mut NetworkMonitor,
    phase: &mut StreamPhase<'_>,
) -> Result<bool, SessionError> {
    let Some(cursor) = phase.cursor.as_mut() else {
        return Ok(false);
    };
    match transport.send_video_datagram(
        cursor.next().expect("cursor always has a next datagram"),
        peer,
    ) {
        Ok(VideoSendDisposition::Sent) => {
            let complete = cursor.sent_one();
            monitor.note_send(MediaKind::Video);
            if complete {
                result.video_frames_sent += 1;
                result.media_frames_sent += 1;
                phase.cursor = None;
            }
            Ok(false)
        }
        Ok(VideoSendDisposition::WouldBlock) => Ok(true),
        Err(error) => Err(error),
    }
}

#[allow(clippy::too_many_arguments)]
fn receive_video_step(
    transport: &mut SessionMediaTransport,
    options: &SessionOptions,
    peer: SocketAddr,
    reassembler: &mut FrameReassembler,
    width: u32,
    height: u32,
    result: &mut SessionResult,
    dual: &mut Option<DualStreamRecorder>,
    monitor: &mut NetworkMonitor,
    compressed: bool,
    remote_bpp: u32,
    queue: &mut ReceivePrefillQueue<ReceivedVideoFrame>,
) -> Result<(), SessionError> {
    if options.stream_rx_video && !options.audio_only {
        receive_video_datagram_step(
            transport,
            peer,
            reassembler,
            width,
            height,
            options,
            result,
            dual,
            monitor,
            compressed,
            remote_bpp,
            queue,
        )?;
    }
    Ok(())
}

fn copy_scheduler_counters(result: &mut SessionResult, scheduler: &DeadlineScheduler) {
    if !result.audio_backend.is_empty() {
        result.audio_deadline_misses = scheduler.counters.audio_deadline_misses;
        result.audio_skipped_deadlines = scheduler.counters.audio_skipped_deadlines;
        result.audio_max_lateness_us = scheduler.counters.audio_max_lateness_us;
        result.audio_lateness_p95_upper_us = scheduler.counters.audio_lateness.p95_upper_us();
    }
    result.video_queue_age_p95_upper_us = scheduler.counters.video_queue_age.p95_upper_us();
    result.video_max_queue_age_us = scheduler.counters.video_max_queue_age_us;
    result.video_stale_drops = scheduler.counters.video_stale_drops;
    result.video_backpressure_drops = scheduler.counters.video_backpressure_drops;
    result.video_deadline_drops = scheduler.counters.video_deadline_drops;
}
