//! Explicit native DLL trust locations shared by device and packet adapters.
//!
//! A DLL is loaded only from an absolute path in one of these locations, in search order:
//! 1. `C:\Windows\System32` (and `Npcap` below it for the packet library);
//! 2. the component's vendor installation directory;
//! 3. the running executable's own directory (an app-local DLL, known file names only).
//!
//! The executable directory is allowed (an app-local copy is a supported deployment) but
//! comes last: an installed library is preferred, and a copy planted next to the executable
//! only acts as a fallback. It is restricted to the file names this crate asks for, so it
//! cannot be used to load an arbitrary library, and an executable directory on a UNC or
//! network path is refused. Candidate selection skips any file the location rules would
//! reject, so a rejected file cannot shadow a valid one. This allowlist applies to the
//! top-level DLL only; its imports resolve through `LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR`
//! from that DLL's directory, then System32.
use std::path::{Path, PathBuf};

/// File names the adapters request; the only names accepted from the executable directory.
const KNOWN_DLL_NAMES: &[&str] = &[
    "xiapi64.dll",
    "xiapi.dll",
    "xiapi32.dll",
    "portaudio_x64.dll",
    "portaudio.dll",
    "portaudio_x86.dll",
    "wpcap.dll",
    "Packet.dll",
];

/// Whether a Windows path is a UNC or network path (`\\server\share` or `\\?\UNC\...`).
fn is_network_path(path: &Path) -> bool {
    let text = path
        .to_string_lossy()
        .replace('/', "\\")
        .to_ascii_uppercase();
    text.starts_with(r"\\?\UNC\")
        || (text.starts_with(r"\\") && !text.starts_with(r"\\?\") && !text.starts_with(r"\\.\"))
}

/// The executable's directory, unless it is on a network path.
fn executable_dir() -> Option<PathBuf> {
    std::env::current_exe()
        .ok()
        .and_then(|path| path.parent().map(Path::to_path_buf))
        .filter(|dir| !is_network_path(dir))
}

/// System and vendor directories for `component` (empty off Windows).
fn system_dirs_for(component: &str, windows: bool) -> Vec<PathBuf> {
    if !windows {
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

fn search_dirs_with(component: &str, exe_dir: Option<PathBuf>, windows: bool) -> Vec<PathBuf> {
    if !windows {
        return Vec::new();
    }
    system_dirs_for(component, windows)
        .into_iter()
        .chain(exe_dir.filter(|dir| !is_network_path(dir)))
        .collect()
}

/// System and vendor directories only, for system libraries that never ship app-local.
#[cfg(windows)]
pub(crate) fn system_search_dirs(component: &str) -> Vec<PathBuf> {
    system_dirs_for(component, cfg!(windows))
}

pub(crate) fn search_dirs(component: &str) -> Vec<PathBuf> {
    search_dirs_with(component, executable_dir(), cfg!(windows))
}

fn is_known_dll_name(name: &std::ffi::OsStr) -> bool {
    name.to_str().is_some_and(|name| {
        KNOWN_DLL_NAMES
            .iter()
            .any(|known| known.eq_ignore_ascii_case(name))
    })
}

/// Whether a canonical library path is in a trusted location. System and vendor
/// directories keep accepting any file name; the executable directory accepts only the
/// known names.
fn location_allows(canonical: &Path, system_dirs: &[PathBuf], exe_dir: Option<&Path>) -> bool {
    let Some(parent) = canonical.parent() else {
        return false;
    };
    if system_dirs.iter().any(|dir| dir.as_path() == parent) {
        return true;
    }
    exe_dir == Some(parent) && canonical.file_name().is_some_and(is_known_dll_name)
}

/// Existing candidates in search order (directory first, then name), limited to the ones
/// `validated_path` accepts so a rejected file never shadows a valid one.
pub(crate) fn candidate_paths(
    dirs: &[PathBuf],
    names: &[&str],
    trailing: &[PathBuf],
) -> Vec<PathBuf> {
    candidate_paths_where(dirs, names, trailing, |path| validated_path(path).is_ok())
}

fn candidate_paths_where(
    dirs: &[PathBuf],
    names: &[&str],
    trailing: &[PathBuf],
    allowed: impl Fn(&Path) -> bool,
) -> Vec<PathBuf> {
    dirs.iter()
        .flat_map(|dir| names.iter().map(move |name| dir.join(name)))
        .chain(trailing.iter().cloned())
        .filter(|path| path.is_absolute() && path.is_file() && allowed(path))
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
    let canonical_dirs = |dirs: Vec<PathBuf>| -> Vec<PathBuf> {
        dirs.into_iter()
            .filter_map(|dir| dir.canonicalize().ok())
            .collect()
    };
    let system_dirs = canonical_dirs(
        ["ximea", "portaudio", "pcap"]
            .iter()
            .flat_map(|name| system_dirs_for(name, cfg!(windows)))
            .collect(),
    );
    let exe_dir = executable_dir()
        .and_then(|dir| dir.canonicalize().ok())
        .filter(|dir| !is_network_path(dir));
    if !location_allows(&canonical, &system_dirs, exe_dir.as_deref()) || !canonical.is_file() {
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

    #[test]
    fn executable_directory_is_searched_last_on_windows_only() {
        let exe = PathBuf::from(r"D:\app");
        let dirs = search_dirs_with("portaudio", Some(exe.clone()), true);
        assert_eq!(dirs[0], PathBuf::from(r"C:\Windows\System32"));
        assert_eq!(
            dirs[1],
            PathBuf::from(r"C:\Program Files\Open LoLa\portaudio")
        );
        assert_eq!(dirs.last(), Some(&exe));
        assert!(search_dirs_with("portaudio", Some(exe), false).is_empty());
        let pcap = search_dirs_with("pcap", Some(PathBuf::from(r"D:\app")), true);
        assert_eq!(pcap[0], PathBuf::from(r"C:\Windows\System32\Npcap"));
        assert_eq!(pcap[1], PathBuf::from(r"C:\Windows\System32"));
        assert_eq!(pcap.last(), Some(&PathBuf::from(r"D:\app")));
    }

    #[test]
    fn network_executable_directories_are_refused() {
        for network in [
            r"\\?\UNC\server\share\app",
            r"\\?\unc\server\share",
            r"\\server\share\app",
            "//server/share/app",
        ] {
            assert!(is_network_path(Path::new(network)), "{network}");
            let dirs = search_dirs_with("ximea", Some(PathBuf::from(network)), true);
            assert!(!dirs.contains(&PathBuf::from(network)), "{network}");
            assert_eq!(dirs.len(), 2, "{network}");
        }
        for local in [r"D:\app", r"\\?\C:\app", r"\\.\C:\app", "/usr/bin"] {
            assert!(!is_network_path(Path::new(local)), "{local}");
        }
    }

    #[test]
    fn media_foundation_searches_system32_only() {
        assert_eq!(
            system_dirs_for("mediafoundation", true),
            vec![PathBuf::from(r"C:\Windows\System32")]
        );
    }

    #[test]
    fn executable_directory_accepts_known_names_only() {
        let exe = PathBuf::from("/app");
        let system = [PathBuf::from("/system")];
        for name in [
            "portaudio_x64.dll",
            "PORTAUDIO.DLL",
            "xiapi64.dll",
            "wpcap.dll",
        ] {
            let path = exe.join(name);
            assert!(location_allows(&path, &system, Some(&exe)), "{name}");
        }
        for name in ["evil.dll", "kernel32.dll", "portaudio.dll.bak"] {
            let path = exe.join(name);
            assert!(!location_allows(&path, &system, Some(&exe)), "{name}");
        }
        // System and vendor directories are unchanged: any file name remains accepted.
        assert!(location_allows(
            &system[0].join("iphlpapi.dll"),
            &system,
            Some(&exe)
        ));
        // Other directories, subdirectories of the executable directory, and a missing
        // executable directory are all rejected.
        assert!(!location_allows(
            Path::new("/other/portaudio.dll"),
            &system,
            Some(&exe)
        ));
        assert!(!location_allows(
            &exe.join("sub").join("portaudio.dll"),
            &system,
            Some(&exe)
        ));
        assert!(!location_allows(&exe.join("portaudio.dll"), &system, None));
    }

    #[test]
    fn candidate_paths_include_an_existing_executable_directory_file() {
        let dir = tempfile::tempdir().unwrap();
        std::fs::write(dir.path().join("portaudio.dll"), b"x").unwrap();
        let dirs = search_dirs_with("portaudio", Some(dir.path().to_path_buf()), true);
        let names = ["portaudio_x64.dll", "portaudio.dll"];
        let found = candidate_paths_where(&dirs, &names, &[], |_| true);
        assert_eq!(found, vec![dir.path().join("portaudio.dll")]);
        assert!(candidate_paths_where(&dirs, &["not-requested.dll"], &[], |_| true).is_empty());
    }

    #[test]
    fn earlier_directories_win_over_earlier_names() {
        let system = tempfile::tempdir().unwrap();
        let app = tempfile::tempdir().unwrap();
        std::fs::write(system.path().join("xiapi.dll"), b"x").unwrap();
        std::fs::write(app.path().join("xiapi64.dll"), b"x").unwrap();
        let dirs = [system.path().to_path_buf(), app.path().to_path_buf()];
        let found = candidate_paths_where(&dirs, &["xiapi64.dll", "xiapi.dll"], &[], |_| true);
        assert_eq!(
            found,
            vec![
                system.path().join("xiapi.dll"),
                app.path().join("xiapi64.dll")
            ]
        );
    }

    #[test]
    fn a_rejected_candidate_never_shadows_a_valid_one() {
        let bad = tempfile::tempdir().unwrap();
        let good = tempfile::tempdir().unwrap();
        std::fs::write(bad.path().join("wpcap.dll"), b"x").unwrap();
        std::fs::write(good.path().join("wpcap.dll"), b"x").unwrap();
        let dirs = [bad.path().to_path_buf(), good.path().to_path_buf()];
        let found = candidate_paths_where(&dirs, &["wpcap.dll"], &[], |path| {
            path.starts_with(good.path())
        });
        assert_eq!(found, vec![good.path().join("wpcap.dll")]);
        // The public selection applies the real location rules: a temp directory is neither
        // a system, vendor nor executable directory, so nothing is offered.
        assert!(candidate_paths(&dirs, &["wpcap.dll"], &[]).is_empty());
    }
}
