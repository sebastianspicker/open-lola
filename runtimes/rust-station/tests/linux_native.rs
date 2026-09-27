//! Opt-in native API integration on Linux virtual or physical devices.
//! Set explicit device environment variables; no device is chosen implicitly.
#![cfg(target_os = "linux")]
use rusty_lola::audio::alsa::{AlsaAudio, AlsaConfig};
use rusty_lola::video::v4l2::{V4l2Camera, V4l2Config};
use std::time::{Duration, Instant};

#[test]
#[ignore = "requires explicitly configured ALSA loopback or physical duplex devices"]
fn alsa_duplex_device_reads_and_cancels() {
    let mut audio = AlsaAudio::open(AlsaConfig {
        capture_device: std::env::var("OPEN_LOLA_ALSA_CAPTURE").expect("set capture hw identifier"),
        playback_device: std::env::var("OPEN_LOLA_ALSA_PLAYBACK")
            .expect("set playback hw identifier"),
        capture_enabled: true,
        playback_enabled: true,
        sample_rate: 44100,
        channels: 2,
        bits_per_sample: 16,
        frames_per_buffer: 64,
    })
    .unwrap();
    audio.start().unwrap();
    let mut pcm = Vec::with_capacity(256);
    let deadline = Instant::now() + Duration::from_secs(2);
    while pcm.is_empty() && Instant::now() < deadline {
        audio.write_pcm(&[0; 256]).unwrap();
        audio.read_pcm_into(&mut pcm).unwrap();
    }
    assert_eq!(
        pcm.len(),
        256,
        "capture did not produce one exact native period"
    );
    let start = Instant::now();
    audio.cancellation().cancel();
    assert!(audio.read_pcm_into(&mut pcm).is_err());
    audio.stop().unwrap();
    assert!(start.elapsed() < Duration::from_millis(250));
}

#[test]
#[ignore = "requires explicitly configured V4L2 loopback or physical camera"]
fn v4l2_exact_mode_captures_and_cancels() {
    let mut camera = V4l2Camera::open(V4l2Config {
        device: std::env::var("OPEN_LOLA_V4L2_DEVICE").expect("set video device node"),
        width: 640,
        height: 480,
        fps: 30,
        pixel_format: "YUYV".into(),
    })
    .unwrap();
    camera.start().unwrap();
    let (pixels, format) = camera.grab().unwrap();
    assert_eq!(format, "RGB24");
    assert_eq!(pixels.len(), 640 * 480 * 3);
    let start = Instant::now();
    camera.cancellation_handle().cancel();
    assert!(camera.grab().is_err());
    camera.stop().unwrap();
    assert!(start.elapsed() < Duration::from_millis(250));
}
