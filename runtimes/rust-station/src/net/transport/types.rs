use std::net::SocketAddr;
use std::time::SystemTime;
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
    pub received_at: SystemTime,
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
}

impl TransportError {
    pub(crate) fn from_io(error: std::io::Error) -> Self {
        match error.kind() {
            std::io::ErrorKind::WouldBlock => Self::WouldBlock,
            std::io::ErrorKind::TimedOut => Self::Timeout,
            _ => Self::Io(error.to_string()),
        }
    }
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
