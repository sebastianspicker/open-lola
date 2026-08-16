//! Client media-plane acquisition performed only after QUICKCONN acceptance.

use super::backends::SessionAudioBackend;
use super::media::SessionMediaTransport;
use super::SessionOptions;
use crate::config::StationSettings;
use crate::net::{NpcapMediaTransport, Udp};
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
        if options.peer_mode.eq_ignore_ascii_case("loopback") {
            return Err(SessionError::Configuration(
                "Npcap cannot be used for loopback sessions".into(),
            ));
        }
        let source_ip: std::net::Ipv4Addr = settings.network.local_ip.parse().map_err(|_| {
            SessionError::Configuration("Npcap requires a concrete local IPv4 address".into())
        })?;
        let peer_ip = match peer_addr.ip() {
            std::net::IpAddr::V4(ip) => ip,
            std::net::IpAddr::V6(_) => {
                return Err(SessionError::Configuration(
                    "Npcap requires an IPv4 peer".into(),
                ));
            }
        };
        let device = options
            .pcap_device
            .as_deref()
            .filter(|value| !value.is_empty())
            .or_else(|| {
                (!settings.network.pcap_device.is_empty())
                    .then_some(settings.network.pcap_device.as_str())
            })
            .ok_or_else(|| {
                SessionError::Configuration("Npcap requires an explicitly selected adapter".into())
            })?;
        let source_mac = super::control::resolve_local_session_mac(
            "RUSTY_LOLA_LOCAL_MAC",
            source_ip,
            peer_ip,
            device,
        )?;
        let peer_mac =
            super::control::resolve_session_mac("RUSTY_LOLA_PEER_MAC", peer_ip, source_ip)?;
        let mut transport = NpcapMediaTransport::open(
            device,
            source_ip,
            peer_ip,
            source_mac,
            peer_mac,
            settings.network.audio_port,
            settings.network.video_port,
            settings.network.vlan_tag,
        )
        .map_err(SessionError::Transport)?;
        transport
            .set_queue_depths(
                settings.network.audio_receive_queue_depth as usize,
                settings.network.video_receive_queue_depth as usize,
            )
            .map_err(SessionError::Transport)?;
        return Ok(SessionMediaTransport::npcap(transport));
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
