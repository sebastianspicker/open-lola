# pylint: disable=missing-function-docstring
"""Main LoLa connector implementation."""

from __future__ import annotations

import asyncio
from contextlib import ExitStack, contextmanager
from dataclasses import replace
import logging
import socket
import time
from collections.abc import Awaitable, Callable, Iterator

from . import connector as connector_module
from .connector import (
    ControlResult,
    LolaConnectorOptions,
    QuickConnResult,
    Session,
    StatusCheckResult,
    _ControlReceiveStats,
    _StatusProbeState,
    _accepted_quickconn_result,
    _connector_options_from_legacy,
    _handle_status_response,
    _quickconn_timeout_result,
    _rejected_quickconn_result,
    _status_timeout_result,
    _stateless_control_action,
    close_udp_socket,
)
from .connector_sockets import make_bound_udp_socket
from .media import (
    Fragment,
    MediaReassembler,
    VideoPrelude,
    build_audio_payload,
    iter_video_payloads,
    parse_media_payload,
    parse_serialized_media,
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
    MediaSettings,
    ControlMessage,
    build_control_datagram,
    build_osc15_control_datagram,
    message_ip,
    parse_control_datagram,
)

logger = logging.getLogger(__name__)

class LolaConnector:  # pylint: disable=too-many-instance-attributes
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
            return await asyncio.wait_for(
                receive, timeout=deadline - asyncio.get_running_loop().time()
            )
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
            logger.warning(
                "ignored malformed LoLa control datagram from %s", addr[0], exc_info=True
            )
            return None

    async def initiate(self, remote_ip: str, sid: int = 0, timeout: float = 2.0) -> Session:
        result = await self.initiate_result(remote_ip, sid, timeout=timeout)
        if result.session is not None:
            return result.session
        if result.reason == "rejected":
            raise RuntimeError(result.response_text or "LoLa rejected QuickConn")
        raise TimeoutError("LoLa QuickConn ACK timed out")

    async def initiate_result(
        self, remote_ip: str, sid: int = 0, timeout: float = 2.0
    ) -> QuickConnResult:
        stats = _ControlReceiveStats()
        with self.udp_socket(self.control_port) as sock:
            await self._send_control(sock, MESG_QUICKCONN, remote_ip, sid)

            async def handle_quickconn_ack(
                msg: ControlMessage, addr: tuple[str, int]
            ) -> QuickConnResult | None:
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

    async def check_status_result(
        self, remote_ip: str, sid: int = 0, timeout: float = 2.0
    ) -> StatusCheckResult:
        sent_dialects = (
            ("ascii", "osc15") if self.control_dialect == "auto" else (self.control_dialect,)
        )
        state = _StatusProbeState(stats=_ControlReceiveStats())
        with self.udp_socket(self.control_port) as sock:
            await self._send_status_probes(sock, remote_ip, sid)

            async def handle_status_response(
                msg: ControlMessage, addr: tuple[str, int]
            ) -> StatusCheckResult | None:
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

    async def accept_once(
        self, timeout: float | None = None, ready_event: asyncio.Event | None = None
    ) -> Session:
        """Accept one incoming LoLa QuickConn and establish a session."""
        with self.udp_socket(self.control_port) as sock:
            if ready_event is not None:
                ready_event.set()

            async def handle_incoming_control(
                msg: ControlMessage, addr: tuple[str, int]
            ) -> Session | None:
                return await self._handle_incoming_control(sock, msg, addr)

            def accept_timeout() -> Session:
                raise TimeoutError("LoLa QuickConn did not arrive")

            return await self._receive_control_until(
                sock, handle_incoming_control, accept_timeout, timeout=timeout
            )

    async def _handle_incoming_control(
        self,
        sock: socket.socket,
        msg: ControlMessage,
        addr: tuple[str, int],
    ) -> Session | None:
        response_ip = message_ip(msg, addr[0])
        if msg.kind == MESG_CHECKLOLASTATUS:
            await self._send_control(
                sock, MESG_CHECKLOLASTATUS_ACK, response_ip, msg.sid, dialect=msg.dialect
            )
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
            "accepted QuickConn: sender=%s src=%r dialect=%s remote_settings=%s",
            addr[0],
            msg.src_ip,
            msg.dialect,
            remote_settings,
        )
        self.close_media_sockets()
        self.session = Session(self.local_ip, response_ip, msg.sid, remote_settings)
        return self.session

    # pylint: disable-next=too-many-arguments,too-many-positional-arguments
    async def _reject_incompatible_quickconn(
        self,
        sock: socket.socket,
        msg: ControlMessage,
        addr: tuple[str, int],
        response_ip: str,
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
        return (
            sender_ip == session.remote_ip
            and remote_ip == session.remote_ip
            and msg.sid == session.sid
        )

    def settings_from_quickconn_ack(self, msg: ControlMessage) -> MediaSettings:
        """Return peer media settings from a QuickConn ACK control message."""
        settings = MediaSettings.from_fields(msg.fields, self.settings)
        if msg.dialect == "osc15":
            # OSC15 ACKs mirror the initiator's Bayer marker; keep that rule
            # symmetric with the accept-side ACK builder.
            return replace(settings, bayer=self.settings.bayer)
        return settings

    async def _send_control(  # pylint: disable=too-many-arguments,too-many-positional-arguments
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
            datagram = build_control_datagram(
                kind, self.local_ip, remote_ip, sid, settings or self.settings, txt
            )
        await connector_module.udp_sendto(sock, datagram, (remote_ip, self.control_port))

    async def send_control_once(
        self, kind: str, remote_ip: str, sid: int = 0, txt: str = ""
    ) -> None:
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

    async def send_audio_on_socket(self, sock: socket.socket, pcm: bytes, sequence: int) -> bool:
        session = self.session
        if session is None:
            raise RuntimeError("no active LoLa session")
        payload = build_audio_payload(sequence, pcm)
        return await connector_module.udp_sendto(
            sock, payload, (session.remote_ip, self.audio_port)
        )

    async def send_video_on_socket(self, sock: socket.socket, frame: bytes, sequence: int) -> bool:
        """Send a frame without a runtime deadline (legacy compatibility API)."""
        return (
            await self.send_video_until_on_socket(sock, frame, sequence, deadline=None)
            == "sent"
        )

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
            sent = await connector_module.udp_sendto(
                sock, payload, (session.remote_ip, self.video_port)
            )
            if not sent:
                # A partial video frame is useless to the receiver.  Do not
                # wait for writability or resume its remaining fragments.
                return "backpressure"
            # A frame can contain thousands of fragments. Give the audio TX
            # task a deadline opportunity between fragments instead of holding
            # the event loop until the entire frame has been emitted.
            await asyncio.sleep(0)
        return "sent"

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
            payload, addr = await connector_module.udp_recvfrom(sock, 65535)
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
                logger.warning(
                    "ignored malformed LoLa %s media payload from=%s",
                    name,
                    addr[0],
                    exc_info=True,
                )
                continue
            logger.info("%s seq=%s bytes=%s from=%s", name, sequence, len(media), addr[0])
