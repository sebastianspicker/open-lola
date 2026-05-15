# M07 Create Notices And Attribution Files

Date: 2026-05-04
Status: M07 notice and attribution draft implemented, pending final license and reviewer signoff
Verdict: PARTIAL

## Objective

Create release-ready attribution and notice files that match the exact public
release contents.

## Scope

Covers source license, docs license, Apple SDK note, optional SDK adapters,
standards attribution, driver prerequisites, fixtures, benchmark data, and
excluded internal evidence.

## Affected Files

- `LICENSE`
- `THIRD_PARTY_NOTICES.md`
- `docs/compliance/third-party-notices-plan.md`
- `docs/compliance/notices-attribution-register.md`
- `docs/compliance/dependency-license-review.md`
- `docs/compliance/release-compliance-checklist.md`
- `docs/compliance/open-questions.md`
- `README.md`
- `docs/compliance/release-manifest.md`

## Actions

- Expand root `THIRD_PARTY_NOTICES.md` from the M05 inventory into an M07 notice
  and attribution draft.
- Record that the root `LICENSE` placeholder cannot be replaced without
  maintainer/legal decision.
- Keep README license/notice references as pending, not final.
- Record documentation license as pending if separate.
- Add notice rows for included dependency, SDK, standards, fixture, and asset
  categories.
- Add SDK and standards attribution gates.
- Add fixture provenance note and CQ019 blocker.
- Add explicit exclusions for internal binary, report, and RE evidence.
- Confirm notice draft matches the current release manifest.

## Acceptance Criteria

- Notice file exists at repo root and is clearly marked draft or final for the
  release.
- Notice file covers every included dependency, SDK, standard, asset, and
  fixture category.
- Notice file does not imply redistribution rights for excluded artifacts.
- README points to license and notices.
- Maintainer/legal review is complete before any notice file is marked final.

## Risks

- Notice file can become misleading if it describes excluded internal evidence
  as redistributable.
- Optional SDK adapters may require separate notices.
- Fixture provenance may remain incomplete.

## Required Reviewer

Maintainer/legal reviewer.

## Progress Checklist

- [x] Draft root notice file created.
- [x] README pending license/notice references added.
- [x] M07 attribution register created.
- [x] Included dependency categories listed.
- [x] Excluded artifacts listed.
- [x] Fixture provenance blocker listed.
- [x] SDK/standards notes listed.
- [ ] Final root notice file approved.
- [ ] README final license/notice references added.
- [ ] Reviewer signoff recorded.

## Resume Point

Resume after M05 final license decisions and CQ019 fixture provenance signoff.
Update [../notices-attribution-register.md](../notices-attribution-register.md),
then mark the root `THIRD_PARTY_NOTICES.md` final only for the exact release
manifest.

VERDICT: PARTIAL
