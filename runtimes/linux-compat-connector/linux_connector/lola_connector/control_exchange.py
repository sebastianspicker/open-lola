"""Composed control-plane transport for the LoLa connector facade."""

from __future__ import annotations

import asyncio
import logging
import socket
from collections.abc import Awaitable, Callable
from typing import Protocol, TypeVar

from .connector_models import _ControlReceiveStats, _ControlSendRequest
from .connector_socket_io import udp_recvfrom, udp_sendto
from .protocol import ControlMessage, MediaSettings, build_control_datagram, build_osc15_control_datagram, parse_control_datagram

ControlResult = TypeVar("ControlResult")
logger = logging.getLogger(__name__)


class ControlExchangeHost(Protocol):
    """State the exchange needs from the connector facade."""

    local_ip: str
    control_port: int
    control_dialect: str
    settings: MediaSettings
    source_name: str


class ControlExchange:
    """Own async control datagram receive, parse, and send mechanics."""

    def __init__(self, host: ControlExchangeHost) -> None:
        self._host = host

    async def receive_until(
        self,
        sock: socket.socket,
        handler: Callable[[ControlMessage, tuple[str, int]], Awaitable[ControlResult | None]],
        on_timeout: Callable[[], ControlResult],
        *,
        timeout: float | None,
        stats: _ControlReceiveStats | None,
    ) -> ControlResult:
        loop = asyncio.get_running_loop()
        deadline = None if timeout is None else loop.time() + timeout
        while deadline is None or loop.time() < deadline:
            received = await self.receive_datagram(sock, deadline)
            if received is None:
                return on_timeout()
            result = await self.dispatch_datagram(*received, handler, stats)
            if result is not None:
                return result
        return on_timeout()

    async def receive_datagram(
        self, sock: socket.socket, deadline: float | None
    ) -> tuple[bytes, tuple[str, int]] | None:
        try:
            receive = udp_recvfrom(sock, 4096)
            if deadline is None:
                return await receive
            return await asyncio.wait_for(receive, timeout=deadline - asyncio.get_running_loop().time())
        except asyncio.TimeoutError:
            return None

    async def dispatch_datagram(
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

    async def send(self, sock: socket.socket, request: _ControlSendRequest) -> None:
        """Encode and send one control datagram using host-level settings."""
        host = self._host
        selected = request.dialect or host.control_dialect
        if selected == "osc15":
            datagram = build_osc15_control_datagram(
                request.kind, host.local_ip, request.remote_ip, request.sid,
                request.settings or host.settings, request.txt, source_name=host.source_name,
            )
        else:
            datagram = build_control_datagram(
                request.kind, host.local_ip, request.remote_ip, request.sid,
                request.settings or host.settings, request.txt,
            )
        port = host.control_port if request.remote_port is None else request.remote_port
        await udp_sendto(sock, datagram, (request.remote_ip, port))
