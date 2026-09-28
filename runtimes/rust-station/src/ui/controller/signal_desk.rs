//! Typed workflow, command, device, and evidence views for Signal Desk.

use super::StationUIController;
use serde_json::Value;

mod inventory;
pub(super) use inventory::InventoryResult;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DeskSection {
    Session,
    Setup,
    Monitor,
    Evidence,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SessionPhase {
    Setup,
    Ready,
    Live,
    Review,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Measurement {
    NotMeasured,
    Pending,
    Passed(String),
    Failed(String),
    Observed(String),
}

impl Measurement {
    pub fn label(&self) -> String {
        match self {
            Self::NotMeasured => "Not measured".into(),
            Self::Pending => "Pending".into(),
            Self::Passed(detail) => format!("Pass · {detail}"),
            Self::Failed(detail) => format!("Fail · {detail}"),
            Self::Observed(detail) => detail.clone(),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ActionState {
    pub enabled: bool,
    pub disabled_reason: Option<String>,
}

impl ActionState {
    fn enabled() -> Self {
        Self {
            enabled: true,
            disabled_reason: None,
        }
    }

    fn disabled(reason: impl Into<String>) -> Self {
        Self {
            enabled: false,
            disabled_reason: Some(reason.into()),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DeskActions {
    pub ready: ActionState,
    pub arm: ActionState,
    pub start: ActionState,
    pub stop: ActionState,
    pub next_action: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AudioHealthSnapshot {
    pub backend: Measurement,
    pub transmit: Measurement,
    pub receive: Measurement,
    pub device_xruns: Measurement,
    pub deadline: Measurement,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EvidenceSnapshot {
    pub control_reachability: Measurement,
    pub negotiation: Measurement,
    pub transmit: Measurement,
    pub receive: Measurement,
    pub report_validation: Measurement,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DeviceChoice {
    pub id: String,
    pub label: String,
    pub supports_input: bool,
    pub supports_output: bool,
    pub formats: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum InventoryState {
    NotMeasured,
    Loading,
    Available(Vec<DeviceChoice>),
    Error(String),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DeviceSnapshot {
    pub audio: InventoryState,
    pub video: InventoryState,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SignalDeskSnapshot {
    pub phase: SessionPhase,
    pub config_ready: bool,
    pub armed: bool,
    pub readiness_detail: String,
    pub actions: DeskActions,
    pub audio: AudioHealthSnapshot,
    pub evidence: EvidenceSnapshot,
    pub devices: DeviceSnapshot,
}

#[derive(Debug, Clone, PartialEq)]
pub enum ControllerCommand {
    ValidateSetup,
    Arm,
    Start {
        timeout: f64,
        frames: u32,
        extras: bool,
        continuous: bool,
    },
    Stop,
    CheckControl {
        timeout: f64,
    },
    RefreshDevices,
}

#[derive(Debug, Clone, PartialEq)]
pub struct CommandOutcome {
    pub accepted: bool,
    pub message: String,
    pub report: Option<Value>,
}

impl StationUIController {
    pub fn signal_desk_snapshot(&mut self) -> SignalDeskSnapshot {
        self.reconcile_signal_desk();
        let report = self.live.get_report();
        SignalDeskSnapshot {
            phase: self.signal_phase,
            config_ready: self.ready_fingerprint.is_some(),
            armed: self.armed_fingerprint.is_some(),
            readiness_detail: self.readiness_detail.clone(),
            actions: self.desk_actions(),
            audio: audio_health(&report),
            evidence: evidence_snapshot(&self.state, &report, self.check_in_progress),
            devices: self.device_snapshot.clone(),
        }
    }

    pub fn execute_command(&mut self, command: ControllerCommand) -> CommandOutcome {
        self.reconcile_signal_desk();
        match command {
            ControllerCommand::ValidateSetup => self.validate_setup(),
            ControllerCommand::Arm => self.arm(),
            ControllerCommand::Start {
                timeout,
                frames,
                extras,
                continuous,
            } => self.start_armed(timeout, frames, extras, continuous),
            ControllerCommand::Stop => {
                if !self.live.is_running() && !self.state.settings_locked {
                    return rejected("No live session to stop");
                }
                let report = self.request_stop_live();
                accepted("Stop requested", Some(report))
            }
            ControllerCommand::CheckControl { timeout } => {
                if self.live.is_running() || self.check_in_progress {
                    return rejected(
                        "Control check is unavailable while another operation is active",
                    );
                }
                let report = self.start_check(timeout);
                accepted("Control-plane check started", Some(report))
            }
            ControllerCommand::RefreshDevices => self.refresh_devices(),
        }
    }

    fn validate_setup(&mut self) -> CommandOutcome {
        if self.settings_are_locked() {
            return rejected("Setup is locked while a session or check is active");
        }
        self.set_settings_from_state();
        match self.settings.validate() {
            Ok(()) => {
                let fingerprint = self.configuration_fingerprint();
                self.ready_fingerprint = Some(fingerprint);
                self.armed_fingerprint = None;
                self.signal_phase = SessionPhase::Ready;
                self.readiness_detail = "Configuration validated for this setup".into();
                accepted(&self.readiness_detail, None)
            }
            Err(error) => {
                self.ready_fingerprint = None;
                self.armed_fingerprint = None;
                self.signal_phase = SessionPhase::Setup;
                self.readiness_detail = error.to_string();
                rejected(&self.readiness_detail)
            }
        }
    }

    fn arm(&mut self) -> CommandOutcome {
        let fingerprint = self.configuration_fingerprint();
        if self.ready_fingerprint != Some(fingerprint) {
            return rejected("Run Ready after the latest setup change");
        }
        if self.settings_are_locked() {
            return rejected("Arming is unavailable while a session or check is active");
        }
        self.armed_fingerprint = Some(fingerprint);
        accepted("Session armed", None)
    }

    fn start_armed(
        &mut self,
        timeout: f64,
        frames: u32,
        extras: bool,
        continuous: bool,
    ) -> CommandOutcome {
        let fingerprint = self.configuration_fingerprint();
        if self.armed_fingerprint != Some(fingerprint) {
            return rejected("Arm the validated setup before starting");
        }
        let report = match self.state.peer_mode.as_str() {
            "listen" => self.start_listen(timeout, extras),
            _ => self.start_connect(timeout, frames, extras, continuous),
        };
        let ok = report.get("ok").and_then(Value::as_bool).unwrap_or(true)
            && !self.state.status.starts_with("configuration_error");
        if ok {
            self.signal_phase = SessionPhase::Live;
            accepted("Session start requested", Some(report))
        } else {
            self.signal_phase = SessionPhase::Review;
            rejected_with_report("Session could not start", report)
        }
    }

    fn refresh_devices(&mut self) -> CommandOutcome {
        if self.device_inventory_rx.is_some() {
            return rejected("Device inventory refresh is already in progress");
        }
        self.set_settings_from_state();
        let fingerprint = self.configuration_fingerprint();
        let generation = self.device_inventory_generation.wrapping_add(1);
        let (sender, receiver) = std::sync::mpsc::sync_channel(1);
        let audio_backend = self.settings.audio.backend;
        let video_backend = self.settings.video.backend;
        let task = std::thread::Builder::new()
            .name("rusty-lola-device-inventory".into())
            .spawn(move || {
                let _ = sender.send(inventory::collect(
                    generation,
                    fingerprint,
                    audio_backend,
                    video_backend,
                ));
            });
        match task {
            Ok(_worker) => {
                self.begin_device_inventory(generation, fingerprint, receiver);
                accepted("Device inventory refresh started", None)
            }
            Err(error) => {
                let message = format!("Could not start device inventory: {error}");
                self.device_snapshot = DeviceSnapshot {
                    audio: InventoryState::Error(message.clone()),
                    video: InventoryState::Error(message.clone()),
                };
                rejected(message)
            }
        }
    }

    fn reconcile_signal_desk(&mut self) {
        let fingerprint = self.configuration_fingerprint();
        self.poll_device_inventory_for(fingerprint);
        if self
            .ready_fingerprint
            .is_some_and(|ready| ready != fingerprint)
        {
            self.ready_fingerprint = None;
            self.armed_fingerprint = None;
            self.readiness_detail = "Setup changed; run Ready again".into();
            if !self.live.is_running() {
                self.signal_phase = SessionPhase::Setup;
            }
        }
        if self.live.is_running() {
            self.signal_phase = SessionPhase::Live;
        } else if self.signal_phase == SessionPhase::Live && !self.state.settings_locked {
            self.signal_phase = SessionPhase::Review;
            self.armed_fingerprint = None;
        }
    }

    fn configuration_fingerprint(&self) -> u64 {
        let bytes = serde_json::to_vec(&self.state.configuration_json()).unwrap_or_default();
        bytes.into_iter().fold(0xcbf29ce484222325, |hash, byte| {
            (hash ^ u64::from(byte)).wrapping_mul(0x100000001b3)
        })
    }

    fn begin_device_inventory(
        &mut self,
        generation: u64,
        fingerprint: u64,
        receiver: std::sync::mpsc::Receiver<inventory::InventoryResult>,
    ) {
        self.device_inventory_generation = generation;
        self.device_inventory_fingerprint = Some(fingerprint);
        self.device_inventory_rx = Some(receiver);
        self.device_snapshot = DeviceSnapshot {
            audio: InventoryState::Loading,
            video: InventoryState::Loading,
        };
    }

    pub fn poll_device_inventory(&mut self) {
        self.poll_device_inventory_for(self.configuration_fingerprint());
    }

    fn poll_device_inventory_for(&mut self, current_fingerprint: u64) {
        let result = match self
            .device_inventory_rx
            .as_ref()
            .map(|receiver| receiver.try_recv())
        {
            Some(Ok(result)) => result,
            Some(Err(std::sync::mpsc::TryRecvError::Empty)) | None => return,
            Some(Err(std::sync::mpsc::TryRecvError::Disconnected)) => {
                self.device_inventory_rx = None;
                self.device_inventory_fingerprint = None;
                let error = InventoryState::Error("Device inventory worker disconnected".into());
                self.device_snapshot = DeviceSnapshot {
                    audio: error.clone(),
                    video: error,
                };
                return;
            }
        };
        let current_request = self.device_inventory_fingerprint;
        self.device_inventory_rx = None;
        self.device_inventory_fingerprint = None;
        if result.generation == self.device_inventory_generation
            && current_request == Some(result.fingerprint)
            && result.fingerprint == current_fingerprint
        {
            self.device_snapshot = DeviceSnapshot {
                audio: result.audio,
                video: result.video,
            };
        } else {
            self.device_snapshot = DeviceSnapshot {
                audio: InventoryState::NotMeasured,
                video: InventoryState::NotMeasured,
            };
        }
    }

    pub fn device_inventory_pending(&self) -> bool {
        self.device_inventory_rx.is_some()
    }

    fn desk_actions(&self) -> DeskActions {
        let busy = self.settings_are_locked();
        let current = self.configuration_fingerprint();
        let ready = self.ready_fingerprint == Some(current);
        let armed = self.armed_fingerprint == Some(current);
        let ready_action = if busy {
            ActionState::disabled("A session or control check is active")
        } else {
            ActionState::enabled()
        };
        let arm = if busy {
            ActionState::disabled("A session or control check is active")
        } else if !ready {
            ActionState::disabled("Run Ready for the current setup")
        } else {
            ActionState::enabled()
        };
        let start = if self.live.is_running() {
            ActionState::disabled("The session is already live")
        } else if self.check_in_progress {
            ActionState::disabled("Wait for the control check to finish")
        } else if !armed {
            ActionState::disabled("Arm the validated setup")
        } else {
            ActionState::enabled()
        };
        let stop = if self.live.is_running() || self.state.settings_locked {
            ActionState::enabled()
        } else {
            ActionState::disabled("No live session is running")
        };
        let next_action = if self.live.is_running() {
            "Monitor audio health; Stop when the session is complete"
        } else if !ready {
            "Review setup, then run Ready"
        } else if !armed {
            "Arm the validated setup"
        } else {
            "Start the armed session"
        };
        DeskActions {
            ready: ready_action,
            arm,
            start,
            stop,
            next_action: next_action.into(),
        }
    }
}

fn audio_health(report: &Value) -> AudioHealthSnapshot {
    let backend = match report.get("active_audio_backend") {
        Some(Value::String(value)) if !value.is_empty() => Measurement::Passed(value.clone()),
        _ => Measurement::NotMeasured,
    };
    let deadline = value_u64(report, "audio_deadline_misses")
        .filter(|_| {
            ["audio_frames_sent", "audio_frames_received"]
                .iter()
                .any(|key| value_u64(report, key).is_some_and(|count| count > 0))
        })
        .map(|count| {
            if count == 0 {
                Measurement::Passed("0 deadline misses".into())
            } else {
                Measurement::Failed(format!("{count} deadline misses"))
            }
        })
        .unwrap_or(Measurement::NotMeasured);
    AudioHealthSnapshot {
        backend,
        transmit: count_measurement(report, "audio_frames_sent", "audio frames sent"),
        receive: count_measurement(report, "audio_frames_received", "audio frames received"),
        device_xruns: count_measurement(report, "audio_device_xruns", "device xruns"),
        deadline,
    }
}

fn evidence_snapshot(
    state: &crate::ui::state::StationUIState,
    report: &Value,
    check_pending: bool,
) -> EvidenceSnapshot {
    let control_reachability = if check_pending {
        Measurement::Pending
    } else {
        match state.reachable {
            Some(true) => Measurement::Passed(
                state
                    .rtt_ms
                    .map_or_else(|| "reachable".into(), |ms| format!("{ms:.1} ms")),
            ),
            Some(false) => Measurement::Failed("unreachable".into()),
            None => Measurement::NotMeasured,
        }
    };
    let negotiation = report
        .get("negotiated_media")
        .filter(|value| !value.is_null())
        .map(|value| Measurement::Observed(compact(value)))
        .unwrap_or(Measurement::NotMeasured);
    let report_validation = report
        .get("report_validation")
        .or_else(|| report.get("report_valid"))
        .map(|value| match value.as_bool() {
            Some(true) => Measurement::Passed("validated".into()),
            Some(false) => Measurement::Failed("validation failed".into()),
            None => Measurement::Observed(compact(value)),
        })
        .unwrap_or(Measurement::NotMeasured);
    EvidenceSnapshot {
        control_reachability,
        negotiation,
        transmit: pair_measurement(report, "video_frames_sent", "audio_frames_sent", "frames"),
        receive: pair_measurement(
            report,
            "video_frames_received",
            "audio_frames_received",
            "frames",
        ),
        report_validation,
    }
}

fn count_measurement(report: &Value, key: &str, label: &str) -> Measurement {
    value_u64(report, key)
        .map(|count| Measurement::Observed(format!("{count} {label}")))
        .unwrap_or(Measurement::NotMeasured)
}

fn pair_measurement(report: &Value, video: &str, audio: &str, unit: &str) -> Measurement {
    match (value_u64(report, video), value_u64(report, audio)) {
        (None, None) => Measurement::NotMeasured,
        (video, audio) => Measurement::Observed(format!(
            "video {} · audio {} {unit}",
            video.map_or_else(|| "Not measured".into(), |value| value.to_string()),
            audio.map_or_else(|| "Not measured".into(), |value| value.to_string())
        )),
    }
}

fn value_u64(report: &Value, key: &str) -> Option<u64> {
    report
        .get(key)
        .or_else(|| report.get("counters").and_then(|value| value.get(key)))
        .and_then(Value::as_u64)
}

fn compact(value: &Value) -> String {
    serde_json::to_string(value).unwrap_or_else(|_| "unavailable".into())
}

fn accepted(message: impl Into<String>, report: Option<Value>) -> CommandOutcome {
    CommandOutcome {
        accepted: true,
        message: message.into(),
        report,
    }
}

fn rejected(message: impl Into<String>) -> CommandOutcome {
    CommandOutcome {
        accepted: false,
        message: message.into(),
        report: None,
    }
}

fn rejected_with_report(message: impl Into<String>, report: Value) -> CommandOutcome {
    CommandOutcome {
        accepted: false,
        message: message.into(),
        report: Some(report),
    }
}

#[cfg(test)]
mod tests;
