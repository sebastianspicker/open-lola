"""Pure acceptance and rejection policy for LoLa control responses."""

from __future__ import annotations

from .connector_models import (
    QuickConnResult,
    Session,
    StatusCheckResult,
    _ControlReceiveStats,
    _StatusProbeState,
)
from .protocol import MESG_CHAT, MESG_CHECKLOLASTATUS_ACK, MESG_REJECT, ControlMessage


def quickconn_timeout_result(stats: _ControlReceiveStats) -> QuickConnResult:
    """Turn observed receive failures into a stable QuickConn result."""
    return QuickConnResult(
        session=None,
        reason=control_receive_failure_reason(stats),
        malformed_datagrams=stats.malformed_datagrams,
        wrong_peer_datagrams=stats.wrong_peer_datagrams,
        unexpected_datagrams=stats.unexpected_datagrams,
    )


def accepted_quickconn_result(
    session: Session, msg: ControlMessage, addr: tuple[str, int], stats: _ControlReceiveStats
) -> QuickConnResult:
    """Report an accepted QuickConn together with discarded datagram evidence."""
    return QuickConnResult(
        session=session,
        reason="ack",
        response_ip=addr[0],
        response_kind=msg.kind,
        malformed_datagrams=stats.malformed_datagrams,
        wrong_peer_datagrams=stats.wrong_peer_datagrams,
        unexpected_datagrams=stats.unexpected_datagrams,
    )


def rejected_quickconn_result(
    msg: ControlMessage, addr: tuple[str, int], stats: _ControlReceiveStats
) -> QuickConnResult:
    """Report an explicit peer rejection."""
    return QuickConnResult(
        session=None,
        reason="rejected",
        response_ip=addr[0],
        response_kind=msg.kind,
        response_text=msg.txt,
        malformed_datagrams=stats.malformed_datagrams,
        wrong_peer_datagrams=stats.wrong_peer_datagrams,
        unexpected_datagrams=stats.unexpected_datagrams,
    )


def control_response_rejection_reason(
    msg: ControlMessage, addr: tuple[str, int], remote_ip: str, local_ip: str, sid: int, control_port: int
) -> str | None:
    """Return why an initiator must ignore a control-plane response."""
    if addr != (remote_ip, control_port):
        return "wrong-peer"
    if msg.dialect == "osc15":
        return None
    if msg.src_ip != remote_ip or msg.dst_ip != local_ip:
        return "wrong-peer"
    return None if msg.fields.get("SID") == str(sid) else "unexpected-response"


def record_control_response_rejection(stats: _ControlReceiveStats, reason: str) -> None:
    """Count peer and protocol mismatches consistently."""
    if reason == "wrong-peer":
        stats.wrong_peer_datagrams += 1
    else:
        stats.unexpected_datagrams += 1


def handle_status_response(
    msg: ControlMessage,
    addr: tuple[str, int],
    remote_ip: str,
    sent_dialects: tuple[str, ...],
    state: _StatusProbeState,
    *,
    local_ip: str,
    sid: int,
    control_port: int,
) -> StatusCheckResult | None:
    """Accept only a status ACK bound to the probe's peer and session."""
    reason = control_response_rejection_reason(msg, addr, remote_ip, local_ip, sid, control_port)
    if reason is not None:
        record_control_response_rejection(state.stats, reason)
        state.response_ip, state.reason = addr[0], reason
        return None
    if msg.kind != MESG_CHECKLOLASTATUS_ACK:
        state.stats.unexpected_datagrams += 1
        state.response_ip, state.response_kind, state.reason = addr[0], msg.kind, "unexpected-response"
        return None
    return StatusCheckResult(
        acknowledged=True,
        reason="ack",
        response_ip=addr[0],
        response_kind=msg.kind,
        malformed_datagrams=state.stats.malformed_datagrams,
        wrong_peer_datagrams=state.stats.wrong_peer_datagrams,
        unexpected_datagrams=state.stats.unexpected_datagrams,
        sent_dialects=sent_dialects,
    )


def status_timeout_result(state: _StatusProbeState, sent_dialects: tuple[str, ...]) -> StatusCheckResult:
    """Build the terminal negative status result from observed evidence."""
    if state.reason == "timeout" and state.stats.malformed_datagrams:
        state.reason = "malformed-response"
    return StatusCheckResult(
        acknowledged=False,
        reason=state.reason,
        response_ip=state.response_ip,
        response_kind=state.response_kind,
        malformed_datagrams=state.stats.malformed_datagrams,
        wrong_peer_datagrams=state.stats.wrong_peer_datagrams,
        unexpected_datagrams=state.stats.unexpected_datagrams,
        sent_dialects=sent_dialects,
    )


def stateless_control_action(msg: ControlMessage) -> str:
    """Map session-independent control messages to host actions."""
    if msg.kind == MESG_CHAT:
        return "chat"
    if msg.kind == MESG_REJECT:
        return "reject"
    return "ignore"


def control_receive_failure_reason(stats: _ControlReceiveStats) -> str:
    """Prioritize the observable reason why a control exchange ended."""
    if stats.unexpected_datagrams:
        return "unexpected-response"
    if stats.wrong_peer_datagrams:
        return "wrong-peer"
    return "malformed-response" if stats.malformed_datagrams else "timeout"
