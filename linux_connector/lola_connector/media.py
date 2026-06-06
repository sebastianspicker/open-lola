"""LoLa audio/video UDP payload codec.

This layer is the LoLa payload inside UDP. It intentionally does not build raw
Ethernet/IP/UDP headers; Linux normal UDP sockets are enough when LoLa's pcap
RX can see packets on the selected NIC.
"""

from __future__ import annotations

from dataclasses import dataclass
import logging
import math
import struct

logger = logging.getLogger(__name__)


FRAGMENT_MAGIC = bytes.fromhex("fd fd fd fd df df df df")
FRAGMENT_SENTINEL = bytes.fromhex("ee ee ee ee")
VIDEO_PRELUDE_SENTINEL = bytes.fromhex("aa aa aa aa")
FRAGMENT_HEADER_SIZE = 0x21
MEDIA_HEADER_OFFSET = 0x0C
VIDEO_PRELUDE_SIZE = 0x40
# Live Windows LoLa captures show audio UDP payloads padded to 1066 bytes.
# The useful serialized audio inside that packet is still only 8 + PCM bytes.
AUDIO_UDP_PAYLOAD_SIZE = 0x42A
MAX_MEDIA_FRAME_SIZE = 16 * 1024 * 1024
MAX_MEDIA_FRAGMENT_COUNT = 16_384


@dataclass(frozen=True)
class Fragment:
    frame_id: int
    fragment_count: int
    fragment_index: int
    original_offset: int
    fragment_length: int
    flags: int
    data: bytes


@dataclass(frozen=True)
class VideoPrelude:
    frame_id: int
    expected_size: int
    fragment_count: int


@dataclass(frozen=True)
class AudioFrame:
    sequence: int
    pcm: bytes


@dataclass(frozen=True)
class VideoFrame:
    sequence: int
    payload: bytes
    compressed: bool = False


def serialize_media_frame(sequence: int, payload: bytes) -> bytes:
    """Serialize the common LoLa media body: sequence, byte length, payload."""
    return struct.pack("<II", sequence, len(payload)) + payload


def parse_serialized_media(data: bytes) -> tuple[int, bytes]:
    if len(data) < 8:
        raise ValueError("serialized LoLa media frame is shorter than 8 bytes")
    sequence, payload_len = struct.unpack_from("<II", data, 0)
    payload = data[8 : 8 + payload_len]
    if len(payload) != payload_len:
        raise ValueError("serialized LoLa media payload is truncated")
    return sequence, payload


def parse_audio_frame(data: bytes) -> AudioFrame:
    sequence, pcm = parse_serialized_media(data)
    return AudioFrame(sequence, pcm)


def parse_video_frame(data: bytes, compressed: bool = False) -> VideoFrame:
    sequence, payload = parse_serialized_media(data)
    return VideoFrame(sequence, payload, compressed=compressed)


def clamp_packet_size(packet_size: int) -> int:
    return max(0x80, min(0x2000, packet_size))


def fragment_serialized(serialized: bytes, frame_id: int, packet_size: int = 0x400) -> list[bytes]:
    """Wrap a serialized audio/video body in LoLa's 0x21-byte fragments."""
    packet_size = clamp_packet_size(packet_size)
    chunk_capacity = packet_size - FRAGMENT_HEADER_SIZE
    fragment_count = max(1, math.ceil(len(serialized) / chunk_capacity))
    packets: list[bytes] = []

    for index in range(fragment_count):
        offset = index * chunk_capacity
        chunk = serialized[offset : offset + chunk_capacity]
        flags = 1 if index == fragment_count - 1 else 0
        header = (
            FRAGMENT_MAGIC
            + FRAGMENT_SENTINEL
            + struct.pack("<IIIII", frame_id, fragment_count, index, offset, len(chunk))
            + bytes([flags])
        )
        packets.append(header + chunk)
    return packets


def parse_fragment(payload: bytes) -> Fragment | None:
    if len(payload) < FRAGMENT_HEADER_SIZE:
        return None
    if payload[:8] != FRAGMENT_MAGIC or payload[8:12] != FRAGMENT_SENTINEL:
        return None
    frame_id, fragment_count, fragment_index, original_offset, fragment_length = struct.unpack_from(
        "<IIIII",
        payload,
        MEDIA_HEADER_OFFSET,
    )
    data = payload[FRAGMENT_HEADER_SIZE : FRAGMENT_HEADER_SIZE + fragment_length]
    if len(data) != fragment_length:
        return None
    return Fragment(frame_id, fragment_count, fragment_index, original_offset, fragment_length, payload[0x20], data)


def build_video_prelude(frame_id: int, expected_size: int, fragment_count: int) -> bytes:
    """Build the 0x40-byte video frame prelude LoLa expects before fragments."""
    payload = bytearray(VIDEO_PRELUDE_SIZE)
    payload[0:8] = FRAGMENT_MAGIC
    payload[8:12] = VIDEO_PRELUDE_SENTINEL
    struct.pack_into("<III", payload, 0x10, frame_id, expected_size, 0)
    struct.pack_into("<I", payload, 0x1C, fragment_count)
    return bytes(payload)


def parse_video_prelude(payload: bytes) -> VideoPrelude | None:
    if len(payload) != VIDEO_PRELUDE_SIZE:
        return None
    if payload[:8] != FRAGMENT_MAGIC or payload[8:12] != VIDEO_PRELUDE_SENTINEL:
        return None
    frame_id, expected_size = struct.unpack_from("<II", payload, 0x10)
    fragment_count = struct.unpack_from("<I", payload, 0x1C)[0]
    return VideoPrelude(frame_id, expected_size, fragment_count)


def build_audio_payload(sequence: int, pcm: bytes, frame_id: int | None = None) -> bytes:
    """Build one complete LoLa audio UDP payload.

    Audio is a single LoLa fragment per 64-frame callback. Dynamic captures
    showed the accepted Windows relationship is fragment frame_id == body
    sequence + 1; using the same value made Windows count packets incomplete.
    """
    frame_id = ((sequence + 1) & 0xFFFFFFFF) if frame_id is None else frame_id
    serialized = serialize_media_frame(sequence, pcm)
    packets = fragment_serialized(serialized, frame_id, packet_size=AUDIO_UDP_PAYLOAD_SIZE)
    if len(packets) != 1:
        raise ValueError("audio payload must fit into one LoLa fragment")
    return packets[0].ljust(AUDIO_UDP_PAYLOAD_SIZE, b"\x00")


def expected_audio_payload_size(channels: int, bits_per_sample: int = 16, frames_per_callback: int = 64) -> int:
    """PCM byte count for one LoLa audio callback block."""
    return channels * frames_per_callback * (bits_per_sample // 8)


def build_video_payloads(sequence: int, payload: bytes, frame_id: int | None = None, packet_size: int = 1000) -> list[bytes]:
    """Build the full UDP payload sequence for one LoLa video frame."""
    frame_id = sequence if frame_id is None else frame_id
    serialized = serialize_media_frame(sequence, payload)
    fragments = fragment_serialized(serialized, frame_id, packet_size=packet_size)
    return [build_video_prelude(frame_id, len(serialized), len(fragments)), *fragments]


class MediaReassembler:
    """Collect LoLa fragments until one serialized media body is complete."""

    def __init__(self, *, allow_fragment_auto_begin: bool = True) -> None:
        self.allow_fragment_auto_begin = allow_fragment_auto_begin
        self.frame_id: int | None = None
        self.expected_size = 0
        self.fragment_count = 0
        self.parts: dict[int, Fragment] = {}

    def begin(self, frame_id: int, expected_size: int, fragment_count: int) -> None:
        validate_reassembly_shape(expected_size, fragment_count)
        self.frame_id = frame_id
        self.expected_size = expected_size
        self.fragment_count = fragment_count
        self.parts.clear()

    def add(self, fragment: Fragment) -> bytes | None:
        """Add a normal fragment and return the assembled body when complete."""
        if not self._ensure_active_frame(fragment):
            return None
        if not self._store_fragment(fragment):
            return None
        return self._assemble_if_complete()

    def _ensure_active_frame(self, fragment: Fragment) -> bool:
        if self.frame_id is None:
            return self._begin_from_fragment(fragment)
        if fragment.frame_id != self.frame_id:
            logger.warning("fragment frame id %d does not match active frame %d", fragment.frame_id, self.frame_id)
            return False
        return True

    def _begin_from_fragment(self, fragment: Fragment) -> bool:
        if not self.allow_fragment_auto_begin:
            logger.warning("fragment frame %d arrived before a prelude", fragment.frame_id)
            return False
        self.begin(fragment.frame_id, sum_hint(fragment), fragment.fragment_count)
        return True

    def _store_fragment(self, fragment: Fragment) -> bool:
        if not self._fragment_index_in_range(fragment):
            return False
        if self._is_duplicate_fragment(fragment):
            return False
        if fragment.fragment_length <= 0:
            raise ValueError(f"fragment has empty payload at index {fragment.fragment_index}")
        end = fragment.original_offset + fragment.fragment_length
        if end > self.expected_size:
            raise ValueError(f"fragment exceeds declared frame size: {end} > {self.expected_size}")
        self.parts[fragment.fragment_index] = fragment
        return True

    def _fragment_index_in_range(self, fragment: Fragment) -> bool:
        if 0 <= fragment.fragment_index < self.fragment_count:
            return True
        logger.warning(
            "fragment index %d out of range for frame %d with count %d",
            fragment.fragment_index,
            fragment.frame_id,
            self.fragment_count,
        )
        return False

    def _is_duplicate_fragment(self, fragment: Fragment) -> bool:
        if fragment.fragment_index not in self.parts:
            return False
        logger.debug("duplicate fragment %d ignored for frame %d", fragment.fragment_index, fragment.frame_id)
        return True

    def _assemble_if_complete(self) -> bytes | None:
        if len(self.parts) != self.fragment_count:
            return None
        expected_size = self.expected_size or max(
            part.original_offset + part.fragment_length for part in self.parts.values()
        )
        parts_by_offset = sorted(self.parts.values(), key=lambda part: part.original_offset)
        self._validate_part_coverage(parts_by_offset, expected_size)
        result = self._assembled_parts(parts_by_offset, expected_size)
        self._reset_active_frame()
        return result

    def _validate_part_coverage(self, parts_by_offset: list[Fragment], expected_size: int) -> None:
        cursor = 0
        try:
            for part in parts_by_offset:
                if part.original_offset < cursor:
                    raise ValueError(
                        f"fragment overlaps declared frame range at offset {part.original_offset}"
                    )
                if part.original_offset > cursor:
                    raise ValueError(f"fragment gap in declared frame range: {cursor}..{part.original_offset}")
                cursor = part.original_offset + part.fragment_length
            if cursor != expected_size:
                raise ValueError(f"fragment coverage does not match declared frame size: {cursor} != {expected_size}")
        except ValueError:
            self._reset_active_frame()
            raise

    def _assembled_parts(self, parts_by_offset: list[Fragment], expected_size: int) -> bytes:
        assembled = bytearray(expected_size)
        for part in parts_by_offset:
            end = part.original_offset + part.fragment_length
            assembled[part.original_offset:end] = part.data
        return bytes(assembled)

    def _reset_active_frame(self) -> None:
        self.frame_id = None
        self.parts.clear()


def sum_hint(fragment: Fragment) -> int:
    return fragment.original_offset + fragment.fragment_length if fragment.fragment_count == 1 else 0


def validate_reassembly_shape(expected_size: int, fragment_count: int) -> None:
    # Trust boundary: these limits apply after a QuickConn-authenticated peer
    # has joined the session. MAX_MEDIA_FRAME_SIZE and
    # MAX_MEDIA_FRAGMENT_COUNT bound one frame; callers that expose this to
    # untrusted pre-session traffic must add their own rate limit.
    if expected_size <= 0 or expected_size > MAX_MEDIA_FRAME_SIZE:
        raise ValueError(f"invalid LoLa media frame size: {expected_size}")
    if fragment_count <= 0 or fragment_count > MAX_MEDIA_FRAGMENT_COUNT:
        raise ValueError(f"invalid LoLa fragment count: {fragment_count}")


def parse_media_payload(payload: bytes) -> Fragment | VideoPrelude | None:
    prelude = parse_video_prelude(payload)
    if prelude is not None:
        return prelude
    return parse_fragment(payload)
