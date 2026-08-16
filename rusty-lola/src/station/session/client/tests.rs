use super::*;
use crate::config::default_settings;
use crate::net::Udp;
use crate::protocol::{
    build_control_datagram, decode_mesg, MESG_CHECKLOLASTATUS_ACK, MESG_QUICKCONN_ACK, MESG_REJECT,
};
use crate::station::{SessionError, SessionRuntimeControl};
use std::thread;
use std::time::{Duration, Instant};

#[test]
fn quickconn_ack_requires_only_matching_audio_fields() {
    let settings = default_settings();
    let requested = protocol_media_settings(&settings);
    let packet = build_control_datagram(
        MESG_QUICKCONN_ACK,
        &settings.network.remote_ip,
        &settings.network.local_ip,
        settings.network.session_id as u32,
        Some(&requested),
        "",
    )
    .unwrap();
    let mut message = decode_mesg(&packet).unwrap();
    message.fields.insert("BAYER".into(), "0".into());
    assert!(verify_quickconn_ack_audio(&message, &requested).is_ok());
    message.fields.insert("SR".into(), "48000".into());
    assert!(matches!(
        verify_quickconn_ack_audio(&message, &requested),
        Err(SessionError::ControlHandshake(_))
    ));
}

#[derive(Clone, Copy)]
enum NegotiationReply {
    Reject,
    MalformedAck,
    IncompatibleAck,
    AcceptedThenCancel,
}

fn distinct_ports() -> [u16; 4] {
    let mut selected = Vec::with_capacity(4);
    while selected.len() < 4 {
        let port = Udp::free_port("127.0.0.1").unwrap();
        if !selected.contains(&port) {
            selected.push(port);
        }
    }
    selected.try_into().unwrap()
}

fn remote_settings(ports: [u16; 4]) -> crate::config::StationSettings {
    let mut settings = default_settings();
    settings.network.bind_ip = "127.0.0.1".into();
    settings.network.local_ip = "127.0.0.1".into();
    settings.network.remote_ip = "127.0.0.1".into();
    settings.network.control_port = ports[0];
    settings.network.audio_port = ports[1];
    settings.network.video_port = ports[2];
    settings
}

fn remote_options() -> SessionOptions {
    let mut options = SessionOptions::demo();
    options.peer_mode = "remote".into();
    options.control_extras = false;
    options.apply_color = false;
    options.auto_bayer = false;
    options.stream_frames = 1;
    options
}

fn spawn_negotiator(
    settings: crate::config::StationSettings,
    peer_control: u16,
    reply: NegotiationReply,
    runtime: Option<SessionRuntimeControl>,
) -> thread::JoinHandle<Vec<String>> {
    let (ready_sender, ready_receiver) = std::sync::mpsc::sync_channel(0);
    let handle = thread::spawn(move || {
        let control = Udp::bind("127.0.0.1", peer_control).unwrap();
        control.set_timeout(1.0).unwrap();
        ready_sender.send(()).unwrap();
        let (_, client) = control.recv_vec().unwrap();
        let status = build_session_control(
            &settings,
            MESG_CHECKLOLASTATUS_ACK,
            &settings.network.local_ip,
            &settings.network.remote_ip,
            "",
            None,
        )
        .unwrap();
        send_control_datagram(&control, &status, client).unwrap();
        let (_, client) = control.recv_vec().unwrap();
        match reply {
            NegotiationReply::MalformedAck => {
                control
                    .send_to(b"not a LoLa control packet", client)
                    .unwrap();
            }
            NegotiationReply::Reject => {
                let rejection = build_session_control(
                    &settings,
                    MESG_REJECT,
                    &settings.network.local_ip,
                    &settings.network.remote_ip,
                    "busy",
                    None,
                )
                .unwrap();
                send_control_datagram(&control, &rejection, client).unwrap();
            }
            NegotiationReply::IncompatibleAck | NegotiationReply::AcceptedThenCancel => {
                let mut media = protocol_media_settings(&settings);
                if matches!(reply, NegotiationReply::IncompatibleAck) {
                    media.sample_rate += 1;
                }
                let acknowledgement = build_session_control(
                    &settings,
                    MESG_QUICKCONN_ACK,
                    &settings.network.local_ip,
                    &settings.network.remote_ip,
                    "",
                    Some(&media),
                )
                .unwrap();
                send_control_datagram(&control, &acknowledgement, client).unwrap();
            }
        }
        if let Some(runtime) = runtime {
            let deadline = Instant::now() + Duration::from_secs(1);
            while runtime.phase() != SessionPhase::Streaming && Instant::now() < deadline {
                thread::sleep(Duration::from_millis(1));
            }
            runtime.cancel();
        }

        let mut messages = Vec::new();
        let deadline = Instant::now() + Duration::from_millis(300);
        while Instant::now() < deadline {
            control.set_timeout(0.02).unwrap();
            match control.recv_vec() {
                Ok((packet, _)) => {
                    if let Ok(message) = decode_mesg(&packet) {
                        messages.push(message.name);
                    }
                }
                Err(error)
                    if matches!(
                        error.kind(),
                        std::io::ErrorKind::TimedOut | std::io::ErrorKind::WouldBlock
                    ) => {}
                Err(error) => panic!("control receive failed: {error}"),
            }
        }
        messages
    });
    ready_receiver.recv().unwrap();
    handle
}

#[test]
fn status_timeout_does_not_open_fixed_media_or_send_terminal_control() {
    let _lock = crate::net::udp::UDP_TEST_LOCK
        .lock()
        .unwrap_or_else(|error| error.into_inner());
    let ports = distinct_ports();
    let settings = remote_settings(ports);
    let _audio_reservation = Udp::bind("127.0.0.1", ports[1]).unwrap();
    let _video_reservation = Udp::bind("127.0.0.1", ports[2]).unwrap();
    let mut result = SessionResult::default();

    let outcome = client_session(
        &settings,
        &remote_options(),
        &mut result,
        0.05,
        ports[3],
        ports[1],
        ports[2],
        "127.0.0.1",
    );

    assert!(matches!(outcome, Err(SessionError::Timeout(_))));
    assert!(result.audio_backend.is_empty());
    assert!(!result.messages_sent.iter().any(|message| {
        matches!(
            message.as_str(),
            "/MESG_STOP_AUDIO_SIGNAL" | "/MESG_DISCONNECT"
        )
    }));
}

#[test]
fn malformed_or_incompatible_ack_does_not_open_media_or_send_terminal_control() {
    let _lock = crate::net::udp::UDP_TEST_LOCK
        .lock()
        .unwrap_or_else(|error| error.into_inner());
    for reply in [
        NegotiationReply::MalformedAck,
        NegotiationReply::IncompatibleAck,
    ] {
        let ports = distinct_ports();
        let settings = remote_settings(ports);
        let _audio_reservation = Udp::bind("127.0.0.1", ports[1]).unwrap();
        let _video_reservation = Udp::bind("127.0.0.1", ports[2]).unwrap();
        let peer = spawn_negotiator(settings.clone(), ports[3], reply, None);
        let mut result = SessionResult::default();

        let outcome = client_session(
            &settings,
            &remote_options(),
            &mut result,
            0.5,
            ports[3],
            ports[1],
            ports[2],
            "127.0.0.1",
        );

        assert!(outcome.is_err());
        assert!(result.audio_backend.is_empty());
        assert!(!result.messages_sent.iter().any(|message| {
            matches!(
                message.as_str(),
                "/MESG_STOP_AUDIO_SIGNAL" | "/MESG_DISCONNECT"
            )
        }));
        assert!(peer.join().unwrap().iter().all(|message| !matches!(
            message.as_str(),
            "/MESG_STOP_AUDIO_SIGNAL" | "/MESG_DISCONNECT"
        )));
    }
}

#[test]
fn reject_does_not_open_media_or_send_terminal_control() {
    let _lock = crate::net::udp::UDP_TEST_LOCK
        .lock()
        .unwrap_or_else(|error| error.into_inner());
    let ports = distinct_ports();
    let settings = remote_settings(ports);
    let _audio_reservation = Udp::bind("127.0.0.1", ports[1]).unwrap();
    let _video_reservation = Udp::bind("127.0.0.1", ports[2]).unwrap();
    let peer = spawn_negotiator(settings.clone(), ports[3], NegotiationReply::Reject, None);
    let mut result = SessionResult::default();

    assert!(client_session(
        &settings,
        &remote_options(),
        &mut result,
        0.5,
        ports[3],
        ports[1],
        ports[2],
        "127.0.0.1",
    )
    .is_ok());
    assert!(result.rejected);
    assert!(result.audio_backend.is_empty());
    assert!(!result.messages_sent.iter().any(|message| {
        matches!(
            message.as_str(),
            "/MESG_STOP_AUDIO_SIGNAL" | "/MESG_DISCONNECT"
        )
    }));
    assert!(peer.join().unwrap().iter().all(|message| !matches!(
        message.as_str(),
        "/MESG_STOP_AUDIO_SIGNAL" | "/MESG_DISCONNECT"
    )));
}

#[test]
fn cancellation_after_ack_checked_cleans_once() {
    let _lock = crate::net::udp::UDP_TEST_LOCK
        .lock()
        .unwrap_or_else(|error| error.into_inner());
    let ports = distinct_ports();
    let settings = remote_settings(ports);
    let runtime = SessionRuntimeControl::default();
    let peer = spawn_negotiator(
        settings.clone(),
        ports[3],
        NegotiationReply::AcceptedThenCancel,
        Some(runtime.clone()),
    );
    let mut options = remote_options();
    options.runtime_control = Some(runtime);
    let mut result = SessionResult::default();

    assert!(client_session(
        &settings,
        &options,
        &mut result,
        1.0,
        ports[3],
        ports[1],
        ports[2],
        "127.0.0.1",
    )
    .is_ok());
    assert!(!result.audio_backend.is_empty());
    assert_eq!(
        result
            .messages_sent
            .iter()
            .filter(|message| message.as_str() == "/MESG_STOP_AUDIO_SIGNAL")
            .count(),
        1
    );
    assert_eq!(
        result
            .messages_sent
            .iter()
            .filter(|message| message.as_str() == "/MESG_DISCONNECT")
            .count(),
        1
    );
    let received = peer.join().unwrap();
    assert_eq!(
        received
            .iter()
            .filter(|message| message.as_str() == "/MESG_STOP_AUDIO_SIGNAL")
            .count(),
        1
    );
    assert_eq!(
        received
            .iter()
            .filter(|message| message.as_str() == "/MESG_DISCONNECT")
            .count(),
        1
    );
}
