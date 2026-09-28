use super::*;

pub(super) struct Camera;

impl Camera {
    pub(super) fn open(
        _config: &V4l2Config,
        _format: NativeFormat,
        _cancellation: Arc<AtomicBool>,
    ) -> V4l2Result<Self> {
        Err(V4l2Error::UnsupportedPlatform)
    }

    pub(super) fn start(&mut self) -> V4l2Result<()> {
        Err(V4l2Error::UnsupportedPlatform)
    }

    pub(super) fn grab(&mut self, _timeout: Duration) -> V4l2Result<(Vec<u8>, String)> {
        Err(V4l2Error::UnsupportedPlatform)
    }

    pub(super) fn stop(&mut self) -> V4l2Result<()> {
        Err(V4l2Error::UnsupportedPlatform)
    }
}

pub(super) fn inventory() -> V4l2Result<Vec<V4l2DeviceInfo>> {
    Err(V4l2Error::UnsupportedPlatform)
}

pub(super) fn inventory_device(_device: &str) -> V4l2Result<V4l2DeviceInfo> {
    Err(V4l2Error::UnsupportedPlatform)
}
