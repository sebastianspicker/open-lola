"""Transmit scheduling and local-capture validation for the Linux LoLa runtime."""

from __future__ import annotations

import asyncio
import logging
import socket
import time
from typing import Protocol, cast

from .backends import AudioCapture, VideoCapture
from .connector import LolaConnector
from .media import expected_audio_payload_size
from .runtime_types import (
    VIDEO_FRAME_MAX_AGE_SECONDS,
    AudioTxPacing,
    CapturedVideoFrame,
    RuntimeStats,
    VideoDeadlineSender,
)

logger = logging.getLogger(__name__)


class RuntimeTransmitHost(Protocol):
    """Runtime state consumed by deterministic transmit scheduling helpers."""

    connector: LolaConnector
    audio_capture: AudioCapture
    video_capture: VideoCapture | None
    audio_interval_scale: float
    stats: RuntimeStats
    _stop: asyncio.Event
    _audio_sock: socket.socket | None
    _video_sock: socket.socket | None
    _audio_tx_enabled: asyncio.Event
    _video_tx_enabled: asyncio.Event
    _video_tx_queue: asyncio.Queue[CapturedVideoFrame]


async def audio_tx_loop(runtime: RuntimeTransmitHost) -> None:
    """Send paced audio blocks while transmission is enabled."""
    sequence = 0
    pacing = audio_tx_pacing(runtime)
    while not runtime._stop.is_set():
        if audio_tx_is_paused(runtime):
            pacing.next_send = time.perf_counter()
            await asyncio.sleep(0.01)
            continue
        await wait_for_audio_tx_deadline(pacing)
        if runtime._stop.is_set():
            break
        sequence = await send_audio_tx_packet(runtime, sequence)
        advance_audio_tx_deadline(pacing)


def audio_tx_pacing(runtime: RuntimeTransmitHost) -> AudioTxPacing:
    """Derive cadence from the capture source and negotiated media settings."""
    frames_per_callback = getattr(runtime.audio_capture, "frames_per_callback", 0)
    if frames_per_callback == 0:
        logger.warning("audio capture frames_per_callback=0; external pacing is disabled")
    return AudioTxPacing.for_capture(
        frames_per_callback=frames_per_callback,
        sample_rate=runtime.connector.settings.sample_rate,
        interval_scale=runtime.audio_interval_scale,
        external_pacing=bool(getattr(runtime.audio_capture, "external_pacing", False)),
        now=time.perf_counter(),
    )


def audio_tx_is_paused(runtime: RuntimeTransmitHost) -> bool:
    """Report whether control currently disables audio transmission."""
    return not runtime._audio_tx_enabled.is_set()


async def wait_for_audio_tx_deadline(pacing: AudioTxPacing) -> None:
    """Yield until an externally paced capture reaches its next packet deadline."""
    if not pacing.external:
        return
    while True:
        remaining = pacing.next_send - time.perf_counter()
        if remaining <= 0:
            return
        await asyncio.sleep(remaining)


async def send_audio_tx_packet(runtime: RuntimeTransmitHost, sequence: int) -> int:
    """Validate and transmit one exact 64-frame local PCM block."""
    if runtime._audio_sock is None:
        raise RuntimeError("audio socket is not initialized")
    pcm = await runtime.audio_capture.read_block()
    if runtime._stop.is_set():
        return sequence
    if not valid_local_audio_payload(runtime, pcm):
        runtime.stats.audio_tx_dropped += 1
        runtime.stats.audio_tx_malformed_dropped += 1
        logger.warning("dropped malformed captured LoLa audio block bytes=%s", len(pcm))
        return (sequence + 1) & 0xFFFFFFFF
    sent = await runtime.connector.send_audio_on_socket(runtime._audio_sock, pcm, sequence)
    if sent is False:
        runtime.stats.audio_tx_dropped += 1
        return (sequence + 1) & 0xFFFFFFFF
    runtime.stats.audio_tx += 1
    return (sequence + 1) & 0xFFFFFFFF


def valid_local_audio_payload(runtime: RuntimeTransmitHost, pcm: bytes) -> bool:
    """Require one exact local 64-frame PCM payload before packetizing it."""
    expected_size = expected_audio_payload_size(
        channels=runtime.connector.settings.channels,
        bits_per_sample=runtime.connector.settings.bits_per_sample,
    )
    return len(pcm) == expected_size


def advance_audio_tx_deadline(pacing: AudioTxPacing) -> None:
    """Advance the capture cadence after a transmit attempt."""
    pacing.advance(time.perf_counter())


async def video_capture_loop(runtime: RuntimeTransmitHost) -> None:
    """Continuously retain only the newest frame produced by the backend."""
    if runtime.video_capture is None:
        raise RuntimeError("video_capture must be set before starting video capture loop")
    while not runtime._stop.is_set():
        if not runtime._video_tx_enabled.is_set():
            await asyncio.sleep(0.01)
            continue
        frame = await runtime.video_capture.read_frame()
        if runtime._stop.is_set():
            break
        captured = CapturedVideoFrame(frame=frame, captured_at=time.perf_counter())
        try:
            runtime._video_tx_queue.put_nowait(captured)
        except asyncio.QueueFull:
            runtime._video_tx_queue.get_nowait()
            runtime.stats.video_tx_replaced += 1
            runtime.stats.video_tx_dropped += 1
            runtime._video_tx_queue.put_nowait(captured)


async def video_tx_loop(runtime: RuntimeTransmitHost) -> None:
    """Transmit freshest captured video frames while video transmission is enabled."""
    sequence = 0
    if runtime.video_capture is None:
        raise RuntimeError("video_capture must be set before starting video TX loop")
    while not runtime._stop.is_set():
        if not runtime._video_tx_enabled.is_set():
            await asyncio.sleep(0.01)
            continue
        captured = await runtime._video_tx_queue.get()
        if runtime._stop.is_set():
            break
        outcome = await send_captured_video(runtime, captured, sequence)
        sequence = (sequence + 1) & 0xFFFFFFFF
        if outcome == "sent":
            runtime.stats.video_tx += 1
        else:
            record_video_tx_drop(runtime, outcome)


async def send_captured_video(runtime: RuntimeTransmitHost, captured: CapturedVideoFrame, sequence: int) -> str:
    """Transmit a fresh, locally valid captured video frame."""
    if runtime._video_sock is None:
        raise RuntimeError("video socket is not initialized")
    deadline = captured.captured_at + VIDEO_FRAME_MAX_AGE_SECONDS
    if time.perf_counter() >= deadline:
        return "deadline"
    if not valid_local_video_payload(runtime, captured.frame):
        return "malformed"
    sender = cast(VideoDeadlineSender | None, getattr(runtime.connector, "send_video_until_on_socket", None))
    if sender is not None:
        return await sender(runtime._video_sock, captured.frame, sequence, deadline=deadline)
    sent = await runtime.connector.send_video_on_socket(runtime._video_sock, captured.frame, sequence)
    return "sent" if sent else "backpressure"


def valid_local_video_payload(runtime: RuntimeTransmitHost, frame: bytes) -> bool:
    """Validate raw capture geometry; compressed frames are opaque to the runtime."""
    settings = runtime.connector.settings
    if settings.compression:
        return True
    width = settings.width
    height = settings.height
    bits_per_pixel = settings.bits_per_pixel
    if width <= 0 or height <= 0 or bits_per_pixel <= 0 or bits_per_pixel % 8:
        return False
    return len(frame) == width * height * (bits_per_pixel // 8)


def record_video_tx_drop(runtime: RuntimeTransmitHost, outcome: str) -> None:
    """Record deadline, backpressure, or malformed-capture video drops."""
    runtime.stats.video_tx_dropped += 1
    if outcome == "deadline":
        runtime.stats.video_tx_deadline_dropped += 1
    elif outcome == "backpressure":
        runtime.stats.video_tx_backpressure_dropped += 1
    elif outcome == "malformed":
        runtime.stats.video_tx_malformed_dropped += 1
