# N05 Source/Test/Doc Crosswalk

Date: 2026-05-04  
Status: implemented through C02 executable inventory  
Priority: P1  
Verdict: PARTIAL

## Objective

Create a crosswalk from each active source group to related tests, fixtures,
docs, runtime role, owner, status, confidence, and refactor risk before moving
source files. C02 implemented this as `SourceOwnershipInventory.swift` and
[../source-ownership-inventory.md](../source-ownership-inventory.md).

## Affected Paths

- `Sources/OpenLolaCore/`
- `Sources/open-lola/`
- `Sources/open-lola-app/`
- `Tests/OpenLolaCoreTests/`
- `Tests/OpenLolaCoreTests/Fixtures/`
- `docs/architecture/`
- `docs/source-contracts/`
- `mac-port/`

## Required Row Fields

| Field | Meaning |
|---|---|
| Source path or group | Exact file or grouped files. |
| Functional category | Audio, video, network, timing, protocol, release, etc. |
| Runtime role | Realtime path, report contract, CLI adapter, UI shell, fixture, or validator. |
| Related tests | Matching test files. |
| Related fixtures | Fixture directories or files. |
| Related docs | Architecture, source contract, milestone, or report docs. |
| Owner | Human/domain owner if known; otherwise `needs human review`. |
| Status | active, partial, stale, generated, external/vendor, unknown. |
| Confidence | confirmed, likely, inferred, unclear, needs human review. |
| Refactor risk | low, medium, high, blocking. |
| Validation | Commands needed after changing this area. |

## Acceptance Criteria

- Every active source group has a row.
- Unclear ownership is labeled `needs human review`.
- Crosswalk identified the first safe source-move batch.
- C02 then executed only the low-risk `Core/` support move; high-risk runtime
  groups remain deferred.

## Validation

```bash
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
```

## Resume Here

Continue source moves only through C02/N07/N08 follow-up batches with
`SourceOwnershipInventoryTests.swift` kept current.

VERDICT: PARTIAL
