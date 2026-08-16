"""Consume the implementation-neutral LoLa 2.0 compatibility corpus."""

from __future__ import annotations

import json
from pathlib import Path
from typing import cast

import pytest

from linux_connector.lola_connector.media import (
    AUDIO_UDP_PAYLOAD_SIZE,
    Fragment,
    VideoPrelude,
    build_audio_payload,
    build_video_payloads,
    parse_fragment,
    parse_serialized_media,
    parse_video_prelude,
)
from linux_connector.lola_connector.protocol import (
    CONTROL_DATAGRAM_SIZE,
    MESG_QUICKCONN,
    MESG_QUICKCONN_ACK,
    MediaSettings,
    build_control_datagram,
    parse_control_datagram,
)

CORPUS_PATH = Path(__file__).parents[2] / "interop" / "lola2" / "manifest.json"
CorpusCase = dict[str, object]


def _load_cases() -> tuple[CorpusCase, ...]:
    payload = json.loads(CORPUS_PATH.read_text(encoding="utf-8"))
    assert isinstance(payload, dict)
    assert payload["schema"] == "open-lola.lola2.compatibility-corpus/v1"
    assert isinstance(payload["version"], str)
    assert isinstance(payload["provenance"], dict)
    assert payload["provenance"].get("original_windows_capture") is False
    cases = payload["cases"]
    assert isinstance(cases, list)
    assert cases
    assert all(isinstance(case, dict) for case in cases)
    return tuple(cast(CorpusCase, case) for case in cases)


CASES = _load_cases()


def _text(case: CorpusCase, key: str) -> str:
    value = case[key]
    assert isinstance(value, str)
    return value


def _integer(case: CorpusCase, key: str) -> int:
    value = case[key]
    assert isinstance(value, int)
    return value


def _expected(case: CorpusCase) -> CorpusCase:
    value = case["expected"]
    assert isinstance(value, dict)
    return cast(CorpusCase, value)


def _input_bytes(case: CorpusCase) -> bytes:
    if "input_hex" in case:
        return bytes.fromhex(_text(case, "input_hex"))
    data = _text(case, "input_ascii").encode("ascii")
    if "pad_to" not in case:
        return data
    pad_byte = _text(case, "pad_byte").encode("ascii") if "pad_byte" in case else b"\0"
    assert len(pad_byte) == 1
    return data.ljust(_integer(case, "pad_to"), pad_byte)


def _assert_control_encoding(case: CorpusCase, expected: CorpusCase) -> None:
    kind = _text(case, "kind")
    settings = MediaSettings() if kind in {MESG_QUICKCONN, MESG_QUICKCONN_ACK} else None
    datagram = build_control_datagram(
        kind,
        _text(case, "src_ip"),
        _text(case, "dst_ip"),
        _integer(case, "sid"),
        settings,
        _text(case, "txt") if "txt" in case else "",
    )
    prefix = _text(case, "expected_prefix").encode("ascii")
    assert len(datagram) == _integer(expected, "wire_size") == CONTROL_DATAGRAM_SIZE
    assert datagram[: len(prefix)] == prefix
    assert datagram[len(prefix) :] == b"\0" * (CONTROL_DATAGRAM_SIZE - len(prefix))
    parsed = parse_control_datagram(datagram)
    assert parsed is not None
    assert parsed.sid == _integer(expected, "sid")
    if "txt" in expected:
        assert parsed.txt == _text(expected, "txt")


def _assert_control_parse(case: CorpusCase, expected: CorpusCase) -> None:
    parsed = parse_control_datagram(_input_bytes(case))
    category = _text(expected, "category")
    if category.startswith("reject."):
        assert parsed is None
        return
    assert category == "accept"
    assert parsed is not None
    expected_sid = str(expected["sid_canonical"]) if "sid_canonical" in expected else str(_integer(expected, "sid"))
    assert parsed.fields["SID"] == expected_sid
    if "txt" in expected:
        assert parsed.txt == _text(expected, "txt")


def _assert_control_encoding_rejection(case: CorpusCase, expected: CorpusCase) -> None:
    txt = _text(case, "txt") if "txt" in case else _text(case, "txt_repeat") * _integer(case, "txt_count")
    category = _text(expected, "category")
    error_type: type[Exception]
    if category == "reject.non_ascii":
        error_type = UnicodeEncodeError
    elif category == "reject.oversize":
        error_type = ValueError
    else:
        pytest.fail(f"unsupported control encoding rejection category: {category}")
    with pytest.raises(error_type):
        build_control_datagram(
            _text(case, "kind"),
            _text(case, "src_ip"),
            _text(case, "dst_ip"),
            _integer(case, "sid"),
            txt=txt,
        )


def _assert_serialized_parse(case: CorpusCase, expected: CorpusCase) -> None:
    with pytest.raises(ValueError, match="payload length mismatch"):
        parse_serialized_media(_input_bytes(case))
    assert _text(expected, "category") == "reject.serialized_length"


def _assert_audio_encoding(case: CorpusCase, expected: CorpusCase) -> None:
    payload = build_audio_payload(_integer(case, "sequence"), bytes.fromhex(_text(case, "pcm_hex")))
    fragment = parse_fragment(payload)
    assert len(payload) == _integer(expected, "wire_size") == AUDIO_UDP_PAYLOAD_SIZE
    assert isinstance(fragment, Fragment)
    assert fragment.frame_id == _integer(expected, "frame_id")
    assert fragment.fragment_count == _integer(expected, "fragment_count")
    assert fragment.fragment_index == _integer(expected, "fragment_index")
    assert fragment.original_offset == _integer(expected, "original_offset")
    assert fragment.fragment_length == _integer(expected, "fragment_length")
    assert fragment.flags == _integer(expected, "flags")
    assert fragment.data.hex() == _text(expected, "serialized_hex")
    assert payload[33 + fragment.fragment_length :] == b"\0" * (AUDIO_UDP_PAYLOAD_SIZE - 33 - fragment.fragment_length)


def _assert_video_encoding(case: CorpusCase, expected: CorpusCase) -> None:
    packets = build_video_payloads(
        _integer(case, "sequence"),
        bytes.fromhex(_text(case, "payload_hex")),
        packet_size=_integer(case, "packet_size"),
    )
    prelude = parse_video_prelude(packets[0])
    fragment_cases = expected["fragments"]
    assert isinstance(prelude, VideoPrelude)
    assert isinstance(fragment_cases, list)
    assert prelude.frame_id == _integer(expected, "frame_id")
    assert prelude.expected_size == _integer(expected, "serialized_size")
    assert prelude.fragment_count == _integer(expected, "fragment_count")
    assert packets[0].hex() == _text(expected, "prelude_hex")
    assert len(packets[1:]) == len(fragment_cases)
    for packet, fragment_case in zip(packets[1:], fragment_cases, strict=True):
        assert isinstance(fragment_case, dict)
        expected_fragment = cast(CorpusCase, fragment_case)
        fragment = parse_fragment(packet)
        assert isinstance(fragment, Fragment)
        assert fragment.frame_id == _integer(expected, "frame_id")
        assert fragment.fragment_count == _integer(expected, "fragment_count")
        assert fragment.fragment_index == _integer(expected_fragment, "fragment_index")
        assert fragment.original_offset == _integer(expected_fragment, "original_offset")
        assert fragment.fragment_length == _integer(expected_fragment, "fragment_length")
        assert fragment.flags == _integer(expected_fragment, "flags")
        assert fragment.data.hex() == _text(expected_fragment, "data_hex")


@pytest.mark.parametrize("case", CASES, ids=lambda case: str(case["id"]))
def test_lola2_compatibility_corpus(case: CorpusCase) -> None:
    """Every corpus case is executable against the Python wire codec."""
    expected = _expected(case)
    operation = _text(case, "operation")
    assert _text(expected, "category") in {
        "accept",
        "reject.invalid_sid",
        "reject.duplicate_field",
        "reject.missing_required_fields",
        "reject.txt_order",
        "reject.non_ascii",
        "reject.oversize",
        "reject.serialized_length",
    }
    if operation == "encode_control":
        _assert_control_encoding(case, expected)
    elif operation == "parse_control":
        _assert_control_parse(case, expected)
    elif operation == "reject_control_encoding":
        _assert_control_encoding_rejection(case, expected)
    elif operation == "parse_serialized":
        _assert_serialized_parse(case, expected)
    elif operation == "encode_audio":
        _assert_audio_encoding(case, expected)
    elif operation == "encode_video":
        _assert_video_encoding(case, expected)
    else:
        pytest.fail(f"unknown corpus operation: {operation}")
