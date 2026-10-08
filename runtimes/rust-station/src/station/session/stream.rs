//! Deadline-first interleaved stream execution.

use super::audio_receive::AudioReceiveQueue;

use super::audio::send_recv_audio_frame;
use super::backends::SessionAudioBackend;
use super::capture::CaptureWorker;
use super::control::{pump_control, send_queued_controls, QuickconnAckCache};
use super::media::{SessionMediaTransport, VideoSendDisposition};
use super::scheduler::{DeadlineScheduler, PreparedVideoMailbox, VideoTxCursor};
use super::stream_support::{note_realtime_priority, record_audio_backend_counters};
use super::video::{consume_prepared_capture, receive_video_datagram_step, VideoReceiveQueue};
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
    audio_queue: &mut AudioReceiveQueue,
    video_reassembler: &mut FrameReassembler,
    video_queue: &mut VideoReceiveQueue,
    quickconn_ack: Option<&QuickconnAckCache>,
) -> Result<(), SessionError> {
    let mut phase = StreamPhase::new(
        audio_period(settings),
        video_period(settings),
        capture,
        n_frames,
    );
    let mut audio_writer = AudioDatagramWriter::new();
    note_realtime_priority(result);
    while phase.should_continue(options, result, started) {
        if stream_cancelled(options) {
            break;
        }
        let now = Instant::now();
        // The capture device clock paces audio when it has a block ready; the
        // wall clock remains the fallback.
        let device_ready = capture_consumed_at_deadline(options, result, started, &phase)
            && audio
                .as_deref()
                .and_then(SessionAudioBackend::capture_blocks_ready)
                .is_some_and(|blocks| blocks > 0);
        let audio_due = (device_ready && phase.scheduler.service_device_block(now))
            || phase.scheduler.audio_due(now);
        if phase.control_service_due(now, audio_due)
            && process_controls(
                control_socket,
                control_peer,
                settings,
                options,
                result,
                quickconn_ack,
            )?
        {
            break;
        }
        phase.expire_stale_video(now);
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
            record_audio_backend_counters(result, audio.as_deref());
            audio_result?;
            prepare_video_capture(&mut phase, options, result, dual, previews)?;
        }
        let backpressured = send_video_step(transport, peer_video, result, monitor, &mut phase)?;
        let received_video = receive_video_step(
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
            &phase,
        )?;
        phase.finish_quantum(
            QuantumOutcome {
                audio_due,
                backpressured,
                received_video,
            },
            result,
            options,
        );
    }
    Ok(())
}

/// Video datagrams admitted per scheduler quantum. A quantum is bounded by
/// the audio deadline guard as well, so a burst never starves audio.
const VIDEO_RECEIVE_DRAIN_LIMIT: usize = 64;
/// Remaining time to the next audio deadline below which no further video
/// datagram is read in the current quantum.
const VIDEO_RECEIVE_AUDIO_GUARD: Duration = Duration::from_micros(150);
/// Pause while the video socket refuses more datagrams. Long enough for the
/// kernel to drain a few packets, short enough to stay well inside a frame.
const VIDEO_BACKPRESSURE_PAUSE: Duration = Duration::from_micros(200);
/// Video datagrams sent per scheduler quantum, bounded so a burst cannot
/// monopolise the loop; sending also stops near the audio deadline.
const VIDEO_SEND_BURST_LIMIT: usize = 16;
/// Remaining time to the next audio deadline below which no further video
/// datagram is sent in the current quantum.
const VIDEO_SEND_AUDIO_GUARD: Duration = Duration::from_micros(150);
/// The idle sleep ends this long before the audio deadline; the remainder is
/// spun so OS timer granularity cannot make the deadline late.
const EARLY_WAKE_MARGIN: Duration = Duration::from_micros(200);
/// Longest the control socket may go unserviced while audio is not due. Each
/// service costs a nonblocking toggle plus a receive on the control socket.
const CONTROL_SERVICE_INTERVAL: Duration = Duration::from_millis(2);

struct QuantumOutcome {
    audio_due: bool,
    backpressured: bool,
    received_video: bool,
}

struct StreamPhase<'a> {
    scheduler: DeadlineScheduler,
    mailbox: PreparedVideoMailbox,
    cursor: Option<VideoTxCursor>,
    capture: Option<&'a mut CaptureWorker>,
    audio_sequence: u32,
    finite_drain_deadline: Option<Instant>,
    n_frames: u64,
    /// Prepared frames older than this are discarded unsent.
    video_age_limit: Duration,
    /// A cursor blocked by socket backpressure for longer than this is
    /// discarded; shorter stalls simply retry on the next quantum.
    video_backpressure_limit: Duration,
    blocked_since: Option<Instant>,
    last_control_service: Instant,
}

impl<'a> StreamPhase<'a> {
    fn new(
        period: Duration,
        frame_period: Duration,
        capture: Option<&'a mut CaptureWorker>,
        n_frames: u32,
    ) -> Self {
        Self {
            scheduler: DeadlineScheduler::new(period),
            mailbox: PreparedVideoMailbox::default(),
            cursor: None,
            capture,
            audio_sequence: 0,
            finite_drain_deadline: None,
            n_frames: u64::from(n_frames),
            video_age_limit: video_age_limit(frame_period),
            video_backpressure_limit: frame_period.max(Duration::from_millis(20)),
            blocked_since: None,
            last_control_service: Instant::now(),
        }
    }
    /// Whether the control socket is serviced this pass: at every audio
    /// deadline, or once the service interval has elapsed. Records the service
    /// time when it is, so callers only need to act on `true`.
    fn control_service_due(&mut self, now: Instant, audio_due: bool) -> bool {
        let due =
            audio_due || now.duration_since(self.last_control_service) >= CONTROL_SERVICE_INTERVAL;
        if due {
            self.last_control_service = now;
        }
        due
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
            .is_some_and(|cursor| cursor.expired(now, self.video_age_limit))
        {
            self.scheduler.drop_video_for_deadline(&mut self.cursor);
            self.blocked_since = None;
        }
    }
    /// Socket backpressure is ordinary for a fragmented frame whose bytes
    /// exceed the kernel send buffer. The cursor is kept and retried; only a
    /// stall longer than the backpressure limit discards the frame.
    fn note_backpressure(&mut self, backpressured: bool, now: Instant) {
        if !backpressured {
            self.blocked_since = None;
            return;
        }
        let since = *self.blocked_since.get_or_insert(now);
        if now.duration_since(since) > self.video_backpressure_limit {
            self.scheduler.drop_video_for_backpressure(&mut self.cursor);
            self.blocked_since = None;
        }
    }
    fn finish_quantum(
        &mut self,
        outcome: QuantumOutcome,
        result: &mut SessionResult,
        options: &SessionOptions,
    ) {
        let now = Instant::now();
        self.note_backpressure(outcome.backpressured, now);
        if !outcome.audio_due && !outcome.received_video {
            let until_audio = self.scheduler.wait_until_audio_due(now);
            let pause = if self.cursor.is_none() {
                if until_audio <= EARLY_WAKE_MARGIN {
                    while self.scheduler.wait_until_audio_due(Instant::now()) > Duration::ZERO {
                        std::hint::spin_loop();
                    }
                    Duration::ZERO
                } else {
                    (until_audio - EARLY_WAKE_MARGIN).min(Duration::from_millis(1))
                }
            } else if outcome.backpressured {
                until_audio.min(VIDEO_BACKPRESSURE_PAUSE)
            } else {
                Duration::ZERO
            };
            if !pause.is_zero() {
                thread::sleep(pause);
            }
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
fn video_period(settings: &StationSettings) -> Duration {
    Duration::from_secs_f64(1.0 / f64::from(settings.video.fps.clamp(1, 240)))
}
/// Two frame periods, bounded so slow frame rates still expire within a
/// quarter second and fast ones keep a usable retry window.
fn video_age_limit(frame_period: Duration) -> Duration {
    (frame_period * 2).clamp(Duration::from_millis(50), Duration::from_millis(250))
}
/// Whether the next audio deadline will read a capture block. Only then may a
/// ready block pace the clock: a test-signal send or a finished transmit run
/// never drains the ring, so its occupancy says nothing about the device.
fn capture_consumed_at_deadline(
    options: &SessionOptions,
    result: &SessionResult,
    started: Instant,
    phase: &StreamPhase<'_>,
) -> bool {
    options.stream_tx_audio
        && !options.test_signal_send()
        && (options.persistent
            || duration_active(options, started)
            || result.audio_frames_sent < phase.n_frames)
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
    quickconn_ack: Option<&QuickconnAckCache>,
) -> Result<bool, SessionError> {
    send_queued_controls(socket, peer, settings, options, result)?;
    pump_control(
        socket,
        peer,
        settings,
        result,
        options.runtime_control.as_ref(),
        quickconn_ack,
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
    queue: &mut AudioReceiveQueue,
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
    for _ in 0..VIDEO_SEND_BURST_LIMIT {
        let Some(cursor) = phase.cursor.as_mut() else {
            break;
        };
        match transport.send_video_datagram(
            cursor.next().expect("cursor always has a next datagram"),
            peer,
        )? {
            VideoSendDisposition::Sent => {
                let complete = cursor.sent_one();
                if complete {
                    monitor.note_send(MediaKind::Video);
                    result.video_frames_sent += 1;
                    result.media_frames_sent += 1;
                    phase.cursor = None;
                }
            }
            VideoSendDisposition::WouldBlock => return Ok(true),
        }
        if phase.scheduler.wait_until_audio_due(Instant::now()) < VIDEO_SEND_AUDIO_GUARD {
            break;
        }
    }
    Ok(false)
}

/// Drains a bounded burst of video datagrams, yielding early when the next
/// audio deadline is close. Returns whether any datagram was read.
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
    queue: &mut VideoReceiveQueue,
    phase: &StreamPhase<'_>,
) -> Result<bool, SessionError> {
    if !options.stream_rx_video || options.audio_only {
        return Ok(false);
    }
    queue.poll_decoded(width, height, remote_bpp, options, result, dual, monitor);
    let mut received = false;
    for _ in 0..VIDEO_RECEIVE_DRAIN_LIMIT {
        if !receive_video_datagram_step(
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
        )? {
            break;
        }
        received = true;
        if phase.scheduler.wait_until_audio_due(Instant::now()) < VIDEO_RECEIVE_AUDIO_GUARD {
            break;
        }
    }
    result.video_superseded_incomplete_frames += reassembler.take_evicted_older_frames();
    Ok(received)
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
    result.audio_device_paced_services = scheduler.counters.audio_device_paced_services;
}
