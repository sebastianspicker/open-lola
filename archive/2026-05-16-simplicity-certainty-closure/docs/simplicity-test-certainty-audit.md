# Simplicity, Test-Quality, and Certainty Audit

Date: 2026-05-16

Scope: consolidation of these source audits only:

- `docs/overengineering-index.md`
- `docs/minimum-code-audit.md`
- `docs/test-intent-audit.md`
- `docs/fail-loud-audit.md`

Hard boundary: this document does not add new source-code findings. It merges,
prioritizes, and cross-references findings already supported by the four source
audits. Production code and tests were not changed.

## 1. Executive summary

The highest-risk cluster is not "too much code" by itself. It is code whose
complexity makes certainty hard to prove: app process state, subprocess cleanup,
external connector lifecycle reports, UDP report verdicts, and release PASS
labels. These areas need behavior tests before simplification.

The clearest low-risk simplification candidates are single-use or governance
surfaces that source audits found to be mostly policy/documentation scaffolding:
`AppSettingsMutationPolicy`, `ReportMetadataArtifact`, and compiled assumption
ledgers. These still need targeted checks because some are wired into release
and docs gates.

The test audit does not say the test suite is weak overall. It identifies weak
coverage at the boundaries where behavior matters most: app lifecycle, cleanup
failures, no-skip Python UDP selftests, real external connector processes,
adverse UDP media conditions, and false-pass fixture validation.

## 2. Source audit coverage

| Source audit | Covered | Finding IDs used | Notable uncertainty preserved |
| --- | --- | --- | --- |
| `docs/overengineering-index.md` | Source, tests, linux connector, scripts, active docs; vendored/archived treated as background | `OE-001` through `OE-014` | Not line-by-line across all files; several findings mark runtime intent `UNCLEAR`. |
| `docs/minimum-code-audit.md` | Current source, tests, active docs relevant to minimum-code changes | `MCA-001` through `MCA-016` | App not run; external connector process behavior not exercised live; some ledgers may be intentional release gates. |
| `docs/test-intent-audit.md` | Active Swift/Python tests and testing docs | `TIA-001` through `TIA-013` | Risk-bucket sampling, not all tests line-reviewed; some string/doc tests are intentional policy gates. |
| `docs/fail-loud-audit.md` | Runtime, validation, UI, release hygiene, process, UDP, and LoLa connector certainty paths | `FLA-001` through `FLA-012` | Representative high-risk inspection, not every source line; runtime probes were not executed. |

## 3. Consolidated findings index

| ID | Theme | Severity | File / area | Source IDs |
| --- | --- | --- | --- | --- |
| STC-MC-001 | MINIMUM_CODE | P1 | App execution controller | `MCA-001` |
| STC-MC-002 | MINIMUM_CODE | P1 | Process runner family | `MCA-002` |
| STC-MC-003 | MINIMUM_CODE | P2 | Compiled inventories and matrices | `OE-001`, `OE-002`, `OE-003`, `OE-004`, `MCA-005` |
| STC-MC-004 | MINIMUM_CODE | P2 | App settings persistence | `OE-007`, `MCA-006` |
| STC-MC-005 | MINIMUM_CODE | P2 | Unsupported/planning-only app modes | `OE-009`, `MCA-008` |
| STC-MC-006 | MINIMUM_CODE | P2 | Legacy `--audio-compression` path | `OE-010`, `MCA-009` |
| STC-MC-007 | MINIMUM_CODE | P2 | NMP workflow surfaces | `OE-011`, `MCA-012` |
| STC-MC-008 | MINIMUM_CODE | P2 | Governance ledgers in source | `OE-005`, `OE-006`, `MCA-010`, `MCA-011` |
| STC-MC-009 | MINIMUM_CODE | P2 | Validation/report helper abstractions | `OE-012`, `OE-013`, `OE-014`, `MCA-013`, `MCA-014`, `MCA-015` |
| STC-MC-010 | MINIMUM_CODE | P3 | Single-use settings mutation policy | `OE-008`, `MCA-007` |
| STC-MC-011 | MINIMUM_CODE | P2 | CLI parser duplication | `MCA-004` |
| STC-TI-001 | TEST_INTENT | P1 | App lifecycle and rendered UI tests | `TIA-001`, `TIA-012`, `FLA-012` |
| STC-TI-002 | TEST_INTENT | P2 | Source-token and docs-string tests | `TIA-002`, `TIA-003`, `TIA-004`, `TIA-005` |
| STC-TI-003 | TEST_INTENT | P2 | Inventory tests that prove alignment more than behavior | `TIA-006` |
| STC-TI-004 | TEST_INTENT | P2 | Synthetic smoke aggregate test locality | `TIA-007` |
| STC-TI-005 | TEST_INTENT | P2 | Broad semantic wrapper tests | `TIA-008` |
| STC-TI-006 | TEST_INTENT | P1 | Python UDP/runtime tests and skips | `TIA-009`, `TIA-010` |
| STC-TI-007 | TEST_INTENT | P2 | Mock-heavy external connector AV tests | `TIA-011` |
| STC-TI-008 | TEST_INTENT | P2 | UDP adverse-condition gaps | `TIA-013` |
| STC-FL-001 | FAIL_LOUD | P1 | App stop/report/validation state | `FLA-001`, `FLA-002`, `MCA-001`, `TIA-001` |
| STC-FL-002 | FAIL_LOUD | P1 | External connector process cleanup | `FLA-004`, `MCA-003`, `MCA-002` |
| STC-FL-003 | FAIL_LOUD | P1 | Managed process cleanup | `FLA-005`, `MCA-002` |
| STC-FL-004 | FAIL_LOUD | P1 | Python process cleanup | `FLA-006` |
| STC-FL-005 | FAIL_LOUD | P1 | UDP loopback and continuous route certainty | `FLA-007`, `FLA-008`, `FLA-009` |
| STC-FL-006 | FAIL_LOUD | P2 | LoLa status boolean | `FLA-010` |
| STC-FL-007 | FAIL_LOUD | P1 | Release hygiene PASS labels | `FLA-011`, `TIA-003` |
| STC-FL-008 | FAIL_LOUD | P2 | Internal LoLa executable preflight PASS | `FLA-003` |
| STC-FL-009 | FAIL_LOUD | P2 | Network diagnostics scoped PASS | `MCA-016` |

## 4. Minimum-code findings

### STC-MC-001

- ID: STC-MC-001
- Source audit(s): `docs/minimum-code-audit.md`
- Original finding ID(s): `MCA-001`
- Theme: MINIMUM_CODE
- Severity: P1
- File: `Sources/open-lola-app/AppExecutionController.swift`
- Symbol or line range: `AppExecutionController`, `start`, `launchProcess`,
  `runOneShot`, `stop`, `finishReport`
- Evidence: The source audit says one observable controller owns settings,
  phase, status text, commands, log paths, reports, metrics, capture reports,
  validation exit codes, error log, timers, process handles, stop state, and
  execution kind. It also notes separate direct execution, operator-surface,
  validation, report refresh, stop, and teardown paths.
- Why it matters: The amount of mutable state makes it hard to prove UI status,
  report state, and process lifecycle remain synchronized.
- Suggested remediation: First add behavior tests for current lifecycle
  semantics. Then constrain execution result state into one private value and
  make report finalization single-owner.
- Test or verification needed: `swift test --filter AppShell`,
  `swift test --filter NativeAppShell`, and an app build/run smoke when
  practical.
- Risk of change: High, because this is user-visible process lifecycle state.
- Confidence: high

### STC-MC-002

- ID: STC-MC-002
- Source audit(s): `docs/minimum-code-audit.md`
- Original finding ID(s): `MCA-002`
- Theme: MINIMUM_CODE
- Severity: P1
- File: `Sources/OpenLolaCore/Support/ManagedProcessRunner.swift`,
  `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorProcessRunner.swift`,
  `Sources/OpenLolaCore/Network/Diagnostics/NetworkDiagnostics.swift`
- Symbol or line range: `ManagedProcessRunner`,
  `ExternalConnectorProcessRunner`, `runNetworkDiagnosticsProcess`
- Evidence: The minimum-code audit found at least three subprocess
  implementations for bounded output, timeout handling, termination, and pipe
  capture; external connectors add POSIX process-group behavior.
- Why it matters: Duplicated process behavior increases the chance that only one
  path handles timeout, output capture, or cleanup truthfully.
- Suggested remediation: Inventory exact semantic differences first. Share only
  small repeated helpers where semantics match; keep process-group behavior
  local if it is genuinely connector-specific.
- Test or verification needed: `swift test --filter ManagedProcessRunner`,
  `swift test --filter ExternalConnector`, `swift test --filter
  NetworkDiagnostics`.
- Risk of change: High, due to process cleanup and runtime-report semantics.
- Confidence: high

### STC-MC-003

- ID: STC-MC-003
- Source audit(s): `docs/overengineering-index.md`,
  `docs/minimum-code-audit.md`
- Original finding ID(s): `OE-001`, `OE-002`, `OE-003`, `OE-004`, `MCA-005`
- Theme: MINIMUM_CODE
- Severity: P2
- File: `Sources/OpenLolaCore/Evidence/ReportSchemaInventory.swift`,
  `Sources/OpenLolaCore/Support/Inventories/FixtureSmokeMatrixData.swift`,
  `Sources/OpenLolaCore/Support/Inventories/SourceOwnershipInventory.swift`,
  `Sources/OpenLolaCore/Support/Inventories/NetworkRouteCommandMatrix.swift`
- Symbol or line range: `ReportSchemaInventory`, `FixtureSmokeMatrix`,
  `SourceOwnershipInventory`, `NetworkRouteCommandMatrix`
- Evidence: Both source audits found hand-maintained compiled inventories that
  repeat command names, fixture names/counts, source paths, owners, validators,
  smoke commands, tests, and release-readiness metadata.
- Why it matters: Tests can become proofs that duplicate ledgers agree instead
  of proofs that validators and runtime contracts behave correctly.
- Suggested remediation: Pick one authority per concern, derive other views from
  it where possible, and keep only fields consumed by current CLI, docs,
  verifier, or release gates.
- Test or verification needed: inventory, fixture, source ownership, route
  matrix, machine-readable surface, and release-readiness checks named in the
  source audits.
- Risk of change: High for release/docs gates, medium for runtime.
- Confidence: high

### STC-MC-004

- ID: STC-MC-004
- Source audit(s): `docs/overengineering-index.md`,
  `docs/minimum-code-audit.md`
- Original finding ID(s): `OE-007`, `MCA-006`
- Theme: MINIMUM_CODE
- Severity: P2
- File: `Sources/open-lola-app/AppSettings.swift`,
  `Sources/open-lola-app/AppStorageKeys.swift`,
  `Sources/open-lola-app/AppShellStoredDefaults.swift`
- Symbol or line range: `AppSettings`, `AppStorageKeys`,
  `AppShellStoredDefaults`
- Evidence: The audits found parallel field lists for observable settings,
  string keys, manual UserDefaults writes, stored-default hydration, runtime
  command fields, and SwiftUI bindings.
- Why it matters: Adding or renaming settings can desynchronize persistence,
  UI, and runtime behavior.
- Suggested remediation: Keep storage keys stable, but group load/save behavior
  closer to typed setting structs or a small field table with migration tests.
- Test or verification needed: app settings round-trip tests and
  `NativeAppShellOpusCommandTests`.
- Risk of change: Medium to high because UserDefaults are a compatibility
  surface.
- Confidence: high

### STC-MC-005

- ID: STC-MC-005
- Source audit(s): `docs/overengineering-index.md`,
  `docs/minimum-code-audit.md`
- Original finding ID(s): `OE-009`, `MCA-008`
- Theme: MINIMUM_CODE
- Severity: P2
- File: `Sources/OpenLolaCore/Platform/NativeAppShellSessionMode.swift`,
  `Sources/open-lola-app/AppExecutionController.swift`
- Symbol or line range: `NativeAppShellSessionMode`,
  `start(operatorSurface:execute:)`
- Evidence: The app models direct Mac peer, Windows LoLa, JackTrip, and
  UltraGrid modes, but JackTrip and UltraGrid are explicitly not wired to app
  execution.
- Why it matters: Unsupported modes add UI and execution branching and can imply
  runnable behavior unless presented as planning-only.
- Suggested remediation: Hide unsupported modes from executable UI, mark them
  explicitly planning-only, or remove app-mode plumbing after proving no active
  contract requires it.
- Test or verification needed: app shell mode tests and rendered UI smoke.
- Risk of change: Medium.
- Confidence: medium

### STC-MC-006

- ID: STC-MC-006
- Source audit(s): `docs/overengineering-index.md`,
  `docs/minimum-code-audit.md`
- Original finding ID(s): `OE-010`, `MCA-009`
- Theme: MINIMUM_CODE
- Severity: P2
- File: `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVRunTypes.swift`,
  `Sources/open-lola/Commands/Network/DirectP2PSessionRunCommandSupport.swift`,
  `Sources/open-lola-app/AppShellStoredDefaults.swift`
- Symbol or line range: `DirectPeerSessionAudioCompression`,
  `DirectPeerSessionAudioTransport.legacyAudioCompression`,
  `--audio-compression`
- Evidence: The audits found a legacy CLI/storage path for `audioCompression`
  that maps to `audioTransport`, rejects conflicts, hides old help, and migrates
  old app defaults.
- Why it matters: Two names model overlapping behavior, and the legacy name
  cannot represent the newer transport space.
- Suggested remediation: Keep app storage migration until proven unnecessary;
  remove or deprecate the CLI flag only after active scripts/docs/tests no
  longer require it.
- Test or verification needed: direct-peer Opus CLI tests and app migration
  tests.
- Risk of change: Medium.
- Confidence: high

### STC-MC-007

- ID: STC-MC-007
- Source audit(s): `docs/overengineering-index.md`,
  `docs/minimum-code-audit.md`
- Original finding ID(s): `OE-011`, `MCA-012`
- Theme: MINIMUM_CODE
- Severity: P2
- File: `Sources/OpenLolaCore/Connectors/NMP/ExternalConnectorNmpWorkflow.swift`
- Symbol or line range: NMP plan/run/validate workflow
- Evidence: Source audits describe a broad workflow that coordinates plan,
  preflight, endpoint run, validation, report artifacts, and multi-connector
  options.
- Why it matters: A generic connector workflow may exceed current Mac-native
  LoLa needs and preserve stages that only forward configuration.
- Suggested remediation: Inventory active CLI, docs, tests, and release-gate
  consumers. Inline or delete stages that add no validation.
- Test or verification needed: `swift test --filter ExternalConnectorNmp`,
  CLI inventory tests, and schema inventory tests.
- Risk of change: Medium.
- Confidence: medium

### STC-MC-008

- ID: STC-MC-008
- Source audit(s): `docs/overengineering-index.md`,
  `docs/minimum-code-audit.md`
- Original finding ID(s): `OE-005`, `OE-006`, `MCA-010`, `MCA-011`
- Theme: MINIMUM_CODE
- Severity: P2
- File: `Sources/OpenLolaCore/Release/LoLaParityDeferredFeatures.swift`,
  `Sources/OpenLolaCore/Audio/Routing/AudioRoutingAssumptionLedger.swift`
- Symbol or line range: deferred parity and assumption ledgers
- Evidence: The audits found source-compiled governance ledgers for deferred
  parity and audio-routing assumptions, with tests/fixtures/schema rows but no
  clear runtime consumer for all fields.
- Why it matters: Governance data can look like executable behavior and expand
  source/test surface without solving runtime behavior.
- Suggested remediation: Keep only fields consumed by current release/schema
  gates; move explanatory or aspirational detail to active docs.
- Test or verification needed: deferred-feature, source-ownership, docs, schema,
  and release-readiness checks.
- Risk of change: Medium.
- Confidence: medium

### STC-MC-009

- ID: STC-MC-009
- Source audit(s): `docs/overengineering-index.md`,
  `docs/minimum-code-audit.md`
- Original finding ID(s): `OE-012`, `OE-013`, `OE-014`, `MCA-013`, `MCA-014`,
  `MCA-015`
- Theme: MINIMUM_CODE
- Severity: P2
- File: `Sources/OpenLolaCore/Core/ValidationPrimitives.swift`,
  `Sources/OpenLolaCore/Evidence/ReportValidatorSurface.swift`,
  `Sources/OpenLolaCore/Support/BoundedFileReader.swift`
- Symbol or line range: validation primitive protocols,
  `ReportMetadataArtifact`, report read convenience extension
- Evidence: The audits identify protocol/helper layers that may exceed current
  use: conditional validation helper protocols, a metadata marker protocol, and
  domain-specific report reading layered on bounded file I/O.
- Why it matters: Helper lattices can make validators test helper mechanics
  instead of report outcomes.
- Suggested remediation: Keep broadly used validation and bounded I/O behavior;
  inline marker or single-use convenience layers only after call-site inventory.
- Test or verification needed: validation primitive, report schema, fixture
  validation, bounded reader, and affected validator tests.
- Risk of change: Medium.
- Confidence: medium for validation primitives, lower for read convenience.

### STC-MC-010

- ID: STC-MC-010
- Source audit(s): `docs/overengineering-index.md`,
  `docs/minimum-code-audit.md`
- Original finding ID(s): `OE-008`, `MCA-007`
- Theme: MINIMUM_CODE
- Severity: P3
- File: `Sources/open-lola-app/AppShellSettingsView.swift`
- Symbol or line range: `AppSettingsMutationPolicy`
- Evidence: Both audits found a single-use enum wrapping one `isRunning`
  boolean and two help strings.
- Why it matters: It adds a named policy surface without a cross-module policy.
- Suggested remediation: Inline the boolean/help text or keep a private local
  helper if it improves readability.
- Test or verification needed: `swift test --filter AppShellSlice05Tests`.
- Risk of change: Low.
- Confidence: high

### STC-MC-011

- ID: STC-MC-011
- Source audit(s): `docs/minimum-code-audit.md`
- Original finding ID(s): `MCA-004`
- Theme: MINIMUM_CODE
- Severity: P2
- File: `Sources/OpenLolaCore/Network/Diagnostics/NetworkDiagnostics.swift`
- Symbol or line range: `parseNetworkDiagnosticsArguments`,
  `KeyValueArgumentParser`
- Evidence: The minimum-code audit found network diagnostics still has a local
  `--key value` parser while many command paths already use
  `KeyValueArgumentParser`.
- Why it matters: Hand-written parsers can drift in unknown-flag, missing-value,
  and dash-prefixed-value behavior.
- Suggested remediation: Use `KeyValueArgumentParser` only where semantics match
  exactly; keep specialized validation where it adds real behavior.
- Test or verification needed: parser and network diagnostics tests, including
  unknown flag, missing value, invalid number, and dash-prefixed values.
- Risk of change: Medium.
- Confidence: high

## 5. Test-intent findings

### STC-TI-001

- ID: STC-TI-001
- Source audit(s): `docs/test-intent-audit.md`,
  `docs/fail-loud-audit.md`
- Original finding ID(s): `TIA-001`, `TIA-012`, `FLA-012`
- Theme: TEST_INTENT
- Severity: P1
- File: `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift`,
  native app shell test files
- Symbol or line range: app execution validation and native app shell tests
- Evidence: Source audits say validation evidence gating is tested, but real
  start, failed launch, stop-requested teardown, termination-handler
  finalization, rendered status text, dead menu/action behavior, and stale
  validation reset are not sufficiently exercised.
- Why it matters: The highest-risk app certainty problems can survive a green
  suite if only validation finishing is tested.
- Suggested remediation: Add behavior tests for real short-lived processes,
  failed executable launch, stop lifecycle, malformed reports, stale pass reset,
  and rendered/report-backed status.
- Test or verification needed: focused app shell tests plus app build/run smoke.
- Risk of change: High.
- Confidence: high for controller gaps; medium for rendered UI gap.

### STC-TI-002

- ID: STC-TI-002
- Source audit(s): `docs/test-intent-audit.md`
- Original finding ID(s): `TIA-002`, `TIA-003`, `TIA-004`, `TIA-005`
- Theme: TEST_INTENT
- Severity: P2
- File: `Tests/OpenLolaCoreTests/VerificationToolingContractTests.swift`,
  `Tests/OpenLolaCoreTests/ReleaseArtifactHygieneContractTests.swift`,
  `Tests/OpenLolaCoreTests/SourceNamingConventionTests.swift`,
  `Tests/OpenLolaCoreTests/CodeLineBudgetTests.swift`
- Symbol or line range: source-token, docs-string, naming, and line-budget
  policy tests
- Evidence: The test audit found tests that assert source strings, docs
  substrings, naming examples, dependency lists, or line counts. Some are useful
  policy gates but do not prove behavior.
- Why it matters: These tests can pass while operational behavior is wrong or
  fail for safe behavior-preserving edits.
- Suggested remediation: Label policy gates as policy coverage and pair them
  with executable behavior checks where runtime or release behavior is claimed.
- Test or verification needed: runnable dry-run PowerShell evidence when
  available, contaminated release candidate behavior tests, source filename
  scanning against policy, and subsystem behavior tests named in line-budget
  exceptions.
- Risk of change: Low to medium.
- Confidence: high

### STC-TI-003

- ID: STC-TI-003
- Source audit(s): `docs/test-intent-audit.md`
- Original finding ID(s): `TIA-006`
- Theme: TEST_INTENT
- Severity: P2
- File: `Tests/OpenLolaCoreTests/FixtureSmokeMatrixTests.swift`,
  `Tests/OpenLolaCoreTests/ReportSchemaInventoryTests.swift`
- Symbol or line range: fixture/schema inventory tests
- Evidence: The test audit says these tests mostly prove inventories agree and
  paths/counts exist, not that every false-pass validator rejects the bad
  evidence for the declared behavioral reason.
- Why it matters: Duplicate inventory agreement can hide validator regressions.
- Suggested remediation: For each high-risk false-pass fixture, decode through
  the public validator and assert the declared rejection.
- Test or verification needed: fixture smoke, schema inventory, and public
  validator filters.
- Risk of change: Medium.
- Confidence: high

### STC-TI-004

- ID: STC-TI-004
- Source audit(s): `docs/test-intent-audit.md`
- Original finding ID(s): `TIA-007`
- Theme: TEST_INTENT
- Severity: P2
- File: `Tests/OpenLolaCoreTests/SyntheticSmokeReportContractTests.swift`
- Symbol or line range: `syntheticSmokeReportsValidateAsPartialWithoutClaimingRuntimePass`
- Evidence: The audit says the central intent is strong, but 23 cases are
  packed into one aggregate test with a hardcoded case count and many literal
  field assertions.
- Why it matters: A failure lacks locality, and harmless report-shape evolution
  can fail the test.
- Suggested remediation: Preserve the `PARTIAL`/no-real-world-claim intent, but
  split high-risk smoke families into named behavior tests.
- Test or verification needed: synthetic smoke report filters and report
  validation fixtures.
- Risk of change: Medium.
- Confidence: high

### STC-TI-005

- ID: STC-TI-005
- Source audit(s): `docs/test-intent-audit.md`
- Original finding ID(s): `TIA-008`
- Theme: TEST_INTENT
- Severity: P2
- File: `Tests/OpenLolaCoreTests/*Tests.swift`
- Symbol or line range: 45 `semantic...TestsScenario` wrappers
- Evidence: The test audit found many single `@Test` wrappers that call
  multiple intent-rich helpers.
- Why it matters: Behavior may be covered, but failure locality is poor and
  independent contracts can be hidden inside broad scenarios.
- Suggested remediation: Promote high-risk helpers to independent `@Test`
  declarations where they represent separate runtime, parser, evidence, or
  state-transition contracts.
- Test or verification needed: affected focused Swift test filters.
- Risk of change: Medium.
- Confidence: medium

### STC-TI-006

- ID: STC-TI-006
- Source audit(s): `docs/test-intent-audit.md`
- Original finding ID(s): `TIA-009`, `TIA-010`
- Theme: TEST_INTENT
- Severity: P1
- File: `linux_connector/tests/test_process_runtime.py`,
  `linux_connector/tests/test_runtime_contracts.py`
- Symbol or line range: private runtime loop tests and UDP selftests
- Evidence: The audit found good Python runtime intent, but several tests call
  private loops or monkeypatch internals. The only Python end-to-end UDP
  selftests can skip when `127.0.0.2` is unavailable.
- Why it matters: Public runtime behavior and portable end-to-end coverage can
  disappear while internals remain tested.
- Suggested remediation: Prefer public runtime entry points with injected
  sockets/captures and add a no-skip localhost fallback or explicit capability
  report for loopback alias gaps.
- Test or verification needed: linux connector pytest suite with no bytecode and
  explicit environment-skip reporting.
- Risk of change: Medium to high.
- Confidence: high

### STC-TI-007

- ID: STC-TI-007
- Source audit(s): `docs/test-intent-audit.md`
- Original finding ID(s): `TIA-011`
- Theme: TEST_INTENT
- Severity: P2
- File: `Tests/OpenLolaCoreTests/ExternalConnectorProcessGroupTests.swift`
- Symbol or line range: `jackTripAudioVideoProcessRunUsesInjectedProcessRunnerForPrimaryAndAuxiliary`
- Evidence: The audit says part of the test asserts mock runner invocation
  counts, process IDs, and executable strings; the same file has better real
  descendant-kill coverage.
- Why it matters: Mock orchestration tests can pass while real process-group
  behavior breaks.
- Suggested remediation: Keep mock routing coverage but pair it with real
  short-lived primary/auxiliary process runs for pass, nonzero exit, auxiliary
  failure, timeout, and capture.
- Test or verification needed: external connector process group tests.
- Risk of change: Medium.
- Confidence: medium

### STC-TI-008

- ID: STC-TI-008
- Source audit(s): `docs/test-intent-audit.md`
- Original finding ID(s): `TIA-013`
- Theme: TEST_INTENT
- Severity: P2
- File: `Tests/OpenLolaCoreTests/UdpMediaTransportTests.swift`
- Symbol or line range: UDP media transport packet and metric tests
- Evidence: The audit says existing tests are valuable but short and
  deterministic; sustained/adverse timing coverage is missing.
- Why it matters: Longer burst loss, jitter, duplicate, reorder, and receive
  deadline bugs can escape.
- Suggested remediation: Add bounded adverse-network table tests for burst
  gaps, rollover plus duplicate, stale video fragments, receive timeout, and
  mixed audio/video stream IDs.
- Test or verification needed: `swift test --filter UdpMediaTransportTests`.
- Risk of change: Medium.
- Confidence: high

## 6. Fail-loud findings

### STC-FL-001

- ID: STC-FL-001
- Source audit(s): `docs/fail-loud-audit.md`,
  `docs/minimum-code-audit.md`, `docs/test-intent-audit.md`
- Original finding ID(s): `FLA-001`, `FLA-002`, `MCA-001`, `TIA-001`
- Theme: FAIL_LOUD
- Severity: P1
- File: `Sources/open-lola-app/AppExecutionController.swift`
- Symbol or line range: `stop()`, `runOneShot`, `finishReport`
- Evidence: The fail-loud audit says `stop()` immediately finalizes a report
  after terminate request, before exit/log-close evidence. It also says
  validation launch failure sets failed UI state without calling completion or
  setting validation-exit evidence.
- Why it matters: UI/report state can imply final stopped or failed validation
  state when the process or validator lifecycle is still uncertain.
- Suggested remediation: Add explicit lifecycle states for termination pending,
  termination observed, validation launch failed, and report finalization; make
  report finalization single-owner.
- Test or verification needed: app lifecycle tests for start, failed start,
  stop, nonzero exit, stale validation reset, malformed reports, and manual app
  smoke.
- Risk of change: High.
- Confidence: high for stop finalization, medium for validation-start
  completion impact.

### STC-FL-002

- ID: STC-FL-002
- Source audit(s): `docs/fail-loud-audit.md`,
  `docs/minimum-code-audit.md`
- Original finding ID(s): `FLA-004`, `MCA-003`, `MCA-002`
- Theme: FAIL_LOUD
- Severity: P1
- File: `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorProcessRunner.swift`
- Symbol or line range: `waitForExternalConnectorProcess`,
  `terminateExternalConnectorProcessGroup`, `cleanupExternalConnectorProcessGroup`,
  wait-status handling
- Evidence: Source audits identify ignored wait/kill results and `ECHILD`
  mapped to `Int32.min`, which can flow into process results as exit status.
- Why it matters: Connector reports can look bounded and clean while cleanup or
  exit-status evidence is unknown.
- Suggested remediation: Replace magic wait-status sentinel and ignored cleanup
  returns with structured lifecycle evidence.
- Test or verification needed: external connector process-group tests for
  timeout, child cleanup, unknown wait status, failed wait/kill visibility.
- Risk of change: High.
- Confidence: high for ignored cleanup, medium for `ECHILD` reachability.

### STC-FL-003

- ID: STC-FL-003
- Source audit(s): `docs/fail-loud-audit.md`,
  `docs/minimum-code-audit.md`
- Original finding ID(s): `FLA-005`, `MCA-002`
- Theme: FAIL_LOUD
- Severity: P1
- File: `Sources/OpenLolaCore/Support/ManagedProcessRunner.swift`
- Symbol or line range: `killImmediately`, `closeOutputHandles`, `terminate`
- Evidence: The fail-loud audit says kill return values, file-handle close
  errors, and the second wait result after SIGKILL are ignored.
- Why it matters: App and CLI callers can clear process state despite incomplete
  teardown evidence.
- Suggested remediation: Return teardown evidence where reports or UI depend on
  it; keep fire-and-forget only for paths that never claim final success.
- Test or verification needed: `ManagedProcessRunnerTests` with visible failed
  cleanup outcomes.
- Risk of change: High.
- Confidence: high

### STC-FL-004

- ID: STC-FL-004
- Source audit(s): `docs/fail-loud-audit.md`
- Original finding ID(s): `FLA-006`
- Theme: FAIL_LOUD
- Severity: P1
- File: `linux_connector/lola_connector/backends.py`
- Symbol or line range: `ManagedProcessCapture._close_process`
- Evidence: The fail-loud audit says terminate/wait/kill `OSError`s are logged
  at debug level and `self.process` is set to `None` regardless.
- Why it matters: Runtime can proceed as if a backend is closed while external
  process state remains uncertain.
- Suggested remediation: Return cleanup status or add cleanup warnings to
  runtime stats/report output.
- Test or verification needed: linux connector process-runtime tests that assert
  caller-visible cleanup uncertainty.
- Risk of change: Medium to high.
- Confidence: high

### STC-FL-005

- ID: STC-FL-005
- Source audit(s): `docs/fail-loud-audit.md`
- Original finding ID(s): `FLA-007`, `FLA-008`, `FLA-009`
- Theme: FAIL_LOUD
- Severity: P1
- File: `Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackSocketRunners.swift`,
  `Sources/OpenLolaCore/Network/UDP/UdpPcmContinuousRouteRunner.swift`
- Symbol or line range: `runSenderLoop`, `waitForConnectedEcho`,
  `UdpPcmContinuousRouteLocalhostSmoke.run`, `runReceiverLoop`
- Evidence: Fail-loud findings identify malformed echo/drop ambiguity, ignored
  receiver completion timeout, and caller-provided PASS verdicts despite local
  receive errors.
- Why it matters: Network reports can collapse protocol errors, timeout,
  concurrency failure, and caller optimism into loss or PASS.
- Suggested remediation: Add malformed/wrong-size/fatal counters, explicit
  receiver join timeout, and verdict derivation or validation that blocks PASS
  with receive errors/high loss/no packets.
- Test or verification needed: UDP loopback malformed echo tests, continuous
  receiver join-timeout tests, and report-verdict validation tests.
- Risk of change: Medium to high.
- Confidence: medium-high

### STC-FL-006

- ID: STC-FL-006
- Source audit(s): `docs/fail-loud-audit.md`
- Original finding ID(s): `FLA-010`
- Theme: FAIL_LOUD
- Severity: P2
- File: `linux_connector/lola_connector/connector.py`
- Symbol or line range: `LolaConnector.check_status`, `_receive_control_until`
- Evidence: The source audit says ACK returns `True`, timeout returns `False`,
  and malformed control datagrams are ignored after warning.
- Why it matters: Callers cannot distinguish no response, malformed response,
  wrong peer, or explicit negative status.
- Suggested remediation: Replace boolean with a result type carrying ACK,
  timeout, malformed count, wrong-peer count, dialects attempted, and elapsed
  time.
- Test or verification needed: connector tests for timeout, malformed response,
  wrong peer, and ACK.
- Risk of change: Medium.
- Confidence: high

### STC-FL-007

- ID: STC-FL-007
- Source audit(s): `docs/fail-loud-audit.md`,
  `docs/test-intent-audit.md`
- Original finding ID(s): `FLA-011`, `TIA-003`
- Theme: FAIL_LOUD
- Severity: P1
- File: `scripts/export-release-candidate.sh`,
  `scripts/verify-release-hygiene.sh`,
  `Tests/OpenLolaCoreTests/ReleaseArtifactHygieneContractTests.swift`
- Symbol or line range: release candidate export and hygiene verification
- Evidence: The fail-loud audit says scripts print generic `VERDICT: PASS`,
  including a mode where only live checkout residue was scanned, while product
  readiness remains PARTIAL. The test audit says release tests rely partly on
  strings/docs alignment rather than contaminated artifact behavior.
- Why it matters: CI snippets or user output can be misread as product PASS.
- Suggested remediation: Scope verdict labels to the evidence class and test
  clean/contaminated candidate behavior.
- Test or verification needed: release hygiene contract tests and
  `bash scripts/verify-release-hygiene.sh`.
- Risk of change: Medium.
- Confidence: high

### STC-FL-008

- ID: STC-FL-008
- Source audit(s): `docs/fail-loud-audit.md`
- Original finding ID(s): `FLA-003`
- Theme: FAIL_LOUD
- Severity: P2
- File: `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorExecutablePreflight.swift`
- Symbol or line range: `lolaInternalProbe()`
- Evidence: The fail-loud audit says the internal LoLa probe reports
  `verdict: .pass` with `launched: false` because no external executable is
  required.
- Why it matters: PASS can be read as launch readiness even when no executable
  launched.
- Suggested remediation: Add explicit status such as `notRequired` or
  `internalPath`, and keep aggregate PASS scoped to evidence class.
- Test or verification needed: executable preflight tests.
- Risk of change: Medium.
- Confidence: high

### STC-FL-009

- ID: STC-FL-009
- Source audit(s): `docs/minimum-code-audit.md`
- Original finding ID(s): `MCA-016`
- Theme: FAIL_LOUD
- Severity: P2
- File: `Sources/OpenLolaCore/Network/Diagnostics/NetworkDiagnostics.swift`
- Symbol or line range: `networkDiagnosticsVerdict`,
  `NetworkDiagnosticsReport`
- Evidence: The minimum-code audit says network diagnostics can return `.pass`
  for reachability/threshold checks while notes state this does not prove audio
  latency or Internet LoLa readiness.
- Why it matters: Shared PASS vocabulary can be over-read by downstream gates.
- Suggested remediation: Inspect consumers; gate product-readiness uses or add a
  domain-specific readiness field if consumers are ambiguous.
- Test or verification needed: network diagnostics verdict tests and goal
  preflight tests.
- Risk of change: Medium.
- Confidence: medium

## 7. Duplicates merged

| Consolidated ID | Merged source IDs | Reason |
| --- | --- | --- |
| STC-MC-003 | `OE-001`, `OE-002`, `OE-003`, `OE-004`, `MCA-005` | Same duplicate compiled inventory/matrix family. |
| STC-MC-004 | `OE-007`, `MCA-006` | Same app settings/storage/defaults boilerplate. |
| STC-MC-005 | `OE-009`, `MCA-008` | Same unsupported/planning-only app mode concern. |
| STC-MC-006 | `OE-010`, `MCA-009` | Same legacy audio-compression compatibility path. |
| STC-MC-007 | `OE-011`, `MCA-012` | Same NMP workflow breadth concern. |
| STC-MC-008 | `OE-005`, `OE-006`, `MCA-010`, `MCA-011` | Source-compiled governance/deferred ledgers with overlapping minimum-code risk. |
| STC-MC-009 | `OE-012`, `OE-013`, `OE-014`, `MCA-013`, `MCA-014`, `MCA-015` | Related validation/report helper abstraction concerns. |
| STC-MC-010 | `OE-008`, `MCA-007` | Same single-use settings mutation policy. |
| STC-TI-001 | `TIA-001`, `TIA-012`, `FLA-012` | Same missing app lifecycle/UI failure-behavior coverage cluster. |
| STC-FL-001 | `FLA-001`, `FLA-002`, with related `MCA-001`, `TIA-001` | Same app certainty/lifecycle surface, with distinct stop and validation-launch symptoms preserved. |
| STC-FL-005 | `FLA-007`, `FLA-008`, `FLA-009` | Same UDP report-certainty family; each symptom is preserved in evidence. |
| STC-FL-007 | `FLA-011`, `TIA-003` | Same release certainty surface: unscoped PASS plus weak string-heavy tests. |

## 8. Conflicts or inconsistencies between source audits

- The source audits do not directly contradict each other on any consolidated
  finding.
- Several audits intentionally classify the same area differently: for example,
  app execution is both a minimum-code risk (`MCA-001`) and a fail-loud risk
  (`FLA-001`, `FLA-002`). This is not a conflict; remediation must treat it as
  lifecycle correctness first and simplification second.
- Inventory and ledger surfaces are called overengineered/minimum-code risks,
  while the test audit recognizes some as useful policy gates. This is a
  tension, not a contradiction: do not delete them until the release/docs gate
  value is replaced or proven unnecessary.
- Synthetic smoke tests are called valuable in `docs/test-intent-audit.md` even
  though their aggregate shape is weak. The consolidated finding preserves both
  statements.
- `BoundedFileReader` is explicitly kept as valuable in
  `docs/minimum-code-audit.md`; only the report-specific convenience layer is
  uncertain. This document does not recommend removing bounded I/O.

## 9. Highest-risk issues

1. STC-FL-001: app stop/report/validation state can surface certainty before
   process or validation evidence exists.
2. STC-FL-002 and STC-FL-003: Swift process cleanup paths ignore or hide
   lifecycle uncertainty.
3. STC-FL-005: UDP reports can hide malformed traffic, ignored join timeout, or
   caller-supplied PASS.
4. STC-FL-007: release hygiene PASS labels can be detached from the product
   PARTIAL caveat.
5. STC-TI-006: Python end-to-end UDP selftests can skip on loopback alias
   availability, leaving public runtime behavior weakly covered.

## 10. Low-risk simplification candidates

1. STC-MC-010: inline `AppSettingsMutationPolicy` after preserving disabled
   state behavior.
2. Part of STC-MC-009: remove or inline `ReportMetadataArtifact` only if no
   generic metadata consumer exists.
3. Part of STC-MC-008: move source-compiled assumption text to docs/fixtures if
   release/schema gates only need IDs/status.
4. STC-MC-011: migrate network diagnostics parsing to the shared parser if
   semantics match exactly.

## 11. Suggested remediation slices

### SLICE-01

- Slice ID: SLICE-01
- Title: App lifecycle certainty before simplification
- Findings addressed: STC-FL-001, STC-MC-001, STC-TI-001
- Minimal remediation strategy: Add failing behavior tests for stop, failed
  launch, validation launch failure, stale validation reset, and report
  finalization. Then make lifecycle/report finalization single-owner.
- Files likely affected: `Sources/open-lola-app/AppExecutionController.swift`,
  app shell tests.
- Tests needed: focused app shell behavior tests and native app shell tests.
- Verification needed: `swift test --filter AppShell`,
  `swift test --filter NativeAppShell`, app build/run smoke.
- Risk level: High.
- Definition of Done: no UI/report state claims final stopped/validated status
  until process or validator evidence exists; tests fail on premature success.

### SLICE-02

- Slice ID: SLICE-02
- Title: Process lifecycle result evidence
- Findings addressed: STC-FL-002, STC-FL-003, STC-FL-004, STC-MC-002,
  STC-TI-007
- Minimal remediation strategy: Inventory process-runner semantics, add
  cleanup/unknown-status tests, then introduce the smallest structured teardown
  evidence needed by report-producing callers.
- Files likely affected: Swift process runner files, Python backend cleanup,
  external connector process tests, linux connector process tests.
- Tests needed: Managed process, external connector process group, network
  diagnostics, and linux connector cleanup tests.
- Verification needed: relevant Swift filters plus
  `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider
  linux_connector`.
- Risk level: High.
- Definition of Done: report-producing process paths expose launched, exited,
  timed out, cleanup failed, and unknown-exit states without magic sentinels.

### SLICE-03

- Slice ID: SLICE-03
- Title: UDP certainty counters and verdict gates
- Findings addressed: STC-FL-005, STC-TI-008
- Minimal remediation strategy: Add report-visible malformed/wrong-size/fatal
  counters, receiver join-timeout signaling, and PASS blocking for local receive
  errors before simplifying route code.
- Files likely affected: UDP loopback/continuous route runners and UDP tests.
- Tests needed: malformed echo injection, receiver join timeout, receive-error
  PASS rejection, adverse UDP media table tests.
- Verification needed: UDP loopback, continuous receiver, route report, and
  media transport filters.
- Risk level: Medium-high.
- Definition of Done: UDP reports distinguish protocol error, timeout, join
  failure, loss, and valid PASS criteria.

### SLICE-04

- Slice ID: SLICE-04
- Title: Release and diagnostic verdict scoping
- Findings addressed: STC-FL-007, STC-FL-009, STC-TI-002
- Minimal remediation strategy: Rename generic script PASS labels to scoped
  verdicts and add behavior tests for contaminated release candidates; inspect
  network diagnostics consumers before changing verdict shape.
- Files likely affected: release hygiene scripts/tests, network diagnostics
  report consumers.
- Tests needed: clean/contaminated release candidate tests, diagnostics verdict
  consumer tests.
- Verification needed: `bash scripts/verify-release-hygiene.sh`, release
  artifact hygiene tests, network diagnostics tests.
- Risk level: Medium.
- Definition of Done: no script or diagnostic output can be mistaken for product
  PASS without its evidence class.

### SLICE-05

- Slice ID: SLICE-05
- Title: Inventory and fixture authority reduction
- Findings addressed: STC-MC-003, STC-TI-003
- Minimal remediation strategy: Pick one active authority for report/fixture/
  owner/route metadata, then derive secondary views. Replace agreement-only
  checks with public validator checks for false-pass fixtures.
- Files likely affected: inventory files, fixture matrix tests, report schema
  tests, release readiness scripts.
- Tests needed: inventory contract tests, fixture false-pass validator sweep,
  source ownership tests, release readiness.
- Verification needed: named inventory filters plus
  `bash scripts/verify-release-readiness.sh`.
- Risk level: High.
- Definition of Done: duplicate metadata is reduced and every retained metadata
  field has a current consumer or generated source.

### SLICE-06

- Slice ID: SLICE-06
- Title: App settings and unsupported modes
- Findings addressed: STC-MC-004, STC-MC-005, STC-MC-006
- Minimal remediation strategy: Preserve storage compatibility, then group
  settings persistence. Separately decide whether unsupported connector modes
  are planning-only or hidden from executable UI. Keep legacy audio migration
  until active dependency search is clean.
- Files likely affected: app settings/defaults/session-mode files and related
  tests.
- Tests needed: settings round trips, legacy audio migration, unsupported mode
  execution prevention, rendered app smoke.
- Verification needed: app shell and native shell filters.
- Risk level: Medium-high.
- Definition of Done: settings load/save has fewer parallel lists, unsupported
  modes cannot imply execution success, and legacy migrations remain tested.

### SLICE-07

- Slice ID: SLICE-07
- Title: Test suite behavior/locality cleanup
- Findings addressed: STC-TI-004, STC-TI-005, STC-TI-006, STC-TI-007,
  STC-TI-008
- Minimal remediation strategy: Split aggregate tests where locality matters,
  promote high-risk semantic helpers to independent tests, move Python runtime
  coverage toward public entry points, and pair mock tests with real process
  behavior.
- Files likely affected: Swift test files and linux connector tests.
- Tests needed: new focused tests are the deliverable.
- Verification needed: targeted filters first, then broader Swift/Python test
  matrix after behavior changes.
- Risk level: Medium.
- Definition of Done: high-risk failures identify the behavior that regressed,
  not only a broad scenario wrapper or mock wiring assertion.

### SLICE-08

- Slice ID: SLICE-08
- Title: Low-risk inline/delete pass
- Findings addressed: STC-MC-008, STC-MC-009, STC-MC-010, STC-MC-011
- Minimal remediation strategy: Only after call-site inventory, inline
  single-use marker/policy helpers and move governance text out of source where
  release gates do not require Swift types.
- Files likely affected: settings view, report validator surface, assumption
  ledgers, network diagnostics parser.
- Tests needed: focused tests named by each affected source audit.
- Verification needed: docs gate, focused Swift filters.
- Risk level: Low to medium.
- Definition of Done: removed lines have no active runtime/release consumer, and
  replacement tests still verify the intended policy or behavior.

## 12. Verification strategy

For this consolidation document:

```bash
bash scripts/verify-docs.sh
```

Before implementation:

1. Re-read the relevant source audit finding and live code.
2. Add or identify a behavior test for the failure/certainty condition.
3. Run the narrow filter named in the finding.
4. Only then simplify or fix the smallest slice.

After source/test changes in high-risk areas:

```bash
swift test --filter AppShell
swift test --filter NativeAppShell
swift test --filter ManagedProcessRunner
swift test --filter ExternalConnector
swift test --filter UdpMediaTransport
swift test --filter NetworkDiagnostics
PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector
bash scripts/verify-release-readiness.sh
```

Run `swift test --no-parallel` only after focused filters are green or when the
changed surface is broad enough to require the full Swift matrix.

## 13. Remaining uncertainty

- This document depends on the four source audits; it did not re-audit every
  underlying source file line-by-line.
- Findings marked medium or low confidence in source audits retain that
  uncertainty here.
- Some compiled inventories, ledgers, and string tests may be intentional
  release-policy gates. Remove them only after proving their current gate value
  is replaced.
- Hardware, signing, real Windows LoLa, real app launch, and adverse network
  timing evidence remain outside this consolidation.
- Passing docs verification only proves this Markdown surface is syntactically
  and link/path valid. It does not prove the underlying remediation is complete.
