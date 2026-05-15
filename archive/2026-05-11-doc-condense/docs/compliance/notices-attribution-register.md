# Notices And Attribution Register

Date: 2026-05-11
Milestone: [M07 Create Notices And Attribution Files](../../archive/2026-05-05-workflow-consolidation/superseded/docs/compliance/milestones/M07-notices-attribution.md)
Status: M07 notice and attribution draft, pending maintainer/legal signoff with current release blockers
Verdict: PARTIAL

## Purpose

This register records the notice and attribution decisions for the current
curated release candidate. It is an engineering compliance artifact, not legal
advice. The root [../../THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md)
file is still a blocking draft until the project license, documentation license,
fixture provenance, release allowlist, and maintainer/legal review are complete.

Latest local refresh: 2026-05-11.

| Report | Result | Notice impact |
|---|---|---|
| `/private/tmp/open-lola-open-source-release-readiness-current.json` | `VERDICT: PARTIAL`; 9 requirements, 6 blockers. | Final notices, source/docs licenses, fixture provenance, reviewer signoff, and public release approval remain blocking. |
| `/private/tmp/open-lola-goal-completion-audit-current.json` | `VERDICT: PARTIAL`; 93 mapped items, 77 pass, 16 partial, 26 blockers. | Notice signoff is necessary for release readiness but not sufficient for full goal completion. |

## Release Notice Scope

| Path or class | Notice posture | Release effect |
|---|---|---|
| `Sources/**`, `Tests/**/*.swift`, `scripts/**`, `Package.swift` | Project-authored source and verification tooling, pending final project license. | Include only after `LICENSE` is final. |
| `README.md`, curated `docs/**` public docs | Project-authored docs, pending final documentation license. | Include only after documentation license is explicit. |
| `Tests/OpenLolaCoreTests/Fixtures/**` | 53 JSON and 3 HEX fixture files, currently described as synthetic/open-lola-generated but awaiting CQ019 confirmation. | Include only after fixture provenance signoff. |
| Apple `AVFoundation`, `CoreAudio`, `CoreMedia` SDK APIs | Linked public Apple platform frameworks; no Apple SDK files are redistributed by source release. | Record Apple SDK agreement state before binary/app distribution. |
| Swift toolchain/runtime | Build toolchain only in source release. | Review separately if binary artifacts embed redistributable runtime pieces. |
| Blackmagic Desktop Video SDK / DeckLink SDK | Optional future adapter only; no SDK headers/libs/samples/manuals are vendored. | Add adapter-specific notice only if SDK-backed code or binary distribution lands. |
| RME drivers, firmware tools, TotalMix FX | User-installed external software for measured hardware runs; not vendored. | Mention as prerequisite only; do not redistribute. |
| Art-Net | Planned lighting protocol lane; no release-ready output claim. | Record credit and OEM-code disposition before product/output release. |
| sACN / ANSI E1.31 | Planned standards-based lighting lane. | Record authorized standards copy/version/terms before implementation or release claim. |
| Dante / Audinate | Optional proprietary AoIP lane; no SDK integrated. | Keep out of release notices unless a licensed integration is approved. |
| `win-compiled/**`, `reverse-engineering/**`, generated evidence packages | Internal evidence or binary/static-analysis corpus. | Exclude by default; do not describe as redistributed third-party content. |
| `mac-port/reports/**` | Evidence reports can contain route context and operator details. | Exclude by default; publish only selected redacted summaries. |

## Attribution Table

| Item | Attribution state | Required M07 action |
|---|---|---|
| open-lola project source | Copyright holder/year range pending. | Replace root `LICENSE` placeholder after maintainer/legal decision. |
| open-lola documentation | Documentation license pending. | Record whether docs share the source license or use a separate docs license. |
| Apple platform frameworks | SDK note recorded; no SDK file redistribution. | Record accepted Apple developer agreement state before signed release. |
| Blackmagic, DeckLink, ATEM, UltraStudio names | Factual hardware/API references only. | Keep no-endorsement posture; add SDK notice only if adapter lands. |
| RME and TotalMix names | Factual user-installed driver/software references only. | Record measured driver/firmware/TotalMix versions in reports, not bundled notices. |
| Art-Net | Attribution and OEM-code decision pending. | Add required product/user-guide credit only after protocol output is implemented and reviewed. |
| sACN/E1.31 | Standards version/access terms pending. | Add standards citation only after authorized copy and terms are recorded. |
| Dante/Audinate | Out of scope until licensed integration path exists. | Do not include activation, license, or SDK behavior in public docs. |
| Test fixtures | Provenance confirmation pending. | Close CQ019 or exclude fixtures from public release. |
| Windows binary/static evidence corpus | Excluded, not redistributed. | Keep out of release archive and notice table except as an exclusion statement. |

## Required Human Decisions

TODO(human): [M07 project license] -> Replace the root LICENSE placeholder with final project license text before notices can become final -> [MIT / Apache-2.0 / BSD-3-Clause / other]

TODO(human): [M07 documentation license] -> Record whether public docs use the source license or a separate documentation license -> [same as source / CC-BY-4.0 / CC-BY-SA-4.0 / other]

TODO(human): [M07 copyright holder] -> Confirm copyright holder and year range for source and docs -> [Sebastian Spicker / institution / project maintainers / other]

TODO(human): [M07 fixture release] -> Confirm all 53 JSON and 3 HEX fixtures are synthetic, open-lola-generated, public-standard, or approved measured data -> [include all confirmed fixtures / exclude unclear fixtures / ship source without fixtures]

TODO(human): [M07 Art-Net disposition] -> Record Art-Net credit and OEM-code status before any Art-Net product/output release -> [not in scope / OEM code requested / OEM code assigned]

TODO(human): [M07 sACN disposition] -> Record authorized sACN/E1.31 standards copy, version, and access terms before implementation or release claims -> [not in scope / ANSI E1.31:2025 reviewed / other authorized version]

## Publication Rule

The root notice file must not imply redistribution rights for excluded internal
evidence. If a public release includes only the curated source/docs allowlist,
the notice packet should state:

- no external SwiftPM packages are declared;
- Apple frameworks are linked through public SDK APIs and Apple SDK files are not
  redistributed;
- optional vendor SDKs are not vendored and are not required for the default
  build;
- drivers and external hardware software are user-installed prerequisites only;
- fixtures are included only after provenance confirmation;
- `win-compiled/**`, `reverse-engineering/**`, generated evidence packages,
  vendor SDK files, captures, private data, and raw reports are excluded.

## Resume Here

When maintainer/legal decisions are available, update this register first, then
replace the root `LICENSE` placeholder and change
[../../THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md) from draft to final
for the exact release allowlist.

VERDICT: PARTIAL
