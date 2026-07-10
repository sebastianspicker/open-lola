# pylint: disable=missing-function-docstring
"""Validated subprocess command parsing for media backends."""

from __future__ import annotations

from dataclasses import dataclass
import shlex

SHELL_CONTROL_CHARS = frozenset(";&|<>`$")
SHELL_EXECUTABLE_NAMES = frozenset({
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
})
ALLOWED_PROCESS_EXECUTABLE_NAMES = frozenset({
    "aplay",
    "arecord",
    "ffmpeg",
    "ffplay",
    "gst-launch-1.0",
    "pacat",
    "parec",
    "python",
    "python3",
})

@dataclass(frozen=True)
class ProcessCommand:  # pylint: disable=missing-class-docstring
    executable: str
    executable_name: str
    arguments: tuple[str, ...]

    @property
    def argv(self) -> list[str]:
        return [self.executable, *self.arguments]



def split_command(command: str) -> list[str]:
    parts = shlex.split(command)
    validate_process_command(parts, reject_shell_control=True)
    return parts


def make_process_command(command: str | list[str]) -> ProcessCommand:
    parts = split_command(command) if isinstance(command, str) else command
    validate_process_command(parts)
    return ProcessCommand(
        executable=parts[0],
        executable_name=process_executable_name(parts[0]),
        arguments=tuple(parts[1:]),
    )


def validate_process_command(command: list[str], *, reject_shell_control: bool = False) -> None:
    if not command:
        raise ValueError("process command must not be empty")
    executable = command[0]
    if not executable:
        raise ValueError("process command executable must not be empty")
    executable_name = process_executable_name(executable)
    validate_process_executable_name(executable_name)
    for argument in command:
        validate_process_argument(argument, reject_shell_control=reject_shell_control)


def validate_process_executable_name(executable_name: str) -> None:
    if executable_name in SHELL_EXECUTABLE_NAMES:
        raise ValueError(f"process command must not invoke a shell directly: {executable_name}")
    if executable_name not in ALLOWED_PROCESS_EXECUTABLE_NAMES:
        allowed = ", ".join(sorted(ALLOWED_PROCESS_EXECUTABLE_NAMES))
        raise ValueError(
            f"process command executable is not allowed: {executable_name}; "
            f"allowed: {allowed}"
        )


def validate_process_argument(argument: str, *, reject_shell_control: bool) -> None:
    if any(ord(character) < 32 or ord(character) == 127 for character in argument):
        raise ValueError("process command arguments must not contain control characters")
    if reject_shell_control and any(character in SHELL_CONTROL_CHARS for character in argument):
        raise ValueError("process command strings must not contain shell control characters")


def process_executable_name(executable: str) -> str:
    return executable.rsplit("/", 1)[-1].rsplit("\\", 1)[-1].lower()
