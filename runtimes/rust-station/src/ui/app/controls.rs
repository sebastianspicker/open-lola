//! Interactive controls and their controller event handlers.

use super::StationApp;
use crate::ui::controller::ControllerCommand;
use eframe::egui;

impl StationApp {
    pub(super) fn render_controls(&mut self, ui: &mut egui::Ui) {
        let connected = self.controller.live_running() || self.controller.check_pending();
        egui::Panel::left("controls")
            .default_size(340.0)
            .show(ui, |ui| {
                egui::ScrollArea::vertical().show(ui, |ui| {
                    self.connection_panel(ui, connected);
                    self.sessions_panel(ui);
                    self.stream_toggles_panel(ui, connected);
                    self.record_chat_panel(ui, connected);
                    self.productivity_panel(ui, connected);
                    self.settings_toggle(ui);
                });
            });
    }

    fn connection_panel(&mut self, ui: &mut egui::Ui, connected: bool) {
        ui.heading("Connection");
        self.ip_fields(ui, connected);
        self.peer_mode_selector(ui);
        self.apply_ips_button(ui, connected);
        ui.checkbox(&mut self.continuous, "continuous stream after connect");
        ui.horizontal_wrapped(|ui| {
            self.check_button(ui, connected);
        });
    }

    fn ip_fields(&mut self, ui: &mut egui::Ui, connected: bool) {
        ui.horizontal(|ui| {
            ui.label("Remote IP");
            ui.add_enabled(!connected, egui::TextEdit::singleline(&mut self.remote_ip));
        });
        ui.horizontal(|ui| {
            ui.label("Local IP");
            ui.add_enabled(!connected, egui::TextEdit::singleline(&mut self.local_ip));
        });
    }

    fn peer_mode_selector(&mut self, ui: &mut egui::Ui) {
        let mut peer_mode = self.controller.get_state().peer_mode.clone();
        ui.horizontal(|ui| {
            ui.label("Peer role");
            egui::ComboBox::from_id_salt("peer_mode")
                .selected_text(&peer_mode)
                .show_ui(ui, |ui| {
                    ui.selectable_value(&mut peer_mode, "remote".into(), "Remote");
                    ui.selectable_value(&mut peer_mode, "listen".into(), "Listen");
                    ui.selectable_value(&mut peer_mode, "loopback".into(), "Loopback (diagnostic)");
                });
        });
        if peer_mode != self.controller.get_state().peer_mode {
            if let Err(error) = self.controller.set_peer_mode(&peer_mode) {
                self.push_log(format!("peer role rejected: {error}"));
            }
        }
    }

    fn apply_ips_button(&mut self, ui: &mut egui::Ui, connected: bool) {
        if ui
            .add_enabled(!connected, egui::Button::new("Apply IPs"))
            .clicked()
        {
            self.controller.set_remote_ip(&self.remote_ip);
            self.controller.state_mut().local_ip = self.local_ip.clone();
            self.push_log(format!("remote={} local={}", self.remote_ip, self.local_ip));
        }
    }

    fn check_button(&mut self, ui: &mut egui::Ui, connected: bool) {
        if ui
            .add_enabled(!connected, egui::Button::new("Check control"))
            .clicked()
        {
            self.controller.set_remote_ip(&self.remote_ip);
            let result = self
                .controller
                .execute_command(ControllerCommand::CheckControl {
                    timeout: self.timeout as f64,
                });
            self.last_status = self.controller.get_state().status.clone();
            self.push_log(result.message);
        }
    }

    fn sessions_panel(&mut self, ui: &mut egui::Ui) {
        ui.separator();
        ui.heading("Sessions");
        ui.horizontal(|ui| {
            for tab_id in 1i32..=3 {
                if ui.button(format!("Tab {tab_id}")).clicked() {
                    let _ = self.controller.select_tab(tab_id);
                    let _ = self.controller.enable_tab(tab_id, true);
                    self.remote_ip = self.controller.get_state().remote_ip.clone();
                    self.push_log(format!("selected tab {tab_id}"));
                }
            }
        });
        ui.label(format!(
            "active SID={}",
            self.controller.get_state().session_id
        ));
    }

    fn stream_toggles_panel(&mut self, ui: &mut egui::Ui, connected: bool) {
        ui.separator();
        ui.heading("Stream toggles");
        ui.horizontal(|ui| {
            self.stream_toggle(ui, connected, "tx", "video", "TX V");
            self.stream_toggle(ui, connected, "tx", "audio", "TX A");
            self.stream_toggle(ui, connected, "rx", "video", "RX V");
            self.stream_toggle(ui, connected, "rx", "audio", "RX A");
        });
    }

    fn stream_toggle(
        &mut self,
        ui: &mut egui::Ui,
        connected: bool,
        direction: &str,
        media: &str,
        label: &str,
    ) {
        let value = match (direction, media) {
            ("tx", "video") => &mut self.tx_video,
            ("tx", "audio") => &mut self.tx_audio,
            ("rx", "video") => &mut self.rx_video,
            ("rx", "audio") => &mut self.rx_audio,
            _ => unreachable!("fixed stream toggle mapping"),
        };
        if ui
            .add_enabled(!connected, egui::Checkbox::new(value, label))
            .changed()
        {
            let _ = self.controller.set_stream_toggle(direction, media, *value);
        }
    }

    fn record_chat_panel(&mut self, ui: &mut egui::Ui, connected: bool) {
        ui.separator();
        ui.heading("Record / Chat");
        ui.horizontal(|ui| {
            ui.label("path");
            ui.add_enabled(
                !connected,
                egui::TextEdit::singleline(&mut self.record_path),
            );
        });
        self.record_toggle(ui, connected);
        self.chat_controls(ui);
        ui.label(format!(
            "chat history: {}",
            self.controller.get_state().last_chat.join(" | ")
        ));
    }

    fn record_toggle(&mut self, ui: &mut egui::Ui, connected: bool) {
        if ui
            .add_enabled(
                !connected,
                egui::Checkbox::new(&mut self.record_enabled, "Record"),
            )
            .changed()
        {
            self.controller
                .set_record_enabled(self.record_enabled, Some(&self.record_path));
            self.push_log(format!(
                "record={} path={}",
                self.record_enabled, self.record_path
            ));
        }
    }

    fn chat_controls(&mut self, ui: &mut egui::Ui) {
        ui.horizontal(|ui| {
            ui.text_edit_singleline(&mut self.chat_input);
            if ui.button("Send chat").clicked() {
                let result = self.controller.send_chat(&self.chat_input);
                self.push_log(format!(
                    "chat ok={}",
                    result
                        .get("ok")
                        .and_then(|value| value.as_bool())
                        .unwrap_or(false)
                ));
                self.chat_input.clear();
            }
        });
    }

    fn productivity_panel(&mut self, ui: &mut egui::Ui, connected: bool) {
        ui.separator();
        ui.heading("Productivity");
        self.audio_level_control(ui, connected);
        self.camera_control(ui, connected);
        self.layout_controls(ui);
        self.performance_controls(ui);
        self.test_signal_controls(ui, connected);
    }

    fn audio_level_control(&mut self, ui: &mut egui::Ui, connected: bool) {
        ui.horizontal(|ui| {
            ui.label("TX audio level");
            if ui
                .add_enabled(!connected, egui::Slider::new(&mut self.tx_level, 1..=2))
                .changed()
            {
                self.controller.set_tx_audio_level(self.tx_level);
            }
        });
    }

    fn camera_control(&mut self, ui: &mut egui::Ui, connected: bool) {
        ui.horizontal(|ui| {
            ui.label("Camera #");
            if ui
                .add_enabled(!connected, egui::Slider::new(&mut self.camera_index, 0..=3))
                .changed()
            {
                let index = self.controller.set_local_camera(self.camera_index);
                self.push_log(format!("camera_index={index}"));
            }
        });
    }

    fn layout_controls(&mut self, ui: &mut egui::Ui) {
        ui.horizontal(|ui| {
            self.layout_button(ui, "tile_v");
            self.layout_button(ui, "tile_h");
            self.layout_button(ui, "max_remote");
        });
        ui.label(format!("layout={}", self.layout_mode));
    }

    fn layout_button(&mut self, ui: &mut egui::Ui, layout: &str) {
        if ui.button(layout).clicked() {
            self.layout_mode = layout.into();
            let _ = self.controller.layout_windows(layout);
        }
    }

    fn performance_controls(&mut self, ui: &mut egui::Ui) {
        ui.horizontal(|ui| {
            if ui.button("Refresh BW").clicked() {
                self.bw_mbps = self.controller.estimate_bandwidth();
                self.push_log(format!("bw={:.3} Mbps", self.bw_mbps));
            }
            self.priority_button(ui, "Priority high", "high");
            self.priority_button(ui, "Priority normal", "normal");
        });
    }

    fn priority_button(&mut self, ui: &mut egui::Ui, label: &str, level: &str) {
        if ui.button(label).clicked() {
            self.process_priority = self.controller.set_process_priority_level(level);
            self.push_log(format!("priority={}", self.process_priority));
        }
    }

    fn test_signal_controls(&mut self, ui: &mut egui::Ui, connected: bool) {
        ui.horizontal(|ui| {
            if ui
                .add_enabled(!connected, egui::Button::new("Test signals ON"))
                .clicked()
            {
                let result = self.controller.start_test_signals(true);
                self.push_log(format!(
                    "test signals configured={}",
                    result
                        .get("ok")
                        .and_then(|value| value.as_bool())
                        .unwrap_or(false)
                ));
            }
            if ui
                .add_enabled(!connected, egui::Button::new("Test signals OFF"))
                .clicked()
            {
                let _ = self.controller.stop_test_signals();
                self.push_log("test signals off");
            }
        });
    }

    fn settings_toggle(&mut self, ui: &mut egui::Ui) {
        ui.separator();
        if ui
            .add_enabled(
                !self.controller.settings_are_locked(),
                egui::Button::new("Settings…"),
            )
            .clicked()
        {
            self.show_settings = !self.show_settings;
        }
        if self.show_settings {
            self.settings_panel(ui);
        }
    }
}
