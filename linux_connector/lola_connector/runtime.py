# pylint: disable=missing-function-docstring
"""Application runtime for a Linux LoLa port."""

from __future__ import annotations

import asyncio
import logging
import socket
import time
from collections.abc import Coroutine

from .backends import AudioCapture, AudioPlayback, VideoCapture, VideoDisplay
from .connector import Session, close_udp_socket, udp_recvfrom
from .connector_impl import LolaConnector
from .media import (
    Fragment,
    MediaReassembler,
    VideoPrelude,
    expected_audio_payload_size,
    parse_audio_frame,
    parse_media_payload,
    parse_video_frame,
)
from .runtime_control import _RuntimeControlHandler
from . import runtime_transmit
from .runtime_types import (
    AudioTxPacing,
    CapturedVideoFrame,
    ClosableBackend,
    RuntimeStats,
    sequence_is_newer,
)

logger = logging.getLogger(__name__)


class LolaLinuxRuntime:  # pylint: disable=too-many-instance-attributes
    """Pump media between Linux backends and a negotiated LoLa session.

    The connector owns the protocol; the runtime owns clocks and backends. This
    split lets synthetic sources, FFmpeg/GStreamer subprocesses, and future
    native Linux devices feed the same LoLa packet layer.

    Instances are single-event-loop objects. Runtime state, including TX enable
    events toggled by media and control tasks, must not be mutated from another
    thread or event loop.
    """

    def __init__(  # pylint: disable=too-many-arguments,too-many-positional-arguments
        self,
        connector: LolaConnector,
        audio_capture: AudioCapture,
        audio_playback: AudioPlayback,
        video_capture: VideoCapture | None = None,
        video_display: VideoDisplay | None = None,
        audio_interval_scale: float = 1.0,
    ) -> None:
        """Create a runtime around negotiated connector and media backends."""
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
        self._terminated = asyncio.Event()
        self._stop_lock = asyncio.Lock()
        self._closed = False
        self._worker_failure: Exception | None = None
        self._tasks: list[asyncio.Task[None]] = []
        self._audio_sock: socket.socket | None = None
        self._video_sock: socket.socket | None = None
        self._control_sock: socket.socket | None = None
        self._audio_tx_enabled = asyncio.Event()
        self._video_tx_enabled = asyncio.Event()
        self._audio_sink_queue: asyncio.Queue[tuple[bytes, int]] = asyncio.Queue(maxsize=1)
        self._video_sink_queue: asyncio.Queue[tuple[bytes, int, bool]] = asyncio.Queue(maxsize=1)
        self._video_tx_queue: asyncio.Queue[CapturedVideoFrame] = asyncio.Queue(maxsize=1)
        self._control_handler = _RuntimeControlHandler(
            connector=self.connector,
            stats=self.stats,
            control_socket=lambda: self._control_sock,
            stop=self._stop,
            audio_tx_enabled=self._audio_tx_enabled,
            video_tx_enabled=self._video_tx_enabled,
            has_video_capture=lambda: self.video_capture is not None,
        )

    async def start(
        self,
        receive: bool = True,
        transmit_audio: bool = True,
        transmit_video: bool = True,
        control: bool = True,
    ) -> None:
        try:
            self._validate_start_state()
            self._stop.clear()
            self._terminated.clear()
            self._closed = False
            self._worker_failure = None
            self._open_start_sockets(receive=receive, control=control)
            self._configure_tx_enablement(transmit_audio=transmit_audio, transmit_video=transmit_video)
            self._start_runtime_tasks(receive=receive, control=control)
        except BaseException as exc:
            for cleanup_error in await self._cleanup_failed_start():
                exc.add_note(f"runtime startup cleanup failed: {cleanup_error!r}")
            raise

    def _validate_start_state(self) -> None:
        if self.connector.session is None:
            raise RuntimeError("connector has no active LoLa session")
        if self._tasks:
            raise RuntimeError("runtime is already started")

    def _open_start_sockets(self, *, receive: bool, control: bool) -> None:
        self._audio_sock = self.connector.make_udp_socket(self.connector.audio_port)
        if receive or self.video_capture is not None:
            self._video_sock = self.connector.make_udp_socket(self.connector.video_port)
        if control:
            self._control_sock = self.connector.make_udp_socket(self.connector.control_port)
            self.connector.register_runtime_control_socket(self._control_sock)

    def _configure_tx_enablement(self, *, transmit_audio: bool, transmit_video: bool) -> None:
        self._audio_tx_enabled.clear()
        self._video_tx_enabled.clear()
        if transmit_audio:
            self._audio_tx_enabled.set()
        if transmit_video:
            self._video_tx_enabled.set()

    def _start_runtime_tasks(self, *, receive: bool, control: bool) -> None:
        if control:
            self._start_runtime_task(self._control_handler.run())
        self._start_runtime_task(self._audio_tx_loop())
        if self.video_capture is not None:
            self._start_runtime_task(self._video_capture_loop())
            self._start_runtime_task(self._video_tx_loop())
        if receive:
            self._start_runtime_task(self._audio_sink_loop())
            if self.video_display is not None:
                self._start_runtime_task(self._video_sink_loop())
            self._start_runtime_task(self._media_rx_loop())

    def _start_runtime_task(self, worker: Coroutine[object, object, None]) -> None:
        task = asyncio.create_task(worker)
        task.add_done_callback(self._record_runtime_task_completion)
        self._tasks.append(task)

    def _record_runtime_task_completion(self, task: asyncio.Task[None]) -> None:
        if task.cancelled():
            return
        error = task.exception()
        if error is not None:
            self._record_worker_failure(error)

    def _record_worker_failure(self, error: BaseException) -> None:
        if isinstance(error, Exception) and self._worker_failure is None:
            self._worker_failure = error
        self._stop.set()

    async def stop(self) -> None:
        """Terminate runtime workers and close resources once, even on concurrent callers."""
        async with self._stop_lock:
            if self._closed:
                return
            self._closed = True
            self._stop.set()
            task_errors: list[Exception] = []
            cleanup_errors: list[Exception] = []
            try:
                for task in self._tasks:
                    task.cancel()
                task_errors = await self._drain_runtime_tasks("runtime task failed during stop")
                self._tasks.clear()
                cleanup_errors.extend(self._close_sockets())
                cleanup_errors.extend(await self._close_backends_collecting_errors())
            finally:
                self._terminated.set()
            if self._worker_failure is not None:
                errors = [self._worker_failure, *(error for error in task_errors + cleanup_errors if error is not self._worker_failure)]
                raise ExceptionGroup("runtime task failed during stop", errors)
            if cleanup_errors:
                raise ExceptionGroup("runtime cleanup failed during stop", cleanup_errors)

    async def wait_terminated(self) -> None:
        """Wait until a local stop or validated peer disconnect terminates this runtime."""
        await self._stop.wait()
        if self._worker_failure is not None:
            raise self._worker_failure

    async def _cleanup_failed_start(self) -> list[Exception]:
        cleanup_errors: list[Exception] = []
        self._stop.set()
        for task in self._tasks:
            task.cancel()
        cleanup_errors.extend(await self._drain_runtime_tasks("runtime task failed during startup cleanup"))
        self._tasks.clear()
        cleanup_errors.extend(self._close_sockets())
        cleanup_errors.extend(await self._close_backends_collecting_errors())
        return cleanup_errors

    async def _drain_runtime_tasks(self, log_message: str) -> list[Exception]:
        results = await asyncio.gather(*self._tasks, return_exceptions=True)
        task_errors: list[Exception] = []
        for result in results:
            if isinstance(result, asyncio.CancelledError):
                continue
            if isinstance(result, Exception):
                logger.error(log_message, exc_info=(type(result), result, result.__traceback__))
                task_errors.append(result)
                self._record_worker_failure(result)
                continue
            if isinstance(result, BaseException):
                raise result
        return task_errors

    async def _close_backends_collecting_errors(self) -> list[Exception]:
        backends = [self.audio_capture, self.audio_playback]
        if self.video_capture is not None:
            backends.append(self.video_capture)
        if self.video_display is not None:
            backends.append(self.video_display)
        results = await asyncio.gather(
            *(self._close_backend(backend) for backend in backends),
            return_exceptions=True,
        )
        cleanup_errors: list[Exception] = []
        for result in results:
            if isinstance(result, Exception):
                cleanup_errors.append(result)
                continue
            if isinstance(result, BaseException):
                raise result
        return cleanup_errors

    def _close_sockets(self) -> list[Exception]:
        cleanup_errors: list[Exception] = []
        for name in ("_audio_sock", "_video_sock", "_control_sock"):
            sock = getattr(self, name)
            if sock is None:
                continue
            try:
                if name == "_control_sock":
                    unregister = getattr(self.connector, "unregister_runtime_control_socket", None)
                    if callable(unregister):
                        unregister(sock)
                close_udp_socket(sock)
            except OSError as exc:  # cleanup must continue for remaining sockets
                cleanup_errors.append(exc)
            finally:
                setattr(self, name, None)
        return cleanup_errors

    async def run_for(self, seconds: float, **start_kwargs: bool) -> RuntimeStats:
        await self.start(**start_kwargs)
        try:
            await asyncio.sleep(seconds)
        finally:
            await self.stop()
        return self.stats

    async def _audio_tx_loop(self) -> None:
        await runtime_transmit.audio_tx_loop(self)

    def _audio_tx_pacing(self) -> AudioTxPacing:
        return runtime_transmit.audio_tx_pacing(self)

    def _audio_tx_is_paused(self) -> bool:
        return runtime_transmit.audio_tx_is_paused(self)

    async def _wait_for_audio_tx_deadline(self, pacing: AudioTxPacing) -> None:
        await runtime_transmit.wait_for_audio_tx_deadline(pacing)

    async def _send_audio_tx_packet(self, sequence: int) -> int:
        return await runtime_transmit.send_audio_tx_packet(self, sequence)

    def _valid_local_audio_payload(self, pcm: bytes) -> bool:
        return runtime_transmit.valid_local_audio_payload(self, pcm)

    def _advance_audio_tx_deadline(self, pacing: AudioTxPacing) -> None:
        runtime_transmit.advance_audio_tx_deadline(pacing)

    async def _video_capture_loop(self) -> None:
        await runtime_transmit.video_capture_loop(self)

    async def _video_tx_loop(self) -> None:
        await runtime_transmit.video_tx_loop(self)

    async def _send_captured_video(self, captured: CapturedVideoFrame, sequence: int) -> str:
        return await runtime_transmit.send_captured_video(self, captured, sequence)

    def _valid_local_video_payload(self, frame: bytes) -> bool:
        return runtime_transmit.valid_local_video_payload(self, frame)

    def _record_video_tx_drop(self, outcome: str) -> None:
        runtime_transmit.record_video_tx_drop(self, outcome)

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
            if self._stop.is_set():
                break
            if kind == "audio":
                newest = self._drain_audio_to_newest(sock, payload, addr)
                if newest is None:
                    continue
                payload, addr = newest
            session = self._session_for_media_sender(addr, kind)
            if session is None:
                continue
            await self._handle_media_payload(payload, addr[0], session, reasm, kind)

    def _drain_audio_to_newest(
        self,
        sock: socket.socket,
        payload: bytes,
        addr: tuple[str, int],
    ) -> tuple[bytes, tuple[str, int]] | None:
        """Discard queued audio datagrams so playback receives the newest block.

        Audio is one LoLa fragment per callback. Draining only this stream
        avoids extending its latency behind kernel buffering while leaving the
        ordered multi-fragment video stream intact.
        """
        newest_valid: tuple[bytes, tuple[str, int], int] | None = None
        while True:
            newest_valid = self._select_audio_drain_candidate(
                newest_valid,
                payload,
                addr,
            )
            try:
                payload, addr = sock.recvfrom(65535)
            except BlockingIOError:
                break
        if newest_valid is None:
            return None
        return newest_valid[0], newest_valid[1]

    def _select_audio_drain_candidate(
        self,
        newest_valid: tuple[bytes, tuple[str, int], int] | None,
        payload: bytes,
        addr: tuple[str, int],
    ) -> tuple[bytes, tuple[str, int], int] | None:
        sequence = self._valid_audio_datagram_sequence(payload, addr)
        if sequence is None:
            self._count_audio_drain_discard(payload, addr)
            return newest_valid

        candidate = (payload, addr, sequence)
        if newest_valid is None:
            return candidate
        if sequence_is_newer(sequence, newest_valid[2]):
            self.stats.audio_rx_kernel_dropped += 1
            return candidate

        self.stats.audio_rx_reordered_dropped += 1
        return newest_valid

    def _valid_audio_datagram_sequence(self, payload: bytes, addr: tuple[str, int]) -> int | None:
        session = self._audio_session_for_sender(addr)
        if session is None:
            return None
        fragment = self._single_audio_fragment(payload)
        if fragment is None:
            return None
        try:
            audio = parse_audio_frame(fragment.data)
        except ValueError:
            return None
        expected_bytes = expected_audio_payload_size(
            channels=session.remote_settings.channels,
            bits_per_sample=session.remote_settings.bits_per_sample,
        )
        return audio.sequence if len(audio.pcm) == expected_bytes else None

    def _audio_session_for_sender(self, addr: tuple[str, int]) -> Session | None:
        session = self.connector.session
        if session is None or addr[0] != session.remote_ip:
            return None
        return session if addr[1] == self.connector.audio_port else None

    @staticmethod
    def _single_audio_fragment(payload: bytes) -> Fragment | None:
        try:
            fragment = parse_media_payload(payload)
        except ValueError:
            return None
        if not isinstance(fragment, Fragment):
            return None
        if LolaLinuxRuntime._is_complete_audio_fragment(fragment):
            return fragment
        return None

    @staticmethod
    def _is_complete_audio_fragment(fragment: Fragment) -> bool:
        return (
            fragment.fragment_count == 1
            and fragment.fragment_index == 0
            and fragment.original_offset == 0
            and fragment.flags & 1 != 0
        )

    def _count_audio_drain_discard(self, _payload: bytes, addr: tuple[str, int]) -> None:
        session = self.connector.session
        if session is None or addr[0] != session.remote_ip:
            self.stats.audio_rx_wrong_peer_dropped += 1
            return
        if addr[1] != self.connector.audio_port:
            self.stats.audio_rx_wrong_port_dropped += 1
            return
        self.stats.audio_rx_malformed_dropped += 1

    def _session_for_media_sender(self, addr: tuple[str, int], kind: str) -> Session | None:
        session = self.connector.session
        if session is None or addr[0] != session.remote_ip:
            return None
        expected_port = self.connector.audio_port if kind == "audio" else self.connector.video_port
        if addr[1] != expected_port:
            self._count_malformed_media(kind)
            logger.warning(
                "ignored LoLa %s media payload from unexpected source port %s expected=%s from=%s",
                kind,
                addr[1],
                expected_port,
                addr[0],
            )
            return None
        return session
    # pylint: disable-next=too-many-arguments,too-many-positional-arguments
    async def _handle_media_payload(
        self,
        payload: bytes,
        remote_ip: str,
        session: Session,
        reasm: MediaReassembler,
        kind: str,
    ) -> None:
        try:
            item = parse_media_payload(payload)
            if isinstance(item, VideoPrelude):
                if kind == "video":
                    reasm.begin(item.frame_id, item.expected_size, item.fragment_count)
                else:
                    self._count_malformed_media(kind)
                return
            if item is None:
                self._count_malformed_media(kind)
                logger.warning(
                    "ignored unrecognized LoLa %s media payload bytes=%s from=%s",
                    kind,
                    len(payload),
                    remote_ip,
                )
                return
            if not isinstance(item, Fragment):
                self._count_malformed_media(kind)
                logger.warning(
                    "ignored unexpected LoLa %s media payload type %s from=%s",
                    kind,
                    type(item).__name__,
                    remote_ip,
                )
                return
            await self._handle_media_fragment(item, session, reasm, kind)
        except ValueError:
            self._count_malformed_media(kind)
            logger.warning(
                "ignored malformed LoLa %s media payload from=%s",
                kind,
                remote_ip,
                exc_info=True,
            )

    async def _handle_media_fragment(
        self,
        item: Fragment,
        session: Session,
        reasm: MediaReassembler,
        kind: str,
    ) -> None:
        assembled = reasm.add(item)
        if assembled is None:
            return
        if kind == "audio":
            audio_frame = parse_audio_frame(assembled)
            self._enqueue_audio_sink(audio_frame.pcm, audio_frame.sequence)
            return
        if self.video_display is None:
            return
        compressed = bool(session.remote_settings.compression)
        video_frame = parse_video_frame(assembled, compressed=compressed)
        if not self._accept_remote_video_frame(video_frame.payload, session.remote_settings, video_frame.compressed):
            return
        self._enqueue_video_sink(video_frame.payload, video_frame.sequence, video_frame.compressed)

    def _accept_remote_video_frame(
        self,
        payload: bytes,
        remote_settings: object,
        compressed: bool,
    ) -> bool:
        """Reject malformed raw video before it can shift the display stream."""
        if compressed:
            return True
        width = getattr(remote_settings, "width", 0)
        height = getattr(remote_settings, "height", 0)
        bits_per_pixel = getattr(remote_settings, "bits_per_pixel", 0)
        if (
            not isinstance(width, int)
            or not isinstance(height, int)
            or not isinstance(bits_per_pixel, int)
            or width <= 0
            or height <= 0
            or bits_per_pixel <= 0
            or bits_per_pixel % 8 != 0
        ):
            self._drop_malformed_video_frame("non-byte-aligned or nonpositive negotiated geometry")
            return False
        expected_size = width * height * (bits_per_pixel // 8)
        if len(payload) != expected_size:
            self._drop_malformed_video_frame(f"payload size {len(payload)} != negotiated {expected_size}")
            return False
        return True

    def _drop_malformed_video_frame(self, reason: str) -> None:
        """Account for a rejected completed video frame without touching the sink queue."""
        self.stats.video_malformed_rx += 1
        self.stats.video_rx_dropped += 1
        logger.warning("dropped malformed raw LoLa video frame: %s", reason)

    def _enqueue_audio_sink(self, pcm: bytes, sequence: int) -> None:
        try:
            self._audio_sink_queue.put_nowait((pcm, sequence))
        except asyncio.QueueFull:
            queued_pcm, queued_sequence = self._audio_sink_queue.get_nowait()
            if sequence_is_newer(sequence, queued_sequence):
                self.stats.audio_rx_dropped += 1
                self._audio_sink_queue.put_nowait((pcm, sequence))
            else:
                self.stats.audio_rx_reordered_dropped += 1
                self._audio_sink_queue.put_nowait((queued_pcm, queued_sequence))

    def _enqueue_video_sink(self, frame: bytes, sequence: int, compressed: bool) -> None:
        try:
            self._video_sink_queue.put_nowait((frame, sequence, compressed))
        except asyncio.QueueFull:
            self._video_sink_queue.get_nowait()
            self.stats.video_rx_dropped += 1
            self._video_sink_queue.put_nowait((frame, sequence, compressed))

    async def _audio_sink_loop(self) -> None:
        while not self._stop.is_set():
            pcm, sequence = await self._audio_sink_queue.get()
            await self.audio_playback.write_block(pcm, sequence)
            self.stats.audio_rx += 1

    async def _video_sink_loop(self) -> None:
        if self.video_display is None:
            return
        while not self._stop.is_set():
            frame, sequence, compressed = await self._video_sink_queue.get()
            await self.video_display.show_frame(frame, sequence, compressed)
            self.stats.video_rx += 1

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
