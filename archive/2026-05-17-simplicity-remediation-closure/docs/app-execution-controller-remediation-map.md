# AppExecutionController Remediation Map

Date: 2026-05-17

Source slice: `SRP-008` in `docs/simplicity-remediation-plan.md`

Status: investigation only. No production code or tests are changed by this
map.

## Scope

`SRP-008` exists because `AppExecutionController` currently owns command
construction, process lifecycle, validation readiness, report loading, artifact
state, and UI-facing status. The follow-up extraction must be behavior-first and
small enough to review independently.

## Current Responsibilities

- UI state: `armedForExecution`, `status`, `phase`, exit codes, validation exit
  code, elapsed timer state, last error, and error log.
- Settings and paths: mutable `NativeAppShellExecutionSettings`, stdout/stderr
  log paths, supervisor report path, plan path, and external connector report
  path.
- Command construction: direct-peer supervisor and validator commands, Windows
  LoLa session and validator commands, dry-run command preview, and unsupported
  connector rejection.
- Plan artifact writing: `writePlanOrLogError(from:)` writes the two-peer plan
  before direct-peer app execution.
- Process lifecycle: start, dry run, armed start, one-shot validation launch,
  termination handling, stop request, teardown, log-file preparation, process
  handle clearing, and elapsed timer updates.
- Validation readiness: missing report detection, unsupported-mode rejection,
  running-process guard, and UI-facing unavailable messages.
- Validation context: direct-peer vs Windows LoLa execution kind, validator
  arguments, and external connector report path selection.
- Report finalization: `NativeAppShellExecutionReport` construction, validator
  command capture, stop-request reporting, verdict selection, and execution
  notes.
- Runtime evidence loading: direct-peer supervisor metrics, Windows LoLa
  external connector report loading, capture report loading, and validation
  evidence error messages.
- UI helpers: log-file availability, `NSWorkspace` log opening, and derived
  validation evidence through `hasValidatedRuntimeEvidence`.

## Current Callers

- `OpenLolaApp` owns the controller, wires it into the main window/settings
  scene, calls arm, plan write, dry run, start, stop, validate, and teardown on
  background scene phase.
- `AppShellRootView` observes controller state for derived surface refresh,
  session state, status snapshot, elapsed timer, stop action, capture evidence,
  latency metrics, and external connector evidence.
- `AppTransportView` calls arm, dry run, start, stop, validate, readiness, and
  plan writing from the transport strip.
- `AppExecutionView` calls command preview, plan writing, error dismissal, and
  reads settings, running state, paths, last command, last report, and loaded
  connector evidence.
- `AppReportsView` and `AppLogsView` read report/log state and call log-opening
  helpers.
- `AppOperatorReadinessView`, `AppConsoleStatusSnapshot`, and
  `AppValidationRow` consume status, validation exit code, runtime evidence,
  and external connector evidence for UI truth claims.
- `AppShellSettingsView` mutates execution settings and locks execution fields
  while the controller is running.

## Current Tests

- `AppShellBehaviorTests` covers app session-state derivation, stop-request
  report timing, validation launch failure, validation evidence for missing,
  malformed, partial, failed, and passing direct-peer/Windows LoLa reports, and
  hosted footer validation status.
- `AppShellSlice05Tests` covers validation readiness for missing direct-peer and
  Windows LoLa report artifacts, unsupported app modes, command-preview
  rejection for unsupported modes, settings lock help text, and workflow mode
  state.
- `NativeAppShellSurfaceActionTests` covers release-readiness action metadata
  for external realtime launch boundaries.
- `NativeAppShellTests` and `NativeAppShellWindowsLoLaTests` cover lower-level
  direct-peer and Windows LoLa command argument contracts outside the app
  controller.

## Missing Or Weak Tests Before Extraction

- Mode-switch stale evidence: validation or launch after switching between
  direct-peer and Windows LoLa must clear stale `lastLatencyMetrics`,
  `lastCaptureReport`, and `lastExternalConnectorReport`.
- Validator command provenance: the last app execution report should record the
  validator command for direct-peer and Windows LoLa modes without falling back
  to a stale executable path.
- Validation context boundaries: unsupported connector modes should not leave a
  stale execution kind or report path that can affect the next validation.
- Process cleanup evidence: process close/termination cleanup warnings are
  outside `SRP-008` and belong to `SRP-013`, but controller tests should still
  assert that report finalization waits for termination.
- Log opening failure: `NSWorkspace` open failure is only observable through
  controller error state and is not directly covered.
- Executable path verification: unverified path handling is outside `SRP-008`
  and belongs to `SRP-011`; do not mix that behavior into the first extraction.

## Smallest Follow-Up Extraction Target

Target: validation-evidence loading and verdict projection.

Concrete behavior to protect: a validator exit code of `0` must not make the app
claim `Validation passed`, `Report validated`, or report verdict `PASS` unless
the current direct-peer supervisor report or current Windows LoLa external
connector report was loaded and validated for the active execution kind.

Rationale:

- This is the narrowest high-risk responsibility currently spanning
  `finishValidation(exitCode:)`, `finishReport(...)`,
  `executionReportVerdict(...)`, `validationEvidenceErrorMessage()`,
  `refreshExternalConnectorReport()`, and `refreshCaptureReport()`.
- The behavior already has meaningful tests in `AppShellBehaviorTests`, so a
  follow-up extraction can be guarded before and after the move.
- It should reuse or extend the existing `AppRuntimeEvidenceScope` boundary
  where that stays simpler. Do not introduce a generic execution framework.
- Process lifecycle and command construction should stay in the controller for
  the first extraction because they have different failure modes and review
  risks.

Required pre-extraction test: add a focused mode-switch stale-evidence test that
loads or seeds evidence for one execution kind, switches validation context to
the other kind, and proves stale evidence cannot validate the new context.

## Follow-Up Slice Definition

- Title: Extract App Validation Evidence Loading
- Findings addressed: `STC-MC-001`
- Minimal fix strategy: move only current validation evidence loading, verdict
  selection, and validation-evidence error text behind a small boundary. Keep
  command construction and process lifecycle unchanged.
- Likely files: `Sources/open-lola-app/AppExecutionController.swift`,
  `Sources/open-lola-app/AppRuntimeEvidenceScope.swift`, and
  `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift`.
- Behavior affected: no intended behavior change; validation success remains
  gated by current runtime/report evidence.
- Verification: `swift test --filter AppShellBehaviorTests`,
  `swift test --filter AppShellSlice05Tests`, and
  `swift test --filter NativeAppShellSurfaceActionTests`.
- Definition of Done: existing validation-evidence tests and the new
  stale-evidence mode-switch test pass before and after extraction, and the
  controller no longer owns report-file loading or validation verdict mapping.
