# Test Intent Audit

Date: 2026-05-17

Scope: audit-only pass over the active Swift and Python test suite. No
production code or tests were changed. This pass inspected representative
high-risk tests, release/tooling tests, inventory tests, app/runtime-state tests,
and Python connector runtime tests. It did not line-review every assertion in
all test files.

Live inventory:

- Swift test files: 169 under `Tests/OpenLolaCoreTests/`.
- Python test files: 4 under `linux_connector/tests/`.
- Swift `@Test` declarations found by text inventory: 475.
- Python `def test_...` tests found by text inventory: 84.
- Active `docs/testing/test-quality-audit.md`: not present in this checkout.

Judgment rule used here: a test is only called valuable when it would fail if a
meaningful behavior or risk boundary changed incorrectly. Tests that only prove a
string, file path, count, or source-text fragment exists are treated as weak
unless that literal is itself the public contract.

## Findings

### TIA-001

- Test file: `Tests/OpenLolaCoreTests/LoLaQuickConnectFallbackTests.swift`
- Test name / symbol: `lolaUdpTransmitFallsBackToQuickConnectWhenStatusAckTimesOut`,
  `lolaUdpReceiveKeepsControlSocketAliveForPostConnectRetries`,
  `lolaUdpTxRxKeepsControlSocketAliveForPostConnectCommands`,
  `secondaryLoopbackAliasAvailable`
- Production behavior supposedly protected: LoLa UDP control fallback behavior
  when the status ACK path times out or post-connect commands need the control
  socket to remain alive.
- Why the current test is weak or missing:
  - Three runtime-heavy test bodies return immediately when
    `secondaryLoopbackAliasAvailable()` is false (`LoLaQuickConnectFallbackTests.swift:15-17`,
    `50-52`, `85-86`).
  - The availability probe returns a boolean after a best-effort bind to
    `127.0.0.2` (`LoLaQuickConnectFallbackTests.swift:389-395`).
  - A machine without that alias can report these tests as passing without
    exercising the fallback flow.
- What meaningful behavior should be tested: The suite should distinguish
  "passed fallback behavior" from "not exercised because loopback alias is
  missing".
- Example better test description: `LoLa fallback tests report explicit skip or
  environment requirement when secondary loopback alias is unavailable`.
- Edge cases to include:
  - Loopback alias unavailable.
  - Loopback alias available but peer bind times out.
  - Status ACK timeout followed by QuickConn success.
  - Control socket remains open for retry messages after initial QuickConn.
- If the business/runtime behavior changed incorrectly, would this test fail?
  Not always. On hosts without `127.0.0.2`, the runtime behavior is not tested.
- Risk level: high
- Confidence: high

### TIA-002

- Test file: `Tests/OpenLolaCoreTests/ReleaseRunConfigurationContractTests.swift`
- Test name / symbol:
  `releaseRunConfigurationsAndTestingIndexDocumentActiveHarnessContracts`
- Production behavior supposedly protected: Release harnesses remain active,
  documented, and represented in the testing index.
- Why the current test is weak or missing:
  - It builds a `contracts` array containing four source paths, configuration
    type names, and descriptions, but only asserts `contracts.count == 4`
    (`ReleaseRunConfigurationContractTests.swift:8-37`).
  - It does not verify those files exist, that the configuration symbols compile,
    that matching CLI commands run, or that the harnesses reject false PASS.
  - The remaining checks are hardcoded documentation substrings
    (`ReleaseRunConfigurationContractTests.swift:36-42`).
- What meaningful behavior should be tested: Release harnesses should be
  executable or decodable through their public CLI/report paths, and should fail
  when required measured/clean-Mac/signing evidence is absent.
- Example better test description: `Release validation harnesses reject PASS when
  required measured or clean-Mac evidence is missing`.
- Edge cases to include:
  - Missing output path.
  - Malformed report input.
  - Synthetic evidence trying to produce PASS.
  - Harness source or command removed while docs remain.
- If the business/runtime behavior changed incorrectly, would this test fail?
  Usually no. A harness could stop running correctly while docs text and array
  count still pass.
- Risk level: medium
- Confidence: high

### TIA-003

- Test file: `Tests/OpenLolaCoreTests/MachineReadableSurfaceContractTests.swift`
- Test name / symbol: `machineReadableInventoryAndMatrixJSONSurfacesRoundTrip`
- Production behavior supposedly protected: Machine-readable CLI/report surfaces
  round-trip as JSON and keep verdict vocabulary stable.
- Why the current test is weak or missing:
  - Each case calls an `OpenLolaCLI.*Data()` wrapper, decodes it, and compares it
    to the same underlying report factory (`MachineReadableSurfaceContractTests.swift:8-80`).
  - It pins wrapper count with `surfaceCases.count == 10`
    (`MachineReadableSurfaceContractTests.swift:83`) rather than proving the
    executable CLI surfaces emit the expected JSON and verdict lines.
  - This can pass if both wrapper and report factory are hardcoded together while
    a CLI command is missing or emits a wrong status.
- What meaningful behavior should be tested: The executable CLI commands should
  emit parseable JSON and truthful verdict lines for every active surface.
- Example better test description: `Inventory CLI commands emit parseable JSON
  whose decoded report validates and whose terminal verdict matches product
  evidence policy`.
- Edge cases to include:
  - Missing `VERDICT:` line.
  - CLI command exists in inventory but not executable router.
  - JSON encodes but report validation fails.
  - PASS emitted for synthetic/partial-only surface.
- If the business/runtime behavior changed incorrectly, would this test fail?
  Only partly. It would fail if the report factory changes, but not necessarily
  if executable CLI routing or output framing breaks.
- Risk level: medium
- Confidence: high

### TIA-004

- Test file: `Tests/OpenLolaCoreTests/ReportSchemaInventoryTests.swift`
- Test name / symbol:
  `reportSchemaInventoryCoversMetadataCommandsFixturesSyntheticSmokesAndOwners`,
  `assertReportMetadataArtifact`
- Production behavior supposedly protected: Report schemas expose metadata and
  stay connected to validators, fixtures, synthetic smokes, and owners.
- Why the current test is weak or missing:
  - The first assertions call a no-op generic helper to prove compile-time
    conformance to `ReportMetadataArtifact` (`ReportSchemaInventoryTests.swift:51-57`,
    `166`).
  - The same test then checks inventory wiring, file existence, notes, and policy
    string fragments (`ReportSchemaInventoryTests.swift:59-98`).
  - This is mixed with valuable false-pass fixture behavior in a separate test
    (`ReportSchemaInventoryTests.swift:122-153`), but the metadata portion does
    not prove that metadata fields are meaningful, non-empty in decoded reports,
    or shown in public validation output.
- What meaningful behavior should be tested: Decoded report fixtures that claim
  metadata should expose meaningful `title`, `capturedAt`, and `notes`, and
  validators should reject metadata omissions where the contract requires them.
- Example better test description: `Metadata-backed report fixtures decode with
  non-empty title, capture time, and notes used by validator output`.
- Edge cases to include:
  - Empty title.
  - Missing or malformed capture timestamp.
  - Notes that remove evidence boundary wording.
  - Metadata protocol conformance without real encoded fields.
- If the business/runtime behavior changed incorrectly, would this test fail?
  No for metadata semantics. It only proves the type conforms and paths exist.
- Risk level: medium
- Confidence: high

### TIA-005

- Test file: `Tests/OpenLolaCoreTests/CodeLineBudgetTests.swift`
- Test name / symbol: `scopedCodeFilesStayWithinLineBudget`
- Production behavior supposedly protected: First-party files stay within agreed
  line budgets and stale exceptions are detected.
- Why the current test is weak or missing:
  - It is a repository policy scanner embedded in Swift unit tests. It walks
    `Package.swift`, `Sources`, `Tests`, `scripts`, `script`,
    `linux_connector`, `private`, and `.github` (`CodeLineBudgetTests.swift:15-24`).
  - It counts physical newlines and applies extension-based budgets
    (`CodeLineBudgetTests.swift:27-57`, `118-132`, `198-202`).
  - This may enforce a useful maintainability rule, but it does not verify
    runtime or business behavior. A broken media path can still pass while a
    harmless long test helper fails.
- What meaningful behavior should be tested: Keep line-budget enforcement as a
  hygiene gate, but pair it with behavior tests for the risks that large files
  tend to hide: state transitions, failure propagation, malformed packets, and
  false PASS prevention.
- Example better test description: `Realtime and app-controller files over the
  budget must either be split or have explicit behavior coverage for state,
  failure, and edge cases`.
- Edge cases to include:
  - Stale exception file.
  - Oversized file in runtime-critical path.
  - Generated/vendor files ignored deliberately.
  - Behavior coverage missing for an oversized high-risk file.
- If the business/runtime behavior changed incorrectly, would this test fail?
  No. It fails on size, not behavior.
- Risk level: low
- Confidence: high

### TIA-006

- Test file:
  `Tests/OpenLolaCoreTests/SourceOwnershipInventoryTests.swift`,
  `Tests/OpenLolaCoreTests/RealtimeAudioPathInventoryTests.swift`,
  `Tests/OpenLolaCoreTests/NetworkRouteCommandMatrixTests.swift`,
  `Tests/OpenLolaCoreTests/VideoControlDegradeMatrixTests.swift`,
  `Tests/OpenLolaCoreTests/FixtureSmokeMatrixTests.swift`
- Test name / symbol: inventory/matrix path-existence and ledger-shape tests
- Production behavior supposedly protected: Release/readiness inventories stay
  synchronized with active sources, tests, docs, commands, fixtures, and
  evidence-boundary policy.
- Why the current test is weak or missing:
  - Several tests assert non-empty strings and `FileManager.default.fileExists`
    for ledger paths (`SourceOwnershipInventoryTests.swift:7-28`,
    `RealtimeAudioPathInventoryTests.swift:7-17`,
    `NetworkRouteCommandMatrixTests.swift:7-22`,
    `VideoControlDegradeMatrixTests.swift:7-21`,
    `FixtureSmokeMatrixTests.swift:24-35`).
  - These tests are useful drift guards, but many assertions would pass if the
    referenced production behavior were wrong, untested, or unreachable.
  - Some tests do encode meaningful policy, such as keeping NAT/diagnostic/local
    smokes out of fastest evidence (`NetworkRouteCommandMatrixTests.swift:35-56`)
    and keeping video/control surfaces disarmed and degrade-first
    (`VideoControlDegradeMatrixTests.swift:33-64`). The weak part is the
    path/ledger shape checks.
- What meaningful behavior should be tested: Each high-risk inventory row should
  be backed by at least one behavior test that exercises the runtime/report
  policy it claims, not only by an existing file path.
- Example better test description: `Every fastest-direct route matrix row has a
  behavior test proving its PASS/partial boundary and every excluded route cannot
  contribute to fastest evidence`.
- Edge cases to include:
  - Inventory row points to a test file that only checks literals.
  - Command exists but emits wrong verdict.
  - Fixture count matches while validator accepts false PASS.
  - High-risk source path exists but has no negative tests.
- If the business/runtime behavior changed incorrectly, would this test fail?
  Often no for path-existence tests; yes for the specific policy tests noted
  above.
- Risk level: medium
- Confidence: high

### TIA-007

- Test file: `Tests/OpenLolaCoreTests/ReleaseArtifactHygieneContractTests.swift`
- Test name / symbol:
  `releaseHygienePolicyDocsManifestNoticeAndVerificationMatrixStayAligned`,
  `releaseVerificationContractsCoverArchivedPlanDocsTimeoutsAndPythonTooling`
- Production behavior supposedly protected: Release boundaries, dependency
  tooling, archived plan handling, and documentation stay aligned with release
  verification.
- Why the current test is weak or missing:
  - The alignment test mostly checks literal strings across docs and manifests
    (`ReleaseArtifactHygieneContractTests.swift:4-38`).
  - The verification-contract test checks archived file locations, docs checker
    output, workflow timeout math, exact Python dependencies, and text in
    `docs/testing/README.md` (`ReleaseArtifactHygieneContractTests.swift:146-226`).
  - These assertions can prevent drift, but many would pass if the release
    workflow no longer exercises the intended behavior.
  - The same file also contains valuable behavior tests that stage a release
    candidate and inject generated residue to confirm failures
    (`ReleaseArtifactHygieneContractTests.swift:40-143`, `283-397`).
- What meaningful behavior should be tested: Prefer executing the release
  scripts against synthetic clean and contaminated candidates over checking docs
  and YAML text directly.
- Example better test description: `Release hygiene rejects generated, private,
  archive, and extra vendor artifacts from both live checkout and staged release
  candidate`.
- Edge cases to include:
  - Dirty live checkout with generated residue.
  - Candidate containing `.build`, `__pycache__`, `.ruff_cache`, or extra vendor
    test directories.
  - Workflow omits a gate but docs still mention it.
  - Dependency lock policy violated by unbounded dependency.
- If the business/runtime behavior changed incorrectly, would this test fail?
  The literal alignment tests might not; the script execution tests likely
  would.
- Risk level: medium
- Confidence: high

### TIA-008

- Test file: `Tests/OpenLolaCoreTests/AppBundleScriptSourcePolicyTests.swift`
- Test name / symbol:
  `buildAndRunScriptStagesAppCliPermissionsSignatureAndDebugLaunch`
- Production behavior supposedly protected: The app bundle script stages app/CLI
  binaries, permissions, signing, debug launch, and UI evidence hooks.
- Why the current test is weak or missing:
  - The test uses fake tool logs and checks build/codesign/lldb command text
    (`AppBundleScriptSourcePolicyTests.swift:12-32`).
  - It reads the script source and asserts it contains `require_any_ui_label`,
    `"Remote unavailable"`, and `"LoLa not measured"`
    (`AppBundleScriptSourcePolicyTests.swift:17`, `33-35`).
  - That proves the script contains literal hooks, not that a built app window
    renders truthful runtime status or that screenshots/accessibility evidence
    are captured.
- What meaningful behavior should be tested: A launch probe should run the app
  bundle, capture process evidence, accessibility text, and screenshot evidence,
  and verify visible status does not claim connected/healthy/ready without
  runtime proof.
- Example better test description: `Native app launch probe captures visible UI
  evidence and rejects optimistic connected/validated status before runtime
  evidence exists`.
- Edge cases to include:
  - App launches but no accessibility text is captured.
  - Screenshot missing or blank.
  - UI shows validated/live without report evidence.
  - CLI binary missing from app bundle.
- If the business/runtime behavior changed incorrectly, would this test fail?
  Not reliably. Source text can remain while UI launch evidence breaks.
- Risk level: high
- Confidence: high

### TIA-009

- Test file: `Tests/OpenLolaCoreTests/VerificationToolingContractTests.swift`
- Test name / symbol:
  `semanticVerificationToolingContractTestsScenario`,
  `releaseReadinessScriptDefinesLocalVerificationMatrix`,
  `ciWorkflowRunsSameReleaseReadinessScriptWithoutPublishingArtifacts`
- Production behavior supposedly protected: Local release readiness, CI workflow,
  manual gates, and helper scripts remain aligned and do not publish artifacts.
- Why the current test is weak or missing:
  - The top-level `@Test` is a scenario wrapper that calls helper functions
    rather than registering each behavior as a separate Swift test
    (`VerificationToolingContractTests.swift:4-11`).
  - The release matrix test stubs shell functions and checks output strings
    (`VerificationToolingContractTests.swift:13-74`).
  - The CI workflow test reads YAML and asserts literal substrings and forbidden
    substrings (`VerificationToolingContractTests.swift:90-103`).
  - These are useful guardrails but can pass if a command listed in the matrix
    fails when actually run.
- What meaningful behavior should be tested: Each critical gate should have a
  behavior test or script execution path that proves it fails loudly on a
  synthetic broken input and succeeds on a minimal valid input.
- Example better test description: `Release readiness matrix executes every
  configured gate or stubs only external hardware gates while preserving failure
  propagation`.
- Edge cases to include:
  - Listed CLI probe exits non-zero.
  - A timed step times out.
  - Manual gate accidentally runs as a pass-producing automated gate.
  - CI workflow includes publishing or upload actions.
- If the business/runtime behavior changed incorrectly, would this test fail?
  Only if the changed behavior alters the listed text or stubbed output.
- Risk level: medium
- Confidence: medium

### TIA-010

- Test file: `Tests/OpenLolaCoreTests/GoalRuntimeEvidenceTemplateTests.swift`
- Test name / symbol:
  `goalRuntimeEvidenceTemplateCarriesRequiredCommandsAndValidators`,
  `goalRuntimeEvidenceTemplateCommandsCoverEveryAdvertisedSurface`,
  `goalRuntimeEvidenceTemplateValidatorPrintsBothVerdicts`
- Production behavior supposedly protected: Runtime evidence template lists the
  commands and validators needed to move product evidence beyond PARTIAL.
- Why the current test is weak or missing:
  - It joins command templates and checks substring presence for command names,
    signing commands, notarization commands, and validators
    (`GoalRuntimeEvidenceTemplateTests.swift:6-30`).
  - It checks every advertised local surface has a command template containing
    the command word (`GoalRuntimeEvidenceTemplateTests.swift:32-42`).
  - It asserts exact validator output lines
    (`GoalRuntimeEvidenceTemplateTests.swift:57-72`).
  - These tests do not prove the command templates parse, run, write reports, or
    validate the reports they claim to produce.
- What meaningful behavior should be tested: Template commands should be
  machine-checkable against the active CLI command inventory and validator
  registry, and critical templates should run in dry-run or fixture mode when
  possible.
- Example better test description: `Every runtime evidence template command maps
  to an active CLI command and its advertised validator rejects a malformed or
  false-PASS report`.
- Edge cases to include:
  - Command string names an inactive CLI command.
  - Validator name exists but does not reject false PASS.
  - Template omits required output/report path.
  - Surface advertises local runnable workflow without executable command.
- If the business/runtime behavior changed incorrectly, would this test fail?
  Not necessarily. It mainly protects template text and exact validator output.
- Risk level: medium
- Confidence: high

### TIA-011

- Test file: `Tests/OpenLolaCoreTests/SyntheticSmokeReportContractTests.swift`
- Test name / symbol: `syntheticSmokeReportsValidateAsPartialWithoutClaimingRuntimePass`
- Production behavior supposedly protected: Synthetic smoke reports validate as
  PARTIAL and do not claim runtime/field readiness.
- Why the current test is weak or missing:
  - The behavioral intent is important and many assertions would fail if a
    synthetic report changed to PASS (`SyntheticSmokeReportContractTests.swift:6-219`).
  - The test also pins a hardcoded case count with `smokeCases.count == 23`
    (`SyntheticSmokeReportContractTests.swift:221`).
  - Most smoke cases only validate the happy synthetic report and inspect a few
    fields; they do not mutate each report toward false PASS and confirm
    validator rejection.
- What meaningful behavior should be tested: Every synthetic smoke report should
  have a paired negative assertion that setting PASS or adding runtime-readiness
  claims fails validation.
- Example better test description: `Every synthetic smoke report rejects PASS or
  field-readiness claims without measured evidence`.
- Edge cases to include:
  - Synthetic report verdict changed to PASS.
  - Synthetic run mode changed to measured.
  - Real-world verdict changed to PASS.
  - Missing evidence-boundary notes.
- If the business/runtime behavior changed incorrectly, would this test fail?
  Yes for many direct verdict changes; not for all false-PASS variants because
  most cases lack targeted negative mutation.
- Risk level: high
- Confidence: medium

### TIA-012

- Test file: multiple Swift files with `semantic...TestsScenario` wrappers
- Test name / symbol: 45 `semantic...TestsScenario` functions found by live
  inventory, including `semanticAppShellBehaviorTestsScenario`,
  `semanticMadiReceiveTestsScenario`,
  `semanticVerificationToolingContractTestsScenario`, and
  `semanticLoLaQuickConnectFallbackTestsScenario`
- Production behavior supposedly protected: Many unrelated behaviors are grouped
  under one top-level Swift Testing test per file.
- Why the current test is weak or missing:
  - The scenario wrapper pattern registers one `@Test` and calls helper
    functions manually. Example: `AppShellBehaviorTests.swift:7-15` and
    `VerificationToolingContractTests.swift:4-11`.
  - Failures still fail the wrapper, so this is not a correctness hole by
    itself. The weakness is reporting, filtering, and intent clarity: the
    registered test name often says "semantic scenario" instead of the specific
    behavior that matters.
  - This makes it easier to skip or rerun too broad a target and harder to see
    which behavioral contract is missing coverage.
- What meaningful behavior should be tested: Risk-bearing behaviors should be
  individually registered with names that state the reason the behavior matters,
  especially failure/partial/PASS boundaries.
- Example better test description: `Direct-peer validation rejects stale
  supervisor metrics even when last validation exit code is zero`.
- Edge cases to include:
  - One helper silently returns early.
  - One helper is never called by the scenario wrapper.
  - A developer filters by a behavior name and misses the wrapper.
  - Test reports show only the wrapper name for several separate failures.
- If the business/runtime behavior changed incorrectly, would this test fail?
  Often yes if the helper runs, but reporting/filtering can hide which behavior
  was supposed to be protected.
- Risk level: low
- Confidence: high

### TIA-013

- Test file: `MISSING` from unit test suite; related evidence appears in
  `scripts/verify-release-readiness.sh` and `AppBundleScriptSourcePolicyTests`
- Test name / symbol: native app launch and rendered runtime-status test
- Production behavior supposedly protected: The macOS app must not show
  connected, live, validated, or healthy states without runtime/report evidence.
- Why the current test is weak or missing:
  - Model-level tests cover app state and validation evidence thoroughly
    (`AppShellBehaviorTests.swift:17-84`, `133-381`).
  - Source-level bundle script tests check script text and fake tool logs
    (`AppBundleScriptSourcePolicyTests.swift:12-35`).
  - Release readiness includes `run_native_app_launch_probe`, which requires
    process evidence, accessibility UI text, and screenshot evidence
    (`scripts/verify-release-readiness.sh:167-176`, `204-205`).
  - The unit test suite does not itself launch the real app and assert rendered
    UI state against runtime evidence.
- What meaningful behavior should be tested: A launch-level smoke should verify
  the visible UI state reflects `PARTIAL`/not measured until validation evidence
  exists.
- Example better test description: `Launched app renders not-measured state and
  does not show live/validated until a valid runtime report is loaded`.
- Edge cases to include:
  - No report exists.
  - Malformed report exists.
  - Partial external connector report exists.
  - Passing report exists but runtime evidence is stale or from wrong mode.
- If the business/runtime behavior changed incorrectly, would this test fail?
  No current unit test proves the rendered app state. The release script may
  catch launch-evidence failures if it is run.
- Risk level: high
- Confidence: medium

### TIA-014

- Test file: `linux_connector/tests/test_codec.py`;
  `linux_connector/tests/test_process_runtime.py`
- Test name / symbol: `require_loopback_alias`
- Production behavior supposedly protected: Linux connector self-tests can run
  loopback UDP flows that need `127.0.0.2`.
- Why the current test is weak or missing:
  - Python helper `require_loopback_alias` calls `pytest.skip` when the alias is
    not available (`test_codec.py:59-66`, `test_process_runtime.py:45-49`).
  - Unlike the Swift early returns in TIA-001, these are explicit pytest skips.
    The remaining weakness is that core connector loopback behavior may be
    absent from routine runs on hosts without the alias.
- What meaningful behavior should be tested: CI or local verification should
  report skipped loopback capability separately from behavioral PASS, and a
  socket-free fallback test should still exercise parser/state failure paths.
- Example better test description: `Connector loopback tests skip explicitly
  when alias is unavailable and socket-free contract tests still cover timeout
  and malformed control behavior`.
- Edge cases to include:
  - Alias unavailable.
  - Alias available but bind fails after readiness.
  - Timeout without incoming QuickConn.
  - Malformed control/media payload.
- If the business/runtime behavior changed incorrectly, would this test fail?
  Only on hosts where the alias-dependent tests actually run. Socket-free
  runtime contract tests cover some fallback behavior separately.
- Risk level: medium
- Confidence: medium

## High-Risk Missing Tests

1. Native rendered UI runtime-state smoke: the suite needs an explicit app launch
   check that visible UI state stays not-measured/partial until runtime evidence
   exists. Release readiness has a launch probe, but unit tests mostly cover
   models and script text.
2. Explicit skip/failure accounting for Swift LoLa fallback tests when
   `127.0.0.2` is unavailable. Silent `return` makes a skipped runtime path look
   green.
3. Per-synthetic-report false-PASS mutation tests. The aggregate synthetic smoke
   test verifies many PARTIAL outputs but does not mutate every report into a
   forbidden PASS claim.
4. Behavior-backed coverage for inventory rows. Many rows prove file paths and
   strings exist; high-risk rows should map to behavior tests that would fail if
   evidence boundaries or validators were wrong.
5. Template command executability checks for `GoalRuntimeEvidenceTemplate`.
   Command substrings should be tied to active CLI commands and validators.

## Weak Tests To Rewrite

| Priority | Test | Rewrite goal |
|---:|---|---|
| 1 | `LoLaQuickConnectFallbackTests` early-return guards | Replace silent returns with explicit skip/failure accounting and socket-free fallback coverage. |
| 2 | `ReleaseRunConfigurationContractTests` | Replace docs/count assertions with executable release-harness behavior and false-PASS rejection. |
| 3 | `AppBundleScriptSourcePolicyTests` UI label source checks | Add actual launch/rendered-state proof, or keep source checks only as secondary guardrails. |
| 4 | `MachineReadableSurfaceContractTests` | Test executable CLI JSON/verdict output, not only wrappers against their own factories. |
| 5 | `ReportSchemaInventoryTests` metadata conformance helper | Replace no-op marker checks with decoded metadata behavior and validator expectations. |
| 6 | Inventory/matrix path-existence tests | Keep drift checks, but add behavior-backed evidence for high-risk entries. |
| 7 | `GoalRuntimeEvidenceTemplateTests` command substring checks | Cross-check templates against active CLI/parser/validator behavior. |
| 8 | `CodeLineBudgetTests` | Keep as hygiene, but do not treat it as behavior coverage. |

## Tests That Are Valuable And Should Be Preserved

- `AppShellBehaviorTests`: model-level app tests verify that live/validated state
  requires actual evidence, validation launch failure remains explicit, stale
  metrics are cleared, malformed reports fail, partial/fail reports do not pass,
  and PASS remains gated by runtime evidence (`AppShellBehaviorTests.swift:17-84`,
  `133-381`). These would fail on meaningful false-success regressions.
- `ReportSchemaInventoryTests.reportSchemaFalsePassFixturesFailThroughPublicValidators`:
  iterates registered false-pass fixtures and runs public validators, failing if
  a false-PASS fixture validates unexpectedly (`ReportSchemaInventoryTests.swift:122-153`).
- `ReleaseArtifactHygieneContractTests.releaseExportScriptStagesAllowlistedCandidateAndRunsHygieneGate`
  and `releaseHygieneScriptScansLiveAndCandidateGeneratedResidue`: run scripts
  and inject forbidden artifacts, so they would fail if hygiene stops rejecting
  generated/private/vendor residue (`ReleaseArtifactHygieneContractTests.swift:40-143`,
  `283-397`).
- `linux_connector/tests/test_runtime_contracts.py`: timeout, ready-event,
  worker failure, stale task, uninitialized socket, malformed media/control, and
  event-loop-yield tests encode failure behavior rather than only output strings
  (`test_runtime_contracts.py:17-39`, `89-188`, `218-290`).
- `LoLaCompatibilityMediaCodecTests.lolaFragmentReassemblyRejectsDuplicateMissingWrongPreludeAndInconsistentHeaders`:
  covers duplicate fragments, missing fragments, wrong prelude frame IDs,
  inconsistent fragment counts, invalid final flags, and oversized counts/sizes
  (`LoLaCompatibilityMediaCodecTests.swift:281-380`).
- `BoundedFileReaderTests`: oversized input and undecodable text are negative
  tests around input safety, not just happy-path decode checks
  (`BoundedFileReaderTests.swift:6-53`).
- `ManagedProcessRunnerTests`: process timeout and forced-kill outcome tests
  would catch false exit/cleanup regressions (`ManagedProcessRunnerTests.swift:25-73`).
- `VideoControlDegradeMatrixTests` policy tests for disarmed control surfaces and
  degrade-before-audio impact are valuable even though the file also contains
  path-existence checks (`VideoControlDegradeMatrixTests.swift:33-64`).
- `NetworkRouteCommandMatrixTests.networkRouteCommandMatrixKeepsNatDiagnosticsAndLocalSmokesOutOfFastestEvidence`
  preserves a meaningful product-evidence boundary
  (`NetworkRouteCommandMatrixTests.swift:35-56`).

## Suggested Regression-Test Backlog

1. Add explicit Swift skip/failure reporting for environment-dependent LoLa
   fallback tests and add socket-free contract tests for fallback state
   transitions.
2. Add a native app rendered-state smoke that captures process evidence,
   accessibility text, and screenshot, then asserts the UI does not claim live or
   validated without evidence.
3. Convert release harness docs/count tests into public command/report tests
   that reject missing, malformed, synthetic, and false-PASS evidence.
4. Replace `ReportMetadataArtifact` compile-only assertions with decoded report
   fixture tests for metadata semantics.
5. Add a generated command/validator cross-check for runtime evidence template
   command lines.
6. Add behavior coverage mapping for high-risk inventory rows: every fastest
   route, app status, report schema, and video/control degrade policy row should
   point to at least one negative or state-transition test.
7. Split high-value `semantic...TestsScenario` wrappers into individually
   registered `@Test` functions where the behavior is high-risk, especially
   false PASS, validation, process lifecycle, and runtime network paths.

## Verification Commands

Use focused checks before broad checks:

```bash
swift test --filter AppShellBehaviorTests
swift test --filter LoLaQuickConnectFallbackTests
swift test --filter ReportSchemaInventoryTests
swift test --filter ReleaseRunConfigurationContractTests
swift test --filter MachineReadableSurfaceContractTests
swift test --filter ReleaseArtifactHygieneContractTests
swift test --filter AppBundleScriptSourcePolicyTests
swift test --filter VerificationToolingContractTests
swift test --filter SyntheticSmokeReportContractTests
PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector
bash scripts/verify-docs.sh
```

For final confidence after rewriting tests:

```bash
swift test --no-parallel
bash scripts/verify-release-readiness.sh
```

## Remaining Uncertainty

- This pass did not inspect every assertion in all 475 Swift `@Test`
  declarations and 84 Python tests.
- Some literal strings are public contracts in this repo, especially verdict
  vocabulary and CLI names. The audit flags weak literal-only tests where the
  literal is not enough to prove behavior.
- Several inventory tests are deliberately release-readiness ledgers. They are
  useful drift guards, but they should not be counted as behavior coverage unless
  paired with executable behavior tests.
- The release-readiness app launch probe may cover some rendered UI risk outside
  normal unit-test runs. That should be treated as a separate gate, not proof
  that the unit test suite covers rendered UI state.
