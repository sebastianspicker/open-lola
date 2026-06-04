# Current Public State

Date: 2026-05-22
Status: active public state after source-level audit/remediation closure
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
- The native Mac app can launch JackTrip and UltraGrid through Open LoLa's
  `external-connector-session-run` path and validate the generated connector
  report. This is app-shell/runtime wiring only; it does not bundle reference
  `jacktrip`/`uv` binaries or satisfy reference-peer parity.
- Native UltraGrid/MVTP source-level runtime support now covers provider
  selection, bounded PT21 PCM and PT20 raw-video sinks, dynamic RTP payload
  mappings, local JPEG/H.264 validation, FEC/encryption behavior, control-command
  modeling, topology reporting, and evidence-gated `PASS` validation. Measured
  reference-peer parity remains blocked by missing
  `OPEN_LOLA_REFERENCE_PEER_HOST`.
- Native JackTrip source-level runtime support now covers provider selection,
  bounded DEFAULT PCM sinks, 8/16/24/32-bit PCM, `coreaudio`/`jack-graph`
  backend selection, hub topology, TCP handshake and auth/TLS frame modeling,
  DEFAULT/JAMLINK/EMPTY headers, WebRTC data-channel and WebTransport datagram
  packet models, plugin-boundary reporting, Opus-extension payloads, and
  evidence-gated `PASS` validation. Measured reference-peer parity remains
  blocked by missing `OPEN_LOLA_REFERENCE_PEER_HOST` and no local `jacktrip`
  executable.
- Swift Windows LoLa live probing has source and runtime evidence for
  post-connect status handling and outbound generated AV. A 2026-05-15 Windows
  peer run confirmed the Mac Swift responder is seen as running, video is
  visible, and Windows-side audio buffer realignment dropped by roughly 90%
  after live audio/video TX was split into separate paced loops.
- `OpenSourceReleaseReadinessReport` records the source-release blocker state
  without granting release approval.
- Public architecture docs for original open-lola design decisions, public
  standard references, public API boundaries, and implementation hypotheses.
- The completed 2026-05-20 to 2026-05-21 source audit, refactor plan,
  remediation ledger, remediation status, architecture map, code index, and
  verification baseline are archived under
  `../archive/2026-05-21-audit-remediation-closure/`. They are trace evidence,
  not active execution state.

Latest local evidence refresh, 2026-05-21:

- `swift build --product open-lola` passed outside the sandbox after the known
  SwiftPM manifest sandbox failure.
- `goal-runtime-preflight-run` and its validator passed with
  `VERDICT: PARTIAL`.
- `goal-completion-audit-run` and its validator passed with `VERDICT: PARTIAL`:
  93 mapped items, 77 pass, 16 partial, 16 blocked items, 21 blockers, and 21
  next actions.
- `open-source-release-readiness-run` and its validator passed with
  `VERDICT: PARTIAL`: 9 requirements and 6 blockers.
- Current host probes found 3 Core Audio devices, 4 video devices, camera
  permission authorized, 0 RME MADI candidates, 0 Blackmagic/ATEM candidates,
  1 codesigning identity, and 0 Developer ID Application identities.

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
- UltraGrid/MVTP and JackTrip reference-peer interoperability evidence,
  including real external peer hosts, packet/media quality, teardown, timing,
  and field-route evidence. JackTrip `jack-graph` field claims also need
  measured local JACK graph capture evidence.
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

Superseded roadmaps, audits, plans, ledgers, status files, subfolder routers,
research matrices, and generated historical outputs are indexed from
[../archive/README.md](../archive/README.md). Older archive lanes remain trace
evidence only; do not resume implementation from them unless a task explicitly
asks for archival trace work.

## Resume Here

Resume implementation from the active Mac-port handoff. The next real-world
closure step is still the hardware baseline: identify reference Macs, RME MADI
paths, device UIDs, route labels, packet-capture points, DSCP/PTP policy, and
thresholds before promoting any physical gate to `PASS`.

VERDICT: PARTIAL
