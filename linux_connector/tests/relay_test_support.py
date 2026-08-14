"""Shared relay doubles for deterministic connector tests."""

from __future__ import annotations

import argparse


class RelaySocketDouble:
    """Socket double that records sent datagrams and can simulate backpressure."""

    def __init__(self, *, blocked: bool = False) -> None:
        self.blocked = blocked
        self.closed = False
        self.sent: list[tuple[bytes, tuple[str, int]]] = []

    def sendto(self, payload: bytes, address: tuple[str, int]) -> int:
        if self.blocked:
            raise BlockingIOError("full")
        self.sent.append((payload, address))
        return len(payload)

    def close(self) -> None:
        self.closed = True


def relay_args() -> argparse.Namespace:
    """Return valid local relay arguments shared by relay coverage tests."""
    return argparse.Namespace(
        tshark="tshark",
        interface="4",
        src_ip="192.0.2.1",
        dst_ip="192.0.2.30",
        audio_port=19788,
        video_port=19798,
        stats_interval=2.0,
    )
