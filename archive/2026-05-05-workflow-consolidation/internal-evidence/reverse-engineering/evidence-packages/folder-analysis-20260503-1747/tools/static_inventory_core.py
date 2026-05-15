#!/usr/bin/env python3
"""Static inventory builder for the LoLa v2.0 Windows artifact folder."""

from __future__ import annotations

import hashlib
import re
import subprocess
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import lief


ROOT = Path(__file__).resolve().parents[4]
TARGET = ROOT / "win-compiled" / "2-0"
OUT = ROOT / "reverse-engineering" / "evidence-packages" / "folder-analysis-20260503-1747"
DATA_DIR = OUT / "data"

INTEREST_PATTERNS: dict[str, tuple[str, ...]] = {
    "identity": ("lola", "tartini", "garr", "conts.it", "official release", "beta"),
    "audio": (
        "asio",
        "audio",
        "portaudio",
        "pa_",
        "44100",
        "48000",
        "sample",
        "buffer",
        "remoteaudio",
        "audioport",
        "wav",
    ),
    "video": (
        "video",
        "camera",
        "ximea",
        "xiapi",
        "ptgrey",
        "frame",
        "fps",
        "rgb24",
        "mono8",
        "bayer",
        "preview",
        "dib",
        "opencv",
        "cvtcolor",
        "resize",
    ),
    "codec": (
        "jpeg",
        "m-jpeg",
        "gpujpeg",
        "cuda",
        "compression",
        "compress",
        "decompress",
        "quality",
        "ijg",
    ),
    "network": (
        "pcap",
        "winpcap",
        "udp",
        "socket",
        "sendto",
        "recvfrom",
        "packet",
        "srcip",
        "dstip",
        "audioport",
        "videoport",
        "socketport",
        "rpcap",
    ),
    "session": (
        "/mesg_",
        "quickconn",
        "reject",
        "disconnect",
        "chat",
        "sid",
        "txt:",
        "checklolastatus",
        "send_audio_signal",
        "stop_audio_signal",
    ),
    "timing": (
        "latency",
        "delay",
        "sync",
        "timestamp",
        "timebeginperiod",
        "timegettime",
        "dropped",
        "incomplete",
        "realigned",
        "queue",
        "ring",
        "threshold",
    ),
    "config": (
        ".ini",
        "inputaudiodevname",
        "outputaudiodevname",
        "lolariority",
        "lolapriority",
        "videopacketsize",
        "rxpacketfiltering",
        "wpcap_setmintocopy",
        "ximeacolors.ini",
        "camerafiles",
    ),
    "licensing_or_identity_surface": (
        "serial",
        "activation",
        "registry",
        "processorname",
        "bios",
        "mainboard",
        "license",
    ),
}

SECRET_VALUE_RE = re.compile(
    r"(?i)(password|passwd|secret|token|api[_-]?key|private[_-]?key|credential)"
    r"\\s*[:=]\\s*[^;\\s]+"
)

RUNTIME_LIB_PREFIXES = (
    "mfc",
    "msvc",
    "vcruntime",
    "concrt",
    "api-ms-win-crt",
)


@dataclass(frozen=True)
class ToolResult:
    ok: bool
    stdout: str
    stderr: str


def run_tool(args: list[str], timeout: int = 60) -> ToolResult:
    try:
        completed = subprocess.run(
            args,
            cwd=ROOT,
            check=False,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        return ToolResult(
            ok=completed.returncode == 0,
            stdout=completed.stdout.strip(),
            stderr=completed.stderr.strip(),
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        return ToolResult(ok=False, stdout="", stderr=str(exc))


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def file_type(path: Path) -> str:
    result = run_tool(["file", rel(path)])
    return result.stdout.split(": ", 1)[1] if ": " in result.stdout else result.stdout


def extract_strings(path: Path) -> list[str]:
    if path.stat().st_size > 120_000_000:
        return []
    result = run_tool(["strings", "-a", "-n", "4", rel(path)], timeout=90)
    if result.ok or result.stdout:
        return [line.strip() for line in result.stdout.splitlines() if line.strip()]
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except UnicodeDecodeError:
        return []
    return [line.strip() for line in text.splitlines() if line.strip()]


def redact_secret_values(text: str) -> str:
    return SECRET_VALUE_RE.sub(lambda match: match.group(1) + "=<redacted>", text)


def string_hits(strings: list[str], limit_per_group: int = 35) -> dict[str, list[str]]:
    grouped: dict[str, list[str]] = {key: [] for key in INTEREST_PATTERNS}
    seen: dict[str, set[str]] = {key: set() for key in INTEREST_PATTERNS}
    for value in strings:
        clean = redact_secret_values(value)
        lower = clean.lower()
        for group, needles in INTEREST_PATTERNS.items():
            if any(needle in lower for needle in needles):
                if clean not in seen[group] and len(grouped[group]) < limit_per_group:
                    grouped[group].append(clean)
                    seen[group].add(clean)
    return {key: values for key, values in grouped.items() if values}


def parse_lief(path: Path) -> dict[str, Any]:
    out: dict[str, Any] = {
        "format": None,
        "architecture": "not applicable",
        "imports": {},
        "exports": [],
        "linked_libraries": [],
        "resources": {},
        "function_count": None,
        "parse_error": None,
    }
    try:
        binary = lief.parse(str(path))
    except Exception as exc:  # noqa: BLE001 - third-party parser has mixed errors.
        out["parse_error"] = str(exc)
        return out
    if binary is None:
        out["parse_error"] = "not parsed by LIEF"
        return out

    out["format"] = str(binary.format).replace("FORMATS.", "")
    if hasattr(binary, "header") and hasattr(binary.header, "machine"):
        out["architecture"] = str(binary.header.machine).replace("MACHINE_TYPES.", "")
    elif hasattr(binary, "header") and hasattr(binary.header, "cpu_type"):
        out["architecture"] = str(binary.header.cpu_type)

    if hasattr(binary, "functions"):
        try:
            out["function_count"] = len(list(binary.functions))
        except Exception:  # noqa: BLE001
            out["function_count"] = None

    if hasattr(binary, "imports"):
        imports: dict[str, list[str]] = {}
        libs: list[str] = []
        for imported_library in list(binary.imports):
            lib_name = imported_library.name
            libs.append(lib_name)
            names: list[str] = []
            for entry in list(imported_library.entries):
                name = entry.name if entry.name else f"Ordinal_{entry.ordinal}"
                names.append(name)
            imports[lib_name] = names
        out["imports"] = imports
        out["linked_libraries"] = libs
    elif hasattr(binary, "libraries"):
        out["linked_libraries"] = [str(lib) for lib in list(binary.libraries)]

    if hasattr(binary, "exported_functions"):
        out["exports"] = [
            function.name
            for function in list(binary.exported_functions)
            if getattr(function, "name", "")
        ]

    if getattr(binary, "has_resources", False):
        manager = binary.resources_manager
        resources: dict[str, Any] = {
            "types": [],
            "has_manifest": bool(getattr(manager, "has_manifest", False)),
            "icon_count": 0,
            "dialog_count": 0,
            "string_table_count": 0,
            "has_version": bool(getattr(manager, "has_version", False)),
        }
        try:
            resources["types"] = [
                str(resource_type).replace("TYPE.", "")
                for resource_type in list(manager.types)
            ]
        except Exception:  # noqa: BLE001
            pass
        for key, has_attr, value_attr in (
            ("icon_count", "has_icons", "icons"),
            ("dialog_count", "has_dialogs", "dialogs"),
            ("string_table_count", "has_string_table", "string_table"),
        ):
            try:
                if getattr(manager, has_attr):
                    resources[key] = len(list(getattr(manager, value_attr)))
            except Exception:  # noqa: BLE001
                resources[key] = "unreadable"
        out["resources"] = resources

    return out


def role_for(path: Path, metadata: dict[str, Any], hits: dict[str, list[str]]) -> tuple[str, str]:
    name = path.name.lower()
    relpath = rel(path).lower()
    libs = {lib.lower() for lib in metadata.get("linked_libraries", [])}
    exports = {export.lower() for export in metadata.get("exports", [])}

    if name == ".ds_store":
        return ("macOS Finder metadata; no LoLa runtime role", "high")
    if name == "lolagui_ximea_x64.exe":
        return ("primary v2.0 LoLa GUI/runtime for live audio, XIMEA video, session control, and WinPcap media transport", "high")
    if name == "lolagui_tester_x64.exe":
        return ("LoLa tester/support GUI for network/session testing; not the main production GUI", "high")
    if name == "lolavideoconverter_x64.exe":
        return ("offline video conversion helper using OpenCV/IJG surfaces; not a live TX/RX participant", "high")
    if name == "lolawavsplitter_x64.exe":
        return ("offline WAV split/conversion helper; not a live TX/RX participant", "high")
    if "winpcap" in relpath:
        return ("WinPcap installer payload needed by raw packet capture/sendqueue transport", "high")
    if "ximea_api_installer" in name:
        return ("XIMEA SDK/API installer payload for camera runtime support", "high")
    if name == "portaudio_x64.dll":
        return ("PortAudio runtime used for ASIO/audio device enumeration and stream I/O", "high")
    if name == "xiapi64.dll":
        return ("XIMEA camera SDK runtime; large exported camera-control and frame-acquisition surface", "high")
    if name == "gpujpeg.dll":
        return ("GPUJPEG codec runtime present in the package; exports CUDA JPEG encode/decode API", "high")
    if name == "cudart64_55.dll":
        return ("CUDA 5.5 runtime dependency for GPUJPEG lineage", "high")
    if name == "jpeg62.dll":
        return ("IJG/libjpeg codec runtime used by CPU MJPEG and helper conversion paths", "high")
    if name.startswith("opencv_"):
        return ("OpenCV 2.4.9 image processing/display/runtime dependency", "high")
    if name in {"ximea.ini", "ptgrey.ini"}:
        return ("camera model/profile table with resolution, pixel format, and FPS presets", "high")
    if name == "ximeacolors.ini":
        return ("XIMEA color-correction defaults consumed by the main GUI", "high")
    if name.startswith(RUNTIME_LIB_PREFIXES):
        return ("Microsoft Visual C++/MFC runtime dependency", "high")
    if name.endswith(".dll") and exports:
        return ("third-party/runtime DLL with exported API surface", "medium")
    if name.endswith(".exe"):
        if {"wpcap.dll"} & libs:
            return ("Windows executable with WinPcap network surface; exact operator role inferred from strings/imports", "medium")
        return ("Windows executable/helper; role inferred from name and static strings", "medium")
    if hits:
        return ("configuration/resource artifact with LoLa-relevant strings", "medium")
    return ("support artifact; no AV/network role found in static pass", "medium")


def next_step_for(path: Path, metadata: dict[str, Any], role: str) -> str:
    name = path.name.lower()
    libs = {lib.lower() for lib in metadata.get("linked_libraries", [])}
    if name == "lolagui_ximea_x64.exe":
        return "Run controlled Windows lab validation with XIMEA/ASIO peer and packet capture; do not execute on this Mac."
    if name == "lolagui_tester_x64.exe":
        return "Validate tester message behavior only in an isolated Windows lab with no production network."
    if name in {"lolavideoconverter_x64.exe", "lolawavsplitter_x64.exe"}:
        return "Feed known sample files in an isolated Windows VM to confirm helper-only behavior."
    if name == "gpujpeg.dll":
        return "Confirm whether any v2.0 process loads this dynamically; static main import table does not."
    if name == "xiapi64.dll":
        return "Validate camera API calls against supported XIMEA hardware in lab runtime."
    if name == "portaudio_x64.dll":
        return "Validate ASIO buffer-size behavior with target audio hardware."
    if "installer" in role.lower() or "setup" in rel(path).lower():
        return "Extract installer offline with NSIS-aware tooling such as 7-Zip or innounp; do not run installer."
    if "camera model/profile" in role.lower():
        return "Map profiles to actual camera hardware modes and confirm selected runtime profile."
    if "wpcap.dll" in libs:
        return "Inspect packet grammar with Ghidra/xrefs and later with isolated capture."
    return "No immediate validation unless this artifact becomes part of a live runtime path."


def confidence_level(role_confidence: str, metadata: dict[str, Any], hits: dict[str, list[str]]) -> str:
    if role_confidence == "high":
        return "high"
    if metadata.get("linked_libraries") or metadata.get("exports") or hits:
        return "medium"
    return "low"


def summarize_resources(resources: dict[str, Any]) -> str:
    if not resources:
        return "none observed"
    parts = []
    if resources.get("types"):
        parts.append("types=" + ",".join(resources["types"]))
    for key in ("icon_count", "dialog_count", "string_table_count"):
        value = resources.get(key)
        if value:
            parts.append(f"{key}={value}")
    if resources.get("has_manifest"):
        parts.append("manifest")
    if resources.get("has_version"):
        parts.append("version")
    return "; ".join(parts) if parts else "resources parsed, no notable entries"


def make_artifact(path: Path) -> dict[str, Any]:
    metadata = parse_lief(path)
    strings = extract_strings(path)
    hits = string_hits(strings)
    role, role_conf = role_for(path, metadata, hits)
    return {
        "path": rel(path),
        "size": path.stat().st_size,
        "sha256": sha256(path),
        "file_type": file_type(path),
        "architecture": metadata.get("architecture") or "not applicable",
        "binary_format": metadata.get("format"),
        "imports": metadata.get("imports", {}),
        "exports": metadata.get("exports", []),
        "linked_libraries": metadata.get("linked_libraries", []),
        "resources": metadata.get("resources", {}),
        "function_count": metadata.get("function_count"),
        "strings_of_interest": hits,
        "likely_role": role,
        "confidence": confidence_level(role_conf, metadata, hits),
        "next_validation_step": next_step_for(path, metadata, role),
        "parse_error": metadata.get("parse_error"),
    }


def role_counts(artifacts: list[dict[str, Any]]) -> dict[str, int]:
    counts: Counter[str] = Counter()
    for item in artifacts:
        file_type = item["file_type"].lower()
        path = item["path"].lower()
        if path.endswith(".exe") and "installer" not in file_type:
            counts["exe"] += 1
        elif path.endswith(".dll"):
            counts["dll"] += 1
        elif "installer" in file_type:
            counts["installer"] += 1
        elif path.endswith(".ini"):
            counts["config"] += 1
        elif path.endswith(".ds_store"):
            counts["metadata"] += 1
        else:
            counts["other"] += 1
    return dict(counts)


def markdown_table_value(value: str, max_len: int = 90) -> str:
    escaped = value.replace("|", "\\|").replace("\n", " ")
    if len(escaped) > max_len:
        return escaped[: max_len - 4] + " ..."
    return escaped


def library_summary(artifact: dict[str, Any]) -> str:
    libs = artifact["linked_libraries"]
    return ", ".join(libs[:10]) + (f", ... +{len(libs) - 10}" if len(libs) > 10 else "")


def export_summary(artifact: dict[str, Any]) -> str:
    exports = artifact["exports"]
    if not exports:
        return "none"
    return ", ".join(exports[:8]) + (f", ... +{len(exports) - 8}" if len(exports) > 8 else "")


def string_summary(artifact: dict[str, Any]) -> str:
    groups = artifact["strings_of_interest"]
    if not groups:
        return "none selected"
    return "; ".join(f"{key}: {len(values)}" for key, values in groups.items())
