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
mod npcap;
mod peer;
mod report;
mod runner;
mod scheduler;
mod stream;
mod timing;
mod types;
mod video;

pub use runner::{run_check_only, run_default_session, run_reject_session, run_session};
#[cfg(any(feature = "gui", test))]
pub(crate) use types::VideoPreviewUpdate;
pub use types::{
    PeerRole, RuntimeActivity, SessionOptions, SessionPhase, SessionResult, SessionRuntimeControl,
    VideoPreview,
};

#[cfg(test)]
mod recovery_tests;
