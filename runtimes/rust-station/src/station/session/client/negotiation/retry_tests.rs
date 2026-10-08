//! A lost handshake datagram is re-sent instead of consuming the window.
use super::*;
use crate::config::default_settings;
use crate::protocol::decode_mesg;
use std::net::UdpSocket;
use std::thread;

#[test]
fn unanswered_status_check_is_resent_until_the_responder_answers() {
    let mut settings = default_settings();
    settings.network.local_ip = "127.0.0.1".into();
    settings.network.remote_ip = "127.0.0.1".into();
    let client = Udp::bind("127.0.0.1", 0).unwrap();
    let responder = UdpSocket::bind("127.0.0.1:0").unwrap();
    responder
        .set_read_timeout(Some(Duration::from_secs(5)))
        .unwrap();
    let peer = responder.local_addr().unwrap();
    let ack = build_session_control(
        &settings,
        crate::protocol::MESG_CHECKLOLASTATUS_ACK,
        &settings.network.remote_ip,
        &settings.network.local_ip,
        "",
        None,
    )
    .unwrap();
    // The responder ignores the first request (a lost datagram on the wire)
    // and answers the second one.
    let responder_thread = thread::spawn(move || {
        let mut buffer = [0; 2048];
        let mut received = Vec::new();
        for attempt in 0..2 {
            let (size, source) = responder.recv_from(&mut buffer).unwrap();
            received.push(decode_mesg(&buffer[..size]).unwrap().name);
            if attempt == 1 {
                responder.send_to(&ack, source).unwrap();
            }
        }
        received
    });
    let status = build_session_control(
        &settings,
        MESG_CHECKLOLASTATUS,
        &settings.network.local_ip,
        &settings.network.remote_ip,
        "",
        None,
    )
    .unwrap();
    let mut sent = Vec::new();
    let started = Instant::now();
    let reply = send_control_with_retries(
        &client,
        &status,
        peer,
        &settings,
        started + Duration::from_secs(5),
        None,
        STATUS_REPLY_KINDS,
        &mut sent,
        "/MESG_CHECKLOLASTATUS",
    )
    .unwrap();
    assert_eq!(reply.name, "/MESG_CHECKLOLASTATUS_ACK");
    assert_eq!(sent.len(), 2, "exactly one re-send was needed");
    assert!(started.elapsed() >= HANDSHAKE_RETRY_INTERVAL);
    assert!(started.elapsed() < Duration::from_secs(4));
    assert_eq!(
        responder_thread.join().unwrap(),
        vec!["/MESG_CHECKLOLASTATUS", "/MESG_CHECKLOLASTATUS"]
    );
}

#[test]
fn handshake_without_any_reply_times_out_at_the_deadline() {
    let mut settings = default_settings();
    settings.network.local_ip = "127.0.0.1".into();
    settings.network.remote_ip = "127.0.0.1".into();
    let client = Udp::bind("127.0.0.1", 0).unwrap();
    let silent = UdpSocket::bind("127.0.0.1:0").unwrap();
    let status = build_session_control(
        &settings,
        MESG_CHECKLOLASTATUS,
        &settings.network.local_ip,
        &settings.network.remote_ip,
        "",
        None,
    )
    .unwrap();
    let mut sent = Vec::new();
    let started = Instant::now();
    let error = send_control_with_retries(
        &client,
        &status,
        silent.local_addr().unwrap(),
        &settings,
        started + Duration::from_millis(1200),
        None,
        STATUS_REPLY_KINDS,
        &mut sent,
        "/MESG_CHECKLOLASTATUS",
    )
    .unwrap_err();
    assert!(matches!(error, SessionError::Timeout(_)), "{error}");
    assert!(sent.len() >= 2 && sent.len() <= 4, "{} sends", sent.len());
    assert!(started.elapsed() >= Duration::from_millis(1100));
}

#[test]
fn nothing_is_sent_once_the_deadline_has_passed() {
    let mut settings = default_settings();
    settings.network.local_ip = "127.0.0.1".into();
    settings.network.remote_ip = "127.0.0.1".into();
    let client = Udp::bind("127.0.0.1", 0).unwrap();
    let silent = UdpSocket::bind("127.0.0.1:0").unwrap();
    silent
        .set_read_timeout(Some(Duration::from_millis(200)))
        .unwrap();
    let mut sent = Vec::new();
    let error = send_control_with_retries(
        &client,
        b"/MESG_CHECKLOLASTATUS;",
        silent.local_addr().unwrap(),
        &settings,
        Instant::now(),
        None,
        STATUS_REPLY_KINDS,
        &mut sent,
        "/MESG_CHECKLOLASTATUS",
    )
    .unwrap_err();
    assert!(matches!(error, SessionError::Timeout(_)), "{error}");
    assert!(sent.is_empty());
    assert!(silent.recv_from(&mut [0; 64]).is_err(), "datagram leaked");
}

#[test]
fn reject_reason_is_unescaped() {
    let reply = crate::protocol::Mesg {
        name: "/MESG_REJECT".into(),
        fields: [("TXT".to_string(), "bad%3A media%3B 5%25".to_string())].into(),
    };
    assert_eq!(reject_reason(&reply), "bad: media; 5%");
}
