# pylint: disable=missing-function-docstring
"""Shell-free asynchronous subprocess launch helpers."""

from __future__ import annotations

import asyncio
from asyncio.subprocess import PIPE, Process
import shutil

from .process_commands import ProcessCommand


ENV_EXECUTABLE = "/usr/bin/env"


def resolved_executable(command: ProcessCommand) -> str:
    executable = shutil.which(command.executable)
    if executable is None:
        raise FileNotFoundError(f"process executable not found: {command.executable}")
    return executable


async def launch_stdout_process(command: ProcessCommand) -> Process:
    return await asyncio.create_subprocess_exec(
        ENV_EXECUTABLE,
        "--",
        resolved_executable(command),
        *command.arguments,
        stdout=PIPE,
    )


async def launch_stdin_process(command: ProcessCommand) -> Process:
    return await asyncio.create_subprocess_exec(
        ENV_EXECUTABLE,
        "--",
        resolved_executable(command),
        *command.arguments,
        stdin=PIPE,
    )
