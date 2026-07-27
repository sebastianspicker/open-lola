"""Command-line entry point for the Open LoLa Linux compatibility prototype."""

from __future__ import annotations

import argparse
import asyncio
from collections.abc import Iterable
from dataclasses import dataclass
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
from .connector import Session
from .connector_impl import LolaConnector
from .protocol import MESG_SEND_AUDIO_SIGNAL, MESG_STOP_AUDIO_SIGNAL, MediaSettings
from .runtime import LolaLinuxRuntime
from .selftest import run_bidirectional_selftest, run_control_handshake_selftest


@dataclass(frozen=True)
class OptionalFiniteRange:
    """Name a finite CLI argument range, including whether its absence is allowed."""
    name: str
    minimum: float
    maximum: float
    allow_none: bool = False


OPTIONAL_FINITE_RANGES = (
    OptionalFiniteRange("duration", 0.001, 86_400.0, allow_none=True),
    OptionalFiniteRange("timeout", 0.001, 86_400.0),
    OptionalFiniteRange("tone_frequency", 1.0, 24_000.0),
    OptionalFiniteRange("tone_amplitude", 0.0, 1.0),
)


def build_parser() -> argparse.ArgumentParser:
    """Create the CLI parser with global and mode-specific LoLa arguments."""
    parser = argparse.ArgumentParser(
        description="Open LoLa Linux compatibility prototype for LoLa 2.0"
    )
    add_global_args(parser)
    parser.set_defaults(wait_for_remote_test_signal=False, request_remote_audio_signal=False)
    sub = parser.add_subparsers(dest="mode", required=True)
    add_selftest_subparser(sub)
    add_status_subparser(sub)
    add_listen_subparser(sub)
    add_connect_subparser(sub)
    return parser


def add_global_args(parser: argparse.ArgumentParser) -> None:
    """Add addressing, media-format, and backend options shared by every mode."""
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
    parser.add_argument(
        "--source-name",
        default="",
        help="Optional OSC15 source name; defaults to the local IP",
    )
    parser.add_argument("--audio-capture-cmd", help="Command that writes raw PCM to stdout")
    parser.add_argument("--audio-playback-cmd", help="Command that reads raw PCM from stdin")
    parser.add_argument(
        "--video-capture-cmd", help="Command that writes raw frames or JPEG frames to stdout"
    )
    parser.add_argument(
        "--video-display-cmd",
        help="Command that reads raw frames or JPEG frames from stdin",
    )
    parser.add_argument(
        "--max-frame-bytes",
        type=int,
        default=16 * 1024 * 1024,
        help="Maximum accepted JPEG frame size in bytes",
    )
    parser.add_argument(
        "--audio-frames-per-callback",
        type=int,
        default=64,
        help="PCM frames per LoLa audio packet",
    )
    parser.add_argument(
        "--audio-interval-scale",
        type=float,
        default=1.0,
        help="Scale synthetic audio packet interval for clock tuning",
    )


def add_selftest_subparser(sub: argparse._SubParsersAction[argparse.ArgumentParser]) -> None:
    """Add the bounded local synthetic-transport self-test command."""
    selftest = sub.add_parser(
        "selftest", help="Run local synthetic UDP transport test; not physical end-to-end proof"
    )
    selftest.add_argument("--duration", type=float, default=0.25)
    selftest.add_argument("--port-offset", type=int)


def add_status_subparser(sub: argparse._SubParsersAction[argparse.ArgumentParser]) -> None:
    """Add the remote status-probe command and its ACK timeout settings."""
    status = sub.add_parser("status", help="Send LoLa status probe and wait for ACK")
    status.add_argument("remote_ip")
    status.add_argument("--sid", type=int, default=0)
    status.add_argument("--timeout", type=float, default=2.0)


def add_listen_subparser(sub: argparse._SubParsersAction[argparse.ArgumentParser]) -> None:
    """Add the passive QuickConn command with optional receive and test media."""
    listen = sub.add_parser("listen", help="Accept one incoming LoLa QuickConn")
    listen.add_argument(
        "--rx", action="store_true", help="Print decoded incoming media metadata after ACK"
    )
    add_test_media_args(listen)
    listen.add_argument("--duration", type=float, help="Run media runtime for this many seconds")
    listen.add_argument(
        "--wait-for-remote-test-signal",
        action="store_true",
        help="Prepare synthetic media but start TX only after remote LoLa asks for AV test signals",
    )
    listen.add_argument(
        "--request-remote-audio-signal",
        action="store_true",
        help="Ask remote LoLa to transmit its built-in audio test signal during the run",
    )


def add_connect_subparser(sub: argparse._SubParsersAction[argparse.ArgumentParser]) -> None:
    """Add the initiating QuickConn command with remote endpoint parameters."""
    connect = sub.add_parser("connect", help="Initiate QuickConn to a LoLa host")
    connect.add_argument("remote_ip")
    connect.add_argument("--sid", type=int, default=0)
    connect.add_argument(
        "--rx", action="store_true", help="Print decoded incoming media metadata after ACK"
    )
    add_test_media_args(connect)
    connect.add_argument("--duration", type=float, help="Run media runtime for this many seconds")
    connect.add_argument(
        "--wait-for-remote-test-signal",
        action="store_true",
        help="Prepare synthetic media but start TX only after remote LoLa asks for AV test signals",
    )
    connect.add_argument(
        "--request-remote-audio-signal",
        action="store_true",
        help="Ask remote LoLa to transmit its built-in audio test signal during the run",
    )

def add_test_media_args(parser: argparse.ArgumentParser) -> None:
    """Add synthetic-media selection and tone controls to a media-capable mode."""
    parser.add_argument(
        "--test-media",
        choices=["silence", "sine", "tones", "diagnostic"],
        help="Transmit generated audio/video after ACK",
    )
    parser.add_argument("--tone-frequency", type=float, default=440.0)
    parser.add_argument("--tone-amplitude", type=float, default=0.15)


async def run(args: argparse.Namespace) -> None:
    """Dispatch the selected CLI mode to self-test, status, or negotiated media work."""
    if args.mode == "selftest":
        await run_selftest_mode(args)
        return
    connector = connector_from_args(args)
    if args.mode == "status":
        await run_status_mode(args, connector)
        return
    session = await establish_session(args, connector)
    print(
        f"connected sid={session.sid} local={session.local_ip} "
        f"remote={session.remote_ip} remote_settings={session.remote_settings}"
    )
    if should_start_runtime(args):
        await run_media_runtime(args, connector, session)
    elif args.rx:
        await connector.recv_media_forever()


async def run_selftest_mode(args: argparse.Namespace) -> None:
    """Run control and bidirectional loopback checks, then print both counter sets."""
    duration = require_float_cli_attribute(args, "duration")
    port_offset = require_optional_int_cli_attribute(args, "port_offset")
    await run_control_handshake_selftest(port_offset=port_offset)
    stats_a, stats_b = await run_bidirectional_selftest(seconds=duration, port_offset=port_offset)
    print(f"endpoint_a={stats_a}")
    print(f"endpoint_b={stats_b}")


def connector_from_args(args: argparse.Namespace) -> LolaConnector:
    """Construct a connector from the CLI's validated settings."""
    return LolaConnector(
        args.local_ip,
        settings=media_settings_from_args(args),
        video_packet_size=args.packet_size,
        control_dialect=args.control_dialect,
        source_name=args.source_name,
    )


async def run_status_mode(args: argparse.Namespace, connector: LolaConnector) -> None:
    """Probe the remote endpoint and print ACK, malformed, and peer-rejection counts."""
    result = await connector.check_status_result(args.remote_ip, args.sid, timeout=args.timeout)
    print(
        f"status_ack={1 if result.acknowledged else 0} "
        f"status_reason={result.reason} "
        f"status_malformed={result.malformed_datagrams} "
        f"status_wrong_peer={result.wrong_peer_datagrams} "
        f"status_unexpected={result.unexpected_datagrams}"
    )


async def establish_session(args: argparse.Namespace, connector: LolaConnector) -> Session:
    """Perform the control handshake needed before media starts."""
    if args.mode == "listen":
        return await connector.accept_once()
    return await connector.initiate(args.remote_ip, args.sid)


def should_start_runtime(args: argparse.Namespace) -> bool:
    """Decide whether the selected CLI mode needs a media runtime."""
    return bool(
        args.test_media
        or args.audio_capture_cmd
        or args.audio_playback_cmd
        or args.video_capture_cmd
        or args.video_display_cmd
    )


async def run_media_runtime(
    args: argparse.Namespace, connector: LolaConnector, session: Session
) -> None:
    """Start negotiated media backends and choose indefinite or bounded execution."""
    settings = media_settings_from_args(args)
    video_capture = build_video_capture(args, settings)
    runtime = build_runtime(args, connector, settings, video_capture)
    tx_audio = not args.wait_for_remote_test_signal
    tx_video = video_capture is not None and not args.wait_for_remote_test_signal
    await runtime.start(
        receive=args.rx, transmit_audio=tx_audio, transmit_video=tx_video, control=True
    )
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
    """Compose capture, playback, display, and pacing backends for one session."""
    audio_playback = (
        ProcessAudioPlayback(
            args.audio_playback_cmd,
            block_bytes=settings.channels
            * args.audio_frames_per_callback
            * max(1, settings.bits_per_sample // 8),
        )
        if args.audio_playback_cmd
        else MemoryAudioPlayback()
    )
    video_display = (
        ProcessVideoDisplay(args.video_display_cmd)
        if args.video_display_cmd
        else MemoryVideoDisplay()
    )
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
    """Stop a timed run cleanly, including any requested remote test signal."""
    try:
        await request_remote_audio_if_needed(args, connector, session)
        await asyncio.sleep(args.duration)
    finally:
        if args.request_remote_audio_signal:
            await connector.send_control_once(
                MESG_STOP_AUDIO_SIGNAL, session.remote_ip, session.sid
            )
        await runtime.stop()
        await connector.send_disconnect()
    print(f"runtime stats: {runtime.stats}")


async def request_remote_audio_if_needed(
    args: argparse.Namespace, connector: LolaConnector, session: Session
) -> None:
    """Request the remote built-in audio signal when that diagnostic option is enabled."""
    if args.request_remote_audio_signal:
        await connector.send_control_once(MESG_SEND_AUDIO_SIGNAL, session.remote_ip, session.sid)


def require_cli_attribute(args: argparse.Namespace, name: str) -> object:
    """Return a parser-provided attribute or expose an internal CLI wiring error."""
    if not hasattr(args, name):
        raise RuntimeError(f"CLI parser did not provide required selftest argument: {name}")
    return getattr(args, name)


def require_float_cli_attribute(args: argparse.Namespace, name: str) -> float:
    """Return a numeric parser value as float, rejecting unexpected argument types."""
    value = require_cli_attribute(args, name)
    if isinstance(value, int | float):
        return float(value)
    raise RuntimeError(f"CLI parser provided non-float selftest argument {name}: {value!r}")


def require_optional_int_cli_attribute(args: argparse.Namespace, name: str) -> int | None:
    """Return an optional integer parser value, rejecting incompatible values early."""
    value = require_cli_attribute(args, name)
    if value is None or isinstance(value, int):
        return value
    raise RuntimeError(f"CLI parser provided non-int selftest argument {name}: {value!r}")


def main() -> None:
    """Parse and validate CLI arguments before dispatching the selected async mode."""
    logging.basicConfig(level=logging.INFO, format="%(message)s")
    parser = build_parser()
    args = parser.parse_args()
    try:
        validate_cli_args(args)
    except ValueError as exc:
        parser.error(str(exc))
    asyncio.run(run(args))


def media_settings_from_args(args: argparse.Namespace) -> MediaSettings:
    """Convert CLI media options into validated LoLa settings."""
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
    """Validate media settings and mode-dependent arguments before opening sockets."""
    settings = media_settings_from_args(args)
    validate_required_cli_bounds(args, settings)
    validate_optional_cli_bounds(args)


def validate_required_cli_bounds(args: argparse.Namespace, settings: MediaSettings) -> None:
    """Enforce packet, PCM, and timing limits implied by the LoLa wire format."""
    require_int_range("packet_size", args.packet_size, 0x80, 0x2000)
    require_int_range("max_frame_bytes", args.max_frame_bytes, 1, MAX_MEDIA_FRAME_SIZE)
    if args.audio_frames_per_callback != 64:
        raise ValueError(
            "audio_frames_per_callback must be 64: LoLa 2.0 has no callback-size negotiation"
        )
    max_pcm_bytes = AUDIO_UDP_PAYLOAD_SIZE - FRAGMENT_HEADER_SIZE - 8
    pcm_bytes = (
        settings.channels
        * args.audio_frames_per_callback
        * max(1, settings.bits_per_sample // 8)
    )
    if pcm_bytes > max_pcm_bytes:
        raise ValueError(
            f"audio callback block exceeds LoLa UDP payload: {pcm_bytes} > {max_pcm_bytes}"
        )
    require_finite_range(
        "audio_interval_scale", args.audio_interval_scale, minimum=0.0001, maximum=100.0
    )


def validate_optional_cli_bounds(args: argparse.Namespace) -> None:
    """Validate optional session and self-test parameters when their mode supplies them."""
    validate_optional_finite_ranges(args, OPTIONAL_FINITE_RANGES)
    if hasattr(args, "sid"):
        require_int_range("sid", args.sid, 0, 2_147_483_647)
    if hasattr(args, "port_offset") and args.port_offset is not None:
        require_int_range("port_offset", args.port_offset, 0, 40_000)


def validate_optional_finite_ranges(
    args: argparse.Namespace,
    ranges: Iterable[OptionalFiniteRange],
) -> None:
    """Validate configured finite ranges while preserving intentionally absent options."""
    for value_range in ranges:
        if not hasattr(args, value_range.name):
            continue
        value = getattr(args, value_range.name)
        if value is None and value_range.allow_none:
            continue
        if value is None:
            raise ValueError(f"{value_range.name} must not be None")
        require_finite_range(
            value_range.name,
            value,
            minimum=value_range.minimum,
            maximum=value_range.maximum,
        )


def require_int_range(name: str, value: int, minimum: int, maximum: int) -> None:
    """Raise a precise error unless an integer lies within its supported bounds."""
    if value < minimum or value > maximum:
        raise ValueError(f"{name} must be between {minimum} and {maximum}, got {value}")


def require_finite_range(name: str, value: float, *, minimum: float, maximum: float) -> None:
    """Reject non-finite or out-of-range floating-point media configuration values."""
    if not math.isfinite(value) or value < minimum or value > maximum:
        raise ValueError(
            f"{name} must be finite and between {minimum:g} and {maximum:g}, got {value!r}"
        )


def build_audio_capture(args: argparse.Namespace, settings: MediaSettings) -> AudioCapture:
    """Select process or synthetic audio capture from the requested test-media mode."""
    if args.audio_capture_cmd:
        return ProcessAudioCapture(args.audio_capture_cmd, settings)
    # "diagnostic" includes audio so the single command reproduces full Linux
    # synthetic AV into Windows LoLa. "sine" is intentionally audio-only.
    if args.test_media in {"tones", "diagnostic"}:
        return MultiToneAudioCapture(
            settings,
            amplitude=args.tone_amplitude,
            frames_per_callback=args.audio_frames_per_callback,
        )
    if args.test_media == "sine":
        return SineAudioCapture(
            settings,
            frequency=args.tone_frequency,
            amplitude=args.tone_amplitude,
            frames_per_callback=args.audio_frames_per_callback,
        )
    return SilenceAudioCapture(settings, frames_per_callback=args.audio_frames_per_callback)


def build_video_capture(args: argparse.Namespace, settings: MediaSettings) -> VideoCapture | None:
    """Select process or diagnostic video capture only when the mode carries video."""
    if args.video_capture_cmd:
        if settings.compression == 1:
            return ProcessJpegVideoCapture(
                args.video_capture_cmd, max_frame_bytes=args.max_frame_bytes
            )
        return ProcessRawVideoCapture(args.video_capture_cmd, settings)
    if args.test_media == "diagnostic" and settings.compression == 0:
        return DiagnosticVideoCapture(settings)
    # Keep sine/tones/silence audio-only; this was essential for isolating
    # audio timing without video fragment bursts.
    return None


if __name__ == "__main__":
    main()
