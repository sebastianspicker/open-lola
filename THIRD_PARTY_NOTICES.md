# Third-Party Notices And Attribution

Date: 2026-08-18
Status: active notice inventory; redistribution review remains open
Verdict: PARTIAL

First-party Open LoLa source code and documentation are licensed under the
Apache License, Version 2.0 in `LICENSE`. The distribution attribution and
educational-project statement are in `NOTICE`; the original LoLa licensing and
independent-project boundary are reviewed in `LEGAL.md`.

This inventory does not replace any component's license. The public source
does not redistribute Opus or JPEG XS implementations. Field and binary
distribution claims remain `PARTIAL` pending their own review.

Review this notice file against the selected source tree before any release.

## Current Package Inventory

`Package.swift` currently declares no external SwiftPM package dependencies.
The SwiftPM targets link Apple platform frameworks:

- `AVFoundation`
- `CoreAudio`
- `CoreMedia`

No external SwiftPM package dependencies are currently part of the release
notice scope.

The release-hygiene gate keeps this draft aligned with the package manifest:

```bash
bash tools/verify-release-hygiene.sh
```

## Current Release Notice Scope

| Content class | Current state | Notice posture |
|---|---|---|
| Project source | Project-authored SwiftPM source and packaging scripts. | Apache-2.0, except separately identified third-party material. |
| Project documentation | Curated public docs. | Apache-2.0, except separately identified third-party material. |
| Generated build outputs | `.build/**`, `.swiftpm/**`, packages, app bundles, archives. | Excluded from source release. |

## Notice Table

| Item | Current repo use | Redistribution posture | Notice action |
|---|---|---|---|
| Apple Core Audio | Linked Apple framework via public SDK API. | Do not redistribute Apple SDK files. Distribution must follow the accepted Apple developer agreements. | Keep SDK note; no copied Apple docs. |
| Apple AVFoundation/CoreMedia | Linked Apple frameworks via public SDK APIs. | Do not redistribute Apple SDK files. Distribution must follow the accepted Apple developer agreements. | Keep SDK note; no copied Apple docs. |
| Swift toolchain/runtime | Build toolchain only; no vendored Swift toolchain files. | Review binary distribution form separately. | Note Swift toolchain license if distributing binaries with embedded runtime pieces. |
| Opus 1.5.2 reference implementation | Not bundled or linked in this source tree; Opus selections are unavailable. | An independently supplied implementation needs its own license and patent review. | Review if restored. |
| ISO/IEC 21122-5 JPEG XS reference software, second edition | Not bundled or linked in this source tree; JPEG XS selections are unavailable. | Distribution or production use needs separate legal review. | Review if restored. |
| Blackmagic Desktop Video SDK / DeckLink SDK | Optional future adapter; not vendored and not required for default build. | Do not commit or redistribute SDK headers, libraries, samples, installers, or manuals unless terms permit. | Add adapter-specific notice only if SDK-backed code lands. |
| RME drivers and TotalMix FX | User-installed external driver/software for measured hardware runs. | Do not redistribute driver packages, apps, firmware tools, or manuals. | Document user prerequisite and measured driver/version fields. |
| Art-Net | Source-level safety and report models; no physical bridge or fixture claim. | No release-ready product claim until credit and OEM-code disposition are recorded. | Complete attribution review before enabling a distributable implementation. |
| sACN / ANSI E1.31 | Source-level safety and report models; no physical bridge or fixture claim. | Any distributable implementation requires an authorized standards basis and recorded version/terms. | Complete standards and attribution review before enabling a distributable implementation. |
| Dante / Audinate | Optional AoIP lane; no SDK integrated. | No SDK or activation integration without license review. | Add only for the actual licensed integration used. |
| Windows LoLa corpus and bundled vendor binaries | Not version-controlled; any lawfully held evidence remains outside the repository. | Excluded from public release unless rights are documented. | Do not list as redistributable third-party content. |

## Codec boundary

The public source tree excludes redistributed Opus and JPEG XS code. Adding an
implementation later requires origin and patch rationale, notice review, and
an updated release decision.

## Trademark And Naming Posture

Vendor and standards names in this repository are used for factual compatibility,
hardware-target, or standards-reference discussion. No endorsement or affiliation
is implied. Any product-facing copy should receive a separate trademark and
attribution review before publication.

## Excluded From Public Release By Default

- `archive/**`
- `private/**`
- `reverse-engineering/**` if the old top-level tree is restored
- vendor SDK files or installers
- raw packet captures, media captures, screenshots, private endpoints, venue
  data, secrets, credentials, and unclear sample data
- unsanitized or unapproved runtime reports and evidence bundles

## Open Items

- Apple developer agreement state is not recorded for the release account.
- Blackmagic SDK, Art-Net OEM code, sACN/E1.31 version, and Dante scope remain
  reviewer-gated.
- Trademark and product-facing attribution review is not complete.

See `docs/RELEASING.md` for the source-candidate boundary and approval
procedure. Local review packets and planning notes are not version-controlled
release inputs.

VERDICT: PARTIAL
