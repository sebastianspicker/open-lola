use super::super::{AlsaError, AlsaResult};
use libloading::Library;
use std::ffi::{c_char, c_int, c_long, c_uint, c_ulong, c_void};
use std::os::unix::fs::MetadataExt;
use std::path::{Path, PathBuf};

pub(super) type PcmHandle = c_void;
pub(super) type HwParams = c_void;
pub(super) type PcmFrames = c_ulong;
pub(super) type PcmSignedFrames = c_long;

pub(super) const STREAM_PLAYBACK: c_int = 0;
pub(super) const STREAM_CAPTURE: c_int = 1;
pub(super) const NONBLOCK: c_int = 1;
pub(super) const ACCESS_RW_INTERLEAVED: c_int = 3;
pub(super) const FORMAT_S8: c_int = 0;
pub(super) const FORMAT_S16_LE: c_int = 2;
pub(super) const FORMAT_S32_LE: c_int = 10;
pub(super) const FORMAT_S24_3LE: c_int = 32;

type PcmOpen = unsafe extern "C" fn(*mut *mut PcmHandle, *const c_char, c_int, c_int) -> c_int;
type PcmClose = unsafe extern "C" fn(*mut PcmHandle) -> c_int;
type PcmPrepare = unsafe extern "C" fn(*mut PcmHandle) -> c_int;
type PcmStart = unsafe extern "C" fn(*mut PcmHandle) -> c_int;
type PcmDrop = unsafe extern "C" fn(*mut PcmHandle) -> c_int;
type PcmResume = unsafe extern "C" fn(*mut PcmHandle) -> c_int;
type PcmRead = unsafe extern "C" fn(*mut PcmHandle, *mut c_void, PcmFrames) -> PcmSignedFrames;
type PcmWrite = unsafe extern "C" fn(*mut PcmHandle, *const c_void, PcmFrames) -> PcmSignedFrames;
type PcmWait = unsafe extern "C" fn(*mut PcmHandle, c_int) -> c_int;
type PcmHwParamsMalloc = unsafe extern "C" fn(*mut *mut HwParams) -> c_int;
type PcmHwParamsFree = unsafe extern "C" fn(*mut HwParams);
type PcmHwParamsAny = unsafe extern "C" fn(*mut PcmHandle, *mut HwParams) -> c_int;
type PcmHwParamsApply = unsafe extern "C" fn(*mut PcmHandle, *mut HwParams) -> c_int;
type PcmHwParamsSetAccess = unsafe extern "C" fn(*mut PcmHandle, *mut HwParams, c_int) -> c_int;
type PcmHwParamsSetFormat = unsafe extern "C" fn(*mut PcmHandle, *mut HwParams, c_int) -> c_int;
type PcmHwParamsSetChannels = unsafe extern "C" fn(*mut PcmHandle, *mut HwParams, c_uint) -> c_int;
type PcmHwParamsSetRate =
    unsafe extern "C" fn(*mut PcmHandle, *mut HwParams, c_uint, c_int) -> c_int;
type PcmHwParamsSetPeriod =
    unsafe extern "C" fn(*mut PcmHandle, *mut HwParams, PcmFrames, c_int) -> c_int;
type PcmHwParamsGetFormat = unsafe extern "C" fn(*const HwParams, *mut c_int) -> c_int;
type PcmHwParamsGetChannels = unsafe extern "C" fn(*const HwParams, *mut c_uint) -> c_int;
type PcmHwParamsGetRate = unsafe extern "C" fn(*const HwParams, *mut c_uint, *mut c_int) -> c_int;
type PcmHwParamsGetPeriod =
    unsafe extern "C" fn(*const HwParams, *mut PcmFrames, *mut c_int) -> c_int;
type StrError = unsafe extern "C" fn(c_int) -> *const c_char;
type DeviceNameHint = unsafe extern "C" fn(c_int, *const c_char, *mut *mut *mut c_void) -> c_int;
type DeviceNameGetHint = unsafe extern "C" fn(*const c_void, *const c_char) -> *mut c_char;
type DeviceNameFreeHint = unsafe extern "C" fn(*mut *mut c_void) -> c_int;

pub(super) struct AlsaApi {
    _library: Library,
    pub(super) pcm_open: PcmOpen,
    pub(super) pcm_close: PcmClose,
    pub(super) pcm_prepare: PcmPrepare,
    pub(super) pcm_start: PcmStart,
    pub(super) pcm_drop: PcmDrop,
    pub(super) pcm_resume: PcmResume,
    pub(super) pcm_readi: PcmRead,
    pub(super) pcm_writei: PcmWrite,
    pub(super) pcm_wait: PcmWait,
    pub(super) hw_malloc: PcmHwParamsMalloc,
    pub(super) hw_free: PcmHwParamsFree,
    pub(super) hw_any: PcmHwParamsAny,
    pub(super) hw_apply: PcmHwParamsApply,
    pub(super) hw_set_access: PcmHwParamsSetAccess,
    pub(super) hw_set_format: PcmHwParamsSetFormat,
    pub(super) hw_set_channels: PcmHwParamsSetChannels,
    pub(super) hw_set_rate: PcmHwParamsSetRate,
    pub(super) hw_set_period: PcmHwParamsSetPeriod,
    pub(super) hw_get_format: PcmHwParamsGetFormat,
    pub(super) hw_get_channels: PcmHwParamsGetChannels,
    pub(super) hw_get_rate: PcmHwParamsGetRate,
    pub(super) hw_get_period: PcmHwParamsGetPeriod,
    pub(super) strerror: StrError,
    pub(super) device_name_hint: DeviceNameHint,
    pub(super) device_name_get_hint: DeviceNameGetHint,
    pub(super) device_name_free_hint: DeviceNameFreeHint,
}

impl AlsaApi {
    pub(super) fn load() -> AlsaResult<Self> {
        let path = trusted_library_path()?;
        // SAFETY: `path` is a canonical, root-owned, non-writable regular file
        // reached only through fixed system-library candidates.
        let library = unsafe { Library::new(&path) }
            .map_err(|error| AlsaError::Library(format!("{}: {error}", path.display())))?;
        Self::bind(library)
    }

    fn bind(library: Library) -> AlsaResult<Self> {
        macro_rules! symbol {
            ($type:ty, $name:literal) => {{
                // SAFETY: the symbol name is NUL-terminated and the type is copied
                // from the public ALSA C API declaration.
                unsafe { library.get::<$type>($name) }
                    .map(|value| *value)
                    .map_err(|error| {
                        AlsaError::Library(format!(
                            "missing {}: {error}",
                            String::from_utf8_lossy(&$name[..$name.len() - 1])
                        ))
                    })?
            }};
        }
        Ok(Self {
            pcm_open: symbol!(PcmOpen, b"snd_pcm_open\0"),
            pcm_close: symbol!(PcmClose, b"snd_pcm_close\0"),
            pcm_prepare: symbol!(PcmPrepare, b"snd_pcm_prepare\0"),
            pcm_start: symbol!(PcmStart, b"snd_pcm_start\0"),
            pcm_drop: symbol!(PcmDrop, b"snd_pcm_drop\0"),
            pcm_resume: symbol!(PcmResume, b"snd_pcm_resume\0"),
            pcm_readi: symbol!(PcmRead, b"snd_pcm_readi\0"),
            pcm_writei: symbol!(PcmWrite, b"snd_pcm_writei\0"),
            pcm_wait: symbol!(PcmWait, b"snd_pcm_wait\0"),
            hw_malloc: symbol!(PcmHwParamsMalloc, b"snd_pcm_hw_params_malloc\0"),
            hw_free: symbol!(PcmHwParamsFree, b"snd_pcm_hw_params_free\0"),
            hw_any: symbol!(PcmHwParamsAny, b"snd_pcm_hw_params_any\0"),
            hw_apply: symbol!(PcmHwParamsApply, b"snd_pcm_hw_params\0"),
            hw_set_access: symbol!(PcmHwParamsSetAccess, b"snd_pcm_hw_params_set_access\0"),
            hw_set_format: symbol!(PcmHwParamsSetFormat, b"snd_pcm_hw_params_set_format\0"),
            hw_set_channels: symbol!(PcmHwParamsSetChannels, b"snd_pcm_hw_params_set_channels\0"),
            hw_set_rate: symbol!(PcmHwParamsSetRate, b"snd_pcm_hw_params_set_rate\0"),
            hw_set_period: symbol!(PcmHwParamsSetPeriod, b"snd_pcm_hw_params_set_period_size\0"),
            hw_get_format: symbol!(PcmHwParamsGetFormat, b"snd_pcm_hw_params_get_format\0"),
            hw_get_channels: symbol!(PcmHwParamsGetChannels, b"snd_pcm_hw_params_get_channels\0"),
            hw_get_rate: symbol!(PcmHwParamsGetRate, b"snd_pcm_hw_params_get_rate\0"),
            hw_get_period: symbol!(PcmHwParamsGetPeriod, b"snd_pcm_hw_params_get_period_size\0"),
            strerror: symbol!(StrError, b"snd_strerror\0"),
            device_name_hint: symbol!(DeviceNameHint, b"snd_device_name_hint\0"),
            device_name_get_hint: symbol!(DeviceNameGetHint, b"snd_device_name_get_hint\0"),
            device_name_free_hint: symbol!(DeviceNameFreeHint, b"snd_device_name_free_hint\0"),
            _library: library,
        })
    }

    pub(super) fn error_text(&self, code: i32) -> String {
        // SAFETY: ALSA owns the returned static string; it is copied immediately.
        let text = unsafe { (self.strerror)(code) };
        if text.is_null() {
            format!("ALSA error {code}")
        } else {
            // SAFETY: ALSA documents a NUL-terminated static string.
            unsafe { std::ffi::CStr::from_ptr(text) }
                .to_string_lossy()
                .into_owned()
        }
    }
}

fn trusted_library_path() -> AlsaResult<PathBuf> {
    const CANDIDATES: &[&str] = &[
        "/usr/lib/x86_64-linux-gnu/libasound.so.2",
        "/lib/x86_64-linux-gnu/libasound.so.2",
        "/usr/lib/aarch64-linux-gnu/libasound.so.2",
        "/lib/aarch64-linux-gnu/libasound.so.2",
        "/usr/lib/arm-linux-gnueabihf/libasound.so.2",
        "/lib/arm-linux-gnueabihf/libasound.so.2",
        "/usr/lib/riscv64-linux-gnu/libasound.so.2",
        "/lib/riscv64-linux-gnu/libasound.so.2",
        "/usr/lib64/libasound.so.2",
        "/lib64/libasound.so.2",
    ];
    let mut rejected = Vec::new();
    for candidate in CANDIDATES {
        let path = Path::new(candidate);
        if !path.exists() {
            continue;
        }
        match validate_library(path) {
            Ok(path) => return Ok(path),
            Err(reason) => rejected.push(format!("{candidate}: {reason}")),
        }
    }
    let detail = if rejected.is_empty() {
        "no fixed system libasound path exists".to_owned()
    } else {
        rejected.join("; ")
    };
    Err(AlsaError::Library(detail))
}

fn validate_library(candidate: &Path) -> Result<PathBuf, String> {
    if !candidate.is_absolute() {
        return Err("path is not absolute".into());
    }
    let canonical = candidate
        .canonicalize()
        .map_err(|error| error.to_string())?;
    let metadata = canonical.metadata().map_err(|error| error.to_string())?;
    if !metadata.file_type().is_file() {
        return Err("target is not a regular file".into());
    }
    if metadata.uid() != 0 {
        return Err(format!(
            "target owner uid is {}, expected 0",
            metadata.uid()
        ));
    }
    if metadata.mode() & 0o022 != 0 {
        return Err(format!(
            "target mode {:o} permits group/world writes",
            metadata.mode() & 0o777
        ));
    }
    Ok(canonical)
}
