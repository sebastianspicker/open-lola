//! Interactive station GUI (egui) fully wired to StationUIController.
//!
//! Every control panel binds to the real controller / session path — no decorative
//! placeholder widgets. Headless path is `StationUIController::run_headless` via CLI.
//!
//! Blocking compatibility calls remain available to headless callers. Egui uses
//! explicit asynchronous Check, Connect, Listen, and Stop commands.

use crate::ui::controller::StationUIController;
use eframe::egui;
use eframe::egui::{Color32, TextureHandle};

mod model;
mod settings;

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
    preview_frame: u64,
    preview_w: u32,
    preview_h: u32,
    process_priority: String,
    record_path: String,
}

impl eframe::App for StationApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        self.refresh_live_status();
        self.update_preview(ctx);
        if self.controller.live_running()
            || self.controller.check_pending()
            || self.controller.get_state().test_signal_active
        {
            ctx.request_repaint_after(std::time::Duration::from_millis(100));
        }

        let status = self.controller.get_state().status.clone();
        let connected = self.controller.live_running() || self.controller.check_pending();

        egui::TopBottomPanel::top("top").show(ctx, |ui| {
            ui.horizontal(|ui| {
                ui.heading("rusty-lola station");
                ui.separator();
                ui.label(format!("status: {status}"));
                if self.controller.live_running() {
                    ui.colored_label(Color32::LIGHT_GREEN, "● LIVE");
                }
                if self.controller.get_state().test_signal_active {
                    ui.colored_label(Color32::YELLOW, "TEST SIG");
                }
                let tabs = self.controller.board().to_dict();
                if let Some(leds) = tabs.get("leds") {
                    ui.label(format!(
                        "LED1={} LED2={} LED3={}",
                        leds.get("1").and_then(|v| v.as_str()).unwrap_or("?"),
                        leds.get("2").and_then(|v| v.as_str()).unwrap_or("?"),
                        leds.get("3").and_then(|v| v.as_str()).unwrap_or("?")
                    ));
                }
                ui.separator();
                ui.label(format!("TX est. {:.1} Mbps", self.bw_mbps));
            });
        });

        egui::SidePanel::left("controls")
            .default_width(340.0)
            .show(ctx, |ui| {
                egui::ScrollArea::vertical().show(ui, |ui| {
                    ui.heading("Connection");
                    ui.horizontal(|ui| {
                        ui.label("Remote IP");
                        ui.add_enabled(!connected, egui::TextEdit::singleline(&mut self.remote_ip));
                    });
                    ui.horizontal(|ui| {
                        ui.label("Local IP");
                        ui.add_enabled(!connected, egui::TextEdit::singleline(&mut self.local_ip));
                    });
                    let mut peer_mode = self.controller.get_state().peer_mode.clone();
                    ui.horizontal(|ui| {
                        ui.label("Peer role");
                        egui::ComboBox::from_id_salt("peer_mode")
                            .selected_text(&peer_mode)
                            .show_ui(ui, |ui| {
                                ui.selectable_value(&mut peer_mode, "remote".into(), "Remote");
                                ui.selectable_value(&mut peer_mode, "listen".into(), "Listen");
                                ui.selectable_value(
                                    &mut peer_mode,
                                    "loopback".into(),
                                    "Loopback (diagnostic)",
                                );
                            });
                    });
                    if peer_mode != self.controller.get_state().peer_mode {
                        if let Err(error) = self.controller.set_peer_mode(&peer_mode) {
                            self.push_log(format!("peer role rejected: {error}"));
                        }
                    }
                    if ui
                        .add_enabled(!connected, egui::Button::new("Apply IPs"))
                        .clicked()
                    {
                        self.controller.set_remote_ip(&self.remote_ip);
                        self.controller.state_mut().local_ip = self.local_ip.clone();
                        self.push_log(format!("remote={} local={}", self.remote_ip, self.local_ip));
                    }

                    ui.checkbox(&mut self.continuous, "continuous stream after connect");
                    ui.horizontal_wrapped(|ui| {
                        if ui
                            .add_enabled(!connected, egui::Button::new("Check"))
                            .clicked()
                        {
                            self.controller.set_remote_ip(&self.remote_ip);
                            let r = self.controller.start_check(self.timeout as f64);
                            self.last_status = self.controller.get_state().status.clone();
                            self.push_log(format!(
                                "control check pending={} (no QUICKCONN or media)",
                                r.get("pending").and_then(|v| v.as_bool()).unwrap_or(false)
                            ));
                        }
                        if ui
                            .add_enabled(!connected, egui::Button::new("Connect"))
                            .clicked()
                        {
                            self.controller.set_remote_ip(&self.remote_ip);
                            let r = self.controller.start_connect(
                                self.timeout as f64,
                                self.frames,
                                true,
                                self.continuous,
                            );
                            self.last_status = self.controller.get_state().status.clone();
                            self.push_log(format!("connect requested status={}", self.last_status));
                            let _ = r;
                        }
                        if ui
                            .add_enabled(!connected, egui::Button::new("Listen"))
                            .clicked()
                        {
                            let _ = self.controller.start_listen(self.timeout as f64, true);
                            self.last_status = self.controller.get_state().status.clone();
                            self.push_log(format!("listen requested status={}", self.last_status));
                        }
                        if ui
                            .add_enabled(self.controller.live_running(), egui::Button::new("Stop"))
                            .clicked()
                        {
                            let _ = self.controller.request_stop_live();
                            self.push_log("stop requested");
                            self.last_status = "disconnecting".into();
                        }
                    });

                    ui.separator();
                    ui.heading("Sessions");
                    ui.horizontal(|ui| {
                        for tid in 1i32..=3 {
                            if ui.button(format!("Tab {tid}")).clicked() {
                                let _ = self.controller.select_tab(tid);
                                let _ = self.controller.enable_tab(tid, true);
                                self.remote_ip = self.controller.get_state().remote_ip.clone();
                                self.push_log(format!("selected tab {tid}"));
                            }
                        }
                    });
                    ui.label(format!(
                        "active SID={}",
                        self.controller.get_state().session_id
                    ));

                    ui.separator();
                    ui.heading("Stream toggles");
                    ui.horizontal(|ui| {
                        if ui
                            .add_enabled(
                                !connected,
                                egui::Checkbox::new(&mut self.tx_video, "TX V"),
                            )
                            .changed()
                        {
                            let _ = self
                                .controller
                                .set_stream_toggle("tx", "video", self.tx_video);
                        }
                        if ui
                            .add_enabled(
                                !connected,
                                egui::Checkbox::new(&mut self.tx_audio, "TX A"),
                            )
                            .changed()
                        {
                            let _ = self
                                .controller
                                .set_stream_toggle("tx", "audio", self.tx_audio);
                        }
                        if ui
                            .add_enabled(
                                !connected,
                                egui::Checkbox::new(&mut self.rx_video, "RX V"),
                            )
                            .changed()
                        {
                            let _ = self
                                .controller
                                .set_stream_toggle("rx", "video", self.rx_video);
                        }
                        if ui
                            .add_enabled(
                                !connected,
                                egui::Checkbox::new(&mut self.rx_audio, "RX A"),
                            )
                            .changed()
                        {
                            let _ = self
                                .controller
                                .set_stream_toggle("rx", "audio", self.rx_audio);
                        }
                    });

                    ui.separator();
                    ui.heading("Record / Chat");
                    ui.horizontal(|ui| {
                        ui.label("path");
                        ui.add_enabled(
                            !connected,
                            egui::TextEdit::singleline(&mut self.record_path),
                        );
                    });
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
                    ui.horizontal(|ui| {
                        ui.text_edit_singleline(&mut self.chat_input);
                        if ui.button("Send chat").clicked() {
                            let r = self.controller.send_chat(&self.chat_input);
                            self.push_log(format!(
                                "chat ok={}",
                                r.get("ok").and_then(|v| v.as_bool()).unwrap_or(false)
                            ));
                            self.chat_input.clear();
                        }
                    });
                    ui.label(format!(
                        "chat history: {}",
                        self.controller.get_state().last_chat.join(" | ")
                    ));

                    ui.separator();
                    ui.heading("Productivity");
                    ui.horizontal(|ui| {
                        ui.label("TX audio level");
                        if ui
                            .add_enabled(!connected, egui::Slider::new(&mut self.tx_level, 1..=2))
                            .changed()
                        {
                            self.controller.set_tx_audio_level(self.tx_level);
                        }
                    });
                    ui.horizontal(|ui| {
                        ui.label("Camera #");
                        if ui
                            .add_enabled(
                                !connected,
                                egui::Slider::new(&mut self.camera_index, 0..=3),
                            )
                            .changed()
                        {
                            let idx = self.controller.set_local_camera(self.camera_index);
                            self.push_log(format!("camera_index={idx}"));
                        }
                    });
                    ui.horizontal(|ui| {
                        if ui.button("tile_v").clicked() {
                            self.layout_mode = "tile_v".into();
                            let _ = self.controller.layout_windows("tile_v");
                        }
                        if ui.button("tile_h").clicked() {
                            self.layout_mode = "tile_h".into();
                            let _ = self.controller.layout_windows("tile_h");
                        }
                        if ui.button("max_remote").clicked() {
                            self.layout_mode = "max_remote".into();
                            let _ = self.controller.layout_windows("max_remote");
                        }
                    });
                    ui.label(format!("layout={}", self.layout_mode));
                    ui.horizontal(|ui| {
                        if ui.button("Refresh BW").clicked() {
                            self.bw_mbps = self.controller.estimate_bandwidth();
                            self.push_log(format!("bw={:.3} Mbps", self.bw_mbps));
                        }
                        if ui.button("Priority high").clicked() {
                            self.process_priority =
                                self.controller.set_process_priority_level("high");
                            self.push_log(format!("priority={}", self.process_priority));
                        }
                        if ui.button("Priority normal").clicked() {
                            self.process_priority =
                                self.controller.set_process_priority_level("normal");
                            self.push_log(format!("priority={}", self.process_priority));
                        }
                    });
                    ui.horizontal(|ui| {
                        if ui
                            .add_enabled(!connected, egui::Button::new("Test signals ON"))
                            .clicked()
                        {
                            let r = self.controller.start_test_signals(true);
                            self.push_log(format!(
                                "test signals configured={}",
                                r.get("ok").and_then(|v| v.as_bool()).unwrap_or(false)
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
                });
            });

        egui::CentralPanel::default().show(ctx, |ui| {
            ui.heading("Preview / Status / Monitor");
            ui.horizontal(|ui| {
                // Live software preview pane (SMPTE when test signals active)
                if let Some(tex) = &self.preview_tex {
                    ui.group(|ui| {
                        ui.label(if self.controller.get_state().test_signal_active {
                            "Diagnostic preview (synthetic SMPTE test signal)"
                        } else if self.preview_is_live {
                            "Latest session video preview"
                        } else {
                            "Local UI preview (synthetic)"
                        });
                        ui.image((tex.id(), egui::vec2(480.0, 270.0)));
                    });
                }
                ui.vertical(|ui| {
                    let st = self.controller.get_state();
                    ui.monospace(format!("status={}", st.status));
                    ui.monospace(format!("remote={} local={}", st.remote_ip, st.local_ip));
                    ui.monospace(format!(
                        "ports C={} A={} V={} SID={}",
                        st.control_port, st.audio_port, st.video_port, st.session_id
                    ));
                    ui.monospace(format!(
                        "live_running={} continuous={}",
                        self.controller.live_running(),
                        st.continuous_live
                    ));
                    ui.monospace(format!(
                        "tx_level={} cam_idx={} bw={:.3} prio={}",
                        st.tx_audio_level,
                        st.local_camera_index,
                        st.estimated_tx_mbps,
                        st.process_priority
                    ));
                    ui.monospace(format!(
                        "stream TX-V={} TX-A={} RX-V={} RX-A={}",
                        st.stream_toggles.get("tx_video").copied().unwrap_or(true),
                        st.stream_toggles.get("tx_audio").copied().unwrap_or(true),
                        st.stream_toggles.get("rx_video").copied().unwrap_or(true),
                        st.stream_toggles.get("rx_audio").copied().unwrap_or(true),
                    ));
                    ui.monospace(format!(
                        "mode={} compress={} bayer={} color={}",
                        st.camera_mode_id, st.compression, st.auto_bayer, st.apply_color
                    ));
                });
            });

            if self.controller.live_running() {
                let r = self.controller.live_report();
                ui.separator();
                ui.label("Live report");
                ui.monospace(format!(
                    "requested A={} V={} transport={}",
                    r.get("requested_audio_backend")
                        .and_then(|v| v.as_str())
                        .unwrap_or("?"),
                    r.get("requested_video_backend")
                        .and_then(|v| v.as_str())
                        .unwrap_or("?"),
                    r.get("requested_transport")
                        .and_then(|v| v.as_str())
                        .unwrap_or("?"),
                ));
                ui.monospace(format!(
                    "active A={} V={} transport={} evidence={}",
                    r.get("active_audio_backend")
                        .and_then(|v| v.as_str())
                        .unwrap_or("initializing"),
                    r.get("active_video_backend")
                        .and_then(|v| v.as_str())
                        .unwrap_or("initializing"),
                    r.get("active_transport")
                        .and_then(|v| v.as_str())
                        .unwrap_or("initializing"),
                    r.get("evidence")
                        .and_then(|v| v.as_str())
                        .unwrap_or("unknown"),
                ));
                ui.monospace(format!(
                    "segments={} vf_sent={} af_sent={} status={}",
                    r.get("segments").and_then(|v| v.as_u64()).unwrap_or(0),
                    r.get("video_frames_sent")
                        .and_then(|v| v.as_u64())
                        .unwrap_or(0),
                    r.get("audio_frames_sent")
                        .and_then(|v| v.as_u64())
                        .unwrap_or(0),
                    r.get("status").and_then(|v| v.as_str()).unwrap_or("?"),
                ));
            }

            let st = self.controller.get_state();
            if let Some(mon) = st
                .last_result
                .as_ref()
                .and_then(|r| r.get("network_monitor"))
            {
                ui.separator();
                ui.label("Network monitor");
                ui.monospace(serde_json::to_string_pretty(mon).unwrap_or_default());
            }
            if let Some(caps) = st.last_result.as_ref().and_then(|r| r.get("capabilities")) {
                ui.separator();
                ui.label("Negotiated capabilities");
                ui.monospace(serde_json::to_string_pretty(caps).unwrap_or_default());
            }

            ui.separator();
            ui.heading("Log");
            egui::ScrollArea::vertical()
                .max_height(220.0)
                .show(ui, |ui| {
                    for line in &self.log {
                        ui.label(line);
                    }
                });
        });
    }
}
