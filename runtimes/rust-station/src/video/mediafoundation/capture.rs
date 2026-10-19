//! Windows capture: open a device with its exact native mode, read synchronously.

use super::api::{api, check, take, ComApartment, ComPtr, MfApi, MfRuntime};
use super::com::*;
use super::device::{
    create_reader, current_type, describe, describe_type, enumerate, native_modes, native_type,
    select_video_stream, set_current_type, MediaSource,
};
use super::{
    convert_frame, mismatch_hint, pick_device, select_mode, MfConfig, MfDeviceInfo, MfError,
    MfFrameLayout, MfMode, MfOutput, MfResult,
};
use std::ptr::null_mut;

/// Reader flags that ask the caller to re-read the media type.
const MEDIA_TYPE_CHANGED: u32 =
    MF_SOURCE_READERF_CURRENTMEDIATYPECHANGED | MF_SOURCE_READERF_NATIVEMEDIATYPECHANGED;

/// Stream ticks and gaps tolerated before a read counts as failed.
const MAX_EMPTY_READS: usize = 16;

/// Reader before source: fields drop in declaration order, so the reader is
/// released before the source is shut down.
struct Session {
    reader: ComPtr<IMFSourceReaderVtbl>,
    _source: MediaSource,
}

/// Field order is the teardown order: session, then MFShutdown, then COM.
pub(super) struct Camera {
    session: Option<Session>,
    layout: MfFrameLayout,
    _runtime: MfRuntime,
    _com: ComApartment,
}

impl Camera {
    pub(super) fn open(config: &MfConfig) -> MfResult<Self> {
        let api = api()?;
        let com = ComApartment::enter(api)?;
        let runtime = MfRuntime::start(api)?;
        let devices = enumerate(api)?;
        // One unreadable device must not hide the others: keep its reason and go on.
        let names = devices
            .iter()
            .map(|device| describe(api, device).map_err(|error| error.to_string()))
            .collect::<Vec<_>>();
        let (index, name) = pick_device(&names, config)?;
        let source = MediaSource::activate(&devices[index])?;
        drop(devices);
        let reader = create_reader(api, &source)?;
        select_video_stream(&reader)?;
        let layout = configure(&reader, config, name)?;
        Ok(Self {
            session: Some(Session {
                reader,
                _source: source,
            }),
            layout,
            _runtime: runtime,
            _com: com,
        })
    }

    pub(super) fn grab(&mut self, output: MfOutput) -> MfResult<Vec<u8>> {
        let session = self.session.as_ref().ok_or(MfError::Stopped)?;
        for _ in 0..MAX_EMPTY_READS {
            if let Some(sample) = read_sample(&session.reader, &self.layout)? {
                return copy_sample(&sample, &self.layout, output);
            }
        }
        Err(MfError::InvalidFrame(format!(
            "no sample after {MAX_EMPTY_READS} reads"
        )))
    }

    pub(super) fn stop(&mut self) -> MfResult<()> {
        self.session = None;
        Ok(())
    }
}

/// Picks and sets the exact requested native type, then reads back its layout.
fn configure(
    reader: &ComPtr<IMFSourceReaderVtbl>,
    config: &MfConfig,
    device: &str,
) -> MfResult<MfFrameLayout> {
    let modes = native_modes(reader)?;
    let request = config.request();
    let selection = select_mode(&modes, &request)
        .ok_or_else(|| MfError::ModeNotOffered(mismatch_hint(&request, device, &modes)))?;
    let media_type = native_type(reader, selection.index as u32)?
        .ok_or_else(|| MfError::InvalidConfig("the selected native type disappeared".into()))?;
    if let Some(rate) = selection.set_frame_rate {
        media_type.set_u64(&MF_MT_FRAME_RATE, rate.packed())?;
    }
    set_current_type(reader, &media_type)?;
    current_layout(reader, &modes[selection.index])
}

/// The reader's current media type as a frame layout, whatever it is.
fn read_layout(reader: &ComPtr<IMFSourceReaderVtbl>) -> MfResult<MfFrameLayout> {
    let current = current_type(reader)?;
    let actual = describe_type(&current)?;
    let stride = match current.get_u32(&MF_MT_DEFAULT_STRIDE)? {
        // The attribute is a UINT32 that stores a signed stride.
        Some(stride) => stride as i32,
        None => MfFrameLayout::default_stride(&actual.subtype, actual.width)
            .ok_or_else(|| MfError::InvalidConfig("frame stride overflow".into()))?,
    };
    Ok(MfFrameLayout {
        subtype: actual.subtype,
        width: actual.width,
        height: actual.height,
        stride,
    })
}

fn current_layout(
    reader: &ComPtr<IMFSourceReaderVtbl>,
    expected: &MfMode,
) -> MfResult<MfFrameLayout> {
    let layout = read_layout(reader)?;
    let actual = &layout;
    if (&actual.subtype, actual.width, actual.height)
        != (&expected.subtype, expected.width, expected.height)
    {
        return Err(MfError::InvalidConfig(format!(
            "the reader delivers {} {}x{} instead of {} {}x{}",
            actual.subtype,
            actual.width,
            actual.height,
            expected.subtype,
            expected.width,
            expected.height
        )));
    }
    Ok(layout)
}

/// One synchronous `ReadSample`; `None` for a stream tick without a sample.
fn read_sample(
    reader: &ComPtr<IMFSourceReaderVtbl>,
    selected: &MfFrameLayout,
) -> MfResult<Option<ComPtr<IMFSampleVtbl>>> {
    let (mut stream, mut flags, mut timestamp, mut raw) = (0u32, 0u32, 0i64, null_mut());
    // SAFETY: synchronous reader (no callback), valid stream constant and out-pointers.
    let hr = unsafe {
        (reader.vtbl().read_sample)(
            reader.as_raw(),
            MF_SOURCE_READER_FIRST_VIDEO_STREAM,
            0,
            &mut stream,
            &mut flags,
            &mut timestamp,
            &mut raw,
        )
    };
    // SAFETY: `raw` is null or one owned IMFSample reference; adopt it before any early return.
    let sample = unsafe { ComPtr::from_raw(raw) };
    check(hr, "IMFSourceReader::ReadSample")?;
    stream_flags_error(flags)?;
    // Some drivers raise a type-changed flag on the first sample after SetCurrentMediaType.
    // Keep going if the reader still delivers the selected mode; fail only if it moved.
    if flags & MEDIA_TYPE_CHANGED != 0 {
        let current = read_layout(reader)?;
        selected
            .ensure_unchanged(&current)
            .map_err(MfError::InvalidFrame)?;
    }
    Ok(sample)
}

fn stream_flags_error(flags: u32) -> MfResult<()> {
    let problem = if flags & MF_SOURCE_READERF_ERROR != 0 {
        "the source reader reported a stream error"
    } else if flags & MF_SOURCE_READERF_ENDOFSTREAM != 0 {
        "the camera ended the stream"
    } else {
        return Ok(());
    };
    Err(MfError::InvalidFrame(problem.into()))
}

fn copy_sample(
    sample: &ComPtr<IMFSampleVtbl>,
    layout: &MfFrameLayout,
    output: MfOutput,
) -> MfResult<Vec<u8>> {
    // SAFETY: valid sample; ConvertToContiguousBuffer writes one owned IMFMediaBuffer.
    let buffer: ComPtr<IMFMediaBufferVtbl> = unsafe {
        take("IMFSample::ConvertToContiguousBuffer", |out| {
            (sample.vtbl().convert_to_contiguous_buffer)(sample.as_raw(), out)
        })
    }?;
    let locked = LockedBuffer::lock(&buffer)?;
    convert_frame(locked.bytes(), layout, output).map_err(MfError::InvalidFrame)
}

/// A locked media buffer; `Unlock` runs on drop.
struct LockedBuffer<'a> {
    buffer: &'a ComPtr<IMFMediaBufferVtbl>,
    data: *const u8,
    length: usize,
}

impl<'a> LockedBuffer<'a> {
    fn lock(buffer: &'a ComPtr<IMFMediaBufferVtbl>) -> MfResult<Self> {
        let (mut data, mut length) = (null_mut(), 0u32);
        // SAFETY: valid buffer; the max-length out-pointer is optional and passed as null.
        let hr =
            unsafe { (buffer.vtbl().lock)(buffer.as_raw(), &mut data, null_mut(), &mut length) };
        check(hr, "IMFMediaBuffer::Lock")?;
        Ok(Self {
            buffer,
            data,
            length: length as usize,
        })
    }

    fn bytes(&self) -> &[u8] {
        if self.data.is_null() {
            return &[];
        }
        // SAFETY: Lock returned `length` valid bytes at `data`, readable until Unlock in drop.
        unsafe { std::slice::from_raw_parts(self.data, self.length) }
    }
}

impl Drop for LockedBuffer<'_> {
    fn drop(&mut self) {
        // SAFETY: balances the successful Lock made by `lock`.
        let _ = unsafe { (self.buffer.vtbl().unlock)(self.buffer.as_raw()) };
    }
}

pub(super) fn inventory() -> MfResult<Vec<MfDeviceInfo>> {
    let api = api()?;
    let _com = ComApartment::enter(api)?;
    let _runtime = MfRuntime::start(api)?;
    let devices = enumerate(api)?;
    devices
        .iter()
        .map(|device| {
            let (name, symbolic_link) = describe(api, device)?;
            let (modes, modes_error) = match probe_modes(api, device) {
                Ok(modes) => (modes, None),
                Err(error) => (Vec::new(), Some(error.to_string())),
            };
            Ok(MfDeviceInfo {
                name,
                symbolic_link,
                modes,
                modes_error,
            })
        })
        .collect()
}

fn probe_modes(api: &MfApi, device: &ComPtr<IMFActivateVtbl>) -> MfResult<Vec<MfMode>> {
    let source = MediaSource::activate(device)?;
    let reader = create_reader(api, &source)?;
    native_modes(&reader)
}
