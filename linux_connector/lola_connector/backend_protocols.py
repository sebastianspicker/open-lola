"""Protocols shared by Linux media backends and runtime orchestration."""

from __future__ import annotations

from typing import Protocol


class AudioCapture(Protocol):  # pylint: disable=too-few-public-methods
    """Specify the asynchronous PCM source consumed by the runtime transmitter."""

    async def read_block(self) -> bytes:
        """Return one LoLa audio callback block as interleaved PCM bytes."""
        raise NotImplementedError


class AudioPlayback(Protocol):  # pylint: disable=too-few-public-methods
    """Specify the asynchronous PCM sink fed by the runtime receiver."""

    async def write_block(self, pcm: bytes, sequence: int) -> None:
        """Play or store one received LoLa audio block."""
        raise NotImplementedError


class VideoCapture(Protocol):  # pylint: disable=too-few-public-methods
    """Specify the asynchronous raw or compressed video source for transmission."""

    async def read_frame(self) -> bytes:
        """Return one raw or encoded video frame matching MediaSettings."""
        raise NotImplementedError


class VideoDisplay(Protocol):  # pylint: disable=too-few-public-methods
    """Specify the asynchronous decoded-video sink used by the runtime."""

    async def show_frame(self, frame: bytes, sequence: int, compressed: bool) -> None:
        """Display or store one received LoLa video frame."""
        raise NotImplementedError
