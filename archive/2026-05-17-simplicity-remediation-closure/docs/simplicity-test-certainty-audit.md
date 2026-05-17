# Simplicity, Test-Quality, And Certainty Audit

Date: 2026-05-17

Scope: consolidation of four existing audit documents only:

- `docs/overengineering-index.md`
- `docs/minimum-code-audit.md`
- `docs/test-intent-audit.md`
- `docs/fail-loud-audit.md`

No production code, test code, refactor, deletion, or source reformatting was
performed for this consolidation. Findings below are not new discoveries; they
are merged and prioritized from the source audits. Unclear intent and active
compatibility evidence from the source audits are preserved.

## 1. Executive Summary

The source audits converge on three broad risks:

1. Some runtime-critical paths can report or imply success after only an
   attempted operation, especially Core Audio cleanup, UDP loopback, native app
   launch evidence, raw AVFoundation frame capture, and process cleanup.
2. Several tests protect source text, counts, wrapper calls, or inventory shape
   rather than the runtime or product behavior that matters.
3. A family of inventory, matrix, and wrapper abstractions duplicates facts
   already present in executable routers, validators, fixtures, scripts, docs,
   and behavior tests.

Highest-risk consolidated findings:

- `STC-FL-001`: Core Audio graph shutdown clears state after unverified
  stop/destroy/restore calls.
- `STC-FL-003`: UDP PCM loopback can return sender evidence while the looper
  failed or timed out.
- `STC-FL-004`: native app release readiness can print `PASS` without proving
  required accessibility labels.
- `STC-TI-001`: Swift LoLa fallback tests can return early and appear green
  when the loopback alias is unavailable.
- `STC-TI-006`: app UI truth is mostly protected by model and script-text tests,
  not a rendered runtime-state test.
- `STC-MC-001`: `AppExecutionController` mixes command construction, process
  lifecycle, validation, report loading, artifact state, and UI-facing state in
  one large controller.

This audit separates confirmed simplification targets from uncertain areas:

- Confirmed low-risk simplification candidates are mostly wrapper/no-op tests
  and contract rows that assert counts or literals instead of behavior.
- `ExternalConnectorNMP`, raw Ethernet helpers, and the line-budget gate are
  not deletion targets without a separate active-use audit.
- The legacy `audioCompression` compatibility path is explicitly not a
  simplification target because the source audits found current docs/tests that
  prove active migration behavior.

## 2. Source Audit Coverage

| Source audit | Coverage summarized here | Notes |
|---|---:|---|
| `docs/overengineering-index.md` | `OE-001` through `OE-013` | All findings represented in consolidated findings or uncertainty/conflict notes. |
| `docs/minimum-code-audit.md` | `MCA-001` through `MCA-013` | `MCA-013` is preserved as `KEEP`, not an action target. |
| `docs/test-intent-audit.md` | `TIA-001` through `TIA-014` | All weak/missing-test findings are represented. Valuable-test notes are preserved in verification guidance. |
| `docs/fail-loud-audit.md` | `FLA-001` through `FLA-012` | All false-success findings are represented. |

Coverage limits inherited from the source audits:

- The source audits were targeted, not a line-by-line proof of every file.
- Some findings are based on source evidence and existing tests, not runtime
  hardware proof.
- External downstream consumers of public CLI/report/test surfaces were not
  audited.
- `UNCLEAR`, `INVESTIGATE`, and medium-confidence judgments from source audits
  remain uncertain here.

## 3. Consolidated Findings Index

| ID | Theme | Severity | Source finding IDs | Primary file or area | Confidence |
|---|---|---:|---|---|---|
| `STC-MC-001` | `MINIMUM_CODE` | P1 | `OE-013`, `MCA-001` | `Sources/open-lola-app/AppExecutionController.swift` | high |
| `STC-MC-002` | `MINIMUM_CODE` | P2 | `OE-001`, `MCA-002` | CLI command registry and inventory | high |
| `STC-MC-003` | `MINIMUM_CODE` | P2 | `OE-005`, `MCA-003` | report schema inventory | high |
| `STC-MC-004` | `MINIMUM_CODE` | P2 | `OE-002`, `OE-003`, `OE-004`, `MCA-004`, `MCA-005`, `MCA-006`, `TIA-006` | network/video/source inventories and matrices | high |
| `STC-MC-005` | `MINIMUM_CODE` | P2 | `OE-006`, `OE-007`, `MCA-007`, `TIA-003` | `OpenLolaCLI` JSON wrapper pairs | high |
| `STC-MC-006` | `MINIMUM_CODE` | P3 | `OE-009`, `MCA-008`, `TIA-004` | `ReportMetadataArtifact` marker/no-op helper | medium |
| `STC-MC-007` | `MINIMUM_CODE` | P2 | `OE-010`, `MCA-009` | external connector NMP plan/preflight/workflow stack | medium |
| `STC-MC-008` | `MINIMUM_CODE` | P2 | `OE-011`, `MCA-010` | Python raw Ethernet helper export | medium |
| `STC-MC-009` | `MINIMUM_CODE` | P2 | `OE-012`, `MCA-012`, `TIA-005` | `CodeLineBudgetTests` repository scanner | medium |
| `STC-TI-001` | `TEST_INTENT` | P1 | `TIA-001` | Swift LoLa quick-connect fallback tests | high |
| `STC-TI-002` | `TEST_INTENT` | P2 | `OE-008`, `MCA-011`, `TIA-002` | `ReleaseRunConfigurationContractTests` | high |
| `STC-TI-003` | `TEST_INTENT` | P2 | `TIA-006`, `TIA-007`, `TIA-009`, `TIA-010` | inventory, release hygiene, tooling, and template literal tests | medium |
| `STC-TI-004` | `TEST_INTENT` | P1 | `TIA-008`, `TIA-013`, `FLA-004` | app bundle script test and missing rendered app UI test | medium |
| `STC-TI-005` | `TEST_INTENT` | P1 | `TIA-011` | synthetic smoke report tests | medium |
| `STC-TI-006` | `TEST_INTENT` | P3 | `TIA-012` | `semantic...TestsScenario` wrappers | high |
| `STC-TI-007` | `TEST_INTENT` | P2 | `TIA-014` | Python loopback alias-dependent tests | medium |
| `STC-FL-001` | `FAIL_LOUD` | P1 | `FLA-001` | `DirectPeerRealtimeAudioGraph.stopUnlocked()` | high |
| `STC-FL-002` | `FAIL_LOUD` | P1 | `FLA-002` | `AudioLoopbackRunner.runIOProc(...)` | high |
| `STC-FL-003` | `FAIL_LOUD` | P1 | `FLA-003` | `UdpPcmLoopbackSmoke.run(...)` | high |
| `STC-FL-004` | `FAIL_LOUD` | P1 | `FLA-004`, `TIA-008`, `TIA-013` | native app launch verification | high |
| `STC-FL-005` | `FAIL_LOUD` | P2 | `FLA-005`, `FLA-006`, `FLA-012` | NAT and LoLa control datagram accounting | high |
| `STC-FL-006` | `FAIL_LOUD` | P2 | `FLA-007`, `FLA-008` | app command path and pasteboard success states | medium |
| `STC-FL-007` | `FAIL_LOUD` | P2 | `FLA-009` | `ManagedProcessRunner` cleanup result | medium |
| `STC-FL-008` | `FAIL_LOUD` | P2 | `FLA-010` | `AVFoundationFrameRecorder` raw frame capture | medium |
| `STC-FL-009` | `FAIL_LOUD` | P2 | `FLA-011` | `PackagingFieldTestRun.packagingFieldRunVerdict(...)` | high |

## 4. Minimum-Code Findings

### STC-MC-001

- ID: `STC-MC-001`
- Source audit(s): `docs/overengineering-index.md`,
  `docs/minimum-code-audit.md`
- Original finding ID(s): `OE-013`, `MCA-001`
- Theme: `MINIMUM_CODE`
- Severity: P1
- File: `Sources/open-lola-app/AppExecutionController.swift`
- Symbol or line range: `AppExecutionController`
- Evidence: the source audits describe this controller as a 720-line mixed
  state/process/validation/report/UI controller. `MCA-001` specifically says it
  handles command building, process lifecycle, validation, report loading,
  artifact state, and UI-facing status in one place.
- Why it matters: the file is large in a high-risk UI/runtime boundary and can
  hide state transitions, command uncertainty, and launch/validation failures.
- Suggested remediation: split only along current responsibilities that already
  have behavior seams: command resolution, process execution, report loading,
  validation state, and UI status projection. Do not add a generic framework.
- Test or verification needed: focused app-shell tests for missing executable,
  launch failure, malformed report, stale report, and validation state; broader
  app verification after each slice.
- Risk of change: high, because this file sits between UI state, command
  execution, report evidence, and operator feedback.
- Confidence: high

### STC-MC-002

- ID: `STC-MC-002`
- Source audit(s): `docs/overengineering-index.md`,
  `docs/minimum-code-audit.md`
- Original finding ID(s): `OE-001`, `MCA-002`
- Theme: `MINIMUM_CODE`
- Severity: P2
- File: `Sources/open-lola/main.swift`;
  `Sources/OpenLolaCore/Support/Inventories/CLICommandInventory.swift`
- Symbol or line range: executable CLI router and `CLICommandInventory.entries`
- Evidence: both source audits report duplicated command facts between the
  executable router and a static command inventory.
- Why it matters: command availability can drift between the router, docs,
  inventory JSON, and tests. The extra registry adds maintenance surface without
  proving commands execute.
- Suggested remediation: derive inventory from one source of truth or replace
  inventory rows with tests that execute or parse the real command surface.
- Test or verification needed: executable CLI command inventory test that
  proves each advertised command routes, emits parseable output where promised,
  and refuses false `PASS` where relevant.
- Risk of change: medium; CLI/report command names are public surface area.
- Confidence: high

### STC-MC-003

- ID: `STC-MC-003`
- Source audit(s): `docs/overengineering-index.md`,
  `docs/minimum-code-audit.md`
- Original finding ID(s): `OE-005`, `MCA-003`
- Theme: `MINIMUM_CODE`
- Severity: P2
- File: `Sources/OpenLolaCore/Evidence/ReportSchemaInventory.swift`;
  `Tests/OpenLolaCoreTests/ReportSchemaInventoryTests.swift`
- Symbol or line range: `ReportSchemaInventory`
- Evidence: the source audits say the inventory duplicates report/schema,
  validator, fixture, smoke-test, and ownership facts that already exist in
  production types, fixtures, validators, tests, and docs.
- Why it matters: duplicated schema ledgers can become trusted even when the
  validator or fixture behavior changes differently.
- Suggested remediation: keep only behavior-backed schema checks: decode
  fixtures, run validators, reject false `PASS`, and use docs generation or
  one active manifest only if current consumers require it.
- Test or verification needed: fixture decode/validate tests and false-pass
  mutation tests for every report schema kept in the manifest.
- Risk of change: medium; report schema inventory may be a public machine
  surface.
- Confidence: high

### STC-MC-004

- ID: `STC-MC-004`
- Source audit(s): `docs/overengineering-index.md`,
  `docs/minimum-code-audit.md`, `docs/test-intent-audit.md`
- Original finding ID(s): `OE-002`, `OE-003`, `OE-004`, `MCA-004`,
  `MCA-005`, `MCA-006`, `TIA-006`
- Theme: `MINIMUM_CODE`
- Severity: P2
- File: `Sources/OpenLolaCore/Support/Inventories/NetworkRouteCommandMatrix.swift`;
  `Sources/OpenLolaCore/Support/Inventories/VideoControlDegradeMatrix.swift`;
  `Sources/OpenLolaCore/Support/Inventories/SourceOwnershipInventory.swift`
- Symbol or line range: network route matrix, video/control degrade matrix,
  source ownership inventory
- Evidence: source audits describe these as static crosswalks or planning
  inventories embedded in production Swift. `TIA-006` says many related tests
  assert non-empty strings and file paths rather than runtime behavior.
- Why it matters: production code carries planning/release ledger data that can
  drift from executable behavior. Tests can stay green while a route, command,
  or evidence boundary is wrong.
- Suggested remediation: replace rows with behavior-backed checks where the
  row describes runtime policy; move planning-only ownership data to docs if no
  runtime consumer requires it.
- Test or verification needed: per-row behavior tests for route verdict
  boundaries, degrade-first video/control policy, and source ownership only
  where ownership is an active release contract.
- Risk of change: medium; matrices may feed current docs/release reports.
- Confidence: high

### STC-MC-005

- ID: `STC-MC-005`
- Source audit(s): `docs/overengineering-index.md`,
  `docs/minimum-code-audit.md`, `docs/test-intent-audit.md`
- Original finding ID(s): `OE-006`, `OE-007`, `MCA-007`, `TIA-003`
- Theme: `MINIMUM_CODE`
- Severity: P2
- File: `Sources/open-lola/main.swift`;
  `Tests/OpenLolaCoreTests/MachineReadableSurfaceContractTests.swift`
- Symbol or line range: `OpenLolaCLI.*Data()`, `OpenLolaCLI.*JSONString()`,
  `machineReadableInventoryAndMatrixJSONSurfacesRoundTrip`
- Evidence: source audits identify paired Data/String wrappers around
  machine-readable factories and a wrapper-level test that decodes wrapper
  output back into the same underlying factories while pinning a case count.
- Why it matters: wrapper tests can pass while executable CLI routing or output
  framing is wrong. The wrapper layer adds little value if it only forwards JSON
  encoding.
- Suggested remediation: inline single-use wrappers or keep one generic encode
  helper; move coverage to executable CLI surfaces that emit JSON and verdict
  lines.
- Test or verification needed: CLI-level JSON parsing tests, missing
  `VERDICT:` tests, validator rejection tests, and command-router coverage.
- Risk of change: medium; machine-readable surfaces may be consumed by docs or
  tooling.
- Confidence: high

### STC-MC-006

- ID: `STC-MC-006`
- Source audit(s): `docs/overengineering-index.md`,
  `docs/minimum-code-audit.md`, `docs/test-intent-audit.md`
- Original finding ID(s): `OE-009`, `MCA-008`, `TIA-004`
- Theme: `MINIMUM_CODE`
- Severity: P3
- File: `Tests/OpenLolaCoreTests/ReportSchemaInventoryTests.swift`;
  related report metadata protocol code
- Symbol or line range: `ReportMetadataArtifact`,
  `assertReportMetadataArtifact`
- Evidence: source audits describe a marker/no-op helper that proves compile
  conformance but not metadata semantics. `TIA-004` says it does not prove
  decoded metadata is meaningful or shown in validator output.
- Why it matters: boilerplate creates a false sense that metadata behavior is
  tested.
- Suggested remediation: remove or inline the marker/no-op helper if no runtime
  consumer needs it; replace it with decoded fixture metadata assertions.
- Test or verification needed: fixtures with empty title, malformed capture
  time, missing notes, and validator output assertions.
- Risk of change: low to medium, depending on public protocol usage.
- Confidence: medium

### STC-MC-007

- ID: `STC-MC-007`
- Source audit(s): `docs/overengineering-index.md`,
  `docs/minimum-code-audit.md`
- Original finding ID(s): `OE-010`, `MCA-009`
- Theme: `MINIMUM_CODE`
- Severity: P2
- File: external connector NMP plan/preflight/endpoint/workflow files
- Symbol or line range: external connector NMP stack
- Evidence: source audits flag a broad plan/preflight/endpoint/workflow option
  surface as potentially speculative, but also say docs and tests reference it
  as active. Intent is marked `UNCLEAR`/`INVESTIGATE`.
- Why it matters: a wide compatibility workflow can add configuration and
  branching for a narrow current problem, but deleting it without active-use
  proof could break a documented compatibility path.
- Suggested remediation: first perform a current-use audit. Only simplify NMP
  options that have no active CLI, app, doc, test, report, or external
  compatibility consumer.
- Test or verification needed: active-use inventory, focused external connector
  tests, and report validation for every remaining option.
- Risk of change: medium to high until active use is proven.
- Confidence: medium

### STC-MC-008

- ID: `STC-MC-008`
- Source audit(s): `docs/overengineering-index.md`,
  `docs/minimum-code-audit.md`
- Original finding ID(s): `OE-011`, `MCA-010`
- Theme: `MINIMUM_CODE`
- Severity: P2
- File: `linux_connector/lola_connector/ethernet.py`;
  `linux_connector/lola_connector/__init__.py`
- Symbol or line range: publicly exported raw Ethernet helpers
- Evidence: source audits say normal runtime uses UDP while raw Ethernet helper
  exports appear active only through tests/docs. Intent is marked unclear.
- Why it matters: public fallback helpers increase API surface and maintenance
  without clear current runtime use.
- Suggested remediation: audit external and internal use before deletion. If no
  real consumer exists, make the helpers private to tests or remove the public
  export with a compatibility note.
- Test or verification needed: `rg` use audit across Python package, tests,
  docs, and release scripts; Python connector tests for the retained public
  surface.
- Risk of change: medium; public Python exports may be used outside the repo.
- Confidence: medium

### STC-MC-009

- ID: `STC-MC-009`
- Source audit(s): `docs/overengineering-index.md`,
  `docs/minimum-code-audit.md`, `docs/test-intent-audit.md`
- Original finding ID(s): `OE-012`, `MCA-012`, `TIA-005`
- Theme: `MINIMUM_CODE`
- Severity: P2
- File: `Tests/OpenLolaCoreTests/CodeLineBudgetTests.swift`
- Symbol or line range: `scopedCodeFilesStayWithinLineBudget`
- Evidence: source audits describe a broad repository policy scanner embedded
  in Swift tests. `TIA-005` says it fails on file size, not runtime behavior.
  The policy itself may be intentional.
- Why it matters: a useful hygiene rule can dominate test failures while not
  proving the behavior risks that large files hide.
- Suggested remediation: keep the policy only if it remains an explicit gate;
  narrow it to owned source files or move it to a docs/hygiene verification
  script. Pair oversized high-risk files with behavior tests.
- Test or verification needed: line-budget gate should still catch stale
  exceptions; high-risk oversized files need state/failure/edge tests.
- Risk of change: medium for workflow expectations, low for runtime behavior.
- Confidence: medium

## 5. Test-Intent Findings

### STC-TI-001

- ID: `STC-TI-001`
- Source audit(s): `docs/test-intent-audit.md`
- Original finding ID(s): `TIA-001`
- Theme: `TEST_INTENT`
- Severity: P1
- File: `Tests/OpenLolaCoreTests/LoLaQuickConnectFallbackTests.swift`
- Symbol or line range:
  `lolaUdpTransmitFallsBackToQuickConnectWhenStatusAckTimesOut`,
  `lolaUdpReceiveKeepsControlSocketAliveForPostConnectRetries`,
  `lolaUdpTxRxKeepsControlSocketAliveForPostConnectCommands`,
  `secondaryLoopbackAliasAvailable`
- Evidence: the source audit says three runtime-heavy tests return immediately
  when `secondaryLoopbackAliasAvailable()` is false, so hosts without
  `127.0.0.2` can report passing tests without exercising fallback behavior.
- Why it matters: a critical compatibility fallback can appear green when the
  actual runtime path did not run.
- Suggested remediation: make unavailable loopback alias an explicit skip or
  failure in the relevant verification profile, and add socket-free tests for
  fallback state transitions where possible.
- Test or verification needed: alias unavailable, alias available but peer bind
  timeout, status ACK timeout followed by QuickConn success, and control socket
  retry tests.
- Risk of change: medium; changing skip behavior can affect local developer
  runs and CI requirements.
- Confidence: high

### STC-TI-002

- ID: `STC-TI-002`
- Source audit(s): `docs/overengineering-index.md`,
  `docs/minimum-code-audit.md`, `docs/test-intent-audit.md`
- Original finding ID(s): `OE-008`, `MCA-011`, `TIA-002`
- Theme: `TEST_INTENT`
- Severity: P2
- File: `Tests/OpenLolaCoreTests/ReleaseRunConfigurationContractTests.swift`
- Symbol or line range:
  `releaseRunConfigurationsAndTestingIndexDocumentActiveHarnessContracts`
- Evidence: source audits say the test builds four contract rows, asserts the
  count, and checks hardcoded documentation substrings. It does not prove the
  harnesses execute or reject false `PASS`.
- Why it matters: release harness drift can be hidden behind green docs/count
  assertions.
- Suggested remediation: delete or replace the count/literal test with
  executable harness checks and false-PASS rejection tests.
- Test or verification needed: missing output path, malformed report input,
  synthetic evidence trying to produce `PASS`, and removed command with stale
  docs.
- Risk of change: low to medium; deleting the weak test is low risk only if
  behavior coverage replaces it.
- Confidence: high

### STC-TI-003

- ID: `STC-TI-003`
- Source audit(s): `docs/test-intent-audit.md`
- Original finding ID(s): `TIA-006`, `TIA-007`, `TIA-009`, `TIA-010`
- Theme: `TEST_INTENT`
- Severity: P2
- File: inventory, release hygiene, verification tooling, and runtime evidence
  template test files
- Symbol or line range: path/literal/string-matrix tests
- Evidence: the source audit identifies tests that check file existence,
  non-empty strings, YAML/doc substrings, command substrings, exact output
  lines, or stubbed script output. Some tests in those files are valuable
  behavior checks, especially release-residue script tests.
- Why it matters: string and path checks can pass while the runtime command,
  validator, or release gate is broken.
- Suggested remediation: keep behavior tests that run scripts or reject bad
  artifacts; replace literal-only assertions with executable command, validator,
  and synthetic-broken-input checks.
- Test or verification needed: command exists but emits wrong verdict, validator
  accepts false `PASS`, workflow omits a gate while docs mention it, and
  template command names an inactive CLI command.
- Risk of change: medium; some literals may be intentional public contracts.
- Confidence: medium

### STC-TI-004

- ID: `STC-TI-004`
- Source audit(s): `docs/test-intent-audit.md`, `docs/fail-loud-audit.md`
- Original finding ID(s): `TIA-008`, `TIA-013`, `FLA-004`
- Theme: `TEST_INTENT`
- Severity: P1
- File: `Tests/OpenLolaCoreTests/AppBundleScriptSourcePolicyTests.swift`;
  `script/build_and_run.sh`; `scripts/verify-release-readiness.sh`
- Symbol or line range: app bundle source-policy test and missing native
  rendered runtime-state test
- Evidence: source audits say the test checks fake tool logs and source text
  such as `require_any_ui_label`, while unit tests do not launch the real app
  and verify rendered UI state. `FLA-004` adds that release readiness can pass
  when accessibility label capture is unavailable.
- Why it matters: app UI can imply connected, live, validated, or healthy state
  without runtime/report evidence, and the current test may not fail.
- Suggested remediation: add launch-level rendered UI smoke coverage or make
  the existing release probe fail/mark uncertain when required UI labels are not
  captured.
- Test or verification needed: no report, malformed report, partial report,
  stale passing report, missing screenshot, blank screenshot, and Accessibility
  unavailable cases.
- Risk of change: high for release workflow and UI evidence policy.
- Confidence: medium

### STC-TI-005

- ID: `STC-TI-005`
- Source audit(s): `docs/test-intent-audit.md`
- Original finding ID(s): `TIA-011`
- Theme: `TEST_INTENT`
- Severity: P1
- File: `Tests/OpenLolaCoreTests/SyntheticSmokeReportContractTests.swift`
- Symbol or line range:
  `syntheticSmokeReportsValidateAsPartialWithoutClaimingRuntimePass`
- Evidence: the source audit says the test has valuable partial/false-readiness
  intent, but pins a count and does not mutate every synthetic report toward a
  forbidden `PASS` claim.
- Why it matters: synthetic evidence is a core product-boundary risk. A report
  can drift toward false success in a variant not covered by the happy partial
  assertion.
- Suggested remediation: pair every synthetic report case with negative
  mutations that set `PASS`, measured mode, real-world readiness, or remove
  evidence-boundary notes.
- Test or verification needed: per-report false-pass mutation tests and
  validator rejection assertions.
- Risk of change: medium; existing report fixtures and validators are public
  evidence contracts.
- Confidence: medium

### STC-TI-006

- ID: `STC-TI-006`
- Source audit(s): `docs/test-intent-audit.md`
- Original finding ID(s): `TIA-012`
- Theme: `TEST_INTENT`
- Severity: P3
- File: multiple Swift test files with `semantic...TestsScenario` wrappers
- Symbol or line range: 45 `semantic...TestsScenario` functions from the
  source audit inventory
- Evidence: the source audit says wrapper tests call helper functions manually,
  so failures still fail, but reporting/filtering/intent clarity are weaker.
- Why it matters: behavior-specific tests are harder to filter, rerun, or
  understand; a helper can be skipped or omitted without the top-level test name
  exposing the missing behavior.
- Suggested remediation: register risk-bearing helper behaviors as individual
  tests with names that state the protected behavior.
- Test or verification needed: no new behavior test is required before
  splitting; verify the same helper assertions still run after registration.
- Risk of change: low.
- Confidence: high

### STC-TI-007

- ID: `STC-TI-007`
- Source audit(s): `docs/test-intent-audit.md`
- Original finding ID(s): `TIA-014`
- Theme: `TEST_INTENT`
- Severity: P2
- File: `linux_connector/tests/test_codec.py`;
  `linux_connector/tests/test_process_runtime.py`
- Symbol or line range: `require_loopback_alias`
- Evidence: the source audit says these tests explicitly `pytest.skip` when
  `127.0.0.2` is unavailable. This is clearer than the Swift early return but
  still means routine runs may miss loopback behavior.
- Why it matters: core connector loopback behavior can be absent from local
  verification while the run is treated as broadly green.
- Suggested remediation: report skipped loopback capability separately and add
  socket-free parser/state tests for timeout and malformed input paths.
- Test or verification needed: alias unavailable, alias available but bind
  fails, timeout without QuickConn, malformed control/media payload.
- Risk of change: medium for CI/local environment expectations.
- Confidence: medium

## 6. Fail-Loud Findings

### STC-FL-001

- ID: `STC-FL-001`
- Source audit(s): `docs/fail-loud-audit.md`
- Original finding ID(s): `FLA-001`
- Theme: `FAIL_LOUD`
- Severity: P1
- File: `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift`
- Symbol or line range: `DirectPeerRealtimeAudioGraph.stopUnlocked()`
- Evidence: the source audit says `AudioDeviceStop` and
  `AudioDeviceDestroyIOProcID` return values are ignored, sample-rate/buffer
  restore uses `try?`, and state is cleared afterward.
- Why it matters: the graph can look stopped and restored when Core Audio did
  not accept cleanup or restoration calls.
- Suggested remediation: return or record an explicit cleanup result before
  clearing state; include stop/destroy/restore failures in runtime/report
  metadata.
- Test or verification needed: injected Core Audio stop, destroy, and restore
  failures; report must expose failures and avoid full shutdown success.
- Risk of change: high; realtime audio cleanup and device restoration are
  high-risk runtime paths.
- Confidence: high

### STC-FL-002

- ID: `STC-FL-002`
- Source audit(s): `docs/fail-loud-audit.md`
- Original finding ID(s): `FLA-002`
- Theme: `FAIL_LOUD`
- Severity: P1
- File: `Sources/OpenLolaCore/Audio/Routing/AudioLoopbackRun.swift`
- Symbol or line range: `AudioLoopbackRunner.runIOProc(...)`
- Evidence: source audit says the report is built as `.completed` after
  `AudioDeviceStop`, while IOProc destroy return value and device property
  restoration errors are ignored.
- Why it matters: a run can report completion while cleanup/restoration failed
  and the audio device may remain altered.
- Suggested remediation: capture cleanup status and downgrade or annotate the
  report when destroy/restore is failed or unknown.
- Test or verification needed: injected cleanup failures plus validator rule
  that rejects plain completed claims when cleanup status is failed/unknown.
- Risk of change: high in audio device I/O paths.
- Confidence: high

### STC-FL-003

- ID: `STC-FL-003`
- Source audit(s): `docs/fail-loud-audit.md`
- Original finding ID(s): `FLA-003`
- Theme: `FAIL_LOUD`
- Severity: P1
- File: `Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackSmokes.swift`
- Symbol or line range: `UdpPcmLoopbackSmoke.run(...)`
- Evidence: source audit says the looper runs in the background, catches
  errors into a local zero-limit debug trace, and the caller ignores
  `done.wait(...)` success before returning the sender report.
- Why it matters: a loopback smoke can become evidence even when the receive
  side failed or never completed.
- Suggested remediation: require a looper result, propagate looper errors, and
  record completion timeout or receive-side counts.
- Test or verification needed: injected looper failure and timeout tests plus
  existing UDP loopback tests.
- Risk of change: high; UDP loopback evidence is a runtime proof surface.
- Confidence: high

### STC-FL-004

- ID: `STC-FL-004`
- Source audit(s): `docs/fail-loud-audit.md`,
  `docs/test-intent-audit.md`
- Original finding ID(s): `FLA-004`, `TIA-008`, `TIA-013`
- Theme: `FAIL_LOUD`
- Severity: P1
- File: `script/build_and_run.sh`; `scripts/verify-release-readiness.sh`;
  `Tests/OpenLolaCoreTests/AppBundleScriptSourcePolicyTests.swift`
- Symbol or line range: native app launch verification and release readiness
  probe
- Evidence: source audits say label capture can fall back to a non-empty text
  file when AppleScript fails, and release readiness can still print native app
  launch `PASS` if process, accessibility text, and screenshot files exist.
- Why it matters: UI launch evidence can be overstated on machines without
  Accessibility permission or where UI traversal fails.
- Suggested remediation: make required label capture mandatory for `--verify`,
  or emit explicit `PARTIAL`/`UNCERTAIN` that release readiness does not print
  as `PASS`.
- Test or verification needed: harness where `osascript` fails but screenshot
  and visible-window evidence exist; release readiness must fail or mark
  uncertainty.
- Risk of change: high for release gates and operator-visible status.
- Confidence: high

### STC-FL-005

- ID: `STC-FL-005`
- Source audit(s): `docs/fail-loud-audit.md`
- Original finding ID(s): `FLA-005`, `FLA-006`, `FLA-012`
- Theme: `FAIL_LOUD`
- Severity: P2
- File: `Sources/OpenLolaCore/Network/NAT/NatRendezvousRelayRunners.swift`;
  `Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteReports.swift`;
  `linux_connector/lola_connector/connector.py`
- Symbol or line range: NAT rendezvous/relay datagram loops;
  `LolaConnector._receive_control_until(...)`; `check_status(...)`
- Evidence: source audit says malformed or wrong-session NAT datagrams are
  skipped without counters, Python QuickConn/accept skips malformed control
  datagrams without returning counts, and `check_status` collapses rich status
  reasons to a Boolean.
- Why it matters: callers cannot distinguish timeout/idle behavior from noisy,
  malformed, wrong-peer, or wrong-session responses.
- Suggested remediation: add explicit skipped/malformed/wrong-peer/wrong-session
  counters and prefer rich result types over Boolean convenience in runtime
  paths.
- Test or verification needed: malformed and wrong-session NAT datagrams,
  malformed QuickConn ACK, wrong-peer control datagrams, and `check_status`
  caller audit.
- Risk of change: medium; report schemas and Python public API may change.
- Confidence: high

### STC-FL-006

- ID: `STC-FL-006`
- Source audit(s): `docs/fail-loud-audit.md`
- Original finding ID(s): `FLA-007`, `FLA-008`
- Theme: `FAIL_LOUD`
- Severity: P2
- File: `Sources/open-lola-app/AppExecutablePathResolver.swift`;
  `Sources/open-lola-app/AppExecutionController.swift`;
  `Sources/open-lola-app/AppOperatorArtifactViews.swift`;
  `Sources/open-lola-app/AppExecutionView.swift`;
  `Sources/open-lola-app/AppPacketMonitorView.swift`;
  `Sources/open-lola-app/AppShellSupportViews.swift`
- Symbol or line range: app executable path resolution and pasteboard copy
  helpers
- Evidence: source audit says unverified executable paths are returned after a
  warning and pasteboard `setString` Boolean results are ignored while UI status
  can say copied.
- Why it matters: the app can show a plausible runnable command or copied
  artifact when the path/copy operation was not proven.
- Suggested remediation: return typed verified/unverified path resolution and
  check pasteboard writes before setting success status.
- Test or verification needed: nonexistent executable path should produce
  unavailable/failed state; injectable pasteboard failure should not show
  copied status.
- Risk of change: medium; UI flow and command preview behavior may change.
- Confidence: medium

### STC-FL-007

- ID: `STC-FL-007`
- Source audit(s): `docs/fail-loud-audit.md`
- Original finding ID(s): `FLA-009`
- Theme: `FAIL_LOUD`
- Severity: P2
- File: `Sources/OpenLolaCore/Support/ManagedProcessRunner.swift`
- Symbol or line range: `ManagedProcess.closeOutputHandles()`,
  `killImmediately()`, termination result
- Evidence: source audit says `kill(..., SIGKILL)` return value is ignored,
  stdout/stderr handle closes use `try?`, and termination result omits kill
  errno and close warnings.
- Why it matters: process cleanup or log flush failures can disappear from
  app/report state.
- Suggested remediation: preserve cleanup warnings/errors in
  `ManagedProcessTerminationResult`.
- Test or verification needed: injectable process/handle wrapper simulating
  kill and close failures.
- Risk of change: medium.
- Confidence: medium

### STC-FL-008

- ID: `STC-FL-008`
- Source audit(s): `docs/fail-loud-audit.md`
- Original finding ID(s): `FLA-010`
- Theme: `FAIL_LOUD`
- Severity: P2
- File: `Sources/OpenLolaCore/Video/VideoCaptureAVFoundation.swift`
- Symbol or line range: `AVFoundationFrameRecorder.record(...)`,
  `rawFrameBytes(from:)`
- Evidence: source audit says raw extraction uses `try?`, frames are still
  counted, saved raw payloads are optional, and
  `CVPixelBufferLockBaseAddress` status is ignored.
- Why it matters: AV/raw-video evidence can appear to have captured frames even
  when required raw payload extraction failed.
- Suggested remediation: record raw extraction attempts/failures and distinguish
  raw capture disabled from raw capture requested but failed.
- Test or verification needed: unsupported/invalid pixel-buffer path increments
  failure count and prevents raw evidence claims; direct P2P AV validation for
  missing raw payload evidence.
- Risk of change: medium to high for video capture evidence.
- Confidence: medium

### STC-FL-009

- ID: `STC-FL-009`
- Source audit(s): `docs/fail-loud-audit.md`
- Original finding ID(s): `FLA-011`
- Theme: `FAIL_LOUD`
- Severity: P2
- File: `Sources/OpenLolaCore/Release/PackagingFieldTestRun.swift`
- Symbol or line range: `packagingFieldRunVerdict(...)`
- Evidence: source audit says pass-candidate validation is run with `try?`; if
  validation fails, the verdict downgrades to `.partial` while discarding the
  validation error.
- Why it matters: release operators see `PARTIAL` without the blocked gate or
  validation reason.
- Suggested remediation: record validation error text as a blocked-gate note or
  validation summary when downgrading from pass candidate to partial.
- Test or verification needed: force each pass-candidate validation error and
  assert the generated partial report names the blocker.
- Risk of change: medium; report notes/blockers may be public evidence surface.
- Confidence: high

## 7. Duplicates Merged

| Consolidated ID | Merged source IDs | Merge reason |
|---|---|---|
| `STC-MC-001` | `OE-013`, `MCA-001` | Same large app controller and same simplification risk. |
| `STC-MC-002` | `OE-001`, `MCA-002` | Same duplicated CLI router/inventory issue. |
| `STC-MC-003` | `OE-005`, `MCA-003` | Same report/schema inventory duplication. |
| `STC-MC-004` | `OE-002`, `OE-003`, `OE-004`, `MCA-004`, `MCA-005`, `MCA-006`, `TIA-006` | Same family of static matrix/inventory abstractions and path-shape tests. |
| `STC-MC-005` | `OE-006`, `OE-007`, `MCA-007`, `TIA-003` | Same JSON wrapper layer and wrapper-level round-trip test. |
| `STC-MC-006` | `OE-009`, `MCA-008`, `TIA-004` | Same metadata marker/no-op helper and weak metadata test. |
| `STC-MC-007` | `OE-010`, `MCA-009` | Same external connector NMP option surface, with preserved uncertainty. |
| `STC-MC-008` | `OE-011`, `MCA-010` | Same raw Ethernet public helper/export uncertainty. |
| `STC-MC-009` | `OE-012`, `MCA-012`, `TIA-005` | Same line-budget policy scanner and behavior-coverage mismatch. |
| `STC-TI-002` | `OE-008`, `MCA-011`, `TIA-002` | Same release-run contract rows/count/literal test. |
| `STC-TI-004` | `TIA-008`, `TIA-013`, `FLA-004` | Same native app UI evidence weakness from test and fail-loud perspectives. |
| `STC-FL-005` | `FLA-005`, `FLA-006`, `FLA-012` | Same missing malformed/wrong-peer/reason accounting pattern across NAT and Python LoLa control. |
| `STC-FL-006` | `FLA-007`, `FLA-008` | Same app UI success-before-proof pattern for command paths and copy actions. |

Source findings intentionally not merged further:

- `FLA-001` and `FLA-002` are both Core Audio cleanup issues, but they are
  separate runtime flows and should keep separate tests.
- `TIA-001` and `TIA-014` both depend on `127.0.0.2`, but one silently returns
  in Swift tests and the other explicitly skips in pytest; the risk and
  remediation differ.
- `STC-MC-007` and `STC-MC-008` are both uncertain compatibility surfaces, but
  one is Swift external connector NMP workflow and the other is Python raw
  Ethernet export.

## 8. Conflicts Or Inconsistencies Between Source Audits

1. `audioCompression` compatibility is not a cleanup target.
   `docs/minimum-code-audit.md` records `MCA-013` as `KEEP` because current
   docs/tests prove active migration behavior. Even if it resembles
   compatibility slop, this consolidation treats it as protected until a
   future audit proves it obsolete.

2. External connector NMP looks speculative but is documented/tested as active.
   `OE-010` and `MCA-009` flag broad option/configuration surface, but both
   preserve uncertainty because current docs/tests reference the workflow. This
   audit classifies it as `INVESTIGATE`, not `DELETE`.

3. Raw Ethernet helpers appear optional but may be public compatibility surface.
   `OE-011` and `MCA-010` found no normal UDP runtime dependency, but public
   Python exports may have downstream users. This audit does not recommend
   deletion without external-use proof.

4. Line-budget tests are weak behavior tests but may be intentional hygiene.
   `TIA-005` says the test does not prove runtime behavior; `OE-012` and
   `MCA-012` mark placement/scope uncertain. This audit recommends narrowing or
   relocating only after preserving the intended policy gate.

5. Native app launch evidence has a source-text guard but a runtime fallback.
   `TIA-008` finds the test checks script text, while `FLA-004` finds a path
   where release readiness can still pass with fallback accessibility text.
   The conflict is surfaced as a release-gate behavior issue, not averaged.

## 9. Highest-Risk Issues

| Priority | Finding | Why it is high risk |
|---:|---|---|
| 1 | `STC-FL-001` | Core Audio state can be cleared after unverified realtime cleanup/restoration. |
| 2 | `STC-FL-003` | UDP loopback evidence can be returned while the receive side failed or timed out. |
| 3 | `STC-FL-004` | Release readiness can print native app launch `PASS` without required UI label proof. |
| 4 | `STC-FL-002` | Audio loopback report can say completed after hidden destroy/restore failures. |
| 5 | `STC-TI-001` | Swift fallback tests can silently avoid exercising LoLa control fallback. |
| 6 | `STC-TI-004` | Rendered app UI truth is not protected by a direct launch/runtime-state test. |
| 7 | `STC-TI-005` | Synthetic report tests do not mutate every report toward false `PASS`. |
| 8 | `STC-MC-001` | App execution state is concentrated in one large controller at the UI/runtime boundary. |

## 10. Low-Risk Simplification Candidates

These are low-risk only if replacement behavior coverage exists where needed:

| Candidate | Source IDs | Why likely low risk | Required proof first |
|---|---|---|---|
| Release run count/literal contract rows | `OE-008`, `MCA-011`, `TIA-002` | Source audits say the test mostly asserts count and docs substrings. | Harness execution and false-PASS rejection tests. |
| Metadata marker/no-op helper | `OE-009`, `MCA-008`, `TIA-004` | Source audits say it proves compile conformance, not behavior. | Decoded metadata fixture and validator-output tests. |
| `OpenLolaCLI.*Data()` / `*JSONString()` wrapper pairs | `OE-006`, `MCA-007`, `TIA-003` | Single forwarding layer around JSON factories. | CLI-level machine-readable output tests. |
| CLI inventory family rows that duplicate router facts | `OE-001`, `MCA-002` | Duplicate facts can be derived from executable routing. | Public command inventory audit and router tests. |
| Scenario wrapper registration cleanup | `TIA-012` | Failures already occur if helpers run; change mostly improves reporting/filtering. | Verify each helper is still registered and runnable. |

Not low-risk yet:

- External connector NMP stack: active docs/tests make intent unclear.
- Raw Ethernet Python exports: downstream public API use is unknown.
- `audioCompression`: source audit says keep.
- Core Audio, UDP loopback, AVFoundation, and process cleanup: behavior-risk
  changes require focused injection tests and broader runtime verification.

## 11. Suggested Remediation Slices

### SLICE-01

- Slice ID: `SLICE-01`
- Title: Fail loudly on runtime cleanup uncertainty
- Findings addressed: `STC-FL-001`, `STC-FL-002`, `STC-FL-007`, `STC-FL-008`
- Minimal remediation strategy: add explicit cleanup/result accounting in the
  affected runtime paths. Preserve current behavior except where success is
  currently claimed without proof.
- Files likely affected:
  `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift`,
  `Sources/OpenLolaCore/Audio/Routing/AudioLoopbackRun.swift`,
  `Sources/OpenLolaCore/Support/ManagedProcessRunner.swift`,
  `Sources/OpenLolaCore/Video/VideoCaptureAVFoundation.swift`,
  focused tests.
- Tests needed: injectable Core Audio stop/destroy/restore failures, process
  kill/handle-close failures, raw frame extraction failure.
- Verification needed: focused Swift filters for new tests, then relevant audio
  and video report validator tests.
- Risk level: high
- Definition of Done: reports/results distinguish success, failed cleanup, and
  unknown cleanup; focused tests fail before the fix and pass after it.

### SLICE-02

- Slice ID: `SLICE-02`
- Title: Account for skipped, malformed, and missing loopback/control work
- Findings addressed: `STC-FL-003`, `STC-FL-005`, `STC-TI-001`,
  `STC-TI-007`
- Minimal remediation strategy: add explicit receive-side/looper result fields
  and malformed/wrong-peer/wrong-session counts; make unavailable loopback
  capability visible as skip/uncertainty rather than silent green.
- Files likely affected:
  `Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackSmokes.swift`,
  NAT rendezvous/relay report code,
  `linux_connector/lola_connector/connector.py`,
  Swift LoLa fallback tests, Python connector tests.
- Tests needed: looper failure/timeout, malformed NAT datagrams, wrong-session
  NAT datagrams, malformed QuickConn ACK, unavailable alias, alias available
  fallback success.
- Verification needed: focused Swift network tests, `python -m pytest -p
  no:cacheprovider linux_connector`, and report validator checks if schemas
  change.
- Risk level: high
- Definition of Done: loopback/control reports cannot conflate full success,
  partial success, skipped work, and timeout/malformed traffic.

### SLICE-03

- Slice ID: `SLICE-03`
- Title: Make app UI and launch evidence prove the status they claim
- Findings addressed: `STC-FL-004`, `STC-FL-006`, `STC-TI-004`,
  `STC-MC-001`
- Minimal remediation strategy: first make the release/native launch probe fail
  or mark uncertainty when required labels are missing; then split only the
  app-controller logic needed to make command path and copy status explicit.
- Files likely affected:
  `script/build_and_run.sh`,
  `scripts/verify-release-readiness.sh`,
  `Sources/open-lola-app/AppExecutionController.swift`,
  `Sources/open-lola-app/AppExecutablePathResolver.swift`,
  app view files with pasteboard helpers, focused app tests.
- Tests needed: Accessibility unavailable, missing labels, missing executable,
  pasteboard failure, no report, malformed report, partial report, stale pass.
- Verification needed: `swift test --filter AppBundleScriptSourcePolicyTests`
  or replacement behavior tests, app shell tests, and a manual/native launch
  probe when environment permits.
- Risk level: high
- Definition of Done: UI/release status distinguishes verified launch evidence
  from fallback or unavailable evidence, and app copy/path states do not claim
  success without proof.

### SLICE-04

- Slice ID: `SLICE-04`
- Title: Replace trivia tests with behavior tests
- Findings addressed: `STC-TI-002`, `STC-TI-003`, `STC-TI-005`,
  `STC-TI-006`, `STC-MC-005`, `STC-MC-006`
- Minimal remediation strategy: remove count/string/no-op assertions only after
  adding behavior coverage for executable harnesses, CLI JSON output, metadata
  semantics, and synthetic false-PASS rejection.
- Files likely affected:
  `Tests/OpenLolaCoreTests/ReleaseRunConfigurationContractTests.swift`,
  `Tests/OpenLolaCoreTests/MachineReadableSurfaceContractTests.swift`,
  `Tests/OpenLolaCoreTests/ReportSchemaInventoryTests.swift`,
  `Tests/OpenLolaCoreTests/SyntheticSmokeReportContractTests.swift`,
  selected inventory/tooling/template tests.
- Tests needed: harness false-PASS rejection, CLI output parse/validate,
  metadata fixture validation, synthetic report mutation tests.
- Verification needed: focused Swift filters for changed tests, then
  `swift test --no-parallel` if test registration or shared fixtures change.
- Risk level: medium
- Definition of Done: each retained test would fail when meaningful behavior or
  evidence policy changes incorrectly.

### SLICE-05

- Slice ID: `SLICE-05`
- Title: Deduplicate command/schema/matrix inventories after behavior coverage
- Findings addressed: `STC-MC-002`, `STC-MC-003`, `STC-MC-004`
- Minimal remediation strategy: choose one current source of truth for each
  command/schema/policy fact and remove duplicate rows only after verifying all
  current consumers.
- Files likely affected: CLI router/inventory files, report schema inventory,
  route/video/source matrix files, docs/tests that consume those surfaces.
- Tests needed: public command route tests, schema fixture/validator tests,
  route verdict-boundary tests, video/control degrade policy tests.
- Verification needed: focused Swift tests, docs verification, report
  validation, and CLI smoke checks for affected commands.
- Risk level: medium to high
- Definition of Done: no behavior or public machine-readable surface is lost;
  duplicated facts are either derived or covered by behavior tests.

### SLICE-06

- Slice ID: `SLICE-06`
- Title: Prove or shrink uncertain compatibility surfaces
- Findings addressed: `STC-MC-007`, `STC-MC-008`
- Minimal remediation strategy: perform active-use inventory before any code
  deletion. Mark each NMP/raw-Ethernet option as active, test-only, docs-only,
  or unused.
- Files likely affected: external connector NMP files, Python raw Ethernet
  helper files, docs, tests, CLI/app callers if any.
- Tests needed: focused external connector workflow tests and Python connector
  tests for any retained public helpers.
- Verification needed: `rg` use audit across source/docs/tests/scripts,
  relevant Swift external connector filters, and Python connector test suite.
- Risk level: medium
- Definition of Done: each retained compatibility path has a current caller or
  documented public contract; each removed path has no active-use evidence.

### SLICE-07

- Slice ID: `SLICE-07`
- Title: Re-scope the line-budget gate without losing the policy
- Findings addressed: `STC-MC-009`
- Minimal remediation strategy: decide whether line-budget enforcement belongs
  in Swift unit tests or docs/hygiene verification. Keep the current policy
  intent if it is still required.
- Files likely affected: `Tests/OpenLolaCoreTests/CodeLineBudgetTests.swift`,
  verification scripts/docs if the gate moves.
- Tests needed: stale exception detection and oversized owned-source detection;
  behavior tests for oversized high-risk runtime files.
- Verification needed: focused line-budget test or replacement script plus docs
  verification.
- Risk level: low to medium
- Definition of Done: policy failures remain visible, but runtime test results
  are not dominated by a broad repository scanner that proves no behavior.

## 12. Verification Strategy

For this consolidation document:

- Run `bash scripts/verify-docs.sh` when practical.
- Confirm only `docs/simplicity-test-certainty-audit.md` was created or updated
  by this task.

For future remediation:

- Start with focused tests named in each slice.
- Broaden only after the local behavior boundary is proven.
- Use `swift test --filter <RelevantSwiftTestName>` for focused Swift work.
- Use `swift test --no-parallel` after shared contracts, report schemas, CLI
  surfaces, or test registration change.
- Use `python -m pytest -p no:cacheprovider linux_connector` for Python
  connector changes.
- Use `ruff check linux_connector scripts/verify_docs scripts/lib/*.py` and
  `python -m mypy --strict linux_connector/lola_connector scripts/verify_docs
  scripts/lib/*.py` for Python source changes.
- Use `shellcheck -x scripts/*.sh scripts/lib/*.sh script/*.sh
  linux_connector/env/*.sh` for script changes.
- Use `bash scripts/verify-release-readiness.sh` only when release gates,
  app-launch probes, or release evidence policy change, and report any skipped
  hardware/manual gates explicitly.
- Do not call a runtime path fixed until negative/failure behavior is verified,
  not just the happy path.

## 13. Remaining Uncertainty

- This file is a consolidation of source audits, not a new full-code audit.
- Some source audit files are targeted and explicitly did not inspect every
  source or assertion.
- `STC-MC-007`, `STC-MC-008`, and `STC-MC-009` remain uncertain because source
  audits found evidence of active docs/tests or intentional policy, but also
  found over-broad shape.
- External users of CLI surfaces, report schemas, Python exports, and
  machine-readable inventories were not audited.
- Runtime proof for Core Audio, AVFoundation, native app launch, and network
  edge cases still requires injectable tests or manual/native probes.
- Valuable existing tests called out by `docs/test-intent-audit.md` should be
  preserved unless a replacement test would fail on the same meaningful
  behavior: app shell behavior tests, Python runtime tests, external connector
  process-group tests, bounded file reader tests, managed process runner tests,
  and LoLa compatibility media codec tests.
- Files described by the source audits as simple enough should not be touched
  without new evidence: `CLICommandHelpers.validateReport`, base
  `ReportValidatorSurface`, `linux_connector/lola_connector/media.py`,
  `ExternalConnectorSessionRuntime`, and
  `ExternalConnectorProcessRunner`.
