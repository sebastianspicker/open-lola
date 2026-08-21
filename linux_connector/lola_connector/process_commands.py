"""Validated subprocess command parsing for media backends."""

from __future__ import annotations

import os.path
import shlex
from dataclasses import dataclass

SHELL_CONTROL_CHARS = frozenset(";&|<>`$")
SHELL_EXECUTABLE_NAMES = frozenset(
    {
        "bash",
        "cmd",
        "cmd.exe",
        "fish",
        "powershell",
        "powershell.exe",
        "pwsh",
        "pwsh.exe",
        "sh",
        "zsh",
    }
)
ALLOWED_PROCESS_EXECUTABLE_NAMES = frozenset(
    {
        "aplay",
        "arecord",
        "ffmpeg",
        "ffplay",
        "gst-launch-1.0",
        "pacat",
        "parec",
    }
)
# The process adapters are a trusted-operator integration, not a sandbox. Keep
# this deliberately small so an allowlisted basename cannot be supplied from a
# workspace, temporary directory, or a PATH shadow.
TRUSTED_SYSTEM_EXECUTABLE_PREFIXES = (
    "/usr/bin",
    "/usr/local/bin",
    "/usr/local/Cellar",
    "/opt/homebrew/bin",
    "/opt/homebrew/Cellar",
)


@dataclass(frozen=True)
class ProcessCommand:
    """Store an allowlisted executable and pre-tokenized arguments for a media process."""

    executable: str
    executable_name: str
    arguments: tuple[str, ...]

    @property
    def argv(self) -> list[str]:
        return [self.executable, *self.arguments]


def split_command(command: str) -> list[str]:
    """Tokenize command without allowing shell interpretation."""
    parts = shlex.split(command)
    validate_process_command(parts, reject_shell_control=True)
    return parts


def make_process_command(command: str | list[str]) -> ProcessCommand:
    """Validate command tokens and freeze them into a shell-free process request."""
    parts = split_command(command) if isinstance(command, str) else command
    validate_process_command(parts)
    executable = canonical_trusted_executable_path(parts[0]) if os.path.isabs(parts[0]) else parts[0]
    return ProcessCommand(
        executable=executable,
        executable_name=process_executable_name(executable),
        arguments=tuple(parts[1:]),
    )


def validate_process_command(command: list[str], *, reject_shell_control: bool = False) -> None:
    """Require a nonempty allowlisted executable and safe argument sequence."""
    if not command:
        raise ValueError("process command must not be empty")
    executable = command[0]
    if not executable:
        raise ValueError("process command executable must not be empty")
    validate_process_executable(executable)
    for argument in command:
        validate_process_argument(argument, reject_shell_control=reject_shell_control)


def validate_process_executable_name(executable_name: str) -> None:
    """Reject shells and executables outside the media-backend allowlist."""
    if executable_name in SHELL_EXECUTABLE_NAMES:
        raise ValueError(f"process command must not invoke a shell directly: {executable_name}")
    if executable_name not in ALLOWED_PROCESS_EXECUTABLE_NAMES:
        allowed = ", ".join(sorted(ALLOWED_PROCESS_EXECUTABLE_NAMES))
        raise ValueError(f"process command executable is not allowed: {executable_name}; allowed: {allowed}")


def validate_process_executable(executable: str) -> None:
    """Require an allowlisted absolute executable in a trusted system prefix."""
    validate_process_executable_name(process_executable_name(executable))
    if not os.path.isabs(executable):
        raise ValueError("process command executable must be an absolute path")
    canonical_trusted_executable_path(executable)


def canonical_trusted_executable_path(executable: str) -> str:
    """Return an absolute executable's canonical path after enforcing the trusted-prefix policy."""
    if not os.path.isabs(executable):
        raise ValueError("process command executable must be an absolute path")
    if os.path.islink(executable):
        raise ValueError("process command executable must not be a symbolic link")
    canonical_path = os.path.realpath(executable)
    validate_process_executable_name(process_executable_name(canonical_path))
    if any(
        os.path.commonpath((canonical_path, prefix)) == prefix
        for prefix in TRUSTED_SYSTEM_EXECUTABLE_PREFIXES
    ):
        return canonical_path
    prefixes = ", ".join(TRUSTED_SYSTEM_EXECUTABLE_PREFIXES)
    raise ValueError(f"process command executable must resolve within a trusted system prefix: {prefixes}")


def validate_process_argument(argument: str, *, reject_shell_control: bool) -> None:
    """Reject control bytes and, for command strings, shell metacharacters."""
    if any(ord(character) < 32 or ord(character) == 127 for character in argument):
        raise ValueError("process command arguments must not contain control characters")
    if reject_shell_control and any(character in SHELL_CONTROL_CHARS for character in argument):
        raise ValueError("process command strings must not contain shell control characters")


def process_executable_name(executable: str) -> str:
    """Return the basename used to enforce executable allowlists."""
    return executable.rsplit("/", 1)[-1].rsplit("\\", 1)[-1].lower()
