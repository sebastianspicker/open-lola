use super::devices::load_portaudio;
use std::path::{Path, PathBuf};

/// Copies the discovered PortAudio DLL into a shipping directory when possible.
pub fn ensure_shipped_portaudio_dll(ship_dir: impl AsRef<Path>) -> Option<PathBuf> {
    let ship = ship_dir.as_ref();
    let _ = std::fs::create_dir_all(ship);
    let dest = ship.join("portaudio_x64.dll");
    if dest.is_file() {
        return Some(dest);
    }
    if let Ok(lib) = load_portaudio(None) {
        if std::fs::copy(lib.path(), &dest).is_ok() {
            return Some(dest);
        }
    }
    if let Ok(manifest) = std::env::var("CARGO_MANIFEST_DIR") {
        let archive = PathBuf::from(manifest)
            .join("..")
            .join("archive")
            .join("lola-closed-2.0")
            .join("portaudio_x64.dll");
        if archive.is_file() && std::fs::copy(&archive, &dest).is_ok() {
            return Some(dest);
        }
    }
    None
}
