use super::backends::SessionAudioBackend;
use super::media::{send_audio_media, ReceivePrefillQueue, SessionMediaTransport};
use super::{SessionOptions, SessionResult};
use crate::audio::{generate_pcm_tone, test_tone_frequency, TEST_TONE_AMPLITUDE};
use crate::net::MediaKind;
use crate::protocol::{parse_audio_frame, AudioFrame, FrameReassembler, AUDIO_UDP_PAYLOAD_SIZE};
use crate::station::av_productivity::{apply_tx_audio_level, incomplete_frame_ok};
use crate::station::dual_recorder::DualStreamRecorder;
use crate::station::monitor::NetworkMonitor;
use crate::station::SessionError;
use std::net::SocketAddr;

#[allow(clippy::too_many_arguments)]
pub(super) fn send_recv_audio_frame(
    audio: &mut SessionAudioBackend,
    media_transport: &mut SessionMediaTransport,
    peer_audio_addr: SocketAddr,
    a_re: &mut FrameReassembler,
    packet_size: usize,
    channels: u16,
    sample_rate: u32,
    bits_per_sample: u16,
    options: &SessionOptions,
    transmit: bool,
    receive: bool,
    _sid: u32,
    frame_i: u32,
    _t0: u64,
    result: &mut SessionResult,
    dual: &mut Option<DualStreamRecorder>,
    monitor: &mut NetworkMonitor,
    receive_queue: &mut ReceivePrefillQueue<Vec<u8>>,
) -> Result<(), SessionError> {
    if transmit {
        // Test-signal TX: 689/750 Hz @ −12 dBFS (manual §4.12) when mode is send/both.
        let mut pcm = if options.test_signal_send() {
            let n = audio.buffer_samples().max(1);
            let freq = test_tone_frequency(frame_i);
            let tone = generate_pcm_tone(
                channels,
                sample_rate,
                bits_per_sample,
                n,
                freq,
                TEST_TONE_AMPLITUDE,
                frame_i.wrapping_mul(n),
            );
            result.test_signal_applied = true;
            result.test_signal_mode = options.test_signal_mode.clone();
            result.audio_signal_active = Some(true);
            tone
        } else {
            audio.read_pcm()?
        };
        if options.tx_audio_level > 1 {
            pcm = apply_tx_audio_level(&pcm, f64::from(options.tx_audio_level), bits_per_sample);
        }
        if let Some(rec) = dual.as_mut() {
            rec.write_audio("local", &pcm);
        }
        let frame = AudioFrame {
            sequence: frame_i + 1,
            pcm,
        };
        let _ = packet_size;
        send_audio_media(media_transport, &frame, peer_audio_addr)?;
        result.audio_frames_sent += 1;
        result.media_frames_sent += 1;
        monitor.note_send(MediaKind::Audio);
    }
    // The audio transport contract is one strict 1066-byte datagram per
    // quantum. Do not wait for fragments here: blocking would steal the next
    // backend-clock audio deadline.
    let _ = incomplete_frame_ok(1, 1, options.incomplete_frame_threshold_pct);
    if receive {
        receive_audio_datagram_step(
            audio,
            media_transport,
            peer_audio_addr,
            a_re,
            result,
            dual,
            monitor,
            receive_queue,
        )?;
    }
    if let Some(control) = options.runtime_control.as_ref() {
        control.set_activity(result);
    }
    Ok(())
}

/// Consume at most one transport receive and at most one completed audio
/// frame. This is intentionally separate from `recv_media`, whose retry loop
/// remains for the explicitly diagnostic sequential path.
#[allow(clippy::too_many_arguments)]
pub(super) fn receive_audio_datagram_step(
    audio: &mut SessionAudioBackend,
    media_transport: &mut SessionMediaTransport,
    peer_audio_addr: SocketAddr,
    a_re: &mut FrameReassembler,
    result: &mut SessionResult,
    dual: &mut Option<DualStreamRecorder>,
    monitor: &mut NetworkMonitor,
    receive_queue: &mut ReceivePrefillQueue<Vec<u8>>,
) -> Result<(), SessionError> {
    let Some(datagram) = media_transport.receive_kind(MediaKind::Audio)? else {
        return Ok(());
    };
    if datagram.peer != peer_audio_addr || datagram.payload.len() != AUDIO_UDP_PAYLOAD_SIZE {
        return Ok(());
    }
    let Some(echo) = a_re
        .feed(&datagram.payload)
        .map_err(|error| SessionError::Protocol(error.to_string()))?
    else {
        return Ok(());
    };
    let frame = parse_audio_frame(&echo).map_err(|e| SessionError::Protocol(e.to_string()))?;
    result.audio_frames_received += 1;
    result.media_frames_received += 1;
    monitor.note_recv(MediaKind::Audio, Some(frame.sequence));
    let (playback, replaced) = receive_queue.push(frame.pcm);
    if replaced {
        monitor.note_drop(1);
    }
    if let Some(playback) = playback {
        audio.play_pcm(&playback)?;
        if let Some(rec) = dual.as_mut() {
            rec.write_audio("remote", &playback);
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::config::default_settings;
    use std::net::{IpAddr, Ipv4Addr};
    use std::time::{Duration, Instant};

    #[test]
    fn audio_receive_step_returns_after_one_empty_transport_poll() {
        let settings = default_settings();
        let receiver = crate::net::Udp::bind("127.0.0.1", 0).unwrap();
        receiver.set_timeout(0.001).unwrap();
        let video = crate::net::Udp::bind("127.0.0.1", 0).unwrap();

        let mut transport = SessionMediaTransport::diagnostic_udp(receiver, video);
        let mut audio = SessionAudioBackend::open(&settings, &SessionOptions::demo()).unwrap();
        let mut reassembler = FrameReassembler::with_limit(1);
        let mut result = SessionResult::default();
        let mut dual = None;
        let mut monitor = NetworkMonitor::new();
        let mut queue = ReceivePrefillQueue::new(1, 0);
        let started = Instant::now();
        receive_audio_datagram_step(
            &mut audio,
            &mut transport,
            SocketAddr::new(IpAddr::V4(Ipv4Addr::LOCALHOST), 9),
            &mut reassembler,
            &mut result,
            &mut dual,
            &mut monitor,
            &mut queue,
        )
        .unwrap();
        assert!(started.elapsed() < Duration::from_millis(100));
        assert_eq!(transport.stats().received_datagrams, 0);
        assert_eq!(result.audio_frames_received, 0);
        audio.stop().unwrap();
    }
}
