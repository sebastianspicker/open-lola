# pylint: disable=missing-function-docstring
"""Async LoLa connector skeleton for Linux."""

from __future__ import annotations

import asyncio
from dataclasses import dataclass
import importlib
import logging
import socket
from typing import TYPE_CHECKING, TypeVar, cast

from .protocol import (
    DEFAULT_AUDIO_PORT,
    DEFAULT_CONTROL_PORT,
    DEFAULT_VIDEO_PORT,
    MESG_CHAT,
    MESG_CHECKLOLASTATUS_ACK,
    MESG_REJECT,
    MediaSettings,
    ControlMessage,
)

logger = logging.getLogger(__name__)
ControlResult = TypeVar("ControlResult")
_socket_read_locks: dict[int, asyncio.Lock] = {}
_socket_write_locks: dict[int, asyncio.Lock] = {}


@dataclass
class Session:
    """Bind negotiated peer settings and identifiers to one LoLa media session."""
    local_ip: str
    remote_ip: str
    sid: int
    remote_settings: MediaSettings


@dataclass(frozen=True)
class StatusCheckResult:  # pylint: disable=too-many-instance-attributes
    """Report status-probe acknowledgement and rejected-datagram evidence."""
    acknowledged: bool
    reason: str
    response_ip: str | None = None
    response_kind: str | None = None
    malformed_datagrams: int = 0
    wrong_peer_datagrams: int = 0
    unexpected_datagrams: int = 0
    sent_dialects: tuple[str, ...] = ()

    def __bool__(self) -> bool:
        """Return whether the status probe was acknowledged."""
        return self.acknowledged


@dataclass(frozen=True)
class LolaConnectorOptions:
    """Collect optional connector behavior that preserves legacy call compatibility."""
    control_port: int = DEFAULT_CONTROL_PORT
    audio_port: int = DEFAULT_AUDIO_PORT
    video_port: int = DEFAULT_VIDEO_PORT
    video_packet_size: int = 1000
    control_dialect: str = "ascii"
    source_name: str = ""


@dataclass
class _ControlReceiveStats:
    malformed_datagrams: int = 0
    wrong_peer_datagrams: int = 0
    unexpected_datagrams: int = 0


@dataclass
class _StatusProbeState:
    stats: _ControlReceiveStats
    response_ip: str | None = None
    response_kind: str | None = None
    reason: str = "timeout"


@dataclass(frozen=True)
class QuickConnResult:  # pylint: disable=too-many-instance-attributes
    """Report QuickConn acceptance, peer metadata, and rejection evidence."""
    session: Session | None
    reason: str
    response_ip: str | None = None
    response_kind: str | None = None
    response_text: str = ""
    malformed_datagrams: int = 0
    wrong_peer_datagrams: int = 0
    unexpected_datagrams: int = 0

    def __bool__(self) -> bool:
        """Return whether QuickConn produced a session."""
        return self.session is not None


async def udp_recvfrom(sock: socket.socket, size: int) -> tuple[bytes, tuple[str, int]]:
    """Serialize reads per socket while awaiting one nonblocking UDP datagram."""
    async with _socket_lock(_socket_read_locks, sock):
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
    """Attempt one UDP datagram immediately without waiting for writability.

    A realtime media sender must not turn a full kernel send buffer into an
    unbounded deadline delay.  ``False`` therefore means the datagram was not
    accepted because the nonblocking socket would block; other socket errors
    remain observable by the caller.
    """
    try:
        sent = sock.sendto(data, address)
    except BlockingIOError:
        return False
    if sent != len(data):
        raise OSError(f"partial UDP datagram send: {sent} of {len(data)} bytes")
    return True


def _socket_lock(locks: dict[int, asyncio.Lock], sock: socket.socket) -> asyncio.Lock:
    fileno = sock.fileno()
    lock = locks.get(fileno)
    if lock is None:
        lock = asyncio.Lock()
        locks[fileno] = lock
    return lock


def unregister_udp_socket(sock: socket.socket) -> None:
    """Drop cached read and write locks before a socket descriptor can be reused."""
    try:
        fileno = sock.fileno()
    except (AttributeError, OSError):
        return
    if fileno < 0:
        return
    _socket_read_locks.pop(fileno, None)
    _socket_write_locks.pop(fileno, None)


def close_udp_socket(sock: socket.socket) -> None:
    """Remove per-socket lock state, then close the underlying UDP socket."""
    unregister_udp_socket(sock)
    sock.close()


def _control_receive_failure_reason(stats: _ControlReceiveStats) -> str:
    if stats.unexpected_datagrams:
        return "unexpected-response"
    if stats.wrong_peer_datagrams:
        return "wrong-peer"
    if stats.malformed_datagrams:
        return "malformed-response"
    return "timeout"


def _quickconn_timeout_result(stats: _ControlReceiveStats) -> QuickConnResult:
    return QuickConnResult(
        session=None,
        reason=_control_receive_failure_reason(stats),
        malformed_datagrams=stats.malformed_datagrams,
        wrong_peer_datagrams=stats.wrong_peer_datagrams,
        unexpected_datagrams=stats.unexpected_datagrams,
    )


def _rejected_quickconn_result(
    msg: ControlMessage,
    addr: tuple[str, int],
    stats: _ControlReceiveStats,
) -> QuickConnResult:
    return QuickConnResult(
        session=None,
        reason="rejected",
        response_ip=addr[0],
        response_kind=msg.kind,
        response_text=msg.txt,
        malformed_datagrams=stats.malformed_datagrams,
        wrong_peer_datagrams=stats.wrong_peer_datagrams,
        unexpected_datagrams=stats.unexpected_datagrams,
    )


def _accepted_quickconn_result(
    session: Session,
    msg: ControlMessage,
    addr: tuple[str, int],
    stats: _ControlReceiveStats,
) -> QuickConnResult:
    return QuickConnResult(
        session=session,
        reason="ack",
        response_ip=addr[0],
        response_kind=msg.kind,
        malformed_datagrams=stats.malformed_datagrams,
        wrong_peer_datagrams=stats.wrong_peer_datagrams,
        unexpected_datagrams=stats.unexpected_datagrams,
    )


def _handle_status_response(
    msg: ControlMessage,
    addr: tuple[str, int],
    remote_ip: str,
    sent_dialects: tuple[str, ...],
    state: _StatusProbeState,
) -> StatusCheckResult | None:
    if addr[0] != remote_ip:
        state.stats.wrong_peer_datagrams += 1
        state.response_ip = addr[0]
        state.reason = "wrong-peer"
        return None
    if msg.kind != MESG_CHECKLOLASTATUS_ACK:
        state.stats.unexpected_datagrams += 1
        state.response_ip = addr[0]
        state.response_kind = msg.kind
        state.reason = "unexpected-response"
        return None

    return StatusCheckResult(
        acknowledged=True,
        reason="ack",
        response_ip=addr[0],
        response_kind=msg.kind,
        malformed_datagrams=state.stats.malformed_datagrams,
        wrong_peer_datagrams=state.stats.wrong_peer_datagrams,
        unexpected_datagrams=state.stats.unexpected_datagrams,
        sent_dialects=sent_dialects,
    )


def _status_timeout_result(
    state: _StatusProbeState,
    sent_dialects: tuple[str, ...],
) -> StatusCheckResult:
    if state.reason == "timeout" and state.stats.malformed_datagrams:
        state.reason = "malformed-response"
    return StatusCheckResult(
        acknowledged=False,
        reason=state.reason,
        response_ip=state.response_ip,
        response_kind=state.response_kind,
        malformed_datagrams=state.stats.malformed_datagrams,
        wrong_peer_datagrams=state.stats.wrong_peer_datagrams,
        unexpected_datagrams=state.stats.unexpected_datagrams,
        sent_dialects=sent_dialects,
    )


def _stateless_control_action(msg: ControlMessage) -> str:
    if msg.kind == MESG_CHAT:
        return "chat"
    if msg.kind == MESG_REJECT:
        return "reject"
    return "ignore"


def _connector_options_from_legacy(
    positional: tuple[object, ...],
    keywords: dict[str, object],
    options: LolaConnectorOptions | None,
) -> LolaConnectorOptions:
    if options is not None and (positional or keywords):
        raise TypeError("LolaConnector options cannot be combined with legacy port arguments")

    values = _legacy_option_values(positional, keywords)
    return options or LolaConnectorOptions(
        control_port=_legacy_int(values, "control_port"),
        audio_port=_legacy_int(values, "audio_port"),
        video_port=_legacy_int(values, "video_port"),
        video_packet_size=_legacy_int(values, "video_packet_size"),
        control_dialect=_legacy_str(values, "control_dialect"),
        source_name=_legacy_str(values, "source_name"),
    )


def _legacy_option_values(
    positional: tuple[object, ...],
    keywords: dict[str, object],
) -> dict[str, object]:
    names = (
        "control_port",
        "audio_port",
        "video_port",
        "video_packet_size",
        "control_dialect",
        "source_name",
    )
    if len(positional) > len(names):
        raise TypeError("too many positional arguments for LolaConnector")

    values: dict[str, object] = dict(zip(names, positional, strict=False))
    duplicates = set(values).intersection(keywords)
    if duplicates:
        duplicate = sorted(duplicates)[0]
        raise TypeError(f"LolaConnector got multiple values for {duplicate}")
    values.update(keywords)
    return values


def _legacy_int(values: dict[str, object], name: str) -> int:
    defaults = LolaConnectorOptions()
    value = values.get(name, getattr(defaults, name))
    if not isinstance(value, int):
        raise TypeError(f"LolaConnector {name} must be int")
    return value


def _legacy_str(values: dict[str, object], name: str) -> str:
    defaults = LolaConnectorOptions()
    value = values.get(name, getattr(defaults, name))
    if not isinstance(value, str):
        raise TypeError(f"LolaConnector {name} must be str")
    return value


if TYPE_CHECKING:
    from .connector_impl import LolaConnector
else:
    LolaConnector = importlib.import_module(".connector_impl", __package__).LolaConnector
