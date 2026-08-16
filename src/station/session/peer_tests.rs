use super::*;
use crate::config::default_settings;
use crate::protocol::{MESG_CHAT, MESG_CHECKLOLASTATUS_ACK, MESG_QUICKCONN};

fn listener_packet(settings: &StationSettings, kind: &str) -> Vec<u8> {
    build_session_control(
        settings,
        kind,
        &settings.network.remote_ip,
        &settings.network.local_ip,
        "",
        (kind == MESG_QUICKCONN)
            .then(|| super::super::control::protocol_media_settings(settings))
            .as_ref(),
    )
    .unwrap()
}

#[test]
fn listener_negotiation_observes_cancellation_before_socket_timeout() {
    let socket = Udp::bind("127.0.0.1", 0).unwrap();
    let settings = default_settings();
    let control = super::super::SessionRuntimeControl::default();
    control.cancel();
    let mut options = SessionOptions::demo();
    options.runtime_control = Some(control);
    let started = Instant::now();
    assert!(matches!(
        recv_peer_control_until(
            &socket,
            &settings,
            &options,
            None,
            started + Duration::from_secs(1),
            INITIAL_NEGOTIATION_KINDS,
        ),
        Err(SessionError::PeerDisconnect(_))
    ));
    assert!(started.elapsed() < Duration::from_millis(100));
}

#[test]
fn listener_negotiation_discards_noise_until_expected_quickconn() {
    let settings = default_settings();
    let receiver = Udp::bind("127.0.0.1", 0).unwrap();
    let peer = Udp::bind("127.0.0.1", 0).unwrap();
    let destination = receiver.local_addr().unwrap();
    peer.send_to(b"malformed", destination).unwrap();
    peer.send_to(&listener_packet(&settings, MESG_CHAT), destination)
        .unwrap();
    peer.send_to(
        &listener_packet(&settings, MESG_CHECKLOLASTATUS_ACK),
        destination,
    )
    .unwrap();
    peer.send_to(&listener_packet(&settings, MESG_QUICKCONN), destination)
        .unwrap();

    let (message, sender) = recv_peer_control_until(
        &receiver,
        &settings,
        &SessionOptions::demo(),
        None,
        Instant::now() + Duration::from_secs(1),
        INITIAL_NEGOTIATION_KINDS,
    )
    .unwrap();
    assert_eq!(sender, peer.local_addr().unwrap());
    assert_eq!(message.name, "/MESG_QUICKCONN");
}
