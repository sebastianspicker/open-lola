# Test Intent Audit

Date: 2026-05-16

Scope: active Swift and Python tests in the current checkout:

- `Tests/OpenLolaCoreTests/*.swift`
- `Tests/OpenLolaCoreTests/Fixtures/**`
- `linux_connector/tests/*.py`
- active verification guidance in `docs/testing/README.md`

This is audit-only. No production code and no tests were changed.

Live inventory:

| Surface | Current count | Evidence command |
| --- | ---: | --- |
| Swift test files | 169 | `find Tests/OpenLolaCoreTests -maxdepth 1 -type f -name '*.swift'` |
| Swift fixtures | 56 | `find Tests/OpenLolaCoreTests/Fixtures -type f` |
| Python test files | 3 | `find linux_connector -path '*/tests/*' -type f` |
| Swift `@Test` declarations | 462 | `rg -n "@Test" Tests/OpenLolaCoreTests -g '*.swift'` |
| Swift `#expect` checks | 4099 | `rg -n "#expect" Tests/OpenLolaCoreTests -g '*.swift'` |
| Python `def test_` declarations | 73 | `rg -n "def test_" linux_connector/tests -g '*.py'` |
| Python assertions / raises | 198 | `rg -n "assert |pytest\\.raises" linux_connector/tests -g '*.py'` |

Judgment rule: a test is valuable only if it would fail when meaningful
business, runtime, protocol, or evidence-boundary behavior changes incorrectly.
Tests that only preserve text, counts, helper naming, or internal structure are
classified as weak even if they are useful as policy gates.

## Findings

### TIA-001

- ID: TIA-001
- Test file: `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift`
- Test name / symbol: `semanticAppShellBehaviorTestsScenario`,
  `appExecutionValidationRequiresCompleteCurrentReportEvidence`
- Production behavior supposedly protected: The macOS app must not show live,
  connected, validated, or healthy runtime state without current validated
  direct-peer or Windows-LoLa evidence.
- Why the current test is weak or missing: The existing checks are valuable for
  `finishValidation(exitCode:)` evidence gating, malformed reports, partial
  reports, failed reports, and pass reports. They do not exercise
  `AppExecutionController.start`, `launchProcess`, termination-handler teardown,
  `stop()`, failed executable launch, or stop-requested report finalization.
- If the business/runtime behavior changed incorrectly, would this test fail?
  Partly. It would catch validation evidence promotion bugs, but not broken
  start/stop state transitions or process lifecycle divergence.
- What meaningful behavior should be tested: Starting a real short-lived test
  process transitions through running to finished; failed launch records
  `failedToStart`; `stop()` does not report success before the process exits;
  validation state is cleared when a new run starts.
- Example better test description: "app execution stop request remains
  non-success until the launched process exits and the report is refreshed."
- Edge cases to include: missing executable, nonzero exit, process writes valid
  report after stop, process writes malformed report, validation after stale
  previous pass, unsupported operator mode.
- Risk level: high
- Confidence: high

### TIA-002

- ID: TIA-002
- Test file: `Tests/OpenLolaCoreTests/VerificationToolingContractTests.swift`
- Test name / symbol: `wslLoLaNetworkHelperUsesStrictDryRunAndScopedFirewallControls`
- Production behavior supposedly protected: The Windows/WSL helper must be
  dry-run safe, use `ShouldProcess`, expose `-SkipWslShutdown`, and avoid
  unscoped firewall mutation.
- Why the current test is weak or missing: When `pwsh` is unavailable, the test
  falls back to string checks for PowerShell source text. That proves tokens are
  present, not that the helper preserves config, scopes firewall rules, or
  respects `-WhatIf`.
- If the business/runtime behavior changed incorrectly, would this test fail?
  No in the no-`pwsh` branch. The script could contain the strings while the
  operational behavior is wrong.
- What meaningful behavior should be tested: A runnable dry-run path should
  prove that the target config file is unchanged and that the intended scoped
  firewall operation is reported without performing mutation.
- Example better test description: "WSL LoLa network helper leaves config
  unchanged and reports scoped firewall changes under `-WhatIf`."
- Edge cases to include: missing config file, existing mirrored networking,
  duplicate UDP ports, empty interface alias, no `-SkipWslShutdown`.
- Risk level: medium
- Confidence: high

### TIA-003

- ID: TIA-003
- Test file: `Tests/OpenLolaCoreTests/ReleaseArtifactHygieneContractTests.swift`
- Test name / symbol:
  `releaseHygienePolicyDocsManifestNoticeAndVerificationMatrixStayAligned`,
  `releaseVerificationContractsCoverArchivedPlanDocsTimeoutsAndPythonTooling`
- Production behavior supposedly protected: Release candidates must exclude
  private/generated/archive residue, documentation must describe the same
  release boundary, and verification commands must stay aligned with CI.
- Why the current test is weak or missing: The first test relies heavily on
  `contains` checks against Markdown and notice files. The third test mixes
  meaningful checks with hardcoded dependency lists, docs-string checks, and
  active/archived plan-file presence. These are policy checks, not direct
  behavioral checks of the release artifact.
- If the business/runtime behavior changed incorrectly, would this test fail?
  Partly. It would catch some documentation drift and missing script wiring,
  but a broken release export or hygiene scanner can still pass if the strings
  remain.
- What meaningful behavior should be tested: The release exporter and hygiene
  scanner should be exercised on clean and contaminated staged trees, with
  assertions on actual included/excluded files and nonzero failure for
  forbidden residue.
- Example better test description: "release hygiene rejects a staged candidate
  containing private evidence, build output, Python bytecode, or vendored test
  residue."
- Edge cases to include: symlinked forbidden paths, nested `__pycache__`,
  hidden files, stale archived plan files, missing `THIRD_PARTY_NOTICES.md`.
- Risk level: medium
- Confidence: high

### TIA-004

- ID: TIA-004
- Test file: `Tests/OpenLolaCoreTests/SourceNamingConventionTests.swift`
- Test name / symbol:
  `cleanRoomNamingPolicyAndTwoPeerPrototypeSurfaceStayDocumented`
- Production behavior supposedly protected: Source naming policy and two-peer
  prototype command/report surfaces should remain documented and discoverable.
- Why the current test is weak or missing: The naming portion only asserts that
  documentation contains suffix strings and example filenames. That is
  implementation and documentation trivia; it does not validate naming policy
  against the actual source tree.
- If the business/runtime behavior changed incorrectly, would this test fail?
  No for runtime behavior, and only weakly for naming policy. The docs can keep
  the examples while new source files violate the policy.
- What meaningful behavior should be tested: Scan current source filenames and
  fail when new `*Helpers`, `*Support`, or `*Utilities` names violate the
  documented policy or lack an explicit exception.
- Example better test description: "new helper/support suffixes require a
  documented active exception tied to a source owner."
- Edge cases to include: nested source directories, generated/vendored files,
  test support files, renamed CLI command support, new one-off utilities.
- Risk level: low
- Confidence: high

### TIA-005

- ID: TIA-005
- Test file: `Tests/OpenLolaCoreTests/CodeLineBudgetTests.swift`
- Test name / symbol: `scopedCodeFilesStayWithinLineBudget`
- Production behavior supposedly protected: Source files should stay small
  enough to remain reviewable and avoid broad overgrown modules.
- Why the current test is weak or missing: This is a structural policy gate,
  not an intent test. It can pass while runtime behavior is wrong, and it can
  fail for a behavior-preserving edit that legitimately needs more lines.
- If the business/runtime behavior changed incorrectly, would this test fail?
  No. It only fails when file line counts or exception-ledger rows violate the
  policy.
- What meaningful behavior should be tested: Keep this as a policy gate, but do
  not count it as behavioral coverage. Pair line-budget failures with subsystem
  behavior tests before simplifying source.
- Example better test description: "line budget gate enforces reviewability;
  runtime behavior is covered by subsystem tests named in the exception row."
- Edge cases to include: stale exception rows, generated files, vendored code,
  large test-support files, line-count exceptions with no behavior-test pointer.
- Risk level: low
- Confidence: high

### TIA-006

- ID: TIA-006
- Test file: `Tests/OpenLolaCoreTests/FixtureSmokeMatrixTests.swift`,
  `Tests/OpenLolaCoreTests/ReportSchemaInventoryTests.swift`
- Test name / symbol: `fixtureSmokeMatrixMatchesFixtureTree`,
  `fixtureSmokeMatrixHasOwnersForEveryFixtureGroup`,
  `reportSchemaInventoryCoversMetadataCommandsFixturesSyntheticSmokesAndOwners`
- Production behavior supposedly protected: Report schemas, fixture groups,
  validators, synthetic-smoke commands, source owners, and false-pass fixtures
  must stay aligned.
- Why the current test is weak or missing: These tests mostly prove that
  multiple inventories agree and that paths/counts exist. They are useful
  contract checks, but many assertions would pass if report validators stopped
  enforcing the actual false-pass behavior.
- If the business/runtime behavior changed incorrectly, would this test fail?
  Partly. It catches missing fixture files and inventory drift, but not every
  broken validator policy.
- What meaningful behavior should be tested: For each high-risk false-pass
  fixture, decode through the public validator and assert the exact behavioral
  rejection that prevents synthetic, incomplete, or stale evidence from
  becoming `PASS`.
- Example better test description: "every registered false-pass fixture fails
  through its public validator for the reason declared by its schema entry."
- Edge cases to include: missing validator command, stale false-pass fixture,
  fixture that decodes but validates as pass, schema entry with no active CLI
  validator.
- Risk level: medium
- Confidence: high

### TIA-007

- ID: TIA-007
- Test file: `Tests/OpenLolaCoreTests/SyntheticSmokeReportContractTests.swift`
- Test name / symbol: `syntheticSmokeReportsValidateAsPartialWithoutClaimingRuntimePass`
- Production behavior supposedly protected: Synthetic smoke reports must remain
  `PARTIAL` and must not claim measured runtime or product readiness.
- Why the current test is weak or missing: The central intent is strong, but 23
  smoke cases are packed into one test with a hardcoded case count and many
  field-literal assertions. A failure identifies the aggregate test, not the
  specific product boundary that regressed.
- If the business/runtime behavior changed incorrectly, would this test fail?
  Usually yes for synthetic `PASS` regressions, but not with good diagnostic
  locality, and hardcoded shape assertions can fail for harmless report
  evolution.
- What meaningful behavior should be tested: Preserve the synthetic
  `PARTIAL`/no-real-world-claim checks, but split high-risk smoke families into
  named tests by behavioral boundary.
- Example better test description: "external connector synthetic smoke keeps
  source-level pass separate from real-world interoperability partial."
- Edge cases to include: synthetic evidence marked measured, source-level pass
  promoted to product pass, missing manual gate note, empty blocker list,
  connector-specific real-world claim set true.
- Risk level: medium
- Confidence: high

### TIA-008

- ID: TIA-008
- Test file: `Tests/OpenLolaCoreTests/*Tests.swift` files containing
  `func semantic*TestsScenario`
- Test name / symbol: 45 `semantic...TestsScenario` wrappers, including
  `semanticAppShellBehaviorTestsScenario`,
  `semanticVerificationToolingContractTestsScenario`,
  `semanticUdpPcmPacketTestsScenario`
- Production behavior supposedly protected: Multiple subsystem behavior groups
  are protected through one public Swift Testing test that calls helper
  functions.
- Why the current test is weak or missing: The helper names are often more
  intent-rich than the single `@Test` wrapper, but Swift Testing only reports
  the wrapper as the test. This reduces failure locality and can make broad
  scenarios hide which behavioral reason failed.
- If the business/runtime behavior changed incorrectly, would this test fail?
  Yes when a helper assertion fails, but the reported test name is less precise
  than the behavior under test.
- What meaningful behavior should be tested: Keep semantic names, but promote
  high-risk helpers to separate `@Test` declarations where they represent
  independent runtime, parser, evidence, or state-transition contracts.
- Example better test description: "direct peer local run downgrades missing
  receive proof instead of accepting synthetic pass."
- Edge cases to include: validation failure locality, flaky long scenario
  setup, one helper mutating shared state for later helpers, async helper
  failures.
- Risk level: medium
- Confidence: medium

### TIA-009

- ID: TIA-009
- Test file: `linux_connector/tests/test_process_runtime.py`
- Test name / symbol:
  `test_runtime_control_loop_requires_initialized_socket`,
  `test_runtime_audio_tx_checks_socket_before_consuming_capture`,
  `test_runtime_media_rx_logs_unexpected_payload_type`,
  `test_runtime_media_rx_counts_malformed_payload_without_task_failure`,
  `test_runtime_control_loop_counts_malformed_payload_without_task_failure`
- Production behavior supposedly protected: The Python connector runtime should
  fail early when sockets are uninitialized, avoid consuming capture before
  socket readiness, count malformed media/control payloads, and keep malformed
  packets from killing runtime tasks.
- Why the current test is weak or missing: The intent is good, but several
  tests call private runtime loops or monkeypatch internal functions directly.
  That couples tests to implementation structure and can fail during safe
  refactors while missing behavior reachable only through public run/start
  paths.
- If the business/runtime behavior changed incorrectly, would this test fail?
  Partly. It catches the current internal loop behavior, but not necessarily
  public runtime behavior after refactoring or when socket setup changes.
- What meaningful behavior should be tested: Prefer public runtime entry points
  with injected sockets/captures where possible, and assert observable stats,
  logs, task survival, and cleanup.
- Example better test description: "runtime receiving malformed media datagrams
  increments malformed counters and stops cleanly through `run_for`."
- Edge cases to include: repeated malformed bursts, mixed valid/malformed
  datagrams, socket close during receive, capture read cancellation, control
  and media loops running together.
- Risk level: medium
- Confidence: high

### TIA-010

- ID: TIA-010
- Test file: `linux_connector/tests/test_process_runtime.py`
- Test name / symbol: `test_bidirectional_udp_runtime_selftest`,
  `test_control_handshake_udp_selftest`
- Production behavior supposedly protected: Python connector loopback should
  exchange audio/video media and control handshakes across two local peers.
- Why the current test is weak or missing: Both tests skip when `127.0.0.2`
  cannot be bound. That is reasonable for portability, but it means the only
  Python end-to-end UDP selftests can disappear silently on hosts without the
  alias.
- If the business/runtime behavior changed incorrectly, would this test fail?
  No when skipped. On hosts with the alias, yes for basic audio/video/control
  loopback.
- What meaningful behavior should be tested: Provide a non-skipped localhost
  fallback that still exercises two-peer routing semantics, or mark the skip as
  an explicit environment gap in verification output.
- Example better test description: "bidirectional UDP selftest either runs on a
  routable loopback pair or reports an explicit missing-loopback capability
  gate."
- Edge cases to include: alias unavailable, port collision, one peer starts
  late, media succeeds but control fails, control succeeds but video receives
  zero frames.
- Risk level: high
- Confidence: high

### TIA-011

- ID: TIA-011
- Test file: `Tests/OpenLolaCoreTests/ExternalConnectorProcessGroupTests.swift`
- Test name / symbol: `jackTripAudioVideoProcessRunUsesInjectedProcessRunnerForPrimaryAndAuxiliary`
- Production behavior supposedly protected: JackTrip audio-video runs should
  invoke both primary and auxiliary external processes and report process
  status truthfully.
- Why the current test is weak or missing: Part of the test uses a mock runner
  and asserts mock invocation counts, process IDs, and executable strings. The
  same file has a valuable real descendant-kill test, but this injected-runner
  section can pass even if real process-group behavior breaks.
- If the business/runtime behavior changed incorrectly, would this test fail?
  Partly. It catches orchestration wiring into the runner, not the real
  process-group semantics.
- What meaningful behavior should be tested: Keep the mock test for routing,
  but pair it with a real short-lived primary/auxiliary process run that proves
  both are launched, captured, timed out or exited, and reported correctly.
- Example better test description: "JackTrip audio-video session launches and
  reports both primary and auxiliary real process invocations."
- Edge cases to include: primary launch failure, auxiliary launch failure,
  primary exits nonzero while auxiliary succeeds, auxiliary timeout, output
  capture truncation.
- Risk level: medium
- Confidence: medium

### TIA-012

- ID: TIA-012
- Test file: `Tests/OpenLolaCoreTests/NativeAppShellTests.swift`,
  `Tests/OpenLolaCoreTests/NativeAppShellOpusCommandTests.swift`,
  `Tests/OpenLolaCoreTests/NativeAppShellWindowsLoLaTests.swift`,
  `Tests/OpenLolaCoreTests/AppShellSlice05Tests.swift`
- Test name / symbol: native app shell command-building and validation tests
- Production behavior supposedly protected: The native app shell should build
  correct direct-peer and Windows-LoLa commands, hide unsupported runtime
  modes, and keep settings tied to runtime behavior.
- Why the current test is weak or missing: The suite checks command arguments,
  validation readiness, missing-report states, and unsupported modes. It does
  not run the app UI, verify menu/action wiring, verify disabled controls in a
  rendered view, or assert that visible status text follows process/report
  state during a real run.
- If the business/runtime behavior changed incorrectly, would this test fail?
  Partly. It catches model and command-building regressions, but not rendered
  UI status or dead menu/action regressions.
- What meaningful behavior should be tested: Add an app-level smoke probe that
  launches the app or app support surface, triggers a dry-run command, and
  verifies visible/report-backed status transitions.
- Example better test description: "operator console displays validation failed
  when the selected report is missing and never shows live without validated
  evidence."
- Edge cases to include: unsupported JackTrip/UltraGrid mode, missing output
  path, invalid host, stale validation pass, malformed report, process failure.
- Risk level: high
- Confidence: medium

### TIA-013

- ID: TIA-013
- Test file: `Tests/OpenLolaCoreTests/UdpMediaTransportTests.swift`
- Test name / symbol:
  `udpMediaTransportTracksLossRolloverReorderDuplicateAndClockSkew`,
  `mediaPacketRejectsTruncatedMismatchedAndMalformedPayloads`
- Production behavior supposedly protected: UDP media transport must preserve
  audio/video/timing packet contracts and track loss, rollover, late packets,
  reordered packets, duplicates, clock skew, and malformed payloads.
- Why the current test is weak or missing: These are valuable tests and should
  be preserved. The main gap is sustained/adverse timing coverage: current
  checks use small local loopback sequences and deterministic timestamps, not
  longer bursts with realistic jitter and receive deadlines.
- If the business/runtime behavior changed incorrectly, would this test fail?
  Yes for many packet contract and metric regressions; no for longer-running
  timing/backpressure bugs outside the short deterministic sequences.
- What meaningful behavior should be tested: Add bounded adverse-network
  scenarios that mix burst loss, delayed delivery, duplicate payloads, and
  receive deadline pressure.
- Example better test description: "UDP media transport keeps loss and late
  packet counters truthful during a bounded burst-loss and reorder sequence."
- Edge cases to include: burst gaps larger than one packet, sequence rollover
  plus duplicate, stale video fragment after frame completion, receive timeout,
  mixed audio/video stream IDs.
- Risk level: medium
- Confidence: high

## High-Risk Missing Tests

1. App execution lifecycle: start, failed start, stop-requested teardown,
   termination-handler finalization, and stale validation reset for
   `AppExecutionController`.
2. Rendered app/UI runtime-state smoke: no visible `live`, `connected`,
   `streaming`, or `validated` state without report-backed evidence.
3. Python connector end-to-end UDP selftests that do not silently skip when
   `127.0.0.2` is unavailable.
4. External connector real primary/auxiliary process behavior for non-mock
   audio-video launch, nonzero exit, auxiliary failure, and timeout.
5. Sustained adverse UDP media conditions: burst loss, jitter, duplicates,
   reorder, receive deadlines, and mixed stream IDs.

## Weak Tests To Rewrite

| Priority | Test | Rewrite target |
| --- | --- | --- |
| 1 | `AppShellBehaviorTests` validation-only controller coverage | Add real process lifecycle/state-transition tests. |
| 2 | `VerificationToolingContractTests.wslLoLaNetworkHelperUsesStrictDryRunAndScopedFirewallControls` | Replace no-`pwsh` source-token fallback with executable or explicit capability-gated behavior evidence. |
| 3 | `ReleaseArtifactHygieneContractTests.releaseHygienePolicyDocsManifestNoticeAndVerificationMatrixStayAligned` | Keep fewer docs-alignment assertions and prefer staged clean/contaminated candidate behavior. |
| 4 | `FixtureSmokeMatrixTests` / `ReportSchemaInventoryTests` overlap | Drive false-pass fixtures through public validators once per schema. |
| 5 | `SourceNamingConventionTests` naming-doc substring checks | Scan source filenames against the naming policy and exception list. |
| 6 | Python private-loop runtime tests | Move toward public runtime entry points with injected sockets/captures. |
| 7 | Mock-only external connector AV launch checks | Pair with real short-lived primary/auxiliary process execution. |
| 8 | Broad `semantic...TestsScenario` wrappers | Promote high-risk helpers to independent `@Test` declarations. |

## Tests That Are Valuable And Should Be Preserved

- `Tests/OpenLolaCoreTests/UdpMediaTransportTests.swift`: packet decoding,
  malformed payload rejection, loss/reorder/duplicate/clock-skew metrics, and
  raw video reassembly checks encode real protocol behavior.
- `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift`: validation evidence
  gating prevents stale or incomplete reports from producing live/validated UI
  state.
- `Tests/OpenLolaCoreTests/ExternalConnectorProcessGroupTests.swift`:
  `timedExternalConnectorRunKillsTermIgnoringDescendant` exercises a real
  process-tree teardown risk and should remain behavior-based.
- `Tests/OpenLolaCoreTests/ManagedProcessRunnerTests.swift`: deadline behavior
  and output capture tests protect real process-runner semantics.
- `linux_connector/tests/test_runtime_contracts.py`: malformed payload,
  failed-worker cleanup, stale task-handle, and event-loop-yield checks protect
  meaningful runtime behavior.
- `linux_connector/tests/test_process_runtime.py`: CLI bounds validation,
  process backend death reporting, and bounded JPEG capture tests are
  behavior-based despite some private-seam coupling.
- `Tests/OpenLolaCoreTests/SyntheticSmokeReportContractTests.swift`: preserve
  the core assertion that synthetic smoke reports remain `PARTIAL` and do not
  claim real-world readiness.

## Suggested Regression-Test Backlog

1. `AppExecutionController` process lifecycle regression suite:
   failed launch, nonzero exit, stop request, report written after stop,
   malformed report after process exit, and new run clears stale pass evidence.
2. Native app rendered-state smoke probe:
   launch/support-surface test that verifies status text and disabled controls
   follow real report/process state.
3. Python connector no-skip loopback fallback:
   use a portable two-socket localhost setup or emit a first-class capability
   report when alias binding is unavailable.
4. External connector process report regressions:
   real primary/auxiliary subprocesses for pass, nonzero exit, auxiliary
   failure, timeout, stdout/stderr capture, and process-group cleanup.
5. UDP adverse-condition table:
   burst loss, duplicate after rollover, delayed receive, mixed stream IDs,
   stale video fragment, and bounded receive timeout.
6. False-pass fixture validator sweep:
   every schema-declared false-pass fixture must fail through its public
   validator for the declared behavioral reason.
7. Docs/policy source-name gate:
   replace naming-doc token checks with actual source filename scanning and
   exception validation.

## Verification Commands

Documentation-only verification for this audit:

```bash
bash scripts/verify-docs.sh
```

Focused verification after future test rewrites:

```bash
swift test --filter AppShellBehaviorTests
swift test --filter NativeAppShell
swift test --filter ExternalConnectorProcessGroupTests
swift test --filter ManagedProcessRunnerTests
swift test --filter UdpMediaTransportTests
swift test --filter FixtureSmokeMatrixTests
swift test --filter ReportSchemaInventoryTests
PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector
```

Broad verification after changing test behavior:

```bash
swift test --no-parallel
bash scripts/verify-release-readiness.sh
```

## Remaining Uncertainty

- This audit sampled by risk bucket across a large active suite; it did not
  line-review all 462 Swift tests and 73 Python test declarations.
- Some string and documentation tests are intentional policy gates. They should
  be labeled and treated as policy coverage, not behavioral coverage.
- Hardware, signing, real app launch, real Windows LoLa, and real network
  timing evidence remain outside this local test-intent audit.
- The current suite has no disabled Swift tests found by the skip search, but
  Python has environment skips around loopback alias availability.
- Passing docs verification confirms this audit document is linked and
  path-valid; it does not validate the test-quality findings themselves.
