# Minimum Code Audit

Date: 2026-05-16

Scope: current source, tests, and active documentation surfaces relevant to
"minimum code that solves the problem." This is an audit-only document. No
production code was changed.

Method: source search for inventories, runners, parsers, legacy paths, app
state, validation scaffolding, and duplicated command/configuration surfaces;
targeted reads of representative runtime-critical files; reuse of live evidence
captured in `docs/overengineering-index.md` where the current tree still points
to the same symbols.

Priority model:

1. Correctness risk or false-success risk.
2. Code that hides state, process errors, or teardown failures.
3. Code that makes meaningful tests difficult.
4. Code that duplicates behavior or authority.
5. Code that is merely ugly, broad, or verbose but appears safe.

## Findings

### MCA-001

- ID: MCA-001
- File: `Sources/open-lola-app/AppExecutionController.swift`
- Symbol / function / class / module: `AppExecutionController`, `start`,
  `launchProcess`, `runOneShot`, `stop`, `finishReport`
- Suggested action: SIMPLIFY
- Current behavior: One observable controller owns app execution settings,
  execution phase, status text, command/log paths, reports, latency metrics,
  capture reports, validation exit codes, error log state, elapsed-time state,
  process handles, stop state, and execution kind. It has separate paths for
  writing plans, direct execution, operator-surface execution, validation runs,
  report refresh, stop, and teardown. `stop()` marks a stop request and calls
  report finalization immediately while the termination handler also finalizes
  after process exit.
- Required behavior, if inferable: The app needs one truthful execution state
  machine that starts one command, exposes real running/finished/failed/stopped
  state, refreshes reports, and never promotes partial execution to success.
- Complexity problem: Too many mutable fields can be changed from multiple
  methods, and the run/validation paths duplicate process-launch and teardown
  concerns. This raises the risk that UI status, report state, and process state
  diverge.
- Minimal alternative: First extract no new public abstraction. Constrain the
  mutable execution result into one private value and route normal runs and
  validation through one private launch/teardown path where possible. Keep mode
  selection at the edge and make stop/report finalization single-owner.
- Risk of simplification: High. This is user-visible app state and process
  lifecycle code; a smaller version can easily break stop behavior, report
  refresh, or validation status.
- Tests needed before simplification: App controller behavior tests for start,
  failed start, validation pass/fail, stop-requested teardown, report refresh
  errors, and unsupported operator modes.
- Verification command or strategy: `swift test --filter AppShell`,
  `swift test --filter NativeAppShell`, then build/run the app path with
  `swift build --product open-lola-app` or `bash script/build_and_run.sh --verify`
  when practical.
- Confidence: high

### MCA-002

- ID: MCA-002
- File: `Sources/OpenLolaCore/Support/ManagedProcessRunner.swift`,
  `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorProcessRunner.swift`,
  `Sources/OpenLolaCore/Network/Diagnostics/NetworkDiagnostics.swift`
- Symbol / function / class / module: `ManagedProcessRunner`,
  `ExternalConnectorProcessRunner`, `runNetworkDiagnosticsProcess`
- Suggested action: DEDUPLICATE
- Current behavior: The tree has at least three process-execution
  implementations. `ManagedProcessRunner` wraps `Process` with output handles
  and timeout termination. `ExternalConnectorProcessRunner` has POSIX
  process-group behavior, pipe capture, `waitpid`, and group termination.
  `NetworkDiagnostics` has its own `Process`, bounded pipe capture, semaphore,
  timeout, terminate, and kill flow.
- Required behavior, if inferable: App commands, external connector workflows,
  and network diagnostics must all run subprocesses with bounded output,
  timeout handling, truthful exit status, and no orphaned children. External
  connector process groups may legitimately require POSIX-specific code.
- Complexity problem: Common capture/timeout/teardown behavior is repeated in
  separate implementations. The duplication makes it harder to reason about
  which path has the correct timeout, handle-closing, and termination semantics.
- Minimal alternative: Do not create a broad process framework. Inventory the
  exact differences first, keep process-group behavior local to external
  connectors, and share only the smallest repeated helper that current call
  sites already need, such as bounded capture or timeout termination.
- Risk of simplification: High. Process teardown and external connector process
  groups are runtime-critical and may depend on platform-specific behavior.
- Tests needed before simplification: Managed runner tests, external connector
  process-group tests including timeout and child cleanup, and network
  diagnostics timeout/capture tests.
- Verification command or strategy: `swift test --filter ManagedProcessRunner`,
  `swift test --filter ExternalConnector`, `swift test --filter NetworkDiagnostics`.
- Confidence: high

### MCA-003

- ID: MCA-003
- File: `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorProcessRunner.swift`
- Symbol / function / class / module: `RunningExternalConnectorProcess.waitStatus`,
  `ExternalConnectorProcessResult.waitStatus`, `externalConnectorExitStatus`
- Suggested action: INVESTIGATE
- Current behavior: The external connector runner waits with `waitpid`. If
  `waitpid` reports `ECHILD`, the code returns `Int32.min` as a sentinel wait
  status and later maps wait status through `externalConnectorExitStatus`.
- Required behavior, if inferable: A completed external connector run should
  report whether the process launched, whether it exited, whether it was timed
  out, and a truthful exit status or explicit reason that the wait status is not
  available.
- Complexity problem: A magic sentinel hides a process-state distinction inside
  an integer that normally encodes POSIX wait status. That is smaller than a
  structured state, but it is not minimum code if every consumer must remember
  the sentinel meaning.
- Minimal alternative: Before changing behavior, inspect report consumers. If
  consumers need this distinction, replace the sentinel with an explicit local
  status case or existing error field. If no consumer uses it, remove the
  sentinel path and report the failure through the existing error surface.
- Risk of simplification: Medium to high. External connector teardown and
  Windows-LoLa evidence reports depend on this path.
- Tests needed before simplification: A test for `ECHILD` or unavailable wait
  status handling, plus existing external connector timeout and normal-exit
  tests.
- Verification command or strategy: `swift test --filter ExternalConnector`.
- Confidence: medium

### MCA-004

- ID: MCA-004
- File: `Sources/OpenLolaCore/Network/Diagnostics/NetworkDiagnostics.swift`,
  plus command configuration files that already use or bypass
  `KeyValueArgumentParser`
- Symbol / function / class / module: `parseNetworkDiagnosticsArguments`,
  `parseExternalConnectorKeyValueArguments`, `KeyValueArgumentParser`
- Suggested action: DEDUPLICATE
- Current behavior: Many command paths already use `KeyValueArgumentParser`,
  but network diagnostics still has a local `while` loop parser for `--key
  value` arguments. External connector parsing wraps the shared parser through
  `parseExternalConnectorKeyValueArguments`.
- Required behavior, if inferable: CLI commands should consistently reject
  unknown flags, missing values, invalid values, and malformed key/value input.
- Complexity problem: Hand-written parsers duplicate validation rules and error
  semantics. This is unnecessary configurability at the parser layer: every
  command can drift in how it accepts or rejects the same shape of arguments.
- Minimal alternative: Replace local parse loops with `KeyValueArgumentParser`
  only where semantics match exactly. Keep specialized wrappers when they add
  real connector-specific defaults or validation.
- Risk of simplification: Medium. CLI error text and support for values that
  look like flags may be part of tests or scripts.
- Tests needed before simplification: Focused parser tests for the changed
  command, including unknown flag, missing value, invalid numeric value, and
  dash-prefixed value cases where relevant.
- Verification command or strategy: `swift test --filter KeyValueArgumentParser`,
  `swift test --filter NetworkDiagnostics`, plus affected command tests.
- Confidence: high

### MCA-005

- ID: MCA-005
- File: `Sources/OpenLolaCore/Evidence/ReportSchemaInventory.swift`,
  `Sources/OpenLolaCore/Support/Inventories/FixtureSmokeMatrixData.swift`,
  `Sources/OpenLolaCore/Support/Inventories/SourceOwnershipInventory.swift`,
  `Sources/OpenLolaCore/Support/Inventories/NetworkRouteCommandMatrix.swift`
- Symbol / function / class / module: `ReportSchemaInventory`,
  `FixtureSmokeMatrixData`, `SourceOwnershipInventory`,
  `NetworkRouteCommandMatrix`
- Suggested action: DEDUPLICATE
- Current behavior: The source tree keeps several compiled inventories and
  matrices that repeat command names, fixture names, source paths, owners,
  validators, and release-readiness metadata. Tests assert these inventories
  against each other and against fixture surfaces.
- Required behavior, if inferable: Release and documentation gates need
  machine-readable inventories that detect missing validators, moved files, and
  stale commands.
- Complexity problem: Multiple hand-maintained authority surfaces make the code
  larger than the behavior they protect. The tests can become proofs that the
  duplicate ledgers agree rather than proofs that runtime/report contracts work.
- Minimal alternative: Pick one active inventory authority per concern and
  generate or derive the other matrix views from it. Keep only data that is
  consumed by a current CLI, verifier, docs gate, or release gate.
- Risk of simplification: High. These files are wired into release-readiness,
  source ownership, fixture, and machine-readable surface tests.
- Tests needed before simplification: Inventory contract tests, fixture smoke
  matrix tests, source ownership tests, CLI inventory tests, and release
  readiness checks.
- Verification command or strategy: `swift test --filter ReportSchemaInventoryTests`,
  `swift test --filter FixtureSmokeMatrixTests`,
  `swift test --filter SourceOwnershipInventoryTests`,
  `swift test --filter NetworkRouteCommandMatrixTests`,
  `bash scripts/verify-release-readiness.sh`.
- Confidence: high

### MCA-006

- ID: MCA-006
- File: `Sources/open-lola-app/AppSettings.swift`,
  `Sources/open-lola-app/AppStorageKeys.swift`,
  `Sources/open-lola-app/AppShellStoredDefaults.swift`
- Symbol / function / class / module: `AppSettings`, `AppStorageKeys`,
  `AppShellStoredDefaults`
- Suggested action: SIMPLIFY
- Current behavior: App defaults are represented through parallel field lists:
  settings properties, string storage keys, and manual read/write/hydration
  logic. `AppShellStoredDefaults` also performs legacy migration for
  `audioCompression` to `audioTransport`.
- Required behavior, if inferable: Persist app settings, hydrate operator
  surface defaults, migrate known legacy keys, and keep UI controls tied to
  runtime behavior.
- Complexity problem: Parallel field lists are easy to desynchronize and make
  every settings addition touch multiple files. This is boilerplate that hides
  persistence behavior rather than making it explicit at the call site.
- Minimal alternative: Keep the current storage keys stable, but group related
  default read/write logic closer to the setting structs or small focused
  helpers. Do not migrate key names unless a migration test exists.
- Risk of simplification: Medium to high. User defaults are a compatibility
  surface and migration failures can silently reset user configuration.
- Tests needed before simplification: Persistence round-trip tests for direct
  peer, Windows LoLa, preview, execution settings, and legacy
  `audioCompression` migration.
- Verification command or strategy: `swift test --filter AppShell`,
  `swift test --filter NativeAppShellOpusCommandTests`.
- Confidence: high

### MCA-007

- ID: MCA-007
- File: `Sources/open-lola-app/AppShellSettingsView.swift`
- Symbol / function / class / module: `AppSettingsMutationPolicy`
- Suggested action: INLINE
- Current behavior: A tiny enum exposes `executionSettingsLocked(isRunning:)`
  and `help(isRunning:)`. It is used only by the settings view and by focused
  tests.
- Required behavior, if inferable: Disable or explain execution settings while
  a run is active.
- Complexity problem: The abstraction is a single-use wrapper over a boolean
  and a help string. It does not centralize a cross-module policy.
- Minimal alternative: Inline the boolean and help text into the settings view,
  or keep a private local helper if the view would become less readable.
- Risk of simplification: Low. The behavior is small, but the disabled-control
  UX must remain tested.
- Tests needed before simplification: Existing AppShell slice tests that assert
  locked settings while running.
- Verification command or strategy: `swift test --filter AppShellSlice05Tests`.
- Confidence: high

### MCA-008

- ID: MCA-008
- File: `Sources/OpenLolaCore/Platform/NativeAppShellSessionMode.swift`,
  `Sources/open-lola-app/AppExecutionController.swift`
- Symbol / function / class / module: `NativeAppShellSessionMode`,
  `start(operatorSurface:execute:)`
- Suggested action: INVESTIGATE
- Current behavior: The app models direct Mac peer, Windows LoLa, JackTrip, and
  UltraGrid session modes. Execution supports direct Mac peer and Windows LoLa,
  while JackTrip and UltraGrid paths fail with "not wired to execution" errors.
- Required behavior, if inferable: The app should only expose modes that it can
  either execute or clearly present as planning-only without suggesting a
  runnable state.
- Complexity problem: Unsupported modes increase UI state and execution
  branching without delivering runtime behavior. They also create false-success
  risk if labels or plans imply that a mode is executable.
- Minimal alternative: Keep direct Mac peer and Windows LoLa as executable app
  modes. Either hide unsupported modes from executable UI, mark them explicitly
  as planning-only, or remove their app-mode plumbing if no current docs/tests
  require them.
- Risk of simplification: Medium. These modes may exist as deliberate future
  surface or documentation contract.
- Tests needed before simplification: App mode selection tests and command-plan
  tests that verify unsupported modes cannot be executed as successful runs.
- Verification command or strategy: `swift test --filter AppShell`,
  `swift test --filter NativeAppShell`.
- Confidence: medium

### MCA-009

- ID: MCA-009
- File: `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVRunTypes.swift`,
  `Sources/open-lola/Commands/Network/DirectP2PSessionRunCommandSupport.swift`,
  `Sources/open-lola/Commands/Network/DirectP2PSessionRunArgumentSupport.swift`,
  `Sources/open-lola-app/AppShellStoredDefaults.swift`
- Symbol / function / class / module: `DirectPeerSessionAudioCompression`,
  `DirectPeerSessionAudioTransport.legacyAudioCompression`, `--audio-compression`
- Suggested action: REPLACE_DEPRECATED
- Current behavior: The direct-peer AV command accepts the legacy
  `--audio-compression` flag, maps it to `audioTransport`, rejects conflicts,
  and hides the legacy flag from help. The app migrates the persisted legacy
  `audioCompression` key to `audioTransport`.
- Required behavior, if inferable: Current runtime should use
  `--audio-transport`; old persisted app settings should migrate without
  silently losing intent.
- Complexity problem: The legacy compatibility path adds enum and parser
  surface that exists only to preserve old naming. It is proportional only while
  active scripts, docs, or user defaults still require it.
- Minimal alternative: Keep the app storage migration until legacy defaults are
  proven unnecessary. For CLI, document a deprecation window or remove
  `--audio-compression` once tests and docs prove no active workflow uses it.
- Risk of simplification: Medium. Removing the flag can break old scripts and
  local test fixtures.
- Tests needed before simplification: CLI conflict tests, hidden-help tests,
  and app legacy-default migration tests.
- Verification command or strategy: `swift test --filter DirectPeerSessionOpusCLITests`,
  `swift test --filter NativeAppShellOpusCommandTests`.
- Confidence: high

### MCA-010

- ID: MCA-010
- File: `Sources/OpenLolaCore/Audio/Routing/AudioRoutingAssumptionLedger.swift`
- Symbol / function / class / module: `AudioRoutingAssumptionLedger`
- Suggested action: DELETE
- Current behavior: A compiled source ledger records audio routing assumptions,
  evidence, status, and tests. Search evidence shows this is included in source
  ownership and documentation-style governance checks rather than realtime
  audio routing.
- Required behavior, if inferable: Keep audio routing assumptions visible and
  verifiable so runtime work does not overclaim device, TX/RX, or local-RX
  behavior.
- Complexity problem: A static audit ledger in source code is not minimum
  runtime code if it is not consumed by runtime, validators, or release gates
  that require Swift types. It can make governance data look like executable
  behavior.
- Minimal alternative: Move durable assumption text to active docs and keep
  only a small source-owned pointer or release gate if machine-readable checks
  still need it.
- Risk of simplification: Medium. Source ownership and docs gates may depend
  on the compiled ledger today.
- Tests needed before simplification: Source ownership tests and any audio
  routing documentation/gate tests that consume the ledger.
- Verification command or strategy: `swift test --filter SourceOwnershipInventoryTests`,
  `bash scripts/verify-docs.sh`.
- Confidence: medium

### MCA-011

- ID: MCA-011
- File: `Sources/OpenLolaCore/Release/LoLaParityDeferredFeatures.swift`
- Symbol / function / class / module: `LoLaParityDeferredFeatures`
- Suggested action: SIMPLIFY
- Current behavior: A source-level deferred-feature registry records parity
  gaps and is tied to tests, fixture validation, schema inventory, and source
  ownership surfaces.
- Required behavior, if inferable: The project must not claim LoLa parity or
  product readiness for unimplemented or unmeasured features.
- Complexity problem: A registry of deferred features can become a speculative
  feature framework. The minimum requirement is a truthful blocker list tied to
  release gates, not a broad source model unless multiple current gates need
  typed access.
- Minimal alternative: Keep only the fields consumed by current release/schema
  gates. Move explanatory or aspirational detail to docs.
- Risk of simplification: Medium. It is protecting against false parity claims,
  so removing too much could weaken release evidence.
- Tests needed before simplification: Deferred-feature tests, schema inventory
  tests, and release-readiness fixture validation.
- Verification command or strategy: `swift test --filter LoLaParityDeferredFeaturesTests`,
  `swift test --filter ReportSchemaInventoryTests`,
  `bash scripts/verify-release-readiness.sh`.
- Confidence: medium

### MCA-012

- ID: MCA-012
- File: `Sources/OpenLolaCore/Connectors/NMP/ExternalConnectorNmpWorkflow.swift`
- Symbol / function / class / module: `ExternalConnectorNmpWorkflow`,
  NMP plan/run/validate flow
- Suggested action: INVESTIGATE
- Current behavior: The NMP connector path has a workflow-style surface that
  coordinates plan configuration, session run configuration, validation, and
  report artifacts.
- Required behavior, if inferable: NMP connector work should produce explicit
  plan/run/validation artifacts without implying that synthetic or connector
  evidence proves full product readiness.
- Complexity problem: The workflow surface looks broader than a minimum command
  pipeline and may preserve plan/run/validate stages for one connector family.
  That is warranted only if all stages are current user-facing commands or
  release gates.
- Minimal alternative: Inventory which NMP workflow stages are active CLI
  commands, tests, docs, or release gates. Inline or delete any stage that only
  forwards configuration without adding validation.
- Risk of simplification: Medium. Connector workflows are public CLI/report
  surface.
- Tests needed before simplification: NMP plan, run, validation, report-schema,
  and CLI command inventory tests.
- Verification command or strategy: `swift test --filter ExternalConnectorNmp`,
  `swift test --filter CLICommandInventoryTests`,
  `swift test --filter ReportSchemaInventoryTests`.
- Confidence: medium

### MCA-013

- ID: MCA-013
- File: `Sources/OpenLolaCore/Core/ValidationPrimitives.swift`
- Symbol / function / class / module: `ValidationPrimitives`,
  validation issue/report/verdict helper types
- Suggested action: SIMPLIFY
- Current behavior: Validation behavior is modeled through shared primitive
  types and tests. Multiple validators use these primitives to produce
  structured issues and verdicts.
- Required behavior, if inferable: Validators should emit consistent verdicts,
  issue severities, messages, and machine-readable results.
- Complexity problem: The primitive lattice may be broader than the current
  validators need. If shared types mostly mirror one or two validators, they
  add indirection and make tests assert helper mechanics instead of validation
  outcomes.
- Minimal alternative: Keep shared primitives that have multiple real validator
  consumers. Inline or narrow helper types that only serve a single validator or
  duplicate report-schema fields.
- Risk of simplification: Medium. Validator output is a public contract and is
  used by release gates.
- Tests needed before simplification: Validation primitive tests plus validator
  tests for every consumer changed.
- Verification command or strategy: `swift test --filter ValidationPrimitivesTests`
  and the affected validator filters.
- Confidence: medium

### MCA-014

- ID: MCA-014
- File: `Sources/OpenLolaCore/Evidence/ReportValidatorSurface.swift`
- Symbol / function / class / module: `ReportMetadataArtifact`
- Suggested action: INLINE
- Current behavior: `ReportMetadataArtifact` is a metadata-bearing refinement
  adopted by a small set of report structs and asserted by
  `ReportSchemaInventoryTests`.
- Required behavior, if inferable: Report structs must expose stable metadata
  needed by schema inventory and release evidence.
- Complexity problem: If no runtime or generic code consumes the protocol, it
  is a marker abstraction used mostly by tests. That is not minimum code if the
  same contract can be tested directly on the concrete report types.
- Minimal alternative: Replace marker-protocol assertions with direct concrete
  metadata checks, unless a real generic report-metadata consumer exists.
- Risk of simplification: Low to medium. The risk is mostly test and schema
  inventory churn, not runtime behavior.
- Tests needed before simplification: Report schema inventory tests and all
  report metadata fixture tests.
- Verification command or strategy: `swift test --filter ReportSchemaInventoryTests`.
- Confidence: medium

### MCA-015

- ID: MCA-015
- File: `Sources/OpenLolaCore/Support/BoundedFileReader.swift`,
  `Sources/open-lola/main.swift`,
  `Sources/open-lola/Commands/Benchmarks/E2EBenchmarkCommands.swift`,
  `Sources/open-lola/Commands/Network/DirectP2PSessionRunCommandSupport.swift`
- Symbol / function / class / module: `BoundedFileReader`,
  `readValidatedReport` call sites
- Suggested action: INVESTIGATE
- Current behavior: `BoundedFileReader` centralizes bounded data/string/JSON
  reads and is used by CLI validation/report paths. A report-validation helper
  extension adds a more domain-specific read path.
- Required behavior, if inferable: CLI validation should read bounded files and
  decode reports without unbounded memory use.
- Complexity problem: The bounded file helper itself is justified. The
  domain-specific validation extension may be a single-use convenience if it
  only hides a decode call at one or two call sites.
- Minimal alternative: Keep the bounded file primitive. Inline any report-only
  extension that does not reduce duplication across current validators.
- Risk of simplification: Low to medium. Bounded input handling is security and
  stability relevant, so the core helper should remain.
- Tests needed before simplification: Bounded reader tests and affected CLI
  validator tests for max-size, missing-file, invalid JSON, and valid report
  paths.
- Verification command or strategy: `swift test --filter BoundedFileReaderTests`
  plus affected validator tests.
- Confidence: low

### MCA-016

- ID: MCA-016
- File: `Sources/OpenLolaCore/Network/Diagnostics/NetworkDiagnostics.swift`
- Symbol / function / class / module: `networkDiagnosticsVerdict`,
  `NetworkDiagnosticsReport`
- Suggested action: INVESTIGATE
- Current behavior: Network diagnostics can return `.pass` when ping and
  traceroute thresholds pass, while report notes state that diagnostics compare
  reachability only and do not prove audio latency or Internet LoLa readiness.
- Required behavior, if inferable: A network diagnostics report may pass its
  local diagnostic contract, but product readiness must remain `PARTIAL` unless
  audio/video/runtime evidence exists.
- Complexity problem: The code uses a shared verdict vocabulary for a limited
  diagnostic domain. That can force extra explanatory notes and downstream
  caution to prevent a local `PASS` from being read as a product pass.
- Minimal alternative: Before changing verdict semantics, inspect all consumers.
  If any consumer treats diagnostic `.pass` as release readiness, gate it there
  or use a domain-specific readiness field. If consumers already scope it
  correctly, keep the code and document the boundary in tests.
- Risk of simplification: Medium. Verdict vocabulary and JSON reports are
  public contracts.
- Tests needed before simplification: Network diagnostics verdict tests and any
  release/goal preflight tests that consume diagnostics.
- Verification command or strategy: `swift test --filter NetworkDiagnostics`,
  `swift test --filter GoalRuntimePreflight`.
- Confidence: medium

## Keep Unless New Evidence Appears

- `ManagedProcessRunner` by itself: keep. It solves a real app subprocess
  problem. The concern is duplication with other runners, not that this helper
  is inherently too large.
- `BoundedFileReader` core data/string/JSON reads: keep. Bounded file I/O is a
  stability and security guard. Only domain-specific convenience layers should
  be questioned.
- `KeyValueArgumentParser`: keep. Current evidence shows many real call sites;
  the minimum-code direction is to reuse it more consistently, not replace it.
- Explicit legacy migration for persisted app defaults: keep until active user
  defaults and tests prove it can be removed safely.

## Prioritized Remediation Table

| Priority | ID | Action | Area | Why first | Verification |
| --- | --- | --- | --- | --- | --- |
| 1 | MCA-001 | SIMPLIFY | App execution state | Highest false-status and teardown divergence risk in user-visible app runtime | `swift test --filter AppShell`; `swift test --filter NativeAppShell`; app build/run smoke |
| 2 | MCA-003 | INVESTIGATE | External connector wait status | Magic process sentinel can hide teardown state in compatibility reports | `swift test --filter ExternalConnector` |
| 3 | MCA-002 | DEDUPLICATE | Process runners | Duplicated timeout/capture/termination code affects runtime reliability | Managed runner, external connector, and network diagnostics tests |
| 4 | MCA-016 | INVESTIGATE | Network diagnostics verdict scope | Shared PASS vocabulary can be over-read if downstream gates are loose | `swift test --filter NetworkDiagnostics`; relevant preflight tests |
| 5 | MCA-004 | DEDUPLICATE | CLI parsers | Duplicate parse loops create inconsistent command validation | `swift test --filter KeyValueArgumentParser`; affected command tests |
| 6 | MCA-005 | DEDUPLICATE | Inventory/matrix family | Duplicate source-of-truth ledgers dominate tests and release gates | Inventory, fixture, source ownership, route matrix, release readiness checks |
| 7 | MCA-006 | SIMPLIFY | App settings persistence | Parallel field lists are easy to desynchronize and hide migration behavior | `swift test --filter AppShell`; `swift test --filter NativeAppShellOpusCommandTests` |
| 8 | MCA-008 | INVESTIGATE | Unsupported app modes | Planning-only modes increase UI state and can imply executable behavior | App shell and native shell mode tests |
| 9 | MCA-009 | REPLACE_DEPRECATED | `--audio-compression` legacy path | Deprecated naming remains in parser and storage migration | Direct peer Opus CLI and app migration tests |
| 10 | MCA-012 | INVESTIGATE | NMP workflow staging | Workflow surface may exceed current connector needs | NMP, CLI inventory, schema inventory tests |
| 11 | MCA-013 | SIMPLIFY | Validation primitives | Shared helper lattice may exceed current validator consumers | Validation primitive and affected validator tests |
| 12 | MCA-011 | SIMPLIFY | Deferred feature registry | Source registry may contain docs-level blocker data | Deferred feature, schema, release readiness tests |
| 13 | MCA-010 | DELETE | Audio routing ledger | Static governance data may not need to live in source | Source ownership and docs verification |
| 14 | MCA-014 | INLINE | Report metadata marker | Marker protocol may only support tests | Report schema inventory tests |
| 15 | MCA-007 | INLINE | Settings mutation policy | Single-use wrapper around disabled-state text | `swift test --filter AppShellSlice05Tests` |
| 16 | MCA-015 | INVESTIGATE | Report read convenience | Possible single-use layer over justified bounded I/O | Bounded reader and affected validator tests |

## Areas Not Fully Inspected

- Vendored/reference codec trees were intentionally not audited for
  simplification because changing them would be high risk and outside a
  minimum-code cleanup pass.
- Every command parser was not read line-by-line. The audit identifies a real
  parser-consistency pattern and names representative files; a remediation pass
  should inventory each command before editing.
- The macOS app was not run. UI/runtime findings are source-evidence findings
  and need app-level behavior tests before simplification.
- External connector process-group behavior was not exercised live. Findings in
  that area are deliberately `INVESTIGATE` where runtime semantics are unclear.

## Remaining Uncertainty

- Some inventory and workflow code may be intentionally retained because release
  gates require machine-readable source data. Simplification should start by
  proving which fields are actually consumed.
- Some deprecated paths may still be needed by local scripts or archived
  evidence reproduction. Remove them only after a current docs/test search shows
  no active dependency.
- A smaller implementation is not automatically safer in realtime or process
  lifecycle paths. For MCA-001 through MCA-003, tests must establish current
  behavior before any cleanup.
