//! Station control and media session facade.
//!
//! The public session API remains here; implementation details are divided by
//! transport, peer, media, backend, and stream responsibilities.

mod audio;
mod backends;
mod capture;
mod client;
mod client_cleanup;
mod client_media;
mod control;
mod lifecycle;
mod media;
mod peer;
mod runner;
mod scheduler;
mod stream;
mod types;
mod video;

pub use runner::{run_check_only, run_default_session, run_reject_session, run_session};
pub use types::{
    PeerRole, RuntimeActivity, SessionOptions, SessionPhase, SessionResult, SessionRuntimeControl,
    VideoPreview,
};
