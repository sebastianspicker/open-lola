use super::*;
use crate::config::VideoBackend;
use std::sync::mpsc;

#[test]
fn config_change_invalidates_ready_and_armed_without_runtime_state() {
    let mut controller = StationUIController::default();
    assert!(
        controller
            .execute_command(ControllerCommand::ValidateSetup)
            .accepted
    );
    assert!(controller.execute_command(ControllerCommand::Arm).accepted);
    controller.state_mut().sample_rate = 48_000;

    let snapshot = controller.signal_desk_snapshot();
    assert_eq!(snapshot.phase, SessionPhase::Setup);
    assert!(!snapshot.config_ready);
    assert!(!snapshot.armed);
    assert_eq!(
        snapshot.actions.start.disabled_reason.as_deref(),
        Some("Arm the validated setup")
    );
}

#[test]
fn runtime_status_is_not_part_of_configuration_fingerprint() {
    let mut controller = StationUIController::default();
    controller.execute_command(ControllerCommand::ValidateSetup);
    controller.execute_command(ControllerCommand::Arm);
    controller.state_mut().status = "some_process_activity".into();
    controller.state_mut().reachable = Some(true);
    controller.state_mut().rtt_ms = Some(2.5);

    let snapshot = controller.signal_desk_snapshot();
    assert!(snapshot.config_ready);
    assert!(snapshot.armed);
}

#[test]
fn start_requires_current_arm() {
    let mut controller = StationUIController::default();
    let result = controller.execute_command(ControllerCommand::Start {
        timeout: 1.0,
        frames: 1,
        extras: true,
        continuous: false,
    });
    assert!(!result.accepted);
    assert!(result.message.contains("Arm"));
}

#[test]
fn absent_runtime_values_remain_not_measured() {
    let health = audio_health(&serde_json::json!({"status": "idle"}));
    let evidence = evidence_snapshot(
        StationUIController::default().get_state(),
        &serde_json::json!({"status": "idle"}),
        false,
    );
    assert_eq!(health.transmit, Measurement::NotMeasured);
    assert_eq!(health.device_xruns, Measurement::NotMeasured);
    assert_eq!(evidence.negotiation, Measurement::NotMeasured);
    assert_eq!(evidence.report_validation, Measurement::NotMeasured);
}

#[test]
fn audio_device_xruns_are_shown_only_when_reported() {
    let health = audio_health(&serde_json::json!({"audio_device_xruns": 3}));
    assert_eq!(
        health.device_xruns,
        Measurement::Observed("3 device xruns".into())
    );
}

#[test]
fn device_inventory_transitions_from_loading_to_result_and_error() {
    let mut controller = StationUIController::default();
    let fingerprint = controller.configuration_fingerprint();
    let (sender, receiver) = mpsc::sync_channel(1);
    controller.begin_device_inventory(7, fingerprint, receiver);
    assert!(matches!(
        controller.signal_desk_snapshot().devices.audio,
        InventoryState::Loading
    ));

    sender
        .send(inventory_result(
            7,
            fingerprint,
            InventoryState::Available(vec![device_choice("input")]),
            InventoryState::Error("camera unavailable".into()),
        ))
        .unwrap();
    let devices = controller.signal_desk_snapshot().devices;
    assert!(matches!(devices.audio, InventoryState::Available(_)));
    assert_eq!(
        devices.video,
        InventoryState::Error("camera unavailable".into())
    );

    let (sender, receiver) = mpsc::sync_channel(1);
    controller.begin_device_inventory(8, fingerprint, receiver);
    sender
        .send(inventory_result(
            8,
            fingerprint,
            InventoryState::Error("audio unavailable".into()),
            InventoryState::Error("camera unavailable".into()),
        ))
        .unwrap();
    let devices = controller.signal_desk_snapshot().devices;
    assert_eq!(
        devices.audio,
        InventoryState::Error("audio unavailable".into())
    );
    assert_eq!(
        devices.video,
        InventoryState::Error("camera unavailable".into())
    );
}

#[test]
fn reconfigured_device_inventory_result_is_discarded() {
    let mut controller = StationUIController::default();
    let fingerprint = controller.configuration_fingerprint();
    let (sender, receiver) = mpsc::sync_channel(1);
    controller.begin_device_inventory(7, fingerprint, receiver);
    controller.state_mut().audio_backend = "diagnostic".into();
    sender
        .send(inventory_result(
            7,
            fingerprint,
            InventoryState::Available(vec![device_choice("stale")]),
            InventoryState::Available(Vec::new()),
        ))
        .unwrap();

    let devices = controller.signal_desk_snapshot().devices;
    assert_eq!(devices.audio, InventoryState::NotMeasured);
    assert_eq!(devices.video, InventoryState::NotMeasured);
}

#[test]
fn duplicate_device_inventory_refresh_is_rejected_while_pending() {
    let mut controller = StationUIController::default();
    let fingerprint = controller.configuration_fingerprint();
    let (_sender, receiver) = mpsc::sync_channel(1);
    controller.begin_device_inventory(7, fingerprint, receiver);

    let outcome = controller.execute_command(ControllerCommand::RefreshDevices);
    assert!(!outcome.accepted);
    assert_eq!(
        outcome.message,
        "Device inventory refresh is already in progress"
    );
    assert!(controller.device_inventory_pending());
}

#[test]
fn native_linux_video_selection_round_trips_through_ui_state() {
    let mut settings = crate::config::default_settings();
    settings.video.backend = VideoBackend::V4l2;
    settings.video.device = "/dev/video7".into();
    settings.video.pixel_format = "YUYV".into();
    let mut controller = StationUIController::new(Some(settings));

    assert_eq!(controller.get_state().camera_backend, "v4l2");
    assert_eq!(controller.get_state().video_device, "/dev/video7");
    assert_eq!(controller.get_state().video_pixel_format, "YUYV");
    let applied = controller.set_settings_from_state();
    assert_eq!(applied.video.backend, VideoBackend::V4l2);
    assert_eq!(applied.video.device, "/dev/video7");
    assert_eq!(applied.video.pixel_format, "YUYV");
}

fn inventory_result(
    generation: u64,
    fingerprint: u64,
    audio: InventoryState,
    video: InventoryState,
) -> inventory::InventoryResult {
    inventory::InventoryResult {
        generation,
        fingerprint,
        audio,
        video,
    }
}

fn device_choice(id: &str) -> DeviceChoice {
    DeviceChoice {
        id: id.into(),
        label: id.into(),
        supports_input: true,
        supports_output: true,
        formats: Vec::new(),
    }
}
