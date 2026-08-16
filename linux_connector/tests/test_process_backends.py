"""Tests for Linux process-backed media adapters."""

# pylint: disable=missing-function-docstring

from __future__ import annotations

import asyncio
import logging
from collections.abc import Awaitable, Callable
from functools import partial

import pytest
from pytest import LogCaptureFixture

from linux_connector.lola_connector import backends
from linux_connector.lola_connector.backends import (
    JpegFrameExtractor,
    ProcessAudioCapture,
    ProcessAudioPlayback,
    ProcessJpegVideoCapture,
    ProcessRawVideoCapture,
    ProcessVideoDisplay,
    split_command,
)
from linux_connector.lola_connector.process_commands import ProcessCommand
from linux_connector.lola_connector.protocol import MediaSettings
from linux_connector.tests.support import expect_contains, expect_equal, expect_is_none, expect_not_none, expect_true


def expect_is(actual: object, expected: object, label: str) -> None:
    if actual is not expected:
        pytest.fail(f"{label}: expected {expected!r}, got {actual!r}")


async def assert_writer_backend_reports_dead_subprocess(
    backend: ProcessAudioPlayback | ProcessVideoDisplay,
    operation: Callable[[], Awaitable[None]],
    expected_error: str,
) -> None:
    """Verify a writer backend reports an exited child before accepting data."""
    await backend.start()
    process = expect_not_none(backend.process, "writer backend process")
    try:
        await asyncio.wait_for(process.wait(), timeout=10.0)
        with pytest.raises(RuntimeError, match=expected_error):
            await operation()
    finally:
        await backend.aclose()


class StdoutlessProcess:  # pylint: disable=missing-class-docstring
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


class FakeProcessTransport:  # pylint: disable=missing-class-docstring,too-few-public-methods
    def __init__(self) -> None:
        self.high_water: int | None = None
        self.buffer_size = 0

    def get_write_buffer_size(self) -> int:
        return self.buffer_size

    def set_write_buffer_limits(self, *, high: int) -> None:
        self.high_water = high


class FakeProcessWriter:  # pylint: disable=missing-class-docstring,too-few-public-methods
    def __init__(self) -> None:
        self.transport = FakeProcessTransport()
        self.data = bytearray()
        self.closed = False

    def close(self) -> None:
        self.closed = True

    async def drain(self) -> None:
        self.transport.buffer_size = 0

    def write(self, data: bytes) -> None:
        self.data.extend(data)
        self.transport.buffer_size += len(data)


class FakeProcessReader:  # pylint: disable=missing-class-docstring,too-few-public-methods
    def __init__(self, data: bytes) -> None:
        self.data = bytearray(data)

    async def read(self, size: int) -> bytes:
        chunk = bytes(self.data[:size])
        del self.data[:size]
        return chunk

    async def readexactly(self, size: int) -> bytes:
        chunk = await self.read(size)
        if len(chunk) != size:
            raise asyncio.IncompleteReadError(chunk, size)
        return chunk


class FakeMediaProcess:  # pylint: disable=missing-class-docstring,too-few-public-methods
    def __init__(self, stdout: bytes | None = b"", *, returncode: int | None = None) -> None:
        self.returncode = returncode
        self.stdin = FakeProcessWriter()
        self._done = asyncio.Event()
        if returncode is not None:
            self._done.set()
        if stdout is None:
            self.stdout = None
        else:
            self.stdout = FakeProcessReader(stdout)

    def kill(self) -> None:
        self.returncode = -9
        self._done.set()

    def terminate(self) -> None:
        self.returncode = 0
        self._done.set()

    async def wait(self) -> int:
        await self._done.wait()
        return self.returncode if self.returncode is not None else 0


def inject_stdout_process(monkeypatch: pytest.MonkeyPatch, process: FakeMediaProcess) -> None:
    async def launch(_command: ProcessCommand) -> FakeMediaProcess:
        return process

    monkeypatch.setattr(backends, "launch_stdout_process", launch)


def inject_stdin_process(monkeypatch: pytest.MonkeyPatch, process: FakeMediaProcess) -> None:
    async def launch(_command: ProcessCommand) -> FakeMediaProcess:
        return process

    monkeypatch.setattr(backends, "launch_stdin_process", launch)


def test_process_command_split_and_jpeg_capture_shape(monkeypatch: pytest.MonkeyPatch) -> None:

    expect_equal(
        split_command("ffmpeg -f s16le -"),
        ["ffmpeg", "-f", "s16le", "-"],
        "process command split",
    )

    inject_stdout_process(monkeypatch, FakeMediaProcess(b"noise\xff\xd8abc\xff\xd9tail"))

    async def run() -> None:
        jpeg = ProcessJpegVideoCapture(["ffmpeg"])
        try:
            expect_equal(await jpeg.read_frame(), b"\xff\xd8abc\xff\xd9", "JPEG frame shape")
        finally:
            await jpeg.aclose()

    asyncio.run(run())


def test_process_jpeg_video_capture_rejects_unbounded_buffer(monkeypatch: pytest.MonkeyPatch) -> None:
    inject_stdout_process(monkeypatch, FakeMediaProcess(b"\xff\xd8" + (b"x" * 8)))

    async def run() -> None:
        jpeg = ProcessJpegVideoCapture(["ffmpeg"], max_frame_bytes=8)
        try:
            with pytest.raises(ValueError, match="JPEG frame exceeds"):
                await jpeg.read_frame()
        finally:
            await jpeg.aclose()

    asyncio.run(run())


def test_process_jpeg_video_capture_caps_current_frame_only() -> None:
    extractor = JpegFrameExtractor(max_frame_bytes=6, warn_frame_bytes=100)
    extractor.append(b"\xff\xd8aa\xff\xd9\xff\xd8bb\xff\xd9")

    expect_equal(extractor.extract_frame(), b"\xff\xd8aa\xff\xd9", "first capped JPEG frame")
    expect_equal(extractor.extract_frame(), b"\xff\xd8bb\xff\xd9", "second capped JPEG frame")
    expect_is_none(extractor.extract_frame(), "exhausted capped JPEG frames")


def test_process_raw_video_capture_frame_size() -> None:
    settings = MediaSettings(width=32, height=16, bits_per_pixel=8)
    capture = ProcessRawVideoCapture(["ffmpeg"], settings)
    expect_equal(capture.frame_size, 512, "raw video frame size")


def test_process_video_display_expands_remote_format_placeholders() -> None:
    remote_settings = MediaSettings(width=720, height=576, bits_per_pixel=16, fps=50, compression=0)

    display = ProcessVideoDisplay(
        [
            "ffplay",
            "-video_size",
            "{video_size}",
            "-pixel_format",
            "{pixel_format}",
            "-framerate",
            "{fps}",
            "-bpp",
            "{bpp}",
            "-compression",
            "{compression}",
        ],
        remote_settings,
    )

    expect_equal(
        display.command.argv,
        [
            "ffplay",
            "-video_size",
            "720x576",
            "-pixel_format",
            "gray16le",
            "-framerate",
            "50",
            "-bpp",
            "16",
            "-compression",
            "0",
        ],
        "expanded remote video command",
    )
    expect_equal(display.remote_settings, remote_settings, "immutable remote display settings")


def test_process_audio_playback_reports_dead_subprocess(monkeypatch: pytest.MonkeyPatch) -> None:
    inject_stdin_process(monkeypatch, FakeMediaProcess(returncode=0))

    async def run() -> None:
        playback = ProcessAudioPlayback(["ffplay"])
        await assert_writer_backend_reports_dead_subprocess(
            playback,
            partial(playback.write_block, b"pcm", sequence=1),
            "audio playback process died",
        )

    asyncio.run(run())


def test_process_video_display_reports_dead_subprocess(monkeypatch: pytest.MonkeyPatch) -> None:
    inject_stdin_process(monkeypatch, FakeMediaProcess(returncode=0))

    async def run() -> None:
        display = ProcessVideoDisplay(["ffplay"])
        await assert_writer_backend_reports_dead_subprocess(
            display,
            partial(display.show_frame, b"frame", sequence=1, compressed=False),
            "video display process died",
        )

    asyncio.run(run())


def test_process_write_backends_accept_data_and_close_cleanly(monkeypatch: pytest.MonkeyPatch) -> None:
    processes = [FakeMediaProcess(), FakeMediaProcess()]

    async def launch(_command: ProcessCommand) -> FakeMediaProcess:
        return processes.pop(0)

    monkeypatch.setattr(backends, "launch_stdin_process", launch)

    async def run() -> None:
        playback = ProcessAudioPlayback(["ffplay"])
        await playback.write_block(b"pcm", sequence=1)
        await playback.aclose()
        expect_is_none(playback.process, "closed playback process")

        display = ProcessVideoDisplay(["ffplay"])
        await display.show_frame(b"frame", sequence=1, compressed=False)
        await display.aclose()
        expect_is_none(display.process, "closed display process")

    asyncio.run(run())


def test_process_audio_playback_sets_one_block_stdin_high_water_mark() -> None:
    class Transport:  # pylint: disable=missing-class-docstring,too-few-public-methods
        def __init__(self) -> None:
            self.high_water: int | None = None

        def set_write_buffer_limits(self, *, high: int) -> None:
            self.high_water = high

    class Writer:  # pylint: disable=missing-class-docstring,too-few-public-methods
        def __init__(self) -> None:
            self.transport = Transport()

    class Process:  # pylint: disable=missing-class-docstring,too-few-public-methods
        returncode = None

        def __init__(self) -> None:
            self.stdin = Writer()

    async def run() -> None:
        playback = ProcessAudioPlayback(["ffplay"], block_bytes=256)
        playback.process = Process()  # type: ignore[assignment]
        await playback.start()
        expect_equal(playback.buffered_byte_limit, 256, "audio writer high-water metric")
        expect_equal(
            playback.process.stdin.transport.high_water,  # type: ignore[union-attr]
            256,
            "audio writer high-water",
        )

    asyncio.run(run())


def test_process_audio_capture_reports_silent_subprocess_exit(monkeypatch: pytest.MonkeyPatch) -> None:
    inject_stdout_process(monkeypatch, FakeMediaProcess(returncode=0))

    async def run() -> None:
        settings = MediaSettings()
        capture = ProcessAudioCapture(["ffmpeg"], settings)
        await capture.start()
        await asyncio.sleep(0.05)
        with pytest.raises(RuntimeError, match="audio capture process died"):
            await capture.read_block()

    asyncio.run(run())


def test_process_audio_capture_tracks_and_cleans_stdoutless_subprocess(
    monkeypatch: pytest.MonkeyPatch,
) -> None:

    async def create_stdoutless_process(_command: ProcessCommand) -> StdoutlessProcess:
        return process

    process = StdoutlessProcess()
    monkeypatch.setattr(backends, "launch_stdout_process", create_stdoutless_process)

    async def run() -> None:
        capture = ProcessAudioCapture(["ffmpeg"], MediaSettings())
        with pytest.raises(RuntimeError, match="did not expose stdout"):
            await capture.start()

        expect_true(process.killed, "stdoutless audio capture process killed")
        expect_true(process.waited, "stdoutless audio capture process waited")
        expect_is_none(capture.process, "stdoutless audio capture process state")

    asyncio.run(run())


def test_process_audio_capture_preserves_start_error_when_cleanup_fails(
    monkeypatch: pytest.MonkeyPatch,
) -> None:

    class CleanupFailingStdoutlessProcess:  # pylint: disable=missing-class-docstring
        stdout = None
        returncode = None

        def __init__(self) -> None:
            self.killed = False

        def kill(self) -> None:
            self.killed = True

        async def wait(self) -> int:
            raise OSError("wait failed")

    async def create_stdoutless_process(_command: ProcessCommand) -> CleanupFailingStdoutlessProcess:
        return process

    process = CleanupFailingStdoutlessProcess()
    monkeypatch.setattr(backends, "launch_stdout_process", create_stdoutless_process)

    async def run() -> None:
        capture = ProcessAudioCapture(["ffmpeg"], MediaSettings())
        with pytest.raises(RuntimeError, match="did not expose stdout") as raised:
            await capture.start()

        expect_true(process.killed, "cleanup-failing audio capture process killed")
        expect_is_none(capture.process, "cleanup-failing audio capture process state")
        expect_true(
            any("audio capture process cleanup failed" in note for note in getattr(raised.value, "__notes__", [])),
            "cleanup failure note",
        )

    asyncio.run(run())


def test_process_video_capture_tracks_and_cleans_stdoutless_subprocess(
    monkeypatch: pytest.MonkeyPatch,
) -> None:

    async def create_stdoutless_process(_command: ProcessCommand) -> StdoutlessProcess:
        process = processes.pop(0)
        created.append(process)
        return process

    processes = [StdoutlessProcess(), StdoutlessProcess()]
    created: list[StdoutlessProcess] = []
    monkeypatch.setattr(backends, "launch_stdout_process", create_stdoutless_process)

    async def run() -> None:
        raw = ProcessRawVideoCapture(["ffmpeg"], MediaSettings(width=16, height=8, bits_per_pixel=8))
        with pytest.raises(RuntimeError, match="raw video capture process did not expose stdout"):
            await raw.start()

        expect_equal(len(created), 1, "created raw video process count")
        expect_true(created[0].killed, "stdoutless raw video process killed")
        expect_true(created[0].waited, "stdoutless raw video process waited")
        expect_equal(len(processes), 1, "remaining video process count")
        expect_is_none(raw.process, "stdoutless raw video process state")

        jpeg = ProcessJpegVideoCapture(["ffmpeg"])
        with pytest.raises(RuntimeError, match="JPEG video capture process did not expose stdout"):
            await jpeg.start()

        expect_equal(len(created), 2, "created JPEG video process count")
        expect_true(created[1].killed, "stdoutless JPEG video process killed")
        expect_true(created[1].waited, "stdoutless JPEG video process waited")
        expect_equal(len(processes), 0, "remaining video process count")
        expect_is_none(jpeg.process, "stdoutless JPEG video process state")

    asyncio.run(run())


def test_process_video_capture_cleans_up_after_early_exit(monkeypatch: pytest.MonkeyPatch) -> None:
    processes = [FakeMediaProcess(returncode=0), FakeMediaProcess(returncode=0)]

    async def launch(_command: ProcessCommand) -> FakeMediaProcess:
        return processes.pop(0)

    monkeypatch.setattr(backends, "launch_stdout_process", launch)

    async def run() -> None:
        settings = MediaSettings(width=16, height=8, bits_per_pixel=8)
        raw = ProcessRawVideoCapture(["ffmpeg"], settings)
        with pytest.raises(RuntimeError, match="raw video capture process died"):
            await raw.read_frame()
        expect_is_none(raw.process, "early-exit raw video process state")

        jpeg = ProcessJpegVideoCapture(["ffmpeg"])
        with pytest.raises((EOFError, RuntimeError), match="JPEG"):
            await jpeg.read_frame()
        expect_is_none(jpeg.process, "early-exit JPEG video process state")

    asyncio.run(run())


class TerminateFailingProcess:  # pylint: disable=missing-class-docstring
    stdin = None

    def terminate(self) -> None:
        raise OSError("terminate failed")

    async def wait(self) -> int:
        return 0


class WaitFailingProcess:  # pylint: disable=missing-class-docstring
    stdin = None

    def terminate(self) -> None:
        return None

    async def wait(self) -> int:
        raise OSError("wait failed")


class KillFailingProcess:  # pylint: disable=missing-class-docstring
    stdin = None

    def terminate(self) -> None:
        return None

    def kill(self) -> None:
        raise OSError("kill failed")

    async def wait(self) -> int:
        return 0


# pylint: disable-next=missing-class-docstring,too-few-public-methods
class ManagedProcess(backends.ProcessLifecycleMixin):
    def __init__(self, process: object) -> None:
        """Record process object under lifecycle mixin."""
        self.process = process  # type: ignore[assignment]


async def timeout_wait_for(awaitable: object, timeout: float) -> int:
    _ = timeout
    close = getattr(awaitable, "close", None)
    if close is not None:
        close()
    raise asyncio.TimeoutError


async def assert_cleanup_warning(process: object, expected: str, label: str) -> None:
    managed = ManagedProcess(process)
    close_process = managed._close_process
    await close_process()
    expect_is_none(managed.process, f"{label} process state")
    expect_true(
        any(expected in warning for warning in managed.cleanup_warnings),
        f"{label} cleanup warning",
    )


async def run_suppressed_cleanup_oserror_cases(monkeypatch: pytest.MonkeyPatch) -> None:
    await assert_cleanup_warning(TerminateFailingProcess(), "terminate failed", "terminate-failing")
    await assert_cleanup_warning(WaitFailingProcess(), "wait failed", "wait-failing")

    monkeypatch.setattr(asyncio, "wait_for", timeout_wait_for)
    await assert_cleanup_warning(KillFailingProcess(), "kill failed", "kill-failing")


def test_process_lifecycle_records_suppressed_cleanup_oserror(
    caplog: LogCaptureFixture,
    monkeypatch: pytest.MonkeyPatch,
) -> None:

    caplog.set_level(logging.DEBUG, logger="linux_connector.lola_connector.backends")
    asyncio.run(run_suppressed_cleanup_oserror_cases(monkeypatch))

    expect_contains(
        "suppressed process terminate failure during cleanup",
        caplog.text,
        "cleanup warning log",
    )


def test_process_backends_raise_runtime_error_when_start_leaves_process_unset() -> None:

    settings = MediaSettings(width=32, height=16, bits_per_pixel=8)

    class UnreadyAudioPlayback(ProcessAudioPlayback):  # pylint: disable=missing-class-docstring
        async def start(self) -> None:
            pass

    class UnreadyRawVideoCapture(ProcessRawVideoCapture):  # pylint: disable=missing-class-docstring
        async def start(self) -> None:
            pass

    # pylint: disable-next=missing-class-docstring
    class UnreadyJpegVideoCapture(ProcessJpegVideoCapture):
        async def start(self) -> None:
            pass

    class UnreadyVideoDisplay(ProcessVideoDisplay):  # pylint: disable=missing-class-docstring
        async def start(self) -> None:
            pass

    async def run() -> None:
        with pytest.raises(RuntimeError, match="audio playback process is not ready"):
            await UnreadyAudioPlayback(["ffplay"]).write_block(b"pcm", sequence=1)
        with pytest.raises(RuntimeError, match="raw video capture process is not ready"):
            await UnreadyRawVideoCapture(["ffmpeg"], settings).read_frame()
        with pytest.raises(RuntimeError, match="JPEG video capture process is not ready"):
            await UnreadyJpegVideoCapture(["ffmpeg"]).read_frame()
        with pytest.raises(RuntimeError, match="video display process is not ready"):
            await UnreadyVideoDisplay(["ffplay"]).show_frame(b"frame", sequence=1, compressed=False)

    asyncio.run(run())
