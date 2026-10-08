use std::net::SocketAddr;
use thiserror::Error;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MediaKind {
    Audio,
    Video,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ReceivedDatagram {
    pub kind: MediaKind,
    pub peer: SocketAddr,
    pub source_port: u16,
    pub payload: Vec<u8>,
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct TransportStats {
    pub sent_datagrams: u64,
    pub received_datagrams: u64,
    pub sent_bytes: u64,
    pub received_bytes: u64,
    pub malformed_drops: u64,
    pub wrong_peer_drops: u64,
    pub wrong_port_drops: u64,
    pub kernel_drops: u64,
    pub backpressure_drops: u64,
    pub queue_replacement_drops: u64,
    /// Receive errors that carry no datagram, such as a Windows ICMP
    /// port-unreachable surfacing as `ConnectionReset`.
    pub transient_receive_errors: u64,
}

#[derive(Debug, Clone, PartialEq, Eq, Error)]
pub enum TransportError {
    #[error("media transport would block")]
    WouldBlock,
    #[error("media transport timed out")]
    Timeout,
    #[error("media transport is shut down")]
    Closed,
    #[error("invalid media transport configuration: {0}")]
    Configuration(String),
    #[error("media transport I/O: {0}")]
    Io(String),
    #[error("Npcap: {0}")]
    Npcap(String),
    #[error("media transport backpressure: {0}")]
    Backpressure(String),
    /// A send fault expected to clear by itself (no buffers, no route yet,
    /// refused by a peer that is restarting). The datagram is dropped.
    #[error("media transport transient fault: {0}")]
    Transient(String),
}

impl TransportError {
    pub(crate) fn from_io(error: std::io::Error) -> Self {
        match error.kind() {
            std::io::ErrorKind::WouldBlock => Self::WouldBlock,
            std::io::ErrorKind::TimedOut => Self::Timeout,
            _ if error.raw_os_error().is_some_and(is_transient_os_error) => {
                Self::Transient(error.to_string())
            }
            _ => Self::Io(error.to_string()),
        }
    }
}

/// Raw OS errors that a datagram sender treats as a dropped packet instead of
/// a failed session: ENOBUFS, EHOSTUNREACH, ENETUNREACH, ENETDOWN, EHOSTDOWN,
/// ECONNREFUSED, ECONNRESET, EPERM and EINTR.
#[cfg(unix)]
pub(crate) fn is_transient_os_error(code: i32) -> bool {
    [
        libc::ENOBUFS,
        libc::EHOSTUNREACH,
        libc::ENETUNREACH,
        libc::ENETDOWN,
        libc::EHOSTDOWN,
        libc::ECONNREFUSED,
        libc::ECONNRESET,
        libc::EPERM,
        libc::EINTR,
    ]
    .contains(&code)
}

/// Winsock equivalents (WSAEINTR, WSAENETDOWN, WSAENETUNREACH, WSAECONNRESET,
/// WSAENOBUFS, WSAECONNREFUSED, WSAEHOSTDOWN, WSAEHOSTUNREACH, WSAEACCES).
#[cfg(windows)]
pub(crate) fn is_transient_os_error(code: i32) -> bool {
    [
        10004, 10050, 10051, 10054, 10055, 10061, 10064, 10065, 10013,
    ]
    .contains(&code)
}

#[cfg(not(any(unix, windows)))]
pub(crate) fn is_transient_os_error(_code: i32) -> bool {
    false
}

/// Result of polling one media socket. `Discarded` means a datagram was read
/// but rejected by the peer/port/size classifier, so more may still be queued.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DatagramPoll {
    Datagram(ReceivedDatagram),
    Discarded,
    Empty,
}

pub trait MediaTransport {
    fn send(&mut self, kind: MediaKind, payload: &[u8]) -> Result<(), TransportError>;
    fn receive(&mut self) -> Result<Option<ReceivedDatagram>, TransportError>;
    fn stats(&self) -> TransportStats;
    /// Refreshes any fallible native counters for an explicit report.
    ///
    /// Pure software transports inherit the cached snapshot. Native transports
    /// override this so an unavailable reporting source stays an explicit
    /// error without adding work to each receive poll.
    fn stats_snapshot(&mut self) -> Result<TransportStats, TransportError> {
        Ok(self.stats())
    }
    fn shutdown(&mut self) -> Result<(), TransportError>;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn transient_os_errors_are_drops_and_others_stay_io_errors() {
        #[cfg(unix)]
        {
            for code in [
                libc::ENOBUFS,
                libc::EHOSTUNREACH,
                libc::ENETUNREACH,
                libc::ENETDOWN,
                libc::EHOSTDOWN,
                libc::ECONNREFUSED,
                libc::ECONNRESET,
                libc::EPERM,
                libc::EINTR,
            ] {
                let error = TransportError::from_io(std::io::Error::from_raw_os_error(code));
                assert!(matches!(error, TransportError::Transient(_)), "{code}");
            }
            let fatal = TransportError::from_io(std::io::Error::from_raw_os_error(libc::EBADF));
            assert!(matches!(fatal, TransportError::Io(_)));
        }
        assert_eq!(
            TransportError::from_io(std::io::ErrorKind::WouldBlock.into()),
            TransportError::WouldBlock
        );
        assert!(matches!(
            TransportError::from_io(std::io::Error::other("custom")),
            TransportError::Io(_)
        ));
    }
}
