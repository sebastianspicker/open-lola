"""Command-line entry point for the prototype LoLa Linux connector."""

from __future__ import annotations

import argparse
import asyncio

from .backends import (
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
from .connector import LolaConnector
from .protocol import MESG_SEND_AUDIO_SIGNAL, MESG_STOP_AUDIO_SIGNAL, MediaSettings
from .runtime import LolaLinuxRuntime
from .selftest import run_bidirectional_selftest, run_control_handshake_selftest


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Prototype LoLa 2.0 Linux connector")
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
    parser.add_argument("--audio-capture-cmd", help="Command that writes raw PCM to stdout")
    parser.add_argument("--audio-playback-cmd", help="Command that reads raw PCM from stdin")
    parser.add_argument("--video-capture-cmd", help="Command that writes raw frames or JPEG frames to stdout")
    parser.add_argument("--video-display-cmd", help="Command that reads raw frames or JPEG frames from stdin")
    parser.add_argument("--audio-frames-per-callback", type=int, default=64, help="PCM frames per LoLa audio packet")
    parser.add_argument("--audio-interval-scale", type=float, default=1.0, help="Scale synthetic audio packet interval for clock tuning")
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
    listen.add_argument("--test-media", choices=["silence", "sine", "tones", "diagnostic"], help="Transmit generated audio/video after ACK")
    listen.add_argument("--tone-frequency", type=float, default=440.0)
    listen.add_argument("--tone-amplitude", type=float, default=0.15)
    listen.add_argument("--duration", type=float, help="Run media runtime for this many seconds")
    listen.add_argument("--wait-for-remote-test-signal", action="store_true", help="Prepare synthetic media but start TX only after remote LoLa asks for AV test signals")
    connect = sub.add_parser("connect", help="Initiate QuickConn to a LoLa host")
    connect.add_argument("remote_ip")
    connect.add_argument("--sid", type=int, default=0)
    connect.add_argument("--rx", action="store_true", help="Print decoded incoming media metadata after ACK")
    connect.add_argument("--test-media", choices=["silence", "sine", "tones", "diagnostic"], help="Transmit generated audio/video after ACK")
    connect.add_argument("--tone-frequency", type=float, default=440.0)
    connect.add_argument("--tone-amplitude", type=float, default=0.15)
    connect.add_argument("--duration", type=float, help="Run media runtime for this many seconds")
    connect.add_argument("--wait-for-remote-test-signal", action="store_true", help="Prepare synthetic media but start TX only after remote LoLa asks for AV test signals")
    connect.add_argument("--request-remote-audio-signal", action="store_true", help="Ask remote LoLa to transmit its built-in audio test signal during the run")
    return parser


async def run(args: argparse.Namespace) -> None:
    if args.mode == "selftest":
        await run_control_handshake_selftest(port_offset=args.port_offset)
        stats_a, stats_b = await run_bidirectional_selftest(seconds=args.duration, port_offset=args.port_offset)
        print(f"endpoint_a={stats_a}")
        print(f"endpoint_b={stats_b}")
        return
    settings = MediaSettings(
        sample_rate=args.sr,
        bits_per_sample=args.bps,
        channels=args.channels,
        fps=args.fps,
        bits_per_pixel=args.bpp,
        width=args.width,
        height=args.height,
        compression=args.compression,
    )
    connector = LolaConnector(
        args.local_ip,
        settings=settings,
        video_packet_size=args.packet_size,
        control_dialect=args.control_dialect,
    )
    if args.mode == "status":
        ok = await connector.check_status(args.remote_ip, args.sid, timeout=args.timeout)
        print("status_ack=1" if ok else "status_ack=0")
        return
    if args.mode == "listen":
        session = await connector.accept_once()
    else:
        session = await connector.initiate(args.remote_ip, args.sid)
    print(f"connected sid={session.sid} local={session.local_ip} remote={session.remote_ip} remote_settings={session.remote_settings}")
    if args.test_media or args.audio_capture_cmd or args.audio_playback_cmd or args.video_capture_cmd or args.video_display_cmd:
        audio_capture = build_audio_capture(args, settings)
        audio_playback = ProcessAudioPlayback(args.audio_playback_cmd) if args.audio_playback_cmd else MemoryAudioPlayback()
        video_capture = build_video_capture(args, settings)
        video_display = ProcessVideoDisplay(args.video_display_cmd) if args.video_display_cmd else MemoryVideoDisplay()
        runtime = LolaLinuxRuntime(
            connector,
            audio_capture,
            audio_playback,
            video_capture=video_capture,
            video_display=video_display,
            audio_interval_scale=args.audio_interval_scale,
        )
        # The Windows Tools menu can ask the remote side to send test media.
        # With this flag, prepare the synthetic sources but keep TX disabled
        # until MESG_SEND_AUDIO_SIGNAL arrives.
        tx_audio = not getattr(args, "wait_for_remote_test_signal", False)
        tx_video = video_capture is not None and not getattr(args, "wait_for_remote_test_signal", False)
        if args.duration is None:
            await runtime.start(receive=args.rx, transmit_audio=tx_audio, transmit_video=tx_video, control=True)
            if getattr(args, "request_remote_audio_signal", False):
                await connector.send_control_once(MESG_SEND_AUDIO_SIGNAL, session.remote_ip, session.sid)
            await asyncio.Event().wait()
        else:
            await runtime.start(receive=args.rx, transmit_audio=tx_audio, transmit_video=tx_video, control=True)
            try:
                if getattr(args, "request_remote_audio_signal", False):
                    await connector.send_control_once(MESG_SEND_AUDIO_SIGNAL, session.remote_ip, session.sid)
                await asyncio.sleep(args.duration)
            finally:
                if getattr(args, "request_remote_audio_signal", False):
                    await connector.send_control_once(MESG_STOP_AUDIO_SIGNAL, session.remote_ip, session.sid)
                await runtime.stop()
                await connector.send_disconnect()
            print(f"runtime stats: {runtime.stats}")
    elif args.rx:
        await connector.recv_media_forever()


def main() -> None:
    asyncio.run(run(build_parser().parse_args()))


def build_audio_capture(args: argparse.Namespace, settings: MediaSettings):
    if args.audio_capture_cmd:
        return ProcessAudioCapture(args.audio_capture_cmd, settings)
    # "diagnostic" includes audio so the single command reproduces full Linux
    # synthetic AV into Windows LoLa. "sine" is intentionally audio-only.
    if args.test_media in {"tones", "diagnostic"}:
        return MultiToneAudioCapture(settings, amplitude=args.tone_amplitude, frames_per_callback=args.audio_frames_per_callback)
    if args.test_media == "sine":
        return SineAudioCapture(settings, frequency=args.tone_frequency, amplitude=args.tone_amplitude, frames_per_callback=args.audio_frames_per_callback)
    return SilenceAudioCapture(settings, frames_per_callback=args.audio_frames_per_callback)


def build_video_capture(args: argparse.Namespace, settings: MediaSettings):
    if args.video_capture_cmd:
        if settings.compression == 1:
            return ProcessJpegVideoCapture(args.video_capture_cmd)
        return ProcessRawVideoCapture(args.video_capture_cmd, settings)
    if args.test_media == "diagnostic" and settings.compression == 0:
        return DiagnosticVideoCapture(settings)
    # Keep sine/tones/silence audio-only; this was essential for isolating
    # audio timing without video fragment bursts.
    return None


if __name__ == "__main__":
    main()
