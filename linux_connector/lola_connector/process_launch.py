"""Shell-free asynchronous subprocess launch helpers."""

from __future__ import annotations

import asyncio
from asyncio.subprocess import PIPE, Process
import shutil
from typing import TypedDict, Unpack

from .process_commands import ProcessCommand


ENV_EXECUTABLE = "/usr/bin/env"


class _ProcessPipe(TypedDict, total=False):
    stdin: int
    stdout: int


def resolved_executable(command: ProcessCommand) -> str:
    """Resolve an allowlisted command through PATH or fail before process creation."""
    executable = shutil.which(command.executable)
    if executable is None:
        raise FileNotFoundError(f"process executable not found: {command.executable}")
    return executable


async def _launch_process(command: ProcessCommand, **stdio: Unpack[_ProcessPipe]) -> Process:
    """Launch an allowlisted process with the caller-selected stdio pipe."""
    return await asyncio.create_subprocess_exec(
        ENV_EXECUTABLE,
        "--",
        resolved_executable(command),
        *command.arguments,
        **stdio,
    )


async def launch_stdout_process(command: ProcessCommand) -> Process:
    """Launch a shell-free media producer with stdout captured for async reads."""
    return await _launch_process(command, stdout=PIPE)


async def launch_stdin_process(command: ProcessCommand) -> Process:
    """Launch a shell-free media consumer with stdin exposed for async writes."""
    return await _launch_process(command, stdin=PIPE)
