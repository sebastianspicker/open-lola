use super::linux::{ioctl_mut, open_device, public_capabilities, query_capability};
use super::uapi::*;
use super::*;
use std::fs::File;
use std::path::Path;
use std::time::{Duration, Instant};

const MAX_FORMATS: u32 = 256;
const MAX_MODES_PER_FORMAT: u32 = 4096;
const MAX_INTERVALS_PER_MODE: u32 = 4096;
const MAX_DEVICE_IOCTLS: usize = 16_384;
const MAX_DEVICE_RECORDS: usize = 8_192;
const MAX_DEVICE_ENUMERATION_TIME: Duration = Duration::from_secs(2);

struct EnumerationBudget {
    started: Instant,
    ioctls: usize,
    records: usize,
    max_ioctls: usize,
    max_records: usize,
    max_time: Duration,
}

impl EnumerationBudget {
    fn new() -> Self {
        Self {
            started: Instant::now(),
            ioctls: 0,
            records: 0,
            max_ioctls: MAX_DEVICE_IOCTLS,
            max_records: MAX_DEVICE_RECORDS,
            max_time: MAX_DEVICE_ENUMERATION_TIME,
        }
    }

    fn before_ioctl(&mut self) -> V4l2Result<()> {
        if self.ioctls >= self.max_ioctls || self.started.elapsed() >= self.max_time {
            return Err(V4l2Error::InventoryLimit(format!(
                "device enumeration stopped after {} ioctls, {} records, or {:?}",
                self.max_ioctls, self.max_records, self.max_time
            )));
        }
        self.ioctls += 1;
        Ok(())
    }

    fn record(&mut self) -> V4l2Result<()> {
        if self.records >= self.max_records {
            return Err(V4l2Error::InventoryLimit(format!(
                "device enumeration stopped at {} records",
                self.max_records
            )));
        }
        self.records += 1;
        Ok(())
    }
}

pub(super) fn inventory() -> V4l2Result<Vec<V4l2DeviceInfo>> {
    let mut paths = Vec::new();
    for entry in std::fs::read_dir("/dev").map_err(|error| V4l2Error::Io {
        operation: "read /dev for V4L2 devices",
        source: error,
    })? {
        let entry = entry.map_err(|error| V4l2Error::Io {
            operation: "read /dev directory entry",
            source: error,
        })?;
        let name = entry.file_name();
        let name = name.to_string_lossy();
        let suffix = name.strip_prefix("video");
        if suffix
            .is_some_and(|value| !value.is_empty() && value.bytes().all(|b| b.is_ascii_digit()))
        {
            if paths.len() == 64 {
                return Err(V4l2Error::InventoryLimit(
                    "more than 64 video device nodes".into(),
                ));
            }
            paths.push(entry.path());
        }
    }
    paths.sort();
    let mut devices = Vec::new();
    let mut budget = EnumerationBudget::new();
    for path in paths {
        match inventory_path_with_budget(&path, &mut budget) {
            Ok(device) => devices.push(device),
            Err(error @ V4l2Error::InventoryLimit(_)) => return Err(error),
            Err(_) => {}
        }
    }
    Ok(devices)
}

pub(super) fn inventory_device(device: &str) -> V4l2Result<V4l2DeviceInfo> {
    if device.is_empty() {
        return Err(V4l2Error::InvalidConfig("device path is empty".into()));
    }
    inventory_path(Path::new(device))
}

fn inventory_path(path: &Path) -> V4l2Result<V4l2DeviceInfo> {
    inventory_path_with_budget(path, &mut EnumerationBudget::new())
}

fn inventory_path_with_budget(
    path: &Path,
    budget: &mut EnumerationBudget,
) -> V4l2Result<V4l2DeviceInfo> {
    let file = open_device(path, false)?;
    budget.before_ioctl()?;
    let capability = query_capability(&file)?;
    let capabilities = public_capabilities(&capability);
    let buffer_type = if capabilities.video_capture {
        Some(BUF_TYPE_VIDEO_CAPTURE)
    } else if capabilities.video_capture_mplane {
        Some(BUF_TYPE_VIDEO_CAPTURE_MPLANE)
    } else {
        None
    };
    let formats = buffer_type
        .map(|value| enumerate_formats(&file, value, budget))
        .transpose()?
        .unwrap_or_default();
    Ok(V4l2DeviceInfo {
        device: path.to_string_lossy().into_owned(),
        driver: fixed_string(&capability.driver),
        card: fixed_string(&capability.card),
        bus_info: fixed_string(&capability.bus_info),
        version: capability.version,
        capabilities,
        formats,
    })
}

fn enumerate_formats(
    file: &File,
    buffer_type: u32,
    budget: &mut EnumerationBudget,
) -> V4l2Result<Vec<V4l2FormatInfo>> {
    let mut formats = Vec::new();
    for index in 0..MAX_FORMATS {
        let mut description = FormatDescription {
            index,
            type_: buffer_type,
            ..FormatDescription::default()
        };
        if enum_ioctl(
            file,
            VIDIOC_ENUM_FMT,
            &mut description,
            "VIDIOC_ENUM_FMT",
            budget,
        )? {
            return Ok(formats);
        }
        budget.record()?;
        formats.push(V4l2FormatInfo {
            pixel_format: fourcc_string(description.pixel_format),
            description: fixed_string(&description.description),
            compressed: description.flags & FMT_FLAG_COMPRESSED != 0,
            emulated: description.flags & FMT_FLAG_EMULATED != 0,
            modes: enumerate_sizes(file, description.pixel_format, budget)?,
        });
    }
    Err(V4l2Error::InvalidFrame(format!(
        "format enumeration exceeded {MAX_FORMATS} entries"
    )))
}

fn enumerate_sizes(
    file: &File,
    pixel_format: u32,
    budget: &mut EnumerationBudget,
) -> V4l2Result<Vec<V4l2Mode>> {
    let mut modes = Vec::new();
    for index in 0..MAX_MODES_PER_FORMAT {
        let mut item = FrameSizeEnumeration {
            index,
            pixel_format,
            ..FrameSizeEnumeration::default()
        };
        if enum_ioctl(
            file,
            VIDIOC_ENUM_FRAMESIZES,
            &mut item,
            "VIDIOC_ENUM_FRAMESIZES",
            budget,
        )? {
            return Ok(modes);
        }
        // SAFETY: ENUM_FRAMESIZES selects the union member through `type_`.
        let (size, interval_width, interval_height) = unsafe { frame_size(&item)? };
        budget.record()?;
        modes.push(V4l2Mode {
            size,
            intervals: enumerate_intervals(
                file,
                pixel_format,
                interval_width,
                interval_height,
                budget,
            )?,
        });
    }
    Err(V4l2Error::InvalidFrame(format!(
        "frame-size enumeration exceeded {MAX_MODES_PER_FORMAT} entries"
    )))
}

unsafe fn frame_size(item: &FrameSizeEnumeration) -> V4l2Result<(V4l2FrameSize, u32, u32)> {
    match item.type_ {
        FRMSIZE_TYPE_DISCRETE => {
            // SAFETY: The type discriminator selects the discrete union member.
            let value = unsafe { item.value.discrete };
            Ok((
                V4l2FrameSize::Discrete {
                    width: value.width,
                    height: value.height,
                },
                value.width,
                value.height,
            ))
        }
        FRMSIZE_TYPE_CONTINUOUS | FRMSIZE_TYPE_STEPWISE => {
            // SAFETY: The type discriminator selects the stepwise union member.
            let value = unsafe { item.value.stepwise };
            Ok((
                V4l2FrameSize::Range {
                    continuous: item.type_ == FRMSIZE_TYPE_CONTINUOUS,
                    min_width: value.min_width,
                    max_width: value.max_width,
                    step_width: value.step_width,
                    min_height: value.min_height,
                    max_height: value.max_height,
                    step_height: value.step_height,
                },
                value.min_width,
                value.min_height,
            ))
        }
        value => Err(V4l2Error::InvalidFrame(format!(
            "unknown V4L2 frame-size type {value}"
        ))),
    }
}

fn enumerate_intervals(
    file: &File,
    pixel_format: u32,
    width: u32,
    height: u32,
    budget: &mut EnumerationBudget,
) -> V4l2Result<Vec<V4l2FrameInterval>> {
    let mut intervals = Vec::new();
    for index in 0..MAX_INTERVALS_PER_MODE {
        let mut item = FrameIntervalEnumeration {
            index,
            pixel_format,
            width,
            height,
            ..FrameIntervalEnumeration::default()
        };
        if enum_ioctl(
            file,
            VIDIOC_ENUM_FRAMEINTERVALS,
            &mut item,
            "VIDIOC_ENUM_FRAMEINTERVALS",
            budget,
        )? {
            return Ok(intervals);
        }
        budget.record()?;
        // SAFETY: ENUM_FRAMEINTERVALS initialized item and its type selects the union member.
        intervals.push(unsafe { frame_interval(&item)? });
    }
    Err(V4l2Error::InvalidFrame(format!(
        "frame-interval enumeration exceeded {MAX_INTERVALS_PER_MODE} entries"
    )))
}

unsafe fn frame_interval(item: &FrameIntervalEnumeration) -> V4l2Result<V4l2FrameInterval> {
    match item.type_ {
        FRMIVAL_TYPE_DISCRETE => {
            // SAFETY: The type discriminator selects the discrete union member.
            let value = unsafe { item.value.discrete };
            Ok(V4l2FrameInterval::Discrete {
                numerator: value.numerator,
                denominator: value.denominator,
            })
        }
        FRMIVAL_TYPE_CONTINUOUS | FRMIVAL_TYPE_STEPWISE => {
            // SAFETY: The type discriminator selects the stepwise union member.
            let value = unsafe { item.value.stepwise };
            Ok(V4l2FrameInterval::Range {
                continuous: item.type_ == FRMIVAL_TYPE_CONTINUOUS,
                min_numerator: value.min.numerator,
                min_denominator: value.min.denominator,
                max_numerator: value.max.numerator,
                max_denominator: value.max.denominator,
                step_numerator: value.step.numerator,
                step_denominator: value.step.denominator,
            })
        }
        value => Err(V4l2Error::InvalidFrame(format!(
            "unknown V4L2 frame-interval type {value}"
        ))),
    }
}

fn fixed_string(value: &[u8]) -> String {
    let length = value
        .iter()
        .position(|byte| *byte == 0)
        .unwrap_or(value.len());
    String::from_utf8_lossy(&value[..length]).into_owned()
}

fn enum_ioctl<T>(
    file: &File,
    request: libc::Ioctl,
    value: &mut T,
    operation: &'static str,
    budget: &mut EnumerationBudget,
) -> V4l2Result<bool> {
    budget.before_ioctl()?;
    match ioctl_mut(file, request, value, operation) {
        Ok(()) => Ok(false),
        Err(V4l2Error::Io { source, .. }) if source.raw_os_error() == Some(libc::EINVAL) => {
            Ok(true)
        }
        Err(error) => Err(error),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fixed_uapi_strings_stop_at_nul() {
        assert_eq!(fixed_string(b"camera\0ignored"), "camera");
        assert_eq!(fixed_string(b"camera"), "camera");
    }

    #[test]
    fn frame_ranges_preserve_continuous_values() {
        let mut continuous = FrameSizeEnumeration {
            type_: FRMSIZE_TYPE_CONTINUOUS,
            ..FrameSizeEnumeration::default()
        };
        continuous.value.stepwise = FrameSizeStepwise {
            min_width: 320,
            max_width: 1920,
            step_width: 1,
            min_height: 240,
            max_height: 1080,
            step_height: 1,
        };
        // SAFETY: The test initialized the stepwise member selected by type_.
        let (size, width, height) = unsafe { frame_size(&continuous).unwrap() };
        assert_eq!((width, height), (320, 240));
        assert!(matches!(
            size,
            V4l2FrameSize::Range {
                continuous: true,
                max_width: 1920,
                max_height: 1080,
                ..
            }
        ));
    }

    #[test]
    fn never_ending_driver_is_stopped_by_shared_budget() {
        let mut budget = EnumerationBudget {
            started: Instant::now(),
            ioctls: 0,
            records: 0,
            max_ioctls: 3,
            max_records: 3,
            max_time: Duration::from_secs(60),
        };
        for _ in 0..3 {
            budget.before_ioctl().unwrap();
            budget.record().unwrap();
        }
        assert!(matches!(
            budget.before_ioctl(),
            Err(V4l2Error::InventoryLimit(_))
        ));
        assert!(matches!(budget.record(), Err(V4l2Error::InventoryLimit(_))));
    }
}
