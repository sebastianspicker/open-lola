# C12 Artifact Dependency And Generated-Output Hygiene

Date: 2026-05-04  
Status: implemented executable code improvement milestone  
Priority: P0  
Verdict: PASS for C12 hygiene contract; product release readiness remains PARTIAL

## Code Evidence

- `.gitignore` already ignores `.build/`, Swift/Xcode outputs, caches, logs,
  packages, and local secrets.
- `.build/` is still present in the filesystem snapshot and contains local
  SwiftPM generated output.
- `win-compiled/` contains external/vendor Windows binaries, DLLs, installers,
  and camera presets used as static evidence.
- `Package.swift` currently has SwiftPM targets and Apple framework links, with
  no third-party package dependency declarations.
- `scripts/verify-release-hygiene.sh` now enforces the C12 repository policy
  and can scan a staged release candidate with a hard exclusion list.
- `scripts/export-release-candidate.sh` stages the allowlisted source candidate
  outside the raw checkout and runs the C12 candidate scan against it.
- `scripts/verify-release-readiness.sh` now runs the C12 hygiene gate.

## Objective

Prevent generated output, internal reverse-engineering evidence, and external
vendor artifacts from entering a release artifact by accident.

## Affected Files

- `.gitignore`
- `.build/`
- `Package.swift`
- `THIRD_PARTY_NOTICES.md`
- `docs/compliance/release-manifest.md`
- `docs/compliance/dependency-license-review.md`
- `win-compiled/`
- `reverse-engineering/`
- future release/export scripts

## Improvement Plan

1. Implemented `scripts/verify-release-hygiene.sh` to fail on `.build/`, debug
   symbols, build DBs, raw reverse-engineering packages, `docs/review/`, or
   `win-compiled/` in a supplied release candidate.
2. Kept `win-compiled/` as internal static evidence unless legal approval says
   otherwise.
3. Added package-manifest drift checks so dependency and notice docs must stay
   aligned with `Package.swift`.
4. Added explicit default exclusion for `docs/review/**` in release hygiene
   docs and release manifest.
5. Added `scripts/export-release-candidate.sh` as the source candidate staging
   path before archive inspection.
6. Kept generated outputs rebuild-from-source only; no generated output was
   deleted or moved in this implementation.

## Acceptance Criteria

- Release candidate generation has an allowlist or hard exclusion list.
- `.build/` is never treated as source or release output.
- `win-compiled/` and raw `reverse-engineering/` are excluded by default.
- Notices reflect only approved release contents.
- C10 release-readiness verification runs the C12 hygiene gate.

## Verification

```bash
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
bash scripts/export-release-candidate.sh /path/to/output-parent
bash scripts/verify-release-hygiene.sh
swift build
swift test
bash scripts/verify-release-readiness.sh
```

Candidate-directory scanning is run by the export script and remains available
for manually prepared candidates:

```bash
OPEN_LOLA_RELEASE_CANDIDATE=/path/to/release-candidate bash scripts/verify-release-hygiene.sh
```

## Resume Here

Next release work should inspect the staged source candidate, close license and
notice blockers, and record reviewer signoff before any archive is distributed.

VERDICT: PASS
