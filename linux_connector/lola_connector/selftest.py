# pylint: disable=missing-function-docstring
"""Local bidirectional UDP self-test for the Linux LoLa runtime."""

from __future__ import annotations

import asyncio
from dataclasses import dataclass
import os
import socket

from .backends import MemoryAudioPlayback, MemoryVideoDisplay, PatternVideoCapture, SineAudioCapture
from .connector import LolaConnector, Session
from .protocol import DEFAULT_AUDIO_PORT, DEFAULT_CONTROL_PORT, DEFAULT_VIDEO_PORT, MediaSettings
from .runtime import LolaLinuxRuntime, RuntimeStats


def default_port_offset() -> int:
    """Return a bounded offset that keeps all LoLa self-test ports below 49152."""
    return os.getpid() % 5000


def loopback_alias_capability(ip: str = "127.0.0.2") -> tuple[bool, str]:
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.bind((ip, 0))
    except OSError as exc:
        return False, f"loopback alias {ip} is not available: {exc}"
    finally:
        sock.close()
    return True, f"loopback alias {ip} is available"


@dataclass
class _SelftestEndpoint:
    runtime: LolaLinuxRuntime
    audio: MemoryAudioPlayback
    video: MemoryVideoDisplay


async def run_control_handshake_selftest(
    ip_a: str = "127.0.0.1",
    ip_b: str = "127.0.0.2",
    port_offset: int | None = None,
) -> tuple[Session, Session]:
    settings = MediaSettings(width=16, height=8, fps=25)
    if port_offset is None:
        port_offset = default_port_offset()
    control_port = DEFAULT_CONTROL_PORT + port_offset
    conn_a = LolaConnector(ip_a, settings, control_port=control_port)
    conn_b = LolaConnector(ip_b, settings, control_port=control_port)
    accept_ready = asyncio.Event()
    accept_task = asyncio.create_task(conn_b.accept_once(ready_event=accept_ready))
    await asyncio.wait_for(accept_ready.wait(), timeout=1.0)
    session_a = await conn_a.initiate(ip_b, sid=0)
    session_b = await asyncio.wait_for(accept_task, timeout=1.0)
    if session_a.remote_ip != ip_b or session_b.remote_ip != ip_a:
        raise AssertionError(f"bad sessions: a={session_a} b={session_b}")
    return session_a, session_b


async def run_bidirectional_selftest(
    seconds: float = 0.25,
    ip_a: str = "127.0.0.1",
    ip_b: str = "127.0.0.2",
    port_offset: int | None = None,
) -> tuple[RuntimeStats, RuntimeStats]:
    settings, control_port, audio_port, video_port = _selftest_ports(port_offset)
    endpoint_a = _build_selftest_endpoint(
        ip_a, ip_b, settings, control_port, audio_port, video_port
    )
    endpoint_b = _build_selftest_endpoint(
        ip_b,
        ip_a,
        settings,
        control_port,
        audio_port,
        video_port,
        frequency=554.37,
    )

    await _start_bidirectional_runtimes(endpoint_a.runtime, endpoint_b.runtime)
    try:
        await asyncio.sleep(seconds)
    finally:
        await _stop_bidirectional_runtimes(endpoint_a.runtime, endpoint_b.runtime)

    _assert_bidirectional_media(endpoint_a, endpoint_b)
    return endpoint_a.runtime.stats, endpoint_b.runtime.stats


def _selftest_ports(port_offset: int | None) -> tuple[MediaSettings, int, int, int]:
    offset = default_port_offset() if port_offset is None else port_offset
    settings = MediaSettings(width=16, height=8, fps=25)
    return (
        settings,
        DEFAULT_CONTROL_PORT + offset,
        DEFAULT_AUDIO_PORT + offset,
        DEFAULT_VIDEO_PORT + offset,
    )


def _build_selftest_endpoint(  # pylint: disable=too-many-arguments,too-many-positional-arguments
    local_ip: str,
    remote_ip: str,
    settings: MediaSettings,
    control_port: int,
    audio_port: int,
    video_port: int,
    frequency: float = 440.0,
) -> _SelftestEndpoint:
    connector = LolaConnector(
        local_ip,
        settings,
        control_port=control_port,
        audio_port=audio_port,
        video_port=video_port,
    )
    connector.session = Session(local_ip, remote_ip, 0, settings)
    audio = MemoryAudioPlayback()
    video = MemoryVideoDisplay()
    runtime = LolaLinuxRuntime(
        connector,
        SineAudioCapture(settings, frequency=frequency),
        audio,
        video_capture=PatternVideoCapture(settings),
        video_display=video,
    )
    return _SelftestEndpoint(runtime, audio, video)


async def _start_bidirectional_runtimes(
    runtime_a: LolaLinuxRuntime, runtime_b: LolaLinuxRuntime
) -> None:
    await runtime_a.start(receive=True, transmit_audio=True, transmit_video=True, control=True)
    await runtime_b.start(receive=True, transmit_audio=True, transmit_video=True, control=True)


async def _stop_bidirectional_runtimes(
    runtime_a: LolaLinuxRuntime, runtime_b: LolaLinuxRuntime
) -> None:
    await runtime_a.stop()
    await runtime_b.stop()


def _assert_bidirectional_media(
    endpoint_a: _SelftestEndpoint, endpoint_b: _SelftestEndpoint
) -> None:
    stats_a = endpoint_a.runtime.stats
    stats_b = endpoint_b.runtime.stats
    _assert_audio_flowed(stats_a, stats_b)
    _assert_video_flowed(stats_a, stats_b)
    _assert_memory_sinks_received(endpoint_a, endpoint_b)


def _assert_audio_flowed(stats_a: RuntimeStats, stats_b: RuntimeStats) -> None:
    if stats_a.audio_rx == 0 or stats_b.audio_rx == 0:
        raise AssertionError(f"audio did not flow both ways: a={stats_a} b={stats_b}")


def _assert_video_flowed(stats_a: RuntimeStats, stats_b: RuntimeStats) -> None:
    if stats_a.video_rx == 0 or stats_b.video_rx == 0:
        raise AssertionError(f"video did not flow both ways: a={stats_a} b={stats_b}")


def _assert_memory_sinks_received(
    endpoint_a: _SelftestEndpoint, endpoint_b: _SelftestEndpoint
) -> None:
    if not _endpoint_sinks_received(endpoint_a) or not _endpoint_sinks_received(endpoint_b):
        raise AssertionError("memory sinks did not receive bidirectional media")


def _endpoint_sinks_received(endpoint: _SelftestEndpoint) -> bool:
    return bool(endpoint.audio.blocks and endpoint.video.frames)


def main() -> None:
    asyncio.run(run_control_handshake_selftest())
    stats_a, stats_b = asyncio.run(run_bidirectional_selftest())
    print(f"endpoint_a={stats_a}")
    print(f"endpoint_b={stats_b}")


if __name__ == "__main__":
    main()
