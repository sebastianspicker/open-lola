from __future__ import annotations

import asyncio
import logging
import sys

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
)
from linux_connector.lola_connector.protocol import MediaSettings


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
    extractor = JpegFrameExtractor(max_frame_bytes=6, warn_frame_bytes=100)
    extractor.append(b"\xff\xd8aa\xff\xd9\xff\xd8bb\xff\xd9")

    assert extractor.extract_frame() == b"\xff\xd8aa\xff\xd9"
    assert extractor.extract_frame() == b"\xff\xd8bb\xff\xd9"
    assert extractor.extract_frame() is None


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
        assert playback.process is None

        display = ProcessVideoDisplay([sys.executable, "-c", "import sys; sys.stdin.buffer.read()"])
        await display.show_frame(b"frame", sequence=1, compressed=False)
        await display.aclose()
        assert display.process is None

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
            self.process = process

    async def run() -> None:
        terminate_failed = ManagedProcess(TerminateFailingProcess())
        await terminate_failed._close_process()
        assert terminate_failed.process is None
        assert any("terminate failed" in warning for warning in terminate_failed.cleanup_warnings)

        wait_failed = ManagedProcess(WaitFailingProcess())
        await wait_failed._close_process()
        assert wait_failed.process is None
        assert any("wait failed" in warning for warning in wait_failed.cleanup_warnings)

        async def timeout_wait_for(awaitable: object, timeout: float) -> int:
            close = getattr(awaitable, "close", None)
            if close is not None:
                close()
            raise asyncio.TimeoutError

        monkeypatch.setattr(backends.asyncio, "wait_for", timeout_wait_for)
        kill_failed = ManagedProcess(KillFailingProcess())
        await kill_failed._close_process()
        assert kill_failed.process is None
        assert any("kill failed" in warning for warning in kill_failed.cleanup_warnings)

    caplog.set_level(logging.DEBUG, logger="linux_connector.lola_connector.backends")
    asyncio.run(run())

    assert "suppressed process terminate failure during cleanup" in caplog.text


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
