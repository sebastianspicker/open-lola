# Open Lola Reverse Engineering Companion 2026

Canonical entry point:
[REVERSE_ENGINEERING_COMPANION_2026.md](REVERSE_ENGINEERING_COMPANION_2026.md)

Date: 2026-05-04  
Status: internal reverse-engineering companion set  
Scope: documentation consolidation of static Windows LoLa evidence
Verdict: PARTIAL

## Hard Boundary

This companion records what static analysis proves or strongly suggests about
the Windows LoLa corpus. It is not a live compatibility specification.

No Windows executable was run. No Wine, activation bypass, hardware probing,
packet capture, or binary patching was performed. Claims are labeled as static
fact, strong inference, medium inference, or runtime gap.

## Reading Order

1. Read this companion first.
2. Read
   [REVERSE_ENGINEERING_ARTIFACTS_AND_ORIGINS_2026.md](REVERSE_ENGINEERING_ARTIFACTS_AND_ORIGINS_2026.md)
   for the corpus, origins, helper roles, package deltas, and ownership
   boundaries.
3. Read
   [REVERSE_ENGINEERING_LOLA_E2E_WORKFLOW_2026.md](REVERSE_ENGINEERING_LOLA_E2E_WORKFLOW_2026.md)
   for local processing, session/control, TX/RX, fragment/reassembly, and E2E
   behavior.
4. Use
   [REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md](REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md)
   as the source-of-truth claim register.
5. Use
   [REVERSE_ENGINEERING_SECURITY_COMMANDS_CONFIDENCE_2026.md](REVERSE_ENGINEERING_SECURITY_COMMANDS_CONFIDENCE_2026.md)
   for command provenance, security-relevant observations, and confidence.
6. Use [lola-2-windows/README.md](lola-2-windows/README.md) for the Mac-only
   legacy-compatibility reconstruction harness.
7. Use
   [../archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/README.md](../archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/README.md)
   only when generated static inventory, Ghidra summaries, or tool evidence is
   needed.
8. Use historical files only when address-level or command-level detail is
   needed.

## Document Map

| Document | Role |
|---|---|
| [REVERSE_ENGINEERING_ARTIFACTS_AND_ORIGINS_2026.md](REVERSE_ENGINEERING_ARTIFACTS_AND_ORIGINS_2026.md) | Corpus inventory, LoLa origins, v1.5/v2.0 lineage, helper/runtime boundaries, and camera/config payloads. |
| [REVERSE_ENGINEERING_LOLA_E2E_WORKFLOW_2026.md](REVERSE_ENGINEERING_LOLA_E2E_WORKFLOW_2026.md) | Audio/video/network/session workflow, local TX, RX, reassembly, diagrams, and runtime gaps. |
| [REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md](REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md) | Static evidence matrix with claim level, evidence source, confidence, and remaining gap. |
| [REVERSE_ENGINEERING_SECURITY_COMMANDS_CONFIDENCE_2026.md](REVERSE_ENGINEERING_SECURITY_COMMANDS_CONFIDENCE_2026.md) | Security-relevant static observations, activation boundary, exact commands, and verification notes. |
| [lola-2-windows/](lola-2-windows/README.md) | Mac-only legacy-compatibility reconstruction harness and future Windows validation roadmap. |
| [../archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/](../archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/README.md) | Generated static inventory, strings, Ghidra summaries, tool evidence, and compatibility addendum. |

## Finding Summary

| Area | Finding | Status |
|---|---|---|
| Product identity | LoLa, Low Latency A/V Streaming, from the Tartini/GARR LoLa project. | Static fact |
| Primary target | `../archive/2026-05-11-win-compiled/win-compiled/2-0/LolaGui_XIMEA_x64.exe` is the active analyzed v2.0 live GUI. | Static fact |
| Package shape | Full corpus has 100 non-`.DS_Store` files: 72 in v1.5 and 28 in v2.0. | Static fact |
| v2.0 lineage | v2.0 is an assembled distribution around a newer main GUI, updated XIMEA camera config, `XimeaColors.ini`, and newer VC runtime files. | Strong inference |
| Tester lineage | Tester is byte-identical across v1.5/v2.0 and identifies as LoLa Tester 1.0.3 based on LoLa 1.3.0. | Static fact |
| Helper tools | Video converter and WAV splitter are byte-identical offline utilities, not live media transport paths. | Static fact |
| CUDA/GPUJPEG | GPUJPEG caller path is proven in the v1.5 CUDA GUI; v2.0 main has strings/settings but no static GPUJPEG import. | Static fact |
| Audio | v2.0 uses PortAudio/ASIO, 64-frame int16 callback blocks, bounded local work, and WinPcap media send. | Strong inference |
| Video | v2.0 uses XIMEA capture, raw or MJPEG TX, fragmenting, RX reassembly, CPU IJG/libjpeg decode, and GDI/DIB display. | Strong inference |
| Network/session | v2.0 uses WinPcap media paths, Winsock/IP Helper support, BPF filtering, and plaintext `/MESG_*` control/chat strings with `SRCIP`, `DSTIP`, and `SID`. | Static fact |
| Security boundary | No TLS, certificate, or authenticated key-exchange surface was found in the static string/import evidence. | Static fact |
| Runtime proof | Exact live packet grammar, control framing, activation algorithm, hardware timing, and 48 kHz interop are not statically proven. | Runtime gap |

## Decision Summary

| Area | Decision | Reason |
|---|---|---|
| Canonical documentation | use companion set | Matches the research structure and keeps current findings separate from historical address-level notes. |
| Historical slice reports | preserve under `archive/2026-05-05-doc-consolidation/reverse-engineering/deprecated-reverse-engineering/` | They contain useful address-level evidence but overlap and are no longer the entry point. |
| Generated evidence package | preserve under `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/` | It is internal static evidence and should not sit in the public `docs/` tree. |
| Windows LoLa compatibility | evidence only | Current Mac-native plan no longer requires LoLa wire compatibility, but LoLa remains benchmark/design evidence. |
| Static labels | keep mandatory | The evidence boundary matters because no Windows runtime, hardware, peer, or packet capture was used. |
| Diagrams | include for workflow | LoLa processing crosses audio, video, network, control, display, recording, and helper lanes. |

Decision values are normalized to: use, preserve, evidence only, keep
mandatory, include.

## Historical Files

The following files are preserved for traceability but are no longer the primary
reverse-engineering entry point:

- [deprecated-reverse-engineering/README.md](../archive/2026-05-05-doc-consolidation/reverse-engineering/deprecated-reverse-engineering/README.md)
- [ARTIFACTS_AND_VERSIONING.md](../archive/2026-05-05-doc-consolidation/reverse-engineering/deprecated-reverse-engineering/ARTIFACTS_AND_VERSIONING.md)
- [AUDIO_VIDEO_CAMERA_SURFACE.md](../archive/2026-05-05-doc-consolidation/reverse-engineering/deprecated-reverse-engineering/AUDIO_VIDEO_CAMERA_SURFACE.md)
- [AUDIO_WORKFLOW_REVERSE_ENGINEERING.md](../archive/2026-05-05-doc-consolidation/reverse-engineering/deprecated-reverse-engineering/AUDIO_WORKFLOW_REVERSE_ENGINEERING.md)
- [CORPUS_ORIGINS_AND_INTEGRATION.md](../archive/2026-05-05-doc-consolidation/reverse-engineering/deprecated-reverse-engineering/CORPUS_ORIGINS_AND_INTEGRATION.md)
- [NETWORK_AND_SESSION_PROTOCOL.md](../archive/2026-05-05-doc-consolidation/reverse-engineering/deprecated-reverse-engineering/NETWORK_AND_SESSION_PROTOCOL.md)
- [SECURITY_COMMANDS_CONFIDENCE.md](../archive/2026-05-05-doc-consolidation/reverse-engineering/deprecated-reverse-engineering/SECURITY_COMMANDS_CONFIDENCE.md)
- [VIDEO_WORKFLOW_REVERSE_ENGINEERING.md](../archive/2026-05-05-doc-consolidation/reverse-engineering/deprecated-reverse-engineering/VIDEO_WORKFLOW_REVERSE_ENGINEERING.md)
- [WIRING_AND_E2E_STRATEGY.md](../archive/2026-05-05-doc-consolidation/reverse-engineering/deprecated-reverse-engineering/WIRING_AND_E2E_STRATEGY.md)

Their content remains useful for address-level disassembly, exact command
history, and older intermediate reasoning. Current summaries and confidence
status belong in the canonical companion set above.

## Static Evidence Boundary

[REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md](REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md)
records the current source-of-truth claim matrix. Ghidra projects, generated
summaries, and scratch scripts are preserved only when they are distilled under
[archived internal evidence packages](../archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/); live scratch projects remain outside
the repository.

Any implementation depending on byte-for-byte protocol compatibility with
Windows LoLa must still perform a Windows runtime pass with hardware or a peer,
capture real packets, and document the exact packet/control grammar separately.
