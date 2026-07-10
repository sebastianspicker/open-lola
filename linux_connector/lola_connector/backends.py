# pylint: disable=missing-function-docstring
"""Linux media backend interfaces and dependency-free test backends."""

from __future__ import annotations

import asyncio
from dataclasses import dataclass, field
import logging
import math
import shlex
from asyncio.subprocess import PIPE, Process
from typing import Protocol

from .media import expected_audio_payload_size
from .protocol import MediaSettings

LOGGER = logging.getLogger(__name__)
SHELL_CONTROL_CHARS = frozenset(";&|<>`$")
SHELL_EXECUTABLE_NAMES = frozenset({
    "bash",
    "cmd",
    "cmd.exe",
    "fish",
    "powershell",
    "powershell.exe",
    "pwsh",
    "pwsh.exe",
    "sh",
    "zsh",
})
ALLOWED_PROCESS_EXECUTABLE_NAMES = frozenset({
    "aplay",
    "arecord",
    "ffmpeg",
    "ffplay",
    "gst-launch-1.0",
    "pacat",
    "parec",
    "python",
    "python3",
})


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


@dataclass(frozen=True)
class ProcessCommand:  # pylint: disable=missing-class-docstring
    executable: str
    executable_name: str
    arguments: tuple[str, ...]

    @property
    def argv(self) -> list[str]:
        return [self.executable, *self.arguments]


@dataclass(frozen=True)
class _RgbPixelContext:  # pylint: disable=too-many-instance-attributes
    x: int
    y: int
    tick: int
    palette: tuple[tuple[int, int, int], ...]
    bar_width: int
    moving_x: int
    moving_y: int
    moving_size: int


class ProcessLifecycleMixin:  # pylint: disable=missing-class-docstring,too-few-public-methods
    command: ProcessCommand
    process: Process | None

    def _configure_process_command(self, command: str | list[str]) -> None:
        self.command = make_process_command(command)
        self.process = None

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
            raise ValueError(
                "DiagnosticVideoCapture emits raw frames; use JPEG process "
                "capture for compressed mode"
            )
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
                frame[row + x] = self._mono8_pixel(
                    x,
                    y,
                    t,
                    bar_width,
                    (cx, cy),
                    (moving_x, moving_y, moving_size),
                )

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
        palette = self._rgb_palette()
        bar_width = max(1, width // len(palette))

        for y in range(height):
            for x in range(width):
                pixel = self._rgb_pixel(
                    _RgbPixelContext(x, y, t, palette, bar_width, moving_x, moving_y, moving_size)
                )
                offset = (y * width + x) * bytes_per_pixel
                self._write_rgb_pixel(frame, offset, bytes_per_pixel, *pixel)

        self.frame_index += 1
        return bytes(frame)

    def _rgb_palette(self) -> tuple[tuple[int, int, int], ...]:
        return (
            (255, 255, 255),
            (255, 255, 0),
            (0, 255, 255),
            (0, 255, 0),
            (255, 0, 255),
            (255, 0, 0),
            (0, 0, 255),
            (0, 0, 0),
        )

    def _mono8_pixel(  # pylint: disable=too-many-arguments,too-many-positional-arguments
        self,
        x: int,
        y: int,
        tick: int,
        bar_width: int,
        crosshair: tuple[int, int],
        moving_square: tuple[int, int, int],
    ) -> int:
        value = self._mono8_bar_value(x, y, bar_width)
        cx, cy = crosshair
        moving_x, moving_y, moving_size = moving_square
        if x == cx or y == cy:
            return 255
        if moving_x <= x < moving_x + moving_size and moving_y <= y < moving_y + moving_size:
            return 255 if ((x + y + tick) & 4) else 32
        if y < 16 and ((x // 8) & 1) == ((tick // 5) & 1):
            return 220
        return value

    def _mono8_bar_value(self, x: int, y: int, bar_width: int) -> int:
        bar_index = min(7, x // bar_width)
        return (bar_index * 32 + (y * 64 // max(1, self.settings.height))) & 0xFF

    def _rgb_pixel(self, context: _RgbPixelContext) -> tuple[int, int, int]:
        r, g, b = context.palette[min(len(context.palette) - 1, context.x // context.bar_width)]
        shade = context.y / max(1, self.settings.height - 1)
        r = int(r * (0.45 + 0.55 * shade))
        g = int(g * (0.45 + 0.55 * shade))
        b = int(b * (0.45 + 0.55 * shade))
        if context.x == self.settings.width // 2 or context.y == self.settings.height // 2:
            return 255, 255, 255
        if _inside_moving_square(context):
            return (255, 255, 255) if ((context.x + context.y + context.tick) & 4) else (0, 0, 0)
        return r, g, b

    def _write_rgb_pixel(  # pylint: disable=too-many-arguments,too-many-positional-arguments
        self,
        frame: bytearray,
        offset: int,
        bytes_per_pixel: int,
        r: int,
        g: int,
        b: int,
    ) -> None:
        frame[offset : offset + 3] = bytes((r, g, b))
        if bytes_per_pixel == 4:
            frame[offset + 3] = 255

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


class MemoryVideoDisplay:  # pylint: disable=missing-class-docstring,too-few-public-methods
    def __init__(self) -> None:
        """Create an in-memory frame sink."""
        self.frames: list[tuple[int, bytes, bool]] = []

    async def show_frame(self, frame: bytes, sequence: int, compressed: bool) -> None:
        self.frames.append((sequence, frame, compressed))


def split_command(command: str) -> list[str]:
    parts = shlex.split(command)
    validate_process_command(parts, reject_shell_control=True)
    return parts


def make_process_command(command: str | list[str]) -> ProcessCommand:
    parts = split_command(command) if isinstance(command, str) else command
    validate_process_command(parts)
    return ProcessCommand(
        executable=parts[0],
        executable_name=process_executable_name(parts[0]),
        arguments=tuple(parts[1:]),
    )


def validate_process_command(command: list[str], *, reject_shell_control: bool = False) -> None:
    if not command:
        raise ValueError("process command must not be empty")
    executable = command[0]
    if not executable:
        raise ValueError("process command executable must not be empty")
    executable_name = process_executable_name(executable)
    validate_process_executable_name(executable_name)
    for argument in command:
        validate_process_argument(argument, reject_shell_control=reject_shell_control)


def validate_process_executable_name(executable_name: str) -> None:
    if executable_name in SHELL_EXECUTABLE_NAMES:
        raise ValueError(f"process command must not invoke a shell directly: {executable_name}")
    if executable_name not in ALLOWED_PROCESS_EXECUTABLE_NAMES:
        allowed = ", ".join(sorted(ALLOWED_PROCESS_EXECUTABLE_NAMES))
        raise ValueError(
            f"process command executable is not allowed: {executable_name}; "
            f"allowed: {allowed}"
        )


def validate_process_argument(argument: str, *, reject_shell_control: bool) -> None:
    if any(ord(character) < 32 or ord(character) == 127 for character in argument):
        raise ValueError("process command arguments must not contain control characters")
    if reject_shell_control and any(character in SHELL_CONTROL_CHARS for character in argument):
        raise ValueError("process command strings must not contain shell control characters")


def _inside_moving_square(context: _RgbPixelContext) -> bool:
    return (
        context.moving_x <= context.x < context.moving_x + context.moving_size
        and context.moving_y <= context.y < context.moving_y + context.moving_size
    )


def process_executable_name(executable: str) -> str:
    return executable.rsplit("/", 1)[-1].rsplit("\\", 1)[-1].lower()


async def launch_stdout_process(command: ProcessCommand) -> Process:
    arguments = command.arguments
    executable = command.executable_name
    if executable not in ALLOWED_PROCESS_EXECUTABLE_NAMES:
        raise RuntimeError(f"unsupported process executable: {executable}")
    return await asyncio.create_subprocess_exec(executable, *arguments, stdout=PIPE)


async def launch_stdin_process(command: ProcessCommand) -> Process:
    arguments = command.arguments
    executable = command.executable_name
    if executable not in ALLOWED_PROCESS_EXECUTABLE_NAMES:
        raise RuntimeError(f"unsupported process executable: {executable}")
    return await asyncio.create_subprocess_exec(executable, *arguments, stdin=PIPE)


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
        await self._write_stdin_or_cleanup(frame, sequence, "video display")

    async def aclose(self) -> None:
        await self._close_process(close_stdin=True)
