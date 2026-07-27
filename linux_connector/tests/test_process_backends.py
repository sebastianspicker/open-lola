"""Tests for Linux process-backed media adapters."""

# pylint: disable=missing-function-docstring

from __future__ import annotations

import asyncio
import logging
import sys
from asyncio.subprocess import PIPE

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
    make_process_command,
    split_command,
    validate_process_command,
)
from linux_connector.lola_connector.protocol import MediaSettings
from linux_connector.lola_connector.process_commands import ProcessCommand
from linux_connector.lola_connector import process_launch
from linux_connector.tests.support import expect_contains, expect_equal, expect_is_none, expect_true


def expect_is(actual: object, expected: object, label: str) -> None:
    if actual is not expected:
        pytest.fail(f"{label}: expected {expected!r}, got {actual!r}")


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


def test_process_command_split_and_jpeg_capture_shape() -> None:

    expect_equal(
        split_command("ffmpeg -f s16le -"),
        ["ffmpeg", "-f", "s16le", "-"],
        "process command split",
    )

    async def run() -> None:
        jpeg = ProcessJpegVideoCapture([
            sys.executable,
            "-c",
            (
                "import sys; "
                "sys.stdout.buffer.write(b'noise\\xff\\xd8abc\\xff\\xd9tail'); "
                "sys.stdout.flush()"
            ),
        ])
        try:
            expect_equal(await jpeg.read_frame(), b"\xff\xd8abc\xff\xd9", "JPEG frame shape")
        finally:
            await jpeg.aclose()

    asyncio.run(run())


def test_process_command_validation_rejects_shell_control_and_shell_executables() -> None:
    expect_equal(split_command(
        "ffmpeg -hide_banner -loglevel error -f pulse -i default -f s16le -ac 2 -ar 44100 -"
    ), [
        "ffmpeg",
        "-hide_banner",
        "-loglevel",
        "error",
        "-f",
        "pulse",
        "-i",
        "default",
        "-f",
        "s16le",
        "-ac",
        "2",
        "-ar",
        "44100",
        "-",
    ], "safe process command split")

    with pytest.raises(ValueError, match="shell control"):
        split_command("ffmpeg -f s16le - ; touch /tmp/unsafe")
    with pytest.raises(ValueError, match="must not invoke a shell"):
        validate_process_command(["sh", "-c", "ffmpeg -f s16le -"])
    with pytest.raises(ValueError, match="control characters"):
        validate_process_command(["ffmpeg", "line\nbreak"])
    with pytest.raises(ValueError, match="must not be empty"):
        validate_process_command([])
    with pytest.raises(ValueError, match="not allowed"):
        validate_process_command(["custom-capture-helper"])


def test_process_command_validation_accepts_versioned_python_and_rejects_lookalikes() -> None:
    validate_process_command(["/usr/local/bin/python3.14", "-c", "print('ok')"])

    lookalikes = ("python3.", "python3.14m", "python3.14-custom", "python3.14.exe", "python4.1")
    for executable in lookalikes:
        with pytest.raises(ValueError, match="not allowed"):
            validate_process_command([executable, "-c", "print('unexpected')"])


def test_process_command_object_separates_executable_from_arguments() -> None:
    command = make_process_command("ffmpeg -hide_banner -f s16le -")

    expect_equal(command.executable, "ffmpeg", "validated process executable")
    expect_equal(command.executable_name, "ffmpeg", "validated process executable name")
    expect_equal(
        command.arguments,
        ("-hide_banner", "-f", "s16le", "-"),
        "validated process arguments",
    )
    expect_equal(
        command.argv,
        ["ffmpeg", "-hide_banner", "-f", "s16le", "-"],
        "validated process argv",
    )

    with pytest.raises(ValueError, match="shell control"):
        make_process_command("ffmpeg -f s16le - && unsafe")
    with pytest.raises(ValueError, match="must not invoke a shell"):
        make_process_command(["bash", "-c", "ffmpeg -f s16le -"])


def test_process_launch_resolves_allowlisted_executable_without_shell(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    command = ProcessCommand("ffmpeg", "ffmpeg", ("-f", "s16le", "-"))
    calls: list[tuple[object, ...]] = []

    monkeypatch.setattr(process_launch.shutil, "which", lambda name: "/usr/bin/ffmpeg")

    async def fake_create(*args: object, **kwargs: object) -> object:
        calls.append(args)
        expect_equal(kwargs.get("stdout"), PIPE, "stdout pipe")
        return object()

    monkeypatch.setattr(process_launch.asyncio, "create_subprocess_exec", fake_create)

    async def run() -> None:
        await process_launch.launch_stdout_process(command)

    asyncio.run(run())
    expect_equal(
        calls,
        [("/usr/bin/env", "--", "/usr/bin/ffmpeg", "-f", "s16le", "-")],
        "static env argv",
    )


def test_process_launch_fails_closed_when_executable_is_missing(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    command = ProcessCommand("missing", "missing", ())
    monkeypatch.setattr(process_launch.shutil, "which", lambda _: None)

    with pytest.raises(FileNotFoundError, match="process executable not found"):
        asyncio.run(process_launch.launch_stdout_process(command))


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
    extractor = JpegFrameExtractor(max_frame_bytes=6, warn_frame_bytes=100)
    extractor.append(b"\xff\xd8aa\xff\xd9\xff\xd8bb\xff\xd9")

    expect_equal(extractor.extract_frame(), b"\xff\xd8aa\xff\xd9", "first capped JPEG frame")
    expect_equal(extractor.extract_frame(), b"\xff\xd8bb\xff\xd9", "second capped JPEG frame")
    expect_is_none(extractor.extract_frame(), "exhausted capped JPEG frames")


def test_process_raw_video_capture_frame_size() -> None:
    settings = MediaSettings(width=32, height=16, bits_per_pixel=8)
    capture = ProcessRawVideoCapture(["ffmpeg"], settings)
    expect_equal(capture.frame_size, 512, "raw video frame size")


def test_process_audio_playback_reports_dead_subprocess() -> None:

    async def run() -> None:
        playback = ProcessAudioPlayback([sys.executable, "-c", "import sys; sys.exit(0)"])
        await playback.start()
        process = playback.process
        if process is None:
            pytest.fail("audio playback process is not ready")
        try:
            await asyncio.wait_for(process.wait(), timeout=1.0)
            with pytest.raises(RuntimeError, match="audio playback process died"):
                await playback.write_block(b"pcm", sequence=1)
        finally:
            await playback.aclose()

    asyncio.run(run())


def test_process_video_display_reports_dead_subprocess() -> None:

    async def run() -> None:
        display = ProcessVideoDisplay([sys.executable, "-c", "import sys; sys.exit(0)"])
        await display.start()
        process = display.process
        if process is None:
            pytest.fail("video display process is not ready")
        try:
            await asyncio.wait_for(process.wait(), timeout=1.0)
            with pytest.raises(RuntimeError, match="video display process died"):
                await display.show_frame(b"frame", sequence=1, compressed=False)
        finally:
            await display.aclose()

    asyncio.run(run())


def test_process_write_backends_accept_data_and_close_cleanly() -> None:

    async def run() -> None:
        playback = ProcessAudioPlayback(
            [sys.executable, "-c", "import sys; sys.stdin.buffer.read()"]
        )
        await playback.write_block(b"pcm", sequence=1)
        await playback.aclose()
        expect_is_none(playback.process, "closed playback process")

        display = ProcessVideoDisplay([sys.executable, "-c", "import sys; sys.stdin.buffer.read()"])
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
        playback = ProcessAudioPlayback(["python"], block_bytes=256)
        playback.process = Process()  # type: ignore[assignment]
        await playback.start()
        expect_equal(playback.buffered_byte_limit, 256, "audio writer high-water metric")
        expect_equal(
            playback.process.stdin.transport.high_water,  # type: ignore[union-attr]
            256,
            "audio writer high-water",
        )

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


def test_process_audio_capture_tracks_and_cleans_stdoutless_subprocess(
    monkeypatch: pytest.MonkeyPatch,
) -> None:

    async def create_stdoutless_process(*_args: str, stdout: int) -> StdoutlessProcess:
        expect_is(stdout, PIPE, "audio capture stdout pipe")
        return process

    process = StdoutlessProcess()
    monkeypatch.setattr(asyncio, "create_subprocess_exec", create_stdoutless_process)

    async def run() -> None:
        capture = ProcessAudioCapture(["python"], MediaSettings())
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

    async def create_stdoutless_process(
        *_args: str, stdout: int
    ) -> CleanupFailingStdoutlessProcess:
        expect_is(stdout, PIPE, "audio capture stdout pipe")
        return process

    process = CleanupFailingStdoutlessProcess()
    monkeypatch.setattr(asyncio, "create_subprocess_exec", create_stdoutless_process)

    async def run() -> None:
        capture = ProcessAudioCapture(["python"], MediaSettings())
        with pytest.raises(RuntimeError, match="did not expose stdout") as raised:
            await capture.start()

        expect_true(process.killed, "cleanup-failing audio capture process killed")
        expect_is_none(capture.process, "cleanup-failing audio capture process state")
        expect_true(any(
            "audio capture process cleanup failed" in note
            for note in getattr(raised.value, "__notes__", [])
        ), "cleanup failure note")

    asyncio.run(run())


def test_process_video_capture_tracks_and_cleans_stdoutless_subprocess(
    monkeypatch: pytest.MonkeyPatch,
) -> None:

    async def create_stdoutless_process(*_args: str, stdout: int) -> StdoutlessProcess:
        expect_is(stdout, PIPE, "video capture stdout pipe")
        process = processes.pop(0)
        created.append(process)
        return process

    processes = [StdoutlessProcess(), StdoutlessProcess()]
    created: list[StdoutlessProcess] = []
    monkeypatch.setattr(asyncio, "create_subprocess_exec", create_stdoutless_process)

    async def run() -> None:
        raw = ProcessRawVideoCapture(
            ["python"], MediaSettings(width=16, height=8, bits_per_pixel=8)
        )
        with pytest.raises(RuntimeError, match="raw video capture process did not expose stdout"):
            await raw.start()

        expect_equal(len(created), 1, "created raw video process count")
        expect_true(created[0].killed, "stdoutless raw video process killed")
        expect_true(created[0].waited, "stdoutless raw video process waited")
        expect_equal(len(processes), 1, "remaining video process count")
        expect_is_none(raw.process, "stdoutless raw video process state")

        jpeg = ProcessJpegVideoCapture(["python"])
        with pytest.raises(RuntimeError, match="JPEG video capture process did not expose stdout"):
            await jpeg.start()

        expect_equal(len(created), 2, "created JPEG video process count")
        expect_true(created[1].killed, "stdoutless JPEG video process killed")
        expect_true(created[1].waited, "stdoutless JPEG video process waited")
        expect_equal(len(processes), 0, "remaining video process count")
        expect_is_none(jpeg.process, "stdoutless JPEG video process state")

    asyncio.run(run())


def test_process_video_capture_cleans_up_after_early_exit() -> None:

    async def run() -> None:
        settings = MediaSettings(width=16, height=8, bits_per_pixel=8)
        raw = ProcessRawVideoCapture([sys.executable, "-c", "import sys; sys.exit(0)"], settings)
        with pytest.raises(RuntimeError, match="raw video capture process died"):
            await raw.read_frame()
        expect_is_none(raw.process, "early-exit raw video process state")

        jpeg = ProcessJpegVideoCapture([sys.executable, "-c", "import sys; sys.exit(0)"])
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
    close_process = getattr(managed, "_close_process")
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
            await UnreadyAudioPlayback(["python"]).write_block(b"pcm", sequence=1)
        with pytest.raises(RuntimeError, match="raw video capture process is not ready"):
            await UnreadyRawVideoCapture(["python"], settings).read_frame()
        with pytest.raises(RuntimeError, match="JPEG video capture process is not ready"):
            await UnreadyJpegVideoCapture(["python"]).read_frame()
        with pytest.raises(RuntimeError, match="video display process is not ready"):
            await UnreadyVideoDisplay(["python"]).show_frame(b"frame", sequence=1, compressed=False)

    asyncio.run(run())
