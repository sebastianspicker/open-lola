//! Interactive station GUI (egui) fully wired to StationUIController.
//!
//! Every control panel binds to the real controller / session path — no decorative
//! placeholder widgets. Headless path is `StationUIController::run_headless` via CLI.
//!
//! Blocking compatibility calls remain available to headless callers. Egui uses
//! explicit asynchronous Check, Connect, Listen, and Stop commands.

use crate::ui::controller::{DeskSection, StationUIController};
use eframe::egui;
use eframe::egui::TextureHandle;

mod controls;
mod model;
mod settings;
mod status;
mod workflow;

/// Launch interactive station window. Blocks until closed.
pub fn run_interactive_ui() -> Result<(), String> {
    let options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_inner_size([1280.0, 800.0])
            .with_title("rusty-lola station"),
        ..Default::default()
    };
    eframe::run_native(
        "rusty-lola",
        options,
        Box::new(|_cc| Ok(Box::new(StationApp::new()))),
    )
    .map_err(|e| format!("GUI error: {e}"))
}

struct StationApp {
    controller: StationUIController,
    remote_ip: String,
    local_ip: String,
    chat_input: String,
    last_status: String,
    log: Vec<String>,
    show_settings: bool,
    record_enabled: bool,
    timeout: f32,
    frames: u32,
    continuous: bool,
    tx_level: u8,
    camera_index: i32,
    layout_mode: String,
    bw_mbps: f64,
    // Stream toggles (bound to controller)
    tx_video: bool,
    tx_audio: bool,
    rx_video: bool,
    rx_audio: bool,
    // Preview texture (software / SMPTE when test signals active)
    preview_tex: Option<TextureHandle>,
    preview_is_live: bool,
    preview_generation: Option<u64>,
    preview_frame: u64,
    preview_w: u32,
    preview_h: u32,
    process_priority: String,
    record_path: String,
    section: DeskSection,
}

impl eframe::App for StationApp {
    fn ui(&mut self, ui: &mut egui::Ui, _frame: &mut eframe::Frame) {
        self.prepare_frame(ui.ctx());
        self.render_header(ui);
        self.render_action_bar(ui);
        if self.section == DeskSection::Session {
            self.render_controls(ui);
        }
        self.render_status(ui);
    }
}

impl StationApp {
    fn prepare_frame(&mut self, ctx: &egui::Context) {
        self.refresh_live_status();
        self.controller.poll_device_inventory();
        self.update_preview(ctx);
        if self.controller.live_running()
            || self.controller.check_pending()
            || self.controller.device_inventory_pending()
            || self.controller.get_state().test_signal_active
        {
            ctx.request_repaint_after(std::time::Duration::from_millis(100));
        }
    }
}
