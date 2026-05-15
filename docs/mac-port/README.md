# Mac Port Implementation Status

Date: 2026-05-15
Status: consolidated active Mac-port implementation handoff
Verdict: PARTIAL

This directory is the active Mac-port implementation documentation lane. It
replaces the former top-level `mac-port/` handoff tree and keeps only documents
that describe current state without duplicating the public roadmap, source
contracts, testing matrix, or compliance manifest.

## Active Files

| File | Purpose |
|---|---|
| [README.md](README.md) | Current implementation stage, completed work, missing evidence, and file-by-file consolidation result. |
| [open-questions.md](open-questions.md) | Human input and measurement gates that still block runtime or release PASS. |
| [risk-register.md](risk-register.md) | Active Mac-port risks that still affect implementation or field evidence. |
| [sota-open-question-matrix.md](sota-open-question-matrix.md) | Detailed research-probe routing for SOTA questions. Recheck dated sources before implementing a row. |

Public-safe summaries remain in [../current-state.md](../current-state.md),
[../roadmap/README.md](../roadmap/README.md), and
[../source-contracts/README.md](../source-contracts/README.md). Verification
commands and release boundaries remain in [../testing/README.md](../testing/README.md)
and [../compliance/release-manifest.md](../compliance/release-manifest.md).

## File-by-File Disposition

| Former file | Disposition | Reason |
|---|---|---|
| `mac-port/README.md` | Archived under `archive/2026-05-11-mac-port-consolidation/docs/mac-port/README.md`. | Router duplicated this README and used the old top-level path. |
| `mac-port/IMPLEMENTATION_COMPANION.md` | Archived under `archive/2026-05-11-mac-port-consolidation/docs/mac-port/IMPLEMENTATION_COMPANION.md`. | Oversized mixed handoff: progress, commands, archive map, and domain notes now consolidated here or delegated to focused active docs. |
| `mac-port/OPEN_QUESTIONS.md` | Moved to [open-questions.md](open-questions.md). | Still current, but path and release/compliance links needed updating. |
| `mac-port/RISK_REGISTER.md` | Moved to [risk-register.md](risk-register.md). | Still current, but path and status needed updating. |
| `mac-port/SOTA_2026_OPEN_QUESTION_MATRIX.md` | Moved to [sota-open-question-matrix.md](sota-open-question-matrix.md). | Still useful as a detailed research routing matrix; filename and resume links were normalized. |
| `mac-port/implementation-companions/README.md` | Archived under `archive/2026-05-11-mac-port-consolidation/docs/mac-port/implementation-companions/README.md`. | Router duplicated domain detail and pointed at the archived F01-F12 history. |
| `mac-port/implementation-companions/audio-network.md` | Archived under `archive/2026-05-11-mac-port-consolidation/docs/mac-port/implementation-companions/audio-network.md`. | Current audio/network status is summarized below; detailed source contracts live in public architecture/source-contract docs. |
| `mac-port/implementation-companions/video-control.md` | Archived under `archive/2026-05-11-mac-port-consolidation/docs/mac-port/implementation-companions/video-control.md`. | Current video/control status is summarized below; detailed design remains in public architecture docs. |
| `mac-port/implementation-companions/app-release-field.md` | Archived under `archive/2026-05-11-mac-port-consolidation/docs/mac-port/implementation-companions/app-release-field.md`. | Current app/release status is summarized below and release boundaries live in compliance docs. |
| `mac-port/implementation-companions/evidence-compliance.md` | Archived under `archive/2026-05-11-mac-port-consolidation/docs/mac-port/implementation-companions/evidence-compliance.md`. | Duplicated the active docs map, archive rules, and release manifest. |
| `mac-port/templates/SESSION_HANDOFF_TEMPLATE.md` | Archived under `archive/2026-05-11-mac-port-consolidation/docs/mac-port/templates/SESSION_HANDOFF_TEMPLATE.md`. | Template referenced the old top-level `mac-port` path and is not current project state. |
| `mac-port/templates/MILESTONE_STATUS_TEMPLATE.md` | Archived under `archive/2026-05-11-mac-port-consolidation/docs/mac-port/templates/MILESTONE_STATUS_TEMPLATE.md`. | Generic template, not active status. |

## Implementation Stage

The project is past source-contract scaffolding and local validation. It is not
past real-world runtime validation.

| Stage | State | Evidence |
|---|---|---|
| Documentation and SwiftPM scaffold | Done | Swift package, `OpenLolaCore`, CLI, SwiftUI app target, tests, docs verifier, and release hygiene scripts exist. |
| Core source contracts | Source-level done | M02 Core Audio inventory and M04 UDP PCM packet contract are source-level PASS; packet serializers, validators, fixtures, and local smokes exist. |
| Local source/runtime probes | Source-level partial | Direct P2P, RX buffering, video transport, app shell, release-readiness, and connector report paths exist with synthetic, localhost, or constrained Windows LoLa peer evidence. |
| Physical audio/network proof | Missing | No current RME MADI hardware identity, accepted device UIDs, two-Mac route labels, packet captures, DSCP/PTP observations, or physical latency/loss reports are recorded. |
| Physical video/control proof | Missing | No Blackmagic/ATEM device proof, capture permission proof, video-under-audio-stress run, OSC peer, ATEM read-only status, or lighting/sACN/Art-Net isolated run is recorded. |
| Release and field proof | Missing | No final license, fixture provenance signoff, Developer ID package, notarization ticket, Gatekeeper acceptance, clean-Mac launch, or reviewed release candidate exists. |

## Completed

- M00 scaffold is complete at source level.
- M02 Core Audio inventory is complete at source level.
- M04 UDP PCM packet contract is complete at source level.
- The code contains validators, report schemas, local smokes, and CLI probes for
  most M01-M15 lanes.
- Release-readiness CLI probes include
  `open-source-release-readiness-run` and
  `validate-open-source-release-readiness-report`; they are blocker reports, not
  release approval.
- Linux LoLa compatibility evidence is preserved as a seed in
  `linux_connector/`. Swift now has constrained Windows LoLa runtime evidence
  for UDP control/status retry handling and outbound generated AV: the Windows
  peer sees the Mac Swift responder as running, generated video is visible, and
  audio buffer realignment on the Windows side dropped by roughly 90% after
  Swift live audio/video TX was split into separate paced loops. Full Windows
  interoperability remains unproven until a fresh measured Windows-originated
  media capture succeeds and inbound Swift decode is validated.
- G16 compatibility parity remains deliberately deferred unless a specific
  feature is promoted with measured evidence.
- Documentation cleanup moved superseded roadmap, source-contract, testing,
  compliance, Mac-port, and Windows corpus material into dated archive lanes.

## Missing

- Q001 hardware baseline: reference Macs, RME MADI model, driver/firmware,
  TotalMix state, device UIDs, channel labels, route labels, packet-capture
  points, DSCP policy, and PASS thresholds.
- Q002-Q004 physical audio and route measurement: analog loopback, two-Mac UDP
  PCM route, direct P2P control/media transcript, packet age, jitter, loss,
  underrun/overrun, and RX-buffer benchmark on the same physical route.
- Q005-Q006 timing and professional AoIP evidence: PTP/AVB/AES67/RAVENNA/Dante
  endpoints, lock state, profile notes, and stress comparisons.
- Q007-Q009 physical video/control/lighting evidence: Blackmagic/ATEM or
  AVFoundation capture, VideoToolbox policy measurement if encoding is used,
  video transport under audio stress, OSC peer, ATEM read-only probe, isolated
  lighting target, blackout behavior, and packet capture.
- Q010 release evidence: signing identity, entitlements, notarization,
  Gatekeeper acceptance, clean-Mac field run, final notices, fixture
  provenance, reviewer signoff, and publication approval.
- Q011-Q012 NAT/ISP and diagnostic evidence: self-hosted rendezvous/forwarder
  choice, firewall rules, route permissions, ICMP/traceroute/UDP echo data, and
  raw-vs-NAT latency comparison.

## Resume Here

Do not add a new milestone file. Start from Q001 in
[open-questions.md](open-questions.md), collect real hardware and route facts,
then run the matching CLI/report validators from [../testing/README.md](../testing/README.md).
Only promote a row from `PARTIAL` to `PASS` when the physical report and
validator both support that verdict.

VERDICT: PARTIAL
