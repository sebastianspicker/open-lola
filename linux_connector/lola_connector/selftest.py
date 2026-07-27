# pylint: disable=missing-function-docstring
"""Local bidirectional UDP self-test for the Linux LoLa runtime."""

from __future__ import annotations

import asyncio
from dataclasses import dataclass
import os
import socket
import time

from .backends import MemoryAudioPlayback, MemoryVideoDisplay, PatternVideoCapture, SineAudioCapture
from .connector import Session, udp_sendto
from .connector_impl import LolaConnector
from .media import build_audio_payload, iter_video_payloads
from .protocol import (
    DEFAULT_AUDIO_PORT,
    DEFAULT_CONTROL_PORT,
    DEFAULT_VIDEO_PORT,
    MediaSettings,
    build_control_datagram,
    build_osc15_control_datagram,
)
from .runtime import LolaLinuxRuntime
from .runtime_types import RuntimeStats


def default_port_offset() -> int:
    """Return a bounded offset that keeps all LoLa self-test ports below 49152."""
    return os.getpid() % 5000


def loopback_alias_capability(ip: str = "127.0.0.2") -> tuple[bool, str]:
    """Probe whether the requested loopback alias can bind a UDP socket."""
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


@dataclass(frozen=True)
class _SelftestPorts:
    """Keep same-host self-test endpoints separate without a loopback alias."""

    control: int
    audio: int
    video: int


class _SelftestConnector(LolaConnector):
    """Route a synthetic endpoint to its same-address peer's distinct ports."""

    def __init__(
        self,
        local_ip: str,
        settings: MediaSettings,
        local_ports: _SelftestPorts,
        peer_ports: _SelftestPorts,
    ) -> None:
        super().__init__(
            local_ip,
            settings,
            control_port=local_ports.control,
            audio_port=local_ports.audio,
            video_port=local_ports.video,
        )
        self._peer_ports = peer_ports

    @property
    def peer_ports(self) -> _SelftestPorts:
        """Return the paired endpoint ports used by the self-test adapter."""
        return self._peer_ports

    async def _send_control(  # pylint: disable=too-many-arguments,too-many-positional-arguments
        self,
        sock: socket.socket,
        kind: str,
        remote_ip: str,
        sid: int,
        txt: str = "",
        dialect: str | None = None,
        settings: MediaSettings | None = None,
    ) -> None:
        selected = dialect or self.control_dialect
        if selected == "osc15":
            datagram = build_osc15_control_datagram(
                kind,
                self.local_ip,
                remote_ip,
                sid,
                settings or self.settings,
                txt,
                source_name=self.source_name,
            )
        else:
            datagram = build_control_datagram(
                kind, self.local_ip, remote_ip, sid, settings or self.settings, txt
            )
        await udp_sendto(sock, datagram, (remote_ip, self._peer_ports.control))

    async def send_audio_on_socket(self, sock: socket.socket, pcm: bytes, sequence: int) -> bool:
        payload = build_audio_payload(sequence, pcm)
        session = self.session
        if session is None:
            raise RuntimeError("no active LoLa session")
        return await udp_sendto(sock, payload, (session.remote_ip, self._peer_ports.audio))

    async def send_video_until_on_socket(
        self,
        sock: socket.socket,
        frame: bytes,
        sequence: int,
        *,
        deadline: float | None,
    ) -> str:
        session = self.session
        if session is None:
            raise RuntimeError("no active LoLa session")
        for payload in iter_video_payloads(sequence, frame, packet_size=self.video_packet_size):
            if deadline is not None and time.perf_counter() >= deadline:
                return "deadline"
            if not await udp_sendto(sock, payload, (session.remote_ip, self._peer_ports.video)):
                return "backpressure"
            await asyncio.sleep(0)
        return "sent"


class _SelftestRuntime(LolaLinuxRuntime):
    """Validate media source ports against the paired synthetic endpoint."""

    @property
    def _peer_ports(self) -> _SelftestPorts:
        connector = self.connector
        if not isinstance(connector, _SelftestConnector):
            raise TypeError("self-test runtime requires _SelftestConnector")
        return connector.peer_ports

    def _audio_session_for_sender(self, addr: tuple[str, int]) -> Session | None:
        session = self.connector.session
        if session is None or addr[0] != session.remote_ip:
            return None
        return session if addr[1] == self._peer_ports.audio else None

    def _count_audio_drain_discard(self, _payload: bytes, addr: tuple[str, int]) -> None:
        session = self.connector.session
        if session is None or addr[0] != session.remote_ip:
            self.stats.audio_rx_wrong_peer_dropped += 1
        elif addr[1] != self._peer_ports.audio:
            self.stats.audio_rx_wrong_port_dropped += 1
        else:
            self.stats.audio_rx_malformed_dropped += 1

    def _session_for_media_sender(self, addr: tuple[str, int], kind: str) -> Session | None:
        session = self.connector.session
        if session is None or addr[0] != session.remote_ip:
            return None
        expected_port = self._peer_ports.audio if kind == "audio" else self._peer_ports.video
        if addr[1] != expected_port:
            self._count_malformed_media(kind)
            return None
        return session


async def run_control_handshake_selftest(
    ip_a: str = "127.0.0.1",
    ip_b: str = "127.0.0.1",
    port_offset: int | None = None,
) -> tuple[Session, Session]:
    """Exercise a loopback QuickConn handshake using the selected port offset."""
    settings, ports_a, ports_b = _selftest_ports(port_offset)
    conn_a = _SelftestConnector(ip_a, settings, ports_a, ports_b)
    conn_b = _SelftestConnector(ip_b, settings, ports_b, ports_a)
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
    ip_b: str = "127.0.0.1",
    port_offset: int | None = None,
) -> tuple[RuntimeStats, RuntimeStats]:
    """Exchange bounded synthetic media between two loopback runtime endpoints."""
    settings, ports_a, ports_b = _selftest_ports(port_offset)
    endpoint_a = _build_selftest_endpoint(ip_a, ip_b, settings, ports_a, ports_b)
    endpoint_b = _build_selftest_endpoint(
        ip_b,
        ip_a,
        settings,
        ports_b,
        ports_a,
        frequency=554.37,
    )

    await _start_bidirectional_runtimes(endpoint_a.runtime, endpoint_b.runtime)
    try:
        await asyncio.sleep(seconds)
    finally:
        await _stop_bidirectional_runtimes(endpoint_a.runtime, endpoint_b.runtime)

    _assert_bidirectional_media(endpoint_a, endpoint_b)
    return endpoint_a.runtime.stats, endpoint_b.runtime.stats


def _selftest_ports(port_offset: int | None) -> tuple[MediaSettings, _SelftestPorts, _SelftestPorts]:
    offset = default_port_offset() if port_offset is None else port_offset
    settings = MediaSettings(width=16, height=8, fps=25)
    return (
        settings,
        _SelftestPorts(
            control=DEFAULT_CONTROL_PORT + offset,
            audio=DEFAULT_AUDIO_PORT + offset,
            video=DEFAULT_VIDEO_PORT + offset,
        ),
        _SelftestPorts(
            control=DEFAULT_CONTROL_PORT + offset + 1,
            audio=DEFAULT_AUDIO_PORT + offset + 1,
            video=DEFAULT_VIDEO_PORT + offset + 1,
        ),
    )


def _build_selftest_endpoint(  # pylint: disable=too-many-arguments,too-many-positional-arguments
    local_ip: str,
    remote_ip: str,
    settings: MediaSettings,
    local_ports: _SelftestPorts,
    peer_ports: _SelftestPorts,
    frequency: float = 440.0,
) -> _SelftestEndpoint:
    connector = _SelftestConnector(local_ip, settings, local_ports, peer_ports)
    connector.session = Session(local_ip, remote_ip, 0, settings)
    audio = MemoryAudioPlayback()
    video = MemoryVideoDisplay()
    runtime = _SelftestRuntime(
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
    """Run loopback control and bidirectional media self-tests, then print counters."""
    asyncio.run(run_control_handshake_selftest())
    stats_a, stats_b = asyncio.run(run_bidirectional_selftest())
    print(f"endpoint_a={stats_a}")
    print(f"endpoint_b={stats_b}")


if __name__ == "__main__":
    main()
