# Compliance And Release Boundary

Date: 2026-08-13
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

Latest B10 local source-alpha proof, 2026-08-13:

- under Xcode 26.6 (17F113) and Swift 6.3.3, the complete serialized suite
  passed 1,660 tests in 8 suites with 0 failures in 172.481 seconds, and a
  separate fresh-scratch TSan run passed 20 tests with no findings;
- the locked primary Python suite passed 307 tests; Ruff 0.15.20, strict mypy
  1.14.1, lock, documentation, source-documentation, localhost connector,
  shell, tracked-boundary, PSScriptAnalyzer, and 5 Pester checks passed;
- the standalone Rust compatibility workspace passed 252 tests with 3
  intentional external-oracle ignores, strict Clippy, formatting, the Windows
  target check, the live Python wire oracle, and both Python-connector
  directions. It is not part of the curated source candidate;
- the B10 allowlisted inspection candidate contains 1,585 regular files with
  aggregate SHA-256
  `80942af4f8f1aaac7f77d521e6d706a18f46466ba36d6fdc373fd30d62ac9fe4`,
  passed candidate hygiene, and remains explicitly `DIRTY_INSPECTION_ONLY` and
  nonpublishable;
- the exact unified readiness wrapper consumed that candidate and exited 0 in
  215.65 seconds. Its source gate passed; product/runtime and overall readiness
  remained `PARTIAL` with six source-release blockers;
- B8-only historical evidence: first-party Semgrep passed. It is not B10
  candidate evidence;
- raw-checkout hygiene remains blocked by preserved user residue and ignored
  `.DS_Store` files. It is noncandidate and non-publishable;
- local app proof passed codesign, Launch Services, process, and visible
  1280x840 checks. Current AX and screenshot checks fail, so this is not
  accessibility or screenshot evidence;
- the proposed `v0.1.0-alpha.1` source candidate remains untagged and
  unpublished.

These are source-shape results. They do not grant public release approval or
establish runtime, hardware, signing, latency, or interoperability readiness.

The first-party licensing surface was updated on 2026-08-18: `LICENSE` applies
Apache-2.0 to first-party source and documentation, while `NOTICE` and
`LEGAL.md` preserve original LoLa attribution, educational-project purpose,
non-affiliation, and third-party boundaries. This closes the prior no-license
blocker only; it does not resolve the remaining blockers above.

## Boundary Rules

- The raw checkout is not a release artifact.
- Git must not track private material, archive payloads,
  reverse-engineering/research/binary lanes, local tool state, or transient
  working records.
- `scripts/verify-tracked-boundary.sh` enforces the current index and protects
  against force-added files that `.gitignore` cannot stop by itself.
- Release candidates must be built from an allowlist and scanned for forbidden
  internal, archive, generated, binary, and local-state paths.
- B10 artifact and evidence writers confine external paths, and codesign I/O is
  bounded. These controls reduce local damage and stalls; they do not supply
  signing identity, notarization, or publication approval.
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
