"""Tests for Linux runtime media delivery contracts."""

# pylint: disable=missing-function-docstring

from __future__ import annotations

import asyncio
import socket
from types import SimpleNamespace
from typing import cast

import pytest

from linux_connector.lola_connector.backends import MemoryAudioPlayback, MemoryVideoDisplay, SilenceAudioCapture
from linux_connector.lola_connector.connector import Session
from linux_connector.lola_connector.connector_impl import LolaConnector
from linux_connector.lola_connector.media import (
    MediaReassembler,
    build_audio_payload,
    build_video_payloads,
    expected_audio_payload_size,
)
from linux_connector.lola_connector.protocol import MediaSettings
from linux_connector.lola_connector.runtime import LolaLinuxRuntime
from linux_connector.lola_connector.runtime_types import CapturedVideoFrame
from linux_connector.tests.support import expect_equal, runtime_with_session


class _QueuedSocket:
    def __init__(self, pending: list[tuple[bytes, tuple[str, int]]]) -> None:
        self.pending = pending

    def recvfrom(self, _size: int) -> tuple[bytes, tuple[str, int]]:
        if not self.pending:
            raise BlockingIOError
        return self.pending.pop(0)


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
            cast(socket.socket, audio_socket),
            b"\0" * expected_audio_payload_size(channels=2),
            4,
        )
        video_sent = await connector.send_video_on_socket(cast(socket.socket, video_socket), b"x" * 4096, 5)

        expect_equal(audio_sent, False)
        expect_equal(video_sent, False)
        expect_equal(audio_socket.calls, 1)
        # The second video datagram blocked; no remaining fragments were tried.
        expect_equal(video_socket.calls, 2)

    asyncio.run(run())


def test_runtime_sink_handoffs_are_bounded_and_latest_only() -> None:
    runtime = runtime_with_session(video_display=MemoryVideoDisplay())

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


def test_runtime_accepts_exact_raw_frame_using_remote_not_local_geometry() -> None:
    async def run() -> None:
        local_settings = MediaSettings(width=16, height=8, bits_per_pixel=8)
        remote_settings = MediaSettings(width=3, height=2, bits_per_pixel=16, compression=0)
        connector = LolaConnector("127.0.0.1", local_settings)
        session = Session("127.0.0.1", "127.0.0.2", 1, remote_settings)
        connector.session = session
        runtime = LolaLinuxRuntime(
            connector,
            SilenceAudioCapture(local_settings),
            MemoryAudioPlayback(),
            video_display=MemoryVideoDisplay(),
        )
        frame = bytes(range(12))
        reassembler = MediaReassembler()

        for packet in build_video_payloads(7, frame):
            await runtime._handle_media_payload(  # pylint: disable=protected-access
                packet, session.remote_ip, session, reassembler, "video"
            )

        expect_equal(runtime._video_sink_queue.get_nowait(), (frame, 7, False))  # pylint: disable=protected-access
        expect_equal(runtime.stats.video_malformed_rx, 0)

    asyncio.run(run())


def test_runtime_drops_wrong_length_raw_frame_without_shifting_next_frame() -> None:
    async def run() -> None:
        settings = MediaSettings(width=3, height=2, bits_per_pixel=16, compression=0)
        connector = LolaConnector("127.0.0.1", settings)
        session = Session("127.0.0.1", "127.0.0.2", 1, settings)
        connector.session = session
        runtime = LolaLinuxRuntime(
            connector,
            SilenceAudioCapture(settings),
            MemoryAudioPlayback(),
            video_display=MemoryVideoDisplay(),
        )
        wrong_reassembler = MediaReassembler()
        for packet in build_video_payloads(7, bytes(11)):
            await runtime._handle_media_payload(  # pylint: disable=protected-access
                packet, session.remote_ip, session, wrong_reassembler, "video"
            )
        valid_frame = bytes(range(12))
        valid_reassembler = MediaReassembler()
        for packet in build_video_payloads(8, valid_frame):
            await runtime._handle_media_payload(  # pylint: disable=protected-access
                packet, session.remote_ip, session, valid_reassembler, "video"
            )

        expect_equal(runtime.stats.video_malformed_rx, 1)
        expect_equal(runtime.stats.video_rx_dropped, 1)
        expect_equal(runtime._video_sink_queue.get_nowait(), (valid_frame, 8, False))  # pylint: disable=protected-access

    asyncio.run(run())


def test_runtime_drops_raw_frames_with_invalid_negotiated_geometry() -> None:
    runtime = runtime_with_session(video_display=MemoryVideoDisplay())
    invalid_settings = SimpleNamespace(width=0, height=2, bits_per_pixel=7)

    accepted = runtime._accept_remote_video_frame(  # pylint: disable=protected-access
        b"", invalid_settings, compressed=False
    )

    expect_equal(accepted, False)
    expect_equal(runtime.stats.video_malformed_rx, 1)
    expect_equal(runtime.stats.video_rx_dropped, 1)


def test_runtime_accepts_compressed_frame_at_different_remote_geometry() -> None:
    async def run() -> None:
        local_settings = MediaSettings(width=16, height=8, compression=0)
        remote_settings = MediaSettings(width=1920, height=1080, bits_per_pixel=24, compression=1)
        connector = LolaConnector("127.0.0.1", local_settings)
        session = Session("127.0.0.1", "127.0.0.2", 1, remote_settings)
        connector.session = session
        runtime = LolaLinuxRuntime(
            connector,
            SilenceAudioCapture(local_settings),
            MemoryAudioPlayback(),
            video_display=MemoryVideoDisplay(),
        )
        frame = b"\xff\xd8compressed\xff\xd9"
        reassembler = MediaReassembler()
        for packet in build_video_payloads(9, frame):
            await runtime._handle_media_payload(  # pylint: disable=protected-access
                packet, session.remote_ip, session, reassembler, "video"
            )

        expect_equal(runtime._video_sink_queue.get_nowait(), (frame, 9, True))  # pylint: disable=protected-access
        expect_equal(runtime.stats.video_malformed_rx, 0)

    asyncio.run(run())


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
    drain = runtime._drain_audio_to_newest

    payload, addr = drain(
        QueuedSocket(),
        build_audio_payload(1, b"\0" * expected_audio_payload_size(channels=2)),
        ("127.0.0.2", 19788),
    )

    expect_equal(payload, build_audio_payload(3, b"\0" * expected_audio_payload_size(channels=2)))
    expect_equal(addr, ("127.0.0.2", 19788))
    expect_equal(runtime.stats.audio_rx_kernel_dropped, 2)


def test_runtime_audio_drain_keeps_newest_valid_packet_despite_invalid_tail() -> None:
    runtime = runtime_with_session()
    pcm = b"\0" * expected_audio_payload_size(channels=2)
    valid_one = build_audio_payload(1, pcm)
    valid_two = build_audio_payload(2, pcm)
    newest = runtime._drain_audio_to_newest(  # pylint: disable=protected-access
        cast(
            socket.socket,
            _QueuedSocket(
                [
                    (b"bad", ("127.0.0.9", 19788)),
                    (valid_two, ("127.0.0.2", 19788)),
                    (b"bad", ("127.0.0.2", 19788)),
                    (build_audio_payload(9, b"\0"), ("127.0.0.2", 19788)),
                    (valid_one, ("127.0.0.2", 19999)),
                ]
            ),
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
    runtime = runtime_with_session()
    pcm = b"\0" * expected_audio_payload_size(channels=2)
    newest = runtime._drain_audio_to_newest(  # pylint: disable=protected-access
        cast(
            socket.socket,
            _QueuedSocket(
                [
                    (build_audio_payload(0xFFFFFFFE, pcm), ("127.0.0.2", 19788)),
                    (build_audio_payload(0xFFFFFFFD, pcm), ("127.0.0.2", 19788)),
                    (build_audio_payload(0xFFFFFFFE, pcm), ("127.0.0.2", 19788)),
                    (build_audio_payload(0, pcm), ("127.0.0.2", 19788)),
                ]
            ),
        ),
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
            CapturedVideoFrame(b"stale", captured_at=0.0)
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
