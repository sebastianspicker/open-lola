//! Bounded session recording adapter; disk and codec work runs off the scheduler.
use super::dual_recorder::{DualRecordFinalize, DualStreamRecorder};
use std::collections::VecDeque;
use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::sync::mpsc::{self, SyncSender};
use std::sync::{
    atomic::{AtomicBool, AtomicUsize, Ordering},
    Arc,
};
use std::thread::JoinHandle;
use std::time::{Duration, Instant};
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
const MAX_VIDEO_BYTES: usize = 16 * 1024 * 1024;
struct RecordJob {
    _slot: QueueSlot,
    remote: bool,
    pcm: [u8; 1025],
    payload: RecordPayload,
}
enum RecordPayload {
    Audio {
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

pub(crate) struct SessionRecorder {
    sender: Option<SyncSender<RecordJob>>,
    worker: Option<JoinHandle<DualRecordFinalize>>,
    dropped: u64,
    startup_error: Option<String>,
    pending: Arc<AtomicUsize>,
    cancelled: Arc<AtomicBool>,
    admission: RecordAdmission,
}
impl SessionRecorder {
    #[allow(clippy::too_many_arguments)]
    pub(crate) fn with_options(
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
        let pending = Arc::new(AtomicUsize::new(0));
        let cancelled = Arc::new(AtomicBool::new(false));
        let admission = RecordAdmission::new(
            mode,
            local_audio,
            remote_audio,
            local_video,
            remote_video,
            preview_root.is_some(),
        );
        if ACTIVE_WORKERS
            .fetch_update(Ordering::AcqRel, Ordering::Acquire, |active| {
                (active < 2).then_some(active + 1)
            })
            .is_err()
        {
            return Self {
                sender: None,
                worker: None,
                dropped: 0,
                startup_error: Some("two recording workers are still active".into()),
                pending,
                cancelled,
                admission,
            };
        }
        let lease = WorkerLease;
        let (stem, mode, format) = (stem.to_owned(), mode.to_owned(), format.to_owned());
        let stopping = cancelled.clone();
        let (sender, receiver) = mpsc::sync_channel::<RecordJob>(QUEUE_CAPACITY);
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
                let (mut previews, warning) = open_previews(preview_root);
                if let Some(warning) = warning {
                    finalized.warnings.push(warning);
                }
                for job in receiver {
                    if stopping.load(Ordering::Acquire) {
                        break;
                    }
                    match job.payload {
                        RecordPayload::Audio { length } => {
                            if let Some(recorder) = recorder.as_mut() {
                                recorder.write_audio(side(job.remote), &job.pcm[..length]);
                            }
                        }
                        RecordPayload::Video {
                            pixels,
                            width,
                            height,
                        } => {
                            if let Some(recorder) = recorder.as_mut() {
                                recorder.write_video_frame(
                                    side(job.remote),
                                    &pixels,
                                    width,
                                    height,
                                );
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
                cancelled,
                admission,
            },
            Err(error) => Self {
                sender: None,
                worker: None,
                dropped: 0,
                startup_error: Some(error.to_string()),
                pending,
                cancelled,
                admission,
            },
        }
    }
    pub(crate) fn write_audio(&mut self, side: &str, pcm: &[u8]) {
        let remote = side.eq_ignore_ascii_case("remote");
        if pcm.is_empty() || !self.admission.audio(remote) {
            return;
        }
        if pcm.len() > 1025 {
            self.dropped += 1;
            return;
        }
        let Some(slot) = self.reserve() else {
            return;
        };
        let mut block = [0; 1025];
        block[..pcm.len()].copy_from_slice(pcm);
        self.enqueue(RecordJob {
            _slot: slot,
            remote,
            pcm: block,
            payload: RecordPayload::Audio { length: pcm.len() },
        });
    }
    pub(crate) fn write_video_frame(
        &mut self,
        side: &str,
        pixels: &[u8],
        width: u32,
        height: u32,
    ) -> Option<PathBuf> {
        let remote = side.eq_ignore_ascii_case("remote");
        if !self.admission.video(remote) {
            return None;
        }
        if pixels.len() > MAX_VIDEO_BYTES {
            self.dropped += 1;
            return None;
        }
        let slot = self.reserve()?;
        self.enqueue(RecordJob {
            _slot: slot,
            remote,
            pcm: [0; 1025],
            payload: RecordPayload::Video {
                pixels: pixels.to_vec(),
                width,
                height,
            },
        });
        // Paths are published only after the worker has finalized actual files.
        None
    }
    pub(crate) fn write_preview_frame(&mut self, frame_index: u32, pixels: &[u8]) {
        if !self.admission.previews {
            return;
        }
        if pixels.is_empty() || pixels.len() > MAX_VIDEO_BYTES {
            self.dropped += 1;
            return;
        }
        let Some(slot) = self.reserve() else {
            return;
        };
        self.enqueue(RecordJob {
            _slot: slot,
            remote: false,
            pcm: [0; 1025],
            payload: RecordPayload::Preview {
                file_name: format!("preview_{frame_index:04}.raw"),
                pixels: pixels.to_vec(),
            },
        });
    }
    fn reserve(&mut self) -> Option<QueueSlot> {
        if self.sender.is_none()
            || self
                .pending
                .fetch_update(Ordering::AcqRel, Ordering::Acquire, |count| {
                    (count < QUEUE_CAPACITY).then_some(count + 1)
                })
                .is_err()
        {
            self.dropped += 1;
            return None;
        }
        Some(QueueSlot(self.pending.clone()))
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
    pub(crate) fn close_checked(mut self) -> DualRecordFinalize {
        self.finish()
    }
    fn finish(&mut self) -> DualRecordFinalize {
        self.sender.take();
        let mut result = match self.worker.take() {
            Some(worker) => {
                let deadline = Instant::now() + Duration::from_millis(500);
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
                    DualRecordFinalize {warnings:vec!["recording finalization exceeded 500 ms; pending filesystem operation may finish later, evidence incomplete".into()],..Default::default()}
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
        let mode = mode.to_ascii_lowercase();
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

const PREVIEW_PATH_WINDOW: usize = 128;

struct PreviewOutput {
    directory: PathBuf,
    paths: VecDeque<PathBuf>,
    omitted: u64,
    failed: bool,
    warning: Option<String>,
}

impl PreviewOutput {
    fn new(directory: PathBuf) -> Self {
        Self {
            directory,
            paths: VecDeque::with_capacity(PREVIEW_PATH_WINDOW),
            omitted: 0,
            failed: false,
            warning: None,
        }
    }

    fn write(&mut self, file_name: &str, pixels: &[u8]) {
        if self.failed {
            return;
        }
        let path = self.directory.join(file_name);
        if let Err(error) = write_preview_file(&path, pixels) {
            self.failed = true;
            self.warning = Some(format!("write preview {}: {error}", path.display()));
            return;
        }
        if self.paths.len() == PREVIEW_PATH_WINDOW {
            self.paths.pop_front();
            self.omitted = self.omitted.saturating_add(1);
        }
        self.paths.push_back(path);
    }

    fn finish(mut self, finalized: &mut DualRecordFinalize) {
        finalized.preview_paths.extend(self.paths);
        if let Some(warning) = self.warning.take() {
            finalized.warnings.push(warning);
        }
        if self.omitted > 0 {
            finalized.warnings.push(format!(
                "preview evidence incomplete: {} older completed paths omitted",
                self.omitted
            ));
        }
    }
}

fn write_preview_file(path: &Path, pixels: &[u8]) -> std::io::Result<()> {
    let mut options = fs::OpenOptions::new();
    options.write(true).create_new(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options
            .mode(0o600)
            .custom_flags(libc::O_NOFOLLOW | libc::O_NONBLOCK | libc::O_CLOEXEC);
    }
    #[cfg(windows)]
    {
        use std::os::windows::fs::OpenOptionsExt;
        options.custom_flags(0x0020_0000); // FILE_FLAG_OPEN_REPARSE_POINT
    }
    let mut file = options.open(path)?;
    if !file.metadata()?.is_file() {
        return Err(std::io::Error::new(
            std::io::ErrorKind::InvalidInput,
            "preview output must be a regular file",
        ));
    }
    file.write_all(pixels)?;
    file.flush()
}

#[cfg(test)]
mod tests;
