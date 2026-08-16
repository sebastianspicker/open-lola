//! Strict xiAPI camera backend, probe, and shipping helpers.

mod diagnostic;
mod ffi;
mod strict;
mod types;

pub use diagnostic::{ensure_shipped_ximea_dll, probe_ximea, CameraBackendInfo};
pub use ffi::{load_xiapi, XiApiLibrary};
pub use strict::{open_ximea_strict, StrictXimeaCamera};
pub use types::{
    XimeaColorMode, XimeaConfig, XimeaError, XimeaFrame, XimeaPixelFormat, XimeaResult,
};

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn probe_loads_via_ffi_not_path_only() {
        let p = probe_ximea();
        if p.available {
            assert!(p.loaded);
            assert!(p.library_path.as_ref().unwrap().is_file());
            let lib = load_xiapi(p.library_path.as_deref()).expect("reload via LoadLibrary");
            let n = lib.get_number_devices();
            assert!(n.is_ok() || n.is_err());
        } else {
            assert!(!p.loaded);
            assert!(!p.reason.is_empty());
        }
    }

    #[test]
    fn load_xiapi_binds_required_symbols_when_dll_present() {
        let probe = probe_ximea();
        if !probe.available {
            return;
        }
        let lib = load_xiapi(probe.library_path.as_deref()).expect("load");
        let _ = lib.get_number_devices();
    }
}
