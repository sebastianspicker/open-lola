//! Pick the local LAN address for a connect/listen run when the default loopback would never match.

use crate::config::StationSettings;
use std::net::{IpAddr, UdpSocket};

/// Local IP the OS would use to reach `remote`; no packet is sent.
fn route_local_ip(remote: IpAddr, port: u16) -> Option<IpAddr> {
    let bind = if remote.is_ipv6() {
        "[::]:0"
    } else {
        "0.0.0.0:0"
    };
    let socket = UdpSocket::bind(bind).ok()?;
    socket.connect((remote, port)).ok()?;
    socket.local_addr().ok().map(|addr| addr.ip())
}

/// The local IP to adopt, or `None` to keep `local_ip`. Only a still-default loopback
/// local IP facing a non-loopback remote is replaced.
fn select_local_ip(
    local_ip: &str,
    remote_ip: &str,
    route: impl FnOnce(IpAddr) -> Option<IpAddr>,
) -> Option<IpAddr> {
    let remote: IpAddr = remote_ip.parse().ok()?;
    if local_ip != "127.0.0.1" || remote.is_loopback() {
        return None;
    }
    route(remote).filter(|ip| !ip.is_loopback() && !ip.is_unspecified())
}

/// Replace a default `local_ip` with the routed LAN address and say so on stderr.
/// An explicit `--local-ip` is never touched; a settings value equal to the default
/// cannot be told apart from an unset one and is treated as default.
pub(super) fn apply_route_local_ip(settings: &mut StationSettings, local_ip_flag: bool) {
    if local_ip_flag {
        return;
    }
    let network = &mut settings.network;
    let port = network.control_port;
    let selected = select_local_ip(&network.local_ip, &network.remote_ip, |remote| {
        route_local_ip(remote, port)
    });
    if let Some(ip) = selected {
        eprintln!(
            "local IP {ip} selected from route to {} (override with --local-ip)",
            network.remote_ip
        );
        network.local_ip = ip.to_string();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn lan() -> Option<IpAddr> {
        Some("192.168.1.10".parse().unwrap())
    }

    #[test]
    fn loopback_remote_keeps_the_default() {
        assert_eq!(select_local_ip("127.0.0.1", "127.0.0.1", |_| lan()), None);
    }

    #[test]
    fn non_loopback_remote_adopts_the_routed_address() {
        assert_eq!(select_local_ip("127.0.0.1", "192.0.2.1", |_| lan()), lan());
    }

    #[test]
    fn explicit_local_ip_and_loopback_routes_are_kept() {
        assert_eq!(select_local_ip("10.0.0.5", "192.0.2.1", |_| lan()), None);
        let loopback = Some("127.0.0.1".parse().unwrap());
        assert_eq!(
            select_local_ip("127.0.0.1", "192.0.2.1", |_| loopback),
            None
        );
        assert_eq!(select_local_ip("127.0.0.1", "not-an-ip", |_| lan()), None);
    }

    #[test]
    fn route_lookup_never_yields_loopback_for_a_remote_address() {
        let remote: IpAddr = "192.0.2.1".parse().unwrap();
        if let Some(ip) = route_local_ip(remote, 7000) {
            assert!(!ip.is_loopback());
        }
        let loopback: IpAddr = "127.0.0.1".parse().unwrap();
        if let Some(ip) = route_local_ip(loopback, 7000) {
            assert!(ip.is_loopback());
        }
    }
}
