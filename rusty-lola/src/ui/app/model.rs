use super::StationApp;
use crate::ui::controller::StationUIController;
use crate::video::{generate_smpte_bars, SoftwareCamera};
use eframe::egui::{self, ColorImage, TextureOptions};

impl StationApp {
    pub(super) fn new() -> Self {
        let mut controller = StationUIController::new(None);
        // Interactive use starts in the production client role. Loopback stays
        // available only through an explicit diagnostic selection.
        let _ = controller.set_peer_mode("remote");
        let (
            remote_ip,
            local_ip,
            tx_video,
            tx_audio,
            rx_video,
            rx_audio,
            process_priority,
            record_path,
            record_enabled,
            tx_level,
            camera_index,
        ) = {
            let state = controller.get_state();
            (
                state.remote_ip.clone(),
                state.local_ip.clone(),
                *state.stream_toggles.get("tx_video").unwrap_or(&true),
                *state.stream_toggles.get("tx_audio").unwrap_or(&true),
                *state.stream_toggles.get("rx_video").unwrap_or(&true),
                *state.stream_toggles.get("rx_audio").unwrap_or(&true),
                state.process_priority.clone(),
                if state.record_path.is_empty() {
                    "record_out".into()
                } else {
                    state.record_path.clone()
                },
                state.record_enabled,
                state.tx_audio_level,
                state.local_camera_index as i32,
            )
        };
        let bw_mbps = controller.estimate_bandwidth();
        Self {
            controller,
            remote_ip,
            local_ip,
            chat_input: String::new(),
            last_status: "idle".into(),
            log: vec!["rusty-lola interactive station ready".into()],
            show_settings: false,
            record_enabled,
            timeout: 5.0,
            frames: 3,
            continuous: true,
            tx_level,
            camera_index,
            layout_mode: "tile_v".into(),
            bw_mbps,
            tx_video,
            tx_audio,
            rx_video,
            rx_audio,
            preview_tex: None,
            preview_is_live: false,
            preview_frame: 0,
            preview_w: 320,
            preview_h: 180,
            process_priority,
            record_path,
        }
    }

    pub(super) fn push_log(&mut self, message: impl Into<String>) {
        self.log.push(message.into());
        if self.log.len() > 80 {
            self.log.drain(0..self.log.len() - 80);
        }
    }

    pub(super) fn refresh_live_status(&mut self) {
        if self.controller.live_running() || self.controller.get_state().settings_locked {
            let report = self.controller.poll_live();
            if let Some(status) = report.get("status").and_then(|value| value.as_str()) {
                self.controller.state_mut().status = status.into();
                self.last_status = status.into();
            }
        }
        if let Some(result) = self.controller.poll_reachability() {
            self.push_log(format!(
                "reachable={}",
                result
                    .get("ok")
                    .and_then(|value| value.as_bool())
                    .unwrap_or(false)
            ));
        }
    }

    /// Refresh the synthetic software/SMPTE preview texture.
    pub(super) fn update_preview(&mut self, context: &egui::Context) {
        let width = self.preview_w;
        let height = self.preview_h;
        let test_signal_active = self.controller.get_state().test_signal_active;
        let live = (!test_signal_active)
            .then(|| self.controller.live_preview())
            .flatten();
        self.preview_is_live = live.is_some();
        let (width, height, rgb) = if let Some(preview) = live {
            (preview.width, preview.height, preview.rgb)
        } else if test_signal_active {
            (
                width,
                height,
                generate_smpte_bars(width, height, false)
                    .unwrap_or_else(|_| vec![40; (width * height * 3) as usize]),
            )
        } else {
            let mut camera = SoftwareCamera::default();
            camera.open_dims(width, height, "RGB24");
            camera.frame = self.preview_frame as u32;
            (width, height, camera.grab().0)
        };
        let image = ColorImage::from_rgb([width as usize, height as usize], &rgb);
        match &mut self.preview_tex {
            Some(texture) => texture.set(image, TextureOptions::LINEAR),
            None => {
                self.preview_tex =
                    Some(context.load_texture("station_preview", image, TextureOptions::LINEAR));
            }
        }
        if self.controller.live_running() || test_signal_active {
            self.preview_frame = self.preview_frame.wrapping_add(1);
        }
    }
}
