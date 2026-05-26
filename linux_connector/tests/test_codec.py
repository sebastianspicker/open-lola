from __future__ import annotations

import errno
import logging
import socket
import struct
import tomllib
from pathlib import Path

import pytest
from pytest import LogCaptureFixture

import linux_connector.lola_connector.connector as connector_module
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
from linux_connector.lola_connector.connector import LolaConnector, Session
from linux_connector.lola_connector.ethernet import build_ethernet_ipv4_udp_frame, build_ipv4_udp_packet, parse_mac
from linux_connector.lola_connector.backends import (
    DiagnosticVideoCapture,
    MemoryAudioPlayback,
    MultiToneAudioCapture,
    PatternVideoCapture,
    SilenceAudioCapture,
    SineAudioCapture,
)
from linux_connector.lola_connector.runtime import LolaLinuxRuntime
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


def test_control_quickconn_round_trip() -> None:
    settings = MediaSettings(width=1280, height=720, compression=1)
    datagram = build_control_datagram(MESG_QUICKCONN, "10.0.0.1", "10.0.0.2", 1, settings)
    assert len(datagram) == CONTROL_DATAGRAM_SIZE
    parsed = parse_control_datagram(datagram)
    assert parsed is not None
    assert parsed.kind == "MESG_QUICKCONN"
    assert parsed.src_ip == "10.0.0.1"
    assert parsed.dst_ip == "10.0.0.2"
    assert parsed.sid == 1
    assert parsed.media.width == 1280
    assert parsed.media.height == 720
    assert parsed.media.compression == 1


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

    assert parsed is not None
    assert parsed.media.sample_rate == 44100
    assert connector.settings_from_quickconn_ack(parsed).bayer == 1


@pytest.mark.parametrize(("sample_rate", "fps"), [(44100.5, 25.0), (44100.0, 29.97)])
def test_osc15_quickconn_rejects_fractional_media_doubles(sample_rate: float, fps: float) -> None:
    datagram = build_osc15_quickconn_ack_datagram(sample_rate=sample_rate, fps=fps)

    assert parse_control_datagram(datagram) is None


def test_osc15_control_paths_do_not_default_to_hostname() -> None:
    connector = LolaConnector("10.0.0.1", control_dialect="osc15")
    datagram = build_osc15_control_datagram(
        MESG_CHECKLOLASTATUS_ACK,
        connector.local_ip,
        "10.0.0.2",
        source_name=connector.source_name,
    )
    parsed = parse_control_datagram(datagram)

    assert connector.source_name == ""
    assert parsed is not None
    assert parsed.src_ip == connector.local_ip


def test_control_parser_rejects_non_ascii_datagram() -> None:
    assert parse_control_datagram(b"/MESG_CHAT;TXT:\xff\0") is None


def test_control_parser_rejects_oversized_datagram() -> None:
    assert parse_control_datagram(b"/MESG_CHAT;" + b"x" * CONTROL_DATAGRAM_SIZE) is None


def test_control_parser_rejects_non_mesg_and_unknown_kinds() -> None:
    assert parse_control_datagram(b"HELLO;SRCIP:10.0.0.1\0") is None
    assert parse_control_datagram(b"/OTHER_CHAT;SRCIP:10.0.0.1\0") is None
    assert parse_control_datagram(b"/MESG_UNKNOWN;SRCIP:10.0.0.1\0") is None


def test_general_control_handler_ignores_status_ack_action() -> None:
    connector = LolaConnector("127.0.0.1", MediaSettings())
    message = ControlMessage(
        kind=MESG_CHECKLOLASTATUS_ACK,
        fields={"SRCIP": "127.0.0.2", "SID": "1"},
        text="/MESG_CHECKLOLASTATUS_ACK;SRCIP:127.0.0.2;SID:1",
    )

    assert connector.handle_control_message(message, sender_ip="127.0.0.2") == "ignore"


@pytest.mark.parametrize("kind", [MESG_SEND_AUDIO_SIGNAL, MESG_STOP_AUDIO_SIGNAL, MESG_DISCONNECT])
def test_control_handler_ignores_state_changes_from_non_session_sender(kind: str) -> None:
    connector = LolaConnector("127.0.0.1", MediaSettings())
    connector.session = Session("127.0.0.1", "127.0.0.2", 42, MediaSettings())
    message = ControlMessage(
        kind=kind,
        fields={"SRCIP": "127.0.0.3", "SID": "42"},
        text=f"/{kind};SRCIP:127.0.0.3;SID:42",
    )

    assert connector.handle_control_message(message, sender_ip="127.0.0.3") == "ignore"
    assert connector.session is not None


@pytest.mark.parametrize("kind", [MESG_SEND_AUDIO_SIGNAL, MESG_STOP_AUDIO_SIGNAL, MESG_DISCONNECT])
def test_control_handler_ignores_state_changes_from_wrong_session_id(kind: str) -> None:
    connector = LolaConnector("127.0.0.1", MediaSettings())
    connector.session = Session("127.0.0.1", "127.0.0.2", 42, MediaSettings())
    message = ControlMessage(
        kind=kind,
        fields={"SRCIP": "127.0.0.2", "SID": "7"},
        text=f"/{kind};SRCIP:127.0.0.2;SID:7",
    )

    assert connector.handle_control_message(message, sender_ip="127.0.0.2") == "ignore"
    assert connector.session is not None


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

    assert connector.handle_control_message(send_audio, sender_ip="127.0.0.2") == "send_audio_signal"
    assert connector.session is not None
    assert connector.handle_control_message(disconnect, sender_ip="127.0.0.2") == "disconnect"
    assert connector.session is None


def test_default_selftest_ports_stay_outside_ephemeral_range() -> None:
    assert DEFAULT_VIDEO_PORT + default_port_offset() < 49152


def test_pcap_decoder_dependency_is_documented_optional_extra() -> None:
    pyproject = tomllib.loads(Path("pyproject.toml").read_text(encoding="utf-8"))
    pcap_dependencies = pyproject["project"]["optional-dependencies"]["pcap"]
    tools_readme = Path("linux_connector/tools/README.md").read_text(encoding="utf-8")

    assert pcap_dependencies == ["scapy>=2.6,<3"]
    assert "open-lola2-linux-connector[pcap]" in tools_readme


def test_all_recovered_control_kinds_round_trip() -> None:
    for kind in CONTROL_MESSAGE_KINDS:
        datagram = build_control_datagram(kind, "10.0.0.1", "10.0.0.2", 1, txt="hello")
        parsed = parse_control_datagram(datagram)
        assert parsed is not None
        assert parsed.kind == kind
        assert parsed.src_ip == "10.0.0.1"
        assert parsed.dst_ip == "10.0.0.2"
        if kind == MESG_CHAT:
            assert parsed.txt == "hello"


@pytest.mark.parametrize("kind", [MESG_CHAT, MESG_REJECT])
def test_control_txt_builder_escapes_field_delimiters(kind: str) -> None:
    datagram = build_control_datagram(kind, "10.0.0.1", "10.0.0.2", 1, txt="legit;SRCIP:attacker.com 100%")
    parsed = parse_control_datagram(datagram)

    assert parsed is not None
    assert parsed.src_ip == "10.0.0.1"
    assert parsed.raw_txt == "legit%3BSRCIP%3Aattacker.com 100%25"
    assert parsed.txt == "legit;SRCIP:attacker.com 100%"


def test_control_txt_parser_decodes_one_escape_layer_only() -> None:
    datagram = build_control_datagram(MESG_CHAT, "10.0.0.1", "10.0.0.2", 1, txt="show %3B literally")
    parsed = parse_control_datagram(datagram)

    assert parsed is not None
    assert parsed.raw_txt == "show %253B literally"
    assert parsed.txt == "show %3B literally"


def test_ascii_control_parser_rejects_fields_after_txt() -> None:
    datagram = b"/MESG_CHAT;SRCIP:10.0.0.1;TXT:hello;DSTIP:10.0.0.2\0"

    assert parse_control_datagram(datagram) is None


def test_ascii_quickconn_rejects_duplicate_media_fields() -> None:
    datagram = (
        b"/MESG_QUICKCONN;SRCIP:10.0.0.1;DSTIP:10.0.0.2;SID:1;"
        b"SR:44100;SR:48000;BPS:16;CHNLS:2;FPS:25;BPP:8;X:640;Y:480;COMP:0;BAYER:0"
    ).ljust(CONTROL_DATAGRAM_SIZE, b"\0")

    assert parse_control_datagram(datagram) is None


def test_ascii_quickconn_rejects_missing_required_media_fields() -> None:
    datagram = (
        b"/MESG_QUICKCONN_ACK;SRCIP:10.0.0.2;DSTIP:10.0.0.1;SID:1;"
        b"SR:44100;BPS:16;CHNLS:2;FPS:25;BPP:8;X:640;Y:480;COMP:0"
    ).ljust(CONTROL_DATAGRAM_SIZE, b"\0")

    assert parse_control_datagram(datagram) is None


def test_audio_payload_round_trip() -> None:
    pcm = bytes(range(expected_audio_payload_size(channels=1)))
    fragment = parse_media_payload(build_audio_payload(7, pcm))
    assert isinstance(fragment, Fragment)
    reasm = MediaReassembler()
    serialized = reasm.add(fragment)
    assert serialized is not None
    sequence, payload = parse_serialized_media(serialized)
    assert sequence == 7
    assert payload == pcm


def test_video_payload_round_trip() -> None:
    frame = bytes([x % 251 for x in range(5000)])
    packets = build_video_payloads(9, frame, packet_size=1000)
    prelude = parse_media_payload(packets[0])
    assert isinstance(prelude, VideoPrelude)
    reasm = MediaReassembler()
    reasm.begin(prelude.frame_id, prelude.expected_size, prelude.fragment_count)
    assembled = None
    for packet in packets[1:]:
        fragment = parse_media_payload(packet)
        assert isinstance(fragment, Fragment)
        assembled = reasm.add(fragment) or assembled
    assert assembled is not None
    sequence, payload = parse_serialized_media(assembled)
    assert sequence == 9
    assert payload == frame


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

    assert reasm.add(Fragment(1, 2, 0, 0, 4, 0, b"abcd")) is None
    with pytest.raises(ValueError, match="overlaps"):
        reasm.add(Fragment(1, 2, 1, 2, 6, 1, b"cdefgh"))


def test_media_reassembler_rejects_missing_middle_range() -> None:
    reasm = MediaReassembler()
    reasm.begin(1, 8, 2)

    assert reasm.add(Fragment(1, 2, 0, 0, 2, 0, b"ab")) is None
    with pytest.raises(ValueError, match="fragment gap"):
        reasm.add(Fragment(1, 2, 1, 4, 4, 1, b"efgh"))


def test_media_reassembler_accepts_exact_contiguous_coverage() -> None:
    reasm = MediaReassembler()
    reasm.begin(1, 8, 2)

    assert reasm.add(Fragment(1, 2, 1, 4, 4, 1, b"efgh")) is None
    assert reasm.add(Fragment(1, 2, 0, 0, 4, 0, b"abcd")) == b"abcdefgh"


def test_media_reassembler_ignores_out_of_range_fragment(caplog: LogCaptureFixture) -> None:
    reasm = MediaReassembler()
    reasm.begin(1, 8, 1)
    fragment = Fragment(1, 1, 1, 0, 2, 1, b"xx")

    assert reasm.add(fragment) is None
    assert "out of range" in caplog.text


def test_media_reassembler_ignores_duplicate_fragment() -> None:
    reasm = MediaReassembler()
    reasm.begin(1, 16, 2)
    fragment = Fragment(1, 2, 0, 0, 8, 1, b"abcdefgh")

    assert reasm.add(fragment) is None
    assert reasm.add(fragment) is None
    assert len(reasm.parts) == 1


def test_raw_outer_packet_layout() -> None:
    payload = build_audio_payload(1, bytes(range(128)))
    packet = build_ipv4_udp_packet("10.0.0.1", "10.0.0.2", 19788, 19788, payload)
    assert packet[0] == 0x45
    assert packet[8] == 0x80
    assert packet[9] == 0x11
    assert packet[20:22] == (19788).to_bytes(2, "big")
    assert packet[22:24] == (19788).to_bytes(2, "big")
    assert packet[28:] == payload

    frame = build_ethernet_ipv4_udp_frame(
        "02:00:00:00:00:01",
        "02:00:00:00:00:02",
        "10.0.0.1",
        "10.0.0.2",
        19798,
        19798,
        payload,
    )
    assert frame[:6] == parse_mac("02:00:00:00:00:02")
    assert frame[6:12] == parse_mac("02:00:00:00:00:01")
    assert frame[12:14] == b"\x08\x00"
    assert frame[14] == 0x45


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

    assert int.from_bytes(packet[2:4], "big") == 65_535
    assert int.from_bytes(packet[24:26], "big") == 65_515
    assert packet[28:] == payload

    with pytest.raises(ValueError, match="UDP payload must be at most 65507 bytes"):
        build_ipv4_udp_packet("10.0.0.1", "10.0.0.2", 19788, 19788, bytes(65_508))


async def _exercise_test_backends() -> None:
    settings = MediaSettings(width=16, height=8)
    silence = SilenceAudioCapture(settings)
    assert len(await silence.read_block()) == expected_audio_payload_size(settings.channels)
    sine = SineAudioCapture(settings)
    assert len(await sine.read_block()) == expected_audio_payload_size(settings.channels)
    video = PatternVideoCapture(settings)
    assert len(await video.read_frame()) == settings.width * settings.height
    tones = MultiToneAudioCapture(settings)
    tone_block = await tones.read_block()
    assert len(tone_block) == expected_audio_payload_size(settings.channels)
    diagnostic = DiagnosticVideoCapture(settings)
    diagnostic_frame_a = await diagnostic.read_frame()
    diagnostic_frame_b = await diagnostic.read_frame()
    assert len(diagnostic_frame_a) == settings.width * settings.height
    assert diagnostic_frame_a != diagnostic_frame_b


async def _exercise_rgb_diagnostic_video() -> None:
    settings = MediaSettings(width=16, height=8, bits_per_pixel=24)
    video = DiagnosticVideoCapture(settings)
    frame = await video.read_frame()
    assert len(frame) == settings.width * settings.height * 3


def test_test_backends_emit_lola_sized_media() -> None:
    import asyncio

    asyncio.run(_exercise_test_backends())
    asyncio.run(_exercise_rgb_diagnostic_video())


def test_multi_tone_capture_documents_single_event_loop_phase_state() -> None:
    from dataclasses import fields

    phase_field = next(field for field in fields(MultiToneAudioCapture) if field.name == "phases")
    assert phase_field.metadata["concurrency"] == "single-event-loop"


def test_runtime_accepts_backend_contracts() -> None:
    import asyncio

    class FakeConnector(LolaConnector):
        def __init__(self) -> None:
            settings = MediaSettings(width=16, height=8)
            super().__init__("127.0.0.1", settings, audio_port=19788, video_port=19798)
            self.session = Session("127.0.0.1", "127.0.0.2", 1, settings)
            self.audio_sent = 0
            self.video_sent = 0

        async def send_audio_on_socket(self, sock: socket.socket, pcm: bytes, sequence: int) -> None:
            _ = sock
            _ = pcm
            _ = sequence
            self.audio_sent += 1

        async def send_video_on_socket(self, sock: socket.socket, frame: bytes, sequence: int) -> None:
            _ = sock
            _ = frame
            _ = sequence
            self.video_sent += 1

        def make_udp_socket(self, bind_port: int = 0) -> socket.socket:
            _ = bind_port
            return socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    settings = MediaSettings(width=16, height=8)
    fake = FakeConnector()
    runtime = LolaLinuxRuntime(
        fake,
        SilenceAudioCapture(settings),
        MemoryAudioPlayback(),
        video_capture=PatternVideoCapture(settings),
        video_display=None,
    )
    stats = asyncio.run(runtime.run_for(0.06, receive=False, transmit_audio=True, transmit_video=True, control=False))
    assert stats.audio_tx > 0
    assert stats.video_tx > 0
    assert fake.audio_sent == stats.audio_tx
    assert fake.video_sent == stats.video_tx


def test_runtime_keeps_tx_disabled_until_requested() -> None:
    import asyncio

    class FakeConnector(LolaConnector):
        def __init__(self) -> None:
            settings = MediaSettings(width=16, height=8)
            super().__init__("127.0.0.1", settings, audio_port=19788, video_port=19798)
            self.session = Session("127.0.0.1", "127.0.0.2", 1, settings)
            self.audio_sent = 0
            self.video_sent = 0

        async def send_audio_on_socket(self, sock: socket.socket, pcm: bytes, sequence: int) -> None:
            _ = sock
            _ = pcm
            _ = sequence
            self.audio_sent += 1

        async def send_video_on_socket(self, sock: socket.socket, frame: bytes, sequence: int) -> None:
            _ = sock
            _ = frame
            _ = sequence
            self.video_sent += 1

        def make_udp_socket(self, bind_port: int = 0) -> socket.socket:
            _ = bind_port
            return socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    settings = MediaSettings(width=16, height=8)
    fake = FakeConnector()
    runtime = LolaLinuxRuntime(
        fake,
        SilenceAudioCapture(settings),
        MemoryAudioPlayback(),
        video_capture=PatternVideoCapture(settings),
        video_display=None,
    )
    stats = asyncio.run(runtime.run_for(0.03, receive=False, transmit_audio=False, transmit_video=False, control=False))
    assert stats.audio_tx == 0
    assert stats.video_tx == 0
    assert fake.audio_sent == 0
    assert fake.video_sent == 0


def test_connector_reuses_media_send_sockets() -> None:
    import asyncio

    class CountingConnector(LolaConnector):
        def __init__(self, audio_port: int, video_port: int):
            super().__init__("127.0.0.1", MediaSettings(width=4, height=4), audio_port=audio_port, video_port=video_port)
            self.opened_ports: list[int] = []

        def make_udp_socket(self, bind_port: int = 0) -> socket.socket:
            self.opened_ports.append(bind_port)
            return super().make_udp_socket(bind_port)

    async def run() -> None:
        audio_probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        video_probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
            audio_probe.bind(("127.0.0.1", 0))
            video_probe.bind(("127.0.0.1", 0))
            audio_port = audio_probe.getsockname()[1]
            video_port = video_probe.getsockname()[1]
        finally:
            audio_probe.close()
            video_probe.close()
        connector = CountingConnector(audio_port, video_port)
        connector.session = Session("127.0.0.1", "127.0.0.1", 1, MediaSettings(width=4, height=4))
        await connector.send_audio(b"\0" * expected_audio_payload_size(channels=2), sequence=1)
        await connector.send_audio(b"\0" * expected_audio_payload_size(channels=2), sequence=2)
        await connector.send_video(b"\0" * 16, sequence=1)
        await connector.send_video(b"\0" * 16, sequence=2)
        connector.close_media_sockets()
        assert connector.opened_ports.count(connector.audio_port) == 1
        assert connector.opened_ports.count(connector.video_port) == 1

    asyncio.run(run())


def test_connector_logs_and_closes_failed_udp_socket_setup(
    monkeypatch: pytest.MonkeyPatch,
    caplog: LogCaptureFixture,
) -> None:
    class BindFailingSocket:
        def __init__(self) -> None:
            self.closed = False

        def setsockopt(self, *_args: int) -> None:
            return None

        def setblocking(self, _flag: bool) -> None:
            return None

        def bind(self, _address: tuple[str, int]) -> None:
            raise OSError(errno.EADDRINUSE, "address already in use")

        def close(self) -> None:
            self.closed = True

    opened = BindFailingSocket()

    def make_socket(_family: int, _kind: int) -> BindFailingSocket:
        return opened

    monkeypatch.setattr(connector_module.socket, "socket", make_socket)
    caplog.set_level(logging.WARNING, logger="linux_connector.lola_connector.connector")

    connector = LolaConnector("127.0.0.1", MediaSettings())
    with pytest.raises(OSError):
        connector.make_udp_socket(19788)

    assert opened.closed
    assert "UDP socket setup failed for 127.0.0.1:19788" in caplog.text
    assert f"errno={errno.EADDRINUSE}" in caplog.text


def build_osc15_quickconn_ack_datagram(sample_rate: float, fps: float) -> bytes:
    args: list[tuple[str, object]] = [
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
