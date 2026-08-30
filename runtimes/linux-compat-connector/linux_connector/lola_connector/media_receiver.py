"""Receive-only media behavior composed into the canonical LoLa connector."""

from __future__ import annotations

import asyncio
import logging
import socket
from contextlib import ExitStack
from typing import ContextManager, Protocol

from .connector_models import Session
from .connector_socket_io import udp_recvfrom
from .media import Fragment, MediaReassembler, VideoPrelude, parse_media_payload, parse_serialized_media

logger = logging.getLogger(__name__)


class MediaReceiverHost(Protocol):
    """The socket and negotiated-session state needed by media reception."""

    session: Session | None
    audio_port: int
    video_port: int

    def udp_socket(self, bind_port: int = 0) -> ContextManager[socket.socket]: ...


class MediaReceiver:
    """Receive-only media service composed into the connector facade."""

    def __init__(self, host: MediaReceiverHost) -> None:
        self._host = host

    @property
    def session(self) -> Session | None:
        return self._host.session

    @property
    def audio_port(self) -> int:
        return self._host.audio_port

    @property
    def video_port(self) -> int:
        return self._host.video_port

    def udp_socket(self, bind_port: int = 0) -> ContextManager[socket.socket]:
        return self._host.udp_socket(bind_port)

    async def recv_media_forever(self) -> None:
        audio_reasm = MediaReassembler()
        video_reasm = MediaReassembler()
        with ExitStack() as stack:
            audio_sock = stack.enter_context(self.udp_socket(self.audio_port))
            video_sock = stack.enter_context(self.udp_socket(self.video_port))
            await asyncio.gather(
                self.recv_stream(audio_sock, audio_reasm, "audio"),
                self.recv_stream(video_sock, video_reasm, "video"),
            )

    async def recv_stream(self, sock: socket.socket, reasm: MediaReassembler, name: str) -> None:
        while True:
            payload, addr = await udp_recvfrom(sock, 65535)
            session = self.session
            if session is None:
                continue
            if addr[0] != session.remote_ip:
                continue
            expected_port = self.audio_port if name == "audio" else self.video_port
            if addr[1] != expected_port:
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
