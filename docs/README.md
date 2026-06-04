# Documentation

Date: 2026-06-02
Status: flat active technical reference surface with code-quality ledgers
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
| [clean-room-design-rules.md](clean-room-design-rules.md) | Clean-room implementation rules and evidence boundaries. |
| [open-questions.md](open-questions.md) | Human-input questions, SOTA source refresh, and measurement gates. |
| [risk-register.md](risk-register.md) | Active implementation and release risks. |
| [mac-to-mac-connection.md](mac-to-mac-connection.md) | Active mac-to-mac setup goal and preflight-first contract. |
| [e2e-p2p-session.md](e2e-p2p-session.md) | End-to-end P2P session target, blockers, and evidence gates. |
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
| [codacy-status-ledger.md](codacy-status-ledger.md), [codacy-remediation-ledger.md](codacy-remediation-ledger.md) | Local Codacy backlog/remediation tracking. These ledgers are code-quality status, not runtime or release evidence. |

## Archive Boundary

Implementation status lives in [implementation-handoff.md](implementation-handoff.md).
Research-derived requirements live in the flat technical references above.
Archive details live in [../archive/README.md](../archive/README.md), including
completed plans, audits, ledgers, remediation statuses, source inventories,
verification baselines, deprecated routers, generated historical outputs,
connector closure packets, and the completed 2026-05-21 audit/remediation
packet. Publication claims should use the active flat docs unless the release
manifest explicitly allows selected archived research files.
Internal reverse-engineering evidence lives under `../private/reverse-engineering/`.

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
