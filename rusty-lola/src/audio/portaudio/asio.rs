use super::devices::*;
use super::ffi::*;

/// Confirm a selected device is provided by PortAudio's ASIO host API. This is
/// deliberately separate from selection so default and named selections cannot
/// silently cross into WASAPI, MME, or DirectSound in the strict backend.
pub(super) fn require_asio_device_locked(
    fns: &PaFns,
    device: i32,
    direction: &'static str,
) -> PortAudioResult<()> {
    let operation = "ASIO device verification";
    let get_device_info = fns.get_device_info.ok_or_else(|| PortAudioError::Native {
        operation,
        detail: "Pa_GetDeviceInfo not bound".into(),
    })?;
    let get_host_api_info = fns
        .get_host_api_info
        .ok_or_else(|| PortAudioError::Native {
            operation,
            detail: "Pa_GetHostApiInfo not bound".into(),
        })?;
    // SAFETY: PortAudio has been initialized and `device` came from its
    // selection API or caller configuration; its immutable device info stays
    // valid while the leaked library remains initialized under `pa_lock`.
    let device_info = unsafe { get_device_info(device) };
    if device_info.is_null() {
        return Err(PortAudioError::Native {
            operation,
            detail: format!("Pa_GetDeviceInfo({device}) returned null"),
        });
    }
    // SAFETY: non-null `Pa_GetDeviceInfo` results point to the documented
    // immutable `PaDeviceInfo` layout for the initialized PortAudio instance.
    let host_api = unsafe { (*device_info).host_api };
    if host_api < 0 {
        return Err(PortAudioError::Native {
            operation,
            detail: format!("device {device} has invalid host API index {host_api}"),
        });
    }
    // SAFETY: `host_api` is read from the PortAudio-owned device info above;
    // the returned pointer remains valid for the initialized library lifetime.
    let host_api_info = unsafe { get_host_api_info(host_api) };
    if host_api_info.is_null() {
        return Err(PortAudioError::Native {
            operation,
            detail: format!("Pa_GetHostApiInfo({host_api}) returned null"),
        });
    }
    // SAFETY: non-null `Pa_GetHostApiInfo` results point to the documented
    // immutable `PaHostApiInfo` layout for the initialized PortAudio instance.
    let host_api_type = unsafe { (*host_api_info).type_ };
    if host_api_type == PA_ASIO {
        Ok(())
    } else {
        Err(PortAudioError::NotAsioDevice {
            direction,
            device,
            host_api_type,
        })
    }
}
