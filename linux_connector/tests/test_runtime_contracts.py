from __future__ import annotations

import logging
import socket

import pytest
from pytest import LogCaptureFixture

import linux_connector.lola_connector.runtime as runtime_module
from linux_connector.lola_connector.backends import MemoryAudioPlayback, SilenceAudioCapture
from linux_connector.lola_connector.connector import LolaConnector, Session
from linux_connector.lola_connector.media import MediaReassembler, expected_audio_payload_size
from linux_connector.lola_connector.protocol import MediaSettings
from linux_connector.lola_connector.runtime import LolaLinuxRuntime


def test_accept_once_honors_timeout_without_incoming_quickconn() -> None:
    import asyncio

    async def run() -> None:
        connector = LolaConnector("127.0.0.1", control_port=0)
        with pytest.raises(TimeoutError, match="LoLa QuickConn did not arrive"):
            await connector.accept_once(timeout=0.01)

    asyncio.run(run())


def test_accept_once_signals_ready_after_binding() -> None:
    import asyncio

    async def run() -> None:
        connector = LolaConnector("127.0.0.1", control_port=0)
        ready = asyncio.Event()
        accept_task = asyncio.create_task(connector.accept_once(timeout=0.01, ready_event=ready))
        await asyncio.wait_for(ready.wait(), timeout=0.5)
        with pytest.raises(TimeoutError, match="LoLa QuickConn did not arrive"):
            await accept_task

    asyncio.run(run())


def test_runtime_without_video_capture_does_not_emit_video_tx() -> None:
    import asyncio

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

    stats = asyncio.run(runtime.run_for(0.02, receive=False, transmit_audio=False, transmit_video=True, control=False))

    assert stats.video_tx == 0


def test_runtime_stop_logs_failed_worker_before_cleanup(caplog: LogCaptureFixture) -> None:
    import asyncio

    class FailingAudioCapture:
        frames_per_callback = 0

        def __init__(self) -> None:
            self.closed = False

        async def read_block(self) -> bytes:
            raise RuntimeError("audio capture failed")

        async def aclose(self) -> None:
            self.closed = True

    class FakeConnector(LolaConnector):
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

        assert capture.closed
        assert runtime._tasks == []

    caplog.set_level("ERROR", logger="linux_connector.lola_connector.runtime")
    asyncio.run(run())
    assert "runtime task failed during stop" in caplog.text


def test_runtime_start_rejects_stale_task_handles() -> None:
    import asyncio

    async def run() -> None:
        settings = MediaSettings(width=16, height=8)
        connector = LolaConnector("127.0.0.1", settings)
        connector.session = Session("127.0.0.1", "127.0.0.2", 1, settings)
        runtime = LolaLinuxRuntime(connector, SilenceAudioCapture(settings), MemoryAudioPlayback())
        await runtime.start(receive=False, transmit_audio=False, transmit_video=False, control=False)
        try:
            with pytest.raises(RuntimeError, match="runtime is already started"):
                await runtime.start(receive=False, transmit_audio=False, transmit_video=False, control=False)
        finally:
            await runtime.stop()

    asyncio.run(run())


def test_runtime_control_loop_requires_initialized_socket() -> None:
    import asyncio

    async def run() -> None:
        settings = MediaSettings(width=16, height=8)
        connector = LolaConnector("127.0.0.1", settings)
        connector.session = Session("127.0.0.1", "127.0.0.2", 1, settings)
        runtime = LolaLinuxRuntime(connector, SilenceAudioCapture(settings), MemoryAudioPlayback())
        with pytest.raises(RuntimeError, match="control socket is not initialized"):
            await runtime._control_loop()

    asyncio.run(run())


def test_runtime_audio_tx_checks_socket_before_consuming_capture() -> None:
    import asyncio

    class CountingAudioCapture:
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
        runtime._audio_tx_enabled.set()

        with pytest.raises(RuntimeError, match="audio socket is not initialized"):
            await runtime._audio_tx_loop()

        assert capture.reads == 0

    asyncio.run(run())


def test_runtime_media_rx_logs_unexpected_payload_type(
    monkeypatch: pytest.MonkeyPatch,
    caplog: LogCaptureFixture,
) -> None:
    import asyncio

    async def run() -> None:
        settings = MediaSettings(width=16, height=8)
        connector = LolaConnector("127.0.0.1", settings)
        connector.session = Session("127.0.0.1", "127.0.0.2", 1, settings)
        runtime = LolaLinuxRuntime(connector, SilenceAudioCapture(settings), MemoryAudioPlayback())

        async def fake_recvfrom(_sock: socket.socket, _size: int) -> tuple[bytes, tuple[str, int]]:
            runtime._stop.set()
            return b"unexpected", ("127.0.0.2", 19788)

        monkeypatch.setattr(runtime_module, "udp_recvfrom", fake_recvfrom)
        monkeypatch.setattr(runtime_module, "parse_media_payload", lambda _payload: object())
        caplog.set_level(logging.WARNING, logger="linux_connector.lola_connector.runtime")

        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            await runtime._rx_socket_loop(sock, MediaReassembler(), "audio")

    asyncio.run(run())
    assert "ignored unexpected LoLa audio media payload type object from=127.0.0.2" in caplog.text


def test_runtime_media_rx_counts_malformed_payload_without_task_failure(
    monkeypatch: pytest.MonkeyPatch,
    caplog: LogCaptureFixture,
) -> None:
    import asyncio

    async def run() -> None:
        settings = MediaSettings(width=16, height=8)
        connector = LolaConnector("127.0.0.1", settings)
        connector.session = Session("127.0.0.1", "127.0.0.2", 1, settings)
        runtime = LolaLinuxRuntime(connector, SilenceAudioCapture(settings), MemoryAudioPlayback())

        async def fake_recvfrom(_sock: socket.socket, _size: int) -> tuple[bytes, tuple[str, int]]:
            runtime._stop.set()
            return b"not-a-lola-media-packet", ("127.0.0.2", 19788)

        monkeypatch.setattr(runtime_module, "udp_recvfrom", fake_recvfrom)
        caplog.set_level(logging.WARNING, logger="linux_connector.lola_connector.runtime")

        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            await runtime._rx_socket_loop(sock, MediaReassembler(), "audio")

        assert runtime.stats.audio_malformed_rx == 1

    asyncio.run(run())
    assert "ignored unrecognized LoLa audio media payload" in caplog.text


def test_runtime_control_loop_counts_malformed_payload_without_task_failure(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    import asyncio

    async def run() -> None:
        settings = MediaSettings(width=16, height=8)
        connector = LolaConnector("127.0.0.1", settings)
        connector.session = Session("127.0.0.1", "127.0.0.2", 1, settings)
        runtime = LolaLinuxRuntime(connector, SilenceAudioCapture(settings), MemoryAudioPlayback())

        async def fake_recvfrom(_sock: socket.socket, _size: int) -> tuple[bytes, tuple[str, int]]:
            runtime._stop.set()
            return b"not-a-lola-control-packet", ("127.0.0.2", 7000)

        monkeypatch.setattr(runtime_module, "udp_recvfrom", fake_recvfrom)

        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            runtime._control_sock = sock
            await runtime._control_loop()

        assert runtime.stats.control_malformed_rx == 1

    asyncio.run(run())


def test_runtime_run_for_yields_to_event_loop() -> None:
    import asyncio

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
        await runtime.run_for(0.01, receive=False, transmit_audio=False, transmit_video=False, control=False)
        await marker_task
        assert observed

    asyncio.run(run())
