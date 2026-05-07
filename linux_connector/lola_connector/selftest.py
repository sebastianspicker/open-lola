"""Local bidirectional UDP self-test for the Linux LoLa runtime."""

from __future__ import annotations

import asyncio
import os

from .backends import MemoryAudioPlayback, MemoryVideoDisplay, PatternVideoCapture, SineAudioCapture
from .connector import LolaConnector, Session
from .protocol import DEFAULT_AUDIO_PORT, DEFAULT_CONTROL_PORT, DEFAULT_VIDEO_PORT, MediaSettings
from .runtime import LolaLinuxRuntime


async def run_control_handshake_selftest(
    ip_a: str = "127.0.0.1",
    ip_b: str = "127.0.0.2",
    port_offset: int | None = None,
) -> tuple[Session, Session]:
    settings = MediaSettings(width=16, height=8, fps=25)
    if port_offset is None:
        port_offset = 15000 + (os.getpid() % 15000)
    control_port = DEFAULT_CONTROL_PORT + port_offset
    conn_a = LolaConnector(ip_a, settings, control_port=control_port)
    conn_b = LolaConnector(ip_b, settings, control_port=control_port)
    accept_task = asyncio.create_task(conn_b.accept_once())
    await asyncio.sleep(0)
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
) -> tuple[object, object]:
    settings = MediaSettings(width=16, height=8, fps=25)
    if port_offset is None:
        port_offset = 10000 + (os.getpid() % 20000)
    control_port = DEFAULT_CONTROL_PORT + port_offset
    audio_port = DEFAULT_AUDIO_PORT + port_offset
    video_port = DEFAULT_VIDEO_PORT + port_offset

    conn_a = LolaConnector(ip_a, settings, control_port=control_port, audio_port=audio_port, video_port=video_port)
    conn_b = LolaConnector(ip_b, settings, control_port=control_port, audio_port=audio_port, video_port=video_port)
    conn_a.session = Session(ip_a, ip_b, 0, settings)
    conn_b.session = Session(ip_b, ip_a, 0, settings)

    audio_a = MemoryAudioPlayback()
    audio_b = MemoryAudioPlayback()
    video_a = MemoryVideoDisplay()
    video_b = MemoryVideoDisplay()

    runtime_a = LolaLinuxRuntime(
        conn_a,
        SineAudioCapture(settings),
        audio_a,
        video_capture=PatternVideoCapture(settings),
        video_display=video_a,
    )
    runtime_b = LolaLinuxRuntime(
        conn_b,
        SineAudioCapture(settings, frequency=554.37),
        audio_b,
        video_capture=PatternVideoCapture(settings),
        video_display=video_b,
    )

    await runtime_a.start(receive=True, transmit_audio=True, transmit_video=True, control=True)
    await runtime_b.start(receive=True, transmit_audio=True, transmit_video=True, control=True)
    try:
        await asyncio.sleep(seconds)
    finally:
        await runtime_a.stop()
        await runtime_b.stop()

    if runtime_a.stats.audio_rx == 0 or runtime_b.stats.audio_rx == 0:
        raise AssertionError(f"audio did not flow both ways: a={runtime_a.stats} b={runtime_b.stats}")
    if runtime_a.stats.video_rx == 0 or runtime_b.stats.video_rx == 0:
        raise AssertionError(f"video did not flow both ways: a={runtime_a.stats} b={runtime_b.stats}")
    if not audio_a.blocks or not audio_b.blocks or not video_a.frames or not video_b.frames:
        raise AssertionError("memory sinks did not receive bidirectional media")
    return runtime_a.stats, runtime_b.stats


def main() -> None:
    asyncio.run(run_control_handshake_selftest())
    stats_a, stats_b = asyncio.run(run_bidirectional_selftest())
    print(f"endpoint_a={stats_a}")
    print(f"endpoint_b={stats_b}")


if __name__ == "__main__":
    main()
