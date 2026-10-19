//! Hand-declared Media Foundation COM ABI: GUIDs, HRESULTs and vtables.
//!
//! Every vtable lists all slots of its interface in the order of the Windows
//! SDK headers (`unknwn.h`, `mfobjects.h`, `mfidl.h`, `mfreadwrite.h`).
//! Methods this backend never calls are `usize` placeholders: only their
//! position matters. The layout tests below pin each slot count.
#![cfg_attr(not(windows), allow(dead_code))]

use std::ffi::c_void;

pub(super) type Hresult = i32;

/// `GUID` from `guiddef.h`.
#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(super) struct Guid {
    pub(super) data1: u32,
    pub(super) data2: u16,
    pub(super) data3: u16,
    pub(super) data4: [u8; 8],
}

impl Guid {
    /// Builds a GUID from its registry spelling, e.g. `0x3231564e_0000_0010_8000_00aa00389b71`.
    pub(super) const fn from_u128(value: u128) -> Self {
        Self {
            data1: (value >> 96) as u32,
            data2: (value >> 80) as u16,
            data3: (value >> 64) as u16,
            data4: (value as u64).to_be_bytes(),
        }
    }

    /// Whether this is a `DEFINE_MEDIATYPE_GUID` subtype (`XXXXXXXX-0000-0010-8000-00AA00389B71`).
    pub(super) fn is_media_type_guid(&self) -> bool {
        Self::from_u128(u128::from(self.data1) << 96 | MEDIA_TYPE_GUID_BASE) == *self
    }
}

/// Shared tail of every `DEFINE_MEDIATYPE_GUID` subtype in `mfapi.h`.
const MEDIA_TYPE_GUID_BASE: u128 = 0x0000_0010_8000_00aa_0038_9b71;

/// `MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE` (mfidl.h).
pub(super) const MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE: Guid =
    Guid::from_u128(0xc60ac5fe_252a_478f_a0ef_bc8fa5f7cad3);
/// `MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_GUID` (mfidl.h).
pub(super) const MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_GUID: Guid =
    Guid::from_u128(0x8ac3587a_4ae7_42d8_99e0_0a6013eef90f);
/// `MF_DEVSOURCE_ATTRIBUTE_FRIENDLY_NAME` (mfidl.h).
pub(super) const MF_DEVSOURCE_ATTRIBUTE_FRIENDLY_NAME: Guid =
    Guid::from_u128(0x60d0e559_52f8_4fa2_bbce_acdb34a8ec01);
/// `MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_SYMBOLIC_LINK` (mfidl.h).
pub(super) const MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_SYMBOLIC_LINK: Guid =
    Guid::from_u128(0x58f0aad8_22bf_4f8a_bb3d_d2c4978c6e2f);
/// `MF_MT_MAJOR_TYPE` (mfapi.h).
pub(super) const MF_MT_MAJOR_TYPE: Guid = Guid::from_u128(0x48eba18e_f8c9_4687_bf11_0a74c9f96a8f);
/// `MF_MT_SUBTYPE` (mfapi.h).
pub(super) const MF_MT_SUBTYPE: Guid = Guid::from_u128(0xf7e34c9a_42e8_4714_b74b_cb29d72c35e5);
/// `MF_MT_FRAME_SIZE` (mfapi.h): width in the high 32 bits, height in the low.
pub(super) const MF_MT_FRAME_SIZE: Guid = Guid::from_u128(0x1652c33d_d6b2_4012_b834_72030849a37d);
/// `MF_MT_FRAME_RATE` (mfapi.h): numerator high, denominator low.
pub(super) const MF_MT_FRAME_RATE: Guid = Guid::from_u128(0xc459a2e8_3d2c_4e44_b132_fee5156c7bb0);
/// `MF_MT_FRAME_RATE_RANGE_MIN` (mfapi.h).
pub(super) const MF_MT_FRAME_RATE_RANGE_MIN: Guid =
    Guid::from_u128(0xd2e7558c_dc1f_403f_9a72_d28bb1eb3b5e);
/// `MF_MT_FRAME_RATE_RANGE_MAX` (mfapi.h).
pub(super) const MF_MT_FRAME_RATE_RANGE_MAX: Guid =
    Guid::from_u128(0xe3371d41_b4cf_4a05_bd4e_20b88bb2c4d6);
/// `MF_MT_DEFAULT_STRIDE` (mfapi.h): a UINT32 holding a signed stride.
pub(super) const MF_MT_DEFAULT_STRIDE: Guid =
    Guid::from_u128(0x644b4e48_1e02_4516_b0eb_c01ca9d49ac6);
/// `MFMediaType_Video` (mfapi.h).
pub(super) const MF_MEDIA_TYPE_VIDEO: Guid =
    Guid::from_u128(0x73646976_0000_0010_8000_00aa00389b71);
/// `MFVideoFormat_NV12` (mfapi.h).
pub(super) const MF_VIDEO_FORMAT_NV12: Guid =
    Guid::from_u128(0x3231564e_0000_0010_8000_00aa00389b71);
/// `MFVideoFormat_YUY2` (mfapi.h).
pub(super) const MF_VIDEO_FORMAT_YUY2: Guid =
    Guid::from_u128(0x32595559_0000_0010_8000_00aa00389b71);
/// `MFVideoFormat_RGB32` (mfapi.h), `D3DFMT_X8R8G8B8`: B, G, R, X in memory.
pub(super) const MF_VIDEO_FORMAT_RGB32: Guid =
    Guid::from_u128(0x00000016_0000_0010_8000_00aa00389b71);
/// `IID_IMFMediaSource` (mfidl.h).
pub(super) const IID_IMF_MEDIA_SOURCE: Guid =
    Guid::from_u128(0x279a808d_aec7_40c8_9c6b_a6b492c78a66);

/// `MF_VERSION` (mfapi.h): `MF_SDK_VERSION << 16 | MF_API_VERSION`.
pub(super) const MF_VERSION: u32 = 0x0002_0070;
/// `MFSTARTUP_LITE` (mfapi.h): no socket library.
pub(super) const MFSTARTUP_LITE: u32 = 1;
/// `COINIT_MULTITHREADED` (objbase.h).
pub(super) const COINIT_MULTITHREADED: u32 = 0;
/// `MF_SOURCE_READER_FIRST_VIDEO_STREAM` (mfreadwrite.h).
pub(super) const MF_SOURCE_READER_FIRST_VIDEO_STREAM: u32 = 0xFFFF_FFFC;
/// `MF_SOURCE_READER_ALL_STREAMS` (mfreadwrite.h).
pub(super) const MF_SOURCE_READER_ALL_STREAMS: u32 = 0xFFFF_FFFE;
/// `MF_SOURCE_READERF_ERROR` (mfreadwrite.h).
pub(super) const MF_SOURCE_READERF_ERROR: u32 = 0x1;
/// `MF_SOURCE_READERF_ENDOFSTREAM` (mfreadwrite.h).
pub(super) const MF_SOURCE_READERF_ENDOFSTREAM: u32 = 0x2;
/// `MF_SOURCE_READERF_NATIVEMEDIATYPECHANGED` (mfreadwrite.h).
pub(super) const MF_SOURCE_READERF_NATIVEMEDIATYPECHANGED: u32 = 0x10;
/// `MF_SOURCE_READERF_CURRENTMEDIATYPECHANGED` (mfreadwrite.h).
pub(super) const MF_SOURCE_READERF_CURRENTMEDIATYPECHANGED: u32 = 0x20;

/// `S_OK` / `S_FALSE` (winerror.h).
pub(super) const S_OK: Hresult = 0;
pub(super) const S_FALSE: Hresult = 1;
/// `RPC_E_CHANGED_MODE` (winerror.h): the thread already joined an STA.
pub(super) const RPC_E_CHANGED_MODE: Hresult = 0x8001_0106_u32 as i32;
/// `MF_E_ATTRIBUTENOTFOUND` (mferror.h).
pub(super) const MF_E_ATTRIBUTENOTFOUND: Hresult = 0xC00D_36E6_u32 as i32;
/// `MF_E_NO_MORE_TYPES` (mferror.h).
pub(super) const MF_E_NO_MORE_TYPES: Hresult = 0xC00D_36B9_u32 as i32;

type This = *mut c_void;

/// `IUnknown` (unknwn.h): QueryInterface, AddRef, Release.
#[repr(C)]
pub(super) struct IUnknownVtbl {
    pub(super) query_interface: usize,
    pub(super) add_ref: usize,
    pub(super) release: unsafe extern "system" fn(This) -> u32,
}

/// `IMFAttributes` (mfobjects.h), 30 methods after IUnknown.
#[repr(C)]
pub(super) struct IMFAttributesVtbl {
    pub(super) base: IUnknownVtbl,
    pub(super) get_item: usize,
    pub(super) get_item_type: usize,
    pub(super) compare_item: usize,
    pub(super) compare: usize,
    pub(super) get_uint32: unsafe extern "system" fn(This, *const Guid, *mut u32) -> Hresult,
    pub(super) get_uint64: unsafe extern "system" fn(This, *const Guid, *mut u64) -> Hresult,
    pub(super) get_double: usize,
    pub(super) get_guid: unsafe extern "system" fn(This, *const Guid, *mut Guid) -> Hresult,
    pub(super) get_string_length: usize,
    pub(super) get_string: usize,
    pub(super) get_allocated_string:
        unsafe extern "system" fn(This, *const Guid, *mut *mut u16, *mut u32) -> Hresult,
    pub(super) get_blob_size: usize,
    pub(super) get_blob: usize,
    pub(super) get_allocated_blob: usize,
    pub(super) get_unknown: usize,
    pub(super) set_item: usize,
    pub(super) delete_item: usize,
    pub(super) delete_all_items: usize,
    pub(super) set_uint32: usize,
    pub(super) set_uint64: unsafe extern "system" fn(This, *const Guid, u64) -> Hresult,
    pub(super) set_double: usize,
    pub(super) set_guid: unsafe extern "system" fn(This, *const Guid, *const Guid) -> Hresult,
    pub(super) set_string: usize,
    pub(super) set_blob: usize,
    pub(super) set_unknown: usize,
    pub(super) lock_store: usize,
    pub(super) unlock_store: usize,
    pub(super) get_count: usize,
    pub(super) get_item_by_index: usize,
    pub(super) copy_all_items: usize,
}

/// `IMFActivate` (mfobjects.h): IMFAttributes + ActivateObject, ShutdownObject, DetachObject.
#[repr(C)]
pub(super) struct IMFActivateVtbl {
    pub(super) base: IMFAttributesVtbl,
    pub(super) activate_object: unsafe extern "system" fn(This, *const Guid, *mut This) -> Hresult,
    pub(super) shutdown_object: usize,
    pub(super) detach_object: usize,
}

/// `IMFMediaSource` (mfidl.h): IMFMediaEventGenerator (GetEvent, BeginGetEvent,
/// EndGetEvent, QueueEvent) + GetCharacteristics, CreatePresentationDescriptor,
/// Start, Stop, Pause, Shutdown.
#[repr(C)]
pub(super) struct IMFMediaSourceVtbl {
    pub(super) base: IUnknownVtbl,
    pub(super) get_event: usize,
    pub(super) begin_get_event: usize,
    pub(super) end_get_event: usize,
    pub(super) queue_event: usize,
    pub(super) get_characteristics: usize,
    pub(super) create_presentation_descriptor: usize,
    pub(super) start: usize,
    pub(super) stop: usize,
    pub(super) pause: usize,
    pub(super) shutdown: unsafe extern "system" fn(This) -> Hresult,
}

/// `IMFSourceReader` (mfreadwrite.h), 10 methods after IUnknown.
#[repr(C)]
pub(super) struct IMFSourceReaderVtbl {
    pub(super) base: IUnknownVtbl,
    pub(super) get_stream_selection: usize,
    pub(super) set_stream_selection: unsafe extern "system" fn(This, u32, i32) -> Hresult,
    pub(super) get_native_media_type:
        unsafe extern "system" fn(This, u32, u32, *mut This) -> Hresult,
    pub(super) get_current_media_type: unsafe extern "system" fn(This, u32, *mut This) -> Hresult,
    pub(super) set_current_media_type:
        unsafe extern "system" fn(This, u32, *const u32, This) -> Hresult,
    pub(super) set_current_position: usize,
    pub(super) read_sample: unsafe extern "system" fn(
        This,
        u32,
        u32,
        *mut u32,
        *mut u32,
        *mut i64,
        *mut This,
    ) -> Hresult,
    pub(super) flush: usize,
    pub(super) get_service_for_stream: usize,
    pub(super) get_presentation_attribute: usize,
}

/// `IMFMediaType` (mfobjects.h): IMFAttributes + GetMajorType, IsCompressedFormat,
/// IsEqual, GetRepresentation, FreeRepresentation.
#[repr(C)]
pub(super) struct IMFMediaTypeVtbl {
    pub(super) base: IMFAttributesVtbl,
    pub(super) get_major_type: usize,
    pub(super) is_compressed_format: usize,
    pub(super) is_equal: usize,
    pub(super) get_representation: usize,
    pub(super) free_representation: usize,
}

/// `IMFSample` (mfobjects.h), 14 methods after IMFAttributes.
#[repr(C)]
pub(super) struct IMFSampleVtbl {
    pub(super) base: IMFAttributesVtbl,
    pub(super) get_sample_flags: usize,
    pub(super) set_sample_flags: usize,
    pub(super) get_sample_time: usize,
    pub(super) set_sample_time: usize,
    pub(super) get_sample_duration: usize,
    pub(super) set_sample_duration: usize,
    pub(super) get_buffer_count: usize,
    pub(super) get_buffer_by_index: usize,
    pub(super) convert_to_contiguous_buffer: unsafe extern "system" fn(This, *mut This) -> Hresult,
    pub(super) add_buffer: usize,
    pub(super) remove_buffer_by_index: usize,
    pub(super) remove_all_buffers: usize,
    pub(super) get_total_length: usize,
    pub(super) copy_to_buffer: usize,
}

/// `IMFMediaBuffer` (mfobjects.h): Lock, Unlock, GetCurrentLength,
/// SetCurrentLength, GetMaxLength.
#[repr(C)]
pub(super) struct IMFMediaBufferVtbl {
    pub(super) base: IUnknownVtbl,
    pub(super) lock: unsafe extern "system" fn(This, *mut *mut u8, *mut u32, *mut u32) -> Hresult,
    pub(super) unlock: unsafe extern "system" fn(This) -> Hresult,
    pub(super) get_current_length: usize,
    pub(super) set_current_length: usize,
    pub(super) get_max_length: usize,
}

/// A vtable whose first member is the `IUnknown` vtable.
///
/// # Safety
/// Implementors must be `#[repr(C)]` and begin (directly or through their
/// first `base` field) with [`IUnknownVtbl`], so a pointer to the vtable can be
/// read as a pointer to `IUnknownVtbl`.
pub(super) unsafe trait ComVtbl {}

// SAFETY: each vtable below is #[repr(C)] and starts with IUnknownVtbl, directly
// or through a `base` chain that itself starts with IUnknownVtbl.
unsafe impl ComVtbl for IMFAttributesVtbl {}
// SAFETY: see above; `base` is IMFAttributesVtbl.
unsafe impl ComVtbl for IMFActivateVtbl {}
// SAFETY: see above; `base` is IUnknownVtbl.
unsafe impl ComVtbl for IMFMediaSourceVtbl {}
// SAFETY: see above; `base` is IUnknownVtbl.
unsafe impl ComVtbl for IMFSourceReaderVtbl {}
// SAFETY: see above; `base` is IMFAttributesVtbl.
unsafe impl ComVtbl for IMFMediaTypeVtbl {}
// SAFETY: see above; `base` is IMFAttributesVtbl.
unsafe impl ComVtbl for IMFSampleVtbl {}
// SAFETY: see above; `base` is IUnknownVtbl.
unsafe impl ComVtbl for IMFMediaBufferVtbl {}

/// Slot counts from the SDK headers, inherited methods included.
pub(super) const IUNKNOWN_SLOTS: usize = 3;
pub(super) const IMF_ATTRIBUTES_SLOTS: usize = IUNKNOWN_SLOTS + 30;
pub(super) const IMF_ACTIVATE_SLOTS: usize = IMF_ATTRIBUTES_SLOTS + 3;
pub(super) const IMF_MEDIA_SOURCE_SLOTS: usize = IUNKNOWN_SLOTS + 4 + 6;
pub(super) const IMF_SOURCE_READER_SLOTS: usize = IUNKNOWN_SLOTS + 10;
pub(super) const IMF_MEDIA_TYPE_SLOTS: usize = IMF_ATTRIBUTES_SLOTS + 5;
pub(super) const IMF_SAMPLE_SLOTS: usize = IMF_ATTRIBUTES_SLOTS + 14;
pub(super) const IMF_MEDIA_BUFFER_SLOTS: usize = IUNKNOWN_SLOTS + 5;

const fn slots<T>() -> usize {
    std::mem::size_of::<T>() / std::mem::size_of::<usize>()
}

const _: () = {
    assert!(slots::<IUnknownVtbl>() == IUNKNOWN_SLOTS);
    assert!(slots::<IMFAttributesVtbl>() == IMF_ATTRIBUTES_SLOTS);
    assert!(slots::<IMFActivateVtbl>() == IMF_ACTIVATE_SLOTS);
    assert!(slots::<IMFMediaSourceVtbl>() == IMF_MEDIA_SOURCE_SLOTS);
    assert!(slots::<IMFSourceReaderVtbl>() == IMF_SOURCE_READER_SLOTS);
    assert!(slots::<IMFMediaTypeVtbl>() == IMF_MEDIA_TYPE_SLOTS);
    assert!(slots::<IMFSampleVtbl>() == IMF_SAMPLE_SLOTS);
    assert!(slots::<IMFMediaBufferVtbl>() == IMF_MEDIA_BUFFER_SLOTS);
    assert!(std::mem::size_of::<Guid>() == 16);
};

#[cfg(test)]
mod tests {
    use super::*;
    use std::mem::{offset_of, size_of};

    const WORD: usize = size_of::<usize>();

    #[test]
    fn vtable_slot_counts_match_the_sdk_headers() {
        assert_eq!(size_of::<IUnknownVtbl>(), 3 * WORD);
        assert_eq!(size_of::<IMFAttributesVtbl>(), 33 * WORD);
        assert_eq!(size_of::<IMFActivateVtbl>(), 36 * WORD);
        assert_eq!(size_of::<IMFMediaSourceVtbl>(), 13 * WORD);
        assert_eq!(size_of::<IMFSourceReaderVtbl>(), 13 * WORD);
        assert_eq!(size_of::<IMFMediaTypeVtbl>(), 38 * WORD);
        assert_eq!(size_of::<IMFSampleVtbl>(), 47 * WORD);
        assert_eq!(size_of::<IMFMediaBufferVtbl>(), 8 * WORD);
    }

    #[test]
    fn called_methods_sit_at_their_sdk_slot_index() {
        let slot = |offset: usize| offset / WORD;
        assert_eq!(slot(offset_of!(IUnknownVtbl, release)), 2);
        assert_eq!(slot(offset_of!(IMFAttributesVtbl, get_uint32)), 7);
        assert_eq!(slot(offset_of!(IMFAttributesVtbl, get_uint64)), 8);
        assert_eq!(slot(offset_of!(IMFAttributesVtbl, get_guid)), 10);
        assert_eq!(
            slot(offset_of!(IMFAttributesVtbl, get_allocated_string)),
            13
        );
        assert_eq!(slot(offset_of!(IMFAttributesVtbl, set_uint64)), 22);
        assert_eq!(slot(offset_of!(IMFAttributesVtbl, set_guid)), 24);
        assert_eq!(slot(offset_of!(IMFActivateVtbl, activate_object)), 33);
        assert_eq!(slot(offset_of!(IMFMediaSourceVtbl, shutdown)), 12);
        assert_eq!(
            slot(offset_of!(IMFSourceReaderVtbl, set_stream_selection)),
            4
        );
        assert_eq!(
            slot(offset_of!(IMFSourceReaderVtbl, get_native_media_type)),
            5
        );
        assert_eq!(
            slot(offset_of!(IMFSourceReaderVtbl, get_current_media_type)),
            6
        );
        assert_eq!(
            slot(offset_of!(IMFSourceReaderVtbl, set_current_media_type)),
            7
        );
        assert_eq!(slot(offset_of!(IMFSourceReaderVtbl, read_sample)), 9);
        assert_eq!(
            slot(offset_of!(IMFSampleVtbl, convert_to_contiguous_buffer)),
            41
        );
        assert_eq!(slot(offset_of!(IMFMediaBufferVtbl, lock)), 3);
        assert_eq!(slot(offset_of!(IMFMediaBufferVtbl, unlock)), 4);
    }

    #[test]
    fn guid_fields_follow_the_registry_spelling() {
        assert_eq!(
            MF_VIDEO_FORMAT_NV12,
            Guid {
                data1: 0x3231_564e,
                data2: 0,
                data3: 0x0010,
                data4: [0x80, 0x00, 0x00, 0xaa, 0x00, 0x38, 0x9b, 0x71],
            }
        );
        assert_eq!(MF_VIDEO_FORMAT_NV12.data1.to_le_bytes(), *b"NV12");
        assert_eq!(MF_VIDEO_FORMAT_YUY2.data1.to_le_bytes(), *b"YUY2");
        assert!(MF_VIDEO_FORMAT_RGB32.is_media_type_guid());
        assert!(MF_MEDIA_TYPE_VIDEO.is_media_type_guid());
        assert!(!MF_MT_SUBTYPE.is_media_type_guid());
    }
}
