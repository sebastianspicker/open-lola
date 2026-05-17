# Documentation

Date: 2026-05-17
Status: flat active technical reference surface after cleanup
Verdict: PARTIAL

This directory is the active technical reference surface for open-lola. Active
docs are intentionally flat: root-level `docs/*.md` files only. Superseded
routers, background notes, and completed plans live under `../archive/`.

## Document Map

| Document | Purpose |
|---|---|
| [current-state.md](current-state.md) | Publication-safe current project state and evidence gates. |
| [implementation-handoff.md](implementation-handoff.md) | Active implementation handoff, completed source surface, blockers, and resume point. |
| [source-contracts.md](source-contracts.md) | Condensed active public source-contract summary. |
| [testing.md](testing.md) | Source verification, CLI probe, and real-world evidence boundary. |
| [release-boundary.md](release-boundary.md) | Condensed compliance, release, clean-room, and public/internal boundary summary. |
| [release-manifest.md](release-manifest.md) | Active release allowlist, exclusions, and blockers. |
| [open-questions.md](open-questions.md) | Human-input questions, SOTA source refresh, and measurement gates. |
| [risk-register.md](risk-register.md) | Active implementation and release risks. |
| [mac-to-mac-connection.md](mac-to-mac-connection.md) | Active mac-to-mac setup goal and preflight-first contract. |
| [reverse-engineering-boundary.md](reverse-engineering-boundary.md) | Public-safe reverse-engineering boundary and file disposition. |
| [compatibility-scope.md](compatibility-scope.md) | LoLa compatibility boundary. |
| [validation-methodology.md](validation-methodology.md) | Claim labels, evidence labels, and publication-safe wording. |
| [latency-first-architecture.md](latency-first-architecture.md) | Audio-first architecture entry point. |
| [p2p-networking.md](p2p-networking.md) | P2P networking, route setup, media packet, and transport error-handling reference. |
| [open-lola-protocol.md](open-lola-protocol.md) | Original open-lola protocol reference. |
| [latency-budget.md](latency-budget.md), [latency-profiles.md](latency-profiles.md), [rx-buffering.md](rx-buffering.md) | Latency and receive-buffer policy references. |
| [audio-routing.md](audio-routing.md), [audio-rme-madi.md](audio-rme-madi.md), [madi-full-rx-tx.md](madi-full-rx-tx.md), [rme-madi-routing.md](rme-madi-routing.md), [multichannel-audio-routing.md](multichannel-audio-routing.md), [multichannel-transport.md](multichannel-transport.md) | Audio, MADI, multichannel, and routing references. |
| [video-blackmagic-atem.md](video-blackmagic-atem.md), [multiple-video-streams.md](multiple-video-streams.md), [av-sync-and-timing.md](av-sync-and-timing.md), [lighting-control.md](lighting-control.md) | Video, AV sync, and control references. |
| [benchmark-methodology.md](benchmark-methodology.md), [benchmark-audio-latency.md](benchmark-audio-latency.md), [benchmark-e2e-av.md](benchmark-e2e-av.md) | Benchmark methodology references. |

## Internal Boundary

Implementation status lives in [implementation-handoff.md](implementation-handoff.md).
Research-derived requirements live in the flat technical references above.
Detailed research ledgers are archived under
`../archive/2026-05-11-research-archive/`; publication claims should use the
active flat docs unless the release manifest explicitly allows selected
archived research files.
Internal reverse-engineering evidence lives under
`../private/reverse-engineering/`. Superseded reverse-engineering routers and
stale roadmap files are preserved under
`../archive/2026-05-11-reverse-engineering-consolidation/`. Superseded roadmap,
source-contract, testing, and compliance details are preserved under
`../archive/2026-05-11-doc-condense/`.
Superseded Mac-port handoff files are preserved under
`../archive/2026-05-11-mac-port-consolidation/`.
Completed 2026-05-16 source-audit, refactor-plan, remediation, simplification,
verification-baseline, and test-quality artifacts are preserved under
`../archive/2026-05-16-source-audit-refactor-closure/`.
Completed 2026-05-17 source-audit, refactor-plan, remediation ledger/status,
architecture map, and verification-baseline artifacts are preserved under
`../archive/2026-05-17-refactor-remediation-closure/`.
The later completed simplification-only audit/plan run is preserved under
`../archive/2026-05-16-completed-simplification-run/`.
The completed simplicity/certainty audit chain and closed SIM remediation
plan, ledger, and status files are preserved under
`../archive/2026-05-16-simplicity-certainty-closure/`.
The later completed 2026-05-17 simplicity/certainty audit packet, SRP
remediation plan, ledger/status, and companion investigation inventories are
preserved under
`../archive/2026-05-17-simplicity-remediation-closure/`.
The 2026-05-17 docs flattening cleanup archived superseded subfolder routers,
background notes, and merged planning notes under
`../archive/2026-05-17-docs-flattening-cleanup/`.

Public docs may summarize measured, reviewed evidence. They must not link to
raw internal evidence, Windows binaries, packet dumps, private route context, or
archived review notes as implementation authority.

## Resume here

Resume here: update this map only when a public-safe active documentation file
is added, removed, or reclassified. Keep release wording `VERDICT: PARTIAL`
until the release manifest, license, notices, fixture provenance, reviewer
signoff, hardware, benchmark, signing, notarization, Gatekeeper, and clean-Mac
gates close.

VERDICT: PARTIAL
