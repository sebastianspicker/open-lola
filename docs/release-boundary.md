# Compliance And Release Boundary

Date: 2026-05-21
Status: condensed active compliance handoff after release-readiness refresh
Verdict: PARTIAL

Release and compliance docs now live in the flat active docs surface:

| Document | Purpose |
|---|---|
| [release-boundary.md](release-boundary.md) | Compliance summary, active blockers, and reviewer handoff. |
| [release-manifest.md](release-manifest.md) | Include/exclude posture for release candidates. |

Detailed M01-M10 ledgers, registers, checklists, and review packets were
superseded and archived under
`../archive/2026-05-11-doc-condense/docs/compliance/`.

## Active Blockers

Public release remains blocked until these are resolved:

- final source license and documentation license;
- finalized third-party notices for the exact release contents;
- No external SwiftPM package dependencies are currently declared; if
  `Package.swift` gains any `.package(...)` entries, update this compliance
  summary and `THIRD_PARTY_NOTICES.md` before release;
- release candidates include `linux_connector/**`,
  `Tests/OpenLolaCoreTests/Fixtures/**`, and the active `script/**` app-bundle
  helper lane only inside the curated allowlist, and trim uncompiled vendored
  upstream CI/test/training/build-system folders from the Opus and JPEG XS drops
  during export;
- use `scripts/export-release-candidate.sh` to stage candidates and
  `verify-release-hygiene.sh` to scan the exact staged tree;
- fixture provenance and clean-room reviewer signoff;
- maintainer/legal approval for public publication;
- hardware, benchmark, signing, notarization, Gatekeeper, and clean-Mac
  evidence for any product/runtime claims.

Latest local release-readiness refresh, 2026-05-21:

- `open-source-release-readiness-run` and
  `validate-open-source-release-readiness-report` passed as source-shape
  commands and remained `VERDICT: PARTIAL`.
- The report contains 9 requirements and 6 blockers: source license,
  documentation license, third-party notices, fixture provenance, reviewer
  signoff, and public release approval.
- Release allowlist, internal-evidence exclusion, and no-external-SwiftPM-
  dependency requirements are finalized in source, but they do not grant public
  release approval.

## Boundary Rules

- The raw checkout is not a release artifact.
- Release candidates must be built from an allowlist and scanned for forbidden
  internal, archive, generated, binary, and local-state paths.
- `.build/**`, `.swiftpm/**`, `DerivedData/**`,
  `archive/2026-05-11-win-compiled/**`,
  `archive/2026-05-11-research-archive/**`, `private/**`,
  `reverse-engineering/**` if the old top-level tree is restored,
  `research/**`, `research/deprecated-research/**`, `archive/**`,
  restored root `plan.md`, `plan-findings-ledger.md`,
  `plan-remediation-ledger.md`, `plan-status.md`,
  `plan-remediation-status.md`,
  `docs/review/**`,
  `private/reports/**`, `re_out/**`, generated outputs, captures,
  package artifacts, Python bytecode caches, `__pycache__/**`, `*.py[cod]`,
  `.pytest_cache`, `.ruff_cache`, `.mypy_cache`, `*.dSYM`, `*.xcarchive`,
  `*.xcresult`, `*.app`, `*.pkg`, `*.dmg`, `.DS_Store`, `.env`, `.env.*`,
  `*.ssn`, `LolaGui.ini`, and uncompiled vendored upstream CI/test/training/
  build-system folders not selected by `Package.swift` are excluded by default.
- Public docs may summarize clean-room architecture, original source behavior,
  public standards, public APIs, and measured evidence. They must not expose
  raw internal reverse-engineering details.

## Vendor Fence And Patch Policy

- `Sources/opus-1.5.2/` and `Sources/xs_ref_sw_ed2/` are third-party lanes,
  not first-party cleanup or refactor targets.
- `Package.swift` is the compiled-subset authority: `COpus` lists the selected
  Opus sources and `CJpegXSReference` selects the JPEG XS `libjxs` target.
- Open-lola-local vendor code is limited to
  `Sources/opus-1.5.2/openlola_bridge/**` unless a future review explicitly
  records a local upstream patch, notice impact, and release-hygiene update.
- Candidate export and hygiene checks strip or reject upstream CI, tests,
  training, demo, and build-system extras that are not part of the selected
  build subset.

## Resume Here

Use [release-manifest.md](release-manifest.md) for the release allowlist and
blocker posture. Reopen archived compliance ledgers only for traceability.

VERDICT: PARTIAL
