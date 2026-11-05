//! Bounded session recording adapter; disk and codec work runs off the scheduler.
use super::dual_recorder::{DualRecordFinalize, DualRecordResult, DualStreamRecorder};
use super::sync::lock_unpoison;
use super::SessionOptions;
use crate::config::StationSettings;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::mpsc::{self, SyncSender};
use std::sync::{
    atomic::{AtomicBool, AtomicUsize, Ordering},
    Arc,
};
use std::thread::JoinHandle;
use std::time::{Duration, Instant};

mod preview;
use preview::PreviewOutput;
static ACTIVE_WORKERS: AtomicUsize = AtomicUsize::new(0);
struct WorkerLease;
impl Drop for WorkerLease {
    fn drop(&mut self) {
        ACTIVE_WORKERS.fetch_sub(1, Ordering::AcqRel);
    }
}
struct QueueSlot(Arc<AtomicUsize>);
impl Drop for QueueSlot {
    fn drop(&mut self) {
        self.0.fetch_sub(1, Ordering::AcqRel);
    }
}

const QUEUE_CAPACITY: usize = 8;
/// About 1.3 s of 5 ms blocks, so queued video encodes cannot crowd out audio.
const AUDIO_QUEUE_CAPACITY: usize = 256;
const MAX_VIDEO_BYTES: usize = 16 * 1024 * 1024;
/// Finalization waits this long plus one second per queued video job.
const FINALIZE_BASE: Duration = Duration::from_secs(10);
struct RecordJob {
    _slot: QueueSlot,
    remote: bool,
    payload: RecordPayload,
}
// Audio stays inline so queueing a block never allocates; slots total about 270 KB.
#[allow(clippy::large_enum_variant)]
enum RecordPayload {
    Audio {
        pcm: [u8; 1025],
        length: usize,
    },
    Video {
        pixels: Vec<u8>,
        width: u32,
        height: u32,
    },
    Preview {
        file_name: String,
        pixels: Vec<u8>,
    },
}

#[derive(Clone, Copy)]
struct RecordAdmission {
    local_audio: bool,
    remote_audio: bool,
    local_video: bool,
    remote_video: bool,
    previews: bool,
}

pub struct SessionRecorder {
    sender: Option<SyncSender<RecordJob>>,
    worker: Option<JoinHandle<DualRecordFinalize>>,
    dropped: u64,
    startup_error: Option<String>,
    pending: Arc<AtomicUsize>,
    audio_pending: Arc<AtomicUsize>,
    cancelled: Arc<AtomicBool>,
    admission: RecordAdmission,
    /// Output paths the worker opened, kept for a finalize that times out.
    known_paths: Arc<std::sync::Mutex<DualRecordResult>>,
}
impl SessionRecorder {
    /// Recorder for a session's record and preview options, or `None` when neither is set.
    pub(crate) fn for_session(
        settings: &StationSettings,
        options: &SessionOptions,
    ) -> Option<Self> {
        let record_dir = options.record.then(|| options.record_dir.clone()).flatten();
        let preview_dir = options.preview_dir.clone();
        if record_dir.is_none() && preview_dir.is_none() {
            return None;
        }
        let mode = if options.record {
            settings.recording.mode.as_str()
        } else {
            "none"
        };
        Some(Self::with_options(
            record_dir,
            preview_dir,
            settings.audio.sample_rate,
            settings.audio.channels,
            settings.audio.bits_per_sample,
            "session",
            mode,
            options.record && settings.recording.record_local_audio,
            options.record && settings.recording.record_remote_audio,
            options.record && settings.recording.record_local_video,
            options.record && settings.recording.record_remote_video,
            &settings.recording.video_format,
        ))
    }

    #[allow(clippy::too_many_arguments)]
    pub fn with_options(
        record_root: Option<PathBuf>,
        preview_root: Option<PathBuf>,
        sample_rate: u32,
        channels: u16,
        bits_per_sample: u16,
        stem: &str,
        mode: &str,
        local_audio: bool,
        remote_audio: bool,
        local_video: bool,
        remote_video: bool,
        format: &str,
    ) -> Self {
        // Normalised once here, matching the settings validator, for every consumer below.
        let (mode, format) = (
            mode.trim().to_ascii_lowercase(),
            format.trim().to_ascii_lowercase(),
        );
        let pending = Arc::new(AtomicUsize::new(0));
        let audio_pending = Arc::new(AtomicUsize::new(0));
        let cancelled = Arc::new(AtomicBool::new(false));
        let known_paths = Arc::new(std::sync::Mutex::new(DualRecordResult::default()));
        let admission = RecordAdmission::new(
            &mode,
            local_audio,
            remote_audio,
            local_video,
            remote_video,
            preview_root.is_some(),
        );
        // `fetch_update` is deprecated in favour of `try_update` on recent
        // toolchains; the older name keeps the crate building on older stable.
        #[allow(deprecated)]
        let reserved = ACTIVE_WORKERS
            .fetch_update(Ordering::AcqRel, Ordering::Acquire, |active| {
                (active < 2).then_some(active + 1)
            })
            .is_err();
        if reserved {
            return Self {
                sender: None,
                worker: None,
                dropped: 0,
                startup_error: Some("two recording workers are still active".into()),
                pending,
                audio_pending,
                cancelled,
                admission,
                known_paths,
            };
        }
        let lease = WorkerLease;
        let stem = stem.to_owned();
        let stopping = cancelled.clone();
        let worker_paths = known_paths.clone();
        let (sender, receiver) =
            mpsc::sync_channel::<RecordJob>(QUEUE_CAPACITY + AUDIO_QUEUE_CAPACITY);
        let worker = std::thread::Builder::new()
            .name("rusty-lola-recorder".into())
            .spawn(move || {
                let _lease = lease;
                // All path and directory operations belong to this worker.
                let (mut recorder, mut finalized) = open_recorder(
                    record_root,
                    sample_rate,
                    channels,
                    bits_per_sample,
                    &stem,
                    &mode,
                    local_audio,
                    remote_audio,
                    local_video,
                    remote_video,
                    &format,
                );
                if let Some(recorder) = recorder.as_ref() {
                    *lock_unpoison(&worker_paths) = recorder.audio_paths();
                }
                let (mut previews, warning) = open_previews(preview_root);
                if let Some(warning) = warning {
                    finalized.warnings.push(warning);
                }
                for job in receiver {
                    if stopping.load(Ordering::Acquire) {
                        break;
                    }
                    match job.payload {
                        RecordPayload::Audio { pcm, length } => {
                            if let Some(recorder) = recorder.as_mut() {
                                recorder.write_audio(side(job.remote), &pcm[..length]);
                            }
                        }
                        RecordPayload::Video {
                            pixels,
                            width,
                            height,
                        } => {
                            let written = recorder.as_mut().and_then(|recorder| {
                                recorder.write_video_frame(side(job.remote), &pixels, width, height)
                            });
                            // Kept so a finalize timeout can still report the video outputs.
                            if let Some(path) = written {
                                let mut known = lock_unpoison(&worker_paths);
                                let paths = if job.remote {
                                    &mut known.remote_video_paths
                                } else {
                                    &mut known.local_video_paths
                                };
                                if paths.len()
                                    == crate::station::dual_recorder::RECENT_VIDEO_PATH_WINDOW
                                {
                                    paths.remove(0);
                                }
                                paths.push(path);
                            }
                        }
                        RecordPayload::Preview { file_name, pixels } => {
                            if let Some(previews) = previews.as_mut() {
                                previews.write(&file_name, &pixels);
                            }
                        }
                    }
                }
                if let Some(recorder) = recorder {
                    let completed = recorder.close_checked();
                    finalized.result = completed.result;
                    finalized.warnings.extend(completed.warnings);
                }
                if let Some(previews) = previews {
                    previews.finish(&mut finalized);
                }
                finalized
            });
        match worker {
            Ok(worker) => Self {
                sender: Some(sender),
                worker: Some(worker),
                dropped: 0,
                startup_error: None,
                pending,
                audio_pending,
                cancelled,
                admission,
                known_paths,
            },
            Err(error) => Self {
                sender: None,
                worker: None,
                dropped: 0,
                startup_error: Some(error.to_string()),
                pending,
                audio_pending,
                cancelled,
                admission,
                known_paths,
            },
        }
    }
    pub fn write_audio(&mut self, side: &str, pcm: &[u8]) {
        let remote = side.eq_ignore_ascii_case("remote");
        if pcm.is_empty() || !self.admission.audio(remote) {
            return;
        }
        if pcm.len() > 1025 {
            self.dropped += 1;
            return;
        }
        let Some(slot) = self.reserve(true) else {
            return;
        };
        let mut block = [0; 1025];
        block[..pcm.len()].copy_from_slice(pcm);
        self.enqueue(RecordJob {
            _slot: slot,
            remote,
            payload: RecordPayload::Audio {
                pcm: block,
                length: pcm.len(),
            },
        });
    }
    pub fn write_video_frame(&mut self, side: &str, pixels: &[u8], width: u32, height: u32) {
        let remote = side.eq_ignore_ascii_case("remote");
        if !self.admission.video(remote) {
            return;
        }
        if pixels.len() > MAX_VIDEO_BYTES {
            self.dropped += 1;
            return;
        }
        let Some(slot) = self.reserve(false) else {
            return;
        };
        self.enqueue(RecordJob {
            _slot: slot,
            remote,
            payload: RecordPayload::Video {
                pixels: pixels.to_vec(),
                width,
                height,
            },
        });
    }
    pub(crate) fn write_preview_frame(&mut self, frame_index: u32, pixels: &[u8]) {
        if !self.admission.previews {
            return;
        }
        if pixels.is_empty() || pixels.len() > MAX_VIDEO_BYTES {
            self.dropped += 1;
            return;
        }
        let Some(slot) = self.reserve(false) else {
            return;
        };
        self.enqueue(RecordJob {
            _slot: slot,
            remote: false,
            payload: RecordPayload::Preview {
                file_name: format!("preview_{frame_index:04}.raw"),
                pixels: pixels.to_vec(),
            },
        });
    }
    fn reserve(&mut self, audio: bool) -> Option<QueueSlot> {
        let (pending, capacity) = if audio {
            (&self.audio_pending, AUDIO_QUEUE_CAPACITY)
        } else {
            (&self.pending, QUEUE_CAPACITY)
        };
        #[allow(deprecated)]
        let slot_unavailable = self.sender.is_none()
            || pending
                .fetch_update(Ordering::AcqRel, Ordering::Acquire, |count| {
                    (count < capacity).then_some(count + 1)
                })
                .is_err();
        if slot_unavailable {
            self.dropped += 1;
            return None;
        }
        Some(QueueSlot(pending.clone()))
    }
    fn enqueue(&mut self, job: RecordJob) {
        if self
            .sender
            .as_ref()
            .is_none_or(|sender| sender.try_send(job).is_err())
        {
            self.dropped += 1;
        }
    }
    pub fn close_checked(mut self) -> DualRecordFinalize {
        self.finish()
    }
    fn finish(&mut self) -> DualRecordFinalize {
        self.sender.take();
        let mut result = match self.worker.take() {
            Some(worker) => {
                let budget = FINALIZE_BASE
                    + Duration::from_secs(1) * self.pending.load(Ordering::Acquire) as u32;
                let deadline = Instant::now() + budget;
                while !worker.is_finished() && Instant::now() < deadline {
                    std::thread::sleep(Duration::from_millis(2));
                }
                if worker.is_finished() {
                    worker.join().unwrap_or_else(|_| DualRecordFinalize {
                        warnings: vec!["recording worker panicked".into()],
                        ..Default::default()
                    })
                } else {
                    self.cancelled.store(true, Ordering::Release);
                    // Detached I/O retains its lease: another stalled worker cannot
                    // create an unbounded number of threads on subsequent sessions.
                    DualRecordFinalize {
                        result: lock_unpoison(&self.known_paths).clone(),
                        warnings: vec![format!("recording finalization exceeded {} ms; pending filesystem operation may finish later, evidence incomplete", budget.as_millis())],
                        ..Default::default()
                    }
                }
            }
            None => DualRecordFinalize::default(),
        };
        if self.dropped > 0 {
            result.warnings.push(format!(
                "recording incomplete: {} media blocks dropped by bounded recording queue",
                self.dropped
            ));
        }
        if let Some(error) = self.startup_error.take() {
            result
                .warnings
                .push(format!("recording worker unavailable: {error}"));
        }
        result
    }
}
impl RecordAdmission {
    fn new(
        mode: &str,
        local_audio: bool,
        remote_audio: bool,
        local_video: bool,
        remote_video: bool,
        previews: bool,
    ) -> Self {
        let audio = mode == "av" || mode == "audio";
        let video = mode == "av" || mode == "video";
        Self {
            local_audio: audio && local_audio,
            remote_audio: audio && remote_audio,
            local_video: video && local_video,
            remote_video: video && remote_video,
            previews,
        }
    }

    fn audio(self, remote: bool) -> bool {
        if remote {
            self.remote_audio
        } else {
            self.local_audio
        }
    }

    fn video(self, remote: bool) -> bool {
        if remote {
            self.remote_video
        } else {
            self.local_video
        }
    }
}

#[allow(clippy::too_many_arguments)]
fn open_recorder(
    root: Option<PathBuf>,
    sample_rate: u32,
    channels: u16,
    bits_per_sample: u16,
    stem: &str,
    mode: &str,
    local_audio: bool,
    remote_audio: bool,
    local_video: bool,
    remote_video: bool,
    format: &str,
) -> (Option<DualStreamRecorder>, DualRecordFinalize) {
    let Some(root) = root else {
        return (None, DualRecordFinalize::default());
    };
    match session_directory(&root, "recording") {
        Ok(directory) => (
            Some(DualStreamRecorder::with_options(
                directory,
                sample_rate,
                channels,
                bits_per_sample,
                stem,
                mode,
                local_audio,
                remote_audio,
                local_video,
                remote_video,
                format,
            )),
            DualRecordFinalize::default(),
        ),
        Err(warning) => (
            None,
            DualRecordFinalize {
                warnings: vec![warning],
                ..Default::default()
            },
        ),
    }
}

fn open_previews(root: Option<PathBuf>) -> (Option<PreviewOutput>, Option<String>) {
    let Some(root) = root else {
        return (None, None);
    };
    match session_directory(&root, "preview") {
        Ok(directory) => (Some(PreviewOutput::new(directory)), None),
        Err(warning) => (None, Some(warning)),
    }
}

fn session_directory(root: &Path, kind: &str) -> Result<PathBuf, String> {
    fs::create_dir_all(root)
        .map_err(|error| format!("create {kind} root {}: {error}", root.display()))?;
    tempfile::Builder::new()
        .prefix("session-")
        .tempdir_in(root)
        .map(|directory| directory.keep())
        .map_err(|error| format!("create {kind} session directory: {error}"))
}

impl Drop for SessionRecorder {
    fn drop(&mut self) {
        if self.worker.is_some() {
            let _ = self.finish();
        }
    }
}
fn side(remote: bool) -> &'static str {
    if remote {
        "remote"
    } else {
        "local"
    }
}

#[cfg(test)]
mod tests;
