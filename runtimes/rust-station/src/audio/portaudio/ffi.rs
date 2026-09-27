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

pub(super) struct PaBindings {
    initialize: PaInitialize,
    terminate: PaTerminate,
    get_device_count: PaGetDeviceCount,
    get_default_input: Option<PaGetDefaultInputDevice>,
    get_default_output: Option<PaGetDefaultOutputDevice>,
    get_device_info: Option<PaGetDeviceInfo>,
    get_host_api_info: Option<PaGetHostApiInfo>,
    get_error_text: Option<PaGetErrorText>,
    open_stream: PaOpenStream,
    close_stream: PaCloseStream,
    start_stream: PaStartStream,
    stop_stream: PaStopStream,
    read_stream: PaReadStream,
    write_stream: PaWriteStream,
}

impl PaFns {
    pub(super) fn from_bindings(path: PathBuf, bindings: PaBindings) -> Self {
        Self {
            path,
            initialize: bindings.initialize,
            terminate: bindings.terminate,
            get_device_count: bindings.get_device_count,
            get_default_input: bindings.get_default_input,
            get_default_output: bindings.get_default_output,
            get_device_info: bindings.get_device_info,
            get_host_api_info: bindings.get_host_api_info,
            get_error_text: bindings.get_error_text,
            open_stream: bindings.open_stream,
            close_stream: bindings.close_stream,
            start_stream: bindings.start_stream,
            stop_stream: bindings.stop_stream,
            read_stream: bindings.read_stream,
            write_stream: bindings.write_stream,
            initialized: false,
        }
    }
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
    crate::native_loader::search_dirs("portaudio")
}

pub(super) fn candidate_paths() -> Vec<PathBuf> {
    crate::native_loader::candidate_paths(
        &search_dirs(),
        &["portaudio_x64.dll", "portaudio.dll", "portaudio_x86.dll"],
        &[],
    )
}

/// Bind the PortAudio ABI while the caller owns the loaded library.
pub(super) fn bind_pa_symbols(lib: &Library) -> Result<PaBindings, String> {
    macro_rules! required_symbol {
        ($type:ty, $symbol:literal) => {
            // SAFETY: `$symbol` is a NUL-terminated PortAudio symbol and `$type` matches its C ABI.
            unsafe { lib.get::<$type>($symbol) }
                .map(|symbol| *symbol)
                .map_err(|error| {
                    format!(
                        "{}: {error}",
                        String::from_utf8_lossy(&$symbol[..$symbol.len() - 1])
                    )
                })?
        };
    }
    macro_rules! optional_symbol {
        ($type:ty, $symbol:literal) => {{
            // SAFETY: `$symbol` is a NUL-terminated PortAudio symbol and `$type` matches its C ABI.
            unsafe { lib.get::<$type>($symbol).ok().map(|symbol| *symbol) }
        }};
    }
    Ok(PaBindings {
        initialize: required_symbol!(PaInitialize, b"Pa_Initialize\0"),
        terminate: required_symbol!(PaTerminate, b"Pa_Terminate\0"),
        get_device_count: required_symbol!(PaGetDeviceCount, b"Pa_GetDeviceCount\0"),
        open_stream: required_symbol!(PaOpenStream, b"Pa_OpenStream\0"),
        close_stream: required_symbol!(PaCloseStream, b"Pa_CloseStream\0"),
        start_stream: required_symbol!(PaStartStream, b"Pa_StartStream\0"),
        stop_stream: required_symbol!(PaStopStream, b"Pa_StopStream\0"),
        read_stream: required_symbol!(PaReadStream, b"Pa_ReadStream\0"),
        write_stream: required_symbol!(PaWriteStream, b"Pa_WriteStream\0"),
        get_default_input: optional_symbol!(PaGetDefaultInputDevice, b"Pa_GetDefaultInputDevice\0"),
        get_default_output: optional_symbol!(
            PaGetDefaultOutputDevice,
            b"Pa_GetDefaultOutputDevice\0"
        ),
        get_device_info: optional_symbol!(PaGetDeviceInfo, b"Pa_GetDeviceInfo\0"),
        get_host_api_info: optional_symbol!(PaGetHostApiInfo, b"Pa_GetHostApiInfo\0"),
        get_error_text: optional_symbol!(PaGetErrorText, b"Pa_GetErrorText\0"),
    })
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
        let lib = match unsafe { crate::native_loader::load(&path) } {
            Ok(l) => l,
            Err(e) => {
                last_err = format!("load {}: {e}", path.display());
                continue;
            }
        };
        let bindings = match bind_pa_symbols(&lib) {
            Ok(bindings) => bindings,
            Err(error) => {
                last_err = error;
                continue;
            }
        };

        // Never unload: leak Library for process lifetime.
        let _leaked: &'static Library = Box::leak(Box::new(lib));
        let path_resolved = path.canonicalize().unwrap_or(path);
        *slot = Some(PaGlobal::Ready(Box::new(PaFns::from_bindings(
            path_resolved,
            bindings,
        ))));
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
