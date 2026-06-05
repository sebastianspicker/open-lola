#!/usr/bin/env python3
import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

PacketTotals = dict[str, dict[str, float | int]]
EndpointMap = dict[str, dict[str, Any]]


def load_runtime_text(path: Path) -> str:
    if path.suffix == ".json":
        payload = json.loads(path.read_text(encoding="utf-8"))
        process = payload.get("process", {})
        return "\n".join(
            str(process.get(key, payload.get(key, "")))
            for key in ("standardOutputPrefix", "standardErrorPrefix")
        )
    return path.read_text(encoding="utf-8", errors="replace")


def packet_totals_from_text(text: str) -> PacketTotals:
    packet_totals: PacketTotals = {}
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
    return packet_totals


def audio_decode_from_text(text: str) -> dict[str, int] | None:
    audio_match = re.search(
        r"Audio dec stats \(cumulative\): ([0-9]+) played \/ ([0-9]+) total audio frames",
        text,
    )
    if not audio_match:
        return None
    played, total = (int(value) for value in audio_match.groups())
    return {
        "played": played,
        "total": total,
        "lostFrames": total - played,
    }


def video_decode_from_text(text: str) -> dict[str, int] | None:
    video_match = re.search(
        r"Video dec stats \(cumulative\): ([0-9]+) total \/ ([0-9]+) disp "
        r"\/ ([0-9]+) drop \/ ([0-9]+) corr \/ ([0-9]+) miss",
        text,
    )
    if not video_match:
        return None
    total, displayed, dropped, corrected, missed = (int(value) for value in video_match.groups())
    return {
        "total": total,
        "displayed": displayed,
        "dropped": dropped,
        "corrected": corrected,
        "missed": missed,
    }


def display_fps_from_text(text: str, video_display: str) -> dict[str, Any]:
    display_fps_values = [
        float(value)
        for value in re.findall(
            rf"\[{re.escape(video_display)}\] [0-9]+ frames in [0-9.]+ seconds = ([0-9.]+) FPS",
            text,
        )
    ]
    return {
        "samples": display_fps_values,
        "min": min(display_fps_values) if display_fps_values else None,
        "max": max(display_fps_values) if display_fps_values else None,
    }


def detected_format(text: str, kind: str) -> str | None:
    match = re.search(rf"New incoming {kind} format detected: ([^\n]+)", text)
    return match.group(1) if match else None


def endpoint_metrics(label: str, path: Path, video_display: str) -> dict[str, Any]:
    text = load_runtime_text(path)

    return {
        "label": label,
        "path": str(path),
        "audioFormat": detected_format(text, "audio"),
        "videoFormat": detected_format(text, "video"),
        "packetTotals": packet_totals_from_text(text),
        "audioDecode": audio_decode_from_text(text),
        "videoDecode": video_decode_from_text(text),
        "displayFps": display_fps_from_text(text, video_display),
    }


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def require_endpoint_health(endpoints: EndpointMap) -> list[str]:
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


def min_packet_percent(endpoints: EndpointMap, prefix: str) -> float:
    return min(
        float(totals["minPercent"])
        for label, metrics in endpoints.items()
        if label.startswith(prefix)
        for totals in metrics["packetTotals"].values()
    )


def audio_losses(endpoints: EndpointMap, prefix: str) -> int:
    return sum(
        int(metrics["audioDecode"]["lostFrames"])
        for label, metrics in endpoints.items()
        if label.startswith(prefix) and metrics["audioDecode"]
    )


def video_losses(endpoints: EndpointMap, prefix: str) -> int:
    return sum(
        int(metrics["videoDecode"]["dropped"]) + int(metrics["videoDecode"]["missed"])
        for label, metrics in endpoints.items()
        if label.startswith(prefix) and metrics["videoDecode"]
    )


def min_display_fps(endpoints: EndpointMap, prefix: str) -> float:
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


def endpoint_metric_map(args: argparse.Namespace) -> EndpointMap:
    return {
        label: endpoint_metrics(label, Path(path), args.video_display)
        for label, path in zip(args.endpoint[0::2], args.endpoint[1::2])
    }


def managed_connection_metrics(args: argparse.Namespace) -> tuple[Path, dict[str, Any], Any]:
    path = Path(args.managed_connection_metrics)
    metrics = json.loads(path.read_text(encoding="utf-8"))
    return path, metrics, metrics.get("audioVideoConnectionMs")


def parity_errors(
    args: argparse.Namespace,
    endpoints: EndpointMap,
    managed_metrics: dict[str, Any],
    managed_connection_ms: Any,
) -> list[str]:
    comparison = comparison_values(args, endpoints, managed_connection_ms)

    errors: list[str] = []
    require(
        comparison["comparisons"]["managedPacketReceiptNoWorseThanDirect"],
        f"managed packet receipt is worse than {args.direct_label}",
        errors,
    )
    require(
        comparison["comparisons"]["managedAudioDecodeNoWorseThanDirect"],
        f"managed audio decode losses are worse than {args.direct_label}",
        errors,
    )
    require(
        comparison["comparisons"]["managedVideoDecodeNoWorseThanDirect"],
        f"managed video decode losses are worse than {args.direct_label}",
        errors,
    )
    require(comparison["audioFormatsMatch"], "direct and managed audio formats differ", errors)
    require(comparison["videoFormatsMatch"], "direct and managed video formats differ", errors)
    require(args.direct_connection_ms > 0, "direct connection timing was not measured", errors)
    require(
        managed_metrics.get("connected") is True,
        "managed connection timing did not reach audio and video",
        errors,
    )
    require(isinstance(managed_connection_ms, int), "managed connection timing is missing", errors)
    require(
        comparison["comparisons"]["managedConnectionSetupWithinDelta"],
        "managed connection setup is slower than direct by more than "
        f"{args.max_managed_connection_delta_ms} ms",
        errors,
    )
    require(
        comparison["comparisons"]["managedDisplayFpsWithinDelta"],
        "managed display FPS is lower than direct by more than "
        f"{args.max_managed_display_fps_delta}",
        errors,
    )
    return errors


def build_report(
    args: argparse.Namespace,
    endpoints: EndpointMap,
    managed_connection_metrics_path: Path,
    managed_connection_ms: Any,
    errors: list[str],
) -> dict[str, Any]:
    endpoint_health_errors = require_endpoint_health(endpoints)
    direct_endpoint_health_errors = [
        error for error in endpoint_health_errors if error.startswith("direct-")
    ]
    managed_endpoint_health_errors = [
        error for error in endpoint_health_errors if error.startswith("managed-")
    ]
    comparison = comparison_values(args, endpoints, managed_connection_ms)
    report: dict[str, Any] = {
        "schema": args.schema,
        "verdict": "PARTIAL",
        "scope": args.scope,
        "evidenceBoundary": args.evidence_boundary,
        "comparisons": comparison["comparisons"],
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
            "managedMinusDirectMs": comparison["connectionDeltaMs"],
            "maxManagedConnectionDeltaMs": args.max_managed_connection_delta_ms,
            "connectionPollSeconds": args.connection_poll_seconds,
            "managedMetricsPath": str(managed_connection_metrics_path),
        },
        "displaySmoothness": {
            "directMinDisplayFps": comparison["directMinDisplayFps"],
            "managedMinDisplayFps": comparison["managedMinDisplayFps"],
            "directMinusManagedFps": comparison["displayFpsDelta"],
            "maxManagedDisplayFpsDelta": args.max_managed_display_fps_delta,
            "displayDevice": args.video_display,
        },
        "endpoints": endpoints,
        "errors": errors,
    }
    if args.preflight_report:
        report["preflightReport"] = args.preflight_report
    return report


def comparison_values(args: argparse.Namespace, endpoints: EndpointMap, managed_connection_ms: Any) -> dict[str, Any]:
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
    return {
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
        "audioFormatsMatch": len(audio_formats) == 1,
        "videoFormatsMatch": len(video_formats) == 1,
        "connectionDeltaMs": connection_delta_ms,
        "directMinDisplayFps": direct_min_display_fps,
        "managedMinDisplayFps": managed_min_display_fps,
        "displayFpsDelta": display_fps_delta,
    }


def main() -> int:
    args = parse_args()
    if len(args.endpoint) % 2 != 0:
        print("endpoint arguments must be label/path pairs", file=sys.stderr)
        return 2

    managed_metrics_path, managed_metrics, managed_connection_ms = managed_connection_metrics(args)
    endpoints = endpoint_metric_map(args)
    errors = parity_errors(args, endpoints, managed_metrics, managed_connection_ms)
    report = build_report(args, endpoints, managed_metrics_path, managed_connection_ms, errors)

    Path(args.report).write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
