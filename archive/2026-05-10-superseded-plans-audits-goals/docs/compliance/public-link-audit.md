# Public Link Audit

Date: 2026-05-04
Milestone: [M02 Separate Internal RE Notes From Public Docs](../../archive/2026-05-05-workflow-consolidation/superseded/docs/compliance/milestones/M02-internal-vs-public-separation.md)
Status: M02 link audit plus M06 re-audit snapshot, pending reviewer signoff
Verdict: PARTIAL

## Purpose

This file records the M02 audit of public-facing documentation links against
the release boundary in [public-internal-boundary.md](public-internal-boundary.md)
and [release-manifest.md](release-manifest.md).

## Public Surface Audited

The M02 public-link audit checked these public-facing documentation paths:

- `README.md`
- `docs/README.md`
- `docs/current-state.md`
- `docs/architecture/**`
- `docs/benchmarks/**`
- `docs/background/**`
- `docs/source-contracts/**`
- `docs/compliance/**`

Mixed/internal planning paths such as `archive/2026-05-05-workflow-consolidation/superseded/root/MAC_PORT_PLAN.md`, `mac-port/**`,
`docs/historical/**`, root `research/**`, `reverse-engineering/**`, and
`win-compiled/**` are governed by the release manifest and require separate
review before publication.

## Commands

The audit used repository-local text search, not a Git diff, because this
checkout is not a Git worktree in this environment.

```bash
rg -n "\]\(([^)]*reverse-engineering|[^)]*win-compiled|[^)]*background/|[^)]*mac-port/)" README.md docs/README.md docs/current-state.md docs/architecture docs/benchmarks docs/background docs/source-contracts docs/compliance
rg -n "Ghidra|PDB|packet byte maps|proprietary message templates|license/authentication" README.md docs/README.md docs/current-state.md docs/architecture docs/benchmarks docs/background docs/source-contracts
```

## Findings And Remediation

| File/path | Issue | Risk type | Severity | Remediation |
|---|---|---|---|---|
| `README.md` | Root reading order linked directly to root `research/RESEARCH_COMPANION_2026.md`. | Public documentation boundary. | Medium | Rewritten to link to the curated public `docs/background/README.md` lane. |
| `README.md` | Root reading order linked directly to `reverse-engineering/README.md`. | Clean-room and raw evidence exposure. | High | Rewritten to link to `docs/compliance/public-internal-boundary.md` instead. |
| `README.md` | Root reading order linked directly to mixed roadmap and handoff files. | Public release boundary. | Medium | Rewritten to start from curated `docs/**` and compliance manifest links. |
| `docs/README.md` | Link to `background/README.md` resolves to `docs/background/README.md`, not root `research/**`. | Link ambiguity. | Low | Accepted as public-safe; no change required. |
| `docs/current-state.md` | Link to `background/README.md` resolves to `docs/background/README.md`, not root `research/**`. | Link ambiguity. | Low | Accepted as public-safe; no change required. |
| `docs/architecture/clean-room-design-rules.md` | Link to `../background/` resolves to `docs/background/`. | Link ambiguity. | Low | Accepted as public-safe; no change required. |
| `docs/README.md`, `docs/benchmarks/README.md`, `docs/source-contracts/README.md` | Public docs linked directly to review-only `mac-port/**` paths. | Public release boundary. | Medium | Rewritten to point to the compliance release manifest. |
| `archive/2026-05-05-workflow-consolidation/superseded/root/MAC_PORT_PLAN.md`, `mac-port/**`, `docs/historical/**` | Mixed planning files can contain internal links or stale claims. | Public release claim and evidence boundary. | Medium | Keep in "Review Before Including" until M03/M06 sanitization. |

## Raw-Evidence Link Result

After remediation, the default public reading order no longer links readers
directly to root internal research notes, raw reverse-engineering evidence, or
review-only implementation handoff files.

The public docs still mention excluded evidence classes as policy examples.
That is acceptable when the text is about redaction or governance and does not
include raw proprietary content.

## M06 Addendum

The M06 public-documentation review reran the public-link audit against the
curated public surface and found no direct links from public docs into
`reverse-engineering/**`, `win-compiled/**`, root `research/RESEARCH_*.md`, or
`mac-port/**`.

The M06 private-data text audit found address examples only in
`mac-port/reports/**`, which is not part of the curated public docs surface.
Those examples were redacted to TEST-NET documentation addresses, and
`mac-port/reports/**` remains excluded by default unless a selected report is
reviewed as a redacted public summary.

## Remaining Review Items

- Keep `archive/2026-05-05-workflow-consolidation/superseded/root/MAC_PORT_PLAN.md` and `mac-port/**` review-only unless a separate
  public export is approved.
- Review `docs/compliance/**` during M10 before publishing governance material.
- Decide whether root `research/RESEARCH_*.md` receives a sanitized public
  derivative or remains internal-only.
- Inspect the release candidate generated by `scripts/export-release-candidate.sh`
  before any public archive is approved.

## Acceptance Criteria Status

| Criterion | Status |
|---|---|
| Root public reading order avoids direct raw evidence links. | Met. |
| Public docs do not link to `win-compiled/**`. | Met for audited public surface. |
| Public docs do not link to `reverse-engineering/**`. | Met for audited public surface. |
| Public docs do not link directly to review-only `mac-port/**` paths. | Met for audited public surface. |
| Public docs use `docs/background/**` as the curated research lane. | Met. |
| Mixed roadmap and handoff files remain review-only. | Met in manifest. |
| Reviewer signoff exists. | Pending. |

VERDICT: PARTIAL
