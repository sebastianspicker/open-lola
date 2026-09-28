use super::audio::send_recv_audio_frame;
use super::backends::{SessionAudioBackend, SessionCameraBackend};
use super::capture::CaptureWorker;
use super::client_cleanup::finalize_client_session;
use super::client_media::prepare_client_media;
use super::control::{
    build_session_control, pump_control, resolve_peer_ipv4, send_control_datagram,
    send_queued_controls, ClientDisconnectGuard,
};
use super::lifecycle::{record_cached_transport_stats, record_transport_monitor};
use super::media::{should_stream_more, ReceivePrefillQueue, SessionMediaTransport};
use super::stream::run_interleaved_stream;
use super::types::{now_us, session_cancelled, stream_dims};
use super::video::{send_recv_video_frame, ReceivedVideoFrame};
use super::{SessionOptions, SessionPhase, SessionResult};
use crate::config::{load_ximea_colors, ColorSettings, MediaTransportKind, StationSettings};
use crate::net::Udp;
use crate::protocol::{FrameReassembler, MESG_CHAT, MESG_SEND_AUDIO_SIGNAL, MESG_SWITCH_ON_BB};
use crate::shipped_ximea_colors;
use crate::station::monitor::NetworkMonitor;
use crate::station::recording_worker::SessionRecorder as DualStreamRecorder;
use crate::station::SessionError;
use crate::video::BayerPattern;
use std::net::SocketAddr;
use std::thread;
use std::time::{Duration, Instant};

mod negotiation;

#[allow(clippy::too_many_arguments)]
pub(super) fn client_session(
    settings: &StationSettings,
    options: &SessionOptions,
    result: &mut SessionResult,
    timeout: f64,
    peer_control: u16,
    peer_audio: u16,
    peer_video: u16,
    peer_host: &str,
) -> Result<(), SessionError> {
    let mut monitor = NetworkMonitor::new();
    monitor.local_fps_settings = settings.video.fps as f64;
    let bind = &settings.network.bind_ip;
    let fixed_media_ports = !options.peer_mode.eq_ignore_ascii_case("loopback");
    let control_bind_port = settings.network.control_port * u16::from(fixed_media_ports);
    let client_ctrl =
        Udp::bind(bind, control_bind_port).map_err(|e| SessionError::Transport(e.to_string()))?;
    client_ctrl.set_timeout(0.01).ok();
    let deadline_scheduled = options.interleaved_av
        || options.persistent
        || !options.peer_mode.eq_ignore_ascii_case("loopback");
    let audio_period = f64::from(settings.audio.buffer_samples.max(1))
        / f64::from(settings.audio.sample_rate.max(1));
    // A scheduler receive step must be bounded well below an audio callback.
    // Npcap's vendor capture timeout remains outside UDP socket control.
    let media_timeout = if deadline_scheduled {
        (audio_period / 2.0).clamp(0.000_1, 0.001)
    } else {
        timeout
    };
    let peer_addr = resolve_peer_ipv4(peer_host, peer_control)?;
    let peer_video_addr = SocketAddr::new(peer_addr.ip(), peer_video);
    let peer_audio_addr = SocketAddr::new(peer_addr.ip(), peer_audio);
    let requested_npcap = options
        .media_transport
        .unwrap_or(settings.network.media_transport)
        == MediaTransportKind::Npcap;
    if session_cancelled(options) {
        return Err(SessionError::PeerDisconnect(
            "session cancelled before negotiation".into(),
        ));
    }
    if let Some(control) = options.runtime_control.as_ref() {
        control.set_activity(result);
    }
    // Color settings for stream path
    let colors: Option<ColorSettings> = if options.apply_color {
        options.color_settings.clone().or_else(|| {
            if shipped_ximea_colors().is_file() {
                load_ximea_colors(shipped_ximea_colors()).ok()
            } else {
                None
            }
        })
    } else {
        None
    };
    let negotiation::ClientNegotiation::Accepted {
        remote_video_bpp,
        capabilities,
    } = negotiation::negotiate_client(
        settings,
        options,
        result,
        &client_ctrl,
        peer_addr,
        timeout,
        &mut monitor,
    )?
    else {
        return Ok(());
    };
    let mut disconnect_guard = ClientDisconnectGuard::new(&client_ctrl, peer_addr, settings)?;
    // The peer has accepted QUICKCONN. Acquire the media plane now, keeping
    // the ACK-to-first-media interval limited to socket/adapter setup and the
    // audio start. Before this point the client owns control only.
    let mut prepared = match prepare_client_media(
        settings,
        options,
        peer_addr,
        fixed_media_ports,
        media_timeout,
        requested_npcap,
    ) {
        Ok(prepared) => prepared,
        Err(preparation) => {
            let (error, mut prepared) = *preparation;
            let mut dual = None;
            let mut record_paths = Vec::new();
            let mut preview_paths = Vec::new();
            let mut capture_worker = None;
            let mut direct_camera = None;
            let (outcome, cleanup) = finalize_client_session(
                Err(error),
                &mut dual,
                &mut record_paths,
                &mut preview_paths,
                &mut capture_worker,
                &mut direct_camera,
                &mut prepared.audio,
                &mut prepared.transport,
                &client_ctrl,
                &mut disconnect_guard,
                settings,
                peer_addr,
            );
            if let Some(transport) = prepared.transport.as_ref() {
                record_cached_transport_stats(result, transport.stats());
            }
            negotiation::apply_cleanup_result(result, cleanup);
            return outcome;
        }
    };
    let mut audio = prepared
        .audio
        .take()
        .expect("successful media preparation starts audio");
    let mut media_transport = prepared
        .transport
        .take()
        .expect("successful media preparation opens transport");
    result.audio_backend = audio.name().into();
    result.media_transport = if requested_npcap { "npcap" } else { "udp" }.into();
    result.raw_plane_used = requested_npcap;
    result.capabilities = capabilities;
    result.states.push("STREAMING".into());
    if let Some(control) = options.runtime_control.as_ref() {
        control.set_phase(SessionPhase::Streaming);
    }

    let mut resources = ClientStreamResources::default();
    let primary = run_client_stream(
        settings,
        options,
        result,
        &client_ctrl,
        peer_addr,
        peer_audio_addr,
        peer_video_addr,
        remote_video_bpp,
        colors,
        &mut audio,
        &mut media_transport,
        &mut monitor,
        &mut resources,
    );

    result.audio_device_xruns = audio.xruns();
    let mut record_paths = Vec::new();
    let mut audio = Some(audio);
    let mut media_transport = Some(media_transport);
    let (cleanup_outcome, cleanup) = finalize_client_session(
        primary,
        &mut resources.dual,
        &mut record_paths,
        &mut result.preview_paths,
        &mut resources.capture_worker,
        &mut resources.direct_camera,
        &mut audio,
        &mut media_transport,
        &client_ctrl,
        &mut disconnect_guard,
        settings,
        peer_addr,
    );
    result.record_paths = record_paths;
    if let Some(transport) = media_transport.as_ref() {
        record_cached_transport_stats(result, transport.stats());
    }
    negotiation::apply_cleanup_result(result, cleanup);
    cleanup_outcome
}

#[derive(Default)]
struct ClientStreamResources {
    dual: Option<DualStreamRecorder>,
    capture_worker: Option<CaptureWorker>,
    direct_camera: Option<SessionCameraBackend>,
}

#[allow(clippy::too_many_arguments)]
fn run_client_stream(
    settings: &StationSettings,
    options: &SessionOptions,
    result: &mut SessionResult,
    control_socket: &Udp,
    peer: SocketAddr,
    peer_audio: SocketAddr,
    peer_video: SocketAddr,
    remote_video_bpp: u32,
    colors: Option<ColorSettings>,
    audio: &mut SessionAudioBackend,
    transport: &mut SessionMediaTransport,
    monitor: &mut NetworkMonitor,
    resources: &mut ClientStreamResources,
) -> Result<(), SessionError> {
    if session_cancelled(options) {
        return Err(SessionError::PeerDisconnect(
            "session cancelled after media acquisition".into(),
        ));
    }
    send_client_control_extras(settings, options, result, control_socket, peer)?;
    control_socket
        .set_timeout(0.001)
        .map_err(|error| SessionError::Transport(error.to_string()))?;
    let use_jpeg = settings.video.compression
        || result
            .capabilities
            .get("COMP")
            .and_then(serde_json::Value::as_i64)
            .unwrap_or(0)
            == 1;
    result.compression_used = use_jpeg;
    let n_frames = options.stream_frames.max(1);
    result.stream_frames = n_frames;
    let (stream_w, stream_h) = stream_dims(settings.video.width, settings.video.height, options);
    let packet_size = settings.network.video_packet_size as usize;
    let sid = settings.network.session_id as u32;
    let t0 = now_us();
    resources.dual = create_client_recorder(settings, options, audio);
    let mut previews = Vec::new();
    let scheduled = options.interleaved_av
        || options.persistent
        || matches!(
            options.peer_mode.trim().to_ascii_lowercase().as_str(),
            "loopback" | "remote"
        );
    configure_client_capture(
        settings,
        options,
        result,
        packet_size,
        stream_w,
        stream_h,
        colors.clone(),
        use_jpeg,
        sid,
        t0,
        scheduled,
        resources,
    )?;
    let mut video_reassembler = FrameReassembler::strict_video();
    let mut audio_reassembler =
        FrameReassembler::with_limit(settings.network.audio_receive_queue_depth.max(1) as usize);
    let mut audio_queue = ReceivePrefillQueue::new(
        settings.network.audio_receive_queue_depth,
        settings.network.audio_receive_prefill,
    );
    let mut video_queue = ReceivePrefillQueue::new(
        settings.network.video_receive_queue_depth,
        settings.network.video_receive_prefill,
    );
    let started = Instant::now();
    if scheduled {
        run_interleaved_stream(
            resources.capture_worker.as_mut(),
            Some(audio),
            transport,
            settings,
            options,
            result,
            n_frames,
            started,
            peer_audio,
            peer_video,
            control_socket,
            peer,
            packet_size,
            use_jpeg,
            remote_video_bpp,
            stream_w,
            stream_h,
            sid,
            t0,
            &mut resources.dual,
            &mut previews,
            monitor,
            &mut audio_reassembler,
            &mut audio_queue,
            &mut video_reassembler,
            &mut video_queue,
        )?;
    } else {
        run_sequential_client_stream(
            settings,
            options,
            result,
            control_socket,
            peer,
            peer_audio,
            peer_video,
            remote_video_bpp,
            colors.as_ref(),
            audio,
            transport,
            monitor,
            resources,
            n_frames,
            started,
            packet_size,
            stream_w,
            stream_h,
            use_jpeg,
            sid,
            t0,
            &mut audio_reassembler,
            &mut audio_queue,
            &mut video_reassembler,
            &mut video_queue,
            &mut previews,
        )?;
    }
    result.preview_paths = previews;
    record_transport_monitor(result, monitor, transport)?;
    negotiation::set_client_phase(options, SessionPhase::Stopping);
    Ok(())
}

fn send_client_control_extras(
    settings: &StationSettings,
    options: &SessionOptions,
    result: &mut SessionResult,
    socket: &Udp,
    peer: SocketAddr,
) -> Result<(), SessionError> {
    if !options.control_extras {
        return Ok(());
    }
    for (kind, text) in [
        (MESG_SWITCH_ON_BB, ""),
        (MESG_CHAT, options.chat_text.as_str()),
        (MESG_SEND_AUDIO_SIGNAL, ""),
    ] {
        let message = build_session_control(
            settings,
            kind,
            &settings.network.local_ip,
            &settings.network.remote_ip,
            text,
            None,
        )
        .map_err(|error| SessionError::ControlHandshake(error.to_string()))?;
        send_control_datagram(socket, &message, peer)?;
    }
    result.messages_sent.extend([
        "/MESG_SWITCH_ON_BB".into(),
        "/MESG_CHAT".into(),
        "/MESG_SEND_AUDIO_SIGNAL".into(),
    ]);
    result.bounce_back = Some(true);
    result.chat_messages.push(options.chat_text.clone());
    result.audio_signal_active = Some(true);
    thread::sleep(Duration::from_millis(20));
    Ok(())
}

fn create_client_recorder(
    settings: &StationSettings,
    options: &SessionOptions,
    _audio: &SessionAudioBackend,
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
fn configure_client_capture(
    settings: &StationSettings,
    options: &SessionOptions,
    result: &mut SessionResult,
    packet_size: usize,
    width: u32,
    height: u32,
    colors: Option<ColorSettings>,
    use_jpeg: bool,
    sid: u32,
    t0: u64,
    scheduled: bool,
    resources: &mut ClientStreamResources,
) -> Result<(), SessionError> {
    if !options.stream_tx_video || options.audio_only {
        return Ok(());
    }
    let mode = SessionCameraBackend::synthetic_mode(settings, result.camera_mode_id.clone());
    if scheduled {
        let worker = CaptureWorker::start(
            settings,
            options,
            mode,
            packet_size,
            width,
            height,
            colors,
            BayerPattern::parse(&options.bayer_pattern).unwrap_or(BayerPattern::Bggr),
            use_jpeg,
            sid,
            t0,
        )?;
        result.camera_backend = worker.name().into();
        resources.capture_worker = Some(worker);
    } else {
        let camera = SessionCameraBackend::open(settings, options, &mode)?;
        result.camera_backend = camera.name().into();
        resources.direct_camera = Some(camera);
    }
    if let Some(control) = options.runtime_control.as_ref() {
        control.set_activity(result);
    }
    Ok(())
}

#[allow(clippy::too_many_arguments)]
fn run_sequential_client_stream(
    settings: &StationSettings,
    options: &SessionOptions,
    result: &mut SessionResult,
    control: &Udp,
    peer: SocketAddr,
    peer_audio: SocketAddr,
    peer_video: SocketAddr,
    remote_bpp: u32,
    colors: Option<&ColorSettings>,
    audio: &mut SessionAudioBackend,
    transport: &mut SessionMediaTransport,
    monitor: &mut NetworkMonitor,
    resources: &mut ClientStreamResources,
    n_frames: u32,
    started: Instant,
    packet_size: usize,
    stream_w: u32,
    stream_h: u32,
    use_jpeg: bool,
    sid: u32,
    t0: u64,
    audio_reassembler: &mut FrameReassembler,
    audio_queue: &mut ReceivePrefillQueue<Vec<u8>>,
    video_reassembler: &mut FrameReassembler,
    video_queue: &mut ReceivePrefillQueue<ReceivedVideoFrame>,
    previews: &mut Vec<String>,
) -> Result<(), SessionError> {
    let mut audio_writer = crate::protocol::AudioDatagramWriter::new();
    let mut frames = 0;
    if (options.stream_tx_video || options.stream_rx_video) && !options.audio_only {
        while should_stream_more(frames, n_frames, started, options.duration_sec, options) {
            if client_control_disconnect(control, peer, settings, options, result)? {
                break;
            }
            send_recv_video_frame(
                resources.direct_camera.as_mut(),
                transport,
                peer_video,
                video_reassembler,
                packet_size,
                stream_w,
                stream_h,
                remote_bpp,
                settings.video.width,
                settings.video.height,
                settings.video.jpeg_quality,
                settings.video.bayer,
                options,
                colors,
                BayerPattern::parse(&options.bayer_pattern).unwrap_or(BayerPattern::Bggr),
                use_jpeg,
                sid,
                frames,
                t0,
                result,
                &mut resources.dual,
                previews,
                monitor,
                control,
                peer,
                settings,
                video_queue,
            )?;
            if result.peer_disconnected() {
                break;
            }
            frames += 1;
        }
    }
    if options.stream_tx_audio || options.stream_rx_audio {
        for sequence in 0..frames.max(n_frames) {
            if client_control_disconnect(control, peer, settings, options, result)? {
                break;
            }
            send_recv_audio_frame(
                audio,
                transport,
                peer_audio,
                audio_reassembler,
                packet_size,
                settings.audio.channels,
                settings.audio.sample_rate,
                settings.audio.bits_per_sample,
                options,
                options.stream_tx_audio,
                options.stream_rx_audio,
                sid,
                sequence,
                t0,
                result,
                &mut resources.dual,
                monitor,
                audio_queue,
                &mut audio_writer,
            )?;
            if result.peer_disconnected() {
                break;
            }
        }
    }
    Ok(())
}

fn client_control_disconnect(
    control: &Udp,
    peer: SocketAddr,
    settings: &StationSettings,
    options: &SessionOptions,
    result: &mut SessionResult,
) -> Result<bool, SessionError> {
    send_queued_controls(control, peer, settings, options, result)?;
    pump_control(
        control,
        peer,
        settings,
        result,
        options.runtime_control.as_ref(),
    )
}
