//! Station configuration precedence: settings, imported session, CLI overrides.

use crate::config::{default_settings, load_settings, save_settings, StationSettings};
use crate::station::{apply_profile_to_settings, load_session_input};
use std::path::Path;

pub(super) fn load_station_settings(
    settings_path: Option<&Path>,
    session_path: Option<&Path>,
) -> Result<StationSettings, String> {
    let mut settings = match settings_path {
        Some(path) if path.is_file() => load_settings(path).map_err(|error| error.to_string())?,
        Some(path) => {
            let settings = default_settings();
            save_settings(path, &settings).map_err(|error| error.to_string())?;
            settings
        }
        None => default_settings(),
    };
    if let Some(path) = session_path {
        let profile = load_session_input(path).map_err(|error| error.to_string())?;
        apply_profile_to_settings(&mut settings, &profile);
    }
    Ok(settings)
}
