"""Application runtime for a Linux LoLa port."""

from __future__ import annotations

import asyncio
from dataclasses import dataclass, field
import logging
import socket
import time
from typing import Protocol, runtime_checkable

from .backends import AudioCapture, AudioPlayback, VideoCapture, VideoDisplay
from .connector import LolaConnector, close_udp_socket, udp_recvfrom, udp_sendto
from .media import Fragment, MediaReassembler, VideoPrelude, parse_audio_frame, parse_media_payload, parse_video_frame
from .protocol import (
    MESG_CHECKLOLASTATUS,
    MESG_CHECKLOLASTATUS_ACK,
    MESG_QUICKCONN,
    MESG_REJECT,
    build_control_datagram,
    build_osc15_control_datagram,
    message_ip,
    parse_control_datagram,
)

logger = logging.getLogger(__name__)


@dataclass
class RuntimeStats:
    audio_tx: int = 0
    audio_rx: int = 0
    audio_malformed_rx: int = 0
    video_tx: int = 0
    video_rx: int = 0
    video_malformed_rx: int = 0
    control_rx: int = 0
    control_malformed_rx: int = 0
    cleanup_warnings: list[str] = field(default_factory=list)


@runtime_checkable
class ClosableBackend(Protocol):
    async def aclose(self) -> None:
        ...


class LolaLinuxRuntime:
    """Pump media between Linux backends and a negotiated LoLa session.

    The connector owns the protocol; the runtime owns clocks and backends. This
    split lets synthetic sources, FFmpeg/GStreamer subprocesses, and future
    native Linux devices feed the same LoLa packet layer.

    Instances are single-event-loop objects. Runtime state, including TX enable
    events toggled by media and control tasks, must not be mutated from another
    thread or event loop.
    """

    def __init__(
        self,
        connector: LolaConnector,
        audio_capture: AudioCapture,
        audio_playback: AudioPlayback,
        video_capture: VideoCapture | None = None,
        video_display: VideoDisplay | None = None,
        audio_interval_scale: float = 1.0,
    ) -> None:
        self.connector = connector
        self.audio_capture = audio_capture
        self.audio_playback = audio_playback
        self.video_capture = video_capture
        self.video_display = video_display
        # WSL timers landed slightly slow in live tests. The scale keeps the
        # synthetic 64-frame audio cadence close to LoLa's 44100/64 packet rate.
        self.audio_interval_scale = audio_interval_scale
        self.stats = RuntimeStats()
        self._stop = asyncio.Event()
        self._tasks: list[asyncio.Task[None]] = []
        self._audio_sock: socket.socket | None = None
        self._video_sock: socket.socket | None = None
        self._control_sock: socket.socket | None = None
        # Owned by this runtime's single asyncio event loop; cross-thread
        # toggles must enter through that loop instead of touching events here.
        self._audio_tx_enabled = asyncio.Event()
        self._video_tx_enabled = asyncio.Event()

    async def start(
        self,
        receive: bool = True,
        transmit_audio: bool = True,
        transmit_video: bool = True,
        control: bool = True,
    ) -> None:
        try:
            if self.connector.session is None:
                raise RuntimeError("connector has no active LoLa session")
            if self._tasks:
                raise RuntimeError("runtime is already started")
            self._stop.clear()
            self._audio_sock = self.connector.make_udp_socket(self.connector.audio_port)
            if receive or self.video_capture is not None:
                self._video_sock = self.connector.make_udp_socket(self.connector.video_port)
            self._audio_tx_enabled.clear()
            self._video_tx_enabled.clear()
            if transmit_audio:
                self._audio_tx_enabled.set()
            if transmit_video:
                self._video_tx_enabled.set()
            if control:
                self._control_sock = self.connector.make_udp_socket(self.connector.control_port)
                self._tasks.append(asyncio.create_task(self._control_loop()))
            self._tasks.append(asyncio.create_task(self._audio_tx_loop()))
            if self.video_capture is not None:
                self._tasks.append(asyncio.create_task(self._video_tx_loop()))
            if receive:
                self._tasks.append(asyncio.create_task(self._media_rx_loop()))
        except BaseException as exc:
            try:
                await self._cleanup_failed_start()
            except Exception as cleanup_error:
                exc.add_note(f"runtime startup cleanup failed: {cleanup_error!r}")
            raise

    async def stop(self) -> None:
        self._stop.set()
        for task in self._tasks:
            task.cancel()
        task_errors: list[Exception] = []
        for task in self._tasks:
            try:
                await task
            except asyncio.CancelledError:
                pass
            except Exception as exc:
                logger.exception("runtime task failed during stop")
                task_errors.append(exc)
        self._tasks.clear()
        self._close_sockets()
        await self._close_backend(self.audio_capture)
        await self._close_backend(self.audio_playback)
        if self.video_capture is not None:
            await self._close_backend(self.video_capture)
        if self.video_display is not None:
            await self._close_backend(self.video_display)
        if task_errors:
            raise ExceptionGroup("runtime task failed during stop", task_errors)

    async def _cleanup_failed_start(self) -> None:
        self._stop.set()
        for task in self._tasks:
            task.cancel()
        for task in self._tasks:
            try:
                await task
            except asyncio.CancelledError:
                pass
            except Exception:
                logger.exception("runtime task failed during startup cleanup")
        self._tasks.clear()
        self._close_sockets()
        await self._close_backend(self.audio_capture)
        await self._close_backend(self.audio_playback)
        if self.video_capture is not None:
            await self._close_backend(self.video_capture)
        if self.video_display is not None:
            await self._close_backend(self.video_display)

    def _close_sockets(self) -> None:
        if self._audio_sock is not None:
            close_udp_socket(self._audio_sock)
            self._audio_sock = None
        if self._video_sock is not None:
            close_udp_socket(self._video_sock)
            self._video_sock = None
        if self._control_sock is not None:
            close_udp_socket(self._control_sock)
            self._control_sock = None

    async def run_for(self, seconds: float, **start_kwargs: bool) -> RuntimeStats:
        await self.start(**start_kwargs)
        try:
            await asyncio.sleep(seconds)
        finally:
            await self.stop()
        return self.stats

    async def _audio_tx_loop(self) -> None:
        sequence = 0
        frames_per_callback = getattr(self.audio_capture, "frames_per_callback", 0)
        if frames_per_callback == 0:
            logger.warning("audio capture frames_per_callback=0; external pacing is disabled")
        sample_rate = max(1, self.connector.settings.sample_rate)
        interval = frames_per_callback / sample_rate * self.audio_interval_scale if frames_per_callback else 0.0
        # Synthetic captures generate PCM immediately and rely on this absolute
        # pacer. Real process/device captures usually block on their own clock.
        external_pacing = bool(getattr(self.audio_capture, "external_pacing", False) and interval > 0.0)
        next_send = time.perf_counter()
        while not self._stop.is_set():
            if not self._audio_tx_enabled.is_set():
                next_send = time.perf_counter()
                await asyncio.sleep(0.01)
                continue
            if external_pacing:
                await self._wait_until(next_send)
            if self._audio_sock is None:
                raise RuntimeError("audio socket is not initialized")
            pcm = await self.audio_capture.read_block()
            await self.connector.send_audio_on_socket(self._audio_sock, pcm, sequence)
            sequence = (sequence + 1) & 0xFFFFFFFF
            self.stats.audio_tx += 1
            if external_pacing:
                now = time.perf_counter()
                next_send += interval
                if next_send < now - interval:
                    # If the process was descheduled, resume from now instead
                    # of emitting a burst of stale audio packets.
                    next_send = now + interval

    async def _video_tx_loop(self) -> None:
        sequence = 0
        if self.video_capture is None:
            raise RuntimeError("video_capture must be set before starting video TX loop")
        while not self._stop.is_set():
            if not self._video_tx_enabled.is_set():
                await asyncio.sleep(0.01)
                continue
            frame = await self.video_capture.read_frame()
            if self._video_sock is None:
                raise RuntimeError("video socket is not initialized")
            await self.connector.send_video_on_socket(self._video_sock, frame, sequence)
            sequence = (sequence + 1) & 0xFFFFFFFF
            self.stats.video_tx += 1

    async def _media_rx_loop(self) -> None:
        audio_reasm = MediaReassembler(allow_fragment_auto_begin=True)
        video_reasm = MediaReassembler(allow_fragment_auto_begin=False)
        if self._audio_sock is None or self._video_sock is None:
            raise RuntimeError("media receive sockets are not initialized")
        await asyncio.gather(
            self._rx_socket_loop(self._audio_sock, audio_reasm, "audio"),
            self._rx_socket_loop(self._video_sock, video_reasm, "video"),
        )

    async def _rx_socket_loop(self, sock: socket.socket, reasm: MediaReassembler, kind: str) -> None:
        while not self._stop.is_set():
            payload, addr = await udp_recvfrom(sock, 65535)
            session = self.connector.session
            if session is None:
                continue
            if addr[0] != session.remote_ip:
                continue
            try:
                item = parse_media_payload(payload)
                if isinstance(item, VideoPrelude):
                    # Video frames announce expected size/fragment count up front.
                    # Audio has no prelude and starts directly with a normal fragment.
                    reasm.begin(item.frame_id, item.expected_size, item.fragment_count)
                    continue
                if item is None:
                    self._count_malformed_media(kind)
                    logger.warning(
                        "ignored unrecognized LoLa %s media payload bytes=%s from=%s",
                        kind,
                        len(payload),
                        addr[0],
                    )
                    continue
                if not isinstance(item, Fragment):
                    self._count_malformed_media(kind)
                    logger.warning(
                        "ignored unexpected LoLa %s media payload type %s from=%s",
                        kind,
                        type(item).__name__,
                        addr[0],
                    )
                    continue
                assembled = reasm.add(item)
                if assembled is None:
                    continue
                if kind == "audio":
                    audio_frame = parse_audio_frame(assembled)
                    await self.audio_playback.write_block(audio_frame.pcm, audio_frame.sequence)
                    self.stats.audio_rx += 1
                    continue
                if self.video_display is None:
                    continue
                compressed = bool(session.remote_settings.compression)
                video_frame = parse_video_frame(assembled, compressed=compressed)
            except ValueError:
                self._count_malformed_media(kind)
                logger.warning("ignored malformed LoLa %s media payload from=%s", kind, addr[0], exc_info=True)
                continue
            if self.video_display is not None:
                await self.video_display.show_frame(
                    video_frame.payload,
                    video_frame.sequence,
                    video_frame.compressed,
                )
                self.stats.video_rx += 1

    async def _control_loop(self) -> None:
        if self._control_sock is None:
            raise RuntimeError("control socket is not initialized")
        while not self._stop.is_set():
            data, addr = await udp_recvfrom(self._control_sock, 4096)
            try:
                msg = parse_control_datagram(data)
            except ValueError:
                self.stats.control_malformed_rx += 1
                logger.warning("ignored malformed LoLa control payload from=%s", addr[0], exc_info=True)
                continue
            if msg is None:
                self.stats.control_malformed_rx += 1
                continue
            self.stats.control_rx += 1
            remote_ip = message_ip(msg, addr[0])
            if msg.kind == MESG_CHECKLOLASTATUS:
                if msg.dialect == "osc15":
                    response = build_osc15_control_datagram(
                        MESG_CHECKLOLASTATUS_ACK,
                        self.connector.local_ip,
                        remote_ip,
                        msg.sid,
                        self.connector.settings,
                        source_name=self.connector.source_name,
                    )
                else:
                    response = build_control_datagram(
                        MESG_CHECKLOLASTATUS_ACK,
                        self.connector.local_ip,
                        remote_ip,
                        msg.sid,
                        self.connector.settings,
                    )
                await udp_sendto(self._control_sock, response, (remote_ip, self.connector.control_port))
                continue
            if msg.kind == MESG_QUICKCONN:
                # This runtime is already inside an established session. A
                # second QuickConn is rejected just like a busy LoLa peer.
                if msg.dialect == "osc15":
                    response = build_osc15_control_datagram(
                        MESG_REJECT,
                        self.connector.local_ip,
                        remote_ip,
                        msg.sid,
                        txt="Linux LoLa connector is already in a session.",
                        source_name=self.connector.source_name,
                    )
                else:
                    response = build_control_datagram(
                        MESG_REJECT,
                        self.connector.local_ip,
                        remote_ip,
                        msg.sid,
                        txt="Linux LoLa connector is already in a session.",
                    )
                await udp_sendto(self._control_sock, response, (remote_ip, self.connector.control_port))
                continue
            action = self.connector.handle_control_message(msg, sender_ip=addr[0])
            if action == "send_audio_signal":
                # Windows menu "Receive AV Test Signals" asks the remote side
                # to start sending; in our runtime that means enabling the
                # prepared synthetic capture sources.
                self._audio_tx_enabled.set()
                if self.video_capture is not None:
                    self._video_tx_enabled.set()
                continue
            if action == "stop_audio_signal":
                self._audio_tx_enabled.clear()
                self._video_tx_enabled.clear()
                continue
            if action == "disconnect":
                self._stop.set()

    def _count_malformed_media(self, kind: str) -> None:
        if kind == "audio":
            self.stats.audio_malformed_rx += 1
        elif kind == "video":
            self.stats.video_malformed_rx += 1

    async def _close_backend(self, backend: object) -> None:
        if isinstance(backend, ClosableBackend):
            await backend.aclose()
        warnings = getattr(backend, "cleanup_warnings", None)
        if warnings:
            self.stats.cleanup_warnings.extend(str(warning) for warning in warnings)

    async def _wait_until(self, deadline: float) -> None:
        """Wait until an audio deadline within Python's event-loop timer ceiling."""
        while True:
            remaining = deadline - time.perf_counter()
            if remaining <= 0:
                return
            await asyncio.sleep(remaining)
