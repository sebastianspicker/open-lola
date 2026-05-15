from __future__ import annotations

from typing import Any

from static_inventory_core import (
    OUT,
    export_summary,
    library_summary,
    markdown_table_value,
    string_summary,
    summarize_resources,
)

def write_inventory(artifacts: list[dict[str, Any]]) -> None:
    lines = [
        "# Artifact Inventory",
        "",
        "Every file under `win-compiled/2-0` is represented here. Long import, export,",
        "resource, and string lists are preserved in `data/artifacts.json`; this table",
        "keeps the human review surface compact.",
        "",
        "| Path | Size | SHA256 | Type | Architecture | Libraries | Exports | Resources | Strings | Likely role | Confidence | Next validation |",
        "|---|---:|---|---|---|---|---|---|---|---|---|---|",
    ]
    for item in artifacts:
        lines.append(
            "| "
            + " | ".join(
                [
                    f"`{item['path']}`",
                    str(item["size"]),
                    f"`{item['sha256']}`",
                    markdown_table_value(item["file_type"]),
                    markdown_table_value(str(item["architecture"])),
                    markdown_table_value(library_summary(item)),
                    markdown_table_value(export_summary(item)),
                    markdown_table_value(summarize_resources(item["resources"])),
                    markdown_table_value(string_summary(item)),
                    markdown_table_value(item["likely_role"], 130),
                    item["confidence"],
                    markdown_table_value(item["next_validation_step"], 150),
                ]
            )
            + " |"
        )
    (OUT / "artifact-inventory.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_strings(artifacts: list[dict[str, Any]]) -> None:
    lines = [
        "# Strings Of Interest",
        "",
        "Filtered strings only. This file intentionally avoids full raw string dumps and",
        "redacts obvious secret-value patterns. No usable credential material was found",
        "in the filtered output.",
        "",
    ]
    for item in artifacts:
        if not item["strings_of_interest"]:
            continue
        lines.append(f"## `{item['path']}`")
        lines.append("")
        for group, values in item["strings_of_interest"].items():
            lines.append(f"### {group}")
            for value in values:
                lines.append(f"- `{value}`")
            lines.append("")
    (OUT / "strings-of-interest.md").write_text("\n".join(lines), encoding="utf-8")


def write_findings(artifacts: list[dict[str, Any]]) -> None:
    by_path = {item["path"]: item for item in artifacts}
    main = by_path["win-compiled/2-0/LolaGui_XIMEA_x64.exe"]
    tester = by_path["win-compiled/2-0/LolaGui_Tester/LolaGui_TESTER_x64.exe"]
    converter = by_path["win-compiled/2-0/LolaVideoConverter_x64.exe"]
    splitter = by_path["win-compiled/2-0/LolaWavSplitter_x64.exe"]

    main_libs = {lib.lower() for lib in main["linked_libraries"]}
    main_strings = {
        value
        for values in main["strings_of_interest"].values()
        for value in values
    }

    findings = [
        (
            "confirmed",
            "Primary v2.0 runtime identity",
            "`LolaGui_XIMEA_x64.exe` is the current v2.0 live GUI target: it is PE32+ x86-64, imports MFC140/VC runtime, PortAudio, WinPcap, XIMEA, OpenCV, IJG JPEG, GDI/DWrite/D2D, IP helper, and Winsock.",
            "High",
        ),
        (
            "confirmed",
            "Audio capture/playback surface",
            "Main imports include `portaudio_x64.dll` and strings include ASIO device errors, ASIO buffer-size warnings, audio input/output device keys, audio RX frame counters, local/remote WAV recording names, `44100`, and `48000`.",
            "High",
        ),
        (
            "confirmed",
            "Video capture/rendering surface",
            "Main imports include `xiapi64.dll`, `opencv_core249.dll`, `opencv_imgproc249.dll`, `opencv_highgui249.dll`, and GDI/D2D rendering libraries. Strings reference XIMEA initialization, camera preview, XimeaColors.ini, frame-ready events, and video recording.",
            "High",
        ),
        (
            "confirmed",
            "Network transport surface",
            "Main imports include `wpcap.dll`, `WS2_32.dll`, and `IPHLPAPI.DLL`; strings include BPF filter templates, WinPcap tuning keys, packet counters, audio/video ports, and `/MESG_*` session messages.",
            "High",
        ),
        (
            "observed",
            "Plaintext session/control message templates",
            "Strings include `/MESG_CHECKLOLASTATUS`, `/MESG_QUICKCONN`, `/MESG_REJECT`, `/MESG_DISCONNECT`, `/MESG_CHAT`, `SRCIP`, `DSTIP`, `SID`, and `TXT` templates.",
            "High",
        ),
        (
            "observed",
            "Default media/control port names",
            "Config strings include `socketport`, `audioport`, and `videoport`; prior canonical evidence pins defaults as control 7000, audio 19788, video 19798, but this package did not execute the INI loader.",
            "Medium",
        ),
        (
            "observed",
            "Camera profile payloads",
            "`CAMERAFILES/Ximea.ini` lists XIMEA xiQ/XiC and generic 60 FPS Mono8/RGB24 modes up to 2048x2048; `PtGrey.ini` lists FL3/GS3 and generic modes up to 120 FPS.",
            "High",
        ),
        (
            "confirmed",
            "GPUJPEG package presence",
            "`gpujpeg.dll` exports CUDA JPEG encode/decode APIs and links to `cudart64_55.dll`, but the primary v2.0 main GUI import table does not import `gpujpeg.dll`.",
            "High",
        ),
        (
            "inferred",
            "CPU MJPEG live path is stronger than v2.0 GPUJPEG path",
            "The main GUI imports `jpeg62.dll` and has strings for `M-JPEG (CPU)`, JPEG encoding/decoding, and optimization keys. GPUJPEG is present as a DLL but not statically linked by the main GUI.",
            "High",
        ),
        (
            "inferred",
            "WinPcap-centered low-latency design",
            "The primary GUI combines PortAudio callbacks, WinPcap send/sendqueue/receive functions, packet filters, audio/video dropped/incomplete counters, and buffer-tuning keys. This points to raw packetized low-latency transport rather than high-level media streaming.",
            "High",
        ),
        (
            "inferred",
            "Helpers are offline/support surfaces",
            f"`{converter['path']}` imports OpenCV/JPEG but no WinPcap, PortAudio, or XIMEA live stack; `{splitter['path']}` has WAV/file helper role; `{tester['path']}` has WinPcap/session surface but is labeled tester/support lineage.",
            "High",
        ),
        (
            "hypothesis",
            "PtGrey retained as configuration lineage",
            "`PtGrey.ini` is shipped, but the analyzed v2.0 XIMEA GUI import table does not expose a FlyCapture/PtGrey SDK DLL. PtGrey may be retained from older/alternate builds or dynamically routed elsewhere.",
            "Medium",
        ),
        (
            "requires validation",
            "Actual packet grammar and timing",
            "Static evidence confirms packet/session surfaces, but byte-for-byte audio/video payload grammar, loss behavior, drift handling, and hardware timing require isolated Windows runtime plus peer/hardware and packet capture.",
            "High",
        ),
    ]

    if "gpujpeg.dll" not in main_libs:
        findings.append(
            (
                "confirmed",
                "No static main-GUI GPUJPEG import",
                "`gpujpeg.dll` is not in the `LolaGui_XIMEA_x64.exe` linked-library list. Dynamic loading was not proven in this pass.",
                "High",
            )
        )
    if any("/MESG_QUICKCONN" in value for value in main_strings):
        findings.append(
            (
                "confirmed",
                "Quick connection carries A/V parameters",
                "`/MESG_QUICKCONN` string template embeds `SR`, `BPS`, `CHNLS`, `FPS`, `BPP`, `X`, `Y`, `COMP`, and `BAYER`, tying session setup directly to audio/video format negotiation.",
                "High",
            )
        )

    lines = [
        "# Findings",
        "",
        "| Classification | Finding | Evidence | Confidence |",
        "|---|---|---|---|",
    ]
    for classification, finding, evidence, confidence in findings:
        lines.append(
            f"| {classification} | {finding} | {markdown_table_value(evidence, 220)} | {confidence} |"
        )
    (OUT / "findings.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_av_analysis() -> None:
    lines = [
        "# AV TX/RX Focus Analysis",
        "",
        "## Audio",
        "",
        "- Classification: confirmed. `LolaGui_XIMEA_x64.exe` imports `portaudio_x64.dll` and contains ASIO setup/error strings, audio device keys, audio channel/sample-rate mismatch diagnostics, local/remote WAV recording names, and audio RX/drop/realign counters.",
        "- Classification: inferred. The design is callback/buffer oriented and prioritizes small ASIO buffers. The warning string explicitly says LoLa requires 32 or 64 sample audio-card buffers.",
        "- Classification: requires validation. Exact callback scheduling, clock source, underrun policy, and 44.1 kHz versus 48 kHz runtime selection need Windows hardware measurement.",
        "",
        "## Video",
        "",
        "- Classification: confirmed. The main GUI imports XIMEA (`xiGetImage`, `xiOpenDevice`, `xiStartAcquisition`, `xiSetParam*`), OpenCV 2.4.9, GDI/D2D/DWrite, and IJG JPEG.",
        "- Classification: observed. Camera profile files encode Mono8/RGB24 profiles, explicit resolutions, and high-FPS presets. `XimeaColors.ini` stores white-balance/color correction defaults.",
        "- Classification: inferred. The primary live v2.0 camera path is XIMEA capture -> local preview/frame buffers -> raw or CPU MJPEG video TX -> receive/decode/display/recording.",
        "- Classification: requires validation. Exact frame queue depth, drop policy, and camera timing require hardware execution.",
        "",
        "## Codecs",
        "",
        "- Classification: confirmed. CPU JPEG is active at package/import/string level through `jpeg62.dll` and `M-JPEG (CPU)` strings.",
        "- Classification: confirmed. GPUJPEG is present as a CUDA-backed DLL with exported encode/decode APIs.",
        "- Classification: inferred. GPUJPEG is not statically linked by the v2.0 main GUI, so it is likely retained package lineage or dynamically optional rather than the primary v2.0 live codec.",
        "",
        "## Network And Session",
        "",
        "- Classification: confirmed. The primary GUI links WinPcap and Winsock/IP Helper. It contains `pcap_sendpacket`, sendqueue, receive/filter functions, raw IP/UDP filter strings, ARP/ICMP support, and plaintext `/MESG_*` control templates.",
        "- Classification: observed. Session setup strings carry A/V format fields: sample rate, bits per sample, channels, FPS, bits per pixel, frame dimensions, compression, and Bayer flag.",
        "- Classification: inferred. Control/session messages appear separate from high-rate audio/video packet paths; media is packetized over WinPcap/raw UDP-like framing.",
        "- Classification: requires validation. No runtime packet capture was performed, so exact Ethernet/IP/UDP headers, payload grammar, sequencing, and retransmission/drop semantics remain unknown.",
        "",
        "## Low-Latency Design Hints",
        "",
        "- 32/64 sample ASIO buffer warning.",
        "- WinPcap `setmintocopy`, BPF filtering, and sendqueue usage.",
        "- Separate audio/video ports and explicit packet-size configuration.",
        "- Audio/video dropped/incomplete/realigned counters.",
        "- CPU MJPEG and raw video paths rather than general-purpose streaming protocols.",
    ]
    (OUT / "av-tx-rx-analysis.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_diagrams() -> None:
    lines = [
        "# Mermaid Diagrams",
        "",
        "## Module Dependency Graph",
        "",
        "```mermaid",
        "flowchart LR",
        "  Main[LolaGui_XIMEA_x64.exe]",
        "  Tester[LolaGui_TESTER_x64.exe]",
        "  Converter[LolaVideoConverter_x64.exe]",
        "  Splitter[LolaWavSplitter_x64.exe]",
        "  Main --> MFC140[mfc140/msvcp140/vcruntime140/concrt140]",
        "  Main --> PortAudio[portaudio_x64.dll]",
        "  Main --> WinPcap[WinPcap driver/runtime]",
        "  Main --> Ximea[xiapi64.dll]",
        "  Main --> OpenCV[opencv_core/imgproc/highgui249]",
        "  Main --> JPEG[jpeg62.dll]",
        "  Main --> GDI[GDI/D2D/DWrite]",
        "  Main --> Winsock[WS2_32/IPHLPAPI]",
        "  Tester --> MFC100[mfc100/msvcp100/msvcr100]",
        "  Tester --> WinPcap",
        "  Tester --> Winsock",
        "  Converter --> OpenCV",
        "  Converter --> JPEG",
        "  Splitter --> MFC100",
        "  GPUJPEG[gpujpeg.dll] --> CUDA[cudart64_55.dll]",
        "  Main -. not statically imported .-> GPUJPEG",
        "```",
        "",
        "## Suspected AV TX/RX Pipeline",
        "",
        "```mermaid",
        "flowchart LR",
        "  ASIO[ASIO device via PortAudio] --> AudioBuffers[small audio buffers / WAV record copies]",
        "  XimeaCam[XIMEA camera via xiapi64] --> FrameBuffers[frame buffers / preview]",
        "  FrameBuffers --> RawVideo[raw video path]",
        "  FrameBuffers --> CpuMjpeg[CPU MJPEG via jpeg62]",
        "  AudioBuffers --> AudioPackets[audio packet builder]",
        "  RawVideo --> VideoPackets[video packet builder]",
        "  CpuMjpeg --> VideoPackets",
        "  AudioPackets --> PcapTx[WinPcap sendpacket/sendqueue]",
        "  VideoPackets --> PcapTx",
        "  PcapRx[WinPcap pcap_next_ex/filter] --> Reassembly[fragment/reassembly buffers]",
        "  Reassembly --> RemoteAudio[remote audio ring/playback]",
        "  Reassembly --> Decode[raw copy or JPEG decode]",
        "  Decode --> Display[GDI/DIB/OpenCV display and recording]",
        "```",
        "",
        "## Suspected Network/Session Flow",
        "",
        "```mermaid",
        "sequenceDiagram",
        "  participant Local as Local LoLa GUI",
        "  participant Remote as Remote LoLa GUI",
        "  Local->>Remote: /MESG_CHECKLOLASTATUS SRCIP DSTIP SID",
        "  Remote-->>Local: /MESG_CHECKLOLASTATUS_ACK",
        "  Local->>Remote: /MESG_QUICKCONN SR BPS CHNLS FPS BPP X Y COMP BAYER",
        "  Remote-->>Local: /MESG_QUICKCONN_ACK or /MESG_REJECT TXT",
        "  Local->>Remote: WinPcap audio/video packets on media ports",
        "  Remote-->>Local: WinPcap audio/video packets on media ports",
        "  Local->>Remote: /MESG_CHAT or /MESG_DISCONNECT as control messages",
        "```",
    ]
    (OUT / "diagrams.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
