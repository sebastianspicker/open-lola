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
import linux_connector.lola_connector.runtime_control as runtime_control_module
from linux_connector.lola_connector.backends import (
    MemoryAudioPlayback,
    MemoryVideoDisplay,
    SilenceAudioCapture,
)
from linux_connector.lola_connector.connector import LolaConnector, Session
from linux_connector.lola_connector.media import build_audio_payload, expected_audio_payload_size
from linux_connector.lola_connector.protocol import MediaSettings
from linux_connector.lola_connector.runtime import LolaLinuxRuntime


def expect_equal(actual: object, expected: object, message: str = "values differ") -> None:
    if actual != expected:
        raise AssertionError(f"{message}: expected {expected!r}, got {actual!r}")


def expect_true(value: object, message: str = "expected truthy value") -> None:
    if not value:
        raise AssertionError(message)


def expect_in(member: object, container: Any) -> None:
    if member not in container:
        raise AssertionError(f"expected {member!r} to be present")


def expect_gt(actual: int, minimum: int) -> None:
    if actual <= minimum:
        raise AssertionError(f"expected {actual!r} to be greater than {minimum!r}")


def _expect_probe_counts(
    result: object, *, reason: str, malformed: int = 0, wrong_peer: int = 0, unexpected: int = 0
) -> None:
    expect_equal(getattr(result, "reason"), reason, "probe reason")
    expect_equal(getattr(result, "malformed_datagrams"), malformed, "probe malformed datagrams")
    expect_equal(getattr(result, "wrong_peer_datagrams"), wrong_peer, "probe wrong-peer datagrams")
    expect_equal(getattr(result, "unexpected_datagrams"), unexpected, "probe unexpected datagrams")


class _QueuedSocket:
    def __init__(self, pending: list[tuple[bytes, tuple[str, int]]]) -> None:
        self.pending = pending

    def recvfrom(self, _size: int) -> tuple[bytes, tuple[str, int]]:
        if not self.pending:
            raise BlockingIOError
        return self.pending.pop(0)


def _runtime_with_session(*, video_display: MemoryVideoDisplay | None = None) -> LolaLinuxRuntime:
    settings = MediaSettings(width=16, height=8)
    connector = LolaConnector("127.0.0.1", settings)
    connector.session = Session("127.0.0.1", "127.0.0.2", 1, settings)
    return LolaLinuxRuntime(
        connector, SilenceAudioCapture(settings), MemoryAudioPlayback(), video_display=video_display
    )


async def _receive_payload(payload: bytes, sender: tuple[str, int]) -> tuple[bytes, tuple[str, int]]:
    await asyncio.sleep(0)
    return payload, sender


async def _receive_payload_on_socket(
    payload: bytes, sock: socket.socket
) -> tuple[bytes, tuple[str, int]]:
    return await _receive_payload(payload, ("127.0.0.2", sock.getsockname()[1]))


@pytest.mark.usefixtures("require_localhost_udp")
def test_accept_once_honors_timeout_without_incoming_quickconn() -> None:

    async def run() -> None:
        connector = LolaConnector("127.0.0.1", control_port=0)
        with pytest.raises(TimeoutError, match="LoLa QuickConn did not arrive"):
            await connector.accept_once(timeout=0.01)

    asyncio.run(run())


@pytest.mark.usefixtures("require_localhost_udp")
def test_accept_once_signals_ready_after_binding() -> None:

    async def run() -> None:
        connector = LolaConnector("127.0.0.1", control_port=0)
        ready = asyncio.Event()
        accept_task = asyncio.create_task(connector.accept_once(timeout=0.01, ready_event=ready))
        await asyncio.wait_for(ready.wait(), timeout=0.5)
        with pytest.raises(TimeoutError, match="LoLa QuickConn did not arrive"):
            await accept_task

    asyncio.run(run())


@pytest.mark.usefixtures("require_localhost_udp")
def test_runtime_without_video_capture_does_not_emit_video_tx() -> None:

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


@pytest.mark.usefixtures("require_localhost_udp")
def test_audio_only_runtime_start_does_not_bind_video_port() -> None:

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


@pytest.mark.usefixtures("require_localhost_udp")
def test_runtime_start_rejects_stale_task_handles() -> None:

    async def run() -> None:
        runtime = _runtime_with_session()
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
        runtime = _runtime_with_session()
        with pytest.raises(RuntimeError, match="control socket is not initialized"):
            await runtime._control_handler.run()  # pylint: disable=protected-access

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


def test_media_send_drops_immediately_when_udp_socket_would_block() -> None:
    class BlockingSocket:  # pylint: disable=missing-class-docstring,too-few-public-methods
        def __init__(self, block_on_call: int) -> None:
            self.block_on_call = block_on_call
            self.calls = 0

        def sendto(self, payload: bytes, address: tuple[str, int]) -> int:
            _ = address
            self.calls += 1
            if self.calls == self.block_on_call:
                raise BlockingIOError("send buffer full")
            return len(payload)

    async def run() -> None:
        settings = MediaSettings(width=64, height=32)
        connector = LolaConnector("127.0.0.1", settings)
        connector.session = Session("127.0.0.1", "127.0.0.2", 1, settings)
        audio_socket = BlockingSocket(block_on_call=1)
        video_socket = BlockingSocket(block_on_call=2)

        audio_sent = await connector.send_audio_on_socket(
            audio_socket, b"\0" * expected_audio_payload_size(channels=2), 4
        )
        video_sent = await connector.send_video_on_socket(video_socket, b"x" * 4096, 5)

        expect_equal(audio_sent, False)
        expect_equal(video_sent, False)
        expect_equal(audio_socket.calls, 1)
        # The second video datagram blocked; no remaining fragments were tried.
        expect_equal(video_socket.calls, 2)

    asyncio.run(run())


def test_runtime_sink_handoffs_are_bounded_and_latest_only() -> None:
    runtime = _runtime_with_session(video_display=MemoryVideoDisplay())

    runtime._enqueue_audio_sink(b"one", 1)  # pylint: disable=protected-access
    runtime._enqueue_audio_sink(b"two", 2)  # pylint: disable=protected-access
    runtime._enqueue_audio_sink(b"three", 3)  # pylint: disable=protected-access
    runtime._enqueue_video_sink(b"old", 1, False)  # pylint: disable=protected-access
    runtime._enqueue_video_sink(b"new", 2, False)  # pylint: disable=protected-access

    expect_equal(runtime.stats.audio_rx_dropped, 2)
    expect_equal(runtime.stats.video_rx_dropped, 1)
    expect_equal(runtime._audio_sink_queue.qsize(), 1)  # pylint: disable=protected-access
    audio_item = runtime._audio_sink_queue.get_nowait()  # pylint: disable=protected-access
    expect_equal(audio_item[1], 3)
    video_item = runtime._video_sink_queue.get_nowait()  # pylint: disable=protected-access
    expect_equal(video_item[1], 2)


def test_runtime_audio_socket_drain_discards_stale_kernel_blocks() -> None:
    class QueuedSocket:  # pylint: disable=missing-class-docstring,too-few-public-methods
        def __init__(self) -> None:
            pcm = b"\0" * expected_audio_payload_size(channels=2)
            self.pending = [
                (build_audio_payload(2, pcm), ("127.0.0.2", 19788)),
                (build_audio_payload(3, pcm), ("127.0.0.2", 19788)),
            ]

        def recvfrom(self, _size: int) -> tuple[bytes, tuple[str, int]]:
            if not self.pending:
                raise BlockingIOError
            return self.pending.pop(0)

    settings = MediaSettings(width=16, height=8)
    connector = LolaConnector("127.0.0.1", settings)
    connector.session = Session("127.0.0.1", "127.0.0.2", 1, settings)
    runtime = LolaLinuxRuntime(connector, SilenceAudioCapture(settings), MemoryAudioPlayback())
    drain = getattr(runtime, "_drain_audio_to_newest")

    payload, addr = drain(
        QueuedSocket(),
        build_audio_payload(1, b"\0" * expected_audio_payload_size(channels=2)),
        ("127.0.0.2", 19788),
    )

    expect_equal(payload, build_audio_payload(3, b"\0" * expected_audio_payload_size(channels=2)))
    expect_equal(addr, ("127.0.0.2", 19788))
    expect_equal(runtime.stats.audio_rx_kernel_dropped, 2)


def test_runtime_audio_drain_keeps_newest_valid_packet_despite_invalid_tail() -> None:
    runtime = _runtime_with_session()
    pcm = b"\0" * expected_audio_payload_size(channels=2)
    valid_one = build_audio_payload(1, pcm)
    valid_two = build_audio_payload(2, pcm)
    newest = runtime._drain_audio_to_newest(  # pylint: disable=protected-access
        _QueuedSocket(
            [
                (b"bad", ("127.0.0.9", 19788)),
                (valid_two, ("127.0.0.2", 19788)),
                (b"bad", ("127.0.0.2", 19788)),
                (build_audio_payload(9, b"\0"), ("127.0.0.2", 19788)),
                (valid_one, ("127.0.0.2", 19999)),
            ]
        ),
        valid_one,
        ("127.0.0.2", 19788),
    )

    expect_equal(newest, (valid_two, ("127.0.0.2", 19788)))
    expect_equal(runtime.stats.audio_rx_kernel_dropped, 1)
    expect_equal(runtime.stats.audio_rx_wrong_peer_dropped, 1)
    expect_equal(runtime.stats.audio_rx_wrong_port_dropped, 1)
    expect_equal(runtime.stats.audio_rx_malformed_dropped, 2)


def test_runtime_audio_drain_and_sink_use_modulo_sequence_ordering() -> None:
    runtime = _runtime_with_session()
    pcm = b"\0" * expected_audio_payload_size(channels=2)
    newest = runtime._drain_audio_to_newest(  # pylint: disable=protected-access
        _QueuedSocket([
            (build_audio_payload(0xFFFFFFFE, pcm), ("127.0.0.2", 19788)),
            (build_audio_payload(0xFFFFFFFD, pcm), ("127.0.0.2", 19788)),
            (build_audio_payload(0xFFFFFFFE, pcm), ("127.0.0.2", 19788)),
            (build_audio_payload(0, pcm), ("127.0.0.2", 19788)),
        ]),
        build_audio_payload(0xFFFFFFFE, pcm),
        ("127.0.0.2", 19788),
    )
    expect_equal(newest, (build_audio_payload(0, pcm), ("127.0.0.2", 19788)))
    expect_equal(runtime.stats.audio_rx_reordered_dropped, 3)

    runtime._enqueue_audio_sink(b"new", 0)  # pylint: disable=protected-access
    runtime._enqueue_audio_sink(b"old", 0xFFFFFFFF)  # pylint: disable=protected-access
    runtime._enqueue_audio_sink(b"duplicate", 0)  # pylint: disable=protected-access
    expect_equal(runtime._audio_sink_queue.get_nowait(), (b"new", 0))  # pylint: disable=protected-access
    expect_equal(runtime.stats.audio_rx_reordered_dropped, 5)


def test_runtime_video_stale_frame_is_dropped_before_transmit() -> None:
    class NeverSendConnector(LolaConnector):  # pylint: disable=missing-class-docstring
        async def send_video_until_on_socket(self, *_args: object, **_kwargs: object) -> str:
            raise AssertionError("stale frame must not be sent")

    class UnusedCapture:  # pylint: disable=missing-class-docstring,too-few-public-methods
        async def read_frame(self) -> bytes:
            raise AssertionError("stale frame test must not capture")

    async def run() -> None:
        settings = MediaSettings(width=16, height=8)
        connector = NeverSendConnector("127.0.0.1", settings)
        connector.session = Session("127.0.0.1", "127.0.0.2", 1, settings)
        runtime = LolaLinuxRuntime(
            connector,
            SilenceAudioCapture(settings),
            MemoryAudioPlayback(),
            video_capture=UnusedCapture(),
        )
        runtime._video_sock = object()  # type: ignore[assignment]  # pylint: disable=protected-access
        runtime._video_tx_enabled.set()  # pylint: disable=protected-access
        runtime._video_tx_queue.put_nowait(  # pylint: disable=protected-access
            runtime_module.CapturedVideoFrame(b"stale", captured_at=0.0)
        )
        task = asyncio.create_task(runtime._video_tx_loop())  # pylint: disable=protected-access
        await asyncio.sleep(0)
        runtime._stop.set()  # pylint: disable=protected-access
        task.cancel()
        with pytest.raises(asyncio.CancelledError):
            await task
        expect_equal(runtime.stats.video_tx_deadline_dropped, 1)
        expect_equal(runtime.stats.video_tx_dropped, 1)

    asyncio.run(run())


def test_audio_pacer_resumes_one_quantum_after_any_missed_deadline(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    settings = MediaSettings(width=16, height=8)
    connector = LolaConnector("127.0.0.1", settings)
    runtime = LolaLinuxRuntime(connector, SilenceAudioCapture(settings), MemoryAudioPlayback())
    pacing = runtime_module.AudioTxPacing(external=True, interval=0.001, next_send=1.0)
    monkeypatch.setattr(runtime_module.time, "perf_counter", lambda: 1.0015)

    runtime._advance_audio_tx_deadline(pacing)  # pylint: disable=protected-access

    expect_equal(pacing.next_send, 1.0025)


def test_memory_sinks_have_fixed_diagnostic_capacity() -> None:
    async def run() -> None:
        audio = MemoryAudioPlayback(capacity=1)
        video = MemoryVideoDisplay(capacity=1)
        await audio.write_block(b"one", 1)
        await audio.write_block(b"two", 2)
        await video.show_frame(b"one", 1, False)
        await video.show_frame(b"two", 2, False)
        expect_equal(len(audio.blocks), 1)
        expect_equal(audio.dropped_blocks, 1)
        expect_equal(len(video.frames), 1)
        expect_equal(video.dropped_frames, 1)

    asyncio.run(run())


@pytest.mark.usefixtures("require_localhost_udp")
def test_runtime_media_rx_logs_unexpected_payload_type(
    monkeypatch: pytest.MonkeyPatch,
    caplog: LogCaptureFixture,
) -> None:

    async def run() -> None:
        runtime = _runtime_with_session()
        monkeypatch.setattr(
            runtime_module,
            "udp_recvfrom",
            lambda sock, _size: _receive_payload_on_socket(b"unexpected", sock),
        )
        monkeypatch.setattr(runtime_module, "parse_media_payload", lambda _payload: object())
        caplog.set_level(logging.WARNING, logger="linux_connector.lola_connector.runtime")

        await runtime.run_for(
            0.01, receive=True, transmit_audio=False, transmit_video=False, control=False
        )

    asyncio.run(run())
    expect_in("ignored unexpected LoLa", caplog.text)
    expect_in("media payload type object from=127.0.0.2", caplog.text)


@pytest.mark.usefixtures("require_localhost_udp")
def test_runtime_media_rx_counts_malformed_payload_without_task_failure(
    monkeypatch: pytest.MonkeyPatch,
    caplog: LogCaptureFixture,
) -> None:

    async def run() -> None:
        runtime = _runtime_with_session()
        monkeypatch.setattr(
            runtime_module,
            "udp_recvfrom",
            lambda sock, _size: _receive_payload_on_socket(b"not-a-lola-media-packet", sock),
        )
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


@pytest.mark.usefixtures("require_localhost_udp")
def test_runtime_control_loop_counts_malformed_payload_without_task_failure(
    monkeypatch: pytest.MonkeyPatch,
) -> None:

    async def run() -> None:
        runtime = _runtime_with_session()
        monkeypatch.setattr(
            runtime_control_module,
            "udp_recvfrom",
            lambda sock, _size: _receive_payload(b"not-a-lola-control-packet", ("127.0.0.2", 7000)),
        )

        await runtime.run_for(
            0.01, receive=False, transmit_audio=False, transmit_video=False, control=True
        )

        expect_gt(runtime.stats.control_malformed_rx, 0)

    asyncio.run(run())


@pytest.mark.usefixtures("require_localhost_udp")
def test_runtime_run_for_yields_to_event_loop() -> None:

    async def run() -> None:
        runtime = _runtime_with_session()
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
