//! Responder handshake helpers: tolerant QUICKCONN parsing and the
//! re-acknowledgement of a repeated QUICKCONN once media is flowing.
use super::super::control::{apply_stream_control, pump_control_from, QuickconnAckCache};
use super::super::{SessionOptions, SessionResult};
use crate::config::StationSettings;
use crate::net::Udp;
use crate::protocol::{parse_quickconn_fields, MediaSettings, Mesg, ProtocolError};
use crate::station::bounded::push_bounded;
use crate::station::sync::lock_unpoison;
use crate::station::SessionError;
use serde_json::Value;
use std::collections::BTreeMap;
use std::net::SocketAddr;
use std::sync::{Arc, Mutex};

const VIDEO_FIELDS: &[&str] = &["FPS", "BPP", "X", "Y", "COMP", "BAYER"];

pub(super) fn record_received(shared: &Arc<Mutex<SessionResult>>, name: &str) {
    push_bounded(&mut lock_unpoison(shared).messages_received, name.into());
}

pub(super) fn record_sent(shared: &Arc<Mutex<SessionResult>>, name: &str) {
    push_bounded(&mut lock_unpoison(shared).messages_sent, name.into());
}

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
    receive: impl FnMut() -> std::io::Result<Option<(Vec<u8>, SocketAddr)>>,
    socket: &Udp,
    ack: &QuickconnAckCache,
    expected_sender: SocketAddr,
    settings: &StationSettings,
    options: &SessionOptions,
    shared: &Arc<Mutex<SessionResult>>,
) -> Result<bool, SessionError> {
    pump_control_from(receive, expected_sender, settings, true, |message| {
        if message.name == "/MESG_QUICKCONN" {
            // Send without the result lock, so report readers never wait on the socket.
            if ack.resend(socket, expected_sender) {
                push_bounded(
                    &mut lock_unpoison(shared).messages_sent,
                    "/MESG_QUICKCONN_ACK".into(),
                );
            }
            return false;
        }
        apply_stream_control(
            message,
            &mut lock_unpoison(shared),
            options.runtime_control.as_ref(),
        )
    })
}
