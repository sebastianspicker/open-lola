use super::super::{AlsaDeviceInfo, AlsaError, AlsaResult};
use super::ffi::AlsaApi;
use std::collections::BTreeMap;
use std::ffi::{c_char, c_void, CStr};

pub(super) fn read(api: &AlsaApi) -> AlsaResult<Vec<AlsaDeviceInfo>> {
    let interface = c"pcm";
    let mut hints = std::ptr::null_mut();
    // SAFETY: output pointer and static interface name are valid.
    let result = unsafe { (api.device_name_hint)(-1, interface.as_ptr(), &mut hints) };
    if result < 0 {
        return Err(AlsaError::Native {
            operation: "enumerate devices",
            code: result,
            detail: api.error_text(result),
        });
    }
    let guard = HintGuard { api, hints };
    let mut devices = BTreeMap::<String, AlsaDeviceInfo>::new();
    if hints.is_null() {
        return Ok(Vec::new());
    }
    let started = std::time::Instant::now();
    super::super::inventory_budget::walk_hints(
        |index| {
            // SAFETY: ALSA returns a null-terminated pointer array. The bounded
            // walker stops at the first sentinel and never skips an element.
            let hint = unsafe { *hints.add(index) };
            if hint.is_null() {
                return Ok(false);
            }
            if let Some(device) = read_hint(api, hint) {
                devices
                    .entry(device.name.clone())
                    .and_modify(|existing| merge(existing, &device))
                    .or_insert(device);
            }
            Ok(true)
        },
        || started.elapsed(),
    )?;
    drop(guard);
    Ok(devices.into_values().collect())
}

fn read_hint(api: &AlsaApi, hint: *const c_void) -> Option<AlsaDeviceInfo> {
    let name = hint_string(api, hint, c"NAME")?;
    if name != "hw" && !name.starts_with("hw:") {
        return None;
    }
    let description = hint_string(api, hint, c"DESC").map(normalize_description);
    let io_id = hint_string(api, hint, c"IOID");
    let (supports_capture, supports_playback) = match io_id.as_deref() {
        Some("Input") => (true, false),
        Some("Output") => (false, true),
        None => (true, true),
        Some(_) => (false, false),
    };
    Some(AlsaDeviceInfo {
        name,
        description,
        supports_capture,
        supports_playback,
    })
}

fn hint_string(api: &AlsaApi, hint: *const c_void, field: &CStr) -> Option<String> {
    // SAFETY: the hint and field are supplied according to the ALSA hint API.
    let raw = unsafe { (api.device_name_get_hint)(hint, field.as_ptr()) };
    if raw.is_null() {
        return None;
    }
    let value = OwnedHintString(raw);
    // SAFETY: ALSA guarantees a NUL-terminated allocation; strnlen stops at
    // that terminator or the explicit metadata ceiling before allocation.
    let length = unsafe { libc::strnlen(value.0, 4097) };
    if length > 4096 {
        return None;
    }
    // SAFETY: the successful bounded scan found these initialized string bytes.
    let bytes = unsafe { std::slice::from_raw_parts(value.0.cast::<u8>(), length) };
    Some(String::from_utf8_lossy(bytes).into_owned())
}

fn normalize_description(value: String) -> String {
    value
        .replace('\n', " ")
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
}

fn merge(existing: &mut AlsaDeviceInfo, incoming: &AlsaDeviceInfo) {
    existing.supports_capture |= incoming.supports_capture;
    existing.supports_playback |= incoming.supports_playback;
    if existing.description.is_none() {
        existing.description.clone_from(&incoming.description);
    }
}

struct HintGuard<'a> {
    api: &'a AlsaApi,
    hints: *mut *mut c_void,
}

impl Drop for HintGuard<'_> {
    fn drop(&mut self) {
        if !self.hints.is_null() {
            // SAFETY: this is the pointer returned by `snd_device_name_hint`.
            let _ = unsafe { (self.api.device_name_free_hint)(self.hints) };
        }
    }
}

struct OwnedHintString(*mut c_char);

impl Drop for OwnedHintString {
    fn drop(&mut self) {
        // SAFETY: ALSA documents these strings as malloc-allocated.
        unsafe { libc::free(self.0.cast()) };
    }
}
