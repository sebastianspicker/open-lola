# M09 Prepare Release-Readiness Compliance Checklist

Date: 2026-05-04
Status: dry-run release checklist executed, reviewer signoff pending
Verdict: PARTIAL

## Objective

Turn the compliance review into a release-ready checklist that maintainers can
complete before publishing source, docs, binaries, or packages.

## Scope

Uses M01-M08 outputs, release manifest, license and notice decisions, public
doc review, implementation audit, verification results, and packaging evidence.

## Affected Files

- `docs/compliance/release-compliance-checklist.md`
- `docs/compliance/risk-register.md`
- future release manifest
- final `LICENSE`
- final `THIRD_PARTY_NOTICES.md`
- `README.md`
- `mac-port/milestones/M15_PACKAGING_FIELD_TEST.md`
- release artifacts
- `docs/compliance/release-readiness-checklist-run.md`

## Actions

- Froze release manifest for the M09 dry-run profile.
- Completed the contributor and release checklist as an execution record in
  [release-readiness-checklist-run.md](../release-readiness-checklist-run.md).
- Verified `LICENSE` and `THIRD_PARTY_NOTICES.md` are present, but both remain
  non-final blockers.
- Built `/private/tmp/open-lola-m09-release-candidate.tar.gz` from the allowlist
  recipe and inspected its contents.
- Verified excluded artifacts are absent from the dry-run archive.
- Ran docs, shell, Swift build/test, source-boundary scans, archive scans, and CLI
  surface probes.
- Recorded blockers honestly and kept the final verdict `PARTIAL`.

## Acceptance Criteria

- Checklist is complete or explicitly blocked.
- Release archive contents are inspected.
- Verification results are recorded.
- Remaining risks are accepted or fixed.
- Final verdict is machine-readable.

## Risks

- Verification can pass while release archive contains unsafe files.
- License/notice files can drift from actual contents.
- Hardware/signing evidence may remain unavailable and must keep verdict
  PARTIAL.

## Required Reviewer

Maintainer plus release reviewer.

## Progress Checklist

- [x] Release manifest frozen.
- [x] Checklist completed.
- [x] Release archive inspected.
- [x] License/notice files checked.
- [x] Verification matrix recorded.
- [x] Final verdict recorded.
- [ ] Reviewer signoff recorded.

## Resume Point

Resume by attaching
[release-readiness-checklist-run.md](../release-readiness-checklist-run.md), the
M09 dry-run archive command, and the archive inspection result to the M10 review
packet. Do not publish until reviewer signoff, final license/notices, CQ019
fixture provenance, and M15 signing/clean-Mac evidence are complete.

VERDICT: PARTIAL
