//! Public V4L2 inventory records.

use super::V4l2FormatInfo;
use serde::Serialize;

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize)]
pub struct V4l2Capabilities {
    pub raw: u32,
    pub device_raw: u32,
    pub video_capture: bool,
    pub video_capture_mplane: bool,
    pub streaming: bool,
    pub read_write: bool,
    pub metadata_capture: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct V4l2DeviceInfo {
    pub device: String,
    pub driver: String,
    pub card: String,
    pub bus_info: String,
    pub version: u32,
    pub capabilities: V4l2Capabilities,
    pub formats: Vec<V4l2FormatInfo>,
    /// Why the node could not be inspected or enumeration stopped at it; such a
    /// node is still listed (with empty details) so it does not hide the others.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
}
