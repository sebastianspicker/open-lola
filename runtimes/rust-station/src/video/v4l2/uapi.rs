//! Minimal Linux V4L2 UAPI required by the single-planar mmap capture path.

use libc::{c_ulong, timeval, Ioctl};
use std::ffi::c_void;

pub(super) const BUF_TYPE_VIDEO_CAPTURE: u32 = 1;
pub(super) const BUF_TYPE_VIDEO_CAPTURE_MPLANE: u32 = 9;
pub(super) const FIELD_ANY: u32 = 0;
pub(super) const MEMORY_MMAP: u32 = 1;

pub(super) const CAP_VIDEO_CAPTURE: u32 = 0x0000_0001;
pub(super) const CAP_VIDEO_CAPTURE_MPLANE: u32 = 0x0000_1000;
pub(super) const CAP_META_CAPTURE: u32 = 0x0080_0000;
pub(super) const CAP_READWRITE: u32 = 0x0100_0000;
pub(super) const CAP_STREAMING: u32 = 0x0400_0000;
pub(super) const CAP_EXT_PIX_FORMAT: u32 = 0x0020_0000;
pub(super) const CAP_DEVICE_CAPS: u32 = 0x8000_0000;

pub(super) const PIX_FMT_PRIV_MAGIC: u32 = 0xfeed_cafe;

pub(super) const FMT_FLAG_COMPRESSED: u32 = 0x0001;
pub(super) const FMT_FLAG_EMULATED: u32 = 0x0002;
pub(super) const FRMSIZE_TYPE_DISCRETE: u32 = 1;
pub(super) const FRMSIZE_TYPE_CONTINUOUS: u32 = 2;
pub(super) const FRMSIZE_TYPE_STEPWISE: u32 = 3;
pub(super) const FRMIVAL_TYPE_DISCRETE: u32 = 1;
pub(super) const FRMIVAL_TYPE_CONTINUOUS: u32 = 2;
pub(super) const FRMIVAL_TYPE_STEPWISE: u32 = 3;
pub(super) const BUF_FLAG_ERROR: u32 = 0x0040;
pub(super) const CAP_TIME_PER_FRAME: u32 = 0x1000;

const V4L2_IOCTL_TYPE: u32 = b'V' as u32;

pub(super) const VIDIOC_QUERYCAP: Ioctl = libc::_IOR::<Capability>(V4L2_IOCTL_TYPE, 0);
pub(super) const VIDIOC_ENUM_FMT: Ioctl = libc::_IOWR::<FormatDescription>(V4L2_IOCTL_TYPE, 2);
pub(super) const VIDIOC_S_FMT: Ioctl = libc::_IOWR::<Format>(V4L2_IOCTL_TYPE, 5);
pub(super) const VIDIOC_REQBUFS: Ioctl = libc::_IOWR::<RequestBuffers>(V4L2_IOCTL_TYPE, 8);
pub(super) const VIDIOC_QUERYBUF: Ioctl = libc::_IOWR::<Buffer>(V4L2_IOCTL_TYPE, 9);
pub(super) const VIDIOC_QBUF: Ioctl = libc::_IOWR::<Buffer>(V4L2_IOCTL_TYPE, 15);
pub(super) const VIDIOC_DQBUF: Ioctl = libc::_IOWR::<Buffer>(V4L2_IOCTL_TYPE, 17);
pub(super) const VIDIOC_STREAMON: Ioctl = libc::_IOW::<u32>(V4L2_IOCTL_TYPE, 18);
pub(super) const VIDIOC_STREAMOFF: Ioctl = libc::_IOW::<u32>(V4L2_IOCTL_TYPE, 19);
pub(super) const VIDIOC_G_PARM: Ioctl = libc::_IOWR::<StreamParameters>(V4L2_IOCTL_TYPE, 21);
pub(super) const VIDIOC_S_PARM: Ioctl = libc::_IOWR::<StreamParameters>(V4L2_IOCTL_TYPE, 22);
pub(super) const VIDIOC_ENUM_FRAMESIZES: Ioctl =
    libc::_IOWR::<FrameSizeEnumeration>(V4L2_IOCTL_TYPE, 74);
pub(super) const VIDIOC_ENUM_FRAMEINTERVALS: Ioctl =
    libc::_IOWR::<FrameIntervalEnumeration>(V4L2_IOCTL_TYPE, 75);

fn zeroed<T>() -> T {
    // SAFETY: This module calls `zeroed` only for C V4L2 records whose fields
    // are integers, byte arrays, pointers, or unions of those POD fields.
    unsafe { std::mem::zeroed() }
}

#[repr(C)]
#[derive(Clone, Copy)]
pub(super) struct Capability {
    pub driver: [u8; 16],
    pub card: [u8; 32],
    pub bus_info: [u8; 32],
    pub version: u32,
    pub capabilities: u32,
    pub device_caps: u32,
    pub reserved: [u32; 3],
}

impl Default for Capability {
    fn default() -> Self {
        zeroed()
    }
}

#[repr(C)]
#[derive(Clone, Copy)]
pub(super) struct FormatDescription {
    pub index: u32,
    pub type_: u32,
    pub flags: u32,
    pub description: [u8; 32],
    pub pixel_format: u32,
    pub media_bus_code: u32,
    pub reserved: [u32; 3],
}

impl Default for FormatDescription {
    fn default() -> Self {
        zeroed()
    }
}

#[repr(C)]
#[derive(Clone, Copy, Default)]
pub(super) struct Fraction {
    pub numerator: u32,
    pub denominator: u32,
}

#[repr(C)]
#[derive(Clone, Copy, Default)]
pub(super) struct FrameSizeDiscrete {
    pub width: u32,
    pub height: u32,
}

#[repr(C)]
#[derive(Clone, Copy, Default)]
pub(super) struct FrameSizeStepwise {
    pub min_width: u32,
    pub max_width: u32,
    pub step_width: u32,
    pub min_height: u32,
    pub max_height: u32,
    pub step_height: u32,
}

#[repr(C)]
#[derive(Clone, Copy)]
pub(super) union FrameSizeValue {
    pub discrete: FrameSizeDiscrete,
    pub stepwise: FrameSizeStepwise,
}

#[repr(C)]
#[derive(Clone, Copy)]
pub(super) struct FrameSizeEnumeration {
    pub index: u32,
    pub pixel_format: u32,
    pub type_: u32,
    pub value: FrameSizeValue,
    pub reserved: [u32; 2],
}

impl Default for FrameSizeEnumeration {
    fn default() -> Self {
        zeroed()
    }
}

#[repr(C)]
#[derive(Clone, Copy, Default)]
pub(super) struct FrameIntervalStepwise {
    pub min: Fraction,
    pub max: Fraction,
    pub step: Fraction,
}

#[repr(C)]
#[derive(Clone, Copy)]
pub(super) union FrameIntervalValue {
    pub discrete: Fraction,
    pub stepwise: FrameIntervalStepwise,
}

#[repr(C)]
#[derive(Clone, Copy)]
pub(super) struct FrameIntervalEnumeration {
    pub index: u32,
    pub pixel_format: u32,
    pub width: u32,
    pub height: u32,
    pub type_: u32,
    pub value: FrameIntervalValue,
    pub reserved: [u32; 2],
}

impl Default for FrameIntervalEnumeration {
    fn default() -> Self {
        zeroed()
    }
}

#[repr(C)]
#[derive(Clone, Copy, Default)]
pub(super) struct PixelFormat {
    pub width: u32,
    pub height: u32,
    pub pixel_format: u32,
    pub field: u32,
    pub bytes_per_line: u32,
    pub size_image: u32,
    pub color_space: u32,
    pub private: u32,
    pub flags: u32,
    pub ycbcr_encoding: u32,
    pub quantization: u32,
    pub transfer_function: u32,
}

#[repr(C)]
#[derive(Clone, Copy)]
pub(super) union FormatValue {
    pub pixel: PixelFormat,
    pub raw: [u8; 200],
    #[allow(dead_code)]
    pub pointer_alignment: *mut c_void,
}

#[repr(C)]
#[derive(Clone, Copy)]
pub(super) struct Format {
    pub type_: u32,
    pub value: FormatValue,
}

impl Default for Format {
    fn default() -> Self {
        zeroed()
    }
}

#[repr(C)]
#[derive(Clone, Copy, Default)]
pub(super) struct CaptureParameters {
    pub capability: u32,
    pub capture_mode: u32,
    pub time_per_frame: Fraction,
    pub extended_mode: u32,
    pub read_buffers: u32,
    pub reserved: [u32; 4],
}

#[repr(C)]
#[derive(Clone, Copy)]
pub(super) union StreamParametersValue {
    pub capture: CaptureParameters,
    pub raw: [u8; 200],
}

#[repr(C)]
#[derive(Clone, Copy)]
pub(super) struct StreamParameters {
    pub type_: u32,
    pub value: StreamParametersValue,
}

impl Default for StreamParameters {
    fn default() -> Self {
        zeroed()
    }
}

#[repr(C)]
#[derive(Clone, Copy, Default)]
pub(super) struct RequestBuffers {
    pub count: u32,
    pub type_: u32,
    pub memory: u32,
    pub capabilities: u32,
    pub flags: u8,
    pub reserved: [u8; 3],
}

#[repr(C)]
#[derive(Clone, Copy, Default)]
pub(super) struct TimeCode {
    pub type_: u32,
    pub flags: u32,
    pub frames: u8,
    pub seconds: u8,
    pub minutes: u8,
    pub hours: u8,
    pub user_bits: [u8; 4],
}

#[repr(C)]
#[derive(Clone, Copy)]
pub(super) union BufferMemory {
    pub offset: u32,
    #[allow(dead_code)]
    pub user_pointer: c_ulong,
    #[allow(dead_code)]
    pub planes: *mut c_void,
    #[allow(dead_code)]
    pub dma_buffer_fd: i32,
}

#[repr(C)]
#[derive(Clone, Copy)]
pub(super) struct Buffer {
    pub index: u32,
    pub type_: u32,
    pub bytes_used: u32,
    pub flags: u32,
    pub field: u32,
    pub timestamp: timeval,
    pub timecode: TimeCode,
    pub sequence: u32,
    pub memory: u32,
    pub location: BufferMemory,
    pub length: u32,
    pub reserved2: u32,
    pub request_fd: i32,
}

impl Default for Buffer {
    fn default() -> Self {
        zeroed()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn uapi_record_sizes_match_linux_headers() {
        assert_eq!(std::mem::size_of::<Capability>(), 104);
        assert_eq!(std::mem::size_of::<FormatDescription>(), 64);
        assert_eq!(std::mem::size_of::<FrameSizeEnumeration>(), 44);
        assert_eq!(std::mem::size_of::<FrameIntervalEnumeration>(), 52);
        #[cfg(target_pointer_width = "64")]
        assert_eq!(std::mem::size_of::<Format>(), 208);
        #[cfg(target_pointer_width = "32")]
        assert_eq!(std::mem::size_of::<Format>(), 204);
        assert_eq!(std::mem::size_of::<StreamParameters>(), 204);
        assert_eq!(std::mem::size_of::<RequestBuffers>(), 20);
        #[cfg(target_pointer_width = "64")]
        assert_eq!(std::mem::size_of::<Buffer>(), 88);
    }

    #[cfg(target_arch = "x86_64")]
    #[test]
    fn ioctl_numbers_match_x86_64_linux_uapi() {
        assert_eq!(VIDIOC_QUERYCAP, 2_154_321_408);
        assert_eq!(VIDIOC_ENUM_FMT, 3_225_441_794);
        assert_eq!(VIDIOC_S_FMT, 3_234_878_981);
        assert_eq!(VIDIOC_REQBUFS, 3_222_558_216);
        assert_eq!(VIDIOC_QUERYBUF, 3_227_014_665);
        assert_eq!(VIDIOC_QBUF, 3_227_014_671);
        assert_eq!(VIDIOC_DQBUF, 3_227_014_673);
        assert_eq!(VIDIOC_STREAMON, 1_074_026_002);
        assert_eq!(VIDIOC_STREAMOFF, 1_074_026_003);
        assert_eq!(VIDIOC_G_PARM, 3_234_616_853);
        assert_eq!(VIDIOC_S_PARM, 3_234_616_854);
        assert_eq!(VIDIOC_ENUM_FRAMESIZES, 3_224_131_146);
        assert_eq!(VIDIOC_ENUM_FRAMEINTERVALS, 3_224_655_435);
    }
}
