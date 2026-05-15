#!/usr/bin/env python3
"""Generate the LoLa 2.0 Legacy Compatibility Mode RE addendum.

The generator is intentionally static-only. It consumes the existing inventory
JSON and Ghidra markdown summaries produced for the timestamped package, then
writes a compatibility-focused dossier without executing target binaries.
"""

from __future__ import annotations

import json
from pathlib import Path


PACKAGE_DIR = Path(__file__).resolve().parents[1]
OUT_DIR = PACKAGE_DIR / "legacy-compatibility-mode"
DATA_DIR = OUT_DIR / "data"


def load_artifacts() -> list[dict[str, object]]:
    with (PACKAGE_DIR / "data" / "artifacts.json").open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, list):
        raise TypeError("artifacts.json must contain a list")
    return data


def string_counts(artifact: dict[str, object]) -> dict[str, int]:
    raw = artifact.get("strings_of_interest", {})
    if not isinstance(raw, dict):
        return {}
    return {
        str(category): len(values)
        for category, values in raw.items()
        if isinstance(values, list) and values
    }


def classify_artifact(path: str) -> dict[str, object]:
    lower = path.lower()

    if lower.endswith(".ds_store"):
        return {
            "tier": "metadata-only",
            "scope": "excluded",
            "compatibility_use": "Ignore for Legacy Compatibility Mode.",
            "decoded_static_status": "confirmed: no LoLa runtime role",
            "next_validation": "None.",
        }
    if lower.endswith(".ini"):
        if "camerafiles" in lower:
            use = "Parse as camera-profile input for mode, resolution, pixel format, and FPS compatibility."
        else:
            use = "Parse as XIMEA color-correction defaults."
        return {
            "tier": "profile-config",
            "scope": "include",
            "compatibility_use": use,
            "decoded_static_status": "confirmed: text configuration artifact",
            "next_validation": "Round-trip parser tests against every shipped line.",
        }
    if "winpcap_4_1_3.exe" in lower:
        return {
            "tier": "installer-dependency",
            "scope": "document only",
            "compatibility_use": "Defines legacy packet driver dependency; do not execute in this pass.",
            "decoded_static_status": "observed: NSIS installer payload",
            "next_validation": "Offline installer extraction only if dependency payload versions are needed.",
        }
    if "ximea_api_installer.exe" in lower:
        return {
            "tier": "installer-dependency",
            "scope": "document only",
            "compatibility_use": "Defines legacy camera SDK dependency; do not execute in this pass.",
            "decoded_static_status": "observed: NSIS installer payload",
            "next_validation": "Offline extraction only if SDK DLL provenance is needed.",
        }
    if lower.endswith("lolagui_ximea_x64.exe"):
        return {
            "tier": "protocol-critical",
            "scope": "include",
            "compatibility_use": (
                "Primary LoLa 2.0 peer corpus: session grammar, WinPcap packetization, "
                "audio TX/RX, XIMEA video TX/RX, CPU MJPEG, and timing/buffering hints."
            ),
            "decoded_static_status": "confirmed: live GUI/runtime participant",
            "next_validation": "Use isolated Windows peer captures to close byte-exact media packet grammar.",
        }
    if lower.endswith("lolagui_tester_x64.exe"):
        return {
            "tier": "support-protocol-corpus",
            "scope": "include after main",
            "compatibility_use": "Alternate tester/support GUI; useful for cross-checking session/control lineage.",
            "decoded_static_status": "observed: support GUI with LoLa session strings",
            "next_validation": "Compare tester sendqueue/JPEG xrefs against the main GUI when field names are recovered.",
        }
    if lower.endswith("lolavideoconverter_x64.exe"):
        return {
            "tier": "operator-helper",
            "scope": "document only",
            "compatibility_use": "Offline video conversion helper; confirms OpenCV/IJG media formats, not live TX/RX.",
            "decoded_static_status": "inferred: file conversion surface",
            "next_validation": "Use only as format reference for saved local/remote frames.",
        }
    if lower.endswith("lolawavsplitter_x64.exe"):
        return {
            "tier": "operator-helper",
            "scope": "document only",
            "compatibility_use": "Offline WAV helper; confirms PCM/WAV file workflow, not live TX/RX.",
            "decoded_static_status": "inferred: file helper surface",
            "next_validation": "Use only as WAV artifact reference if legacy recordings must be imported.",
        }
    if lower.endswith("portaudio_x64.dll"):
        return {
            "tier": "audio-io-critical",
            "scope": "include API surface",
            "compatibility_use": "Audio device and ASIO stream boundary; informs buffer-size and sample-rate behavior.",
            "decoded_static_status": "confirmed: PortAudio export/import surface",
            "next_validation": "Measure ASIO callback sizes with known 32/64 sample devices in a lab.",
        }
    if lower.endswith("xiapi64.dll"):
        return {
            "tier": "camera-io-critical",
            "scope": "include API surface",
            "compatibility_use": "XIMEA camera acquisition/control boundary; not a LoLa wire-protocol source.",
            "decoded_static_status": "confirmed: XIMEA SDK runtime",
            "next_validation": "Validate camera mode mapping against real XIMEA hardware.",
        }
    if lower.endswith("jpeg62.dll"):
        return {
            "tier": "codec-critical",
            "scope": "include API surface",
            "compatibility_use": "Mandatory CPU JPEG/MJPEG codec surface for compressed video compatibility.",
            "decoded_static_status": "confirmed: IJG/libjpeg runtime",
            "next_validation": "Create JPEG fixture tests for quality values 40..100.",
        }
    if lower.endswith("gpujpeg.dll"):
        return {
            "tier": "optional-codec-corpus",
            "scope": "document optional",
            "compatibility_use": "CUDA/GPUJPEG corpus present, but not statically linked by the main v2 GUI.",
            "decoded_static_status": "confirmed: DLL present; runtime reachability unproven",
            "next_validation": "Search dynamic-load paths or capture runtime DLL loads on isolated Windows.",
        }
    if lower.endswith("cudart64_55.dll"):
        return {
            "tier": "optional-codec-dependency",
            "scope": "document optional",
            "compatibility_use": "CUDA 5.5 dependency for GPUJPEG lineage.",
            "decoded_static_status": "confirmed: third-party runtime dependency",
            "next_validation": "Only needed if GPUJPEG runtime use is proven.",
        }
    if "opencv_" in lower:
        return {
            "tier": "media-runtime",
            "scope": "include API surface",
            "compatibility_use": "Image processing/display/file helper runtime; not the LoLa wire protocol itself.",
            "decoded_static_status": "confirmed: OpenCV 2.4.9 runtime dependency",
            "next_validation": "Map only used APIs in live GUI and helpers.",
        }
    runtime_names = (
        "mfc100.dll",
        "mfc140.dll",
        "msvcp100.dll",
        "msvcp140.dll",
        "msvcr100.dll",
        "vcruntime140.dll",
        "concrt140.dll",
    )
    if lower.endswith(runtime_names):
        return {
            "tier": "runtime-only",
            "scope": "exclude from protocol implementation",
            "compatibility_use": "Microsoft runtime support; ship or replace through native runtime choices, not protocol logic.",
            "decoded_static_status": "confirmed: support library",
            "next_validation": "None for LoLa packet compatibility.",
        }
    return {
        "tier": "unclassified",
        "scope": "review",
        "compatibility_use": "Review manually.",
        "decoded_static_status": "requires validation",
        "next_validation": "Inspect imports, exports, and string categories.",
    }


def compatibility_rows(artifacts: list[dict[str, object]]) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for artifact in artifacts:
        path = str(artifact["path"])
        classification = classify_artifact(path)
        counts = string_counts(artifact)
        rows.append(
            {
                "path": path,
                "size": artifact["size"],
                "sha256": artifact["sha256"],
                "file_type": artifact["file_type"],
                "architecture": artifact["architecture"],
                "tier": classification["tier"],
                "scope": classification["scope"],
                "compatibility_use": classification["compatibility_use"],
                "decoded_static_status": classification["decoded_static_status"],
                "next_validation": classification["next_validation"],
                "likely_role": artifact["likely_role"],
                "confidence": artifact["confidence"],
                "string_category_counts": counts,
                "linked_libraries": artifact.get("linked_libraries", []),
                "exports_sample": list(artifact.get("exports", []))[:20],
            }
        )
    return rows


def fmt_counts(counts: dict[str, int]) -> str:
    if not counts:
        return "none"
    return ", ".join(f"{key}={value}" for key, value in sorted(counts.items()))


def table_row(values: list[object]) -> str:
    escaped = []
    for value in values:
        text = str(value).replace("|", "\\|").replace("\n", " ")
        escaped.append(text)
    return "| " + " | ".join(escaped) + " |"
