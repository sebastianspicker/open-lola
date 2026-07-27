# Release Manifest

Date: 2026-07-24
Status: active public release manifest
Verdict: PARTIAL

This manifest prevents the raw checkout from being mistaken for a public
release artifact. Release candidates must be generated from an allowlist, not
published from the raw checkout. This file defines both the version-control
boundary and the release-candidate allowlist.

## Include By Default

Include only these lanes in a curated source release candidate:

- root metadata, community files, and reproducible analysis configuration:
  `.codacy.yaml`,
  `.gitignore`, `.python-version`, `.prospector.yaml`, `Package.swift`, `LICENSE`,
  `THIRD_PARTY_NOTICES.md`, `README.md`, `GOAL.md`, `CONTRIBUTING.md`,
  `SECURITY.md`, `CODE_OF_CONDUCT.md`, `SUPPORT.md`, `CHANGELOG.md`, `RELEASE_STATUS.md`,
  `pyproject.toml`, and `uv.lock`;
- original source and tests: `Sources/**`, `Tests/**`,
  `Tests/OpenLolaCoreTests/Fixtures/**`, after the candidate exporter removes
  uncompiled vendored upstream CI, test, training, demo, and build-system
  folders from the Opus and JPEG XS drops;
- Linux connector source/tests/docs: `linux_connector/**`;
- GitHub trust/verification surface: `.github/ISSUE_TEMPLATE/**`,
  `.github/pull_request_template.md`, `.github/workflows/release-readiness.yml`,
  the canonical Open LoLa SVG/ICNS identity assets, the generated
  `.github/assets/open-lola-social-preview.png`, and the explicitly selected
  offline UI documentation renders
  `.github/assets/open-lola-signal-desk-light.png` and
  `.github/assets/open-lola-signal-desk-dark.png`;
- the public-safe archive boundary summary: `archive/README.md`;
- verification and packaging tooling under `scripts/**`;
- curated public docs: `docs/README.md`, `docs/current-state.md`,
  `docs/product.md`, `docs/design-system.md`,
  `docs/source-contracts.md`, `docs/testing.md`, `docs/release-boundary.md`,
  `docs/release-manifest.md`, `docs/RELEASING.md`, `docs/open-questions.md`,
  `docs/risk-register.md`, `docs/mac-to-mac-connection.md`,
  `docs/reverse-engineering-boundary.md`, `docs/compatibility-scope.md`,
  `docs/validation-methodology.md`, and the technical references explicitly
  listed in `docs/README.md`.

## Repository Tracking Boundary

The following paths are local-only and must not be version-controlled or
force-added. `scripts/verify-tracked-boundary.sh` enforces this rule:

- private evidence and machine-local tool state;
- archive payloads other than the public-safe `archive/README.md` summary;
- research, reverse-engineering, binary, or internal working lanes;
- build products, caches, captures, credentials, and transient reports.

This boundary applies to Git, not only release exports. Product source, tests,
test fixtures, and source-owned commands remain trackable even when their
domain vocabulary includes those words.

The canonical path-level rules live in
`scripts/release-boundary-policy.txt`.

## Exclude By Default

Exclude these lanes from release candidates:

- `.build/**`;
- `.swiftpm/**`;
- `DerivedData/**`;
- `archive/**` except the public boundary summary `archive/README.md`;
- `private/**`;
- `reverse-engineering/**`;
- `research/**`;
- `research/deprecated-research/**`;
- private, internal, and machine-local tool state identified by
  `scripts/release-boundary-policy.txt`;
- `.venv`;
- `venv`;
- `.codacy`;
- top-level `mac-port/**`;
- `docs/review/**`;
- `private/reports/**`;
- `re_out/**`, build outputs, caches, generated packages, Python bytecode
  caches, debug symbols, `__pycache__/**`, `*.py[cod]`, `*.dSYM`,
  `.pytest_cache`, `.ruff_cache`, `.mypy_cache`, `.hypothesis`, `.tox`, `.nox`,
  `.uv-cache`, `*.egg-info`, `pip-wheel-metadata`, `*.xcarchive`,
  `*.xcresult`, `*.app`, `*.pkg`, `*.dmg`;
- uncompiled vendored upstream CI, test, training, demo, and build-system
  material under `Sources/opus-1.5.2/` and `Sources/xs_ref_sw_ed2/` that is not
  selected by `Package.swift`;
- captures, profiling output, and screenshots unless explicitly selected;
- `.DS_Store`, `.vscode`, `.idea`, `.fleet`, `.history`, `.env`, `.env.*`,
  `*.ssn`, `LolaGui.ini`, logs, and temporary files.

## Vendor Fence And Patch Policy

The vendored codec/reference roots are third-party source lanes, not
first-party refactor lanes:

- `COpus` builds from `Sources/opus-1.5.2/` using the exact source list in
  `Package.swift`; open-lola-local code is limited to
  `Sources/opus-1.5.2/openlola_bridge/**`.
- `CJpegXSReference` builds from `Sources/xs_ref_sw_ed2/libjxs` using the
  SwiftPM target declaration. Its `CMakeLists.txt` and `src/msbpack.c` remain in
  the candidate because `Package.swift` names them explicitly in `exclude`; they
  are not compiled.
- Upstream vendor internals are read-only during ordinary maintenance. Any local change
  outside the bridge path requires a maintainer/legal review note, origin or
  patch rationale, notice impact review in `THIRD_PARTY_NOTICES.md`, and a
  release-hygiene update before publication.
- The release exporter starts from a top-level source-root allowlist, strips
  uncompiled upstream CI, tests, training, demos, helper scripts, and
  build-system metadata. For Opus it retains only selected C files, headers,
  `COPYING`, `AUTHORS`, `README`, and `LICENSE_PLEASE_READ.txt`; the hygiene gate
  independently rejects any other Opus file if it reappears.

## Blockers

Release remains `PARTIAL` until:

- source and documentation licenses are final;
- notices match the exact release allowlist;
- the JPEG XS redistribution posture and detailed protocol-documentation
  publication boundary are explicitly approved;
- fixture provenance is signed off;
- clean-room and implementation reviewers approve the source/test/doc surface;
- hardware, benchmark, signing, notarization, Gatekeeper, and clean-Mac evidence
  exists for any runtime/package claim;
- the exact candidate passes release hygiene.

The current checkout remains a dirty integration workspace rather than a named,
immutable candidate. The exporter result is an inspection candidate and cannot
substitute for a clean commit/tag, approval, or release provenance.

The proposed first source-alpha identifier is `v0.1.0-alpha.1`; it is not
currently a tag or published release. See `RELEASE_STATUS.md` and
`docs/RELEASING.md`.

## Verification

Generate and scan a candidate with:

```bash
bash scripts/export-release-candidate.sh /private/tmp/open-lola-release
OPEN_LOLA_RELEASE_CANDIDATE=/private/tmp/open-lola-release/open-lola-source-candidate \
  bash scripts/verify-release-hygiene.sh
```

The exporter requires a clean source checkout. A dirty integration workspace
may be exported only with `OPEN_LOLA_ALLOW_DIRTY_INSPECTION=1`; that output is
marked for inspection and cannot be used as release provenance.

Run the full local wrapper before any publication decision:

```bash
bash scripts/verify-release-readiness.sh
```

VERDICT: PARTIAL
