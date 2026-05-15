# M-REVIEW-02 Source/Test/Doc Crosswalk And Boundary Closure

Date: 2026-05-04  
Status: proposed next milestone  
Verdict: PARTIAL

## Objective

Close the review publication boundary and create a source/test/doc crosswalk
before any source restructuring, cleanup, or CI work.

## Required Inputs

- [../file-classification-index.md](../file-classification-index.md)
- [../module-responsibility-map.md](../module-responsibility-map.md)
- [../source-restructure-proposal.md](../source-restructure-proposal.md)
- [../documentation-restructure-proposal.md](../documentation-restructure-proposal.md)
- [../risk-register.md](../risk-register.md)

## Included Companion Actions

| Action | Companion | Blocking |
|---|---|---|
| Decide review boundary. | [N01_REVIEW_BOUNDARY_DECISION.md](N01_REVIEW_BOUNDARY_DECISION.md) | yes |
| Record release policy. | [N03_RELEASE_MANIFEST_POLICY.md](N03_RELEASE_MANIFEST_POLICY.md) | yes |
| Create source/test/doc crosswalk. | [N05_SOURCE_TEST_DOC_CROSSWALK.md](N05_SOURCE_TEST_DOC_CROSSWALK.md) | yes |
| Separate synthetic and measured evidence. | [N06_MEASURED_EVIDENCE_LEDGER.md](N06_MEASURED_EVIDENCE_LEDGER.md) | yes for PASS claims |
| Plan source restructuring. | [N07_SOURCE_RESTRUCTURE_PLAN.md](N07_SOURCE_RESTRUCTURE_PLAN.md) | yes before source moves |

## Out Of Scope

- moving Swift files,
- changing runtime behavior,
- deleting `.build/`,
- creating CI,
- declaring hardware/signing/benchmark PASS.

## Deliverables

| Deliverable | Proposed location | Status |
|---|---|---|
| Review boundary decision | compliance/release docs or `docs/review/` note | pending |
| Source/test/doc crosswalk | `docs/review/` or future `docs/development/` | pending |
| Evidence ledger policy | `docs/review/` or `docs/benchmarks/` after boundary decision | pending |
| Source restructure batch plan | `docs/review/` | pending |

## Acceptance Criteria

- `docs/review/` has an explicit public/internal/release-exclusion decision.
- Every active source group has related tests, fixtures, docs, runtime role,
  owner, confidence, status, and refactor risk recorded.
- No source moves are proposed without validation commands and rollback notes.
- Hardware/signing/benchmark claims remain `PARTIAL` unless real evidence is
  attached.

## Validation

```bash
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
```

Swift verification becomes required only when source files are changed later:

```bash
swift build
swift test
```

## Resume Here

Start with [N01_REVIEW_BOUNDARY_DECISION.md](N01_REVIEW_BOUNDARY_DECISION.md),
then continue with [N05_SOURCE_TEST_DOC_CROSSWALK.md](N05_SOURCE_TEST_DOC_CROSSWALK.md).

VERDICT: PARTIAL
