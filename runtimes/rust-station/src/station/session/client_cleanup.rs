use super::backends::{SessionAudioBackend, SessionCameraBackend};
use super::capture::CaptureWorker;
use super::control::{build_session_control, send_control_datagram};
use super::lifecycle::{CleanupFinalizer, CleanupReport};
use super::media::SessionMediaTransport;
use crate::config::StationSettings;
use crate::net::Udp;
use crate::protocol::{MESG_DISCONNECT, MESG_STOP_AUDIO_SIGNAL};
use crate::station::recording_worker::SessionRecorder as DualStreamRecorder;
use crate::station::SessionError;
use std::net::SocketAddr;

/// Best-effort protocol cleanup for every successfully negotiated client session.
///
/// The normal path still reports checked sends. If a media/backend/recording
/// operation returns early, this guard keeps the peer from waiting indefinitely.
pub(super) struct ClientDisconnectGuard<'a> {
    socket: &'a Udp,
    peer: SocketAddr,
    stop_audio: Vec<u8>,
    disconnect: Vec<u8>,
    armed: bool,
}

impl<'a> ClientDisconnectGuard<'a> {
    pub(super) fn new(
        socket: &'a Udp,
        peer: SocketAddr,
        settings: &StationSettings,
    ) -> Result<Self, SessionError> {
        let encode = |kind| {
            build_session_control(
                settings,
                kind,
                &settings.network.local_ip,
                &settings.network.remote_ip,
                "",
                None,
            )
            .map_err(|error| SessionError::ControlHandshake(error.to_string()))
        };
        Ok(Self {
            socket,
            peer,
            stop_audio: encode(MESG_STOP_AUDIO_SIGNAL)?,
            disconnect: encode(MESG_DISCONNECT)?,
            armed: true,
        })
    }

    pub(super) fn disarm(&mut self) {
        self.armed = false;
    }
}

impl Drop for ClientDisconnectGuard<'_> {
    fn drop(&mut self) {
        if self.armed {
            let _ = send_control_datagram(self.socket, &self.stop_audio, self.peer);
            let _ = send_control_datagram(self.socket, &self.disconnect, self.peer);
        }
    }
}

#[allow(clippy::too_many_arguments)]
pub(super) fn finalize_client_session(
    primary: Result<(), SessionError>,
    dual: &mut Option<DualStreamRecorder>,
    record_paths: &mut Vec<String>,
    preview_paths: &mut Vec<String>,
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
                *preview_paths = finalized
                    .preview_paths
                    .iter()
                    .map(|path| path.display().to_string())
                    .collect();
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
            ("stop-audio-signal", &mut stop_audio_signal),
            // Disconnect and recorder come before the bounded capture join: the capture
            // worker never feeds the recorder, and a slow join must not eat their time.
            ("disconnect", &mut disconnect),
            ("recorder", &mut recorder),
            ("capture-worker", &mut stop_capture),
            ("camera", &mut stop_camera),
            ("audio", &mut stop_audio),
            ("transport", &mut shutdown_transport),
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
