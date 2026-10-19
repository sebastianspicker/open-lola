//! Runtime-loaded Media Foundation entry points, COM ownership and attribute access.
//!
//! ole32.dll, mfplat.dll, mf.dll and mfreadwrite.dll are loaded once from
//! System32 through `native_loader` and leaked, so COM objects never outlive
//! their code. Nothing is linked at build time.

use super::com::*;
use super::{MfError, MfResult};
use libloading::Library;
use std::ffi::c_void;
use std::ptr::{null, NonNull};
use std::sync::OnceLock;
use std::thread::ThreadId;

type CoInitializeExFn = unsafe extern "system" fn(*const c_void, u32) -> Hresult;
type CoUninitializeFn = unsafe extern "system" fn();
type CoTaskMemFreeFn = unsafe extern "system" fn(*const c_void);
type MfStartupFn = unsafe extern "system" fn(u32, u32) -> Hresult;
type MfShutdownFn = unsafe extern "system" fn() -> Hresult;
type MfCreateAttributesFn = unsafe extern "system" fn(*mut *mut c_void, u32) -> Hresult;
type MfEnumDeviceSourcesFn =
    unsafe extern "system" fn(*mut c_void, *mut *mut *mut c_void, *mut u32) -> Hresult;
type MfCreateSourceReaderFromMediaSourceFn =
    unsafe extern "system" fn(*mut c_void, *mut c_void, *mut *mut c_void) -> Hresult;

/// Entry points with the signatures from objbase.h, combaseapi.h, mfapi.h,
/// mfidl.h and mfreadwrite.h.
pub(super) struct MfApi {
    co_initialize_ex: CoInitializeExFn,
    co_uninitialize: CoUninitializeFn,
    pub(super) co_task_mem_free: CoTaskMemFreeFn,
    mf_startup: MfStartupFn,
    mf_shutdown: MfShutdownFn,
    pub(super) mf_create_attributes: MfCreateAttributesFn,
    pub(super) mf_enum_device_sources: MfEnumDeviceSourcesFn,
    pub(super) mf_create_source_reader_from_media_source: MfCreateSourceReaderFromMediaSourceFn,
}

/// Loads the four DLLs once per process.
pub(super) fn api() -> MfResult<&'static MfApi> {
    static API: OnceLock<Result<MfApi, String>> = OnceLock::new();
    API.get_or_init(bind)
        .as_ref()
        .map_err(|error| MfError::Unavailable(error.clone()))
}

fn bind() -> Result<MfApi, String> {
    let ole32 = load_library("ole32.dll")?;
    let mfplat = load_library("mfplat.dll")?;
    let mf = load_library("mf.dll")?;
    let mfreadwrite = load_library("mfreadwrite.dll")?;
    // SAFETY: every name is NUL-terminated and every target type matches the
    // export's documented Win32 signature and `system` calling convention.
    unsafe {
        Ok(MfApi {
            co_initialize_ex: symbol(ole32, b"CoInitializeEx\0")?,
            co_uninitialize: symbol(ole32, b"CoUninitialize\0")?,
            co_task_mem_free: symbol(ole32, b"CoTaskMemFree\0")?,
            mf_startup: symbol(mfplat, b"MFStartup\0")?,
            mf_shutdown: symbol(mfplat, b"MFShutdown\0")?,
            mf_create_attributes: symbol(mfplat, b"MFCreateAttributes\0")?,
            mf_enum_device_sources: symbol(mf, b"MFEnumDeviceSources\0")?,
            mf_create_source_reader_from_media_source: symbol(
                mfreadwrite,
                b"MFCreateSourceReaderFromMediaSource\0",
            )?,
        })
    }
}

fn load_library(name: &str) -> Result<&'static Library, String> {
    // System32 only: Media Foundation is an OS component, never loaded app-local.
    let dirs = crate::native_loader::system_search_dirs("mediafoundation");
    let path = crate::native_loader::candidate_paths(&dirs, &[name], &[])
        .into_iter()
        .next()
        .ok_or_else(|| {
            format!("{name} not found in System32 (Windows N editions need the Media Feature Pack)")
        })?;
    // SAFETY: a System32 path validated by native_loader; the library is leaked
    // below so the symbols bound from it stay valid for the process lifetime.
    let library = unsafe { crate::native_loader::load(&path) }
        .map_err(|error| format!("load {}: {error}", path.display()))?;
    Ok(Box::leak(Box::new(library)))
}

/// Reads one export as a function pointer.
///
/// # Safety
/// `name` must be NUL-terminated and `T` must be the export's exact function type.
unsafe fn symbol<T: Copy>(library: &'static Library, name: &[u8]) -> Result<T, String> {
    // SAFETY: forwarded from the caller's contract on `name` and `T`.
    unsafe { library.get::<T>(name) }
        .map(|symbol| *symbol)
        .map_err(|error| {
            format!(
                "{}: {error}",
                String::from_utf8_lossy(&name[..name.len() - 1])
            )
        })
}

/// Turns a failed HRESULT into an error naming the call.
pub(super) fn check(hr: Hresult, operation: &'static str) -> MfResult<()> {
    if hr < 0 {
        Err(MfError::Call {
            operation,
            code: hr as u32,
        })
    } else {
        Ok(())
    }
}

/// One owned COM reference; `Release` runs exactly once, on drop.
pub(super) struct ComPtr<V: ComVtbl> {
    raw: NonNull<*const V>,
}

impl<V: ComVtbl> ComPtr<V> {
    /// Adopts a reference returned through an out-parameter.
    ///
    /// # Safety
    /// `raw` must be null or an owned reference to an object whose vtable is `V`.
    pub(super) unsafe fn from_raw(raw: *mut c_void) -> Option<Self> {
        NonNull::new(raw.cast()).map(|raw| Self { raw })
    }

    pub(super) fn as_raw(&self) -> *mut c_void {
        self.raw.as_ptr().cast()
    }

    pub(super) fn vtbl(&self) -> &V {
        // SAFETY: the object stays alive while this reference is held, and a
        // COM object's first word is its vtable pointer.
        unsafe { &**self.raw.as_ptr() }
    }
}

impl<V: ComVtbl> Drop for ComPtr<V> {
    fn drop(&mut self) {
        let unknown = (self.vtbl() as *const V).cast::<IUnknownVtbl>();
        // SAFETY: `V: ComVtbl` starts with IUnknownVtbl, and this owned reference
        // is released exactly once because `drop` runs once.
        unsafe { ((*unknown).release)(self.as_raw()) };
    }
}

/// Calls a creator that writes one owned interface pointer and adopts it.
///
/// # Safety
/// On success `call` must write null or an owned reference whose vtable is `V`.
pub(super) unsafe fn take<V: ComVtbl>(
    operation: &'static str,
    call: impl FnOnce(*mut *mut c_void) -> Hresult,
) -> MfResult<ComPtr<V>> {
    let mut raw = std::ptr::null_mut();
    check(call(&mut raw), operation)?;
    // SAFETY: forwarded from the caller's contract on what `call` writes.
    unsafe { ComPtr::from_raw(raw) }.ok_or(MfError::Call {
        operation,
        code: 0x8000_4003, // E_POINTER: success without an object.
    })
}

/// Interfaces deriving from IMFAttributes.
pub(super) trait Attributes: ComVtbl {
    fn attributes(&self) -> &IMFAttributesVtbl;
}

impl Attributes for IMFAttributesVtbl {
    fn attributes(&self) -> &IMFAttributesVtbl {
        self
    }
}

impl Attributes for IMFActivateVtbl {
    fn attributes(&self) -> &IMFAttributesVtbl {
        &self.base
    }
}

impl Attributes for IMFMediaTypeVtbl {
    fn attributes(&self) -> &IMFAttributesVtbl {
        &self.base
    }
}

fn optional<T>(hr: Hresult, operation: &'static str, value: T) -> MfResult<Option<T>> {
    if hr == MF_E_ATTRIBUTENOTFOUND {
        return Ok(None);
    }
    check(hr, operation).map(|()| Some(value))
}

impl<V: Attributes> ComPtr<V> {
    pub(super) fn get_u32(&self, key: &Guid) -> MfResult<Option<u32>> {
        let mut value = 0;
        // SAFETY: valid `this`, key and out-pointer for IMFAttributes::GetUINT32.
        let hr = unsafe { (self.vtbl().attributes().get_uint32)(self.as_raw(), key, &mut value) };
        optional(hr, "IMFAttributes::GetUINT32", value)
    }

    pub(super) fn get_u64(&self, key: &Guid) -> MfResult<Option<u64>> {
        let mut value = 0;
        // SAFETY: valid `this`, key and out-pointer for IMFAttributes::GetUINT64.
        let hr = unsafe { (self.vtbl().attributes().get_uint64)(self.as_raw(), key, &mut value) };
        optional(hr, "IMFAttributes::GetUINT64", value)
    }

    pub(super) fn get_guid(&self, key: &Guid) -> MfResult<Option<Guid>> {
        let mut value = Guid::from_u128(0);
        // SAFETY: valid `this`, key and out-pointer for IMFAttributes::GetGUID.
        let hr = unsafe { (self.vtbl().attributes().get_guid)(self.as_raw(), key, &mut value) };
        optional(hr, "IMFAttributes::GetGUID", value)
    }

    pub(super) fn get_string(&self, api: &MfApi, key: &Guid) -> MfResult<Option<String>> {
        let mut text: *mut u16 = std::ptr::null_mut();
        let mut length = 0u32;
        // SAFETY: valid `this`, key and out-pointers for IMFAttributes::GetAllocatedString.
        let hr = unsafe {
            (self.vtbl().attributes().get_allocated_string)(
                self.as_raw(),
                key,
                &mut text,
                &mut length,
            )
        };
        if optional(hr, "IMFAttributes::GetAllocatedString", ())?.is_none() || text.is_null() {
            return Ok(None);
        }
        // SAFETY: on success `text` holds `length` UTF-16 units allocated by CoTaskMemAlloc.
        let value =
            String::from_utf16_lossy(unsafe { std::slice::from_raw_parts(text, length as usize) });
        // SAFETY: the string was allocated with CoTaskMemAlloc and is freed once.
        unsafe { (api.co_task_mem_free)(text.cast()) };
        Ok(Some(value))
    }

    pub(super) fn set_u64(&self, key: &Guid, value: u64) -> MfResult<()> {
        // SAFETY: valid `this` and key for IMFAttributes::SetUINT64.
        let hr = unsafe { (self.vtbl().attributes().set_uint64)(self.as_raw(), key, value) };
        check(hr, "IMFAttributes::SetUINT64")
    }

    pub(super) fn set_guid(&self, key: &Guid, value: &Guid) -> MfResult<()> {
        // SAFETY: valid `this`, key and value for IMFAttributes::SetGUID.
        let hr = unsafe { (self.vtbl().attributes().set_guid)(self.as_raw(), key, value) };
        check(hr, "IMFAttributes::SetGUID")
    }
}

/// Joins the multithreaded apartment; balances CoInitializeEx on drop.
pub(super) struct ComApartment {
    api: &'static MfApi,
    uninitialize: bool,
    thread: ThreadId,
}

impl ComApartment {
    pub(super) fn enter(api: &'static MfApi) -> MfResult<Self> {
        // SAFETY: the reserved pointer must be null and COINIT_MULTITHREADED is a valid flag.
        let hr = unsafe { (api.co_initialize_ex)(null(), COINIT_MULTITHREADED) };
        let uninitialize = match hr {
            S_OK | S_FALSE => true,
            // The thread already joined an STA; Media Foundation works there too.
            RPC_E_CHANGED_MODE => false,
            code => {
                return Err(MfError::Call {
                    operation: "CoInitializeEx",
                    code: code as u32,
                })
            }
        };
        Ok(Self {
            api,
            uninitialize,
            thread: std::thread::current().id(),
        })
    }
}

impl Drop for ComApartment {
    fn drop(&mut self) {
        if self.uninitialize && std::thread::current().id() == self.thread {
            // SAFETY: balances the successful CoInitializeEx made on this thread.
            unsafe { (self.api.co_uninitialize)() };
        }
    }
}

/// Holds one MFStartup reference; MFShutdown runs on drop.
pub(super) struct MfRuntime {
    api: &'static MfApi,
}

impl MfRuntime {
    pub(super) fn start(api: &'static MfApi) -> MfResult<Self> {
        // SAFETY: MF_VERSION and MFSTARTUP_LITE are the documented arguments.
        let status = unsafe { (api.mf_startup)(MF_VERSION, MFSTARTUP_LITE) };
        check(status, "MFStartup")?;
        Ok(Self { api })
    }
}

impl Drop for MfRuntime {
    fn drop(&mut self) {
        // SAFETY: balances the successful MFStartup made by `start`.
        let _ = unsafe { (self.api.mf_shutdown)() };
    }
}
