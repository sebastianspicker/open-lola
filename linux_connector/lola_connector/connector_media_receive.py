"""Legacy LoLa media receive loop."""

from __future__ import annotations

import asyncio
from contextlib import ExitStack
import logging
import socket
from typing import TYPE_CHECKING, ContextManager

from . import connector as connector_module
from .connector import Session
from .media import Fragment, MediaReassembler, VideoPrelude, parse_media_payload, parse_serialized_media

logger = logging.getLogger(__name__)


class LolaConnectorMediaReceiveMixin:
    """Preserve LolaConnector's legacy receive-only media API."""

    session: Session | None
    audio_port: int
    video_port: int

    if TYPE_CHECKING:

        def udp_socket(self, bind_port: int = 0) -> ContextManager[socket.socket]: ...

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
