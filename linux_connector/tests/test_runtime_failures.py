"""Tests for runtime startup cleanup and UDP self-tests."""

# pylint: disable=missing-function-docstring

from __future__ import annotations

import asyncio

import pytest

from linux_connector.lola_connector.backends import MemoryAudioPlayback, SilenceAudioCapture
from linux_connector.lola_connector.connector import LolaConnector, Session
from linux_connector.lola_connector.protocol import MediaSettings
from linux_connector.lola_connector.runtime import LolaLinuxRuntime
from linux_connector.lola_connector.selftest import (
    loopback_alias_capability,
    run_bidirectional_selftest,
    run_control_handshake_selftest,
)

def expect_true(condition: object, label: str) -> None:
    if not condition:
        pytest.fail(f"{label}: expected truthy value")



def expect_equal(actual: object, expected: object, label: str) -> None:
    if actual != expected:
        pytest.fail(f"{label}: expected {expected!r}, got {actual!r}")



def expect_greater_than(actual: int, threshold: int, label: str) -> None:
    if actual <= threshold:
        pytest.fail(f"{label}: expected value greater than {threshold}, got {actual}")



def require_loopback_alias(ip: str = "127.0.0.2") -> None:
    available, message = loopback_alias_capability(ip)
    if not available:
        pytest.skip(message)



class RuntimeFailureFakeSocket:  # pylint: disable=missing-class-docstring
    def __init__(self) -> None:
        """Create an open fake socket."""
        self.closed = False

    def fileno(self) -> int:
        return -1

    def getsockname(self) -> tuple[str, int]:
        return ("127.0.0.1", 0)

    def close(self) -> None:
        self.closed = True


class RuntimeFailureAudioCapture(SilenceAudioCapture):  # pylint: disable=missing-class-docstring
    def __init__(self, settings: MediaSettings) -> None:
        """Create a close-tracking audio capture."""
        super().__init__(settings)
        self.closed = False

    async def aclose(self) -> None:
        self.closed = True


class RuntimeFailurePlayback(MemoryAudioPlayback):  # pylint: disable=missing-class-docstring
    def __init__(self) -> None:
        """Create a close-tracking audio playback."""
        super().__init__()
        self.closed = False

    async def aclose(self) -> None:
        self.closed = True


class RuntimeFailureVideoCapture:  # pylint: disable=missing-class-docstring
    def __init__(self) -> None:
        """Create a close-tracking video capture."""
        self.closed = False

    async def read_frame(self) -> bytes:
        return b"frame"

    async def aclose(self) -> None:
        self.closed = True


class RuntimeFailureVideoDisplay:  # pylint: disable=missing-class-docstring
    def __init__(self) -> None:
        """Create a close-tracking video display."""
        self.closed = False

    async def show_frame(self, frame: bytes, sequence: int, compressed: bool) -> None:
        _ = frame
        _ = sequence
        _ = compressed

    async def aclose(self) -> None:
        self.closed = True


async def run_runtime_start_failure_case(fail_on_call: int) -> None:
    settings = MediaSettings()
    connector = LolaConnector("127.0.0.1", settings)
    connector.session = Session("127.0.0.1", "127.0.0.2", 1, settings)
    sockets: list[RuntimeFailureFakeSocket] = []

    def make_udp_socket(bind_port: int = 0) -> RuntimeFailureFakeSocket:
        _ = bind_port
        if len(sockets) + 1 == fail_on_call:
            raise OSError("socket setup failed")
        sock = RuntimeFailureFakeSocket()
        sockets.append(sock)
        return sock

    connector.make_udp_socket = make_udp_socket  # type: ignore[assignment,method-assign]
    audio_capture = RuntimeFailureAudioCapture(settings)
    audio_playback = RuntimeFailurePlayback()
    video_capture = RuntimeFailureVideoCapture()
    video_display = RuntimeFailureVideoDisplay()
    runtime = LolaLinuxRuntime(
        connector, audio_capture, audio_playback, video_capture, video_display
    )

    with pytest.raises(OSError, match="socket setup failed"):
        await runtime.start()

    expect_true(sockets, "partially opened runtime sockets")
    expect_true(all(sock.closed for sock in sockets), "partial runtime socket cleanup")
    expect_true(audio_capture.closed, "partial audio capture cleanup")
    expect_true(audio_playback.closed, "partial audio playback cleanup")
    expect_true(video_capture.closed, "partial video capture cleanup")
    expect_true(video_display.closed, "partial video display cleanup")


def test_runtime_start_failure_closes_partial_socket_and_backend_setup() -> None:

    asyncio.run(run_runtime_start_failure_case(fail_on_call=2))
    asyncio.run(run_runtime_start_failure_case(fail_on_call=3))


def test_bidirectional_udp_runtime_selftest() -> None:

    require_loopback_alias()
    stats_a, stats_b = asyncio.run(run_bidirectional_selftest(seconds=0.12, port_offset=21000))
    expect_greater_than(stats_a.audio_rx, 0, "selftest peer A audio RX")
    expect_greater_than(stats_b.audio_rx, 0, "selftest peer B audio RX")
    expect_greater_than(stats_a.video_rx, 0, "selftest peer A video RX")
    expect_greater_than(stats_b.video_rx, 0, "selftest peer B video RX")


def test_control_handshake_udp_selftest() -> None:

    require_loopback_alias()
    session_a, session_b = asyncio.run(run_control_handshake_selftest(port_offset=23000))
    expect_equal(session_a.remote_ip, "127.0.0.2", "selftest peer A remote IP")
    expect_equal(session_b.remote_ip, "127.0.0.1", "selftest peer B remote IP")
