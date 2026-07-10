"""Integration tests for synthetic backends, runtime, and UDP sockets."""

# pylint: disable=missing-function-docstring

from __future__ import annotations

import asyncio
from dataclasses import fields
import errno
import logging
import socket
from typing import TypeVar

import pytest
from pytest import LogCaptureFixture

from linux_connector.lola_connector.backends import (
    DiagnosticVideoCapture,
    MemoryAudioPlayback,
    MultiToneAudioCapture,
    PatternVideoCapture,
    SilenceAudioCapture,
    SineAudioCapture,
)
from linux_connector.lola_connector.connector import LolaConnector, Session
from linux_connector.lola_connector.media import expected_audio_payload_size
from linux_connector.lola_connector.protocol import MediaSettings
from linux_connector.lola_connector.runtime import LolaLinuxRuntime

T = TypeVar("T")

def expect_true(condition: object, label: str) -> None:
    if not condition:
        pytest.fail(f"{label}: expected truthy value")


def expect_equal(actual: object, expected: object, label: str) -> None:
    if actual != expected:
        pytest.fail(f"{label}: expected {expected!r}, got {actual!r}")


def expect_not_equal(actual: object, expected: object, label: str) -> None:
    if actual == expected:
        pytest.fail(f"{label}: expected value different from {expected!r}")


def expect_less_than(actual: int, threshold: int, label: str) -> None:
    if actual >= threshold:
        pytest.fail(f"{label}: expected value less than {threshold}, got {actual}")


def expect_greater_than(actual: int, threshold: int, label: str) -> None:
    if actual <= threshold:
        pytest.fail(f"{label}: expected value greater than {threshold}, got {actual}")


def expect_is_none(actual: object, label: str) -> None:
    if actual is not None:
        pytest.fail(f"{label}: expected None, got {actual!r}")


def expect_not_none(actual: T | None, label: str) -> T:
    if actual is None:
        pytest.fail(f"{label}: expected non-None value")
    return actual


def expect_instance(actual: object, expected_type: type[T], label: str) -> T:
    if not isinstance(actual, expected_type):
        pytest.fail(f"{label}: expected {expected_type.__name__}, got {type(actual).__name__}")
    return actual


def expect_contains(needle: str, haystack: str, label: str) -> None:
    if needle not in haystack:
        pytest.fail(f"{label}: expected {needle!r} in {haystack!r}")



async def _exercise_test_backends() -> None:
    settings = MediaSettings(width=16, height=8)
    silence = SilenceAudioCapture(settings)
    expect_equal(
        len(await silence.read_block()),
        expected_audio_payload_size(settings.channels),
        "silence audio block size",
    )
    sine = SineAudioCapture(settings)
    expect_equal(
        len(await sine.read_block()),
        expected_audio_payload_size(settings.channels),
        "sine audio block size",
    )
    video = PatternVideoCapture(settings)
    expect_equal(
        len(await video.read_frame()),
        settings.width * settings.height,
        "pattern video frame size",
    )
    tones = MultiToneAudioCapture(settings)
    tone_block = await tones.read_block()
    expect_equal(
        len(tone_block),
        expected_audio_payload_size(settings.channels),
        "multi-tone audio block size",
    )
    diagnostic = DiagnosticVideoCapture(settings)
    diagnostic_frame_a = await diagnostic.read_frame()
    diagnostic_frame_b = await diagnostic.read_frame()
    expect_equal(
        len(diagnostic_frame_a),
        settings.width * settings.height,
        "diagnostic video frame size",
    )
    expect_not_equal(diagnostic_frame_a, diagnostic_frame_b, "diagnostic video frame progression")


async def _exercise_rgb_diagnostic_video() -> None:
    settings = MediaSettings(width=16, height=8, bits_per_pixel=24)
    video = DiagnosticVideoCapture(settings)
    frame = await video.read_frame()
    expect_equal(
        len(frame),
        settings.width * settings.height * 3,
        "RGB diagnostic video frame size",
    )


def test_test_backends_emit_lola_sized_media() -> None:

    asyncio.run(_exercise_test_backends())
    asyncio.run(_exercise_rgb_diagnostic_video())


def test_multi_tone_capture_documents_single_event_loop_phase_state() -> None:

    phase_field = next(field for field in fields(MultiToneAudioCapture) if field.name == "phases")
    expect_equal(
        phase_field.metadata["concurrency"],
        "single-event-loop",
        "multi-tone phase concurrency metadata",
    )


def test_runtime_accepts_backend_contracts() -> None:

    class FakeConnector(LolaConnector):  # pylint: disable=missing-class-docstring
        def __init__(self) -> None:
            settings = MediaSettings(width=16, height=8)
            super().__init__("127.0.0.1", settings, audio_port=19788, video_port=19798)
            self.session = Session("127.0.0.1", "127.0.0.2", 1, settings)
            self.audio_sent = 0
            self.video_sent = 0

        async def send_audio_on_socket(
            self, sock: socket.socket, pcm: bytes, sequence: int
        ) -> None:
            _ = sock
            _ = pcm
            _ = sequence
            self.audio_sent += 1

        async def send_video_on_socket(
            self, sock: socket.socket, frame: bytes, sequence: int
        ) -> None:
            _ = sock
            _ = frame
            _ = sequence
            self.video_sent += 1

        def make_udp_socket(self, bind_port: int = 0) -> socket.socket:
            _ = bind_port
            return socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    settings = MediaSettings(width=16, height=8)
    fake = FakeConnector()
    runtime = LolaLinuxRuntime(
        fake,
        SilenceAudioCapture(settings),
        MemoryAudioPlayback(),
        video_capture=PatternVideoCapture(settings),
        video_display=None,
    )
    stats = asyncio.run(
        runtime.run_for(
            0.06, receive=False, transmit_audio=True, transmit_video=True, control=False
        )
    )
    expect_greater_than(stats.audio_tx, 0, "runtime audio TX count")
    expect_greater_than(stats.video_tx, 0, "runtime video TX count")
    expect_equal(fake.audio_sent, stats.audio_tx, "runtime audio send count")
    expect_equal(fake.video_sent, stats.video_tx, "runtime video send count")


def test_runtime_keeps_tx_disabled_until_requested() -> None:

    class FakeConnector(LolaConnector):  # pylint: disable=missing-class-docstring
        def __init__(self) -> None:
            settings = MediaSettings(width=16, height=8)
            super().__init__("127.0.0.1", settings, audio_port=19788, video_port=19798)
            self.session = Session("127.0.0.1", "127.0.0.2", 1, settings)
            self.audio_sent = 0
            self.video_sent = 0

        async def send_audio_on_socket(
            self, sock: socket.socket, pcm: bytes, sequence: int
        ) -> None:
            _ = sock
            _ = pcm
            _ = sequence
            self.audio_sent += 1

        async def send_video_on_socket(
            self, sock: socket.socket, frame: bytes, sequence: int
        ) -> None:
            _ = sock
            _ = frame
            _ = sequence
            self.video_sent += 1

        def make_udp_socket(self, bind_port: int = 0) -> socket.socket:
            _ = bind_port
            return socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    settings = MediaSettings(width=16, height=8)
    fake = FakeConnector()
    runtime = LolaLinuxRuntime(
        fake,
        SilenceAudioCapture(settings),
        MemoryAudioPlayback(),
        video_capture=PatternVideoCapture(settings),
        video_display=None,
    )
    stats = asyncio.run(
        runtime.run_for(
            0.03,
            receive=False,
            transmit_audio=False,
            transmit_video=False,
            control=False,
        )
    )
    expect_equal(stats.audio_tx, 0, "disabled audio TX stats")
    expect_equal(stats.video_tx, 0, "disabled video TX stats")
    expect_equal(fake.audio_sent, 0, "disabled audio send count")
    expect_equal(fake.video_sent, 0, "disabled video send count")


def test_connector_reuses_media_send_sockets(require_localhost_udp: None) -> None:

    class CountingConnector(LolaConnector):  # pylint: disable=missing-class-docstring
        def __init__(self, audio_port: int, video_port: int):
            super().__init__(
                "127.0.0.1",
                MediaSettings(width=4, height=4),
                audio_port=audio_port,
                video_port=video_port,
            )
            self.opened_ports: list[int] = []

        def make_udp_socket(self, bind_port: int = 0) -> socket.socket:
            self.opened_ports.append(bind_port)
            return super().make_udp_socket(bind_port)

    async def run() -> None:
        audio_probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        video_probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
            audio_probe.bind(("127.0.0.1", 0))
            video_probe.bind(("127.0.0.1", 0))
            audio_port = audio_probe.getsockname()[1]
            video_port = video_probe.getsockname()[1]
        finally:
            audio_probe.close()
            video_probe.close()
        connector = CountingConnector(audio_port, video_port)
        connector.session = Session("127.0.0.1", "127.0.0.1", 1, MediaSettings(width=4, height=4))
        await connector.send_audio(b"\0" * expected_audio_payload_size(channels=2), sequence=1)
        await connector.send_audio(b"\0" * expected_audio_payload_size(channels=2), sequence=2)
        await connector.send_video(b"\0" * 16, sequence=1)
        await connector.send_video(b"\0" * 16, sequence=2)
        connector.close_media_sockets()
        expect_equal(
            connector.opened_ports.count(connector.audio_port),
            1,
            "audio send socket reuse",
        )
        expect_equal(
            connector.opened_ports.count(connector.video_port),
            1,
            "video send socket reuse",
        )

    asyncio.run(run())


def test_connector_logs_and_closes_failed_udp_socket_setup(
    monkeypatch: pytest.MonkeyPatch,
    caplog: LogCaptureFixture,
) -> None:
    class BindFailingSocket:  # pylint: disable=missing-class-docstring
        def __init__(self) -> None:
            self.closed = False

        def setsockopt(self, *_args: int) -> None:
            return None

        def setblocking(self, _flag: bool) -> None:
            return None

        def bind(self, _address: tuple[str, int]) -> None:
            raise OSError(errno.EADDRINUSE, "address already in use")

        def close(self) -> None:
            self.closed = True

    opened = BindFailingSocket()

    def make_socket(_family: int, _kind: int) -> BindFailingSocket:
        return opened

    monkeypatch.setattr(socket, "socket", make_socket)
    caplog.set_level(logging.WARNING, logger="linux_connector.lola_connector.connector")

    connector = LolaConnector("127.0.0.1", MediaSettings())
    with pytest.raises(OSError):
        connector.make_udp_socket(19788)

    expect_true(opened.closed, "failed UDP socket closed")
    expect_contains(
        "UDP socket setup failed for 127.0.0.1:19788",
        caplog.text,
        "UDP setup failure log",
    )
    expect_contains(f"errno={errno.EADDRINUSE}", caplog.text, "UDP setup errno log")
