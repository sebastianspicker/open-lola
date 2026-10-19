//! Station configuration precedence: settings, imported session, CLI overrides.

use crate::config::{default_settings, load_settings, save_settings, StationSettings};
use crate::station::{apply_profile_to_settings, load_session_input};
use std::path::Path;

/// Tell the operator a missing `--settings` file was created rather than loaded.
fn created_notice(path: &Path) -> String {
    format!(
        "settings file {} did not exist; created it with default settings",
        path.display()
    )
}

pub(super) fn load_station_settings(
    settings_path: Option<&Path>,
    session_path: Option<&Path>,
) -> Result<StationSettings, String> {
    let mut settings = match settings_path {
        Some(path) if path.is_file() => load_settings(path).map_err(|error| error.to_string())?,
        Some(path) => {
            let settings = default_settings();
            save_settings(path, &settings).map_err(|error| error.to_string())?;
            eprintln!("{}", created_notice(path));
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn missing_settings_file_is_created_and_named_in_the_notice() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("station.json");
        let settings = load_station_settings(Some(&path), None).unwrap();
        assert!(path.is_file());
        assert_eq!(settings.network.control_port, 7000);
        let notice = created_notice(&path);
        assert!(notice.contains(&path.display().to_string()), "{notice}");
        assert!(notice.contains("created"), "{notice}");
        // A second run loads the file instead of creating it again.
        assert!(load_station_settings(Some(&path), None).is_ok());
    }
}
