"""Characterization tests for OSC15 control datagram decoding."""

from __future__ import annotations

import asyncio
import struct
from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock

import pytest

from linux_connector.lola_connector.process_commands import (
    canonical_trusted_executable_path,
    make_process_command,
)
from linux_connector.lola_connector.protocol import (
    MESG_CHAT,
    MESG_CHECKLOLASTATUS,
    MESG_SEND_AUDIO_SIGNAL,
    ControlMessage,
    MediaSettings,
    build_control_datagram,
    parse_control_datagram,
    parse_osc15_control_datagram,
)
from linux_connector.lola_connector.media import (
    build_audio_payload,
    build_video_payloads,
    parse_audio_frame,
    parse_fragment,
    parse_video_frame,
    parse_video_prelude,
)
from linux_connector.lola_connector.runtime import LolaLinuxRuntime
from linux_connector.lola_connector.runtime_control import _RuntimeControlHandler
from linux_connector.lola_connector.runtime_types import RuntimeStats


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

    parsed = parse_osc15_control_datagram(message)
    assert parsed is not None

    assert parsed.src_ip == "10.0.0.2"
    assert parsed.fields["SR"] == "48000"
    assert parsed.fields["BPS"] == "24"
    assert parsed.fields["BAYER"] == "1"
    assert parsed.fields["FPS"] == "60"


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

    assert parse_osc15_control_datagram(message) is None


def test_osc15_decoder_rejects_unsupported_argument_tag() -> None:
    message = _osc_message("/MESG_CHECKLOLASTATUS_ACK", "x")

    assert parse_osc15_control_datagram(message) is None


def test_inline_lola2_control_audio_video_wire_contract_rejects_malformed_bytes() -> None:
    control = build_control_datagram(MESG_CHAT, "192.0.2.1", "192.0.2.2", 7, MediaSettings(), "hello")
    parsed_control = parse_control_datagram(control)
    assert parsed_control is not None
    assert (parsed_control.kind, parsed_control.src_ip, parsed_control.dst_ip, parsed_control.sid, parsed_control.txt) == (
        MESG_CHAT, "192.0.2.1", "192.0.2.2", 7, "hello"
    )

    audio_fragment = parse_fragment(build_audio_payload(8, b"\x01\x02" * 64))
    assert audio_fragment is not None and parse_audio_frame(audio_fragment.data).sequence == 8
    video_payloads = build_video_payloads(9, b"inline-video", packet_size=128)
    prelude = parse_video_prelude(video_payloads[0])
    fragments = [parse_fragment(payload) for payload in video_payloads[1:]]
    assert prelude is not None and all(fragment is not None for fragment in fragments)
    serialized = b"".join(fragment.data for fragment in fragments if fragment is not None)
    assert (parse_video_frame(serialized).sequence, parse_video_frame(serialized).payload) == (9, b"inline-video")
    assert parse_control_datagram(b"\xff") is None
    assert parse_fragment(video_payloads[1][:-1]) is None


def test_fake_runtime_failure_closes_each_socket_backend_and_task_once(monkeypatch: pytest.MonkeyPatch) -> None:
    async def exercise() -> None:
        closed_sockets: list[object] = []
        closed_backends: list[str] = []
        task_stops: list[str] = []

        class Backend:
            def __init__(self, name: str) -> None:
                self.name = name

            async def aclose(self) -> None:
                closed_backends.append(self.name)

        connector = SimpleNamespace(session=SimpleNamespace(), unregister_runtime_control_socket=lambda sock: None)
        runtime = LolaLinuxRuntime(connector, Backend("capture"), Backend("playback"))
        runtime._audio_sock, runtime._video_sock, runtime._control_sock = object(), object(), object()

        async def worker() -> None:
            try:
                await asyncio.Event().wait()
            finally:
                task_stops.append("stopped")

        runtime._tasks.append(asyncio.create_task(worker()))
        await asyncio.sleep(0)
        monkeypatch.setattr("linux_connector.lola_connector.runtime.close_udp_socket", closed_sockets.append)
        runtime._record_worker_failure(RuntimeError("peer disconnect failure"))
        with pytest.raises(ExceptionGroup, match="runtime task failed"):
            await asyncio.gather(runtime.stop(), runtime.stop())
        assert len(closed_sockets) == 3
        assert sorted(closed_backends) == ["capture", "playback"]
        assert task_stops == ["stopped"]

    asyncio.run(exercise())


def test_runtime_control_rejects_mismatched_claimed_sources_before_ack_or_action(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    async def exercise() -> None:
        sent = AsyncMock()
        connector = SimpleNamespace(
            local_ip="127.0.0.1",
            settings=SimpleNamespace(),
            source_name="test-source",
            handle_control_message=Mock(return_value="send_audio_signal"),
        )
        audio_enabled = asyncio.Event()
        handler = _RuntimeControlHandler(
            connector=connector,
            stats=RuntimeStats(),
            control_socket=lambda: object(),
            stop=asyncio.Event(),
            audio_tx_enabled=audio_enabled,
            video_tx_enabled=asyncio.Event(),
            has_video_capture=lambda: False,
        )
        monkeypatch.setattr("linux_connector.lola_connector.runtime_control.udp_sendto", sent)
        sender = ("198.51.100.7", 7000)

        await handler._handle_message(
            ControlMessage(MESG_CHECKLOLASTATUS, {"SRCIP": "203.0.113.9", "SID": "1"}, ""),
            sender,
        )
        await handler._handle_message(
            ControlMessage(MESG_SEND_AUDIO_SIGNAL, {"SRCIP": "203.0.113.9"}, "", dialect="osc15"),
            sender,
        )

        sent.assert_not_awaited()
        connector.handle_control_message.assert_not_called()
        assert not audio_enabled.is_set()

    asyncio.run(exercise())


def test_process_commands_require_trusted_nonsymlink_absolute_executables(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    for command in (
        "ffmpeg -i input.mov",
        "./ffmpeg -i input.mov",
        "/tmp/ffmpeg -i input.mov",
        "/usr/bin/ffmpeg -i input.mov; whoami",
    ):
        with pytest.raises(ValueError):
            make_process_command(command)

    monkeypatch.setattr("linux_connector.lola_connector.process_commands.os.path.islink", lambda _: True)
    with pytest.raises(ValueError, match="symbolic link"):
        canonical_trusted_executable_path("/usr/bin/ffmpeg")
