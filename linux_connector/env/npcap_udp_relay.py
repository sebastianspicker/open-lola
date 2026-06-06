"""Relay Windows/Npcap-captured LoLa UDP payloads into normal UDP.

Windows LoLa can inject packets on the vEthernet/Npcap adapter that are visible
to Npcap but not delivered into the WSL guest stack. This helper captures those
outbound packets with tshark and resends their UDP payloads via normal Winsock
UDP so Linux LoLa running in WSL can receive and decode them.
"""

from __future__ import annotations

import argparse
from contextlib import suppress
from dataclasses import dataclass
import ipaddress
import logging
import socket
import subprocess  # nosec B404
import time
from typing import IO, Protocol

logger = logging.getLogger(__name__)
MAX_UDP_PORT = 65_535
DEFAULT_TSHARK = r"C:\Program Files\Wireshark\tshark.exe"
ALLOWED_TSHARK_EXECUTABLES = frozenset({DEFAULT_TSHARK.lower(), "tshark"})


@dataclass(frozen=True)
class RelayProcessCommand:
    executable: str
    executable_name: str
    arguments: tuple[str, ...]

    @property
    def argv(self) -> list[str]:
        return [self.executable, *self.arguments]


class DatagramSender(Protocol):
    def sendto(self, payload: bytes, address: tuple[str, int]) -> int:
        ...


@dataclass
class RelaySockets:
    audio: socket.socket
    video: socket.socket


@dataclass
class RelayState:
    counts: dict[int, int]
    last_stats: float


@dataclass(frozen=True)
class CapturedUdpPayload:
    src_port: int
    payload: bytes


def send_payload_nonblocking(sock: DatagramSender, payload: bytes, address: tuple[str, int]) -> bool:
    try:
        sock.sendto(payload, address)
    except BlockingIOError:
        logger.warning("dropping relay payload because UDP send buffer is full: %s:%s", address[0], address[1])
        return False
    return True


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--tshark", default=DEFAULT_TSHARK)
    parser.add_argument("--interface", default="4", help="dumpcap/tshark interface number or name")
    parser.add_argument("--src-ip", default="172.24.144.1")
    parser.add_argument("--dst-ip", default="172.24.159.30")
    parser.add_argument("--audio-port", type=int, default=19788)
    parser.add_argument("--video-port", type=int, default=19798)
    parser.add_argument("--stats-interval", type=float, default=2.0)
    return parser.parse_args()


def validate_relay_args(args: argparse.Namespace) -> None:
    validate_process_argument(args.tshark, "tshark")
    validate_tshark_executable(args.tshark)
    validate_process_argument(args.interface, "interface")
    ipaddress.ip_address(args.src_ip)
    ipaddress.ip_address(args.dst_ip)
    validate_udp_port(args.audio_port, "audio-port")
    validate_udp_port(args.video_port, "video-port")
    if args.stats_interval <= 0:
        raise ValueError("stats-interval must be positive")


def build_tshark_command(args: argparse.Namespace) -> RelayProcessCommand:
    validate_relay_args(args)
    capture_filter = (
        f"udp and src host {args.src_ip} and dst host {args.dst_ip} and "
        f"(src port {args.audio_port} or src port {args.video_port})"
    )
    display_filter = (
        f"ip.src=={args.src_ip} && ip.dst=={args.dst_ip} && "
        f"(udp.srcport=={args.audio_port} || udp.srcport=={args.video_port})"
    )
    return RelayProcessCommand(
        executable=args.tshark,
        executable_name=tshark_executable_name(args.tshark),
        arguments=(
            "-l",
            "-i",
            args.interface,
            "-f",
            capture_filter,
            "-Y",
            display_filter,
            "-T",
            "fields",
            "-e",
            "udp.srcport",
            "-e",
            "udp.payload",
        ),
    )


def validate_process_argument(value: str, name: str) -> None:
    if not value:
        raise ValueError(f"{name} must not be empty")
    if any(ord(character) < 32 or ord(character) == 127 for character in value):
        raise ValueError(f"{name} must not contain control characters")


def tshark_executable_name(executable: str) -> str:
    return executable.rsplit("/", 1)[-1].rsplit("\\", 1)[-1].lower()


def validate_tshark_executable(executable: str) -> None:
    normalized = executable.lower()
    executable_name = tshark_executable_name(executable)
    if normalized not in ALLOWED_TSHARK_EXECUTABLES and executable_name not in ALLOWED_TSHARK_EXECUTABLES:
        raise ValueError("tshark must be the default Wireshark path or bare tshark")


def validate_udp_port(value: int, name: str) -> None:
    if value <= 0 or value > MAX_UDP_PORT:
        raise ValueError(f"{name} must be between 1 and {MAX_UDP_PORT}")


def start_tshark_capture(command: RelayProcessCommand) -> subprocess.Popen[str]:
    arguments = list(command.arguments)
    if command.executable.lower() == DEFAULT_TSHARK.lower():
        return subprocess.Popen(  # nosec B603
            [DEFAULT_TSHARK, *arguments],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,
        )
    if command.executable_name == "tshark":
        return subprocess.Popen(  # nosec B603 B607
            ["tshark", *arguments],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,
        )
    raise RuntimeError(f"unsupported tshark executable: {command.executable}")


def open_relay_sockets() -> RelaySockets:
    video_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    audio_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    video_sock.setblocking(False)
    audio_sock.setblocking(False)
    return RelaySockets(audio=audio_sock, video=video_sock)


def require_process_stdout(proc: subprocess.Popen[str]) -> IO[str]:
    if proc.stdout is None:
        raise RuntimeError("tshark process did not expose stdout")
    return proc.stdout


def parse_capture_line(line: str) -> CapturedUdpPayload | None:
    stripped = line.strip()
    if not stripped:
        return None
    try:
        port_text, payload_hex = stripped.split("\t", 1)
        return CapturedUdpPayload(
            src_port=int(port_text),
            payload=bytes.fromhex(payload_hex.replace(":", "")),
        )
    except ValueError:
        return None


def relay_payload(payload: CapturedUdpPayload, args: argparse.Namespace, sockets: RelaySockets, counts: dict[int, int]) -> None:
    if payload.src_port == args.video_port:
        # Preserve the LoLa UDP payload exactly; only the outer Windows
        # delivery path changes from Npcap injection to normal UDP.
        if send_payload_nonblocking(sockets.video, payload.payload, (args.dst_ip, args.video_port)):
            counts[args.video_port] += 1
    elif payload.src_port == args.audio_port:
        if send_payload_nonblocking(sockets.audio, payload.payload, (args.dst_ip, args.audio_port)):
            counts[args.audio_port] += 1


def log_relay_stats_if_due(args: argparse.Namespace, state: RelayState) -> None:
    now = time.monotonic()
    if now - state.last_stats < args.stats_interval:
        return
    logger.info("relayed audio=%s video=%s", state.counts[args.audio_port], state.counts[args.video_port])
    state.last_stats = now


def relay_capture_lines(stdout: IO[str], args: argparse.Namespace, sockets: RelaySockets) -> None:
    state = RelayState(counts={args.audio_port: 0, args.video_port: 0}, last_stats=time.monotonic())
    for line in stdout:
        payload = parse_capture_line(line)
        if payload is None:
            continue
        relay_payload(payload, args, sockets, state.counts)
        log_relay_stats_if_due(args, state)


def stop_relay_process(proc: subprocess.Popen[str]) -> None:
    proc.terminate()
    try:
        proc.wait(timeout=3)
    except subprocess.TimeoutExpired:
        proc.kill()
        with suppress(subprocess.TimeoutExpired):
            proc.wait(timeout=3)


def close_relay_sockets(sockets: RelaySockets) -> None:
    sockets.video.close()
    sockets.audio.close()


def main() -> int:
    args = parse_args()
    # Capture only original Windows LoLa media packets. The relay re-sends via
    # normal Winsock sockets with ephemeral source ports, so this src-port
    # filter prevents the relay from capturing and replaying its own output.
    cmd = build_tshark_command(args)
    sockets = open_relay_sockets()
    proc = start_tshark_capture(cmd)
    stdout = require_process_stdout(proc)
    logger.info("relay started %s", " ".join(cmd.argv))
    try:
        relay_capture_lines(stdout, args, sockets)
    except KeyboardInterrupt:
        pass
    finally:
        stop_relay_process(proc)
        close_relay_sockets(sockets)
    return 0


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(message)s")
    raise SystemExit(main())
