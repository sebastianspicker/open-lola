use super::{MfConfig, MfDeviceInfo, MfError, MfOutput, MfResult};

pub(super) struct Camera;

impl Camera {
    pub(super) fn open(_config: &MfConfig) -> MfResult<Self> {
        Err(MfError::UnsupportedPlatform)
    }

    pub(super) fn grab(&mut self, _output: MfOutput) -> MfResult<Vec<u8>> {
        Err(MfError::UnsupportedPlatform)
    }

    pub(super) fn stop(&mut self) -> MfResult<()> {
        Err(MfError::UnsupportedPlatform)
    }
}

pub(super) fn inventory() -> MfResult<Vec<MfDeviceInfo>> {
    Err(MfError::UnsupportedPlatform)
}
