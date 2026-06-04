"""Relay Windows/Npcap-captured LoLa UDP payloads into normal UDP.

Windows LoLa can inject packets on the vEthernet/Npcap adapter that are visible
to Npcap but not delivered into the WSL guest stack. This helper captures those
outbound packets with tshark and resends their UDP payloads via normal Winsock
UDP so Linux LoLa running in WSL can receive and decode them.
"""

from __future__ import annotations

import argparse
from contextlib import suppress
import ipaddress
import logging
import socket
import subprocess
import time
from typing import Protocol

logger = logging.getLogger(__name__)
MAX_UDP_PORT = 65_535


class DatagramSender(Protocol):
    def sendto(self, payload: bytes, address: tuple[str, int]) -> int:
        ...


def send_payload_nonblocking(sock: DatagramSender, payload: bytes, address: tuple[str, int]) -> bool:
    try:
        sock.sendto(payload, address)
    except BlockingIOError:
        logger.warning("dropping relay payload because UDP send buffer is full: %s:%s", address[0], address[1])
        return False
    return True


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--tshark", default=r"C:\Program Files\Wireshark\tshark.exe")
    parser.add_argument("--interface", default="4", help="dumpcap/tshark interface number or name")
    parser.add_argument("--src-ip", default="172.24.144.1")
    parser.add_argument("--dst-ip", default="172.24.159.30")
    parser.add_argument("--audio-port", type=int, default=19788)
    parser.add_argument("--video-port", type=int, default=19798)
    parser.add_argument("--stats-interval", type=float, default=2.0)
    return parser.parse_args()


def validate_relay_args(args: argparse.Namespace) -> None:
    validate_process_argument(args.tshark, "tshark")
    validate_process_argument(args.interface, "interface")
    ipaddress.ip_address(args.src_ip)
    ipaddress.ip_address(args.dst_ip)
    validate_udp_port(args.audio_port, "audio-port")
    validate_udp_port(args.video_port, "video-port")
    if args.stats_interval <= 0:
        raise ValueError("stats-interval must be positive")


def validate_process_argument(value: str, name: str) -> None:
    if not value:
        raise ValueError(f"{name} must not be empty")
    if any(ord(character) < 32 or ord(character) == 127 for character in value):
        raise ValueError(f"{name} must not contain control characters")


def validate_udp_port(value: int, name: str) -> None:
    if value <= 0 or value > MAX_UDP_PORT:
        raise ValueError(f"{name} must be between 1 and {MAX_UDP_PORT}")


def main() -> int:
    args = parse_args()
    validate_relay_args(args)
    # Capture only original Windows LoLa media packets. The relay re-sends via
    # normal Winsock sockets with ephemeral source ports, so this src-port
    # filter prevents the relay from capturing and replaying its own output.
    capture_filter = (
        f"udp and src host {args.src_ip} and dst host {args.dst_ip} and "
        f"(src port {args.audio_port} or src port {args.video_port})"
    )
    display_filter = (
        f"ip.src=={args.src_ip} && ip.dst=={args.dst_ip} && "
        f"(udp.srcport=={args.audio_port} || udp.srcport=={args.video_port})"
    )
    cmd = [
        args.tshark,
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
    ]
    video_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    audio_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    video_sock.setblocking(False)
    audio_sock.setblocking(False)
    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
    )
    if proc.stdout is None:
        raise RuntimeError("tshark process did not expose stdout")
    counts = {args.audio_port: 0, args.video_port: 0}
    last_stats = time.monotonic()
    logger.info("relay started %s", " ".join(cmd))
    try:
        for line in proc.stdout:
            line = line.strip()
            if not line:
                continue
            try:
                port_text, payload_hex = line.split("\t", 1)
                src_port = int(port_text)
                payload = bytes.fromhex(payload_hex.replace(":", ""))
            except ValueError:
                continue
            if src_port == args.video_port:
                # Preserve the LoLa UDP payload exactly; only the outer Windows
                # delivery path changes from Npcap injection to normal UDP.
                if send_payload_nonblocking(video_sock, payload, (args.dst_ip, args.video_port)):
                    counts[args.video_port] += 1
            elif src_port == args.audio_port:
                if send_payload_nonblocking(audio_sock, payload, (args.dst_ip, args.audio_port)):
                    counts[args.audio_port] += 1
            now = time.monotonic()
            if now - last_stats >= args.stats_interval:
                logger.info("relayed audio=%s video=%s", counts[args.audio_port], counts[args.video_port])
                last_stats = now
    except KeyboardInterrupt:
        pass
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=3)
        except subprocess.TimeoutExpired:
            proc.kill()
            with suppress(subprocess.TimeoutExpired):
                proc.wait(timeout=3)
        video_sock.close()
        audio_sock.close()
    return 0


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(message)s")
    raise SystemExit(main())
