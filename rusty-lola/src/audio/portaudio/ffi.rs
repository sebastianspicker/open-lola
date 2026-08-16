use super::*;
use std::ffi::c_ulong;

pub(super) const PA_NO_ERROR: i32 = 0;
/// C `unsigned long` aliases copied from `portaudio.h`.
pub(super) type PaSampleFormat = c_ulong;
pub(super) type PaStreamFlags = c_ulong;
pub(super) type PaFramesPerBuffer = c_ulong;
pub(super) type PaStreamCallbackFlags = c_ulong;

pub(super) const PA_INT32: PaSampleFormat = 0x0000_0002;
pub(super) const PA_INT24: PaSampleFormat = 0x0000_0004;
pub(super) const PA_INT16: PaSampleFormat = 0x0000_0008;
pub(super) const PA_INT8: PaSampleFormat = 0x0000_0010;
pub(super) const PA_NO_FLAG: PaStreamFlags = 0;
pub(super) const PA_CONTINUE: i32 = 0;
/// `paInputOverflow` from `portaudio.h`.
pub(super) const PA_INPUT_OVERFLOW: PaStreamCallbackFlags = 0x0000_0002;
/// `paOutputUnderflow` from `portaudio.h`.
pub(super) const PA_OUTPUT_UNDERFLOW: PaStreamCallbackFlags = 0x0000_0004;
/// `paASIO` from `portaudio.h`'s `PaHostApiTypeId` enum.
pub(super) const PA_ASIO: i32 = 3;

pub(super) type PaInitialize = unsafe extern "C" fn() -> i32;
pub(super) type PaTerminate = unsafe extern "C" fn() -> i32;
pub(super) type PaGetDeviceCount = unsafe extern "C" fn() -> i32;
pub(super) type PaGetDefaultInputDevice = unsafe extern "C" fn() -> i32;
pub(super) type PaGetDefaultOutputDevice = unsafe extern "C" fn() -> i32;
pub(super) type PaGetDeviceInfo = unsafe extern "C" fn(i32) -> *const PaDeviceInfo;
pub(super) type PaGetHostApiInfo = unsafe extern "C" fn(i32) -> *const PaHostApiInfo;
pub(super) type PaGetErrorText = unsafe extern "C" fn(i32) -> *const i8;
pub(super) type PaOpenStream = unsafe extern "C" fn(
    *mut *mut std::ffi::c_void,
    *const PaStreamParameters,
    *const PaStreamParameters,
    f64,
    PaFramesPerBuffer,
    PaStreamFlags,
    *mut std::ffi::c_void,
    *mut std::ffi::c_void,
) -> i32;
pub(super) type PaCloseStream = unsafe extern "C" fn(*mut std::ffi::c_void) -> i32;
pub(super) type PaStartStream = unsafe extern "C" fn(*mut std::ffi::c_void) -> i32;
pub(super) type PaStopStream = unsafe extern "C" fn(*mut std::ffi::c_void) -> i32;
pub(super) type PaReadStream =
    unsafe extern "C" fn(*mut std::ffi::c_void, *mut std::ffi::c_void, PaFramesPerBuffer) -> i32;
pub(super) type PaWriteStream =
    unsafe extern "C" fn(*mut std::ffi::c_void, *const std::ffi::c_void, PaFramesPerBuffer) -> i32;
pub(super) type PaStreamCallback = unsafe extern "C" fn(
    *const std::ffi::c_void,
    *mut std::ffi::c_void,
    PaFramesPerBuffer,
    *const PaStreamCallbackTimeInfo,
    PaStreamCallbackFlags,
    *mut std::ffi::c_void,
) -> i32;

#[repr(C)]
pub(super) struct PaStreamCallbackTimeInfo {
    input_buffer_adc_time: f64,
    current_time: f64,
    output_buffer_dac_time: f64,
}

/// C layout copied from `portaudio.h`. It is only dereferenced while the leaked
/// process-lifetime PortAudio library is loaded and `pa_lock` is held.
#[repr(C)]
pub(super) struct PaDeviceInfo {
    pub(super) struct_version: i32,
    pub(super) name: *const i8,
    pub(super) host_api: i32,
    pub(super) max_input_channels: i32,
    pub(super) max_output_channels: i32,
    pub(super) default_low_input_latency: f64,
    pub(super) default_low_output_latency: f64,
    pub(super) default_high_input_latency: f64,
    pub(super) default_high_output_latency: f64,
    pub(super) default_sample_rate: f64,
}

/// C layout copied from `portaudio.h`. `type_` is `PaHostApiTypeId` and must
/// equal `paASIO` for a stream opened by the strict ASIO backend.
#[repr(C)]
pub(super) struct PaHostApiInfo {
    pub(super) struct_version: i32,
    pub(super) type_: i32,
    pub(super) name: *const i8,
    pub(super) device_count: i32,
    pub(super) default_input_device: i32,
    pub(super) default_output_device: i32,
}

#[repr(C)]
pub(super) struct PaStreamParameters {
    pub(super) device: i32,
    pub(super) channel_count: i32,
    pub(super) sample_format: PaSampleFormat,
    pub(super) suggested_latency: f64,
    pub(super) host_api_specific_stream_info: *mut std::ffi::c_void,
}

#[cfg(windows)]
const _: () = {
    assert!(std::mem::size_of::<c_ulong>() == 4);
    assert!(std::mem::size_of::<PaSampleFormat>() == std::mem::size_of::<c_ulong>());
    assert!(std::mem::size_of::<PaStreamFlags>() == std::mem::size_of::<c_ulong>());
    assert!(std::mem::size_of::<PaFramesPerBuffer>() == std::mem::size_of::<c_ulong>());
    assert!(std::mem::size_of::<PaStreamCallbackFlags>() == std::mem::size_of::<c_ulong>());
};

/// Bound function pointers + path. Library is leaked (never unloaded).
pub(super) struct PaFns {
    pub(super) path: PathBuf,
    pub(super) initialize: PaInitialize,
    #[allow(dead_code)]
    pub(super) terminate: PaTerminate,
    pub(super) get_device_count: PaGetDeviceCount,
    pub(super) get_default_input: Option<PaGetDefaultInputDevice>,
    pub(super) get_default_output: Option<PaGetDefaultOutputDevice>,
    pub(super) get_device_info: Option<PaGetDeviceInfo>,
    pub(super) get_host_api_info: Option<PaGetHostApiInfo>,
    pub(super) get_error_text: Option<PaGetErrorText>,
    pub(super) open_stream: PaOpenStream,
    pub(super) close_stream: PaCloseStream,
    pub(super) start_stream: PaStartStream,
    pub(super) stop_stream: PaStopStream,
    pub(super) read_stream: PaReadStream,
    pub(super) write_stream: PaWriteStream,
    pub(super) initialized: bool,
}

/// Process-wide PA state: either failed permanently, or ready with leaked DLL.
pub(super) enum PaGlobal {
    Failed(String),
    Ready(Box<PaFns>),
}

pub(super) fn pa_lock() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    LOCK.get_or_init(|| Mutex::new(()))
        .lock()
        .unwrap_or_else(|e| e.into_inner())
}

pub(super) fn pa_global() -> &'static Mutex<Option<PaGlobal>> {
    static GLOBAL: OnceLock<Mutex<Option<PaGlobal>>> = OnceLock::new();
    GLOBAL.get_or_init(|| Mutex::new(None))
}

pub(super) fn search_dirs() -> Vec<PathBuf> {
    let mut dirs = crate::native_library_search_dirs("portaudio").to_vec();
    if let Ok(manifest) = std::env::var("CARGO_MANIFEST_DIR") {
        let root = PathBuf::from(manifest);
        dirs.push(root.join("ship").join("portaudio"));
        dirs.push(root.join("ship"));
        dirs.push(root.join("..").join("archive").join("lola-closed-2.0"));
    }
    dirs.push(PathBuf::from(r"C:\Windows\System32"));
    if let Ok(p) = std::env::var("PATH") {
        for part in p.split(';') {
            if !part.is_empty() {
                dirs.push(PathBuf::from(part));
            }
        }
    }
    dirs
}

pub(super) fn candidate_paths() -> Vec<PathBuf> {
    let mut out = Vec::new();
    for name in ["portaudio_x64.dll", "portaudio.dll", "portaudio_x86.dll"] {
        for dir in search_dirs() {
            let p = dir.join(name);
            if p.is_file() {
                out.push(p);
            }
        }
        out.push(PathBuf::from(name));
    }
    out
}

/// Load DLL once and bind symbols. Caller must hold `pa_lock`.
/// The `Library` is intentionally leaked so FreeLibrary never runs mid-process.
pub(super) fn ensure_pa_loaded_locked() -> Result<(), String> {
    let mut slot = pa_global().lock().unwrap_or_else(|e| e.into_inner());
    if slot.is_some() {
        return match slot.as_ref().unwrap() {
            PaGlobal::Failed(e) => Err(e.clone()),
            PaGlobal::Ready(_) => Ok(()),
        };
    }

    let mut last_err = "PortAudio DLL not found".to_string();
    for path in candidate_paths() {
        // SAFETY: the surrounding PortAudio ownership and pointer checks establish the operation preconditions.
        let lib = match unsafe { Library::new(&path) } {
            Ok(l) => l,
            Err(e) => {
                last_err = format!("load {}: {e}", path.display());
                continue;
            }
        };
        // SAFETY: the surrounding PortAudio ownership and pointer checks establish the operation preconditions.
        let initialize: PaInitialize = match unsafe { lib.get(b"Pa_Initialize\0") } {
            Ok(s) => *s,
            Err(e) => {
                last_err = format!("Pa_Initialize: {e}");
                continue;
            }
        };
        // SAFETY: the surrounding PortAudio ownership and pointer checks establish the operation preconditions.
        let terminate: PaTerminate = match unsafe { lib.get(b"Pa_Terminate\0") } {
            Ok(s) => *s,
            Err(e) => {
                last_err = format!("Pa_Terminate: {e}");
                continue;
            }
        };
        // SAFETY: the surrounding PortAudio ownership and pointer checks establish the operation preconditions.
        let get_device_count: PaGetDeviceCount = match unsafe { lib.get(b"Pa_GetDeviceCount\0") } {
            Ok(s) => *s,
            Err(e) => {
                last_err = format!("Pa_GetDeviceCount: {e}");
                continue;
            }
        };
        // SAFETY: the surrounding PortAudio ownership and pointer checks establish the operation preconditions.
        let open_stream: PaOpenStream = match unsafe { lib.get(b"Pa_OpenStream\0") } {
            Ok(s) => *s,
            Err(e) => {
                last_err = format!("Pa_OpenStream: {e}");
                continue;
            }
        };
        // SAFETY: the surrounding PortAudio ownership and pointer checks establish the operation preconditions.
        let close_stream: PaCloseStream = match unsafe { lib.get(b"Pa_CloseStream\0") } {
            Ok(s) => *s,
            Err(e) => {
                last_err = format!("Pa_CloseStream: {e}");
                continue;
            }
        };
        // SAFETY: the surrounding PortAudio ownership and pointer checks establish the operation preconditions.
        let start_stream: PaStartStream = match unsafe { lib.get(b"Pa_StartStream\0") } {
            Ok(s) => *s,
            Err(e) => {
                last_err = format!("Pa_StartStream: {e}");
                continue;
            }
        };
        // SAFETY: the surrounding PortAudio ownership and pointer checks establish the operation preconditions.
        let stop_stream: PaStopStream = match unsafe { lib.get(b"Pa_StopStream\0") } {
            Ok(s) => *s,
            Err(e) => {
                last_err = format!("Pa_StopStream: {e}");
                continue;
            }
        };
        // SAFETY: the surrounding PortAudio ownership and pointer checks establish the operation preconditions.
        let read_stream: PaReadStream = match unsafe { lib.get(b"Pa_ReadStream\0") } {
            Ok(s) => *s,
            Err(e) => {
                last_err = format!("Pa_ReadStream: {e}");
                continue;
            }
        };
        // SAFETY: the surrounding PortAudio ownership and pointer checks establish the operation preconditions.
        let write_stream: PaWriteStream = match unsafe { lib.get(b"Pa_WriteStream\0") } {
            Ok(s) => *s,
            Err(e) => {
                last_err = format!("Pa_WriteStream: {e}");
                continue;
            }
        };
        let get_default_input: Option<PaGetDefaultInputDevice> =
    // SAFETY: the surrounding PortAudio ownership and pointer checks establish the operation preconditions.
            unsafe { lib.get(b"Pa_GetDefaultInputDevice\0").ok().map(|s| *s) };
        let get_default_output: Option<PaGetDefaultOutputDevice> =
    // SAFETY: the surrounding PortAudio ownership and pointer checks establish the operation preconditions.
            unsafe { lib.get(b"Pa_GetDefaultOutputDevice\0").ok().map(|s| *s) };
        let get_device_info: Option<PaGetDeviceInfo> =
    // SAFETY: the surrounding PortAudio ownership and pointer checks establish the operation preconditions.
            unsafe { lib.get(b"Pa_GetDeviceInfo\0").ok().map(|s| *s) };
        let get_host_api_info: Option<PaGetHostApiInfo> =
    // SAFETY: the surrounding PortAudio ownership and pointer checks establish the operation preconditions.
            unsafe { lib.get(b"Pa_GetHostApiInfo\0").ok().map(|s| *s) };
        let get_error_text: Option<PaGetErrorText> =
    // SAFETY: the surrounding PortAudio ownership and pointer checks establish the operation preconditions.
            unsafe { lib.get(b"Pa_GetErrorText\0").ok().map(|s| *s) };

        // Never unload: leak Library for process lifetime.
        let _leaked: &'static Library = Box::leak(Box::new(lib));
        let path_resolved = path.canonicalize().unwrap_or(path);
        *slot = Some(PaGlobal::Ready(Box::new(PaFns {
            path: path_resolved,
            initialize,
            terminate,
            get_device_count,
            get_default_input,
            get_default_output,
            get_device_info,
            get_host_api_info,
            get_error_text,
            open_stream,
            close_stream,
            start_stream,
            stop_stream,
            read_stream,
            write_stream,
            initialized: false,
        })));
        return Ok(());
    }

    *slot = Some(PaGlobal::Failed(last_err.clone()));
    Err(last_err)
}

/// Ensure DLL loaded + Pa_Initialize done. Caller must hold `pa_lock`.
pub(super) fn ensure_pa_ready_locked() -> Result<(), String> {
    ensure_pa_loaded_locked()?;
    let mut slot = pa_global().lock().unwrap_or_else(|e| e.into_inner());
    match slot.as_mut() {
        Some(PaGlobal::Failed(e)) => Err(e.clone()),
        Some(PaGlobal::Ready(fns)) => {
            if !fns.initialized {
                // SAFETY: the surrounding PortAudio ownership and pointer checks establish the operation preconditions.
                let code = unsafe { (fns.initialize)() };
                if code < PA_NO_ERROR {
                    let msg = error_text_fns(fns, code);
                    let full = format!("Pa_Initialize: {msg}");
                    *slot = Some(PaGlobal::Failed(full.clone()));
                    return Err(full);
                }
                fns.initialized = true;
            }
            Ok(())
        }
        None => Err("PortAudio global not initialized".into()),
    }
}

pub(super) fn error_text_fns(fns: &PaFns, code: i32) -> String {
    if let Some(f) = fns.get_error_text {
        // SAFETY: the surrounding PortAudio ownership and pointer checks establish the operation preconditions.
        let p = unsafe { f(code) };
        if !p.is_null() {
            // SAFETY: the surrounding PortAudio ownership and pointer checks establish the operation preconditions.
            let s = unsafe { std::ffi::CStr::from_ptr(p) };
            return s.to_string_lossy().into_owned();
        }
    }
    format!("PortAudio error {code}")
}

pub(super) fn with_pa_fns_locked<R>(f: impl FnOnce(&mut PaFns) -> R) -> Result<R, String> {
    ensure_pa_ready_locked()?;
    let mut slot = pa_global().lock().unwrap_or_else(|e| e.into_inner());
    match slot.as_mut() {
        Some(PaGlobal::Ready(fns)) => Ok(f(fns)),
        Some(PaGlobal::Failed(e)) => Err(e.clone()),
        None => Err("PortAudio global missing".into()),
    }
}
