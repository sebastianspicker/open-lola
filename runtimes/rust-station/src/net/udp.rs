//! Thin UDP helper with bind / sendto / recvfrom and timeout.

use socket2::{Domain, Protocol, Socket, Type};
use std::io;
use std::net::{SocketAddr, ToSocketAddrs, UdpSocket};
use std::sync::{Mutex, MutexGuard};
use std::time::Duration;

/// Limits kernel UDP buffering so queued media cannot grow without bound.
const UDP_SOCKET_BUFFER_BYTES: usize = 256 * 1024;
const MAX_UDP_DRAIN_DATAGRAMS: usize = 256;

#[derive(Debug)]
pub struct Udp {
    sock: UdpSocket,
    receive_state: Mutex<ReceiveState>,
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
        })
    }

    pub fn bind(host: &str, port: u16) -> io::Result<Self> {
        let addr = format!("{host}:{port}");
        let sock = bounded_udp_socket(&addr)?;
        Ok(Self {
            sock,
            receive_state: Mutex::new(ReceiveState::new()),
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
            Err(error)
                if matches!(
                    error.kind(),
                    io::ErrorKind::WouldBlock | io::ErrorKind::TimedOut
                ) =>
            {
                Ok(None)
            }
            Err(error) => Err(error),
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
            Err(error)
                if matches!(
                    error.kind(),
                    io::ErrorKind::WouldBlock | io::ErrorKind::TimedOut
                ) =>
            {
                Ok(None)
            }
            Err(error) => Err(error),
        };
        let restore_result = nonblocking.restore();
        match received {
            Err(error) => Err(error),
            Ok(value) => restore_result.map(|()| value),
        }
    }

    /// Nonblocking variant used by deadline schedulers. It drains at most one
    /// bounded quantum after the first accepted datagram.
    pub(crate) fn try_recv_latest<T, F>(&self, mut classify: F) -> io::Result<(Option<T>, u64)>
    where
        F: FnMut(&[u8], SocketAddr) -> Option<T>,
    {
        let mut state = self.lock_receive()?;
        let mut nonblocking =
            NonblockingReceive::enable_unless(&self.sock, state.permanently_nonblocking)?;
        let first = match self.recv_into_scratch(&mut state) {
            Ok(datagram) => Some(datagram),
            Err(error)
                if matches!(
                    error.kind(),
                    io::ErrorKind::WouldBlock | io::ErrorKind::TimedOut
                ) =>
            {
                None
            }
            Err(error) => {
                let _ = nonblocking.restore();
                return Err(error);
            }
        };
        let Some((length, peer)) = first else {
            nonblocking.restore()?;
            return Ok((None, 0));
        };
        let Some(mut latest) = classify(&state.scratch[..length], peer) else {
            nonblocking.restore()?;
            return Ok((None, 0));
        };
        let drain_result = drain_latest(&mut latest, || {
            let (length, peer) = self.recv_into_scratch(&mut state)?;
            Ok(classify(&state.scratch[..length], peer))
        });
        let restore_result = nonblocking.restore();
        let replacements = match drain_result {
            Ok(replacements) => replacements,
            Err(error) => {
                let _ = restore_result;
                return Err(error);
            }
        };
        restore_result?;
        Ok((Some(latest), replacements))
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

fn drain_latest<T, R>(latest: &mut T, mut receive: R) -> io::Result<u64>
where
    R: FnMut() -> io::Result<Option<T>>,
{
    let mut replacements = 0;
    for _ in 0..MAX_UDP_DRAIN_DATAGRAMS {
        match receive() {
            Ok(datagram) => {
                if let Some(datagram) = datagram {
                    *latest = datagram;
                    replacements += 1;
                }
            }
            Err(error)
                if matches!(
                    error.kind(),
                    io::ErrorKind::WouldBlock | io::ErrorKind::TimedOut
                ) =>
            {
                break;
            }
            Err(error) => return Err(error),
        }
    }
    Ok(replacements)
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
    socket.set_recv_buffer_size(UDP_SOCKET_BUFFER_BYTES)?;
    socket.set_send_buffer_size(UDP_SOCKET_BUFFER_BYTES)?;
    socket.bind(&addr.into())?;
    Ok(socket.into())
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
