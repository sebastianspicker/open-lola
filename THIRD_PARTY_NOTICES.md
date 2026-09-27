# Third-Party Notices And Attribution

Date: 2026-08-18
Status: active notice inventory; redistribution review remains open
Verdict: PARTIAL

First-party Open LoLa source code and documentation are licensed under the
Apache License, Version 2.0 in `LICENSE`. The distribution attribution and
educational-project statement are in `NOTICE`; the original LoLa licensing and
independent-project boundary are reviewed in `LEGAL.md`.

This inventory does not replace any component's license. Current release
readiness remains `PARTIAL`: the exact third-party notice packet, JPEG XS
distribution decision, fixture provenance, reviewer signoff, and public release
approval remain blocking.

Maintainer decision required: finalize this notice file against the selected
release allowlist, fixture provenance, JPEG XS disposition, and reviewer
signoff before publication.

## Current Package Inventory

`Package.swift` currently declares no external SwiftPM package dependencies.
The source tree vendors the ISO/IEC 21122-5 JPEG XS reference software under
`third_party/jpeg-xs/` for evaluation/testing integration. The SwiftPM targets
link Apple platform frameworks:

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
| Project source and tests | Project-authored SwiftPM source, focused tests, and scripts. | Apache-2.0, except separately identified third-party material. |
| Project documentation | Curated public docs and compliance governance docs. | Apache-2.0, except separately identified third-party material. |
| Generated build outputs | `.build/**`, `.swiftpm/**`, packages, app bundles, archives. | Excluded from source release. |

## Notice Table

| Item | Current repo use | Redistribution posture | Notice action |
|---|---|---|---|
| Apple Core Audio | Linked Apple framework via public SDK API. | Do not redistribute Apple SDK files. Distribution must follow the accepted Apple developer agreements. | Keep SDK note; no copied Apple docs. |
| Apple AVFoundation/CoreMedia | Linked Apple frameworks via public SDK APIs. | Do not redistribute Apple SDK files. Distribution must follow the accepted Apple developer agreements. | Keep SDK note; no copied Apple docs. |
| Swift toolchain/runtime | Build toolchain only; no vendored Swift toolchain files. | Review binary distribution form separately. | Note Swift toolchain license if distributing binaries with embedded runtime pieces. |
| Opus 1.5.2 reference implementation | Vendored C codec under `third_party/opus/` and linked through the `COpus` SwiftPM target for opt-in Direct AV Opus CELT restricted low-delay audio. | Keep the upstream BSD-style copyright notice and disclaimer from `third_party/opus/COPYING` and the patent references in `third_party/opus/LICENSE_PLEASE_READ.txt`; Opus patent/license posture still needs release review before product distribution. | Include both Opus notices and patent review in the final release packet. |
| ISO/IEC 21122-5 JPEG XS reference software, second edition | Vendored C reference codec under `third_party/jpeg-xs/` and linked through the `CJpegXSReference` SwiftPM target for opt-in JPEG XS tests/runtime. | The bundled license grants copyright use for evaluation/testing and conformance work only; it grants no patent license. Distribution or production/commercial use requires separate legal review. | Keep `third_party/jpeg-xs/LICENSE.md`; do not mark JPEG XS as production-cleared. |
| Blackmagic Desktop Video SDK / DeckLink SDK | Optional future adapter; not vendored and not required for default build. | Do not commit or redistribute SDK headers, libraries, samples, installers, or manuals unless terms permit. | Add adapter-specific notice only if SDK-backed code lands. |
| RME drivers and TotalMix FX | User-installed external driver/software for measured hardware runs. | Do not redistribute driver packages, apps, firmware tools, or manuals. | Document user prerequisite and measured driver/version fields. |
| Art-Net | Source-level safety and report models; no physical bridge or fixture claim. | No release-ready product claim until credit and OEM-code disposition are recorded. | Complete attribution review before enabling a distributable implementation. |
| sACN / ANSI E1.31 | Source-level safety and report models; no physical bridge or fixture claim. | Any distributable implementation requires an authorized standards basis and recorded version/terms. | Complete standards and attribution review before enabling a distributable implementation. |
| Dante / Audinate | Optional AoIP lane; no SDK integrated. | No SDK or activation integration without license review. | Add only for the actual licensed integration used. |
| Windows LoLa corpus and bundled vendor binaries | Not version-controlled; any lawfully held evidence remains outside the repository. | Excluded from public release unless rights are documented. | Do not list as redistributable third-party content. |
| Synthetic test fixtures | Local tests and validation fixtures. | Include only after provenance confirmation. | Link fixture provenance in release packet. |

## Vendor Fence And Patch Policy

Vendored codec/reference trees are third-party lanes. `Package.swift` is the
compiled-subset authority for `COpus` and `CJpegXSReference`; the release
exporter retains only the selected Opus C files, headers, and required upstream
notices. The exporter and `tools/release-boundary-policy.txt` define the other
upstream extras stripped from staged candidates.

Open-lola-local vendor code is limited to
`third_party/opus/openlola_bridge/**`. Any future edit to upstream Opus or
JPEG XS files outside that bridge boundary requires maintainer/legal review,
origin or patch rationale, and this notice table to be refreshed before
publication.

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

- Fixture provenance is not confirmed for public release.
- Apple developer agreement state is not recorded for the release account.
- Blackmagic SDK, Art-Net OEM code, sACN/E1.31 version, and Dante scope remain
  reviewer-gated.
- Trademark and product-facing attribution review is not complete.

See `docs/RELEASING.md` for the source-candidate boundary and approval
procedure. Local review packets and planning notes are not version-controlled
release inputs.

VERDICT: PARTIAL
