# Repository Review

Date: 2026-05-04  
Status: documentation-only functional audit  
Scope: current filesystem snapshot, not a Git worktree  
Verdict: PARTIAL

This review maps the current open-lola repository by function and purpose so
future development, reverse engineering, porting, refactoring, testing,
documentation, and cleanup can start from a shared inventory.

This review started as documentation-only. C04 has since been implemented as a
source-level runtime-claim guard, C09 has since been implemented as a
source-level packaging/signing/clean-Mac release gate, C08 has since been
implemented as an executable fixture/CLI smoke matrix, C01 has since been
implemented as an executable CLI command inventory plus validator routing
cleanup, C03 has since been implemented as a shared report-validator surface
plus executable schema/evidence inventory, C06 has since been implemented as an
executable realtime audio path inventory and runtime RX PASS guard, C05 has
since been implemented as an executable network route command matrix plus
NAT-friendly PASS guard, and C07 has since been implemented as an executable
video/control degrade matrix plus stricter integrated-profile and integrated-AV
guards. C02 has since been implemented as an executable source ownership
inventory plus a first behavior-neutral `Sources/OpenLolaCore/Core/` support
split, and C10 has since been implemented as a local/CI release-readiness
parity contract. C11 has since been implemented as a core-owned app-shell
surface contract, SwiftUI presentation update, CLI probe, validator, and
release-readiness probe. C12 has since been implemented as a non-destructive
artifact/dependency/generated-output hygiene gate; high-risk runtime source
moves remain deferred.

## Inspection Basis

Commands used for the live snapshot:

```bash
pwd
git status --short
find . -type d -print
find . -type f -print
find . -path './.build' -prune -o -type f -print
find . -path './.build' -prune -o -type f -print | wc -l
find . -type f -print | wc -l
find . -path './.build' -prune -o -type f -print | awk -F/ '{print $2}' | sort | uniq -c | sort -nr
find . -path './.build' -prune -o -type f -print | awk '{... extension count ...}'
wc -l Sources/OpenLolaCore/*.swift Sources/open-lola/*.swift Sources/open-lola-app/*.swift Tests/OpenLolaCoreTests/*.swift
```

Observed counts at inspection start:

| Scope | Count | Notes |
|---|---:|---|
| Total files | 4599 | Dominated by SwiftPM `.build/` output. |
| Non-`.build` files | 680 | Active source, docs, tests, fixtures, scripts, and Windows evidence corpus. |
| `.build/` files | 3919 | Generated SwiftPM products, modules, object files, debug symbols, and indexes. |
| Swift source/test files | 212 | 148 source files plus 64 test/source-helper files. |
| Markdown files | 299 | Public docs, internal reverse-engineering docs, roadmap, reports, historical snapshots, and this review set after creation. |
| Windows corpus files | 100 | PE executables, DLLs, camera configs, installers, and presets. |

Top-level non-`.build` file distribution at inspection start:

| Top-level area | File count | Primary role |
|---|---:|---|
| `Sources/` | 148 | SwiftPM core library, CLI, and SwiftUI app target. |
| `mac-port/` | 128 | Internal implementation handoff, milestones, reports, templates, and historical port plans. |
| `docs/` | 112 | Publication-safe public docs plus historical public snapshots. |
| `Tests/` | 109 | Swift tests and JSON/HEX fixtures. |
| `win-compiled/` | 100 | Legacy Windows LoLa static evidence corpus. |
| `reverse-engineering/` | 53 | Internal static analysis, generated evidence package, and legacy compatibility notes. |
| `research/` | 13 | Current and deprecated research companion set. |
| `scripts/` | 12 | Documentation and release-readiness verification harness. |

## Reading Order

| Document | Purpose |
|---|---|
| [functional-categorization.md](functional-categorization.md) | Repository overview and functional category map. |
| [file-classification-index.md](file-classification-index.md) | Path-level classification index with status, confidence, and recommendations. |
| [module-responsibility-map.md](module-responsibility-map.md) | Runtime/source component responsibility map and diagrams. |
| [improvement-roadmap.md](improvement-roadmap.md) | Prioritized P0-P3 improvement plan. |
| [cleanup-candidates.md](cleanup-candidates.md) | Cleanup, archive, generated-output, and stale-material candidates. |
| [documentation-restructure-proposal.md](documentation-restructure-proposal.md) | Proposed documentation organization without moving files. |
| [source-restructure-proposal.md](source-restructure-proposal.md) | Proposed Swift/test/tool structure without refactoring. |
| [risk-register.md](risk-register.md) | Severity/likelihood register for repository and artifact risks. |
| [open-questions.md](open-questions.md) | Human decisions and unclear areas. |
| [next-actions.md](next-actions.md) | Concrete next steps for audit closure and implementation planning. |
| [fixture-cli-smoke-matrix.md](fixture-cli-smoke-matrix.md) | C08 human-readable fixture, validator, and CLI smoke matrix. |
| [cli-command-inventory.md](cli-command-inventory.md) | C01 human-readable CLI command ownership inventory. |
| [report-schema-inventory.md](report-schema-inventory.md) | C03 human-readable report schema, validator, fixture, and evidence-class inventory. |
| [realtime-audio-path-inventory.md](realtime-audio-path-inventory.md) | C06 human-readable realtime, near-realtime, report-only, and synthetic-only audio path inventory. |
| [network-route-command-matrix.md](network-route-command-matrix.md) | C05 human-readable network route command, parser, route mode, and evidence-boundary matrix. |
| [video-control-degrade-matrix.md](video-control-degrade-matrix.md) | C07 human-readable video/control degradation, audio-protection, and control-arming matrix. |
| [source-ownership-inventory.md](source-ownership-inventory.md) | C02 human-readable source ownership, test, fixture, and documentation crosswalk. |
| [verification-matrix.md](verification-matrix.md) | C10 local verification, CI parity, release-boundary, and manual gate matrix. |
| [release-artifact-hygiene.md](release-artifact-hygiene.md) | C12 generated-output, dependency, internal-evidence, and candidate-archive hygiene contract. |
| [companions/README.md](companions/README.md) | Companion index; code release-readiness milestones are the primary track. |
| [companions/CODE_RELEASE_READINESS_ROADMAP.md](companions/CODE_RELEASE_READINESS_ROADMAP.md) | Code-quality and release-readiness milestone roadmap. |

## Current Repository Overview

The project is a Mac-native Swift Package Manager workspace for an audio-first,
low-latency networked audio/video system inspired by lessons from the Windows
LoLa artifact corpus. The active package exposes:

- `OpenLolaCore`: reusable Swift core library for audio, network, protocol,
  timing, video, report, validation, and runtime proof contracts.
- `open-lola`: CLI target for validators, synthetic smokes, measurement runs,
  network/P2P commands, MADI paths, latency profiling, release hardening, and
  milestone proof commands.
- `open-lola-app`: SwiftUI shell target that presents the core-owned app-shell
  surface contract, synthetic runtime metrics, configuration boundaries, and
  launch-readiness blocker state.

The repository has a strong evidence and documentation layer:

- `docs/` is the public-facing, publication-safe surface.
- `mac-port/` is review-only implementation handoff material.
- `research/` is the research companion set.
- `reverse-engineering/` is the internal static evidence lane.
- `win-compiled/` is a preserved Windows binary/config corpus for static
  evidence and benchmark context.

The current filesystem is not a Git worktree. Git-based proof, branch hygiene,
and diff review are unavailable until the directory is placed under Git again or
copied into a real worktree.

## Most Important Findings

1. `.build/` exists in the checkout and contains 3919 generated files, including
   build databases, debug binaries, module cache records, object files, debug
   symbols, and index records. It is ignored by `.gitignore`, but it is still
   present in this filesystem snapshot and must be excluded from public export
   and cleanup plans.
2. The active Swift source is functionally broad but physically flat:
   `Sources/OpenLolaCore/` holds broad audio, video, network, timing, protocol,
   report, validation, packaging, and release logic. C02 now isolates only the
   low-risk shared support files under `Sources/OpenLolaCore/Core/`; the
   high-risk runtime groups remain in the original flat area until later
   incremental batches.
3. Documentation is intentionally split by audience, but the split has become
   hard to navigate: public docs, internal implementation handoffs, research,
   reverse engineering, compliance, historical snapshots, and source contracts
   all exist with overlapping milestone language.
4. `win-compiled/` is intentionally preserved as static evidence. It contains
   PE binaries, vendor/runtime DLLs, installers, and camera presets. This is a
   compliance and publication boundary risk unless every export path excludes
   it by default.
5. C10 now adds `.github/workflows/release-readiness.yml`, which runs the same
   local script as maintainers: `bash scripts/verify-release-readiness.sh`.
   Live CI read-back remains unavailable because this filesystem is not a Git
   worktree.
6. C05 now separates direct-route evidence contributors from NAT, relay,
   diagnostics, loopback, packet-only, and direct-P2P partial evidence through
   an executable matrix and strict NAT-friendly PASS guards.
7. C07 now indexes video/control surfaces and tightens integrated profile and
   integrated AV degrade-first tests. Real Blackmagic/ATEM/lighting evidence
   remains `PARTIAL`.
8. C02 now gives future source moves an executable ownership crosswalk and one
   completed low-risk split. Runtime-critical moves must still proceed one
   batch at a time.
9. C10 now gives local and future CI verification a shared non-publishing
   release-readiness entrypoint.
10. C12 now adds `scripts/verify-release-hygiene.sh`, which enforces
    generated-output, internal-evidence, review-doc, vendor-binary, and
    dependency/notice boundaries for release candidates.
11. C11 now adds `NativeAppShellSurface.swift`,
    `native-app-shell-surface-probe`, and the matching validator so UI
    readiness remains read-only/source-level until a real launched app window
    is recorded.
12. The project uses many source-level validators and synthetic smokes, but the
   major runtime claims remain `PARTIAL` until real RME/MADI, direct route,
   Blackmagic/ATEM, lighting, packaging, signing, clean-Mac, and benchmark
   evidence exists.

## Recommended Next Action

Treat this review as the navigation layer for the next implementation tranche.
C01 CLI routing, C02 source ownership, C03 report validator/schema inventory,
C05 network route semantics, C06 realtime audio buffering/latency hardening,
C07 video/control degrade-first hardening, C10 verification parity, and C12
artifact/dependency/generated-output hygiene are now implemented at source
level. C11 app shell runtime readiness is also implemented at source/tooling
level, and `scripts/export-release-candidate.sh` now stages a source candidate
through C12 candidate scanning. The next code-quality action should inspect the
staged candidate, close release-review decisions, or collect real launched app
evidence.

## Highest-Value Improvements

1. Inspect the staged source candidate generated by
   `scripts/export-release-candidate.sh` and record release-review decisions.
2. Read back C10 CI after Git context exists.
3. Classify `docs/review/` as internal-only, public-safe, or release-excluded.
4. Exclude or clean generated `.build/` output before any release/archive work.
5. Resolve `LICENSE` and `THIRD_PARTY_NOTICES.md` before public source or binary
   release.
6. Keep C12 in the release-readiness matrix before public release/export work.
7. Collect launched `open-lola-app` window evidence before describing the UI as
   field-ready.
8. Continue source moves only through C02 follow-up batches with executable
   ownership coverage.
9. Keep hardware, signing, clean-Mac, and benchmark claims at `PARTIAL` until
   real evidence exists.

## Unsafe Or Unclear Items

| Path | Reason human review is needed | Priority |
|---|---|---|
| `docs/review/` | New audit material lives under `docs/` but references internal boundaries and cleanup risks. | P1 |
| `LICENSE` | Pending placeholder, not a final release grant. | P0 |
| `THIRD_PARTY_NOTICES.md` | Draft notice file. | P0 |
| `win-compiled/` | External/vendor Windows binaries, DLLs, installers, and camera configs. | P0 |
| `reverse-engineering/evidence-packages/` | Generated static evidence with internal analysis detail. | P2 |
| `.build/` | Generated local SwiftPM output present in the filesystem. | P0 |
| `.github/workflows/release-readiness.yml` | CI workflow exists locally, but GitHub run status cannot be proven because this is not a Git worktree. | P1 |

## Proposed Next Milestone

Release export or launched app evidence: either create a non-publishing export
script that stages a candidate and runs C12 hygiene, or record real
`open-lola-app` launch evidence before presenting the app target as field-ready.

## Resume Point

Resume at
[companions/CODE_RELEASE_READINESS_ROADMAP.md](companions/CODE_RELEASE_READINESS_ROADMAP.md),
then [release-artifact-hygiene.md](release-artifact-hygiene.md) for release
archive work or
[companions/C11_MACOS_APP_SHELL_RUNTIME_READINESS.md](companions/C11_MACOS_APP_SHELL_RUNTIME_READINESS.md)
for the remaining real app launch evidence gate.

VERDICT: PARTIAL
