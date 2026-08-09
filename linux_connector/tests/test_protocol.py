"""Characterization tests for OSC15 control datagram decoding."""

from __future__ import annotations

import struct

import pytest

from linux_connector.lola_connector.protocol import parse_osc15_control_datagram
from linux_connector.tests.support import expect_equal, expect_is_none, expect_not_none


def _osc_message(address: str, tags: str, *arguments: bytes) -> bytes:
    return _osc_string(address) + _osc_string("," + tags) + b"".join(arguments)


def _osc_string(value: str) -> bytes:
    raw = value.encode("ascii") + b"\0"
    return raw.ljust((len(raw) + 3) & ~3, b"\0")


def test_osc15_decoder_preserves_mixed_string_int_and_double_arguments() -> None:
    message = _osc_message(
        "/MESG_QUICKCONN_ACK",
        "sdiisdiiii",
        _osc_string("10.0.0.2"),
        struct.pack(">d", 48_000.0),
        struct.pack(">i", 24),
        struct.pack(">i", 2),
        _osc_string("BAYER"),
        struct.pack(">d", 60.0),
        struct.pack(">i", 10),
        struct.pack(">i", 1920),
        struct.pack(">i", 1080),
        struct.pack(">i", 1),
    )

    parsed = expect_not_none(parse_osc15_control_datagram(message), "mixed OSC15 argument parse")

    expect_equal(parsed.src_ip, "10.0.0.2", "mixed OSC15 source IP")
    expect_equal(parsed.fields["SR"], "48000", "mixed OSC15 double sample rate")
    expect_equal(parsed.fields["BPS"], "24", "mixed OSC15 integer bit depth")
    expect_equal(parsed.fields["BAYER"], "1", "mixed OSC15 string marker")
    expect_equal(parsed.fields["FPS"], "60", "mixed OSC15 double frame rate")


@pytest.mark.parametrize(
    ("tags", "argument"),
    [
        ("s", b"10.0.0.2"),
        ("si", _osc_string("10.0.0.2") + b"\x00\x01"),
        ("sd", _osc_string("10.0.0.2") + b"\x00\x00\x00\x00"),
    ],
)
def test_osc15_decoder_rejects_truncated_arguments(tags: str, argument: bytes) -> None:
    message = _osc_message("/MESG_CHECKLOLASTATUS_ACK", tags, argument)

    expect_is_none(parse_osc15_control_datagram(message), f"truncated OSC15 {tags[-1]} argument")


def test_osc15_decoder_rejects_unsupported_argument_tag() -> None:
    message = _osc_message("/MESG_CHECKLOLASTATUS_ACK", "x")

    expect_is_none(parse_osc15_control_datagram(message), "unsupported OSC15 argument tag")
