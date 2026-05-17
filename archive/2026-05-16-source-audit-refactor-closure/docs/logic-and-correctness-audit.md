# Logic and correctness audit

Date: 2026-05-16

Scope: source-level audit for silent wrong behavior, false success states,
runtime crash risks, API misuse, edge cases, and misleading tests. This pass did
not modify production code and did not run the Swift test suite.

## Commands and evidence gathered

- `cat AGENTS.md`
- `rg` inspections for `try?`, `catch`, `Date()`, verdict handling, validation,
  source-string tests, ping parsing, and runtime state checks.
- `nl -ba ... | sed -n ...` inspections of the files cited below.

## Confirmed issues

### LC-001 - App validation can mark a partial direct Mac supervisor report as passed

- ID: LC-001
- Location: `Sources/open-lola-app/AppExecutionController.swift:58-75`,
  `Sources/open-lola-app/AppLatencyHeroMetrics.swift:27-47`,
  `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift:133-160`,
  `Sources/OpenLolaCore/Network/P2P/DirectPeerTwoPeerLocalRunReport.swift:169-184`
- Evidence: `AppRuntimeEvidenceScope.hasValidatedRuntimeEvidence` only checks
  `validationExitCode == 0` and `!directPeerLatencyMetrics.isPartial` for direct
  Mac mode. `AppLatencyHeroMetrics.load` decodes the supervisor report and loads
  peer reports, but it does not require the supervisor report verdict to be
  `.pass`. The existing app-shell test writes a supervisor report with
  `verdict: .partial`, calls `finishValidation(exitCode: 0)`, and expects
  `"Validation passed."`. The supervisor report validator requires aggregate
  report evidence before `.pass`, so this is a real verdict mismatch.
- Why it matters: The UI can present a green validation state even though the
  supervisor report itself is only partial. That is a false-success path in a
  high-risk runtime area.
- Minimal reproduction or reasoning: Create a direct supervisor report with
  loadable peer reports but `verdict: .partial`, then call
  `finishValidation(exitCode: 0)`. Current tests already encode this path and
  expect `phase == .validationPassed`.
- Existing test coverage, if any: Covered in the wrong direction by
  `appExecutionValidationRequiresCompleteCurrentReportEvidence`, which asserts
  partial supervisor reports can pass when peer metrics load.
- Missing test that should exist: A behavior test where a validator-success
  direct supervisor report with `verdict: .partial` remains
  `.validationFailed` or shows a distinct "evidence partial" state.
- Suggested minimal fix: Make direct app validation require the validated
  supervisor report verdict, or explicitly rename/status the state so partial
  supervisor evidence cannot become `"Validation passed."`.
- Risk level: high
- Verification command or strategy: Add the missing app-shell behavior test, then
  run `swift test --filter AppShellBehaviorTests`.
- Confidence: high

### LC-002 - Windows LoLa validation accepts any valid connector report as runtime evidence

- ID: LC-002
- Location: `Sources/open-lola-app/AppExecutionController.swift:58-75`,
  `Sources/open-lola-app/AppExecutionController.swift:349-364`,
  `Sources/open-lola-app/AppExecutionController.swift:566-590`,
  `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSession.swift:606-631`
- Evidence: Windows LoLa mode returns `externalConnectorReport != nil` from
  `hasValidatedRuntimeEvidence`. `ExternalConnectorSessionReport.validate()`
  permits `.partial` reports and also permits `.fail` reports when
  `runtimeError` is non-empty. `finishValidation(exitCode: 0)` maps any
  `hasValidatedRuntimeEvidence` value to `"Validation passed."`.
- Why it matters: A syntactically valid `.partial` or `.fail` external connector
  report can be treated as completed app validation. That can run without
  crashing while presenting the wrong operational state.
- Minimal reproduction or reasoning: Write a valid
  `ExternalConnectorSessionReport` with `verdict: .partial` or `verdict: .fail`
  and a `runtimeError`, point the app Windows LoLa output path at it, then call
  `finishValidation(exitCode: 0)`. The current predicate only checks non-nil
  report load.
- Existing test coverage, if any:
  `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift:105-117` covers the
  missing-report case only. `NativeAppShellWindowsLoLaTests` checks validator
  command construction, not verdict semantics.
- Missing test that should exist: App validation tests for Windows LoLa `.pass`,
  `.partial`, and `.fail` reports.
- Suggested minimal fix: Require `externalConnectorReport?.verdict == .pass` for
  `"Validation passed."`, or surface `.partial`/`.fail` as distinct non-green
  validation states.
- Risk level: high
- Verification command or strategy: Add Windows LoLa app-shell behavior tests,
  then run `swift test --filter AppShellBehaviorTests`.
- Confidence: high

### LC-003 - Two-peer aggregate report failures are silently discarded

- ID: LC-003
- Location:
  `Sources/open-lola/Commands/Network/DirectP2PTwoPeerLocalRunCommandSupport.swift:18-27`,
  `Sources/open-lola/Commands/Network/DirectP2PTwoPeerLocalRunCommandSupport.swift:376-401`
- Evidence: `runDirectP2PTwoPeerLocalRunCommand` calls
  `try? writeAggregatePrototypeReport(...)`. That helper loads both peer reports
  and both RX proof files and writes the aggregate prototype report. Any decode,
  missing-file, validation, or write failure becomes `nil`, and the final
  supervisor report only records `aggregateExecuted: false` with no reason.
- Why it matters: The command can complete normally while losing the reason why
  aggregate evidence was not produced. Operators see partial output but not the
  actual missing/corrupt artifact.
- Minimal reproduction or reasoning: Run with two child process results that
  have exit code 0 but one missing RX proof or corrupt peer report. The helper
  throws, `try?` converts it to `nil`, and report construction continues.
- Existing test coverage, if any:
  `DirectPeerTwoPeerRunPlanTests` checks pass/downgrade semantics at the report
  builder level, but not the CLI path that swallows aggregate write failures.
- Missing test that should exist: CLI/support test that injects a missing or
  invalid aggregate input and verifies the failure reason is preserved in the
  supervisor report or command result.
- Suggested minimal fix: Replace `try?` with explicit error capture. Either fail
  the command for expected aggregate evidence, or add an explicit aggregate
  failure field/note before returning partial.
- Risk level: medium
- Verification command or strategy: Add a focused two-peer local-run support
  test, then run `swift test --filter DirectPeerTwoPeerRunPlanTests`.
- Confidence: high

### LC-004 - Runtime deadlines use wall-clock time in process, control, and media waits

- ID: LC-004
- Location:
  `Sources/open-lola/Commands/Network/DirectP2PTwoPeerLocalRunCommandSupport.swift:82-85`,
  `Sources/open-lola/Commands/Network/DirectP2PTwoPeerLocalRunCommandSupport.swift:243-259`,
  `Sources/OpenLolaCore/Support/ManagedProcessRunner.swift:110-146`,
  `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSessionRuntime.swift:179-236`,
  `Sources/OpenLolaCore/Connectors/LoLa/LoLaControlExchangeRuntime.swift:191-194`,
  `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityRawLink.swift:77-78`,
  `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityUdpMediaSocket.swift:43-45`
- Evidence: These wait loops compute deadlines with `Date().addingTimeInterval`
  and compare with `Date()`, while nearby tests and other code use
  `ContinuousClock` or `DispatchTime` for monotonic waits.
- Why it matters: NTP/manual clock changes can make a bounded runtime wait
  return too early or wait too long. In media/control/process supervision, this
  can create silent partial evidence, stale process state, or misleading timeout
  reports.
- Minimal reproduction or reasoning: During one of these waits, move the system
  clock backward or forward. The loop condition changes independently of real
  elapsed time.
- Existing test coverage, if any: No tests found that simulate system clock
  jumps. Some test helpers use monotonic clocks, which suggests the safer pattern
  exists locally.
- Missing test that should exist: Injectable clock or helper-level tests proving
  process/control/media deadlines are elapsed-time based.
- Suggested minimal fix: Move deadline logic to `DispatchTime`,
  `ContinuousClock`, or a small monotonic deadline helper.
- Risk level: medium
- Verification command or strategy: Add helper tests around timeout behavior and
  run targeted tests for process supervision and LoLa media/control runners.
- Confidence: high

## Suspected issues needing verification

### LC-005 - UDP media jitter EWMA appears to mix streams

- ID: LC-005
- Location: `Sources/OpenLolaCore/Network/UDP/UdpMediaTransport.swift:323-329`,
  `Sources/OpenLolaCore/Network/UDP/UdpMediaTransport.swift:527-571`,
  `Tests/OpenLolaCoreTests/UdpMediaTransportTests.swift:283-390`
- Evidence: `previousTransitByStream` and `transitSampleCountByStream` are keyed
  per payload type and stream ID, but `metricsState.jitterMicroseconds` is one
  aggregate EWMA updated by every stream. The current tests exercise jitter/loss
  on one stream ID.
- Why it matters: Interleaved audio/video or multi-stream packets can pollute a
  single jitter value. The app/report may show a plausible number that belongs
  to the last mixed stream pattern rather than the stream being evaluated.
- Minimal reproduction or reasoning: Send enough packets on stream A to seed
  jitter, then interleave stream B with different transit deltas. Because the
  previous transit is per stream but the EWMA is shared, updates from B change
  the aggregate used for A.
- Existing test coverage, if any: Single-stream UDP media loss/reorder/jitter
  tests only.
- Missing test that should exist: Multi-stream jitter test with two stream IDs or
  audio/video payload types and deterministic receive timestamps.
- Suggested minimal fix: Store jitter state per `UdpMediaSequenceKey`, then
  expose an explicit aggregate policy such as max, selected stream, or per-stream
  report rows.
- Risk level: medium
- Verification command or strategy: Add deterministic unit coverage around
  `recordReceived` behavior, possibly by extracting a metric accumulator.
- Confidence: medium

### LC-006 - Network diagnostics collapses parser and process failures into partial reports without reason

- ID: LC-006
- Location: `Sources/OpenLolaCore/Network/Diagnostics/NetworkDiagnostics.swift:169-213`,
  `Sources/OpenLolaCore/Network/Diagnostics/NetworkDiagnostics.swift:312-324`,
  `Tests/OpenLolaCoreTests/NetworkDiagnosticsTests.swift:28-39`
- Evidence: `parsePing` defaults malformed packet counts to `0` and packet loss
  to `100` instead of throwing for malformed summaries. The runner then uses
  `try? NetworkDiagnosticsParser.parsePing(...)` and returns `nil` for any
  process or parse failure. The existing malformed-summary test only checks
  `packetLossPercent == 100`.
- Why it matters: A diagnostic run can produce a partial report without saying
  whether ping failed, parsing failed, the output was localized/unsupported, or
  the peer was genuinely unreachable.
- Minimal reproduction or reasoning: Feed a non-macOS or malformed ping summary
  with valid timing text. The parser can return default values, or the runner can
  drop the parse failure entirely.
- Existing test coverage, if any: macOS ping output is covered; malformed output
  behavior is asserted but not tied to report error visibility.
- Missing test that should exist: Linux/localized/malformed ping output cases and
  report-level assertions that parse failure reasons are preserved.
- Suggested minimal fix: Return structured ping diagnostic errors in the report
  rather than collapsing failures to `nil`.
- Risk level: low
- Verification command or strategy: Add parser fixture tests and a runner test
  with injected command output.
- Confidence: medium

### LC-007 - Some tests assert readiness or text trivia instead of behavior that matters

- ID: LC-007
- Location: `Tests/OpenLolaCoreTests/AppShellSlice05Tests.swift:36-49`,
  `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift:147-160`,
  `Tests/OpenLolaCoreTests/NetworkDiagnosticsTests.swift:28-39`,
  broad examples in `ReleaseArtifactHygieneContractTests`,
  `SourceNamingConventionTests`, and `GoalRuntimeEvidenceTemplateTests`
- Evidence: The validation-readiness test writes `{}` and expects `.ready`,
  proving only path existence. The app behavior test expects a partial supervisor
  report to produce `"Validation passed."`. Several contract tests assert that
  strings or docs contain substrings; those may be useful release guards, but
  they do not prove runtime behavior.
- Why it matters: These tests can remain green while false-success behavior,
  malformed report handling, or runtime validation semantics are wrong.
- Minimal reproduction or reasoning: Change report verdict semantics or provide
  invalid JSON at an existing path. The readiness test still passes because it
  only checks existence, and the partial-report validation test currently
  protects the questionable behavior in LC-001.
- Existing test coverage, if any: The cited tests exist, but they are weak for
  behavior correctness.
- Missing test that should exist: Behavior-first tests around validation verdict
  handling, invalid JSON, fail/partial reports, and app-visible state.
- Suggested minimal fix: Keep string-contract tests only where they guard public
  artifacts, but add executable behavior tests for the runtime states they claim
  to protect.
- Risk level: medium
- Verification command or strategy: Replace or augment the cited tests, then run
  `swift test --filter AppShellBehaviorTests` and affected contract-test filters.
- Confidence: high

### LC-008 - Public runtime constructors can trap instead of returning validation errors

- ID: LC-008
- Location:
  `Sources/OpenLolaCore/Audio/Realtime/DirectPeerAudioPayloadRing.swift:21-40`,
  `Sources/OpenLolaCore/Timing/RxBuffering.swift:52-73`,
  `Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioBuffers.swift:151-157`,
  `Sources/OpenLolaCore/Support/SPSCAtomicRing.swift:25-31`
- Evidence: Several runtime structures use `precondition` for positive sizes or
  overflow checks. Many call paths validate before construction, but the
  initializers are public or shared enough that an unvalidated future call site
  would abort the process instead of surfacing a typed error.
- Why it matters: User-derived configuration should fail as validation, not as a
  process crash, especially near realtime audio buffers.
- Minimal reproduction or reasoning: Calling `DirectPeerAudioPayloadRing` with
  zero capacity or `RxBufferPolicy.init` with non-positive `framesPerPacket`
  traps. Whether current CLI/app input can reach these paths without validation
  needs call-chain proof.
- Existing test coverage, if any: Parser and policy factory tests cover many
  invalid values before construction. No audit evidence found that every public
  initializer is unreachable from unvalidated inputs.
- Missing test that should exist: Boundary tests proving CLI/app decoded
  configuration cannot instantiate these types with zero/negative sizes.
- Suggested minimal fix: Keep internal invariants where appropriate, but route
  user-derived construction through throwing factories or documented validated
  wrappers.
- Risk level: low
- Verification command or strategy: Trace all production call sites for each
  initializer and add boundary tests at the highest public configuration layer.
- Confidence: low

## Coverage gaps and uncertainty

- No production code was changed.
- No Swift tests, app launches, hardware runs, network runs, or migration-like
  checks were executed for this audit.
- Full file-by-file correctness coverage was not attempted in this pass. Highest
  attention went to app validation, report verdicts, two-peer run supervision,
  UDP media metrics, LoLa connector waits, network diagnostics, and tests that
  appeared to encode runtime truth.
- Realtime Core Audio callback behavior, full AVFoundation capture paths,
  multi-peer routing, NAT relay behavior, packaging/release report validators,
  and Python connector runtime deserve separate deep audits.

## Recommended next audit targets

1. Add behavior tests for LC-001 and LC-002 before changing app validation.
2. Audit all `MeasurementVerdict` promotion paths for partial-to-pass or
   fail-to-pass gaps.
3. Extract and test UDP media metric accumulation independently from sockets.
4. Replace wall-clock runtime deadlines with a monotonic helper in one subsystem
   first, then reuse it only where the behavior is proven.
5. Review source-string contract tests and keep only those that guard durable
   public artifacts.
