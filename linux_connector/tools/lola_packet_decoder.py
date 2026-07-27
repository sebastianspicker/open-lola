#!/usr/bin/env python3
"""Decode Lola AV UDP fragmentation payloads recovered from static analysis.

This parser targets UDP payloads produced by the flFMTDataEncoder path:

  00: 8-byte magic, bytes fd fd fd fd df df df df
  08: 4-byte sentinel, ee ee ee ee
  0c: uint32 frame_id
  10: uint32 fragment_count
  14: uint32 fragment_index
  18: uint32 original_payload_offset
  1c: uint32 fragment_length
  20: uint8 flags
  21: fragment data

Usage:
  python lola_packet_decoder.py capture.pcapng
"""

from __future__ import annotations

import argparse
import collections
import dataclasses
import struct
from pathlib import Path
from typing import Any

from scapy.all import IP, UDP, PcapReader  # type: ignore[import-not-found]

from linux_connector.lola_connector.media import Fragment


MAGIC = bytes.fromhex("fd fd fd fd df df df df")
SENTINEL = bytes.fromhex("ee ee ee ee")
VIDEO_PRELUDE_SENTINEL = bytes.fromhex("aa aa aa aa")
HEADER_SIZE = 0x21
VIDEO_PRELUDE_SIZE = 0x40


@dataclasses.dataclass(frozen=True)
class LolaFragment(Fragment):  # pylint: disable=too-many-instance-attributes
    """Extend decoded fragments with packet-source context for capture summaries."""
    src: str
    dst: str
    sport: int
    dport: int


@dataclasses.dataclass(frozen=True)
class LolaVideoPrelude:
    """Store video-prelude metadata keyed to a captured LoLa stream."""
    src: str
    dst: str
    sport: int
    dport: int
    frame_id: int
    expected_size: int
    fragment_count: int


FrameKey = tuple[str, str, int, int, int]
FrameMap = dict[FrameKey, list[LolaFragment]]
PreludeMap = dict[FrameKey, LolaVideoPrelude]


@dataclasses.dataclass(frozen=True)
class PacketSummary:
    """Aggregate fragment and prelude observations from one capture file."""
    frames: FrameMap
    preludes: PreludeMap
    fragment_total: int
    prelude_total: int


def parse_lola_fragment(pkt: Any) -> LolaFragment | None:
    """Decode one UDP packet as a LoLa fragment with capture endpoint metadata."""
    if IP not in pkt or UDP not in pkt:
        return None
    udp = pkt[UDP]
    payload = bytes(udp.payload)
    if len(payload) < HEADER_SIZE:
        return None
    if payload[:8] != MAGIC or payload[8:12] != SENTINEL:
        return None
    frame_id, fragment_count, fragment_index, original_offset, fragment_length = struct.unpack_from(
        "<IIIII", payload, 0x0C
    )
    flags = payload[0x20]
    data = payload[HEADER_SIZE : HEADER_SIZE + fragment_length]
    if len(data) != fragment_length:
        return None
    ip = pkt[IP]
    return LolaFragment(
        src=ip.src,
        dst=ip.dst,
        sport=int(udp.sport),
        dport=int(udp.dport),
        frame_id=frame_id,
        fragment_count=fragment_count,
        fragment_index=fragment_index,
        original_offset=original_offset,
        fragment_length=fragment_length,
        flags=flags,
        data=data,
    )


def parse_lola_video_prelude(pkt: Any) -> LolaVideoPrelude | None:
    """Decode one UDP packet as LoLa video-prelude metadata when present."""
    if IP not in pkt or UDP not in pkt:
        return None
    udp = pkt[UDP]
    payload = bytes(udp.payload)
    if len(payload) != VIDEO_PRELUDE_SIZE:
        return None
    if payload[:8] != MAGIC or payload[8:12] != VIDEO_PRELUDE_SENTINEL:
        return None
    frame_id, expected_size = struct.unpack_from("<II", payload, 0x10)
    fragment_count = struct.unpack_from("<I", payload, 0x1C)[0]
    ip = pkt[IP]
    return LolaVideoPrelude(
        src=ip.src,
        dst=ip.dst,
        sport=int(udp.sport),
        dport=int(udp.dport),
        frame_id=frame_id,
        expected_size=expected_size,
        fragment_count=fragment_count,
    )


def summarize(path: Path) -> None:
    """Decode a packet capture and print its LoLa fragment completeness summary."""
    summary = collect_packet_summary(path)
    print_packet_summary(summary)


def collect_packet_summary(path: Path) -> PacketSummary:
    """Group captured fragments and preludes by endpoint tuple and frame ID."""
    frames: FrameMap = collections.defaultdict(list)
    preludes: PreludeMap = {}
    fragment_total = 0
    prelude_total = 0
    with PcapReader(str(path)) as reader:
        for pkt in reader:
            prelude = parse_lola_video_prelude(pkt)
            if prelude is not None:
                prelude_total += 1
                preludes[prelude_key(prelude)] = prelude
                continue
            frag = parse_lola_fragment(pkt)
            if frag is None:
                continue
            fragment_total += 1
            frames[fragment_key(frag)].append(frag)
    return PacketSummary(
        frames=dict(frames),
        preludes=preludes,
        fragment_total=fragment_total,
        prelude_total=prelude_total,
    )


def prelude_key(prelude: LolaVideoPrelude) -> FrameKey:
    """Derive prelude key from the decoded LoLa media metadata."""
    return (prelude.src, prelude.dst, prelude.sport, prelude.dport, prelude.frame_id)


def fragment_key(fragment: LolaFragment) -> FrameKey:
    """Build the stable key used to group media fragments."""
    return (fragment.src, fragment.dst, fragment.sport, fragment.dport, fragment.frame_id)


def print_packet_summary(summary: PacketSummary) -> None:
    """Print capture totals and one completeness line per decoded frame."""
    print(f"lola_fragments={summary.fragment_total}")
    print(f"lola_video_preludes={summary.prelude_total}")
    print(f"lola_frames={len(summary.frames)}")
    for key, fragments in sorted(
        summary.frames.items(),
        key=lambda item: (item[0][4], item[0][:4]),
    ):
        print(frame_summary_line(key, fragments, summary.preludes.get(key)))


def frame_summary_line(
    key: FrameKey,
    fragments: list[LolaFragment],
    prelude: LolaVideoPrelude | None,
) -> str:
    """Render one concise decoded-frame summary line."""
    src, dst, sport, dport, frame_id = key
    got_indexes = {fragment.fragment_index for fragment in fragments}
    expected = expected_fragment_count(fragments, prelude)
    total_bytes = sum(fragment.fragment_length for fragment in fragments)
    flags = sorted({fragment.flags for fragment in fragments})
    return (
        f"{src}:{sport} -> {dst}:{dport} frame={frame_id} "
        f"frags={len(got_indexes)}/{expected} complete={len(got_indexes) == expected} "
        f"bytes={total_bytes} flags={flags}{prelude_size_note(prelude)}"
    )


def expected_fragment_count(fragments: list[LolaFragment], prelude: LolaVideoPrelude | None) -> int:
    """Prefer prelude metadata when determining a frame's expected fragment count."""
    if prelude is not None:
        return prelude.fragment_count
    return max(fragment.fragment_count for fragment in fragments)


def prelude_size_note(prelude: LolaVideoPrelude | None) -> str:
    """Derive prelude size note from the decoded LoLa media metadata."""
    return f" prelude_size={prelude.expected_size}" if prelude is not None else ""


def main() -> None:
    """Parse one capture path and print its decoded LoLa packet summary."""
    parser = argparse.ArgumentParser()
    parser.add_argument("capture", type=Path)
    args = parser.parse_args()
    summarize(args.capture)


if __name__ == "__main__":
    main()
