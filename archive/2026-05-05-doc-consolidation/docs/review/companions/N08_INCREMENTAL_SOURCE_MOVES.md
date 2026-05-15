# N08 Incremental Source Moves

Date: 2026-05-04  
Status: future implementation companion; C02 first batch complete  
Priority: P1  
Verdict: PARTIAL

## Objective

Move one source area at a time only after the restructure plan is approved.
C02 has already moved the low-risk `Core/` support batch.

## Current Rule

This companion does not authorize additional source moves now. It exists so a
future implementation pass has a narrow handoff after the C02 first batch.

## Preconditions

- [N07_SOURCE_RESTRUCTURE_PLAN.md](N07_SOURCE_RESTRUCTURE_PLAN.md) is approved.
- The repository is in a Git worktree or another explicit change-tracking
  method is chosen.
- The next batch has a validation matrix and updates
  `SourceOwnershipInventory.swift`.
- User explicitly asks to implement source moves.

## Future Execution Pattern

1. Move one functional batch.
2. Update imports/paths only as needed.
3. Update tests/docs references only for moved paths.
4. Run verification.
5. Stop and report before the next batch.

## Required Validation

```bash
swift build
swift test
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
```

Add a relevant CLI smoke for any moved CLI/runtime path.

## Stop Conditions

- SwiftPM sandboxing blocks build/test and unsandboxed rerun is not approved.
- A move changes runtime behavior.
- A batch touches public/internal boundary docs unexpectedly.
- Git/change tracking is unavailable and the user wants commit-quality proof.

## Resume Here

Resume from the next approved batch in
[N07_SOURCE_RESTRUCTURE_PLAN.md](N07_SOURCE_RESTRUCTURE_PLAN.md).

VERDICT: PARTIAL
