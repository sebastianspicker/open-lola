# Mac Port Public Roadmap

Date: 2026-05-04
Status: sanitized public roadmap export
Source posture: `mac-port/**` remains review-only
Verdict: PARTIAL

## Purpose

This is the public-safe roadmap for the open-lola Mac port. It summarizes the
implementation direction without exposing raw internal research, generated
static-analysis detail, bundled Windows artifacts, packet dumps, proprietary
symbols, license/authentication behavior, or binary-derived packet layouts.

The roadmap is engineering guidance, not legal advice. Public release still
requires the license, notice, SDK, attribution, fixture-provenance, clean-room,
and maintainer/legal review gates tracked under
[../compliance/](../compliance/README.md).

## Release Posture

| Path | Public posture | Reason |
|---|---|---|
| `docs/roadmap/**` | Public roadmap lane after M06/M08 review. | Sanitized, public-safe summary with no raw-evidence links. |
| `mac-port/IMPLEMENTATION_COMPANION.md` | Review-only. | Canonical implementation overview with internal evidence links and detailed handoff references. |
| `mac-port/**` | Review-only. | Active implementation handoff, milestone history, reports, and operator notes. |
| `research/RESEARCH_*.md` | Internal/review-only. | Root research notes may need sanitization before publication. |
| `reverse-engineering/**`, `win-compiled/**` | Exclude by default. | Raw evidence and binary corpus are not public release material. |

## Roadmap Principles

- Audio timing is the primary acceptance gate.
- Video, control, lighting, recording, UI, and compatibility work are
  subordinate lanes.
- Synthetic fixtures prove source shape only; measured hardware and route
  reports are required for `PASS`.
- Legacy Windows LoLa behavior is benchmark context, not the default
  compatibility target.
- Compatibility features are optional, evidence-gated, and cannot change the
  default Mac-native fastest path.
- Public claims must cite public docs, original open-lola tests, or measured
  reports, not internal reverse-engineering evidence.

## Milestone Summary

| ID | Public objective | Current public posture | Required evidence before PASS |
|---|---|---|---|
| M00 | Establish original SwiftPM source, tests, and docs harness. | Complete source gate. | None for M00. |
| M01 | Record reference Macs, audio interfaces, route labels, capture points, DSCP policy, and thresholds. | PARTIAL. | Real hardware inventory and route facts. |
| M02 | Enumerate Core Audio devices and report callback-safe inventory data. | Complete source gate. | Target RME visibility remains needed for later gates. |
| M03 | Measure endpoint loopback and select fastest stable mode. | PARTIAL. | RME/MADI loopback matrix across buffer sizes and sample rates. |
| M04 | Define open-lola-owned UDP PCM packet contract. | Complete source gate. | Physical route performance remains M05 work. |
| M05 | Certify direct, switched, and campus UDP PCM routes. | PARTIAL. | Two-Mac reports with packet capture, packet age, loss, jitter, and DSCP classification. |
| M06 | Add drift telemetry and same-deadline PLC policy. | PARTIAL. | 60-minute fixed-target run, artifact assessment, and same-hardware baseline comparison. |
| M07 | Evaluate AVB, TSN, AES67, RAVENNA, Dante, and related modes as optional interop. | PARTIAL. | Standards/vendor-profile review plus measured comparison against direct UDP PCM. |
| M08 | Add Blackmagic/ATEM-first video capture with AVFoundation fallback. | PARTIAL. | Target hardware inventory, permission state, capture metrics, and unchanged audio timing. |
| M09 | Add best-effort video transport. | PARTIAL. | Physical video route, frame-age/drop metrics, and proof that video degrades before audio changes. |
| M10 | Prove integrated headless A/V coexistence. | PARTIAL. | 30-minute measured run with accepted audio, route, drift, capture, transport, control, and packet-capture evidence. |
| M11 | Add OSC show-control and read-only ATEM status probes. | PARTIAL. | Live peer evidence and unchanged audio metrics. |
| M12 | Gate sACN/Art-Net and fixture work behind standards, explicit arm, isolated route, and no audio impact. | PARTIAL. | Standards/license disposition, one-universe isolated probe, packet capture, and audio-impact report. |
| M13 | Build native app shell around proven headless core. | PARTIAL. | Launched app-bundle evidence and app-vs-CLI metrics comparison. |
| M14 | Add opt-in raw recording/session artifacts and release-hardening reports outside live deadlines. | PARTIAL. | Physical raw recording run, disk-pressure stress, recording-off/on comparison, audited public docs, release claims, and benchmark comparison. |
| M15 | Package, sign, notarize, and field-test on clean Macs. | PARTIAL. | License/notice closure, SDK redistribution review, signing identity, entitlements, notarization, Gatekeeper, and clean-Mac report. |

## Clean-Room Gates

| Area | Public-safe requirement | Gate |
|---|---|---|
| Protocol | Use an open-lola-owned, versioned UDP PCM contract. | Do not copy or publish proprietary packet grammar; compatibility payloads require separate review. |
| Compatibility | Keep legacy interoperability optional. | No compatibility mode becomes default without explicit user direction, measured evidence, and maintainer/legal review. |
| Video | Use public macOS APIs or approved optional SDK adapters. | Do not vendor SDK files or reproduce vendor-internal behavior without license review. |
| Lighting | Use standards-reviewed sACN/Art-Net gates and isolated routes. | Record standards/license disposition before public release or product claims. |
| Benchmarking | Treat "faster than LoLa" as a measured ledger claim. | Same-hardware, same-route baseline required; synthetic or inferred comparisons stay `PARTIAL`. |
| Release | Publish from an allowlist. | `LICENSE`, `THIRD_PARTY_NOTICES.md`, fixture provenance, SDK notes, and release manifest must be closed or explicitly deferred. |

## Public Claim Rules

- Say "source gate complete" only for original source contracts that build and
  test.
- Say `PARTIAL` whenever required real hardware, route, signing, clean-Mac, SDK,
  standards, or reviewer evidence is missing.
- Do not claim wire compatibility, release readiness, or performance superiority
  without measured reports.
- Do not publish internal artifact paths as evidence in public claims.
- Document adapted, changed, or independently improved behavior as open-lola
  requirements and tests, not as copied proprietary behavior.

## Next Public Milestones

1. Close M05 license and dependency review before publication.
2. Close M06 public-doc wording review for `docs/**`.
3. Create `THIRD_PARTY_NOTICES.md` in M07.
4. Audit implementation and public claims in M08.
5. Build the M09 release checklist and M10 review packet from allowlisted files.

## Resume Here

For public roadmap work, edit this file and keep the review-only implementation
handoff under `mac-port/IMPLEMENTATION_COMPANION.md` and `mac-port/**`
separate. For implementation
work, use the review-only handoff after checking the compliance
[release manifest](../compliance/release-manifest.md).

VERDICT: PARTIAL
