# Release Manifest

Date: 2026-05-11
Status: condensed active release manifest after documentation cleanup
Verdict: PARTIAL

This manifest prevents the raw checkout from being mistaken for a public
release artifact. Release candidates must be generated from an allowlist, not
published from the raw checkout. This file defines the active release candidate
posture after the documentation cleanup. Older compliance inventories, review
packets, and checklists are archived under
`../../archive/2026-05-11-doc-condense/docs/compliance/`.

## Include By Default

Include only these lanes in a curated source release candidate:

- root metadata: `.gitignore`, `Package.swift`, `LICENSE`,
  `THIRD_PARTY_NOTICES.md`, `README.md`, `GOAL.md`, `pyproject.toml`;
- original source and tests: `Sources/**`, `Tests/**`,
  `Tests/OpenLolaCoreTests/Fixtures/**`, after the candidate exporter removes
  uncompiled vendored upstream CI, test, training, demo, and build-system
  folders from the Opus and JPEG XS drops;
- Linux connector source/tests/docs: `linux_connector/**`;
- verification tooling: `.github/workflows/release-readiness.yml`,
  `scripts/**`;
- curated public docs: `docs/README.md`, `docs/current-state.md`,
  `docs/roadmap/README.md`, `docs/source-contracts/README.md`,
  `docs/testing/README.md`, `docs/mac-port/README.md`,
  `docs/mac-port/open-questions.md`, `docs/mac-port/risk-register.md`,
  `docs/mac-port/sota-open-question-matrix.md`,
  `docs/reverse-engineering/README.md`, `docs/architecture/**`,
  `docs/benchmarks/**`, `docs/background/**`, `docs/diagrams/**`,
  `docs/compliance/README.md`, and `docs/compliance/release-manifest.md`.

## Exclude By Default

Exclude these lanes unless a future review explicitly changes the boundary:

- `.build/**`;
- `.swiftpm/**`;
- `DerivedData/**`;
- `archive/**`;
- root `plan.md`, `plan-findings-ledger.md`, and `plan-status.md` if restored;
- `private/**`;
- `reverse-engineering/**` if the old top-level tree is restored;
- `archive/2026-05-11-research-archive/**`;
- `research/**`;
- `research/deprecated-research/**`;
- `archive/2026-05-11-win-compiled/**`;
- top-level `mac-port/**` if restored;
- `docs/review/**`;
- `docs/mac-port/reports/**`;
- `re_out/**`, build outputs, caches, generated packages, Python bytecode
  caches, debug symbols, `__pycache__/**`, `*.py[cod]`, `*.dSYM`,
  `.pytest_cache`, `.ruff_cache`, `.mypy_cache`, `*.xcarchive`,
  `*.xcresult`, `*.app`, `*.pkg`, `*.dmg`;
- uncompiled vendored upstream CI, test, training, demo, and build-system
  folders under `Sources/opus-1.5.2/` and `Sources/xs_ref_sw_ed2/` that are
  not selected by `Package.swift`;
- captures, profiling output, screenshots unless explicitly selected;
- `.DS_Store`, `.env`, `.env.*`, `*.ssn`, `LolaGui.ini`, logs, and temporary
  files.

## Vendor Fence And Patch Policy

The vendored codec/reference roots are third-party source lanes, not
first-party refactor lanes:

- `COpus` builds from `Sources/opus-1.5.2/` using the exact source list in
  `Package.swift`; open-lola-local code is limited to
  `Sources/opus-1.5.2/openlola_bridge/**`.
- `CJpegXSReference` builds from `Sources/xs_ref_sw_ed2/libjxs` using the
  SwiftPM target declaration and excludes upstream build files not selected by
  `Package.swift`.
- Upstream vendor internals are read-only for routine cleanup. Any local change
  outside the bridge path requires a maintainer/legal review note, origin or
  patch rationale, notice impact review in `THIRD_PARTY_NOTICES.md`, and a
  release-hygiene update before publication.
- The release exporter strips uncompiled upstream CI, tests, training, demos,
  and build-system metadata from staged candidates; the hygiene gate rejects a
  candidate if those paths reappear.

## Blockers

Release remains `PARTIAL` until:

- source and documentation licenses are final;
- notices match the exact release allowlist;
- fixture provenance is signed off;
- clean-room and implementation reviewers approve the source/test/doc surface;
- hardware, benchmark, signing, notarization, Gatekeeper, and clean-Mac evidence
  exists for any runtime/package claim;
- the exact candidate passes release hygiene.

## Verification

Generate and scan a candidate with:

```bash
bash scripts/export-release-candidate.sh /path/to/output-parent
OPEN_LOLA_RELEASE_CANDIDATE=/path/to/release-candidate bash scripts/verify-release-hygiene.sh
```

Run the full local wrapper before any publication decision:

```bash
bash scripts/verify-release-readiness.sh
```

## Resume Here

Keep this file as the single active release boundary. Do not restore the
archived compliance registers as active release inputs unless the release
process is deliberately expanded.

VERDICT: PARTIAL
