//! Npcap media plane with strict dynamic bindings and private RAII handles.

mod ffi;
mod packet;
mod plane;

pub use ffi::{load_pcap, PcapLibrary};
pub use packet::{
    build_ethernet_ipv4_udp_frame, parse_mac_address, resolve_direct_lan_mac_via_ip_helper,
    resolve_mac_via_ip_helper,
};
#[doc(hidden)]
pub use packet::{parse_ethernet_ipv4_udp_frame_borrowed, BorrowedUdpPacket};
pub use plane::RawMediaPlane;
