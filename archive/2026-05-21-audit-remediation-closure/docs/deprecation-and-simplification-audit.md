# Deprecation And Simplification Audit

Date: 2026-05-20

Scope: dead-code, deprecated API, obsolete compatibility, duplication,
boilerplate, and overengineering candidates in the live checkout. This is an
audit only; no production code or tests were changed.

Verdict: no first-party source file is proven safe to delete from this pass.
Several areas are strong cleanup candidates, but most are active compatibility
or release-contract surfaces and need targeted verification before removal.

## Method

Evidence sources:

- `AGENTS.md`
- `docs/code-index.md`
- `docs/architecture-map.md`
- `docs/verification-baseline.md`
- `docs/source-contracts.md`
- `Package.swift`
- targeted reads in `Sources/`, `Tests/`, `linux_connector/`, and `scripts/`
- `rg`, `find`, `wc -l`, `ruff`, `mypy`, and `shellcheck`

Safe checks run during this audit:

- `env RUFF_CACHE_DIR=/private/tmp/open-lola2-das-audit-ruff-cache ruff check linux_connector scripts/verify_docs scripts/lib/*.py`: PASS
- `env MYPY_CACHE_DIR=/private/tmp/open-lola2-das-audit-mypy-cache python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py`: PASS
- `shellcheck -x scripts/*.sh scripts/lib/*.sh script/*.sh linux_connector/env/*.sh`: PASS

Swift build/test and runtime gates were not run for this docs-only audit. The
current verification baseline remains `PARTIAL`.

## Negative Findings

- No first-party source file is proven unused.
- No broad source deletion is recommended without runtime or git-history
  verification.
- The only first-party Swift deprecation annotation found in this pass is the
  `audioDeviceUID` compatibility accessor in
  `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraphTypes.swift`.
- Deprecated mentions inside vendored Opus and JPEG XS files are third-party
  collateral, not first-party API deprecations.

## Findings

### DSA-001

- Category: unused vendored files / boilerplate / release-excluded collateral
- Location: `Sources/xs_ref_sw_ed2/programs/`, `Sources/xs_ref_sw_ed2/extras/`,
  `Sources/xs_ref_sw_ed2/std/`, the root and `libjxs` CMake build files, and
  the excluded `msbpack.c` source file.
- Evidence: `Package.swift` builds `CJpegXSReference` from
  `Sources/xs_ref_sw_ed2/libjxs` and explicitly excludes `CMakeLists.txt` and
  `src/msbpack.c`. The release exporter and release hygiene policy remove or
  reject the programs, extras, std shim, CMake files, and excluded source. The
  code index marks `Sources/xs_ref_sw_ed2/programs/` as `UNCLEAR`, likely
  vendor collateral, not a SwiftPM product.
- Why it is likely obsolete or harmful: these files increase raw checkout size
  and audit surface while the product build and release candidate deliberately
  exclude them.
- What could break if changed: upstream-reference reproducibility, license or
  notice obligations, manual JPEG XS debugging, or future vendor updates.
- Suggested action: investigate; delete or move to a vendor-source archive only
  if git history, license review, and script/doc search prove they are not
  required. This needs runtime or git-history verification.
- Risk level: medium.
- Verification needed: `swift build`, JPEG XS bridge tests, release-candidate
  export plus hygiene, docs verifier, license/notice review, and `rg` proving no
  active script, test, or doc invokes the reference programs.

### DSA-002

- Category: unused vendored files / boilerplate / generated-or-upstream
  collateral
- Location: uncompiled collateral under `Sources/opus-1.5.2/`, including test,
  DNN/training, build-system, CI, and package metadata files outside the
  `COpus` source whitelist
- Evidence: `Package.swift` lists the exact C source files compiled into the
  `COpus` target. The release exporter and hygiene policy remove or reject
  Opus `.github`, tests, DNN, training, cmake, m4, meson, autogen, configure,
  Makefile, pkg-config, and source-list collateral. Release hygiene tests assert
  these paths are absent from staged candidates.
- Why it is likely obsolete or harmful: the raw checkout carries many files that
  are not built, tested, or released, so they expand security and review scope.
- What could break if changed: upstream Opus update workflow, license notices,
  local codec debugging, or build assumptions hidden in vendor headers.
- Suggested action: investigate; keep until a vendor-prune policy proves which
  files are needed for license, update, and bridge maintenance. This needs
  runtime or git-history verification.
- Risk level: medium.
- Verification needed: `swift build --product open-lola`, Opus codec tests,
  release export/hygiene, third-party notice review, and a source-membership
  diff between `Package.swift` and the vendored tree.

### DSA-003

- Category: deprecated internal API / obsolete compatibility branch
- Location: `DirectPeerSessionAudioCompression` and hidden
  `--audio-compression` handling in
  `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVRunTypes.swift`,
  `Sources/open-lola/Commands/Network/DirectP2PSessionRunCommandSupport.swift`,
  `Sources/open-lola/Commands/Network/DirectP2PSessionRunArgumentSupport.swift`,
  `Sources/OpenLolaCore/Platform/NativeAppShellDirectPeerCommand.swift`,
  `Sources/OpenLolaCore/Network/P2P/DirectPeerTwoPeerRunPlan.swift`, and
  `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVRuntimeReport.swift`
- Evidence: `docs/source-contracts.md` says `audioTransport` is canonical and
  legacy `audioCompression` / `--audio-compression` is hidden compatibility.
  The public argument set hides `--audio-compression`, while tests assert help
  omits it and invalid legacy values still fail deterministically. Runtime
  reports still decode and sometimes encode the legacy field.
- Why it is likely obsolete or harmful: one audio concept is modeled twice,
  increasing parser, report, app-default, and migration complexity. The legacy
  enum cannot represent newer transports such as AES67/ST2110 L24.
- What could break if changed: old CLI invocations, stored app defaults, JSON
  report decoding, fixtures, two-peer plans, and external scripts using the
  hidden flag.
- Suggested action: investigate, then replace with a single `audioTransport`
  contract and explicit migration/breaking-change coverage. Do not delete until
  active fixtures, stored defaults, reports, scripts, and git history are
  checked.
- Recheck note 2026-05-21: git history and focused tests still show this as an
  active compatibility surface. `git log -S audioCompression` found recent
  checkpoint history, and `DirectPeerAudioCompatibilityContractTests` plus
  `DirectPeerSessionOpusCLITests` still protect legacy decode and hidden CLI
  behavior. Do not delete without a separate migration decision.
- Risk level: high.
- Verification needed: targeted Direct P2P CLI/report/app tests, fixture decode
  tests, stored-defaults migration tests, `rg -- --audio-compression`, git
  history search, and broader Direct P2P verification.

### DSA-004

- Category: deprecated internal API / compatibility shim
- Location: legacy `audioDeviceUID` alongside canonical `inputDeviceUID` and
  `outputDeviceUID` in Direct P2P and realtime audio configuration/report types
- Evidence: `docs/source-contracts.md` says split device UIDs are canonical and
  the single `audioDeviceUID` is retained only as a compatibility bridge.
  `DirectPeerRealtimeAudioGraphConfiguration.audioDeviceUID` is explicitly
  annotated deprecated. Direct P2P configuration, reports, socket runner, tests,
  and CLI parsing still carry both single and split UIDs.
- Why it is likely obsolete or harmful: single-device naming is misleading for
  separate capture/playback devices and encourages old full-duplex assumptions.
- What could break if changed: decoded legacy graph configs, report fixtures,
  callers that pass only one device UID, app command generation, and tests that
  still assert compatibility behavior.
- Suggested action: investigate; remove the single-device API only after a
  migration is explicit and all active callers use split UIDs. This needs
  runtime or git-history verification.
- Recheck note 2026-05-21: git history and focused tests still show this as an
  active compatibility surface. `git log -S audioDeviceUID` found recent
  checkpoint history, `DirectPeerAudioCompatibilityContractTests` still protect
  report and initializer compatibility, `DirectPeerSessionCLITests` still
  protect hidden CLI migration behavior, and `DirectPeerRealtimeAudioGraphTests`
  still protect split-UID realtime configuration. Do not delete without a
  separate migration decision.
- Risk level: high.
- Verification needed: realtime graph tests, Direct P2P AV tests, app shell
  command tests, report fixture validation, manual Core Audio split-device smoke
  when runtime behavior is touched.

### DSA-005

- Category: misleading name / old behavior path retained as public contract
- Location: `DirectPeerTwoPeerPrototypeReport`,
  `direct-p2p-two-peer-report`, `validate-direct-p2p-two-peer-report`,
  `direct-p2p-two-peer-prototype-report`, and
  `validate-direct-p2p-two-peer-prototype-report`
- Evidence: `direct-p2p-two-peer-report` and
  `validate-direct-p2p-two-peer-report` are now the canonical CLI aliases for
  the active aggregate report. `docs/source-contracts.md` still says the
  prototype-named report and CLI command are compatibility contracts despite
  the name. Both commands are present in
  `Sources/open-lola/Commands/Network/NetworkCommands.swift`, the report type
  and builder are active in
  `Sources/OpenLolaCore/Network/P2P/DirectPeerTwoPeerRunPlanReportTypes.swift`,
  and source-naming tests require both canonical and compatibility commands in
  the schema inventory entry.
- Why it is likely obsolete or harmful: "prototype" undercuts the measured
  contract and keeps old milestone wording in active CLI/report names. The
  remaining prototype type and report ID are now compatibility surfaces rather
  than the preferred CLI.
- What could break if changed: public CLI names, validator commands, schema
  inventory, fixtures, app-generated run plans, tests, and existing reports.
- Suggested action: keep; the CLI now has promoted non-prototype aliases while
  old names remain available. Investigate a later report-schema/type migration
  only with explicit fixture compatibility coverage and a documented breaking or
  deprecation path.
- Risk level: high.
- Verification needed: CLI inventory tests, source naming tests, report schema
  tests, two-peer run plan tests, validator round-trip tests, and fixture
  migration coverage before any future schema/type rename.

### DSA-006

- Category: endless switch chains / duplication / mixed responsibilities
- Location: `Sources/open-lola/Commands/Network/NetworkCommands.swift`,
  `Sources/open-lola/Commands/MilestoneCommands.swift`, and
  `Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift`
- Evidence: current line counts are 441, 556, and 320 respectively.
  `MilestoneValidationCommands.swift` now has no `switch arguments` or
  `case let args where` branches after POST-DSA-006-B moved custom-output
  validators into the same table as simple validators. `NetworkCommands.swift`
  still has a table for simple validators plus explicit branches for packet,
  session-pair, evidence-bundle, local-run, help, and runner commands.
  POST-DSA-006-C moved the repeated milestone runtime `validate` plus JSON
  output-write sequence into a local `writeValidatedReport` helper while
  preserving branch-visible command dispatch. POST-DSA-006-D moved the repeated
  `validate` plus stdout pretty-JSON plus `VERDICT:` sequence into a local
  `printValidatedJSONReport` helper while keeping special summary lines and
  command branches explicit. POST-DSA-006-F rechecked the remaining
  `MilestoneCommands.swift` custom paths and found no safe additional
  deletion-only cleanup: `latency-profile-synthetic-smoke` still has
  mode-specific validation, `madi-tx-synthetic-smoke` still uses a report type
  that does not conform to `ReportValidatingArtifact`, `native-app-shell-
  surface-probe` validates a source report before building the probe report,
  `external-connector-synthetic-smoke` prints source and real-world verdict
  lines, and `external-connector-nmp-workflow-run` writes child reports plus
  the parent report. `MilestoneCommands.swift` remains a broad runtime command
  fanout.
- Why it is likely obsolete or harmful: routing, help, inventory, validators,
  and tests can drift. Adding a command requires edits in multiple places and
  increases false-success risk for command discovery.
- What could break if changed: CLI command names, output text, help behavior,
  validator dispatch, command inventory, and machine-readable surface tests.
- Suggested action: simplify incrementally. Validator dispatch is now table
  backed; runtime dispatch should only be reduced through bounded, behavior-
  preserving slices that keep command names and inventory coverage explicit. Do
  not perform a broad rewrite without a written plan.
- Risk level: high.
- Verification needed: command inventory tests, machine-readable surface tests,
  report schema tests, command-specific tests, and manual spot checks for
  public CLI output.
- Remediation note: RFP-014 moved simple milestone report validators into a
  table. POST-DSA-006-A then moved simple no-extra-output network report
  validators into `simpleNetworkReportValidators` and updated the route-matrix
  source scanner to recognize table-backed validators. Custom validators,
  runner commands, packet validators, and multi-file validators intentionally
  remained explicit. POST-DSA-006-B then moved the remaining custom-output
  milestone validators into `milestoneReportValidators`, leaving
  `handleMilestoneValidationCommand` as a two-argument table lookup with no
  validation switch chain. POST-DSA-006-C then deduplicated the repeated
  milestone runtime report `validate` plus JSON write operation with a local
  helper and verified the command surface plus full Swift suite. POST-DSA-006-D
  then deduplicated the repeated stdout JSON/verdict output path and spot-
  checked representative executable commands. POST-DSA-006-E folded the
  remaining `latency-profile-synthetic-smoke` custom validate plus stdout JSON
  plus verdict sequence into the existing helper without changing the branch or
  output contract. POST-DSA-006-F rechecked the remaining runtime custom paths
  and retained them as behavior-specific paths rather than introducing a
  single-use helper or broad table rewrite. Runtime command branch dispatch and
  special network validators remain explicit.

### DSA-007

- Category: boilerplate / duplicate source-of-truth tables
- Location: `Sources/OpenLolaCore/Support/Inventories/CLICommandInventory.swift`,
  `Sources/OpenLolaCore/Evidence/ReportSchemaInventory.swift`,
  `Sources/OpenLolaCore/Support/Inventories/SourceOwnershipInventory.swift`,
  and `Sources/OpenLolaCore/Support/Inventories/FixtureSmokeMatrixData.swift`
- Evidence: these files contain hard-coded command, schema, source path, test
  path, fixture, and verification metadata. They are active: CLI commands print
  inventory reports, and tests compare command/schema/source ownership surfaces
  against these tables.
- Why it is likely obsolete or harmful: manual inventories duplicate source
  truth and can drift as files and commands move.
- What could break if changed: machine-readable JSON reports, public inventory
  commands, report schema tests, source ownership tests, docs, and release
  policy tests.
- Suggested action: keep for now, but audit whether any entries can be
  generated from command/schema registries. Do not introduce a generator unless
  it replaces at least two real duplicate tables now.
- Risk level: medium.
- Verification needed: `swift test --filter CLICommandInventoryTests`,
  `swift test --filter ReportSchemaInventoryTests`,
  `swift test --filter SourceOwnershipInventoryTests`,
  machine-readable surface tests, and docs verifier.
- Status: POST-DSA-007-A rechecked the active inventory and surface contracts
  on 2026-05-21 with the CLI command, report schema, source ownership, and
  machine-readable surface tests. Keep these tables as active public contract
  metadata until a written generator slice can replace at least two duplicate
  tables with behavior-preserving verification.

### DSA-008

- Category: mixed responsibilities / overcomplicated file
- Location: `Sources/open-lola-app/AppExecutionController.swift`,
  `Sources/open-lola-app/AppExecutionCommandPreview.swift`,
  `Sources/open-lola-app/AppExecutionPreparation.swift`, and
  `Sources/open-lola-app/AppExecutionEvidenceSupport.swift`
- Evidence: `AppExecutionController.swift` is 712 lines and is now below the
  base line budget, so its no-growth exception was removed from
  `scripts/code-line-budget-exceptions.txt`. It still owns process lifecycle,
  external connector report state, session-token evidence, error logs, and
  runtime-evidence decisions. Command preview and validator-command generation
  live in the 44-line `Sources/open-lola-app/AppExecutionCommandPreview.swift`
  extension. Shared plan-write and app execution-preparation helpers live in
  the 37-line `Sources/open-lola-app/AppExecutionPreparation.swift` extension.
  Shared execution phase/readiness/invalidation definitions live in the 83-line
  `Sources/open-lola-app/AppExecutionState.swift` file, and default log paths,
  log snapshots, previous-run evidence, log opening, report loading, and report
  assembly helpers live in the 191-line
  `Sources/open-lola-app/AppExecutionEvidenceSupport.swift` file.
- Why it is likely obsolete or harmful: process state, report validation, UI
  status text, and evidence gating are coupled in one controller, making it hard
  to prove status truthfulness.
- What could break if changed: app start/stop, validation, status labels,
  runtime evidence, saved log paths, and menu/button state.
- Suggested action: simplify in small slices only. Unsupported connector
  execution-preparation and validation-readiness duplication has already been
  reduced; future work should target one proven behavior area at a time and
  extract only behavior with multiple current call sites.
- Remediation note 2026-05-21: POST-DSA-010-B moved the repeated
  execution-preparation switch from `OpenLolaApp`, `AppTransportView`, and
  `AppShellRootView` into `AppExecutionController.prepareExecution(from:)`.
  The controller now owns the single decision that Direct Mac peer writes a
  plan, Windows LoLa can proceed directly, and planning-only JackTrip/UltraGrid
  cannot prepare app execution.
- Remediation note 2026-05-21: POST-DSA-008-A removed unused internal
  `supervisorCommand(executablePath:)` and single-report
  `validatorCommand(executablePath:)` helpers after `rg` found no source or
  test call sites. The app keeps the operator-surface command builders used by
  current UI and tests.
- Remediation note 2026-05-21: POST-DSA-008-B moved shared execution
  phase/kind, validation result/readiness, and runtime-evidence invalidation
  policy definitions into `AppExecutionState.swift`. The controller still owns
  lifecycle, report loading, and runtime evidence handling, so deeper splits
  remain future behavior-preserving slices.
- Remediation note 2026-05-21: POST-DSA-008-C moved the already separate log
  snapshot, previous-run evidence snapshot, log file opener, report loader, and
  report assembler helper types into `AppExecutionEvidenceSupport.swift`. The
  controller still owns process lifecycle and runtime-evidence decisions, so
  future splits should target lifecycle behavior with focused tests rather than
  moving helper code for its own sake.
- Remediation note 2026-05-21: POST-DSA-008-D moved command-preview generation
  into `AppExecutionCommandPreview.swift`, moved plan-write handling beside the
  shared execution-preparation route, moved default log URL generation into the
  evidence support file, and removed the `AppExecutionController.swift` line-
  budget exception after the file dropped below the base budget. The remaining
  controller risk is lifecycle/runtime-evidence behavior, not file size.
- Remediation note 2026-05-21: POST-APP-VERIFY-C made the strict native app
  launch verifier activate the staged app before System Events capture and
  report frontmost state before and after activation. Focused script policy
  tests and ShellCheck pass, but the real verifier still fails on this host
  with `frontmostBeforeActivation=false`, `frontmostAfterActivation=false`, and
  `accessibilityWindows=0` while CoreGraphics sees the app window. Treat the
  AX label gate as still blocked, not closed.
- Recheck note 2026-05-21: POST-APP-VERIFY-D reran the strict verifier outside
  the sandbox after the app menu cleanup. The current bundle still fails with
  the same AX blocker: CoreGraphics sees an `Open LoLa` window, but System
  Events reports `frontmostBeforeActivation=false`,
  `frontmostAfterActivation=false`, and `accessibilityWindows=0`.
- Recheck note 2026-05-21: POST-APP-VERIFY-E reran the strict verifier outside
  the sandbox after the app execution state/readiness split. The rebuilt bundle
  still fails on the same host gate: System Events reports no accessibility
  windows, while CoreGraphics captures a visible `Open LoLa` window.
- Recheck note 2026-05-21: POST-APP-VERIFY-F reran the strict verifier outside
  the sandbox. The current bundle now exits 0 and captures non-empty
  accessibility UI, window-list, and screenshot evidence. Treat the launch
  AX/window gate as locally closed; remaining app-shell audit risk is manual
  operator behavior and lifecycle/report evidence truthfulness.
- Risk level: high.
- Verification needed: focused app-shell tests, native app bundle verification,
  runtime report validation tests, and manual UI smoke for visible state.

### DSA-009

- Category: mixed responsibilities / UI state duplication
- Location: `Sources/open-lola-app/AppShellRootView.swift`,
  `Sources/open-lola-app/AppShellSectionViews.swift`,
  `Sources/open-lola-app/AppConsoleModels.swift`,
  `Sources/open-lola-app/AppSettings.swift`, and
  `Sources/open-lola-app/AppSettingsDraft.swift`
- Evidence: line counts are 512, 689, 582, 245, and 587 after the app-root,
  console, and settings-draft splits. The original baseline recorded
  line-budget failures for the app root, console model, and settings file.
  These files contain derived UI state, settings normalization, status copy,
  validation details, and session-mode branching.
- Why it is likely obsolete or harmful: view, settings, and console policy can
  drift from each other, especially around `PARTIAL`, unsupported modes, and
  validation readiness.
- What could break if changed: visible app state, settings persistence,
  workflow arming, validation calls, report path handling, and user-facing copy.
- Suggested action: simplify only with behavior-preserving slices. Prefer
  deleting duplicated branches or moving existing logic to a single current
  owner over adding new UI abstractions.
- Remediation note 2026-05-21: POST-DSA-009-A replaced duplicate validation
  readiness helpers in `AppOverviewOperatorSummary` and
  `AppValidationPreflightModel` with one file-local helper that delegates to
  the existing app execution route owner.
- Remediation note 2026-05-21: POST-DSA-009-B moved validation rows,
  validation preflight state, blockers, and advanced-control recovery copy into
  `AppValidationConsoleModels.swift`. `AppConsoleModels.swift` dropped below
  the base line budget and its line-budget exception was removed.
- Remediation note 2026-05-21: POST-DSA-009-C moved settings draft commit,
  conflict, runtime-change detection, and fingerprinting behavior into
  `AppSettingsDraft.swift`. `AppSettings.swift` dropped below the base line
  budget and its line-budget exception was removed.
- Remediation note 2026-05-21: POST-DSA-009-D moved the section router and
  overview/session/streams/routing/devices/diagnostics/validation/settings
  section views into `AppShellSectionViews.swift`. `AppShellRootView.swift`
  dropped below the base line budget and its line-budget exception was removed.
- Remediation note 2026-05-21: POST-DSA-009-E fixed validation preflight
  truthfulness so a validator exit code 0 with missing, stale, or partial
  runtime evidence stays `Evidence incomplete` instead of collapsing into a
  generic last-validation-failed blocker.
- Risk level: high.
- Verification needed: app-shell behavior tests, screenshot/manual UI checks,
  app bundle launch verification, and docs verifier for any public wording.

### DSA-010

- Category: stale feature flag / duplicate compatibility branch
- Location: repeated `.jackTrip` and `.ultraGrid` app-runtime branches in
  `Sources/OpenLolaCore/Platform/NativeAppShellSessionMode.swift`,
  `Sources/open-lola-app/OpenLolaApp.swift`,
  `Sources/open-lola-app/AppShellRootView.swift`,
  `Sources/open-lola-app/AppTransportView.swift`,
  `Sources/open-lola-app/AppExecutionController.swift`, and
  `Sources/open-lola-app/AppConsoleModels.swift`
- Evidence: `NativeAppShellSessionMode.supportsAppExecution` returns false for
  JackTrip and UltraGrid, while several app views duplicate `case .jackTrip,
  .ultraGrid: return false` or `.unsupported(...)`. Tests assert these modes are
  selectable for planning but not wired for app execution.
- Why it is likely obsolete or harmful: the modes are visible in the app but
  cannot launch from the app, so duplicated unsupported branches create
  maintenance cost and a risk of misleading UI state.
- What could break if changed: operator planning UI, settings visibility,
  menu state, external connector guidance, and tests that enforce CLI-only
  status.
- Suggested action: keep the planning-only contract. The known unsupported
  execution-preparation and settings-visibility branches are now centralized;
  continue only if a new duplicated unsupported branch is proven by source and
  tests. Do not expose app launch until runtime evidence exists.
- Remediation note 2026-05-21: POST-DSA-010-B centralized the remaining
  app-level execution-preparation branch used by menu actions, the transport
  strip, and the session banner. JackTrip and UltraGrid remain selectable for
  planning and still return `false` for app execution preparation.
- Remediation note 2026-05-21: POST-DSA-010-C moved settings visibility onto
  `NativeAppShellAppExecutionRoute`, so unsupported JackTrip and UltraGrid
  modes return the external connector notice directly instead of flowing
  through an unreachable advanced-settings branch.
- Risk level: medium.
- Verification needed: app-shell tests for session modes, manual UI smoke, and
  external connector CLI tests proving the CLI path remains intact.

### DSA-011

- Category: single-use abstractions / boilerplate
- Location: remaining app menu/action policy helpers such as
  `AppMenuActionHandling` in `Sources/open-lola-app/OpenLolaApp.swift`;
  formerly included `AppQuitGuardPolicy`.
- Evidence: `AppQuitGuardPolicy` previously had one production call and direct
  unit tests; it has now been removed. `AppMenuActionHandling` is used by the
  menu renderer and tests that compare handled IDs to the surface contract. The
  remaining helper is a small wrapper around a literal set.
- Resolution note 2026-05-20: `AppQuitGuardPolicy` was removed and its single
  predicate was inlined into the application termination guard. The test now
  targets `OpenLolaApplicationDelegate` termination behavior instead of the
  deleted wrapper. `AppMenuActionHandling` remains because it is still the
  explicit contract check between menu-rendered actions and
  `NativeAppShellSurfaceContract`.
- Recheck 2026-05-21: before POST-DSA-011-B, `OpenLolaApp` still used
  `AppMenuActionHandling.isHandled` to route unsupported menu actions, while
  `AppShellSlice05Tests.appMenuActionHandlingCoversEveryContractAction`
  compared the handled IDs to `NativeAppShellSurfaceContract.releaseReadiness`.
  Deleting the whole helper without replacement would have removed the current
  explicit contract check.
- Remediation note 2026-05-21: POST-DSA-011-B removed the single-use
  `AppMenuActionHandling.isHandled` wrapper. `OpenLolaApp` now checks
  `handledActionIDs.contains(action.id)` directly, while
  `AppShellSlice05Tests.appMenuActionHandlingCoversEveryContractAction` still
  proves the handled action ID set matches
  `NativeAppShellSurfaceContract.releaseReadiness`.
- Why it is likely obsolete or harmful: wrappers can make simple UI policy look
  more general than it is and add test surface around implementation trivia.
- What could break if changed: menu handling, quit confirmation, action
  inventory contract tests, and accessibility/menu probe expectations.
- Suggested action: keep the remaining menu-action ID set as the explicit
  contract anchor unless a future slice replaces it with direct behavior
  coverage that still proves every release-readiness menu action is handled.
- Risk level: low.
- Verification needed: app-shell behavior tests, app surface contract tests,
  native app launch probe, and review that tests still verify behavior rather
  than private helper calls.

### DSA-012

- Category: overcomplicated tests / duplicate literal coverage
- Location: `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift` and
  `Tests/OpenLolaCoreTests/AppShellSlice05Tests.swift`
- Evidence: original line counts were 2,442 and 974. Remediation split
  packet-monitor tests into `AppShellPacketMonitorTests.swift`, split
  transport/menu policy tests into
  `AppShellTransportMenuPolicyTests.swift`, split general UI policy tests into
  `AppShellUIPolicyTests.swift`, and split execution-controller lifecycle/log
  snapshot tests into `AppShellExecutionControllerTests.swift`, then split
  settings/executable-input assertions into
  `AppShellSettingsExecutionInputTests.swift`, then split runtime evidence and
  session-token assertions into `AppShellRuntimeEvidenceTests.swift`, then
  split validation report graph assertions into
  `AppShellValidationEvidenceGraphTests.swift`. Shared app-shell fixtures now
  live in `AppShellTestSupport.swift` so future behavior-area splits do not
  duplicate report and operator-state builders. POST-DSA-012-J split
  operational copy/accessibility/pasteboard assertions into
  `AppShellOperationalCopyTests.swift` and workflow-mode visibility assertions
  into `AppShellWorkflowModePolicyTests.swift`. Current line counts are 704,
  713, 165, 258, 217, 355, 114, 87, 253, 419, 132, and 70 respectively. Tests
  still assert many UI-policy literals, disabled reasons, and helper predicates
  directly.
- Resolution note 2026-05-20: the transport/menu policy assertions were moved
  into `Tests/OpenLolaCoreTests/AppShellTransportMenuPolicyTests.swift`, and
  general UI policy assertions were moved into
  `Tests/OpenLolaCoreTests/AppShellUIPolicyTests.swift`. Shared app-shell test
  builders were moved into `Tests/OpenLolaCoreTests/AppShellTestSupport.swift`.
  POST-DSA-012-D moved execution-controller lifecycle/log snapshot assertions
  into `Tests/OpenLolaCoreTests/AppShellExecutionControllerTests.swift`.
  POST-DSA-012-E moved settings/executable-input assertions into
  `Tests/OpenLolaCoreTests/AppShellSettingsExecutionInputTests.swift`.
  POST-DSA-012-F moved runtime evidence/session-token assertions into
  `Tests/OpenLolaCoreTests/AppShellRuntimeEvidenceTests.swift`.
  POST-DSA-012-G moved validation report graph assertions into
  `Tests/OpenLolaCoreTests/AppShellValidationEvidenceGraphTests.swift`. The
  line-budget exception for `AppShellSlice05Tests.swift` was lowered to its new
  current count. POST-DSA-012-I moved the sidebar session-indicator policy test
  into `Tests/OpenLolaCoreTests/AppShellUIPolicyTests.swift`, bringing
  `AppShellBehaviorTests.swift` below the base line budget and removing its
  exception row. POST-DSA-012-J moved operational copy/accessibility/pasteboard
  assertions into `Tests/OpenLolaCoreTests/AppShellOperationalCopyTests.swift`
  and workflow-mode visibility assertions into
  `Tests/OpenLolaCoreTests/AppShellWorkflowModePolicyTests.swift`, bringing
  `AppShellSlice05Tests.swift` below the base line budget and removing its
  exception row.
- Why it is likely obsolete or harmful: very large literal-heavy test files can
  make small UI wording or policy changes expensive and can reward preserving
  helper shape instead of behavior.
- What could break if changed: app-shell behavior coverage, false-success
  prevention, menu/action contract checks, and validation-readiness regression
  tests.
- Suggested action: deduplicate fixtures and split by behavior area. Do not
  delete tests unless an equivalent behavior-level test remains.
- Risk level: medium.
- Verification needed: focused app-shell tests, full Swift app-shell filter,
  line-budget test, and a review that each retained test fails for meaningful
  user-visible behavior.

### DSA-013

- Category: endless flag matrix / mixed responsibilities
- Location: `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSession.swift`
  and
  `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSessionConfigurationParsing.swift`
- Evidence: `ExternalConnectorSession.swift` was 780 lines and mixed the
  shared connector report/session model with `ExternalConnectorSessionConfiguration.parse`.
  POST-DSA-013-A split parsing into the focused
  `ExternalConnectorSessionConfigurationParsing.swift`, reducing the session
  file to 642 lines. POST-DSA-013-B kept the parser focused and added
  connector-scoped rejection for UltraGrid-only and JackTrip-only CLI flags.
  POST-DSA-013-C kept the parser focused at 205 lines and rejected LoLa
  raw-link-only CLI flags for non-LoLa connectors before launch-plan validation.
  POST-DSA-013-D kept the parser focused at 219 lines and rejects ignored LoLa
  video control flags for UltraGrid/JackTrip plus `--lola-video-payload` for
  JackTrip. UltraGrid still accepts `--lola-video-payload avfoundation-raw8`
  because `UltraGridMediaProvider` uses it to select AVFoundation raw video
  payload capture. The parser still contains a shared allowed-flag set for
  LoLa, UltraGrid, JackTrip, media, raw-link, topology, FEC, encryption,
  control, and plugin settings.
- Resolution note 2026-05-20: POST-DSA-013-A moved the session CLI parser out
  of the report/session hub and fixed the existing
  `ultraGridControlCommands` array contract so repeated
  `--ultragrid-control-command` flags are preserved in parse order while scalar
  duplicate arguments still fail closed. The old line-budget exception for
  `ExternalConnectorSession.swift` was removed after `CodeLineBudgetTests`
  passed.
- Resolution note 2026-05-21: POST-DSA-013-B added a regression test and parser
  guard so `mvtp-ultragrid` rejects JackTrip-only flags, while JackTrip and LoLa
  reject UltraGrid-only flags before connector defaults can silently ignore
  them. Shared media/full-duplex and LoLa video payload flags were not narrowed
  because current UltraGrid/JackTrip code still references them.
- Resolution note 2026-05-21: POST-DSA-013-C added parser-level rejection for
  `--raw-link-interface`, `--source-mac`, and `--destination-mac` when the CLI
  connector is UltraGrid or JackTrip. The lower-level launch-plan guard remains
  for programmatic configurations, but CLI input now fails before unsupported
  raw-link options can be carried into non-LoLa session configuration.
- Resolution note 2026-05-21: POST-DSA-013-D added parser-level rejection for
  `--video-compression` and `--video-bayer` outside LoLa, and for
  `--lola-video-payload` on JackTrip. Focused tests preserve UltraGrid's active
  `--lola-video-payload avfoundation-raw8` path and prove the ignored flags now
  fail before defaults can silently discard them.
- Recheck note 2026-05-21: POST-DSA-013-E searched the remaining shared
  external connector parser flags against LoLa, UltraGrid, JackTrip, and test
  call sites. The currently shared media, port, capture/playback,
  `--lola-video-payload`, topology, FEC, encryption, control, and JackTrip
  settings have active connector-specific consumers or focused tests. No new
  ignored connector-scoped CLI flag was proven safe to delete in this pass.
- Why it is likely obsolete or harmful: a single parser owns multiple connector
  dialects, making connector-specific validation and defaults hard to audit.
- What could break if changed: external connector session CLI, report schemas,
  dry-run behavior, native LoLa/UltraGrid/JackTrip modes, NMP endpoint runs, and
  pass-evidence gates.
- Suggested action: simplify only after connector-specific tests identify
  stable seams. Prefer deleting unsupported flag paths over adding generic
  parser layers.
- Risk level: high.
- Verification needed: `swift test --filter ExternalConnectorSessionTests`,
  `swift test --filter ExternalConnectorAvMatrixTests`, connector-specific
  LoLa/UltraGrid/JackTrip tests, NMP endpoint tests, and reference-peer gates
  when runtime behavior changes.

### DSA-014

- Category: overengineering candidate / active compatibility workflow
- Location: `Sources/OpenLolaCore/Connectors/NMP/`
- Evidence: four main NMP files total 1,050 lines and have dedicated plan,
  preflight, endpoint-run, and workflow tests. `docs/source-contracts.md` says
  NMP is an active verification surface and should be kept while CLI, schema
  inventory, scripts, and tests reference it.
- Resolution note 2026-05-20: POST-DSA-014-A confirmed active source, CLI,
  schema, docs, and test usage. NMP reports are routed by
  `Sources/open-lola/Commands/MilestoneCommands.swift`, validators are routed by
  `Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift`,
  schemas are listed in `Sources/OpenLolaCore/Evidence/ReportSchemaInventory.swift`,
  and `docs/source-contracts.md` explicitly keeps NMP while those surfaces
  reference it. `swift test --filter ExternalConnectorNmp --no-parallel`,
  `ReportSchemaInventoryTests`, `CLICommandInventoryTests`, and
  `NetworkRouteCommandMatrixTests` passed. Do not delete or merge NMP from this
  audit; only revisit if runtime or git-history evidence proves the workflow is
  no longer used.
- Why it is likely obsolete or harmful: the layer orchestrates other connector
  contracts and may be heavier than current runtime evidence supports.
- What could break if changed: NMP plan/preflight/workflow commands, endpoint
  run reports, schema inventory, external connector fixture expectations, and
  comparison workflows.
- Suggested action: keep for now. Investigate whether NMP is still required by
  active users or CI before deleting or merging it into connector commands. This
  needs runtime or git-history verification.
- Risk level: high.
- Verification needed: all NMP tests, external connector session tests,
  command/schema inventory tests, docs/source contract review, and git-history
  evidence of actual workflow use.

### DSA-015

- Category: boilerplate / mixed responsibilities / hardcoded policy
- Location: `scripts/verify_docs/constants.py` and
  `scripts/verify_docs/markdown_checks.py`
- Evidence: line counts are 436 and 463. The constants module hardcodes active
  docs, archive topology, public planning tokens, forbidden tokens, release
  tokens, and Windows corpus paths. The markdown checks module owns link checks,
  source path checks, required topics, ASCII checks, archive checks, public
  planning checks, release-hardening checks, TODO checks, and SOTA checks.
- Resolution note 2026-05-20: POST-DSA-015-A removed the empty active
  public-milestone doc list and its unreachable heading contract from the docs
  verifier because `check_milestone_contract` already forbids active
  `docs/milestones`. `rg` found no remaining code or test references to
  `PUBLIC_MILESTONE_DOCS`, `PUBLIC_MILESTONE_HEADINGS`, or the removed
  diagnostic text. POST-DSA-015-B removed the duplicate `SOTA_MATRIX` constant
  after proving it pointed at the same active `docs/open-questions.md` file as
  `OPEN_QUESTIONS`; the SOTA check still reports the folded-open-questions
  diagnostic and reads the active file once. POST-DSA-015-C removed the
  remaining impossible duplicate `Q001` through `Q010` branch after proving it
  checked the same `OPEN_QUESTIONS` text a second time. POST-DSA-015-D removed
  the single-use `PUBLIC_CURRENT_STATE_DOCS` and `WINDOWS_CORPUS` constants
  after `rg` and AST proof showed no imports or references outside the local
  derived values. POST-DSA-015-E inlined the internal
  `ARCHIVED_DOC_IGNORE_PATHS` manifest section because `rg` over the live
  verifier and tests showed no references; `DOC_IGNORE_PREFIXES` still reads
  the same `doc-ignore-prefix` section directly.
- Why it is likely obsolete or harmful: docs policy is spread across long
  hardcoded Python files, making public-doc failures hard to reason about and
  easy to accidentally broaden.
- What could break if changed: docs verifier, release candidate export,
  forbidden-token policy, archive policy, public current-state docs, and CI.
- Suggested action: simplify by deleting obsolete constants after each is proven
  unused. Avoid new abstraction unless it replaces duplicated policy across
  multiple current checks.
- Risk level: medium.
- Verification needed: `bash scripts/verify-docs.sh`, Python `ruff` and `mypy`,
  release hygiene/export tests, and path-specific fixtures for any verifier
  rule changed.

### DSA-016

- Category: duplicated shell orchestration / compatibility helper sprawl
- Location: UltraGrid and JackTrip parity/reference scripts under `scripts/`
- Evidence: local parity and RX/TX scripts total roughly 1,479 lines across the
  sampled Docker/native/client wrappers plus `scripts/lib/parity.sh`. `rg`
  shows repeated output-dir defaults, cleanup traps, timeout variables, Docker
  network/container setup, log polling, and text assertions, even though a
  shared parity library already exists.
- Why it is likely obsolete or harmful: local-lab scripts are environment
  sensitive, duplicate cleanup and wait behavior, and can be mistaken for
  product readiness.
- What could break if changed: local UltraGrid/JackTrip parity workflows,
  release-hygiene tests, Docker image policy, and reference-peer evidence runs.
- Suggested action: deduplicate only exact repeated helper behavior with at
  least two current script call sites. Keep connector-specific command lines
  explicit.
- Remediation note 2026-05-20: POST-DSA-016-A moved the repeated foreground
  Docker stop-on-exit and INT/TERM cleanup runner from the UltraGrid and
  JackTrip Docker client wrappers into `scripts/lib/parity.sh`. Connector-
  specific Docker arguments remain explicit in each wrapper.
- Remediation note 2026-05-21: POST-DSA-016-B moved the repeated output
  directory fallback contract for six parity-backed UltraGrid/JackTrip RX/TX
  and comparison scripts into `parity_output_dir`. The helper preserves the
  existing priority of explicit argument, `OPEN_LOLA_OUTPUT_DIR`, then
  `${TMPDIR:-/tmp}/open-lola-<suffix>-$$`. Stress/reference wrappers that do
  not source `scripts/lib/parity.sh` were left unchanged to avoid a broader
  shell-library change.
- Remediation note 2026-05-21: POST-DSA-016-C moved the exact repeated
  managed Docker RX/TX cleanup loop from
  `scripts/run-local-ultragrid-rxtx-docker.sh` and
  `scripts/run-local-jacktrip-rxtx-docker.sh` into
  `parity_stop_docker_containers_by_name_prefix`. Connector command lines,
  Docker image policy, parity comparison scripts, and native scripts remain
  explicit.
- Risk level: medium.
- Verification needed: `shellcheck`, script-specific dry runs where safe,
  release artifact hygiene tests, Docker parity checks on a working daemon, and
  reference-peer gates when available.

### DSA-017

- Category: misleading name / mixed responsibilities / compatibility seed
- Location: `linux_connector/lola_connector/cli.py`,
  `linux_connector/lola_connector/backends.py`, and
  `linux_connector/lola_connector/connector.py`
- Evidence: the Python package and CLI help now present the connector as the
  Linux LoLa compatibility seed instead of the "prototype LoLa Linux connector".
  The broader structural concern remains: `cli.py` mixes parser definition,
  runtime dispatch, validation, backend construction, and selftest routing.
  `backends.py` is 580 lines and defines protocol interfaces plus memory,
  generated, and subprocess audio/video backends. `connector.py` is 651 lines
  and owns async control/session logic.
- Resolution note 2026-05-20: the misleading entry-point/package wording was
  fixed and covered by a parser-help test. Historical docs may still use
  "prototype" when describing the current non-production validation status.
- Why it is likely obsolete or harmful: "prototype" naming and broad files make
  it unclear whether this is a durable compatibility seed or throwaway lab
  code. Mixed responsibilities make runtime behavior harder to audit.
- What could break if changed: Python connector CLI, Windows/WSL lab flows,
  selftests, process backend runtime, media compatibility, and docs that treat
  the connector as authoritative seed behavior.
- Suggested action: keep active behavior. Investigate rename and file splits
  only after proving CLI compatibility expectations and user-facing docs.
- Risk level: medium.
- Verification needed: `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p
  no:cacheprovider linux_connector`, `ruff`, `mypy`, real Windows/WSL lab
  smoke, and git-history verification before deleting any mode or backend.

## Highest-Risk Candidates

1. DSA-003 and DSA-004: Direct P2P legacy audio transport/device contracts.
2. DSA-006 and DSA-013: CLI and external connector parser dispatch surfaces.
3. DSA-008 through DSA-010: app execution and UI truthfulness.
4. DSA-005 and DSA-014: public report/workflow compatibility contracts that
   look obsolete but remain active.

## Likely Dead Or Deletable Only After Proof

- JPEG XS reference programs/extras/std shims from DSA-001.
- Uncompiled Opus vendor collateral from DSA-002.
- No remaining DSA-011 wrapper is a current deletion candidate. The
  menu-action ID set remains active surface-contract coverage.
- Legacy `audioCompression` and `audioDeviceUID` surfaces from DSA-003 and
  DSA-004 only after explicit migration evidence.

## Likely Overcomplicated Files

- `Sources/open-lola-app/AppExecutionController.swift`
- `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSession.swift`
- `Sources/open-lola/Commands/MilestoneCommands.swift`
- `scripts/verify_docs/constants.py`
- `scripts/verify_docs/markdown_checks.py`

## Likely Deprecated Compatibility Paths

- Hidden Direct P2P `audioCompression` / `--audio-compression`.
- Legacy Direct P2P and realtime graph `audioDeviceUID`.
- Prototype-named Direct P2P two-peer report and command.
- App-selectable but app-unlaunchable JackTrip and UltraGrid modes.
- NMP workflow reports only if future runtime or git-history evidence proves
  current CLI, schema, docs, and tests are no longer active authority.
- Local Docker/native connector parity helpers if replaced by measured
  reference-peer workflows.

## Recommended Next Audit Targets

1. Direct P2P compatibility migration only after an explicit breaking-change
   decision. The 2026-05-21 source, test, docs, and git-history recheck still
   shows `audioCompression`, hidden `--audio-compression`, and legacy
   `audioDeviceUID` as active compatibility surfaces rather than ordinary
   cleanup targets.
2. App-shell UI truthfulness audit focused on AppExecutionController
   lifecycle/report evidence surfaces and manual operator behavior, not the
   now-split execution state/readiness definitions, already-centralized
   unsupported JackTrip/UltraGrid execution branches, now-split console
   validation-preflight model, now-split settings draft workflow, now-split app
   section views, or the locally closed launch accessibility/window gate.
   POST-APP-VERIFY-F passed the strict native app verifier and captured
   accessibility UI, window-list, and screenshot evidence.
3. Future runtime command dispatch audits only after a new written slice plan
   or command-family change; the current `MilestoneCommands.swift` special
   paths were rechecked and retained.
4. Vendored source boundary audit with license/update policy before deleting
   release-excluded collateral.
5. Future external connector parser audits should start only from a new
   connector-specific behavior change or direct proof of an ignored flag path,
   not from a larger parser abstraction. Current ignored LoLa raw-link and
   video-control CLI paths are rejected at parse time, and the remaining shared
   flags were rechecked on 2026-05-21 with no additional deletion candidate
   proven.

## Coverage Gaps And Uncertainty

- Full file-by-file semantic review was not repeated for every source file; the
  audit builds on `docs/code-index.md` and targeted live evidence.
- Runtime usage was not measured. Items marked investigate or "needs runtime or
  git-history verification" must not be deleted from this audit alone.
- Full Swift test was rerun after POST-DSA-016-B and passed with 868 Swift
  Testing tests plus the existing 4 skipped LoLa UDP control retry/fallback
  tests. Focused POST-DSA-016-B script tests, ShellCheck, docs verification,
  and whitespace checks also passed. POST-APP-VERIFY-F reran the strict native
  app verifier and passed with accessibility UI, window-list, and screenshot
  evidence. Use `docs/verification-baseline.md` for broader verification
  state.
- Vendored Opus and JPEG XS internals were treated as third-party boundaries,
  not first-party refactor targets.
- Docker, reference-peer, hardware, and manual UI gates were not run.
