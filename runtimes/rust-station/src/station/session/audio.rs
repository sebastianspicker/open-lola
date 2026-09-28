use super::backends::SessionAudioBackend;
use super::media::{send_audio_media, ReceivePrefillQueue, SessionMediaTransport};
use super::{SessionOptions, SessionResult};
use crate::audio::{generate_pcm_tone, test_tone_frequency, TEST_TONE_AMPLITUDE};
use crate::net::MediaKind;
use crate::protocol::{
    parse_audio_datagram, AudioDatagramWriter, FrameReassembler, AUDIO_UDP_PAYLOAD_SIZE,
};
use crate::station::av_productivity::{apply_tx_audio_level, incomplete_frame_ok};
use crate::station::monitor::NetworkMonitor;
use crate::station::recording_worker::SessionRecorder as DualStreamRecorder;
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
    audio_writer: &mut AudioDatagramWriter,
) -> Result<(), SessionError> {
    if transmit {
        // Test-signal TX: 689/750 Hz @ −12 dBFS (manual §4.12) when mode is send/both.
        let generated_pcm;
        let pcm = if options.test_signal_send() {
            let n = audio.buffer_samples().max(1);
            let freq = test_tone_frequency(frame_i);
            generated_pcm = generate_pcm_tone(
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
            generated_pcm.as_slice()
        } else {
            audio.read_pcm()?
        };
        if !pcm.is_empty() {
            let leveled_pcm;
            let pcm = if options.tx_audio_level > 1 {
                leveled_pcm =
                    apply_tx_audio_level(pcm, f64::from(options.tx_audio_level), bits_per_sample);
                leveled_pcm.as_slice()
            } else {
                pcm
            };
            if let Some(rec) = dual.as_mut() {
                rec.write_audio("local", pcm);
            }
            let _ = packet_size;
            send_audio_media(
                media_transport,
                frame_i + 1,
                pcm,
                peer_audio_addr,
                audio_writer,
            )?;
            result.audio_frames_sent += 1;
            result.media_frames_sent += 1;
            monitor.note_send(MediaKind::Audio);
        }
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
        result.audio_malformed_drops += 1;
        monitor.note_drop(1);
        return Ok(());
    }
    let _ = a_re;
    let frame = match parse_audio_datagram(&datagram.payload) {
        Ok(frame) => frame,
        Err(_) => {
            result.audio_malformed_drops += 1;
            monitor.note_drop(1);
            return Ok(());
        }
    };
    if !receive_queue.admit_sequence(frame.sequence) {
        monitor.note_drop(1);
        return Ok(());
    }
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
