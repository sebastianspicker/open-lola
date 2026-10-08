//! Thin UDP helper with bind / sendto / recvfrom and timeout.

use socket2::{Domain, Protocol, Socket, Type};
use std::io;
use std::net::{SocketAddr, ToSocketAddrs, UdpSocket};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Mutex, MutexGuard};
use std::time::Duration;

/// Bounded kernel UDP buffering. Raw video arrives in bursts of several
/// hundred fragments per frame, so the first request is generous; the kernel
/// may cap it (Linux `rmem_max`) or reject it (macOS `maxsockbuf`), in which
/// case the next smaller bound is requested. The floor keeps one complete
/// audio deadline plus scheduler slack queued without silent loss.
const UDP_SOCKET_BUFFER_BYTES: &[usize] = &[
    4 * 1024 * 1024,
    2 * 1024 * 1024,
    1024 * 1024,
    512 * 1024,
    256 * 1024,
    64 * 1024,
];

#[derive(Debug)]
pub struct Udp {
    sock: UdpSocket,
    receive_state: Mutex<ReceiveState>,
    /// `ConnectionReset` receives (Windows ICMP port-unreachable) absorbed
    /// as "no datagram" since the last `take_transient_receive_errors`.
    transient_receive_errors: AtomicU64,
}

#[derive(Debug)]
struct ReceiveState {
    scratch: Vec<u8>,
    permanently_nonblocking: bool,
}

impl Udp {
    pub fn new() -> io::Result<Self> {
        // Use an ephemeral port while retaining bounded kernel buffers.
        let sock = bounded_udp_socket("0.0.0.0:0")?;
        Ok(Self {
            sock,
            receive_state: Mutex::new(ReceiveState::new()),
            transient_receive_errors: AtomicU64::new(0),
        })
    }

    pub fn bind(host: &str, port: u16) -> io::Result<Self> {
        let addr = format!("{host}:{port}");
        let sock = bounded_udp_socket(&addr)?;
        Ok(Self {
            sock,
            receive_state: Mutex::new(ReceiveState::new()),
            transient_receive_errors: AtomicU64::new(0),
        })
    }

    pub fn free_port(bind_ip: &str) -> io::Result<u16> {
        let sock = UdpSocket::bind(format!("{bind_ip}:0"))?;
        Ok(sock.local_addr()?.port())
    }

    pub fn set_timeout(&self, secs: f64) -> io::Result<()> {
        let _receive_lock = self.lock_receive()?;
        let d = if secs <= 0.0 {
            None
        } else {
            Some(Duration::from_secs_f64(secs))
        };
        self.sock.set_read_timeout(d)?;
        self.sock.set_write_timeout(d)?;
        Ok(())
    }

    pub fn local_addr(&self) -> io::Result<SocketAddr> {
        self.sock.local_addr()
    }

    pub fn send_to(&self, buf: &[u8], addr: impl ToSocketAddrs) -> io::Result<usize> {
        self.sock.send_to(buf, addr)
    }

    pub fn recv_from(&self, buf: &mut [u8]) -> io::Result<(usize, SocketAddr)> {
        let _receive_state = self.lock_receive()?;
        self.sock.recv_from(buf)
    }

    pub fn recv_vec(&self) -> io::Result<(Vec<u8>, SocketAddr)> {
        let mut state = self.lock_receive()?;
        let (length, peer) = self.recv_into_scratch(&mut state)?;
        Ok((state.scratch[..length].to_vec(), peer))
    }

    /// Pins a media socket in nonblocking mode once. Control sockets continue
    /// to use their configured blocking/timeout mode between individual polls.
    pub(crate) fn configure_media_nonblocking(&self) -> io::Result<()> {
        let mut state = self.lock_receive()?;
        if !state.permanently_nonblocking {
            self.sock.set_nonblocking(true)?;
            state.permanently_nonblocking = true;
        }
        Ok(())
    }

    /// Performs one receive without waiting, preserving the socket's configured
    /// blocking mode and timeout for negotiation callers.
    pub(crate) fn try_recv_vec(&self) -> io::Result<Option<(Vec<u8>, SocketAddr)>> {
        let mut state = self.lock_receive()?;
        let mut nonblocking =
            NonblockingReceive::enable_unless(&self.sock, state.permanently_nonblocking)?;
        let received = match self.recv_into_scratch(&mut state) {
            Ok((length, peer)) => Ok(Some((state.scratch[..length].to_vec(), peer))),
            Err(error) => self.absorb_empty_receive(error),
        };
        let restore_result = nonblocking.restore();
        match received {
            Err(error) => Err(error),
            Ok(value) => restore_result.map(|()| value),
        }
    }

    /// Receives one datagram without waiting and lets the caller validate the
    /// borrowed scratch bytes before choosing whether to copy them.
    pub(crate) fn try_recv<T, F>(&self, classify: F) -> io::Result<Option<T>>
    where
        F: FnOnce(&[u8], SocketAddr) -> Option<T>,
    {
        let mut state = self.lock_receive()?;
        let mut nonblocking =
            NonblockingReceive::enable_unless(&self.sock, state.permanently_nonblocking)?;
        let received = match self.recv_into_scratch(&mut state) {
            Ok((length, peer)) => Ok(classify(&state.scratch[..length], peer)),
            Err(error) => self.absorb_empty_receive(error),
        };
        let restore_result = nonblocking.restore();
        match received {
            Err(error) => Err(error),
            Ok(value) => restore_result.map(|()| value),
        }
    }

    /// Maps receive errors that carry no datagram to "nothing received". A
    /// `ConnectionReset` is a Windows ICMP port-unreachable for an earlier
    /// send and is counted instead of failing the poll.
    fn absorb_empty_receive<T>(&self, error: io::Error) -> io::Result<Option<T>> {
        match error.kind() {
            io::ErrorKind::WouldBlock | io::ErrorKind::TimedOut => Ok(None),
            io::ErrorKind::ConnectionReset => {
                self.transient_receive_errors
                    .fetch_add(1, Ordering::Relaxed);
                Ok(None)
            }
            _ => Err(error),
        }
    }

    /// Returns and clears the count of absorbed transient receive errors.
    pub(crate) fn take_transient_receive_errors(&self) -> u64 {
        self.transient_receive_errors.swap(0, Ordering::Relaxed)
    }

    fn lock_receive(&self) -> io::Result<MutexGuard<'_, ReceiveState>> {
        self.receive_state.lock().map_err(|_| {
            io::Error::other("UDP receive state lock was poisoned by a previous panic")
        })
    }

    fn recv_into_scratch(&self, state: &mut ReceiveState) -> io::Result<(usize, SocketAddr)> {
        self.sock.recv_from(&mut state.scratch)
    }
}

impl ReceiveState {
    fn new() -> Self {
        Self {
            scratch: vec![0; 65_535],
            permanently_nonblocking: false,
        }
    }
}

fn bounded_udp_socket(addr: impl ToSocketAddrs) -> io::Result<UdpSocket> {
    let mut last_error = None;
    for addr in addr.to_socket_addrs()? {
        match bind_bounded_udp_socket(addr) {
            Ok(socket) => return Ok(socket),
            Err(error) => last_error = Some(error),
        }
    }
    Err(last_error.unwrap_or_else(|| {
        io::Error::new(
            io::ErrorKind::InvalidInput,
            "UDP bind address did not resolve to a socket address",
        )
    }))
}

fn bind_bounded_udp_socket(addr: SocketAddr) -> io::Result<UdpSocket> {
    let socket = Socket::new(Domain::for_address(addr), Type::DGRAM, Some(Protocol::UDP))?;
    set_bounded_buffer(|bytes| socket.set_recv_buffer_size(bytes))?;
    set_bounded_buffer(|bytes| socket.set_send_buffer_size(bytes))?;
    socket.bind(&addr.into())?;
    Ok(socket.into())
}

/// Applies the largest acceptable bound from `UDP_SOCKET_BUFFER_BYTES`.
/// Only the smallest bound is allowed to fail the bind.
fn set_bounded_buffer(mut apply: impl FnMut(usize) -> io::Result<()>) -> io::Result<()> {
    let mut last_error = None;
    for bytes in UDP_SOCKET_BUFFER_BYTES {
        match apply(*bytes) {
            Ok(()) => return Ok(()),
            Err(error) => last_error = Some(error),
        }
    }
    Err(last_error.unwrap_or_else(|| io::Error::other("no UDP socket buffer bound configured")))
}

/// Restores blocking mode even when a drain exits through an error path.
struct NonblockingReceive<'a> {
    socket: &'a UdpSocket,
    active: bool,
}

impl<'a> NonblockingReceive<'a> {
    fn enable_unless(socket: &'a UdpSocket, already_nonblocking: bool) -> io::Result<Self> {
        if !already_nonblocking {
            socket.set_nonblocking(true)?;
        }
        Ok(Self {
            socket,
            active: !already_nonblocking,
        })
    }

    fn restore(&mut self) -> io::Result<()> {
        if self.active {
            self.socket.set_nonblocking(false)?;
            self.active = false;
        }
        Ok(())
    }
}

impl Drop for NonblockingReceive<'_> {
    fn drop(&mut self) {
        let _ = self.restore();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn receive_scratch_is_reused_across_datagrams() {
        let receiver = Udp::bind("127.0.0.1", 0).unwrap();
        receiver.set_timeout(0.5).unwrap();
        let sender = UdpSocket::bind("127.0.0.1:0").unwrap();
        let destination = receiver.local_addr().unwrap();
        let scratch = receiver.lock_receive().unwrap().scratch.as_ptr();

        for payload in [b"first".as_slice(), b"second".as_slice()] {
            sender.send_to(payload, destination).unwrap();
            assert_eq!(receiver.recv_vec().unwrap().0, payload);
            assert_eq!(receiver.lock_receive().unwrap().scratch.as_ptr(), scratch);
        }
    }

    #[test]
    fn connection_reset_is_counted_as_an_empty_receive() {
        let udp = Udp::bind("127.0.0.1", 0).unwrap();
        let reset: io::Result<Option<()>> =
            udp.absorb_empty_receive(io::ErrorKind::ConnectionReset.into());
        assert_eq!(reset.unwrap(), None);
        let empty: io::Result<Option<()>> =
            udp.absorb_empty_receive(io::ErrorKind::WouldBlock.into());
        assert_eq!(empty.unwrap(), None);
        let fatal: io::Result<Option<()>> =
            udp.absorb_empty_receive(io::ErrorKind::PermissionDenied.into());
        assert!(fatal.is_err());
        assert_eq!(udp.take_transient_receive_errors(), 1);
        assert_eq!(udp.take_transient_receive_errors(), 0);
    }

    #[test]
    fn media_nonblocking_mode_is_sticky_but_control_poll_is_temporary() {
        let control = Udp::bind("127.0.0.1", 0).unwrap();
        assert_eq!(control.try_recv_vec().unwrap(), None);
        assert!(!control.lock_receive().unwrap().permanently_nonblocking);

        let media = Udp::bind("127.0.0.1", 0).unwrap();
        media.configure_media_nonblocking().unwrap();
        assert_eq!(media.try_recv(|_, _| Some(())).unwrap(), None);
        assert!(media.lock_receive().unwrap().permanently_nonblocking);
        media.configure_media_nonblocking().unwrap();
        assert!(media.lock_receive().unwrap().permanently_nonblocking);
    }
}
