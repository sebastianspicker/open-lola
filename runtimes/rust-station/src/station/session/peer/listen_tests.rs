//! Listener sessions driven by a scripted peer over loopback sockets.
//!
//! The listener pins the peer's control source port to the configured control
//! port and, on the media path, to the configured peer ports, so the scripted
//! peer's real ports are written into the settings.
use super::super::control::protocol_media_settings;
use super::super::runner::{finish_listener_outcome, merge_listener_result};
use super::super::SessionRuntimeControl;
use super::*;
use crate::protocol::{
    build_audio_payload, build_video_payloads, FrameReassembler, MediaSettings,
    MESG_CHECKLOLASTATUS, MESG_DISCONNECT, MESG_QUICKCONN,
};
use std::net::UdpSocket;
use std::thread;

const LOOPBACK: &str = "127.0.0.1";
/// How long the listen-test peer exchanges audio and video with the listener.
const MEDIA_WINDOW: Duration = Duration::from_secs(2);

struct ScriptedPeer {
    control: UdpSocket,
    audio: UdpSocket,
    video: UdpSocket,
}

impl ScriptedPeer {
    fn bind() -> Self {
        let socket = || {
            let socket = UdpSocket::bind((LOOPBACK, 0)).unwrap();
            socket
                .set_read_timeout(Some(Duration::from_millis(200)))
                .unwrap();
            socket
        };
        Self {
            control: socket(),
            audio: socket(),
            video: socket(),
        }
    }

    fn port(socket: &UdpSocket) -> u16 {
        socket.local_addr().unwrap().port()
    }

    fn settings(&self) -> StationSettings {
        let mut settings = crate::config::default_settings();
        settings.network.bind_ip = LOOPBACK.into();
        settings.network.local_ip = LOOPBACK.into();
        settings.network.remote_ip = LOOPBACK.into();
        settings.network.control_port = Self::port(&self.control);
        settings.network.audio_port = Self::port(&self.audio);
        settings.network.video_port = Self::port(&self.video);
        // The Mono8 tuple the macOS connector offers.
        settings.video.bayer = 0;
        settings
    }

    fn control_datagram(
        settings: &StationSettings,
        kind: &str,
        media: Option<&MediaSettings>,
    ) -> Vec<u8> {
        build_session_control(
            settings,
            kind,
            &settings.network.remote_ip,
            &settings.network.local_ip,
            "",
            media,
        )
        .unwrap()
    }

    /// Resends `datagram` until the listener answers with `reply`.
    fn exchange(&self, listener: SocketAddr, datagram: &[u8], reply: &str) {
        let deadline = Instant::now() + Duration::from_secs(5);
        let mut buffer = [0_u8; 2048];
        while Instant::now() < deadline {
            self.control.send_to(datagram, listener).unwrap();
            while let Ok((size, _)) = self.control.recv_from(&mut buffer) {
                if decode_mesg(&buffer[..size]).is_ok_and(|message| message.name == reply) {
                    return;
                }
            }
        }
        panic!("no {reply} from the listener");
    }

    /// Streams audio and 25 fps video to the listener for `window`, returning
    /// the audio datagrams and complete video frames it sent back.
    fn exchange_media(
        &self,
        window: Duration,
        listener_audio: SocketAddr,
        listener_video: SocketAddr,
    ) -> (u64, u64) {
        let (mut buffer, mut sequence) = ([0_u8; 65_536], 0_u32);
        let mut reassembler = FrameReassembler::strict_video();
        let (mut audio_seen, mut video_seen) = (0, 0);
        self.audio.set_nonblocking(true).unwrap();
        self.video.set_nonblocking(true).unwrap();
        let started = Instant::now();
        while started.elapsed() < window {
            let audio = build_audio_payload(sequence, &[0; 256], None).unwrap();
            self.audio.send_to(&audio, listener_audio).unwrap();
            if sequence % 20 == 0 {
                for datagram in build_video_payloads(sequence, &vec![0x55; 1280 * 720], None, 1400)
                {
                    self.video.send_to(&datagram, listener_video).unwrap();
                }
            }
            sequence += 1;
            while self.audio.recv_from(&mut buffer).is_ok() {
                audio_seen += 1;
            }
            while let Ok((size, _)) = self.video.recv_from(&mut buffer) {
                video_seen += u64::from(matches!(reassembler.feed(&buffer[..size]), Ok(Some(_))));
            }
            thread::sleep(Duration::from_millis(2));
        }
        (audio_seen, video_seen)
    }
}

fn listen_options() -> SessionOptions {
    let mut options = SessionOptions::demo();
    options.peer_mode = "listen".into();
    options.use_catalog_geometry = false;
    options
}

/// A peer that DISCONNECTs inside the control-extras window ends the session
/// normally. The listener used to report `ok: false` with an empty error.
#[test]
fn peer_disconnect_after_negotiation_is_a_clean_end() {
    let peer = ScriptedPeer::bind();
    let settings = peer.settings();
    let mut options = listen_options();
    options.audio_only = true;
    assert!(options.control_extras, "the extras window is the default");
    let (sockets, ports) = PeerSockets::bind_ephemeral(LOOPBACK).unwrap();
    let listener = SocketAddr::new(LOOPBACK.parse().unwrap(), ports.control);
    let shared = Arc::new(Mutex::new(SessionResult::default()));
    let body = {
        let (settings, options, shared) = (settings.clone(), options.clone(), shared.clone());
        thread::spawn(move || {
            peer_session_body_with_sockets(settings, sockets, options, shared, 5.0)
        })
    };
    let media = protocol_media_settings(&settings);
    for (kind, media, reply) in [
        (MESG_CHECKLOLASTATUS, None, "/MESG_CHECKLOLASTATUS_ACK"),
        (MESG_QUICKCONN, Some(&media), "/MESG_QUICKCONN_ACK"),
    ] {
        peer.exchange(
            listener,
            &ScriptedPeer::control_datagram(&settings, kind, media),
            reply,
        );
    }
    let disconnect = ScriptedPeer::control_datagram(&settings, MESG_DISCONNECT, None);
    peer.control.send_to(&disconnect, listener).unwrap();

    let outcome = body.join().unwrap();
    let mut result = SessionResult::default();
    merge_listener_result(&mut result, lock_unpoison(&shared).clone());
    finish_listener_outcome(&mut result, &options, outcome);
    // No media flowed, so the DISCONNECT is a failure with a message, not a clean end.
    assert!(!result.ok, "{result:?}");
    assert_eq!(result.error, "peer disconnected before any media");
    assert!(result.failure.is_some(), "{result:?}");
    assert!(result.peer_disconnected(), "{result:?}");
    assert_eq!(result.states.last().map(String::as_str), Some("IDLE"));
}

fn disconnected_result(frames: u64) -> SessionResult {
    SessionResult {
        messages_received: vec!["/MESG_DISCONNECT".into()],
        audio_frames_received: frames,
        ..Default::default()
    }
}

/// The normal-return path and the `Err(PeerDisconnect)` path agree: a peer DISCONNECT
/// after some media is a clean end, one before any media is a failure with an error.
#[test]
fn both_disconnect_paths_agree_on_whether_media_flowed() {
    let options = listen_options();
    let disconnect = || Err(SessionError::PeerDisconnect("peer disconnected".into()));
    for (frames, ok) in [(0, false), (2, true)] {
        let mut returned = disconnected_result(frames);
        finish_listener_outcome(&mut returned, &options, Ok(()));
        let mut errored = disconnected_result(frames);
        finish_listener_outcome(&mut errored, &options, disconnect());
        for result in [&mut returned, &mut errored] {
            result.ensure_failure_message();
            assert_eq!(result.ok, ok, "{frames} frames: {result:?}");
            assert_eq!(result.error.is_empty(), ok, "{result:?}");
            assert_eq!(result.states.last().map(String::as_str), Some("IDLE"));
        }
        if !ok {
            assert_eq!(returned.error, "peer disconnected before any media");
            assert_eq!(errored.error, returned.error);
        }
    }
}

/// Without a peer DISCONNECT (a watchdog or cancel), partial media is still a failure.
#[test]
fn a_disconnect_error_without_a_peer_disconnect_still_fails_on_partial_media() {
    let mut result = SessionResult {
        audio_frames_received: 2,
        ..Default::default()
    };
    let error = SessionError::PeerDisconnect("peer silent for 6.0s".into());
    finish_listener_outcome(&mut result, &listen_options(), Err(error));
    assert!(
        !result.ok && result.error.contains("peer silent"),
        "{result:?}"
    );
}

/// A listener negotiated at the macOS default 1280x720 Mono8 tuple, receiving
/// video as the connector sends it, must still transmit video and keep audio
/// flowing. Partly sent frames used to be discarded for age, so a frame that
/// took longer than the age limit to leave was never completed; the small
/// packet size makes every frame slow to leave, as on a debug build.
#[test]
fn listener_transmits_video_and_audio_while_receiving_video() {
    let peer = ScriptedPeer::bind();
    let mut settings = peer.settings();
    settings.network.video_packet_size = 256;
    let control = SessionRuntimeControl::default();
    let mut options = listen_options();
    options.persistent = true;
    options.runtime_control = Some(control.clone());
    let sockets = [(); 3].map(|()| Udp::bind(LOOPBACK, 0).unwrap());
    let [control_socket, audio_socket, video_socket] = sockets;
    let listener_audio = audio_socket.local_addr().unwrap();
    let listener_video = video_socket.local_addr().unwrap();
    control_socket.set_timeout(0.001).unwrap();
    audio_socket.set_timeout(0.1).unwrap();
    video_socket.set_timeout(0.1).unwrap();
    let shared = Arc::new(Mutex::new(SessionResult::default()));
    let listen = {
        let (settings, options, shared) = (settings.clone(), options.clone(), shared.clone());
        let peer_addr = |socket: &UdpSocket| {
            SocketAddr::new(LOOPBACK.parse().unwrap(), ScriptedPeer::port(socket))
        };
        let (control_peer, audio_port, video_port) = (
            peer_addr(&peer.control),
            ScriptedPeer::port(&peer.audio),
            ScriptedPeer::port(&peer.video),
        );
        thread::spawn(move || {
            // The production transport pins the peer to this host's own port
            // numbers; one loopback address cannot give the peer those.
            let mut transport = SessionMediaTransport::diagnostic_udp(audio_socket, video_socket);
            listen::run_listen_media(
                &settings,
                &options,
                &shared,
                &control_socket,
                control_peer,
                audio_port,
                video_port,
                settings.network.video_packet_size as usize,
                3,
                &protocol_media_settings(&settings),
                &mut transport,
                None,
            )
        })
    };
    let (peer_audio, peer_video) =
        peer.exchange_media(MEDIA_WINDOW, listener_audio, listener_video);
    control.cancel();
    listen.join().unwrap().unwrap();

    let result = lock_unpoison(&shared).clone();
    let audio_period =
        f64::from(settings.audio.buffer_samples) / f64::from(settings.audio.sample_rate);
    let nominal_audio = (MEDIA_WINDOW.as_secs_f64() / audio_period) as u64;
    assert!(result.video_frames_sent >= 1, "video starved: {result:?}");
    assert!(peer_video >= 1, "the peer saw no complete video frame");
    assert!(result.video_frames_received >= 3, "{result:?}");
    // Video work shares the thread with audio: keep a fair share, not the full rate.
    let floor = nominal_audio / 8;
    assert!(
        result.audio_frames_sent >= floor && peer_audio >= floor,
        "audio starved: sent {} seen {peer_audio} floor {floor}: {result:?}",
        result.audio_frames_sent
    );
}
