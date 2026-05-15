"""Linux media backend interfaces and dependency-free test backends."""

from __future__ import annotations

import asyncio
from dataclasses import dataclass, field
import logging
import math
import shlex
from asyncio.subprocess import PIPE, Process
from typing import Protocol, runtime_checkable

from .media import expected_audio_payload_size
from .protocol import MediaSettings

LOGGER = logging.getLogger(__name__)


class AudioCapture(Protocol):
    async def read_block(self) -> bytes:
        """Return one LoLa audio callback block as interleaved PCM bytes."""


@runtime_checkable
class AudioBackend(AudioCapture, Protocol):
    async def aclose(self) -> None:
        """Close any process, device, or file resources owned by the backend."""


class AudioPlayback(Protocol):
    async def write_block(self, pcm: bytes, sequence: int) -> None:
        """Play or store one received LoLa audio block."""


class VideoCapture(Protocol):
    async def read_frame(self) -> bytes:
        """Return one raw or encoded video frame matching MediaSettings."""


class VideoDisplay(Protocol):
    async def show_frame(self, frame: bytes, sequence: int, compressed: bool) -> None:
        """Display or store one received LoLa video frame."""


class ProcessLifecycleMixin:
    process: Process | None

    async def _cleanup_failed_start(self, process: Process, original: BaseException, label: str) -> None:
        try:
            process.kill()
            await process.wait()
        except Exception as cleanup_error:
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
        if close_stdin and self.process.stdin is not None:
            self.process.stdin.close()
        try:
            try:
                self.process.terminate()
            except ProcessLookupError:
                await self.process.wait()
                return
            except OSError:
                LOGGER.debug("suppressed process terminate failure during cleanup", exc_info=True)
            try:
                await asyncio.wait_for(self.process.wait(), timeout=1.0)
            except OSError:
                LOGGER.debug("suppressed process wait failure during cleanup", exc_info=True)
        except ProcessLookupError:
            await self.process.wait()
        except asyncio.TimeoutError:
            try:
                self.process.kill()
            except ProcessLookupError:
                pass
            except OSError:
                LOGGER.debug("suppressed process kill failure during cleanup", exc_info=True)
            try:
                await self.process.wait()
            except OSError:
                LOGGER.debug("suppressed process wait-after-kill failure during cleanup", exc_info=True)
        finally:
            self.process = None


@dataclass
class SilenceAudioCapture:
    """Synthetic silence source for protocol/timing tests without audio I/O."""

    settings: MediaSettings
    frames_per_callback: int = 64
    # Synthetic sources are paced by LolaLinuxRuntime so one clock controls all
    # LoLa audio packet timing.
    external_pacing: bool = True

    async def read_block(self) -> bytes:
        return bytes(expected_audio_payload_size(self.settings.channels, self.settings.bits_per_sample, self.frames_per_callback))


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


class MemoryAudioPlayback:
    def __init__(self) -> None:
        self.blocks: list[tuple[int, bytes]] = []

    async def write_block(self, pcm: bytes, sequence: int) -> None:
        self.blocks.append((sequence, pcm))


@dataclass
class PatternVideoCapture:
    settings: MediaSettings
    frame_index: int = 0

    async def read_frame(self) -> bytes:
        await asyncio.sleep(1.0 / max(1, self.settings.fps))
        if self.settings.compression != 0:
            raise ValueError("PatternVideoCapture emits raw frames; use a JPEG/GStreamer backend for compressed mode")
        pixel_count = self.settings.width * self.settings.height
        if self.settings.bits_per_pixel != 8:
            raise ValueError("PatternVideoCapture currently emits 8-bit mono/raw frames only")
        base = self.frame_index & 0xFF
        self.frame_index += 1
        return bytes((base + x) & 0xFF for x in range(pixel_count))


@dataclass
class DiagnosticVideoCapture:
    """Synthetic moving test card for visual confirmation on Windows LoLa.

    The moving square and frame ticks make it clear that Windows is displaying
    live Linux frames rather than a stale image.
    """

    settings: MediaSettings
    frame_index: int = 0

    async def read_frame(self) -> bytes:
        await asyncio.sleep(1.0 / max(1, self.settings.fps))
        if self.settings.compression != 0:
            raise ValueError("DiagnosticVideoCapture emits raw frames; use JPEG process capture for compressed mode")
        if self.settings.bits_per_pixel == 8:
            return self._mono8_frame()
        if self.settings.bits_per_pixel in {24, 32}:
            return self._rgb_frame(bytes_per_pixel=self.settings.bits_per_pixel // 8)
        raise ValueError("DiagnosticVideoCapture supports 8, 24, or 32 bits per pixel")

    def _mono8_frame(self) -> bytes:
        width = self.settings.width
        height = self.settings.height
        frame = bytearray(width * height)
        t = self.frame_index
        bar_width = max(1, width // 8)
        moving_size = max(8, min(width, height) // 8)
        moving_x = (t * 7) % max(1, width - moving_size)
        moving_y = (t * 5) % max(1, height - moving_size)
        cx = width // 2
        cy = height // 2

        for y in range(height):
            row = y * width
            for x in range(width):
                bar = min(7, x // bar_width)
                value = (bar * 32 + (y * 64 // max(1, height))) & 0xFF
                if x == cx or y == cy:
                    value = 255
                if moving_x <= x < moving_x + moving_size and moving_y <= y < moving_y + moving_size:
                    value = 255 if ((x + y + t) & 4) else 32
                if y < 16 and ((x // 8) & 1) == ((t // 5) & 1):
                    value = 220
                frame[row + x] = value

        self._draw_frame_ticks_mono(frame, width, height, t)
        self.frame_index += 1
        return bytes(frame)

    def _rgb_frame(self, bytes_per_pixel: int) -> bytes:
        width = self.settings.width
        height = self.settings.height
        frame = bytearray(width * height * bytes_per_pixel)
        t = self.frame_index
        moving_size = max(8, min(width, height) // 8)
        moving_x = (t * 7) % max(1, width - moving_size)
        moving_y = (t * 5) % max(1, height - moving_size)
        palette = (
            (255, 255, 255),
            (255, 255, 0),
            (0, 255, 255),
            (0, 255, 0),
            (255, 0, 255),
            (255, 0, 0),
            (0, 0, 255),
            (0, 0, 0),
        )
        bar_width = max(1, width // len(palette))
        cx = width // 2
        cy = height // 2

        for y in range(height):
            for x in range(width):
                r, g, b = palette[min(len(palette) - 1, x // bar_width)]
                shade = y / max(1, height - 1)
                r = int(r * (0.45 + 0.55 * shade))
                g = int(g * (0.45 + 0.55 * shade))
                b = int(b * (0.45 + 0.55 * shade))
                if x == cx or y == cy:
                    r, g, b = 255, 255, 255
                if moving_x <= x < moving_x + moving_size and moving_y <= y < moving_y + moving_size:
                    r, g, b = (255, 255, 255) if ((x + y + t) & 4) else (0, 0, 0)
                offset = (y * width + x) * bytes_per_pixel
                frame[offset : offset + 3] = bytes((r, g, b))
                if bytes_per_pixel == 4:
                    frame[offset + 3] = 255

        self.frame_index += 1
        return bytes(frame)

    def _draw_frame_ticks_mono(self, frame: bytearray, width: int, height: int, tick: int) -> None:
        tick_count = min(16, width // 10)
        y0 = max(0, height - 18)
        for bit in range(tick_count):
            value = 255 if (tick >> bit) & 1 else 40
            x0 = 2 + bit * 10
            for y in range(y0, min(height, y0 + 12)):
                row = y * width
                for x in range(x0, min(width, x0 + 8)):
                    frame[row + x] = value


class MemoryVideoDisplay:
    def __init__(self) -> None:
        self.frames: list[tuple[int, bytes, bool]] = []

    async def show_frame(self, frame: bytes, sequence: int, compressed: bool) -> None:
        self.frames.append((sequence, frame, compressed))


class ProcessBackendError(RuntimeError):
    pass


def split_command(command: str) -> list[str]:
    return shlex.split(command)


class ProcessAudioCapture(ProcessLifecycleMixin):
    """Read raw interleaved PCM blocks from a subprocess stdout.

    The subprocess is responsible for real device timing. Unlike synthetic
    captures, this backend does not declare external_pacing.

    Example command on Linux:
    `ffmpeg -hide_banner -loglevel error -f pulse -i default -f s16le -ac 2 -ar 44100 -`
    """

    def __init__(self, command: str | list[str], settings: MediaSettings, frames_per_callback: int = 64) -> None:
        self.command = split_command(command) if isinstance(command, str) else command
        self.settings = settings
        self.frames_per_callback = frames_per_callback
        self.block_size = expected_audio_payload_size(settings.channels, settings.bits_per_sample, frames_per_callback)
        self.process: Process | None = None

    async def start(self) -> None:
        if self.process is None or self.process.returncode is not None:
            process: Process | None = None
            try:
                process = await asyncio.create_subprocess_exec(*self.command, stdout=PIPE)
                self.process = process
                if process.stdout is None:
                    raise RuntimeError("audio capture process did not expose stdout")
            except asyncio.CancelledError as original:
                if process is not None:
                    await self._cleanup_failed_start(process, original, "audio capture")
                raise
            except (OSError, RuntimeError) as original:
                if process is not None:
                    await self._cleanup_failed_start(process, original, "audio capture")
                raise

    async def read_block(self) -> bytes:
        await self.start()
        if self.process is None or self.process.stdout is None:
            raise RuntimeError("audio capture process is not ready")
        if self.process.returncode is not None:
            returncode = self.process.returncode
            await self.aclose()
            raise RuntimeError(f"audio capture process died before reading: exit {returncode}")
        return await self._readexactly_or_cleanup(self.process.stdout, self.block_size, "audio capture")

    async def aclose(self) -> None:
        await self._close_process()


class ProcessAudioPlayback(ProcessLifecycleMixin):
    """Write raw interleaved PCM blocks to a subprocess stdin.

    Example command on Linux:
    `ffplay -hide_banner -loglevel error -f s16le -ac 2 -ar 44100 -nodisp -autoexit -`
    """

    def __init__(self, command: str | list[str]) -> None:
        self.command = split_command(command) if isinstance(command, str) else command
        self.process: Process | None = None

    async def start(self) -> None:
        if self.process is None:
            self.process = await asyncio.create_subprocess_exec(*self.command, stdin=PIPE)

    async def write_block(self, pcm: bytes, sequence: int) -> None:
        await self.start()
        if self.process is None or self.process.stdin is None:
            raise RuntimeError("audio playback process is not ready")
        try:
            self.process.stdin.write(pcm)
            await self.process.stdin.drain()
        except (BrokenPipeError, ConnectionError, OSError) as exc:
            await self.aclose()
            raise RuntimeError(f"audio playback process died while writing sequence {sequence}: {exc}") from exc

    async def aclose(self) -> None:
        await self._close_process(close_stdin=True)


class ProcessRawVideoCapture(ProcessLifecycleMixin):
    """Read fixed-size raw frames from a subprocess stdout.

    The frame size must match the negotiated LoLa raw video settings exactly;
    otherwise the receiver will reassemble valid packets into invalid frames.

    Example command on Linux:
    `ffmpeg -hide_banner -loglevel error -f v4l2 -video_size 640x480 -framerate 25 -i /dev/video0 -pix_fmt gray -f rawvideo -`
    """

    def __init__(self, command: str | list[str], settings: MediaSettings) -> None:
        self.command = split_command(command) if isinstance(command, str) else command
        self.settings = settings
        self.frame_size = settings.width * settings.height * max(1, settings.bits_per_pixel // 8)
        self.process: Process | None = None

    async def start(self) -> None:
        if self.process is None or self.process.returncode is not None:
            process: Process | None = None
            try:
                process = await asyncio.create_subprocess_exec(*self.command, stdout=PIPE)
                self.process = process
                if process.stdout is None:
                    raise RuntimeError("raw video capture process did not expose stdout")
            except asyncio.CancelledError as original:
                if process is not None:
                    await self._cleanup_failed_start(process, original, "raw video capture")
                raise
            except (OSError, RuntimeError) as original:
                if process is not None:
                    await self._cleanup_failed_start(process, original, "raw video capture")
                raise

    async def read_frame(self) -> bytes:
        await self.start()
        if self.process is None or self.process.stdout is None:
            raise RuntimeError("raw video capture process is not ready")
        if self.process.returncode is not None:
            returncode = self.process.returncode
            await self.aclose()
            raise RuntimeError(f"raw video capture process died before reading: exit {returncode}")
        return await self._readexactly_or_cleanup(self.process.stdout, self.frame_size, "raw video capture")

    async def aclose(self) -> None:
        await self._close_process()


class ProcessJpegVideoCapture(ProcessLifecycleMixin):
    """Read concatenated JPEG frames from a subprocess stdout.

    LoLa compressed mode expects complete JPEG payloads. This small parser
    splits a continuous byte stream on JPEG SOI/EOI markers.
    """

    DEFAULT_MAX_FRAME_BYTES = 16 * 1024 * 1024
    WARN_FRAME_BYTES = 8 * 1024 * 1024

    def __init__(self, command: str | list[str], max_frame_bytes: int = DEFAULT_MAX_FRAME_BYTES) -> None:
        if max_frame_bytes <= 0:
            raise ValueError("max_frame_bytes must be positive")
        self.command = split_command(command) if isinstance(command, str) else command
        self.max_frame_bytes = max_frame_bytes
        self.process: Process | None = None
        self._extractor = JpegFrameExtractor(
            max_frame_bytes=max_frame_bytes,
            warn_frame_bytes=self.WARN_FRAME_BYTES,
        )
        self._buffer = self._extractor.buffer

    async def start(self) -> None:
        if self.process is None or self.process.returncode is not None:
            process: Process | None = None
            try:
                process = await asyncio.create_subprocess_exec(*self.command, stdout=PIPE)
                self.process = process
                if process.stdout is None:
                    raise RuntimeError("JPEG video capture process did not expose stdout")
            except asyncio.CancelledError as original:
                if process is not None:
                    await self._cleanup_failed_start(process, original, "JPEG video capture")
                raise
            except (OSError, RuntimeError) as original:
                if process is not None:
                    await self._cleanup_failed_start(process, original, "JPEG video capture")
                raise

    async def read_frame(self) -> bytes:
        await self.start()
        if self.process is None or self.process.stdout is None:
            raise RuntimeError("JPEG video capture process is not ready")
        if self.process.returncode is not None:
            returncode = self.process.returncode
            await self.aclose()
            raise RuntimeError(f"JPEG video capture process died before reading: exit {returncode}")
        while True:
            if frame := self._extract_frame():
                return frame
            chunk = await self._read_or_cleanup(self.process.stdout, 65536)
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
        self.max_frame_bytes = max_frame_bytes
        self.warn_frame_bytes = warn_frame_bytes
        self.buffer = bytearray()

    def append(self, chunk: bytes) -> None:
        self.buffer.extend(chunk)

    def extract_frame(self) -> bytes | None:
        start = self.buffer.find(b"\xff\xd8")
        if start > 0:
            del self.buffer[:start]
            start = 0
        elif start < 0 and len(self.buffer) > 1:
            del self.buffer[:-1]

        if start < 0:
            return None
        end = self.buffer.find(b"\xff\xd9", start + 2)
        current_frame_size = (end + 2 if end >= 0 else len(self.buffer)) - start
        if current_frame_size > self.max_frame_bytes:
            raise ValueError(f"JPEG frame exceeds configured byte cap: {current_frame_size} > {self.max_frame_bytes}")
        if current_frame_size > self.warn_frame_bytes:
            logging.getLogger(__name__).warning(
                "JPEG frame buffer exceeds 8 MiB before end marker: %s bytes",
                current_frame_size,
            )

        if end < 0:
            return None
        frame = bytes(self.buffer[start : end + 2])
        del self.buffer[: end + 2]
        return frame


class ProcessVideoDisplay(ProcessLifecycleMixin):
    """Write raw or JPEG video frames to a subprocess stdin."""

    def __init__(self, command: str | list[str]) -> None:
        self.command = split_command(command) if isinstance(command, str) else command
        self.process: Process | None = None

    async def start(self) -> None:
        if self.process is None:
            self.process = await asyncio.create_subprocess_exec(*self.command, stdin=PIPE)

    async def show_frame(self, frame: bytes, sequence: int, compressed: bool) -> None:
        await self.start()
        if self.process is None or self.process.stdin is None:
            raise RuntimeError("video display process is not ready")
        try:
            self.process.stdin.write(frame)
            await self.process.stdin.drain()
        except (BrokenPipeError, ConnectionError, OSError) as exc:
            await self.aclose()
            raise RuntimeError(f"video display process died while writing sequence {sequence}: {exc}") from exc

    async def aclose(self) -> None:
        await self._close_process(close_stdin=True)
