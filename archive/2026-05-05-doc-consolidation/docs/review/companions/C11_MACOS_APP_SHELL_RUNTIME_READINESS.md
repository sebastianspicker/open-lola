# C11 macOS App Shell Runtime Readiness

Date: 2026-05-04  
Status: implemented source-level app-shell milestone  
Priority: P2  
Verdict: PASS for C11 source/tooling scope; product release remains PARTIAL

## Code Evidence

- `Sources/open-lola-app/OpenLolaApp.swift` is a SwiftUI shell using
  the core-owned `NativeAppShellSurfaceContract.releaseReadiness` section and
  action contract.
- `Sources/OpenLolaCore/NativeAppShell.swift` defines the app shell report,
  runtime boundary, configuration snapshot, metrics observer, and smoke
  configuration.
- `Sources/OpenLolaCore/NativeAppShellSurface.swift` defines the C11
  release-readiness surface contract, required section set, read-only actions,
  launch probe plan, and source-level probe report.
- `open-lola native-app-shell-surface-probe` emits a validated C11 source-level
  probe report with `VERDICT: PARTIAL` until a launched app window is observed
  and recorded.
- Tests exist in `NativeAppShellTests.swift`, and a valid fixture exists under
  `Tests/OpenLolaCoreTests/Fixtures/NativeAppShellReports/`.

## Objective

Prepare the app shell for release readiness while preserving the boundary that
SwiftUI does not own realtime audio/video/control lanes.

## Affected Files

- `Sources/open-lola-app/OpenLolaApp.swift`
- `Sources/OpenLolaCore/NativeAppShell.swift`
- `Sources/OpenLolaCore/NativeAppShellSurface.swift`
- `Sources/open-lola/MilestoneCommands.swift`
- `Sources/open-lola/MilestoneValidationCommands.swift`
- `Sources/open-lola/main.swift`
- `Sources/OpenLolaCore/CLICommandInventory.swift`
- `Sources/OpenLolaCore/ReportSchemaInventory.swift`
- `Sources/OpenLolaCore/ReportValidatorSurface.swift`
- `Sources/OpenLolaCore/SourceOwnershipInventory.swift`
- `Tests/OpenLolaCoreTests/NativeAppShellTests.swift`
- `Tests/OpenLolaCoreTests/VerificationToolingContractTests.swift`
- `Tests/OpenLolaCoreTests/Fixtures/NativeAppShellReports/`
- `scripts/verify-release-readiness.sh`
- `scripts/README.md`
- `mac-port/milestones/M13_NATIVE_APP_SHELL.md`

## Implemented Remediation

1. Added a core-owned app surface contract with six required sections:
   overview, configuration, metrics, boundaries, permissions, and launch probe.
2. Removed the app target's private section enum so SwiftUI presents the
   release-readiness surface described by `OpenLolaCore`.
3. Added validation that rejects duplicate sections/actions, hidden realtime
   configuration mutation, realtime start actions, and PASS claims without
   launched-surface evidence.
4. Added a CLI probe and report validator:
   `native-app-shell-surface-probe` and
   `validate-native-app-shell-surface-probe-report`.
5. Added the C11 probe to the release-readiness script used by the local gate
   and future CI.
6. Updated command, report-schema, and source-ownership inventories so C11 is
   visible to future refactor work.

## Acceptance Criteria

| Criterion | Status |
|---|---|
| App shell report proves UI is observer/control shell only. | implemented through `NativeAppShellReport` and `NativeAppShellSurfaceContract` validation |
| Tests cover no realtime ownership by SwiftUI lifecycle. | implemented in `NativeAppShellTests.swift` by checking the app source and surface contract |
| App launch/surface probe exists before UI is called field-ready. | implemented as source-level probe; real launched-window evidence remains a manual/product gate |
| Release packaging gate C09 remains the final app release blocker. | preserved; C11 cannot promote product release to PASS |

## Verification

```bash
swift test --filter NativeAppShellTests
swift test --filter VerificationToolingContractTests
swift test --filter CLICommandInventoryTests
swift test --filter ReportSchemaInventoryTests
swift test --filter SourceOwnershipInventoryTests
.build/debug/open-lola native-app-shell-surface-probe
swift build
swift test
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
bash scripts/verify-release-readiness.sh
```

The C11 source/tooling scope can pass without a GUI session. Product release
readiness still requires a real launched `open-lola-app` window evidence record,
plus C09 signing, notarization, Gatekeeper, and clean-Mac evidence.

## Resume Here

Resume with real launched app evidence: build and launch `open-lola-app` in a
GUI session, record screenshot/log evidence for the six required surface
sections, then feed that evidence into the packaging/signing/clean-Mac gate.

VERDICT: PASS for C11 source/tooling scope; PRODUCT RELEASE VERDICT: PARTIAL
