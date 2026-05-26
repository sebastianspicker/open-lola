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


MAGIC = bytes.fromhex("fd fd fd fd df df df df")
SENTINEL = bytes.fromhex("ee ee ee ee")
VIDEO_PRELUDE_SENTINEL = bytes.fromhex("aa aa aa aa")
HEADER_SIZE = 0x21
VIDEO_PRELUDE_SIZE = 0x40


@dataclasses.dataclass(frozen=True)
class LolaFragment:
    src: str
    dst: str
    sport: int
    dport: int
    frame_id: int
    fragment_count: int
    fragment_index: int
    original_offset: int
    fragment_length: int
    flags: int
    data: bytes


@dataclasses.dataclass(frozen=True)
class LolaVideoPrelude:
    src: str
    dst: str
    sport: int
    dport: int
    frame_id: int
    expected_size: int
    fragment_count: int


def parse_lola_fragment(pkt: Any) -> LolaFragment | None:
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
    frames: dict[tuple[str, str, int, int, int], list[LolaFragment]] = collections.defaultdict(list)
    preludes: dict[tuple[str, str, int, int, int], LolaVideoPrelude] = {}
    total = 0
    prelude_total = 0
    with PcapReader(str(path)) as reader:
        for pkt in reader:
            prelude = parse_lola_video_prelude(pkt)
            if prelude is not None:
                prelude_total += 1
                key = (prelude.src, prelude.dst, prelude.sport, prelude.dport, prelude.frame_id)
                preludes[key] = prelude
                continue
            frag = parse_lola_fragment(pkt)
            if frag is None:
                continue
            total += 1
            key = (frag.src, frag.dst, frag.sport, frag.dport, frag.frame_id)
            frames[key].append(frag)

    print(f"lola_fragments={total}")
    print(f"lola_video_preludes={prelude_total}")
    print(f"lola_frames={len(frames)}")
    for key, frags in sorted(frames.items(), key=lambda item: (item[0][4], item[0][:4])):
        src, dst, sport, dport, frame_id = key
        expected = max(f.fragment_count for f in frags)
        prelude = preludes.get(key)
        if prelude is not None:
            expected = prelude.fragment_count
        got_indexes = {f.fragment_index for f in frags}
        complete = len(got_indexes) == expected
        total_bytes = sum(f.fragment_length for f in frags)
        flags = sorted({f.flags for f in frags})
        prelude_note = f" prelude_size={prelude.expected_size}" if prelude is not None else ""
        print(
            f"{src}:{sport} -> {dst}:{dport} frame={frame_id} "
            f"frags={len(got_indexes)}/{expected} complete={complete} "
            f"bytes={total_bytes} flags={flags}{prelude_note}"
        )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("capture", type=Path)
    args = parser.parse_args()
    summarize(args.capture)


if __name__ == "__main__":
    main()
