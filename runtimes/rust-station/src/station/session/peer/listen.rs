use super::super::backends::SessionAudioBackend;
use super::super::capture::CaptureWorker;
use super::super::control::{build_session_control, send_control_datagram};
use super::super::lifecycle::record_transport_monitor;
use super::super::media::{ReceivePrefillQueue, SessionMediaTransport};
use super::super::stream::run_interleaved_stream;
use super::super::types::now_us;
use super::super::video::ReceivedVideoFrame;
use super::super::{SessionOptions, SessionResult};
use crate::config::StationSettings;
use crate::net::Udp;
use crate::protocol::{FrameReassembler, MESG_DISCONNECT, MESG_STOP_AUDIO_SIGNAL};
use crate::station::monitor::NetworkMonitor;
use crate::station::recording_worker::SessionRecorder as DualStreamRecorder;
use crate::station::sync::lock_unpoison;
use crate::station::SessionError;
use crate::video::BayerPattern;
use std::net::SocketAddr;
use std::sync::{Arc, Mutex};
use std::time::Instant;

/// Sends the responder's terminal controls once the control endpoint has been
/// negotiated.  It deliberately keeps send failures as warnings: cancellation
/// or a finite-stream failure remains the primary outcome.
#[derive(Default)]
struct ListenerControlCleanup {
    finalized: bool,
}

impl ListenerControlCleanup {
    fn finalize(
        &mut self,
        settings: &StationSettings,
        control_socket: &Udp,
        control_peer: SocketAddr,
        shared: &Arc<Mutex<SessionResult>>,
    ) {
        if self.finalized {
            return;
        }
        self.finalized = true;
        for (kind, message_name) in [
            (MESG_STOP_AUDIO_SIGNAL, "/MESG_STOP_AUDIO_SIGNAL"),
            (MESG_DISCONNECT, "/MESG_DISCONNECT"),
        ] {
            let send = build_session_control(
                settings,
                kind,
                &settings.network.local_ip,
                &settings.network.remote_ip,
                "",
                None,
            )
            .map_err(|error| error.to_string())
            .and_then(|message| {
                send_control_datagram(control_socket, &message, control_peer)
                    .map_err(|error| error.to_string())
            });
            let mut result = lock_unpoison(shared);
            match send {
                Ok(()) => result.messages_sent.push(message_name.into()),
                Err(error) => result
                    .cleanup_warnings
                    .push(format!("listener {message_name}: {error}")),
            }
        }
    }
}

#[allow(clippy::too_many_arguments)]
pub(super) fn run_listen_media(
    settings: &StationSettings,
    options: &SessionOptions,
    shared: &Arc<Mutex<SessionResult>>,
    control_socket: &Udp,
    control_peer: SocketAddr,
    peer_audio_port: u16,
    peer_video_port: u16,
    packet_size: usize,
    n_frames: u32,
    negotiated: &crate::protocol::MediaSettings,
    transport: &mut SessionMediaTransport,
) -> Result<(), SessionError> {
    let video_compressed = negotiated.compression == 1;
    let remote_video_bpp = negotiated.bits_per_pixel;
    let do_audio = options.stream_tx_audio || options.stream_rx_audio;
    let peer_audio = SocketAddr::new(control_peer.ip(), peer_audio_port);
    let peer_video = SocketAddr::new(control_peer.ip(), peer_video_port);
    let mut control_cleanup = ListenerControlCleanup::default();
    let mut audio = match do_audio
        .then(|| SessionAudioBackend::open(settings, options))
        .transpose()
    {
        Ok(audio) => audio,
        Err(error) => {
            control_cleanup.finalize(settings, control_socket, control_peer, shared);
            return Err(error);
        }
    };
    let started = Instant::now();
    let bayer_pattern = BayerPattern::parse(&options.bayer_pattern).unwrap_or(BayerPattern::Bggr);
    let (stream_w, stream_h) = (negotiated.width, negotiated.height);
    let mut capture = if options.stream_tx_video && !options.audio_only {
        let mode = super::super::backends::SessionCameraBackend::synthetic_mode(
            settings,
            settings.video.camera_mode_id.clone(),
        );
        match CaptureWorker::start(
            settings,
            options,
            mode,
            packet_size,
            stream_w,
            stream_h,
            options.color_settings.clone(),
            bayer_pattern,
            video_compressed,
            settings.network.session_id as u32,
            now_us(),
        ) {
            Ok(worker) => Some(worker),
            Err(error) => {
                control_cleanup.finalize(settings, control_socket, control_peer, shared);
                if let Some(audio) = audio.as_mut() {
                    let _ = audio.stop();
                }
                return Err(error);
            }
        }
    } else {
        None
    };
    record_backend_selection(
        shared,
        &audio,
        &capture,
        transport,
        video_compressed,
        n_frames,
    );
    let mut recorder = open_recorder(settings, options);
    let mut monitor = NetworkMonitor::new();
    let mut v_re = FrameReassembler::strict_video();
    let mut a_re =
        FrameReassembler::with_limit(settings.network.audio_receive_queue_depth.max(1) as usize);
    let mut audio_queue = ReceivePrefillQueue::new(
        settings.network.audio_receive_queue_depth,
        settings.network.audio_receive_prefill,
    );
    let mut video_queue: ReceivePrefillQueue<ReceivedVideoFrame> = ReceivePrefillQueue::new(
        settings.network.video_receive_queue_depth,
        settings.network.video_receive_prefill,
    );
    let mut previews = Vec::new();
    let primary = {
        let mut result = lock_unpoison(shared);
        run_interleaved_stream(
            capture.as_mut(),
            audio.as_mut(),
            transport,
            settings,
            options,
            &mut result,
            n_frames,
            started,
            peer_audio,
            peer_video,
            control_socket,
            control_peer,
            packet_size,
            video_compressed,
            remote_video_bpp,
            stream_w,
            stream_h,
            settings.network.session_id as u32,
            now_us(),
            &mut recorder,
            &mut previews,
            &mut monitor,
            &mut a_re,
            &mut audio_queue,
            &mut v_re,
            &mut video_queue,
        )
    };
    // The responder uses the observed control source, not configured remote
    // address/port. These datagrams must leave while all sockets are live.
    control_cleanup.finalize(settings, control_socket, control_peer, shared);
    let cleanup_errors = finalize_listen_resources(
        shared,
        transport,
        &mut monitor,
        &mut recorder,
        audio,
        capture,
        previews,
    );
    match primary {
        Err(error) => Err(error),
        Ok(()) if cleanup_errors.is_empty() => Ok(()),
        Ok(()) => Err(SessionError::Cleanup(cleanup_errors.join("; "))),
    }
}

fn record_backend_selection(
    shared: &Arc<Mutex<SessionResult>>,
    audio: &Option<SessionAudioBackend>,
    capture: &Option<CaptureWorker>,
    transport: &SessionMediaTransport,
    video_compressed: bool,
    n_frames: u32,
) {
    let mut result = lock_unpoison(shared);
    result.audio_backend = audio.as_ref().map_or("", SessionAudioBackend::name).into();
    result.camera_backend = capture.as_ref().map_or("", CaptureWorker::name).into();
    result.media_transport = if matches!(transport, SessionMediaTransport::Npcap(_)) {
        "npcap"
    } else {
        "udp"
    }
    .into();
    result.compression_used = video_compressed;
    result.stream_frames = n_frames;
}

fn open_recorder(
    settings: &StationSettings,
    options: &SessionOptions,
) -> Option<DualStreamRecorder> {
    let record_dir = options.record.then(|| options.record_dir.clone()).flatten();
    let preview_dir = options.preview_dir.clone();
    if record_dir.is_none() && preview_dir.is_none() {
        return None;
    }
    let mode = if options.record {
        settings.recording.mode.as_str()
    } else {
        "none"
    };
    Some(DualStreamRecorder::with_options(
        record_dir,
        preview_dir,
        settings.audio.sample_rate,
        settings.audio.channels,
        settings.audio.bits_per_sample,
        "session",
        mode,
        options.record && settings.recording.record_local_audio,
        options.record && settings.recording.record_remote_audio,
        options.record && settings.recording.record_local_video,
        options.record && settings.recording.record_remote_video,
        &settings.recording.video_format,
    ))
}

#[allow(clippy::too_many_arguments)]
fn finalize_listen_resources(
    shared: &Arc<Mutex<SessionResult>>,
    transport: &mut SessionMediaTransport,
    monitor: &mut NetworkMonitor,
    recorder: &mut Option<DualStreamRecorder>,
    audio: Option<SessionAudioBackend>,
    capture: Option<CaptureWorker>,
    previews: Vec<String>,
) -> Vec<String> {
    let mut errors = Vec::new();
    let mut result = lock_unpoison(shared);
    result.preview_paths = previews;
    if let Err(error) = record_transport_monitor(&mut result, monitor, transport) {
        errors.push(format!("transport statistics: {error}"));
    }
    drop(result);
    if let Some(mut audio) = audio {
        if let Err(error) = audio.stop() {
            errors.push(format!("audio backend: {error}"));
        }
    }
    if let Some(mut capture) = capture {
        if let Err(error) = capture.stop() {
            errors.push(format!("capture worker: {error}"));
        }
    }
    if let Some(recorder) = recorder.take() {
        let finalized = recorder.close_checked();
        let mut result = lock_unpoison(shared);
        result.record_paths = finalized.result.all_paths();
        result.preview_paths = finalized
            .preview_paths
            .iter()
            .map(|path| path.display().to_string())
            .collect();
        result.cleanup_warnings.extend(finalized.warnings);
    }
    if !errors.is_empty() {
        lock_unpoison(shared)
            .cleanup_warnings
            .extend(errors.clone());
    }
    errors
}
