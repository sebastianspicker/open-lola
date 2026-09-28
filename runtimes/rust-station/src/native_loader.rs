//! Explicit native DLL trust locations shared by device and packet adapters.
use std::path::{Path, PathBuf};

pub(crate) fn search_dirs(component: &str) -> Vec<PathBuf> {
    if !cfg!(windows) {
        return Vec::new();
    }
    let mut dirs = vec![PathBuf::from(r"C:\Windows\System32")];
    match component {
        "ximea" => dirs.push(PathBuf::from(r"C:\Program Files\XIMEA\API\xiAPI")),
        "pcap" => dirs.insert(0, PathBuf::from(r"C:\Windows\System32\Npcap")),
        "portaudio" => dirs.push(PathBuf::from(r"C:\Program Files\Open LoLa\portaudio")),
        _ => {}
    }
    dirs
}

pub(crate) fn candidate_paths(
    dirs: &[PathBuf],
    names: &[&str],
    trailing: &[PathBuf],
) -> Vec<PathBuf> {
    names
        .iter()
        .flat_map(|name| dirs.iter().map(move |dir| dir.join(name)))
        .chain(trailing.iter().cloned())
        .filter(|path| path.is_absolute() && path.is_file())
        .collect()
}

fn validated_path(path: &Path) -> Result<PathBuf, String> {
    if !path.is_absolute()
        || path
            .components()
            .any(|p| matches!(p, std::path::Component::ParentDir))
    {
        return Err("native library requires an absolute trusted installation path".into());
    }
    let canonical = path.canonicalize().map_err(|error| error.to_string())?;
    let trusted = ["ximea", "portaudio", "pcap"]
        .iter()
        .flat_map(|name| search_dirs(name))
        .any(|dir| {
            dir.canonicalize()
                .is_ok_and(|dir| canonical.parent() == Some(dir.as_path()))
        });
    if !trusted || !canonical.is_file() {
        return Err(
            "native library is outside trusted system/vendor installation directories".into(),
        );
    }
    Ok(canonical)
}

/// Load only an explicit system/vendor path; dependencies use that directory and System32.
///
/// # Safety
/// The caller must bind symbols to the vendor's correct ABI and retain the library.
pub(crate) unsafe fn load(path: &Path) -> Result<libloading::Library, String> {
    let path = validated_path(path)?;
    #[cfg(windows)]
    {
        use libloading::os::windows::{
            Library, LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR, LOAD_LIBRARY_SEARCH_SYSTEM32,
        };
        // SAFETY: validated absolute DLL path; dependency search excludes PATH and working directory.
        unsafe {
            Library::load_with_flags(
                path,
                LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_SYSTEM32,
            )
        }
        .map(Into::into)
        .map_err(|error| error.to_string())
    }
    #[cfg(not(windows))]
    {
        let _ = path;
        Err("Windows native DLL backends are unsupported on this platform".into())
    }
}

pub(crate) fn copy_trusted(source: &Path, destination: &Path) -> Option<PathBuf> {
    let source = validated_path(source).ok()?;
    let parent = destination.parent()?;
    std::fs::create_dir_all(parent).ok()?;
    let mut input = std::fs::File::open(source).ok()?;
    let mut output = tempfile::NamedTempFile::new_in(parent).ok()?;
    std::io::copy(&mut input, &mut output).ok()?;
    output.as_file().sync_all().ok()?;
    output.persist_noclobber(destination).ok()?;
    Some(destination.to_path_buf())
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn rejects_ambient_and_untrusted_paths() {
        for path in ["wpcap.dll", "ship/xiapi64.dll", "../archive/portaudio.dll"] {
            assert!(validated_path(Path::new(path)).is_err());
        }
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("wpcap.dll");
        std::fs::write(&path, b"not a library").unwrap();
        assert!(validated_path(&path).is_err());
        assert!(candidate_paths(&[], &["wpcap.dll"], &[]).is_empty());
    }
}
