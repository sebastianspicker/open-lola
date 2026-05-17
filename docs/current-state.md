# Current Public State

Date: 2026-05-15
Status: condensed active public state after documentation cleanup
Verdict: PARTIAL

open-lola is a clean-room, Mac-native SwiftPM workspace for audio-first
low-latency networked audio/video research and implementation. The active code
surface is `OpenLolaCore`, the `open-lola` CLI, the `open-lola-app` SwiftUI
target, tests, and the Linux LoLa compatibility seed under `linux_connector/`.

## Current State

Source-level work is broadly implemented for the current contract:

- Core scaffolding, CLI surfaces, tests, documentation harness, and
  `session-capabilities`.
- Core Audio inventory, AudioDeviceIOProc/AUHAL-oriented audio paths, UDP PCM
  packet contracts, direct P2P session reports, RX-buffer profiles, and source
  validators.
- Native Mac app shell surfaces, release-readiness reports, external connector
  runners, and local process probes for LoLa, MVTP/UltraGrid, and JackTrip.
- Swift Windows LoLa live probing has source and runtime evidence for
  post-connect status handling and outbound generated AV. A 2026-05-15 Windows
  peer run confirmed the Mac Swift responder is seen as running, video is
  visible, and Windows-side audio buffer realignment dropped by roughly 90%
  after live audio/video TX was split into separate paced loops.
- `OpenSourceReleaseReadinessReport` records the source-release blocker state
  without granting release approval.
- Public architecture docs for original open-lola design decisions, public
  standard references, public API boundaries, and implementation hypotheses.

The product remains `PARTIAL` because source, docs, and local probes are not
the same as real field evidence. Required evidence still includes:

- RME/MADI hardware visibility, route labels, packet-capture points, DSCP/PTP
  policy, and accepted latency/loss thresholds.
- Physical two-Mac direct P2P runs with measured packet age, loss, jitter,
  underrun/overrun, and audio-only fastest-baseline comparison.
- Blackmagic/ATEM or other reviewed video capture proof with video degrading
  before audio timing changes.
- Windows-originated LoLa media capture and decode evidence for the Swift
  compatibility lane; the latest Swift TX/RX report still decoded zero inbound
  Windows media frames and remains `PARTIAL`.
- OSC, sACN, Art-Net, and lighting/control checks with explicit audio-impact
  evidence.
- Developer ID signing, notarization, Gatekeeper, clean-Mac launch, fixture
  provenance, final license/notices, and maintainer/reviewer signoff.

## Evidence Policy

Use these labels when making public claims:

| Label | Meaning |
|---|---|
| Public standard | Backed by a public protocol, standard, vendor API, or documented platform behavior. |
| Public API | Backed by Apple or other public SDK/API behavior. |
| Original open-lola design | Implemented as open-lola-owned source, tests, and docs. |
| Experimentally derived requirement | Requires local or field measurement before promotion. |
| Compatibility requirement | Applies only when a compatibility lane is explicitly selected and measured. |
| Implementation hypothesis | Plausible design guidance that is not yet field evidence. |

Do not promote synthetic fixtures, localhost runs, archived reports, built-in
Mac devices, or placeholder hardware labels to product `PASS`.

## Active Reading Order

1. [../README.md](../README.md) for the checkout entry point.
2. [implementation-handoff.md](implementation-handoff.md) for current source
   status, missing evidence, and resume state.
3. [source-contracts.md](source-contracts.md) for the condensed
   source-contract index.
4. [testing.md](testing.md) for active verification commands and
   surface probes.
5. [validation-methodology.md](validation-methodology.md) for publication-safe research
   summaries and implementation evidence context.
6. [release-boundary.md](release-boundary.md) and
   [release-manifest.md](release-manifest.md) for release
   boundaries.
7. [open-questions.md](open-questions.md) for SOTA source refresh, human-input
   gates, and field-test questions.

Superseded detailed roadmaps, source-contract files, testing matrices, and
compliance ledgers are archived under
`archive/2026-05-11-doc-condense/`. Detailed research matrices and companion
files are archived under `archive/2026-05-11-research-archive/`. The completed
2026-05-13 root plan remediation closure is archived under
`archive/2026-05-14-plan-remediation-closure/`; earlier plan remediation setup
evidence remains under `archive/2026-05-11-plan-remediation/`. Completed
2026-05-16 source-audit, refactor-plan, remediation, simplification,
verification-baseline, and test-quality artifacts are archived under
`archive/2026-05-16-source-audit-refactor-closure/`. The completed 2026-05-17
refactor-remediation closure artifacts are archived under
`archive/2026-05-17-refactor-remediation-closure/`. The completed
simplification-only audit/plan run is archived under
`archive/2026-05-16-completed-simplification-run/`. The completed
simplicity/certainty audit chain and closed SIM remediation plan, ledger, and
status files are archived under
`archive/2026-05-16-simplicity-certainty-closure/`. The later completed
2026-05-17 simplicity/certainty audit packet, SRP remediation plan,
ledger/status, and companion investigation inventories are archived under
`archive/2026-05-17-simplicity-remediation-closure/`. Superseded docs
subfolder routers, background notes, and merged planning notes are archived
under `archive/2026-05-17-docs-flattening-cleanup/`. Older archive lanes remain
trace evidence only.

## Resume Here

Resume implementation from the active Mac-port handoff. The next real-world
closure step is still the hardware baseline: identify reference Macs, RME MADI
paths, device UIDs, route labels, packet-capture points, DSCP/PTP policy, and
thresholds before promoting any physical gate to `PASS`.

VERDICT: PARTIAL
