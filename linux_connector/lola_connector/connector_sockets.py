"""Bound UDP socket construction for the Linux LoLa connector."""

from __future__ import annotations

from collections.abc import Callable
import logging
import socket


logger = logging.getLogger(__name__)

_AUDIO_SOCKET_BUFFER_BYTES = 2 * 0x42A
_VIDEO_SOCKET_BUFFER_BYTES = 256 * 1024


def media_socket_buffer_bytes(bind_port: int, audio_port: int, video_port: int) -> int | None:
    """Select the bounded kernel-buffer request for one negotiated media port."""
    if bind_port == audio_port:
        return _AUDIO_SOCKET_BUFFER_BYTES
    if bind_port == video_port:
        return _VIDEO_SOCKET_BUFFER_BYTES
    return None


def configure_media_socket_buffers(
    sock: socket.socket,
    local_ip: str,
    bind_port: int,
    buffer_bytes: int | None,
) -> None:
    """Apply best-effort receive and send buffer bounds for a media socket."""
    if buffer_bytes is None:
        return
    for option in (socket.SO_RCVBUF, socket.SO_SNDBUF):
        try:
            sock.setsockopt(socket.SOL_SOCKET, option, buffer_bytes)
        except OSError as error:
            logger.warning(
                "UDP media socket buffer setup failed for %s:%s option=%s errno=%s: %s",
                local_ip,
                bind_port,
                option,
                error.errno,
                error,
            )


def make_bound_udp_socket(
    local_ip: str,
    bind_port: int,
    audio_port: int,
    video_port: int,
    close_socket: Callable[[socket.socket], None],
) -> socket.socket:
    """Create one nonblocking connector socket with bounded media buffering."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        configure_media_socket_buffers(
            sock,
            local_ip,
            bind_port,
            media_socket_buffer_bytes(bind_port, audio_port, video_port),
        )
        if hasattr(socket, "SO_REUSEPORT"):
            try:
                sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
            except OSError as error:
                logger.warning(
                    "SO_REUSEPORT unavailable on UDP socket for %s:%s: %s",
                    local_ip,
                    bind_port,
                    error,
                )
        sock.setblocking(False)
        sock.bind((local_ip, bind_port))
    except OSError as error:
        logger.warning(
            "UDP socket setup failed for %s:%s errno=%s: %s",
            local_ip,
            bind_port,
            error.errno,
            error,
        )
        close_socket(sock)
        raise
    except Exception:
        close_socket(sock)
        raise
    return sock
