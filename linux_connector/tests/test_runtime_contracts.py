"""Tests for Linux connector runtime contracts."""

# pylint: disable=missing-function-docstring

from __future__ import annotations

import asyncio
import socket
from collections.abc import Callable
from typing import cast

import pytest
from pytest import LogCaptureFixture

import linux_connector.lola_connector.runtime as runtime_module
from linux_connector.lola_connector.backends import (
    MemoryAudioPlayback,
    SilenceAudioCapture,
)
from linux_connector.lola_connector.connector import Session, _ControlSendRequest
from linux_connector.lola_connector.connector_impl import LolaConnector
from linux_connector.lola_connector.media import expected_audio_payload_size
from linux_connector.lola_connector.protocol import (
    MESG_CHECKLOLASTATUS,
    MESG_CHECKLOLASTATUS_ACK,
    MESG_DISCONNECT,
    MESG_QUICKCONN,
    MESG_QUICKCONN_ACK,
    MESG_REJECT,
    MESG_SEND_AUDIO_SIGNAL,
    MESG_STOP_AUDIO_SIGNAL,
    ControlMessage,
    MediaSettings,
    build_osc15_control_datagram,
    parse_control_datagram,
)
from linux_connector.lola_connector.runtime import LolaLinuxRuntime
from linux_connector.tests.support import (
    expect_contains,
    expect_equal,
    expect_true,
    receive_payload,
    runtime_with_session,
)


class _IncomingControlRecorder(LolaConnector):
    def __init__(self) -> None:
        super().__init__("127.0.0.1", control_port=0)
        self.sent_controls: list[_ControlSendRequest] = []

    async def _send_control(self, _sock: socket.socket, request: _ControlSendRequest) -> None:
        self.sent_controls.append(request)


async def _receive_payload_on_socket(payload: bytes, sock: socket.socket) -> tuple[bytes, tuple[str, int]]:
    return await receive_payload(payload, ("127.0.0.2", sock.getsockname()[1]))


async def _run_media_receive(
    monkeypatch: pytest.MonkeyPatch,
    payload: bytes,
    parser: Callable[[bytes], object] | None = None,
) -> LolaLinuxRuntime:
    runtime = runtime_with_session()
    monkeypatch.setattr(
        runtime_module,
        "udp_recvfrom",
        lambda sock, _size: _receive_payload_on_socket(payload, sock),
    )
    if parser is not None:
        monkeypatch.setattr(runtime_module, "parse_media_payload", parser)
    await runtime.run_for(0.01, receive=True, transmit_audio=False, transmit_video=False, control=False)
    return runtime


@pytest.mark.usefixtures("require_localhost_udp")
def test_accept_once_honors_timeout_without_incoming_quickconn() -> None:

    async def run() -> None:
        connector = LolaConnector("127.0.0.1", control_port=0)
        with pytest.raises(TimeoutError, match="LoLa QuickConn did not arrive"):
            await connector.accept_once(timeout=0.01)

    asyncio.run(run())


@pytest.mark.usefixtures("require_localhost_udp")
def test_accept_once_signals_ready_after_binding() -> None:

    async def run() -> None:
        connector = LolaConnector("127.0.0.1", control_port=0)
        ready = asyncio.Event()
        accept_task = asyncio.create_task(connector.accept_once(timeout=0.01, ready_event=ready))
        await asyncio.wait_for(ready.wait(), timeout=0.5)
        with pytest.raises(TimeoutError, match="LoLa QuickConn did not arrive"):
            await accept_task

    asyncio.run(run())


@pytest.mark.parametrize("kind", [MESG_CHECKLOLASTATUS, MESG_QUICKCONN])
def test_incoming_control_discards_mismatched_srcip_without_reflection_or_session_mutation(kind: str) -> None:
    connector = _IncomingControlRecorder()
    existing_session = Session("127.0.0.1", "127.0.0.4", 3, MediaSettings())
    connector.session = existing_session
    message = ControlMessage(
        kind,
        {"SRCIP": "127.0.0.3", "SID": "7"},
        f"/{kind};SRCIP:127.0.0.3;SID:7",
    )

    result = asyncio.run(
        connector._handle_incoming_control(  # pylint: disable=protected-access
            cast(socket.socket, object()),
            message,
            ("127.0.0.2", 7000),
        )
    )

    expect_equal(result, None, "mismatched control result")
    expect_equal(connector.sent_controls, [], "mismatched control responses")
    expect_equal(connector.session, existing_session, "mismatched control session")


@pytest.mark.parametrize("sender_port", [17001, 17002], ids=["initial", "retry"])
def test_incoming_quickconn_replies_to_each_validated_observed_source_port(sender_port: int) -> None:
    connector = _IncomingControlRecorder()
    message = ControlMessage(
        MESG_QUICKCONN,
        {"SRCIP": "127.0.0.2", "SID": "7"},
        "/MESG_QUICKCONN;SRCIP:127.0.0.2;SID:7",
    )

    session = asyncio.run(
        connector._handle_incoming_control(  # pylint: disable=protected-access
            cast(socket.socket, object()),
            message,
            ("127.0.0.2", sender_port),
        )
    )

    expect_equal(session, Session("127.0.0.1", "127.0.0.2", 7, MediaSettings()), "matching QuickConn session")
    expect_equal(connector.session, session, "matching QuickConn stored session")
    expect_equal(len(connector.sent_controls), 1, "matching QuickConn response count")
    request = connector.sent_controls[0]
    expect_equal(request.kind, MESG_QUICKCONN_ACK, "matching QuickConn response kind")
    expect_equal(request.remote_ip, "127.0.0.2", "matching QuickConn response peer")
    expect_equal(request.remote_port, sender_port, "matching QuickConn response port")


def test_incoming_status_replies_to_validated_observed_source_port() -> None:
    connector = _IncomingControlRecorder()
    message = ControlMessage(
        MESG_CHECKLOLASTATUS,
        {"SRCIP": "127.0.0.2", "SID": "7"},
        "/MESG_CHECKLOLASTATUS;SRCIP:127.0.0.2;SID:7",
    )
    sender = ("127.0.0.2", 17000)

    result = asyncio.run(
        connector._handle_incoming_control(  # pylint: disable=protected-access
            cast(socket.socket, object()),
            message,
            sender,
        )
    )

    expect_equal(result, None, "status control result")
    expect_equal(len(connector.sent_controls), 1, "status response count")
    request = connector.sent_controls[0]
    expect_equal(request.kind, MESG_CHECKLOLASTATUS_ACK, "status response kind")
    expect_equal(request.remote_ip, sender[0], "status response peer")
    expect_equal(request.remote_port, sender[1], "status response port")


def test_incompatible_incoming_quickconn_rejects_to_validated_observed_source_port() -> None:
    connector = _IncomingControlRecorder()
    message = ControlMessage(
        MESG_QUICKCONN,
        {"SRCIP": "127.0.0.2", "SID": "7", "SR": "48000"},
        "/MESG_QUICKCONN;SRCIP:127.0.0.2;SID:7;SR:48000",
    )
    sender = ("127.0.0.2", 17003)

    result = asyncio.run(
        connector._handle_incoming_control(  # pylint: disable=protected-access
            cast(socket.socket, object()),
            message,
            sender,
        )
    )

    expect_equal(result, None, "incompatible QuickConn result")
    expect_equal(connector.session, None, "incompatible QuickConn session")
    expect_equal(len(connector.sent_controls), 1, "incompatible QuickConn response count")
    request = connector.sent_controls[0]
    expect_equal(request.kind, MESG_REJECT, "incompatible QuickConn response kind")
    expect_equal(request.remote_port, sender[1], "incompatible QuickConn response port")


@pytest.mark.parametrize("kind", [MESG_CHECKLOLASTATUS, MESG_QUICKCONN])
def test_active_runtime_does_not_reply_to_forged_claimed_source(
    monkeypatch: pytest.MonkeyPatch,
    kind: str,
) -> None:
    runtime = runtime_with_session()
    sent: list[tuple[bytes, tuple[str, int]]] = []

    async def record_response(response: bytes, remote_endpoint: tuple[str, int]) -> None:
        sent.append((response, remote_endpoint))

    monkeypatch.setattr(runtime._control_handler, "_send_response", record_response)  # pylint: disable=protected-access
    message = ControlMessage(kind, {"SRCIP": "127.0.0.3", "SID": "7"}, f"/{kind};SRCIP:127.0.0.3;SID:7")

    asyncio.run(runtime._control_handler._handle_message(message, ("127.0.0.2", 17000)))  # pylint: disable=protected-access

    expect_equal(sent, [], "forged claimed-source replies")


@pytest.mark.parametrize("kind", [MESG_CHECKLOLASTATUS, MESG_QUICKCONN])
def test_active_runtime_accepts_osc15_source_name_and_replies_to_observed_port(
    monkeypatch: pytest.MonkeyPatch,
    kind: str,
) -> None:
    runtime = runtime_with_session()
    sent: list[tuple[bytes, tuple[str, int]]] = []

    async def record_response(response: bytes, remote_endpoint: tuple[str, int]) -> None:
        sent.append((response, remote_endpoint))

    monkeypatch.setattr(runtime._control_handler, "_send_response", record_response)  # pylint: disable=protected-access
    message = parse_control_datagram(
        build_osc15_control_datagram(
            kind,
            "127.0.0.2",
            "127.0.0.1",
            source_name="legacy-source-name",
        )
    )
    assert message is not None
    sender = ("127.0.0.2", 17001)

    asyncio.run(runtime._control_handler._handle_message(message, sender))  # pylint: disable=protected-access

    expect_equal(len(sent), 1, "OSC15 response count")
    expect_equal(sent[0][1], sender, "OSC15 observed response endpoint")


@pytest.mark.parametrize("sid", [None, "not-an-integer"])
@pytest.mark.parametrize("kind", [MESG_SEND_AUDIO_SIGNAL, MESG_STOP_AUDIO_SIGNAL, MESG_DISCONNECT])
def test_active_sid_zero_rejects_missing_or_invalid_ascii_sid(kind: str, sid: str | None) -> None:
    connector = LolaConnector("127.0.0.1", MediaSettings())
    session = Session("127.0.0.1", "127.0.0.2", 0, MediaSettings())
    connector.session = session
    fields = {"SRCIP": "127.0.0.2"}
    if sid is not None:
        fields["SID"] = sid
    message = ControlMessage(kind, fields, f"/{kind}")

    action = connector.handle_control_message(message, sender_ip="127.0.0.2")

    expect_equal(action, "ignore", "malformed SID action")
    expect_equal(connector.session, session, "malformed SID session")


def test_active_sid_zero_accepts_leading_zero_ascii_sid() -> None:
    connector = LolaConnector("127.0.0.1", MediaSettings())
    connector.session = Session("127.0.0.1", "127.0.0.2", 0, MediaSettings())
    message = ControlMessage(
        MESG_DISCONNECT,
        {"SRCIP": "127.0.0.2", "SID": "000"},
        "/MESG_DISCONNECT;SRCIP:127.0.0.2;SID:000",
    )

    action = connector.handle_control_message(message, sender_ip="127.0.0.2")

    expect_equal(action, "disconnect", "leading-zero SID action")
    expect_equal(connector.session, None, "leading-zero SID session")


def test_ascii_control_parser_rejects_invalid_sid_and_normalizes_leading_zeroes() -> None:
    invalid = parse_control_datagram(b"/MESG_DISCONNECT;SRCIP:127.0.0.2;DSTIP:127.0.0.1;SID:not-an-integer")
    missing = parse_control_datagram(b"/MESG_DISCONNECT;SRCIP:127.0.0.2;DSTIP:127.0.0.1")
    leading_zeroes = parse_control_datagram(b"/MESG_DISCONNECT;SRCIP:127.0.0.2;DSTIP:127.0.0.1;SID:000")

    expect_equal(invalid, None, "invalid ASCII SID")
    expect_equal(missing, None, "missing ASCII SID")
    assert leading_zeroes is not None
    expect_equal(leading_zeroes.bound_sid, 0, "leading-zero parsed SID")
    expect_equal(leading_zeroes.fields["SID"], "0", "leading-zero canonical SID")


@pytest.mark.usefixtures("require_localhost_udp")
def test_runtime_without_video_capture_does_not_emit_video_tx() -> None:

    settings = MediaSettings(width=16, height=8)
    connector = LolaConnector("127.0.0.1", settings)
    connector.session = Session("127.0.0.1", "127.0.0.2", 1, settings)
    runtime = LolaLinuxRuntime(
        connector,
        SilenceAudioCapture(settings),
        MemoryAudioPlayback(),
        video_capture=None,
        video_display=None,
    )

    stats = asyncio.run(runtime.run_for(0.02, receive=False, transmit_audio=False, transmit_video=True, control=False))

    expect_equal(stats.video_tx, 0)


@pytest.mark.usefixtures("require_localhost_udp")
def test_audio_only_runtime_start_does_not_bind_video_port() -> None:

    reserved_video_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    reserved_video_socket.bind(("127.0.0.1", 0))
    occupied_video_port = reserved_video_socket.getsockname()[1]
    try:
        settings = MediaSettings(width=16, height=8)
        connector = LolaConnector("127.0.0.1", settings, audio_port=0, video_port=occupied_video_port)
        connector.session = Session("127.0.0.1", "127.0.0.2", 1, settings)
        runtime = LolaLinuxRuntime(
            connector,
            SilenceAudioCapture(settings),
            MemoryAudioPlayback(),
            video_capture=None,
            video_display=None,
        )

        stats = asyncio.run(
            runtime.run_for(
                0.01,
                receive=False,
                transmit_audio=False,
                transmit_video=False,
                control=False,
            )
        )

        expect_equal(stats.video_tx, 0)
        expect_equal(stats.video_rx, 0)
    finally:
        reserved_video_socket.close()


def test_runtime_stop_logs_failed_worker_before_cleanup(caplog: LogCaptureFixture) -> None:

    class FailingAudioCapture:  # pylint: disable=missing-class-docstring
        frames_per_callback = 0

        def __init__(self) -> None:
            self.closed = False

        async def read_block(self) -> bytes:
            raise RuntimeError("audio capture failed")

        async def aclose(self) -> None:
            self.closed = True

    class FakeConnector(LolaConnector):  # pylint: disable=missing-class-docstring
        def __init__(self) -> None:
            settings = MediaSettings(width=16, height=8)
            super().__init__("127.0.0.1", settings)
            self.session = Session("127.0.0.1", "127.0.0.2", 1, settings)

        def make_udp_socket(self, bind_port: int = 0) -> socket.socket:
            _ = bind_port
            return socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    async def run() -> None:
        capture = FailingAudioCapture()
        runtime = LolaLinuxRuntime(FakeConnector(), capture, MemoryAudioPlayback())
        await runtime.start(receive=False, transmit_audio=True, transmit_video=False, control=False)
        await asyncio.sleep(0)
        with pytest.raises(ExceptionGroup, match="runtime task failed during stop"):
            await runtime.stop()

        expect_true(capture.closed, "audio capture should close after failed stop")

    caplog.set_level("ERROR", logger="linux_connector.lola_connector.runtime")
    asyncio.run(run())
    expect_contains("runtime task failed during stop", caplog.text)


@pytest.mark.usefixtures("require_localhost_udp")
def test_runtime_start_rejects_stale_task_handles() -> None:

    async def run() -> None:
        runtime = runtime_with_session()
        await runtime.start(receive=False, transmit_audio=False, transmit_video=False, control=False)
        try:
            with pytest.raises(RuntimeError, match="runtime is already started"):
                await runtime.start(
                    receive=False,
                    transmit_audio=False,
                    transmit_video=False,
                    control=False,
                )
        finally:
            await runtime.stop()

    asyncio.run(run())


def test_runtime_control_loop_requires_initialized_socket() -> None:

    async def run() -> None:
        runtime = runtime_with_session()
        with pytest.raises(RuntimeError, match="control socket is not initialized"):
            await runtime._control_handler.run()  # pylint: disable=protected-access

    asyncio.run(run())


def test_runtime_audio_tx_checks_socket_before_consuming_capture() -> None:

    class CountingAudioCapture:  # pylint: disable=missing-class-docstring,too-few-public-methods
        frames_per_callback = 64
        external_pacing = False

        def __init__(self) -> None:
            self.reads = 0

        async def read_block(self) -> bytes:
            self.reads += 1
            return b"\0" * expected_audio_payload_size(channels=2)

    async def run() -> None:
        settings = MediaSettings(width=16, height=8)
        connector = LolaConnector("127.0.0.1", settings)
        connector.session = Session("127.0.0.1", "127.0.0.2", 1, settings)
        capture = CountingAudioCapture()
        runtime = LolaLinuxRuntime(connector, capture, MemoryAudioPlayback())
        audio_tx_enabled = runtime._audio_tx_enabled
        audio_tx_loop = runtime._audio_tx_loop
        audio_tx_enabled.set()

        with pytest.raises(RuntimeError, match="audio socket is not initialized"):
            await audio_tx_loop()

        expect_equal(capture.reads, 0)

    asyncio.run(run())
