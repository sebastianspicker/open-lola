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
