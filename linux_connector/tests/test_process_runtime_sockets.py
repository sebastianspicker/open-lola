"""Tests for process runtime UDP socket configuration."""

from __future__ import annotations

import socket

import pytest

from linux_connector.lola_connector.connector import LolaConnector
from linux_connector.lola_connector.protocol import MediaSettings
from linux_connector.tests.support import expect_equal


def test_connector_uses_stream_specific_realtime_udp_buffers(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    class RecordingSocket:
        def __init__(self) -> None:
            self.options: list[tuple[int, int, int]] = []

        def setsockopt(self, level: int, option: int, value: int) -> None:
            self.options.append((level, option, value))

        def setblocking(self, _flag: bool) -> None:
            return None

        def bind(self, _address: tuple[str, int]) -> None:
            return None

        def close(self) -> None:
            return None

    opened: list[RecordingSocket] = []

    def make_socket(_family: int, _kind: int) -> RecordingSocket:
        result = RecordingSocket()
        opened.append(result)
        return result

    monkeypatch.setattr(socket, "socket", make_socket)
    connector = LolaConnector("127.0.0.1", MediaSettings())
    connector.make_udp_socket(connector.audio_port)
    connector.make_udp_socket(connector.video_port)

    audio_values = {
        value for _level, option, value in opened[0].options if option in (socket.SO_RCVBUF, socket.SO_SNDBUF)
    }
    video_values = {
        value for _level, option, value in opened[1].options if option in (socket.SO_RCVBUF, socket.SO_SNDBUF)
    }
    expect_equal(audio_values, {2 * 0x42A}, "audio socket buffer profile")
    expect_equal(video_values, {256 * 1024}, "video socket buffer profile")
