# Reverse-Engineering Boundary

Date: 2026-05-15
Status: public-safe reverse-engineering summary after consolidation
Verdict: PARTIAL

This directory is the public-facing reverse-engineering boundary. It records
what can be said safely in the documentation tree without exposing raw Windows
binary evidence, extracted strings, address-level notes, hashes, command
transcripts, packet captures, or private lab paths.

Detailed reverse-engineering evidence lives under
`../../private/reverse-engineering/` and is excluded from release candidates.
Superseded routers and planning files are preserved under
`../../archive/2026-05-11-reverse-engineering-consolidation/`.

## Current Implementation Stage

The LoLa connector is source-level implemented from local evidence and the
Linux compatibility seed. It is not a real-world Windows LoLa compatibility
claim.

Completed:

- static Windows LoLa corpus classification and dependency boundary review;
- source-level LoLa control-message parser/builder behavior;
- source-level synthetic packet fixture generation and passive decode paths;
- source-level media envelope handling for the corrected Linux-seed audio and
  video layout;
- explicit `tx-rx` connector planning and post-control media TX/RX wiring;
- constrained live Windows LoLa Swift peer evidence for post-connect status
  checks and outbound generated AV: the Windows peer reports the Mac responder
  as running, displays generated video, and shows roughly 90% fewer audio buffer
  realignments after Swift audio and video live TX were paced on separate loops;
- release hygiene rules that keep private evidence and Windows binaries out of
  public candidates.

Missing:

- fresh Windows-originated audio/video media capture after the latest Swift
  outbound/control fixes;
- byte-for-byte validation of control and media packet grammar against real
  Windows LoLa sessions;
- ASIO, WinPcap, XIMEA/PtGrey, packet-loss, reconnect, and 48 kHz runtime
  evidence;
- maintainer/legal/reviewer approval for any public release wording that
  mentions reverse-engineering-derived behavior.

## File Disposition

| Original file | Current location | Disposition |
|---|---|---|
| `reverse-engineering/README.md` | `archive/2026-05-11-reverse-engineering-consolidation/reverse-engineering/README.md` | Superseded duplicate router. |
| `reverse-engineering/REVERSE_ENGINEERING_COMPANION_2026.md` | `archive/2026-05-11-reverse-engineering-consolidation/reverse-engineering/REVERSE_ENGINEERING_COMPANION_2026.md` | Superseded by this public summary and `private/reverse-engineering/README.md`. |
| `reverse-engineering/REVERSE_ENGINEERING_ARTIFACTS_AND_ORIGINS_2026.md` | `private/reverse-engineering/REVERSE_ENGINEERING_ARTIFACTS_AND_ORIGINS_2026.md` | Private static evidence. |
| `reverse-engineering/REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md` | `private/reverse-engineering/REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md` | Private claim/evidence ledger. |
| `reverse-engineering/REVERSE_ENGINEERING_LOLA_E2E_WORKFLOW_2026.md` | `private/reverse-engineering/REVERSE_ENGINEERING_LOLA_E2E_WORKFLOW_2026.md` | Private workflow and protocol evidence. |
| `reverse-engineering/REVERSE_ENGINEERING_SECURITY_COMMANDS_CONFIDENCE_2026.md` | `private/reverse-engineering/REVERSE_ENGINEERING_SECURITY_COMMANDS_CONFIDENCE_2026.md` | Private command, security, and confidence ledger. |
| `reverse-engineering/lola-2-windows/README.md` | `archive/2026-05-11-reverse-engineering-consolidation/reverse-engineering/lola-2-windows/README.md` | Superseded duplicate harness router. |
| `reverse-engineering/lola-2-windows/static-analysis.md` | `private/reverse-engineering/lola-2-windows/static-analysis.md` | Private Windows static-analysis ledger. |
| `reverse-engineering/lola-2-windows/runtime-analysis.md` | `private/reverse-engineering/lola-2-windows/runtime-analysis.md` | Private runtime reconstruction and Windows probe notes. |
| `reverse-engineering/lola-2-windows/validation-checklist.md` | `private/reverse-engineering/lola-2-windows/validation-checklist.md` | Private Mac-confirmable and Windows validation gates. |
| `reverse-engineering/lola-2-windows/legacy-compatibility-roadmap.md` | `archive/2026-05-11-reverse-engineering-consolidation/reverse-engineering/lola-2-windows/legacy-compatibility-roadmap.md` | Superseded because its implementation work packages are reflected in source and private status ledgers. |
| `reverse-engineering/.DS_Store` | `archive/2026-05-11-reverse-engineering-consolidation/reverse-engineering/.DS_Store` | Archived local metadata residue; not active documentation. |

## Publication Rule

Public docs may state sanitized implementation status, evidence classes, and
remaining validation gates. They must not link to private evidence as public
authority, quote raw extracted strings, publish proprietary binary-derived
tables, or imply real-world Windows interoperability before captured media
evidence exists.

Resume here: update this page when private evidence is reclassified, a Windows
validation gate closes, or release wording changes.

VERDICT: PARTIAL
