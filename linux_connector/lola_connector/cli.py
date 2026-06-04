"""Command-line entry point for the LoLa Linux compatibility seed."""

from __future__ import annotations

import argparse
import asyncio
import logging
import math

from .backends import (
    AudioCapture,
    VideoCapture,
    MemoryAudioPlayback,
    MemoryVideoDisplay,
    DiagnosticVideoCapture,
    MultiToneAudioCapture,
    ProcessAudioCapture,
    ProcessAudioPlayback,
    ProcessJpegVideoCapture,
    ProcessRawVideoCapture,
    ProcessVideoDisplay,
    SilenceAudioCapture,
    SineAudioCapture,
)
from .media import AUDIO_UDP_PAYLOAD_SIZE, FRAGMENT_HEADER_SIZE, MAX_MEDIA_FRAME_SIZE
from .connector import LolaConnector, Session
from .protocol import MESG_SEND_AUDIO_SIGNAL, MESG_STOP_AUDIO_SIGNAL, MediaSettings
from .runtime import LolaLinuxRuntime
from .selftest import run_bidirectional_selftest, run_control_handshake_selftest


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="LoLa 2.0 Linux compatibility seed")
    parser.add_argument("--local-ip", required=True, help="Linux-side IPv4 address visible to LoLa")
    parser.add_argument("--sr", type=int, default=44100)
    parser.add_argument("--bps", type=int, default=16)
    parser.add_argument("--channels", type=int, default=2)
    parser.add_argument("--fps", type=int, default=25)
    parser.add_argument("--bpp", type=int, default=8)
    parser.add_argument("--width", type=int, default=640)
    parser.add_argument("--height", type=int, default=480)
    parser.add_argument("--compression", type=int, choices=[0, 1], default=0)
    parser.add_argument("--packet-size", type=int, default=1000)
    parser.add_argument("--control-dialect", choices=["ascii", "osc15", "auto"], default="ascii")
    parser.add_argument("--source-name", default="", help="Optional OSC15 source name; defaults to the local IP")
    parser.add_argument("--audio-capture-cmd", help="Command that writes raw PCM to stdout")
    parser.add_argument("--audio-playback-cmd", help="Command that reads raw PCM from stdin")
    parser.add_argument("--video-capture-cmd", help="Command that writes raw frames or JPEG frames to stdout")
    parser.add_argument("--video-display-cmd", help="Command that reads raw frames or JPEG frames from stdin")
    parser.add_argument("--max-frame-bytes", type=int, default=16 * 1024 * 1024, help="Maximum accepted JPEG frame size in bytes")
    parser.add_argument("--audio-frames-per-callback", type=int, default=64, help="PCM frames per LoLa audio packet")
    parser.add_argument("--audio-interval-scale", type=float, default=1.0, help="Scale synthetic audio packet interval for clock tuning")
    parser.set_defaults(wait_for_remote_test_signal=False, request_remote_audio_signal=False)
    sub = parser.add_subparsers(dest="mode", required=True)
    selftest = sub.add_parser("selftest", help="Run local bidirectional UDP audio/video runtime test")
    selftest.add_argument("--duration", type=float, default=0.25)
    selftest.add_argument("--port-offset", type=int)
    status = sub.add_parser("status", help="Send LoLa status probe and wait for ACK")
    status.add_argument("remote_ip")
    status.add_argument("--sid", type=int, default=0)
    status.add_argument("--timeout", type=float, default=2.0)
    listen = sub.add_parser("listen", help="Accept one incoming LoLa QuickConn")
    listen.add_argument("--rx", action="store_true", help="Print decoded incoming media metadata after ACK")
    add_test_media_args(listen)
    listen.add_argument("--duration", type=float, help="Run media runtime for this many seconds")
    listen.add_argument("--wait-for-remote-test-signal", action="store_true", help="Prepare synthetic media but start TX only after remote LoLa asks for AV test signals")
    listen.add_argument("--request-remote-audio-signal", action="store_true", help="Ask remote LoLa to transmit its built-in audio test signal during the run")
    connect = sub.add_parser("connect", help="Initiate QuickConn to a LoLa host")
    connect.add_argument("remote_ip")
    connect.add_argument("--sid", type=int, default=0)
    connect.add_argument("--rx", action="store_true", help="Print decoded incoming media metadata after ACK")
    add_test_media_args(connect)
    connect.add_argument("--duration", type=float, help="Run media runtime for this many seconds")
    connect.add_argument("--wait-for-remote-test-signal", action="store_true", help="Prepare synthetic media but start TX only after remote LoLa asks for AV test signals")
    connect.add_argument("--request-remote-audio-signal", action="store_true", help="Ask remote LoLa to transmit its built-in audio test signal during the run")
    return parser


def add_test_media_args(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--test-media", choices=["silence", "sine", "tones", "diagnostic"], help="Transmit generated audio/video after ACK")
    parser.add_argument("--tone-frequency", type=float, default=440.0)
    parser.add_argument("--tone-amplitude", type=float, default=0.15)


async def run(args: argparse.Namespace) -> None:
    if args.mode == "selftest":
        await run_selftest_mode(args)
        return
    connector = connector_from_args(args)
    if args.mode == "status":
        await run_status_mode(args, connector)
        return
    session = await establish_session(args, connector)
    print(f"connected sid={session.sid} local={session.local_ip} remote={session.remote_ip} remote_settings={session.remote_settings}")
    if should_start_runtime(args):
        await run_media_runtime(args, connector, session)
    elif args.rx:
        await connector.recv_media_forever()


async def run_selftest_mode(args: argparse.Namespace) -> None:
    duration = require_float_cli_attribute(args, "duration")
    port_offset = require_optional_int_cli_attribute(args, "port_offset")
    await run_control_handshake_selftest(port_offset=port_offset)
    stats_a, stats_b = await run_bidirectional_selftest(seconds=duration, port_offset=port_offset)
    print(f"endpoint_a={stats_a}")
    print(f"endpoint_b={stats_b}")


def connector_from_args(args: argparse.Namespace) -> LolaConnector:
    return LolaConnector(
        args.local_ip,
        settings=media_settings_from_args(args),
        video_packet_size=args.packet_size,
        control_dialect=args.control_dialect,
        source_name=args.source_name,
    )


async def run_status_mode(args: argparse.Namespace, connector: LolaConnector) -> None:
    result = await connector.check_status_result(args.remote_ip, args.sid, timeout=args.timeout)
    print(
        f"status_ack={1 if result.acknowledged else 0} "
        f"status_reason={result.reason} "
        f"status_malformed={result.malformed_datagrams} "
        f"status_wrong_peer={result.wrong_peer_datagrams} "
        f"status_unexpected={result.unexpected_datagrams}"
    )


async def establish_session(args: argparse.Namespace, connector: LolaConnector) -> Session:
    if args.mode == "listen":
        return await connector.accept_once()
    return await connector.initiate(args.remote_ip, args.sid)


def should_start_runtime(args: argparse.Namespace) -> bool:
    return bool(
        args.test_media
        or args.audio_capture_cmd
        or args.audio_playback_cmd
        or args.video_capture_cmd
        or args.video_display_cmd
    )


async def run_media_runtime(args: argparse.Namespace, connector: LolaConnector, session: Session) -> None:
    settings = media_settings_from_args(args)
    video_capture = build_video_capture(args, settings)
    runtime = build_runtime(args, connector, settings, video_capture)
    tx_audio = not args.wait_for_remote_test_signal
    tx_video = video_capture is not None and not args.wait_for_remote_test_signal
    await runtime.start(receive=args.rx, transmit_audio=tx_audio, transmit_video=tx_video, control=True)
    if args.duration is None:
        await request_remote_audio_if_needed(args, connector, session)
        await asyncio.Event().wait()
    else:
        await run_timed_runtime(args, connector, session, runtime)


def build_runtime(
    args: argparse.Namespace,
    connector: LolaConnector,
    settings: MediaSettings,
    video_capture: VideoCapture | None,
) -> LolaLinuxRuntime:
    audio_playback = ProcessAudioPlayback(args.audio_playback_cmd) if args.audio_playback_cmd else MemoryAudioPlayback()
    video_display = ProcessVideoDisplay(args.video_display_cmd) if args.video_display_cmd else MemoryVideoDisplay()
    return LolaLinuxRuntime(
        connector,
        build_audio_capture(args, settings),
        audio_playback,
        video_capture=video_capture,
        video_display=video_display,
        audio_interval_scale=args.audio_interval_scale,
    )


async def run_timed_runtime(
    args: argparse.Namespace,
    connector: LolaConnector,
    session: Session,
    runtime: LolaLinuxRuntime,
) -> None:
    try:
        await request_remote_audio_if_needed(args, connector, session)
        await asyncio.sleep(args.duration)
    finally:
        if args.request_remote_audio_signal:
            await connector.send_control_once(MESG_STOP_AUDIO_SIGNAL, session.remote_ip, session.sid)
        await runtime.stop()
        await connector.send_disconnect()
    print(f"runtime stats: {runtime.stats}")


async def request_remote_audio_if_needed(args: argparse.Namespace, connector: LolaConnector, session: Session) -> None:
    if args.request_remote_audio_signal:
        await connector.send_control_once(MESG_SEND_AUDIO_SIGNAL, session.remote_ip, session.sid)


def require_cli_attribute(args: argparse.Namespace, name: str) -> object:
    if not hasattr(args, name):
        raise RuntimeError(f"CLI parser did not provide required selftest argument: {name}")
    return getattr(args, name)


def require_float_cli_attribute(args: argparse.Namespace, name: str) -> float:
    value = require_cli_attribute(args, name)
    if isinstance(value, int | float):
        return float(value)
    raise RuntimeError(f"CLI parser provided non-float selftest argument {name}: {value!r}")


def require_optional_int_cli_attribute(args: argparse.Namespace, name: str) -> int | None:
    value = require_cli_attribute(args, name)
    if value is None or isinstance(value, int):
        return value
    raise RuntimeError(f"CLI parser provided non-int selftest argument {name}: {value!r}")


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(message)s")
    parser = build_parser()
    args = parser.parse_args()
    try:
        validate_cli_args(args)
    except ValueError as exc:
        parser.error(str(exc))
    asyncio.run(run(args))


def media_settings_from_args(args: argparse.Namespace) -> MediaSettings:
    return MediaSettings(
        sample_rate=args.sr,
        bits_per_sample=args.bps,
        channels=args.channels,
        fps=args.fps,
        bits_per_pixel=args.bpp,
        width=args.width,
        height=args.height,
        compression=args.compression,
    )


def validate_cli_args(args: argparse.Namespace) -> None:
    settings = media_settings_from_args(args)
    require_int_range("packet_size", args.packet_size, 0x80, 0x2000)
    require_int_range("max_frame_bytes", args.max_frame_bytes, 1, MAX_MEDIA_FRAME_SIZE)
    require_int_range("audio_frames_per_callback", args.audio_frames_per_callback, 1, 4096)
    max_pcm_bytes = AUDIO_UDP_PAYLOAD_SIZE - FRAGMENT_HEADER_SIZE - 8
    pcm_bytes = settings.channels * args.audio_frames_per_callback * max(1, settings.bits_per_sample // 8)
    if pcm_bytes > max_pcm_bytes:
        raise ValueError(f"audio callback block exceeds LoLa UDP payload: {pcm_bytes} > {max_pcm_bytes}")
    require_finite_range("audio_interval_scale", args.audio_interval_scale, minimum=0.0001, maximum=100.0)
    if hasattr(args, "duration") and args.duration is not None:
        require_finite_range("duration", args.duration, minimum=0.001, maximum=86_400.0)
    if hasattr(args, "timeout"):
        require_finite_range("timeout", args.timeout, minimum=0.001, maximum=86_400.0)
    if hasattr(args, "tone_frequency"):
        require_finite_range("tone_frequency", args.tone_frequency, minimum=1.0, maximum=24_000.0)
    if hasattr(args, "tone_amplitude"):
        require_finite_range("tone_amplitude", args.tone_amplitude, minimum=0.0, maximum=1.0)
    if hasattr(args, "sid"):
        require_int_range("sid", args.sid, 0, 2_147_483_647)
    if hasattr(args, "port_offset") and args.port_offset is not None:
        require_int_range("port_offset", args.port_offset, 0, 40_000)


def require_int_range(name: str, value: int, minimum: int, maximum: int) -> None:
    if value < minimum or value > maximum:
        raise ValueError(f"{name} must be between {minimum} and {maximum}, got {value}")


def require_finite_range(name: str, value: float, *, minimum: float, maximum: float) -> None:
    if not math.isfinite(value) or value < minimum or value > maximum:
        raise ValueError(f"{name} must be finite and between {minimum:g} and {maximum:g}, got {value!r}")


def build_audio_capture(args: argparse.Namespace, settings: MediaSettings) -> AudioCapture:
    if args.audio_capture_cmd:
        return ProcessAudioCapture(args.audio_capture_cmd, settings)
    # "diagnostic" includes audio so the single command reproduces full Linux
    # synthetic AV into Windows LoLa. "sine" is intentionally audio-only.
    if args.test_media in {"tones", "diagnostic"}:
        return MultiToneAudioCapture(settings, amplitude=args.tone_amplitude, frames_per_callback=args.audio_frames_per_callback)
    if args.test_media == "sine":
        return SineAudioCapture(settings, frequency=args.tone_frequency, amplitude=args.tone_amplitude, frames_per_callback=args.audio_frames_per_callback)
    return SilenceAudioCapture(settings, frames_per_callback=args.audio_frames_per_callback)


def build_video_capture(args: argparse.Namespace, settings: MediaSettings) -> VideoCapture | None:
    if args.video_capture_cmd:
        if settings.compression == 1:
            return ProcessJpegVideoCapture(args.video_capture_cmd, max_frame_bytes=args.max_frame_bytes)
        return ProcessRawVideoCapture(args.video_capture_cmd, settings)
    if args.test_media == "diagnostic" and settings.compression == 0:
        return DiagnosticVideoCapture(settings)
    # Keep sine/tones/silence audio-only; this was essential for isolating
    # audio timing without video fragment bursts.
    return None


if __name__ == "__main__":
    main()
