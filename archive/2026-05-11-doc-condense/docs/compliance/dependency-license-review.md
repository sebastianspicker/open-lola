# Dependency License Review

Date: 2026-05-11
Status: M07 license, dependency, notice, and attribution packet drafted; current release blockers open
Review basis: repository files plus official vendor pages checked 2026-05-04
Verdict: PARTIAL

## Current Release Blocker Overlay

Latest local refresh: 2026-05-11.

| Report | Result | License/dependency impact |
|---|---|---|
| `/private/tmp/open-lola-open-source-release-readiness-current.json` | `VERDICT: PARTIAL`; 9 requirements, 6 blockers. | Final source license, documentation license, third-party notices, fixture provenance, reviewer signoff, and public release approval remain blocking. |
| `/private/tmp/open-lola-goal-completion-audit-current.json` | `VERDICT: PARTIAL`; 93 mapped items, 77 pass, 16 partial, 26 blockers. | License closure would not by itself complete the full project goal while runtime/signing evidence is missing. |

<!-- TODO(human): [License and notices closure] -> Select final source/docs licenses, finalize THIRD_PARTY_NOTICES.md against the release allowlist, and sign off fixture provenance before public release -> [MIT or other permissive license / copyleft license / no public license yet] -->

## Current License State

Root license and notice files now exist, but both are release-blocking draft
artifacts:

| File | M05 state | Release effect |
|---|---|---|
| `LICENSE` | Placeholder only; no final open-source license is granted. | Public release blocked until replaced with selected license text. |
| `THIRD_PARTY_NOTICES.md` | M07 notice and attribution draft only. | Must be marked final only after maintainer/legal signoff against the actual release allowlist. |

Maintainers still need to choose the project source license, decide whether docs
use the same license or a separate documentation license, and confirm that the
public release contains only reviewed original source/docs plus approved fixtures.

## SwiftPM Dependencies

`Package.swift` declares:

| Item | Current state | License concern | Action |
|---|---|---|---|
| External SwiftPM packages | None found in `Package.swift`. | No third-party SwiftPM package notices required today. | Recheck before release. |
| Apple frameworks | `AVFoundation`, `CoreAudio`, `CoreMedia` | Apple SDK terms apply to development/distribution. | Record Apple SDK agreement review. |
| Swift toolchain | Swift 6 package manifest | Toolchain/runtime distribution terms depend on release form. | Review when distributing binaries. |
| Test resources | 53 JSON and 3 hex fixtures | Fixture provenance must be documented. | Label generated/open-lola-owned or exclude. |

No external SwiftPM package dependencies are currently declared in
`Package.swift`.

## C12 Executable Dependency Check

The executable dependency and artifact hygiene gate is:

```bash
bash scripts/verify-release-hygiene.sh
```

The gate fails if `Package.swift` gains a `.package(...)` dependency before
this file and the root `THIRD_PARTY_NOTICES.md` are updated for the exact
release contents. It also verifies that generated output, internal
reverse-engineering evidence, and vendor binary evidence remain excluded by the
release manifest.

## Bundled Binary Artifacts

`win-compiled/` includes Windows application binaries, vendor DLLs, installers,
camera/config payloads, and runtime files. Current release posture:

| Artifact class | Examples | Current action |
|---|---|---|
| LoLa EXE/helpers | GUI, tester, converter, splitter | Internal only unless rights are documented. |
| Vendor DLLs | Microsoft runtime, PortAudio, OpenCV, XIMEA, CUDA, GPUJPEG, IJG/libjpeg | Internal only; license compatibility unknown for redistribution in this repo. |
| Installers | WinPcap, XIMEA API installer | Internal only; do not redistribute in public release without permission. |
| Camera/config payloads | INI, camera payloads, readme files | Internal only until provenance and license are clear. |

## Dependency License Table

| Dependency or technology | Current repo use | Apparent source | Compatibility notes | Notice required |
|---|---|---|---|---|
| Apple Core Audio | Linked framework and public API target | Apple SDK | Allowed only under applicable Apple developer agreements and SDK terms. | SDK notes, not third-party source notice. |
| Apple AVFoundation/CoreMedia | Linked frameworks and public API target | Apple SDK | Same Apple SDK review as above. | SDK notes. |
| Blackmagic Desktop Video SDK | Optional future adapter, not vendored | Blackmagic developer site | SDK download is registration-based; do not vendor headers/libs until terms permit. | Yes if used or redistributed. |
| RME drivers/TotalMix | External installed driver/software, not vendored | RME official downloads/manuals | Treat as user-installed software; do not redistribute driver/app files. | Document driver dependency if required. |
| Art-Net | Planned lighting protocol | Official Art-Net site | Requires credit and OEM-code disposition for implementing products. | Yes for product docs. |
| sACN/E1.31 | Planned lighting protocol | ESTA/ANSI standard | Verify access and standard terms before implementation. | Likely standards attribution. |
| Dante | Optional AoIP lane | Audinate | Proprietary SDK/product licensing; no integration without license review. | Yes if used. |
| OpenCV/IJG/libjpeg/PortAudio/etc. in Windows corpus | Internal static evidence only | Bundled legacy artifacts | Do not treat as open-lola dependencies. | Exclude from public release or notice if rights permit inclusion. |

## Current Release Exclusion Rule

The first public release must be a curated source export. It must exclude
`win-compiled/**`, `reverse-engineering/**`, generated evidence packages, vendor
SDK files, packet captures, media captures, private route data, and unclear
fixtures unless maintainer/legal review explicitly changes that boundary.

## LICENSE Recommendation

Replace the root `LICENSE` placeholder before publication. This review does not
choose a license. The license choice should be maintainer/legal reviewed against:

- open-source publication goals;
- compatibility with future optional SDK adapters;
- whether docs use the same license as code;
- whether benchmarks, fixtures, and reports are redistributable;
- whether internal evidence is excluded from the licensed release.

## THIRD_PARTY_NOTICES Recommendation

Finalize the root `THIRD_PARTY_NOTICES.md` before publication. The current M07
draft and [notices-attribution-register.md](notices-attribution-register.md)
already cover:

- public API/SDK dependency notes;
- optional SDK adapter status;
- standards attribution;
- test fixture provenance;
- excluded internal evidence and binary corpus statement;
- binary redistribution restrictions.
 
They still need maintainer/legal signoff, final license choices, and CQ019
fixture provenance confirmation before they can become final release notices.

## Resume here

Do not publish until M05 and M07 produce a maintainer-approved license and notice
packet. The current root files and May 9 open-source readiness report are
blockers, not final release approval.

VERDICT: PARTIAL
