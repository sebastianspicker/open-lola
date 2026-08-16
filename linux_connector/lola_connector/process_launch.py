"""Shell-free asynchronous subprocess launch helpers."""

from __future__ import annotations

import asyncio
import os.path
import shutil
from asyncio.subprocess import PIPE, Process
from typing import TypedDict, Unpack

from .process_commands import (
    ProcessCommand,
    canonical_trusted_executable_path,
    validate_process_executable,
)


class _ProcessPipe(TypedDict, total=False):
    stdin: int
    stdout: int


def resolved_executable(command: ProcessCommand) -> str:
    """Resolve a bare command, then require its canonical path to be trusted."""
    validate_process_executable(command.executable)
    if os.path.isabs(command.executable):
        return canonical_trusted_executable_path(command.executable)
    executable = shutil.which(command.executable)
    if executable is None:
        raise FileNotFoundError(f"process executable not found: {command.executable}")
    return canonical_trusted_executable_path(executable)


async def _launch_process(command: ProcessCommand, **stdio: Unpack[_ProcessPipe]) -> Process:
    """Launch an allowlisted process with the caller-selected stdio pipe."""
    return await asyncio.create_subprocess_exec(
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
