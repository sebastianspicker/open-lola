# pylint: disable=missing-function-docstring
"""Synthetic video capture backends."""

from __future__ import annotations

import asyncio
from dataclasses import dataclass

from .protocol import MediaSettings


async def await_raw_video_frame(settings: MediaSettings, compressed_error: str) -> None:
    """Delay one frame interval before raw-video capture is retried."""
    await asyncio.sleep(1.0 / max(1, settings.fps))
    if settings.compression != 0:
        raise ValueError(compressed_error)


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


def _inside_moving_square(context: _RgbPixelContext) -> bool:
    return (
        context.moving_x <= context.x < context.moving_x + context.moving_size
        and context.moving_y <= context.y < context.moving_y + context.moving_size
    )


@dataclass
class DiagnosticVideoCapture:
    """Synthetic moving test card for visual confirmation on Windows LoLa.

    The moving square and frame ticks make it clear that Windows is displaying
    live Linux frames rather than a stale image.
    """

    settings: MediaSettings
    frame_index: int = 0

    async def read_frame(self) -> bytes:
        await await_raw_video_frame(
            self.settings,
            "DiagnosticVideoCapture emits raw frames; use JPEG process capture for compressed mode",
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
