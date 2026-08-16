"""Tests for legacy receive-only media endpoint validation."""

from __future__ import annotations

import asyncio
import socket
from typing import cast

import pytest

import linux_connector.lola_connector.connector_media_receive as connector_media_receive_module
from linux_connector.lola_connector.connector import Session
from linux_connector.lola_connector.connector_impl import LolaConnector
from linux_connector.lola_connector.media import build_audio_payload, expected_audio_payload_size
from linux_connector.lola_connector.protocol import MediaSettings
from linux_connector.tests.support import expect_equal


def test_legacy_media_receive_ignores_wrong_source_port_then_accepts_expected_port(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    async def run() -> None:
        settings = MediaSettings(width=16, height=8)
        connector = LolaConnector("127.0.0.1", settings)
        connector.session = Session("127.0.0.1", "127.0.0.2", 1, settings)
        payload = build_audio_payload(1, b"\0" * expected_audio_payload_size(channels=2))
        pending = [
            (payload, ("127.0.0.2", connector.audio_port + 1)),
            (payload, ("127.0.0.2", connector.audio_port)),
        ]
        parser_calls: list[bytes] = []
        received = asyncio.Event()
        original_parser = connector_media_receive_module.parse_media_payload

        async def receive_datagram(_sock: socket.socket, _size: int) -> tuple[bytes, tuple[str, int]]:
            if pending:
                return pending.pop(0)
            received.set()
            await asyncio.Future()
            raise AssertionError("unreachable")

        def record_parser(candidate: bytes) -> object:
            parser_calls.append(candidate)
            return original_parser(candidate)

        monkeypatch.setattr(connector_media_receive_module.connector_module, "udp_recvfrom", receive_datagram)
        monkeypatch.setattr(connector_media_receive_module, "parse_media_payload", record_parser)
        receive_task = asyncio.create_task(
            connector._recv_stream(  # pylint: disable=protected-access
                cast(socket.socket, object()),
                connector_media_receive_module.MediaReassembler(),
                "audio",
            )
        )
        try:
            await asyncio.wait_for(received.wait(), timeout=0.5)
            expect_equal(parser_calls, [payload], "only expected-port media parses")
        finally:
            receive_task.cancel()
            with pytest.raises(asyncio.CancelledError):
                await receive_task

    asyncio.run(run())
