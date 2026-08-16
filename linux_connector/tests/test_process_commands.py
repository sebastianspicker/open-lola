"""Tests for Linux process command validation and launching."""

# pylint: disable=missing-function-docstring

from __future__ import annotations

import asyncio
import shutil
from asyncio.subprocess import PIPE
from collections.abc import Awaitable, Callable

import pytest

from linux_connector.lola_connector import process_launch
from linux_connector.lola_connector.process_commands import (
    ProcessCommand,
    make_process_command,
    split_command,
    validate_process_command,
)
from linux_connector.tests.support import expect_equal


def assert_allowlisted_process_launch(
    monkeypatch: pytest.MonkeyPatch,
    launch: Callable[[ProcessCommand], Awaitable[object]],
    **expected_stdio: int,
) -> None:
    """Verify a shell-free launcher resolves the allowlisted executable and selected pipe."""
    command = ProcessCommand("ffmpeg", "ffmpeg", ("-f", "s16le", "-"))
    calls: list[tuple[object, ...]] = []

    monkeypatch.setattr(shutil, "which", lambda name: "/usr/bin/ffmpeg")

    async def fake_create(*args: object, **kwargs: object) -> object:
        calls.append(args)
        expect_equal(kwargs, expected_stdio, "process stdio")
        return object()

    monkeypatch.setattr(asyncio, "create_subprocess_exec", fake_create)

    async def run() -> None:
        await launch(command)

    asyncio.run(run())
    expect_equal(
        calls,
        [("/usr/bin/ffmpeg", "-f", "s16le", "-")],
        "direct executable argv",
    )


def test_process_command_validation_rejects_shell_control_and_shell_executables() -> None:
    expect_equal(
        split_command("ffmpeg -hide_banner -loglevel error -f pulse -i default -f s16le -ac 2 -ar 44100 -"),
        [
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
        ],
        "safe process command split",
    )

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


def test_process_command_validation_rejects_python_interpreters_and_scripts() -> None:
    commands = (
        ["python", "-c", "print('unexpected')"],
        ["/usr/bin/python3", "-m", "module"],
        ["/usr/local/bin/python3.14", "media-helper.py"],
    )
    for command in commands:
        with pytest.raises(ValueError, match="not allowed"):
            validate_process_command(command)


def test_process_command_validation_rejects_untrusted_and_relative_executables() -> None:
    with pytest.raises(ValueError, match="trusted system prefix"):
        validate_process_command(["/tmp/ffmpeg"])
    with pytest.raises(ValueError, match="bare name or an absolute path"):
        validate_process_command(["tools/ffmpeg"])


def test_process_command_canonicalizes_trusted_absolute_executable() -> None:
    command = make_process_command(["/usr/local/bin/../bin/ffmpeg", "-version"])
    expect_equal(command.executable, "/usr/local/bin/ffmpeg", "canonical trusted executable")


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
    assert_allowlisted_process_launch(monkeypatch, process_launch.launch_stdout_process, stdout=PIPE)


def test_process_launch_resolves_allowlisted_executable_with_stdin_pipe(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    assert_allowlisted_process_launch(monkeypatch, process_launch.launch_stdin_process, stdin=PIPE)


def test_process_launch_fails_closed_when_executable_is_missing(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    command = ProcessCommand("ffmpeg", "ffmpeg", ())
    monkeypatch.setattr(shutil, "which", lambda _: None)

    with pytest.raises(FileNotFoundError, match="process executable not found"):
        asyncio.run(process_launch.launch_stdout_process(command))
    with pytest.raises(FileNotFoundError, match="process executable not found"):
        asyncio.run(process_launch.launch_stdin_process(command))


def test_process_launch_rejects_path_shadowed_tool(monkeypatch: pytest.MonkeyPatch) -> None:
    command = make_process_command(["ffmpeg"])
    monkeypatch.setattr(shutil, "which", lambda _: "/tmp/ffmpeg")

    with pytest.raises(ValueError, match="trusted system prefix"):
        process_launch.resolved_executable(command)


@pytest.mark.parametrize(
    ("command_name", "resolved_path"),
    (
        ("ffmpeg", "/usr/bin/ffmpeg"),
        ("ffplay", "/usr/local/bin/ffplay"),
        ("gst-launch-1.0", "/opt/homebrew/bin/gst-launch-1.0"),
    ),
)
def test_process_launch_accepts_conventional_trusted_resolution(
    monkeypatch: pytest.MonkeyPatch,
    command_name: str,
    resolved_path: str,
) -> None:
    command = make_process_command([command_name])
    monkeypatch.setattr(shutil, "which", lambda _: resolved_path)

    expect_equal(process_launch.resolved_executable(command), resolved_path, "trusted resolved executable")


def test_process_launch_executes_trusted_absolute_path_directly(monkeypatch: pytest.MonkeyPatch) -> None:
    command = make_process_command(["/usr/bin/ffmpeg", "-version"])
    calls: list[tuple[object, ...]] = []

    def unexpected_path_resolution(_name: str) -> str:
        pytest.fail("absolute executable must not be resolved through PATH")

    async def fake_create(*args: object, **kwargs: object) -> object:
        calls.append(args)
        expect_equal(kwargs, {"stdout": PIPE}, "absolute process stdio")
        return object()

    monkeypatch.setattr(shutil, "which", unexpected_path_resolution)
    monkeypatch.setattr(asyncio, "create_subprocess_exec", fake_create)
    asyncio.run(process_launch.launch_stdout_process(command))

    expect_equal(calls, [("/usr/bin/ffmpeg", "-version")], "direct trusted absolute argv")
