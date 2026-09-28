//! Bounded diagnostic relay quanta preserve audio service during video assembly.
use super::*;
use crate::net::MediaKind;
use crate::protocol::{parse_audio_datagram, StreamingVideoFragments};
use crate::station::session::scheduler::{PreparedVideoFrame, VideoTxCursor};
use std::time::Duration;

type PendingVideo = (VideoTxCursor, SocketAddr);
const IDLE_LIMIT: Duration = Duration::from_secs(5);
const VIDEO_AGE_LIMIT: Duration = Duration::from_millis(200);

pub(super) fn run(
    relay: &PeerRelay<'_>,
    transport: &mut SessionMediaTransport,
    reassembler: &mut FrameReassembler,
    n_frames: u32,
    started: Instant,
) -> Result<(), SessionError> {
    let mut writer = AudioDatagramWriter::new();
    let (mut audio_frames, mut video_frames) = (0_u32, 0_u32);
    let (mut last_audio, mut last_video) = (started, started);
    let mut pending: Option<PendingVideo> = None;
    loop {
        let progress = match (
            relay_audio_enabled(relay.options),
            relay_video_enabled(relay.options),
        ) {
            (true, true) => audio_frames.min(video_frames),
            (true, false) => audio_frames,
            _ => video_frames,
        };
        if !should_stream_more(
            progress,
            n_frames,
            started,
            relay.options.duration_sec,
            relay.options,
        ) || relay_control_disconnect(relay)?
        {
            if pending.is_some() {
                lock_unpoison(relay.shared).video_deadline_drops += 1;
            }
            break;
        }
        ensure_progress(relay.options, last_audio, last_video, Instant::now())?;
        let audio =
            relay_audio_enabled(relay.options) && poll_audio(relay, transport, &mut writer)?;
        if audio {
            audio_frames += 1;
            last_audio = Instant::now();
        }
        let consumed = relay_video_enabled(relay.options)
            && poll_video(relay, transport, reassembler, &mut pending)?;
        let (sent, complete) = send_video_quantum(relay, transport, &mut pending)?;
        if complete {
            video_frames += 1;
            last_video = Instant::now();
        }
        if !audio && !consumed && !sent {
            std::thread::sleep(Duration::from_micros(50));
        }
    }
    Ok(())
}

fn ensure_progress(
    options: &SessionOptions,
    last_audio: Instant,
    last_video: Instant,
    now: Instant,
) -> Result<(), SessionError> {
    if !options.persistent
        && ((relay_audio_enabled(options) && now.duration_since(last_audio) >= IDLE_LIMIT)
            || (relay_video_enabled(options) && now.duration_since(last_video) >= IDLE_LIMIT))
    {
        return Err(SessionError::Timeout(
            "diagnostic relay stream made no progress for five seconds".into(),
        ));
    }
    Ok(())
}

fn poll_audio(
    relay: &PeerRelay<'_>,
    transport: &mut SessionMediaTransport,
    writer: &mut AudioDatagramWriter,
) -> Result<bool, SessionError> {
    let Some(datagram) = transport.receive_kind(MediaKind::Audio)? else {
        return Ok(false);
    };
    if relay
        .expected_audio_peer
        .is_some_and(|peer| peer != datagram.peer)
    {
        return Ok(false);
    }
    let frame = match parse_audio_datagram(&datagram.payload) {
        Ok(frame) => frame,
        Err(_) => {
            lock_unpoison(relay.shared).audio_malformed_drops += 1;
            return Ok(false);
        }
    };
    send_audio_media(transport, frame.sequence, &frame.pcm, datagram.peer, writer)?;
    increment_audio_counters(relay.shared);
    Ok(true)
}

/// Returns packet consumption, including incomplete frames, to avoid sleeping
/// between fragments already available in the receive socket.
fn poll_video(
    relay: &PeerRelay<'_>,
    transport: &mut SessionMediaTransport,
    reassembler: &mut FrameReassembler,
    pending: &mut Option<PendingVideo>,
) -> Result<bool, SessionError> {
    let Some(datagram) = transport.receive_kind(MediaKind::Video)? else {
        return Ok(false);
    };
    if relay
        .expected_video_peer
        .is_some_and(|peer| peer != datagram.peer)
    {
        return Ok(true);
    }
    let body = match reassembler.feed(&datagram.payload) {
        Ok(Some(body)) => body,
        Ok(None) => return Ok(true),
        Err(_) => {
            lock_unpoison(relay.shared).video_malformed_drops += 1;
            return Ok(true);
        }
    };
    let frame = match parse_video_frame(&body, relay.video_compressed) {
        Ok(frame) => frame,
        Err(_) => {
            lock_unpoison(relay.shared).video_malformed_drops += 1;
            return Ok(true);
        }
    };
    let mut result = lock_unpoison(relay.shared);
    result.video_frames_received += 1;
    result.media_frames_received += 1;
    if pending.is_some() {
        result.video_stale_drops += 1;
        return Ok(true);
    }
    let prepared = PreparedVideoFrame::new(
        u64::from(frame.sequence),
        StreamingVideoFragments::new(frame.sequence, &frame.payload, None, relay.packet_size),
    );
    *pending = Some((VideoTxCursor::new(prepared), datagram.peer));
    Ok(true)
}

/// Returns (packet sent, frame completed); only completed frames advance a
/// finite relay's completion count. A blocked cursor expires independently.
fn send_video_quantum(
    relay: &PeerRelay<'_>,
    transport: &mut SessionMediaTransport,
    pending: &mut Option<PendingVideo>,
) -> Result<(bool, bool), SessionError> {
    let Some((cursor, destination)) = pending.as_mut() else {
        return Ok((false, false));
    };
    if cursor.expired(Instant::now(), VIDEO_AGE_LIMIT) {
        lock_unpoison(relay.shared).video_deadline_drops += 1;
        *pending = None;
        return Ok((false, false));
    }
    let Some(payload) = cursor.next() else {
        *pending = None;
        return Ok((false, false));
    };
    if transport.send_video_datagram(payload, *destination)?
        == crate::station::session::media::VideoSendDisposition::WouldBlock
    {
        return Ok((false, false));
    }
    let complete = cursor.sent_one();
    if complete {
        let mut result = lock_unpoison(relay.shared);
        result.video_frames_sent += 1;
        result.media_frames_sent += 1;
        *pending = None;
    }
    Ok((true, complete))
}
