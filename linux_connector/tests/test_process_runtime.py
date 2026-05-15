from __future__ import annotations

import argparse
import asyncio
import logging
import socket
import sys
from pathlib import Path

import pytest
from pytest import LogCaptureFixture

import linux_connector.lola_connector.backends as backends
import linux_connector.lola_connector.connector as connector_module
from linux_connector.env.npcap_udp_relay import send_payload_nonblocking
from linux_connector.lola_connector.backends import (
    MemoryAudioPlayback,
    ProcessAudioCapture,
    ProcessAudioPlayback,
    ProcessJpegVideoCapture,
    ProcessRawVideoCapture,
    ProcessVideoDisplay,
    SilenceAudioCapture,
    split_command,
)
from linux_connector.lola_connector.cli import build_parser, build_video_capture, run as run_cli, validate_cli_args
from linux_connector.lola_connector.connector import LolaConnector, Session
from linux_connector.lola_connector.protocol import MediaSettings
from linux_connector.lola_connector.runtime import LolaLinuxRuntime
from linux_connector.lola_connector.selftest import (
    run_bidirectional_selftest,
    run_control_handshake_selftest,
)


def require_loopback_alias(ip: str = "127.0.0.2") -> None:
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.bind((ip, 0))
    except OSError as exc:
        pytest.skip(f"loopback alias {ip} is not available: {exc}")
    finally:
        sock.close()


def test_connector_audio_signal_request_is_event_owned() -> None:
    connector = LolaConnector("127.0.0.1", MediaSettings(width=16, height=8))

    assert not hasattr(connector, "audio_signal_requested")


def test_cli_exposes_remote_signal_flags_without_getattr_fallbacks() -> None:
    parser = build_parser()
    listen_args = parser.parse_args(["--local-ip", "127.0.0.1", "listen"])
    connect_args = parser.parse_args(["--local-ip", "127.0.0.1", "connect", "127.0.0.2"])
    source_name_args = parser.parse_args(["--local-ip", "127.0.0.1", "--source-name", "lab-peer", "status", "127.0.0.2"])

    assert listen_args.wait_for_remote_test_signal is False
    assert listen_args.request_remote_audio_signal is False
    assert connect_args.wait_for_remote_test_signal is False
    assert connect_args.request_remote_audio_signal is False
    assert source_name_args.source_name == "lab-peer"


def test_cli_default_media_and_timing_values_pass_bounds_validation() -> None:
    parser = build_parser()
    args = parser.parse_args(["--local-ip", "127.0.0.1", "connect", "127.0.0.2", "--duration", "0.25"])

    validate_cli_args(args)


@pytest.mark.parametrize(
    ("arguments", "message"),
    [
        (["--sr", "0"], "sample_rate"),
        (["--channels", "9"], "audio callback block"),
        (["--width", "8192", "--height", "8192"], "raw video frame"),
        (["--fps", "0"], "fps"),
        (["--audio-interval-scale", "nan"], "audio_interval_scale"),
        (["--audio-frames-per-callback", "4096"], "audio callback block"),
        (["--max-frame-bytes", "0"], "max_frame_bytes"),
        (["--packet-size", "999999"], "packet_size"),
    ],
)
def test_cli_rejects_unbounded_media_values(arguments: list[str], message: str) -> None:
    parser = build_parser()
    args = parser.parse_args(["--local-ip", "127.0.0.1", *arguments, "connect", "127.0.0.2"])

    with pytest.raises(ValueError, match=message):
        validate_cli_args(args)


@pytest.mark.parametrize(
    ("arguments", "message"),
    [
        (["selftest", "--duration", "0"], "duration"),
        (["status", "127.0.0.2", "--timeout", "inf"], "timeout"),
        (["connect", "127.0.0.2", "--duration", "-1"], "duration"),
        (["connect", "127.0.0.2", "--tone-frequency", "nan"], "tone_frequency"),
        (["connect", "127.0.0.2", "--tone-amplitude", "2"], "tone_amplitude"),
    ],
)
def test_cli_rejects_unbounded_timing_values(arguments: list[str], message: str) -> None:
    parser = build_parser()
    args = parser.parse_args(["--local-ip", "127.0.0.1", *arguments])

    with pytest.raises(ValueError, match=message):
        validate_cli_args(args)


def test_cli_selftest_dispatch_requires_argparse_defaults() -> None:

    async def run_missing_duration() -> None:
        with pytest.raises(RuntimeError, match="duration"):
            await run_cli(argparse.Namespace(mode="selftest", port_offset=None))

    async def run_missing_port_offset() -> None:
        with pytest.raises(RuntimeError, match="port_offset"):
            await run_cli(argparse.Namespace(mode="selftest", duration=0.01))

    asyncio.run(run_missing_duration())
    asyncio.run(run_missing_port_offset())


def test_cli_passes_configured_jpeg_frame_byte_cap_to_capture_backend() -> None:
    parser = build_parser()
    args = parser.parse_args(
        [
            "--local-ip",
            "127.0.0.1",
            "--compression",
            "1",
            "--video-capture-cmd",
            "dummy",
            "--max-frame-bytes",
            "4096",
            "connect",
            "127.0.0.2",
        ]
    )

    capture = build_video_capture(args, MediaSettings(width=16, height=8, compression=1))

    assert isinstance(capture, ProcessJpegVideoCapture)
    assert capture.max_frame_bytes == 4096


def test_process_command_split_and_jpeg_capture_shape() -> None:

    assert split_command("ffmpeg -f s16le -") == ["ffmpeg", "-f", "s16le", "-"]

    async def run() -> None:
        jpeg = ProcessJpegVideoCapture([
            sys.executable,
            "-c",
            "import sys; sys.stdout.buffer.write(b'noise\\xff\\xd8abc\\xff\\xd9tail'); sys.stdout.flush()",
        ])
        try:
            assert await jpeg.read_frame() == b"\xff\xd8abc\xff\xd9"
        finally:
            await jpeg.aclose()

    asyncio.run(run())


def test_process_jpeg_video_capture_rejects_unbounded_buffer() -> None:

    async def run() -> None:
        jpeg = ProcessJpegVideoCapture([
            sys.executable,
            "-c",
            "import sys; sys.stdout.buffer.write(b'\\xff\\xd8' + (b'x' * 8)); sys.stdout.flush()",
        ], max_frame_bytes=8)
        try:
            with pytest.raises(ValueError, match="JPEG frame exceeds"):
                await jpeg.read_frame()
        finally:
            await jpeg.aclose()

    asyncio.run(run())


def test_process_jpeg_video_capture_caps_current_frame_only() -> None:
    source = Path("linux_connector/lola_connector/backends.py").read_text(encoding="utf-8")
    jpeg = ProcessJpegVideoCapture(["dummy"], max_frame_bytes=6)
    jpeg._buffer.extend(b"\xff\xd8aa\xff\xd9\xff\xd8bb\xff\xd9")

    assert "class JpegFrameExtractor:" in source
    assert "self._extractor.extract_frame()" in source
    assert jpeg._extract_frame() == b"\xff\xd8aa\xff\xd9"
    assert jpeg._extract_frame() == b"\xff\xd8bb\xff\xd9"


def test_process_raw_video_capture_frame_size() -> None:
    settings = MediaSettings(width=32, height=16, bits_per_pixel=8)
    capture = ProcessRawVideoCapture(["dummy"], settings)
    assert capture.frame_size == 512


def test_process_audio_playback_reports_dead_subprocess() -> None:

    async def run() -> None:
        playback = ProcessAudioPlayback([sys.executable, "-c", "import sys; sys.exit(0)"])
        await playback.start()
        await asyncio.sleep(0.05)
        with pytest.raises(RuntimeError, match="audio playback process died"):
            await playback.write_block(b"pcm", sequence=1)

    asyncio.run(run())


def test_process_audio_capture_reports_silent_subprocess_exit() -> None:

    async def run() -> None:
        settings = MediaSettings()
        capture = ProcessAudioCapture([sys.executable, "-c", "import sys; sys.exit(0)"], settings)
        await capture.start()
        await asyncio.sleep(0.05)
        with pytest.raises(RuntimeError, match="audio capture process died"):
            await capture.read_block()

    asyncio.run(run())


def test_process_audio_capture_tracks_and_cleans_stdoutless_subprocess(monkeypatch: pytest.MonkeyPatch) -> None:

    class StdoutlessProcess:
        stdout = None
        returncode = None

        def __init__(self) -> None:
            self.killed = False
            self.waited = False

        def kill(self) -> None:
            self.killed = True

        async def wait(self) -> int:
            self.waited = True
            self.returncode = -9
            return self.returncode

    async def create_stdoutless_process(*_args: str, stdout: int) -> StdoutlessProcess:
        assert stdout is backends.PIPE
        return process

    process = StdoutlessProcess()
    monkeypatch.setattr(backends.asyncio, "create_subprocess_exec", create_stdoutless_process)

    async def run() -> None:
        capture = ProcessAudioCapture(["dummy"], MediaSettings())
        with pytest.raises(RuntimeError, match="did not expose stdout"):
            await capture.start()

        assert process.killed
        assert process.waited
        assert capture.process is None

    asyncio.run(run())


def test_process_audio_capture_preserves_start_error_when_cleanup_fails(monkeypatch: pytest.MonkeyPatch) -> None:

    class CleanupFailingStdoutlessProcess:
        stdout = None
        returncode = None

        def __init__(self) -> None:
            self.killed = False

        def kill(self) -> None:
            self.killed = True

        async def wait(self) -> int:
            raise OSError("wait failed")

    async def create_stdoutless_process(*_args: str, stdout: int) -> CleanupFailingStdoutlessProcess:
        assert stdout is backends.PIPE
        return process

    process = CleanupFailingStdoutlessProcess()
    monkeypatch.setattr(backends.asyncio, "create_subprocess_exec", create_stdoutless_process)

    async def run() -> None:
        capture = ProcessAudioCapture(["dummy"], MediaSettings())
        with pytest.raises(RuntimeError, match="did not expose stdout") as raised:
            await capture.start()

        assert process.killed
        assert capture.process is None
        assert any(
            "audio capture process cleanup failed" in note
            for note in getattr(raised.value, "__notes__", [])
        )

    asyncio.run(run())


def test_process_video_capture_tracks_and_cleans_stdoutless_subprocess(monkeypatch: pytest.MonkeyPatch) -> None:

    class StdoutlessProcess:
        stdout = None
        returncode = None

        def __init__(self) -> None:
            self.killed = False
            self.waited = False

        def kill(self) -> None:
            self.killed = True

        async def wait(self) -> int:
            self.waited = True
            self.returncode = -9
            return self.returncode

    async def create_stdoutless_process(*_args: str, stdout: int) -> StdoutlessProcess:
        assert stdout is backends.PIPE
        process = processes.pop(0)
        created.append(process)
        return process

    processes = [StdoutlessProcess(), StdoutlessProcess()]
    created: list[StdoutlessProcess] = []
    monkeypatch.setattr(backends.asyncio, "create_subprocess_exec", create_stdoutless_process)

    async def run() -> None:
        raw = ProcessRawVideoCapture(["dummy"], MediaSettings(width=16, height=8, bits_per_pixel=8))
        with pytest.raises(RuntimeError, match="raw video capture process did not expose stdout"):
            await raw.start()

        assert len(created) == 1
        assert created[0].killed
        assert created[0].waited
        assert len(processes) == 1
        assert raw.process is None

        jpeg = ProcessJpegVideoCapture(["dummy"])
        with pytest.raises(RuntimeError, match="JPEG video capture process did not expose stdout"):
            await jpeg.start()

        assert len(created) == 2
        assert created[1].killed
        assert created[1].waited
        assert len(processes) == 0
        assert jpeg.process is None

    asyncio.run(run())


def test_process_video_capture_cleans_up_after_early_exit() -> None:

    async def run() -> None:
        settings = MediaSettings(width=16, height=8, bits_per_pixel=8)
        raw = ProcessRawVideoCapture([sys.executable, "-c", "import sys; sys.exit(0)"], settings)
        with pytest.raises(RuntimeError, match="raw video capture process died"):
            await raw.read_frame()
        assert raw.process is None

        jpeg = ProcessJpegVideoCapture([sys.executable, "-c", "import sys; sys.exit(0)"])
        with pytest.raises((EOFError, RuntimeError), match="JPEG"):
            await jpeg.read_frame()
        assert jpeg.process is None

    asyncio.run(run())


def test_process_lifecycle_logs_suppressed_cleanup_oserror(caplog: LogCaptureFixture) -> None:

    class TerminateFailingProcess:
        stdin = None

        def terminate(self) -> None:
            raise OSError("terminate failed")

        async def wait(self) -> int:
            return 0

    class ManagedProcess(backends.ProcessLifecycleMixin):
        def __init__(self) -> None:
            self.process = TerminateFailingProcess()

    async def run() -> None:
        managed = ManagedProcess()
        await managed._close_process()
        assert managed.process is None

    caplog.set_level(logging.DEBUG, logger="linux_connector.lola_connector.backends")
    asyncio.run(run())

    assert "suppressed process terminate failure during cleanup" in caplog.text


def test_process_audio_capture_uses_specific_exception_handlers() -> None:
    source = Path("linux_connector/lola_connector/backends.py").read_text(encoding="utf-8")

    assert "except asyncio.CancelledError as original:" in source
    assert "except (OSError, RuntimeError) as original:" in source
    assert "await self._cleanup_failed_start(process, original, \"audio capture\")" in source
    assert "await self._cleanup_failed_start(process, original, \"raw video capture\")" in source
    assert "await self._cleanup_failed_start(process, original, \"JPEG video capture\")" in source
    assert "except Exception:" not in source


def test_udp_socket_helpers_serialize_same_direction_fallbacks() -> None:
    source = Path("linux_connector/lola_connector/connector.py").read_text(encoding="utf-8")

    assert "_socket_read_locks" in source
    assert "_socket_write_locks" in source
    assert "async with _socket_lock(_socket_read_locks, sock)" in source
    assert "async with _socket_lock(_socket_write_locks, sock)" in source
    assert "def unregister_udp_socket(sock: socket.socket) -> None:" in source
    assert "def close_udp_socket(sock: socket.socket) -> None:" in source
    assert "loop.add_reader(sock.fileno(), readable)" in source
    assert "loop.add_writer(sock.fileno(), writable)" in source


def test_udp_socket_lock_registries_shrink_after_close() -> None:
    connector = LolaConnector("127.0.0.1", MediaSettings())
    connector_module._socket_read_locks.clear()
    connector_module._socket_write_locks.clear()

    for _ in range(8):
        sock = connector.make_udp_socket(0)
        fileno = sock.fileno()
        connector_module._socket_lock(connector_module._socket_read_locks, sock)
        connector_module._socket_lock(connector_module._socket_write_locks, sock)
        assert fileno in connector_module._socket_read_locks
        assert fileno in connector_module._socket_write_locks

        connector_module.close_udp_socket(sock)

        assert fileno not in connector_module._socket_read_locks
        assert fileno not in connector_module._socket_write_locks


def test_runtime_stop_reraises_task_failures_after_cleanup() -> None:

    async def run() -> None:
        connector = LolaConnector("127.0.0.1", MediaSettings())
        runtime = LolaLinuxRuntime(
            connector,
            SilenceAudioCapture(MediaSettings()),
            MemoryAudioPlayback(),
        )

        async def fail() -> None:
            raise RuntimeError("background failure")

        runtime._tasks.append(asyncio.create_task(fail()))
        await asyncio.sleep(0)
        with pytest.raises(ExceptionGroup, match="runtime task failed during stop"):
            await runtime.stop()
        assert runtime._tasks == []

    asyncio.run(run())


def test_runtime_start_failure_closes_partial_socket_and_backend_setup() -> None:

    class FakeSocket:
        def __init__(self) -> None:
            self.closed = False

        def close(self) -> None:
            self.closed = True

    class ClosableAudioCapture(SilenceAudioCapture):
        def __init__(self, settings: MediaSettings) -> None:
            super().__init__(settings)
            self.closed = False

        async def aclose(self) -> None:
            self.closed = True

    class ClosablePlayback(MemoryAudioPlayback):
        def __init__(self) -> None:
            super().__init__()
            self.closed = False

        async def aclose(self) -> None:
            self.closed = True

    class ClosableVideoCapture:
        def __init__(self) -> None:
            self.closed = False

        async def read_frame(self) -> bytes:
            return b"frame"

        async def aclose(self) -> None:
            self.closed = True

    class ClosableVideoDisplay:
        def __init__(self) -> None:
            self.closed = False

        async def show_frame(self, frame: bytes, sequence: int, compressed: bool) -> None:
            _ = frame
            _ = sequence
            _ = compressed

        async def aclose(self) -> None:
            self.closed = True

    async def run_case(fail_on_call: int) -> None:
        settings = MediaSettings()
        connector = LolaConnector("127.0.0.1", settings)
        connector.session = Session("127.0.0.1", "127.0.0.2", 1, settings)
        sockets: list[FakeSocket] = []

        def make_udp_socket(bind_port: int = 0) -> FakeSocket:
            _ = bind_port
            if len(sockets) + 1 == fail_on_call:
                raise OSError("socket setup failed")
            sock = FakeSocket()
            sockets.append(sock)
            return sock

        connector.make_udp_socket = make_udp_socket  # type: ignore[method-assign]
        audio_capture = ClosableAudioCapture(settings)
        audio_playback = ClosablePlayback()
        video_capture = ClosableVideoCapture()
        video_display = ClosableVideoDisplay()
        runtime = LolaLinuxRuntime(connector, audio_capture, audio_playback, video_capture, video_display)

        with pytest.raises(OSError, match="socket setup failed"):
            await runtime.start()

        assert sockets
        assert all(sock.closed for sock in sockets)
        assert runtime._tasks == []
        assert runtime._audio_sock is None
        assert runtime._video_sock is None
        assert runtime._control_sock is None
        assert audio_capture.closed
        assert audio_playback.closed
        assert video_capture.closed
        assert video_display.closed

    asyncio.run(run_case(fail_on_call=2))
    asyncio.run(run_case(fail_on_call=3))


def test_process_backends_raise_runtime_error_when_start_leaves_process_unset() -> None:

    settings = MediaSettings(width=32, height=16, bits_per_pixel=8)

    class UnreadyAudioPlayback(ProcessAudioPlayback):
        async def start(self) -> None:
            pass

    class UnreadyRawVideoCapture(ProcessRawVideoCapture):
        async def start(self) -> None:
            pass

    class UnreadyJpegVideoCapture(ProcessJpegVideoCapture):
        async def start(self) -> None:
            pass

    class UnreadyVideoDisplay(ProcessVideoDisplay):
        async def start(self) -> None:
            pass

    async def run() -> None:
        with pytest.raises(RuntimeError, match="audio playback process is not ready"):
            await UnreadyAudioPlayback(["dummy"]).write_block(b"pcm", sequence=1)
        with pytest.raises(RuntimeError, match="raw video capture process is not ready"):
            await UnreadyRawVideoCapture(["dummy"], settings).read_frame()
        with pytest.raises(RuntimeError, match="JPEG video capture process is not ready"):
            await UnreadyJpegVideoCapture(["dummy"]).read_frame()
        with pytest.raises(RuntimeError, match="video display process is not ready"):
            await UnreadyVideoDisplay(["dummy"]).show_frame(b"frame", sequence=1, compressed=False)

    asyncio.run(run())


def test_bidirectional_udp_runtime_selftest() -> None:

    require_loopback_alias()
    stats_a, stats_b = asyncio.run(run_bidirectional_selftest(seconds=0.12, port_offset=21000))
    assert stats_a.audio_rx > 0
    assert stats_b.audio_rx > 0
    assert stats_a.video_rx > 0
    assert stats_b.video_rx > 0


def test_control_handshake_udp_selftest() -> None:

    require_loopback_alias()
    session_a, session_b = asyncio.run(run_control_handshake_selftest(port_offset=23000))
    assert session_a.remote_ip == "127.0.0.2"
    assert session_b.remote_ip == "127.0.0.1"


def test_npcap_relay_drops_would_block_send() -> None:
    class BlockingSocket:
        def sendto(self, payload: bytes, address: tuple[str, int]) -> int:
            _ = payload
            _ = address
            raise BlockingIOError("send buffer full")

    assert send_payload_nonblocking(BlockingSocket(), b"payload", ("127.0.0.1", 19788)) is False
