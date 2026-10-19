use thiserror::Error;

/// A stable, caller-visible category for a terminal station-session failure.
///
/// The detail remains available for CLI and diagnostics, but callers should
/// branch on this enum rather than attempting to interpret that text.
#[derive(Debug, Clone, Error, PartialEq, Eq)]
pub enum SessionError {
    #[error("session runtime is already active")]
    AlreadyActive,
    #[error("invalid runtime configuration: {0}")]
    Configuration(String),
    #[error("control handshake failed: {0}")]
    ControlHandshake(String),
    #[error("media transport failed: {0}")]
    Transport(String),
    #[error("audio backend failed: {0}")]
    AudioBackend(String),
    #[error("video backend failed: {0}")]
    VideoBackend(String),
    #[error("protocol failed: {0}")]
    Protocol(String),
    #[error("session timed out: {0}")]
    Timeout(String),
    #[error("peer disconnected: {0}")]
    PeerDisconnect(String),
    #[error("cleanup failed: {0}")]
    Cleanup(String),
    #[error("session runtime is not active")]
    NotActive,
}

impl SessionError {
    /// A failed `set_timeout` leaves the socket blocking or with a stale deadline, so it
    /// is a transport fault rather than something to ignore.
    pub(crate) fn from_socket_timeout(result: std::io::Result<()>) -> Result<(), Self> {
        result.map_err(|error| Self::Transport(format!("setting socket timeout failed: {error}")))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn socket_timeout_failures_become_transport_errors() {
        assert_eq!(SessionError::from_socket_timeout(Ok(())), Ok(()));
        let failure = std::io::Error::other("invalid argument");
        assert_eq!(
            SessionError::from_socket_timeout(Err(failure)),
            Err(SessionError::Transport(
                "setting socket timeout failed: invalid argument".into()
            ))
        );
    }
}
