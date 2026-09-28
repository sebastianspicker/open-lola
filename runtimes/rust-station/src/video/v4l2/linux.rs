use super::color::resolve_yuyv_color;
use super::convert::{normalize_frame, process_then_requeue, YuyvColorProfile};
use super::lifecycle::{cleanup_capture, start_capture, stop_capture, CaptureLifecycle};
use super::uapi::*;
use super::*;
use std::fs::{File, OpenOptions};
use std::io;
use std::os::fd::{AsRawFd, RawFd};
use std::os::unix::fs::{FileTypeExt, OpenOptionsExt};
use std::path::Path;
use std::sync::atomic::AtomicBool;
use std::sync::Arc;
use std::time::{Duration, Instant};

const REQUESTED_BUFFER_COUNT: u32 = 4;
const MINIMUM_BUFFER_COUNT: u32 = 2;
const MAX_MAPPED_BUFFER_BYTES: usize = crate::protocol::MAX_MEDIA_FRAME_SIZE;
const MAX_TOTAL_MAPPED_BYTES: usize = 128 * 1024 * 1024;

struct MappedBuffer {
    address: usize,
    length: usize,
}

impl MappedBuffer {
    fn map(file: &File, length: usize, offset: u32) -> V4l2Result<Self> {
        if length == 0 {
            return Err(V4l2Error::InvalidFrame(
                "driver returned a zero-length mmap buffer".into(),
            ));
        }
        // SAFETY: The driver supplied `length` and `offset` through QUERYBUF.
        // The live file owns the mapping, and Drop releases the exact range.
        let pointer = unsafe {
            libc::mmap(
                std::ptr::null_mut(),
                length,
                libc::PROT_READ | libc::PROT_WRITE,
                libc::MAP_SHARED,
                file.as_raw_fd(),
                libc::off_t::from(offset),
            )
        };
        if pointer == libc::MAP_FAILED {
            return Err(io_error("mmap capture buffer", io::Error::last_os_error()));
        }
        Ok(Self {
            address: pointer as usize,
            length,
        })
    }

    fn frame(&self, bytes_used: usize) -> V4l2Result<&[u8]> {
        if bytes_used == 0 || bytes_used > self.length {
            return Err(V4l2Error::InvalidFrame(format!(
                "driver reported {bytes_used} used bytes for a {}-byte buffer",
                self.length
            )));
        }
        // SAFETY: The mmap remains live for `self`, bytes_used was checked
        // against its mapped length, and the driver has dequeued this buffer.
        Ok(unsafe { std::slice::from_raw_parts(self.address as *const u8, bytes_used) })
    }
}

impl Drop for MappedBuffer {
    fn drop(&mut self) {
        // SAFETY: `address` and `length` are the unchanged values returned by
        // the successful mmap call owned exclusively by this value.
        unsafe {
            libc::munmap(self.address as *mut std::ffi::c_void, self.length);
        }
    }
}

pub(super) struct Camera {
    resources: CameraResources,
    queued: Vec<bool>,
    format: NativeFormat,
    width: u32,
    height: u32,
    bytes_per_line: u32,
    yuyv_color: YuyvColorProfile,
    cancellation: Arc<AtomicBool>,
    streaming: bool,
}

struct CameraResources {
    file: Option<File>,
    buffers: Vec<MappedBuffer>,
}

impl CameraResources {
    fn file(&self) -> V4l2Result<&File> {
        self.file
            .as_ref()
            .ok_or_else(|| V4l2Error::Cleanup("capture device is already closed".into()))
    }
}

impl CaptureLifecycle for CameraResources {
    fn queue(&mut self, index: u32) -> V4l2Result<()> {
        queue_buffer(self.file()?.as_raw_fd(), index)
    }

    fn stream_on(&mut self) -> V4l2Result<()> {
        let mut buffer_type = BUF_TYPE_VIDEO_CAPTURE;
        ioctl_mut(
            self.file()?,
            VIDIOC_STREAMON,
            &mut buffer_type,
            "VIDIOC_STREAMON",
        )
    }

    fn stream_off(&mut self) -> V4l2Result<()> {
        stream_off(self.file()?)
    }

    fn close(&mut self) {
        drop(self.file.take());
    }

    fn unmap(&mut self) {
        self.buffers.clear();
    }
}

impl Camera {
    pub(super) fn open(
        config: &V4l2Config,
        format: NativeFormat,
        cancellation: Arc<AtomicBool>,
    ) -> V4l2Result<Self> {
        let file = open_device(Path::new(&config.device), true)?;
        let capability = query_capability(&file)?;
        require_capture_capabilities(&capability)?;
        let negotiated = negotiate_format(&file, config, format, &capability)?;
        negotiate_frame_interval(&file, config.fps)?;
        let buffers = map_capture_buffers(&file, negotiated.pixel.size_image)?;
        let queued = vec![false; buffers.len()];
        Ok(Self {
            resources: CameraResources {
                file: Some(file),
                buffers,
            },
            queued,
            format,
            width: negotiated.pixel.width,
            height: negotiated.pixel.height,
            bytes_per_line: negotiated.pixel.bytes_per_line,
            yuyv_color: negotiated.yuyv_color,
            cancellation,
            streaming: false,
        })
    }

    pub(super) fn start(&mut self) -> V4l2Result<()> {
        start_capture(&mut self.resources, &mut self.queued, &mut self.streaming)
    }

    pub(super) fn grab(&mut self, timeout: Duration) -> V4l2Result<(Vec<u8>, String)> {
        if !self.streaming {
            return Err(V4l2Error::InvalidFrame(
                "capture stream has not been started".into(),
            ));
        }
        let deadline = Instant::now() + timeout;
        loop {
            let file_descriptor = self.resources.file()?.as_raw_fd();
            wait_for_readiness(
                &self.cancellation,
                deadline,
                timeout,
                Instant::now,
                |wait| poll_readable(file_descriptor, wait),
            )?;
            match dequeue_buffer(self.resources.file()?) {
                Ok(buffer) => return self.process_buffer(buffer),
                Err(V4l2Error::Io { source, .. })
                    if matches!(
                        source.kind(),
                        io::ErrorKind::WouldBlock | io::ErrorKind::Interrupted
                    ) => {}
                Err(error) => return Err(error),
            }
        }
    }

    pub(super) fn stop(&mut self) -> V4l2Result<()> {
        stop_capture(&mut self.resources, &mut self.queued, &mut self.streaming)
    }

    fn process_buffer(&mut self, buffer: Buffer) -> V4l2Result<(Vec<u8>, String)> {
        let index = buffer.index as usize;
        let mapped = self.resources.buffers.get(index).ok_or_else(|| {
            V4l2Error::InvalidFrame(format!("driver dequeued unknown buffer index {index}"))
        })?;
        self.queued[index] = false;
        let format = self.format;
        let width = self.width;
        let height = self.height;
        let bytes_per_line = self.bytes_per_line;
        let yuyv_color = self.yuyv_color;
        let bytes_used = buffer.bytes_used as usize;
        let frame_has_error = buffer.flags & BUF_FLAG_ERROR != 0;
        let file_descriptor = self.resources.file()?.as_raw_fd();
        let mut requeued = false;
        let result = process_then_requeue(
            || {
                if frame_has_error {
                    return Err(V4l2Error::InvalidFrame(format!(
                        "driver marked buffer {index} as erroneous"
                    )));
                }
                normalize_frame(
                    mapped.frame(bytes_used)?,
                    format,
                    width,
                    height,
                    bytes_per_line,
                    yuyv_color,
                )
            },
            || {
                queue_buffer(file_descriptor, buffer.index)?;
                requeued = true;
                Ok(())
            },
        );
        self.queued[index] = requeued;
        result
    }
}

impl Drop for Camera {
    fn drop(&mut self) {
        cleanup_capture(&mut self.resources, &mut self.queued, &mut self.streaming);
    }
}

pub(super) fn inventory() -> V4l2Result<Vec<V4l2DeviceInfo>> {
    super::inventory::inventory()
}

pub(super) fn inventory_device(device: &str) -> V4l2Result<V4l2DeviceInfo> {
    super::inventory::inventory_device(device)
}

fn device_open_flags() -> i32 {
    libc::O_NONBLOCK | libc::O_CLOEXEC | libc::O_NOCTTY
}

pub(super) fn open_device(path: &Path, writable: bool) -> V4l2Result<File> {
    let mut options = OpenOptions::new();
    options
        .read(true)
        .write(writable)
        .custom_flags(device_open_flags());
    let file = options
        .open(path)
        .map_err(|error| io_error("open V4L2 device", error))?;
    let file_type = file
        .metadata()
        .map_err(|error| io_error("inspect V4L2 device", error))?
        .file_type();
    if !file_type.is_char_device() {
        return Err(V4l2Error::InvalidConfig(format!(
            "{} is not a character device",
            path.display()
        )));
    }
    Ok(file)
}

pub(super) fn query_capability(file: &File) -> V4l2Result<Capability> {
    let mut value = Capability::default();
    ioctl_mut(file, VIDIOC_QUERYCAP, &mut value, "VIDIOC_QUERYCAP")?;
    Ok(value)
}

fn effective_capabilities(value: &Capability) -> u32 {
    if value.capabilities & CAP_DEVICE_CAPS != 0 {
        value.device_caps
    } else {
        value.capabilities
    }
}

pub(super) fn public_capabilities(value: &Capability) -> V4l2Capabilities {
    let effective = effective_capabilities(value);
    V4l2Capabilities {
        raw: value.capabilities,
        device_raw: effective,
        video_capture: effective & CAP_VIDEO_CAPTURE != 0,
        video_capture_mplane: effective & CAP_VIDEO_CAPTURE_MPLANE != 0,
        streaming: effective & CAP_STREAMING != 0,
        read_write: effective & CAP_READWRITE != 0,
        metadata_capture: effective & CAP_META_CAPTURE != 0,
    }
}

fn require_capture_capabilities(value: &Capability) -> V4l2Result<()> {
    let capabilities = public_capabilities(value);
    if !capabilities.video_capture {
        return Err(V4l2Error::MissingCapability("single-planar video capture"));
    }
    if !capabilities.streaming {
        return Err(V4l2Error::MissingCapability("mmap streaming"));
    }
    Ok(())
}

struct NegotiatedFormat {
    pixel: PixelFormat,
    yuyv_color: YuyvColorProfile,
}

fn negotiate_format(
    file: &File,
    config: &V4l2Config,
    native: NativeFormat,
    capability: &Capability,
) -> V4l2Result<NegotiatedFormat> {
    let supports_extended = effective_capabilities(capability) & CAP_EXT_PIX_FORMAT != 0;
    let mut format = Format {
        type_: BUF_TYPE_VIDEO_CAPTURE,
        ..Format::default()
    };
    format.value.pixel = PixelFormat {
        width: config.width,
        height: config.height,
        pixel_format: native.fourcc(),
        field: FIELD_ANY,
        private: if supports_extended {
            PIX_FMT_PRIV_MAGIC
        } else {
            0
        },
        ..PixelFormat::default()
    };
    ioctl_mut(file, VIDIOC_S_FMT, &mut format, "VIDIOC_S_FMT")?;
    // SAFETY: The ioctl succeeded for the single-planar capture type, so the
    // kernel initialized the PixelFormat member of this union.
    let actual = unsafe { format.value.pixel };
    require_exact("width", config.width, actual.width)?;
    require_exact("height", config.height, actual.height)?;
    require_exact(
        "pixel format",
        native.fourcc_name().to_string(),
        fourcc_string(actual.pixel_format),
    )?;
    let minimum = native.minimum_row_bytes(config.width)?;
    if native != NativeFormat::Mjpeg
        && actual.bytes_per_line != 0
        && (actual.bytes_per_line as usize) < minimum
    {
        return Err(V4l2Error::InvalidFrame(format!(
            "driver negotiated {} bytes per line, below required {minimum}",
            actual.bytes_per_line
        )));
    }
    if actual.size_image as usize > MAX_MAPPED_BUFFER_BYTES {
        return Err(V4l2Error::InvalidFrame(format!(
            "negotiated image size {} exceeds {MAX_MAPPED_BUFFER_BYTES}-byte buffer bound",
            actual.size_image
        )));
    }
    let extended = supports_extended && actual.private == PIX_FMT_PRIV_MAGIC;
    let yuyv_color = if native == NativeFormat::Yuyv {
        resolve_yuyv_color(
            actual.color_space,
            actual.ycbcr_encoding,
            actual.quantization,
            extended,
        )?
    } else {
        YuyvColorProfile::default()
    };
    Ok(NegotiatedFormat {
        pixel: actual,
        yuyv_color,
    })
}

fn negotiate_frame_interval(file: &File, fps: u32) -> V4l2Result<()> {
    let mut parameters = StreamParameters {
        type_: BUF_TYPE_VIDEO_CAPTURE,
        ..StreamParameters::default()
    };
    ioctl_mut(file, VIDIOC_G_PARM, &mut parameters, "VIDIOC_G_PARM")?;
    // SAFETY: G_PARM succeeded for the capture type and initialized capture.
    let mut capture = unsafe { parameters.value.capture };
    let requested = Fraction {
        numerator: 1,
        denominator: fps,
    };
    if capture.capability & CAP_TIME_PER_FRAME != 0 {
        capture.time_per_frame = requested;
        parameters.value.capture = capture;
        ioctl_mut(file, VIDIOC_S_PARM, &mut parameters, "VIDIOC_S_PARM")?;
        // SAFETY: S_PARM succeeded and returned capture parameters.
        capture = unsafe { parameters.value.capture };
    }
    require_exact_interval(
        requested.numerator,
        requested.denominator,
        capture.time_per_frame.numerator,
        capture.time_per_frame.denominator,
    )
}

fn map_capture_buffers(file: &File, minimum_length: u32) -> V4l2Result<Vec<MappedBuffer>> {
    let mut request = RequestBuffers {
        count: REQUESTED_BUFFER_COUNT,
        type_: BUF_TYPE_VIDEO_CAPTURE,
        memory: MEMORY_MMAP,
        ..RequestBuffers::default()
    };
    ioctl_mut(file, VIDIOC_REQBUFS, &mut request, "VIDIOC_REQBUFS")?;
    if !(MINIMUM_BUFFER_COUNT..=REQUESTED_BUFFER_COUNT).contains(&request.count) {
        return Err(V4l2Error::InvalidFrame(format!(
            "driver allocated {} mmap buffers; require {MINIMUM_BUFFER_COUNT}..={REQUESTED_BUFFER_COUNT}",
            request.count
        )));
    }
    let mut total = 0usize;
    let mut buffers = Vec::with_capacity(request.count as usize);
    for index in 0..request.count {
        let mut query = capture_buffer(index);
        ioctl_mut(file, VIDIOC_QUERYBUF, &mut query, "VIDIOC_QUERYBUF")?;
        let length = query.length as usize;
        if length < minimum_length as usize {
            return Err(V4l2Error::InvalidFrame(format!(
                "buffer {index} is {length} bytes, below negotiated image size {minimum_length}"
            )));
        }
        if length > MAX_MAPPED_BUFFER_BYTES {
            return Err(V4l2Error::InvalidFrame(format!(
                "buffer {index} is {length} bytes, above {MAX_MAPPED_BUFFER_BYTES}-byte bound"
            )));
        }
        total = total
            .checked_add(length)
            .ok_or_else(|| V4l2Error::InvalidFrame("total mmap buffer length overflow".into()))?;
        if total > MAX_TOTAL_MAPPED_BYTES {
            return Err(V4l2Error::InvalidFrame(format!(
                "mmap buffers require {total} bytes, above {MAX_TOTAL_MAPPED_BYTES}-byte bound"
            )));
        }
        // SAFETY: QUERYBUF succeeded for MMAP and initialized offset.
        let offset = unsafe { query.location.offset };
        buffers.push(MappedBuffer::map(file, length, offset)?);
    }
    Ok(buffers)
}

fn capture_buffer(index: u32) -> Buffer {
    Buffer {
        index,
        type_: BUF_TYPE_VIDEO_CAPTURE,
        memory: MEMORY_MMAP,
        ..Buffer::default()
    }
}

fn queue_buffer(file_descriptor: RawFd, index: u32) -> V4l2Result<()> {
    let mut buffer = capture_buffer(index);
    ioctl_fd(file_descriptor, VIDIOC_QBUF, &mut buffer, "VIDIOC_QBUF")
}

fn dequeue_buffer(file: &File) -> V4l2Result<Buffer> {
    let mut buffer = capture_buffer(0);
    ioctl_mut(file, VIDIOC_DQBUF, &mut buffer, "VIDIOC_DQBUF")?;
    Ok(buffer)
}

fn stream_off(file: &File) -> V4l2Result<()> {
    let mut buffer_type = BUF_TYPE_VIDEO_CAPTURE;
    ioctl_mut(file, VIDIOC_STREAMOFF, &mut buffer_type, "VIDIOC_STREAMOFF")
}

fn poll_readable(file_descriptor: RawFd, timeout: Duration) -> V4l2Result<bool> {
    let milliseconds = timeout.as_millis().clamp(1, i32::MAX as u128) as i32;
    let mut descriptor = libc::pollfd {
        fd: file_descriptor,
        events: libc::POLLIN | libc::POLLPRI,
        revents: 0,
    };
    // SAFETY: `descriptor` is a valid one-element pollfd array.
    let result = unsafe { libc::poll(&mut descriptor, 1, milliseconds) };
    if result > 0 {
        let fatal = descriptor.revents & (libc::POLLERR | libc::POLLHUP | libc::POLLNVAL);
        if fatal != 0 {
            return Err(io_error(
                "poll V4L2 frame readiness",
                io::Error::other(format!("poll returned revents {:#x}", descriptor.revents)),
            ));
        }
        return Ok(descriptor.revents & (libc::POLLIN | libc::POLLPRI) != 0);
    }
    if result == 0 {
        return Ok(false);
    }
    let error = io::Error::last_os_error();
    if error.kind() == io::ErrorKind::Interrupted {
        Ok(false)
    } else {
        Err(io_error("poll V4L2 frame readiness", error))
    }
}

pub(super) fn ioctl_mut<T>(
    file: &File,
    request: libc::Ioctl,
    value: &mut T,
    operation: &'static str,
) -> V4l2Result<()> {
    ioctl_fd(file.as_raw_fd(), request, value, operation)
}

fn ioctl_fd<T>(
    file_descriptor: RawFd,
    request: libc::Ioctl,
    value: &mut T,
    operation: &'static str,
) -> V4l2Result<()> {
    // SAFETY: Each call supplies a valid file descriptor and a mutable pointer
    // to the repr(C) record associated with this ioctl request.
    if unsafe { libc::ioctl(file_descriptor, request, value as *mut T) } >= 0 {
        Ok(())
    } else {
        Err(io_error(operation, io::Error::last_os_error()))
    }
}

fn io_error(operation: &'static str, source: io::Error) -> V4l2Error {
    V4l2Error::Io { operation, source }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn device_open_cannot_acquire_a_controlling_terminal() {
        assert_ne!(device_open_flags() & libc::O_NOCTTY, 0);
        assert_ne!(device_open_flags() & libc::O_NONBLOCK, 0);
        assert_ne!(device_open_flags() & libc::O_CLOEXEC, 0);
    }

    #[test]
    fn effective_capabilities_use_device_specific_mask() {
        let value = Capability {
            capabilities: CAP_DEVICE_CAPS | CAP_VIDEO_CAPTURE | CAP_STREAMING,
            device_caps: CAP_VIDEO_CAPTURE_MPLANE,
            ..Capability::default()
        };
        let public = public_capabilities(&value);
        assert!(!public.video_capture);
        assert!(public.video_capture_mplane);
        assert!(!public.streaming);
    }
}
