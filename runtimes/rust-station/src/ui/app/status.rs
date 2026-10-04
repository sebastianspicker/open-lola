//! Header, preview, status, and monitoring panes.

use super::StationApp;
use crate::ui::controller::{DeskSection, Measurement};
use eframe::egui;
use eframe::egui::Color32;

impl StationApp {
    pub(super) fn render_header(&mut self, ui: &mut egui::Ui) {
        let status = self.controller.get_state().status.clone();
        let snapshot = self.controller.signal_desk_snapshot();
        let audio = snapshot.audio;
        egui::Panel::top("top").show(ui, |ui| {
            ui.horizontal(|ui| {
                ui.heading("Signal Desk");
                ui.small("rusty-lola station");
                ui.separator();
                self.render_navigation(ui);
                ui.separator();
                ui.strong(format!("{:?}", snapshot.phase));
                ui.label(&snapshot.actions.next_action);
                self.live_indicators(ui);
                ui.menu_button("Inspector", |ui| self.session_inspector(ui, &status));
                ui.separator();
                ui.label(format!("TX est. {:.1} Mbps", self.bw_mbps));
            });
            ui.horizontal_wrapped(|ui| {
                ui.strong("Audio health");
                ui.label(format!("backend: {}", audio.backend.label()));
                ui.separator();
                ui.label(format!("TX: {}", audio.transmit.label()));
                ui.separator();
                ui.label(format!("RX: {}", audio.receive.label()));
                ui.separator();
                ui.label(format!("xruns: {}", audio.device_xruns.label()));
                ui.separator();
                ui.label(format!("timing: {}", audio.deadline.label()));
            });
        });
    }

    fn live_indicators(&self, ui: &mut egui::Ui) {
        if self.controller.live_running() {
            ui.colored_label(Color32::LIGHT_GREEN, "● LIVE");
        }
        if self.controller.get_state().test_signal_active {
            ui.colored_label(Color32::YELLOW, "TEST SIG");
        }
    }

    fn session_inspector(&self, ui: &mut egui::Ui, status: &str) {
        ui.monospace(format!("status={status}"));
        let tabs = self.controller.board().to_dict();
        if let Some(leds) = tabs.get("leds") {
            ui.label(format!(
                "LED1={} LED2={} LED3={}",
                leds.get("1")
                    .and_then(|value| value.as_str())
                    .unwrap_or("?"),
                leds.get("2")
                    .and_then(|value| value.as_str())
                    .unwrap_or("?"),
                leds.get("3")
                    .and_then(|value| value.as_str())
                    .unwrap_or("?")
            ));
        }
    }

    pub(super) fn render_status(&mut self, ui: &mut egui::Ui) {
        egui::CentralPanel::default().show(ui, |ui| match self.section {
            DeskSection::Session => self.session_page(ui),
            DeskSection::Setup => self.setup_page(ui),
            DeskSection::Monitor => self.monitor_page(ui),
            DeskSection::Evidence => self.evidence_page(ui),
        });
    }

    fn session_page(&self, ui: &mut egui::Ui) {
        ui.heading("Session");
        ui.label("Operate the selected session. Setup changes apply to the next start.");
        self.preview_and_state(ui);
        self.live_report_panel(ui);
        self.log_panel(ui);
    }

    fn setup_page(&mut self, ui: &mut egui::Ui) {
        ui.heading("Setup");
        ui.label("Configure → Ready → Arm → Start");
        egui::ScrollArea::vertical().show(ui, |ui| self.settings_panel(ui));
    }

    fn monitor_page(&mut self, ui: &mut egui::Ui) {
        ui.heading("Monitor");
        ui.label("Audio health");
        let snapshot = self.controller.signal_desk_snapshot();
        ui.columns(5, |columns| {
            measurement_card(&mut columns[0], "Backend", &snapshot.audio.backend);
            measurement_card(&mut columns[1], "Transmit", &snapshot.audio.transmit);
            measurement_card(&mut columns[2], "Receive", &snapshot.audio.receive);
            measurement_card(
                &mut columns[3],
                "Device xruns",
                &snapshot.audio.device_xruns,
            );
            measurement_card(&mut columns[4], "Deadline", &snapshot.audio.deadline);
        });
        ui.separator();
        self.preview_and_state(ui);
        self.live_report_panel(ui);
        self.monitor_panels(ui);
    }

    fn evidence_page(&mut self, ui: &mut egui::Ui) {
        ui.heading("Evidence");
        ui.label(
            "Each observation is reported separately; absent runtime proof remains Not measured.",
        );
        let snapshot = self.controller.signal_desk_snapshot();
        egui::Grid::new("evidence_grid")
            .num_columns(2)
            .striped(true)
            .show(ui, |ui| {
                evidence_row(
                    ui,
                    "Control reachability",
                    &snapshot.evidence.control_reachability,
                );
                evidence_row(ui, "Media negotiation", &snapshot.evidence.negotiation);
                evidence_row(ui, "Transmit", &snapshot.evidence.transmit);
                evidence_row(ui, "Receive", &snapshot.evidence.receive);
                evidence_row(
                    ui,
                    "Report validation",
                    &snapshot.evidence.report_validation,
                );
            });
        self.monitor_panels(ui);
        self.log_panel(ui);
    }

    fn preview_and_state(&self, ui: &mut egui::Ui) {
        ui.horizontal(|ui| {
            self.preview_panel(ui);
            self.state_panel(ui);
        });
    }

    fn preview_panel(&self, ui: &mut egui::Ui) {
        if let Some(texture) = &self.preview_tex {
            ui.group(|ui| {
                ui.label(self.preview_label());
                ui.image((texture.id(), egui::vec2(480.0, 270.0)));
            });
        }
    }

    fn preview_label(&self) -> &'static str {
        if self.controller.get_state().test_signal_active {
            "Diagnostic preview (synthetic SMPTE test signal)"
        } else if self.preview_is_live {
            "Latest session video preview"
        } else {
            "Local UI preview (synthetic)"
        }
    }

    fn state_panel(&self, ui: &mut egui::Ui) {
        ui.collapsing("Session inspector", |ui| {
            let state = self.controller.get_state();
            ui.monospace(format!("status={}", state.status));
            ui.monospace(format!(
                "remote={} local={}",
                state.remote_ip, state.local_ip
            ));
            ui.monospace(format!(
                "ports C={} A={} V={} SID={}",
                state.control_port, state.audio_port, state.video_port, state.session_id
            ));
            ui.monospace(format!(
                "live_running={} continuous={}",
                self.controller.live_running(),
                state.continuous_live
            ));
            ui.monospace(format!(
                "tx_level={} cam_idx={} bw={:.3} prio={}",
                state.tx_audio_level,
                state.local_camera_index,
                state.estimated_tx_mbps,
                state.process_priority
            ));
            ui.monospace(format!(
                "stream TX-V={} TX-A={} RX-V={} RX-A={}",
                state
                    .stream_toggles
                    .get("tx_video")
                    .copied()
                    .unwrap_or(true),
                state
                    .stream_toggles
                    .get("tx_audio")
                    .copied()
                    .unwrap_or(true),
                state
                    .stream_toggles
                    .get("rx_video")
                    .copied()
                    .unwrap_or(true),
                state
                    .stream_toggles
                    .get("rx_audio")
                    .copied()
                    .unwrap_or(true),
            ));
            ui.monospace(format!(
                "mode={} compress={} bayer={} color={}",
                state.camera_mode_id, state.compression, state.auto_bayer, state.apply_color
            ));
        });
    }

    fn live_report_panel(&self, ui: &mut egui::Ui) {
        if !self.controller.live_running() {
            return;
        }
        let report = self.controller.live_report();
        ui.separator();
        ui.label("Live report");
        ui.monospace(format!(
            "requested A={} V={} transport={}",
            report
                .get("requested_audio_backend")
                .and_then(|value| value.as_str())
                .unwrap_or("?"),
            report
                .get("requested_video_backend")
                .and_then(|value| value.as_str())
                .unwrap_or("?"),
            report
                .get("requested_transport")
                .and_then(|value| value.as_str())
                .unwrap_or("?"),
        ));
        ui.monospace(format!(
            "active A={} V={} transport={} evidence={}",
            report
                .get("active_audio_backend")
                .and_then(|value| value.as_str())
                .unwrap_or("initializing"),
            report
                .get("active_video_backend")
                .and_then(|value| value.as_str())
                .unwrap_or("initializing"),
            report
                .get("active_transport")
                .and_then(|value| value.as_str())
                .unwrap_or("initializing"),
            report
                .get("evidence")
                .and_then(|value| value.as_str())
                .unwrap_or("unknown"),
        ));
        ui.monospace(format!(
            "segments={} vf_sent={} af_sent={} status={}",
            report
                .get("segments")
                .and_then(|value| value.as_u64())
                .unwrap_or(0),
            report
                .get("video_frames_sent")
                .and_then(|value| value.as_u64())
                .unwrap_or(0),
            report
                .get("audio_frames_sent")
                .and_then(|value| value.as_u64())
                .unwrap_or(0),
            report
                .get("status")
                .and_then(|value| value.as_str())
                .unwrap_or("?"),
        ));
    }

    fn monitor_panels(&self, ui: &mut egui::Ui) {
        let state = self.controller.get_state();
        self.json_panel(
            ui,
            "Network monitor",
            state
                .last_result
                .as_ref()
                .and_then(|r| r.get("network_monitor")),
        );
        self.json_panel(
            ui,
            "Negotiated capabilities",
            state
                .last_result
                .as_ref()
                .and_then(|r| r.get("capabilities")),
        );
    }

    fn json_panel(&self, ui: &mut egui::Ui, label: &str, value: Option<&serde_json::Value>) {
        if let Some(value) = value {
            ui.separator();
            ui.label(label);
            ui.monospace(serde_json::to_string_pretty(value).unwrap_or_default());
        }
    }

    fn log_panel(&self, ui: &mut egui::Ui) {
        ui.separator();
        ui.heading("Log");
        egui::ScrollArea::vertical()
            .max_height(220.0)
            .show(ui, |ui| {
                for line in &self.log {
                    ui.label(line);
                }
            });
    }
}

fn measurement_card(ui: &mut egui::Ui, heading: &str, measurement: &Measurement) {
    ui.group(|ui| {
        ui.strong(heading);
        ui.label(measurement.label());
    });
}

fn evidence_row(ui: &mut egui::Ui, heading: &str, measurement: &Measurement) {
    ui.strong(heading);
    ui.monospace(measurement.label());
    ui.end_row();
}
