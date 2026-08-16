//! Optional cross-process checks against the sibling Python connector.

use rusty_lola::config::{default_settings, AudioBackend, VideoBackend};
use rusty_lola::station::{run_session, SessionOptions};
use std::net::UdpSocket;
use std::path::PathBuf;
use std::process::{Child, Command, Output, Stdio};
use std::sync::{Mutex, OnceLock};
use std::thread;
use std::time::{Duration, Instant};

fn connector_root() -> Option<PathBuf> {
    let configured = PathBuf::from(std::env::var_os("TUX_LOLA_ROOT")?);
    [configured.clone(), configured.join("linux_connector")]
        .into_iter()
        .find(|candidate| candidate.join("lola_connector/cli.py").is_file())
}

fn cross_process_lock() -> &'static Mutex<()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    LOCK.get_or_init(|| Mutex::new(()))
}

fn secondary_local_ip() -> String {
    std::env::var("RUSTY_LOLA_TEST_PEER_IP").unwrap_or_else(|_| "127.0.0.2".into())
}

fn secondary_address_available(ip: &str) -> bool {
    UdpSocket::bind((ip, 0)).is_ok()
}

fn wait_until_udp_bound(address: &str, timeout: Duration) {
    let deadline = Instant::now() + timeout;
    while Instant::now() < deadline {
        if UdpSocket::bind(address).is_err() {
            return;
        }
        thread::sleep(Duration::from_millis(20));
    }
    panic!("timed out waiting for UDP listener on {address}");
}

fn python_command(root: &PathBuf) -> Command {
    let python = std::env::var_os("PYTHON").unwrap_or_else(|| "python3".into());
    let mut command = Command::new(python);
    command.current_dir(root).env("PYTHONPATH", root);
    command
}

fn wait_child(mut child: Child, timeout: Duration) -> Output {
    let deadline = Instant::now() + timeout;
    while Instant::now() < deadline {
        if child.try_wait().expect("poll Python child").is_some() {
            return child.wait_with_output().expect("collect Python output");
        }
        thread::sleep(Duration::from_millis(20));
    }
    let _ = child.kill();
    child
        .wait_with_output()
        .expect("collect timed-out Python output")
}

fn rust_settings(local: &str, remote: &str) -> rusty_lola::config::StationSettings {
    let mut settings = default_settings();
    settings.network.bind_ip = local.into();
    settings.network.local_ip = local.into();
    settings.network.remote_ip = remote.into();
    settings.audio.backend = AudioBackend::Diagnostic;
    settings.video.backend = VideoBackend::Diagnostic;
    settings.video.width = 64;
    settings.video.height = 48;
    settings.video.fps = 25;
    settings
}

fn rust_options(mode: &str) -> SessionOptions {
    let mut options = SessionOptions::demo();
    options.peer_mode = mode.into();
    options.stream_frames = 4;
    options.duration_sec = Some(0.35);
    options.interleaved_av = true;
    options.control_extras = false;
    options.use_catalog_geometry = false;
    options.camera_backend = VideoBackend::Diagnostic;
    options.audio_backend = AudioBackend::Diagnostic;
    options.test_signal_mode = "send".into();
    options
}

#[test]
#[ignore = "requires TUX_LOLA_ROOT and a distinct local RUSTY_LOLA_TEST_PEER_IP"]
fn rust_initiator_python_listener_bidirectional_media() {
    let _guard = cross_process_lock()
        .lock()
        .unwrap_or_else(|error| error.into_inner());
    let root = connector_root().expect("TUX_LOLA_ROOT must point at the Python connector");
    let peer_ip = secondary_local_ip();
    assert!(
        secondary_address_available(&peer_ip),
        "{peer_ip} must be a configured local address for isolated fixed-port tests"
    );
    let control_address = format!("{peer_ip}:7000");
    let child = python_command(&root)
        .args([
            "-m",
            "lola_connector.cli",
            "--local-ip",
            &peer_ip,
            "--width",
            "64",
            "--height",
            "48",
            "--fps",
            "25",
            "listen",
            "--rx",
            "--test-media",
            "diagnostic",
            "--duration",
            "0.8",
        ])
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .expect("launch Python listener");
    wait_until_udp_bound(&control_address, Duration::from_secs(2));

    let result = run_session(
        rust_settings("127.0.0.1", &peer_ip),
        4.0,
        rust_options("remote"),
    );
    let output = wait_child(child, Duration::from_secs(5));
    assert!(
        result.ok,
        "Rust initiator failed: {result:?}; Python stdout={} stderr={}",
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    assert!(result.audio_frames_received > 0);
    assert!(result.video_frames_received > 0);
    assert!(
        output.status.success(),
        "Python listener failed during disconnect cleanup: {}",
        String::from_utf8_lossy(&output.stderr)
    );
}

#[test]
#[ignore = "requires TUX_LOLA_ROOT and a distinct local RUSTY_LOLA_TEST_PEER_IP"]
fn python_initiator_rust_listener_bidirectional_media() {
    let _guard = cross_process_lock()
        .lock()
        .unwrap_or_else(|error| error.into_inner());
    let root = connector_root().expect("TUX_LOLA_ROOT must point at the Python connector");
    let peer_ip = secondary_local_ip();
    assert!(
        secondary_address_available(&peer_ip),
        "{peer_ip} must be a configured local address for isolated fixed-port tests"
    );
    let listener_peer_ip = peer_ip.clone();
    let listener = thread::spawn(move || {
        run_session(
            rust_settings("127.0.0.1", &listener_peer_ip),
            4.0,
            rust_options("listen"),
        )
    });
    wait_until_udp_bound("127.0.0.1:7000", Duration::from_secs(2));
    let child = python_command(&root)
        .args([
            "-m",
            "lola_connector.cli",
            "--local-ip",
            &peer_ip,
            "--width",
            "64",
            "--height",
            "48",
            "--fps",
            "25",
            "connect",
            "127.0.0.1",
            "--sid",
            "1",
            "--rx",
            "--test-media",
            "diagnostic",
            "--duration",
            "0.8",
        ])
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .expect("launch Python initiator");
    let output = wait_child(child, Duration::from_secs(5));
    let result = listener.join().expect("Rust listener thread");
    assert!(
        result.ok,
        "Rust listener failed: {}; Python stdout={} stderr={}",
        result.error,
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    assert!(
        result.audio_frames_received > 0,
        "listener counters: {result:?}"
    );
    assert!(
        result.video_frames_received > 0,
        "listener counters: {result:?}"
    );
    assert!(
        output.status.success(),
        "Python initiator failed: {}",
        String::from_utf8_lossy(&output.stderr)
    );
}
