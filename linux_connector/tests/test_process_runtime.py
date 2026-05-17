from __future__ import annotations

import argparse
import asyncio
from contextlib import contextmanager
import socket
from collections.abc import Iterator

import pytest

import linux_connector.lola_connector.connector as connector_module
from linux_connector.env.npcap_udp_relay import send_payload_nonblocking
from linux_connector.lola_connector.backends import (
    MemoryAudioPlayback,
    ProcessJpegVideoCapture,
    SilenceAudioCapture,
)
from linux_connector.lola_connector.cli import build_parser, build_video_capture, run as run_cli, validate_cli_args
from linux_connector.lola_connector.connector import LolaConnector, QuickConnResult, Session, StatusCheckResult
from linux_connector.lola_connector.protocol import (
    CONTROL_DATAGRAM_SIZE,
    MESG_CHAT,
    MESG_CHECKLOLASTATUS,
    MESG_CHECKLOLASTATUS_ACK,
    MESG_QUICKCONN,
    MESG_QUICKCONN_ACK,
    MediaSettings,
    build_control_datagram,
)
from linux_connector.lola_connector.runtime import LolaLinuxRuntime
from linux_connector.lola_connector.selftest import (
    loopback_alias_capability,
    run_bidirectional_selftest,
    run_control_handshake_selftest,
)


def require_loopback_alias(ip: str = "127.0.0.2") -> None:
    available, message = loopback_alias_capability(ip)
    if not available:
        pytest.skip(message)


def test_connector_audio_signal_request_is_event_owned() -> None:
    connector = LolaConnector("127.0.0.1", MediaSettings(width=16, height=8))

    assert not hasattr(connector, "audio_signal_requested")


def test_cli_exposes_remote_signal_flags_without_getattr_fallbacks() -> None:
    parser = build_parser()
    listen_args = parser.parse_args(["--local-ip", "127.0.0.1", "listen"])
    connect_args = parser.parse_args(["--local-ip", "127.0.0.1", "connect", "127.0.0.2"])
    source_name_args = parser.parse_args(["--local-ip", "127.0.0.1", "--source-name", "lab-peer", "status", "127.0.0.2"])

    assert listen_args.wait_for_remote_test_signal is False
    assert listen_args.request_remote_audio_signal is False
    assert connect_args.wait_for_remote_test_signal is False
    assert connect_args.request_remote_audio_signal is False
    assert source_name_args.source_name == "lab-peer"


def test_udp_selftest_loopback_alias_capability_reports_missing_alias(monkeypatch: pytest.MonkeyPatch) -> None:
    class MissingAliasSocket:
        def bind(self, address: tuple[str, int]) -> None:
            raise OSError("alias unavailable")

        def close(self) -> None:
            return None

    monkeypatch.setattr(socket, "socket", lambda *_args, **_kwargs: MissingAliasSocket())

    available, message = loopback_alias_capability("127.0.0.2")

    assert not available
    assert message == "loopback alias 127.0.0.2 is not available: alias unavailable"


def test_udp_selftest_loopback_alias_capability_reports_available_alias() -> None:
    available, message = loopback_alias_capability("127.0.0.1")

    assert available
    assert message == "loopback alias 127.0.0.1 is available"


def test_udp_selftest_loopback_alias_capability_reports_current_environment() -> None:
    available, message = loopback_alias_capability("127.0.0.2")

    if available:
        assert message == "loopback alias 127.0.0.2 is available"
    else:
        assert message.startswith("loopback alias 127.0.0.2 is not available:")


def test_udp_selftest_loopback_alias_requirement_skips_missing_alias(monkeypatch: pytest.MonkeyPatch) -> None:
    class MissingAliasSocket:
        def bind(self, address: tuple[str, int]) -> None:
            raise OSError("alias unavailable")

        def close(self) -> None:
            return None

    monkeypatch.setattr(socket, "socket", lambda *_args, **_kwargs: MissingAliasSocket())

    with pytest.raises(pytest.skip.Exception, match="loopback alias 127.0.0.2 is not available"):
        require_loopback_alias()


def test_cli_default_media_and_timing_values_pass_bounds_validation() -> None:
    parser = build_parser()
    args = parser.parse_args(["--local-ip", "127.0.0.1", "connect", "127.0.0.2", "--duration", "0.25"])

    validate_cli_args(args)


class StatusProbeConnector(LolaConnector):
    def __init__(self, *args: object, **kwargs: object) -> None:
        super().__init__(*args, **kwargs)
        self.sent_controls: list[tuple[str, str, int, str | None]] = []

    @contextmanager
    def udp_socket(self, bind_port: int = 0) -> Iterator[object]:
        yield object()

    async def _send_control(
        self,
        sock: socket.socket,
        kind: str,
        remote_ip: str,
        sid: int,
        txt: str = "",
        dialect: str | None = None,
        settings: MediaSettings | None = None,
    ) -> None:
        self.sent_controls.append((kind, remote_ip, sid, dialect))


def run_status_probe(
    monkeypatch: pytest.MonkeyPatch,
    datagrams: list[tuple[bytes, tuple[str, int]]],
    *,
    control_dialect: str = "ascii",
) -> tuple[StatusCheckResult, list[tuple[str, str, int, str | None]]]:
    async def fake_recvfrom(_sock: object, _size: int) -> tuple[bytes, tuple[str, int]]:
        if datagrams:
            return datagrams.pop(0)
        raise asyncio.TimeoutError

    monkeypatch.setattr(connector_module, "udp_recvfrom", fake_recvfrom)

    async def run() -> tuple[StatusCheckResult, list[tuple[str, str, int, str | None]]]:
        connector = StatusProbeConnector("10.0.0.1", control_dialect=control_dialect)
        result = await connector.check_status_result("10.0.0.2", sid=7, timeout=0.1)
        return result, connector.sent_controls

    return asyncio.run(run())


def run_quickconn_probe(
    monkeypatch: pytest.MonkeyPatch,
    datagrams: list[tuple[bytes, tuple[str, int]]],
) -> tuple[QuickConnResult, list[tuple[str, str, int, str | None]]]:
    async def fake_recvfrom(_sock: object, _size: int) -> tuple[bytes, tuple[str, int]]:
        if datagrams:
            return datagrams.pop(0)
        raise asyncio.TimeoutError

    monkeypatch.setattr(connector_module, "udp_recvfrom", fake_recvfrom)

    async def run() -> tuple[QuickConnResult, list[tuple[str, str, int, str | None]]]:
        connector = StatusProbeConnector("10.0.0.1")
        result = await connector.initiate_result("10.0.0.2", sid=7, timeout=0.1)
        return result, connector.sent_controls

    return asyncio.run(run())


def test_status_probe_result_reports_ack(monkeypatch: pytest.MonkeyPatch) -> None:
    datagram = build_control_datagram(MESG_CHECKLOLASTATUS_ACK, "10.0.0.2", "10.0.0.1", 7)

    result, sent_controls = run_status_probe(monkeypatch, [(datagram, ("10.0.0.2", 7000))])

    assert result.acknowledged
    assert result.reason == "ack"
    assert result.response_ip == "10.0.0.2"
    assert result.response_kind == MESG_CHECKLOLASTATUS_ACK
    assert result.sent_dialects == ("ascii",)
    assert sent_controls == [(MESG_CHECKLOLASTATUS, "10.0.0.2", 7, None)]


def test_quickconn_result_reports_malformed_ack(monkeypatch: pytest.MonkeyPatch) -> None:
    malformed_ack = (
        b"/MESG_QUICKCONN_ACK;SRCIP:10.0.0.2;DSTIP:10.0.0.1;SID:7;SR:garbage"
        .ljust(CONTROL_DATAGRAM_SIZE, b"\0")
    )

    result, sent_controls = run_quickconn_probe(monkeypatch, [(malformed_ack, ("10.0.0.2", 7000))])

    assert not result
    assert result.session is None
    assert result.reason == "malformed-response"
    assert result.malformed_datagrams == 1
    assert result.wrong_peer_datagrams == 0
    assert result.unexpected_datagrams == 0
    assert sent_controls == [(MESG_QUICKCONN, "10.0.0.2", 7, None)]


def test_quickconn_result_reports_wrong_peer_control_datagram(monkeypatch: pytest.MonkeyPatch) -> None:
    datagram = build_control_datagram(MESG_QUICKCONN_ACK, "10.0.0.3", "10.0.0.1", 7)

    result, _sent_controls = run_quickconn_probe(monkeypatch, [(datagram, ("10.0.0.3", 7000))])

    assert not result
    assert result.reason == "wrong-peer"
    assert result.malformed_datagrams == 0
    assert result.wrong_peer_datagrams == 1
    assert result.unexpected_datagrams == 0


def test_quickconn_result_reports_timeout_without_ack(monkeypatch: pytest.MonkeyPatch) -> None:
    result, _sent_controls = run_quickconn_probe(monkeypatch, [])

    assert not result
    assert result.reason == "timeout"
    assert result.malformed_datagrams == 0
    assert result.wrong_peer_datagrams == 0
    assert result.unexpected_datagrams == 0


def test_status_probe_result_reports_timeout(monkeypatch: pytest.MonkeyPatch) -> None:
    result, _sent_controls = run_status_probe(monkeypatch, [])

    assert not result.acknowledged
    assert result.reason == "timeout"
    assert result.malformed_datagrams == 0
    assert result.wrong_peer_datagrams == 0
    assert result.unexpected_datagrams == 0


def test_status_probe_result_reports_malformed_response(monkeypatch: pytest.MonkeyPatch) -> None:
    result, _sent_controls = run_status_probe(monkeypatch, [(b"not lola", ("10.0.0.2", 7000))])

    assert not result.acknowledged
    assert result.reason == "malformed-response"
    assert result.malformed_datagrams == 1


def test_status_probe_result_reports_wrong_peer(monkeypatch: pytest.MonkeyPatch) -> None:
    datagram = build_control_datagram(MESG_CHECKLOLASTATUS_ACK, "10.0.0.3", "10.0.0.1", 7)

    result, _sent_controls = run_status_probe(monkeypatch, [(datagram, ("10.0.0.3", 7000))])

    assert not result.acknowledged
    assert result.reason == "wrong-peer"
    assert result.response_ip == "10.0.0.3"
    assert result.wrong_peer_datagrams == 1


def test_status_probe_result_reports_unexpected_response(monkeypatch: pytest.MonkeyPatch) -> None:
    datagram = build_control_datagram(MESG_CHAT, "10.0.0.2", "10.0.0.1", 7, txt="hello")

    result, _sent_controls = run_status_probe(monkeypatch, [(datagram, ("10.0.0.2", 7000))])

    assert not result.acknowledged
    assert result.reason == "unexpected-response"
    assert result.response_kind == MESG_CHAT
    assert result.unexpected_datagrams == 1


def test_status_probe_auto_dialect_sends_ascii_and_osc15(monkeypatch: pytest.MonkeyPatch) -> None:
    result, sent_controls = run_status_probe(monkeypatch, [], control_dialect="auto")

    assert result.sent_dialects == ("ascii", "osc15")
    assert sent_controls == [
        (MESG_CHECKLOLASTATUS, "10.0.0.2", 7, "ascii"),
        (MESG_CHECKLOLASTATUS, "10.0.0.2", 7, "osc15"),
    ]


def test_status_probe_boolean_wrapper_preserves_compatibility(monkeypatch: pytest.MonkeyPatch) -> None:
    datagram = build_control_datagram(MESG_CHECKLOLASTATUS_ACK, "10.0.0.2", "10.0.0.1", 7)

    async def fake_recvfrom(_sock: object, _size: int) -> tuple[bytes, tuple[str, int]]:
        return datagram, ("10.0.0.2", 7000)

    monkeypatch.setattr(connector_module, "udp_recvfrom", fake_recvfrom)

    async def run() -> bool:
        connector = StatusProbeConnector("10.0.0.1")
        return await connector.check_status("10.0.0.2", sid=7, timeout=0.1)

    assert asyncio.run(run())


def test_cli_status_prints_structured_reason(monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
    async def fake_check_status_result(
        self: LolaConnector,
        remote_ip: str,
        sid: int = 0,
        timeout: float = 2.0,
    ) -> StatusCheckResult:
        return StatusCheckResult(
            acknowledged=False,
            reason="wrong-peer",
            wrong_peer_datagrams=1,
            sent_dialects=("ascii",),
        )

    monkeypatch.setattr(LolaConnector, "check_status_result", fake_check_status_result)
    parser = build_parser()
    args = parser.parse_args(["--local-ip", "127.0.0.1", "status", "127.0.0.2"])

    asyncio.run(run_cli(args))

    output = capsys.readouterr().out
    assert "status_ack=0" in output
    assert "status_reason=wrong-peer" in output
    assert "status_wrong_peer=1" in output


@pytest.mark.parametrize(
    ("arguments", "message"),
    [
        (["--sr", "0"], "sample_rate"),
        (["--channels", "9"], "audio callback block"),
        (["--width", "8192", "--height", "8192"], "raw video frame"),
        (["--fps", "0"], "fps"),
        (["--audio-interval-scale", "nan"], "audio_interval_scale"),
        (["--audio-frames-per-callback", "4096"], "audio callback block"),
        (["--max-frame-bytes", "0"], "max_frame_bytes"),
        (["--packet-size", "999999"], "packet_size"),
    ],
)
def test_cli_rejects_unbounded_media_values(arguments: list[str], message: str) -> None:
    parser = build_parser()
    args = parser.parse_args(["--local-ip", "127.0.0.1", *arguments, "connect", "127.0.0.2"])

    with pytest.raises(ValueError, match=message):
        validate_cli_args(args)


@pytest.mark.parametrize(
    ("arguments", "message"),
    [
        (["selftest", "--duration", "0"], "duration"),
        (["status", "127.0.0.2", "--timeout", "inf"], "timeout"),
        (["connect", "127.0.0.2", "--duration", "-1"], "duration"),
        (["connect", "127.0.0.2", "--tone-frequency", "nan"], "tone_frequency"),
        (["connect", "127.0.0.2", "--tone-amplitude", "2"], "tone_amplitude"),
    ],
)
def test_cli_rejects_unbounded_timing_values(arguments: list[str], message: str) -> None:
    parser = build_parser()
    args = parser.parse_args(["--local-ip", "127.0.0.1", *arguments])

    with pytest.raises(ValueError, match=message):
        validate_cli_args(args)


def test_cli_selftest_dispatch_requires_argparse_defaults() -> None:

    async def run_missing_duration() -> None:
        with pytest.raises(RuntimeError, match="duration"):
            await run_cli(argparse.Namespace(mode="selftest", port_offset=None))

    async def run_missing_port_offset() -> None:
        with pytest.raises(RuntimeError, match="port_offset"):
            await run_cli(argparse.Namespace(mode="selftest", duration=0.01))

    asyncio.run(run_missing_duration())
    asyncio.run(run_missing_port_offset())


def test_cli_passes_configured_jpeg_frame_byte_cap_to_capture_backend() -> None:
    parser = build_parser()
    args = parser.parse_args(
        [
            "--local-ip",
            "127.0.0.1",
            "--compression",
            "1",
            "--video-capture-cmd",
            "dummy",
            "--max-frame-bytes",
            "4096",
            "connect",
            "127.0.0.2",
        ]
    )

    capture = build_video_capture(args, MediaSettings(width=16, height=8, compression=1))

    assert isinstance(capture, ProcessJpegVideoCapture)
    assert capture.max_frame_bytes == 4096


def test_udp_socket_helpers_serialize_same_direction_fallbacks() -> None:
    async def run() -> None:
        connector = LolaConnector("127.0.0.1", MediaSettings())
        receiver = connector.make_udp_socket(0)
        sender = connector.make_udp_socket(0)
        try:
            receiver_address = ("127.0.0.1", receiver.getsockname()[1])
            receive_tasks = [
                asyncio.create_task(asyncio.wait_for(connector_module.udp_recvfrom(receiver, 4096), timeout=1.0)),
                asyncio.create_task(asyncio.wait_for(connector_module.udp_recvfrom(receiver, 4096), timeout=1.0)),
            ]
            await asyncio.gather(
                connector_module.udp_sendto(sender, b"one", receiver_address),
                connector_module.udp_sendto(sender, b"two", receiver_address),
            )
            packets = await asyncio.gather(*receive_tasks)
        finally:
            connector_module.close_udp_socket(sender)
            connector_module.close_udp_socket(receiver)

        assert {packet[0] for packet in packets} == {b"one", b"two"}
        assert all(packet[1][0] == "127.0.0.1" for packet in packets)

    asyncio.run(run())


def test_udp_socket_lock_registries_shrink_after_close() -> None:
    connector = LolaConnector("127.0.0.1", MediaSettings())
    connector_module._socket_read_locks.clear()
    connector_module._socket_write_locks.clear()

    for _ in range(8):
        sock = connector.make_udp_socket(0)
        fileno = sock.fileno()
        connector_module._socket_lock(connector_module._socket_read_locks, sock)
        connector_module._socket_lock(connector_module._socket_write_locks, sock)
        assert fileno in connector_module._socket_read_locks
        assert fileno in connector_module._socket_write_locks

        connector_module.close_udp_socket(sock)

        assert fileno not in connector_module._socket_read_locks
        assert fileno not in connector_module._socket_write_locks


def test_runtime_start_failure_closes_partial_socket_and_backend_setup() -> None:

    class FakeSocket:
        def __init__(self) -> None:
            self.closed = False

        def close(self) -> None:
            self.closed = True

    class ClosableAudioCapture(SilenceAudioCapture):
        def __init__(self, settings: MediaSettings) -> None:
            super().__init__(settings)
            self.closed = False

        async def aclose(self) -> None:
            self.closed = True

    class ClosablePlayback(MemoryAudioPlayback):
        def __init__(self) -> None:
            super().__init__()
            self.closed = False

        async def aclose(self) -> None:
            self.closed = True

    class ClosableVideoCapture:
        def __init__(self) -> None:
            self.closed = False

        async def read_frame(self) -> bytes:
            return b"frame"

        async def aclose(self) -> None:
            self.closed = True

    class ClosableVideoDisplay:
        def __init__(self) -> None:
            self.closed = False

        async def show_frame(self, frame: bytes, sequence: int, compressed: bool) -> None:
            _ = frame
            _ = sequence
            _ = compressed

        async def aclose(self) -> None:
            self.closed = True

    async def run_case(fail_on_call: int) -> None:
        settings = MediaSettings()
        connector = LolaConnector("127.0.0.1", settings)
        connector.session = Session("127.0.0.1", "127.0.0.2", 1, settings)
        sockets: list[FakeSocket] = []

        def make_udp_socket(bind_port: int = 0) -> FakeSocket:
            _ = bind_port
            if len(sockets) + 1 == fail_on_call:
                raise OSError("socket setup failed")
            sock = FakeSocket()
            sockets.append(sock)
            return sock

        connector.make_udp_socket = make_udp_socket  # type: ignore[method-assign]
        audio_capture = ClosableAudioCapture(settings)
        audio_playback = ClosablePlayback()
        video_capture = ClosableVideoCapture()
        video_display = ClosableVideoDisplay()
        runtime = LolaLinuxRuntime(connector, audio_capture, audio_playback, video_capture, video_display)

        with pytest.raises(OSError, match="socket setup failed"):
            await runtime.start()

        assert sockets
        assert all(sock.closed for sock in sockets)
        assert audio_capture.closed
        assert audio_playback.closed
        assert video_capture.closed
        assert video_display.closed

    asyncio.run(run_case(fail_on_call=2))
    asyncio.run(run_case(fail_on_call=3))


def test_bidirectional_udp_runtime_selftest() -> None:

    require_loopback_alias()
    stats_a, stats_b = asyncio.run(run_bidirectional_selftest(seconds=0.12, port_offset=21000))
    assert stats_a.audio_rx > 0
    assert stats_b.audio_rx > 0
    assert stats_a.video_rx > 0
    assert stats_b.video_rx > 0


def test_control_handshake_udp_selftest() -> None:

    require_loopback_alias()
    session_a, session_b = asyncio.run(run_control_handshake_selftest(port_offset=23000))
    assert session_a.remote_ip == "127.0.0.2"
    assert session_b.remote_ip == "127.0.0.1"


def test_npcap_relay_drops_would_block_send() -> None:
    class BlockingSocket:
        def sendto(self, payload: bytes, address: tuple[str, int]) -> int:
            _ = payload
            _ = address
            raise BlockingIOError("send buffer full")

    assert send_payload_nonblocking(BlockingSocket(), b"payload", ("127.0.0.1", 19788)) is False
