use super::audio::send_recv_audio_frame;
use super::backends::SessionCameraBackend;
use super::capture::CaptureWorker;
use super::client_cleanup::finalize_client_session;
use super::client_media::prepare_client_media;
use super::control::{
    build_session_control, protocol_media_settings, pump_control, recv_valid_control_until,
    resolve_peer_ipv4, send_control_datagram, send_queued_controls, verify_quickconn_ack_audio,
    ClientDisconnectGuard, QUICKCONN_REPLY_KINDS, STATUS_REPLY_KINDS,
};
use super::media::{should_stream_more, ReceivePrefillQueue};
use super::stream::run_interleaved_stream;
use super::types::{now_us, session_cancelled, stream_dims};
use super::video::{send_recv_video_frame, ReceivedVideoFrame};
use super::{SessionOptions, SessionPhase, SessionResult};
use crate::config::{load_ximea_colors, ColorSettings, MediaTransportKind, StationSettings};
use crate::net::Udp;
use crate::protocol::{
    parse_quickconn_fields, FrameReassembler, MESG_CHAT, MESG_CHECKLOLASTATUS, MESG_QUICKCONN,
    MESG_SEND_AUDIO_SIGNAL, MESG_SWITCH_ON_BB,
};
use crate::shipped_ximea_colors;
use crate::station::dual_recorder::DualStreamRecorder;
use crate::station::monitor::NetworkMonitor;
use crate::station::SessionError;
use crate::video::BayerPattern;
use std::fs;
use std::net::SocketAddr;
use std::thread;
use std::time::{Duration, Instant};

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
    // CHECK
    if let Some(control) = options.runtime_control.as_ref() {
        control.set_phase(SessionPhase::Checking);
    }
    result.states.push("WAITING_STATUS".into());
    let t_check = Instant::now();
    let negotiation_deadline = t_check + Duration::from_secs_f64(timeout.max(0.01));
    let check = build_session_control(
        settings,
        MESG_CHECKLOLASTATUS,
        &settings.network.local_ip,
        &settings.network.remote_ip,
        "",
        None,
    )
    .map_err(|e| SessionError::ControlHandshake(e.to_string()))?;
    send_control_datagram(&client_ctrl, &check, peer_addr)?;
    result.messages_sent.push("/MESG_CHECKLOLASTATUS".into());
    let msg = recv_valid_control_until(
        &client_ctrl,
        peer_addr,
        settings,
        negotiation_deadline,
        options.runtime_control.as_ref(),
        STATUS_REPLY_KINDS,
    )?;
    let rtt = t_check.elapsed().as_secs_f64() * 1000.0;
    monitor.note_rtt(rtt);
    result.rtt_ms = Some(rtt);
    if msg.name != "/MESG_CHECKLOLASTATUS_ACK" {
        return Err(SessionError::ControlHandshake(format!(
            "expected STATUS_ACK got {}",
            msg.name
        )));
    }
    result.messages_received.push(msg.name);
    result.states.push("READY".into());
    // QUICKCONN
    if let Some(control) = options.runtime_control.as_ref() {
        control.set_phase(SessionPhase::Negotiating);
    }
    result.states.push("NEGOTIATING".into());
    let v = &settings.video;
    let a = &settings.audio;
    let mut requested_media = protocol_media_settings(settings);
    // Auto-Bayer turns the captured Mono8 plane into RGB24 before raw video
    // is serialized, so the negotiated wire BPP must describe that output.
    if options.auto_bayer
        && !options.test_signal_active()
        && requested_media.bayer != 0
        && requested_media.compression == 0
    {
        requested_media.bits_per_pixel = 24;
    }
    let qc = build_session_control(
        settings,
        MESG_QUICKCONN,
        &settings.network.local_ip,
        &settings.network.remote_ip,
        "",
        Some(&requested_media),
    )
    .map_err(|e| SessionError::ControlHandshake(e.to_string()))?;
    send_control_datagram(&client_ctrl, &qc, peer_addr)?;
    result.messages_sent.push("/MESG_QUICKCONN".into());
    let msg = recv_valid_control_until(
        &client_ctrl,
        peer_addr,
        settings,
        negotiation_deadline,
        options.runtime_control.as_ref(),
        QUICKCONN_REPLY_KINDS,
    )?;
    result.messages_received.push(msg.name.clone());
    if msg.name == "/MESG_REJECT" {
        result.rejected = true;
        result.reject_text = msg.fields.get("TXT").cloned().unwrap_or_default();
        result.states.push("REJECTED".into());
        return Ok(());
    }
    if msg.name != "/MESG_QUICKCONN_ACK" {
        return Err(SessionError::ControlHandshake(format!(
            "expected QUICKCONN_ACK got {}",
            msg.name
        )));
    }
    let capabilities =
        parse_quickconn_fields(&msg).map_err(|e| SessionError::ControlHandshake(e.to_string()))?;
    let remote_video_bpp = capabilities
        .get("BPP")
        .and_then(serde_json::Value::as_u64)
        .and_then(|value| u32::try_from(value).ok())
        .unwrap_or(0);
    verify_quickconn_ack_audio(&msg, &requested_media)?;
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
            let mut capture_worker = None;
            let mut direct_camera = None;
            let (outcome, cleanup) = finalize_client_session(
                Err(error),
                &mut dual,
                &mut record_paths,
                &mut capture_worker,
                &mut direct_camera,
                &mut prepared.audio,
                &mut prepared.transport,
                &client_ctrl,
                &mut disconnect_guard,
                settings,
                peer_addr,
            );
            apply_cleanup_result(result, cleanup);
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

    let mut dual: Option<DualStreamRecorder> = None;
    let mut capture_worker: Option<CaptureWorker> = None;
    let mut direct_camera: Option<SessionCameraBackend> = None;
    let primary = (|| -> Result<(), SessionError> {
        if session_cancelled(options) {
            return Err(SessionError::PeerDisconnect(
                "session cancelled after media acquisition".into(),
            ));
        }
        // Control extras
        if options.control_extras {
            let on = build_session_control(
                settings,
                MESG_SWITCH_ON_BB,
                &settings.network.local_ip,
                &settings.network.remote_ip,
                "",
                None,
            )
            .map_err(|e| SessionError::ControlHandshake(e.to_string()))?;
            send_control_datagram(&client_ctrl, &on, peer_addr)?;
            result.messages_sent.push("/MESG_SWITCH_ON_BB".into());
            result.bounce_back = Some(true);

            let chat = build_session_control(
                settings,
                MESG_CHAT,
                &settings.network.local_ip,
                &settings.network.remote_ip,
                &options.chat_text,
                None,
            )
            .map_err(|e| SessionError::ControlHandshake(e.to_string()))?;
            send_control_datagram(&client_ctrl, &chat, peer_addr)?;
            result.messages_sent.push("/MESG_CHAT".into());
            result.chat_messages.push(options.chat_text.clone());

            let sig = build_session_control(
                settings,
                MESG_SEND_AUDIO_SIGNAL,
                &settings.network.local_ip,
                &settings.network.remote_ip,
                "",
                None,
            )
            .map_err(|e| SessionError::ControlHandshake(e.to_string()))?;
            send_control_datagram(&client_ctrl, &sig, peer_addr)?;
            result.messages_sent.push("/MESG_SEND_AUDIO_SIGNAL".into());
            result.audio_signal_active = Some(true);

            thread::sleep(Duration::from_millis(20));
        }
        client_ctrl
            .set_timeout(0.001)
            .map_err(|error| SessionError::Transport(error.to_string()))?;

        let use_jpeg = v.compression
            || result
                .capabilities
                .get("COMP")
                .and_then(|c| c.as_i64())
                .unwrap_or(0)
                == 1;
        result.compression_used = use_jpeg;
        let n_frames = options.stream_frames.max(1);
        result.stream_frames = n_frames;
        let (stream_w, stream_h) = stream_dims(v.width, v.height, options);
        let packet_size = settings.network.video_packet_size as usize;
        let sid = settings.network.session_id as u32;
        let t0 = now_us();
        let stream_t0 = Instant::now();

        dual = if options.record {
            if let Some(dir) = &options.record_dir {
                fs::create_dir_all(dir).ok();
                Some(DualStreamRecorder::with_options(
                    dir,
                    a.sample_rate,
                    a.channels,
                    a.bits_per_sample,
                    "session",
                    &settings.recording.mode,
                    settings.recording.record_local_audio,
                    settings.recording.record_remote_audio,
                    settings.recording.record_local_video,
                    settings.recording.record_remote_video,
                    &settings.recording.video_format,
                ))
            } else {
                None
            }
        } else {
            None
        };

        let mut preview_paths = Vec::new();
        if let Some(dir) = &options.preview_dir {
            fs::create_dir_all(dir).ok();
        }

        let mut v_re = FrameReassembler::strict_video();
        let mut a_re = FrameReassembler::with_limit(
            settings.network.audio_receive_queue_depth.max(1) as usize,
        );
        let mut audio_receive_queue = ReceivePrefillQueue::new(
            settings.network.audio_receive_queue_depth,
            settings.network.audio_receive_prefill,
        );
        let mut video_receive_queue: ReceivePrefillQueue<ReceivedVideoFrame> =
            ReceivePrefillQueue::new(
                settings.network.video_receive_queue_depth,
                settings.network.video_receive_prefill,
            );
        let bayer_pat = BayerPattern::parse(&options.bayer_pattern).unwrap_or(BayerPattern::Bggr);
        let do_video = (options.stream_tx_video || options.stream_rx_video) && !options.audio_only;
        let do_audio = options.stream_tx_audio || options.stream_rx_audio;
        let mut frame_i = 0u32;
        // Every supported initiator role uses the deadline scheduler. The
        // sequential branch remains only as a compatibility guard for an
        // invalid role that the public configuration layer rejects.
        let supported_initiator_role = matches!(
            options.peer_mode.trim().to_ascii_lowercase().as_str(),
            "loopback" | "remote"
        );
        let scheduled = options.interleaved_av || options.persistent || supported_initiator_role;
        if options.stream_tx_video && !options.audio_only {
            let mode =
                SessionCameraBackend::synthetic_mode(settings, result.camera_mode_id.clone());
            if scheduled {
                let worker = CaptureWorker::start(
                    settings,
                    options,
                    mode,
                    packet_size,
                    stream_w,
                    stream_h,
                    colors.clone(),
                    bayer_pat,
                    use_jpeg,
                    sid,
                    t0,
                )?;
                result.camera_backend = worker.name().into();
                capture_worker = Some(worker);
            } else {
                let camera = SessionCameraBackend::open(settings, options, &mode)?;
                result.camera_backend = camera.name().into();
                direct_camera = Some(camera);
            }
            if let Some(control) = options.runtime_control.as_ref() {
                control.set_activity(result);
            }
        }
        if scheduled {
            run_interleaved_stream(
                capture_worker.as_mut(),
                Some(&mut audio),
                &mut media_transport,
                settings,
                options,
                result,
                n_frames,
                stream_t0,
                peer_audio_addr,
                peer_video_addr,
                &client_ctrl,
                peer_addr,
                packet_size,
                use_jpeg,
                remote_video_bpp,
                stream_w,
                stream_h,
                sid,
                t0,
                &mut dual,
                &mut preview_paths,
                &mut monitor,
                &mut a_re,
                &mut audio_receive_queue,
                &mut v_re,
                &mut video_receive_queue,
            )?;
        } else {
            if do_video {
                while should_stream_more(
                    frame_i,
                    n_frames,
                    stream_t0,
                    options.duration_sec,
                    options,
                ) {
                    send_queued_controls(&client_ctrl, peer_addr, settings, options, result)?;
                    if pump_control(
                        &client_ctrl,
                        peer_addr,
                        settings,
                        result,
                        options.runtime_control.as_ref(),
                    )? {
                        break;
                    }
                    send_recv_video_frame(
                        direct_camera.as_mut(),
                        &mut media_transport,
                        peer_video_addr,
                        &mut v_re,
                        packet_size,
                        stream_w,
                        stream_h,
                        remote_video_bpp,
                        v.width,
                        v.height,
                        v.jpeg_quality,
                        settings.video.bayer,
                        options,
                        colors.as_ref(),
                        bayer_pat,
                        use_jpeg,
                        sid,
                        frame_i,
                        t0,
                        result,
                        &mut dual,
                        &mut preview_paths,
                        &mut monitor,
                        &client_ctrl,
                        peer_addr,
                        settings,
                        &mut video_receive_queue,
                    )?;
                    if result.peer_disconnected() {
                        break;
                    }
                    frame_i += 1;
                }
            }
            let planned = frame_i.max(n_frames);
            if do_audio {
                for i in 0..planned {
                    if pump_control(
                        &client_ctrl,
                        peer_addr,
                        settings,
                        result,
                        options.runtime_control.as_ref(),
                    )? {
                        break;
                    }
                    send_recv_audio_frame(
                        &mut audio,
                        &mut media_transport,
                        peer_audio_addr,
                        &mut a_re,
                        packet_size,
                        a.channels,
                        a.sample_rate,
                        a.bits_per_sample,
                        options,
                        options.stream_tx_audio,
                        options.stream_rx_audio,
                        sid,
                        i,
                        t0,
                        result,
                        &mut dual,
                        &mut monitor,
                        &mut audio_receive_queue,
                    )?;
                    if result.peer_disconnected() {
                        break;
                    }
                }
            }
        }

        result.preview_paths = preview_paths;
        result.network_monitor = monitor.to_int_map();
        result.network_monitor_report = monitor.to_report();
        let stats = media_transport.stats();
        for (name, value) in [
            ("sent_datagrams", stats.sent_datagrams),
            ("received_datagrams", stats.received_datagrams),
            ("sent_bytes", stats.sent_bytes),
            ("received_bytes", stats.received_bytes),
            ("malformed_drops", stats.malformed_drops),
            ("wrong_peer_drops", stats.wrong_peer_drops),
            ("wrong_port_drops", stats.wrong_port_drops),
            ("kernel_drops", stats.kernel_drops),
            ("backpressure_drops", stats.backpressure_drops),
            ("queue_replacement_drops", stats.queue_replacement_drops),
        ] {
            result.network_monitor.insert(name.into(), value as i64);
        }

        if let Some(control) = options.runtime_control.as_ref() {
            control.set_phase(SessionPhase::Stopping);
        }

        Ok(())
    })();

    let mut record_paths = Vec::new();
    let mut audio = Some(audio);
    let mut media_transport = Some(media_transport);
    let (cleanup_outcome, cleanup) = finalize_client_session(
        primary,
        &mut dual,
        &mut record_paths,
        &mut capture_worker,
        &mut direct_camera,
        &mut audio,
        &mut media_transport,
        &client_ctrl,
        &mut disconnect_guard,
        settings,
        peer_addr,
    );
    result.record_paths = record_paths;
    apply_cleanup_result(result, cleanup);
    cleanup_outcome
}

fn apply_cleanup_result(result: &mut SessionResult, cleanup: super::lifecycle::CleanupReport) {
    result.cleanup_warnings.extend(cleanup.warnings);
    if cleanup.stop_audio_signal_sent {
        result.messages_sent.push("/MESG_STOP_AUDIO_SIGNAL".into());
    }
    if cleanup.disconnect_sent {
        result.messages_sent.push("/MESG_DISCONNECT".into());
    }
}
