# Logic And Correctness Audit

Date: 2026-05-17

Verdict: PARTIAL

Scope: read-only audit of current source, tests, and active docs for silent
wrong behavior, edge-case runtime failures, API misuse, false success states,
and misleading tests. Production code was not changed.

The strongest previously reported app-validation false-success candidates were
rechecked and appear fixed in this tree: direct Mac supervisor reports with
`partial`/`fail` verdicts and Windows LoLa external connector reports with
`partial`/`fail` verdicts now keep app validation in `validationFailed`.

## Confirmed Issues

### LC-001 - Audio-only Python runtime still binds the video UDP port

- ID: LC-001
- Location: `linux_connector/lola_connector/runtime.py:92-116`;
  `linux_connector/lola_connector/cli.py:130-142`;
  `linux_connector/tests/test_runtime_contracts.py:42-58`
- Evidence: `LolaLinuxRuntime.start()` always opens both
  `self._audio_sock` and `self._video_sock` before it checks
  `transmit_video`, `video_capture`, or `receive`. The CLI deliberately allows
  audio-only modes by computing `tx_video = video_capture is not None ...`.
  The existing no-video test only checks `stats.video_tx == 0`; it does not
  prove the video port was not required.
- Why it matters: an audio-only run can fail before sending audio if the video
  port is unavailable, already bound, blocked by policy, or unnecessary for the
  requested mode. That is a silent contract mismatch: the user asked for
  audio-only behavior but runtime startup still depends on video resources.
- Minimal reproduction or reasoning: start `LolaLinuxRuntime` with
  `receive=False`, `transmit_audio=True`, `transmit_video=False`,
  `video_capture=None`, and pre-bind the configured video port. The call should
  not need the video socket, but the current startup path attempts to bind it.
- Existing test coverage, if any:
  `test_runtime_without_video_capture_does_not_emit_video_tx` verifies no video
  frames are transmitted, but not that video resources are skipped.
- Missing test that should exist: a test that pre-binds `connector.video_port`
  and proves an audio-only runtime can still start, send audio, and stop.
- Suggested minimal fix: bind the video socket only when receive mode or video
  TX actually needs it; update `_media_rx_loop` preconditions accordingly.
- Risk level: high for Python LoLa compatibility runs; medium for source tree
  because this path is a compatibility seed.
- Verification command or strategy:
  `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector/tests/test_runtime_contracts.py linux_connector/tests/test_process_runtime.py`
- Confidence: high

### LC-002 - App validation can say passed while the execution report remains partial

- ID: LC-002
- Location: `Sources/open-lola-app/AppExecutionController.swift:552-581`;
  `Sources/OpenLolaCore/Platform/NativeAppShellExecution.swift:176-235`;
  `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift:368-377`
- Evidence: `finishReport()` always writes
  `verdict: lastExternalConnectorReport?.verdict ?? .partial`. For direct Mac
  peer validation there is no external connector report, so the execution
  report remains `.partial` even when `finishValidation(exitCode: 0)` sets
  app status to `"Validation passed."` and phase to `.validationPassed`.
  The passing direct-Mac test asserts the phase/status/evidence metrics but
  does not assert `passingController.lastReport?.verdict`.
- Why it matters: UI state, generated artifacts, and machine-readable reports
  can disagree. A user or downstream tool can see a passed validation state
  while the report still says partial, or treat the report as partial while the
  app says the current validation passed.
- Minimal reproduction or reasoning: create a valid passing
  `DirectPeerTwoPeerLocalRunReport`, set it as `supervisorReportPath`, call
  `finishValidation(exitCode: 0)`, then inspect `lastReport?.verdict`. The
  code path sets phase/status from `hasValidatedRuntimeEvidence`, but report
  verdict from external connector state only.
- Existing test coverage, if any: the direct-Mac passing app test checks
  validation phase, status, and latency metrics, but not the report verdict.
- Missing test that should exist: a direct-Mac validation test asserting the
  intended relationship between `phase`, `hasValidatedRuntimeEvidence`, and
  `lastReport.verdict`. If product verdict must remain partial, the test should
  assert explicit notes/field names that distinguish product status from
  validation status.
- Suggested minimal fix: make the report verdict derivation explicit per
  `executionKind`, or rename/split the field so direct validation status cannot
  be confused with product readiness.
- Risk level: medium
- Verification command or strategy:
  `swift test --filter AppShellBehaviorTests` plus a report-artifact assertion
  for direct-Mac pass and partial/fail cases.
- Confidence: medium; the inconsistency is confirmed, but intended report
  semantics are UNCLEAR.

### LC-003 - Loopback UDP selftests can pass without running UDP behavior

- ID: LC-003
- Location: `linux_connector/tests/test_process_runtime.py:800-820`
- Evidence: both loopback selftests check `loopback_alias_capability()`, assert
  that the missing-alias message has the expected prefix, and then `return`.
  In pytest this records a passing test, not a skipped or xfailed dependency
  condition.
- Why it matters: the test report can show the bidirectional UDP runtime and
  control handshake selftests as green on machines where the required
  `127.0.0.2` loopback alias is absent. That is misleading verification
  evidence for a network runtime path.
- Minimal reproduction or reasoning: run the tests on a host without
  `127.0.0.2` configured. The tests pass after the message assertion, while no
  bidirectional media or handshake path executes.
- Existing test coverage, if any: these are the coverage points, but they
  encode environment absence as success.
- Missing test that should exist: not a new behavior test; the existing tests
  should use `pytest.skip(message)` or a separate capability test so the
  runtime selftests are reported as skipped when the alias is unavailable.
- Suggested minimal fix: replace the early `return` branches with
  `pytest.skip(message)` and keep `loopback_alias_capability()` covered by a
  dedicated unit test.
- Risk level: medium
- Verification command or strategy:
  `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector/tests/test_process_runtime.py -k "selftest or loopback_alias"`
- Confidence: high

### LC-004 - Source-text tests can pass while runtime behavior drifts

- ID: LC-004
- Location: `Tests/OpenLolaCoreTests/ReleaseArtifactHygieneContractTests.swift:5-37`;
  `Tests/OpenLolaCoreTests/RealtimeAudioPathInventoryTests.swift:7-32`;
  `Tests/OpenLolaCoreTests/VerificationToolingContractTests.swift:90-112`
- Evidence: several tests read repo files and assert string containment,
  inventory membership, or shell/workflow text. These are useful guardrails,
  but they do not execute the runtime behavior named by the text. Examples
  include checking docs mention `verify-release-hygiene.sh`, checking realtime
  inventory entries point at files, and checking workflow text contains or
  omits specific strings.
- Why it matters: these tests can create false confidence if counted as
  behavioral coverage for release hygiene, realtime audio behavior, Docker
  policy, or CI behavior. Text can remain aligned while the underlying command,
  runtime path, or workflow behavior breaks.
- Minimal reproduction or reasoning: a script or runtime function can change
  behavior while retaining the asserted strings. The tests still pass because
  they inspect text, not the behavioral outcome.
- Existing test coverage, if any: some nearby tests execute helper scripts, but
  the text-only tests themselves are not behavior proofs.
- Missing test that should exist: for each text-only contract that protects a
  runtime or release claim, keep at least one behavioral test or script probe
  that executes the command, validates produced artifacts, or checks failure
  behavior.
- Suggested minimal fix: keep these tests as documentation-contract guards, but
  tag or group them separately and avoid treating them as runtime correctness
  coverage. Replace the highest-risk string assertions with command-level
  probes where practical.
- Risk level: medium
- Verification command or strategy: review the Swift test list and map
  text-only tests to behavioral gates; then run the mapped gates from
  `docs/testing/README.md`.
- Confidence: high

## Suspected Issues Needing Verification

### LC-005 - LoLa media receive reports can validate malformed media envelopes as partial evidence

- ID: LC-005
- Location: `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityMediaSession.swift:137-157`;
  `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityMediaSession.swift:423-450`;
  `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityMediaCodec.swift:430-440`;
  `Tests/OpenLolaCoreTests/LoLaCompatibilityMediaSessionTests.swift:63-81`
- Evidence: `decodeFrame()` treats payload decode failures as
  `.malformedFragment` after `try? LoLaCompatibilityMediaCodec.decode(...)`,
  but still sets `envelopeValidated: true`. Report validation checks aggregate
  counts and rejects `.pass`, but does not reject malformed packet kinds or
  require decoded media bodies. The receive-session test uses frames generated
  by the transmitter and does not feed a valid UDP envelope with malformed LoLa
  media payload.
- Why it matters: a report can be structurally valid and include every
  envelope as validated while media content is malformed or undecodable. That
  is acceptable only if the report clearly communicates media-level failure and
  downstream validators never treat envelope validation as media correctness.
- Minimal reproduction or reasoning: create a valid LoLa wire frame on the
  audio or video port with payload bytes that do not decode as a LoLa media
  packet. `receiveReport()` should report a media decode failure explicitly.
  Current code appears to record a frame with packet kind `.malformedFragment`
  and valid envelope counts.
- Existing test coverage, if any: generated TX/RX round-trip and pass-reject
  tests exist; malformed media-with-valid-envelope coverage was not found.
- Missing test that should exist: a receive-report test for a valid
  Ethernet/IP/UDP envelope with malformed LoLa media payload, asserting the
  intended verdict, error field, malformed count, and validation behavior.
- Suggested minimal fix: add explicit malformed media counters or runtime error
  semantics to the report, and make validation enforce the intended contract.
- Risk level: medium
- Verification command or strategy:
  `swift test --filter LoLaCompatibilityMediaSessionTests`
- Confidence: medium

### LC-006 - Adaptive RX buffer controller creation failure is swallowed

- ID: LC-006
- Location: `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift:90-93`;
  `Sources/OpenLolaCore/Timing/RxBuffering.swift:430-467`
- Evidence: when `configuration.rxBufferPolicy.profile == .adaptive`,
  `DirectPeerRealtimeAudioGraph` creates the controller with
  `try? .runtimeController(policy: policy)`. A failure leaves
  `adaptiveRxBufferController` nil while `rxBufferSnapshot` still records the
  adaptive policy.
- Why it matters: if an invalid or future adaptive policy reaches this
  initializer, runtime can continue with a snapshot that says adaptive buffering
  is configured while no controller exists to perform adaptive state changes.
  That is a silent wrong-behavior risk in a realtime path.
- Minimal reproduction or reasoning: construct or decode an adaptive
  `RxBufferPolicy` that `runtimeController(policy:)` rejects after graph input
  validation. Current graph initialization would suppress the error and proceed
  without adaptation. The exact path for such a policy is UNCLEAR.
- Existing test coverage, if any: RX buffer policy and graph tests cover normal
  adaptive behavior, but this audit did not find a test proving controller
  creation errors are surfaced by the graph.
- Missing test that should exist: a graph initialization test that injects an
  invalid adaptive policy and asserts a thrown error, or proves the impossible
  state cannot be constructed from public inputs.
- Suggested minimal fix: replace `try?` with `try` and let graph initialization
  fail when adaptive policy/controller setup is invalid.
- Risk level: medium
- Verification command or strategy:
  `swift test --filter DirectPeerRealtimeAudioGraphRxBufferingTests` and
  `swift test --filter RxBufferingTests`
- Confidence: medium

### LC-007 - Public RX buffer initializer traps before validation can return errors

- ID: LC-007
- Location: `Sources/OpenLolaCore/Timing/RxBuffering.swift:52-70`
- Evidence: `RxBufferPolicy.init(...)` is public and uses
  `precondition(framesPerPacket > 0)` before assigning fields and before
  callers can invoke `validate()`. The type also defines
  `RxBufferPolicyValidationError.nonPositiveField`, so most invalid policy
  inputs are modeled as recoverable validation errors.
- Why it matters: malformed decoded data, tests, tools, or future callers can
  crash the process rather than receiving a typed validation error. In runtime
  or report-validation paths, traps are harder to surface accurately than
  normal failures.
- Minimal reproduction or reasoning: call the public initializer with
  `framesPerPacket: 0`. The code traps at the precondition instead of throwing
  `nonPositiveField("framesPerPacket")`. This audit did not prove whether any
  current decoder path can instantiate such a value before validation.
- Existing test coverage, if any: many factory-method tests cover invalid
  inputs through throwing constructors. No direct public-initializer trap test
  was found, and trap tests would need an isolated process.
- Missing test that should exist: either a decoding/validation test proving
  invalid persisted policy data becomes a typed validation failure, or an
  isolated crash test documenting the intentional trap boundary.
- Suggested minimal fix: remove the precondition from the public initializer
  and rely on throwing factories/validation, or make the initializer internal
  if only validated construction is intended.
- Risk level: medium
- Verification command or strategy:
  `swift test --filter RxBufferingTests`, plus an isolated invalid-decode probe
  if decoded policy data is accepted from reports or fixtures.
- Confidence: medium

## Audited Candidates Not Currently Findings

- Direct Mac app validation with partial/fail supervisor reports: live code now
  checks `supervisorVerdict != .pass` through `AppLatencyHeroMetrics.isPartial`
  and tests cover partial/fail supervisor reports.
- Windows LoLa app validation with partial/fail external connector reports:
  live code now requires `externalConnectorReport?.verdict == .pass` and tests
  cover partial/fail reports.
- Two-peer aggregate report failure swallowing: live code now records
  `aggregateFailureReason` and prints it when aggregate generation fails.
- UDP media jitter cross-stream mixing: live code stores `jitterByStream` and
  returns the max across streams; a test covers per-stream aggregation.
- Wall-clock runtime deadlines in the inspected process/media wait loops: the
  inspected active paths use `DispatchTime`, `MonotonicDeadline`, or
  `time.perf_counter()` for waits. Remaining `Date()` uses in those paths
  appear to be timestamps, not deadlines.

## Coverage Gaps And Uncertainty

- This was a source audit, not a full verification run. No Swift, Python, lint,
  typecheck, shellcheck, app-launch, hardware, or Windows LoLa live commands
  were run during this pass.
- Core Audio callback timing, native device I/O, live UDP packet capture,
  Windows LoLa interop, and app UI visual states were not exercised.
- Vendored Opus and JPEG XS internals were not audited beyond integration
  surfaces.
- Several findings are marked medium confidence because the code exposes an
  inconsistency or silent fallback, but intended behavior is not fully
  specified in the inspected source/docs.

## Recommended Next Audit Targets

1. Python LoLa runtime socket binding and startup lifecycle, starting with
   LC-001.
2. App report/status truthfulness, starting with LC-002 and generated artifact
   summaries.
3. LoLa media receive-report malformed-payload semantics, starting with LC-005.
4. Realtime RX buffer construction and adaptive controller failure surfaces,
   starting with LC-006 and LC-007.
5. Test-suite classification: distinguish runtime behavior tests from text,
   inventory, policy, and environment-capability checks.
