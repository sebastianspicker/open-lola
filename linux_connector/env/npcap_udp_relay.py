"""Relay Windows/Npcap-captured LoLa UDP payloads into normal UDP.

Windows LoLa can inject packets on the vEthernet/Npcap adapter that are visible
to Npcap but not delivered into the WSL guest stack. This helper captures those
outbound packets with tshark and resends their UDP payloads via normal Winsock
UDP so Linux LoLa running in WSL can receive and decode them.
"""

from __future__ import annotations

import argparse
import socket
import subprocess
import sys
import time


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


def main() -> int:
    args = parse_args()
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
    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
    )
    assert proc.stdout is not None
    counts = {args.audio_port: 0, args.video_port: 0}
    last_stats = time.monotonic()
    print("relay started", " ".join(cmd), flush=True)
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
                video_sock.sendto(payload, (args.dst_ip, args.video_port))
                counts[args.video_port] += 1
            elif src_port == args.audio_port:
                audio_sock.sendto(payload, (args.dst_ip, args.audio_port))
                counts[args.audio_port] += 1
            now = time.monotonic()
            if now - last_stats >= args.stats_interval:
                print(
                    f"relayed audio={counts[args.audio_port]} video={counts[args.video_port]}",
                    flush=True,
                )
                last_stats = now
    except KeyboardInterrupt:
        pass
    finally:
        proc.terminate()
        video_sock.close()
        audio_sock.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
