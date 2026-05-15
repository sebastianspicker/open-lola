# M06 Review Public Documentation

Date: 2026-05-04
Status: M06 audit snapshot implemented, pending reviewer signoff
Verdict: PARTIAL

## Objective

Audit every public-facing document and publication draft for legal-safe,
clean-room-safe, and technically accurate wording.

## Scope

Review `README.md`, `docs/**`, public-facing slices of `MAC_PORT_PLAN.md`,
selected `mac-port/**`, release notes, diagrams, benchmark docs, and any
publication drafts.

## Affected Files

- `README.md`
- `docs/README.md`
- `docs/current-state.md`
- `docs/architecture/*.md`
- `docs/background/*.md`
- `docs/benchmarks/*.md`
- `docs/source-contracts/*.md`
- `docs/historical/**`
- selected `mac-port/**`
- `docs/compliance/public-doc-review-register.md`
- `docs/compliance/public-link-audit.md`
- `docs/compliance/public-documentation-safety.md`
- `docs/compliance/release-manifest.md`

## Actions

- Classify each doc or tree in the M06 register: publish after final blockers,
  review-only, internal-only, or exclude by default.
- Keep raw RE details out of public docs.
- Keep direct links to internal evidence out of public exports.
- Confirm confidence labels and `PARTIAL` compatibility/performance wording.
- Replace private route examples with documentation placeholders where a report
  may be used as public-facing review material.
- Confirm no private host, route, endpoint, or sample data leaks into the
  curated public docs.
- Ensure architecture-level findings are useful but not proprietary.

## Acceptance Criteria

- Public docs contain no raw static-analysis details.
- Public docs contain no packet dumps, byte maps, payload grammars, or control
  templates.
- Compatibility and performance claims remain `PARTIAL` unless measured.
- Public docs clearly state what open-lola adapted, changed, or improved
  independently.
- Public docs pass the repo documentation verifier and M06 text audits.

## Risks

- Existing public docs can be technically accurate but still unsafe if they
  imply direct reconstruction.
- Historical docs may preserve old assumptions.
- Public benchmark examples may include private machine or route data.

## Required Reviewer

Maintainer plus public documentation reviewer; legal reviewer for compatibility
or SDK claims.

## Progress Checklist

- [x] Public doc list frozen in
      `docs/compliance/public-doc-review-register.md`.
- [x] Each public-release candidate doc or review-only tree classified.
- [x] Raw internal links absent from curated public export surface.
- [x] Confidence labels and `PARTIAL` claim posture checked.
- [x] Private data audit complete for curated public docs and selected
      `mac-port/reports/**` findings.
- [x] Docs verification passed.
- [ ] Reviewer signoff recorded.

## Resume Point

Resume by having the maintainer/public-doc reviewer sign off
[public-doc-review-register.md](../public-doc-review-register.md), then rerun
the M06 audit commands against the exact release manifest before M10.

VERDICT: PARTIAL
