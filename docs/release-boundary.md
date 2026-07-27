# Compliance And Release Boundary

Date: 2026-07-24
Status: active public compliance and repository boundary
Verdict: PARTIAL

Release and compliance docs now live in the flat active docs surface:

| Document | Purpose |
|---|---|
| [release-boundary.md](release-boundary.md) | Compliance summary, active blockers, and reviewer handoff. |
| [release-manifest.md](release-manifest.md) | Include/exclude posture for release candidates. |
| [docs/RELEASING.md](RELEASING.md) | Source-alpha verification, approval, and publication procedure. |
| [../RELEASE_STATUS.md](../RELEASE_STATUS.md) | Proposed candidate identity and current hard stops. |

Only reviewed public documents are version-controlled compliance inputs.

Release remains `PARTIAL` until the active blockers below have current,
reviewed evidence.

## Active Blockers

Public release remains blocked until these are resolved:

- final source license and documentation license;
- finalized third-party notices for the exact release contents;
- a reviewed distribution decision for the evaluation/testing-only JPEG XS
  reference software currently compiled by SwiftPM;
- clean-room/publication review of the detailed compatibility protocol docs;
- No external SwiftPM package dependencies are currently declared; if
  `Package.swift` gains any `.package(...)` entries, update this compliance
  summary and `THIRD_PARTY_NOTICES.md` before release;
- release candidates include `linux_connector/**`,
  `Tests/OpenLolaCoreTests/Fixtures/**`, and active `scripts/**` tooling only
  inside the curated allowlist, and trim uncompiled vendored
  upstream CI/test/training/build-system folders from the Opus and JPEG XS drops
  during export;
- use `scripts/export-release-candidate.sh` to stage candidates and
  `verify-release-hygiene.sh` to scan the exact staged tree;
- fixture provenance and clean-room reviewer signoff;
- legal/maintainer approval for the Open LoLa name, signal-path mark,
  independent-project statement, and attribution;
- maintainer/legal approval for public publication;
- hardware, benchmark, signing, notarization, Gatekeeper, and clean-Mac
  evidence for any product/runtime claims.

Latest local source-alpha refresh, 2026-07-24:

- the workspace built on the available Swift 6.2.4/Xcode 26.3 host;
- all 1,094 Swift tests passed, including socket-backed cases;
- Python 3.11.14 and pytest 8.4.2 from an existing external environment ran
  all 147 pytest cases;
- strict mypy passed for 25 source files with locally installed mypy 2.3.0,
  while CI pins mypy 1.14.1;
- the locked Python environment was not recreated offline because the
  `ruff==0.15.20` wheel was absent from the local cache;
- Ruff 0.16.0 reported 50 lint findings in the dirty checkout;
- documentation, source-documentation, tracked-boundary, release-hygiene,
  brand-asset, and ShellCheck gates passed;
- the proposed `v0.1.0-alpha.1` source candidate remains untagged and
  unpublished.

These are source-shape results. They do not grant public release approval or
establish runtime, hardware, signing, latency, or interoperability readiness.

## Boundary Rules

- The raw checkout is not a release artifact.
- Git must not track private material, archive payloads,
  reverse-engineering/research/binary lanes, local tool state, or transient
  working records.
- `scripts/verify-tracked-boundary.sh` enforces the current index and protects
  against force-added files that `.gitignore` cannot stop by itself.
- Release candidates must be built from an allowlist and scanned for forbidden
  internal, archive, generated, binary, and local-state paths.
- The canonical path-level exclusion list is
  `scripts/release-boundary-policy.txt`. It covers private and local state,
  archives, build products, caches, credentials, captures, package artifacts,
  editor metadata, and uncompiled vendor collateral not selected by
  `Package.swift`.
- Public docs may summarize clean-room architecture, original source behavior,
  public standards, public APIs, and measured evidence. They must not expose
  raw internal reverse-engineering details.

## Vendor Fence And Patch Policy

- `Sources/opus-1.5.2/` and `Sources/xs_ref_sw_ed2/` are third-party lanes,
  not first-party maintenance targets.
- `Package.swift` is the compiled-subset authority: `COpus` lists the selected
  Opus sources and `CJpegXSReference` selects the JPEG XS `libjxs` target.
- The candidate retains `libjxs/CMakeLists.txt` and `libjxs/src/msbpack.c`
  because the JPEG XS target explicitly names them in `exclude`; neither file
  is compiled.
- Open-lola-local vendor code is limited to
  `Sources/opus-1.5.2/openlola_bridge/**` unless a future review explicitly
  records a local upstream patch, notice impact, and release-hygiene update.
- Candidate export starts from an explicit top-level source-root allowlist;
  export and hygiene checks strip or reject upstream CI, tests, training, demo,
  helper-script, and build-system extras. The Opus boundary retains only C
  files selected by `COpus`, headers, and the four required upstream notice
  files.

The curated screenshots under `.github/assets/` are offline documentation
renders only. They may be included in a source candidate with an explicit
caption, but never as bundle-launch, live-media, latency, or interoperability
evidence. The separately named Open LoLa mark, app-icon, and social-preview
assets are identity materials, not product-evidence screenshots.

VERDICT: PARTIAL
