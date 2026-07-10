# pylint: disable=missing-function-docstring
"""Shell-free asynchronous subprocess launch helpers."""

from __future__ import annotations

import asyncio
from asyncio.subprocess import PIPE, Process
import sys

from .process_commands import ProcessCommand


PROCESS_EXEC_MODULE = "linux_connector.process_exec"


async def launch_stdout_process(command: ProcessCommand) -> Process:
    return await asyncio.create_subprocess_exec(
        sys.executable,
        "-m",
        PROCESS_EXEC_MODULE,
        command.executable_name,
        *command.arguments,
        stdout=PIPE,
    )


async def launch_stdin_process(command: ProcessCommand) -> Process:
    return await asyncio.create_subprocess_exec(
        sys.executable,
        "-m",
        PROCESS_EXEC_MODULE,
        command.executable_name,
        *command.arguments,
        stdin=PIPE,
    )
