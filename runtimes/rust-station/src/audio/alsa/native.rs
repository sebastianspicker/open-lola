//! Linux-specific ALSA implementation.

mod backend;
mod ffi;
mod inventory;

pub(super) use backend::NativeBackend;

pub(super) fn inventory() -> super::AlsaResult<Vec<super::AlsaDeviceInfo>> {
    let api = ffi::AlsaApi::load()?;
    inventory::read(&api)
}
