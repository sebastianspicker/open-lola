use super::{PreviewSource, StationApp};
use crate::station::session::VideoPreviewUpdate;
use crate::ui::controller::{DeskSection, StationUIController};
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
            preview_source: PreviewSource::Synthetic { test_signal: false },
            preview_generation: None,
            preview_w: 320,
            preview_h: 180,
            process_priority,
            record_path,
            section: DeskSection::Session,
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

    /// Refresh the preview texture: received video first, then the local
    /// capture, then a cached synthetic placeholder.
    pub(super) fn update_preview(&mut self, context: &egui::Context) {
        let test_signal = self.controller.get_state().test_signal_active;
        if !test_signal && self.controller.live_running() && self.refresh_live_preview(context) {
            return;
        }
        self.preview_is_live = false;
        self.preview_generation = None;
        let source = PreviewSource::Synthetic { test_signal };
        if self.preview_source == source && self.preview_tex.is_some() {
            return;
        }
        self.preview_source = source;
        let (width, height) = (self.preview_w, self.preview_h);
        let rgb = if test_signal {
            generate_smpte_bars(width, height, false)
                .unwrap_or_else(|_| vec![40; (width * height * 3) as usize])
        } else {
            let mut camera = SoftwareCamera::default();
            camera.open_dims(width, height, "RGB24");
            camera.grab().0
        };
        let image = ColorImage::from_rgb([width as usize, height as usize], &rgb);
        self.set_preview_texture(context, image);
    }

    /// Shows received video when present, else the local capture. Returns
    /// whether a live frame is on display.
    fn refresh_live_preview(&mut self, context: &egui::Context) -> bool {
        let known = |app: &Self, source| {
            (app.preview_source == source && app.preview_tex.is_some())
                .then_some(app.preview_generation)
                .flatten()
        };
        let remote = self
            .controller
            .live_preview_update(known(self, PreviewSource::Remote));
        let (source, update) = match remote {
            VideoPreviewUpdate::Empty => {
                let local = self
                    .controller
                    .live_local_preview_update(known(self, PreviewSource::Local));
                (PreviewSource::Local, local)
            }
            other => (PreviewSource::Remote, other),
        };
        match update {
            VideoPreviewUpdate::Changed(preview) => {
                let image = ColorImage::from_rgb(
                    [preview.width as usize, preview.height as usize],
                    &preview.rgb,
                );
                self.set_preview_texture(context, image);
                self.preview_generation = Some(preview.generation);
                // Poll quickly while frames flow; the 100 ms timer is the fallback.
                context.request_repaint_after(std::time::Duration::from_millis(33));
            }
            VideoPreviewUpdate::Unchanged => {}
            VideoPreviewUpdate::Empty => return false,
        }
        self.preview_source = source;
        self.preview_is_live = true;
        true
    }

    fn set_preview_texture(&mut self, context: &egui::Context, image: ColorImage) {
        match &mut self.preview_tex {
            Some(texture) => texture.set(image, TextureOptions::LINEAR),
            None => {
                self.preview_tex =
                    Some(context.load_texture("station_preview", image, TextureOptions::LINEAR));
            }
        }
    }
}
