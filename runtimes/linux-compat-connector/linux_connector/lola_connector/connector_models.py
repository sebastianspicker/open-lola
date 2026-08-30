"""Typed connector state shared by the facade and composed services."""

from __future__ import annotations

from dataclasses import dataclass

from .protocol import DEFAULT_AUDIO_PORT, DEFAULT_CONTROL_PORT, DEFAULT_VIDEO_PORT, MediaSettings


@dataclass
class Session:
    """Bind negotiated peer settings and identifiers to one LoLa media session."""

    local_ip: str
    remote_ip: str
    sid: int
    remote_settings: MediaSettings


@dataclass(frozen=True)
class StatusCheckResult:
    """Report status-probe acknowledgement and rejected-datagram evidence."""

    acknowledged: bool
    reason: str
    response_ip: str | None = None
    response_kind: str | None = None
    malformed_datagrams: int = 0
    wrong_peer_datagrams: int = 0
    unexpected_datagrams: int = 0
    sent_dialects: tuple[str, ...] = ()

    def __bool__(self) -> bool:
        return self.acknowledged


@dataclass(frozen=True)
class LolaConnectorOptions:
    """Collect named optional behavior for a LoLa connector."""

    control_port: int = DEFAULT_CONTROL_PORT
    audio_port: int = DEFAULT_AUDIO_PORT
    video_port: int = DEFAULT_VIDEO_PORT
    video_packet_size: int = 1000
    control_dialect: str = "ascii"
    source_name: str = ""


@dataclass
class _ControlReceiveStats:
    malformed_datagrams: int = 0
    wrong_peer_datagrams: int = 0
    unexpected_datagrams: int = 0


@dataclass(frozen=True)
class _ControlSendRequest:
    kind: str
    remote_ip: str
    sid: int
    txt: str = ""
    dialect: str | None = None
    settings: MediaSettings | None = None
    remote_port: int | None = None


@dataclass
class _StatusProbeState:
    stats: _ControlReceiveStats
    response_ip: str | None = None
    response_kind: str | None = None
    reason: str = "timeout"


@dataclass(frozen=True)
class QuickConnResult:
    """Report QuickConn acceptance, peer metadata, and rejection evidence."""

    session: Session | None
    reason: str
    response_ip: str | None = None
    response_kind: str | None = None
    response_text: str = ""
    malformed_datagrams: int = 0
    wrong_peer_datagrams: int = 0
    unexpected_datagrams: int = 0

    def __bool__(self) -> bool:
        return self.session is not None
