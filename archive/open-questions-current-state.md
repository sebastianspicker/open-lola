# Open Questions vs Current Project State

Updated: 2026-05-13

This document consolidates active open questions against the live checkout and
the current public state. It intentionally separates source-level completion
from runtime, hardware, signing, and release evidence.

## Source Baseline

- Current public state: `docs/current-state.md` remains `VERDICT: PARTIAL`.
- Active Mac-port question ledger: `docs/mac-port/open-questions.md`.
- Detailed SOTA routing matrix: `docs/mac-port/sota-open-question-matrix.md`.
- Plan remediation closure archive:
  `archive/2026-05-14-plan-remediation-closure/`.
- Checkout evidence mode: no `.git` metadata is present, so evidence is based
  on filesystem inspection, tests, scripts, and CLI probes.

## Current State Summary

Source-level implementation is broad but not product PASS. The codebase has
SwiftPM targets for `OpenLolaCore`, the `open-lola` CLI, the `open-lola-app`
SwiftUI target, test harnesses, release-readiness scripts, and the
`linux_connector` compatibility seed.

The source-owned `plan.md` remediation is closed and archived:

| Plan status | Count |
|---|---:|
| Total findings | 436 |
| Open | 0 |
| In progress | 0 |
| Addressed | 307 |
| Stale/already covered | 92 |
| Invalid | 28 |
| Superseded | 9 |

Broad source verification is green:

| Gate | Current result |
|---|---|
| `ruff check linux_connector` | PASS |
| `pytest linux_connector` | PASS, 58 passed, 2 skipped |
| `python -m mypy --strict linux_connector/lola_connector` | PASS |
| `shellcheck scripts/*.sh scripts/lib/*.sh script/*.sh` | PASS |
| `swift test --no-parallel` | PASS, 1644 tests |
| `open-lola session-capabilities` | PASS, `VERDICT: PASS` |
| `bash scripts/verify-release-readiness.sh` | PASS, `VERDICT: PASS`; embedded manual release probes remain truthful `PARTIAL` for external evidence |

The previous broad Swift policy failures are closed. Oversized source/test files
were split below the 720 LOC budget, validation-call tests now include explicit
assertions or expected-failure checks, and the source-contract tests were
updated to cover extracted helper files.

## Hardware, Audio, And Route Questions

1. **Q001: Which exact reference Macs, RME MADI path, route labels, and thresholds define the hardware baseline?**
   - Current state: source schemas, validators, placeholder fixtures, and aggregate gates exist.
   - Still open because: real Mac identities, OS builds, RME model, driver/firmware, TotalMix state, Core Audio UIDs, clock source, channel labels, route labels, packet-capture points, DSCP policy, and PASS thresholds are not recorded.
   - Blocks: M01 and M13 full PASS, not source validation.

2. **Q002: Which physical analog loopback proves accepted sample rates without hidden conversion?**
   - Current state: Core Audio inventory and fastest-audio validation exist.
   - Still open because: physical loopback evidence is missing.
   - Blocks: fastest-mode selection.

3. **Q003: Do higher sample rates improve corrected one-way latency on the target path?**
   - Current state: validation requires 48/96/192 kHz disposition and rejects non-fastest PASS defaults.
   - Still open because: real loopback matrix evidence is missing.
   - Blocks: high-rate default.

4. **Q004: How do physical routes handle DSCP/QoS under direct, campus, and fallback paths?**
   - Current state: route-report validation, route-certification wrapper validation, aggregate gates, and localhost smoke exist.
   - Still open because: packet captures have not classified each real route as honored, rewritten, ignored, harmful, or not tested with reason.
   - Blocks: campus fastest-mode and M13 route PASS claims.

5. **Q012: What is the measured raw-vs-NAT/ISP route tradeoff?**
   - Current state: UDP echo RTT, ICMP RTT, traceroute hops, debug traces, and raw-vs-NAT added-latency fields exist.
   - Still open because: route permissions, DSCP observation, packet-capture points, and measured direct/campus/ISP-NAT runs are missing.
   - Blocks: route comparison and NAT tradeoff claims.

## AoIP, Timing, And Network Interop Questions

1. **Q005: Which PTP/AVB/AES67/RAVENNA/Dante endpoints and profiles are available?**
   - Current state: AoIP report source validation exists.
   - Still open because: switch/endpoints, PTP version/profile/domain/master, lock state, and failure behavior are not recorded.
   - Blocks: PTP/AVB/AES67/RAVENNA/Dante acceptance.

2. **Q006: Does AVB outperform direct UDP PCM on the actual target network?**
   - Current state: baseline and stress report validation exist.
   - Still open because: AVB-capable hardware and measured idle/stress comparison are missing.
   - Blocks: AVB-as-better-than-UDP claim.

3. **Q011: Which self-hosted rendezvous/forwarder host is allowed for NAT-friendly operation?**
   - Current state: source validation records self-hosted rendezvous, UDP forwarder/relay host, session, direct traversal, relay fallback, raw-P2P preference, and degradation warning.
   - Still open because: host, ports, operator, retention policy, and firewall rules are not selected.
   - Blocks: real NAT/ISP-friendly route evidence.

## Video, Control, And Lighting Questions

1. **Q007: Should production video use AVFoundation, Blackmagic/ATEM, or Desktop Video SDK first?**
   - Current state: policy resolved. Blackmagic/ATEM-first production inventory exists; AVFoundation remains the generic harness/fallback; Desktop Video SDK is optional after measured need.
   - Still open because: physical video capture evidence is still missing, but the source-policy question is resolved.
   - Blocks: physical video PASS, not source validation.

2. **Q008: Which external OSC peer should be tested first?**
   - Current state: policy resolved. Live OSC loopback remains first, Chataigne is preferred external peer, Open Stage Control is fallback.
   - Still open because: live interop measurements are missing, but the source-policy question is resolved.
   - Blocks: live OSC PASS, not source validation.

3. **Q009: Which isolated lighting universe, fixture target, and blackout/drop policy are safe for live output?**
   - Current state: source validation enforces OSC-first cue workflow, explicit arm/isolation, allowed universe, blackout/hold/drop policy, packet-capture evidence, setup-only fixture metadata, local fixture-owner guard, and no audio impact.
   - Still open because: allowed universe, isolated network, fixture target, blackout behavior, and capture point are not selected.
   - Blocks: real sACN/Art-Net output.

## Release And Distribution Questions

1. **Q010: Which signing, notarization, Gatekeeper, and clean-Mac field-test values define release readiness?**
   - Current state: source fields and composite handoff exist for signing identity, distribution identity, entitlements, and clean-Mac target.
   - Still open because: actual Developer ID/signing/notarization/account/profile, entitlements review, Gatekeeper target, and clean-Mac target are not recorded.
   - Blocks: packaging and field-test closure.

## Plan Remediation Questions

1. **P-PLAN-001: Are all concrete `plan.md` findings normalized and closed?**
   - Current state: yes. `archive/2026-05-14-plan-remediation-closure/plan-findings-ledger.md` reconciles 436 findings with no `open` or `in_progress` rows.
   - Evidence: `archive/2026-05-14-plan-remediation-closure/plan-status.md` records total findings 436, addressed count 436, and remaining count by priority P0=0, P1=0, P2=0.

2. **P-PLAN-002: Is verification fully green?**
   - Current state: yes for source-owned gates. Focused checks, Python gates, shellcheck, mypy, full Swift tests, release-readiness, and CLI surface probe pass.
   - Evidence: `archive/2026-05-14-plan-remediation-closure/plan-status.md` records the final verification matrix and `bash scripts/verify-release-readiness.sh` ended with `VERDICT: PASS`.
   - Blocking scope: product PASS still requires external runtime, hardware, signing, notarization, Gatekeeper, clean-Mac, and benchmark evidence outside this checkout.

## Resume Here

1. For runtime closure, start with Q001-Q004 and Q012: hardware identity, route labels, packet-capture points, and thresholds.
2. For network interop, update `docs/mac-port/sota-open-question-matrix.md` before implementing or promoting any AoIP/TSN/JPEG XS/lighting standards row.
3. For release closure, start with Q010 and collect the manual signing, notarization, Gatekeeper, clean-Mac, and hardware evidence required by the release probes.
4. For source cleanup, no `plan.md` findings remain open; start from new evidence only, not the remediated `plan.md` backlog.

VERDICT: PARTIAL
