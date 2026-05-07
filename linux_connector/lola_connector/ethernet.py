"""Optional raw Ethernet/IPv4/UDP frame builder for LoLa media.

LoLa on Windows injects complete Ethernet frames with WinPcap/Npcap. A Linux
connector can usually send normal UDP payloads, but this module preserves the
recovered outer packet format for AF_PACKET/libpcap style transmitters.
"""

from __future__ import annotations

import ipaddress
import struct


ETHERTYPE_IPV4 = 0x0800
IP_ID = 0x1337
IP_TTL = 0x80
IP_PROTO_UDP = 0x11


def parse_mac(text: str) -> bytes:
    parts = text.replace("-", ":").split(":")
    if len(parts) != 6:
        raise ValueError(f"invalid MAC address: {text}")
    return bytes(int(part, 16) for part in parts)


def ipv4_bytes(text: str) -> bytes:
    return ipaddress.IPv4Address(text).packed


def internet_checksum(data: bytes) -> int:
    if len(data) % 2:
        data += b"\0"
    total = 0
    for offset in range(0, len(data), 2):
        total += (data[offset] << 8) + data[offset + 1]
        total = (total & 0xFFFF) + (total >> 16)
    return (~total) & 0xFFFF


def build_ipv4_udp_packet(src_ip: str, dst_ip: str, src_port: int, dst_port: int, payload: bytes, udp_checksum: bool = True) -> bytes:
    src = ipv4_bytes(src_ip)
    dst = ipv4_bytes(dst_ip)
    udp_len = 8 + len(payload)
    ip_len = 20 + udp_len

    ip_header = bytearray(20)
    ip_header[0] = 0x45
    struct.pack_into("!HHHBBH4s4s", ip_header, 2, ip_len, IP_ID, 0, IP_TTL, IP_PROTO_UDP, 0, src, dst)
    struct.pack_into("!H", ip_header, 10, internet_checksum(bytes(ip_header)))

    udp_header = bytearray(8)
    struct.pack_into("!HHHH", udp_header, 0, src_port, dst_port, udp_len, 0)
    if udp_checksum:
        pseudo = src + dst + struct.pack("!BBH", 0, IP_PROTO_UDP, udp_len)
        struct.pack_into("!H", udp_header, 6, internet_checksum(pseudo + bytes(udp_header) + payload))

    return bytes(ip_header) + bytes(udp_header) + payload


def build_ethernet_ipv4_udp_frame(
    src_mac: bytes | str,
    dst_mac: bytes | str,
    src_ip: str,
    dst_ip: str,
    src_port: int,
    dst_port: int,
    payload: bytes,
) -> bytes:
    src_mac_bytes = parse_mac(src_mac) if isinstance(src_mac, str) else src_mac
    dst_mac_bytes = parse_mac(dst_mac) if isinstance(dst_mac, str) else dst_mac
    if len(src_mac_bytes) != 6 or len(dst_mac_bytes) != 6:
        raise ValueError("source and destination MAC addresses must be 6 bytes")
    eth_header = dst_mac_bytes + src_mac_bytes + struct.pack("!H", ETHERTYPE_IPV4)
    return eth_header + build_ipv4_udp_packet(src_ip, dst_ip, src_port, dst_port, payload)
