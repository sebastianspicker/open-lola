from __future__ import annotations

import asyncio
import logging
import sys
from asyncio.subprocess import PIPE

import pytest
from pytest import LogCaptureFixture

import linux_connector.lola_connector.backends as backends
from linux_connector.lola_connector.backends import (
    JpegFrameExtractor,
    ProcessAudioCapture,
    ProcessAudioPlayback,
    ProcessJpegVideoCapture,
    ProcessRawVideoCapture,
    ProcessVideoDisplay,
    split_command,
    validate_process_command,
)
from linux_connector.lola_connector.protocol import MediaSettings


def expect_true(condition: object, label: str) -> None:
    if not condition:
        pytest.fail(f"{label}: expected truthy value")


def expect_equal(actual: object, expected: object, label: str) -> None:
    if actual != expected:
        pytest.fail(f"{label}: expected {expected!r}, got {actual!r}")


def expect_is(actual: object, expected: object, label: str) -> None:
    if actual is not expected:
        pytest.fail(f"{label}: expected {expected!r}, got {actual!r}")


def expect_is_none(actual: object, label: str) -> None:
    if actual is not None:
        pytest.fail(f"{label}: expected None, got {actual!r}")


def expect_contains(needle: str, haystack: str, label: str) -> None:
    if needle not in haystack:
        pytest.fail(f"{label}: expected {needle!r} in {haystack!r}")


def test_process_command_split_and_jpeg_capture_shape() -> None:

    expect_equal(split_command("ffmpeg -f s16le -"), ["ffmpeg", "-f", "s16le", "-"], "process command split")

    async def run() -> None:
        jpeg = ProcessJpegVideoCapture([
            sys.executable,
            "-c",
            "import sys; sys.stdout.buffer.write(b'noise\\xff\\xd8abc\\xff\\xd9tail'); sys.stdout.flush()",
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
    capture = ProcessRawVideoCapture(["dummy"], settings)
    expect_equal(capture.frame_size, 512, "raw video frame size")


def test_process_audio_playback_reports_dead_subprocess() -> None:

    async def run() -> None:
        playback = ProcessAudioPlayback([sys.executable, "-c", "import sys; sys.exit(0)"])
        await playback.start()
        await asyncio.sleep(0.05)
        with pytest.raises(RuntimeError, match="audio playback process died"):
            await playback.write_block(b"pcm", sequence=1)

    asyncio.run(run())


def test_process_video_display_reports_dead_subprocess() -> None:

    async def run() -> None:
        display = ProcessVideoDisplay([sys.executable, "-c", "import sys; sys.exit(0)"])
        await display.start()
        await asyncio.sleep(0.05)
        with pytest.raises(RuntimeError, match="video display process died"):
            await display.show_frame(b"frame", sequence=1, compressed=False)

    asyncio.run(run())


def test_process_write_backends_accept_data_and_close_cleanly() -> None:

    async def run() -> None:
        playback = ProcessAudioPlayback([sys.executable, "-c", "import sys; sys.stdin.buffer.read()"])
        await playback.write_block(b"pcm", sequence=1)
        await playback.aclose()
        expect_is_none(playback.process, "closed playback process")

        display = ProcessVideoDisplay([sys.executable, "-c", "import sys; sys.stdin.buffer.read()"])
        await display.show_frame(b"frame", sequence=1, compressed=False)
        await display.aclose()
        expect_is_none(display.process, "closed display process")

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
        expect_is(stdout, PIPE, "audio capture stdout pipe")
        return process

    process = StdoutlessProcess()
    monkeypatch.setattr(asyncio, "create_subprocess_exec", create_stdoutless_process)

    async def run() -> None:
        capture = ProcessAudioCapture(["dummy"], MediaSettings())
        with pytest.raises(RuntimeError, match="did not expose stdout"):
            await capture.start()

        expect_true(process.killed, "stdoutless audio capture process killed")
        expect_true(process.waited, "stdoutless audio capture process waited")
        expect_is_none(capture.process, "stdoutless audio capture process state")

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
        expect_is(stdout, PIPE, "audio capture stdout pipe")
        return process

    process = CleanupFailingStdoutlessProcess()
    monkeypatch.setattr(asyncio, "create_subprocess_exec", create_stdoutless_process)

    async def run() -> None:
        capture = ProcessAudioCapture(["dummy"], MediaSettings())
        with pytest.raises(RuntimeError, match="did not expose stdout") as raised:
            await capture.start()

        expect_true(process.killed, "cleanup-failing audio capture process killed")
        expect_is_none(capture.process, "cleanup-failing audio capture process state")
        expect_true(any(
            "audio capture process cleanup failed" in note
            for note in getattr(raised.value, "__notes__", [])
        ), "cleanup failure note")

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
        expect_is(stdout, PIPE, "video capture stdout pipe")
        process = processes.pop(0)
        created.append(process)
        return process

    processes = [StdoutlessProcess(), StdoutlessProcess()]
    created: list[StdoutlessProcess] = []
    monkeypatch.setattr(asyncio, "create_subprocess_exec", create_stdoutless_process)

    async def run() -> None:
        raw = ProcessRawVideoCapture(["dummy"], MediaSettings(width=16, height=8, bits_per_pixel=8))
        with pytest.raises(RuntimeError, match="raw video capture process did not expose stdout"):
            await raw.start()

        expect_equal(len(created), 1, "created raw video process count")
        expect_true(created[0].killed, "stdoutless raw video process killed")
        expect_true(created[0].waited, "stdoutless raw video process waited")
        expect_equal(len(processes), 1, "remaining video process count")
        expect_is_none(raw.process, "stdoutless raw video process state")

        jpeg = ProcessJpegVideoCapture(["dummy"])
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


def test_process_lifecycle_records_suppressed_cleanup_oserror(
    caplog: LogCaptureFixture,
    monkeypatch: pytest.MonkeyPatch,
) -> None:

    class TerminateFailingProcess:
        stdin = None

        def terminate(self) -> None:
            raise OSError("terminate failed")

        async def wait(self) -> int:
            return 0

    class WaitFailingProcess:
        stdin = None

        def terminate(self) -> None:
            return None

        async def wait(self) -> int:
            raise OSError("wait failed")

    class KillFailingProcess:
        stdin = None

        def terminate(self) -> None:
            return None

        def kill(self) -> None:
            raise OSError("kill failed")

        async def wait(self) -> int:
            return 0

    class ManagedProcess(backends.ProcessLifecycleMixin):
        def __init__(self, process: object) -> None:
            self.process = process  # type: ignore[assignment]

    async def run() -> None:
        terminate_failed = ManagedProcess(TerminateFailingProcess())
        await terminate_failed._close_process()
        expect_is_none(terminate_failed.process, "terminate-failing process state")
        expect_true(
            any("terminate failed" in warning for warning in terminate_failed.cleanup_warnings),
            "terminate failure cleanup warning",
        )

        wait_failed = ManagedProcess(WaitFailingProcess())
        await wait_failed._close_process()
        expect_is_none(wait_failed.process, "wait-failing process state")
        expect_true(
            any("wait failed" in warning for warning in wait_failed.cleanup_warnings),
            "wait failure cleanup warning",
        )

        async def timeout_wait_for(awaitable: object, timeout: float) -> int:
            close = getattr(awaitable, "close", None)
            if close is not None:
                close()
            raise asyncio.TimeoutError

        monkeypatch.setattr(asyncio, "wait_for", timeout_wait_for)
        kill_failed = ManagedProcess(KillFailingProcess())
        await kill_failed._close_process()
        expect_is_none(kill_failed.process, "kill-failing process state")
        expect_true(
            any("kill failed" in warning for warning in kill_failed.cleanup_warnings),
            "kill failure cleanup warning",
        )

    caplog.set_level(logging.DEBUG, logger="linux_connector.lola_connector.backends")
    asyncio.run(run())

    expect_contains("suppressed process terminate failure during cleanup", caplog.text, "cleanup warning log")


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
