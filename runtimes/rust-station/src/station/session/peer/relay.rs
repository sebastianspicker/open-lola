mod polling;
use super::super::media::{
    recv_media, send_audio_media, send_video_media, should_stream_more, SessionMediaTransport,
};
use super::super::{SessionOptions, SessionResult};
use super::{pump_peer_control, PeerNegotiation, PeerPorts, QuickconnAckCache};
use crate::config::StationSettings;
use crate::net::Udp;
use crate::protocol::{
    parse_audio_frame, parse_video_frame, AudioDatagramWriter, FrameReassembler,
};
use crate::station::sync::lock_unpoison;
use crate::station::SessionError;
use std::net::SocketAddr;
use std::sync::{Arc, Mutex};
use std::time::Instant;

#[allow(clippy::too_many_arguments)]
pub(super) fn run_peer_relay(
    settings: &StationSettings,
    options: &SessionOptions,
    shared: &Arc<Mutex<SessionResult>>,
    control_socket: &Udp,
    negotiation: PeerNegotiation,
    ports: PeerPorts,
    packet_size: usize,
    n_frames: u32,
    media_transport: &mut SessionMediaTransport,
) -> Result<(), SessionError> {
    let mut video_reassembler = FrameReassembler::strict_video();
    let mut audio_reassembler =
        FrameReassembler::with_limit(settings.network.audio_receive_queue_depth.max(1) as usize);
    let expected_video_peer = expected_peer(options, negotiation.addr, ports.video);
    let expected_audio_peer = expected_peer(options, negotiation.addr, ports.audio);
    let started = Instant::now();
    let relay = PeerRelay {
        settings,
        options,
        shared,
        control_socket,
        ack: &negotiation.ack,
        peer: negotiation.addr,
        packet_size,
        video_compressed: negotiation.ack_media.compression == 1,
        expected_video_peer,
        expected_audio_peer,
    };
    let primary = if options.interleaved_av {
        relay_interleaved(
            &relay,
            media_transport,
            &mut audio_reassembler,
            &mut video_reassembler,
            n_frames,
            started,
        )
    } else {
        relay_sequential(
            &relay,
            media_transport,
            &mut audio_reassembler,
            &mut video_reassembler,
            n_frames,
            started,
        )
    };
    let cleanup = media_transport.shutdown();
    record_final_transport_stats(relay.shared, media_transport);
    record_transport_cleanup_error(relay.shared, &cleanup);
    primary.and(cleanup)
}

fn record_final_transport_stats(
    shared: &Arc<Mutex<SessionResult>>,
    media_transport: &SessionMediaTransport,
) {
    let mut result = lock_unpoison(shared);
    super::super::lifecycle::record_cached_transport_stats(&mut result, media_transport.stats());
}

fn record_transport_cleanup_error(
    shared: &Arc<Mutex<SessionResult>>,
    cleanup: &Result<(), SessionError>,
) {
    if let Err(error) = cleanup {
        lock_unpoison(shared)
            .cleanup_warnings
            .push(format!("media transport: {error}"));
    }
}

struct PeerRelay<'a> {
    settings: &'a StationSettings,
    options: &'a SessionOptions,
    shared: &'a Arc<Mutex<SessionResult>>,
    control_socket: &'a Udp,
    ack: &'a QuickconnAckCache,
    peer: SocketAddr,
    packet_size: usize,
    video_compressed: bool,
    expected_video_peer: Option<SocketAddr>,
    expected_audio_peer: Option<SocketAddr>,
}

fn expected_peer(options: &SessionOptions, peer: SocketAddr, port: u16) -> Option<SocketAddr> {
    (!options.peer_mode.eq_ignore_ascii_case("loopback")).then(|| SocketAddr::new(peer.ip(), port))
}

fn relay_interleaved(
    relay: &PeerRelay<'_>,
    media_transport: &mut SessionMediaTransport,
    _audio_reassembler: &mut FrameReassembler,
    video_reassembler: &mut FrameReassembler,
    n_frames: u32,
    started: Instant,
) -> Result<(), SessionError> {
    polling::run(relay, media_transport, video_reassembler, n_frames, started)
}

fn relay_sequential(
    relay: &PeerRelay<'_>,
    media_transport: &mut SessionMediaTransport,
    audio_reassembler: &mut FrameReassembler,
    video_reassembler: &mut FrameReassembler,
    n_frames: u32,
    started: Instant,
) -> Result<(), SessionError> {
    let planned = relay_video_enabled(relay.options)
        .then(|| relay_video_phase(relay, media_transport, video_reassembler, n_frames, started))
        .transpose()?
        .unwrap_or(n_frames);
    if relay_audio_enabled(relay.options) {
        relay_audio_phase(relay, media_transport, audio_reassembler, planned)?;
    }
    Ok(())
}

fn relay_video_phase(
    relay: &PeerRelay<'_>,
    media_transport: &mut SessionMediaTransport,
    reassembler: &mut FrameReassembler,
    n_frames: u32,
    started: Instant,
) -> Result<u32, SessionError> {
    let mut frame_index = 0;
    while should_stream_more(
        frame_index,
        n_frames,
        started,
        relay.options.duration_sec,
        relay.options,
    ) {
        if relay_control_disconnect(relay)? {
            return Ok(frame_index.max(n_frames));
        }
        relay_video_frame(relay, media_transport, reassembler)?;
        frame_index += 1;
    }
    Ok(frame_index.max(n_frames))
}

fn relay_audio_phase(
    relay: &PeerRelay<'_>,
    media_transport: &mut SessionMediaTransport,
    reassembler: &mut FrameReassembler,
    planned: u32,
) -> Result<(), SessionError> {
    let mut audio_writer = AudioDatagramWriter::new();
    for _ in 0..planned {
        if relay_control_disconnect(relay)? {
            return Ok(());
        }
        relay_audio_frame(relay, media_transport, reassembler, &mut audio_writer)?;
    }
    Ok(())
}

fn relay_control_disconnect(relay: &PeerRelay<'_>) -> Result<bool, SessionError> {
    pump_peer_control(
        relay.control_socket,
        relay.ack,
        relay.peer,
        relay.settings,
        relay.options,
        relay.shared,
    )
}

fn relay_audio_enabled(options: &SessionOptions) -> bool {
    options.stream_tx_audio || options.stream_rx_audio
}

fn relay_video_enabled(options: &SessionOptions) -> bool {
    (options.stream_tx_video || options.stream_rx_video) && !options.audio_only
}

fn relay_audio_frame(
    relay: &PeerRelay<'_>,
    media_transport: &mut SessionMediaTransport,
    reassembler: &mut FrameReassembler,
    audio_writer: &mut AudioDatagramWriter,
) -> Result<(), SessionError> {
    let mut control_pump = || relay_control_disconnect(relay);
    let mut malformed = 0;
    let received = recv_media(
        media_transport,
        reassembler,
        relay.expected_audio_peer,
        true,
        0.0,
        relay.options.runtime_control.as_ref(),
        Some(&mut control_pump),
        &mut malformed,
    );
    lock_unpoison(relay.shared).audio_malformed_drops += malformed;
    let (frame, destination) = received?;
    let frame = match parse_audio_frame(&frame) {
        Ok(frame) => frame,
        Err(_) => {
            lock_unpoison(relay.shared).audio_malformed_drops += 1;
            return Ok(());
        }
    };
    send_audio_media(
        media_transport,
        frame.sequence,
        &frame.pcm,
        destination,
        audio_writer,
    )?;
    increment_audio_counters(relay.shared);
    Ok(())
}

fn relay_video_frame(
    relay: &PeerRelay<'_>,
    media_transport: &mut SessionMediaTransport,
    reassembler: &mut FrameReassembler,
) -> Result<(), SessionError> {
    let mut control_pump = || relay_control_disconnect(relay);
    let mut malformed = 0;
    let received = recv_media(
        media_transport,
        reassembler,
        relay.expected_video_peer,
        false,
        relay.options.incomplete_frame_threshold_pct,
        relay.options.runtime_control.as_ref(),
        Some(&mut control_pump),
        &mut malformed,
    );
    lock_unpoison(relay.shared).video_malformed_drops += malformed;
    let (frame, destination) = received?;
    let frame = match parse_video_frame(&frame, relay.video_compressed) {
        Ok(frame) => frame,
        Err(_) => {
            lock_unpoison(relay.shared).video_malformed_drops += 1;
            return Ok(());
        }
    };
    send_video_media(media_transport, &frame, destination, relay.packet_size)?;
    increment_video_counters(relay.shared);
    Ok(())
}

fn increment_audio_counters(shared: &Arc<Mutex<SessionResult>>) {
    let mut result = lock_unpoison(shared);
    result.audio_frames_received += 1;
    result.audio_frames_sent += 1;
    result.media_frames_received += 1;
    result.media_frames_sent += 1;
}

fn increment_video_counters(shared: &Arc<Mutex<SessionResult>>) {
    let mut result = lock_unpoison(shared);
    result.video_frames_received += 1;
    result.video_frames_sent += 1;
    result.media_frames_received += 1;
    result.media_frames_sent += 1;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn relay_shutdown_failure_remains_in_cleanup_warnings() {
        let shared = Arc::new(Mutex::new(SessionResult::default()));
        let cleanup = Err(SessionError::Cleanup("final statistics unavailable".into()));

        record_transport_cleanup_error(&shared, &cleanup);

        assert_eq!(
            lock_unpoison(&shared).cleanup_warnings,
            ["media transport: cleanup failed: final statistics unavailable"]
        );
    }
}
