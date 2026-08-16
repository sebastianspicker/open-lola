"""Deterministic coverage for relay, CLI, and self-test error branches."""

from __future__ import annotations

import argparse
import asyncio
import socket
from types import SimpleNamespace
from typing import cast

import pytest

import linux_connector.env.npcap_udp_relay as relay
from linux_connector.lola_connector import backends, cli, runtime, selftest
from linux_connector.lola_connector import connector as connector_module
from linux_connector.lola_connector.backends import MemoryAudioPlayback, SilenceAudioCapture
from linux_connector.lola_connector.connector import Session
from linux_connector.lola_connector.protocol import (
    MESG_CHAT,
    MESG_CHECKLOLASTATUS_ACK,
    ControlMessage,
    MediaSettings,
)
from linux_connector.lola_connector.runtime_types import CapturedVideoFrame
from linux_connector.tests.relay_test_support import RelaySocketDouble, relay_args


def test_relay_parses_routes_drops_and_closes_without_network(monkeypatch: pytest.MonkeyPatch) -> None:
    args = relay_args()
    audio = RelaySocketDouble()
    video = RelaySocketDouble(blocked=True)
    sockets = relay.RelaySockets(
        audio=cast(socket.socket, audio),
        video=cast(socket.socket, video),
    )
    counts = {args.audio_port: 0, args.video_port: 0}

    assert relay.parse_capture_line("19788\tde:ad:be:ef") == relay.CapturedUdpPayload(
        src_port=19788, payload=b"\xde\xad\xbe\xef"
    )
    assert relay.parse_capture_line("19788 without-a-tab") is None
    relay.relay_payload(relay.CapturedUdpPayload(args.audio_port, b"audio"), args, sockets, counts)
    relay.relay_payload(relay.CapturedUdpPayload(args.video_port, b"video"), args, sockets, counts)
    relay.relay_payload(relay.CapturedUdpPayload(9999, b"ignored"), args, sockets, counts)

    assert audio.sent == [(b"audio", (args.dst_ip, args.audio_port))]
    assert video.sent == []
    assert counts == {args.audio_port: 1, args.video_port: 0}
    state = relay.RelayState(counts=counts, last_stats=0.0)
    monkeypatch.setattr(relay.time, "monotonic", lambda: 2.0)
    relay.log_relay_stats_if_due(args, state)
    assert state.last_stats == 2.0
    relay.close_relay_sockets(sockets)
    assert audio.closed and video.closed


def test_relay_supervisor_stops_and_closes_after_patched_capture(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    args = relay_args()
    fake_process = cast(asyncio.subprocess.Process, SimpleNamespace(stdout=object()))
    sockets = relay.RelaySockets(
        audio=cast(socket.socket, RelaySocketDouble()),
        video=cast(socket.socket, RelaySocketDouble()),
    )
    events: list[str] = []

    async def fake_start(_command: relay.RelayProcessCommand) -> asyncio.subprocess.Process:
        events.append("start")
        return fake_process

    async def fake_lines(
        stdout: asyncio.StreamReader,
        received_args: argparse.Namespace,
        received_sockets: relay.RelaySockets,
    ) -> None:
        assert stdout is fake_process.stdout
        assert received_args is args
        assert received_sockets is sockets
        events.append("lines")

    async def fake_stop(process: asyncio.subprocess.Process) -> None:
        assert process is fake_process
        events.append("stop")

    def fake_close(received_sockets: relay.RelaySockets) -> None:
        assert received_sockets is sockets
        events.append("close")

    monkeypatch.setattr(relay, "open_relay_sockets", lambda: sockets)
    monkeypatch.setattr(relay, "start_tshark_capture", fake_start)
    monkeypatch.setattr(relay, "relay_capture_lines", fake_lines)
    monkeypatch.setattr(relay, "stop_relay_process", fake_stop)
    monkeypatch.setattr(relay, "close_relay_sockets", fake_close)

    assert asyncio.run(relay.run_relay(args)) == 0
    assert events == ["start", "lines", "stop", "close"]


def test_cli_type_guards_and_timed_cleanup_are_local(monkeypatch: pytest.MonkeyPatch) -> None:
    assert cli.require_float_cli_attribute(argparse.Namespace(duration=2), "duration") == 2.0
    assert cli.require_optional_int_cli_attribute(argparse.Namespace(port_offset=None), "port_offset") is None
    with pytest.raises(RuntimeError, match="non-float"):
        cli.require_float_cli_attribute(argparse.Namespace(duration="soon"), "duration")
    with pytest.raises(RuntimeError, match="non-int"):
        cli.require_optional_int_cli_attribute(argparse.Namespace(port_offset="soon"), "port_offset")

    events: list[tuple[object, ...]] = []

    class RuntimeDouble:
        stats = "local"

        async def stop(self) -> None:
            events.append(("runtime-stop",))

    class ConnectorDouble:
        async def send_control_once(self, *values: object) -> None:
            events.append(("control", *values))

        async def send_disconnect(self) -> None:
            events.append(("disconnect",))

    async def fake_sleep(seconds: float) -> None:
        events.append(("sleep", seconds))

    monkeypatch.setattr(cli.asyncio, "sleep", fake_sleep)
    session = Session("127.0.0.1", "127.0.0.1", 7, MediaSettings())
    args = argparse.Namespace(duration=0.25, request_remote_audio_signal=True)
    asyncio.run(
        cli.run_timed_runtime(
            args,
            cast(cli.LolaConnector, ConnectorDouble()),
            session,
            cast(cli.LolaLinuxRuntime, RuntimeDouble()),
        )
    )

    assert events == [
        ("control", cli.MESG_SEND_AUDIO_SIGNAL, "127.0.0.1", 7),
        ("sleep", 0.25),
        ("control", cli.MESG_STOP_AUDIO_SIGNAL, "127.0.0.1", 7),
        ("runtime-stop",),
        ("disconnect",),
    ]


def test_selftest_rejects_missing_session_and_wrong_media_sources() -> None:
    settings = MediaSettings(width=16, height=8, fps=25)
    _settings, local_ports, peer_ports = selftest._selftest_ports(0)
    connector = selftest._SelftestConnector("127.0.0.1", settings, local_ports, peer_ports)
    runtime = selftest._SelftestRuntime(
        connector,
        SilenceAudioCapture(settings),
        MemoryAudioPlayback(),
    )

    with pytest.raises(RuntimeError, match="no active LoLa session"):
        asyncio.run(connector.send_audio_on_socket(cast(socket.socket, object()), b"pcm", 1))
    with pytest.raises(RuntimeError, match="no active LoLa session"):
        asyncio.run(connector.send_video_until_on_socket(cast(socket.socket, object()), b"frame", 1, deadline=None))
    assert runtime._audio_session_for_sender(("127.0.0.2", peer_ports.audio)) is None

    session = Session("127.0.0.1", "127.0.0.2", 0, settings)
    connector.session = session
    assert runtime._audio_session_for_sender(("127.0.0.2", peer_ports.audio)) is session
    assert runtime._audio_session_for_sender(("127.0.0.2", peer_ports.video)) is None
    runtime._count_audio_drain_discard(b"pcm", ("127.0.0.9", peer_ports.audio))
    runtime._count_audio_drain_discard(b"pcm", ("127.0.0.2", peer_ports.video))
    runtime._count_audio_drain_discard(b"pcm", ("127.0.0.2", peer_ports.audio))
    assert runtime.stats.audio_rx_wrong_peer_dropped == 1
    assert runtime.stats.audio_rx_wrong_port_dropped == 1
    assert runtime.stats.audio_rx_malformed_dropped == 1
    assert runtime._session_for_media_sender(("127.0.0.2", peer_ports.video), "video") is session
    assert runtime._session_for_media_sender(("127.0.0.2", peer_ports.audio), "video") is None
    assert runtime.stats.video_malformed_rx == 1


def test_relay_reports_invalid_capture_command_and_missing_stdout() -> None:
    command = relay.RelayProcessCommand("tshark", "tshark", ("-Y", "udp"))

    with pytest.raises(ValueError, match="line-buffered"):
        asyncio.run(relay.start_tshark_capture(command))
    with pytest.raises(RuntimeError, match="did not expose stdout"):
        relay.require_process_stdout(cast(asyncio.subprocess.Process, SimpleNamespace(stdout=None)))


def test_relay_resolution_and_main_interrupt_are_safe(monkeypatch: pytest.MonkeyPatch) -> None:
    bare_command = relay.RelayProcessCommand("tshark", "tshark", ("-l",))
    monkeypatch.setattr(relay.shutil, "which", lambda _name: None)
    with pytest.raises(FileNotFoundError, match="not found"):
        relay.resolve_tshark_executable(bare_command)
    with pytest.raises(RuntimeError, match="unsupported"):
        relay.resolve_tshark_executable(relay.RelayProcessCommand("other", "other", ("-l",)))

    monkeypatch.setattr(relay, "parse_args", relay_args)

    def interrupted(_awaitable: object) -> int:
        close = getattr(_awaitable, "close", None)
        if close is not None:
            close()
        raise KeyboardInterrupt

    monkeypatch.setattr(relay.asyncio, "run", interrupted)
    assert relay.main() == 0


def test_cli_runtime_selection_and_backend_fallbacks() -> None:
    base = dict(
        test_media=None,
        audio_capture_cmd=None,
        audio_playback_cmd=None,
        video_capture_cmd=None,
        video_display_cmd=None,
        tone_amplitude=0.2,
        tone_frequency=440.0,
        audio_frames_per_callback=64,
        max_frame_bytes=4096,
    )
    settings = MediaSettings(width=16, height=8)
    assert not cli.should_start_runtime(argparse.Namespace(**base))
    assert cli.should_start_runtime(argparse.Namespace(**(base | {"audio_playback_cmd": "player"})))
    assert cli.should_start_runtime(argparse.Namespace(**(base | {"request_remote_audio_signal": True})))
    assert cli.should_start_runtime(argparse.Namespace(**(base | {"wait_for_remote_test_signal": True})))

    silence = cli.build_audio_capture(argparse.Namespace(**base), settings)
    tones = cli.build_audio_capture(argparse.Namespace(**(base | {"test_media": "tones"})), settings)
    sine = cli.build_audio_capture(argparse.Namespace(**(base | {"test_media": "sine"})), settings)
    process = cli.build_audio_capture(argparse.Namespace(**(base | {"audio_capture_cmd": "arecord"})), settings)
    assert isinstance(silence, SilenceAudioCapture)
    assert isinstance(tones, backends.MultiToneAudioCapture)
    assert isinstance(sine, backends.SineAudioCapture)
    assert isinstance(process, backends.ProcessAudioCapture)


def test_cli_video_backend_selection_covers_raw_jpeg_and_diagnostic() -> None:
    base = dict(test_media=None, video_capture_cmd=None, max_frame_bytes=4096)
    raw = cli.build_video_capture(
        argparse.Namespace(**(base | {"video_capture_cmd": "ffmpeg"})),
        MediaSettings(width=16, height=8),
    )
    jpeg = cli.build_video_capture(
        argparse.Namespace(**(base | {"video_capture_cmd": "ffmpeg"})),
        MediaSettings(width=16, height=8, compression=1),
    )
    diagnostic = cli.build_video_capture(
        argparse.Namespace(**(base | {"test_media": "diagnostic"})), MediaSettings(width=16, height=8)
    )
    assert isinstance(raw, backends.ProcessRawVideoCapture)
    assert isinstance(jpeg, backends.ProcessJpegVideoCapture)
    assert isinstance(diagnostic, backends.DiagnosticVideoCapture)
    assert cli.build_video_capture(argparse.Namespace(**base), MediaSettings(width=16, height=8)) is None


def test_cli_validation_rejects_optional_sid_and_port_bounds() -> None:
    parser = cli.build_parser()
    args = parser.parse_args(["--local-ip", "127.0.0.1", "connect", "127.0.0.2"])
    args.sid = -1
    with pytest.raises(ValueError, match="sid"):
        cli.validate_cli_args(args)
    args.sid = 0
    args.port_offset = 40_001
    with pytest.raises(ValueError, match="port_offset"):
        cli.validate_cli_args(args)
    args.port_offset = None
    args.tone_frequency = float("inf")
    with pytest.raises(ValueError, match="tone_frequency"):
        cli.validate_cli_args(args)


def test_connector_udp_send_and_legacy_option_rejections_are_local() -> None:
    class DatagramDouble:
        def __init__(self, outcome: int | BaseException) -> None:
            self.outcome = outcome

        def sendto(self, _data: bytes, _address: tuple[str, int]) -> int:
            if isinstance(self.outcome, BaseException):
                raise self.outcome
            return self.outcome

    assert asyncio.run(connector_module.udp_sendto(cast(socket.socket, DatagramDouble(3)), b"one", ("127.0.0.1", 7)))
    assert not asyncio.run(
        connector_module.udp_sendto(cast(socket.socket, DatagramDouble(BlockingIOError())), b"one", ("127.0.0.1", 7))
    )
    with pytest.raises(OSError, match="partial UDP"):
        asyncio.run(connector_module.udp_sendto(cast(socket.socket, DatagramDouble(2)), b"one", ("127.0.0.1", 7)))
    with pytest.raises(TypeError, match="multiple values"):
        connector_module._connector_options_from_legacy((7000,), {"control_port": 7001}, None)
    with pytest.raises(TypeError, match="must be int"):
        connector_module._connector_options_from_legacy((), {"audio_port": "bad"}, None)


def test_connector_status_handler_records_wrong_and_unexpected_peers() -> None:
    state = connector_module._StatusProbeState(connector_module._ControlReceiveStats())
    ack = ControlMessage(MESG_CHECKLOLASTATUS_ACK, {}, "")
    assert connector_module._handle_status_response(ack, ("127.0.0.2", 7000), "127.0.0.1", (), state) is None
    assert state.reason == "wrong-peer"
    unexpected = ControlMessage(MESG_CHAT, {}, "")
    assert connector_module._handle_status_response(unexpected, ("127.0.0.1", 7000), "127.0.0.1", (), state) is None
    assert state.reason == "unexpected-response"
    accepted = connector_module._handle_status_response(ack, ("127.0.0.1", 7000), "127.0.0.1", ("ascii",), state)
    assert accepted is not None and accepted.acknowledged
    assert accepted.wrong_peer_datagrams == 1
    assert accepted.unexpected_datagrams == 1


def test_runtime_uses_legacy_video_sender_fallback_and_deadline_drop(monkeypatch: pytest.MonkeyPatch) -> None:
    settings = MediaSettings(width=16, height=8)

    async def send_video_on_socket(*_values: object) -> bool:
        return False

    connector = SimpleNamespace(
        session=Session("127.0.0.1", "127.0.0.2", 0, settings),
        settings=settings,
        audio_port=19788,
        video_port=19798,
        control_port=7000,
        send_video_on_socket=send_video_on_socket,
    )
    runtime_instance = runtime.LolaLinuxRuntime(
        cast(runtime.LolaConnector, connector), SilenceAudioCapture(settings), MemoryAudioPlayback()
    )
    runtime_instance._video_sock = cast(socket.socket, object())
    monkeypatch.setattr(runtime.time, "perf_counter", lambda: 1.0)
    captured = CapturedVideoFrame(frame=b"\0" * (settings.width * settings.height), captured_at=1.0)
    assert asyncio.run(runtime_instance._send_captured_video(captured, 3)) == "backpressure"
    expired = CapturedVideoFrame(frame=b"frame", captured_at=0.0)
    assert asyncio.run(runtime_instance._send_captured_video(expired, 4)) == "deadline"


def test_runtime_collects_backend_cleanup_warnings() -> None:
    settings = MediaSettings(width=16, height=8)

    class ClosableDouble:
        cleanup_warnings = ["mocked close warning"]

        async def aclose(self) -> None:
            return None

    connector = SimpleNamespace(
        session=Session("127.0.0.1", "127.0.0.2", 0, settings),
        settings=settings,
        audio_port=19788,
        video_port=19798,
        control_port=7000,
    )
    runtime_instance = runtime.LolaLinuxRuntime(
        cast(runtime.LolaConnector, connector), SilenceAudioCapture(settings), MemoryAudioPlayback()
    )
    asyncio.run(runtime_instance._close_backend(ClosableDouble()))
    assert runtime_instance.stats.cleanup_warnings == ["mocked close warning"]


def test_process_backend_argument_and_jpeg_buffer_guards_need_no_process() -> None:
    playback = backends.ProcessAudioPlayback(["ffplay"])
    with pytest.raises(ValueError, match="high-water"):
        playback._configure_stdin_high_water(0)
    with pytest.raises(RuntimeError, match="not ready"):
        playback._stdin_writer_or_raise("audio playback")

    extractor = backends.JpegFrameExtractor(max_frame_bytes=4, warn_frame_bytes=3)
    extractor.append(b"noise")
    assert extractor.extract_frame() is None
    extractor.append(b"\xff\xd8abc")
    with pytest.raises(ValueError, match="byte cap"):
        extractor.extract_frame()
