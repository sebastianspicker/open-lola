"""Tests for Linux connector runtime contracts."""

# pylint: disable=missing-function-docstring

from __future__ import annotations

import asyncio
import logging
import socket
from typing import Any

import pytest
from pytest import LogCaptureFixture

import linux_connector.lola_connector.runtime as runtime_module
from linux_connector.lola_connector.backends import MemoryAudioPlayback, SilenceAudioCapture
from linux_connector.lola_connector.connector import LolaConnector, Session
from linux_connector.lola_connector.media import expected_audio_payload_size
from linux_connector.lola_connector.protocol import MediaSettings
from linux_connector.lola_connector.runtime import LolaLinuxRuntime


def expect_equal(actual: object, expected: object) -> None:
    if actual != expected:
        raise AssertionError(f"expected {expected!r}, got {actual!r}")


def expect_true(value: object, message: str = "expected truthy value") -> None:
    if not value:
        raise AssertionError(message)


def expect_in(member: object, container: Any) -> None:
    if member not in container:
        raise AssertionError(f"expected {member!r} to be present")


def expect_gt(actual: int, minimum: int) -> None:
    if actual <= minimum:
        raise AssertionError(f"expected {actual!r} to be greater than {minimum!r}")


def test_accept_once_honors_timeout_without_incoming_quickconn(require_localhost_udp: None) -> None:

    async def run() -> None:
        connector = LolaConnector("127.0.0.1", control_port=0)
        with pytest.raises(TimeoutError, match="LoLa QuickConn did not arrive"):
            await connector.accept_once(timeout=0.01)

    asyncio.run(run())


def test_accept_once_signals_ready_after_binding(require_localhost_udp: None) -> None:

    async def run() -> None:
        connector = LolaConnector("127.0.0.1", control_port=0)
        ready = asyncio.Event()
        accept_task = asyncio.create_task(connector.accept_once(timeout=0.01, ready_event=ready))
        await asyncio.wait_for(ready.wait(), timeout=0.5)
        with pytest.raises(TimeoutError, match="LoLa QuickConn did not arrive"):
            await accept_task

    asyncio.run(run())


def test_runtime_without_video_capture_does_not_emit_video_tx(require_localhost_udp: None) -> None:

    settings = MediaSettings(width=16, height=8)
    connector = LolaConnector("127.0.0.1", settings)
    connector.session = Session("127.0.0.1", "127.0.0.2", 1, settings)
    runtime = LolaLinuxRuntime(
        connector,
        SilenceAudioCapture(settings),
        MemoryAudioPlayback(),
        video_capture=None,
        video_display=None,
    )

    stats = asyncio.run(
        runtime.run_for(
            0.02, receive=False, transmit_audio=False, transmit_video=True, control=False
        )
    )

    expect_equal(stats.video_tx, 0)


def test_audio_only_runtime_start_does_not_bind_video_port(require_localhost_udp: None) -> None:

    reserved_video_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    reserved_video_socket.bind(("127.0.0.1", 0))
    occupied_video_port = reserved_video_socket.getsockname()[1]
    try:
        settings = MediaSettings(width=16, height=8)
        connector = LolaConnector(
            "127.0.0.1", settings, audio_port=0, video_port=occupied_video_port
        )
        connector.session = Session("127.0.0.1", "127.0.0.2", 1, settings)
        runtime = LolaLinuxRuntime(
            connector,
            SilenceAudioCapture(settings),
            MemoryAudioPlayback(),
            video_capture=None,
            video_display=None,
        )

        stats = asyncio.run(
            runtime.run_for(
                0.01,
                receive=False,
                transmit_audio=False,
                transmit_video=False,
                control=False,
            )
        )

        expect_equal(stats.video_tx, 0)
        expect_equal(stats.video_rx, 0)
    finally:
        reserved_video_socket.close()


def test_runtime_stop_logs_failed_worker_before_cleanup(caplog: LogCaptureFixture) -> None:

    class FailingAudioCapture:  # pylint: disable=missing-class-docstring
        frames_per_callback = 0

        def __init__(self) -> None:
            self.closed = False

        async def read_block(self) -> bytes:
            raise RuntimeError("audio capture failed")

        async def aclose(self) -> None:
            self.closed = True

    class FakeConnector(LolaConnector):  # pylint: disable=missing-class-docstring
        def __init__(self) -> None:
            settings = MediaSettings(width=16, height=8)
            super().__init__("127.0.0.1", settings)
            self.session = Session("127.0.0.1", "127.0.0.2", 1, settings)

        def make_udp_socket(self, bind_port: int = 0) -> socket.socket:
            _ = bind_port
            return socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    async def run() -> None:
        capture = FailingAudioCapture()
        runtime = LolaLinuxRuntime(FakeConnector(), capture, MemoryAudioPlayback())
        await runtime.start(receive=False, transmit_audio=True, transmit_video=False, control=False)
        await asyncio.sleep(0)
        with pytest.raises(ExceptionGroup, match="runtime task failed during stop"):
            await runtime.stop()

        expect_true(capture.closed, "audio capture should close after failed stop")

    caplog.set_level("ERROR", logger="linux_connector.lola_connector.runtime")
    asyncio.run(run())
    expect_in("runtime task failed during stop", caplog.text)


def test_runtime_start_rejects_stale_task_handles(require_localhost_udp: None) -> None:

    async def run() -> None:
        settings = MediaSettings(width=16, height=8)
        connector = LolaConnector("127.0.0.1", settings)
        connector.session = Session("127.0.0.1", "127.0.0.2", 1, settings)
        runtime = LolaLinuxRuntime(connector, SilenceAudioCapture(settings), MemoryAudioPlayback())
        await runtime.start(
            receive=False, transmit_audio=False, transmit_video=False, control=False
        )
        try:
            with pytest.raises(RuntimeError, match="runtime is already started"):
                await runtime.start(
                    receive=False,
                    transmit_audio=False,
                    transmit_video=False,
                    control=False,
                )
        finally:
            await runtime.stop()

    asyncio.run(run())


def test_runtime_control_loop_requires_initialized_socket() -> None:

    async def run() -> None:
        settings = MediaSettings(width=16, height=8)
        connector = LolaConnector("127.0.0.1", settings)
        connector.session = Session("127.0.0.1", "127.0.0.2", 1, settings)
        runtime = LolaLinuxRuntime(connector, SilenceAudioCapture(settings), MemoryAudioPlayback())
        control_loop = getattr(runtime, "_control_loop")
        with pytest.raises(RuntimeError, match="control socket is not initialized"):
            await control_loop()

    asyncio.run(run())


def test_runtime_audio_tx_checks_socket_before_consuming_capture() -> None:

    class CountingAudioCapture:  # pylint: disable=missing-class-docstring,too-few-public-methods
        frames_per_callback = 64
        external_pacing = False

        def __init__(self) -> None:
            self.reads = 0

        async def read_block(self) -> bytes:
            self.reads += 1
            return b"\0" * expected_audio_payload_size(channels=2)

    async def run() -> None:
        settings = MediaSettings(width=16, height=8)
        connector = LolaConnector("127.0.0.1", settings)
        connector.session = Session("127.0.0.1", "127.0.0.2", 1, settings)
        capture = CountingAudioCapture()
        runtime = LolaLinuxRuntime(connector, capture, MemoryAudioPlayback())
        audio_tx_enabled = getattr(runtime, "_audio_tx_enabled")
        audio_tx_loop = getattr(runtime, "_audio_tx_loop")
        audio_tx_enabled.set()

        with pytest.raises(RuntimeError, match="audio socket is not initialized"):
            await audio_tx_loop()

        expect_equal(capture.reads, 0)

    asyncio.run(run())


def test_runtime_media_rx_logs_unexpected_payload_type(
    monkeypatch: pytest.MonkeyPatch,
    caplog: LogCaptureFixture,
    require_localhost_udp: None,
) -> None:

    async def run() -> None:
        settings = MediaSettings(width=16, height=8)
        connector = LolaConnector("127.0.0.1", settings)
        connector.session = Session("127.0.0.1", "127.0.0.2", 1, settings)
        runtime = LolaLinuxRuntime(connector, SilenceAudioCapture(settings), MemoryAudioPlayback())

        async def fake_recvfrom(_sock: socket.socket, _size: int) -> tuple[bytes, tuple[str, int]]:
            await asyncio.sleep(0)
            return b"unexpected", ("127.0.0.2", 19788)

        monkeypatch.setattr(runtime_module, "udp_recvfrom", fake_recvfrom)
        monkeypatch.setattr(runtime_module, "parse_media_payload", lambda _payload: object())
        caplog.set_level(logging.WARNING, logger="linux_connector.lola_connector.runtime")

        await runtime.run_for(
            0.01, receive=True, transmit_audio=False, transmit_video=False, control=False
        )

    asyncio.run(run())
    expect_in("ignored unexpected LoLa", caplog.text)
    expect_in("media payload type object from=127.0.0.2", caplog.text)


def test_runtime_media_rx_counts_malformed_payload_without_task_failure(
    monkeypatch: pytest.MonkeyPatch,
    caplog: LogCaptureFixture,
    require_localhost_udp: None,
) -> None:

    async def run() -> None:
        settings = MediaSettings(width=16, height=8)
        connector = LolaConnector("127.0.0.1", settings)
        connector.session = Session("127.0.0.1", "127.0.0.2", 1, settings)
        runtime = LolaLinuxRuntime(connector, SilenceAudioCapture(settings), MemoryAudioPlayback())

        async def fake_recvfrom(_sock: socket.socket, _size: int) -> tuple[bytes, tuple[str, int]]:
            await asyncio.sleep(0)
            return b"not-a-lola-media-packet", ("127.0.0.2", 19788)

        monkeypatch.setattr(runtime_module, "udp_recvfrom", fake_recvfrom)
        caplog.set_level(logging.WARNING, logger="linux_connector.lola_connector.runtime")

        await runtime.run_for(
            0.01, receive=True, transmit_audio=False, transmit_video=False, control=False
        )

        expect_gt(runtime.stats.audio_malformed_rx + runtime.stats.video_malformed_rx, 0)

    asyncio.run(run())
    expect_in("ignored unrecognized LoLa", caplog.text)
    expect_in("media payload", caplog.text)


def test_runtime_media_sender_must_use_stream_source_port(caplog: LogCaptureFixture) -> None:
    settings = MediaSettings(width=16, height=8)
    connector = LolaConnector("127.0.0.1", settings, audio_port=19788, video_port=19798)
    connector.session = Session("127.0.0.1", "127.0.0.2", 1, settings)
    runtime = LolaLinuxRuntime(connector, SilenceAudioCapture(settings), MemoryAudioPlayback())
    caplog.set_level(logging.WARNING, logger="linux_connector.lola_connector.runtime")

    session_for_media_sender = getattr(runtime, "_session_for_media_sender")
    expect_equal(session_for_media_sender(("127.0.0.2", 19788), "audio"), connector.session)
    expect_equal(session_for_media_sender(("127.0.0.2", 19798), "video"), connector.session)
    expect_equal(session_for_media_sender(("127.0.0.2", 12345), "audio"), None)
    expect_equal(session_for_media_sender(("127.0.0.2", 12345), "video"), None)
    expect_equal(runtime.stats.audio_malformed_rx, 1)
    expect_equal(runtime.stats.video_malformed_rx, 1)
    expect_in("unexpected source port", caplog.text)


def test_runtime_control_loop_counts_malformed_payload_without_task_failure(
    monkeypatch: pytest.MonkeyPatch,
    require_localhost_udp: None,
) -> None:

    async def run() -> None:
        settings = MediaSettings(width=16, height=8)
        connector = LolaConnector("127.0.0.1", settings)
        connector.session = Session("127.0.0.1", "127.0.0.2", 1, settings)
        runtime = LolaLinuxRuntime(connector, SilenceAudioCapture(settings), MemoryAudioPlayback())

        async def fake_recvfrom(_sock: socket.socket, _size: int) -> tuple[bytes, tuple[str, int]]:
            await asyncio.sleep(0)
            return b"not-a-lola-control-packet", ("127.0.0.2", 7000)

        monkeypatch.setattr(runtime_module, "udp_recvfrom", fake_recvfrom)

        await runtime.run_for(
            0.01, receive=False, transmit_audio=False, transmit_video=False, control=True
        )

        expect_gt(runtime.stats.control_malformed_rx, 0)

    asyncio.run(run())


def test_runtime_run_for_yields_to_event_loop(require_localhost_udp: None) -> None:

    async def run() -> None:
        settings = MediaSettings(width=16, height=8)
        connector = LolaConnector("127.0.0.1", settings)
        connector.session = Session("127.0.0.1", "127.0.0.2", 1, settings)
        runtime = LolaLinuxRuntime(connector, SilenceAudioCapture(settings), MemoryAudioPlayback())
        observed = False

        async def marker() -> None:
            nonlocal observed
            await asyncio.sleep(0)
            observed = True

        marker_task = asyncio.create_task(marker())
        await runtime.run_for(
            0.01,
            receive=False,
            transmit_audio=False,
            transmit_video=False,
            control=False,
        )
        await marker_task
        expect_true(observed, "runtime should yield to the event loop")

    asyncio.run(run())
