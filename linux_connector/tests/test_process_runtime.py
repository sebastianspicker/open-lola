from __future__ import annotations

import argparse
import asyncio
from contextlib import contextmanager
import socket
from collections.abc import Iterator
from typing import cast

import pytest

import linux_connector.lola_connector.connector as connector_module
from linux_connector.lola_connector.backends import (
    MemoryAudioPlayback,
    ProcessJpegVideoCapture,
    SilenceAudioCapture,
)
from linux_connector.lola_connector.cli import build_parser, build_video_capture, run as run_cli, validate_cli_args
from linux_connector.lola_connector.connector import (
    LolaConnector,
    LolaConnectorOptions,
    QuickConnResult,
    Session,
    StatusCheckResult,
)
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


def expect_true(condition: object, label: str) -> None:
    if not condition:
        pytest.fail(f"{label}: expected truthy value")


def expect_false(condition: object, label: str) -> None:
    if condition:
        pytest.fail(f"{label}: expected falsey value")


def expect_equal(actual: object, expected: object, label: str) -> None:
    if actual != expected:
        pytest.fail(f"{label}: expected {expected!r}, got {actual!r}")


def expect_is_none(actual: object, label: str) -> None:
    if actual is not None:
        pytest.fail(f"{label}: expected None, got {actual!r}")


def expect_instance(actual: object, expected_type: type[object], label: str) -> None:
    if not isinstance(actual, expected_type):
        pytest.fail(f"{label}: expected {expected_type.__name__}, got {type(actual).__name__}")


def expect_contains(needle: str, haystack: str, label: str) -> None:
    if needle not in haystack:
        pytest.fail(f"{label}: expected {needle!r} in {haystack!r}")


def expect_not_contains(needle: str, haystack: str, label: str) -> None:
    if needle in haystack:
        pytest.fail(f"{label}: expected {needle!r} to be absent from {haystack!r}")


def expect_startswith(actual: str, prefix: str, label: str) -> None:
    if not actual.startswith(prefix):
        pytest.fail(f"{label}: expected {actual!r} to start with {prefix!r}")


def expect_greater_than(actual: int, threshold: int, label: str) -> None:
    if actual <= threshold:
        pytest.fail(f"{label}: expected value greater than {threshold}, got {actual}")


def require_loopback_alias(ip: str = "127.0.0.2") -> None:
    available, message = loopback_alias_capability(ip)
    if not available:
        pytest.skip(message)


def test_connector_audio_signal_request_is_event_owned() -> None:
    connector = LolaConnector("127.0.0.1", MediaSettings(width=16, height=8))

    expect_false(hasattr(connector, "audio_signal_requested"), "legacy audio signal attribute")


def test_connector_options_keyword_preserves_typed_configuration() -> None:
    connector = LolaConnector(
        "127.0.0.1",
        MediaSettings(width=16, height=8),
        options=LolaConnectorOptions(control_port=0, audio_port=1, video_port=2, source_name="lab"),
    )

    expect_equal(connector.control_port, 0, "connector options control port")
    expect_equal(connector.audio_port, 1, "connector options audio port")
    expect_equal(connector.video_port, 2, "connector options video port")
    expect_equal(connector.source_name, "lab", "connector options source name")


def test_cli_exposes_remote_signal_flags_without_getattr_fallbacks() -> None:
    parser = build_parser()
    listen_args = parser.parse_args(["--local-ip", "127.0.0.1", "listen"])
    connect_args = parser.parse_args(["--local-ip", "127.0.0.1", "connect", "127.0.0.2"])
    source_name_args = parser.parse_args(["--local-ip", "127.0.0.1", "--source-name", "lab-peer", "status", "127.0.0.2"])

    expect_false(listen_args.wait_for_remote_test_signal, "listen wait remote signal default")
    expect_false(listen_args.request_remote_audio_signal, "listen request remote signal default")
    expect_false(connect_args.wait_for_remote_test_signal, "connect wait remote signal default")
    expect_false(connect_args.request_remote_audio_signal, "connect request remote signal default")
    expect_equal(source_name_args.source_name, "lab-peer", "source name argument")


def test_cli_help_presents_connector_as_compatibility_seed() -> None:
    help_text = build_parser().format_help()

    expect_contains("LoLa 2.0 Linux compatibility seed", help_text, "CLI help")
    expect_not_contains("Prototype LoLa 2.0 Linux connector", help_text, "CLI help")


def test_udp_selftest_loopback_alias_capability_reports_missing_alias(monkeypatch: pytest.MonkeyPatch) -> None:
    class MissingAliasSocket:
        def bind(self, address: tuple[str, int]) -> None:
            raise OSError("alias unavailable")

        def close(self) -> None:
            return None

    monkeypatch.setattr(socket, "socket", lambda *_args, **_kwargs: MissingAliasSocket())

    available, message = loopback_alias_capability("127.0.0.2")

    expect_false(available, "loopback alias availability")
    expect_equal(message, "loopback alias 127.0.0.2 is not available: alias unavailable", "loopback alias message")


def test_udp_selftest_loopback_alias_capability_reports_available_alias() -> None:
    available, message = loopback_alias_capability("127.0.0.1")

    expect_true(available, "loopback alias availability")
    expect_equal(message, "loopback alias 127.0.0.1 is available", "loopback alias message")


def test_udp_selftest_loopback_alias_capability_reports_current_environment() -> None:
    available, message = loopback_alias_capability("127.0.0.2")

    if available:
        expect_equal(message, "loopback alias 127.0.0.2 is available", "loopback alias message")
    else:
        expect_startswith(message, "loopback alias 127.0.0.2 is not available:", "loopback alias message")


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
    def __init__(
        self,
        local_ip: str,
        settings: MediaSettings | None = None,
        control_dialect: str = "ascii",
    ) -> None:
        super().__init__(
            local_ip,
            settings,
            19798,
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

    expect_true(result.acknowledged, "status ack")
    expect_equal(result.reason, "ack", "status reason")
    expect_equal(result.response_ip, "10.0.0.2", "status response IP")
    expect_equal(result.response_kind, MESG_CHECKLOLASTATUS_ACK, "status response kind")
    expect_equal(result.sent_dialects, ("ascii",), "status sent dialects")
    expect_equal(sent_controls, [(MESG_CHECKLOLASTATUS, "10.0.0.2", 7, None)], "sent status controls")


def test_quickconn_result_reports_malformed_ack(monkeypatch: pytest.MonkeyPatch) -> None:
    malformed_ack = (
        b"/MESG_QUICKCONN_ACK;SRCIP:10.0.0.2;DSTIP:10.0.0.1;SID:7;SR:garbage"
        .ljust(CONTROL_DATAGRAM_SIZE, b"\0")
    )

    result, sent_controls = run_quickconn_probe(monkeypatch, [(malformed_ack, ("10.0.0.2", 7000))])

    expect_false(result, "quickconn result")
    expect_is_none(result.session, "quickconn session")
    expect_equal(result.reason, "malformed-response", "quickconn reason")
    expect_equal(result.malformed_datagrams, 1, "quickconn malformed datagrams")
    expect_equal(result.wrong_peer_datagrams, 0, "quickconn wrong-peer datagrams")
    expect_equal(result.unexpected_datagrams, 0, "quickconn unexpected datagrams")
    expect_equal(sent_controls, [(MESG_QUICKCONN, "10.0.0.2", 7, None)], "sent quickconn controls")


def test_quickconn_result_reports_incomplete_ack_as_malformed(monkeypatch: pytest.MonkeyPatch) -> None:
    incomplete_ack = (
        b"/MESG_QUICKCONN_ACK;SRCIP:10.0.0.2;DSTIP:10.0.0.1;SID:7;"
        b"SR:44100;BPS:16;CHNLS:2;FPS:25;BPP:8;X:640;Y:480;COMP:0"
    ).ljust(CONTROL_DATAGRAM_SIZE, b"\0")

    result, sent_controls = run_quickconn_probe(monkeypatch, [(incomplete_ack, ("10.0.0.2", 7000))])

    expect_false(result, "quickconn result")
    expect_is_none(result.session, "quickconn session")
    expect_equal(result.reason, "malformed-response", "quickconn reason")
    expect_equal(result.malformed_datagrams, 1, "quickconn malformed datagrams")
    expect_equal(result.wrong_peer_datagrams, 0, "quickconn wrong-peer datagrams")
    expect_equal(result.unexpected_datagrams, 0, "quickconn unexpected datagrams")
    expect_equal(sent_controls, [(MESG_QUICKCONN, "10.0.0.2", 7, None)], "sent quickconn controls")


def test_quickconn_result_reports_wrong_peer_control_datagram(monkeypatch: pytest.MonkeyPatch) -> None:
    datagram = build_control_datagram(MESG_QUICKCONN_ACK, "10.0.0.3", "10.0.0.1", 7)

    result, _sent_controls = run_quickconn_probe(monkeypatch, [(datagram, ("10.0.0.3", 7000))])

    expect_false(result, "quickconn result")
    expect_equal(result.reason, "wrong-peer", "quickconn reason")
    expect_equal(result.malformed_datagrams, 0, "quickconn malformed datagrams")
    expect_equal(result.wrong_peer_datagrams, 1, "quickconn wrong-peer datagrams")
    expect_equal(result.unexpected_datagrams, 0, "quickconn unexpected datagrams")


def test_quickconn_result_reports_timeout_without_ack(monkeypatch: pytest.MonkeyPatch) -> None:
    result, _sent_controls = run_quickconn_probe(monkeypatch, [])

    expect_false(result, "quickconn result")
    expect_equal(result.reason, "timeout", "quickconn reason")
    expect_equal(result.malformed_datagrams, 0, "quickconn malformed datagrams")
    expect_equal(result.wrong_peer_datagrams, 0, "quickconn wrong-peer datagrams")
    expect_equal(result.unexpected_datagrams, 0, "quickconn unexpected datagrams")


def test_status_probe_result_reports_timeout(monkeypatch: pytest.MonkeyPatch) -> None:
    result, _sent_controls = run_status_probe(monkeypatch, [])

    expect_false(result.acknowledged, "status ack")
    expect_equal(result.reason, "timeout", "status reason")
    expect_equal(result.malformed_datagrams, 0, "status malformed datagrams")
    expect_equal(result.wrong_peer_datagrams, 0, "status wrong-peer datagrams")
    expect_equal(result.unexpected_datagrams, 0, "status unexpected datagrams")


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
    expect_equal(sent_controls, [
        (MESG_CHECKLOLASTATUS, "10.0.0.2", 7, "ascii"),
        (MESG_CHECKLOLASTATUS, "10.0.0.2", 7, "osc15"),
    ], "sent status controls")


def test_status_probe_boolean_wrapper_preserves_compatibility(monkeypatch: pytest.MonkeyPatch) -> None:
    datagram = build_control_datagram(MESG_CHECKLOLASTATUS_ACK, "10.0.0.2", "10.0.0.1", 7)

    async def fake_recvfrom(_sock: object, _size: int) -> tuple[bytes, tuple[str, int]]:
        return datagram, ("10.0.0.2", 7000)

    monkeypatch.setattr(connector_module, "udp_recvfrom", fake_recvfrom)

    async def run() -> bool:
        connector = StatusProbeConnector("10.0.0.1")
        return await connector.check_status("10.0.0.2", sid=7, timeout=0.1)

    expect_true(asyncio.run(run()), "status boolean wrapper")


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
    expect_contains("status_ack=0", output, "CLI status output")
    expect_contains("status_reason=wrong-peer", output, "CLI status output")
    expect_contains("status_wrong_peer=1", output, "CLI status output")


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
            "ffmpeg",
            "--max-frame-bytes",
            "4096",
            "connect",
            "127.0.0.2",
        ]
    )

    capture = build_video_capture(args, MediaSettings(width=16, height=8, compression=1))

    expect_instance(capture, ProcessJpegVideoCapture, "JPEG video capture backend")
    capture = cast(ProcessJpegVideoCapture, capture)
    expect_equal(capture.max_frame_bytes, 4096, "JPEG frame byte cap")


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

        expect_equal({packet[0] for packet in packets}, {b"one", b"two"}, "serialized UDP payloads")
        expect_true(all(packet[1][0] == "127.0.0.1" for packet in packets), "serialized UDP source address")

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
        expect_true(fileno in connector_module._socket_read_locks, "socket read lock registry")
        expect_true(fileno in connector_module._socket_write_locks, "socket write lock registry")

        connector_module.close_udp_socket(sock)

        expect_false(fileno in connector_module._socket_read_locks, "socket read lock registry")
        expect_false(fileno in connector_module._socket_write_locks, "socket write lock registry")


class RuntimeFailureFakeSocket:
    def __init__(self) -> None:
        self.closed = False

    def close(self) -> None:
        self.closed = True


class RuntimeFailureAudioCapture(SilenceAudioCapture):
    def __init__(self, settings: MediaSettings) -> None:
        super().__init__(settings)
        self.closed = False

    async def aclose(self) -> None:
        self.closed = True


class RuntimeFailurePlayback(MemoryAudioPlayback):
    def __init__(self) -> None:
        super().__init__()
        self.closed = False

    async def aclose(self) -> None:
        self.closed = True


class RuntimeFailureVideoCapture:
    def __init__(self) -> None:
        self.closed = False

    async def read_frame(self) -> bytes:
        return b"frame"

    async def aclose(self) -> None:
        self.closed = True


class RuntimeFailureVideoDisplay:
    def __init__(self) -> None:
        self.closed = False

    async def show_frame(self, frame: bytes, sequence: int, compressed: bool) -> None:
        _ = frame
        _ = sequence
        _ = compressed

    async def aclose(self) -> None:
        self.closed = True


async def run_runtime_start_failure_case(fail_on_call: int) -> None:
    settings = MediaSettings()
    connector = LolaConnector("127.0.0.1", settings)
    connector.session = Session("127.0.0.1", "127.0.0.2", 1, settings)
    sockets: list[RuntimeFailureFakeSocket] = []

    def make_udp_socket(bind_port: int = 0) -> RuntimeFailureFakeSocket:
        _ = bind_port
        if len(sockets) + 1 == fail_on_call:
            raise OSError("socket setup failed")
        sock = RuntimeFailureFakeSocket()
        sockets.append(sock)
        return sock

    connector.make_udp_socket = make_udp_socket  # type: ignore[assignment,method-assign]
    audio_capture = RuntimeFailureAudioCapture(settings)
    audio_playback = RuntimeFailurePlayback()
    video_capture = RuntimeFailureVideoCapture()
    video_display = RuntimeFailureVideoDisplay()
    runtime = LolaLinuxRuntime(connector, audio_capture, audio_playback, video_capture, video_display)

    with pytest.raises(OSError, match="socket setup failed"):
        await runtime.start()

    expect_true(sockets, "partially opened runtime sockets")
    expect_true(all(sock.closed for sock in sockets), "partial runtime socket cleanup")
    expect_true(audio_capture.closed, "partial audio capture cleanup")
    expect_true(audio_playback.closed, "partial audio playback cleanup")
    expect_true(video_capture.closed, "partial video capture cleanup")
    expect_true(video_display.closed, "partial video display cleanup")


def test_runtime_start_failure_closes_partial_socket_and_backend_setup() -> None:

    asyncio.run(run_runtime_start_failure_case(fail_on_call=2))
    asyncio.run(run_runtime_start_failure_case(fail_on_call=3))


def test_bidirectional_udp_runtime_selftest() -> None:

    require_loopback_alias()
    stats_a, stats_b = asyncio.run(run_bidirectional_selftest(seconds=0.12, port_offset=21000))
    expect_greater_than(stats_a.audio_rx, 0, "selftest peer A audio RX")
    expect_greater_than(stats_b.audio_rx, 0, "selftest peer B audio RX")
    expect_greater_than(stats_a.video_rx, 0, "selftest peer A video RX")
    expect_greater_than(stats_b.video_rx, 0, "selftest peer B video RX")


def test_control_handshake_udp_selftest() -> None:

    require_loopback_alias()
    session_a, session_b = asyncio.run(run_control_handshake_selftest(port_offset=23000))
    expect_equal(session_a.remote_ip, "127.0.0.2", "selftest peer A remote IP")
    expect_equal(session_b.remote_ip, "127.0.0.1", "selftest peer B remote IP")
