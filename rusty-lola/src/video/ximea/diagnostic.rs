use super::ffi::{load_xiapi, xi_lock};
use serde_json::{json, Value};
use std::path::{Path, PathBuf};

#[derive(Debug, Clone)]
pub struct CameraBackendInfo {
    pub name: String,
    pub available: bool,
    pub library_path: Option<PathBuf>,
    pub reason: String,
    pub device_count: Option<u32>,
    pub loaded: bool,
}

impl CameraBackendInfo {
    pub fn to_json(&self) -> Value {
        json!({ "name": self.name, "available": self.available, "library_path": self.library_path.as_ref().map(|p| p.display().to_string()), "reason": self.reason, "device_count": self.device_count, "loaded": self.loaded })
    }
}

/// Probe: true only when DLL actually loads and required symbols bind.
pub fn probe_ximea() -> CameraBackendInfo {
    let _g = xi_lock().lock().unwrap_or_else(|e| e.into_inner());
    match load_xiapi(None) {
        Ok(lib) => {
            let device_count = lib.get_number_devices().ok();
            CameraBackendInfo {
                name: "ximea".into(),
                available: true,
                library_path: Some(lib.path().to_path_buf()),
                reason: match device_count {
                    Some(0) => format!("loaded {}; 0 devices", lib.path().display()),
                    Some(n) => format!("loaded {}; {n} device(s)", lib.path().display()),
                    None => format!("loaded {}; device enum failed", lib.path().display()),
                },
                device_count,
                loaded: true,
            }
        }
        Err(e) => CameraBackendInfo {
            name: "ximea".into(),
            available: false,
            library_path: None,
            reason: e,
            device_count: None,
            loaded: false,
        },
    }
}

/// Copies the discovered xiAPI DLL into a shipping directory when possible.
pub fn ensure_shipped_ximea_dll(ship_dir: impl AsRef<Path>) -> Option<PathBuf> {
    let ship = ship_dir.as_ref();
    let _ = std::fs::create_dir_all(ship);
    let dest = ship.join("xiapi64.dll");
    if dest.is_file() {
        return Some(dest);
    }
    if let Ok(lib) = load_xiapi(None) {
        let src = lib.path().to_path_buf();
        if std::fs::copy(&src, &dest).is_ok() {
            return Some(dest);
        }
    }
    if let Ok(manifest) = std::env::var("CARGO_MANIFEST_DIR") {
        let archive = PathBuf::from(manifest)
            .join("..")
            .join("archive")
            .join("lola-closed-2.0")
            .join("xiapi64.dll");
        if archive.is_file() && std::fs::copy(&archive, &dest).is_ok() {
            return Some(dest);
        }
    }
    None
}
