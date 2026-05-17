# Line-Budget Gate Policy Inventory

Date: 2026-05-17

Remediation slice: `SRP-029`

Source finding: `STC-MC-009`

## Decision

The line-budget rule is an active maintainability gate and should stay
enforced. Its current implementation, `CodeLineBudgetTests`, is useful hygiene
but not runtime or business behavior coverage.

The safest follow-up is to move repository-wide line-budget scanning to a
dedicated deterministic hygiene script, wire that script into release hygiene or
release readiness, and only then remove or narrow the Swift test. Until that
replacement exists, keep the current Swift test active; do not add blanket
exceptions for oversized files just to turn the suite green.

## Current Gate

| Item | Current behavior | Classification |
|---|---|---|
| `Tests/OpenLolaCoreTests/CodeLineBudgetTests.swift` | Swift Testing test scans repository paths and fails on oversized files or stale exceptions | Active hygiene gate, not behavior coverage |
| `scripts/code-line-budget-exceptions.txt` | Exception ledger with only a header row today | Active policy input |
| `swift test --no-parallel` | Runs the line-budget test as part of broad Swift verification | Active enforcement path |
| `scripts/verify-release-readiness.sh` | Runs `swift test --no-parallel`, so it indirectly runs the line-budget gate | Active release-readiness enforcement |
| `scripts/verify-release-hygiene.sh` | Does not currently run a line-budget check | Candidate future owner |

## Current Policy Details

`CodeLineBudgetTests` currently:

- scans `Package.swift`, `Sources`, `Tests`, `scripts`, `script`,
  `linux_connector`, `private`, and `.github`;
- applies 720 lines to Swift, Python, and shell files;
- applies 220 lines to C, header, and PowerShell files;
- applies 120 lines to YAML files and Dockerfiles;
- skips vendored `Sources/opus-1.5.2`, `Sources/xs_ref_sw_ed2`, and
  `__pycache__`;
- reads `scripts/code-line-budget-exceptions.txt`;
- rejects malformed, duplicate, stale, and exceeded exception rows;
- counts physical newline bytes.

## Current Failure State

`swift test --filter CodeLineBudgetTests` currently fails on:

| File | Count | Budget | Classification |
|---|---:|---:|---|
| `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift` | 879 | 720 | High-risk runtime source; needs behavior-backed refactor, not a blind exception |
| `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift` | 859 | 720 | Test-only oversized file; safe candidate for file split |
| `Sources/OpenLolaCore/Video/VideoCaptureAVFoundation.swift` | 745 | 720 | High-risk runtime source; needs behavior-backed refactor, not a blind exception |
| `Sources/open-lola-app/AppExecutionController.swift` | 735 | 720 | User-facing state/controller source; needs behavior-backed extraction, not a blind exception |

## Placement Decision

| Option | Decision | Reason |
|---|---|---|
| Keep current Swift test forever | Not preferred | It makes Swift behavior tests the primary signal for broad repository hygiene and scans scripts, Python, private files, and workflow files from a Swift test target. |
| Delete the rule | Reject | The current gate catches real oversized files and stale exception drift. Removing it would lose an active anti-bloat policy. |
| Add exceptions for the four current failures | Reject for cleanup-only work | This would silence the policy without simplifying or improving the oversized high-risk files. |
| Move scanning to a dedicated script and release hygiene/readiness | Preferred follow-up | A deterministic script is a better owner for repository-wide policy and can be run by CI/release gates outside Swift behavior tests. |
| Narrow Swift test to first-party Swift only | Acceptable fallback | Safer than full deletion, but still keeps hygiene policy inside Swift Testing. |

## Minimum Follow-Up Implementation

A safe implementation slice should:

1. Add a deterministic line-budget verifier, for example a future script named
   "scripts/verify-code-line-budget.py", with the current budgets, scoped paths,
   vendor exclusions, physical line counting, and exception-ledger rules.
2. Add focused verifier tests or fixtures proving oversized first-party files,
   missing exception targets, non-code exception targets, duplicate exception
   rows, and below-budget exception rows fail.
3. Wire the verifier into `scripts/verify-release-hygiene.sh` or directly into
   `scripts/verify-release-readiness.sh`.
4. Update `docs/testing/README.md` and script docs so the line-budget command is
   discoverable outside Swift Testing.
5. Only after the script is verified, remove or narrow
   `CodeLineBudgetTests.swift`.

## Behavior Coverage Required Before Exceptions

If a later slice chooses an exception instead of immediate refactor, it should
prove why the oversized file is still safe:

- `DirectPeerRealtimeAudioGraph.swift`: explicit tests for cleanup failure
  propagation, state transitions, realtime buffer boundaries, and false-success
  prevention.
- `VideoCaptureAVFoundation.swift`: explicit tests for raw capture disabled vs
  failed states, extraction errors, payload accounting, and invalid `PASS`
  evidence rejection.
- `AppExecutionController.swift`: explicit tests for stale report clearing,
  executable-path validation, mode changes, validation failure states, and UI
  truth claims.
- `AppShellBehaviorTests.swift`: no runtime exception needed; split into smaller
  test files when practical.

## Rollback Guidance

If a replacement script misses stale exceptions or oversized owned-source files,
restore the current `CodeLineBudgetTests` implementation until the replacement
has equivalent coverage. The policy should stay visible in release-readiness
output throughout the move.

## Verification

Run before marking this investigation complete:

```bash
swift test --filter CodeLineBudgetTests
bash scripts/verify-docs.sh
```

Expected current result: `swift test --filter CodeLineBudgetTests` fails on the
four oversized files listed above. That failure is the current enforcement
evidence, not a product runtime regression.
