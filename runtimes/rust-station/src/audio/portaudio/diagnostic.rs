use super::devices::load_portaudio;
use std::path::{Path, PathBuf};

/// Copies the discovered PortAudio DLL into a shipping directory when possible.
pub fn ensure_shipped_portaudio_dll(ship_dir: impl AsRef<Path>) -> Option<PathBuf> {
    let library = load_portaudio(None).ok()?;
    crate::native_loader::copy_trusted(library.path(), &ship_dir.as_ref().join("portaudio_x64.dll"))
}
