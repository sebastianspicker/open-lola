# C01 CLI Command Router And Argument Parsing

Date: 2026-05-04  
Status: source-level command inventory and validator split implemented  
Priority: P1  
Verdict: PARTIAL

## Code Evidence

- `Sources/open-lola/main.swift` dispatches command groups sequentially, owns
  fallback usage text, and still has direct one-off probe/inventory handling.
- `Sources/OpenLolaCore/CLICommandInventory.swift` is now the executable
  command ownership index.
- `Tests/OpenLolaCoreTests/CLICommandInventoryTests.swift` discovers command
  strings from `Sources/open-lola/*.swift` and fails if the inventory drifts
  from executable router sources.
- `Sources/open-lola/MilestoneValidationCommands.swift` now owns milestone
  report validators that were previously embedded in
  `Sources/open-lola/MilestoneCommands.swift`.
- `Sources/open-lola/MilestoneCommands.swift` is reduced to runtime, probe, and
  smoke commands; it no longer owns the milestone validator domain.
- `Sources/open-lola/CLICommandHelpers.swift` centralizes the repeated
  decode-validate-print validator pattern.
- `Sources/open-lola/NetworkCommands.swift`, MADI command files, performance
  commands, and E2E commands use the shared validator helper for fixed-arity
  report validators.
- `Sources/open-lola/MadiFullDuplexCommands.swift` has a local `parseKeyValues`
  helper and typed required-value helpers; deeper parser consolidation remains
  a later C03/C05/C06 concern if duplication is proven.

## Objective

Make CLI command ownership testable and maintainable without changing command
behavior.

## Affected Files

- `Sources/open-lola/main.swift`
- `Sources/open-lola/MilestoneCommands.swift`
- `Sources/open-lola/MilestoneValidationCommands.swift`
- `Sources/open-lola/CLICommandHelpers.swift`
- `Sources/open-lola/NetworkCommands.swift`
- `Sources/open-lola/MadiFullDuplexCommands.swift`
- `Sources/open-lola/MadiReceiveCommands.swift`
- `Sources/open-lola/LatencyProfileCommands.swift`
- `Sources/open-lola/PerformanceCommands.swift`
- `Sources/open-lola/E2EBenchmarkCommands.swift`
- `Sources/OpenLolaCore/CLICommandInventory.swift`
- `Sources/OpenLolaCore/Core/OpenLolaCLI.swift`
- `Tests/OpenLolaCoreTests/CLICommandInventoryTests.swift`
- command-configuration parsers under `Sources/OpenLolaCore/`

## Improvement Plan

1. Inventory every CLI command and map it to owner source, parser, validator,
   output report, smoke command, and test coverage. Done in
   `CLICommandInventory`.
2. Extract duplicated decode-validate-print command cases into a small local
   helper if the crosswalk proves the pattern is consistent. Done in
   `CLICommandHelpers`.
3. Split `MilestoneCommands.swift` into domain command files only after command
   inventory is complete. Done for validator ownership; runtime/smoke command
   splits should stay milestone-specific follow-up work.
4. Keep command names and existing output stable unless a test documents the
   change. Done for the validator helper migration.
5. Add focused command-dispatch tests or CLI smoke tests for high-risk command
   groups. Done for inventory drift and command ownership paths.

## Implemented Changes

- Added `CLICommandInventory`, `CLICommandInventoryEntry`,
  `CLICommandInventorySummary`, and `CLICommandInventoryReport`.
- Added the `open-lola command-inventory` CLI command and `OpenLolaCLI`
  JSON accessors.
- Added `CLICommandInventoryTests.swift` with live source discovery, duplicate
  command detection, owner/test-path existence checks, summary consistency, and
  JSON round-trip coverage.
- Added `MilestoneValidationCommands.swift` and routed milestone validation
  through it before runtime milestone command handling.
- Added `CLICommandHelpers.swift` with `CLIValidatableReport` and
  `validateReport(at:as:label:extraLines:)`.
- Replaced duplicated report decode/validate/verdict printing in milestone,
  network, MADI receive/full-duplex, performance, and E2E validator commands.

## Current Inventory

| Scope | Count |
|---|---:|
| Total commands | 111 |
| Validators | 38 |
| Run commands | 26 |
| Synthetic smokes | 29 |
| Localhost smokes | 8 |
| Inventory/probe commands | 10 |

| Owner source | Commands |
|---|---:|
| `Sources/open-lola/main.swift` | 7 |
| `Sources/open-lola/NetworkCommands.swift` | 27 |
| `Sources/open-lola/MilestoneValidationCommands.swift` | 22 |
| `Sources/open-lola/MilestoneCommands.swift` | 44 |
| MADI, latency profile, performance, and E2E command files | 11 |

## Non-Goals

- Do not add an external command parser package by default.
- Do not redesign the CLI UX.
- Do not change report schema or runtime behavior.

## Acceptance Criteria

- Every command has a documented owner and validation path. Implemented through
  `CLICommandInventory` and verified against executable command sources.
- `MilestoneCommands.swift` no longer owns milestone validators. Runtime/smoke
  commands remain there until a domain-specific source movement milestone is
  approved.
- Shared validation helpers remove repeated decode-validate-print logic across
  command files.
- Existing command output and verdict behavior remain stable for migrated
  validators.

## Verification

```bash
swift build
swift test
swift test --filter CLICommandInventory
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
.build/debug/open-lola command-inventory
.build/debug/open-lola session-capabilities
.build/debug/open-lola release-hardening-synthetic-smoke
```

## Resume Here

C01, C02 first batch, C03, C05, C06, and C07 are implemented at source level.
Keep broader source movement for later C02 follow-up batches after
source/test/doc coverage remains explicit.

VERDICT: PARTIAL
