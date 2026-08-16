# pylint: disable=missing-function-docstring
"""Main LoLa connector implementation."""

from __future__ import annotations

import asyncio
import logging
import socket
import time
from collections.abc import Awaitable, Callable, Iterator
from contextlib import contextmanager
from dataclasses import replace

from . import connector as connector_module
from .connector import (
    ControlResult,
    LolaConnectorOptions,
    QuickConnResult,
    Session,
    StatusCheckResult,
    _accepted_quickconn_result,
    _connector_options_from_legacy,
    _control_response_rejection_reason,
    _ControlReceiveStats,
    _ControlSendRequest,
    _handle_status_response,
    _quickconn_timeout_result,
    _record_control_response_rejection,
    _rejected_quickconn_result,
    _stateless_control_action,
    _status_timeout_result,
    _StatusProbeState,
    close_udp_socket,
)
from .connector_media_receive import LolaConnectorMediaReceiveMixin
from .connector_sockets import make_bound_udp_socket
from .media import (
    build_audio_payload,
    iter_video_payloads,
)
from .protocol import (
    MESG_CHAT,
    MESG_CHECKLOLASTATUS,
    MESG_CHECKLOLASTATUS_ACK,
    MESG_DISCONNECT,
    MESG_QUICKCONN,
    MESG_QUICKCONN_ACK,
    MESG_REJECT,
    MESG_SEND_AUDIO_SIGNAL,
    MESG_STOP_AUDIO_SIGNAL,
    ControlMessage,
    MediaSettings,
    build_control_datagram,
    build_osc15_control_datagram,
    parse_control_datagram,
)

logger = logging.getLogger(__name__)


class LolaConnector(LolaConnectorMediaReceiveMixin):  # pylint: disable=too-many-instance-attributes
    """Own LoLa UDP sockets, control exchanges, and negotiated media sessions."""

    def __init__(
        self,
        local_ip: str,
        *legacy_args: object,
        **legacy_options: object,
    ) -> None:
        """Create a connector while preserving legacy option arguments."""
        has_settings_keyword = "settings" in legacy_options
        settings = legacy_options.pop("settings", None)
        if legacy_args:
            if has_settings_keyword:
                raise TypeError("LolaConnector got multiple values for settings")
            settings = legacy_args[0]
            legacy_args = legacy_args[1:]
        options = legacy_options.pop("options", None)
        if options is not None and not isinstance(options, LolaConnectorOptions):
            raise TypeError("LolaConnector options must be LolaConnectorOptions")
        if settings is not None and not isinstance(settings, MediaSettings):
            raise TypeError("LolaConnector settings must be MediaSettings")
        resolved = _connector_options_from_legacy(legacy_args, legacy_options, options)
        self.local_ip = local_ip
        self.settings = settings if settings is not None else MediaSettings()
        self.control_port = resolved.control_port
        self.audio_port = resolved.audio_port
        self.video_port = resolved.video_port
        self.video_packet_size = resolved.video_packet_size
        self.control_dialect = resolved.control_dialect
        self.source_name = resolved.source_name
        self.session: Session | None = None
        self._audio_send_sock: socket.socket | None = None
        self._video_send_sock: socket.socket | None = None
        # The media runtime owns this socket and keeps it bound to the fixed
        # local LoLa control port. Active-session controls reuse it so they do
        # not contend with a second bind to the same port.
        self._runtime_control_sock: socket.socket | None = None

    def register_runtime_control_socket(self, sock: socket.socket) -> None:
        """Make a runtime-owned fixed-port socket available for session controls."""
        if self._runtime_control_sock is not None and self._runtime_control_sock is not sock:
            raise RuntimeError("a runtime control socket is already registered")
        self._runtime_control_sock = sock

    def unregister_runtime_control_socket(self, sock: socket.socket) -> None:
        """Release a runtime-owned control socket before its runtime closes it."""
        if self._runtime_control_sock is sock:
            self._runtime_control_sock = None

    def make_udp_socket(self, bind_port: int = 0) -> socket.socket:
        """Create a nonblocking UDP socket bound to LoLa's negotiated local IP.

        Binding media sockets to 19788/19798 is important: Windows LoLa's pcap
        filters and packet parser expect both source and destination stream
        ports to match the configured LoLa audio/video ports.
        """
        return make_bound_udp_socket(
            self.local_ip,
            bind_port,
            self.audio_port,
            self.video_port,
            close_udp_socket,
        )

    @contextmanager
    def udp_socket(self, bind_port: int = 0) -> Iterator[socket.socket]:
        sock = self.make_udp_socket(bind_port)
        try:
            yield sock
        finally:
            close_udp_socket(sock)

    async def _receive_control_until(  # pylint: disable=too-many-arguments
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
            receive = connector_module.udp_recvfrom(sock, 4096)
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
        if result.reason in {"rejected", "incompatible-media"}:
            raise RuntimeError(result.response_text or "LoLa rejected QuickConn")
        raise TimeoutError("LoLa QuickConn ACK timed out")

    async def initiate_result(self, remote_ip: str, sid: int = 0, timeout: float = 2.0) -> QuickConnResult:
        stats = _ControlReceiveStats()
        with self.udp_socket(self.control_port) as sock:
            await self._send_control(
                sock,
                _ControlSendRequest(MESG_QUICKCONN, remote_ip, sid),
            )

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

    def _handle_quickconn_ack(  # pylint: disable=too-many-arguments,too-many-positional-arguments
        self,
        msg: ControlMessage,
        addr: tuple[str, int],
        remote_ip: str,
        sid: int,
        stats: _ControlReceiveStats,
    ) -> QuickConnResult | None:
        rejection_reason = _control_response_rejection_reason(
            msg,
            addr,
            remote_ip,
            self.local_ip,
            sid,
            self._expected_control_response_port(),
        )
        if rejection_reason is not None:
            _record_control_response_rejection(stats, rejection_reason)
            return None
        if msg.kind == MESG_REJECT:
            return _rejected_quickconn_result(msg, addr, stats)
        if msg.kind != MESG_QUICKCONN_ACK:
            stats.unexpected_datagrams += 1
            return None

        remote_settings = self.settings_from_quickconn_ack(msg)
        if not self.settings.compatible_audio(remote_settings):
            return QuickConnResult(
                session=None,
                reason="incompatible-media",
                response_ip=addr[0],
                response_kind=msg.kind,
                response_text=self._compat_error(remote_settings),
                malformed_datagrams=stats.malformed_datagrams,
                wrong_peer_datagrams=stats.wrong_peer_datagrams,
                unexpected_datagrams=stats.unexpected_datagrams,
            )
        self.close_media_sockets()
        self.session = Session(self.local_ip, remote_ip, sid, remote_settings)
        return _accepted_quickconn_result(self.session, msg, addr, stats)

    async def check_status_result(self, remote_ip: str, sid: int = 0, timeout: float = 2.0) -> StatusCheckResult:
        sent_dialects = ("ascii", "osc15") if self.control_dialect == "auto" else (self.control_dialect,)
        state = _StatusProbeState(stats=_ControlReceiveStats())
        with self.udp_socket(self.control_port) as sock:
            await self._send_status_probes(sock, remote_ip, sid)

            async def handle_status_response(msg: ControlMessage, addr: tuple[str, int]) -> StatusCheckResult | None:
                return _handle_status_response(
                    msg,
                    addr,
                    remote_ip,
                    sent_dialects,
                    state,
                    local_ip=self.local_ip,
                    sid=sid,
                    control_port=self._expected_control_response_port(),
                )

            return await self._receive_control_until(
                sock,
                handle_status_response,
                lambda: _status_timeout_result(state, sent_dialects),
                timeout=timeout,
                stats=state.stats,
            )

    def _expected_control_response_port(self) -> int:
        """Return the peer port from which this connector expects control replies."""
        return self.control_port

    async def _send_status_probes(self, sock: socket.socket, remote_ip: str, sid: int) -> None:
        if self.control_dialect == "auto":
            await self._send_control(
                sock,
                _ControlSendRequest(MESG_CHECKLOLASTATUS, remote_ip, sid, dialect="ascii"),
            )
            await self._send_control(
                sock,
                _ControlSendRequest(MESG_CHECKLOLASTATUS, remote_ip, sid, dialect="osc15"),
            )
            return
        await self._send_control(sock, _ControlSendRequest(MESG_CHECKLOLASTATUS, remote_ip, sid))

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
        response_ip = addr[0]
        if msg.dialect != "osc15" and msg.src_ip != response_ip:
            logger.warning(
                "ignored LoLa control datagram with mismatched source: sender=%s src=%r",
                addr[0],
                msg.src_ip,
            )
            return None
        sid = msg.bound_sid
        if sid is None:
            logger.warning("ignored LoLa control datagram with invalid SID from %s", addr[0])
            return None
        if msg.kind == MESG_CHECKLOLASTATUS:
            await self._send_control(
                sock,
                _ControlSendRequest(
                    MESG_CHECKLOLASTATUS_ACK,
                    response_ip,
                    sid,
                    dialect=msg.dialect,
                    remote_port=addr[1],
                ),
            )
            return None
        if msg.kind != MESG_QUICKCONN:
            return None

        remote_settings = MediaSettings.from_fields(msg.fields, self.settings)
        if not self.settings.compatible_audio(remote_settings):
            await self._reject_incompatible_quickconn(sock, msg, addr, remote_settings)
            return None

        ack_settings = self._quickconn_ack_settings(msg, remote_settings)
        await self._send_control(
            sock,
            _ControlSendRequest(
                MESG_QUICKCONN_ACK,
                response_ip,
                sid,
                dialect=msg.dialect,
                settings=ack_settings,
                remote_port=addr[1],
            ),
        )
        logger.info(
            "accepted QuickConn: sender=%s src=%r dialect=%s remote_settings=%s",
            addr[0],
            msg.src_ip,
            msg.dialect,
            remote_settings,
        )
        self.close_media_sockets()
        self.session = Session(self.local_ip, response_ip, sid, remote_settings)
        return self.session

    # pylint: disable-next=too-many-arguments,too-many-positional-arguments
    async def _reject_incompatible_quickconn(
        self,
        sock: socket.socket,
        msg: ControlMessage,
        addr: tuple[str, int],
        remote_settings: MediaSettings,
    ) -> None:
        logger.info(
            "rejecting QuickConn: sender=%s src=%r dialect=%s remote_settings=%s local_settings=%s",
            addr[0],
            msg.src_ip,
            msg.dialect,
            remote_settings,
            self.settings,
        )
        await self._send_control(
            sock,
            _ControlSendRequest(
                MESG_REJECT,
                addr[0],
                msg.sid,
                txt=self._compat_error(remote_settings),
                dialect=msg.dialect,
                remote_port=addr[1],
            ),
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
        source_matches = msg.dialect == "osc15" or msg.src_ip == sender_ip
        return sender_ip == session.remote_ip and source_matches and msg.bound_sid == session.sid

    def settings_from_quickconn_ack(self, msg: ControlMessage) -> MediaSettings:
        """Return peer media settings from a QuickConn ACK control message."""
        settings = MediaSettings.from_fields(msg.fields, self.settings)
        if msg.dialect == "osc15":
            # OSC15 ACKs mirror the initiator's Bayer marker; keep that rule
            # symmetric with the accept-side ACK builder.
            return replace(settings, bayer=self.settings.bayer)
        return settings

    async def _send_control(self, sock: socket.socket, request: _ControlSendRequest) -> None:
        """Send one padded LoLa control datagram to its configured or observed peer port."""
        selected = request.dialect or self.control_dialect
        if selected == "osc15":
            datagram = build_osc15_control_datagram(
                request.kind,
                self.local_ip,
                request.remote_ip,
                request.sid,
                request.settings or self.settings,
                request.txt,
                source_name=self.source_name,
            )
        else:
            datagram = build_control_datagram(
                request.kind,
                self.local_ip,
                request.remote_ip,
                request.sid,
                request.settings or self.settings,
                request.txt,
            )
        remote_port = self.control_port if request.remote_port is None else request.remote_port
        await connector_module.udp_sendto(sock, datagram, (request.remote_ip, remote_port))

    async def send_control_once(self, kind: str, remote_ip: str, sid: int = 0, txt: str = "") -> None:
        sock = self._runtime_control_sock
        if sock is not None:
            await self._send_control(sock, _ControlSendRequest(kind, remote_ip, sid, txt))
            return
        # Status probes intentionally remain ephemeral, but controls sent
        # outside a running media runtime must still originate at LoLa's fixed
        # control port.
        with self.udp_socket(self.control_port) as fixed_port_sock:
            await self._send_control(fixed_port_sock, _ControlSendRequest(kind, remote_ip, sid, txt))

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

    async def send_audio_on_socket(self, sock: socket.socket, pcm: bytes, sequence: int) -> bool:
        session = self.session
        if session is None:
            raise RuntimeError("no active LoLa session")
        payload = build_audio_payload(sequence, pcm)
        return await connector_module.udp_sendto(sock, payload, (session.remote_ip, self.audio_port))

    async def send_video_on_socket(self, sock: socket.socket, frame: bytes, sequence: int) -> bool:
        """Send a frame without a runtime deadline (legacy compatibility API)."""
        return await self.send_video_until_on_socket(sock, frame, sequence, deadline=None) == "sent"

    async def send_video_until_on_socket(
        self,
        sock: socket.socket,
        frame: bytes,
        sequence: int,
        *,
        deadline: float | None,
    ) -> str:
        """Send one frame until its absolute deadline without buffering a suffix.

        The string outcome lets the runtime distinguish an expired frame from
        nonblocking UDP backpressure while retaining the old boolean API.
        """
        session = self.session
        if session is None:
            raise RuntimeError("no active LoLa session")
        for payload in iter_video_payloads(sequence, frame, packet_size=self.video_packet_size):
            if deadline is not None and time.perf_counter() >= deadline:
                return "deadline"
            sent = await connector_module.udp_sendto(sock, payload, (session.remote_ip, self.video_port))
            if not sent:
                # A partial video frame is useless to the receiver.  Do not
                # wait for writability or resume its remaining fragments.
                return "backpressure"
            # A frame can contain thousands of fragments. Give the audio TX
            # task a deadline opportunity between fragments instead of holding
            # the event loop until the entire frame has been emitted.
            await asyncio.sleep(0)
        return "sent"
