# Simplicity Remediation Plan

Date: 2026-05-16

Source: `docs/simplicity-test-certainty-audit.md`

Scope: planning only. This document does not change production code or tests.
Each slice is intended to be small, independently reviewable, and verifiable.
Where the audit says evidence is incomplete, the slice is explicitly labeled
`INVESTIGATION`.

Prioritization order used:

1. False success in critical paths.
2. Broken or missing tests for important behavior.
3. Over-engineering that hides correctness problems.
4. Deprecated or stale compatibility paths.
5. Single-use abstractions.
6. Duplication and boilerplate.
7. Cosmetic simplification.

## Remediation slices

### SIM-001: App stop must not finalize before process exit

- Slice ID: SIM-001
- Title: App stop must not finalize before process exit
- Findings addressed: STC-FL-001, STC-MC-001, STC-TI-001
- Problem: `AppExecutionController.stop()` can create a finished report after
  requesting termination, before process exit and log-close evidence exists.
- Minimal fix strategy: Add a regression test first. Then move stopped-report
  finalization to the termination-observed path or add explicit
  `terminationPending` evidence so the report cannot look final prematurely.
- Files likely affected: `Sources/open-lola-app/AppExecutionController.swift`,
  `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift`
- Behavior affected: app stop/report lifecycle and visible status truthfulness.
- Tests to add/update: start a long-running test process, call `stop()`, assert
  no final success/finished report exists until termination is observed; assert
  the final report includes stop and exit evidence.
- Verification commands: `swift test --filter AppShellBehaviorTests`
- Risk level: High
- Rollback strategy: Revert the controller and test changes for this slice only;
  no schema/storage changes should be bundled into the slice.
- Definition of Done: a stop request is distinguishable from observed process
  termination, and the test fails on premature report finalization.

### SIM-002: Validation launch failure must complete with explicit evidence

- Slice ID: SIM-002
- Title: Validation launch failure must complete with explicit evidence
- Findings addressed: STC-FL-001, STC-TI-001
- Problem: validation start failure sets failed UI state, but the audit found no
  completion-path evidence such as validation exit/launch-failed status.
- Minimal fix strategy: Add a focused missing-validator test, then route launch
  failure through the same report/evidence path with an explicit
  `validationLaunchFailed` or equivalent state.
- Files likely affected: `Sources/open-lola-app/AppExecutionController.swift`,
  `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift`
- Behavior affected: app validation failure reporting.
- Tests to add/update: missing validator executable; failed validator launch;
  stale previous validation evidence cleared before new validation attempt.
- Verification commands: `swift test --filter AppShellBehaviorTests`
- Risk level: Medium-high
- Rollback strategy: Revert this slice to restore previous validation failure
  flow; keep tests isolated so rollback does not affect stop handling.
- Definition of Done: validation that never launches is reported distinctly from
  validation that ran and failed, and stale success evidence is not reused.

### SIM-003: External connector process lifecycle evidence investigation

- Slice ID: SIM-003
- Title: External connector process lifecycle evidence investigation
- Findings addressed: STC-FL-002, STC-MC-002
- Problem: the audit found ignored wait/kill results and `Int32.min` wait-status
  sentinel behavior, but `ECHILD` reachability and required report shape need
  live source-level confirmation before implementation.
- Minimal fix strategy: INVESTIGATION. Trace all consumers of
  `ExternalConnectorProcessResult.exitStatus`, `terminatedAfterDuration`, and
  process-group cleanup. Document the minimal lifecycle states needed before
  changing code.
- Files likely affected: `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorProcessRunner.swift`,
  external connector report/tests
- Behavior affected: none in this investigation slice.
- Tests to add/update: none unless the investigation finds an existing test that
  misstates current behavior; then update the plan before implementation.
- Verification commands: `rg -n "ExternalConnectorProcessResult|terminatedAfterDuration|exitStatus|Int32.min" Sources Tests`
- Risk level: Low
- Rollback strategy: delete the investigation notes or revert the planning
  update; no production/test code changes.
- Definition of Done: a follow-up implementation slice can name exact lifecycle
  fields, affected report contracts, and tests.

### SIM-004: External connector cleanup failures must be report-visible

- Slice ID: SIM-004
- Title: External connector cleanup failures must be report-visible
- Findings addressed: STC-FL-002, STC-TI-007
- Problem: connector process reports can look bounded even when wait/kill/cleanup
  evidence is unknown.
- Minimal fix strategy: After SIM-003, replace ignored cleanup outcomes with the
  smallest explicit result state needed by reports. Prefer local enums/results
  over a general process framework.
- Files likely affected: `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorProcessRunner.swift`,
  `Tests/OpenLolaCoreTests/ExternalConnectorProcessGroupTests.swift`
- Behavior affected: external connector process result/report certainty.
- Tests to add/update: timeout cleanup, unknown wait status, failed wait/kill
  surfaced as uncertainty, normal successful exit unchanged.
- Verification commands: `swift test --filter ExternalConnectorProcessGroupTests`
- Risk level: High
- Rollback strategy: revert only the external connector result/report changes;
  keep ManagedProcessRunner and Python cleanup out of this slice.
- Definition of Done: connector reports cannot silently hide unknown exit or
  cleanup state.

### SIM-025: Unsupported app modes must be explicitly planning-only or hidden

- Slice ID: SIM-025
- Title: Unsupported app modes must be explicitly planning-only or hidden
- Findings addressed: STC-MC-005
- Problem: JackTrip and UltraGrid modes are represented in the app surface while
  execution paths report that they are not wired to app execution.
- Minimal fix strategy: Decide from current docs/tests whether these modes are
  active planning-only surfaces. If yes, label and gate them as planning-only.
  If not, hide them from executable UI. Do not add launcher behavior.
- Files likely affected: `Sources/OpenLolaCore/Platform/NativeAppShellSessionMode.swift`,
  app shell UI/model tests
- Behavior affected: app mode selection and execution-readiness messaging.
- Tests to add/update: unsupported modes cannot start as successful runs;
  planning-only status is visible where the mode remains selectable.
- Verification commands: `swift test --filter AppShell`,
  `swift test --filter NativeAppShell`
- Risk level: Medium
- Rollback strategy: restore the current mode visibility and tests if a current
  operator workflow requires the existing presentation.
- Definition of Done: unsupported connector modes cannot be mistaken for
  executable app modes.

### SIM-026: External connector AV tests need one real process path

- Slice ID: SIM-026
- Title: External connector AV tests need one real process path
- Findings addressed: STC-TI-007
- Problem: one external connector AV test path asserts mock runner invocation
  details, which does not prove real primary/auxiliary process behavior.
- Minimal fix strategy: Add one short-lived real primary/auxiliary process test
  for reporting behavior. Keep the mock test only for routing/orchestration.
- Files likely affected: `Tests/OpenLolaCoreTests/ExternalConnectorProcessGroupTests.swift`
- Behavior affected: test coverage only; production behavior unchanged unless
  the new test exposes a bug.
- Tests to add/update: real primary and auxiliary process pass, auxiliary
  failure, and timeout/reporting as separate small cases if needed.
- Verification commands: `swift test --filter ExternalConnectorProcessGroupTests`
- Risk level: Medium
- Rollback strategy: revert the real-process test additions if they are flaky,
  then replace with a more deterministic helper binary.
- Definition of Done: at least one external connector AV test proves real
  process status reporting instead of mock invocation counts.

### SIM-027: UDP media transport adverse-condition tests

- Slice ID: SIM-027
- Title: UDP media transport adverse-condition tests
- Findings addressed: STC-TI-008
- Problem: UDP media transport tests cover valuable deterministic packet cases
  but not sustained burst loss, jitter, duplicates, reorder, or receive deadline
  pressure.
- Minimal fix strategy: Add a bounded adverse-condition test table. Keep it
  deterministic and small enough for unit-test runtime.
- Files likely affected: `Tests/OpenLolaCoreTests/UdpMediaTransportTests.swift`
- Behavior affected: test coverage only unless the new tests reveal metric bugs.
- Tests to add/update: burst gaps larger than one packet, sequence rollover plus
  duplicate, stale video fragment, mixed stream IDs, bounded receive timeout.
- Verification commands: `swift test --filter UdpMediaTransportTests`
- Risk level: Medium
- Rollback strategy: revert or split any flaky adverse case; keep deterministic
  cases that prove stable behavior.
- Definition of Done: UDP media metric tests include bounded adverse network
  conditions with clear expected counters.

### SIM-005: ManagedProcessRunner teardown must expose uncertainty to callers

- Slice ID: SIM-005
- Title: ManagedProcessRunner teardown must expose uncertainty to callers
- Findings addressed: STC-FL-003, STC-MC-002
- Problem: `kill`, file-handle close, and post-kill wait outcomes are ignored in
  the generic managed process helper.
- Minimal fix strategy: Add tests around teardown evidence, then return a small
  teardown result from timeout termination paths used by report-producing
  callers. Do not add a broad process framework.
- Files likely affected: `Sources/OpenLolaCore/Support/ManagedProcessRunner.swift`,
  `Tests/OpenLolaCoreTests/ManagedProcessRunnerTests.swift`
- Behavior affected: app/process helper teardown certainty.
- Tests to add/update: forced timeout termination reports whether all processes
  exited; handle-close failure is visible where practical; existing run-to-exit
  behavior remains unchanged.
- Verification commands: `swift test --filter ManagedProcessRunnerTests`
- Risk level: High
- Rollback strategy: revert helper signature/result changes and dependent tests;
  keep external connector process-group code untouched.
- Definition of Done: report-producing callers can distinguish attempted cleanup
  from observed cleanup.

### SIM-006: Python backend cleanup uncertainty must be caller-visible

- Slice ID: SIM-006
- Title: Python backend cleanup uncertainty must be caller-visible
- Findings addressed: STC-FL-004, STC-TI-006
- Problem: Python process cleanup suppresses terminate/wait/kill `OSError`s at
  debug level and clears the process handle anyway.
- Minimal fix strategy: Add caller-visible cleanup status or warning collection
  to the backend/runtime stats. Keep cleanup best-effort, but do not hide
  uncertainty from callers.
- Files likely affected: `linux_connector/lola_connector/backends.py`,
  `linux_connector/tests/test_process_runtime.py`
- Behavior affected: Python connector process cleanup reporting.
- Tests to add/update: simulated terminate/wait/kill failures assert visible
  warning/status, not just debug logs.
- Verification commands: `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector`
- Risk level: Medium-high
- Rollback strategy: revert Python backend status additions and tests for this
  slice only.
- Definition of Done: cleanup failure is observable through a runtime-facing
  result, warning, or stats surface.

### SIM-007: UDP loopback must count malformed and fatal echo uncertainty

- Slice ID: SIM-007
- Title: UDP loopback must count malformed and fatal echo uncertainty
- Findings addressed: STC-FL-005
- Problem: malformed echo, wrong-size echo, and fatal connected receive errors
  can collapse into generic loss/timeout.
- Minimal fix strategy: Add report-visible counters/notes for malformed echo,
  wrong-size echo, and fatal receive error. Keep packet send/receive flow
  otherwise unchanged.
- Files likely affected: `Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackSocketRunners.swift`,
  UDP loopback tests
- Behavior affected: UDP loopback report metrics and certainty.
- Tests to add/update: inject malformed/wrong-size echo payloads and assert
  counters; assert valid byte-exact echo behavior remains unchanged.
- Verification commands: `swift test --filter UdpPcmLoopback`
- Risk level: Medium-high
- Rollback strategy: revert metric/report additions and tests; no route runner
  changes should be bundled.
- Definition of Done: loopback reports distinguish loss from malformed/fatal
  echo uncertainty.

### SIM-008: Continuous UDP smoke must fail on receiver join timeout

- Slice ID: SIM-008
- Title: Continuous UDP smoke must fail on receiver join timeout
- Findings addressed: STC-FL-005
- Problem: localhost continuous-route smoke ignores the receiver completion wait
  result before reading the result box.
- Minimal fix strategy: Add a test for receiver completion timeout, then check
  the semaphore result and emit a specific timeout error before reading the
  result box.
- Files likely affected: `Sources/OpenLolaCore/Network/UDP/UdpPcmContinuousRouteRunner.swift`,
  `Tests/OpenLolaCoreTests/UdpPcmContinuousReceiverTests.swift`
- Behavior affected: localhost continuous UDP smoke error reporting.
- Tests to add/update: receiver blocked or delayed beyond join deadline yields
  a specific receiver-completion timeout.
- Verification commands: `swift test --filter UdpPcmContinuousReceiverTests`
- Risk level: Medium
- Rollback strategy: revert the wait-result check and focused test.
- Definition of Done: ignored receiver join timeout is impossible in the smoke
  path.

### SIM-009: Continuous UDP receiver PASS must be derived from local counters

- Slice ID: SIM-009
- Title: Continuous UDP receiver PASS must be derived from local counters
- Findings addressed: STC-FL-005
- Problem: receiver reports can accept caller-provided PASS despite receive
  errors, high loss, or no valid packets.
- Minimal fix strategy: Add validation/derivation that blocks PASS when local
  counters violate explicit criteria. Keep the first pass narrow to receive
  errors and zero valid packets.
- Files likely affected: `Sources/OpenLolaCore/Network/UDP/UdpPcmContinuousRouteRunner.swift`,
  route report tests
- Behavior affected: UDP route report verdict semantics.
- Tests to add/update: PASS config plus receive errors fails/downgrades; zero
  valid packets cannot produce PASS; valid clean run unchanged.
- Verification commands: `swift test --filter UdpPcmContinuousReceiverTests`,
  `swift test --filter UdpPcmRouteReportTests`
- Risk level: Medium-high
- Rollback strategy: revert verdict guard and tests; do not alter packet format.
- Definition of Done: caller optimism alone cannot produce PASS in receiver
  reports.

### SIM-010: Release hygiene verdict labels must be scoped

- Slice ID: SIM-010
- Title: Release hygiene verdict labels must be scoped
- Findings addressed: STC-FL-007, STC-TI-002
- Problem: release scripts print generic `VERDICT: PASS`, which can be detached
  from the product `PARTIAL` caveat.
- Minimal fix strategy: Rename script verdict lines to scoped evidence labels,
  such as `HYGIENE_VERDICT: PASS`, and update tests to assert absence of
  product-level PASS.
- Files likely affected: `scripts/export-release-candidate.sh`,
  `scripts/verify-release-hygiene.sh`,
  `Tests/OpenLolaCoreTests/ReleaseArtifactHygieneContractTests.swift`
- Behavior affected: release/hygiene output semantics.
- Tests to add/update: scoped verdict output, no generic product PASS,
  contaminated candidate still fails.
- Verification commands: `swift test --filter ReleaseArtifactHygieneContractTests`,
  `bash scripts/verify-release-hygiene.sh`
- Risk level: Medium
- Rollback strategy: restore prior output strings and tests if downstream
  scripts require the old exact token; note such dependency before rollback.
- Definition of Done: hygiene PASS cannot be confused with product release PASS.

### SIM-011: Internal LoLa preflight must not encode not-required as launched PASS

- Slice ID: SIM-011
- Title: Internal LoLa preflight must not encode not-required as launched PASS
- Findings addressed: STC-FL-008
- Problem: internal LoLa executable preflight reports `.pass` with
  `launched: false`, which conflates "not required" with executable PASS.
- Minimal fix strategy: Add an explicit status or notes field value that
  distinguishes internal/not-required from launched-and-matched. Avoid changing
  unrelated external executable probes.
- Files likely affected: `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorExecutablePreflight.swift`,
  executable preflight tests
- Behavior affected: executable preflight report semantics.
- Tests to add/update: internal LoLa probe serializes as not-required/internal;
  aggregate wording remains scoped; external UltraGrid/JackTrip PASS unchanged.
- Verification commands: `swift test --filter ExternalConnectorExecutablePreflightTests`
- Risk level: Medium
- Rollback strategy: revert report status change and tests if schema consumers
  require the old field shape; document consumer before rollback.
- Definition of Done: no preflight consumer has to infer not-required from
  `launched: false` plus `verdict: pass`.

### SIM-012: LoLa status probe needs structured result

- Slice ID: SIM-012
- Title: LoLa status probe needs structured result
- Findings addressed: STC-FL-006
- Problem: `check_status` collapses ACK, timeout, malformed response, and wrong
  peer into a boolean result.
- Minimal fix strategy: Add a small result object for status checks. Keep a
  compatibility boolean wrapper only if current callers need it.
- Files likely affected: `linux_connector/lola_connector/connector.py`,
  linux connector tests
- Behavior affected: Python LoLa control status reporting.
- Tests to add/update: ACK, timeout, malformed datagram, wrong peer, auto
  dialect sends.
- Verification commands: `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector`
- Risk level: Medium
- Rollback strategy: keep the old boolean API as wrapper while reverting only
  structured result exposure if needed.
- Definition of Done: callers can tell why a status probe did not return ACK.

### SIM-013: Python UDP selftests need no-silent-skip path

- Slice ID: SIM-013
- Title: Python UDP selftests need no-silent-skip path
- Findings addressed: STC-TI-006
- Problem: Python end-to-end UDP selftests can skip when `127.0.0.2` is
  unavailable.
- Minimal fix strategy: Add a portable localhost two-socket fallback or emit a
  first-class capability report that makes the missing alias explicit in
  verification output.
- Files likely affected: `linux_connector/tests/test_process_runtime.py`,
  possibly linux connector test helpers
- Behavior affected: test coverage, not runtime behavior.
- Tests to add/update: adapt existing selftests to fallback or explicit
  capability assertion.
- Verification commands: `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector`
- Risk level: Medium
- Rollback strategy: revert only the test fallback/capability changes.
- Definition of Done: the end-to-end UDP coverage either runs portably or fails
  with a deliberate capability explanation instead of disappearing silently.

### SIM-014: False-pass fixtures must be tested through public validators

- Slice ID: SIM-014
- Title: False-pass fixtures must be tested through public validators
- Findings addressed: STC-TI-003, STC-MC-003
- Problem: inventory tests prove fixtures and ledgers agree, but not that every
  false-pass fixture fails through its public validator for the intended reason.
- Minimal fix strategy: Add a validator sweep for schema-declared false-pass
  fixtures before reducing inventory duplication.
- Files likely affected: `Tests/OpenLolaCoreTests/FixtureSmokeMatrixTests.swift`,
  `Tests/OpenLolaCoreTests/ReportSchemaInventoryTests.swift`,
  validator tests if a better home exists
- Behavior affected: test behavior only.
- Tests to add/update: every registered false-pass fixture is decoded and
  rejected by the public validator with the declared boundary reason.
- Verification commands: `swift test --filter FixtureSmokeMatrixTests`,
  `swift test --filter ReportSchemaInventoryTests`
- Risk level: Medium
- Rollback strategy: revert the validator sweep test if it proves too broad,
  then split by report family.
- Definition of Done: inventory agreement is backed by executable false-pass
  validation.

### SIM-015: Network diagnostics PASS scope investigation

- Slice ID: SIM-015
- Title: Network diagnostics PASS scope investigation
- Findings addressed: STC-FL-009
- Problem: network diagnostics can return `.pass` for reachability thresholds,
  while notes say this does not prove audio latency or Internet LoLa readiness.
- Minimal fix strategy: INVESTIGATION. Trace all consumers of
  `NetworkDiagnosticsReport.verdict` and determine whether any consumer treats
  it as product readiness.
- Files likely affected: network diagnostics source/tests, goal preflight tests
- Behavior affected: none in this investigation slice.
- Tests to add/update: none until a consumer ambiguity is found.
- Verification commands: `rg -n "NetworkDiagnosticsReport|networkDiagnosticsVerdict|validate-network-diagnostics|GoalRuntimePreflight" Sources Tests docs scripts`
- Risk level: Low
- Rollback strategy: delete investigation notes or update this plan; no code/test
  changes.
- Definition of Done: follow-up is either closed as correctly scoped or split
  into a concrete implementation slice with named consumers and tests.

### SIM-016: App settings mutation policy inline

- Slice ID: SIM-016
- Title: App settings mutation policy inline
- Findings addressed: STC-MC-010
- Problem: `AppSettingsMutationPolicy` is a single-use wrapper around a boolean
  and help text.
- Minimal fix strategy: Inline the policy into the local settings view or make
  it a private local computed property. Do not change UI behavior.
- Files likely affected: `Sources/open-lola-app/AppShellSettingsView.swift`,
  `Tests/OpenLolaCoreTests/AppShellSlice05Tests.swift`
- Behavior affected: none intended; UI disabled-state/help text must remain.
- Tests to add/update: update only if names or exact helper references change;
  keep disabled-state coverage.
- Verification commands: `swift test --filter AppShellSlice05Tests`
- Risk level: Low
- Rollback strategy: restore the tiny enum and test references.
- Definition of Done: same locked-settings behavior with fewer public/local
  symbols.

### SIM-017: ReportMetadataArtifact call-site investigation

- Slice ID: SIM-017
- Title: ReportMetadataArtifact call-site investigation
- Findings addressed: STC-MC-009
- Problem: the audit suggests `ReportMetadataArtifact` may be a marker protocol
  used mostly by tests, but confidence is not high enough for direct deletion.
- Minimal fix strategy: INVESTIGATION. Enumerate conformers and generic
  consumers. If only tests use it, create a follow-up inline/delete slice.
- Files likely affected: `Sources/OpenLolaCore/Evidence/ReportValidatorSurface.swift`,
  report schema tests
- Behavior affected: none in this investigation slice.
- Tests to add/update: none.
- Verification commands: `rg -n "ReportMetadataArtifact" Sources Tests`
- Risk level: Low
- Rollback strategy: remove investigation notes or leave finding blocked.
- Definition of Done: a follow-up slice can state whether deletion is safe and
  which tests prove report metadata remains covered.

### SIM-018: Network diagnostics parser reuse

- Slice ID: SIM-018
- Title: Network diagnostics parser reuse
- Findings addressed: STC-MC-011
- Problem: network diagnostics has a local `--key value` parser while a shared
  `KeyValueArgumentParser` already exists.
- Minimal fix strategy: First compare semantics. If equivalent, replace the
  local parser with the shared parser and keep command-specific validation local.
- Files likely affected: `Sources/OpenLolaCore/Network/Diagnostics/NetworkDiagnostics.swift`,
  parser/network diagnostics tests
- Behavior affected: CLI argument parsing for network diagnostics.
- Tests to add/update: unknown flag, missing value, invalid numeric value,
  dash-prefixed value if supported today.
- Verification commands: `swift test --filter KeyValueArgumentParser`,
  `swift test --filter NetworkDiagnostics`
- Risk level: Medium
- Rollback strategy: restore the local parser if semantics differ in a needed
  way.
- Definition of Done: network diagnostics shares parser behavior without losing
  command-specific validation.

### SIM-019: Legacy audio-compression dependency investigation

- Slice ID: SIM-019
- Title: Legacy audio-compression dependency investigation
- Findings addressed: STC-MC-006
- Problem: `--audio-compression` and persisted `audioCompression` remain as a
  legacy compatibility path.
- Minimal fix strategy: INVESTIGATION. Search active docs, scripts, tests,
  fixtures, app defaults, and report decoding for current dependency before any
  removal.
- Files likely affected: direct-peer command support, app defaults, docs/tests
- Behavior affected: none in this investigation slice.
- Tests to add/update: none until dependency status is known.
- Verification commands: `rg -n "audio-compression|audioCompression|legacyAudioCompression" Sources Tests docs scripts linux_connector`
- Risk level: Low
- Rollback strategy: leave compatibility path untouched.
- Definition of Done: a follow-up slice either keeps migration explicitly or
  removes/deprecates the CLI flag with named compatibility tests.

### SIM-020: Compiled inventory reduction investigation

- Slice ID: SIM-020
- Title: Compiled inventory reduction investigation
- Findings addressed: STC-MC-003, STC-TI-003
- Problem: compiled inventories duplicate metadata, but they may also be active
  release-policy gates.
- Minimal fix strategy: INVESTIGATION. For each inventory field family, map the
  current consumers and mark it `derive`, `keep`, or `delete candidate`.
- Files likely affected: inventory files, release readiness scripts, schema and
  fixture tests
- Behavior affected: none in this investigation slice.
- Tests to add/update: none.
- Verification commands: `rg -n "ReportSchemaInventory|FixtureSmokeMatrix|SourceOwnershipInventory|NetworkRouteCommandMatrix" Sources Tests docs scripts`
- Risk level: Low
- Rollback strategy: do not change code/tests in this slice; close as blocked if
  release gate dependency is real.
- Definition of Done: a concrete field-level reduction plan exists, or the
  inventories are documented as intentionally retained gates.

### SIM-021: App settings persistence reduction investigation

- Slice ID: SIM-021
- Title: App settings persistence reduction investigation
- Findings addressed: STC-MC-004
- Problem: app settings are represented as parallel property/key/hydration
  lists, but storage keys are compatibility surface.
- Minimal fix strategy: INVESTIGATION. Inventory every persisted key, runtime
  field, and migration path before changing storage code.
- Files likely affected: app settings/defaults/storage key files and tests
- Behavior affected: none in this investigation slice.
- Tests to add/update: none until the inventory identifies safe grouping.
- Verification commands: `rg -n "openLola\\.|AppStorageKeys|AppShellStoredDefaults|UserDefaults|audioCompression|audioTransport" Sources Tests`
- Risk level: Low
- Rollback strategy: keep current storage layout.
- Definition of Done: a future implementation slice can name exact fields to
  group and exact migration tests to protect.

### SIM-022: NMP workflow consumer investigation

- Slice ID: SIM-022
- Title: NMP workflow consumer investigation
- Findings addressed: STC-MC-007
- Problem: NMP plan/run/validate workflow may be broader than current active
  connector needs, but it is public CLI/report surface.
- Minimal fix strategy: INVESTIGATION. Map active CLI commands, validators,
  fixtures, docs, and release gates for each NMP stage before deleting or
  inlining anything.
- Files likely affected: NMP workflow/plan/preflight files, CLI inventory,
  schema inventory, docs/tests
- Behavior affected: none in this investigation slice.
- Tests to add/update: none until active consumers are classified.
- Verification commands: `rg -n "ExternalConnectorNmp|nmp" Sources Tests docs scripts`
- Risk level: Low
- Rollback strategy: leave workflow intact if active consumer evidence is
  strong.
- Definition of Done: each NMP stage is classified as keep, simplify, or delete
  candidate with a named verification path.

### SIM-023: Governance ledger reduction investigation

- Slice ID: SIM-023
- Title: Governance ledger reduction investigation
- Findings addressed: STC-MC-008
- Problem: deferred parity and audio-routing assumption ledgers may be docs-level
  governance encoded in source, but some release/schema gates may consume them.
- Minimal fix strategy: INVESTIGATION. Map ledger rows to active tests,
  validators, source ownership, docs gates, and release readiness before moving
  data out of source.
- Files likely affected: deferred parity and audio-routing ledger files,
  source ownership/schema tests, docs
- Behavior affected: none in this investigation slice.
- Tests to add/update: none until consumers are known.
- Verification commands: `rg -n "LoLaParityDeferred|AudioRoutingAssumptionLedger" Sources Tests docs scripts`
- Risk level: Low
- Rollback strategy: keep ledgers in source if they remain active release gates.
- Definition of Done: each ledger is classified as keep in source, move to docs,
  or reduce fields with exact tests.

### SIM-024: Broad semantic wrapper test locality cleanup

- Slice ID: SIM-024
- Title: Broad semantic wrapper test locality cleanup
- Findings addressed: STC-TI-005, STC-TI-004
- Problem: broad `semantic...TestsScenario` wrappers and aggregate synthetic
  smoke tests reduce failure locality.
- Minimal fix strategy: Pick one high-risk test file at a time. Promote only
  independent helper contracts to separate `@Test` declarations and split
  aggregate synthetic smoke families by behavior boundary.
- Files likely affected: selected Swift test files only
- Behavior affected: test diagnostics only; production behavior unchanged.
- Tests to add/update: refactor tests without changing asserted behavior.
- Verification commands: focused test filter for the touched file
- Risk level: Medium
- Rollback strategy: restore the previous aggregate test structure for that one
  file.
- Definition of Done: failures identify the specific behavior boundary rather
  than a broad scenario wrapper.

## Recommended execution order

1. SIM-001
2. SIM-002
3. SIM-003
4. SIM-004
5. SIM-005
6. SIM-006
7. SIM-007
8. SIM-008
9. SIM-009
10. SIM-010
11. SIM-011
12. SIM-012
13. SIM-013
14. SIM-014
15. SIM-015
16. SIM-016
17. SIM-017
18. SIM-018
19. SIM-019
20. SIM-020
21. SIM-021
22. SIM-022
23. SIM-023
24. SIM-024
25. SIM-025
26. SIM-026
27. SIM-027

## P0/P1 slices

There are no P0 slices in the source audit. P1-level slices are:

- SIM-001: app stop/report finalization.
- SIM-002: validation launch failure evidence.
- SIM-004: external connector cleanup visibility.
- SIM-005: managed process teardown evidence.
- SIM-006: Python backend cleanup visibility.
- SIM-007: UDP loopback malformed/fatal uncertainty.
- SIM-009: continuous UDP receiver PASS criteria.
- SIM-010: release hygiene scoped verdicts.
- SIM-013: Python UDP no-silent-skip coverage.

## Low-risk quick wins

- SIM-016: inline `AppSettingsMutationPolicy`.
- SIM-017: investigate `ReportMetadataArtifact` consumers.
- SIM-018: reuse `KeyValueArgumentParser` for network diagnostics if semantics
  match.
- SIM-019: search legacy `audioCompression` dependencies.
- SIM-020 through SIM-023: investigation-only slices that reduce uncertainty
  before any deletion.
- SIM-025: unsupported app-mode boundary cleanup if current tests/docs confirm
  planning-only intent.

## Blocked/uncertain items

- SIM-003 is blocked on consumer tracing before process result shape changes.
- SIM-015 is blocked on proving whether diagnostics PASS is consumed as product
  readiness.
- SIM-019 is blocked on active dependency search for legacy audio compression.
- SIM-020 is blocked on field-level inventory consumer mapping.
- SIM-021 is blocked on persisted-key and migration inventory.
- SIM-022 is blocked on active NMP CLI/docs/release consumer mapping.
- SIM-023 is blocked on ledger consumer mapping.
- Any app UI smoke requiring a launched macOS app remains blocked until that
  runtime probe is explicitly in scope.

## Final verification plan

Use the narrowest verification for each slice first. After related slices pass,
run the grouped checks below.

App lifecycle and UI state:

```bash
swift test --filter AppShellBehaviorTests
swift test --filter AppShellSlice05Tests
swift test --filter NativeAppShell
swift build --product open-lola-app
```

Process lifecycle:

```bash
swift test --filter ManagedProcessRunnerTests
swift test --filter ExternalConnectorProcessGroupTests
swift test --filter NetworkDiagnostics
PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector
```

UDP and network certainty:

```bash
swift test --filter UdpPcmLoopback
swift test --filter UdpPcmContinuousReceiverTests
swift test --filter UdpPcmRouteReportTests
swift test --filter UdpMediaTransportTests
```

Release and inventory gates:

```bash
swift test --filter ReleaseArtifactHygieneContractTests
swift test --filter FixtureSmokeMatrixTests
swift test --filter ReportSchemaInventoryTests
bash scripts/verify-release-hygiene.sh
bash scripts/verify-release-readiness.sh
```

Final broad checks after implementation work, not for this plan-only document:

```bash
swift test --no-parallel
bash scripts/verify-docs.sh
```

For this planning-only document, the required verification is:

```bash
bash scripts/verify-docs.sh
```
