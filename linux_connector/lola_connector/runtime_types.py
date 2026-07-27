"""Shared state and backend contracts for the Linux LoLa runtime."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Protocol, TypedDict, Unpack, cast, runtime_checkable


@dataclass
class RuntimeStats:  # pylint: disable=too-many-instance-attributes
    """Track media, control, ordering, and cleanup counters for one runtime instance."""

    audio_tx: int = 0
    audio_tx_dropped: int = 0
    audio_rx: int = 0
    audio_rx_dropped: int = 0
    audio_rx_kernel_dropped: int = 0
    audio_rx_wrong_peer_dropped: int = 0
    audio_rx_wrong_port_dropped: int = 0
    audio_rx_malformed_dropped: int = 0
    audio_rx_reordered_dropped: int = 0
    audio_malformed_rx: int = 0
    video_tx: int = 0
    video_tx_dropped: int = 0
    video_tx_replaced: int = 0
    video_tx_deadline_dropped: int = 0
    video_tx_backpressure_dropped: int = 0
    video_rx: int = 0
    video_rx_dropped: int = 0
    video_malformed_rx: int = 0
    control_rx: int = 0
    control_malformed_rx: int = 0
    cleanup_warnings: list[str] = field(default_factory=list)


class _AudioTxPacingCaptureInputs(TypedDict):
    """Name the capture values used to derive an audio pacing schedule."""

    frames_per_callback: int
    sample_rate: int
    interval_scale: float
    external_pacing: bool
    now: float


_AUDIO_TX_PACING_CAPTURE_INPUT_NAMES = tuple(_AudioTxPacingCaptureInputs.__annotations__)


@dataclass
class AudioTxPacing:
    """Carry the monotonic interval and next-send deadline for audio transmission."""

    external: bool
    interval: float
    next_send: float

    @classmethod
    def for_capture(
        cls,
        *arguments: int | float | bool,
        **capture: Unpack[_AudioTxPacingCaptureInputs],
    ) -> AudioTxPacing:
        """Derive pacing state from the capture clock and negotiated sample rate."""
        if len(arguments) > len(_AUDIO_TX_PACING_CAPTURE_INPUT_NAMES):
            raise TypeError("for_capture accepts at most five positional arguments")
        values: dict[str, object] = dict(capture)
        unexpected = set(values).difference(_AUDIO_TX_PACING_CAPTURE_INPUT_NAMES)
        if unexpected:
            name = min(unexpected)
            raise TypeError(f"for_capture got an unexpected keyword argument '{name}'")
        for name, value in zip(_AUDIO_TX_PACING_CAPTURE_INPUT_NAMES, arguments):
            if name in values:
                raise TypeError(f"for_capture got multiple values for argument '{name}'")
            values[name] = value
        missing = [name for name in _AUDIO_TX_PACING_CAPTURE_INPUT_NAMES if name not in values]
        if missing:
            raise TypeError(f"for_capture missing required argument '{missing[0]}'")
        frames_per_callback = cast(int, values["frames_per_callback"])
        sample_rate = cast(int, values["sample_rate"])
        interval_scale = cast(float, values["interval_scale"])
        external_pacing = cast(bool, values["external_pacing"])
        now = cast(float, values["now"])
        interval = (
            frames_per_callback / max(1, sample_rate) * interval_scale
            if frames_per_callback
            else 0.0
        )
        external = bool(external_pacing and interval > 0.0)
        return cls(external=external, interval=interval, next_send=now)

    def advance(self, now: float) -> None:
        """Advance one slot and drop catch-up work after a late capture or send."""
        if not self.external:
            return
        self.next_send += self.interval
        if self.next_send <= now:
            self.next_send = now + self.interval


@dataclass(frozen=True)
class CapturedVideoFrame:
    """Couple encoded video bytes with capture time for stale-frame rejection."""

    frame: bytes
    captured_at: float


@runtime_checkable
class ClosableBackend(Protocol):  # pylint: disable=too-few-public-methods
    """Require asynchronous teardown from a runtime-owned media backend."""

    async def aclose(self) -> None:
        """Release resources owned by the backend."""
        ...


def sequence_is_newer(candidate: int, current: int) -> bool:
    """Compare LoLa's modulo-2^32 media sequence without reordering wrap."""
    distance = (candidate - current) & 0xFFFFFFFF
    return distance != 0 and distance < 0x80000000
