//! Preview frame files written by the recording worker.
use super::DualRecordFinalize;
use std::collections::VecDeque;
use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};

const PREVIEW_PATH_WINDOW: usize = 128;

pub(super) struct PreviewOutput {
    pub(super) directory: PathBuf,
    pub(super) paths: VecDeque<PathBuf>,
    pub(super) omitted: u64,
    pub(super) failed: bool,
    pub(super) warning: Option<String>,
}

impl PreviewOutput {
    pub(super) fn new(directory: PathBuf) -> Self {
        Self {
            directory,
            paths: VecDeque::with_capacity(PREVIEW_PATH_WINDOW),
            omitted: 0,
            failed: false,
            warning: None,
        }
    }

    pub(super) fn write(&mut self, file_name: &str, pixels: &[u8]) {
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

    pub(super) fn finish(mut self, finalized: &mut DualRecordFinalize) {
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

pub(super) fn write_preview_file(path: &Path, pixels: &[u8]) -> std::io::Result<()> {
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
