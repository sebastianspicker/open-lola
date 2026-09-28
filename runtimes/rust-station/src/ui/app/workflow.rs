//! Signal Desk navigation and persistent session actions.

use super::StationApp;
use crate::ui::controller::{ControllerCommand, DeskSection, SessionPhase};
use eframe::egui;

impl StationApp {
    pub(super) fn render_navigation(&mut self, ui: &mut egui::Ui) {
        for (section, label) in [
            (DeskSection::Session, "Session"),
            (DeskSection::Setup, "Setup"),
            (DeskSection::Monitor, "Monitor"),
            (DeskSection::Evidence, "Evidence"),
        ] {
            ui.selectable_value(&mut self.section, section, label);
        }
    }

    pub(super) fn render_action_bar(&mut self, context: &egui::Context) {
        let snapshot = self.controller.signal_desk_snapshot();
        egui::TopBottomPanel::bottom("signal_desk_actions")
            .resizable(false)
            .show(context, |ui| {
                ui.add_space(5.0);
                ui.horizontal_wrapped(|ui| {
                    ui.strong("Next");
                    ui.label(&snapshot.actions.next_action);
                    ui.separator();
                    self.command_button(
                        ui,
                        "Ready",
                        &snapshot.actions.ready,
                        ControllerCommand::ValidateSetup,
                    );
                    self.command_button(ui, "Arm", &snapshot.actions.arm, ControllerCommand::Arm);
                    self.command_button(
                        ui,
                        "Start",
                        &snapshot.actions.start,
                        ControllerCommand::Start {
                            timeout: f64::from(self.timeout),
                            frames: self.frames,
                            extras: true,
                            continuous: self.continuous,
                        },
                    );
                    self.command_button(
                        ui,
                        "Stop",
                        &snapshot.actions.stop,
                        ControllerCommand::Stop,
                    );
                    ui.separator();
                    phase_label(ui, snapshot.phase);
                    if snapshot.armed {
                        ui.colored_label(egui::Color32::from_rgb(255, 190, 70), "● ARMED");
                    }
                });
                if !snapshot.config_ready {
                    ui.small(&snapshot.readiness_detail);
                }
                ui.add_space(5.0);
            });
    }

    fn command_button(
        &mut self,
        ui: &mut egui::Ui,
        label: &str,
        state: &crate::ui::controller::ActionState,
        command: ControllerCommand,
    ) {
        let response = ui.add_enabled(state.enabled, egui::Button::new(label));
        let response = if let Some(reason) = &state.disabled_reason {
            response.on_disabled_hover_text(reason)
        } else {
            response
        };
        if response.clicked() {
            let outcome = self.controller.execute_command(command);
            self.push_log(format!(
                "{}: {}",
                if outcome.accepted { "ok" } else { "blocked" },
                outcome.message
            ));
            self.last_status = self.controller.get_state().status.clone();
        }
    }
}

fn phase_label(ui: &mut egui::Ui, phase: SessionPhase) {
    let label = match phase {
        SessionPhase::Setup => "SETUP",
        SessionPhase::Ready => "READY",
        SessionPhase::Live => "LIVE",
        SessionPhase::Review => "REVIEW",
    };
    ui.monospace(label);
}
