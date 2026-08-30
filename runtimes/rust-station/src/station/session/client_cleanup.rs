use super::backends::{SessionAudioBackend, SessionCameraBackend};
use super::capture::CaptureWorker;
use super::control::{build_session_control, send_control_datagram, ClientDisconnectGuard};
use super::lifecycle::{CleanupFinalizer, CleanupReport};
use super::media::SessionMediaTransport;
use crate::config::StationSettings;
use crate::net::Udp;
use crate::protocol::{MESG_DISCONNECT, MESG_STOP_AUDIO_SIGNAL};
use crate::station::dual_recorder::DualStreamRecorder;
use crate::station::SessionError;
use std::net::SocketAddr;

#[allow(clippy::too_many_arguments)]
pub(super) fn finalize_client_session(
    primary: Result<(), SessionError>,
    dual: &mut Option<DualStreamRecorder>,
    record_paths: &mut Vec<String>,
    capture_worker: &mut Option<CaptureWorker>,
    direct_camera: &mut Option<SessionCameraBackend>,
    audio: &mut Option<SessionAudioBackend>,
    media_transport: &mut Option<SessionMediaTransport>,
    client_ctrl: &Udp,
    disconnect_guard: &mut ClientDisconnectGuard<'_>,
    settings: &StationSettings,
    peer_addr: SocketAddr,
) -> (Result<(), SessionError>, CleanupReport) {
    let mut cleanup = CleanupReport::default();
    let mut stop_audio_signal_sent = false;
    let mut disconnect_sent = false;
    // Once checked finalization starts, Drop must not issue a second, hidden
    // terminal-control attempt if one of the explicit sends fails.
    disconnect_guard.disarm();
    let outcome = {
        let mut recorder = || {
            if let Some(recorder) = dual.take() {
                let finalized = recorder.close_checked();
                *record_paths = finalized.result.all_paths();
                if !finalized.warnings.is_empty() {
                    return Err(SessionError::Cleanup(finalized.warnings.join("; ")));
                }
            }
            Ok(())
        };
        let mut stop_audio_signal = || {
            send_terminal_control(&mut stop_audio_signal_sent, || {
                let message = build_session_control(
                    settings,
                    MESG_STOP_AUDIO_SIGNAL,
                    &settings.network.local_ip,
                    &settings.network.remote_ip,
                    "",
                    None,
                )
                .map_err(|error| SessionError::Cleanup(error.to_string()))?;
                send_control_datagram(client_ctrl, &message, peer_addr)
            })
        };
        let mut stop_capture = || match capture_worker.as_mut() {
            Some(worker) => worker.stop(),
            None => Ok(()),
        };
        let mut stop_camera = || match direct_camera.as_mut() {
            Some(camera) => camera.stop(),
            None => Ok(()),
        };
        let mut stop_audio = || audio.as_mut().map_or(Ok(()), SessionAudioBackend::stop);
        let mut shutdown_transport = || {
            media_transport
                .as_mut()
                .map_or(Ok(()), SessionMediaTransport::shutdown)
        };
        let mut disconnect = || {
            send_terminal_control(&mut disconnect_sent, || {
                let message = build_session_control(
                    settings,
                    MESG_DISCONNECT,
                    &settings.network.local_ip,
                    &settings.network.remote_ip,
                    "",
                    None,
                )
                .map_err(|error| SessionError::Cleanup(error.to_string()))?;
                send_control_datagram(client_ctrl, &message, peer_addr)
            })
        };
        let mut finalizers: [CleanupFinalizer<'_>; 7] = [
            ("recorder", &mut recorder),
            ("stop-audio-signal", &mut stop_audio_signal),
            ("capture-worker", &mut stop_capture),
            ("camera", &mut stop_camera),
            ("audio", &mut stop_audio),
            ("transport", &mut shutdown_transport),
            ("disconnect", &mut disconnect),
        ];
        cleanup.finalize(primary.err(), &mut finalizers)
    };
    cleanup.stop_audio_signal_sent = stop_audio_signal_sent;
    cleanup.disconnect_sent = disconnect_sent;
    (outcome, cleanup)
}

fn send_terminal_control(
    sent: &mut bool,
    send: impl FnOnce() -> Result<(), SessionError>,
) -> Result<(), SessionError> {
    let outcome = send();
    if outcome.is_ok() {
        *sent = true;
    }
    outcome
}
