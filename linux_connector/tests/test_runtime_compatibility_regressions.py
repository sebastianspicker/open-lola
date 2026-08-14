"""Deterministic compatibility regressions for the Python media runtime."""

from __future__ import annotations

import argparse
import asyncio
from collections.abc import Iterator
from contextlib import contextmanager
import socket
from typing import cast

import pytest

from linux_connector.lola_connector import cli
from linux_connector.lola_connector.backends import MemoryAudioPlayback, SilenceAudioCapture
from linux_connector.lola_connector.connector import Session
from linux_connector.lola_connector.connector_impl import LolaConnector
from linux_connector.lola_connector.protocol import (
    MESG_SEND_AUDIO_SIGNAL,
    MESG_STOP_AUDIO_SIGNAL,
    ControlMessage,
    MediaSettings,
)
from linux_connector.lola_connector.runtime import LolaLinuxRuntime
from linux_connector.lola_connector.runtime_types import CapturedVideoFrame


class _SocketDouble:
    """Provide the narrow socket contract needed by runtime and connector tests."""

    def __init__(self, port: int = 7000) -> None:
        self.port = port
        self.close_calls = 0

    def fileno(self) -> int:
        return -1

    def getsockname(self) -> tuple[str, int]:
        return ("127.0.0.1", self.port)

    def close(self) -> None:
        self.close_calls += 1


def _session(settings: MediaSettings) -> Session:
    return Session("127.0.0.1", "127.0.0.2", 7, settings)


def test_indefinite_cli_runtime_returns_after_peer_disconnect_without_second_disconnect(
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    """The peer-cleared session wakes the CLI runtime and suppresses its outbound disconnect."""

    class RuntimeDouble:
        stats = "final-stats"

        async def start(self, **_kwargs: bool) -> None:
            return

        async def wait_terminated(self) -> None:
            connector.session = None

        async def stop(self) -> None:
            stop_calls.append("stop")

    settings = MediaSettings(width=2, height=2)
    connector = LolaConnector("127.0.0.1", settings)
    connector.session = _session(settings)
    sent_controls: list[str] = []
    stop_calls: list[str] = []

    async def record_control(kind: str, *_args: object, **_kwargs: object) -> None:
        sent_controls.append(kind)

    args = argparse.Namespace(
        wait_for_remote_test_signal=False,
        request_remote_audio_signal=False,
        rx=False,
        duration=None,
    )
    monkeypatch.setattr(cli, "media_settings_from_args", lambda _args: settings)
    monkeypatch.setattr(cli, "build_video_capture", lambda *_args: None)
    monkeypatch.setattr(cli, "build_runtime", lambda *_args: cast(LolaLinuxRuntime, RuntimeDouble()))
    monkeypatch.setattr(connector, "send_control_once", record_control)

    asyncio.run(cli.run_media_runtime(args, connector, _session(settings)))

    assert stop_calls == ["stop"]
    assert sent_controls == []
    assert "runtime stats: final-stats" in capsys.readouterr().out


def test_active_controls_reuse_runtime_control_socket_and_fallback_binds_fixed_port(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Chat, test-signal, and disconnect controls never allocate an ephemeral active-session socket."""

    settings = MediaSettings(width=2, height=2)
    connector = LolaConnector("127.0.0.1", settings, control_port=17000)
    connector.session = _session(settings)
    runtime_socket = _SocketDouble(connector.control_port)
    connector.register_runtime_control_socket(cast(socket.socket, runtime_socket))
    sent_sockets: list[object] = []

    async def record_send(sock: socket.socket, _request: object) -> None:
        sent_sockets.append(sock)

    @contextmanager
    def unexpected_ephemeral_socket(_port: int = 0) -> Iterator[socket.socket]:
        raise AssertionError("registered runtime control socket must be reused")
        yield cast(socket.socket, object())

    monkeypatch.setattr(connector, "_send_control", record_send)
    monkeypatch.setattr(connector, "udp_socket", unexpected_ephemeral_socket)

    async def run_active_controls() -> None:
        await connector.send_chat("hello")
        await connector.send_control_once(MESG_SEND_AUDIO_SIGNAL, "127.0.0.2", 7)
        await connector.send_control_once(MESG_STOP_AUDIO_SIGNAL, "127.0.0.2", 7)
        await connector.send_disconnect()

    asyncio.run(run_active_controls())
    assert sent_sockets == [runtime_socket] * 4

    connector.unregister_runtime_control_socket(cast(socket.socket, runtime_socket))
    bound_ports: list[int] = []

    @contextmanager
    def fixed_port_socket(port: int = 0) -> Iterator[socket.socket]:
        bound_ports.append(port)
        yield cast(socket.socket, runtime_socket)

    monkeypatch.setattr(connector, "udp_socket", fixed_port_socket)
    asyncio.run(connector.send_control_once(MESG_SEND_AUDIO_SIGNAL, "127.0.0.2", 7))
    assert bound_ports == [connector.control_port]


def test_audio_signal_enables_audio_only_and_stop_disables_both() -> None:
    """LoLa audio test controls must not implicitly start video transmission."""

    settings = MediaSettings(width=2, height=2)
    connector = LolaConnector("127.0.0.1", settings)
    connector.session = _session(settings)
    runtime = LolaLinuxRuntime(connector, SilenceAudioCapture(settings), MemoryAudioPlayback())
    send = ControlMessage(MESG_SEND_AUDIO_SIGNAL, {"SRCIP": "127.0.0.2", "SID": "7"}, "")
    stop = ControlMessage(MESG_STOP_AUDIO_SIGNAL, {"SRCIP": "127.0.0.2", "SID": "7"}, "")

    runtime._control_handler._apply_control_action(send, "127.0.0.2")  # pylint: disable=protected-access
    assert runtime._audio_tx_enabled.is_set()  # pylint: disable=protected-access
    assert not runtime._video_tx_enabled.is_set()  # pylint: disable=protected-access
    runtime._video_tx_enabled.set()  # pylint: disable=protected-access
    runtime._control_handler._apply_control_action(stop, "127.0.0.2")  # pylint: disable=protected-access
    assert not runtime._audio_tx_enabled.is_set()  # pylint: disable=protected-access
    assert not runtime._video_tx_enabled.is_set()  # pylint: disable=protected-access


def test_runtime_rejects_malformed_audio_and_raw_video_before_sending(monkeypatch: pytest.MonkeyPatch) -> None:
    """Backend output must match negotiated local geometry before it reaches UDP serialization."""

    class Capture:
        frames_per_callback = 64
        external_pacing = False

        async def read_block(self) -> bytes:
            return b"too short"

    class RejectingConnector(LolaConnector):
        async def send_audio_on_socket(self, *_args: object) -> bool:
            raise AssertionError("malformed audio must not be sent")

        async def send_video_on_socket(self, *_args: object) -> bool:
            raise AssertionError("malformed video must not be sent")

    settings = MediaSettings(width=2, height=2, bits_per_pixel=8, compression=0)
    connector = RejectingConnector("127.0.0.1", settings)
    connector.session = _session(settings)
    runtime = LolaLinuxRuntime(connector, Capture(), MemoryAudioPlayback())
    runtime._audio_sock = cast(socket.socket, _SocketDouble())  # pylint: disable=protected-access
    runtime._video_sock = cast(socket.socket, _SocketDouble())  # pylint: disable=protected-access
    monkeypatch.setattr("linux_connector.lola_connector.runtime.time.perf_counter", lambda: 1.0)

    assert asyncio.run(runtime._send_audio_tx_packet(3)) == 4  # pylint: disable=protected-access
    assert asyncio.run(
        runtime._send_captured_video(CapturedVideoFrame(b"bad", captured_at=1.0), 4)  # pylint: disable=protected-access
    ) == "malformed"
    runtime._record_video_tx_drop("malformed")  # pylint: disable=protected-access

    assert (runtime.stats.audio_tx, runtime.stats.audio_tx_dropped, runtime.stats.audio_tx_malformed_dropped) == (0, 1, 1)
    assert (runtime.stats.video_tx, runtime.stats.video_tx_dropped, runtime.stats.video_tx_malformed_dropped) == (0, 1, 1)


def test_compressed_video_bypasses_raw_geometry_validation(monkeypatch: pytest.MonkeyPatch) -> None:
    """Compressed capture remains opaque even when its bytes do not match raw geometry."""

    class SendingConnector(LolaConnector):
        async def send_video_until_on_socket(self, *_args: object, **_kwargs: object) -> str:
            return "sent"

    settings = MediaSettings(width=2, height=2, bits_per_pixel=8, compression=1)
    connector = SendingConnector("127.0.0.1", settings)
    connector.session = _session(settings)
    runtime = LolaLinuxRuntime(connector, SilenceAudioCapture(settings), MemoryAudioPlayback())
    runtime._video_sock = cast(socket.socket, _SocketDouble())  # pylint: disable=protected-access
    monkeypatch.setattr("linux_connector.lola_connector.runtime.time.perf_counter", lambda: 1.0)

    outcome = asyncio.run(
        runtime._send_captured_video(CapturedVideoFrame(b"jpeg", captured_at=1.0), 4)  # pylint: disable=protected-access
    )
    assert outcome == "sent"
