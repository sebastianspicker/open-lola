#!/usr/bin/env python3
import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


def load_runtime_text(path: Path) -> str:
    if path.suffix == ".json":
        payload = json.loads(path.read_text(encoding="utf-8"))
        process = payload.get("process", {})
        return "\n".join(
            str(process.get(key, payload.get(key, "")))
            for key in ("standardOutputPrefix", "standardErrorPrefix")
        )
    return path.read_text(encoding="utf-8", errors="replace")


def endpoint_metrics(label: str, path: Path, video_display: str) -> dict[str, Any]:
    text = load_runtime_text(path)
    packet_totals: dict[str, dict[str, float | int]] = {}
    for media, received, expected, percent, lost in re.findall(
        r"\[Pbuf\] \[(audio|video)\] ([0-9]+)\/([0-9]+) packets received "
        r"\(([0-9.]+)%\), ([0-9]+) lost",
        text,
    ):
        totals = packet_totals.setdefault(
            media,
            {"received": 0, "expected": 0, "lost": 0, "minPercent": 100.0},
        )
        totals["received"] = int(totals["received"]) + int(received)
        totals["expected"] = int(totals["expected"]) + int(expected)
        totals["lost"] = int(totals["lost"]) + int(lost)
        totals["minPercent"] = min(float(totals["minPercent"]), float(percent))

    audio_match = re.search(
        r"Audio dec stats \(cumulative\): ([0-9]+) played \/ ([0-9]+) total audio frames",
        text,
    )
    video_match = re.search(
        r"Video dec stats \(cumulative\): ([0-9]+) total \/ ([0-9]+) disp "
        r"\/ ([0-9]+) drop \/ ([0-9]+) corr \/ ([0-9]+) miss",
        text,
    )
    display_fps_values = [
        float(value)
        for value in re.findall(
            rf"\[{re.escape(video_display)}\] [0-9]+ frames in [0-9.]+ seconds = ([0-9.]+) FPS",
            text,
        )
    ]
    audio_format = re.search(r"New incoming audio format detected: ([^\n]+)", text)
    video_format = re.search(r"New incoming video format detected: ([^\n]+)", text)

    metrics: dict[str, Any] = {
        "label": label,
        "path": str(path),
        "audioFormat": audio_format.group(1) if audio_format else None,
        "videoFormat": video_format.group(1) if video_format else None,
        "packetTotals": packet_totals,
        "audioDecode": None,
        "videoDecode": None,
        "displayFps": {
            "samples": display_fps_values,
            "min": min(display_fps_values) if display_fps_values else None,
            "max": max(display_fps_values) if display_fps_values else None,
        },
    }
    if audio_match:
        played, total = (int(value) for value in audio_match.groups())
        metrics["audioDecode"] = {
            "played": played,
            "total": total,
            "lostFrames": total - played,
        }
    if video_match:
        total, displayed, dropped, corrected, missed = (
            int(value) for value in video_match.groups()
        )
        metrics["videoDecode"] = {
            "total": total,
            "displayed": displayed,
            "dropped": dropped,
            "corrected": corrected,
            "missed": missed,
        }
    return metrics


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def require_endpoint_health(endpoints: dict[str, dict[str, Any]]) -> list[str]:
    errors: list[str] = []
    for label, metrics in endpoints.items():
        require(metrics["audioFormat"] is not None, f"{label} missing audio format", errors)
        require(metrics["videoFormat"] is not None, f"{label} missing video format", errors)
        for media in ("audio", "video"):
            totals = metrics["packetTotals"].get(media)
            require(totals is not None, f"{label} missing {media} packet metrics", errors)
            if totals:
                require(int(totals["received"]) > 0, f"{label} {media} received no packets", errors)
                require(int(totals["lost"]) == 0, f"{label} {media} lost packets", errors)
                require(
                    float(totals["minPercent"]) == 100.0,
                    f"{label} {media} packet receipt below 100%",
                    errors,
                )
        audio_decode = metrics["audioDecode"]
        require(audio_decode is not None, f"{label} missing audio decode metrics", errors)
        if audio_decode:
            require(audio_decode["played"] > 0, f"{label} played no audio frames", errors)
            require(audio_decode["lostFrames"] == 0, f"{label} lost audio frames", errors)
        video_decode = metrics["videoDecode"]
        require(video_decode is not None, f"{label} missing video decode metrics", errors)
        if video_decode:
            require(video_decode["displayed"] > 0, f"{label} displayed no video frames", errors)
            require(video_decode["dropped"] == 0, f"{label} dropped video frames", errors)
            require(video_decode["missed"] == 0, f"{label} missed video frames", errors)
        display_fps = metrics["displayFps"]
        require(display_fps["min"] is not None, f"{label} missing display FPS metrics", errors)
        if display_fps["min"] is not None:
            require(display_fps["min"] > 0, f"{label} display FPS did not advance", errors)
    return errors


def min_packet_percent(endpoints: dict[str, dict[str, Any]], prefix: str) -> float:
    return min(
        float(totals["minPercent"])
        for label, metrics in endpoints.items()
        if label.startswith(prefix)
        for totals in metrics["packetTotals"].values()
    )


def audio_losses(endpoints: dict[str, dict[str, Any]], prefix: str) -> int:
    return sum(
        int(metrics["audioDecode"]["lostFrames"])
        for label, metrics in endpoints.items()
        if label.startswith(prefix) and metrics["audioDecode"]
    )


def video_losses(endpoints: dict[str, dict[str, Any]], prefix: str) -> int:
    return sum(
        int(metrics["videoDecode"]["dropped"]) + int(metrics["videoDecode"]["missed"])
        for label, metrics in endpoints.items()
        if label.startswith(prefix) and metrics["videoDecode"]
    )


def min_display_fps(endpoints: dict[str, dict[str, Any]], prefix: str) -> float:
    return min(
        float(metrics["displayFps"]["min"])
        for label, metrics in endpoints.items()
        if label.startswith(prefix) and metrics["displayFps"]["min"] is not None
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", required=True)
    parser.add_argument("--schema", required=True)
    parser.add_argument("--scope", required=True)
    parser.add_argument("--evidence-boundary", required=True)
    parser.add_argument("--direct-label", required=True)
    parser.add_argument("--direct-connection-ms", required=True, type=int)
    parser.add_argument("--managed-connection-metrics", required=True)
    parser.add_argument("--max-managed-connection-delta-ms", required=True, type=int)
    parser.add_argument("--connection-poll-seconds", required=True, type=float)
    parser.add_argument("--max-managed-display-fps-delta", required=True, type=float)
    parser.add_argument("--video-display", required=True)
    parser.add_argument("--preflight-report")
    parser.add_argument("endpoint", nargs="+")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if len(args.endpoint) % 2 != 0:
        print("endpoint arguments must be label/path pairs", file=sys.stderr)
        return 2

    managed_connection_metrics_path = Path(args.managed_connection_metrics)
    managed_connection_metrics = json.loads(
        managed_connection_metrics_path.read_text(encoding="utf-8")
    )
    managed_connection_ms = managed_connection_metrics.get("audioVideoConnectionMs")
    endpoints = {
        label: endpoint_metrics(label, Path(path), args.video_display)
        for label, path in zip(args.endpoint[0::2], args.endpoint[1::2], strict=True)
    }

    endpoint_health_errors = require_endpoint_health(endpoints)
    direct_min_packet_percent = min_packet_percent(endpoints, "direct-")
    managed_min_packet_percent = min_packet_percent(endpoints, "managed-")
    direct_audio_losses = audio_losses(endpoints, "direct-")
    managed_audio_losses = audio_losses(endpoints, "managed-")
    direct_video_losses = video_losses(endpoints, "direct-")
    managed_video_losses = video_losses(endpoints, "managed-")
    audio_formats = {metrics["audioFormat"] for metrics in endpoints.values()}
    video_formats = {metrics["videoFormat"] for metrics in endpoints.values()}
    direct_min_display_fps = min_display_fps(endpoints, "direct-")
    managed_min_display_fps = min_display_fps(endpoints, "managed-")
    connection_delta_ms = (
        managed_connection_ms - args.direct_connection_ms
        if isinstance(managed_connection_ms, int)
        else None
    )
    display_fps_delta = direct_min_display_fps - managed_min_display_fps

    parity_errors: list[str] = []
    require(
        managed_min_packet_percent >= direct_min_packet_percent,
        f"managed packet receipt is worse than {args.direct_label}",
        parity_errors,
    )
    require(
        managed_audio_losses <= direct_audio_losses,
        f"managed audio decode losses are worse than {args.direct_label}",
        parity_errors,
    )
    require(
        managed_video_losses <= direct_video_losses,
        f"managed video decode losses are worse than {args.direct_label}",
        parity_errors,
    )
    require(len(audio_formats) == 1, "direct and managed audio formats differ", parity_errors)
    require(len(video_formats) == 1, "direct and managed video formats differ", parity_errors)
    require(args.direct_connection_ms > 0, "direct connection timing was not measured", parity_errors)
    require(
        managed_connection_metrics.get("connected") is True,
        "managed connection timing did not reach audio and video",
        parity_errors,
    )
    require(isinstance(managed_connection_ms, int), "managed connection timing is missing", parity_errors)
    require(
        connection_delta_ms is not None
        and connection_delta_ms <= args.max_managed_connection_delta_ms,
        "managed connection setup is slower than direct by more than "
        f"{args.max_managed_connection_delta_ms} ms",
        parity_errors,
    )
    require(
        display_fps_delta <= args.max_managed_display_fps_delta,
        "managed display FPS is lower than direct by more than "
        f"{args.max_managed_display_fps_delta}",
        parity_errors,
    )

    direct_endpoint_health_errors = [
        error for error in endpoint_health_errors if error.startswith("direct-")
    ]
    managed_endpoint_health_errors = [
        error for error in endpoint_health_errors if error.startswith("managed-")
    ]
    report: dict[str, Any] = {
        "schema": args.schema,
        "verdict": "PARTIAL",
        "scope": args.scope,
        "evidenceBoundary": args.evidence_boundary,
        "comparisons": {
            "managedPacketReceiptNoWorseThanDirect": managed_min_packet_percent >= direct_min_packet_percent,
            "managedAudioDecodeNoWorseThanDirect": managed_audio_losses <= direct_audio_losses,
            "managedVideoDecodeNoWorseThanDirect": managed_video_losses <= direct_video_losses,
            "mediaFormatsMatch": len(audio_formats) == 1 and len(video_formats) == 1,
            "managedConnectionSetupWithinDelta": (
                connection_delta_ms is not None
                and connection_delta_ms <= args.max_managed_connection_delta_ms
            ),
            "managedDisplayFpsWithinDelta": display_fps_delta <= args.max_managed_display_fps_delta,
        },
        "endpointHealth": {
            "directBaselineClean": not direct_endpoint_health_errors,
            "managedEndpointClean": not managed_endpoint_health_errors,
            "allEndpointsClean": not endpoint_health_errors,
            "directErrors": direct_endpoint_health_errors,
            "managedErrors": managed_endpoint_health_errors,
            "errors": endpoint_health_errors,
        },
        "connectionSetup": {
            "directAudioVideoConnectionMs": args.direct_connection_ms,
            "managedAudioVideoConnectionMs": managed_connection_ms,
            "managedMinusDirectMs": connection_delta_ms,
            "maxManagedConnectionDeltaMs": args.max_managed_connection_delta_ms,
            "connectionPollSeconds": args.connection_poll_seconds,
            "managedMetricsPath": str(managed_connection_metrics_path),
        },
        "displaySmoothness": {
            "directMinDisplayFps": direct_min_display_fps,
            "managedMinDisplayFps": managed_min_display_fps,
            "directMinusManagedFps": display_fps_delta,
            "maxManagedDisplayFpsDelta": args.max_managed_display_fps_delta,
            "displayDevice": args.video_display,
        },
        "endpoints": endpoints,
        "errors": parity_errors,
    }
    if args.preflight_report:
        report["preflightReport"] = args.preflight_report

    Path(args.report).write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    if parity_errors:
        for error in parity_errors:
            print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
