use super::{AlsaError, AlsaResult};

pub(super) fn validate_hardware_device(field: &str, value: &str) -> AlsaResult<()> {
    let suffix = if value == "hw" {
        return Ok(());
    } else if value == value.trim() {
        value.strip_prefix("hw:")
    } else {
        None
    };
    let valid = suffix.is_some_and(|suffix| {
        !suffix.is_empty()
            && suffix
                .bytes()
                .all(|byte| byte.is_ascii_alphanumeric() || b"_-,.=".contains(&byte))
    });
    if valid {
        Ok(())
    } else {
        Err(AlsaError::InvalidConfig(format!(
            "{field} must be a direct hw device; ALSA plug and virtual devices are disabled"
        )))
    }
}
