# open-lola

Date: 2026-05-15
Status: Mac-native SwiftPM workspace with Linux LoLa compatibility seed, current blocker preflights, and condensed documentation archive
Verdict: PARTIAL

open-lola is a clean-room, Mac-native, audio-first exploration of low-latency
peer-to-peer audio/video for professional remote performance, teaching,
rehearsal, and production workflows. The goal is not to copy LoLa; it is to
build an independent implementation with original source contracts, public APIs,
public standards, original tests, and measured reports.

This checkout is not a Git repository in this environment. Verification is
filesystem- and command-based.

## Current State

- Swift Package Manager workspace with `OpenLolaCore`, the `open-lola` CLI, and
  the `open-lola-app` SwiftUI target.
- M00 scaffold, M02 Core Audio inventory, and M04 UDP PCM packet contract are
  source-level PASS.
- M01, M03, M05-M15, MXX source contracts, G16, F10-F12, runtime completion,
  and release hardening remain PARTIAL until measured hardware,
  route, timing, video, control, lighting, recording, packaging, signing,
  notarization, Gatekeeper, clean-Mac, and benchmark evidence exists.
- Public docs live under [docs/](docs/README.md).
- [linux_connector/](linux_connector/README.md) is the authoritative LoLa
  compatibility seed copied from the validated Linux prototype. It is kept as a
  Python seed, not merged into SwiftPM packaging; run it from this checkout with
  `python -m linux_connector...` commands.
- The active implementation handoff is
  [docs/mac-port/README.md](docs/mac-port/README.md).
- Public-safe reverse-engineering status is consolidated under
  [docs/reverse-engineering/README.md](docs/reverse-engineering/README.md);
  private evidence lives under `private/reverse-engineering/` and is excluded
  from release candidates.
- The concise active goal contract remains [GOAL.md](GOAL.md). Archived
  `GOAL.md` copies are historical snapshots only.
- The root plan remediation is closed and archived under
  [archive/2026-05-14-plan-remediation-closure/](archive/2026-05-14-plan-remediation-closure/).
  Start new audit work from fresh evidence, not from the archived backlog.
- Active Mac-port implementation detail is consolidated under
  [docs/mac-port/](docs/mac-port/README.md).
- Superseded docs are preserved under
  `archive/2026-05-11-win-compiled/`,
  `archive/2026-05-11-reverse-engineering-consolidation/`,
  `archive/2026-05-11-mac-port-consolidation/`,
  `archive/2026-05-11-doc-condense/`,
  `archive/2026-05-11-research-archive/`,
  `archive/2026-05-11-plan-remediation/`,
  `archive/2026-05-10-superseded-plans-audits-goals/`,
  `archive/2026-05-11-doc-cleanup/`,
  `archive/2026-05-05-doc-consolidation/` and
  `archive/2026-05-05-workflow-consolidation/`.
- Generated reverse-engineering output formerly under `re_out/` is deprecated
  and preserved under
  `archive/2026-05-10-superseded-plans-audits-goals/generated/re_out/`.

## Reading Order

1. [docs/current-state.md](docs/current-state.md) for the public-safe current
   project state.
2. [docs/roadmap/README.md](docs/roadmap/README.md) for the public-safe
   roadmap.
3. [docs/mac-port/README.md](docs/mac-port/README.md)
   for current implementation status, missing evidence, and resume state.
4. [docs/compliance/release-manifest.md](docs/compliance/release-manifest.md)
   before any release/export work.
5. [docs/reverse-engineering/README.md](docs/reverse-engineering/README.md)
   for public-safe reverse-engineering status and boundary rules.
6. [docs/background/README.md](docs/background/README.md)
   for publication-safe research summaries and implementation evidence context.
7. [archive/2026-05-14-plan-remediation-closure/README.md](archive/2026-05-14-plan-remediation-closure/README.md)
   only when the completed 2026-05-13 plan remediation closure must be
   audited.
8. [archive/2026-05-11-doc-condense/README.md](archive/2026-05-11-doc-condense/README.md)
   only when condensed roadmap, source-contract, testing, or compliance docs
   must be traced locally.
9. [archive/2026-05-11-research-archive/README.md](archive/2026-05-11-research-archive/README.md)
   only when archived detailed research matrices or companion files must be
   traced locally.
10. [archive/2026-05-11-plan-remediation/root/PLAN-REMEDIATION-PROGRESS.md](archive/2026-05-11-plan-remediation/root/PLAN-REMEDIATION-PROGRESS.md)
   only when the earlier plan remediation setup ledger must be audited.
11. [archive/2026-05-11-doc-cleanup/README.md](archive/2026-05-11-doc-cleanup/README.md)
   only when the latest superseded active-tree docs must be traced locally.
12. [archive/2026-05-10-superseded-plans-audits-goals/README.md](archive/2026-05-10-superseded-plans-audits-goals/README.md)
   only when superseded plan, audit, goal, or generated-output documents must
   be traced locally.
13. [archive/2026-05-05-workflow-consolidation/MANIFEST.md](archive/2026-05-05-workflow-consolidation/MANIFEST.md)
   when workflow/documentation moves must be traced locally.

## Implemented Surface

- Direct Audio First remains the fastest runtime policy: video and control work
  must degrade before audio latency, playout target, or route verdict changes.
- Balanced AV remains an explicit profile with visible latency cost; it is not
  the default fastest-path claim.
- `direct-p2p-session-run --media audio-video --av-profile fastest` is now a
  distinct source-level Mac-to-Mac AV lane: it requires explicit
  `--input-uid` and `--output-uid` selection, reports direct
  audio-first/direct RX policy, split Core Audio input/output UID evidence,
  selected buffer frames, preview mode, and real AV runtime counters for routed
  audio and video packets. It remains `PARTIAL` until a physical two-Mac run
  proves AV audio timing equals the audio-only fastest baseline.
- `direct-p2p-two-peer-plan-run` now emits the paired responder/initiator AV
  command surface and evidence gates. `DirectPeerSessionReport` can only
  validate `PASS` when physical two-peer measured evidence, packet-capture,
  structured DSCP/clock artifacts, fastest-AV baseline comparison where
  applicable, and nonzero routed media counters are attached.
- `packaging-field-run` now writes concrete packaged permission and entitlement
  artifacts for microphone, camera, local network, and network-client access.
  Packaging `PASS` still requires Developer ID, notarization, Gatekeeper, and
  clean-Mac evidence.
- `recording-session-run` can now opt in to separate raw audio and raw video
  side-lane artifacts. Recording remains off by default, and real-world
  recording closure stays `PARTIAL` until hardware and disk-pressure evidence
  exists.
- LoLa media source code now matches the Linux seed for the corrected audio and
  video packet layout: padded audio UDP payloads, audio fragment frame IDs
  offset from body sequence, Linux video prelude offsets, and full-size raw
  generated video frames. Exact byte facts live in
  [linux_connector/docs/protocol-reference.md](linux_connector/docs/protocol-reference.md)
  and validation context in
  [linux_connector/docs/windows-validation.md](linux_connector/docs/windows-validation.md).
- Swift Windows LoLa probing on 2026-05-15 improved from control-only/unstable
  AV to an observed AV session: Windows LoLa status checks now report the Mac
  Swift responder as running, generated video is visible, and Windows-side audio
  buffer realignment was reduced by roughly 90% after separating Swift live
  audio and video pacing. The compatibility lane remains `PARTIAL`: the latest
  Swift report still times out while decoding zero Windows-originated media
  frames, so inbound media capture and byte-for-byte peer validation are still
  open gates.
- Release Validation Checklist: run `release-hardening-synthetic-smoke`,
  `goal-completion-audit-run`, `open-source-release-readiness-run`, and the
  verification commands below before treating source-level release hardening as
  current.

## Current Blocker Snapshot

Latest local preflight refresh: 2026-05-11.

| Command | Result |
|---|---|
| Source-level audit closure | Historical audit remediation, dedup/refactor resolution, and stale-finding re-scope are closed; full product completion remains blocked by the rows below. |
| `.build/debug/open-lola goal-completion-audit-run --output /private/tmp/open-lola-goal-completion-audit-current.json` | `VERDICT: PARTIAL`; 93 mapped items, 77 pass, 16 partial, 26 blockers. |
| `.build/debug/open-lola goal-runtime-preflight-run --output /private/tmp/open-lola-goal-runtime-preflight-current.json` | `VERDICT: PARTIAL`; 10 runtime deliverables are partial. |
| `.build/debug/open-lola open-source-release-readiness-run --output /private/tmp/open-lola-open-source-release-readiness-current.json` | `VERDICT: PARTIAL`; 9 requirements, 6 blockers. |

Current host evidence: no captured Core Audio devices, no RME MADI candidates,
no video devices, no Blackmagic/ATEM candidates, denied camera permission, one
valid codesigning identity, and no Developer ID Application identity.

## Verification

```bash
PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector
ruff check linux_connector scripts/verify_docs scripts/lib/*.py
python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py
swift test --filter LoLaCompatibilityMediaCodecTests
swift test --filter LoLaCompatibilityMediaSessionTests
bash scripts/verify-docs.sh
shellcheck -x scripts/*.sh scripts/lib/*.sh
bash scripts/verify-release-hygiene.sh
swift build
swift test --no-parallel
bash scripts/verify-release-readiness.sh
```

SwiftPM may need to run outside the sandbox on this Mac when manifest sandboxing
fails with `sandbox-exec: sandbox_apply: Operation not permitted`.

## Release Boundary

The raw checkout is not a release artifact. Release candidates must be staged
with:

```bash
bash scripts/export-release-candidate.sh /path/to/output-parent
```

Public release remains blocked until license, notices, fixture provenance,
public-doc review, implementation audit, reviewer signoff, hardware benchmarks,
signing, notarization, Gatekeeper, and clean-Mac evidence are complete.

The local open-source release preflight writes the current blocker state without
choosing a license or approving publication:

```bash
.build/debug/open-lola open-source-release-readiness-run --output /path/to/open-source-readiness.json
.build/debug/open-lola validate-open-source-release-readiness-report /path/to/open-source-readiness.json
.build/debug/open-lola goal-completion-audit-run --output /path/to/goal-completion-audit.json
.build/debug/open-lola validate-goal-completion-audit-report /path/to/goal-completion-audit.json
```

VERDICT: PARTIAL
