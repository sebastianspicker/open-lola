//! Off-thread JPEG decoding for received video.
//!
//! Decoding a 720p frame takes several milliseconds while one audio period is
//! about 1.45 ms, so the session thread only hands compressed frames over and
//! later collects the finished result. Both hand-off slots are one deep and
//! the newest frame always wins.

use super::video::ReceivedVideoFrame;
use crate::protocol::VideoFrame;
use crate::station::sync::lock_unpoison;
use crate::video::decode_jpeg;
use std::sync::{Arc, Condvar, Mutex};
use std::thread::{self, JoinHandle};

type DecodeOutcome = Result<ReceivedVideoFrame, ()>;

#[derive(Default)]
struct Slots {
    pending: Option<VideoFrame>,
    result: Option<DecodeOutcome>,
    dropped: u64,
    stop: bool,
}

struct Shared {
    slots: Mutex<Slots>,
    wake: Condvar,
}

/// Decodes and validates compressed video frames on a dedicated thread.
pub(super) struct VideoDecodeWorker {
    shared: Arc<Shared>,
    handle: Option<JoinHandle<()>>,
    width: u32,
    height: u32,
    raw_bpp: u32,
}

/// Decodes a compressed frame and checks it against the negotiated geometry.
pub(super) fn decode_compressed(
    frame: VideoFrame,
    width: u32,
    height: u32,
    raw_bpp: u32,
) -> DecodeOutcome {
    let decoded = decode_jpeg(&frame.payload).map_err(|_| ())?;
    let channels = match decoded.mode.as_str() {
        "L" => 1,
        "RGB" => 3,
        _ => return Err(()),
    };
    let expected = width
        .checked_mul(height)
        .and_then(|pixels| pixels.checked_mul(channels))
        .and_then(|bytes| usize::try_from(bytes).ok())
        .ok_or(())?;
    if decoded.width != width
        || decoded.height != height
        || raw_bpp != channels * 8
        || decoded.pixels.len() != expected
    {
        return Err(());
    }
    Ok(ReceivedVideoFrame::Jpeg { frame, decoded })
}

impl Slots {
    fn store_result(&mut self, outcome: DecodeOutcome) {
        if self.result.replace(outcome).is_some() {
            self.dropped += 1;
        }
    }
}

impl VideoDecodeWorker {
    pub(super) fn start(stream_w: u32, stream_h: u32, raw_bpp: u32) -> Self {
        let shared = Arc::new(Shared {
            slots: Mutex::new(Slots::default()),
            wake: Condvar::new(),
        });
        let worker = Arc::clone(&shared);
        let handle = thread::Builder::new()
            .name("video-decode".into())
            .spawn(move || run(&worker, stream_w, stream_h, raw_bpp))
            .ok();
        Self {
            shared,
            handle,
            width: stream_w,
            height: stream_h,
            raw_bpp,
        }
    }

    /// Queues a frame, replacing an older pending one. Returns whether a
    /// pending frame was replaced.
    pub(super) fn submit(&self, frame: VideoFrame) -> bool {
        if self.handle.is_none() {
            // The thread could not be spawned; degrade to a synchronous decode.
            let outcome = decode_compressed(frame, self.width, self.height, self.raw_bpp);
            lock_unpoison(&self.shared.slots).store_result(outcome);
            return false;
        }
        let mut slots = lock_unpoison(&self.shared.slots);
        let replaced = slots.pending.replace(frame).is_some();
        if replaced {
            slots.dropped += 1;
        }
        drop(slots);
        self.shared.wake.notify_one();
        replaced
    }

    /// Takes the newest finished decode, if any.
    pub(super) fn take(&mut self) -> Option<DecodeOutcome> {
        lock_unpoison(&self.shared.slots).result.take()
    }

    /// Returns and resets the count of frames superseded before presentation.
    pub(super) fn take_dropped(&mut self) -> u64 {
        std::mem::take(&mut lock_unpoison(&self.shared.slots).dropped)
    }
}

fn run(shared: &Shared, width: u32, height: u32, raw_bpp: u32) {
    loop {
        let frame = {
            let mut slots = lock_unpoison(&shared.slots);
            loop {
                if slots.stop {
                    return;
                }
                if let Some(frame) = slots.pending.take() {
                    break frame;
                }
                slots = shared
                    .wake
                    .wait(slots)
                    .unwrap_or_else(|error| error.into_inner());
            }
        };
        let outcome = decode_compressed(frame, width, height, raw_bpp);
        lock_unpoison(&shared.slots).store_result(outcome);
    }
}

impl Drop for VideoDecodeWorker {
    fn drop(&mut self) {
        lock_unpoison(&self.shared.slots).stop = true;
        self.shared.wake.notify_all();
        if let Some(handle) = self.handle.take() {
            let _ = handle.join();
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::{Duration, Instant};

    fn jpeg(sequence: u32, width: u32, height: u32) -> VideoFrame {
        let pixels = vec![127; (width * height * 3) as usize];
        VideoFrame {
            sequence,
            payload: crate::video::encode_frame_jpeg(&pixels, width, height, "RGB24", 90).unwrap(),
            compressed: true,
        }
    }

    fn wait_for(worker: &mut VideoDecodeWorker) -> DecodeOutcome {
        let deadline = Instant::now() + Duration::from_secs(5);
        loop {
            if let Some(outcome) = worker.take() {
                return outcome;
            }
            assert!(Instant::now() < deadline, "decode did not finish");
            thread::sleep(Duration::from_millis(2));
        }
    }

    #[test]
    fn newest_result_wins_and_invalid_frames_are_errors() {
        let mut worker = VideoDecodeWorker::start(8, 8, 24);
        worker.submit(jpeg(1, 8, 8));
        let Ok(first) = wait_for(&mut worker) else {
            panic!("valid frame decodes");
        };
        assert_eq!(first.sequence(), 1);
        worker.submit(jpeg(2, 4, 4));
        assert!(wait_for(&mut worker).is_err(), "wrong geometry is rejected");

        // Replacing unread work keeps only the newest and counts the loss.
        for sequence in 3..40 {
            worker.submit(jpeg(sequence, 8, 8));
        }
        let mut last = None;
        let deadline = Instant::now() + Duration::from_secs(5);
        while last != Some(39) && Instant::now() < deadline {
            if let Some(Ok(frame)) = worker.take() {
                last = Some(frame.sequence());
            }
            thread::sleep(Duration::from_millis(2));
        }
        assert_eq!(last, Some(39));
        assert!(worker.take_dropped() > 0);
        assert_eq!(worker.take_dropped(), 0);
    }

    #[test]
    fn dropping_the_worker_joins_the_thread() {
        let worker = VideoDecodeWorker::start(8, 8, 24);
        let shared = Arc::downgrade(&worker.shared);
        worker.submit(jpeg(1, 8, 8));
        drop(worker);
        assert!(shared.upgrade().is_none(), "thread released shared state");
    }
}
