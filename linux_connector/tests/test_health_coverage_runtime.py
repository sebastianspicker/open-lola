"""Deterministic coverage for synthetic backends and runtime/relay lifecycle branches."""

from __future__ import annotations

import argparse
import asyncio
import socket
import sys
from types import SimpleNamespace
from typing import cast

import pytest

import linux_connector.env.npcap_udp_relay as relay
from linux_connector.lola_connector import backends, cli, connector as connector_module, media, runtime, selftest
from linux_connector.lola_connector.backends import MemoryAudioPlayback, MemoryVideoDisplay, SilenceAudioCapture
from linux_connector.lola_connector.connector import Session
from linux_connector.lola_connector.protocol import (
    ControlMessage,
    MediaSettings,
)
from linux_connector.lola_connector.runtime_types import RuntimeStats


class _RelaySocketDouble:
    def __init__(self, *, blocked: bool = False) -> None:
        self.blocked = blocked
        self.closed = False
        self.sent: list[tuple[bytes, tuple[str, int]]] = []

    def sendto(self, payload: bytes, address: tuple[str, int]) -> int:
        if self.blocked:
            raise BlockingIOError("full")
        self.sent.append((payload, address))
        return len(payload)

    def close(self) -> None:
        self.closed = True


def _relay_args() -> argparse.Namespace:
    return argparse.Namespace(
        tshark="tshark",
        interface="4",
        src_ip="192.0.2.1",
        dst_ip="192.0.2.30",
        audio_port=19788,
        video_port=19798,
        stats_interval=2.0,
    )

def test_synthetic_backends_cover_pcm_capacity_pattern_and_jpeg_boundaries() -> None:
    settings = MediaSettings(width=2, height=1, channels=2)
    sine = backends.SineAudioCapture(settings, frames_per_callback=2)
    tone = backends.MultiToneAudioCapture(settings, frames_per_callback=2)
    assert len(asyncio.run(sine.read_block())) == 8
    assert len(asyncio.run(tone.read_block())) == 8
    with pytest.raises(ValueError, match="16-bit"):
        asyncio.run(backends.SineAudioCapture(MediaSettings(width=2, height=1, bits_per_sample=8)).read_block())
    with pytest.raises(ValueError, match="16-bit"):
        asyncio.run(backends.MultiToneAudioCapture(MediaSettings(width=2, height=1, bits_per_sample=8)).read_block())

    playback = MemoryAudioPlayback(capacity=1)
    display = MemoryVideoDisplay(capacity=1)
    asyncio.run(playback.write_block(b"first", 1))
    asyncio.run(playback.write_block(b"dropped", 2))
    asyncio.run(display.show_frame(b"first", 1, False))
    asyncio.run(display.show_frame(b"dropped", 2, True))
    assert (playback.blocks, playback.dropped_blocks, display.frames, display.dropped_frames) == (
        [(1, b"first")], 1, [(1, b"first", False)], 1
    )

    extractor = backends.JpegFrameExtractor(max_frame_bytes=12, warn_frame_bytes=6)
    extractor.append(b"noise\xff\xd8ok\xff\xd9tail\xff\xd8next\xff\xd9")
    assert extractor.extract_frame() == b"\xff\xd8ok\xff\xd9"
    assert extractor.extract_frame() == b"\xff\xd8next\xff\xd9"


def test_cli_media_runtime_uses_bounded_and_indefinite_dispatches(monkeypatch: pytest.MonkeyPatch) -> None:
    settings = MediaSettings(width=16, height=8)
    session = Session("127.0.0.1", "127.0.0.2", 0, settings)
    events: list[str] = []

    class RuntimeDouble:
        async def start(self, **kwargs: bool) -> None:
            events.append(f"start:{kwargs['transmit_audio']}:{kwargs['transmit_video']}")

    async def timed(*_values: object) -> None:
        events.append("timed")

    async def requested(*_values: object) -> None:
        events.append("requested")

    class EventDouble:
        async def wait(self) -> None:
            events.append("wait")

    args = argparse.Namespace(wait_for_remote_test_signal=False, rx=True, duration=0.1)
    monkeypatch.setattr(cli, "media_settings_from_args", lambda _args: settings)
    monkeypatch.setattr(cli, "build_video_capture", lambda *_args: cast(cli.VideoCapture, object()))
    monkeypatch.setattr(cli, "build_runtime", lambda *_args: cast(cli.LolaLinuxRuntime, RuntimeDouble()))
    monkeypatch.setattr(cli, "run_timed_runtime", timed)
    asyncio.run(cli.run_media_runtime(args, cast(cli.LolaConnector, object()), session))
    args.duration = None
    monkeypatch.setattr(cli, "request_remote_audio_if_needed", requested)
    monkeypatch.setattr(cli.asyncio, "Event", EventDouble)
    asyncio.run(cli.run_media_runtime(args, cast(cli.LolaConnector, object()), session))
    assert events == ["start:True:True", "timed", "start:True:True", "requested", "wait"]


def test_cli_main_formats_parser_errors_and_dispatches_only_valid_arguments(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    events: list[object] = []

    class ParserDouble:
        def parse_args(self) -> argparse.Namespace:
            return argparse.Namespace(mode="selftest")

        def error(self, message: str) -> None:
            events.append(("error", message))

    parser = ParserDouble()
    monkeypatch.setattr(cli, "build_parser", lambda: cast(argparse.ArgumentParser, parser))
    monkeypatch.setattr(cli.logging, "basicConfig", lambda **kwargs: events.append(("logging", kwargs)))
    monkeypatch.setattr(cli, "validate_cli_args", lambda _args: (_ for _ in ()).throw(ValueError("bad option")))

    def record_run(awaitable: object) -> None:
        close = getattr(awaitable, "close", None)
        if close is not None:
            close()
        events.append("run")

    monkeypatch.setattr(cli.asyncio, "run", record_run)
    cli.main()
    assert events == [("logging", {"level": 20, "format": "%(message)s"}), ("error", "bad option"), "run"]


def test_runtime_handles_preludes_bad_payloads_and_completed_audio_without_io() -> None:
    settings = MediaSettings(width=16, height=8)
    connector = SimpleNamespace(
        session=Session("127.0.0.1", "127.0.0.2", 0, settings),
        settings=settings,
        audio_port=19788,
        video_port=19798,
    )
    instance = runtime.LolaLinuxRuntime(
        cast(runtime.LolaConnector, connector), SilenceAudioCapture(settings), MemoryAudioPlayback()
    )
    reassembler = media.MediaReassembler()
    asyncio.run(instance._handle_media_payload(b"not-media", "127.0.0.2", connector.session, reassembler, "audio"))
    assert instance.stats.audio_malformed_rx == 1

    prelude = media.build_video_prelude(5, 8, 1)
    asyncio.run(instance._handle_media_payload(prelude, "127.0.0.2", connector.session, reassembler, "video"))
    assert (reassembler.frame_id, reassembler.expected_size) == (5, 8)
    asyncio.run(
        instance._handle_media_payload(
            media.build_video_prelude(6, 0, 1), "127.0.0.2", connector.session, reassembler, "video"
        )
    )
    assert instance.stats.video_malformed_rx == 1

    audio_payload = media.build_audio_payload(8, bytes(256))
    asyncio.run(
        instance._handle_media_payload(
            audio_payload, "127.0.0.2", connector.session, media.MediaReassembler(), "audio"
        )
    )
    assert instance._audio_sink_queue.get_nowait() == (bytes(256), 8)
    video_body = media.serialize_media_frame(9, b"frame")
    video_packet = media.fragment_serialized(video_body, 9)[0]
    asyncio.run(instance._handle_media_payload(video_packet, "127.0.0.2", connector.session, media.MediaReassembler(), "video"))


def test_runtime_audio_drain_selects_newest_fake_datagram() -> None:
    settings = MediaSettings(width=16, height=8)
    connector = SimpleNamespace(
        session=Session("127.0.0.1", "127.0.0.2", 0, settings),
        settings=settings,
        audio_port=19788,
        video_port=19798,
    )
    instance = runtime.LolaLinuxRuntime(
        cast(runtime.LolaConnector, connector), SilenceAudioCapture(settings), MemoryAudioPlayback()
    )
    first = media.build_audio_payload(2, bytes(256))
    newest = media.build_audio_payload(3, bytes(256))

    class DrainSocket:
        calls = 0

        def recvfrom(self, _size: int) -> tuple[bytes, tuple[str, int]]:
            self.calls += 1
            if self.calls == 1:
                return newest, ("127.0.0.2", 19788)
            raise BlockingIOError

    assert instance._drain_audio_to_newest(cast(socket.socket, DrainSocket()), first, ("127.0.0.2", 19788)) == (
        newest,
        ("127.0.0.2", 19788),
    )
    assert instance.stats.audio_rx_kernel_dropped == 1


def test_selftest_assertions_distinguish_video_and_memory_failures() -> None:
    audio_only = SimpleNamespace(
        runtime=SimpleNamespace(stats=RuntimeStats(audio_rx=1, video_rx=0)),
        audio=MemoryAudioPlayback(),
        video=MemoryVideoDisplay(),
    )
    audio_only.audio.blocks.append((1, b"pcm"))
    with pytest.raises(AssertionError, match="video did not flow"):
        selftest._assert_bidirectional_media(audio_only, audio_only)

    no_sinks = SimpleNamespace(
        runtime=SimpleNamespace(stats=RuntimeStats(audio_rx=1, video_rx=1)),
        audio=MemoryAudioPlayback(),
        video=MemoryVideoDisplay(),
    )
    with pytest.raises(AssertionError, match="memory sinks"):
        selftest._assert_bidirectional_media(no_sinks, no_sinks)


def test_pattern_capture_rejects_non_raw_and_advances_deterministically() -> None:
    raw = backends.PatternVideoCapture(MediaSettings(width=2, height=1))
    assert asyncio.run(raw.read_frame()) == b"\x00\x01"
    assert asyncio.run(raw.read_frame()) == b"\x01\x02"
    with pytest.raises(ValueError, match="8-bit mono"):
        asyncio.run(backends.PatternVideoCapture(MediaSettings(width=2, height=1, bits_per_pixel=16)).read_frame())


def test_connector_status_timeout_preserves_dialect_and_response_metadata() -> None:
    state = connector_module._StatusProbeState(
        connector_module._ControlReceiveStats(malformed_datagrams=2)
    )
    state.response_ip = "127.0.0.9"
    state.response_kind = "broken"
    result = connector_module._status_timeout_result(state, ("ascii", "osc15"))
    assert not result
    assert (result.reason, result.response_ip, result.response_kind, result.sent_dialects) == (
        "malformed-response",
        "127.0.0.9",
        "broken",
        ("ascii", "osc15"),
    )
    rejected = connector_module._rejected_quickconn_result(
        ControlMessage("MESG_REJECT", {"TXT": "no"}, ""),
        ("127.0.0.2", 7000),
        state.stats,
    )
    assert (rejected.reason, rejected.response_text, rejected.response_ip) == ("rejected", "no", "127.0.0.2")


def test_runtime_start_state_enablement_and_fake_socket_cleanup_are_local() -> None:
    settings = MediaSettings(width=16, height=8)
    connector = SimpleNamespace(session=None, settings=settings, audio_port=1, video_port=2, control_port=3)
    instance = runtime.LolaLinuxRuntime(
        cast(runtime.LolaConnector, connector), SilenceAudioCapture(settings), MemoryAudioPlayback()
    )
    with pytest.raises(RuntimeError, match="no active"):
        instance._validate_start_state()
    connector.session = Session("127.0.0.1", "127.0.0.2", 0, settings)
    instance._configure_tx_enablement(transmit_audio=True, transmit_video=False)
    assert instance._audio_tx_enabled.is_set() and not instance._video_tx_enabled.is_set()
    instance._configure_tx_enablement(transmit_audio=False, transmit_video=True)
    assert not instance._audio_tx_enabled.is_set() and instance._video_tx_enabled.is_set()

    class SocketDouble:
        def __init__(self, number: int) -> None:
            self.number = number
            self.closed = False

        def fileno(self) -> int:
            return self.number

        def close(self) -> None:
            self.closed = True

    sockets = [SocketDouble(number) for number in (11, 12, 13)]
    instance._audio_sock, instance._video_sock, instance._control_sock = cast(tuple[socket.socket, socket.socket, socket.socket], tuple(sockets))
    instance._close_sockets()
    assert all(sock.closed for sock in sockets)
    assert (instance._audio_sock, instance._video_sock, instance._control_sock) == (None, None, None)


def test_cli_build_runtime_selects_process_sinks_without_starting_processes() -> None:
    settings = MediaSettings(width=16, height=8)
    connector = SimpleNamespace(session=None, settings=settings, audio_port=1, video_port=2, control_port=3)
    args = argparse.Namespace(
        audio_playback_cmd="ffplay -nodisp",
        video_display_cmd="ffplay -video",
        audio_frames_per_callback=64,
        audio_interval_scale=1.25,
        audio_capture_cmd=None,
        test_media=None,
        tone_amplitude=0.1,
        tone_frequency=440.0,
    )
    built = cli.build_runtime(args, cast(cli.LolaConnector, connector), settings, None)
    assert isinstance(built.audio_capture, SilenceAudioCapture)
    assert isinstance(built.audio_playback, backends.ProcessAudioPlayback)
    assert isinstance(built.video_display, backends.ProcessVideoDisplay)
    assert built.audio_interval_scale == 1.25
    assert built.audio_playback.block_bytes == 256


def test_cli_run_establishes_both_session_modes_and_receives_when_requested(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    settings = MediaSettings(width=16, height=8)
    session = Session("127.0.0.1", "127.0.0.2", 4, settings)
    events: list[tuple[str, object]] = []

    class ConnectorDouble:
        async def accept_once(self) -> Session:
            events.append(("accept", None))
            return session

        async def initiate(self, remote_ip: str, sid: int) -> Session:
            events.append(("initiate", (remote_ip, sid)))
            return session

        async def recv_media_forever(self) -> None:
            events.append(("receive", None))

    connector = ConnectorDouble()
    monkeypatch.setattr(cli, "connector_from_args", lambda _args: cast(cli.LolaConnector, connector))
    listen = argparse.Namespace(
        mode="listen",
        rx=True,
        test_media=None,
        audio_capture_cmd=None,
        audio_playback_cmd=None,
        video_capture_cmd=None,
        video_display_cmd=None,
    )
    connect = argparse.Namespace(**(vars(listen) | {"mode": "connect", "remote_ip": "127.0.0.2", "sid": 4}))
    asyncio.run(cli.run(listen))
    asyncio.run(cli.run(connect))
    assert events == [
        ("accept", None),
        ("receive", None),
        ("initiate", ("127.0.0.2", 4)),
        ("receive", None),
    ]


def test_media_reassembler_rejects_short_complete_coverage() -> None:
    reassembler = media.MediaReassembler()
    reassembler.begin(3, 3, 2)
    assert reassembler.add(media.Fragment(3, 2, 0, 0, 1, 0, b"a")) is None
    with pytest.raises(ValueError, match="does not match"):
        reassembler.add(media.Fragment(3, 2, 1, 1, 1, 1, b"b"))
    assert reassembler.frame_id is None


def test_relay_validates_arguments_and_preserves_tshark_command_shape() -> None:
    args = _relay_args()
    command = relay.build_tshark_command(args)
    assert command.argv[:4] == ["tshark", "-l", "-i", "4"]
    assert any("udp.srcport==19788" in argument for argument in command.arguments)
    assert relay.tshark_executable_name(r"C:\\Tools\\TSHARK.EXE") == "tshark.exe"
    for value, name, message in [
        ("", "interface", "must not be empty"),
        ("line\nfeed", "interface", "control characters"),
    ]:
        with pytest.raises(ValueError, match=message):
            relay.validate_process_argument(value, name)
    for port in (0, 65_536):
        with pytest.raises(ValueError, match="between 1"):
            relay.validate_udp_port(port, "port")
    with pytest.raises(ValueError, match="default Wireshark"):
        relay.validate_tshark_executable("capture.exe")
    invalid = _relay_args()
    invalid.stats_interval = 0.0
    with pytest.raises(ValueError, match="stats-interval"):
        relay.validate_relay_args(invalid)


def test_relay_open_and_stats_paths_use_only_fake_sockets(monkeypatch: pytest.MonkeyPatch) -> None:
    class SocketDouble:
        def __init__(self) -> None:
            self.blocking: list[bool] = []

        def setblocking(self, value: bool) -> None:
            self.blocking.append(value)

        def close(self) -> None:
            return None

    sockets = [SocketDouble(), SocketDouble()]
    monkeypatch.setattr(relay.socket, "socket", lambda *_args: sockets.pop(0))
    opened = relay.open_relay_sockets()
    assert opened.video.blocking == [False]
    assert opened.audio.blocking == [False]
    args = _relay_args()
    state = relay.RelayState(counts={args.audio_port: 4, args.video_port: 5}, last_stats=10.0)
    monkeypatch.setattr(relay.time, "monotonic", lambda: 11.0)
    relay.log_relay_stats_if_due(args, state)
    assert state.last_stats == 10.0


def test_relay_capture_lines_skips_invalid_data_and_routes_fakes(monkeypatch: pytest.MonkeyPatch) -> None:
    args = _relay_args()
    sockets = relay.RelaySockets(
        audio=cast(socket.socket, _RelaySocketDouble()),
        video=cast(socket.socket, _RelaySocketDouble()),
    )

    class StreamDouble:
        def __init__(self) -> None:
            self.lines = iter((b"\n", b"bad\tzz\n", b"19788\t01:02\n", b""))

        async def readline(self) -> bytes:
            return next(self.lines)

    calls: list[dict[int, int]] = []
    monkeypatch.setattr(relay, "log_relay_stats_if_due", lambda _args, state: calls.append(dict(state.counts)))
    asyncio.run(relay.relay_capture_lines(cast(asyncio.StreamReader, StreamDouble()), args, sockets))
    assert cast(_RelaySocketDouble, sockets.audio).sent == [(b"\x01\x02", (args.dst_ip, args.audio_port))]
    assert calls == [{args.audio_port: 1, args.video_port: 0}]


def test_relay_wait_stop_and_kill_fallbacks_are_fake_only(monkeypatch: pytest.MonkeyPatch) -> None:
    class ProcessDouble:
        def __init__(self, returncode: int | None = None) -> None:
            self.returncode = returncode
            self.events: list[str] = []

        async def wait(self) -> int:
            self.events.append("wait")
            return 0

        def terminate(self) -> None:
            self.events.append("terminate")

        def kill(self) -> None:
            self.events.append("kill")

    proc = ProcessDouble()

    async def timed_out(_awaitable: object, *, timeout: float) -> int:
        close = getattr(_awaitable, "close", None)
        if close is not None:
            close()
        assert timeout == 3
        raise asyncio.TimeoutError

    monkeypatch.setattr(relay.asyncio, "wait_for", timed_out)
    assert not asyncio.run(relay._wait_for_relay_process_exit(cast(asyncio.subprocess.Process, proc)))

    already_stopped = ProcessDouble(returncode=0)
    asyncio.run(relay.stop_relay_process(cast(asyncio.subprocess.Process, already_stopped)))
    assert already_stopped.events == ["wait"]

    outcomes = iter((False, False))

    async def fake_wait(_proc: asyncio.subprocess.Process) -> bool:
        return next(outcomes)

    monkeypatch.setattr(relay, "_wait_for_relay_process_exit", fake_wait)
    asyncio.run(relay.stop_relay_process(cast(asyncio.subprocess.Process, proc)))
    assert proc.events == ["terminate", "kill"]


def test_relay_run_cleanup_covers_startup_and_stdout_failures(monkeypatch: pytest.MonkeyPatch) -> None:
    args = _relay_args()
    sockets = relay.RelaySockets(
        audio=cast(socket.socket, _RelaySocketDouble()),
        video=cast(socket.socket, _RelaySocketDouble()),
    )
    command = relay.RelayProcessCommand("tshark", "tshark", ("-l",))
    events: list[str] = []

    monkeypatch.setattr(relay, "build_tshark_command", lambda _args: command)
    monkeypatch.setattr(relay, "open_relay_sockets", lambda: sockets)
    monkeypatch.setattr(relay, "close_relay_sockets", lambda _sockets: events.append("close"))

    async def failed_start(_command: relay.RelayProcessCommand) -> asyncio.subprocess.Process:
        raise OSError("missing tshark")

    monkeypatch.setattr(relay, "start_tshark_capture", failed_start)
    with pytest.raises(OSError, match="missing tshark"):
        asyncio.run(relay.run_relay(args))
    assert events == ["close"]

    proc = cast(asyncio.subprocess.Process, SimpleNamespace(stdout=None))

    async def started(_command: relay.RelayProcessCommand) -> asyncio.subprocess.Process:
        return proc

    async def stopped(received: asyncio.subprocess.Process) -> None:
        assert received is proc
        events.append("stop")

    monkeypatch.setattr(relay, "start_tshark_capture", started)
    monkeypatch.setattr(relay, "stop_relay_process", stopped)
    with pytest.raises(RuntimeError, match="did not expose stdout"):
        asyncio.run(relay.run_relay(args))
    assert events == ["close", "stop", "close"]


def test_relay_parser_and_capture_start_are_fake_only(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        sys,
        "argv",
        ["relay", "--interface", "Npcap", "--audio-port", "7001", "--stats-interval", "3.5"],
    )
    parsed = relay.parse_args()
    assert (parsed.interface, parsed.audio_port, parsed.stats_interval) == ("Npcap", 7001, 3.5)

    command = relay.RelayProcessCommand("tshark", "tshark", ("-l", "-i", "Npcap"))
    events: list[object] = []
    proc = cast(asyncio.subprocess.Process, SimpleNamespace(stdout=object()))

    async def create_process(*argv: object, **kwargs: object) -> asyncio.subprocess.Process:
        events.append((argv, kwargs))
        return proc

    monkeypatch.setattr(relay, "resolve_tshark_executable", lambda _command: "/fake/tshark")
    monkeypatch.setattr(relay.asyncio, "create_subprocess_exec", create_process)
    assert asyncio.run(relay.start_tshark_capture(command)) is proc
    argv, kwargs = cast(tuple[tuple[object, ...], dict[str, object]], events[0])
    assert argv == ("/fake/tshark", "-l", "-i", "Npcap")
    assert kwargs == {"stdout": relay.PIPE, "stderr": relay.DEVNULL}


def test_relay_stop_success_and_default_resolution_are_local(monkeypatch: pytest.MonkeyPatch) -> None:
    class ProcessDouble:
        returncode: int | None = None

        def __init__(self) -> None:
            self.events: list[str] = []

        def terminate(self) -> None:
            self.events.append("terminate")

        def kill(self) -> None:
            self.events.append("kill")

        async def wait(self) -> int:
            self.events.append("wait")
            return 0

    proc = ProcessDouble()
    asyncio.run(relay.stop_relay_process(cast(asyncio.subprocess.Process, proc)))
    assert proc.events == ["terminate", "wait"]
    assert relay.resolve_tshark_executable(
        relay.RelayProcessCommand(relay.DEFAULT_TSHARK, "tshark.exe", ("-l",))
    ) == relay.DEFAULT_TSHARK
    monkeypatch.setattr(relay.shutil, "which", lambda _name: "/fake/tshark")
    assert relay.resolve_tshark_executable(relay.RelayProcessCommand("tshark", "tshark", ("-l",))) == "/fake/tshark"


def test_relay_capture_start_rejects_unbuffered_and_control_character_commands() -> None:
    with pytest.raises(ValueError, match="line-buffered"):
        asyncio.run(relay.start_tshark_capture(relay.RelayProcessCommand("tshark", "tshark", ("-i", "4"))))
    with pytest.raises(ValueError, match="control characters"):
        asyncio.run(relay.start_tshark_capture(relay.RelayProcessCommand("tshark", "tshark", ("-l", "bad\n"))))


def test_relay_video_success_and_jpeg_constructor_bounds_are_local() -> None:
    args = _relay_args()
    video = _RelaySocketDouble()
    sockets = relay.RelaySockets(audio=cast(socket.socket, _RelaySocketDouble()), video=cast(socket.socket, video))
    counts = {args.audio_port: 0, args.video_port: 0}
    relay.relay_payload(relay.CapturedUdpPayload(args.video_port, b"video"), args, sockets, counts)
    assert video.sent == [(b"video", (args.dst_ip, args.video_port))]
    assert counts[args.video_port] == 1
    with pytest.raises(ValueError, match="must be positive"):
        backends.ProcessJpegVideoCapture("ffmpeg", max_frame_bytes=0)


def test_process_backend_read_cleanup_and_exit_error_paths_use_fakes(monkeypatch: pytest.MonkeyPatch) -> None:
    playback = backends.ProcessAudioPlayback("ffplay")
    events: list[str] = []

    async def closed(*, close_stdin: bool = False) -> None:
        events.append(f"close:{close_stdin}")

    monkeypatch.setattr(playback, "_close_process", closed)

    class BrokenReader:
        async def read(self, _size: int) -> bytes:
            raise OSError("read failure")

    with pytest.raises(OSError, match="read failure"):
        asyncio.run(playback._read_or_cleanup(cast(asyncio.StreamReader, BrokenReader()), 8))
    assert events == ["close:False"]

    playback.process = cast(asyncio.subprocess.Process, SimpleNamespace(returncode=12))
    with pytest.raises(RuntimeError, match="exit 12"):
        asyncio.run(playback._raise_if_process_exited("player", "writing"))
    assert events == ["close:False", "close:False"]


def test_runtime_cleanup_helpers_collect_fake_backend_and_task_errors() -> None:
    settings = MediaSettings(width=16, height=8)
    connector = SimpleNamespace(session=None, settings=settings, audio_port=1, video_port=2, control_port=3)

    class FailingBackend:
        async def aclose(self) -> None:
            raise OSError("close failed")

    async def exercise() -> list[Exception]:
        instance = runtime.LolaLinuxRuntime(
            cast(runtime.LolaConnector, connector), FailingBackend(), FailingBackend()
        )

        async def fails() -> None:
            raise ValueError("task failed")

        instance._tasks = [asyncio.create_task(fails())]
        task_errors = await instance._drain_runtime_tasks("fake failure")
        backend_errors = await instance._close_backends_collecting_errors()
        return task_errors + backend_errors

    errors = asyncio.run(exercise())
    assert [str(error) for error in errors] == ["task failed", "close failed", "close failed"]
