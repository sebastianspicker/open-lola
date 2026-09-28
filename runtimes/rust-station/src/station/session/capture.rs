//! Isolated camera capture and image preparation.
//!
//! Native camera handles are created, used, and stopped on this worker. The
//! scheduler only observes completed frames through a depth-one mailbox.

use super::backends::SessionCameraBackend;
use super::types::session_cancelled;
use super::video::{prepare_video_capture, PreparedCapture};
use super::SessionOptions;
use crate::config::{CameraMode, ColorSettings, StationSettings};
use crate::station::sync::lock_unpoison;
use crate::station::SessionError;
use crate::video::BayerPattern;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc::{self, Receiver};
use std::sync::{Arc, Mutex};
use std::thread::{self, JoinHandle};
use std::time::{Duration, Instant};

type CaptureSlot = Arc<Mutex<Option<Result<PreparedCapture, SessionError>>>>;

#[derive(Clone, Default)]
pub(super) struct CaptureMailbox {
    newest: CaptureSlot,
}

impl CaptureMailbox {
    fn publish(&self, capture: Result<PreparedCapture, SessionError>) -> bool {
        lock_unpoison(&self.newest).replace(capture).is_some()
    }

    pub(super) fn take(&self) -> Option<Result<PreparedCapture, SessionError>> {
        lock_unpoison(&self.newest).take()
    }
}

pub(super) struct CaptureWorker {
    mailbox: CaptureMailbox,
    stopped: Arc<AtomicBool>,
    handle: Option<JoinHandle<Result<(), SessionError>>>,
    name: String,
    cancellation: Arc<Mutex<Option<crate::video::v4l2::V4l2Cancellation>>>,
}

struct CaptureJob {
    settings: StationSettings,
    options: SessionOptions,
    mode: CameraMode,
    packet_size: usize,
    stream_w: u32,
    stream_h: u32,
    colors: Option<ColorSettings>,
    bayer: BayerPattern,
    jpeg: bool,
    sid: u32,
    t0: u64,
}

impl CaptureJob {
    fn cancelled(&self, stopped: &AtomicBool) -> bool {
        stopped.load(Ordering::Acquire) || session_cancelled(&self.options)
    }

    fn prepare(
        &self,
        camera: &mut SessionCameraBackend,
        frame_index: u32,
    ) -> Result<PreparedCapture, SessionError> {
        prepare_video_capture(
            camera,
            self.packet_size,
            self.stream_w,
            self.stream_h,
            self.settings.video.width,
            self.settings.video.height,
            self.settings.video.jpeg_quality,
            self.settings.video.bayer,
            &self.options,
            self.colors.as_ref(),
            self.bayer,
            self.jpeg,
            self.sid,
            frame_index,
            self.t0,
        )
    }

    fn capture_period(&self) -> Duration {
        Duration::from_secs_f64(1.0 / f64::from(self.settings.video.fps.max(1)))
    }
}

impl CaptureWorker {
    #[allow(clippy::too_many_arguments)]
    pub(super) fn start(
        settings: &StationSettings,
        options: &SessionOptions,
        mode: CameraMode,
        packet_size: usize,
        stream_w: u32,
        stream_h: u32,
        colors: Option<ColorSettings>,
        bayer: BayerPattern,
        jpeg: bool,
        sid: u32,
        t0: u64,
    ) -> Result<Self, SessionError> {
        if session_cancelled(options) {
            return Err(SessionError::PeerDisconnect(
                "session cancelled before camera worker open".into(),
            ));
        }
        let job = CaptureJob {
            settings: settings.clone(),
            options: options.clone(),
            mode,
            packet_size,
            stream_w,
            stream_h,
            colors,
            bayer,
            jpeg,
            sid,
            t0,
        };
        let mailbox = CaptureMailbox::default();
        let worker_mailbox = mailbox.clone();
        let stopped = Arc::new(AtomicBool::new(false));
        let worker_stopped = Arc::clone(&stopped);
        let cancellation = Arc::new(Mutex::new(None));
        let worker_cancellation = Arc::clone(&cancellation);
        let (ready_tx, ready_rx) = mpsc::sync_channel(1);
        let handle = thread::Builder::new()
            .name("rusty-lola-capture".into())
            .spawn(move || {
                run_capture_worker(
                    job,
                    worker_mailbox,
                    worker_stopped,
                    worker_cancellation,
                    ready_tx,
                )
            })
            .map_err(|error| {
                SessionError::VideoBackend(format!("start capture worker: {error}"))
            })?;
        let name = match await_ready(ready_rx, options, &stopped) {
            Ok(name) => name,
            Err(primary) => {
                stopped.store(true, Ordering::Release);
                let cleanup = handle
                    .join()
                    .map_err(|_| SessionError::Cleanup("capture worker panicked".into()))
                    .and_then(|result| result);
                let _ = cleanup;
                return Err(primary);
            }
        };
        Ok(Self {
            mailbox,
            stopped,
            handle: Some(handle),
            name,
            cancellation,
        })
    }

    pub(super) fn name(&self) -> &str {
        &self.name
    }

    pub(super) fn take(&self) -> Option<Result<PreparedCapture, SessionError>> {
        self.mailbox.take()
    }

    pub(super) fn stop(&mut self) -> Result<(), SessionError> {
        self.stopped.store(true, Ordering::Release);
        if let Some(token) = lock_unpoison(&self.cancellation).as_ref() {
            token.cancel();
        }
        let Some(handle) = self.handle.take() else {
            return Ok(());
        };
        handle
            .join()
            .map_err(|_| SessionError::Cleanup("capture worker panicked".into()))?
    }
}

fn run_capture_worker(
    job: CaptureJob,
    mailbox: CaptureMailbox,
    stopped: Arc<AtomicBool>,
    cancellation: Arc<Mutex<Option<crate::video::v4l2::V4l2Cancellation>>>,
    ready: mpsc::SyncSender<Result<String, SessionError>>,
) -> Result<(), SessionError> {
    if job.cancelled(&stopped) {
        return notify_worker_error(
            &ready,
            SessionError::PeerDisconnect("session cancelled before camera backend open".into()),
        );
    }
    let mut camera = match SessionCameraBackend::open(&job.settings, &job.options, &job.mode) {
        Ok(camera) => camera,
        Err(error) => return notify_worker_error(&ready, error),
    };
    *lock_unpoison(&cancellation) = camera.cancellation_handle();
    if job.cancelled(&stopped) {
        return stop_cancelled_camera(&ready, &mut camera);
    }
    if ready.send(Ok(camera.name().to_string())).is_err() {
        return camera.stop();
    }
    run_capture_loop(&job, &mailbox, &stopped, &mut camera).and(camera.stop())
}

fn notify_worker_error(
    ready: &mpsc::SyncSender<Result<String, SessionError>>,
    error: SessionError,
) -> Result<(), SessionError> {
    let _ = ready.send(Err(error.clone()));
    Err(error)
}

fn stop_cancelled_camera(
    ready: &mpsc::SyncSender<Result<String, SessionError>>,
    camera: &mut SessionCameraBackend,
) -> Result<(), SessionError> {
    let error = SessionError::PeerDisconnect("session cancelled after camera backend open".into());
    let _ = ready.send(Err(error.clone()));
    camera.stop().and(Err(error))
}

fn run_capture_loop(
    job: &CaptureJob,
    mailbox: &CaptureMailbox,
    stopped: &AtomicBool,
    camera: &mut SessionCameraBackend,
) -> Result<(), SessionError> {
    let mut frame_index = 0u32;
    let mut next_capture = Instant::now();
    loop {
        if job.cancelled(stopped) {
            return Ok(());
        }
        let prepared = job.prepare(camera, frame_index);
        frame_index = frame_index.wrapping_add(1);
        match prepared {
            Ok(prepared) => mailbox.publish(Ok(prepared)),
            Err(_) if job.cancelled(stopped) => return Ok(()),
            Err(error) => {
                mailbox.publish(Err(error.clone()));
                return Err(error);
            }
        };
        next_capture += job.capture_period();
        wait_for_capture_deadline(&mut next_capture, job, stopped);
    }
}

fn wait_for_capture_deadline(next_capture: &mut Instant, job: &CaptureJob, stopped: &AtomicBool) {
    let now = Instant::now();
    if *next_capture <= now {
        *next_capture = now;
        return;
    }
    while Instant::now() < *next_capture && !job.cancelled(stopped) {
        thread::sleep(
            next_capture
                .saturating_duration_since(Instant::now())
                .min(Duration::from_millis(5)),
        );
    }
}

impl Drop for CaptureWorker {
    fn drop(&mut self) {
        let _ = self.stop();
    }
}

fn await_ready(
    ready: Receiver<Result<String, SessionError>>,
    options: &SessionOptions,
    stopped: &AtomicBool,
) -> Result<String, SessionError> {
    loop {
        match ready.recv_timeout(Duration::from_millis(10)) {
            Ok(result) => return result,
            Err(mpsc::RecvTimeoutError::Timeout) if session_cancelled(options) => {
                stopped.store(true, Ordering::Release);
                return Err(SessionError::PeerDisconnect(
                    "session cancelled while camera backend opened".into(),
                ));
            }
            Err(mpsc::RecvTimeoutError::Timeout) => continue,
            Err(mpsc::RecvTimeoutError::Disconnected) => {
                return Err(SessionError::VideoBackend(
                    "capture worker stopped before backend readiness".into(),
                ));
            }
        }
    }
}
