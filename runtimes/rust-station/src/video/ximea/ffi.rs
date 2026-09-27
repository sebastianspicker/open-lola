use super::types::*;
use libloading::Library;
use std::path::{Path, PathBuf};
use std::sync::{Mutex, OnceLock};

pub(super) fn xi_lock() -> &'static Mutex<()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    LOCK.get_or_init(|| Mutex::new(()))
}

fn search_dirs() -> Vec<PathBuf> {
    crate::native_loader::search_dirs("ximea")
}

fn candidate_paths() -> Vec<PathBuf> {
    crate::native_loader::candidate_paths(
        &search_dirs(),
        &["xiapi64.dll", "xiapi.dll", "xiapi32.dll"],
        &[],
    )
}

/// Loaded xiAPI with bound entry points (closed LoLa import surface).
pub struct XiApiLibrary {
    _lib: Library,
    path: PathBuf,
    get_number_devices: XiGetNumberDevices,
    open_device: XiOpenDevice,
    close_device: XiCloseDevice,
    start_acq: XiStartAcquisition,
    stop_acq: XiStopAcquisition,
    set_param_int: Option<XiSetParamInt>,
    get_image: Option<XiGetImage>,
}

/// Load xiAPI via LoadLibrary and bind required symbols. Returns Err if unloadable.
pub fn load_xiapi(dll_path: Option<&Path>) -> Result<XiApiLibrary, String> {
    let mut paths = Vec::new();
    if let Some(p) = dll_path {
        paths.push(p.to_path_buf());
    }
    paths.extend(candidate_paths());
    let mut last_err = "xiAPI DLL not found".to_string();
    for path in paths {
        // SAFETY: `path` is a caller-controlled candidate; loading does not expose symbols yet.
        let lib = match unsafe { crate::native_loader::load(&path) } {
            Ok(l) => l,
            Err(e) => {
                last_err = format!("load {}: {e}", path.display());
                continue;
            }
        };
        // SAFETY: xiAPI documents this symbol with the declared C ABI.
        let get_number_devices: XiGetNumberDevices =
            match unsafe { lib.get(b"xiGetNumberDevices\0") } {
                Ok(s) => *s,
                Err(e) => {
                    last_err = format!("xiGetNumberDevices: {e}");
                    continue;
                }
            };
        // SAFETY: xiAPI documents this symbol with the declared C ABI.
        let open_device: XiOpenDevice = match unsafe { lib.get(b"xiOpenDevice\0") } {
            Ok(s) => *s,
            Err(e) => {
                last_err = format!("xiOpenDevice: {e}");
                continue;
            }
        };
        // SAFETY: xiAPI documents this symbol with the declared C ABI.
        let close_device: XiCloseDevice = match unsafe { lib.get(b"xiCloseDevice\0") } {
            Ok(s) => *s,
            Err(e) => {
                last_err = format!("xiCloseDevice: {e}");
                continue;
            }
        };
        // SAFETY: xiAPI documents this symbol with the declared C ABI.
        let start_acq: XiStartAcquisition = match unsafe { lib.get(b"xiStartAcquisition\0") } {
            Ok(s) => *s,
            Err(e) => {
                last_err = format!("xiStartAcquisition: {e}");
                continue;
            }
        };
        // SAFETY: xiAPI documents this symbol with the declared C ABI.
        let stop_acq: XiStopAcquisition = match unsafe { lib.get(b"xiStopAcquisition\0") } {
            Ok(s) => *s,
            Err(e) => {
                last_err = format!("xiStopAcquisition: {e}");
                continue;
            }
        };
        // SAFETY: optional xiAPI symbols are copied while `lib` remains owned.
        let set_param_int: Option<XiSetParamInt> =
            unsafe { lib.get(b"xiSetParamInt\0").ok().map(|s| *s) };
        // SAFETY: optional xiAPI symbols are copied while `lib` remains owned.
        let get_image: Option<XiGetImage> = unsafe { lib.get(b"xiGetImage\0").ok().map(|s| *s) };
        return Ok(XiApiLibrary {
            _lib: lib,
            path: path.canonicalize().unwrap_or(path),
            get_number_devices,
            open_device,
            close_device,
            start_acq,
            stop_acq,
            set_param_int,
            get_image,
        });
    }
    Err(last_err)
}

impl XiApiLibrary {
    pub fn path(&self) -> &Path {
        &self.path
    }

    pub fn get_number_devices(&self) -> Result<u32, String> {
        let mut n = 0u32;
        // SAFETY: xiAPI writes only the valid `n` out-pointer.
        let code = unsafe { (self.get_number_devices)(&mut n) };
        if code != XI_OK {
            return Err(format!("xiGetNumberDevices failed: {code}"));
        }
        Ok(n)
    }

    pub(super) fn open_device(&self, index: u32) -> Result<*mut std::ffi::c_void, String> {
        let mut handle = std::ptr::null_mut();
        // SAFETY: xiAPI writes only the valid `handle` out-pointer.
        let code = unsafe { (self.open_device)(index, &mut handle) };
        if code != XI_OK || handle.is_null() {
            return Err(format!("xiOpenDevice({index}) failed: {code}"));
        }
        Ok(handle)
    }

    pub(super) fn close_device(&self, handle: *mut std::ffi::c_void) {
        if !handle.is_null() {
            // SAFETY: caller owns this xiAPI handle and it is non-null.
            let _ = unsafe { (self.close_device)(handle) };
        }
    }

    pub(super) fn start_acquisition(&self, handle: *mut std::ffi::c_void) -> Result<(), String> {
        // SAFETY: caller owns this live xiAPI handle.
        let code = unsafe { (self.start_acq)(handle) };
        if code != XI_OK {
            return Err(format!("xiStartAcquisition failed: {code}"));
        }
        Ok(())
    }

    pub(super) fn stop_acquisition(&self, handle: *mut std::ffi::c_void) {
        if !handle.is_null() {
            // SAFETY: caller owns this live xiAPI handle.
            let _ = unsafe { (self.stop_acq)(handle) };
        }
    }

    pub(super) fn stop_acquisition_checked(
        &self,
        handle: *mut std::ffi::c_void,
    ) -> XimeaResult<()> {
        // SAFETY: caller owns this live xiAPI handle.
        let code = unsafe { (self.stop_acq)(handle) };
        if code != XI_OK {
            return Err(XimeaError::Native {
                operation: "xiStopAcquisition",
                detail: code.to_string(),
            });
        }
        Ok(())
    }

    pub(super) fn close_device_checked(&self, handle: *mut std::ffi::c_void) -> XimeaResult<()> {
        // SAFETY: caller owns this live xiAPI handle.
        let code = unsafe { (self.close_device)(handle) };
        if code != XI_OK {
            return Err(XimeaError::Native {
                operation: "xiCloseDevice",
                detail: code.to_string(),
            });
        }
        Ok(())
    }

    pub(super) fn set_param_int_checked(
        &self,
        handle: *mut std::ffi::c_void,
        name: &str,
        value: i32,
    ) -> XimeaResult<()> {
        let f = self.set_param_int.ok_or_else(|| XimeaError::Native {
            operation: "xiSetParamInt",
            detail: "symbol not bound".into(),
        })?;
        let name = std::ffi::CString::new(name).map_err(|_| XimeaError::Native {
            operation: "xiSetParamInt",
            detail: "parameter name contains an interior NUL".into(),
        })?;
        // SAFETY: handle and NUL-terminated name remain valid for this call.
        let code = unsafe { f(handle, name.as_ptr(), value) };
        if code != XI_OK {
            return Err(XimeaError::Native {
                operation: "xiSetParamInt",
                detail: format!("{value} for `{}` returned {code}", name.to_string_lossy()),
            });
        }
        Ok(())
    }

    /// Try xiGetImage; returns copied pixels so no vendor pointer crosses this boundary.
    pub(super) fn get_image(
        &self,
        handle: *mut std::ffi::c_void,
        timeout_ms: u32,
    ) -> Result<(Vec<u8>, u32, u32, String), String> {
        let f = self
            .get_image
            .ok_or_else(|| "xiGetImage not bound".to_string())?;
        let mut img = XiImg {
            size: std::mem::size_of::<XiImg>() as u32,
            bp: std::ptr::null_mut(),
            bp_size: 0,
            frm: 0,
            width: 0,
            height: 0,
            nframe: 0,
            ts_sec: 0,
            ts_usec: 0,
            gpi_level: 0,
            black_level: 0,
            padding_x: 0,
            absolute_offset_x: 0,
            absolute_offset_y: 0,
        };
        // SAFETY: xiAPI writes only the valid `img` structure during this call.
        let code = unsafe { f(handle, timeout_ms, &mut img) };
        if code != XI_OK {
            return Err(format!("xiGetImage failed: {code}"));
        }
        if img.bp.is_null() || img.bp_size == 0 || img.width == 0 || img.height == 0 {
            return Err("xiGetImage returned empty buffer".into());
        }
        let len = img.bp_size as usize;
        let mut pixels = vec![0; len];
        // SAFETY: xiAPI returned a non-null buffer and a bounded byte count.
        unsafe {
            std::ptr::copy_nonoverlapping(img.bp.cast::<u8>(), pixels.as_mut_ptr(), len);
        }
        let fmt = match img.frm {
            XI_MONO8 => "Mono8".to_string(),
            XI_RGB24 => "RGB24".to_string(),
            code => format!("xiAPI({code})"),
        };
        Ok((pixels, img.width, img.height, fmt))
    }
}
