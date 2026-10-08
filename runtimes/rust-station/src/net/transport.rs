//! Media transport boundary shared by LoLa audio and video.
//!
//! Public types remain here while UDP and Npcap implementations are isolated
//! in private modules to keep each production source focused and bounded.

mod npcap;
mod types;
mod udp_media;

pub use npcap::NpcapMediaTransport;
pub use types::{
    DatagramPoll, MediaKind, MediaTransport, ReceivedDatagram, TransportError, TransportStats,
};
pub use udp_media::UdpMediaTransport;
