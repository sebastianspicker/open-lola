"""Linux media backend interfaces and dependency-free test backends."""

from __future__ import annotations

import asyncio
from dataclasses import dataclass
import math
import shlex
from asyncio.subprocess import PIPE, Process
from typing import Protocol

from .media import expected_audio_payload_size
from .protocol import MediaSettings


class AudioCapture(Protocol):
    async def read_block(self) -> bytes:
        """Return one LoLa audio callback block as interleaved PCM bytes."""


class AudioPlayback(Protocol):
    async def write_block(self, pcm: bytes, sequence: int) -> None:
        """Play or store one received LoLa audio block."""


class VideoCapture(Protocol):
    async def read_frame(self) -> bytes:
        """Return one raw or encoded video frame matching MediaSettings."""


class VideoDisplay(Protocol):
    async def show_frame(self, frame: bytes, sequence: int, compressed: bool) -> None:
        """Display or store one received LoLa video frame."""


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
    """Synthetic LoLa audio source with a distinct tone per channel."""

    settings: MediaSettings
    frequencies: tuple[float, ...] = (440.0, 660.0, 880.0, 1100.0, 1320.0, 1540.0, 1760.0, 1980.0)
    amplitude: float = 0.18
    frames_per_callback: int = 64
    external_pacing: bool = True

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


class ProcessAudioCapture:
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
        if self.process is None:
            self.process = await asyncio.create_subprocess_exec(*self.command, stdout=PIPE)

    async def read_block(self) -> bytes:
        await self.start()
        assert self.process is not None and self.process.stdout is not None
        data = await self.process.stdout.readexactly(self.block_size)
        return data

    async def aclose(self) -> None:
        if self.process is None:
            return
        self.process.terminate()
        try:
            await asyncio.wait_for(self.process.wait(), timeout=1.0)
        except asyncio.TimeoutError:
            self.process.kill()
            await self.process.wait()
        self.process = None


class ProcessAudioPlayback:
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
        assert self.process is not None and self.process.stdin is not None
        self.process.stdin.write(pcm)
        await self.process.stdin.drain()

    async def aclose(self) -> None:
        if self.process is None:
            return
        if self.process.stdin is not None:
            self.process.stdin.close()
        try:
            await asyncio.wait_for(self.process.wait(), timeout=1.0)
        except asyncio.TimeoutError:
            self.process.kill()
            await self.process.wait()
        self.process = None


class ProcessRawVideoCapture:
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
        if self.process is None:
            self.process = await asyncio.create_subprocess_exec(*self.command, stdout=PIPE)

    async def read_frame(self) -> bytes:
        await self.start()
        assert self.process is not None and self.process.stdout is not None
        return await self.process.stdout.readexactly(self.frame_size)

    async def aclose(self) -> None:
        if self.process is None:
            return
        self.process.terminate()
        try:
            await asyncio.wait_for(self.process.wait(), timeout=1.0)
        except asyncio.TimeoutError:
            self.process.kill()
            await self.process.wait()
        self.process = None


class ProcessJpegVideoCapture:
    """Read concatenated JPEG frames from a subprocess stdout.

    LoLa compressed mode expects complete JPEG payloads. This small parser
    splits a continuous byte stream on JPEG SOI/EOI markers.
    """

    def __init__(self, command: str | list[str]) -> None:
        self.command = split_command(command) if isinstance(command, str) else command
        self.process: Process | None = None
        self._buffer = bytearray()

    async def start(self) -> None:
        if self.process is None:
            self.process = await asyncio.create_subprocess_exec(*self.command, stdout=PIPE)

    async def read_frame(self) -> bytes:
        await self.start()
        assert self.process is not None and self.process.stdout is not None
        while True:
            start = self._buffer.find(b"\xff\xd8")
            end = self._buffer.find(b"\xff\xd9", start + 2 if start >= 0 else 0)
            if start >= 0 and end >= 0:
                frame = bytes(self._buffer[start : end + 2])
                del self._buffer[: end + 2]
                return frame
            chunk = await self.process.stdout.read(65536)
            if not chunk:
                raise EOFError("JPEG capture subprocess ended")
            self._buffer.extend(chunk)

    async def aclose(self) -> None:
        if self.process is None:
            return
        self.process.terminate()
        try:
            await asyncio.wait_for(self.process.wait(), timeout=1.0)
        except asyncio.TimeoutError:
            self.process.kill()
            await self.process.wait()
        self.process = None


class ProcessVideoDisplay:
    """Write raw or JPEG video frames to a subprocess stdin."""

    def __init__(self, command: str | list[str]) -> None:
        self.command = split_command(command) if isinstance(command, str) else command
        self.process: Process | None = None

    async def start(self) -> None:
        if self.process is None:
            self.process = await asyncio.create_subprocess_exec(*self.command, stdin=PIPE)

    async def show_frame(self, frame: bytes, sequence: int, compressed: bool) -> None:
        await self.start()
        assert self.process is not None and self.process.stdin is not None
        self.process.stdin.write(frame)
        await self.process.stdin.drain()

    async def aclose(self) -> None:
        if self.process is None:
            return
        if self.process.stdin is not None:
            self.process.stdin.close()
        try:
            await asyncio.wait_for(self.process.wait(), timeout=1.0)
        except asyncio.TimeoutError:
            self.process.kill()
            await self.process.wait()
        self.process = None
