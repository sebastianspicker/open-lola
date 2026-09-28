//! Client media-plane acquisition performed only after QUICKCONN acceptance.

use super::backends::SessionAudioBackend;
use super::media::SessionMediaTransport;
use super::SessionOptions;
use crate::config::StationSettings;
use crate::net::Udp;
use crate::station::SessionError;
use std::net::SocketAddr;

pub(super) struct PreparedClientMedia {
    pub(super) audio: Option<SessionAudioBackend>,
    pub(super) transport: Option<SessionMediaTransport>,
}

impl PreparedClientMedia {
    pub(super) fn complete(audio: SessionAudioBackend, transport: SessionMediaTransport) -> Self {
        Self {
            audio: Some(audio),
            transport: Some(transport),
        }
    }

    pub(super) fn empty() -> Self {
        Self {
            audio: None,
            transport: None,
        }
    }
}

/// Acquires the media sockets/Npcap adapter and starts audio after control
/// negotiation. Returning partially acquired resources lets the caller run the
/// same checked, ordered finalizer while retaining the original setup error.
#[allow(clippy::too_many_arguments)]
pub(super) fn prepare_client_media(
    settings: &StationSettings,
    options: &SessionOptions,
    peer_addr: SocketAddr,
    fixed_media_ports: bool,
    media_timeout: f64,
    requested_npcap: bool,
) -> Result<PreparedClientMedia, Box<(SessionError, PreparedClientMedia)>> {
    let transport = match open_media_transport(
        settings,
        options,
        peer_addr,
        fixed_media_ports,
        media_timeout,
        requested_npcap,
    ) {
        Ok(transport) => transport,
        Err(error) => return Err(Box::new((error, PreparedClientMedia::empty()))),
    };
    let audio = match SessionAudioBackend::open(settings, options) {
        Ok(audio) => audio,
        Err(error) => {
            return Err(Box::new((
                error,
                PreparedClientMedia {
                    audio: None,
                    transport: Some(transport),
                },
            )));
        }
    };
    Ok(PreparedClientMedia::complete(audio, transport))
}

fn open_media_transport(
    settings: &StationSettings,
    options: &SessionOptions,
    peer_addr: SocketAddr,
    fixed_media_ports: bool,
    media_timeout: f64,
    requested_npcap: bool,
) -> Result<SessionMediaTransport, SessionError> {
    if requested_npcap {
        return super::npcap::open_npcap_media_transport(
            settings,
            options,
            peer_addr,
            settings.network.audio_port,
            settings.network.video_port,
        );
    }

    let bind = &settings.network.bind_ip;
    let client_audio = Udp::bind(
        bind,
        if fixed_media_ports {
            settings.network.audio_port
        } else {
            0
        },
    )
    .map_err(|error| SessionError::Transport(error.to_string()))?;
    let client_video = Udp::bind(
        bind,
        if fixed_media_ports {
            settings.network.video_port
        } else {
            0
        },
    )
    .map_err(|error| SessionError::Transport(error.to_string()))?;
    client_audio.set_timeout(media_timeout).ok();
    client_video.set_timeout(media_timeout).ok();
    client_audio
        .configure_media_nonblocking()
        .map_err(|error| SessionError::Transport(error.to_string()))?;
    client_video
        .configure_media_nonblocking()
        .map_err(|error| SessionError::Transport(error.to_string()))?;
    if fixed_media_ports {
        SessionMediaTransport::udp_from_bound_sockets(
            client_audio,
            client_video,
            peer_addr.ip(),
            settings.network.audio_port,
            settings.network.video_port,
        )
    } else {
        Ok(SessionMediaTransport::diagnostic_udp(
            client_audio,
            client_video,
        ))
    }
}
