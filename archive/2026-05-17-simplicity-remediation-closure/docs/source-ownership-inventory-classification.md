# Source Ownership Inventory Classification

Date: 2026-05-17

Source slice: `SRP-026` in `docs/simplicity-remediation-plan.md`

## Decision

`SourceOwnershipInventory` is an active release contract for this checkout, not
docs-only planning data.

Do not move it out of production Swift in a cleanup-only slice. The inventory is
currently part of the executable release-readiness surface through
`source-ownership-inventory`, and it has behavior coverage that would fail if
new source files or high-risk ownership fences drifted.

## Evidence

- `Sources/open-lola/main.swift` registers `source-ownership-inventory` and
  emits `SourceOwnershipInventory.report()` with a `PARTIAL` verdict.
- `scripts/verify-release-readiness.sh` probes `source-ownership-inventory` as
  part of the release-readiness CLI probe set.
- `Tests/OpenLolaCoreTests/MachineReadableSurfaceContractTests.swift` executes
  the command, decodes `SourceOwnershipInventoryReport`, and checks it matches
  `SourceOwnershipInventory.report()`.
- `Tests/OpenLolaCoreTests/SourceOwnershipInventoryTests.swift` verifies that
  every current Swift/C/C header under `Sources/` resolves to an ownership row,
  unknown source areas fail coverage, and exact/directory/proposed-root matches
  remain distinct.
- `SourceOwnershipInventoryTests` also protects the external connector group,
  the C02 core-support move boundary, high-risk runtime deferrals, the vendored
  code fence, and CLI inventory registration.
- `docs/literal-only-test-inventory.md` already classifies the current tests as
  a mix of public docs/inventory hygiene, behavior proxy, and follow-up policy
  work pending this slice.

## Active Contract

Keep these behaviors in source until a replacement release contract exists:

- the CLI command name and machine-readable report shape;
- full `Sources/` coverage for Swift/C/header files;
- no silent fallback ownership for unknown runtime directories;
- separate exact-path, owned-directory, and proposed-root resolution semantics;
- high-risk runtime grouping for realtime audio, network, video, control,
  release, and vendored/reference code;
- the vendored-code fence that keeps upstream internals out of first-party
  refactor ownership;
- validation commands and related test/doc/fixture links used as drift guards.

## Planning Data

These fields are planning/refactor metadata rather than runtime behavior:

- `proposedSourcePath`;
- `firstMoveCandidate`;
- `movedInC02`;
- `owner`;
- `confidence`;
- `improvementRecommendation`.

They can be narrowed or moved only after a follow-up implementation preserves
the active release contract above. The safest follow-up is to split tests into
contract coverage and planning-metadata coverage before deleting or moving any
fields.

## Blocked Or Uncertain Items

- Moving the inventory to docs is blocked by the release-readiness CLI probe and
  executable JSON surface contract.
- Narrowing planning fields is safe only after a focused follow-up proves the
  release script and command output still carry the ownership data they need.
- No runtime behavior needs to change for this investigation slice.

## Follow-Up Slice Shape

If simplification is still desired, do it as a separate implementation slice:

1. Add or keep an executable/release-readiness test that proves
   `source-ownership-inventory` remains present and emits the current contract.
2. Split `SourceOwnershipInventoryTests` into release-contract checks and
   planning-metadata checks.
3. Remove or move only planning fields that are not consumed by the CLI report,
   release-readiness probe, or active coverage tests.
4. Run `swift test --filter SourceOwnershipInventoryTests`,
   `swift test --filter MachineReadableSurfaceContractTests`, and
   `bash scripts/verify-docs.sh`.
