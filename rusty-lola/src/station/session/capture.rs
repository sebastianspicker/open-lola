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
        let worker_settings = settings.clone();
        let worker_options = options.clone();
        let mailbox = CaptureMailbox::default();
        let worker_mailbox = mailbox.clone();
        let stopped = Arc::new(AtomicBool::new(false));
        let worker_stopped = Arc::clone(&stopped);
        let (ready_tx, ready_rx) = mpsc::sync_channel(1);
        let handle = thread::Builder::new()
            .name("rusty-lola-capture".into())
            .spawn(move || {
                if session_cancelled(&worker_options) || worker_stopped.load(Ordering::Acquire) {
                    let error = SessionError::PeerDisconnect(
                        "session cancelled before camera backend open".into(),
                    );
                    let _ = ready_tx.send(Err(error.clone()));
                    return Err(error);
                }
                let mut camera =
                    match SessionCameraBackend::open(&worker_settings, &worker_options, &mode) {
                        Ok(camera) => camera,
                        Err(error) => {
                            let _ = ready_tx.send(Err(error.clone()));
                            return Err(error);
                        }
                    };
                let name = camera.name().to_string();
                if worker_stopped.load(Ordering::Acquire) || session_cancelled(&worker_options) {
                    let cleanup = camera.stop();
                    let error = SessionError::PeerDisconnect(
                        "session cancelled after camera backend open".into(),
                    );
                    let _ = ready_tx.send(Err(error.clone()));
                    return cleanup.and(Err(error));
                }
                if ready_tx.send(Ok(name)).is_err() {
                    return camera.stop();
                }

                let capture_period =
                    Duration::from_secs_f64(1.0 / f64::from(worker_settings.video.fps.max(1)));
                let mut frame_index = 0u32;
                let mut next_capture = Instant::now();
                let capture_result = loop {
                    if worker_stopped.load(Ordering::Acquire) || session_cancelled(&worker_options)
                    {
                        break Ok(());
                    }
                    let prepared = prepare_video_capture(
                        &mut camera,
                        packet_size,
                        stream_w,
                        stream_h,
                        worker_settings.video.width,
                        worker_settings.video.height,
                        worker_settings.video.jpeg_quality,
                        worker_settings.video.bayer,
                        &worker_options,
                        colors.as_ref(),
                        bayer,
                        jpeg,
                        sid,
                        frame_index,
                        t0,
                    );
                    frame_index = frame_index.wrapping_add(1);
                    let prepared = match prepared {
                        Ok(prepared) => prepared,
                        Err(error) => {
                            worker_mailbox.publish(Err(error.clone()));
                            break Err(error);
                        }
                    };
                    worker_mailbox.publish(Ok(prepared));
                    next_capture += capture_period;
                    let now = Instant::now();
                    if next_capture > now {
                        thread::sleep(next_capture.duration_since(now));
                    } else {
                        next_capture = now;
                    }
                };
                let cleanup = camera.stop();
                capture_result.and(cleanup)
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
                return Err(cleanup.err().unwrap_or(primary));
            }
        };
        Ok(Self {
            mailbox,
            stopped,
            handle: Some(handle),
            name,
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
        let Some(handle) = self.handle.take() else {
            return Ok(());
        };
        handle
            .join()
            .map_err(|_| SessionError::Cleanup("capture worker panicked".into()))?
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
