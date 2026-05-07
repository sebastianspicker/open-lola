from linux_connector.lola_connector.media import (
    Fragment,
    MediaReassembler,
    VideoPrelude,
    build_audio_payload,
    build_video_payloads,
    expected_audio_payload_size,
    parse_media_payload,
    parse_serialized_media,
)
from linux_connector.lola_connector.ethernet import build_ethernet_ipv4_udp_frame, build_ipv4_udp_packet, parse_mac
from linux_connector.lola_connector.backends import (
    DiagnosticVideoCapture,
    MemoryAudioPlayback,
    MultiToneAudioCapture,
    PatternVideoCapture,
    SilenceAudioCapture,
    SineAudioCapture,
)
from linux_connector.lola_connector.backends import ProcessJpegVideoCapture, ProcessRawVideoCapture, split_command
from linux_connector.lola_connector.runtime import LolaLinuxRuntime
from linux_connector.lola_connector.selftest import run_bidirectional_selftest, run_control_handshake_selftest
from linux_connector.lola_connector.protocol import (
    CONTROL_DATAGRAM_SIZE,
    CONTROL_MESSAGE_KINDS,
    MESG_CHAT,
    MESG_QUICKCONN,
    MediaSettings,
    build_control_datagram,
    parse_control_datagram,
)


def test_control_quickconn_round_trip():
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


def test_all_recovered_control_kinds_round_trip():
    for kind in CONTROL_MESSAGE_KINDS:
        datagram = build_control_datagram(kind, "10.0.0.1", "10.0.0.2", 1, txt="hello")
        parsed = parse_control_datagram(datagram)
        assert parsed is not None
        assert parsed.kind == kind
        assert parsed.src_ip == "10.0.0.1"
        assert parsed.dst_ip == "10.0.0.2"
        if kind == MESG_CHAT:
            assert parsed.txt == "hello"


def test_audio_payload_round_trip():
    pcm = bytes(range(expected_audio_payload_size(channels=1)))
    fragment = parse_media_payload(build_audio_payload(7, pcm))
    assert isinstance(fragment, Fragment)
    reasm = MediaReassembler()
    serialized = reasm.add(fragment)
    assert serialized is not None
    sequence, payload = parse_serialized_media(serialized)
    assert sequence == 7
    assert payload == pcm


def test_video_payload_round_trip():
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


def test_raw_outer_packet_layout():
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


async def _exercise_test_backends():
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


async def _exercise_rgb_diagnostic_video():
    settings = MediaSettings(width=16, height=8, bits_per_pixel=24)
    video = DiagnosticVideoCapture(settings)
    frame = await video.read_frame()
    assert len(frame) == settings.width * settings.height * 3


def test_test_backends_emit_lola_sized_media():
    import asyncio

    asyncio.run(_exercise_test_backends())
    asyncio.run(_exercise_rgb_diagnostic_video())


def test_runtime_accepts_backend_contracts():
    import asyncio

    class FakeConnector:
        session = object()
        audio_port = 19788
        video_port = 19798
        audio_sent = 0
        video_sent = 0

        async def send_audio_on_socket(self, sock, pcm, sequence):
            self.audio_sent += 1

        async def send_video_on_socket(self, sock, frame, sequence):
            self.video_sent += 1

        def make_udp_socket(self, bind_port=0):
            class DummySocket:
                def close(self):
                    pass

            return DummySocket()

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


def test_process_command_split_and_jpeg_parser_shape():
    assert split_command("ffmpeg -f s16le -") == ["ffmpeg", "-f", "s16le", "-"]
    jpeg = ProcessJpegVideoCapture(["dummy"])
    jpeg._buffer.extend(b"noise\xff\xd8abc\xff\xd9tail")
    # Exercise the framing search directly without starting the dummy process.
    start = jpeg._buffer.find(b"\xff\xd8")
    end = jpeg._buffer.find(b"\xff\xd9", start + 2)
    assert bytes(jpeg._buffer[start : end + 2]) == b"\xff\xd8abc\xff\xd9"


def test_process_raw_video_capture_frame_size():
    settings = MediaSettings(width=32, height=16, bits_per_pixel=8)
    capture = ProcessRawVideoCapture(["dummy"], settings)
    assert capture.frame_size == 512


def test_bidirectional_udp_runtime_selftest():
    import asyncio

    stats_a, stats_b = asyncio.run(run_bidirectional_selftest(seconds=0.12, port_offset=21000))
    assert stats_a.audio_rx > 0
    assert stats_b.audio_rx > 0
    assert stats_a.video_rx > 0
    assert stats_b.video_rx > 0


def test_control_handshake_udp_selftest():
    import asyncio

    session_a, session_b = asyncio.run(run_control_handshake_selftest(port_offset=23000))
    assert session_a.remote_ip == "127.0.0.2"
    assert session_b.remote_ip == "127.0.0.1"
