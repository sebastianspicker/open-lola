# M02 Separate Internal RE Notes From Public Docs

Date: 2026-05-04
Status: implemented boundary draft, pending reviewer signoff
Verdict: PARTIAL

## Objective

Define and enforce the boundary between internal reverse-engineering evidence
and public open-source documentation.

## Scope

Review `reverse-engineering/**`, `research/**`, `docs/**`, `MAC_PORT_PLAN.md`,
`mac-port/**`, and any publication drafts or historical snapshots.

## Affected Files

- `docs/README.md`
- `docs/background/**`
- `docs/architecture/**`
- `docs/historical/**`
- `research/**`
- `reverse-engineering/**`
- `MAC_PORT_PLAN.md`
- `mac-port/**`
- `README.md`
- `docs/compliance/public-internal-boundary.md`
- `docs/compliance/public-link-audit.md`
- `docs/compliance/release-manifest.md`
- `docs/compliance/open-questions.md`

## Actions

- Mark `reverse-engineering/**` as internal-only by default.
- Mark `win-compiled/**` as internal-only by default.
- Use `docs/background/**` as the curated public research lane.
- Keep root `research/RESEARCH_*.md` internal/review-only by default.
- Keep `docs/` as the sanitized publication surface, but review new
  `docs/compliance/` before public export.
- Remove or rewrite public links that point directly to raw evidence.
- Add public-safe summaries where useful.

## Acceptance Criteria

- Public docs do not link to raw internal evidence.
- Public docs contain no generated static-analysis labels, offsets, raw strings,
  packet byte maps, or license/authentication details.
- Internal docs remain available for traceability but cannot be mistaken for
  public documentation.
- Release manifest contains include/exclude rules.
- Public/internal lane map and public-link audit exist under
  `docs/compliance/`.

## Risks

- Roadmap files may still mix public-safe planning with internal links until
  M03 sanitization.
- Historical docs may be copied into release notes without review.
- Compatibility plans may expose raw protocol reconstruction.

## Required Reviewer

Maintainer, compliance reviewer, and legal reviewer for publication boundary.

## Progress Checklist

- [x] Public/internal lane map drafted.
- [x] Public links audited.
- [x] Internal evidence exclusion rule recorded.
- [x] Sanitized summary gaps identified.
- [x] Release manifest updated.
- [ ] Reviewer signoff recorded.

## Resume Point

Resume with M03 by sanitizing `MAC_PORT_PLAN.md`, `mac-port/**`, and
`docs/historical/**` before any of those review-only files are included in a
public export.

VERDICT: PARTIAL
