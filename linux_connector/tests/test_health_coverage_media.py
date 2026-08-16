"""Deterministic coverage for media, self-test, and runtime diagnostic branches."""

from __future__ import annotations

import argparse
import asyncio
from types import SimpleNamespace
from typing import cast

import pytest

from linux_connector.lola_connector import cli, media, runtime, selftest
from linux_connector.lola_connector import connector as connector_module
from linux_connector.lola_connector.backends import MemoryAudioPlayback, MemoryVideoDisplay, SilenceAudioCapture
from linux_connector.lola_connector.connector import Session
from linux_connector.lola_connector.protocol import MESG_CHAT, ControlMessage, MediaSettings
from linux_connector.lola_connector.runtime_types import RuntimeStats


@pytest.mark.parametrize(
    ("data", "message"),
    [
        (b"", "shorter than 8 bytes"),
        (b"\x01\x00\x00\x00\x02\x00\x00\x00x", "length mismatch"),
    ],
)
def test_media_rejects_truncated_and_mismatched_serialized_bodies(data: bytes, message: str) -> None:
    with pytest.raises(ValueError, match=message):
        media.parse_serialized_media(data)


def test_media_fragment_and_prelude_parsers_reject_malformed_payloads() -> None:
    frame = media.serialize_media_frame(9, b"pcm")
    fragment = media.fragment_serialized(frame, frame_id=10)[0]
    prelude = media.build_video_prelude(10, len(frame), 1)

    assert media.parse_fragment(b"tiny") is None
    assert media.parse_fragment(b"not-a-lola-fragment" * 3) is None
    assert media.parse_fragment(fragment[:-1]) is None
    assert media.parse_video_prelude(b"short") is None
    assert media.parse_video_prelude(bytes(len(prelude))) is None
    assert media.parse_media_payload(prelude) == media.VideoPrelude(10, len(frame), 1)


def test_media_payload_builders_cover_sizes_and_streaming_layout() -> None:
    assert media.clamp_packet_size(1) == 0x80
    assert media.clamp_packet_size(0x9000) == 0x2000
    assert media.expected_audio_payload_size(2, 24, 64) == 384
    with pytest.raises(ValueError, match="one LoLa fragment"):
        media.build_audio_payload(1, bytes(2_000))

    packets = list(media.iter_video_payloads(7, bytes(range(256)), packet_size=0x80))
    assert isinstance(media.parse_media_payload(packets[0]), media.VideoPrelude)
    fragments = [media.parse_fragment(packet) for packet in packets[1:]]
    assert all(fragment is not None for fragment in fragments)
    assert b"".join(fragment.data for fragment in fragments if fragment is not None).startswith(
        media.serialize_media_frame(7, bytes(range(256)))[:8]
    )


def test_media_reassembler_rejects_inactive_wrong_duplicate_empty_and_oversize_fragments() -> None:
    fragment = media.Fragment(7, 1, 0, 0, 3, 1, b"abc")
    strict = media.MediaReassembler(allow_fragment_auto_begin=False)
    assert strict.add(fragment) is None

    reassembler = media.MediaReassembler()
    reassembler.begin(7, 3, 1)
    assert reassembler.add(media.Fragment(8, 1, 0, 0, 3, 1, b"abc")) is None
    assert reassembler.add(media.Fragment(7, 1, 1, 0, 3, 1, b"abc")) is None
    with pytest.raises(ValueError, match="empty payload"):
        reassembler.add(media.Fragment(7, 1, 0, 0, 0, 1, b""))
    with pytest.raises(ValueError, match="exceeds declared"):
        reassembler.add(media.Fragment(7, 1, 0, 1, 3, 1, b"abc"))

    reassembler.begin(7, 3, 1)
    assert reassembler.add(fragment) == b"abc"
    reassembler.begin(7, 3, 1)
    reassembler.parts[0] = fragment
    assert reassembler.add(fragment) is None


@pytest.mark.parametrize(
    ("parts", "expected", "message"),
    [
        (
            [media.Fragment(1, 2, 0, 0, 1, 0, b"a"), media.Fragment(1, 2, 1, 2, 1, 1, b"b")],
            3,
            "gap",
        ),
        (
            [media.Fragment(1, 2, 0, 0, 2, 0, b"aa"), media.Fragment(1, 2, 1, 1, 2, 1, b"bb")],
            3,
            "overlaps",
        ),
    ],
)
def test_media_reassembler_resets_after_invalid_coverage(
    parts: list[media.Fragment], expected: int, message: str
) -> None:
    reassembler = media.MediaReassembler()
    reassembler.begin(1, expected, 2)
    with pytest.raises(ValueError, match=message):
        for part in parts:
            reassembler.add(part)
    assert reassembler.frame_id is None
    assert not reassembler.parts


@pytest.mark.parametrize(
    ("stats", "expected"),
    [
        (connector_module._ControlReceiveStats(unexpected_datagrams=1), "unexpected-response"),
        (connector_module._ControlReceiveStats(wrong_peer_datagrams=1), "wrong-peer"),
        (connector_module._ControlReceiveStats(malformed_datagrams=1), "malformed-response"),
        (connector_module._ControlReceiveStats(), "timeout"),
    ],
)
def test_connector_failure_reason_prioritizes_received_datagrams(
    stats: connector_module._ControlReceiveStats, expected: str
) -> None:
    assert connector_module._control_receive_failure_reason(stats) == expected
    assert connector_module._quickconn_timeout_result(stats).reason == expected


def test_connector_stateless_legacy_and_socket_cache_helpers_are_local() -> None:
    assert connector_module._stateless_control_action(ControlMessage(MESG_CHAT, {}, "")) == "chat"
    assert connector_module._stateless_control_action(ControlMessage("MESG_REJECT", {}, "")) == "reject"
    assert connector_module._stateless_control_action(ControlMessage("other", {}, "")) == "ignore"
    with pytest.raises(TypeError, match="too many positional"):
        connector_module._legacy_option_values((1, 2, 3, 4, 5, 6, 7), {})
    with pytest.raises(TypeError, match="must be str"):
        connector_module._connector_options_from_legacy((), {"source_name": 1}, None)

    class SocketDouble:
        def __init__(self, number: int) -> None:
            self.number = number

        def fileno(self) -> int:
            return self.number

    sock = cast(object, SocketDouble(42))
    first = connector_module._socket_lock({}, sock)
    locks = {42: first}
    assert connector_module._socket_lock(locks, sock) is first
    connector_module._socket_read_locks[42] = first
    connector_module._socket_write_locks[42] = first
    connector_module.unregister_udp_socket(sock)
    assert 42 not in connector_module._socket_read_locks
    assert 42 not in connector_module._socket_write_locks


def test_cli_dispatches_selftest_status_and_idle_connect_without_io(
    monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    events: list[str] = []

    async def fake_selftest(_args: argparse.Namespace) -> None:
        events.append("selftest")

    class ConnectorDouble:
        async def check_status_result(self, *_values: object, **_kwargs: object) -> SimpleNamespace:
            events.append("status")
            return SimpleNamespace(
                acknowledged=True,
                reason="ack",
                malformed_datagrams=0,
                wrong_peer_datagrams=0,
                unexpected_datagrams=0,
            )

        async def send_disconnect(self) -> None:
            events.append("disconnect")

    connector = ConnectorDouble()
    session = Session("127.0.0.1", "127.0.0.2", 3, MediaSettings(width=16, height=8))

    monkeypatch.setattr(cli, "run_selftest_mode", fake_selftest)
    monkeypatch.setattr(cli, "connector_from_args", lambda _args: cast(cli.LolaConnector, connector))
    monkeypatch.setattr(cli, "establish_session", lambda *_args: _return(session))
    asyncio.run(cli.run(argparse.Namespace(mode="selftest")))
    asyncio.run(cli.run(argparse.Namespace(mode="status", remote_ip="127.0.0.2", sid=3, timeout=1.0)))
    asyncio.run(
        cli.run(
            argparse.Namespace(
                mode="connect",
                rx=False,
                test_media=None,
                audio_capture_cmd=None,
                audio_playback_cmd=None,
                video_capture_cmd=None,
                video_display_cmd=None,
            )
        )
    )
    assert events == ["selftest", "status", "disconnect"]
    assert "status_ack=1" in capsys.readouterr().out


async def _return(value: Session) -> Session:
    return value


def test_cli_selftest_formatting_and_optional_ranges(
    monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    stats = RuntimeStats(audio_rx=2)

    async def control(**_kwargs: object) -> None:
        return None

    async def media_run(**_kwargs: object) -> tuple[RuntimeStats, RuntimeStats]:
        return stats, RuntimeStats(video_rx=2)

    monkeypatch.setattr(cli, "run_control_handshake_selftest", control)
    monkeypatch.setattr(cli, "run_bidirectional_selftest", media_run)
    asyncio.run(cli.run_selftest_mode(argparse.Namespace(duration=0.1, port_offset=7)))
    cli.validate_optional_finite_ranges(argparse.Namespace(duration=None), (cli.OPTIONAL_FINITE_RANGES[0],))
    with pytest.raises(ValueError, match="timeout must not be None"):
        cli.validate_optional_finite_ranges(argparse.Namespace(timeout=None), (cli.OPTIONAL_FINITE_RANGES[1],))
    assert "endpoint_a=" in capsys.readouterr().out


def test_runtime_sink_queues_keep_newest_audio_and_video() -> None:
    settings = MediaSettings(width=16, height=8)
    connector = SimpleNamespace(
        session=Session("127.0.0.1", "127.0.0.2", 0, settings),
        settings=settings,
        audio_port=19788,
        video_port=19798,
    )
    instance = runtime.LolaLinuxRuntime(
        cast(runtime.LolaConnector, connector),
        SilenceAudioCapture(settings),
        MemoryAudioPlayback(),
        video_display=MemoryVideoDisplay(),
    )
    instance._enqueue_audio_sink(b"old", 1)
    instance._enqueue_audio_sink(b"new", 2)
    assert instance._audio_sink_queue.get_nowait() == (b"new", 2)
    instance._enqueue_audio_sink(b"new", 2)
    instance._enqueue_audio_sink(b"old", 1)
    assert instance._audio_sink_queue.get_nowait() == (b"new", 2)
    instance._enqueue_video_sink(b"old", 1, False)
    instance._enqueue_video_sink(b"new", 2, True)
    assert instance._video_sink_queue.get_nowait() == (b"new", 2, True)
    assert instance.stats.audio_rx_dropped == 1
    assert instance.stats.audio_rx_reordered_dropped == 1
    assert instance.stats.video_rx_dropped == 1


def test_runtime_audio_fragment_filters_and_media_malformed_counter(monkeypatch: pytest.MonkeyPatch) -> None:
    complete = media.parse_fragment(media.build_audio_payload(4, bytes(256)))
    assert complete is not None
    assert runtime.LolaLinuxRuntime._single_audio_fragment(media.build_audio_payload(4, bytes(256))) == complete
    assert runtime.LolaLinuxRuntime._single_audio_fragment(b"not-media") is None
    monkeypatch.setattr(runtime, "parse_media_payload", lambda _payload: (_ for _ in ()).throw(ValueError("bad")))
    assert runtime.LolaLinuxRuntime._single_audio_fragment(b"bad") is None
    assert not runtime.LolaLinuxRuntime._is_complete_audio_fragment(media.Fragment(1, 2, 0, 0, 1, 0, b"a"))

    settings = MediaSettings(width=16, height=8)
    connector = SimpleNamespace(session=None, settings=settings, audio_port=1, video_port=2)
    instance = runtime.LolaLinuxRuntime(
        cast(runtime.LolaConnector, connector), SilenceAudioCapture(settings), MemoryAudioPlayback()
    )
    instance._count_malformed_media("audio")
    instance._count_malformed_media("video")
    instance._count_malformed_media("other")
    assert (instance.stats.audio_malformed_rx, instance.stats.video_malformed_rx) == (1, 1)


def test_selftest_alias_probe_ports_and_assertions_use_doubles(monkeypatch: pytest.MonkeyPatch) -> None:
    class AliasSocket:
        def __init__(self, fail: bool) -> None:
            self.fail = fail
            self.closed = False

        def bind(self, _address: tuple[str, int]) -> None:
            if self.fail:
                raise OSError("unavailable")

        def close(self) -> None:
            self.closed = True

    failed = AliasSocket(True)
    monkeypatch.setattr(selftest.socket, "socket", lambda *_args: failed)
    assert selftest.loopback_alias_capability("127.0.0.9") == (
        False,
        "loopback alias 127.0.0.9 is not available: unavailable",
    )
    assert failed.closed
    available = AliasSocket(False)
    monkeypatch.setattr(selftest.socket, "socket", lambda *_args: available)
    assert selftest.loopback_alias_capability("127.0.0.9") == (True, "loopback alias 127.0.0.9 is available")
    assert available.closed
    monkeypatch.setattr(selftest.os, "getpid", lambda: 5_123)
    assert selftest.default_port_offset() == 123
    settings, local, peer = selftest._selftest_ports(10)
    assert (settings.width, local.control, peer.video) == (16, 7010, 19809)

    empty = SimpleNamespace(
        runtime=SimpleNamespace(stats=RuntimeStats()), audio=MemoryAudioPlayback(), video=MemoryVideoDisplay()
    )
    with pytest.raises(AssertionError, match="audio did not flow"):
        selftest._assert_bidirectional_media(empty, empty)
    full = SimpleNamespace(
        runtime=SimpleNamespace(stats=RuntimeStats(audio_rx=1, video_rx=1)),
        audio=MemoryAudioPlayback(),
        video=MemoryVideoDisplay(),
    )
    full.audio.blocks.append((1, b"pcm"))
    full.video.frames.append((1, b"frame", False))
    selftest._assert_bidirectional_media(full, full)
