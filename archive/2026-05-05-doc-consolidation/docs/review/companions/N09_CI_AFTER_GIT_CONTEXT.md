# N09 CI After Git Context

Date: 2026-05-04  
Status: C10 workflow exists; live CI read-back pending Git context  
Priority: P1  
Verdict: PARTIAL

## Objective

Read back CI only after this directory is in a Git worktree and
release/publication boundaries are settled.

## Current Finding

`.github/workflows/release-readiness.yml` now exists and runs
`bash scripts/verify-release-readiness.sh`. `git status` still fails because
the directory is not a Git worktree, so live GitHub Actions evidence cannot be
read back from this snapshot.

## Affected Paths

- `.github/workflows/release-readiness.yml`
- `scripts/verify-release-readiness.sh`
- `scripts/verify-docs.sh`
- `Package.swift`
- release/public boundary docs

## Preconditions

- Git worktree exists.
- `docs/review/` boundary is decided.
- Generated output and Windows corpus exclusion policy is documented.
- Local verification commands are green.

## Initial CI Matrix

| Gate | Command |
|---|---|
| Release readiness | `bash scripts/verify-release-readiness.sh` |

Optional later gates should be added only when they can run without private
hardware or secrets.

## Acceptance Criteria

- CI matches local verification through the shared local script.
- CI does not upload or publish `win-compiled/`, `reverse-engineering/`,
  `.build/`, or unreviewed `docs/review/` content.
- Hardware/signing checks remain explicit manual gates unless real CI hardware
  exists.

## Resume Here

After Git context exists, run local verification first, then read back the
GitHub Actions run for `.github/workflows/release-readiness.yml`.

VERDICT: PARTIAL
