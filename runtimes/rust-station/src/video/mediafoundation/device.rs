//! Video capture device enumeration, activation and native media types.

use super::api::{check, take, ComPtr, MfApi};
use super::com::*;
use super::{MfMode, MfRatio, MfResult, MfSubtype};
use std::ffi::c_void;
use std::ptr::null_mut;

const MAX_DEVICES: usize = 16;
const MAX_NATIVE_TYPES: u32 = 512;

/// Every video capture device (`MFEnumDeviceSources` with the VIDCAP source type).
pub(super) fn enumerate(api: &MfApi) -> MfResult<Vec<ComPtr<IMFActivateVtbl>>> {
    // SAFETY: MFCreateAttributes writes one owned IMFAttributes reference.
    let attributes: ComPtr<IMFAttributesVtbl> = unsafe {
        take("MFCreateAttributes", |out| {
            (api.mf_create_attributes)(out, 1)
        })
    }?;
    attributes.set_guid(
        &MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE,
        &MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_GUID,
    )?;
    let mut array: *mut *mut c_void = null_mut();
    let mut count = 0u32;
    // SAFETY: valid attribute store and out-pointers for MFEnumDeviceSources.
    let hr = unsafe { (api.mf_enum_device_sources)(attributes.as_raw(), &mut array, &mut count) };
    check(hr, "MFEnumDeviceSources")?;
    if array.is_null() {
        return Ok(Vec::new());
    }
    // SAFETY: on success `array` holds `count` IMFActivate pointers.
    let entries = unsafe { std::slice::from_raw_parts(array, count as usize) };
    let mut devices: Vec<ComPtr<IMFActivateVtbl>> = entries
        .iter()
        // SAFETY: each entry is one owned IMFActivate reference, adopted exactly once.
        .filter_map(|entry| unsafe { ComPtr::from_raw(*entry) })
        .collect();
    // SAFETY: the array was allocated with CoTaskMemAlloc; its entries are now owned above.
    unsafe { (api.co_task_mem_free)(array.cast()) };
    devices.truncate(MAX_DEVICES);
    Ok(devices)
}

/// Friendly name and symbolic link of one device.
pub(super) fn describe(
    api: &MfApi,
    activate: &ComPtr<IMFActivateVtbl>,
) -> MfResult<(String, String)> {
    let name = activate.get_string(api, &MF_DEVSOURCE_ATTRIBUTE_FRIENDLY_NAME)?;
    let link = activate.get_string(
        api,
        &MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_SYMBOLIC_LINK,
    )?;
    Ok((name.unwrap_or_default(), link.unwrap_or_default()))
}

/// An activated device source; `IMFMediaSource::Shutdown` runs before its release.
pub(super) struct MediaSource {
    source: ComPtr<IMFMediaSourceVtbl>,
}

impl MediaSource {
    pub(super) fn activate(activate: &ComPtr<IMFActivateVtbl>) -> MfResult<Self> {
        // SAFETY: ActivateObject with IID_IMFMediaSource writes an owned IMFMediaSource.
        let source = unsafe {
            take("IMFActivate::ActivateObject", |out| {
                (activate.vtbl().activate_object)(activate.as_raw(), &IID_IMF_MEDIA_SOURCE, out)
            })
        }?;
        Ok(Self { source })
    }
}

impl Drop for MediaSource {
    fn drop(&mut self) {
        // SAFETY: Shutdown takes only `this`, valid while `source` holds its reference.
        let _ = unsafe { (self.source.vtbl().shutdown)(self.source.as_raw()) };
    }
}

/// A synchronous source reader (no callback attribute) over `source`.
pub(super) fn create_reader(
    api: &MfApi,
    source: &MediaSource,
) -> MfResult<ComPtr<IMFSourceReaderVtbl>> {
    // SAFETY: valid media source, null attributes, and one owned IMFSourceReader written.
    unsafe {
        take("MFCreateSourceReaderFromMediaSource", |out| {
            (api.mf_create_source_reader_from_media_source)(source.source.as_raw(), null_mut(), out)
        })
    }
}

/// Reads only the first video stream.
pub(super) fn select_video_stream(reader: &ComPtr<IMFSourceReaderVtbl>) -> MfResult<()> {
    let set = |stream, selected| {
        // SAFETY: valid reader and documented stream constants for SetStreamSelection.
        let hr = unsafe { (reader.vtbl().set_stream_selection)(reader.as_raw(), stream, selected) };
        check(hr, "IMFSourceReader::SetStreamSelection")
    };
    set(MF_SOURCE_READER_ALL_STREAMS, 0)?;
    set(MF_SOURCE_READER_FIRST_VIDEO_STREAM, 1)
}

/// Native type `index` of the first video stream, `None` past the last one.
pub(super) fn native_type(
    reader: &ComPtr<IMFSourceReaderVtbl>,
    index: u32,
) -> MfResult<Option<ComPtr<IMFMediaTypeVtbl>>> {
    let mut raw = null_mut();
    // SAFETY: valid reader, stream constant, index and out-pointer.
    let hr = unsafe {
        (reader.vtbl().get_native_media_type)(
            reader.as_raw(),
            MF_SOURCE_READER_FIRST_VIDEO_STREAM,
            index,
            &mut raw,
        )
    };
    if hr == MF_E_NO_MORE_TYPES {
        return Ok(None);
    }
    check(hr, "IMFSourceReader::GetNativeMediaType")?;
    // SAFETY: on success `raw` is one owned IMFMediaType reference.
    Ok(unsafe { ComPtr::from_raw(raw) })
}

/// All native types, in native index order (the vector index is the native index).
pub(super) fn native_modes(reader: &ComPtr<IMFSourceReaderVtbl>) -> MfResult<Vec<MfMode>> {
    let mut modes = Vec::new();
    for index in 0..MAX_NATIVE_TYPES {
        match native_type(reader, index)? {
            Some(media_type) => modes.push(describe_type(&media_type)?),
            None => break,
        }
    }
    Ok(modes)
}

/// The type the reader currently delivers.
pub(super) fn current_type(
    reader: &ComPtr<IMFSourceReaderVtbl>,
) -> MfResult<ComPtr<IMFMediaTypeVtbl>> {
    // SAFETY: valid reader and stream constant; one owned IMFMediaType written.
    unsafe {
        take("IMFSourceReader::GetCurrentMediaType", |out| {
            (reader.vtbl().get_current_media_type)(
                reader.as_raw(),
                MF_SOURCE_READER_FIRST_VIDEO_STREAM,
                out,
            )
        })
    }
}

pub(super) fn describe_type(media_type: &ComPtr<IMFMediaTypeVtbl>) -> MfResult<MfMode> {
    let major = media_type.get_guid(&MF_MT_MAJOR_TYPE)?;
    let subtype = match media_type.get_guid(&MF_MT_SUBTYPE)? {
        _ if major.is_some_and(|major| major != MF_MEDIA_TYPE_VIDEO) => {
            MfSubtype::Other("non-video".into())
        }
        Some(guid) if guid == MF_VIDEO_FORMAT_NV12 => MfSubtype::Nv12,
        Some(guid) if guid == MF_VIDEO_FORMAT_YUY2 => MfSubtype::Yuy2,
        Some(guid) if guid == MF_VIDEO_FORMAT_RGB32 => MfSubtype::Rgb32,
        // Unconverted subtypes such as MJPG keep their FOURCC as a name.
        Some(guid) if guid.is_media_type_guid() => MfSubtype::from_fourcc(guid.data1),
        Some(guid) => MfSubtype::Other(format!("{{{:08X}-…}}", guid.data1)),
        None => MfSubtype::Other("unknown".into()),
    };
    let (width, height) = media_type
        .get_u64(&MF_MT_FRAME_SIZE)?
        .map_or((0, 0), |size| ((size >> 32) as u32, size as u32));
    let rate = |key| {
        media_type
            .get_u64(key)
            .map(|value| value.map(MfRatio::from_packed))
    };
    Ok(MfMode {
        subtype,
        width,
        height,
        frame_rate: rate(&MF_MT_FRAME_RATE)?,
        frame_rate_min: rate(&MF_MT_FRAME_RATE_RANGE_MIN)?,
        frame_rate_max: rate(&MF_MT_FRAME_RATE_RANGE_MAX)?,
    })
}

/// Sets the exact native type as the reader's output (no converters inserted).
pub(super) fn set_current_type(
    reader: &ComPtr<IMFSourceReaderVtbl>,
    media_type: &ComPtr<IMFMediaTypeVtbl>,
) -> MfResult<()> {
    // SAFETY: valid reader, stream constant, null reserved pointer and media type.
    let hr = unsafe {
        (reader.vtbl().set_current_media_type)(
            reader.as_raw(),
            MF_SOURCE_READER_FIRST_VIDEO_STREAM,
            std::ptr::null(),
            media_type.as_raw(),
        )
    };
    check(hr, "IMFSourceReader::SetCurrentMediaType")
}
