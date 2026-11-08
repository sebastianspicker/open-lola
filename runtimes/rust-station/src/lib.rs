//! rusty-lola Rust rewrite — LoLa-compatible low-latency A/V station.

use std::path::{Path, PathBuf};
use std::sync::Mutex;

pub mod audio;
pub mod cli;
pub mod config;
mod native_loader;
pub mod net;
pub mod protocol;
pub mod station;
pub mod tools;
pub mod ui;
pub mod video;

#[cfg(test)]
pub(crate) mod test_alloc;

pub const IDENTITY: &str = "rusty-lola";
pub const VERSION: &str = env!("CARGO_PKG_VERSION");

const XIMEA_INI: &[u8] = include_bytes!("../data/camera_modes/Ximea.ini");
const XIMEA_COLORS_INI: &[u8] = include_bytes!("../data/camera_modes/XimeaColors.ini");
const PT_GREY_INI: &[u8] = include_bytes!("../data/camera_modes/PtGrey.ini");

/// Locate the runtime resource root.
///
/// An installed distribution can provide `data/camera_modes` beside its
/// executable. Otherwise the compile-time bundled catalogs are materialized
/// in the platform temporary directory, so moving a built binary never leaves
/// it dependent on its former source checkout.
pub fn crate_root() -> PathBuf {
    // Selects data catalogs only (never code); see SECURITY.md.
    // nosemgrep
    std::env::current_exe()
        .ok()
        .as_deref()
        .and_then(resource_root_for_executable)
        .unwrap_or_else(bundled_resource_root)
}

pub fn shipped_camera_modes_dir() -> PathBuf {
    crate_root().join("data").join("camera_modes")
}

pub fn shipped_ximea_ini() -> PathBuf {
    shipped_camera_modes_dir().join("Ximea.ini")
}

pub fn shipped_ximea_colors() -> PathBuf {
    shipped_camera_modes_dir().join("XimeaColors.ini")
}

/// Staging directory `ship/` beside the running executable (never a former Cargo
/// source tree), where the shipping helpers copy vendor DLLs. The loader itself searches
/// the executable's own directory first, then the system and vendor directories listed in
/// `native_loader`; it does not search this `ship/` subdirectory.
pub fn ship_dir() -> PathBuf {
    std::env::current_exe()
        .ok()
        .and_then(|path| path.parent().map(Path::to_path_buf))
        .unwrap_or_else(crate_root)
        .join("ship")
}

fn resource_root_for_executable(executable: &Path) -> Option<PathBuf> {
    let root = executable.parent()?.to_path_buf();
    let camera_modes = root.join("data").join("camera_modes");
    ["Ximea.ini", "XimeaColors.ini", "PtGrey.ini"]
        .iter()
        .all(|name| camera_modes.join(name).is_file())
        .then_some(root)
}

static BUNDLED_ROOT: Mutex<Option<tempfile::TempDir>> = Mutex::new(None);

fn bundled_resource_root() -> PathBuf {
    let mut slot = BUNDLED_ROOT
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner);
    if let Some(root) = slot.as_ref() {
        return root.path().to_path_buf();
    }
    match materialize_bundled_resources() {
        Ok(root) => slot.insert(root).path().to_path_buf(),
        // A path that holds no catalog: callers report a missing file instead of panicking.
        Err(error) => PathBuf::from(format!("<bundled resources unavailable: {error}>")),
    }
}

fn materialize_bundled_resources() -> std::io::Result<tempfile::TempDir> {
    let root = tempfile::Builder::new()
        .prefix(&format!("rusty-lola-{VERSION}-resources-"))
        .tempdir()?;
    let camera_modes = root.path().join("data").join("camera_modes");
    std::fs::create_dir_all(&camera_modes)?;
    for (name, contents) in [
        ("Ximea.ini", XIMEA_INI),
        ("XimeaColors.ini", XIMEA_COLORS_INI),
        ("PtGrey.ini", PT_GREY_INI),
    ] {
        std::fs::write(camera_modes.join(name), contents)?;
    }
    Ok(root)
}

/// Remove the temporary bundled camera catalogs, if this run created them. Call before
/// `process::exit`, which skips destructors.
pub fn remove_bundled_resources() {
    drop(
        BUNDLED_ROOT
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
            .take(),
    );
}
