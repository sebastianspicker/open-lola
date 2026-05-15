# C03 Report Validator Dedup And Evidence Schema

Date: 2026-05-04  
Status: source-level validator surface and schema inventory implemented  
Priority: P1  
Verdict: PARTIAL

## Code Evidence

- C01 already split milestone validators into
  `MilestoneValidationCommands.swift` and centralized fixed-arity validator
  printing through `CLICommandHelpers.swift`.
- C03 now moves the shared validator semantics into
  `Sources/OpenLolaCore/ReportValidatorSurface.swift` so the CLI behavior is
  testable from the core test target.
- C03 now adds `Sources/OpenLolaCore/ReportSchemaInventory.swift`, which maps
  schemas, evidence classes, validators, fixtures, smokes, source files, and
  tests.
- Many source files define report schema and validation behavior:
  `LatencyBenchmarkReport.swift`, `VideoTransportReport.swift`,
  `IntegratedAvReport.swift`, `PackagingFieldTest.swift`,
  `FieldReadyRuntimeProof.swift`, `ReleaseHardening.swift`, and related
  validation files.
- Tests and fixtures exist for many report contracts, but the report family
  index is implicit.

## Objective

Reduce validator duplication and make the evidence/report schema family easier
to extend safely.

## Affected Files

- `Sources/open-lola/MilestoneCommands.swift`
- `Sources/open-lola/NetworkCommands.swift`
- `Sources/open-lola/CLICommandHelpers.swift`
- `Sources/open-lola/MilestoneValidationCommands.swift`
- `Sources/OpenLolaCore/ReportValidatorSurface.swift`
- `Sources/OpenLolaCore/ReportSchemaInventory.swift`
- `Sources/OpenLolaCore/Core/OpenLolaCLI.swift`
- `Tests/OpenLolaCoreTests/ReportSchemaInventoryTests.swift`
- `Sources/OpenLolaCore/*Report*.swift`
- `Sources/OpenLolaCore/*Validation*.swift`
- `Tests/OpenLolaCoreTests/*ReportTests.swift`
- `Tests/OpenLolaCoreTests/Fixtures/**/*.json`

## Improvement Plan

1. Inventory all report validators, report types, fixtures, and command names.
   Done in `ReportSchemaInventory`.
2. Define a minimal shared helper for decode-validate-print if current report
   types can support it without broad protocol churn.
   Done in `ReportValidatorSurface`.
3. Keep report-specific output lines only where they add useful diagnostics.
   Done for `validate-integrated-profile-report` via `aggregate-verdict`.
4. Add tests for shared validator behavior before replacing repeated cases.
   Done in `ReportSchemaInventoryTests`.
5. Document every report schema's evidence class: synthetic, source-level,
   measured, clean-Mac, or external/witnessed.
   Done in source and [../report-schema-inventory.md](../report-schema-inventory.md).

## Implemented Changes

- Added `ReportValidatingArtifact`, `ReportValidatorSurface`, and
  `ReportValidatorConsoleOutput` in `OpenLolaCore`.
- Moved CLI report protocol conformance from the executable target into core
  extensions so report validation formatting is directly testable.
- Kept `Sources/open-lola/CLICommandHelpers.swift` as a thin file-path and
  stdout wrapper around the core validator surface.
- Added `ReportSchemaInventory` with 39 schema/artifact entries and 38 mapped
  validator commands.
- Added the `open-lola report-schema-inventory` CLI command.
- Added `ReportSchemaInventoryTests.swift` for shared validator output,
  strict-failure preservation, CLI validator coverage, fixture/smoke linkage,
  owner/test file existence, summary counts, and JSON round-trip behavior.
- Filled the missing C08 fixture-matrix validator link for
  `LoLaParityDeferredLedgerReport`.

## Current Inventory

| Scope | Count |
|---|---:|
| Report/artifact schemas | 39 |
| Validator commands mapped | 38 |
| Fixture-backed schemas | 28 |
| Schemas requiring measured evidence for PASS | 28 |
| Clean-Mac/release gate schemas | 3 |
| False-PASS regression fixtures | 9 |

## Non-Goals

- Do not collapse distinct report schemas into one generic schema.
- Do not loosen validation to make shared helpers easier.
- Do not claim PASS from synthetic/source-only reports.

## Acceptance Criteria

- Repeated validator boilerplate is reduced. Implemented through the core
  validator surface plus the thin CLI wrapper.
- Report-specific validation remains strict. Verified with a false-PASS release
  hardening fixture.
- Fixture coverage remains at least equivalent. The inventory cross-checks C08
  fixture groups and synthetic smokes.
- CLI output remains stable or intentionally tested. The generic output and
  integrated profile `aggregate-verdict` output are covered.

## Verification

```bash
swift test
swift test --filter ReportSchemaInventory
bash scripts/verify-docs.sh
.build/debug/open-lola report-schema-inventory
.build/debug/open-lola validate-release-hardening-report Tests/OpenLolaCoreTests/Fixtures/ReleaseHardeningReports/valid/release-hardening-partial.json
```

## Resume Here

C03, C05, and C06 are implemented at source level. Continue with
[C07_VIDEO_CONTROL_DEGRADE_FIRST_PATH.md](C07_VIDEO_CONTROL_DEGRADE_FIRST_PATH.md).

VERDICT: PARTIAL
