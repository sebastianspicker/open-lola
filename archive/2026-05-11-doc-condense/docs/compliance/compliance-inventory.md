# Compliance Inventory

Date: 2026-05-11
Milestone: [M01 Inventory Compliance-Relevant Files](../../archive/2026-05-05-workflow-consolidation/superseded/docs/compliance/milestones/M01-inventory.md)
Status: M01 filesystem inventory with current fixture and metadata refresh
Verdict: PARTIAL

## Inventory Method

This checkout is not a Git worktree, so the inventory is filesystem-based.
The inventory was built from the current directory with these commands:

```bash
find . \( -path './.build' -o -path './.swiftpm' -o -path './DerivedData' -o -path './.pytest_cache' -o -path './.ruff_cache' -o -path './.mypy_cache' -o -path './dist' -o -path './.build-gap6' \) -prune -o -type f -print | wc -l
find . -name '.DS_Store' -print
find . -maxdepth 1 -type f | sort
find . -maxdepth 2 -type d | sort
find Sources Tests scripts -type f | wc -l
find Sources Tests -type f -name '*.swift' | wc -l
find scripts -type f -name '*.py' | wc -l
find scripts -type f -name '*.sh' | wc -l
find docs -type f -name '*.md' | wc -l
find mac-port -type f -name '*.md' | wc -l
find research reverse-engineering -type f | wc -l
find archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages -type f | wc -l
find archive/2026-05-10-superseded-plans-audits-goals/generated/re_out -type f | wc -l
find archive/2026-05-11-doc-cleanup -type f -name '*.md' | wc -l
find win-compiled -type f | wc -l
find Tests/OpenLolaCoreTests/Fixtures -type f | wc -l
find . -type f \( -name '*.pcap' -o -name '*.pcapng' -o -name '*.wav' -o -name '*.mov' -o -name '*.mp4' -o -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \) | sort
```

## Current Refresh — 2026-05-11

Latest local blocker reports remain partial:

| Report | Result | Inventory impact |
|---|---|---|
| `/private/tmp/open-lola-open-source-release-readiness-current.json` | `VERDICT: PARTIAL`; 9 requirements, 6 blockers. | Final source license, documentation license, notices, fixture provenance, reviewer signoff, and public release approval remain open. |
| `/private/tmp/open-lola-goal-completion-audit-current.json` | `VERDICT: PARTIAL`; 93 mapped items, 77 pass, 16 partial, 26 blockers. | Inventory cleanup is not sufficient for full goal completion. |

Current local refresh corrected the fixture inventory to 56 files: 53 JSON and
3 HEX. Generated `.DS_Store` files found during this refresh were removed, and
`find . -name '.DS_Store' -print` returned no files afterward.

The root checkout also contains local LoLa runtime/session state:
`LolaGui.ini` and `LastSsn.ssn`. These are not public release inputs; they are
now covered by `.gitignore`, the release manifest, and the executable C12
hygiene gate because they can carry private peer addresses and machine-specific
defaults.

## Current Refresh — 2026-05-10

The root `re_out/` generated reverse-engineering output tree was moved to
`archive/2026-05-10-superseded-plans-audits-goals/generated/re_out/`. It is
deprecated internal trace evidence, not an active documentation lane or release
input. Regenerated root `re_out/` output is now ignored locally and rejected by
C12 release hygiene.

## Current Counts

Excluding generated build/cache outputs and local package output, the current
filesystem snapshot contains 1270 files.

| Area | Count | Notes |
|---|---:|---|
| Root files | Public/governance and project manifest files | `.gitignore`, `GOAL.md`, `LICENSE`, `README.md`, `Package.swift`, `pyproject.toml`, `THIRD_PARTY_NOTICES.md`; the root remediation-plan snapshot is archived, and root `LastSsn.ssn` / `LolaGui.ini` were removed as local state. |
| `Sources/`, `Tests/`, `scripts/` | 521 | 419 Swift files, 12 Python verifier files, 21 shell scripts, scripts docs/helpers, and 56 fixture resources. |
| `docs/**/*.md` | 68 | Public docs plus compliance governance docs. |
| `mac-port/**/*.md` | 12 | Active implementation handoff, four domain companions, templates, and current open-question/risk docs. |
| `research/` and `reverse-engineering/` | 19 | Current internal research and reverse-engineering summaries. |
| `archive/2026-05-10-superseded-plans-audits-goals/generated/re_out/` | 201 | Deprecated generated reverse-engineering output moved out of the active root. |
| `archive/2026-05-11-doc-cleanup/` | 5 Markdown files | Deprecated active-tree plan/remediation/milestone snapshots moved out of active docs. |
| `win-compiled/` | 102 | Windows binary/static evidence corpus. |

## Release Posture Legend

| Posture | Meaning |
|---|---|
| Include | Suitable for the curated public source release after normal review. |
| Review | Potentially publishable, but must be checked for claim wording, private data, or license state. |
| Exclude | Do not include in public release artifacts by default. |
| Missing/blocker | Required governance artifact is absent or incomplete. |

## Inventory By Path

| Path | File type / owner lane | Public status | Release posture | Reason |
|---|---|---|---|---|
| `.gitignore` | Repository hygiene | Public-safe | Include | Already excludes build output, local secrets, package artifacts, and `.DS_Store`. |
| `README.md` | Root public entry point | Public-facing | Review | Needs final root license and notice references once M05/M07 complete. |
| Root `LastSsn.ssn`, root `LolaGui.ini` | Local LoLa runtime/session state | Internal/local | Exclude | Can contain private peer addresses and machine-specific defaults; ignored and rejected by C12; absent from the cleaned raw root. |
| `archive/2026-05-05-workflow-consolidation/superseded/root/MAC_PORT_PLAN.md` | Superseded mixed roadmap | Historical/reference | Archive | Replaced by `README.md`, `docs/roadmap/README.md`, and `mac-port/IMPLEMENTATION_COMPANION.md`. |
| `Package.swift` | SwiftPM manifest | Public-safe | Include | No external SwiftPM packages; links Apple frameworks. Final license still pending. |
| `Sources/**` | Original Mac implementation | Public-safe after clean-room review | Include | Open-lola-owned source lane; M08 should confirm no copied proprietary material. |
| `Tests/**/*.swift` | Original tests | Public-safe after clean-room review | Include | Source tests are part of the source release; fixture provenance still needs review. |
| `Tests/OpenLolaCoreTests/Fixtures/**` | JSON and hex fixtures | Needs provenance review | Review | 56 fixture resources; most appear synthetic/PARTIAL, but provenance must be recorded. |
| `scripts/verify-docs.sh` | Verification script | Public-safe | Include | Release documentation gate. |
| `scripts/verify_docs/**` | Python docs verifier | Public-safe with caveat | Include | Verifies internal RE evidence too; acceptable if public release excludes binary corpus or adjusts verifier expectations. |
| `scripts/README.md` | Script documentation | Public-safe | Include | Supports verifier use. |
| `docs/README.md` | Public docs entry point | Public-safe | Include | Already defines public documentation boundary. |
| `docs/current-state.md` | Public state summary | Public-safe | Include | Uses PARTIAL claims and avoids raw RE detail. |
| `docs/architecture/**` | Public architecture docs | Public-safe after M06 | Include | Needs normal public doc review and clean-room evidence labels. |
| `docs/benchmarks/**` | Benchmark methodology | Public-safe after M06 | Include | Needs private data and fixture provenance review. |
| `docs/source-contracts/**` | Public source contracts | Public-safe after M08 | Include | Must remain original open-lola contracts, not legacy packet grammar. |
| `docs/background/**` | Sanitized public research layer | Public-facing | Review | Intended to be public, but M06 must confirm no raw internal evidence leaks. |
| `docs/historical/**` | Historical public snapshots | Historical | Review | May contain stale claims; include only if traceability value justifies review. |
| `docs/compliance/**` | Compliance governance | Public/internal mixed | Review | Useful for governance; legal reviewer decides whether all risk analysis is public. |
| `mac-port/README.md` | Mac port index | Mixed planning | Review | Useful but internal planning references need public export review. |
| `mac-port/IMPLEMENTATION_COMPANION.md` | Implementation handoff | Internal planning | Review | Should not be public release note without M06 review. |
| `mac-port/MILESTONE_INDEX.md` and `mac-port/milestones/**` | Implementation milestones | Mixed planning | Review | Clean-room/license gates should be preserved; hardware claims remain PARTIAL. |
| `mac-port/reports/**` | Active validation/report notes | Evidence reports | Review | Synthetic vs measured, private data, and artifact references need review. |
| `mac-port/historical/**` | Historical roadmap/status/report snapshots | Historical | Review | Stale assumptions possible; include only in curated docs. |
| `mac-port/templates/**` | Handoff templates | Internal planning | Review | Safe after public wording check. |
| `research/RESEARCH_*.md` | Internal research planning | Internal by default | Review | Some may be sanitized later, but default public surface is `docs/background/`. |
| `research/deprecated-research/**` | Deprecated research | Internal | Exclude | Stale and provenance-heavy; do not publish by default. |
| `archive/2026-05-10-superseded-plans-audits-goals/generated/re_out/**` | Deprecated generated RE output | Internal-only | Exclude | Generated strings, disassembly, decompiler output, and reports; do not publish by default. |
| `archive/2026-05-11-doc-cleanup/**` | Deprecated active-tree docs | Historical/reference | Archive | Superseded root plan, remediation ledgers, and old M14 milestone file replaced by current state, testing, and release-manifest docs. |
| `reverse-engineering/README.md` and canonical RE summaries | Internal static evidence | Internal-only | Exclude | May include binary-derived details and internal evidence links. |
| `reverse-engineering/lola-2-windows/**` | Compatibility RE harness | Internal-only | Exclude | Contains compatibility reconstruction and future parser roadmap. |
| `reverse-engineering/deprecated-reverse-engineering/**` | Deprecated RE detail | Internal-only | Exclude | Contains address/function/static-analysis detail. |
| `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/**` | Generated RE package | Internal-only | Exclude | Generated files including machine-readable evidence and analysis tools. |
| `win-compiled/**` | Binary/static evidence corpus | Internal-only | Exclude | 100 Windows/vender artifacts with unclear redistribution rights. |
| `LICENSE` | Project license placeholder | Root governance | Review/blocker | Exists, but grants no final open-source license. Replace before publication. |
| `THIRD_PARTY_NOTICES.md` | Draft notice inventory | Root governance | Review/blocker | Exists, but must be finalized against the release allowlist in M07. |
| Release manifest | Compliance artifact | Created in `docs/compliance/release-manifest.md` | Include/review | Curated release boundary for M02-M10. |

## Binary And Generated Evidence

| Area | Count / contents | Release posture | Action |
|---|---:|---|---|
| `win-compiled/**` | 102 files: 13 `.exe`, 34 `.dll`, 10 `.ini`, 36 `.kcxp`, 7 `.anlg`, 1 `.ssn`, 1 `.txt`. | Exclude | Keep internal until rights are clarified. |
| Installer EXEs under `win-compiled/**` | Included in the 13 `.exe` count. | Exclude | Do not redistribute without permission. |
| `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/**` | Generated internal evidence package. | Exclude | Keep internal-only; do not publish raw strings/hashes/static evidence. |
| `archive/2026-05-10-superseded-plans-audits-goals/generated/re_out/**` | Generated reverse-engineering output formerly at root `re_out/`. | Exclude | Keep archived for traceability only; do not treat as current docs or release input. |
| `archive/2026-05-11-doc-cleanup/**` | Superseded plan/remediation/milestone docs. | Archive | Keep for traceability only; do not treat as current verification authority. |
| Packet captures and media assets | 2 `.png` documentation assets; no `.pcap`, `.pcapng`, `.wav`, `.mov`, `.mp4`, `.jpg`, or `.jpeg` files found. | Review | PNG docs assets live under `linux_connector/docs/assets/` and stay outside the current release allowlist unless separately approved. |
| `.DS_Store` metadata | Original M01 batch plus regenerated files found later; current 2026-05-09 scan returned none after cleanup. | Exclude | `.gitignore` already prevents recurrence. |

## Fixtures And Sample Data

| Path | Count | Current status | Action |
|---|---:|---|---|
| `Tests/OpenLolaCoreTests/Fixtures/**/*.json` | 53 | Appears synthetic or PARTIAL validation data. | Record provenance before release. |
| `Tests/OpenLolaCoreTests/Fixtures/**/*.hex` | 3 | UDP PCM packet fixtures. | Confirm they are original open-lola fixtures, not legacy packet captures. |

## SDK And Standards References

| Area | Current location | Release posture | Action |
|---|---|---|---|
| Apple SDKs | `Package.swift`, `docs/architecture/**`, `mac-port/**` | Include after review | Record Apple SDK agreement state in M05. |
| Blackmagic Desktop Video | `docs/architecture/**`, `mac-port/**` | Review | Keep optional; do not vendor SDK files. |
| RME drivers/TotalMix | `docs/architecture/**`, `mac-port/**` | Review | Treat as user-installed external software. |
| Art-Net/sACN | `docs/architecture/**`, `background/**`, `mac-port/**` | Review | Record standards/version/attribution status before release. |
| Dante/AoIP | `background/**`, `mac-port/**` | Review | Proprietary SDK lanes need legal review before implementation. |

## M01 Remediation Completed

- Created this reproducible compliance inventory.
- Created [release-manifest.md](release-manifest.md) for release include/exclude
  posture.
- Removed four generated `.DS_Store` files in the original M01 pass; removed
  regenerated `.DS_Store` files again during the 2026-05-09 refresh.
- Confirmed `.gitignore` already excludes `.DS_Store`.
- Confirmed no packet captures or audio/video media sample files were present;
  the only matching media files are two `linux_connector/docs/assets/` PNGs.
- Routed unresolved license, release, fixture, generated evidence, and binary
  corpus questions to [open-questions.md](open-questions.md).

## Remaining M01 Limits

M01 cannot reach `PASS` without maintainer/release-compliance reviewer signoff.
It also cannot resolve the final root `LICENSE` and `THIRD_PARTY_NOTICES.md`.
M05 now records placeholders and explicit deferrals, but final text and signoff
remain maintainer/legal decisions for M05/M07.

VERDICT: PARTIAL
