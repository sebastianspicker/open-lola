# Wording And Structure Audit

Date: 2026-05-05
Status: executed audit for every non-archived Markdown file and every Markdown path in the repository
Verdict: PASS

This audit extends the workflow consolidation pass from file moves into wording,
information, and folder-structure consistency. The checkout is not a Git
worktree, so evidence is filesystem- and command-based.

## Scope

| Surface | Count | Treatment |
|---|---:|---|
| Non-archived Markdown files | 108 | Reviewed as the active reader surface. Wording, metadata, folder references, public/internal links, and duplicate prose were updated where needed. |
| Archived Markdown files | 256 | Checked for classification and duplicate context. Historical wording is preserved unless it breaks active navigation or manifest evidence. |
| Total Markdown files after this audit | 364 | Covered by manifest coverage and link probes. |

## Folder Structure Decisions

| Previous lane | Current lane | Reason |
|---|---|---|
| `docs/research/` | `docs/background/` | Avoids a duplicate public/internal `research` folder name while keeping sanitized public background summaries. |
| `docs/reverse-engineering/README.md` | `docs/compliance/reverse-engineering-boundary.md` | Removes the duplicate public/internal `reverse-engineering` folder name. The top-level `reverse-engineering/` tree remains internal evidence. |
| Top-level `research/` | unchanged | Internal research ledger and evidence matrix; public summaries must be rewritten into `docs/background/`. |
| Top-level `reverse-engineering/` | unchanged | Internal static-evidence lane; public boundary wording moved into compliance. |

## Wording Deduplication Results

| Probe | Result |
|---|---|
| Exact normalized prose duplicates across active files | PASS; zero duplicate prose blocks remain after replacing repeated research-boundary and archive-pointer wording. |
| Near-duplicate active document pairs | PASS; no active document pairs crossed the review threshold. |
| Active metadata consistency | PASS; every non-archived Markdown file now has a heading plus date, status, and verdict metadata. |
| Active relative links | PASS; all relative links across the 108 non-archived Markdown files resolve. |
| Stale public/internal path scan | PASS; no stale `docs/research`, `docs/reverse-engineering`, or removed public RE boundary paths remain in active docs, scripts, Swift path metadata, or tests. |
| Public boundary link scan | PASS; curated public docs do not link directly to raw internal evidence packages, Windows binaries, or root research notes. |
| Source path metadata tests | PASS; `swift test` passed with 767 tests after updating release/export and goal-report path metadata. |

## Manual Improvements Applied

- Replaced the repeated public research boundary sentence with file-specific
  wording in the public background summaries.
- Replaced duplicated archive-pointer prose in the Mac-port companion docs with
  domain-specific audio/network and video/control wording.
- Removed duplicate public/internal folder names by moving public research
  summaries to `docs/background/` and the public reverse-engineering boundary to
  `docs/compliance/reverse-engineering-boundary.md`.
- Updated documentation, release-export allowlists, and source-level path
  metadata to match the new folder layout.
- Added missing status/verdict metadata to active internal research,
  reverse-engineering, Mac-port, template, and scripts Markdown files.

## Archive Treatment

Archive files intentionally preserve historical wording and duplicate snapshots.
Those repetitions are not active reader-surface redundancy. The archive remains
useful for traceability, while active entry points now route to current,
non-duplicative docs.

## Completion Rule

This audit is complete only when the repo-local docs verifier, active-link
probe, duplicate-prose probe, stale-path probe, and release-hygiene/shell checks
all pass on the post-restructure tree.

VERDICT: PASS
