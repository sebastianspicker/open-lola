//! Responder handshake helpers: tolerant QUICKCONN parsing and the
//! re-acknowledgement of a repeated QUICKCONN once media is flowing.
use super::super::control::{
    apply_stream_control, is_stream_control, validate_incoming_control, QuickconnAckCache,
};
use super::super::{SessionOptions, SessionResult};
use crate::config::StationSettings;
use crate::net::Udp;
use crate::protocol::{
    decode_mesg, parse_quickconn_fields, MediaSettings, Mesg, ProtocolError, MESG_QUICKCONN,
};
use crate::station::sync::lock_unpoison;
use crate::station::SessionError;
use serde_json::Value;
use std::collections::BTreeMap;
use std::net::SocketAddr;
use std::sync::{Arc, Mutex};

const VIDEO_FIELDS: &[&str] = &["FPS", "BPP", "X", "Y", "COMP", "BAYER"];

/// Whether the session carries video, i.e. whether video fields in QUICKCONN
/// are binding.
pub(super) fn video_negotiated(options: &SessionOptions) -> bool {
    !(options.audio_only || (!options.stream_tx_video && !options.stream_rx_video))
}

/// Parses QUICKCONN capabilities. Audio-only sessions accept zeroed or absent
/// video fields (as the macOS connector sends) and keep them as written.
pub(super) fn quickconn_capabilities(
    message: &Mesg,
    options: &SessionOptions,
) -> Result<BTreeMap<String, Value>, ProtocolError> {
    let strict = parse_quickconn_fields(message);
    if strict.is_ok() || video_negotiated(options) {
        return strict;
    }
    let defaults = MediaSettings::default().control_fields();
    let mut audio_view = message.clone();
    for pair in defaults.split(';') {
        if let Some((key, value)) = pair.split_once(':') {
            if VIDEO_FIELDS.contains(&key) {
                audio_view.fields.insert(key.into(), value.into());
            }
        }
    }
    let mut capabilities = parse_quickconn_fields(&audio_view)?;
    for key in VIDEO_FIELDS {
        let original = message
            .fields
            .get(*key)
            .and_then(|value| value.parse::<i64>().ok())
            .unwrap_or(0);
        capabilities.insert((*key).into(), serde_json::json!(original));
    }
    Ok(capabilities)
}

pub(super) fn pump_peer_control(
    socket: &Udp,
    ack: &QuickconnAckCache,
    expected_sender: SocketAddr,
    settings: &StationSettings,
    options: &SessionOptions,
    shared: &Arc<Mutex<SessionResult>>,
) -> Result<bool, SessionError> {
    pump_peer_control_from(
        || socket.try_recv_vec(),
        socket,
        ack,
        expected_sender,
        settings,
        options,
        shared,
    )
}

pub(super) fn pump_peer_control_from(
    mut receive: impl FnMut() -> std::io::Result<Option<(Vec<u8>, SocketAddr)>>,
    socket: &Udp,
    ack: &QuickconnAckCache,
    expected_sender: SocketAddr,
    settings: &StationSettings,
    options: &SessionOptions,
    shared: &Arc<Mutex<SessionResult>>,
) -> Result<bool, SessionError> {
    for _ in 0..64 {
        match receive() {
            Ok(Some((data, sender))) => {
                if sender != expected_sender {
                    continue;
                }
                let Ok(message) = decode_mesg(&data) else {
                    continue;
                };
                if validate_incoming_control(&message, sender, settings, Some(expected_sender))
                    .is_err()
                {
                    continue;
                }
                if message.name == format!("/{MESG_QUICKCONN}") {
                    ack.resend(socket, sender, shared);
                    continue;
                }
                if !is_stream_control(&message) {
                    continue;
                }
                let mut result = lock_unpoison(shared);
                if apply_stream_control(&message, &mut result, options.runtime_control.as_ref()) {
                    return Ok(true);
                }
            }
            Ok(None) => return Ok(false),
            Err(error) => return Err(SessionError::Transport(error.to_string())),
        }
    }
    Ok(false)
}
