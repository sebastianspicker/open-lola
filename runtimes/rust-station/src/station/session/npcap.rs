//! Shared Npcap session admission and adapter construction.

use super::media::SessionMediaTransport;
use super::SessionOptions;
use crate::config::StationSettings;
use crate::net::NpcapMediaTransport;
use crate::station::SessionError;
use std::net::{IpAddr, SocketAddr};

/// Open the raw media plane after the caller has completed control negotiation.
///
/// Both initiator and peer use this single admission path so adapter selection,
/// IPv4 requirements, MAC resolution, VLAN handling, and queue sizing remain
/// identical on each side of a session.
pub(super) fn open_npcap_media_transport(
    settings: &StationSettings,
    options: &SessionOptions,
    peer_addr: SocketAddr,
    audio_port: u16,
    video_port: u16,
) -> Result<SessionMediaTransport, SessionError> {
    reject_loopback(options)?;
    let source_ip = settings.network.local_ip.parse().map_err(|_| {
        SessionError::Configuration("Npcap requires a concrete local IPv4 address".into())
    })?;
    let peer_ip = match peer_addr.ip() {
        IpAddr::V4(ip) => ip,
        IpAddr::V6(_) => {
            return Err(SessionError::Configuration(
                "Npcap requires an IPv4 peer".into(),
            ));
        }
    };
    let device = selected_device(settings, options)?;
    let source_mac = super::control::resolve_local_session_mac(
        "RUSTY_LOLA_LOCAL_MAC",
        source_ip,
        peer_ip,
        device,
    )?;
    let peer_mac = super::control::resolve_session_mac("RUSTY_LOLA_PEER_MAC", peer_ip, source_ip)?;
    let mut transport = NpcapMediaTransport::open(
        device,
        source_ip,
        peer_ip,
        source_mac,
        peer_mac,
        audio_port,
        video_port,
        settings.network.vlan_tag,
    )
    .map_err(SessionError::Transport)?;
    transport
        .set_queue_depths(
            settings.network.audio_receive_queue_depth as usize,
            settings.network.video_receive_queue_depth as usize,
        )
        .map_err(SessionError::Transport)?;
    Ok(SessionMediaTransport::npcap(transport))
}

fn reject_loopback(options: &SessionOptions) -> Result<(), SessionError> {
    if options.peer_mode.eq_ignore_ascii_case("loopback") {
        return Err(SessionError::Configuration(
            "Npcap cannot be used for loopback sessions".into(),
        ));
    }
    Ok(())
}

fn selected_device<'a>(
    settings: &'a StationSettings,
    options: &'a SessionOptions,
) -> Result<&'a str, SessionError> {
    options
        .pcap_device
        .as_deref()
        .filter(|value| !value.is_empty())
        .or_else(|| {
            (!settings.network.pcap_device.is_empty())
                .then_some(settings.network.pcap_device.as_str())
        })
        .ok_or_else(|| {
            SessionError::Configuration("Npcap requires an explicitly selected adapter".into())
        })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::config::default_settings;

    #[test]
    fn npcap_admission_rejects_loopback_before_adapter_access() {
        let settings = default_settings();
        let options = SessionOptions::demo();
        let outcome = open_npcap_media_transport(
            &settings,
            &options,
            "127.0.0.1:19788".parse().expect("valid test address"),
            19788,
            19798,
        );
        let Err(error) = outcome else {
            panic!("loopback must never open Npcap");
        };
        assert!(error.to_string().contains("cannot be used for loopback"));
    }
}
