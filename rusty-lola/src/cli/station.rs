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

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[test]
    fn station_imported_lastsnn_overrides_only_its_documented_fields() {
        let dir = tempdir().unwrap();
        let settings_path = dir.path().join("settings.json");
        let session_path = dir.path().join("LastSsn.ssn");
        let mut configured = default_settings();
        configured.video.camera_mode_id = "custom-mode".into();
        configured.network.remote_ip = "192.0.2.10".into();
        save_settings(&settings_path, &configured).unwrap();
        std::fs::write(
            &session_path,
            "[RemoteHost]\nRemoteIpAddr=192.0.2.44;0.0.0.0\n[AVBuffers]\nRemoteAudioBuffers=8;1\nRemoteVideoBuffers=0;0\n",
        )
        .unwrap();

        let settings = load_station_settings(Some(&settings_path), Some(&session_path)).unwrap();
        assert_eq!(settings.video.camera_mode_id, "custom-mode");
        assert_eq!(settings.network.remote_ip, "192.0.2.44");
        assert_eq!(settings.network.audio_receive_queue_depth, 8);
        assert_eq!(settings.network.audio_receive_prefill, 1);
        assert_eq!(settings.network.video_receive_queue_depth, 1);
        assert_eq!(settings.network.video_receive_prefill, 0);
    }
}
