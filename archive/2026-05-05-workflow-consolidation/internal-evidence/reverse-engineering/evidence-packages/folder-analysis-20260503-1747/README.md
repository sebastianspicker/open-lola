# LoLa v2.0 Folder Static Reverse Engineering Package

Date: 2026-05-03
Package: `reverse-engineering/evidence-packages/folder-analysis-20260503-1747/`
Target: `win-compiled/2-0`

## Scope And Safety Boundary

This is a static-only package. No Windows executable, DLL, installer, or helper was run. No network connection was made. No binary patching, source modification, licensing bypass, DRM bypass, authentication bypass, or credential extraction was performed.

The folder is not a Git worktree in this environment, so verification is filesystem-based.

## Package Contents

- [artifact-inventory.md](artifact-inventory.md): per-file path, size, SHA256, type, architecture, imports, exports, linked libraries, resources, strings-of-interest count, role, confidence, and next validation step.
- [strings-of-interest.md](strings-of-interest.md): filtered strings grouped by artifact and evidence category.
- [findings.md](findings.md): classified findings using confirmed/observed/inferred/hypothesis/requires validation.
- [av-tx-rx-analysis.md](av-tx-rx-analysis.md): focused audio/video/codec/network/timing analysis.
- [diagrams.md](diagrams.md): Mermaid dependency, suspected AV pipeline, and suspected network/session flow diagrams.
- [tool-evidence.md](tool-evidence.md): commands, tool versions, skipped tools, and static-analysis boundary.
- [ghidra/](ghidra/): fresh headless Ghidra summaries for the primary v2.0 GUI plus the LoLa-owned tester, video converter, and WAV splitter EXEs; the main GUI also has focused audio, video, and network/session deep dives.
- [data/artifacts.json](data/artifacts.json): machine-readable full inventory.
- [data/strings-interest.json](data/strings-interest.json): machine-readable filtered string evidence.
- [legacy-compatibility-mode/](legacy-compatibility-mode/): compatibility-focused addendum for LoLa 2.0 Windows Legacy Compatibility Mode.

## Corpus Summary

- Files: `29`
- Total size: `186738655` bytes
- Role counts: `{"config": 3, "dll": 19, "exe": 4, "installer": 2, "metadata": 1}`
- Mach-O binaries/frameworks/plugins/databases discovered in this folder: `0`
- Recognized installers: `WinPcap_4_1_3.exe`, `XIMEA_API_Installer.exe`

## What Each EXE Likely Does

- `LolaGui_XIMEA_x64.exe`: primary v2.0 LoLa GUI/runtime for live audio, XIMEA video, session control, and WinPcap media transport.
- `LolaGui_Tester/LolaGui_TESTER_x64.exe`: LoLa tester/support GUI for network/session testing; not the main production GUI.
- `LolaVideoConverter_x64.exe`: offline video conversion helper using OpenCV/IJG surfaces; not a live TX/RX participant.
- `LolaWavSplitter_x64.exe`: offline WAV split/conversion helper; not a live TX/RX participant.
- `WinpcapSetup/WinPcap_4_1_3.exe`: WinPcap installer payload needed by raw packet capture/sendqueue transport.
- `XimeaSetup/XIMEA_API_Installer.exe`: XIMEA SDK/API installer payload for camera runtime support.

## What Each Important DLL Likely Does

- `portaudio_x64.dll`: PortAudio runtime used for ASIO/audio device enumeration and stream I/O.
- `xiapi64.dll`: XIMEA camera SDK runtime; large exported camera-control and frame-acquisition surface.
- `jpeg62.dll`: IJG/libjpeg codec runtime used by CPU MJPEG and helper conversion paths.
- `gpujpeg.dll`: GPUJPEG codec runtime present in the package; exports CUDA JPEG encode/decode API.
- `cudart64_55.dll`: CUDA 5.5 runtime dependency for GPUJPEG lineage.
- `opencv_core249.dll`, `opencv_imgproc249.dll`, `opencv_highgui249.dll`: OpenCV 2.4.9 image processing/display/runtime dependencies.
- `mfc100/msvcr100/msvcp100` and `mfc140/msvcp140/vcruntime140/concrt140`: Microsoft runtime support for older helper/tester lineage and the v2.0 main GUI.

## Strongest AV TX/RX Findings

- The main GUI combines PortAudio/ASIO audio, XIMEA video, WinPcap packet transport, and plaintext session/control messages in one x86-64 MFC executable.
- The strings and imports show separate audio/video ports, audio/video packet/drop counters, BPF filtering, WinPcap sendqueue use, and audio buffer-size warnings around 32/64 sample buffers.
- Static evidence points to a low-latency raw/packetized design rather than RTP/RTSP/WebRTC or a general-purpose streaming stack.

## Strongest Codec Findings

- CPU JPEG/MJPEG is strongly evidenced in v2.0 by `jpeg62.dll`, `M-JPEG (CPU)`, JPEG encode/decode strings, and conversion/recording helper surfaces.
- GPUJPEG exists as a CUDA-backed DLL and exports encode/decode functions, but the v2.0 main GUI does not statically import `gpujpeg.dll`.

## Strongest Network/Protocol Findings

- WinPcap and Winsock/IP Helper are both present in the main GUI import set.
- Session/control strings are plaintext `/MESG_*` templates carrying source/destination IPs, session ID, chat/reject text, and quick-connection A/V format fields.
- Media packet format, sequencing, and loss behavior remain static-only unknowns.

## Unknowns

- Byte-for-byte media packet grammar.
- Exact session state machine and UI transitions.
- Runtime use of GPUJPEG, if any, through dynamic loading.
- PtGrey runtime reachability in this XIMEA-labeled v2.0 GUI.
- Real hardware timing, drift behavior, frame drop policy, and 44.1 kHz/48 kHz interop.
- Installer payload internals, pending offline NSIS extraction.

## Legacy Compatibility Mode Addendum

The compatibility addendum classifies every artifact for LoLa 2.0 Windows
Legacy Compatibility Mode and turns the static AV/session evidence into an
implementation roadmap. Static analysis reaches a strong compatibility base,
but byte-exact LoLa AV TX/RX remains `PARTIAL` until isolated Windows peer
packet captures validate the remaining media payload fields.

VERDICT: PARTIAL
