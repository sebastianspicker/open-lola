//! Npcap media plane with strict dynamic bindings and private RAII handles.

mod ffi;
mod packet;
mod plane;

pub use ffi::{load_pcap, probe_pcap, PcapLibrary, PcapProbe};
pub use packet::{
    build_ethernet_ipv4_udp_frame, internet_checksum, parse_ethernet_ipv4_udp_frame,
    parse_mac_address, resolve_direct_lan_mac_via_ip_helper, resolve_local_mac_via_ip_helper,
    resolve_mac_via_ip_helper, ParsedUdpPacket, ETHERTYPE_IPV4, ETHERTYPE_VLAN, IP_PROTOCOL_UDP,
    MAX_UDP_PAYLOAD,
};
pub use plane::RawMediaPlane;
