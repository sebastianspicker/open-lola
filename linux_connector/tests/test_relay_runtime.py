# pylint: disable=missing-function-docstring
"""Tests for the Windows packet relay helpers."""

from __future__ import annotations

import argparse
import asyncio

import pytest

from linux_connector.env.npcap_udp_relay import (
    build_tshark_command,
    require_process_stdout,
    resolve_tshark_executable,
    send_payload_nonblocking,
    start_tshark_capture,
    stop_relay_process,
    validate_relay_args,
)


def expect_false(condition: object, label: str) -> None:
    if condition:
        pytest.fail(f"{label}: expected falsey value")


def expect_equal(actual: object, expected: object, label: str) -> None:
    if actual != expected:
        pytest.fail(f"{label}: expected {expected!r}, got {actual!r}")


def expect_true(condition: object, label: str) -> None:
    if not condition:
        pytest.fail(f"{label}: expected truthy value")


def relay_args() -> argparse.Namespace:
    return argparse.Namespace(
        tshark=r"C:\Program Files\Wireshark\tshark.exe",
        interface="4",
        src_ip="172.24.144.1",
        dst_ip="172.24.159.30",
        audio_port=19788,
        video_port=19798,
        stats_interval=2.0,
    )


def test_relay_drops_would_block_send() -> None:
    class BlockingSocket:  # pylint: disable=missing-class-docstring,too-few-public-methods
        def sendto(self, payload: bytes, address: tuple[str, int]) -> int:
            _ = payload
            _ = address
            raise BlockingIOError("send buffer full")

    expect_false(
        send_payload_nonblocking(BlockingSocket(), b"payload", ("127.0.0.1", 19788)),
        "nonblocking relay send",
    )


def test_relay_validates_process_and_filter_arguments() -> None:
    args = relay_args()

    validate_relay_args(args)

    args.tshark = r"D:\Tools\tshark.exe"
    with pytest.raises(ValueError, match="default Wireshark path"):
        validate_relay_args(args)
    args.tshark = r"C:\Program Files\Wireshark\tshark.exe"

    args.interface = "4\n-Y unsafe"
    with pytest.raises(ValueError, match="control characters"):
        validate_relay_args(args)
    args.interface = "4"
    args.src_ip = "not-an-ip"
    with pytest.raises(ValueError):
        validate_relay_args(args)
    args.src_ip = "172.24.144.1"
    args.audio_port = 0
    with pytest.raises(ValueError, match="audio-port"):
        validate_relay_args(args)


def test_relay_builds_validated_tshark_command() -> None:
    args = relay_args()

    command = build_tshark_command(args)

    expect_equal(command.executable, r"C:\Program Files\Wireshark\tshark.exe", "relay executable")
    expect_equal(command.executable_name, "tshark.exe", "relay executable name")
    expect_equal(command.arguments[:4], ("-l", "-i", "4", "-f"), "relay capture prefix")
    expect_true("src host 172.24.144.1" in command.argv[5], "relay capture filter source")
    expect_true("udp.srcport==19788" in command.argv[7], "relay display filter audio port")

    args.tshark = ""
    with pytest.raises(ValueError, match="tshark"):
        build_tshark_command(args)

    args.tshark = "tshark"
    command = build_tshark_command(args)
    expect_equal(command.executable_name, "tshark", "bare relay executable name")


def test_relay_resolves_bare_tshark_to_absolute_path(monkeypatch: pytest.MonkeyPatch) -> None:
    args = relay_args()
    args.tshark = "tshark"
    command = build_tshark_command(args)
    monkeypatch.setattr(
        "linux_connector.env.npcap_udp_relay.shutil.which",
        lambda _: "/usr/bin/tshark",
    )

    expect_equal(resolve_tshark_executable(command), "/usr/bin/tshark", "resolved tshark path")


def test_relay_async_start_uses_resolved_tshark_without_shell(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    args = relay_args()
    args.tshark = "tshark"
    command = build_tshark_command(args)
    calls: list[tuple[object, ...]] = []

    monkeypatch.setattr(
        "linux_connector.env.npcap_udp_relay.shutil.which",
        lambda _: "/usr/bin/tshark",
    )

    async def fake_create(*argv: object, **kwargs: object) -> object:
        calls.append(argv)
        expect_equal(kwargs.get("stdout"), asyncio.subprocess.PIPE, "relay stdout pipe")
        expect_equal(kwargs.get("stderr"), asyncio.subprocess.DEVNULL, "relay stderr sink")
        return object()

    monkeypatch.setattr(
        "linux_connector.env.npcap_udp_relay.asyncio.create_subprocess_exec",
        fake_create,
    )
    asyncio.run(start_tshark_capture(command))

    expect_true(calls, "relay subprocess launch")
    expect_equal(calls[0][0], "/usr/bin/tshark", "resolved relay executable")
    expect_equal(calls[0][1], "-l", "relay line-buffer flag")
    expect_true("-f" in calls[0], "relay capture arguments")


def test_relay_async_stdout_and_stop_contract() -> None:
    class Process:
        stdout = object()
        returncode = None

        def __init__(self) -> None:
            self.terminated = False
            self.waited = False

        def terminate(self) -> None:
            self.terminated = True

        async def wait(self) -> int:
            self.waited = True
            self.returncode = 0
            return 0

    process = Process()
    expect_true(require_process_stdout(process) is process.stdout, "relay stdout stream")
    asyncio.run(stop_relay_process(process))
    expect_true(process.terminated, "relay process terminated")
    expect_true(process.waited, "relay process waited")
