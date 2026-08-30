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
    receive_lock: Mutex<()>,
}

impl Udp {
    pub fn new() -> io::Result<Self> {
        // Use an ephemeral port while retaining bounded kernel buffers.
        let sock = bounded_udp_socket("0.0.0.0:0")?;
        Ok(Self {
            sock,
            receive_lock: Mutex::new(()),
        })
    }

    pub fn bind(host: &str, port: u16) -> io::Result<Self> {
        let addr = format!("{host}:{port}");
        let sock = bounded_udp_socket(&addr)?;
        Ok(Self {
            sock,
            receive_lock: Mutex::new(()),
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
        let _receive_lock = self.lock_receive()?;
        self.sock.recv_from(buf)
    }

    pub fn recv_vec(&self) -> io::Result<(Vec<u8>, SocketAddr)> {
        let _receive_lock = self.lock_receive()?;
        self.recv_vec_unlocked()
    }

    /// Performs one receive without waiting, preserving the socket's configured
    /// blocking mode and timeout for negotiation callers.
    pub(crate) fn try_recv_vec(&self) -> io::Result<Option<(Vec<u8>, SocketAddr)>> {
        let _receive_lock = self.lock_receive()?;
        let mut nonblocking = NonblockingReceive::enable(&self.sock)?;
        let received = match self.recv_vec_unlocked() {
            Ok(datagram) => Ok(Some(datagram)),
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
    pub(crate) fn try_recv_vec_latest<T, F>(&self, mut classify: F) -> io::Result<(Option<T>, u64)>
    where
        F: FnMut(Vec<u8>, SocketAddr) -> Option<T>,
    {
        let _receive_lock = self.lock_receive()?;
        let mut nonblocking = NonblockingReceive::enable(&self.sock)?;
        let first = match self.recv_vec_unlocked() {
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
        let Some((payload, peer)) = first else {
            nonblocking.restore()?;
            return Ok((None, 0));
        };
        let Some(mut latest) = classify(payload, peer) else {
            nonblocking.restore()?;
            return Ok((None, 0));
        };
        let drain_result = drain_latest(&mut latest, &mut classify, || self.recv_vec_unlocked());
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

    fn lock_receive(&self) -> io::Result<MutexGuard<'_, ()>> {
        self.receive_lock.lock().map_err(|_| {
            io::Error::other("UDP receive state lock was poisoned by a previous panic")
        })
    }

    fn recv_vec_unlocked(&self) -> io::Result<(Vec<u8>, SocketAddr)> {
        let mut buf = vec![0u8; 65535];
        let (n, addr) = self.sock.recv_from(&mut buf)?;
        buf.truncate(n);
        Ok((buf, addr))
    }
}

fn drain_latest<T, F, R>(latest: &mut T, classify: &mut F, mut receive: R) -> io::Result<u64>
where
    F: FnMut(Vec<u8>, SocketAddr) -> Option<T>,
    R: FnMut() -> io::Result<(Vec<u8>, SocketAddr)>,
{
    let mut replacements = 0;
    for _ in 0..MAX_UDP_DRAIN_DATAGRAMS {
        match receive() {
            Ok((payload, peer)) => {
                if let Some(datagram) = classify(payload, peer) {
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
    fn enable(socket: &'a UdpSocket) -> io::Result<Self> {
        socket.set_nonblocking(true)?;
        Ok(Self {
            socket,
            active: true,
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
