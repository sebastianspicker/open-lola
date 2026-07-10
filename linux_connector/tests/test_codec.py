"""Tests for Linux connector media and protocol codecs."""

# pylint: disable=missing-function-docstring

from __future__ import annotations

import struct
import tomllib
from pathlib import Path
from typing import TypeVar

import pytest
from pytest import LogCaptureFixture

from linux_connector.lola_connector.media import (
    Fragment,
    MAX_MEDIA_FRAME_SIZE,
    MAX_MEDIA_FRAGMENT_COUNT,
    MediaReassembler,
    VideoPrelude,
    build_audio_payload,
    build_video_payloads,
    expected_audio_payload_size,
    parse_media_payload,
    parse_serialized_media,
)
from linux_connector.lola_connector.connector import LolaConnector, LolaConnectorOptions, Session
from linux_connector.lola_connector.ethernet import (
    build_ethernet_ipv4_udp_frame,
    build_ipv4_udp_packet,
    parse_mac,
)
from linux_connector.lola_connector.selftest import (
    default_port_offset,
)
from linux_connector.lola_connector.protocol import (
    CONTROL_DATAGRAM_SIZE,
    CONTROL_MESSAGE_KINDS,
    DEFAULT_VIDEO_PORT,
    MESG_CHAT,
    MESG_CHECKLOLASTATUS_ACK,
    MESG_DISCONNECT,
    MESG_QUICKCONN,
    MESG_QUICKCONN_ACK,
    MESG_REJECT,
    MESG_SEND_AUDIO_SIGNAL,
    MESG_STOP_AUDIO_SIGNAL,
    ControlMessage,
    MediaSettings,
    build_osc15_control_datagram,
    build_control_datagram,
    parse_control_datagram,
)

T = TypeVar("T")


def expect_true(condition: object, label: str) -> None:
    if not condition:
        pytest.fail(f"{label}: expected truthy value")


def expect_equal(actual: object, expected: object, label: str) -> None:
    if actual != expected:
        pytest.fail(f"{label}: expected {expected!r}, got {actual!r}")


def expect_not_equal(actual: object, expected: object, label: str) -> None:
    if actual == expected:
        pytest.fail(f"{label}: expected value different from {expected!r}")


def expect_less_than(actual: int, threshold: int, label: str) -> None:
    if actual >= threshold:
        pytest.fail(f"{label}: expected value less than {threshold}, got {actual}")


def expect_greater_than(actual: int, threshold: int, label: str) -> None:
    if actual <= threshold:
        pytest.fail(f"{label}: expected value greater than {threshold}, got {actual}")


def expect_is_none(actual: object, label: str) -> None:
    if actual is not None:
        pytest.fail(f"{label}: expected None, got {actual!r}")


def expect_not_none(actual: T | None, label: str) -> T:
    if actual is None:
        pytest.fail(f"{label}: expected non-None value")
    return actual


def expect_instance(actual: object, expected_type: type[T], label: str) -> T:
    if not isinstance(actual, expected_type):
        pytest.fail(f"{label}: expected {expected_type.__name__}, got {type(actual).__name__}")
    return actual


def expect_contains(needle: str, haystack: str, label: str) -> None:
    if needle not in haystack:
        pytest.fail(f"{label}: expected {needle!r} in {haystack!r}")


def test_control_quickconn_round_trip() -> None:
    settings = MediaSettings(width=1280, height=720, compression=1)
    datagram = build_control_datagram(MESG_QUICKCONN, "10.0.0.1", "10.0.0.2", 1, settings)
    expect_equal(len(datagram), CONTROL_DATAGRAM_SIZE, "quickconn datagram size")
    parsed = expect_not_none(parse_control_datagram(datagram), "quickconn datagram parse")
    expect_equal(parsed.kind, "MESG_QUICKCONN", "quickconn kind")
    expect_equal(parsed.src_ip, "10.0.0.1", "quickconn source IP")
    expect_equal(parsed.dst_ip, "10.0.0.2", "quickconn destination IP")
    expect_equal(parsed.sid, 1, "quickconn session ID")
    expect_equal(parsed.media.width, 1280, "quickconn media width")
    expect_equal(parsed.media.height, 720, "quickconn media height")
    expect_equal(parsed.media.compression, 1, "quickconn compression")


def test_invalid_media_setting_numbers_are_rejected() -> None:
    with pytest.raises(ValueError, match="invalid numeric media field SR"):
        MediaSettings.from_fields({"SR": "garbage"})


def test_nonfinite_media_setting_numbers_are_rejected() -> None:
    with pytest.raises(ValueError, match="invalid numeric media field SR"):
        MediaSettings.from_fields({"SR": "1e309"})
    with pytest.raises(ValueError, match="invalid media setting width"):
        MediaSettings(width=MAX_MEDIA_FRAME_SIZE, height=MAX_MEDIA_FRAME_SIZE)


@pytest.mark.parametrize("field", ["SR", "FPS"])
def test_fractional_media_setting_numbers_are_rejected(field: str) -> None:
    with pytest.raises(ValueError, match=f"invalid numeric media field {field}"):
        MediaSettings.from_fields({field: "44100.5"})


def test_lola_connector_accepts_options_keyword_without_legacy_args() -> None:
    options = LolaConnectorOptions(
        control_port=0,
        audio_port=10,
        video_port=11,
        video_packet_size=512,
        control_dialect="osc15",
        source_name="linux-test",
    )

    connector = LolaConnector("127.0.0.1", options=options)

    expect_equal(connector.control_port, 0, "options control port")
    expect_equal(connector.audio_port, 10, "options audio port")
    expect_equal(connector.video_port, 11, "options video port")
    expect_equal(connector.video_packet_size, 512, "options video packet size")
    expect_equal(connector.control_dialect, "osc15", "options control dialect")
    expect_equal(connector.source_name, "linux-test", "options source name")


def test_lola_connector_accepts_settings_keyword() -> None:
    settings = MediaSettings(width=16, height=8)

    connector = LolaConnector("127.0.0.1", settings=settings, control_port=0)

    expect_equal(connector.settings, settings, "settings keyword")
    expect_equal(connector.control_port, 0, "settings keyword control port")


def test_lola_connector_preserves_legacy_positional_options() -> None:
    connector = LolaConnector("127.0.0.1", MediaSettings(), 0, 10, 11, 512, "osc15", "legacy-test")

    expect_equal(connector.control_port, 0, "legacy control port")
    expect_equal(connector.audio_port, 10, "legacy audio port")
    expect_equal(connector.video_port, 11, "legacy video port")
    expect_equal(connector.video_packet_size, 512, "legacy video packet size")
    expect_equal(connector.control_dialect, "osc15", "legacy control dialect")
    expect_equal(connector.source_name, "legacy-test", "legacy source name")


def test_lola_connector_rejects_duplicate_settings() -> None:
    settings = MediaSettings(width=16, height=8)

    with pytest.raises(TypeError, match="multiple values for settings"):
        LolaConnector("127.0.0.1", settings, settings=settings)


def test_lola_connector_rejects_invalid_options_keyword() -> None:
    with pytest.raises(TypeError, match="options must be LolaConnectorOptions"):
        LolaConnector("127.0.0.1", options=object())


def test_osc15_quickconn_ack_bayer_is_interpreted_as_local_mirror() -> None:
    local = MediaSettings(width=1280, height=720, bayer=1)
    connector = LolaConnector("10.0.0.1", local, control_dialect="osc15")
    datagram = build_osc15_control_datagram(
        MESG_QUICKCONN_ACK,
        "10.0.0.2",
        "10.0.0.1",
        7,
        MediaSettings(width=1280, height=720, bayer=0),
    )
    parsed = parse_control_datagram(datagram)

    parsed = expect_not_none(parsed, "OSC15 quickconn ack parse")
    expect_equal(parsed.media.sample_rate, 44100, "OSC15 sample rate")
    expect_equal(connector.settings_from_quickconn_ack(parsed).bayer, 1, "OSC15 local bayer mirror")


@pytest.mark.parametrize(("sample_rate", "fps"), [(44100.5, 25.0), (44100.0, 29.97)])
def test_osc15_quickconn_rejects_fractional_media_doubles(sample_rate: float, fps: float) -> None:
    datagram = build_osc15_quickconn_ack_datagram(sample_rate=sample_rate, fps=fps)

    expect_is_none(parse_control_datagram(datagram), "fractional OSC15 quickconn parse")


def test_osc15_control_paths_do_not_default_to_hostname() -> None:
    connector = LolaConnector("10.0.0.1", control_dialect="osc15")
    datagram = build_osc15_control_datagram(
        MESG_CHECKLOLASTATUS_ACK,
        connector.local_ip,
        "10.0.0.2",
        source_name=connector.source_name,
    )
    parsed = parse_control_datagram(datagram)

    expect_equal(connector.source_name, "", "OSC15 default source name")
    parsed = expect_not_none(parsed, "OSC15 status ack parse")
    expect_equal(parsed.src_ip, connector.local_ip, "OSC15 status source IP")


def test_control_parser_rejects_non_ascii_datagram() -> None:
    expect_is_none(
        parse_control_datagram(b"/MESG_CHAT;TXT:\xff\0"),
        "non-ascii control datagram parse",
    )


def test_control_parser_rejects_oversized_datagram() -> None:
    expect_is_none(
        parse_control_datagram(b"/MESG_CHAT;" + b"x" * CONTROL_DATAGRAM_SIZE),
        "oversized control datagram parse",
    )


def test_serialized_media_rejects_trailing_bytes() -> None:
    with pytest.raises(ValueError, match="payload length mismatch"):
        parse_serialized_media(struct.pack("<II", 1, 3) + b"abcx")


def test_control_parser_rejects_non_mesg_and_unknown_kinds() -> None:
    expect_is_none(parse_control_datagram(b"HELLO;SRCIP:10.0.0.1\0"), "non-MESG control parse")
    expect_is_none(
        parse_control_datagram(b"/OTHER_CHAT;SRCIP:10.0.0.1\0"),
        "other-prefixed control parse",
    )
    expect_is_none(
        parse_control_datagram(b"/MESG_UNKNOWN;SRCIP:10.0.0.1\0"),
        "unknown control kind parse",
    )


def test_general_control_handler_ignores_status_ack_action() -> None:
    connector = LolaConnector("127.0.0.1", MediaSettings())
    message = ControlMessage(
        kind=MESG_CHECKLOLASTATUS_ACK,
        fields={"SRCIP": "127.0.0.2", "SID": "1"},
        text="/MESG_CHECKLOLASTATUS_ACK;SRCIP:127.0.0.2;SID:1",
    )

    expect_equal(
        connector.handle_control_message(message, sender_ip="127.0.0.2"),
        "ignore",
        "status ack action",
    )


@pytest.mark.parametrize("kind", [MESG_SEND_AUDIO_SIGNAL, MESG_STOP_AUDIO_SIGNAL, MESG_DISCONNECT])
def test_control_handler_ignores_state_changes_from_non_session_sender(kind: str) -> None:
    connector = LolaConnector("127.0.0.1", MediaSettings())
    connector.session = Session("127.0.0.1", "127.0.0.2", 42, MediaSettings())
    message = ControlMessage(
        kind=kind,
        fields={"SRCIP": "127.0.0.3", "SID": "42"},
        text=f"/{kind};SRCIP:127.0.0.3;SID:42",
    )

    expect_equal(
        connector.handle_control_message(message, sender_ip="127.0.0.3"),
        "ignore",
        "wrong-sender action",
    )
    expect_not_none(connector.session, "wrong-sender session")


@pytest.mark.parametrize("kind", [MESG_SEND_AUDIO_SIGNAL, MESG_STOP_AUDIO_SIGNAL, MESG_DISCONNECT])
def test_control_handler_ignores_state_changes_from_wrong_session_id(kind: str) -> None:
    connector = LolaConnector("127.0.0.1", MediaSettings())
    connector.session = Session("127.0.0.1", "127.0.0.2", 42, MediaSettings())
    message = ControlMessage(
        kind=kind,
        fields={"SRCIP": "127.0.0.2", "SID": "7"},
        text=f"/{kind};SRCIP:127.0.0.2;SID:7",
    )

    expect_equal(
        connector.handle_control_message(message, sender_ip="127.0.0.2"),
        "ignore",
        "wrong-session action",
    )
    expect_not_none(connector.session, "wrong-session session")


def test_control_handler_accepts_state_changes_from_active_session() -> None:
    connector = LolaConnector("127.0.0.1", MediaSettings())
    connector.session = Session("127.0.0.1", "127.0.0.2", 42, MediaSettings())
    send_audio = ControlMessage(
        kind=MESG_SEND_AUDIO_SIGNAL,
        fields={"SRCIP": "127.0.0.2", "SID": "42"},
        text="/MESG_SEND_AUDIO_SIGNAL;SRCIP:127.0.0.2;SID:42",
    )
    disconnect = ControlMessage(
        kind=MESG_DISCONNECT,
        fields={"SRCIP": "127.0.0.2", "SID": "42"},
        text="/MESG_DISCONNECT;SRCIP:127.0.0.2;SID:42",
    )

    expect_equal(
        connector.handle_control_message(send_audio, sender_ip="127.0.0.2"),
        "send_audio_signal",
        "active session send-audio action",
    )
    expect_not_none(connector.session, "active session before disconnect")
    expect_equal(
        connector.handle_control_message(disconnect, sender_ip="127.0.0.2"),
        "disconnect",
        "active session disconnect action",
    )
    expect_is_none(connector.session, "active session after disconnect")


def test_default_selftest_ports_stay_outside_ephemeral_range() -> None:
    expect_less_than(
        DEFAULT_VIDEO_PORT + default_port_offset(),
        49152,
        "default selftest video port",
    )


def test_pcap_decoder_dependency_is_documented_optional_extra() -> None:
    pyproject = tomllib.loads(Path("pyproject.toml").read_text(encoding="utf-8"))
    pcap_dependencies = pyproject["project"]["optional-dependencies"]["pcap"]
    tools_readme = Path("linux_connector/tools/README.md").read_text(encoding="utf-8")

    expect_equal(pcap_dependencies, ["scapy>=2.6,<3"], "pcap optional dependency")
    expect_contains("open-lola2-linux-connector[pcap]", tools_readme, "tools README pcap extra")


def test_all_recovered_control_kinds_round_trip() -> None:
    for kind in CONTROL_MESSAGE_KINDS:
        datagram = build_control_datagram(kind, "10.0.0.1", "10.0.0.2", 1, txt="hello")
        parsed = expect_not_none(parse_control_datagram(datagram), f"{kind} control parse")
        expect_equal(parsed.kind, kind, f"{kind} control kind")
        expect_equal(parsed.src_ip, "10.0.0.1", f"{kind} source IP")
        expect_equal(parsed.dst_ip, "10.0.0.2", f"{kind} destination IP")
        if kind == MESG_CHAT:
            expect_equal(parsed.txt, "hello", "chat text")


@pytest.mark.parametrize("kind", [MESG_CHAT, MESG_REJECT])
def test_control_txt_builder_escapes_field_delimiters(kind: str) -> None:
    datagram = build_control_datagram(
        kind, "10.0.0.1", "10.0.0.2", 1, txt="legit;SRCIP:attacker.com 100%"
    )
    parsed = parse_control_datagram(datagram)

    parsed = expect_not_none(parsed, "escaped text control parse")
    expect_equal(parsed.src_ip, "10.0.0.1", "escaped text source IP")
    expect_equal(parsed.raw_txt, "legit%3BSRCIP%3Aattacker.com 100%25", "escaped raw text")
    expect_equal(parsed.txt, "legit;SRCIP:attacker.com 100%", "escaped decoded text")


def test_control_txt_parser_decodes_one_escape_layer_only() -> None:
    datagram = build_control_datagram(
        MESG_CHAT, "10.0.0.1", "10.0.0.2", 1, txt="show %3B literally"
    )
    parsed = parse_control_datagram(datagram)

    parsed = expect_not_none(parsed, "single-layer escaped text parse")
    expect_equal(parsed.raw_txt, "show %253B literally", "single-layer raw text")
    expect_equal(parsed.txt, "show %3B literally", "single-layer decoded text")


def test_ascii_control_parser_rejects_fields_after_txt() -> None:
    datagram = b"/MESG_CHAT;SRCIP:10.0.0.1;TXT:hello;DSTIP:10.0.0.2\0"

    expect_is_none(parse_control_datagram(datagram), "fields after TXT parse")


def test_ascii_quickconn_rejects_duplicate_media_fields() -> None:
    datagram = (
        b"/MESG_QUICKCONN;SRCIP:10.0.0.1;DSTIP:10.0.0.2;SID:1;"
        b"SR:44100;SR:48000;BPS:16;CHNLS:2;FPS:25;BPP:8;X:640;Y:480;COMP:0;BAYER:0"
    ).ljust(CONTROL_DATAGRAM_SIZE, b"\0")

    expect_is_none(parse_control_datagram(datagram), "duplicate media field parse")


def test_ascii_quickconn_rejects_missing_required_media_fields() -> None:
    datagram = (
        b"/MESG_QUICKCONN_ACK;SRCIP:10.0.0.2;DSTIP:10.0.0.1;SID:1;"
        b"SR:44100;BPS:16;CHNLS:2;FPS:25;BPP:8;X:640;Y:480;COMP:0"
    ).ljust(CONTROL_DATAGRAM_SIZE, b"\0")

    expect_is_none(parse_control_datagram(datagram), "missing required media fields parse")


def test_audio_payload_round_trip() -> None:
    pcm = bytes(range(expected_audio_payload_size(channels=1)))
    fragment = expect_instance(
        parse_media_payload(build_audio_payload(7, pcm)),
        Fragment,
        "audio media fragment",
    )
    reasm = MediaReassembler()
    serialized = expect_not_none(reasm.add(fragment), "serialized audio media")
    sequence, payload = parse_serialized_media(serialized)
    expect_equal(sequence, 7, "audio media sequence")
    expect_equal(payload, pcm, "audio media payload")


def test_video_payload_round_trip() -> None:
    frame = bytes([x % 251 for x in range(5000)])
    packets = build_video_payloads(9, frame, packet_size=1000)
    prelude = expect_instance(parse_media_payload(packets[0]), VideoPrelude, "video prelude")
    reasm = MediaReassembler()
    reasm.begin(prelude.frame_id, prelude.expected_size, prelude.fragment_count)
    assembled = None
    for packet in packets[1:]:
        fragment = expect_instance(parse_media_payload(packet), Fragment, "video fragment")
        assembled = reasm.add(fragment) or assembled
    assembled = expect_not_none(assembled, "assembled video media")
    sequence, payload = parse_serialized_media(assembled)
    expect_equal(sequence, 9, "video media sequence")
    expect_equal(payload, frame, "video media payload")


def test_media_reassembler_rejects_oversized_video_prelude() -> None:
    reasm = MediaReassembler()

    with pytest.raises(ValueError, match="frame size"):
        reasm.begin(1, MAX_MEDIA_FRAME_SIZE + 1, 1)


def test_media_reassembler_rejects_excessive_fragment_count() -> None:
    reasm = MediaReassembler()

    with pytest.raises(ValueError, match="fragment count"):
        reasm.begin(1, 8, MAX_MEDIA_FRAGMENT_COUNT + 1)


def test_media_reassembler_rejects_zero_size_multifragment_auto_begin() -> None:
    reasm = MediaReassembler()
    fragment = Fragment(1, 2, 0, 0, 4, 0, b"abcd")

    with pytest.raises(ValueError, match="frame size"):
        reasm.add(fragment)


def test_media_reassembler_rejects_sparse_fragment_beyond_frame_size() -> None:
    reasm = MediaReassembler()
    reasm.begin(1, 8, 1)
    fragment = Fragment(1, 1, 0, 7, 2, 1, b"xx")

    with pytest.raises(ValueError, match="fragment exceeds"):
        reasm.add(fragment)


def test_media_reassembler_rejects_overlapping_fragment_offsets() -> None:
    reasm = MediaReassembler()
    reasm.begin(1, 8, 2)

    expect_is_none(reasm.add(Fragment(1, 2, 0, 0, 4, 0, b"abcd")), "overlap setup fragment")
    with pytest.raises(ValueError, match="overlaps"):
        reasm.add(Fragment(1, 2, 1, 2, 6, 1, b"cdefgh"))


def test_media_reassembler_rejects_missing_middle_range() -> None:
    reasm = MediaReassembler()
    reasm.begin(1, 8, 2)

    expect_is_none(reasm.add(Fragment(1, 2, 0, 0, 2, 0, b"ab")), "gap setup fragment")
    with pytest.raises(ValueError, match="fragment gap"):
        reasm.add(Fragment(1, 2, 1, 4, 4, 1, b"efgh"))


def test_media_reassembler_accepts_exact_contiguous_coverage() -> None:
    reasm = MediaReassembler()
    reasm.begin(1, 8, 2)

    expect_is_none(reasm.add(Fragment(1, 2, 1, 4, 4, 1, b"efgh")), "contiguous second fragment")
    expect_equal(
        reasm.add(Fragment(1, 2, 0, 0, 4, 0, b"abcd")),
        b"abcdefgh",
        "contiguous reassembly",
    )


def test_media_reassembler_ignores_out_of_range_fragment(caplog: LogCaptureFixture) -> None:
    reasm = MediaReassembler()
    reasm.begin(1, 8, 1)
    fragment = Fragment(1, 1, 1, 0, 2, 1, b"xx")

    expect_is_none(reasm.add(fragment), "out-of-range fragment")
    expect_contains("out of range", caplog.text, "out-of-range fragment log")


def test_media_reassembler_ignores_duplicate_fragment() -> None:
    reasm = MediaReassembler()
    reasm.begin(1, 16, 2)
    fragment = Fragment(1, 2, 0, 0, 8, 1, b"abcdefgh")

    expect_is_none(reasm.add(fragment), "first duplicate fragment")
    expect_is_none(reasm.add(fragment), "second duplicate fragment")
    expect_equal(len(reasm.parts), 1, "duplicate fragment part count")


def test_raw_outer_packet_layout() -> None:
    payload = build_audio_payload(1, bytes(range(128)))
    packet = build_ipv4_udp_packet("10.0.0.1", "10.0.0.2", 19788, 19788, payload)
    expect_equal(packet[0], 0x45, "IPv4 version/header byte")
    expect_equal(packet[8], 0x80, "IPv4 TTL")
    expect_equal(packet[9], 0x11, "IPv4 UDP protocol")
    expect_equal(packet[20:22], (19788).to_bytes(2, "big"), "UDP source port")
    expect_equal(packet[22:24], (19788).to_bytes(2, "big"), "UDP destination port")
    expect_equal(packet[28:], payload, "UDP payload")

    frame = build_ethernet_ipv4_udp_frame(
        "02:00:00:00:00:01",
        "02:00:00:00:00:02",
        "10.0.0.1",
        "10.0.0.2",
        19798,
        19798,
        payload,
    )
    expect_equal(frame[:6], parse_mac("02:00:00:00:00:02"), "ethernet destination MAC")
    expect_equal(frame[6:12], parse_mac("02:00:00:00:00:01"), "ethernet source MAC")
    expect_equal(frame[12:14], b"\x08\x00", "ethernet IPv4 type")
    expect_equal(frame[14], 0x45, "ethernet IPv4 header byte")


def test_raw_outer_packet_builder_rejects_invalid_addresses_and_ports() -> None:
    payload = b"payload"

    with pytest.raises(ValueError, match="src_port"):
        build_ipv4_udp_packet("10.0.0.1", "10.0.0.2", 0, 19788, payload)
    with pytest.raises(ValueError, match="dst_port"):
        build_ipv4_udp_packet("10.0.0.1", "10.0.0.2", 19788, 65536, payload)
    with pytest.raises(ValueError):
        build_ipv4_udp_packet("not-an-ip", "10.0.0.2", 19788, 19788, payload)


def test_raw_outer_packet_builder_rejects_payloads_above_ipv4_udp_ceiling() -> None:
    payload = bytes(65_507)
    packet = build_ipv4_udp_packet("10.0.0.1", "10.0.0.2", 19788, 19788, payload)

    expect_equal(int.from_bytes(packet[2:4], "big"), 65_535, "IPv4 total length")
    expect_equal(int.from_bytes(packet[24:26], "big"), 65_515, "UDP total length")
    expect_equal(packet[28:], payload, "maximum UDP payload")

    with pytest.raises(ValueError, match="UDP payload must be at most 65507 bytes"):
        build_ipv4_udp_packet("10.0.0.1", "10.0.0.2", 19788, 19788, bytes(65_508))


def build_osc15_quickconn_ack_datagram(sample_rate: float, fps: float) -> bytes:
    args: list[tuple[str, str | int | float]] = [
        ("s", "10.0.0.2"),
        ("d", sample_rate),
        ("i", 16),
        ("i", 2),
        ("s", ""),
        ("d", fps),
        ("i", 8),
        ("i", 640),
        ("i", 480),
        ("i", 0),
    ]
    message = osc_string("/MESG_QUICKCONN_ACK") + osc_string(",sdiisdiiii")
    for tag, value in args:
        if tag == "s":
            message += osc_string(str(value))
        elif tag == "i":
            message += struct.pack(">i", int(value))
        elif tag == "d":
            message += struct.pack(">d", float(value))
    return (b"#bundle\0" + struct.pack(">q", 1) + struct.pack(">i", len(message)) + message).ljust(
        CONTROL_DATAGRAM_SIZE,
        b"\0",
    )


def osc_string(value: str) -> bytes:
    raw = value.encode("ascii") + b"\0"
    return raw.ljust((len(raw) + 3) & ~3, b"\0")
