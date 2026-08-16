"""Deterministic coverage for relay lifecycle and process handling branches."""

from __future__ import annotations

import asyncio
import socket
import sys
from types import SimpleNamespace
from typing import cast

import pytest

import linux_connector.env.npcap_udp_relay as relay
from linux_connector.lola_connector import backends
from linux_connector.lola_connector.protocol import MediaSettings
from linux_connector.tests.relay_test_support import RelaySocketDouble, relay_args


def test_relay_validates_arguments_and_preserves_tshark_command_shape() -> None:
    args = relay_args()
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
    invalid = relay_args()
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
    args = relay_args()
    state = relay.RelayState(counts={args.audio_port: 4, args.video_port: 5}, last_stats=10.0)
    monkeypatch.setattr(relay.time, "monotonic", lambda: 11.0)
    relay.log_relay_stats_if_due(args, state)
    assert state.last_stats == 10.0


def test_relay_capture_lines_skips_invalid_data_and_routes_fakes(monkeypatch: pytest.MonkeyPatch) -> None:
    args = relay_args()
    sockets = relay.RelaySockets(
        audio=cast(socket.socket, RelaySocketDouble()),
        video=cast(socket.socket, RelaySocketDouble()),
    )

    class StreamDouble:
        def __init__(self) -> None:
            self.lines = iter((b"\n", b"bad\tzz\n", b"19788\t01:02\n", b""))

        async def readline(self) -> bytes:
            return next(self.lines)

    calls: list[dict[int, int]] = []
    monkeypatch.setattr(relay, "log_relay_stats_if_due", lambda _args, state: calls.append(dict(state.counts)))
    asyncio.run(relay.relay_capture_lines(cast(asyncio.StreamReader, StreamDouble()), args, sockets))
    assert cast(RelaySocketDouble, sockets.audio).sent == [(b"\x01\x02", (args.dst_ip, args.audio_port))]
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
    args = relay_args()
    sockets = relay.RelaySockets(
        audio=cast(socket.socket, RelaySocketDouble()),
        video=cast(socket.socket, RelaySocketDouble()),
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
    assert (
        relay.resolve_tshark_executable(relay.RelayProcessCommand(relay.DEFAULT_TSHARK, "tshark.exe", ("-l",)))
        == relay.DEFAULT_TSHARK
    )
    monkeypatch.setattr(relay.shutil, "which", lambda _name: "/fake/tshark")
    assert relay.resolve_tshark_executable(relay.RelayProcessCommand("tshark", "tshark", ("-l",))) == "/fake/tshark"


def test_relay_capture_start_rejects_unbuffered_and_control_character_commands() -> None:
    with pytest.raises(ValueError, match="line-buffered"):
        asyncio.run(relay.start_tshark_capture(relay.RelayProcessCommand("tshark", "tshark", ("-i", "4"))))
    with pytest.raises(ValueError, match="control characters"):
        asyncio.run(relay.start_tshark_capture(relay.RelayProcessCommand("tshark", "tshark", ("-l", "bad\n"))))


def test_relay_video_success_and_jpeg_constructor_bounds_are_local() -> None:
    args = relay_args()
    video = RelaySocketDouble()
    sockets = relay.RelaySockets(audio=cast(socket.socket, RelaySocketDouble()), video=cast(socket.socket, video))
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
    from linux_connector.lola_connector import runtime

    settings = MediaSettings(width=16, height=8)
    connector = SimpleNamespace(session=None, settings=settings, audio_port=1, video_port=2, control_port=3)

    class FailingBackend:
        async def aclose(self) -> None:
            raise OSError("close failed")

    async def exercise() -> list[Exception]:
        instance = runtime.LolaLinuxRuntime(cast(runtime.LolaConnector, connector), FailingBackend(), FailingBackend())

        async def fails() -> None:
            raise ValueError("task failed")

        instance._tasks = [asyncio.create_task(fails())]
        task_errors = await instance._drain_runtime_tasks("fake failure")
        backend_errors = await instance._close_backends_collecting_errors()
        return task_errors + backend_errors

    errors = asyncio.run(exercise())
    assert [str(error) for error in errors] == ["task failed", "close failed", "close failed"]
