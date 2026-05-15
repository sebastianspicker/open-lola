from __future__ import annotations

import json
from datetime import datetime
from typing import Any

import lief

from static_inventory_core import DATA_DIR, OUT, TARGET, rel, role_counts, run_tool

def write_tool_evidence(artifacts: list[dict[str, Any]]) -> None:
    def version_line(args: list[str], fallback: str) -> str:
        result = run_tool(args)
        for source in (result.stdout, result.stderr):
            lines = source.splitlines()
            if lines:
                if "unknown flag" in lines[0].lower():
                    return fallback
                return lines[0]
        return fallback

    tools = {
        "file": version_line(["file", "--version"], "available"),
        "shasum": version_line(["shasum", "--version"], "available"),
        "strings": version_line(["strings", "--version"], "available"),
        "rabin2": version_line(["rabin2", "-v"], "available"),
        "python3": version_line(["python3", "--version"], "available"),
    }
    ghidra_files = sorted((OUT / "ghidra").glob("*.md"))
    java_home = run_tool(["/usr/libexec/java_home", "-V"])
    if ghidra_files:
        ghidra_status = (
            "rerun succeeded with OpenJDK 25 on the primary GUI and LoLa-owned helper/tester EXEs; "
            + "outputs: "
            + ", ".join(f"`ghidra/{path.name}`" for path in ghidra_files)
        )
    elif java_home.ok:
        ghidra_status = "Java runtime available; rerun pending"
    else:
        ghidra_status = "not rerun: `/usr/libexec/java_home -V` could not locate a Java runtime"

    skipped = [
        "No unknown binaries were executed.",
        "No network commands were run.",
        "No source code or binary patching was needed.",
        "No licensing, DRM, authentication, or access-control bypass was attempted.",
        "No usable credentials or secrets were extracted; secret-like value patterns are redacted in string output.",
        "Mach-O-specific tools (`otool`, `lipo`, `nm`, `codesign`, `spctl`) were not applied because this folder contains no Mach-O, `.dylib`, or framework binaries.",
        "`sqlite3` was not applied because no database file was found.",
        "Installer payloads were identified as NSIS PE files and analyzed statically; payload extraction should be done offline with NSIS-aware tools if needed.",
    ]

    lines = [
        "# Tool Evidence And Boundaries",
        "",
        f"- Generated: `{datetime.now().isoformat(timespec='seconds')}` local time.",
        f"- Target: `{rel(TARGET)}`",
        f"- File count: `{len(artifacts)}`",
        f"- Role counts: `{json.dumps(role_counts(artifacts), sort_keys=True)}`",
        "",
        "## Tools Used",
        "",
    ]
    for tool, version in tools.items():
        lines.append(f"- `{tool}`: {version}")
    lines.extend(
        [
            f"- `lief`: {lief.__version__}",
            f"- `Ghidra analyzeHeadless`: {ghidra_status}",
            "",
            "## Static Boundary",
            "",
        ]
    )
    for item in skipped:
        lines.append(f"- {item}")
    lines.extend(
        [
            "",
            "## Reproduction Commands",
            "",
            "```sh",
            "python3 reverse-engineering/evidence-packages/folder-analysis-20260503-1747/tools/static_inventory.py",
            "find win-compiled/2-0 -type f -print0 | xargs -0 file",
            "find win-compiled/2-0 -type f -print0 | xargs -0 shasum -a 256",
            "JAVA_HOME=/opt/homebrew/Cellar/openjdk/25.0.2/libexec/openjdk.jdk/Contents/Home /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp lola-folder-analysis-20260503-1747-main-jdk25 -import win-compiled/2-0/LolaGui_XIMEA_x64.exe -scriptPath /private/tmp/lola-ghidra-scripts -postScript LoLaStaticSummary.java reverse-engineering/evidence-packages/folder-analysis-20260503-1747/ghidra v2-main -postScript LoLaAudioDeepDive.java reverse-engineering/evidence-packages/folder-analysis-20260503-1747/ghidra v2-main -postScript LoLaVideoDeepDive.java reverse-engineering/evidence-packages/folder-analysis-20260503-1747/ghidra v2-main -postScript LoLaNetworkSessionDeepDive.java reverse-engineering/evidence-packages/folder-analysis-20260503-1747/ghidra v2-main -deleteProject",
            "JAVA_HOME=/opt/homebrew/Cellar/openjdk/25.0.2/libexec/openjdk.jdk/Contents/Home /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp lola-folder-analysis-20260503-1747-tester -import win-compiled/2-0/LolaGui_Tester/LolaGui_TESTER_x64.exe -scriptPath /private/tmp/lola-ghidra-scripts -postScript LoLaStaticSummary.java reverse-engineering/evidence-packages/folder-analysis-20260503-1747/ghidra v2-tester -deleteProject",
            "JAVA_HOME=/opt/homebrew/Cellar/openjdk/25.0.2/libexec/openjdk.jdk/Contents/Home /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp lola-folder-analysis-20260503-1747-video-converter -import win-compiled/2-0/LolaVideoConverter_x64.exe -scriptPath /private/tmp/lola-ghidra-scripts -postScript LoLaStaticSummary.java reverse-engineering/evidence-packages/folder-analysis-20260503-1747/ghidra v2-video-converter -deleteProject",
            "JAVA_HOME=/opt/homebrew/Cellar/openjdk/25.0.2/libexec/openjdk.jdk/Contents/Home /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp lola-folder-analysis-20260503-1747-wav-splitter -import win-compiled/2-0/LolaWavSplitter_x64.exe -scriptPath /private/tmp/lola-ghidra-scripts -postScript LoLaStaticSummary.java reverse-engineering/evidence-packages/folder-analysis-20260503-1747/ghidra v2-wav-splitter -deleteProject",
            "python3 reverse-engineering/evidence-packages/folder-analysis-20260503-1747/tools/compatibility_dossier.py",
            "```",
        ]
    )
    (OUT / "tool-evidence.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_summary(artifacts: list[dict[str, Any]]) -> None:
    by_path = {item["path"]: item for item in artifacts}
    total_size = sum(item["size"] for item in artifacts)
    counts = role_counts(artifacts)
    lines = [
        "# LoLa v2.0 Folder Static Reverse Engineering Package",
        "",
        "Date: 2026-05-03",
        "Package: `reverse-engineering/evidence-packages/folder-analysis-20260503-1747/`",
        "Target: `win-compiled/2-0`",
        "",
        "## Scope And Safety Boundary",
        "",
        "This is a static-only package. No Windows executable, DLL, installer, or helper was run. No network connection was made. No binary patching, source modification, licensing bypass, DRM bypass, authentication bypass, or credential extraction was performed.",
        "",
        "The folder is not a Git worktree in this environment, so verification is filesystem-based.",
        "",
        "## Package Contents",
        "",
        "- [artifact-inventory.md](artifact-inventory.md): per-file path, size, SHA256, type, architecture, imports, exports, linked libraries, resources, strings-of-interest count, role, confidence, and next validation step.",
        "- [strings-of-interest.md](strings-of-interest.md): filtered strings grouped by artifact and evidence category.",
        "- [findings.md](findings.md): classified findings using confirmed/observed/inferred/hypothesis/requires validation.",
        "- [av-tx-rx-analysis.md](av-tx-rx-analysis.md): focused audio/video/codec/network/timing analysis.",
        "- [diagrams.md](diagrams.md): Mermaid dependency, suspected AV pipeline, and suspected network/session flow diagrams.",
        "- [tool-evidence.md](tool-evidence.md): commands, tool versions, skipped tools, and static-analysis boundary.",
        "- [ghidra/](ghidra/): fresh headless Ghidra summaries for the primary v2.0 GUI plus the LoLa-owned tester, video converter, and WAV splitter EXEs; the main GUI also has focused audio, video, and network/session deep dives.",
        "- [data/artifacts.json](data/artifacts.json): machine-readable full inventory.",
        "- [data/strings-interest.json](data/strings-interest.json): machine-readable filtered string evidence.",
        "- [legacy-compatibility-mode/](legacy-compatibility-mode/): compatibility-focused addendum for LoLa 2.0 Windows Legacy Compatibility Mode.",
        "",
        "## Corpus Summary",
        "",
        f"- Files: `{len(artifacts)}`",
        f"- Total size: `{total_size}` bytes",
        f"- Role counts: `{json.dumps(counts, sort_keys=True)}`",
        "- Mach-O binaries/frameworks/plugins/databases discovered in this folder: `0`",
        "- Recognized installers: `WinPcap_4_1_3.exe`, `XIMEA_API_Installer.exe`",
        "",
        "## What Each EXE Likely Does",
        "",
        f"- `LolaGui_XIMEA_x64.exe`: {by_path['win-compiled/2-0/LolaGui_XIMEA_x64.exe']['likely_role']}.",
        f"- `LolaGui_Tester/LolaGui_TESTER_x64.exe`: {by_path['win-compiled/2-0/LolaGui_Tester/LolaGui_TESTER_x64.exe']['likely_role']}.",
        f"- `LolaVideoConverter_x64.exe`: {by_path['win-compiled/2-0/LolaVideoConverter_x64.exe']['likely_role']}.",
        f"- `LolaWavSplitter_x64.exe`: {by_path['win-compiled/2-0/LolaWavSplitter_x64.exe']['likely_role']}.",
        f"- `WinpcapSetup/WinPcap_4_1_3.exe`: {by_path['win-compiled/2-0/WinpcapSetup/WinPcap_4_1_3.exe']['likely_role']}.",
        f"- `XimeaSetup/XIMEA_API_Installer.exe`: {by_path['win-compiled/2-0/XimeaSetup/XIMEA_API_Installer.exe']['likely_role']}.",
        "",
        "## What Each Important DLL Likely Does",
        "",
        f"- `portaudio_x64.dll`: {by_path['win-compiled/2-0/portaudio_x64.dll']['likely_role']}.",
        f"- `xiapi64.dll`: {by_path['win-compiled/2-0/xiapi64.dll']['likely_role']}.",
        f"- `jpeg62.dll`: {by_path['win-compiled/2-0/jpeg62.dll']['likely_role']}.",
        f"- `gpujpeg.dll`: {by_path['win-compiled/2-0/gpujpeg.dll']['likely_role']}.",
        f"- `cudart64_55.dll`: {by_path['win-compiled/2-0/cudart64_55.dll']['likely_role']}.",
        "- `opencv_core249.dll`, `opencv_imgproc249.dll`, `opencv_highgui249.dll`: OpenCV 2.4.9 image processing/display/runtime dependencies.",
        "- `mfc100/msvcr100/msvcp100` and `mfc140/msvcp140/vcruntime140/concrt140`: Microsoft runtime support for older helper/tester lineage and the v2.0 main GUI.",
        "",
        "## Strongest AV TX/RX Findings",
        "",
        "- The main GUI combines PortAudio/ASIO audio, XIMEA video, WinPcap packet transport, and plaintext session/control messages in one x86-64 MFC executable.",
        "- The strings and imports show separate audio/video ports, audio/video packet/drop counters, BPF filtering, WinPcap sendqueue use, and audio buffer-size warnings around 32/64 sample buffers.",
        "- Static evidence points to a low-latency raw/packetized design rather than RTP/RTSP/WebRTC or a general-purpose streaming stack.",
        "",
        "## Strongest Codec Findings",
        "",
        "- CPU JPEG/MJPEG is strongly evidenced in v2.0 by `jpeg62.dll`, `M-JPEG (CPU)`, JPEG encode/decode strings, and conversion/recording helper surfaces.",
        "- GPUJPEG exists as a CUDA-backed DLL and exports encode/decode functions, but the v2.0 main GUI does not statically import `gpujpeg.dll`.",
        "",
        "## Strongest Network/Protocol Findings",
        "",
        "- WinPcap and Winsock/IP Helper are both present in the main GUI import set.",
        "- Session/control strings are plaintext `/MESG_*` templates carrying source/destination IPs, session ID, chat/reject text, and quick-connection A/V format fields.",
        "- Media packet format, sequencing, and loss behavior remain static-only unknowns.",
        "",
        "## Unknowns",
        "",
        "- Byte-for-byte media packet grammar.",
        "- Exact session state machine and UI transitions.",
        "- Runtime use of GPUJPEG, if any, through dynamic loading.",
        "- PtGrey runtime reachability in this XIMEA-labeled v2.0 GUI.",
        "- Real hardware timing, drift behavior, frame drop policy, and 44.1 kHz/48 kHz interop.",
        "- Installer payload internals, pending offline NSIS extraction.",
        "",
        "## Legacy Compatibility Mode Addendum",
        "",
        "The compatibility addendum classifies every artifact for LoLa 2.0 Windows",
        "Legacy Compatibility Mode and turns the static AV/session evidence into an",
        "implementation roadmap. Static analysis reaches a strong compatibility base,",
        "but byte-exact LoLa AV TX/RX remains `PARTIAL` until isolated Windows peer",
        "packet captures validate the remaining media payload fields.",
        "",
        "VERDICT: PARTIAL",
    ]
    (OUT / "README.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_json(artifacts: list[dict[str, Any]]) -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    (DATA_DIR / "artifacts.json").write_text(
        json.dumps(artifacts, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    strings = {
        item["path"]: item["strings_of_interest"]
        for item in artifacts
        if item["strings_of_interest"]
    }
    (DATA_DIR / "strings-interest.json").write_text(
        json.dumps(strings, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
