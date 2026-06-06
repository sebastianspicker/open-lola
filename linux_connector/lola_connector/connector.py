"""Async LoLa connector skeleton for Linux."""

from __future__ import annotations

import asyncio
from contextlib import ExitStack, contextmanager
from dataclasses import dataclass, replace
import logging
import socket
from collections.abc import Awaitable, Callable, Iterator
from typing import TypeVar, cast

from .media import (
    Fragment,
    MediaReassembler,
    VideoPrelude,
    build_audio_payload,
    build_video_payloads,
    parse_media_payload,
    parse_serialized_media,
)
from .protocol import (
    DEFAULT_AUDIO_PORT,
    DEFAULT_CONTROL_PORT,
    DEFAULT_VIDEO_PORT,
    MESG_CHAT,
    MESG_CHECKLOLASTATUS,
    MESG_CHECKLOLASTATUS_ACK,
    MESG_DISCONNECT,
    MESG_QUICKCONN,
    MESG_QUICKCONN_ACK,
    MESG_REJECT,
    MESG_SEND_AUDIO_SIGNAL,
    MESG_STOP_AUDIO_SIGNAL,
    MediaSettings,
    ControlMessage,
    build_control_datagram,
    build_osc15_control_datagram,
    message_ip,
    parse_control_datagram,
)

logger = logging.getLogger(__name__)
ControlResult = TypeVar("ControlResult")
_socket_read_locks: dict[int, asyncio.Lock] = {}
_socket_write_locks: dict[int, asyncio.Lock] = {}


@dataclass
class Session:
    local_ip: str
    remote_ip: str
    sid: int
    remote_settings: MediaSettings


@dataclass(frozen=True)
class StatusCheckResult:
    acknowledged: bool
    reason: str
    response_ip: str | None = None
    response_kind: str | None = None
    malformed_datagrams: int = 0
    wrong_peer_datagrams: int = 0
    unexpected_datagrams: int = 0
    sent_dialects: tuple[str, ...] = ()

    def __bool__(self) -> bool:
        return self.acknowledged


@dataclass(frozen=True)
class LolaConnectorOptions:
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
class QuickConnResult:
    session: Session | None
    reason: str
    response_ip: str | None = None
    response_kind: str | None = None
    response_text: str = ""
    malformed_datagrams: int = 0
    wrong_peer_datagrams: int = 0
    unexpected_datagrams: int = 0

    def __bool__(self) -> bool:
        return self.session is not None


async def udp_recvfrom(sock: socket.socket, size: int) -> tuple[bytes, tuple[str, int]]:
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
        except Exception as exc:
            future.set_exception(exc)

    loop.add_reader(sock.fileno(), readable)
    try:
        readable()
        return await future
    finally:
        loop.remove_reader(sock.fileno())


async def udp_sendto(sock: socket.socket, data: bytes, address: tuple[str, int]) -> None:
    async with _socket_lock(_socket_write_locks, sock):
        await _udp_sendto_unlocked(sock, data, address)


async def _udp_sendto_unlocked(sock: socket.socket, data: bytes, address: tuple[str, int]) -> None:
    loop = asyncio.get_running_loop()
    sock_sendto = getattr(loop, "sock_sendto", None)
    if sock_sendto is not None:
        await sock_sendto(sock, data, address)
        return
    future: asyncio.Future[None] = loop.create_future()

    def writable() -> None:
        if future.done():
            return
        try:
            sock.sendto(data, address)
        except BlockingIOError:
            return
        except Exception as exc:
            future.set_exception(exc)
        else:
            future.set_result(None)

    loop.add_writer(sock.fileno(), writable)
    try:
        writable()
        await future
    finally:
        loop.remove_writer(sock.fileno())


def _socket_lock(locks: dict[int, asyncio.Lock], sock: socket.socket) -> asyncio.Lock:
    fileno = sock.fileno()
    lock = locks.get(fileno)
    if lock is None:
        lock = asyncio.Lock()
        locks[fileno] = lock
    return lock


def unregister_udp_socket(sock: socket.socket) -> None:
    try:
        fileno = sock.fileno()
    except (AttributeError, OSError):
        return
    if fileno < 0:
        return
    _socket_read_locks.pop(fileno, None)
    _socket_write_locks.pop(fileno, None)


def close_udp_socket(sock: socket.socket) -> None:
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

    values = dict(zip(names, positional, strict=False))
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


class LolaConnector:
    def __init__(
        self,
        local_ip: str,
        settings: MediaSettings | None = None,
        *legacy_args: object,
        options: LolaConnectorOptions | None = None,
        **legacy_options: object,
    ) -> None:
        resolved = _connector_options_from_legacy(legacy_args, legacy_options, options)
        self.local_ip = local_ip
        self.settings = settings or MediaSettings()
        self.control_port = resolved.control_port
        self.audio_port = resolved.audio_port
        self.video_port = resolved.video_port
        self.video_packet_size = resolved.video_packet_size
        self.control_dialect = resolved.control_dialect
        self.source_name = resolved.source_name
        self.session: Session | None = None
        self._audio_send_sock: socket.socket | None = None
        self._video_send_sock: socket.socket | None = None

    def make_udp_socket(self, bind_port: int = 0) -> socket.socket:
        """Create a nonblocking UDP socket bound to LoLa's negotiated local IP.

        Binding media sockets to 19788/19798 is important: Windows LoLa's pcap
        filters and packet parser expect both source and destination stream
        ports to match the configured LoLa audio/video ports.
        """
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            if hasattr(socket, "SO_REUSEPORT"):
                try:
                    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
                except OSError as exc:
                    logger.warning("SO_REUSEPORT unavailable on UDP socket for %s:%s: %s", self.local_ip, bind_port, exc)
            sock.setblocking(False)
            sock.bind((self.local_ip, bind_port))
        except OSError as exc:
            logger.warning(
                "UDP socket setup failed for %s:%s errno=%s: %s",
                self.local_ip,
                bind_port,
                exc.errno,
                exc,
            )
            close_udp_socket(sock)
            raise
        except Exception:
            close_udp_socket(sock)
            raise
        return sock

    @contextmanager
    def udp_socket(self, bind_port: int = 0) -> Iterator[socket.socket]:
        sock = self.make_udp_socket(bind_port)
        try:
            yield sock
        finally:
            close_udp_socket(sock)

    async def _receive_control_until(
        self,
        sock: socket.socket,
        handler: Callable[[ControlMessage, tuple[str, int]], Awaitable[ControlResult | None]],
        on_timeout: Callable[[], ControlResult],
        *,
        timeout: float | None = None,
        stats: _ControlReceiveStats | None = None,
    ) -> ControlResult:
        loop = asyncio.get_running_loop()
        deadline = None if timeout is None else loop.time() + timeout
        while deadline is None or loop.time() < deadline:
            received = await self._receive_control_datagram(sock, deadline)
            if received is None:
                return on_timeout()
            data, addr = received
            result = await self._dispatch_control_datagram(data, addr, handler, stats)
            if result is not None:
                return result

        return on_timeout()

    async def _receive_control_datagram(
        self,
        sock: socket.socket,
        deadline: float | None,
    ) -> tuple[bytes, tuple[str, int]] | None:
        try:
            receive = udp_recvfrom(sock, 4096)
            if deadline is None:
                return await receive
            return await asyncio.wait_for(receive, timeout=deadline - asyncio.get_running_loop().time())
        except asyncio.TimeoutError:
            return None

    async def _dispatch_control_datagram(
        self,
        data: bytes,
        addr: tuple[str, int],
        handler: Callable[[ControlMessage, tuple[str, int]], Awaitable[ControlResult | None]],
        stats: _ControlReceiveStats | None,
    ) -> ControlResult | None:
        msg = parse_control_datagram(data)
        if msg is None:
            if stats is not None:
                stats.malformed_datagrams += 1
            return None

        try:
            return await handler(msg, addr)
        except ValueError:
            if stats is not None:
                stats.malformed_datagrams += 1
            logger.warning("ignored malformed LoLa control datagram from %s", addr[0], exc_info=True)
            return None

    async def initiate(self, remote_ip: str, sid: int = 0, timeout: float = 2.0) -> Session:
        result = await self.initiate_result(remote_ip, sid, timeout=timeout)
        if result.session is not None:
            return result.session
        if result.reason == "rejected":
            raise RuntimeError(result.response_text or "LoLa rejected QuickConn")
        raise TimeoutError("LoLa QuickConn ACK timed out")

    async def initiate_result(self, remote_ip: str, sid: int = 0, timeout: float = 2.0) -> QuickConnResult:
        stats = _ControlReceiveStats()
        with self.udp_socket(self.control_port) as sock:
            await self._send_control(sock, MESG_QUICKCONN, remote_ip, sid)

            async def handle_quickconn_ack(msg: ControlMessage, addr: tuple[str, int]) -> QuickConnResult | None:
                return self._handle_quickconn_ack(msg, addr, remote_ip, sid, stats)

            def quickconn_timeout() -> QuickConnResult:
                return _quickconn_timeout_result(stats)

            return await self._receive_control_until(
                sock,
                handle_quickconn_ack,
                quickconn_timeout,
                timeout=timeout,
                stats=stats,
            )

    def _handle_quickconn_ack(
        self,
        msg: ControlMessage,
        addr: tuple[str, int],
        remote_ip: str,
        sid: int,
        stats: _ControlReceiveStats,
    ) -> QuickConnResult | None:
        if addr[0] != remote_ip:
            stats.wrong_peer_datagrams += 1
            return None
        if msg.kind == MESG_REJECT:
            return _rejected_quickconn_result(msg, addr, stats)
        if msg.kind != MESG_QUICKCONN_ACK:
            stats.unexpected_datagrams += 1
            return None

        remote_settings = self.settings_from_quickconn_ack(msg)
        self.close_media_sockets()
        self.session = Session(self.local_ip, remote_ip, sid, remote_settings)
        return _accepted_quickconn_result(self.session, msg, addr, stats)

    async def check_status_result(self, remote_ip: str, sid: int = 0, timeout: float = 2.0) -> StatusCheckResult:
        sent_dialects = ("ascii", "osc15") if self.control_dialect == "auto" else (self.control_dialect,)
        state = _StatusProbeState(stats=_ControlReceiveStats())
        with self.udp_socket(self.control_port) as sock:
            await self._send_status_probes(sock, remote_ip, sid)

            async def handle_status_response(msg: ControlMessage, addr: tuple[str, int]) -> StatusCheckResult | None:
                return _handle_status_response(msg, addr, remote_ip, sent_dialects, state)

            return await self._receive_control_until(
                sock,
                handle_status_response,
                lambda: _status_timeout_result(state, sent_dialects),
                timeout=timeout,
                stats=state.stats,
            )

    async def _send_status_probes(self, sock: socket.socket, remote_ip: str, sid: int) -> None:
        if self.control_dialect == "auto":
            await self._send_control(sock, MESG_CHECKLOLASTATUS, remote_ip, sid, dialect="ascii")
            await self._send_control(sock, MESG_CHECKLOLASTATUS, remote_ip, sid, dialect="osc15")
            return
        await self._send_control(sock, MESG_CHECKLOLASTATUS, remote_ip, sid)

    async def check_status(self, remote_ip: str, sid: int = 0, timeout: float = 2.0) -> bool:
        return (await self.check_status_result(remote_ip, sid, timeout=timeout)).acknowledged

    async def accept_once(self, timeout: float | None = None, ready_event: asyncio.Event | None = None) -> Session:
        """Accept one incoming LoLa QuickConn and establish a session."""
        with self.udp_socket(self.control_port) as sock:
            if ready_event is not None:
                ready_event.set()

            async def handle_incoming_control(msg: ControlMessage, addr: tuple[str, int]) -> Session | None:
                return await self._handle_incoming_control(sock, msg, addr)

            def accept_timeout() -> Session:
                raise TimeoutError("LoLa QuickConn did not arrive")

            return await self._receive_control_until(sock, handle_incoming_control, accept_timeout, timeout=timeout)

    async def _handle_incoming_control(
        self,
        sock: socket.socket,
        msg: ControlMessage,
        addr: tuple[str, int],
    ) -> Session | None:
        response_ip = message_ip(msg, addr[0])
        if msg.kind == MESG_CHECKLOLASTATUS:
            await self._send_control(sock, MESG_CHECKLOLASTATUS_ACK, response_ip, msg.sid, dialect=msg.dialect)
            return None
        if msg.kind != MESG_QUICKCONN:
            return None

        remote_settings = MediaSettings.from_fields(msg.fields, self.settings)
        if not self.settings.compatible_audio(remote_settings):
            await self._reject_incompatible_quickconn(sock, msg, addr, response_ip, remote_settings)
            return None

        ack_settings = self._quickconn_ack_settings(msg, remote_settings)
        await self._send_control(
            sock,
            MESG_QUICKCONN_ACK,
            response_ip,
            msg.sid,
            dialect=msg.dialect,
            settings=ack_settings,
        )
        logger.info(
            "accepted QuickConn: "
            f"sender={addr[0]} src={msg.src_ip!r} dialect={msg.dialect} "
            f"remote_settings={remote_settings}"
        )
        self.close_media_sockets()
        self.session = Session(self.local_ip, response_ip, msg.sid, remote_settings)
        return self.session

    async def _reject_incompatible_quickconn(
        self,
        sock: socket.socket,
        msg: ControlMessage,
        addr: tuple[str, int],
        response_ip: str,
        remote_settings: MediaSettings,
    ) -> None:
        logger.info(
            "rejecting QuickConn: "
            f"sender={addr[0]} src={msg.src_ip!r} dialect={msg.dialect} "
            f"remote_settings={remote_settings} local_settings={self.settings}"
        )
        await self._send_control(
            sock,
            MESG_REJECT,
            response_ip,
            msg.sid,
            txt=self._compat_error(remote_settings),
            dialect=msg.dialect,
        )

    def _quickconn_ack_settings(
        self,
        msg: ControlMessage,
        remote_settings: MediaSettings,
    ) -> MediaSettings:
        if msg.dialect != "osc15":
            return self.settings
        return replace(self.settings, bayer=remote_settings.bayer)

    def handle_control_message(self, msg: ControlMessage, sender_ip: str | None = None) -> str:
        """Update local state for non-handshake control messages.

        Returns a small action label so host applications can decide how to
        surface chat, disconnects, and audio test-signal requests.
        """
        if msg.kind == MESG_DISCONNECT:
            return self._handle_disconnect_control(msg, sender_ip)
        if msg.kind == MESG_SEND_AUDIO_SIGNAL:
            return self._session_action(msg, sender_ip, "send_audio_signal")
        if msg.kind == MESG_STOP_AUDIO_SIGNAL:
            return self._session_action(msg, sender_ip, "stop_audio_signal")
        return _stateless_control_action(msg)

    def _handle_disconnect_control(self, msg: ControlMessage, sender_ip: str | None) -> str:
        if not self._matches_active_session_control(msg, sender_ip):
            return "ignore"
        self.session = None
        self.close_media_sockets()
        return "disconnect"

    def _session_action(self, msg: ControlMessage, sender_ip: str | None, action: str) -> str:
        return action if self._matches_active_session_control(msg, sender_ip) else "ignore"

    def _matches_active_session_control(self, msg: ControlMessage, sender_ip: str | None) -> bool:
        session = self.session
        if session is None or sender_ip is None:
            return False
        remote_ip = message_ip(msg, sender_ip)
        return sender_ip == session.remote_ip and remote_ip == session.remote_ip and msg.sid == session.sid

    def settings_from_quickconn_ack(self, msg: ControlMessage) -> MediaSettings:
        """Return peer media settings from a QuickConn ACK control message."""
        settings = MediaSettings.from_fields(msg.fields, self.settings)
        if msg.dialect == "osc15":
            # OSC15 ACKs mirror the initiator's Bayer marker; keep that rule
            # symmetric with the accept-side ACK builder.
            return replace(settings, bayer=self.settings.bayer)
        return settings

    async def _send_control(
        self,
        sock: socket.socket,
        kind: str,
        remote_ip: str,
        sid: int,
        txt: str = "",
        dialect: str | None = None,
        settings: MediaSettings | None = None,
    ) -> None:
        """Send one padded LoLa control datagram in the selected dialect."""
        selected = dialect or self.control_dialect
        if selected == "osc15":
            datagram = build_osc15_control_datagram(
                kind,
                self.local_ip,
                remote_ip,
                sid,
                settings or self.settings,
                txt,
                source_name=self.source_name,
            )
        else:
            datagram = build_control_datagram(kind, self.local_ip, remote_ip, sid, settings or self.settings, txt)
        await udp_sendto(sock, datagram, (remote_ip, self.control_port))

    async def send_control_once(self, kind: str, remote_ip: str, sid: int = 0, txt: str = "") -> None:
        with self.udp_socket(0) as sock:
            await self._send_control(sock, kind, remote_ip, sid, txt)

    async def send_chat(self, txt: str) -> None:
        if self.session is None:
            raise RuntimeError("no active LoLa session")
        await self.send_control_once(MESG_CHAT, self.session.remote_ip, self.session.sid, txt)

    async def send_disconnect(self) -> None:
        if self.session is None:
            return
        session = self.session
        await self.send_control_once(MESG_DISCONNECT, session.remote_ip, session.sid)
        self.session = None
        self.close_media_sockets()

    def _compat_error(self, remote: MediaSettings) -> str:
        return (
            "Unable to establish a valid connection due to the following reason(s): "
            f"local audio {self.settings.channels}ch/{self.settings.sample_rate}Hz/"
            f"{self.settings.bits_per_sample}bit, remote audio "
            f"{remote.channels}ch/{remote.sample_rate}Hz/{remote.bits_per_sample}bit."
        )

    async def send_audio(self, pcm: bytes, sequence: int) -> None:
        if self.session is None:
            raise RuntimeError("no active LoLa session")
        await self.send_audio_on_socket(self._media_send_socket("audio"), pcm, sequence)

    async def send_video(self, frame: bytes, sequence: int) -> None:
        if self.session is None:
            raise RuntimeError("no active LoLa session")
        await self.send_video_on_socket(self._media_send_socket("video"), frame, sequence)

    def _media_send_socket(self, stream: str) -> socket.socket:
        if stream == "audio":
            if self._audio_send_sock is None:
                self._audio_send_sock = self.make_udp_socket(self.audio_port)
            return self._audio_send_sock
        if stream == "video":
            if self._video_send_sock is None:
                self._video_send_sock = self.make_udp_socket(self.video_port)
            return self._video_send_sock
        raise ValueError(f"unknown media stream: {stream}")

    def close_media_sockets(self) -> None:
        if self._audio_send_sock is not None:
            close_udp_socket(self._audio_send_sock)
            self._audio_send_sock = None
        if self._video_send_sock is not None:
            close_udp_socket(self._video_send_sock)
            self._video_send_sock = None

    async def aclose(self) -> None:
        self.close_media_sockets()

    async def send_audio_on_socket(self, sock: socket.socket, pcm: bytes, sequence: int) -> None:
        session = self.session
        if session is None:
            raise RuntimeError("no active LoLa session")
        payload = build_audio_payload(sequence, pcm)
        await udp_sendto(sock, payload, (session.remote_ip, self.audio_port))

    async def send_video_on_socket(self, sock: socket.socket, frame: bytes, sequence: int) -> None:
        session = self.session
        if session is None:
            raise RuntimeError("no active LoLa session")
        for index, payload in enumerate(build_video_payloads(sequence, frame, packet_size=self.video_packet_size)):
            await udp_sendto(sock, payload, (session.remote_ip, self.video_port))
            if index and index % 16 == 0:
                # Raw 640x480 frames are many UDP fragments. Yield so audio can
                # keep its 64-frame cadence while video is being flushed.
                await asyncio.sleep(0)

    async def recv_media_forever(self) -> None:
        audio_reasm = MediaReassembler()
        video_reasm = MediaReassembler()
        with ExitStack() as stack:
            audio_sock = stack.enter_context(self.udp_socket(self.audio_port))
            video_sock = stack.enter_context(self.udp_socket(self.video_port))
            await asyncio.gather(
                self._recv_stream(audio_sock, audio_reasm, "audio"),
                self._recv_stream(video_sock, video_reasm, "video"),
            )

    async def _recv_stream(self, sock: socket.socket, reasm: MediaReassembler, name: str) -> None:
        while True:
            payload, addr = await udp_recvfrom(sock, 65535)
            session = self.session
            if session is None:
                continue
            if addr[0] != session.remote_ip:
                continue
            try:
                item = parse_media_payload(payload)
                if isinstance(item, VideoPrelude):
                    reasm.begin(item.frame_id, item.expected_size, item.fragment_count)
                    continue
                if not isinstance(item, Fragment):
                    continue
                assembled = reasm.add(item)
                if assembled is None:
                    continue
                sequence, media = parse_serialized_media(assembled)
            except ValueError:
                logger.warning("ignored malformed LoLa %s media payload from=%s", name, addr[0], exc_info=True)
                continue
            logger.info("%s seq=%s bytes=%s from=%s", name, sequence, len(media), addr[0])
