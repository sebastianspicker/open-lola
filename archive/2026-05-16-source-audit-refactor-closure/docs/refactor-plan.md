# Refactor And Code-Quality Plan

Date: 2026-05-16

Purpose: convert the current inventory, architecture map, verification baseline,
deprecation audit, and logic/correctness audit into small reviewable slices.
This is a planning artifact only; no production code is changed by this file.

## Inputs

- `AGENTS.md`
- `docs/code-index.md`
- `docs/verification-baseline.md`
- `docs/architecture-map.md`
- `docs/deprecation-and-simplification-audit.md`
- `docs/logic-and-correctness-audit.md`

## Sequencing Rules

1. Restore trusted verification before source refactors.
2. Fix false-success and silent-wrong behavior before style cleanup.
3. Keep high-risk runtime edits narrow and independently reversible.
4. Delete code only when live usage, tests, and compatibility evidence agree.
5. Prefer direct fixes and inlining over new abstractions.
6. For every implementation slice, run the focused check first; broaden only
   when the touched surface justifies it.

## Slice RP-00 - Restore Documentation And Release-Hygiene Gates

- ID: RP-00
- Title: Restore docs and hygiene verification baseline
- Problem: `docs/verification-baseline.md` records docs verification blocked by
  an archived `.DS_Store` link and release hygiene blocked by generated Python
  cache residue.
- Findings addressed: verification-baseline failures 1 and 2; DS-012.
- Files affected: `archive/2026-05-11-reverse-engineering-consolidation/README.md`,
  generated cache paths such as `scripts/verify_docs/__pycache__`,
  `.ruff_cache`, `.mypy_cache` if present.
- Behavior affected: no runtime behavior. Verification gates become meaningful
  again.
- Public contracts affected: documentation/release hygiene gates only.
- Storage/migration impact, if any: remove generated local cache files only; no
  schema or runtime storage migration.
- Tests to add or update: none expected unless the docs verifier policy needs a
  fixture for archived broken links.
- Verification commands:
  - `bash scripts/verify-docs.sh`
  - `python3 -m scripts.verify_docs`
  - `bash scripts/verify-release-hygiene.sh`
  - `bash scripts/verify-release-readiness.sh`
- Rollback strategy: restore the archived README line and regenerated cache
  files if the cleanup removed intended trace evidence.
- Risk level: low
- Ordering rationale: all later slices need a trusted baseline and release
  wrapper.
- Definition of Done: docs verifier and release hygiene pass, and release
  readiness reaches the next real blocker or completes without the recorded
  baseline failures.

## Slice RP-01 - Stop Direct Mac App Validation From Promoting Partial Evidence

- ID: RP-01
- Title: Direct Mac validation requires supervisor PASS evidence
- Problem: app validation can show `"Validation passed."` for a direct Mac
  supervisor report whose own verdict is `.partial`.
- Findings addressed: LC-001, LC-007.
- Files affected: `Sources/open-lola-app/AppExecutionController.swift`,
  `Sources/open-lola-app/AppLatencyHeroMetrics.swift` if supervisor verdict
  needs to be carried, `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift`.
- Behavior affected: direct Mac validation no longer treats loadable peer
  metrics alone as full validation.
- Public contracts affected: app validation status semantics; no report schema
  change unless the implementation chooses to expose the supervisor verdict in a
  new app-only model.
- Storage/migration impact, if any: none.
- Tests to add or update: update the existing partial-supervisor test to expect
  incomplete validation; add a `.pass` supervisor case that proves validation
  still turns green when the report contract permits it.
- Verification commands:
  - `swift test --build-path /private/tmp/open-lola2-rp01 --no-parallel --filter AppShellBehaviorTests`
  - `swift test --build-path /private/tmp/open-lola2-rp01 --no-parallel --filter NativeAppShell`
- Rollback strategy: revert the app predicate and test expectation in one PR.
- Risk level: high
- Ordering rationale: confirmed false-success state in the native app; fix
  before lower-risk cleanup.
- Definition of Done: a partial direct supervisor report cannot produce
  `.validationPassed`, and a valid pass report still can.

## Slice RP-02 - Stop Windows LoLa App Validation From Accepting Partial Or Fail Reports

- ID: RP-02
- Title: Windows LoLa validation requires pass-level connector evidence
- Problem: Windows LoLa app validation currently treats any validated
  `ExternalConnectorSessionReport`, including `.partial` and `.fail`, as runtime
  evidence.
- Findings addressed: LC-002, LC-007.
- Files affected: `Sources/open-lola-app/AppExecutionController.swift`,
  `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift`,
  `Tests/OpenLolaCoreTests/NativeAppShellWindowsLoLaTests.swift` if command
  expectations need coverage.
- Behavior affected: `.partial` and `.fail` reports remain visible but do not
  produce `"Validation passed."`.
- Public contracts affected: app validation semantics for
  `validate-external-connector-session-report`; connector report schema stays
  unchanged.
- Storage/migration impact, if any: none.
- Tests to add or update: Windows LoLa validation cases for `.pass`, `.partial`,
  `.fail`, unreadable JSON, and missing report path.
- Verification commands:
  - `swift test --build-path /private/tmp/open-lola2-rp02 --no-parallel --filter 'AppShellBehaviorTests|NativeAppShellWindowsLoLaTests'`
  - optional app surface probe after build: `bash script/build_and_run.sh --verify`
- Rollback strategy: revert the Windows LoLa predicate and tests together.
- Risk level: high
- Ordering rationale: confirmed false-success state tied to external endpoint
  evidence.
- Definition of Done: only pass-level connector evidence can mark Windows LoLa
  app validation passed; partial/fail reports produce a truthful non-green state.

## Slice RP-03 - Preserve Two-Peer Aggregate Failure Reasons

- ID: RP-03
- Title: Make two-peer aggregate report failure observable
- Problem: `direct-p2p-two-peer-local-run` discards
  `writeAggregatePrototypeReport` errors with `try?`, so missing/corrupt
  aggregate evidence becomes an unexplained partial report.
- Findings addressed: LC-003.
- Files affected:
  `Sources/open-lola/Commands/Network/DirectP2PTwoPeerLocalRunCommandSupport.swift`,
  `Sources/OpenLolaCore/Network/P2P/DirectPeerTwoPeerLocalRunReport.swift` only
  if an explicit field is chosen, and
  `Tests/OpenLolaCoreTests/DirectPeerTwoPeerRunPlanTests.swift` or a focused CLI
  command-support test.
- Behavior affected: aggregate evidence failure is reported explicitly; no
  silent partial downgrade.
- Public contracts affected: preferably only report `notes`; adding a structured
  field would be a report schema change and must update validators/fixtures.
- Storage/migration impact, if any: none if using notes; schema/fixture update
  if adding a field.
- Tests to add or update: simulate a zero-exit two-peer run with missing RX proof
  or corrupt peer report and assert the failure reason is visible.
- Verification commands:
  - `swift test --build-path /private/tmp/open-lola2-rp03 --no-parallel --filter DirectPeerTwoPeerRunPlanTests`
  - `swift test --build-path /private/tmp/open-lola2-rp03 --no-parallel --filter ReportFixtureValidationContractTests`
- Rollback strategy: revert the explicit error capture and test.
- Risk level: medium
- Ordering rationale: fixes silent partial failure in a high-risk P2P evidence
  path after app false-success fixes.
- Definition of Done: aggregate report failures are visible in command output or
  report content, and successful aggregate reports still produce pass-eligible
  evidence.

## Slice RP-04 - Use Monotonic Deadlines For Process Supervision

- ID: RP-04
- Title: Replace wall-clock process deadlines with monotonic time
- Problem: process and readiness waits use `Date()` deadlines, so system clock
  changes can stretch or shorten bounded waits.
- Findings addressed: LC-004.
- Files affected: `Sources/OpenLolaCore/Support/ManagedProcessRunner.swift`,
  `Sources/open-lola/Commands/Network/DirectP2PTwoPeerLocalRunCommandSupport.swift`,
  `Tests/OpenLolaCoreTests/ManagedProcessRunnerTests.swift`,
  `Tests/OpenLolaCoreTests/DirectPeerTwoPeerRunPlanTests.swift`.
- Behavior affected: timeout behavior becomes elapsed-time based; command names
  and report schemas unchanged.
- Public contracts affected: timeout reliability for CLI/process supervision.
- Storage/migration impact, if any: none.
- Tests to add or update: focused process-runner timeout tests and readiness
  wait tests using injectable elapsed-time logic where practical.
- Verification commands:
  - `swift test --build-path /private/tmp/open-lola2-rp04 --no-parallel --filter 'ManagedProcessRunnerTests|DirectPeerTwoPeerRunPlanTests'`
  - `swift test --build-path /private/tmp/open-lola2-rp04 --no-parallel --filter AppShellBehaviorTests`
- Rollback strategy: revert the deadline helper/signature change and targeted
  tests.
- Risk level: medium
- Ordering rationale: high-risk runtime supervision, but less immediately
  user-visible than confirmed app false-success states.
- Definition of Done: process waits no longer compare against wall-clock
  `Date()`, and existing process-supervision behavior remains covered.

## Slice RP-05 - Use Monotonic Deadlines For LoLa Control And Media Waits

- ID: RP-05
- Title: Replace wall-clock LoLa runtime/media deadlines
- Problem: LoLa control retry responder, raw-link receive, UDP media receive,
  and external connector process waits use wall-clock deadlines.
- Findings addressed: LC-004.
- Files affected:
  `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSessionRuntime.swift`,
  `Sources/OpenLolaCore/Connectors/LoLa/LoLaControlExchangeRuntime.swift`,
  `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityRawLink.swift`,
  `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityUdpMediaSocket.swift`,
  relevant `LoLaCompatibility*Tests` and `ExternalConnector*Tests`.
- Behavior affected: LoLa control/media waits become stable under wall-clock
  changes.
- Public contracts affected: runtime timeout behavior for LoLa compatibility
  commands.
- Storage/migration impact, if any: none.
- Tests to add or update: focused timeout tests for affected helpers, preferring
  dependency-injected clock/deadline seams over sleeping tests.
- Verification commands:
  - `swift test --build-path /private/tmp/open-lola2-rp05 --no-parallel --filter 'LoLaCompatibility|ExternalConnectorSessionTests|ExternalConnectorProcessGroupTests'`
  - `swift test --build-path /private/tmp/open-lola2-rp05 --no-parallel --filter LoLaUdpMediaSocketTests`
- Rollback strategy: revert deadline changes in LoLa files only.
- Risk level: medium
- Ordering rationale: same correctness class as RP-04, but larger connector
  surface and should follow the smaller process-supervision slice.
- Definition of Done: no affected LoLa wait loop uses wall-clock `Date()` for
  elapsed-time decisions, and timeout behavior stays covered.

## Slice RP-06 - Make UDP Media Jitter Aggregation Stream-Aware

- ID: RP-06
- Title: Prevent multi-stream jitter metric contamination
- Problem: `UdpMediaTransport` keeps transit history per stream but updates one
  shared jitter EWMA, so interleaved streams can produce misleading metrics.
- Findings addressed: LC-005.
- Files affected: `Sources/OpenLolaCore/Network/UDP/UdpMediaTransport.swift`,
  `Tests/OpenLolaCoreTests/UdpMediaTransportTests.swift`.
- Behavior affected: jitter reporting becomes explicit for multi-stream input.
- Public contracts affected: `UdpMediaMetrics.jitterMicroseconds` semantics; the
  aggregation policy must be documented by tests.
- Storage/migration impact, if any: none unless report fixtures encode exact
  jitter values.
- Tests to add or update: deterministic two-stream jitter test; existing
  single-stream loss/reorder/duplicate tests must still pass.
- Verification commands:
  - `swift test --build-path /private/tmp/open-lola2-rp06 --no-parallel --filter UdpMediaTransportTests`
  - `swift test --build-path /private/tmp/open-lola2-rp06 --no-parallel --filter 'UdpPcm|PeerSessionAVSupportTests'`
- Rollback strategy: revert metric accumulator changes and tests.
- Risk level: medium
- Ordering rationale: fixes a suspected wrong-result metric in packet/runtime
  code after confirmed false-success and timeout issues.
- Definition of Done: multi-stream packets cannot overwrite each other's jitter
  state unintentionally, and the aggregate metric policy is executable in tests.

## Slice RP-07 - Preserve Network Diagnostics Parse And Process Failure Reasons

- ID: RP-07
- Title: Make ping/traceroute diagnostics failures explainable
- Problem: network diagnostics can collapse ping process or parse failures into
  `nil`, and malformed summaries can become default packet-loss values without
  an explicit reason.
- Findings addressed: LC-006.
- Files affected:
  `Sources/OpenLolaCore/Network/Diagnostics/NetworkDiagnostics.swift`,
  `Tests/OpenLolaCoreTests/NetworkDiagnosticsTests.swift`,
  report fixtures only if the schema changes.
- Behavior affected: diagnostic reports distinguish unreachable peer, process
  failure, unsupported output, and parse failure.
- Public contracts affected: `NetworkDiagnosticsReport` schema if failure
  details become structured fields.
- Storage/migration impact, if any: report schema/fixture migration if adding
  `pingError` or equivalent.
- Tests to add or update: malformed macOS output, Linux-style output if
  supported, localized/unsupported output if unsupported, and runner-level
  process failure.
- Verification commands:
  - `swift test --build-path /private/tmp/open-lola2-rp07 --no-parallel --filter NetworkDiagnosticsTests`
  - `swift test --build-path /private/tmp/open-lola2-rp07 --no-parallel --filter ReportFixtureValidationContractTests`
- Rollback strategy: revert schema/parser changes and fixture updates.
- Risk level: low to medium
- Ordering rationale: improves diagnostic truthfulness after higher-risk runtime
  validation and metrics fixes.
- Definition of Done: a diagnostic partial report includes why ping/traceroute
  data is absent or untrusted.

## Slice RP-08 - Replace Misleading App Validation Tests With Behavior Tests

- ID: RP-08
- Title: Make app validation tests assert runtime truth, not file existence
- Problem: tests currently prove readiness for an existing `{}` file and, in one
  case, protect a partial-report validation pass.
- Findings addressed: LC-007; supports LC-001 and LC-002.
- Files affected: `Tests/OpenLolaCoreTests/AppShellSlice05Tests.swift`,
  `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift`,
  `Tests/OpenLolaCoreTests/NativeAppShellWindowsLoLaTests.swift`.
- Behavior affected: test behavior only, unless paired with RP-01/RP-02.
- Public contracts affected: app validation behavior as encoded by tests.
- Storage/migration impact, if any: none.
- Tests to add or update: invalid JSON at existing path, partial/fail/pass
  report cases, stale report path, and missing report path.
- Verification commands:
  - `swift test --build-path /private/tmp/open-lola2-rp08 --no-parallel --filter 'AppShellSlice05Tests|AppShellBehaviorTests|NativeAppShellWindowsLoLaTests'`
- Rollback strategy: revert tests only.
- Risk level: low
- Ordering rationale: should follow the behavior fixes so tests do not codify
  known-wrong semantics.
- Definition of Done: app validation tests fail when report verdict semantics,
  invalid JSON handling, or missing runtime evidence regress.

## Slice RP-09 - Delete Proven-Dead Python Backend Declarations

- ID: RP-09
- Title: Remove unused Python backend type residue
- Problem: `ProcessBackendError` and likely `AudioBackend` add unused surface in
  the Python connector backend module.
- Findings addressed: DS-001, DS-002.
- Files affected: `linux_connector/lola_connector/backends.py`,
  `linux_connector/tests/*` only if imports need adjustment.
- Behavior affected: none for in-repo callers.
- Public contracts affected: possible direct out-of-repo imports from
  `linux_connector.lola_connector.backends`; verify before deletion.
- Storage/migration impact, if any: none.
- Tests to add or update: usually none; add an import-surface test only if the
  package documents these names.
- Verification commands:
  - `RUFF_CACHE_DIR=/private/tmp/open-lola2-rp09-ruff ruff check linux_connector scripts/verify_docs scripts/lib/*.py`
  - `MYPY_CACHE_DIR=/private/tmp/open-lola2-rp09-mypy python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py`
  - `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector`
- Rollback strategy: restore the two declarations.
- Risk level: low
- Ordering rationale: low-risk deletion after higher-value correctness work.
- Definition of Done: in-repo search finds no references, Python lint/type/tests
  pass, and any external API decision is recorded.

## Slice RP-10 - Inline Single-Use Report Validation Lifecycle

- ID: RP-10
- Title: Inline one-off report validation lifecycle protocol
- Problem: `ReportValidationLifecycle` exists for only `IntegratedAvReport`,
  making validation look more generic than it is.
- Findings addressed: DS-008.
- Files affected: `Sources/OpenLolaCore/Evidence/ReportValidatorSurface.swift`,
  `Sources/OpenLolaCore/Integration/IntegratedAvReportValidation.swift`,
  `Tests/OpenLolaCoreTests/IntegratedAvReportTests.swift`.
- Behavior affected: no intended behavior change.
- Public contracts affected: internal validation structure only, unless the
  protocol is public API; check visibility before removal.
- Storage/migration impact, if any: none.
- Tests to add or update: keep existing error-order behavior covered; add a
  focused validation-order test if removal changes call order risk.
- Verification commands:
  - `swift test --build-path /private/tmp/open-lola2-rp10 --no-parallel --filter IntegratedAvReportTests`
  - `swift test --build-path /private/tmp/open-lola2-rp10 --no-parallel --filter ReportFixtureValidationContractTests`
- Rollback strategy: restore the protocol and extension.
- Risk level: low to medium
- Ordering rationale: simple code-quality slice with a small edit surface.
- Definition of Done: the one-use protocol is gone or explicitly kept with a
  second real call site; validation behavior remains unchanged.

## Slice RP-11 - Deduplicate Video Validation Primitives

- ID: RP-11
- Title: Route video primitive checks through shared validation helpers
- Problem: video capture code duplicates non-empty, positive, non-negative, and
  finite checks already present in core validation primitives.
- Findings addressed: DS-010.
- Files affected: `Sources/OpenLolaCore/Video/VideoCaptureHelpers.swift`,
  `Sources/OpenLolaCore/Video/VideoCaptureReport.swift`,
  `Sources/OpenLolaCore/Video/VideoCaptureAVFoundation.swift`,
  `Sources/OpenLolaCore/Core/ValidationPrimitives.swift` only if an existing
  helper is missing, and video tests.
- Behavior affected: no intended behavior change; error cases and ordering must
  stay stable unless deliberately updated.
- Public contracts affected: video report validation error behavior.
- Storage/migration impact, if any: none.
- Tests to add or update: video validation edge cases for empty fields,
  non-positive sizes, non-finite metrics, packet-age ordering, and AVFoundation
  inventory fields.
- Verification commands:
  - `swift test --build-path /private/tmp/open-lola2-rp11 --no-parallel --filter 'VideoCaptureReportTests|VideoTransportReportTests|VideoTransportRunnerTests'`
  - `swift test --build-path /private/tmp/open-lola2-rp11 --no-parallel --filter ReportFixtureValidationContractTests`
- Rollback strategy: restore local video helper implementations.
- Risk level: medium
- Ordering rationale: meaningful simplification, but lower priority than silent
  wrong behavior and runtime deadline fixes.
- Definition of Done: duplicated primitive video helpers are removed or reduced
  to domain-specific checks, and video report validation remains covered.

## Slice RP-12 - Simplify Python Process Backend Lifecycle Duplication

- ID: RP-12
- Title: Consolidate repeated Python process backend lifecycle code
- Problem: process capture/playback/display classes repeat subprocess start,
  stdout readiness, return-code, stdin, and cleanup logic.
- Findings addressed: DS-016.
- Files affected: `linux_connector/lola_connector/backends.py`,
  `linux_connector/tests/test_process_runtime.py`,
  `linux_connector/tests/test_runtime_contracts.py`.
- Behavior affected: no intended behavior change; cleanup and error reporting
  should become harder to miss across backend variants.
- Public contracts affected: Python connector backend runtime behavior and error
  text.
- Storage/migration impact, if any: none.
- Tests to add or update: early process exit, stdout readiness, stdin write
  failure, cancellation/cleanup, and normal process termination.
- Verification commands:
  - `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector/tests/test_process_runtime.py linux_connector/tests/test_runtime_contracts.py`
  - `RUFF_CACHE_DIR=/private/tmp/open-lola2-rp12-ruff ruff check linux_connector scripts/verify_docs scripts/lib/*.py`
  - `MYPY_CACHE_DIR=/private/tmp/open-lola2-rp12-mypy python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py`
- Rollback strategy: revert the helper extraction and tests.
- Risk level: medium
- Ordering rationale: real duplication with multiple call sites, but should wait
  until correctness and smaller deletion slices are complete.
- Definition of Done: repeated lifecycle branches are reduced without changing
  process behavior, and process-runtime tests cover each backend class touched.

## Slice RP-13 - Compatibility Evidence Pass For Legacy Audio And Report Names

- ID: RP-13
- Title: Prove keep/delete decisions for legacy compatibility paths
- Problem: several compatibility paths look stale but cannot be safely removed
  without usage evidence.
- Findings addressed: DS-003, DS-004, DS-005, DS-007, DS-014, DS-015.
- Files affected: no production files in this slice. Output should be a small
  compatibility decision note under `docs/` or an update to an existing audit
  ledger if the implementation phase explicitly allows it.
- Behavior affected: none.
- Public contracts affected: decision inventory for `--audio-compression`,
  `audioCompression`, `audioDeviceUID`, UDP PCM v1, `OpenLolaContracts`
  aliases, `LoLaParityDeferredSyntheticSmoke`, and direct P2P `prototype`
  naming.
- Storage/migration impact, if any: identifies old JSON/user-default migration
  risks before deletion.
- Tests to add or update: none in this evidence-only slice.
- Verification commands:
  - `rg -n "audioCompression|--audio-compression|audioDeviceUID|LoLaParityDeferredSyntheticSmoke|udpPcmV1|DirectPeerTwoPeerPrototype|OpenLolaContractsAliases" .`
  - `git log --all --stat -- "Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraphTypes.swift" "Sources/open-lola/Commands/Network" "Sources/OpenLolaCore/Network/P2P"`
  - targeted fixture searches under `Tests/OpenLolaCoreTests/Fixtures`
- Rollback strategy: delete the decision note if it proves misleading; no code
  rollback needed.
- Risk level: low
- Ordering rationale: required before any compatibility deletion; intentionally
  separate from code changes.
- Definition of Done: each legacy path has an evidence-backed `keep`, `delete`,
  or `defer` decision and a specific follow-up slice if deletion is justified.

## Slice RP-14 - Pilot One CLI Parser Consolidation

- ID: RP-14
- Title: Replace one hand-rolled CLI parser with `KeyValueArgumentParser`
- Problem: several commands duplicate key/value parser loops even though a
  shared parser exists.
- Findings addressed: DS-009.
- Files affected: start with
  `Sources/open-lola/Commands/Network/DirectP2PTwoPeerPrototypeCommandSupport.swift`
  or one similarly small command parser, plus its focused tests.
- Behavior affected: exact CLI error handling for one command.
- Public contracts affected: command flags, duplicate/missing/unknown argument
  error text for the chosen command.
- Storage/migration impact, if any: none.
- Tests to add or update: unknown flag, duplicate flag, missing value,
  dash-prefixed value behavior, valid command generation, and existing command
  inventory.
- Verification commands:
  - `swift test --build-path /private/tmp/open-lola2-rp14 --no-parallel --filter KeyValueArgumentParserTests`
  - `swift test --build-path /private/tmp/open-lola2-rp14 --no-parallel --filter DirectPeerTwoPeerRunPlanTests`
  - `.build/debug/open-lola <changed-command> --help` after `swift build --product open-lola --build-path /private/tmp/open-lola2-rp14`
- Rollback strategy: restore the hand-rolled parser for that command.
- Risk level: medium
- Ordering rationale: parser cleanup touches public CLI behavior; do it only as
  a one-command pilot after correctness work is stable.
- Definition of Done: one parser is simplified, all command-specific edge cases
  remain covered, and no other command parser is touched.

## Explicitly Deferred

- Broad command-router rewrites from DS-011 are deferred. They touch public CLI
  dispatch and should only happen with a separate written plan and command
  inventory proof.
- UDP PCM v1 removal is deferred. The current audits identify it as a live
  compatibility contract, not dead code.
- `OpenLolaContractsAliases.swift` removal is deferred. Tests intentionally
  assert this compatibility surface.
- Direct P2P `prototype` report renaming is deferred until RP-13 proves a
  compatibility-safe rename path.
- ThreadSanitizer evidence is deferred as an environment/toolchain blocker from
  `docs/verification-baseline.md`, not a source refactor task.
