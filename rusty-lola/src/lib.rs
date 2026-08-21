//! rusty-lola Rust rewrite — LoLa-compatible low-latency A/V station.

use std::path::{Path, PathBuf};
use std::sync::OnceLock;

pub mod audio;
pub mod cli;
pub mod config;
pub mod net;
pub mod protocol;
pub mod station;
pub mod tools;
pub mod ui;
pub mod video;

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

/// Optional vendor DLLs live next to the running executable, never in a
/// former Cargo source tree.
pub fn ship_dir() -> PathBuf {
    std::env::current_exe()
        .ok()
        .and_then(|path| path.parent().map(Path::to_path_buf))
        .unwrap_or_else(crate_root)
        .join("ship")
}

pub(crate) fn native_library_search_dirs(component: &str) -> [PathBuf; 2] {
    native_library_search_dirs_for(&ship_dir(), component)
}

fn native_library_search_dirs_for(ship: &Path, component: &str) -> [PathBuf; 2] {
    [ship.join(component), ship.to_path_buf()]
}

fn resource_root_for_executable(executable: &Path) -> Option<PathBuf> {
    let root = executable.parent()?.to_path_buf();
    let camera_modes = root.join("data").join("camera_modes");
    ["Ximea.ini", "XimeaColors.ini", "PtGrey.ini"]
        .iter()
        .all(|name| camera_modes.join(name).is_file())
        .then_some(root)
}

fn bundled_resource_root() -> PathBuf {
    static ROOT: OnceLock<tempfile::TempDir> = OnceLock::new();
    ROOT.get_or_init(|| {
        let root = tempfile::Builder::new()
            .prefix(&format!("rusty-lola-{VERSION}-resources-"))
            .tempdir()
            .expect("create private bundled-resource directory");
        let camera_modes = root.path().join("data").join("camera_modes");
        std::fs::create_dir_all(&camera_modes).expect("create bundled camera catalog directory");
        for (name, contents) in [
            ("Ximea.ini", XIMEA_INI),
            ("XimeaColors.ini", XIMEA_COLORS_INI),
            ("PtGrey.ini", PT_GREY_INI),
        ] {
            let path = camera_modes.join(name);
            std::fs::write(path, contents).expect("materialize bundled camera catalog");
        }
        root
    })
    .path()
    .to_path_buf()
}
