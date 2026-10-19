//! Bounded operator diagnostics with explicit evidence provenance.
use crate::config::default_settings;
use crate::protocol::{build_control_datagram, decode_mesg, MESG_CHECKLOLASTATUS};
use crate::station::{run_session, SessionOptions};
use serde_json::{json, Value};
use std::net::{Ipv4Addr, SocketAddrV4, UdpSocket};
use std::time::{Duration, Instant};

pub(super) fn print_result(result: Result<Value, String>) -> i32 {
    match result {
        Ok(value) => {
            let ok = value.get("ok").and_then(Value::as_bool).unwrap_or(true);
            println!("{}", serde_json::to_string_pretty(&value).unwrap());
            i32::from(!ok)
        }
        Err(error) => {
            eprintln!("{error}");
            1
        }
    }
}

pub(super) fn status(
    peer: &str,
    local: &str,
    sid: u32,
    port: u16,
    timeout: f64,
) -> Result<Value, String> {
    if !timeout.is_finite() || !(0.001..=60.0).contains(&timeout) {
        return Err("timeout must be 0.001..=60 seconds".into());
    }
    let peer_ip: Ipv4Addr = peer
        .parse()
        .map_err(|_| "peer must be a numeric IPv4 address")?;
    let local_ip: Ipv4Addr = local
        .parse()
        .map_err(|_| "local-ip must be a numeric IPv4 address")?;
    let (socket, note) = bind_probe_socket(local_ip, port)?;
    if let Some(note) = note {
        eprintln!("{note}");
    }
    let peer = SocketAddrV4::new(peer_ip, port);
    status_on_socket(&socket, peer, sid, timeout)
}

/// A listener only accepts control traffic from its configured control port, so the
/// probe sends from that port. Binding it is the smaller fix: the listener keeps its
/// peer pinning for session traffic. If the port is busy (for example a local station
/// is running) fall back to an ephemeral port and say why the probe may time out.
fn bind_probe_socket(local: Ipv4Addr, port: u16) -> Result<(UdpSocket, Option<String>), String> {
    match UdpSocket::bind(SocketAddrV4::new(local, port)) {
        Ok(socket) => Ok((socket, None)),
        Err(error) => {
            let socket = UdpSocket::bind(SocketAddrV4::new(local, 0)).map_err(|e| e.to_string())?;
            let note = format!(
                "status: could not bind control port {port} on {local} ({error}); probing from an ephemeral port, which a listener that pins the control port will ignore"
            );
            Ok((socket, Some(note)))
        }
    }
}

fn status_on_socket(
    socket: &UdpSocket,
    peer: SocketAddrV4,
    sid: u32,
    timeout: f64,
) -> Result<Value, String> {
    socket.set_nonblocking(true).map_err(|e| e.to_string())?;
    let local = socket
        .local_addr()
        .map_err(|e| e.to_string())?
        .ip()
        .to_string();
    let request = build_control_datagram(
        MESG_CHECKLOLASTATUS,
        &local,
        &peer.ip().to_string(),
        sid,
        None,
        "",
    )
    .map_err(|e| e.to_string())?;
    socket.send_to(&request, peer).map_err(|e| e.to_string())?;
    let started = Instant::now();
    let mut buffer = [0_u8; 1025];
    let (mut malformed, mut wrong_peer, mut unexpected) = (0_u64, 0_u64, 0_u64);
    let mut accepted = false;
    while started.elapsed().as_secs_f64() < timeout {
        match socket.recv_from(&mut buffer) {
            Ok((_, sender)) if sender != peer.into() => wrong_peer += 1,
            Ok((length, _)) => match decode_mesg(&buffer[..length]) {
                Err(_) => malformed += 1,
                Ok(message) => {
                    if message.fields.get("SRCIP") != Some(&peer.ip().to_string())
                        || message.fields.get("DSTIP") != Some(&local)
                        || message.fields.get("SID") != Some(&sid.to_string())
                    {
                        wrong_peer += 1;
                    } else if message.name == "/MESG_CHECKLOLASTATUS_ACK" {
                        accepted = true;
                        break;
                    } else {
                        unexpected += 1;
                    }
                }
            },
            Err(error) if error.kind() == std::io::ErrorKind::WouldBlock => {
                std::thread::sleep(Duration::from_millis(1))
            }
            Err(error) => return Err(error.to_string()),
        }
    }
    Ok(
        json!({"ok":accepted,"control_reachable":accepted,"negotiated":false,"media_validated":false,"rtt_ms":if accepted {Some(started.elapsed().as_secs_f64()*1000.0)} else {None},"malformed_drops":malformed,"wrong_peer_drops":wrong_peer,"unexpected_drops":unexpected,"reason":if accepted {"LoLa status acknowledged"} else {"LoLa status timeout"}}),
    )
}

pub(super) fn selftest(duration: f64) -> Result<Value, String> {
    if !duration.is_finite() || !(0.01..=60.0).contains(&duration) {
        return Err("selftest duration must be 0.01..=60 seconds".into());
    }
    let mut settings = default_settings();
    settings.video.width = 64;
    settings.video.height = 48;
    settings.video.fps = 30;
    settings.video.bpp = 24;
    settings.video.bayer = 0;
    settings.network.bind_ip = "127.0.0.1".into();
    let mut options = SessionOptions::demo();
    options.use_catalog_geometry = false;
    options.interleaved_av = true;
    options.duration_sec = Some(duration);
    options.stream_frames = 1;
    let result = run_session(settings, 2.0, options);
    let mut report = result.to_json();
    report["ok"] = json!(
        result.ok
            && result.audio_frames_received > 0
            && result.audio_frames_sent > 0
            && result.video_frames_received > 0
            && result.video_frames_sent > 0
    );
    report["evidence"] = json!("synthetic localhost UDP; no hardware or reference-peer validation");
    report["port_policy"] = json!("OS-assigned ephemeral ports for isolated concurrent selftests");
    Ok(report)
}

/// Probe JSON plus, when PortAudio loads, one entry per device (ASIO devices flagged).
fn portaudio_inventory() -> Value {
    let probe = crate::audio::probe_portaudio();
    let mut report = probe.to_json();
    if probe.available {
        match crate::audio::load_portaudio(None).and_then(|library| library.devices()) {
            Ok(devices) => {
                report["devices"] = devices.iter().map(|d| d.to_json()).collect();
            }
            Err(error) => report["devices_error"] = json!(error),
        }
    }
    report
}

pub(super) fn devices() -> Result<Value, String> {
    let audio = match crate::audio::alsa::inventory_alsa_devices() {
        Ok(devices) => json!({"backend":"alsa", "devices": devices}),
        Err(error) => json!({"backend":"alsa", "devices":[], "error":error.to_string()}),
    };
    let video = match crate::video::v4l2::V4l2Camera::inventory() {
        Ok(devices) => json!({"backend":"v4l2", "devices":devices}),
        Err(error) => json!({"backend":"v4l2", "devices":[], "error":error.to_string()}),
    };
    Ok(json!({"audio": audio,"video":video,
        "portaudio":portaudio_inventory(),
        "ximea":crate::video::probe_ximea().to_json(),
        "mediafoundation":crate::video::mediafoundation::inventory_json(),
        "evidence":"device inventory; stream format and readiness are not yet verified"}))
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn status_counts_invalid_traffic_then_accepts_ack() {
        let peer = UdpSocket::bind("127.0.0.1:0").unwrap();
        peer.set_read_timeout(Some(Duration::from_secs(1))).unwrap();
        let address = match peer.local_addr().unwrap() {
            std::net::SocketAddr::V4(value) => value,
            _ => unreachable!(),
        };
        let thread = std::thread::spawn(move || {
            let mut buffer = [0; 1024];
            let (_, client) = peer.recv_from(&mut buffer).unwrap();
            peer.send_to(b"malformed", client).unwrap();
            let ack = build_control_datagram(
                "MESG_CHECKLOLASTATUS_ACK",
                "127.0.0.1",
                "127.0.0.1",
                1,
                None,
                "",
            )
            .unwrap();
            peer.send_to(&ack, client).unwrap();
        });
        let socket = UdpSocket::bind("127.0.0.1:0").unwrap();
        let result = status_on_socket(&socket, address, 1, 1.0).unwrap();
        thread.join().unwrap();
        assert_eq!(result["ok"], true);
        assert_eq!(result["malformed_drops"], 1);
        assert_eq!(result["negotiated"], false);
    }
    #[test]
    fn probe_binds_the_control_port_or_falls_back_with_a_note() {
        let loopback = Ipv4Addr::LOCALHOST;
        let free = UdpSocket::bind((loopback, 0)).unwrap();
        let port = free.local_addr().unwrap().port();
        drop(free);
        let (bound, note) = bind_probe_socket(loopback, port).unwrap();
        assert_eq!(bound.local_addr().unwrap().port(), port);
        assert!(note.is_none());
        let (fallback, note) = bind_probe_socket(loopback, port).unwrap();
        assert_ne!(fallback.local_addr().unwrap().port(), port);
        let note = note.expect("busy port explains the fallback");
        assert!(note.contains(&format!("control port {port}")), "{note}");
        assert!(note.contains("ephemeral"), "{note}");
    }
    #[test]
    fn repeated_selftest_has_bidirectional_media_and_bounded_duration() {
        for _ in 0..2 {
            let started = Instant::now();
            let report = selftest(0.05).unwrap();
            assert_eq!(report["ok"], true, "{report}");
            assert_eq!(
                report["network_monitor"]["video_sent"], report["video_frames_sent"],
                "monitor counts video frames rather than fragments"
            );
            assert!(started.elapsed() < Duration::from_secs(5));
        }
        for duration in [0.0, -1.0, f64::NAN, f64::INFINITY, 61.0] {
            assert!(selftest(duration).is_err());
        }
    }
}
