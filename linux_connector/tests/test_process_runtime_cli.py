"""Tests for process runtime CLI validation and dispatch."""

# pylint: disable=missing-function-docstring

from __future__ import annotations

import argparse
import asyncio
from typing import cast

import pytest

from linux_connector.lola_connector.backends import ProcessJpegVideoCapture, ProcessVideoDisplay
from linux_connector.lola_connector import cli
from linux_connector.lola_connector.cli import build_parser, build_runtime, build_video_capture, media_settings_from_args
from linux_connector.lola_connector.cli import run as run_cli, validate_cli_args
from linux_connector.lola_connector.connector import LolaConnector, Session, StatusCheckResult
from linux_connector.lola_connector.protocol import MediaSettings
from linux_connector.tests.support import (
    expect_contains,
    expect_equal,
    expect_false,
    expect_instance,
    expect_not_contains,
)


def test_cli_exposes_remote_signal_flags_without_getattr_fallbacks() -> None:
    parser = build_parser()
    listen_args = parser.parse_args(["--local-ip", "127.0.0.1", "listen"])
    connect_args = parser.parse_args(["--local-ip", "127.0.0.1", "connect", "127.0.0.2"])
    source_name_args = parser.parse_args(
        ["--local-ip", "127.0.0.1", "--source-name", "lab-peer", "status", "127.0.0.2"]
    )

    expect_false(listen_args.wait_for_remote_test_signal, "listen wait remote signal default")
    expect_false(listen_args.request_remote_audio_signal, "listen request remote signal default")
    expect_false(connect_args.wait_for_remote_test_signal, "connect wait remote signal default")
    expect_false(connect_args.request_remote_audio_signal, "connect request remote signal default")
    expect_equal(source_name_args.source_name, "lab-peer", "source name argument")


def test_cli_help_presents_connector_as_compatibility_seed() -> None:
    help_text = build_parser().format_help()

    expect_contains(
        "Open LoLa Linux compatibility prototype for LoLa 2.0",
        help_text,
        "CLI help",
    )
    expect_not_contains("Prototype LoLa 2.0 Linux connector", help_text, "CLI help")


def test_cli_default_media_and_timing_values_pass_bounds_validation() -> None:
    parser = build_parser()
    args = parser.parse_args(["--local-ip", "127.0.0.1", "connect", "127.0.0.2", "--duration", "0.25"])

    validate_cli_args(args)


def test_cli_carries_validated_bayer_marker_into_media_settings() -> None:
    parser = build_parser()
    args = parser.parse_args(["--local-ip", "127.0.0.1", "--bayer", "1", "connect", "127.0.0.2"])

    validate_cli_args(args)
    expect_equal(media_settings_from_args(args).bayer, 1, "CLI Bayer marker")


def test_cli_status_prints_structured_reason(
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    async def fake_check_status_result(
        self: LolaConnector,
        remote_ip: str,
        sid: int = 0,
        timeout: float = 2.0,
    ) -> StatusCheckResult:
        _ = (self, remote_ip, sid, timeout)
        return StatusCheckResult(
            acknowledged=False,
            reason="wrong-peer",
            wrong_peer_datagrams=1,
            sent_dialects=("ascii",),
        )

    monkeypatch.setattr(LolaConnector, "check_status_result", fake_check_status_result)
    parser = build_parser()
    args = parser.parse_args(["--local-ip", "127.0.0.1", "status", "127.0.0.2"])

    asyncio.run(run_cli(args))

    output = capsys.readouterr().out
    expect_contains("status_ack=0", output, "CLI status output")
    expect_contains("status_reason=wrong-peer", output, "CLI status output")
    expect_contains("status_wrong_peer=1", output, "CLI status output")


@pytest.mark.parametrize(
    ("arguments", "message"),
    [
        (["--sr", "0"], "sample_rate"),
        (["--channels", "9"], "audio callback block"),
        (["--width", "8192", "--height", "8192"], "raw video frame"),
        (["--fps", "0"], "fps"),
        (["--audio-interval-scale", "nan"], "audio_interval_scale"),
        (["--audio-frames-per-callback", "4096"], "audio_frames_per_callback must be 64"),
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


def test_cli_rejects_none_for_required_finite_range() -> None:
    parser = build_parser()
    args = parser.parse_args(["--local-ip", "127.0.0.1", "status", "127.0.0.2"])
    args.timeout = None

    with pytest.raises(ValueError, match="timeout must not be None"):
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
            "ffmpeg",
            "--max-frame-bytes",
            "4096",
            "connect",
            "127.0.0.2",
        ]
    )

    capture = build_video_capture(args, MediaSettings(width=16, height=8, compression=1))

    expect_instance(capture, ProcessJpegVideoCapture, "JPEG video capture backend")
    capture = cast(ProcessJpegVideoCapture, capture)
    expect_equal(capture.max_frame_bytes, 4096, "JPEG frame byte cap")


def test_cli_build_runtime_expands_video_display_from_remote_settings() -> None:
    args = build_parser().parse_args(
        [
            "--local-ip",
            "127.0.0.1",
            "--video-display-cmd",
            "ffplay -video_size {video_size} -framerate {fps}",
            "connect",
            "127.0.0.2",
        ]
    )
    local_settings = MediaSettings(width=16, height=8, fps=25)
    remote_settings = MediaSettings(width=1920, height=1080, fps=60)
    runtime = build_runtime(
        args,
        LolaConnector("127.0.0.1", local_settings),
        local_settings,
        None,
        remote_settings,
    )

    display = expect_instance(runtime.video_display, ProcessVideoDisplay, "process video display")
    expect_equal(display.command.arguments, ("-video_size", "1920x1080", "-framerate", "60"), "remote argv")
    expect_equal(display.remote_settings, remote_settings, "remote display settings")


def test_timed_runtime_attempts_every_terminal_action_and_groups_failures(monkeypatch: pytest.MonkeyPatch) -> None:
    events: list[str] = []

    class RuntimeDouble:
        stats = "unused"

        async def stop(self) -> None:
            events.append("runtime-stop")
            raise OSError("runtime cleanup")

    class ConnectorDouble:
        async def send_control_once(self, kind: str, *_args: object) -> None:
            events.append(kind)
            if kind == cli.MESG_STOP_AUDIO_SIGNAL:
                raise OSError("stop signal")

        async def send_disconnect(self) -> None:
            events.append("disconnect")
            raise OSError("disconnect")

    async def sleep(_seconds: float) -> None:
        events.append("sleep")

    monkeypatch.setattr(cli.asyncio, "sleep", sleep)
    args = argparse.Namespace(duration=0.1, request_remote_audio_signal=True)
    session = Session("127.0.0.1", "127.0.0.2", 7, MediaSettings())
    with pytest.raises(ExceptionGroup, match="LoLa runtime teardown failed") as raised:
        asyncio.run(
            cli.run_timed_runtime(
                args,
                cast(LolaConnector, ConnectorDouble()),
                session,
                cast(cli.LolaLinuxRuntime, RuntimeDouble()),
            )
        )

    expect_equal(events, [cli.MESG_SEND_AUDIO_SIGNAL, "sleep", cli.MESG_STOP_AUDIO_SIGNAL, "runtime-stop", "disconnect"], "terminal ordering")
    expect_equal(len(raised.value.exceptions), 3, "terminal failures")
