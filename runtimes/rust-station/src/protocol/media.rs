//! LoLa 2.0 UDP media codec.
//!
//! A media body is little-endian `sequence`, `payload length`, then payload.
//! Bodies are carried in the recovered LoLa fragment format rather than a
//! Rust-only envelope.

mod audio_datagram;
mod body;
pub use audio_datagram::parse_audio_datagram;
mod fragment;
mod reassembly;

pub use body::*;
pub use fragment::*;
pub use reassembly::*;
