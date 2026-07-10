# pylint: disable=missing-function-docstring
"""Linux media backend interfaces and dependency-free test backends."""

from __future__ import annotations

import asyncio
from dataclasses import dataclass, field
import logging
import math
from asyncio.subprocess import Process
from typing import Protocol

from .process_commands import (
    ProcessCommand,
    make_process_command,
    split_command,
    validate_process_command,
)
from .process_launch import launch_stdin_process, launch_stdout_process
from .video_backends import DiagnosticVideoCapture

from .media import expected_audio_payload_size
from .protocol import MediaSettings

LOGGER = logging.getLogger(__name__)


class AudioCapture(Protocol):  # pylint: disable=missing-class-docstring,too-few-public-methods
    async def read_block(self) -> bytes:
        """Return one LoLa audio callback block as interleaved PCM bytes."""


class AudioPlayback(Protocol):  # pylint: disable=missing-class-docstring,too-few-public-methods
    async def write_block(self, pcm: bytes, sequence: int) -> None:
        """Play or store one received LoLa audio block."""


class VideoCapture(Protocol):  # pylint: disable=missing-class-docstring,too-few-public-methods
    async def read_frame(self) -> bytes:
        """Return one raw or encoded video frame matching MediaSettings."""


class VideoDisplay(Protocol):  # pylint: disable=missing-class-docstring,too-few-public-methods
    async def show_frame(self, frame: bytes, sequence: int, compressed: bool) -> None:
        """Display or store one received LoLa video frame."""




class ProcessLifecycleMixin:  # pylint: disable=missing-class-docstring,too-few-public-methods
    command: ProcessCommand
    process: Process | None

    def _configure_process_command(self, command: str | list[str]) -> None:
        self.command = make_process_command(command)
        self.process = None
        self._process_wait_task: asyncio.Task[int] | None = None

    @property
    def cleanup_warnings(self) -> list[str]:
        if not hasattr(self, "_cleanup_warnings"):
            self._cleanup_warnings: list[str] = []
        return self._cleanup_warnings

    def _record_cleanup_warning(self, message: str) -> None:
        self.cleanup_warnings.append(message)

    async def _ensure_stdout_process(self, command: ProcessCommand, label: str) -> None:
        if self.process is not None and self.process.returncode is None:
            return
        process: Process | None = None
        try:
            process = await launch_stdout_process(command)
            self.process = process
            if process.stdout is None:
                raise RuntimeError(f"{label} process did not expose stdout")
            self._watch_process_exit(process)
        except asyncio.CancelledError as original:
            if process is not None:
                await self._cleanup_failed_start(process, original, label)
            raise
        except (OSError, RuntimeError) as original:
            if process is not None:
                await self._cleanup_failed_start(process, original, label)
            raise

    async def _ensure_stdin_process(self, command: ProcessCommand) -> None:
        if self.process is None:
            self.process = await launch_stdin_process(command)
            self._watch_process_exit(self.process)

    def _watch_process_exit(self, process: Process) -> None:
        self._process_wait_task = asyncio.create_task(process.wait())

    async def _start_stdout_process(self, label: str) -> None:
        await self._ensure_stdout_process(self.command, label)

    async def _start_stdin_process(self) -> None:
        await self._ensure_stdin_process(self.command)

    def _stdout_reader_or_raise(self, label: str) -> asyncio.StreamReader:
        if self.process is None or self.process.stdout is None:
            raise RuntimeError(f"{label} process is not ready")
        return self.process.stdout

    def _stdin_writer_or_raise(self, label: str) -> asyncio.StreamWriter:
        if self.process is None or self.process.stdin is None:
            raise RuntimeError(f"{label} process is not ready")
        return self.process.stdin

    async def _raise_if_process_exited(self, label: str, action: str) -> None:
        if self.process is None or self.process.returncode is None:
            return
        returncode = self.process.returncode
        await self._close_process()
        raise RuntimeError(f"{label} process died before {action}: exit {returncode}")

    async def _write_stdin_or_cleanup(self, pcm: bytes, sequence: int, label: str) -> None:
        stdin = self._stdin_writer_or_raise(label)
        try:
            stdin.write(pcm)
            await stdin.drain()
        except (BrokenPipeError, ConnectionError, OSError) as exc:
            await self._close_process(close_stdin=True)
            raise RuntimeError(
                f"{label} process died while writing sequence {sequence}: {exc}"
            ) from exc

    async def _cleanup_failed_start(
        self, process: Process, original: BaseException, label: str
    ) -> None:
        try:
            process.kill()
            await process.wait()
        except (OSError, RuntimeError) as cleanup_error:
            original.add_note(f"{label} process cleanup failed: {cleanup_error!r}")
        finally:
            if self.process is process:
                self.process = None

    async def _readexactly_or_cleanup(
        self,
        reader: asyncio.StreamReader,
        size: int,
        label: str,
    ) -> bytes:
        try:
            return await reader.readexactly(size)
        except asyncio.IncompleteReadError as exc:
            await self._close_process()
            raise RuntimeError(f"{label} process died while reading") from exc
        except asyncio.CancelledError:
            await self._close_process()
            raise
        except OSError:
            await self._close_process()
            raise

    async def _read_or_cleanup(
        self,
        reader: asyncio.StreamReader,
        size: int,
    ) -> bytes:
        try:
            return await reader.read(size)
        except asyncio.CancelledError:
            await self._close_process()
            raise
        except OSError:
            await self._close_process()
            raise

    async def _close_process(self, *, close_stdin: bool = False) -> None:
        if self.process is None:
            return
        self._process_wait_task = None
        if close_stdin and self.process.stdin is not None:
            self.process.stdin.close()
        try:
            await self._terminate_and_wait_process()
        except ProcessLookupError:
            await self.process.wait()
        except asyncio.TimeoutError:
            await self._kill_and_wait_process()
        finally:
            self.process = None

    async def _terminate_and_wait_process(self) -> None:
        if self.process is None:
            return
        try:
            self.process.terminate()
        except ProcessLookupError:
            await self.process.wait()
            return
        except OSError as exc:
            self._record_cleanup_warning(f"process terminate failed during cleanup: {exc!r}")
            LOGGER.debug("suppressed process terminate failure during cleanup", exc_info=True)
        try:
            await asyncio.wait_for(self.process.wait(), timeout=1.0)
        except asyncio.TimeoutError:
            raise
        except OSError as exc:
            self._record_cleanup_warning(f"process wait failed during cleanup: {exc!r}")
            LOGGER.debug("suppressed process wait failure during cleanup", exc_info=True)

    async def _kill_and_wait_process(self) -> None:
        if self.process is None:
            return
        try:
            self.process.kill()
        except ProcessLookupError:
            pass
        except OSError as exc:
            self._record_cleanup_warning(f"process kill failed during cleanup: {exc!r}")
            LOGGER.debug("suppressed process kill failure during cleanup", exc_info=True)
        try:
            await self.process.wait()
        except OSError as exc:
            self._record_cleanup_warning(f"process wait-after-kill failed during cleanup: {exc!r}")
            LOGGER.debug("suppressed process wait-after-kill failure during cleanup", exc_info=True)


@dataclass
class SilenceAudioCapture:
    """Synthetic silence source for protocol/timing tests without audio I/O."""

    settings: MediaSettings
    frames_per_callback: int = 64
    # Synthetic sources are paced by LolaLinuxRuntime so one clock controls all
    # LoLa audio packet timing.
    external_pacing: bool = True

    async def read_block(self) -> bytes:
        return bytes(
            expected_audio_payload_size(
                self.settings.channels,
                self.settings.bits_per_sample,
                self.frames_per_callback,
            )
        )


@dataclass
class SineAudioCapture:
    """Single-tone synthetic source for audible Linux-to-Windows validation."""

    settings: MediaSettings
    frequency: float = 440.0
    amplitude: float = 0.15
    frames_per_callback: int = 64
    phase: float = 0.0
    external_pacing: bool = True

    async def read_block(self) -> bytes:
        if self.settings.bits_per_sample != 16:
            raise ValueError("SineAudioCapture currently emits 16-bit PCM only")
        out = bytearray()
        step = 2.0 * math.pi * self.frequency / self.settings.sample_rate
        for _ in range(self.frames_per_callback):
            sample = int(math.sin(self.phase) * self.amplitude * 32767)
            self.phase = (self.phase + step) % (2.0 * math.pi)
            encoded = sample.to_bytes(2, "little", signed=True)
            for _channel in range(self.settings.channels):
                out.extend(encoded)
        return bytes(out)


@dataclass
class MultiToneAudioCapture:
    """Synthetic LoLa audio source with a distinct tone per channel.

    Phase state is intentionally single-event-loop async state. The runtime
    calls one capture from one audio TX coroutine; this class is not thread-safe.
    """

    settings: MediaSettings
    frequencies: tuple[float, ...] = (440.0, 660.0, 880.0, 1100.0, 1320.0, 1540.0, 1760.0, 1980.0)
    amplitude: float = 0.18
    frames_per_callback: int = 64
    external_pacing: bool = True
    phases: list[float] = field(
        init=False,
        metadata={"concurrency": "single-event-loop"},
    )

    def __post_init__(self) -> None:
        """Initialize per-channel oscillator phases."""
        self.phases = [0.0 for _ in range(self.settings.channels)]

    async def read_block(self) -> bytes:
        if self.settings.bits_per_sample != 16:
            raise ValueError("MultiToneAudioCapture currently emits 16-bit PCM only")
        out = bytearray()
        for _ in range(self.frames_per_callback):
            for channel in range(self.settings.channels):
                frequency = self.frequencies[channel % len(self.frequencies)]
                step = 2.0 * math.pi * frequency / self.settings.sample_rate
                sample = int(math.sin(self.phases[channel]) * self.amplitude * 32767)
                self.phases[channel] = (self.phases[channel] + step) % (2.0 * math.pi)
                out.extend(sample.to_bytes(2, "little", signed=True))
        return bytes(out)


class MemoryAudioPlayback:  # pylint: disable=missing-class-docstring,too-few-public-methods
    def __init__(self) -> None:
        """Create an in-memory audio block sink."""
        self.blocks: list[tuple[int, bytes]] = []

    async def write_block(self, pcm: bytes, sequence: int) -> None:
        self.blocks.append((sequence, pcm))


@dataclass
class PatternVideoCapture:  # pylint: disable=missing-class-docstring
    settings: MediaSettings
    frame_index: int = 0

    async def read_frame(self) -> bytes:
        await asyncio.sleep(1.0 / max(1, self.settings.fps))
        if self.settings.compression != 0:
            raise ValueError(
                "PatternVideoCapture emits raw frames; use a JPEG/GStreamer "
                "backend for compressed mode"
            )
        pixel_count = self.settings.width * self.settings.height
        if self.settings.bits_per_pixel != 8:
            raise ValueError("PatternVideoCapture currently emits 8-bit mono/raw frames only")
        base = self.frame_index & 0xFF
        self.frame_index += 1
        return bytes((base + x) & 0xFF for x in range(pixel_count))



class MemoryVideoDisplay:  # pylint: disable=missing-class-docstring,too-few-public-methods
    def __init__(self) -> None:
        """Create an in-memory frame sink."""
        self.frames: list[tuple[int, bytes, bool]] = []

    async def show_frame(self, frame: bytes, sequence: int, compressed: bool) -> None:
        self.frames.append((sequence, frame, compressed))



class ProcessAudioCapture(ProcessLifecycleMixin):
    """Read raw interleaved PCM blocks from a subprocess stdout.

    The subprocess is responsible for real device timing. Unlike synthetic
    captures, this backend does not declare external_pacing.

    Example command on Linux:
    `ffmpeg -hide_banner -loglevel error -f pulse -i default -f s16le -ac 2 -ar 44100 -`
    """

    def __init__(
        self,
        command: str | list[str],
        settings: MediaSettings,
        frames_per_callback: int = 64,
    ) -> None:
        """Create a process-backed audio capture."""
        self._configure_process_command(command)
        self.settings = settings
        self.frames_per_callback = frames_per_callback
        self.block_size = expected_audio_payload_size(
            settings.channels, settings.bits_per_sample, frames_per_callback
        )

    async def start(self) -> None:
        await self._start_stdout_process("audio capture")

    async def read_block(self) -> bytes:
        await self.start()
        reader = self._stdout_reader_or_raise("audio capture")
        await self._raise_if_process_exited("audio capture", "reading")
        return await self._readexactly_or_cleanup(reader, self.block_size, "audio capture")

    async def aclose(self) -> None:
        await self._close_process()


class ProcessAudioPlayback(ProcessLifecycleMixin):
    """Write raw interleaved PCM blocks to a subprocess stdin.

    Example command on Linux:
    `ffplay -hide_banner -loglevel error -f s16le -ac 2 -ar 44100 -nodisp -autoexit -`
    """

    def __init__(self, command: str | list[str]) -> None:
        """Create a process-backed audio playback."""
        self._configure_process_command(command)

    async def start(self) -> None:
        await self._start_stdin_process()

    async def write_block(self, pcm: bytes, sequence: int) -> None:
        await self.start()
        await self._raise_if_process_exited("audio playback", "writing")
        await self._write_stdin_or_cleanup(pcm, sequence, "audio playback")

    async def aclose(self) -> None:
        await self._close_process(close_stdin=True)


class ProcessRawVideoCapture(ProcessLifecycleMixin):
    """Read fixed-size raw frames from a subprocess stdout.

    The frame size must match the negotiated LoLa raw video settings exactly;
    otherwise the receiver will reassemble valid packets into invalid frames.

    Example command on Linux:
    `ffmpeg -hide_banner -loglevel error -f v4l2 -video_size 640x480
    -framerate 25 -i /dev/video0 -pix_fmt gray -f rawvideo -`
    """

    def __init__(self, command: str | list[str], settings: MediaSettings) -> None:
        """Create a raw-video capture process wrapper."""
        self._configure_process_command(command)
        self.settings = settings
        self.frame_size = settings.width * settings.height * max(1, settings.bits_per_pixel // 8)

    async def start(self) -> None:
        await self._start_stdout_process("raw video capture")

    async def read_frame(self) -> bytes:
        await self.start()
        reader = self._stdout_reader_or_raise("raw video capture")
        await self._raise_if_process_exited("raw video capture", "reading")
        return await self._readexactly_or_cleanup(reader, self.frame_size, "raw video capture")

    async def aclose(self) -> None:
        await self._close_process()


class ProcessJpegVideoCapture(ProcessLifecycleMixin):
    """Read concatenated JPEG frames from a subprocess stdout.

    LoLa compressed mode expects complete JPEG payloads. This small parser
    splits a continuous byte stream on JPEG SOI/EOI markers.
    """

    DEFAULT_MAX_FRAME_BYTES = 16 * 1024 * 1024
    WARN_FRAME_BYTES = 8 * 1024 * 1024

    def __init__(
        self,
        command: str | list[str],
        max_frame_bytes: int = DEFAULT_MAX_FRAME_BYTES,
    ) -> None:
        """Create a JPEG capture process wrapper."""
        if max_frame_bytes <= 0:
            raise ValueError("max_frame_bytes must be positive")
        self._configure_process_command(command)
        self.max_frame_bytes = max_frame_bytes
        self._extractor = JpegFrameExtractor(
            max_frame_bytes=max_frame_bytes,
            warn_frame_bytes=self.WARN_FRAME_BYTES,
        )
        self._buffer = self._extractor.buffer

    async def start(self) -> None:
        await self._start_stdout_process("JPEG video capture")

    async def read_frame(self) -> bytes:
        await self.start()
        reader = self._stdout_reader_or_raise("JPEG video capture")
        await self._raise_if_process_exited("JPEG video capture", "reading")
        while True:
            if frame := self._extract_frame():
                return frame
            chunk = await self._read_or_cleanup(reader, 65536)
            if not chunk:
                await self.aclose()
                raise EOFError("JPEG capture subprocess ended")
            self._extractor.append(chunk)

    def _extract_frame(self) -> bytes | None:
        return self._extractor.extract_frame()

    async def aclose(self) -> None:
        await self._close_process()


class JpegFrameExtractor:
    """Incrementally extract complete JPEG frames from a byte stream."""

    def __init__(self, *, max_frame_bytes: int, warn_frame_bytes: int) -> None:
        """Create a bounded JPEG frame extractor."""
        self.max_frame_bytes = max_frame_bytes
        self.warn_frame_bytes = warn_frame_bytes
        self.buffer = bytearray()

    def append(self, chunk: bytes) -> None:
        self.buffer.extend(chunk)

    def extract_frame(self) -> bytes | None:
        start = self._trim_before_start_marker()
        if start < 0:
            return None
        end = self.buffer.find(b"\xff\xd9", start + 2)
        self._check_frame_size(start, end)

        if end < 0:
            return None
        frame = bytes(self.buffer[start : end + 2])
        del self.buffer[: end + 2]
        return frame

    def _trim_before_start_marker(self) -> int:
        start = self.buffer.find(b"\xff\xd8")
        if start > 0:
            del self.buffer[:start]
            return 0
        if start < 0 and len(self.buffer) > 1:
            del self.buffer[:-1]
        return start

    def _check_frame_size(self, start: int, end: int) -> None:
        current_frame_size = (end + 2 if end >= 0 else len(self.buffer)) - start
        if current_frame_size > self.max_frame_bytes:
            raise ValueError(
                "JPEG frame exceeds configured byte cap: "
                f"{current_frame_size} > {self.max_frame_bytes}"
            )
        if current_frame_size > self.warn_frame_bytes:
            logging.getLogger(__name__).warning(
                "JPEG frame buffer exceeds 8 MiB before end marker: %s bytes",
                current_frame_size,
            )


class ProcessVideoDisplay(ProcessLifecycleMixin):
    """Write raw or JPEG video frames to a subprocess stdin."""

    def __init__(self, command: str | list[str]) -> None:
        """Create a process-backed video display."""
        self._configure_process_command(command)

    async def start(self) -> None:
        await self._start_stdin_process()

    async def show_frame(self, frame: bytes, sequence: int, compressed: bool) -> None:
        _ = compressed
        await self.start()
        await self._raise_if_process_exited("video display", "writing")
        await self._write_stdin_or_cleanup(frame, sequence, "video display")

    async def aclose(self) -> None:
        await self._close_process(close_stdin=True)
