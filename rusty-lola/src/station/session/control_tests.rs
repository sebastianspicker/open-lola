use super::*;
use crate::config::default_settings;
use crate::net::Udp;
use crate::protocol::{
    build_control_datagram, decode_mesg, MESG_CHAT, MESG_CHECKLOLASTATUS_ACK, MESG_QUICKCONN_ACK,
};

fn control_packet(settings: &StationSettings, kind: &str) -> Vec<u8> {
    build_control_datagram(
        kind,
        &settings.network.remote_ip,
        &settings.network.local_ip,
        settings.network.session_id as u32,
        None,
        if kind == MESG_CHAT { "hello" } else { "" },
    )
    .unwrap()
}

#[test]
fn ascii_control_rejects_spoofed_sender_and_missing_sid() {
    let settings = default_settings();
    let packet = control_packet(&settings, MESG_CHAT);
    let message = decode_mesg(&packet).unwrap();
    let expected: SocketAddr = format!("{}:7000", settings.network.remote_ip)
        .parse()
        .unwrap();
    let spoofed: SocketAddr = format!("{}:7001", settings.network.remote_ip)
        .parse()
        .unwrap();
    assert!(validate_control_source(&message, spoofed, expected, &settings).is_err());

    let mut missing_sid = message;
    missing_sid.fields.remove("SID");
    assert!(validate_control_source(&missing_sid, expected, expected, &settings).is_err());
}

#[test]
fn disconnect_cancels_runtime_before_mutating_later_stream_state() {
    let runtime = SessionRuntimeControl::default();
    let message = crate::protocol::Mesg {
        name: "/MESG_DISCONNECT".into(),
        fields: Default::default(),
    };
    let mut result = SessionResult::default();
    assert!(apply_stream_control(&message, &mut result, Some(&runtime)));
    assert!(runtime.is_cancelled());
    assert_eq!(result.messages_received, ["/MESG_DISCONNECT"]);
}

#[test]
fn receive_valid_control_ignores_wrong_sender_until_valid_peer_arrives() {
    let settings = default_settings();
    let receiver = Udp::bind("127.0.0.1", 0).unwrap();
    receiver.set_timeout(0.01).unwrap();
    let wrong_sender = Udp::bind("127.0.0.1", 0).unwrap();
    let valid_sender = Udp::bind("127.0.0.1", 0).unwrap();
    let expected = valid_sender.local_addr().unwrap();
    let packet = control_packet(&settings, MESG_CHAT);
    let destination = receiver.local_addr().unwrap();
    wrong_sender.send_to(&packet, destination).unwrap();
    valid_sender.send_to(&packet, destination).unwrap();
    let message = recv_valid_control_until(
        &receiver,
        expected,
        &settings,
        Instant::now() + Duration::from_secs(2),
        None,
        &["/MESG_CHAT"],
    )
    .unwrap();
    assert_eq!(message.name, "/MESG_CHAT");
}

#[test]
fn negotiation_discards_malformed_chat_and_stale_reply_before_status_ack() {
    let _lock = crate::net::udp::UDP_TEST_LOCK
        .lock()
        .unwrap_or_else(|error| error.into_inner());
    let settings = default_settings();
    let receiver = Udp::bind("127.0.0.1", 0).unwrap();
    receiver.set_timeout(0.01).unwrap();
    let peer = Udp::bind("127.0.0.1", 0).unwrap();
    let destination = receiver.local_addr().unwrap();
    peer.send_to(b"not a LoLa control packet", destination)
        .unwrap();
    peer.send_to(&control_packet(&settings, MESG_CHAT), destination)
        .unwrap();
    peer.send_to(&control_packet(&settings, MESG_QUICKCONN_ACK), destination)
        .unwrap();
    peer.send_to(
        &control_packet(&settings, MESG_CHECKLOLASTATUS_ACK),
        destination,
    )
    .unwrap();

    let message = recv_valid_control_until(
        &receiver,
        peer.local_addr().unwrap(),
        &settings,
        Instant::now() + Duration::from_secs(5),
        None,
        STATUS_REPLY_KINDS,
    )
    .unwrap();
    assert_eq!(message.name, "/MESG_CHECKLOLASTATUS_ACK");
}

#[test]
fn stop_during_both_ack_waits_within_poll_budget() {
    let settings = default_settings();
    let receiver = Udp::bind("127.0.0.1", 0).unwrap();
    let peer = Udp::bind("127.0.0.1", 0).unwrap();
    let control = SessionRuntimeControl::default();
    for _ in 0..2 {
        control.cancel();
        let started = Instant::now();
        assert!(matches!(
            recv_valid_control_until(
                &receiver,
                peer.local_addr().unwrap(),
                &settings,
                Instant::now() + Duration::from_millis(20),
                Some(&control),
                STATUS_REPLY_KINDS,
            ),
            Err(SessionError::PeerDisconnect(_))
        ));
        assert!(started.elapsed() < Duration::from_millis(10));
    }
}
