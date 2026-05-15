# Third-Party Notices Plan

Date: 2026-05-09
Status: M07 notice and attribution packet drafted, final notice packet pending with current blockers
Verdict: PARTIAL

## Current Blocker Overlay

Latest local refresh: 2026-05-09.

| Report | Result | Notice-plan impact |
|---|---|---|
| `/private/tmp/open-lola-open-source-release-readiness-current.json` | `VERDICT: PARTIAL`; 8 requirements, 6 blockers. | This plan remains a draft because final source license, documentation license, notices, fixture provenance, reviewer signoff, and public release approval are still open. |
| `/private/tmp/open-lola-goal-completion-audit-current.json` | `VERDICT: PARTIAL`; 92 mapped items, 76 pass, 16 partial, 26 blockers. | Final notices are necessary for release readiness but do not close runtime/signing/full-goal blockers. |

<!-- TODO(human): [Notice packet approval] -> Approve or revise the final notice format and exact included/excluded content for the selected release allowlist -> [root THIRD_PARTY_NOTICES.md only / NOTICE plus appendix / defer public release] -->

## Recommendation

The root [../../THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md) draft now
contains the M07 notice and attribution scope. Do not treat it as the final
notice packet; it must be finalized after maintainer/legal review and matched to
the exact release allowlist. Use
[notices-attribution-register.md](notices-attribution-register.md) as the M07
decision register.

## Proposed Sections

1. Project license and documentation license.
2. Apple SDK and platform terms note.
3. Public standards and protocol attributions.
4. Optional vendor SDK adapters.
5. Runtime driver/software dependencies.
6. Test fixture provenance.
7. Excluded internal evidence and binary corpus.
8. Binary redistribution restrictions.
9. Trademark/no-endorsement posture for factual vendor references.

## Candidate Notice Rows

| Item | Current status | Notice action |
|---|---|---|
| Apple Core Audio, AVFoundation, CoreMedia | Public SDK APIs linked from SwiftPM target. | Add SDK terms note; do not copy Apple docs. |
| Blackmagic Desktop Video SDK | Optional future adapter, not vendored. | Add only if SDK adapter lands; include version and redistribution status. |
| RME driver/TotalMix | User-installed external software. | State not redistributed; record driver dependency in hardware docs. |
| Art-Net | Planned lighting protocol. | Add required credit and OEM-code disposition if implemented. |
| sACN/E1.31 | Planned standards-based lighting protocol. | Add standards attribution after version review. |
| Dante/Audinate | Optional proprietary AoIP lane. | Add only after license review and only for the integration actually used. |
| Windows LoLa corpus | Internal evidence only. | State excluded from public release; do not add as third-party redistributable content unless rights are confirmed. |
| Synthetic test fixtures | Local generated fixtures. | State generation/provenance or exclude unclear fixtures. |
| mac-port reports | Review-only evidence reports. | Exclude by default unless selected summaries are redacted and approved. |

## Binary Redistribution Policy

Public release artifacts must not include:

- Windows EXE/DLL/installer files from `win-compiled/`;
- vendor SDK headers/libraries/installers;
- packet captures or media samples with unclear rights;
- generated static-analysis outputs;
- private host, route, or venue data.

## Acceptance Criteria

- Root `THIRD_PARTY_NOTICES.md` exists and is clearly marked draft or final for
  the release.
- Every included dependency, SDK, standard, fixture, and binary artifact has a
  row or explicit exclusion.
- Notice file matches the exact release manifest.
- Maintainer/legal reviewer signs off before publication.

## Resume here

Use this plan with [notices-attribution-register.md](notices-attribution-register.md)
to turn the draft notice file into the final release notice packet after M05
license decisions and CQ019 fixture provenance are signed off.

VERDICT: PARTIAL
