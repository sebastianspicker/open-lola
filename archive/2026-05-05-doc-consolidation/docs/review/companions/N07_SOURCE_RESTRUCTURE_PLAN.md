# N07 Source Restructure Plan

Date: 2026-05-04  
Status: C02 first batch complete; remaining plan active  
Priority: P1  
Verdict: PARTIAL

## Objective

Convert [../source-restructure-proposal.md](../source-restructure-proposal.md)
into a reviewed, batchable source move plan after the source/test/doc crosswalk
exists. C02 now supplies the executable crosswalk and has completed the first
low-risk `Core/` support move.

## Affected Paths

- `Sources/OpenLolaCore/`
- `Sources/open-lola/`
- `Sources/open-lola-app/`
- `Tests/OpenLolaCoreTests/`

## Preconditions

- [N05_SOURCE_TEST_DOC_CROSSWALK.md](N05_SOURCE_TEST_DOC_CROSSWALK.md) is complete.
- Each proposed source batch has related tests and validation commands.
- No human review blockers remain for the first batch.

## Proposed Batch Order

| Batch | Candidate area | Risk |
|---|---|---|
| 1 | Core support files. | low, completed in C02 |
| 1b | Protocol files. | medium |
| 2 | Report/evidence validation files. | medium |
| 3 | UDP/network files. | high |
| 4 | Audio/realtime/MADI/RME files. | high |
| 5 | Video/control/integrated AV files. | high |
| 6 | CLI command grouping. | medium |
| 7 | SwiftUI app view split if still needed. | low |

## Acceptance Criteria

- Plan describes one batch at a time.
- Each batch has rollback notes and validation commands.
- Runtime behavior is unchanged.
- No move starts until separately approved.

## Validation For Future Implementation

```bash
swift build
swift test
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
```

## Resume Here

C12 release hygiene is implemented. Use
[N08_INCREMENTAL_SOURCE_MOVES.md](N08_INCREMENTAL_SOURCE_MOVES.md) for the next
explicitly scoped source-move batch.

VERDICT: PARTIAL
