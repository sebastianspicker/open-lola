# CLI Command Inventory

Date: 2026-05-05  
Status: executable C01 inventory implemented with GOAL.md codewise closure commands  
Milestone: C01  
Verdict: PARTIAL

## Purpose

This document summarizes the source-level CLI command ownership inventory added
for C01. The executable source of truth is:

- `Sources/OpenLolaCore/CLICommandInventory.swift`
- `Tests/OpenLolaCoreTests/CLICommandInventoryTests.swift`
- `Sources/open-lola/main.swift`

The user-facing probe is:

```bash
.build/debug/open-lola command-inventory
```

Expected output is machine-readable JSON followed by:

```text
VERDICT: PARTIAL
```

The `PARTIAL` verdict is intentional: this inventory proves command ownership
and validation paths, not real hardware, route, signing, clean-Mac, or benchmark
release readiness.

## Summary

| Scope | Count |
|---|---:|
| Total commands | 119 |
| Validators | 40 |
| Run commands | 27 |
| Synthetic smokes | 29 |
| Localhost smokes | 8 |
| Inventory/probe commands | 15 |

## Owner Map

| Owner source | Responsibility | Commands |
|---|---|---:|
| `Sources/open-lola/main.swift` | top-level session, matrix, report schema inventory, GOAL.md codewise closure, realtime audio path inventory, network route command matrix, command inventory, and one-shot UDP probes | 12 |
| `Sources/open-lola/NetworkCommands.swift` | audio/network inventory, UDP PCM routes, loopback, diagnostics, NAT/rendezvous/relay, direct P2P | 27 |
| `Sources/open-lola/MilestoneValidationCommands.swift` | milestone and GOAL.md report validators | 24 |
| `Sources/open-lola/MilestoneCommands.swift` | milestone runtime commands, synthetic smokes, localhost smokes, probes, hardware/video/control/app/release runs | 45 |
| `Sources/open-lola/MadiReceiveCommands.swift` | MADI receive validation and synthetic smoke | 2 |
| `Sources/open-lola/MadiFullDuplexCommands.swift` | MADI full-duplex validation, synthetic smoke, and run command | 3 |
| `Sources/open-lola/LatencyProfileCommands.swift` | latency profile benchmark synthetic smoke | 1 |
| `Sources/open-lola/PerformanceCommands.swift` | performance audit validation and synthetic smoke | 2 |
| `Sources/open-lola/E2EBenchmarkCommands.swift` | E2E benchmark validation, synthetic smoke, and run command | 3 |

## Test Contract

`CLICommandInventoryTests.swift` verifies:

- command strings discovered from executable command sources match
  `CLICommandInventory.entries`,
- no command is listed twice,
- every owner source file exists,
- every related test file exists,
- parser and validation-path descriptions are non-empty,
- inventory summary counts match entries,
- `OpenLolaCLI.commandInventoryData()` round-trips through JSON.

## Improvement Notes

- The validator decode-validate-print pattern is now centralized through
  `CLICommandHelpers.swift`.
- `MilestoneCommands.swift` no longer owns milestone validators.
- Broader runtime command splitting should happen only after C02 approves source
  movement boundaries. C03 report validator semantics are now covered by
  `ReportValidatorSurface` and `ReportSchemaInventory`.
- The inventory should be updated in the same change as any new command. The
  source-discovery test will fail if a command is added without an inventory
  entry.
- C11 adds `native-app-shell-surface-probe` and
  `validate-native-app-shell-surface-probe-report`; both are indexed here and
  covered by `NativeAppShellTests.swift`.
- GOAL.md codewise closure adds `goal-codewise-closure`,
  `goal-codewise-closure-run`, and `validate-goal-codewise-closure-report`;
  these are covered by `GoalCodewiseClosureTests.swift`.

## Resume Here

C01, C03, C05, C07, C08, C10, C11, and C12 are implemented at the
source/tooling level. Continue with real launched app evidence or release
export candidate scanning.

VERDICT: PARTIAL
