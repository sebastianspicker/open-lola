"""Tests for Linux process runtime behavior."""

# pylint: disable=missing-function-docstring

from __future__ import annotations

import asyncio
from contextlib import contextmanager
import socket
from collections.abc import Iterator
from typing import cast

import pytest

import linux_connector.lola_connector.connector as connector_module
import linux_connector.lola_connector.selftest as selftest_module
from linux_connector.lola_connector.connector import LolaConnector, QuickConnResult, _ControlSendRequest
from linux_connector.lola_connector.connector import StatusCheckResult
from linux_connector.lola_connector.protocol import (
    CONTROL_DATAGRAM_SIZE,
    MESG_CHAT,
    MESG_CHECKLOLASTATUS,
    MESG_CHECKLOLASTATUS_ACK,
    MESG_QUICKCONN,
    MESG_QUICKCONN_ACK,
    MediaSettings,
    build_control_datagram,
    build_osc15_control_datagram,
    parse_control_datagram,
)
from linux_connector.lola_connector.selftest import loopback_alias_capability
from linux_connector.tests.support import (
    expect_equal,
    expect_false,
    expect_is_none,
    expect_startswith,
    expect_true,
    require_loopback_alias,
)


class _MissingAliasSocket:
    def bind(self, _address: tuple[str, int]) -> None:
        raise OSError("alias unavailable")

    def close(self) -> None:
        return None


def _missing_alias_socket(*_args: object, **_kwargs: object) -> _MissingAliasSocket:
    return _MissingAliasSocket()


def _probe_receiver(datagrams: list[tuple[bytes, tuple[str, int]]]):
    async def receive(_sock: object, _size: int) -> tuple[bytes, tuple[str, int]]:
        if datagrams:
            return datagrams.pop(0)
        raise asyncio.TimeoutError

    return receive


def _expect_probe_counts(result: object, expected: tuple[str, str, int, int, int]) -> None:
    label, reason, malformed, wrong_peer, unexpected = expected
    expect_equal(getattr(result, "reason"), reason, f"{label} reason")
    expect_equal(getattr(result, "malformed_datagrams"), malformed, f"{label} malformed datagrams")
    expect_equal(getattr(result, "wrong_peer_datagrams"), wrong_peer, f"{label} wrong-peer datagrams")
    expect_equal(getattr(result, "unexpected_datagrams"), unexpected, f"{label} unexpected datagrams")


def _expect_malformed_quickconn(result: QuickConnResult, sent_controls: object) -> None:
    expect_false(result, "quickconn result")
    expect_is_none(result.session, "quickconn session")
    _expect_probe_counts(result, ("quickconn", "malformed-response", 1, 0, 0))
    expect_equal(sent_controls, [(MESG_QUICKCONN, "10.0.0.2", 7, None)], "sent quickconn controls")


def test_connector_audio_signal_request_is_event_owned() -> None:
    connector = LolaConnector("127.0.0.1", MediaSettings(width=16, height=8))

    expect_false(hasattr(connector, "audio_signal_requested"), "legacy audio signal attribute")


def test_udp_selftest_loopback_alias_capability_reports_missing_alias(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(socket, "socket", _missing_alias_socket)

    available, message = loopback_alias_capability("127.0.0.2")

    expect_false(available, "loopback alias availability")
    expect_equal(
        message,
        "loopback alias 127.0.0.2 is not available: alias unavailable",
        "loopback alias message",
    )


@pytest.mark.usefixtures("require_localhost_udp")
def test_udp_selftest_loopback_alias_capability_reports_available_alias() -> None:
    available, message = loopback_alias_capability("127.0.0.1")

    expect_true(available, "loopback alias availability")
    expect_equal(message, "loopback alias 127.0.0.1 is available", "loopback alias message")


def test_udp_selftest_loopback_alias_capability_reports_current_environment() -> None:
    available, message = loopback_alias_capability("127.0.0.2")

    if available:
        expect_equal(message, "loopback alias 127.0.0.2 is available", "loopback alias message")
    else:
        expect_startswith(
            message,
            "loopback alias 127.0.0.2 is not available:",
            "loopback alias message",
        )


def test_udp_selftest_loopback_alias_requirement_skips_missing_alias(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(socket, "socket", _missing_alias_socket)

    with pytest.raises(pytest.skip.Exception, match="loopback alias 127.0.0.2 is not available"):
        require_loopback_alias()


class StatusProbeConnector(LolaConnector):  # pylint: disable=missing-class-docstring
    def __init__(
        self,
        local_ip: str,
        settings: MediaSettings | None = None,
        control_dialect: str = "ascii",
    ) -> None:
        """Create a connector that records status probe controls."""
        super().__init__(
            local_ip,
            settings,
            7000,
            19788,
            19798,
            1000,
            control_dialect,
            "",
        )
        self.sent_controls: list[tuple[str, str, int, str | None]] = []

    @contextmanager
    def udp_socket(self, bind_port: int = 0) -> Iterator[socket.socket]:
        _ = bind_port
        yield cast(socket.socket, object())

    async def _send_control(
        self,
        _sock: socket.socket,
        request: _ControlSendRequest,
    ) -> None:
        self.sent_controls.append((request.kind, request.remote_ip, request.sid, request.dialect))


def run_status_probe(
    monkeypatch: pytest.MonkeyPatch,
    datagrams: list[tuple[bytes, tuple[str, int]]],
    *,
    control_dialect: str = "ascii",
) -> tuple[StatusCheckResult, list[tuple[str, str, int, str | None]]]:
    monkeypatch.setattr(connector_module, "udp_recvfrom", _probe_receiver(datagrams))

    async def run() -> tuple[StatusCheckResult, list[tuple[str, str, int, str | None]]]:
        connector = StatusProbeConnector("10.0.0.1", control_dialect=control_dialect)
        result = await connector.check_status_result("10.0.0.2", sid=7, timeout=0.1)
        return result, connector.sent_controls

    return asyncio.run(run())


def test_control_send_request_preserves_production_and_selftest_routes(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    sent: list[tuple[bytes, tuple[str, int]]] = []

    async def capture(_sock: object, payload: bytes, address: tuple[str, int]) -> bool:
        sent.append((payload, address))
        return True

    monkeypatch.setattr(connector_module, "udp_sendto", capture)
    production = LolaConnector("10.0.0.1", MediaSettings(), control_port=19000)
    asyncio.run(
        production._send_control(
            cast(socket.socket, object()),
            _ControlSendRequest(MESG_CHAT, "10.0.0.2", 7),
        )
    )
    expect_equal(sent[-1][1], ("10.0.0.2", 19000), "production control port")
    production_message = parse_control_datagram(sent[-1][0])
    assert production_message is not None
    expect_equal(production_message.dialect, "ascii", "production default dialect")
    expect_equal(production_message.media, production.settings, "production default settings")

    monkeypatch.setattr(selftest_module, "udp_sendto", capture)
    ports = selftest_module._SelftestPorts(19001, 19002, 19003)
    peer_ports = selftest_module._SelftestPorts(19011, 19012, 19013)
    selftest = selftest_module._SelftestConnector("10.0.0.1", MediaSettings(), ports, peer_ports)
    selftest.source_name = "selftest-peer"
    custom = MediaSettings(sample_rate=48_000)
    asyncio.run(
        selftest._send_control(
            cast(socket.socket, object()),
            _ControlSendRequest(MESG_CHAT, "10.0.0.2", 7, "hello", "osc15"),
        )
    )
    expect_equal(sent[-1][1], ("10.0.0.2", 19011), "selftest paired control port")
    chat_message = parse_control_datagram(sent[-1][0])
    assert chat_message is not None
    expect_equal(chat_message.dialect, "osc15", "selftest explicit dialect")
    expect_equal(chat_message.src_ip, selftest.source_name, "selftest source name")
    expect_equal(chat_message.txt, "hello", "selftest explicit text")

    asyncio.run(
        selftest._send_control(
            cast(socket.socket, object()),
            _ControlSendRequest(MESG_QUICKCONN, "10.0.0.2", 7, dialect="osc15", settings=custom),
        )
    )
    quickconn_message = parse_control_datagram(sent[-1][0])
    assert quickconn_message is not None
    expect_equal(quickconn_message.media, custom, "selftest explicit settings")


def run_quickconn_probe(
    monkeypatch: pytest.MonkeyPatch,
    datagrams: list[tuple[bytes, tuple[str, int]]],
    *,
    control_dialect: str = "ascii",
) -> tuple[QuickConnResult, list[tuple[str, str, int, str | None]]]:
    monkeypatch.setattr(connector_module, "udp_recvfrom", _probe_receiver(datagrams))

    async def run() -> tuple[QuickConnResult, list[tuple[str, str, int, str | None]]]:
        connector = StatusProbeConnector("10.0.0.1", control_dialect=control_dialect)
        result = await connector.initiate_result("10.0.0.2", sid=7, timeout=0.1)
        return result, connector.sent_controls

    return asyncio.run(run())


def test_status_probe_result_reports_ack(monkeypatch: pytest.MonkeyPatch) -> None:
    datagram = build_control_datagram(MESG_CHECKLOLASTATUS_ACK, "10.0.0.2", "10.0.0.1", 7)

    result, sent_controls = run_status_probe(monkeypatch, [(datagram, ("10.0.0.2", 7000))])

    expect_true(result.acknowledged, "status ack")
    expect_equal(result.reason, "ack", "status reason")
    expect_equal(result.response_ip, "10.0.0.2", "status response IP")
    expect_equal(result.response_kind, MESG_CHECKLOLASTATUS_ACK, "status response kind")
    expect_equal(result.sent_dialects, ("ascii",), "status sent dialects")
    expect_equal(
        sent_controls,
        [(MESG_CHECKLOLASTATUS, "10.0.0.2", 7, None)],
        "sent status controls",
    )


def test_quickconn_result_reports_malformed_ack(monkeypatch: pytest.MonkeyPatch) -> None:
    malformed_ack = b"/MESG_QUICKCONN_ACK;SRCIP:10.0.0.2;DSTIP:10.0.0.1;SID:7;SR:garbage".ljust(
        CONTROL_DATAGRAM_SIZE, b"\0"
    )

    result, sent_controls = run_quickconn_probe(monkeypatch, [(malformed_ack, ("10.0.0.2", 7000))])

    _expect_malformed_quickconn(result, sent_controls)


def test_quickconn_result_reports_incomplete_ack_as_malformed(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    incomplete_ack = (
        b"/MESG_QUICKCONN_ACK;SRCIP:10.0.0.2;DSTIP:10.0.0.1;SID:7;"
        b"SR:44100;BPS:16;CHNLS:2;FPS:25;BPP:8;X:640;Y:480;COMP:0"
    ).ljust(CONTROL_DATAGRAM_SIZE, b"\0")

    result, sent_controls = run_quickconn_probe(monkeypatch, [(incomplete_ack, ("10.0.0.2", 7000))])

    _expect_malformed_quickconn(result, sent_controls)


def test_quickconn_result_reports_wrong_peer_control_datagram(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    datagram = build_control_datagram(MESG_QUICKCONN_ACK, "10.0.0.3", "10.0.0.1", 7)

    result, _sent_controls = run_quickconn_probe(monkeypatch, [(datagram, ("10.0.0.3", 7000))])

    expect_false(result, "quickconn result")
    _expect_probe_counts(result, ("quickconn", "wrong-peer", 0, 1, 0))


@pytest.mark.parametrize(
    ("kind", "src_ip", "dst_ip", "sid", "addr", "expected"),
    [
        (MESG_QUICKCONN_ACK, "10.0.0.2", "10.0.0.1", 7, ("10.0.0.2", 7001), ("wrong-peer", 0, 1, 0)),
        (MESG_QUICKCONN_ACK, "10.0.0.2", "10.0.0.1", 6, ("10.0.0.2", 7000), ("unexpected-response", 0, 0, 1)),
        (MESG_QUICKCONN_ACK, "10.0.0.3", "10.0.0.1", 7, ("10.0.0.2", 7000), ("wrong-peer", 0, 1, 0)),
        (MESG_QUICKCONN_ACK, "10.0.0.2", "10.0.0.3", 7, ("10.0.0.2", 7000), ("wrong-peer", 0, 1, 0)),
    ],
    ids=["wrong-port", "stale-sid", "claimed-source", "wrong-destination"],
)
def test_quickconn_result_rejects_unbound_ascii_ack(
    monkeypatch: pytest.MonkeyPatch,
    kind: str,
    src_ip: str,
    dst_ip: str,
    sid: int,
    addr: tuple[str, int],
    expected: tuple[str, int, int, int],
) -> None:
    datagram = build_control_datagram(kind, src_ip, dst_ip, sid)

    result, _sent_controls = run_quickconn_probe(monkeypatch, [(datagram, addr)])

    reason, malformed, wrong_peer, unexpected = expected
    _expect_probe_counts(result, ("quickconn", reason, malformed, wrong_peer, unexpected))


def test_quickconn_result_accepts_osc15_ack_without_ascii_binding_fields(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    datagram = build_osc15_control_datagram(
        MESG_QUICKCONN_ACK,
        "10.0.0.2",
        "10.0.0.1",
        7,
        source_name="legacy-source-name",
    )

    result, _sent_controls = run_quickconn_probe(
        monkeypatch,
        [(datagram, ("10.0.0.2", 7000))],
        control_dialect="osc15",
    )

    expect_true(result, "OSC15 quickconn result")


@pytest.mark.parametrize(
    ("field", "value"),
    [("SR", "48000"), ("BPS", "24"), ("CHNLS", "1")],
    ids=["sample-rate", "bits-per-sample", "channels"],
)
def test_quickconn_ack_rejects_incompatible_audio_without_installing_session(
    monkeypatch: pytest.MonkeyPatch,
    field: str,
    value: str,
) -> None:
    settings = MediaSettings()
    fields = settings.control_fields().replace(f"{field}:{getattr(settings, {'SR': 'sample_rate', 'BPS': 'bits_per_sample', 'CHNLS': 'channels'}[field])}", f"{field}:{value}")
    datagram = (
        f"/MESG_QUICKCONN_ACK;SRCIP:10.0.0.2;DSTIP:10.0.0.1;SID:7;{fields}".encode().ljust(CONTROL_DATAGRAM_SIZE, b"\0")
    )

    result, _sent_controls = run_quickconn_probe(monkeypatch, [(datagram, ("10.0.0.2", 7000))])

    expect_false(result, "incompatible QuickConn ACK")
    expect_equal(result.reason, "incompatible-media", "incompatible ACK reason")


def test_quickconn_result_reports_timeout_without_ack(monkeypatch: pytest.MonkeyPatch) -> None:
    result, _sent_controls = run_quickconn_probe(monkeypatch, [])

    expect_false(result, "quickconn result")
    _expect_probe_counts(result, ("quickconn", "timeout", 0, 0, 0))


def test_status_probe_result_reports_timeout(monkeypatch: pytest.MonkeyPatch) -> None:
    result, _sent_controls = run_status_probe(monkeypatch, [])

    expect_false(result.acknowledged, "status ack")
    _expect_probe_counts(result, ("status", "timeout", 0, 0, 0))


def test_status_probe_result_reports_malformed_response(monkeypatch: pytest.MonkeyPatch) -> None:
    result, _sent_controls = run_status_probe(monkeypatch, [(b"not lola", ("10.0.0.2", 7000))])

    expect_false(result.acknowledged, "status ack")
    expect_equal(result.reason, "malformed-response", "status reason")
    expect_equal(result.malformed_datagrams, 1, "status malformed datagrams")


def test_status_probe_result_reports_wrong_peer(monkeypatch: pytest.MonkeyPatch) -> None:
    datagram = build_control_datagram(MESG_CHECKLOLASTATUS_ACK, "10.0.0.3", "10.0.0.1", 7)

    result, _sent_controls = run_status_probe(monkeypatch, [(datagram, ("10.0.0.3", 7000))])

    expect_false(result.acknowledged, "status ack")
    expect_equal(result.reason, "wrong-peer", "status reason")
    expect_equal(result.response_ip, "10.0.0.3", "status response IP")
    expect_equal(result.wrong_peer_datagrams, 1, "status wrong-peer datagrams")


@pytest.mark.parametrize(
    ("src_ip", "dst_ip", "sid", "addr", "expected"),
    [
        ("10.0.0.2", "10.0.0.1", 7, ("10.0.0.2", 7001), ("wrong-peer", 1, 0)),
        ("10.0.0.2", "10.0.0.1", 6, ("10.0.0.2", 7000), ("unexpected-response", 0, 1)),
        ("10.0.0.3", "10.0.0.1", 7, ("10.0.0.2", 7000), ("wrong-peer", 1, 0)),
        ("10.0.0.2", "10.0.0.3", 7, ("10.0.0.2", 7000), ("wrong-peer", 1, 0)),
    ],
    ids=["wrong-port", "stale-sid", "claimed-source", "wrong-destination"],
)
def test_status_probe_result_rejects_unbound_ascii_ack(
    monkeypatch: pytest.MonkeyPatch,
    src_ip: str,
    dst_ip: str,
    sid: int,
    addr: tuple[str, int],
    expected: tuple[str, int, int],
) -> None:
    datagram = build_control_datagram(MESG_CHECKLOLASTATUS_ACK, src_ip, dst_ip, sid)

    result, _sent_controls = run_status_probe(monkeypatch, [(datagram, addr)])

    reason, wrong_peer, unexpected = expected
    expect_equal(result.reason, reason, "status rejection reason")
    expect_equal(result.wrong_peer_datagrams, wrong_peer, "status wrong-peer datagrams")
    expect_equal(result.unexpected_datagrams, unexpected, "status unexpected datagrams")


def test_status_probe_result_accepts_osc15_ack_without_ascii_binding_fields(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    datagram = build_osc15_control_datagram(
        MESG_CHECKLOLASTATUS_ACK,
        "10.0.0.2",
        "10.0.0.1",
        7,
        source_name="legacy-source-name",
    )

    result, _sent_controls = run_status_probe(
        monkeypatch,
        [(datagram, ("10.0.0.2", 7000))],
        control_dialect="osc15",
    )

    expect_true(result.acknowledged, "OSC15 status acknowledgement")


def test_status_probe_result_reports_unexpected_response(monkeypatch: pytest.MonkeyPatch) -> None:
    datagram = build_control_datagram(MESG_CHAT, "10.0.0.2", "10.0.0.1", 7, txt="hello")

    result, _sent_controls = run_status_probe(monkeypatch, [(datagram, ("10.0.0.2", 7000))])

    expect_false(result.acknowledged, "status ack")
    expect_equal(result.reason, "unexpected-response", "status reason")
    expect_equal(result.response_kind, MESG_CHAT, "status response kind")
    expect_equal(result.unexpected_datagrams, 1, "status unexpected datagrams")


def test_status_probe_auto_dialect_sends_ascii_and_osc15(monkeypatch: pytest.MonkeyPatch) -> None:
    result, sent_controls = run_status_probe(monkeypatch, [], control_dialect="auto")

    expect_equal(result.sent_dialects, ("ascii", "osc15"), "status sent dialects")
    expect_equal(
        sent_controls,
        [
            (MESG_CHECKLOLASTATUS, "10.0.0.2", 7, "ascii"),
            (MESG_CHECKLOLASTATUS, "10.0.0.2", 7, "osc15"),
        ],
        "sent status controls",
    )


def test_status_probe_boolean_wrapper_preserves_compatibility(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    datagram = build_control_datagram(MESG_CHECKLOLASTATUS_ACK, "10.0.0.2", "10.0.0.1", 7)

    async def fake_recvfrom(_sock: object, _size: int) -> tuple[bytes, tuple[str, int]]:
        return datagram, ("10.0.0.2", 7000)

    monkeypatch.setattr(connector_module, "udp_recvfrom", fake_recvfrom)

    async def run() -> bool:
        connector = StatusProbeConnector("10.0.0.1")
        return await connector.check_status("10.0.0.2", sid=7, timeout=0.1)

    expect_true(asyncio.run(run()), "status boolean wrapper")


@pytest.mark.usefixtures("require_localhost_udp")
def test_udp_socket_helpers_serialize_same_direction_fallbacks() -> None:
    async def run() -> None:
        connector = LolaConnector("127.0.0.1", MediaSettings())
        receiver = connector.make_udp_socket(0)
        sender = connector.make_udp_socket(0)
        try:
            receiver_address = ("127.0.0.1", receiver.getsockname()[1])
            receive_tasks = [
                asyncio.create_task(asyncio.wait_for(connector_module.udp_recvfrom(receiver, 4096), timeout=1.0))
                for _ in range(2)
            ]
            await asyncio.gather(
                connector_module.udp_sendto(sender, b"one", receiver_address),
                connector_module.udp_sendto(sender, b"two", receiver_address),
            )
            packets = await asyncio.gather(*receive_tasks)
        finally:
            connector_module.close_udp_socket(sender)
            connector_module.close_udp_socket(receiver)

        expect_equal({packet[0] for packet in packets}, {b"one", b"two"}, "serialized UDP payloads")
        expect_true(
            all(packet[1][0] == "127.0.0.1" for packet in packets),
            "serialized UDP source address",
        )

    asyncio.run(run())


@pytest.mark.usefixtures("require_localhost_udp")
def test_udp_socket_lock_registries_shrink_after_close() -> None:
    connector = LolaConnector("127.0.0.1", MediaSettings())
    read_locks = getattr(connector_module, "_socket_read_locks")
    write_locks = getattr(connector_module, "_socket_write_locks")
    socket_lock = getattr(connector_module, "_socket_lock")
    read_locks.clear()
    write_locks.clear()

    for _ in range(8):
        sock = connector.make_udp_socket(0)
        fileno = sock.fileno()
        socket_lock(read_locks, sock)
        socket_lock(write_locks, sock)
        expect_true(fileno in read_locks, "socket read lock registry")
        expect_true(fileno in write_locks, "socket write lock registry")

        connector_module.close_udp_socket(sock)

        expect_false(fileno in read_locks, "socket read lock registry")
        expect_false(fileno in write_locks, "socket write lock registry")
