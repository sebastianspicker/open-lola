# Reverse Engineering Findings

Canonical entry point:
[REVERSE_ENGINEERING_COMPANION_2026.md](REVERSE_ENGINEERING_COMPANION_2026.md)

Date: 2026-05-04  
Status: internal reverse-engineering companion set  
Scope: static Windows LoLa evidence only
Verdict: PARTIAL

## Internal Evidence Boundary

This folder is internal technical evidence, not the publication surface. Public
summaries belong in
[../docs/background/README.md](../docs/background/README.md), where claims are
sanitized and compatibility language is explicitly scoped.

No Windows executable was run. No Wine, activation bypass, hardware probing,
packet capture, or binary patching was performed. The active files below
present the reverse-engineering findings in the same companion/evidence style as
the research findings.

## Reading Order

1. Read
   [REVERSE_ENGINEERING_COMPANION_2026.md](REVERSE_ENGINEERING_COMPANION_2026.md)
   first.
2. Read
   [REVERSE_ENGINEERING_ARTIFACTS_AND_ORIGINS_2026.md](REVERSE_ENGINEERING_ARTIFACTS_AND_ORIGINS_2026.md)
   for LoLa origins, package lineage, v1.5/v2.0 deltas, helper roles, and
   runtime ownership boundaries.
3. Read
   [REVERSE_ENGINEERING_LOLA_E2E_WORKFLOW_2026.md](REVERSE_ENGINEERING_LOLA_E2E_WORKFLOW_2026.md)
   for audio, video, network/session, TX/RX, reassembly, and E2E workflow.
4. Use
   [REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md](REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md)
   as the source-of-truth static claim register.
5. Use
   [REVERSE_ENGINEERING_SECURITY_COMMANDS_CONFIDENCE_2026.md](REVERSE_ENGINEERING_SECURITY_COMMANDS_CONFIDENCE_2026.md)
   for security-relevant observations, command provenance, confidence, and
   runtime gaps.
6. Use [lola-2-windows/README.md](lola-2-windows/README.md) for the Mac-only
   legacy-compatibility reconstruction harness.
7. Use
   [../archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/README.md](../archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/README.md)
   only when generated static inventory, Ghidra summaries, or tool evidence is
   needed.

## Document Map

| Document | Role |
|---|---|
| [REVERSE_ENGINEERING_COMPANION_2026.md](REVERSE_ENGINEERING_COMPANION_2026.md) | Canonical entry, reading order, decision summary, historical files, and static boundary. |
| [REVERSE_ENGINEERING_ARTIFACTS_AND_ORIGINS_2026.md](REVERSE_ENGINEERING_ARTIFACTS_AND_ORIGINS_2026.md) | Full `win-compiled` corpus classification, LoLa origins, version lineage, third-party boundaries, and camera/config payloads. |
| [REVERSE_ENGINEERING_LOLA_E2E_WORKFLOW_2026.md](REVERSE_ENGINEERING_LOLA_E2E_WORKFLOW_2026.md) | Structured LoLa processing, networking, local TX, RX/reassembly, and end-to-end workflow with Mermaid diagrams. |
| [REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md](REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md) | Claim-by-claim evidence matrix with confidence and runtime gaps. |
| [REVERSE_ENGINEERING_SECURITY_COMMANDS_CONFIDENCE_2026.md](REVERSE_ENGINEERING_SECURITY_COMMANDS_CONFIDENCE_2026.md) | Security observations, exact command history, confidence levels, and verification notes. |
| [lola-2-windows/](lola-2-windows/README.md) | Internal Mac-only compatibility reconstruction and future Windows validation roadmap. |
| [../archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/](../archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/folder-analysis-20260503-1747/README.md) | Internal generated static inventory, strings, Ghidra summaries, and compatibility addendum. |

## Current Result

Static fact: LoLa in `../archive/2026-05-11-win-compiled/win-compiled` is a Windows/MFC low-latency
audio/video package from the Tartini/GARR LoLa project. The analyzed active
v2.0 live target is `../archive/2026-05-11-win-compiled/win-compiled/2-0/LolaGui_XIMEA_x64.exe`.

Static fact: v2.0 is an assembled runtime distribution. It changes the main
GUI, XIMEA camera list, `XimeaColors.ini`, and VC++ 2015-2019 runtime files,
while preserving older tester, converter, splitter, PortAudio, OpenCV,
IJG/libjpeg, GPUJPEG, CUDA, WinPcap, XIMEA installer, and XIMEA runtime
artifacts.

Strong inference: the Windows design is audio-first and WinPcap-centered. The
audio callback does bounded local work, media TX/RX uses raw packet paths, video
can drop/degrade, and helper utilities are offline/support surfaces rather than
live transport paths.

Runtime gap: exact live control framing, byte-for-byte media packet grammar,
hardware timing, packet-loss behavior, activation validation, and 48 kHz
interop remain unproven without Windows execution, hardware, a peer, or packet
capture.

## Historical Files

The previous detailed slice reports are preserved for traceability but are no
longer the primary entry point:

- [deprecated reverse-engineering archive](../archive/2026-05-05-doc-consolidation/reverse-engineering/deprecated-reverse-engineering/README.md)

Current decisions and source-of-truth summaries belong in the canonical files
above. Historical files remain useful for address-level evidence and command
traceability.

## Public Boundary

The public documentation surface is [../docs/](../docs/README.md). It may refer
to internal reverse-engineering notes as withheld evidence, but it must not link
readers directly to raw strings, addresses, hashes, proprietary message
templates, or generated static-analysis detail.
