# License Decision Record

Date: 2026-05-11
Milestone: [M05 Review Dependencies And SDK Licenses](../../archive/2026-05-05-workflow-consolidation/superseded/docs/compliance/milestones/M05-license-review.md)
Status: decisions explicitly deferred, release blocked by current preflight
Verdict: PARTIAL

## Purpose

This record separates engineering compliance facts from maintainer/legal license
choices. It does not provide legal advice and does not select the final project
license.

## Current Decision State

Latest local refresh: 2026-05-11.

| Current report | Result | Decision impact |
|---|---|---|
| `/private/tmp/open-lola-open-source-release-readiness-current.json` | `VERDICT: PARTIAL`; 9 requirements, 6 blockers. | CQ001, CQ002, CQ005, CQ019, reviewer signoff, and public release approval remain blocking. |
| `/private/tmp/open-lola-goal-completion-audit-current.json` | `VERDICT: PARTIAL`; 93 mapped items, 77 pass, 16 partial, 26 blockers. | Final license decisions are necessary but not sufficient for full product completion. |

<!-- TODO(human): [License decision] -> Choose the final source license, documentation license, fixture release posture, notice format, and binary release posture before publication -> [Source-only curated release / source plus signed app / keep internal-only] -->

| Area | M05 disposition | Release effect |
|---|---|---|
| Source code license | Deferred to maintainer/legal reviewer. Root `LICENSE` now records "license pending" and grants no final open-source license. | Public source release blocked. |
| Documentation license | Deferred to maintainer/legal reviewer. | Public docs release blocked unless covered by the final license packet. |
| Notice format | M07 root `THIRD_PARTY_NOTICES.md` notice and attribution draft exists. | Needs final license choices, fixture provenance, and signoff before publication. |
| Public release shape | Curated allowlist remains the only approved release model. | Raw checkout must not be archived as the release artifact. |
| Internal evidence and Windows corpus | Excluded by default. | No redistribution unless rights are documented. |

## Inventory Basis

- `Package.swift` declares no external SwiftPM package dependencies.
- The package links Apple `AVFoundation`, `CoreAudio`, and `CoreMedia`
  frameworks.
- Local test fixtures currently total 53 JSON files and 3 hex files under
  `Tests/OpenLolaCoreTests/Fixtures/`.
- `win-compiled/**` contains 100 recursively inventoried Windows
  binary/config/static-evidence artifacts and remains internal evidence only.
- Blackmagic Desktop Video SDK, RME drivers/TotalMix, Art-Net, sACN/E1.31, and
  Dante/Audinate are not redistributable open-lola source dependencies today;
  they are SDK, driver, standards, or optional integration review items.

## Decision Options To Review

| Decision | Common options | M05 recommendation |
|---|---|---|
| Source license | MIT, Apache-2.0, BSD-3-Clause, GPL-family, custom/no public license. | Pick only after maintainer/legal review of SDK adapter plans and publication goals. |
| Documentation license | Same as source, CC-BY-4.0, CC-BY-SA-4.0, custom/no public license. | Decide explicitly; do not let docs inherit by assumption. |
| Fixture release | Include confirmed synthetic fixtures, include selected measured fixtures after sanitization, or exclude fixtures from first release. | Keep blocked until CQ019 is closed. |
| Notices | Root `THIRD_PARTY_NOTICES.md`, `NOTICE`, or release packet appendix. | Use root `THIRD_PARTY_NOTICES.md` plus release packet copy. |
| Binary release | Source-only, source plus signed app, or internal-only. | Source-only curated export first; binaries require M15/P05 evidence. |

## CQ001-CQ011 Disposition

| ID | Disposition | Required closure |
|---|---|---|
| CQ001 | Deferred. | Replace root `LICENSE` placeholder with selected source license. |
| CQ002 | Deferred. | Record documentation license in `LICENSE`, README, and notice file. |
| CQ003 | Partially resolved. | Curated allowlist remains the only approved release model; exact archive command remains CQ018. |
| CQ004 | Deferred with default exclusion. | Keep `win-compiled/**` internal-only unless rights are documented. |
| CQ005 | Partially resolved. | M07 notice and attribution draft exists; maintainer/legal signoff must mark it final. |
| CQ006 | Deferred. | Record Apple developer account/agreement state before app/binary distribution. |
| CQ007 | Deferred with default exclusion. | Do not vendor Blackmagic SDK files; adapter requires license review. |
| CQ008 | Deferred with user-installed prerequisite posture. | Record exact RME model, driver, firmware, and TotalMix state in measured reports. |
| CQ009 | Deferred. | Record Art-Net OEM-code disposition before Art-Net product/output release. |
| CQ010 | Deferred. | Record sACN/E1.31 standard version and access terms before implementation/release claim. |
| CQ011 | Deferred. | Keep Dante/Audinate out of scope until licensed integration path is approved. |

## Resume Here

The next maintainer action is to replace the root `LICENSE` placeholder with a
real license decision and update `THIRD_PARTY_NOTICES.md` from M07 draft to final
release notices. Keep publication blocked until CQ001-CQ011 are closed or
explicitly deferred in the M10 review packet, and keep full-goal completion
blocked until the non-license runtime/signing evidence in the May 9 completion
audit is attached.

VERDICT: PARTIAL
