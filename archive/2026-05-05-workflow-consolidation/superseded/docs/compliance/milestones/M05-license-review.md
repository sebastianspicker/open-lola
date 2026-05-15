# M05 Review Dependencies And SDK Licenses

Date: 2026-05-04
Status: license and SDK review packet drafted, pending maintainer/legal decisions
Verdict: PARTIAL

## Objective

Resolve project license, dependency, SDK, standards, driver, and redistribution
questions before public release or SDK-backed feature work.

## Scope

Review current SwiftPM dependencies, Apple SDK usage, optional Blackmagic SDK
plans, RME driver dependency, Art-Net/sACN lighting work, Dante/AoIP lanes,
Windows binary corpus, fixtures, and documentation licenses.

## Affected Files

- `Package.swift`
- `LICENSE`
- `THIRD_PARTY_NOTICES.md`
- `docs/compliance/dependency-license-review.md`
- `docs/compliance/license-decision-record.md`
- `docs/compliance/sdk-license-notes.md`
- `docs/compliance/third-party-notices-plan.md`
- `docs/compliance/release-manifest.md`
- `docs/compliance/open-questions.md`
- `mac-port/milestones/M07_AVB_PROFESSIONAL_AOIP_EVALUATION.md`
- `mac-port/milestones/M08_GENERIC_VIDEO_CAPTURE_PROBE.md`
- `mac-port/milestones/M12_SACN_ARTNET_FIXTURE_GATE.md`
- `mac-port/milestones/M15_PACKAGING_FIELD_TEST.md`

## Actions

- Record that the project source license is pending maintainer/legal decision.
- Record that the documentation license is pending maintainer/legal decision.
- Decide public release exclusions.
- Record Apple SDK agreement review.
- Record Blackmagic SDK status.
- Record RME driver dependency status.
- Record Art-Net credit/OEM-code status.
- Record sACN/E1.31 standard version and terms.
- Record Dante/Audinate status if in scope.
- Create dependency license table.

## Acceptance Criteria

- Root license file exists and clearly states whether it is final or pending.
- License compatibility is reviewed for current release contents and blockers are
  recorded.
- SDK usage notes are recorded and marked pending maintainer/legal approval.
- Binary redistribution restrictions are documented.
- Open questions CQ001-CQ011 are closed or explicitly deferred.

## Risks

- Publishing without a license blocks legitimate reuse.
- SDK headers/libraries may be committed without redistribution rights.
- Standards or vendor attribution may be omitted.
- Windows binaries may be accidentally included in a source release.

## Required Reviewer

Maintainer/legal reviewer.

## Progress Checklist

- [x] Project license decision recorded as pending, with publication blocked.
- [x] Documentation license decision recorded as pending, with publication
      blocked.
- [x] Apple SDK review recorded.
- [x] Blackmagic SDK review recorded.
- [x] RME driver dependency status recorded.
- [x] Art-Net/sACN status recorded or deferred.
- [x] Dante/AoIP status recorded or deferred.
- [x] Release exclusions recorded.
- [x] Draft third-party notices file created.
- [ ] Reviewer signoff recorded.

## Resume Point

Resume by replacing the root `LICENSE` placeholder with the selected source and
documentation license decision, then finalize `THIRD_PARTY_NOTICES.md` during
M07. Keep public release blocked until reviewer signoff is recorded.

VERDICT: PARTIAL
