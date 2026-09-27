#!/usr/bin/env python3
"""Validate the PMR-14 runtime fields in an external proof bundle."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any, NoReturn, cast

JsonObject = dict[str, Any]


def fail(message: str) -> NoReturn:
    """Stop at the first contract mismatch with the historical diagnostic."""
    print(message, file=sys.stderr)
    raise SystemExit(1)


def load(path: Path) -> JsonObject:
    """Load one JSON report object."""
    with path.open(encoding="utf-8") as handle:
        value: object = json.load(handle)
    if not isinstance(value, dict):
        fail(f"{path} must contain a JSON object")
    return cast(JsonObject, value)


def require_positive(value: object, label: str) -> None:
    """Require a positive integer metric."""
    if not isinstance(value, int) or value <= 0:
        fail(f"{label} must be > 0")


def require_zero(value: object, label: str) -> None:
    """Require an integer metric with no recorded failures."""
    if not isinstance(value, int) or value != 0:
        fail(f"{label} must be 0")


def require_non_empty(value: object, label: str) -> None:
    """Require a non-empty string evidence field."""
    if not isinstance(value, str) or not value:
        fail(f"{label} must be non-empty")


def require_artifact(artifact: object, label: str) -> None:
    """Require a captured artifact descriptor."""
    if not isinstance(artifact, dict):
        fail(f"{label} must be present")
    require_non_empty(artifact.get("path"), f"{label}.path")
    if artifact.get("captured") is not True:
        fail(f"{label}.captured must be true")


def validate_rx_report_evidence(report: JsonObject) -> None:
    """Validate the physical RX-buffer result and its direct profile."""
    label = "pmr-14/rx-buffer-benchmark.json"
    if report.get("verdict") != "pass":
        fail(f"{label} verdict must be pass")
    if report.get("evidenceKind") != "physicalReferenceRig":
        fail(f"{label} evidenceKind must be physicalReferenceRig")
    rows = report.get("rows")
    if not isinstance(rows, list) or not rows:
        fail(f"{label} rows must be non-empty")
    if any(not isinstance(row, dict) or row.get("physicalEvidence") is not True for row in rows):
        fail(f"{label} rows must all have physicalEvidence: true")
    direct_rows = [row for row in rows if isinstance(row, dict) and row.get("profile") == "direct"]
    if not direct_rows:
        fail(f"{label} must include a direct RX profile row")
    if direct_rows[0].get("fastestPassEligible") is not True:
        fail(f"{label} direct row fastestPassEligible must be true")


def validate_drift_timing_evidence(report: JsonObject) -> None:
    """Validate measured drift/PLC timing and like-for-like baseline evidence."""
    label = "pmr-14/drift-plc-certification.json"
    if report.get("verdict") != "pass":
        fail(f"{label} verdict must be pass")
    if report.get("runMode") != "measured":
        fail(f"{label} runMode must be measured")
    if not report.get("runArtifactPath"):
        fail(f"{label} runArtifactPath must be non-empty")
    baseline = report.get("lolaBaselineComparison") or {}
    if not isinstance(baseline, dict) or baseline.get("availability") != "measured":
        fail(f"{label} lolaBaselineComparison.availability must be measured")
    if baseline.get("measuredOnSameHardwareAndRoute") is not True:
        fail(f"{label} lolaBaselineComparison.measuredOnSameHardwareAndRoute must be true")
    if baseline.get("result") not in {"openLolaFaster", "openLolaEquivalent"}:
        fail(f"{label} lolaBaselineComparison.result must be openLolaFaster or openLolaEquivalent")


def validate_direct_peer_evidence(report: JsonObject) -> None:
    """Validate the external two-peer identity and captured artifacts."""
    label = "pmr-14/direct-p2p-session.json"
    if report.get("verdict") != "pass":
        fail(f"{label} verdict must be pass")
    measured = report.get("measuredEvidence") or {}
    if not isinstance(measured, dict) or measured.get("kind") != "physicalTwoPeerMacs":
        fail(f"{label} measuredEvidence.kind must be physicalTwoPeerMacs")
    require_non_empty(measured.get("packetCapturePath"), f"{label} measuredEvidence.packetCapturePath")
    require_artifact(measured.get("packetCapture"), f"{label} measuredEvidence.packetCapture")
    dscp = measured.get("dscp") or {}
    require_artifact(
        dscp.get("artifact") if isinstance(dscp, dict) else None,
        f"{label} measuredEvidence.dscp.artifact",
    )
    clock = measured.get("clock") or {}
    require_artifact(
        clock.get("artifact") if isinstance(clock, dict) else None,
        f"{label} measuredEvidence.clock.artifact",
    )


def validate_direct_peer_runtime_metrics(report: JsonObject) -> None:
    """Validate packet, playout, and callback counters for the direct-peer run."""
    label = "pmr-14/direct-p2p-session.json"
    metrics = report.get("metrics") or {}
    if not isinstance(metrics, dict):
        metrics = {}
    for field in ("packetsSent", "packetsReceived", "audioPacketsRouted"):
        require_positive(metrics.get(field), f"{label} metrics.{field}")
    for field in ("packetsLost", "recoveryEvents", "audioPayloadsSentOnControlChannel"):
        require_zero(metrics.get(field), f"{label} metrics.{field}")
    for field in ("remotePacketsLost", "remoteLatePackets", "remoteUnderruns", "remoteOverruns"):
        if metrics.get(field) is not None:
            require_zero(metrics.get(field), f"{label} metrics.{field}")

    av_runtime = report.get("avRuntime") or {}
    runtime_metrics = av_runtime.get("runtimeMetrics") or {} if isinstance(av_runtime, dict) else {}
    if not isinstance(runtime_metrics, dict):
        runtime_metrics = {}
    for field in ("audioPayloadsSent", "audioPayloadsQueuedForPlayout"):
        require_positive(runtime_metrics.get(field), f"{label} avRuntime.runtimeMetrics.{field}")
    for field in (
        "audioPayloadsDroppedBeforeSend",
        "audioPayloadsDroppedBeforePlayout",
        "audioPayloadsDroppedByPlayoutQueue",
        "audioPlayoutUnderruns",
        "audioCallbackDeadlineMisses",
        "audioCallbackOverruns",
    ):
        require_zero(runtime_metrics.get(field), f"{label} avRuntime.runtimeMetrics.{field}")


def main(arguments: list[str]) -> int:
    """Load the three reports and preserve their historical validation order."""
    if len(arguments) != 3:
        print(
            "usage: verify_pmr14_runtime_contract.py RX_REPORT DRIFT_REPORT P2P_REPORT",
            file=sys.stderr,
        )
        return 2
    rx_report, drift_report, p2p_report = (load(Path(argument)) for argument in arguments)
    validate_rx_report_evidence(rx_report)
    validate_drift_timing_evidence(drift_report)
    validate_direct_peer_evidence(p2p_report)
    validate_direct_peer_runtime_metrics(p2p_report)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
