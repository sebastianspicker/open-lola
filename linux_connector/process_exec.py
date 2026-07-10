# pylint: disable=missing-function-docstring
"""Exec a validated media command without invoking a shell."""

from __future__ import annotations

import os
import sys

ALLOWED_EXECUTABLES = frozenset({
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


def validate_command(command: list[str]) -> None:
    if not command or command[0] not in ALLOWED_EXECUTABLES:
        raise ValueError("process executable is not allowed")
    if any(
        ord(character) < 32 or ord(character) == 127
        for argument in command
        for character in argument
    ):
        raise ValueError("process command arguments must not contain control characters")


def _exec_aplay(arguments: list[str]) -> None:
    os.execvp("aplay", ["aplay", *arguments])


def _exec_arecord(arguments: list[str]) -> None:
    os.execvp("arecord", ["arecord", *arguments])


def _exec_ffmpeg(arguments: list[str]) -> None:
    os.execvp("ffmpeg", ["ffmpeg", *arguments])


def _exec_ffplay(arguments: list[str]) -> None:
    os.execvp("ffplay", ["ffplay", *arguments])


def _exec_gst(arguments: list[str]) -> None:
    os.execvp("gst-launch-1.0", ["gst-launch-1.0", *arguments])


def _exec_pacat(arguments: list[str]) -> None:
    os.execvp("pacat", ["pacat", *arguments])


def _exec_parec(arguments: list[str]) -> None:
    os.execvp("parec", ["parec", *arguments])


def _exec_python(arguments: list[str]) -> None:
    os.execvp("python", ["python", *arguments])


def _exec_python3(arguments: list[str]) -> None:
    os.execvp("python3", ["python3", *arguments])


EXECUTORS = {
    "aplay": _exec_aplay,
    "arecord": _exec_arecord,
    "ffmpeg": _exec_ffmpeg,
    "ffplay": _exec_ffplay,
    "gst-launch-1.0": _exec_gst,
    "pacat": _exec_pacat,
    "parec": _exec_parec,
    "python": _exec_python,
    "python3": _exec_python3,
}


def main() -> None:
    command = sys.argv[1:]
    validate_command(command)
    executable, *arguments = command
    EXECUTORS[executable](arguments)


if __name__ == "__main__":
    main()
