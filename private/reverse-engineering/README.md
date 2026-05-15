# Private Reverse-Engineering Evidence

Date: 2026-05-11
Status: consolidated private reverse-engineering entry point
Verdict: PARTIAL

This directory is the private evidence lane for Windows LoLa reverse
engineering. It replaces the former top-level `reverse-engineering/` tree.

Public-facing status lives in
[../../docs/reverse-engineering/README.md](../../docs/reverse-engineering/README.md).
Superseded routers and stale roadmap files are archived under
[../../archive/2026-05-11-reverse-engineering-consolidation/](../../archive/2026-05-11-reverse-engineering-consolidation/).

## Active Private Files

| Document | Role |
|---|---|
| [REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md](REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md) | Canonical private claim/evidence ledger. |
| [REVERSE_ENGINEERING_ARTIFACTS_AND_ORIGINS_2026.md](REVERSE_ENGINEERING_ARTIFACTS_AND_ORIGINS_2026.md) | Windows corpus, version lineage, third-party boundaries, and camera/config payload evidence. |
| [REVERSE_ENGINEERING_LOLA_E2E_WORKFLOW_2026.md](REVERSE_ENGINEERING_LOLA_E2E_WORKFLOW_2026.md) | Private workflow, packet path, control/session, and runtime-gap evidence. |
| [REVERSE_ENGINEERING_SECURITY_COMMANDS_CONFIDENCE_2026.md](REVERSE_ENGINEERING_SECURITY_COMMANDS_CONFIDENCE_2026.md) | Private security observations, command provenance, and confidence notes. |
| [lola-2-windows/static-analysis.md](lola-2-windows/static-analysis.md) | Windows 2.0 static inventory, metadata, imports, signing, dependency ownership, and codec evidence. |
| [lola-2-windows/runtime-analysis.md](lola-2-windows/runtime-analysis.md) | Runtime reconstruction, 2026-05-06 Windows UDP probe, implementation conclusion, and remaining validation gates. |
| [lola-2-windows/validation-checklist.md](lola-2-windows/validation-checklist.md) | Mac-confirmable checks and future Windows/hardware validation gates. |

## Implementation Stage

The implementation is at source-level PARTIAL for LoLa compatibility:

- M01 artifact inventory: done for the private dossier.
- M02 binary metadata/dependencies: done for the private dossier.
- M03 static analysis map: partial; current docs cite static clusters and
  prior Ghidra/radare2 evidence, but fresh headless Ghidra regeneration is not
  attached here.
- M04 behavior reconstruction: partial; control and media behavior is
  reconstructed, but live framing and timing are not fully proven.
- M05 AV TX pipeline: source-level implemented, runtime timing still partial.
- M06 AV RX pipeline: source-level implemented, loss/reorder behavior still
  partial.
- M07 codec confirmation: complete for static evidence; runtime performance
  remains future work.
- M08 network/protocol model: source-level implemented from Linux-seed and
  local evidence; byte compatibility remains partial until captures validate it.
- M09 synthetic fixtures/tests plan: implemented as source-level synthetic
  packet and passive decode surfaces; fixtures are not compatibility captures.
- M10 legacy compatibility architecture: implemented as passive decode/parser
  and explicit deferred interop gates.
- M11 implementation roadmap: superseded as a separate active document because
  source code, tests, this README, and the validation checklist now carry the
  current status.

## Current Missing Evidence

- Windows-originated audio/video datagrams captured after the post-control
  socket lifetime fix.
- Real control framing and escaping across status, quick-connect, reject,
  chat, disconnect, bounce-back, and generated-signal states.
- ASIO, WinPcap, XIMEA/PtGrey, packet-loss, reconnect, and 48 kHz interop
  evidence.
- Reviewer approval before any private detail is promoted into public docs.

VERDICT: PARTIAL
