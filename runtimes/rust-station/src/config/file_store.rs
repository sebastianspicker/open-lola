//! Bounded configuration reads and private atomic replacement.
use std::io::{self, Read, Write};
use std::path::Path;

pub(crate) const MAX_CONFIGURATION_BYTES: u64 = 1024 * 1024;

pub(crate) fn read_text(path: &Path) -> io::Result<String> {
    let mut options = std::fs::OpenOptions::new();
    options.read(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.custom_flags(libc::O_NONBLOCK | libc::O_CLOEXEC | libc::O_NOCTTY);
    }
    let file = options.open(path)?;
    if !file.metadata()?.is_file() {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "configuration must be a regular file",
        ));
    }
    let mut text = String::new();
    file.take(MAX_CONFIGURATION_BYTES + 1)
        .read_to_string(&mut text)?;
    if text.len() as u64 > MAX_CONFIGURATION_BYTES {
        return Err(io::Error::new(
            io::ErrorKind::InvalidData,
            "configuration exceeds 1 MiB",
        ));
    }
    Ok(text)
}

pub(crate) fn atomic_write(path: &Path, bytes: &[u8]) -> io::Result<()> {
    if bytes.len() as u64 > MAX_CONFIGURATION_BYTES {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "configuration exceeds 1 MiB",
        ));
    }
    let parent = path
        .parent()
        .filter(|p| !p.as_os_str().is_empty())
        .unwrap_or(Path::new("."));
    std::fs::create_dir_all(parent)?;
    let mut temporary = tempfile::NamedTempFile::new_in(parent)?;
    temporary.write_all(bytes)?;
    temporary.as_file().sync_all()?;
    temporary.persist(path).map_err(|error| error.error)?;
    #[cfg(unix)]
    std::fs::File::open(parent)?.sync_all()?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    #[cfg(unix)]
    #[test]
    fn fifo_readers_are_rejected_without_waiting_for_a_writer() {
        use std::os::unix::ffi::OsStrExt;
        let directory = tempfile::tempdir().unwrap();
        let path = directory.path().join("fifo");
        let name = std::ffi::CString::new(path.as_os_str().as_bytes()).unwrap();
        // SAFETY: name is NUL terminated and points to a disposable test path.
        assert_eq!(unsafe { libc::mkfifo(name.as_ptr(), 0o600) }, 0);
        let started = std::time::Instant::now();
        assert!(read_text(&path).is_err());
        assert!(crate::tools::capture::decode_capture(&path).is_err());
        assert!(started.elapsed() < std::time::Duration::from_secs(1));
    }

    #[test]
    fn bounded_reads_and_atomic_replacement() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("settings.json");
        atomic_write(&path, b"first").unwrap();
        atomic_write(&path, b"second").unwrap();
        assert_eq!(read_text(&path).unwrap(), "second");
        std::fs::write(&path, vec![b'x'; MAX_CONFIGURATION_BYTES as usize + 1]).unwrap();
        assert!(read_text(&path).is_err());
    }
    #[cfg(unix)]
    #[test]
    fn replacement_is_private_and_does_not_follow_destination_symlink() {
        use std::os::unix::fs::{symlink, PermissionsExt};
        let dir = tempfile::tempdir().unwrap();
        let original = dir.path().join("original");
        let target = dir.path().join("settings");
        std::fs::write(&original, b"unchanged").unwrap();
        symlink(&original, &target).unwrap();
        atomic_write(&target, b"private").unwrap();
        assert_eq!(read_text(&original).unwrap(), "unchanged");
        assert_eq!(
            std::fs::metadata(target).unwrap().permissions().mode() & 0o777,
            0o600
        );
    }
}
