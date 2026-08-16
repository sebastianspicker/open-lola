//! Disconnected-only persisted station settings editor.

use super::StationApp;
use eframe::egui;

impl StationApp {
    pub(super) fn settings_panel(&mut self, ui: &mut egui::Ui) {
        ui.group(|ui| {
            ui.label("Settings (applied to the next session)");
            ui.add_enabled_ui(!self.controller.settings_are_locked(), |ui| {
                ui.add(egui::Slider::new(&mut self.timeout, 1.0..=30.0).text("timeout s"));
                ui.add(egui::Slider::new(&mut self.frames, 1..=30).text("frames"));
                self.audio_settings(ui);
                self.video_settings(ui);
                self.network_settings(ui);
                self.recording_settings(ui);
            });
            if self.controller.settings_are_locked() {
                ui.small("Streaming is active: persisted runtime settings are locked.");
            } else if ui.button("Probe reachability").clicked() {
                let _ = self.controller.start_reachability_probe();
                self.push_log("reachability probe started");
            }
        });
    }

    fn audio_settings(&mut self, ui: &mut egui::Ui) {
        ui.collapsing("Audio", |ui| {
            let state = self.controller.state_mut();
            ui.horizontal(|ui| {
                ui.label("input device");
                ui.text_edit_singleline(&mut state.input_device);
            });
            ui.horizontal(|ui| {
                ui.label("output device");
                ui.text_edit_singleline(&mut state.output_device);
            });
            ui.add(
                egui::DragValue::new(&mut state.sample_rate)
                    .range(8_000..=384_000)
                    .suffix(" Hz"),
            );
            ui.add(
                egui::DragValue::new(&mut state.audio_channels)
                    .range(1..=64)
                    .prefix("channels "),
            );
            egui::ComboBox::from_id_salt("bits_per_sample")
                .selected_text(format!("{} bits/sample", state.bits_per_sample))
                .show_ui(ui, |ui| {
                    for bits in [8, 16, 24, 32] {
                        ui.selectable_value(&mut state.bits_per_sample, bits, bits.to_string());
                    }
                });
            ui.add(
                egui::DragValue::new(&mut state.buffer_samples)
                    .range(1..=4096)
                    .prefix("callback samples "),
            );
            ui.add(
                egui::DragValue::new(&mut state.input_offset)
                    .range(0..=63)
                    .prefix("input offset "),
            );
            ui.checkbox(&mut state.local_audio_loop, "local audio loop");
            ui.add(egui::Slider::new(&mut state.tx_audio_level, 1..=2).text("TX audio level"));
            backend_selector(
                ui,
                "audio_backend",
                "audio backend",
                &mut state.audio_backend,
                true,
            );
        });
    }

    fn video_settings(&mut self, ui: &mut egui::Ui) {
        ui.collapsing("Video", |ui| {
            let state = self.controller.state_mut();
            text_field(ui, "camera mode", &mut state.camera_mode_id);
            ui.horizontal(|ui| {
                ui.add(
                    egui::DragValue::new(&mut state.video_width)
                        .range(1..=8192)
                        .prefix("width "),
                );
                ui.add(
                    egui::DragValue::new(&mut state.video_height)
                        .range(1..=8192)
                        .prefix("height "),
                );
                ui.add(
                    egui::DragValue::new(&mut state.video_fps)
                        .range(1..=480)
                        .prefix("fps "),
                );
            });
            egui::ComboBox::from_id_salt("video_bpp")
                .selected_text(format!("{} BPP", state.video_bpp))
                .show_ui(ui, |ui| {
                    for bpp in [8, 16, 24, 32] {
                        ui.selectable_value(&mut state.video_bpp, bpp, bpp.to_string());
                    }
                });
            ui.add(
                egui::DragValue::new(&mut state.video_bayer)
                    .range(0..=255)
                    .prefix("Bayer value "),
            );
            ui.add(
                egui::DragValue::new(&mut state.local_camera_index)
                    .range(0..=3)
                    .prefix("camera index "),
            );
            ui.checkbox(&mut state.compression, "JPEG compression");
            ui.add(egui::Slider::new(&mut state.jpeg_quality, 1..=100).text("JPEG quality"));
            text_field(ui, "Bayer pattern", &mut state.bayer_pattern);
            ui.checkbox(&mut state.auto_bayer, "auto Bayer");
            ui.checkbox(&mut state.audio_only, "audio only");
            ui.add(
                egui::DragValue::new(&mut state.incomplete_frame_threshold_pct)
                    .range(0.0..=100.0)
                    .prefix("incomplete frame % "),
            );
            text_field(ui, "camera catalog", &mut state.catalog_file);
            backend_selector(
                ui,
                "camera_backend",
                "camera backend",
                &mut state.camera_backend,
                false,
            );
        });
    }

    fn network_settings(&mut self, ui: &mut egui::Ui) {
        ui.collapsing("Network", |ui| {
            let state = self.controller.state_mut();
            text_field(ui, "bind IP", &mut state.bind_ip);
            text_field(ui, "local IP", &mut state.local_ip);
            text_field(ui, "remote IP", &mut state.remote_ip);
            ui.horizontal(|ui| {
                ui.add(
                    egui::DragValue::new(&mut state.control_port)
                        .range(1..=u16::MAX)
                        .prefix("control "),
                );
                ui.add(
                    egui::DragValue::new(&mut state.audio_port)
                        .range(1..=u16::MAX)
                        .prefix("audio "),
                );
                ui.add(
                    egui::DragValue::new(&mut state.video_port)
                        .range(1..=u16::MAX)
                        .prefix("video "),
                );
            });
            ui.add(
                egui::DragValue::new(&mut state.session_id)
                    .range(0..=i64::from(u32::MAX))
                    .prefix("SID "),
            );
            ui.add(
                egui::DragValue::new(&mut state.video_packet_size)
                    .range(128..=8192)
                    .prefix("packet bytes "),
            );
            ui.checkbox(&mut state.raw_media_plane, "Npcap media transport");
            text_field(ui, "Npcap adapter", &mut state.pcap_device);
            let mut vlan = state.vlan_tag.unwrap_or(0);
            if ui
                .add(
                    egui::DragValue::new(&mut vlan)
                        .range(0..=4094)
                        .prefix("VLAN (0 none) "),
                )
                .changed()
            {
                state.vlan_tag = (vlan != 0).then_some(vlan);
            }
            egui::ComboBox::from_id_salt("control_dialect")
                .selected_text(&state.control_dialect)
                .show_ui(ui, |ui| {
                    ui.selectable_value(&mut state.control_dialect, "ascii".into(), "ASCII");
                    ui.selectable_value(&mut state.control_dialect, "osc15".into(), "OSC 1.5");
                });
            ui.checkbox(&mut state.precheck_reachable, "precheck reachability");
            ui.add(
                egui::DragValue::new(&mut state.reachability_timeout_ms)
                    .range(1..=60_000)
                    .suffix(" ms"),
            );
            ui.horizontal(|ui| {
                ui.add(
                    egui::DragValue::new(&mut state.audio_receive_queue_depth)
                        .range(1..=4096)
                        .prefix("audio queue "),
                );
                ui.add(
                    egui::DragValue::new(&mut state.audio_receive_prefill)
                        .range(0..=4096)
                        .prefix("audio prefill "),
                );
            });
            ui.horizontal(|ui| {
                ui.add(
                    egui::DragValue::new(&mut state.video_receive_queue_depth)
                        .range(1..=4096)
                        .prefix("video queue "),
                );
                ui.add(
                    egui::DragValue::new(&mut state.video_receive_prefill)
                        .range(0..=4096)
                        .prefix("video prefill "),
                );
            });
        });
    }

    fn recording_settings(&mut self, ui: &mut egui::Ui) {
        ui.collapsing("Recording", |ui| {
            let state = self.controller.state_mut();
            ui.checkbox(&mut state.record_enabled, "record");
            text_field(ui, "recording path", &mut state.record_path);
            ui.horizontal(|ui| {
                ui.checkbox(&mut state.record_local_audio, "local audio");
                ui.checkbox(&mut state.record_remote_audio, "remote audio");
            });
            ui.horizontal(|ui| {
                ui.checkbox(&mut state.record_local_video, "local video");
                ui.checkbox(&mut state.record_remote_video, "remote video");
            });
            egui::ComboBox::from_id_salt("record_mode")
                .selected_text(&state.record_mode)
                .show_ui(ui, |ui| {
                    ui.selectable_value(&mut state.record_mode, "av".into(), "audio + video");
                    ui.selectable_value(&mut state.record_mode, "audio".into(), "audio only");
                    ui.selectable_value(&mut state.record_mode, "video".into(), "video only");
                });
            text_field(ui, "video format", &mut state.record_video_format);
        });
    }
}

fn text_field(ui: &mut egui::Ui, label: &str, value: &mut String) {
    ui.horizontal(|ui| {
        ui.label(label);
        ui.text_edit_singleline(value);
    });
}

fn backend_selector(ui: &mut egui::Ui, id: &str, label: &str, value: &mut String, audio: bool) {
    egui::ComboBox::from_id_salt(id)
        .selected_text(value.as_str())
        .show_ui(ui, |ui| {
            if audio {
                ui.selectable_value(
                    value,
                    "portaudio_asio".into(),
                    format!("{label}: PortAudio/ASIO"),
                );
            } else {
                ui.selectable_value(value, "ximea".into(), format!("{label}: Ximea"));
            }
            ui.selectable_value(value, "diagnostic".into(), format!("{label}: diagnostic"));
        });
}
