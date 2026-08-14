"""Tests for runtime pacing and defensive media receive contracts."""

# pylint: disable=missing-function-docstring

from __future__ import annotations

import asyncio
import logging
import time
from collections.abc import Callable

import pytest
from pytest import LogCaptureFixture

import linux_connector.lola_connector.runtime as runtime_module
import linux_connector.lola_connector.runtime_control as runtime_control_module
from linux_connector.lola_connector.backends import MemoryAudioPlayback, MemoryVideoDisplay, SilenceAudioCapture
from linux_connector.lola_connector.connector import Session
from linux_connector.lola_connector.connector_impl import LolaConnector
from linux_connector.lola_connector.media import MediaReassembler, build_audio_payload, build_video_prelude
from linux_connector.lola_connector.protocol import MediaSettings
from linux_connector.lola_connector.runtime import LolaLinuxRuntime
from linux_connector.lola_connector.runtime_types import AudioTxPacing
from linux_connector.tests.support import (
    expect_contains,
    expect_equal,
    expect_greater_than,
    expect_log_messages,
    expect_true,
    receive_payload,
    runtime_with_session,
)


async def _handle_media_receive(
    monkeypatch: pytest.MonkeyPatch,
    payload: bytes,
    parser: Callable[[bytes], object] | None = None,
) -> LolaLinuxRuntime:
    runtime = runtime_with_session()
    if parser is not None:
        monkeypatch.setattr(runtime_module, "parse_media_payload", parser)
    session = runtime.connector.session
    if session is None:
        raise AssertionError("runtime test session was not configured")
    await runtime._handle_media_payload(  # pylint: disable=protected-access
        payload,
        "127.0.0.2",
        session,
        MediaReassembler(),
        "audio",
    )
    return runtime


def test_audio_pacer_resumes_one_quantum_after_any_missed_deadline(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    settings = MediaSettings(width=16, height=8)
    connector = LolaConnector("127.0.0.1", settings)
    runtime = LolaLinuxRuntime(connector, SilenceAudioCapture(settings), MemoryAudioPlayback())
    pacing = AudioTxPacing(external=True, interval=0.001, next_send=1.0)
    monkeypatch.setattr(time, "perf_counter", lambda: 1.0015)

    runtime._advance_audio_tx_deadline(pacing)  # pylint: disable=protected-access

    expect_equal(pacing.next_send, 1.0025)


def test_audio_tx_pacing_for_capture_accepts_keyword_and_positional_inputs() -> None:
    keyword_pacing = AudioTxPacing.for_capture(
        frames_per_callback=48,
        sample_rate=48_000,
        interval_scale=0.5,
        external_pacing=True,
        now=3.0,
    )
    positional_pacing = AudioTxPacing.for_capture(  # type: ignore[call-arg]
        48, 48_000, 0.5, True, 3.0
    )

    expect_equal(keyword_pacing, AudioTxPacing(external=True, interval=0.0005, next_send=3.0))
    expect_equal(positional_pacing, keyword_pacing)


@pytest.mark.parametrize(
    ("frames_per_callback", "sample_rate", "expected_interval"),
    [(0, 48_000, 0.0), (48, 0, 24.0)],
)
def test_audio_tx_pacing_for_capture_preserves_zero_input_calculations(
    frames_per_callback: int,
    sample_rate: int,
    expected_interval: float,
) -> None:
    pacing = AudioTxPacing.for_capture(  # type: ignore[call-arg]
        frames_per_callback,
        sample_rate,
        0.5,
        True,
        7.0,
    )

    expect_equal(pacing.interval, expected_interval)
    expect_equal(pacing.external, expected_interval > 0.0)
    expect_equal(pacing.next_send, 7.0)


def test_audio_tx_pacing_for_capture_rejects_too_many_positional_inputs() -> None:
    with pytest.raises(TypeError) as error:
        AudioTxPacing.for_capture(1, 2, 3.0, True, 4.0, 5)  # type: ignore[call-arg]

    expect_equal(str(error.value), "for_capture accepts at most five positional arguments")


def test_audio_tx_pacing_for_capture_reports_first_unexpected_keyword() -> None:
    with pytest.raises(TypeError) as error:
        AudioTxPacing.for_capture(alpha=1, zeta=2)  # type: ignore[call-arg]

    expect_equal(str(error.value), "for_capture got an unexpected keyword argument 'alpha'")


def test_audio_tx_pacing_for_capture_rejects_duplicate_positional_keyword_input() -> None:
    with pytest.raises(TypeError) as error:
        AudioTxPacing.for_capture(
            48,
            frames_per_callback=48,
            sample_rate=48_000,
            interval_scale=0.5,
            external_pacing=True,
            now=3.0,
        )

    expect_equal(str(error.value), "for_capture got multiple values for argument 'frames_per_callback'")


def test_audio_tx_pacing_for_capture_reports_first_missing_required_input() -> None:
    with pytest.raises(TypeError) as error:
        AudioTxPacing.for_capture(sample_rate=48_000)  # type: ignore[call-arg]

    expect_equal(str(error.value), "for_capture missing required argument 'frames_per_callback'")


def test_memory_sinks_have_fixed_diagnostic_capacity() -> None:
    async def run() -> None:
        audio = MemoryAudioPlayback(capacity=1)
        video = MemoryVideoDisplay(capacity=1)
        await audio.write_block(b"one", 1)
        await audio.write_block(b"two", 2)
        await video.show_frame(b"one", 1, False)
        await video.show_frame(b"two", 2, False)
        expect_equal(len(audio.blocks), 1)
        expect_equal(audio.dropped_blocks, 1)
        expect_equal(len(video.frames), 1)
        expect_equal(video.dropped_frames, 1)

    asyncio.run(run())


def test_runtime_media_rx_logs_unexpected_payload_type(
    monkeypatch: pytest.MonkeyPatch,
    caplog: LogCaptureFixture,
) -> None:
    caplog.set_level(logging.WARNING, logger="linux_connector.lola_connector.runtime")
    asyncio.run(_handle_media_receive(monkeypatch, b"unexpected", lambda _payload: object()))
    expect_log_messages(
        caplog.text,
        ("ignored unexpected LoLa", "media payload type object from=127.0.0.2"),
    )


def test_runtime_media_rx_counts_malformed_payload_without_task_failure(
    monkeypatch: pytest.MonkeyPatch,
    caplog: LogCaptureFixture,
) -> None:
    caplog.set_level(logging.WARNING, logger="linux_connector.lola_connector.runtime")
    runtime = asyncio.run(_handle_media_receive(monkeypatch, b"not-a-lola-media-packet"))
    expect_greater_than(runtime.stats.audio_malformed_rx + runtime.stats.video_malformed_rx, 0)
    expect_log_messages(caplog.text, ("ignored unrecognized LoLa", "media payload"))


def test_runtime_audio_rx_rejects_video_prelude_then_recovers() -> None:
    async def run() -> None:
        runtime = runtime_with_session()
        session = runtime.connector.session
        if session is None:
            raise AssertionError("runtime test session was not configured")
        reassembler = MediaReassembler()

        await runtime._handle_media_payload(  # pylint: disable=protected-access
            build_video_prelude(7, 12, 1), "127.0.0.2", session, reassembler, "audio"
        )

        expect_equal(runtime.stats.audio_malformed_rx, 1)
        expect_equal((reassembler.frame_id, reassembler.expected_size, reassembler.fragment_count), (None, 0, 0))
        expect_equal(reassembler.parts, {})
        with pytest.raises(asyncio.QueueEmpty):
            runtime._audio_sink_queue.get_nowait()  # pylint: disable=protected-access

        await runtime._handle_media_payload(  # pylint: disable=protected-access
            build_audio_payload(8, b"pcm"), "127.0.0.2", session, reassembler, "audio"
        )

        expect_equal(runtime._audio_sink_queue.get_nowait(), (b"pcm", 8))  # pylint: disable=protected-access

    asyncio.run(run())


def test_runtime_media_sender_must_use_stream_source_port(caplog: LogCaptureFixture) -> None:
    settings = MediaSettings(width=16, height=8)
    connector = LolaConnector("127.0.0.1", settings, audio_port=19788, video_port=19798)
    connector.session = Session("127.0.0.1", "127.0.0.2", 1, settings)
    runtime = LolaLinuxRuntime(connector, SilenceAudioCapture(settings), MemoryAudioPlayback())
    caplog.set_level(logging.WARNING, logger="linux_connector.lola_connector.runtime")

    session_for_media_sender = getattr(runtime, "_session_for_media_sender")
    expect_equal(session_for_media_sender(("127.0.0.2", 19788), "audio"), connector.session)
    expect_equal(session_for_media_sender(("127.0.0.2", 19798), "video"), connector.session)
    expect_equal(session_for_media_sender(("127.0.0.2", 12345), "audio"), None)
    expect_equal(session_for_media_sender(("127.0.0.2", 12345), "video"), None)
    expect_equal(runtime.stats.audio_malformed_rx, 1)
    expect_equal(runtime.stats.video_malformed_rx, 1)
    expect_contains("unexpected source port", caplog.text)


@pytest.mark.usefixtures("require_localhost_udp")
def test_runtime_control_loop_counts_malformed_payload_without_task_failure(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    async def run() -> None:
        runtime = runtime_with_session()
        monkeypatch.setattr(
            runtime_control_module,
            "udp_recvfrom",
            lambda sock, _size: receive_payload(b"not-a-lola-control-packet", ("127.0.0.2", 7000)),
        )

        await runtime.run_for(0.01, receive=False, transmit_audio=False, transmit_video=False, control=True)

        expect_greater_than(runtime.stats.control_malformed_rx, 0)

    asyncio.run(run())


@pytest.mark.usefixtures("require_localhost_udp")
def test_runtime_run_for_yields_to_event_loop() -> None:
    async def run() -> None:
        runtime = runtime_with_session()
        observed = False

        async def marker() -> None:
            nonlocal observed
            await asyncio.sleep(0)
            observed = True

        marker_task = asyncio.create_task(marker())
        await runtime.run_for(
            0.01,
            receive=False,
            transmit_audio=False,
            transmit_video=False,
            control=False,
        )
        await marker_task
        expect_true(observed, "runtime should yield to the event loop")

    asyncio.run(run())
