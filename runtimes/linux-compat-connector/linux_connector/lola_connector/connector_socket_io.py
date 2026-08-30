"""Nonblocking UDP I/O and per-socket serialization for the connector."""

from __future__ import annotations

import asyncio
import socket
from typing import cast

_read_locks: dict[int, asyncio.Lock] = {}
_write_locks: dict[int, asyncio.Lock] = {}


async def udp_recvfrom(sock: socket.socket, size: int) -> tuple[bytes, tuple[str, int]]:
    """Serialize reads per socket while awaiting one nonblocking UDP datagram."""
    async with _socket_lock(_read_locks, sock):
        return await _udp_recvfrom_unlocked(sock, size)


async def _udp_recvfrom_unlocked(sock: socket.socket, size: int) -> tuple[bytes, tuple[str, int]]:
    loop = asyncio.get_running_loop()
    sock_recvfrom = getattr(loop, "sock_recvfrom", None)
    if sock_recvfrom is not None:
        return cast(tuple[bytes, tuple[str, int]], await sock_recvfrom(sock, size))
    future: asyncio.Future[tuple[bytes, tuple[str, int]]] = loop.create_future()

    def readable() -> None:
        if future.done():
            return
        try:
            future.set_result(sock.recvfrom(size))
        except BlockingIOError:
            return
        except OSError as exc:
            future.set_exception(exc)

    loop.add_reader(sock.fileno(), readable)
    try:
        readable()
        return await future
    finally:
        loop.remove_reader(sock.fileno())


async def udp_sendto(sock: socket.socket, data: bytes, address: tuple[str, int]) -> bool:
    """Attempt one UDP datagram without turning backpressure into an await."""
    async with _socket_lock(_write_locks, sock):
        try:
            sent = sock.sendto(data, address)
        except BlockingIOError:
            return False
    if sent != len(data):
        raise OSError(f"partial UDP datagram send: {sent} of {len(data)} bytes")
    return True


def close_udp_socket(sock: socket.socket) -> None:
    """Forget socket lock state before closing its descriptor."""
    fileno = sock.fileno()
    if fileno >= 0:
        _read_locks.pop(fileno, None)
        _write_locks.pop(fileno, None)
    sock.close()


def _socket_lock(locks: dict[int, asyncio.Lock], sock: socket.socket) -> asyncio.Lock:
    fileno = sock.fileno()
    lock = locks.get(fileno)
    if lock is None:
        lock = asyncio.Lock()
        locks[fileno] = lock
    return lock
