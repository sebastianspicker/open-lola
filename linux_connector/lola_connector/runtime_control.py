"""Control-message handling isolated from Linux LoLa media scheduling."""

from __future__ import annotations

import asyncio
from collections.abc import Callable
from dataclasses import dataclass
import logging
import socket
from typing import TypedDict, Unpack

from .connector import udp_recvfrom, udp_sendto
from .connector_impl import LolaConnector
from .protocol import (
    MESG_CHECKLOLASTATUS,
    MESG_CHECKLOLASTATUS_ACK,
    MESG_QUICKCONN,
    MESG_REJECT,
    ControlMessage,
    build_control_datagram,
    build_osc15_control_datagram,
    message_ip,
    parse_control_datagram,
)
from .runtime_types import RuntimeStats


logger = logging.getLogger(__name__)


class _RuntimeControlDependencies(TypedDict):
    """Describe the runtime-owned state required by the control handler."""

    connector: LolaConnector
    stats: RuntimeStats
    control_socket: Callable[[], socket.socket | None]
    stop: asyncio.Event
    audio_tx_enabled: asyncio.Event
    video_tx_enabled: asyncio.Event
    has_video_capture: Callable[[], bool]


@dataclass(init=False)
class _RuntimeControlHandler:
    """Process one runtime's control socket without owning its lifecycle."""

    def __init__(
        self, **dependencies: Unpack[_RuntimeControlDependencies]
    ) -> None:
        self._connector = dependencies["connector"]
        self._stats = dependencies["stats"]
        self._control_socket = dependencies["control_socket"]
        self._stop = dependencies["stop"]
        self._audio_tx_enabled = dependencies["audio_tx_enabled"]
        self._video_tx_enabled = dependencies["video_tx_enabled"]
        self._has_video_capture = dependencies["has_video_capture"]

    async def run(self) -> None:
        """Receive and dispatch control messages until the runtime stops."""
        sock = self._control_socket()
        if sock is None:
            raise RuntimeError("control socket is not initialized")
        while not self._stop.is_set():
            data, addr = await udp_recvfrom(sock, 4096)
            message = self._parse_message(data, addr[0])
            if message is not None:
                await self._handle_message(message, addr[0])

    def _parse_message(self, data: bytes, remote_ip: str) -> ControlMessage | None:
        try:
            message = parse_control_datagram(data)
        except ValueError:
            self._stats.control_malformed_rx += 1
            logger.warning(
                "ignored malformed LoLa control payload from=%s",
                remote_ip,
                exc_info=True,
            )
            return None
        if message is None:
            self._stats.control_malformed_rx += 1
            return None
        self._stats.control_rx += 1
        return message

    async def _handle_message(self, message: ControlMessage, sender_ip: str) -> None:
        if message.kind == MESG_CHECKLOLASTATUS:
            await self._send_status_ack(message, sender_ip)
            return
        if message.kind == MESG_QUICKCONN:
            await self._send_busy_reject(message, sender_ip)
            return
        self._apply_control_action(message, sender_ip)

    async def _send_status_ack(self, message: ControlMessage, sender_ip: str) -> None:
        remote_ip = message_ip(message, sender_ip)
        if message.dialect == "osc15":
            response = build_osc15_control_datagram(
                MESG_CHECKLOLASTATUS_ACK,
                self._connector.local_ip,
                remote_ip,
                message.sid,
                self._connector.settings,
                source_name=self._connector.source_name,
            )
        else:
            response = build_control_datagram(
                MESG_CHECKLOLASTATUS_ACK,
                self._connector.local_ip,
                remote_ip,
                message.sid,
                self._connector.settings,
            )
        await self._send_response(response, remote_ip)

    async def _send_busy_reject(self, message: ControlMessage, sender_ip: str) -> None:
        remote_ip = message_ip(message, sender_ip)
        text = "Linux LoLa connector is already in a session."
        if message.dialect == "osc15":
            response = build_osc15_control_datagram(
                MESG_REJECT,
                self._connector.local_ip,
                remote_ip,
                message.sid,
                txt=text,
                source_name=self._connector.source_name,
            )
        else:
            response = build_control_datagram(
                MESG_REJECT,
                self._connector.local_ip,
                remote_ip,
                message.sid,
                txt=text,
            )
        await self._send_response(response, remote_ip)

    async def _send_response(self, response: bytes, remote_ip: str) -> None:
        sock = self._control_socket()
        if sock is None:
            raise RuntimeError("control socket is not initialized")
        await udp_sendto(sock, response, (remote_ip, self._connector.control_port))

    def _apply_control_action(self, message: ControlMessage, sender_ip: str) -> None:
        action = self._connector.handle_control_message(message, sender_ip=sender_ip)
        if action == "send_audio_signal":
            self._audio_tx_enabled.set()
            if self._has_video_capture():
                self._video_tx_enabled.set()
            return
        if action == "stop_audio_signal":
            self._audio_tx_enabled.clear()
            self._video_tx_enabled.clear()
            return
        if action == "disconnect":
            self._stop.set()
