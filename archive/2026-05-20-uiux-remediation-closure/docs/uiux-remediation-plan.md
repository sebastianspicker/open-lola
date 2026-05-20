# UI/UX Remediation Plan

Date: 2026-05-20

Source audit: `docs/uiux-master-audit.md`

This plan is docs-only. It does not change production code, tests, UI design,
or runtime behavior. It turns the master audit into small, independently
reviewable remediation slices with verifiable outcomes.

## Planning Constraints

- Prefer the smallest targeted fix that resolves the audited behavior.
- Do not create a broad "redesign all UI" effort.
- Keep unrelated UI areas in separate slices.
- If a finding needs a product/design decision or runtime proof, use an
  INVESTIGATION or DECISION slice before implementation.
- Every implementation slice must include a user-facing proof path and a
  focused test or manual verification path.
- Keep `PARTIAL`, source-level, synthetic, report-only, and runtime evidence
  labels truthful.

## Finding Coverage Map

| Finding | Slice |
| --- | --- |
| `MASTER-SB-001` | UIUX-R01 |
| `MASTER-SB-002` | UIUX-R02 |
| `MASTER-FLOW-001` | UIUX-R03 |
| `MASTER-FLOW-003`, `MASTER-SB-013` | UIUX-R04 |
| `MASTER-FLOW-002` | UIUX-R05 |
| `MASTER-FLOW-006` | UIUX-R06 |
| `MASTER-FLOW-007` | UIUX-R07 |
| `MASTER-FLOW-014` | UIUX-R08 |
| `MASTER-FLOW-004` | UIUX-R09 |
| `MASTER-FLOW-005`, `MASTER-SB-005` | UIUX-R10 |
| `MASTER-SB-003`, `MASTER-SB-004` | UIUX-R11 |
| `MASTER-FLOW-009`, `MASTER-SB-006`, `MASTER-SB-012` | UIUX-R12 |
| `MASTER-FLOW-011` | UIUX-R13 |
| `MASTER-FLOW-008` | UIUX-R14 |
| `MASTER-FLOW-010`, `MASTER-SB-007` | UIUX-R15 |
| `MASTER-SB-008` | UIUX-R16 |
| `MASTER-SB-009` | UIUX-R17 |
| `MASTER-SB-010`, `MASTER-SB-011` | UIUX-R18 |
| `MASTER-SB-014` | UIUX-R19 |
| `MASTER-VA-001` | UIUX-R20 |
| `MASTER-VA-002` | UIUX-R21 |
| `MASTER-VA-003` | UIUX-R22 |
| `MASTER-VA-004` | UIUX-R23 |
| `MASTER-VA-005` | UIUX-R24 |
| `MASTER-VA-006` | UIUX-R25 |
| `MASTER-VA-007` | UIUX-R26 |
| `MASTER-VA-008` | UIUX-R27 |
| `MASTER-VA-009` | UIUX-R28 |
| `MASTER-VA-010` | UIUX-R29 |
| `MASTER-VA-011` | UIUX-R30 |
| `MASTER-FLOW-012` | UIUX-R31 |
| `MASTER-FLOW-013` | UIUX-R32 |

## Remediation Slices

### UIUX-R01 - Invalidate run readiness after runtime-affecting edits

- Slice ID: UIUX-R01
- Title: Invalidate stale validation/runtime evidence before Start
- Findings addressed: `MASTER-SB-001`
- Problem: Start can remain available from prior validation evidence after the
  user changes runtime-affecting settings or operator-surface fields.
- Minimal remediation strategy: Add one explicit invalidation path for
  runtime-affecting mutations. Clear validation/evidence readiness when those
  fields change, and only re-enable Start after current validation succeeds.
- Files likely affected: `Sources/open-lola-app/AppExecutionController.swift`,
  `Sources/open-lola-app/AppSettings.swift`,
  `Sources/open-lola-app/AppLocalOperatorSurfaceView.swift`,
  `Sources/open-lola-app/AppTransportView.swift`,
  `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift`,
  `Tests/OpenLolaCoreTests/AppShellSlice05Tests.swift`
- User behavior affected: Start becomes blocked again after changing ports,
  devices, report paths, peer fields, connector settings, or other
  runtime-affecting controls.
- Runtime behavior affected, if any: Prevents a live run from using stale
  validation evidence for a changed configuration.
- Tests/manual checks to add: Model tests that validate a report, mutate each
  runtime-affecting field category, and assert Start/preflight returns blocked
  until validation reruns.
- Verification commands/checklist: `swift test --filter AppShell --no-parallel`;
  `swift test --filter NativeAppShell --no-parallel`; manual app check for
  validate, edit, Start-disabled, revalidate, Start-enabled.
- Risk level: High.
- Rollback strategy: Revert the invalidation hook and tests as a single slice;
  return to previous Start gating.
- Definition of Done: A changed runtime setting reliably invalidates run
  readiness, the UI explains the need to revalidate, and focused tests prove the
  stale-evidence path is blocked.

### UIUX-R02 - Wire or demote Command Intent Stop

- Slice ID: UIUX-R02
- Title: Fix misleading `Intent: Stop`
- Findings addressed: `MASTER-SB-002`
- Problem: `Intent: Stop` looks like a stop control but only mutates command
  intent metadata.
- Minimal remediation strategy: Either wire it to the same confirmed stop path
  as other Stop controls, or relabel/disable it as metadata-only while a run is
  active. Prefer the smaller option that matches the intended Command Intent
  model after inspection.
- Files likely affected: `Sources/open-lola-app/AppLocalOperatorSurfaceView.swift`,
  `Sources/open-lola-app/AppShellRootView.swift`,
  `Sources/open-lola-app/AppTransportView.swift`,
  `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift`
- User behavior affected: Pressing a Stop-looking control either stops the
  active run through the real path or no longer appears to stop runtime.
- Runtime behavior affected, if any: If wired, this affects active process stop
  behavior; if demoted, runtime remains unchanged.
- Tests/manual checks to add: Test the button while `isRunning == true`; assert
  stop path invocation or unavailable/relabelled metadata-only state.
- Verification commands/checklist: `swift test --filter AppShellBehavior --no-parallel`;
  manual check of Devices command intent panel during active and idle states.
- Risk level: Medium-high.
- Rollback strategy: Revert the button behavior/copy and its tests.
- Definition of Done: No UI control labelled as Stop can leave the process
  running while presenting stop-requested state as if runtime stopped.

### UIUX-R03 - Fix stale validation shortcut

- Slice ID: UIUX-R03
- Title: Align validation shortcut copy and menu contract
- Findings addressed: `MASTER-FLOW-001`
- Problem: Settings advertises `Command-Shift-V`, but the validation menu
  action has no shortcut in the source contract.
- Minimal remediation strategy: Either add the shortcut to
  `validate-supervisor-report` and test it, or remove the Settings shortcut
  text. Prefer removing text if shortcut ownership is unclear.
- Files likely affected: `Sources/open-lola-app/AppShellSettingsTabs.swift`,
  `Sources/OpenLolaCore/Platform/NativeAppShellSurfaceContract.swift`,
  `Sources/open-lola-app/OpenLolaApp.swift`,
  `Tests/OpenLolaCoreTests/AppShellSlice05Tests.swift`
- User behavior affected: Keyboard guidance becomes truthful.
- Runtime behavior affected, if any: None unless the shortcut is added.
- Tests/manual checks to add: Contract test that visible shortcut copy matches
  the menu action inventory; manual menu check.
- Verification commands/checklist: `swift test --filter AppShellSlice05 --no-parallel`;
  manual Settings and menu shortcut inspection.
- Risk level: Low-medium.
- Rollback strategy: Revert copy/shortcut contract change and matching tests.
- Definition of Done: No visible UI advertises a validation shortcut unless the
  menu action actually owns it.

### UIUX-R04 - Clarify first-run readiness sequence

- Slice ID: UIUX-R04
- Title: Split setup readiness from start readiness
- Findings addressed: `MASTER-FLOW-003`, `MASTER-SB-013`
- Problem: A first-time user can see disabled Start, blocked Validate, or "Can
  I Run? Ready" without a linear next step.
- Minimal remediation strategy: Adjust existing model/copy only. Show a minimal
  sequence of states: configure, produce/load report, validate current evidence,
  start. Rename ambiguous `Ready` states when they mean ready to validate rather
  than ready to start.
- Files likely affected: `Sources/open-lola-app/AppConsoleModels.swift`,
  `Sources/open-lola-app/AppShellRootView.swift`,
  `Sources/open-lola-app/AppTransportView.swift`,
  `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift`
- User behavior affected: Users can identify the next required artifact or
  validation step before Start.
- Runtime behavior affected, if any: None; Start gating remains strict.
- Tests/manual checks to add: State tests for unconfigured, configured-no-report,
  report-ready-not-validated, validation-failed, evidence-incomplete, and
  ready-to-start copy.
- Verification commands/checklist: `swift test --filter AppShell --no-parallel`;
  manual Session and Validation smoke with no report and with a validated report.
- Risk level: Medium.
- Rollback strategy: Revert copy/model changes and tests.
- Definition of Done: The readiness UI never says start-ready before current
  validation/evidence is proven, and each blocked state names the next action.

### UIUX-R05 - Decide planning-only connector workflow handoff

- Slice ID: UIUX-R05
- Title: DECISION - planning-only connector modes in the app
- Findings addressed: `MASTER-FLOW-002`
- Problem: JackTrip and UltraGrid are selectable in the primary picker but have
  no app runtime launcher and no concrete handoff target.
- Minimal remediation strategy: Decide whether they remain selectable as
  planning-only modes, move to a separate planning section, or link to a
  concrete CLI/docs handoff. Do not implement runtime launchers in this slice.
- Files likely affected: `docs/uiux-remediation-plan.md`,
  `Sources/open-lola-app/AppLocalOperatorSurfaceView.swift`,
  `Sources/open-lola-app/AppShellSettingsTabs.swift`,
  `Sources/OpenLolaCore/Platform/NativeAppShellSessionMode.swift`
- User behavior affected: Users stop mistaking planning-only modes for runnable
  app workflows.
- Runtime behavior affected, if any: None.
- Tests/manual checks to add: Decision note with accepted labels and handoff
  target; later tests for picker labels and disabled run behavior.
- Verification commands/checklist: Confirm selected handoff command/docs path
  exists; later `swift test --filter AppShell --no-parallel`.
- Risk level: Medium.
- Rollback strategy: Revert only planning labels/handoff copy; runtime remains
  unchanged.
- Definition of Done: A documented decision identifies the exact user-facing
  treatment and proof target for JackTrip/UltraGrid app surfaces.
- Decision outcome, 2026-05-20: Keep JackTrip and UltraGrid selectable only as
  planning/comparison modes until a separate app-runtime launcher is explicitly
  implemented. Do not imply they can be launched from the app. Later UI copy
  should label them as planning-only or comparison-only, keep Start/Validate
  unavailable from those app modes, and point users to the active external
  connector parity gates in `docs/testing.md` plus the connector boundaries in
  `docs/source-contracts.md`. Proof target for the later UI slice: tests should
  assert `supportsAppExecution == false`, unavailable copy names planning-only
  status and the `docs/testing.md` parity gate, and no app Start path becomes
  enabled for JackTrip or UltraGrid.

### UIUX-R06 - Separate real execution from command intent controls

- Slice ID: UIUX-R06
- Title: Clarify execution versus intent affordances
- Findings addressed: `MASTER-FLOW-006`
- Problem: Menu, Session transport, topbar/footer, and Command Intent controls
  use overlapping labels for different side effects.
- Minimal remediation strategy: Keep Session transport as the primary run path.
  Rename or scope intent-only controls so they cannot be mistaken for process
  launch/stop controls. Do not move broad layouts in this slice.
- Files likely affected: `Sources/open-lola-app/AppLocalOperatorSurfaceView.swift`,
  `Sources/open-lola-app/AppTransportView.swift`,
  `Sources/open-lola-app/OpenLolaApp.swift`,
  `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift`
- User behavior affected: Users can distinguish process control from metadata
  intent.
- Runtime behavior affected, if any: None unless paired with UIUX-R02.
- Tests/manual checks to add: Tests that labels and side effects differ clearly
  for intent-only versus runtime controls.
- Verification commands/checklist: `swift test --filter AppShellBehavior --no-parallel`;
  manual scan of Session and Devices controls.
- Risk level: Medium.
- Rollback strategy: Revert label/scope changes only.
- Definition of Done: Every execution-looking affordance clearly indicates
  whether it launches/stops runtime or only sets intent state.

### UIUX-R07 - Centralize stop confirmation copy

- Slice ID: UIUX-R07
- Title: Make Stop confirmation policy and copy consistent
- Findings addressed: `MASTER-FLOW-007`
- Problem: Stop and quit surfaces use several entry points and slightly
  different wording for active session/supervisor/live state.
- Minimal remediation strategy: Extract or reuse one stop confirmation policy
  and one copy source for menu, transport, topbar/footer, and quit guard where
  applicable.
- Files likely affected: `Sources/open-lola-app/OpenLolaApp.swift`,
  `Sources/open-lola-app/AppTransportView.swift`,
  `Sources/open-lola-app/AppShellRootView.swift`,
  `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift`
- User behavior affected: Stop/quit prompts describe the same active process in
  consistent language.
- Runtime behavior affected, if any: Stop behavior should not change.
- Tests/manual checks to add: Tests for shared title/message and dry-run versus
  active-run confirmation policy.
- Verification commands/checklist: `swift test --filter AppShellBehavior --no-parallel`;
  manual menu, topbar/footer, transport, quit confirmation check.
- Risk level: Medium.
- Rollback strategy: Revert centralized copy/policy helper and tests.
- Definition of Done: All Stop entry points use the same confirmation policy
  and compatible copy for the same runtime state.

### UIUX-R08 - Add recoverable disabled reasons for menu actions

- Slice ID: UIUX-R08
- Title: Explain unavailable menu actions
- Findings addressed: `MASTER-FLOW-014`
- Problem: Menu actions are disabled without the recovery help visible on
  equivalent in-window controls.
- Minimal remediation strategy: Add policy-owned disabled reason strings and
  surface them through feasible macOS menu help or a status panel. If macOS menu
  limitations block inline help, document the fallback and use the status panel.
- Files likely affected: `Sources/open-lola-app/OpenLolaApp.swift`,
  `Sources/open-lola-app/AppTransportView.swift`,
  `Sources/OpenLolaCore/Platform/NativeAppShellSurfaceContract.swift`,
  `Tests/OpenLolaCoreTests/AppShellSlice05Tests.swift`
- User behavior affected: Menu-driven users know whether setup, arm, report,
  validation, or evidence is missing.
- Runtime behavior affected, if any: None.
- Tests/manual checks to add: Policy tests for disabled reason text; manual
  menu/status panel inspection.
- Verification commands/checklist: `swift test --filter AppShellSlice05 --no-parallel`;
  manual app menu smoke.
- Risk level: Medium.
- Rollback strategy: Revert disabled reason plumbing and tests.
- Definition of Done: Every high-risk disabled menu action has a discoverable
  reason and a next step.

### UIUX-R09 - Keep Packet Monitor reachable with truthful empty state

- Slice ID: UIUX-R09
- Title: Make Packet Monitor empty evidence route discoverable
- Findings addressed: `MASTER-FLOW-004`
- Problem: Packet Monitor can appear dimmed/unavailable even though its empty
  state explains how to produce packet evidence.
- Minimal remediation strategy: Keep the route reachable after setup and change
  sidebar/unavailable copy to "No capture yet" or equivalent truthful empty
  state. Do not invent live packet tailing.
- Files likely affected: `Sources/open-lola-app/AppConsoleChromeView.swift`,
  `Sources/open-lola-app/AppConsoleModels.swift`,
  `Sources/open-lola-app/AppShellRootView.swift`,
  `Sources/open-lola-app/AppPacketMonitorView.swift`,
  `Tests/OpenLolaCoreTests/AppShellSlice05Tests.swift`
- User behavior affected: Users can reach Packet Monitor to learn how to
  produce packet evidence.
- Runtime behavior affected, if any: None.
- Tests/manual checks to add: Route availability test with configured session
  and no capture; copy tests for empty/no-capture state.
- Verification commands/checklist: `swift test --filter AppShellSlice05 --no-parallel`;
  manual sidebar and search check.
- Risk level: Low-medium.
- Rollback strategy: Revert route availability/copy changes and tests.
- Definition of Done: Packet Monitor is reachable when it should explain
  missing evidence, and no UI implies packets exist before a capture report.

### UIUX-R10 - Resolve settings ownership and stale draft risk

- Slice ID: UIUX-R10
- Title: Prevent stale Settings saves from overwriting current state
- Findings addressed: `MASTER-FLOW-005`, `MASTER-SB-005`
- Problem: Settings are split across Devices, sidebar summary, and macOS
  Settings; an open settings draft can overwrite newer main-window edits.
- Minimal remediation strategy: Add source revision or dirty/conflict handling
  to Settings Save. Keep sidebar Settings read-only. Clarify which categories
  are edited in Devices versus Settings without moving broad UI.
- Files likely affected: `Sources/open-lola-app/AppShellSettingsView.swift`,
  `Sources/open-lola-app/AppSettings.swift`,
  `Sources/open-lola-app/AppShellRootView.swift`,
  `Tests/OpenLolaCoreTests/AppShellSlice05Tests.swift`
- User behavior affected: Users cannot silently save stale settings over newer
  main-window changes.
- Runtime behavior affected, if any: Prevents accidental runtime configuration
  rollback.
- Tests/manual checks to add: Open draft, mutate live operator surface,
  attempt Save, assert conflict warning/reload/preservation.
- Verification commands/checklist: `swift test --filter AppShellSlice05 --no-parallel`;
  manual Settings window and Devices edit/save smoke.
- Risk level: Medium-high.
- Rollback strategy: Revert draft conflict handling and copy changes.
- Definition of Done: Settings Save either applies current edits safely or
  warns/reloads when the source state changed elsewhere.

### UIUX-R11 - Fix locked input and inventory refresh stale-state seams

- Slice ID: UIUX-R11
- Title: Align input locking and inventory refresh merge behavior
- Findings addressed: `MASTER-SB-003`, `MASTER-SB-004`
- Problem: A remote host label remains editable while adjacent fields are
  locked, and async inventory refresh can reapply stale snapshot fields.
- Minimal remediation strategy: Apply the same lock policy to the remote host
  field unless proven metadata-only. Change refresh apply logic to merge only
  inventory results or block affected edits during refresh.
- Files likely affected: `Sources/open-lola-app/AppLocalOperatorSurfaceView.swift`,
  `Sources/open-lola-app/AppLocalOperatorInventory.swift`,
  `Tests/OpenLolaCoreTests/AppShellSlice05Tests.swift`
- User behavior affected: Users cannot accidentally edit locked runtime fields
  or lose edits during inventory refresh.
- Runtime behavior affected, if any: Prevents stale or inconsistent plan inputs.
- Tests/manual checks to add: Input-lock tests for each remote field; async
  refresh test that preserves or blocks concurrent edits.
- Verification commands/checklist: `swift test --filter AppShellSlice05 --no-parallel`;
  manual Devices refresh/edit smoke.
- Risk level: Medium.
- Rollback strategy: Revert lock/merge changes and tests.
- Definition of Done: Locked state covers all runtime-affecting fields, and a
  refresh cannot silently overwrite user edits.

### UIUX-R12 - Harden artifact and remote inventory operations

- Slice ID: UIUX-R12
- Title: Make artifact import/write state explicit and non-stale
- Findings addressed: `MASTER-FLOW-009`, `MASTER-SB-006`, `MASTER-SB-012`
- Problem: Remote inventory/artifact flow is fragile; stale generated content
  can remain after failures, and Write Plan Artifact can overwrite existing
  files without confirmation or counts.
- Minimal remediation strategy: Clear stale generated content on unrelated
  actions/failures, add import validation summaries, and add overwrite
  confirmation or timestamped output for existing plan artifacts.
- Files likely affected: `Sources/open-lola-app/AppOperatorArtifactViews.swift`,
  `Sources/OpenLolaCore/Platform/NativeAppShellArtifacts.swift`,
  `Sources/open-lola-app/AppRemoteInventoryImport.swift`,
  `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift`
- User behavior affected: Users know whether imported/written artifacts are
  current, failed, skipped, or overwritten.
- Runtime behavior affected, if any: Prevents stale artifact data from feeding
  later plans.
- Tests/manual checks to add: Invalid JSON, missing IDs, successful import,
  failing paste/write, stale content cleared, existing target file behavior.
- Verification commands/checklist: `swift test --filter AppShell --no-parallel`;
  manual artifact panel copy/paste/write smoke.
- Risk level: Medium.
- Rollback strategy: Revert artifact state/confirmation changes and tests.
- Definition of Done: Artifact actions report current result, do not display
  stale generated content as current, and do not overwrite without proof or
  confirmation.

### UIUX-R13 - Add recovery for empty device inventory and permission failures

- Slice ID: UIUX-R13
- Title: Provide setup recovery for no devices and denied permissions
- Findings addressed: `MASTER-FLOW-011`
- Problem: Empty device and permission states surface status text but not a
  complete recovery path.
- Minimal remediation strategy: Add small recovery copy/actions near existing
  empty states: refresh inventory, open Diagnostics, and explain macOS privacy
  requirements. Do not add OS automation that cannot be supported.
- Files likely affected: `Sources/open-lola-app/AppLocalOperatorSurfaceView.swift`,
  `Sources/open-lola-app/AppReceiverPreviewServices.swift`,
  `Sources/open-lola-app/AppShellRootView.swift`,
  `Tests/OpenLolaCoreTests/AppShellSlice05Tests.swift`
- User behavior affected: First setup has a clear path when devices or
  permissions are missing.
- Runtime behavior affected, if any: None.
- Tests/manual checks to add: Empty inventory model/copy tests; permission
  denied preview copy tests; manual camera/microphone denied smoke.
- Verification commands/checklist: `swift test --filter AppShellSlice05 --no-parallel`;
  manual device/permission scenarios.
- Risk level: Medium.
- Rollback strategy: Revert recovery copy/actions and tests.
- Definition of Done: Each empty/permission failure state names a next action
  without implying the app can grant system permissions directly.

### UIUX-R14 - Reveal advanced fields only when blockers require them

- Slice ID: UIUX-R14
- Title: Add blocker-to-field recovery for hidden advanced controls
- Findings addressed: `MASTER-FLOW-008`
- Problem: Normal/Advanced disclosure can hide fields needed to resolve
  validation blockers.
- Minimal remediation strategy: Map existing blocker types to field groups. If
  a blocker depends on hidden advanced controls, show a targeted "Show
  Advanced" affordance or reveal that group. Avoid broad IA changes.
- Files likely affected: `Sources/open-lola-app/AppConsoleModels.swift`,
  `Sources/open-lola-app/AppLocalOperatorSurfaceView.swift`,
  `Sources/open-lola-app/AppShellSettingsTabs.swift`,
  `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift`
- User behavior affected: Users can discover the exact hidden control needed to
  resolve a blocker.
- Runtime behavior affected, if any: None direct.
- Tests/manual checks to add: Tests mapping blockers to field groups and
  asserting advanced recovery appears only when needed.
- Verification commands/checklist: `swift test --filter AppShell --no-parallel`;
  manual normal-mode blocker smoke.
- Risk level: Medium.
- Rollback strategy: Revert blocker mapping and affordance.
- Definition of Done: A hidden field required by a blocker has a visible,
  targeted path to reveal it.

### UIUX-R15 - Separate local preview, remote evidence, and meter truth

- Slice ID: UIUX-R15
- Title: Clarify preview/evidence types and failed metering state
- Findings addressed: `MASTER-FLOW-010`, `MASTER-SB-007`
- Problem: Local preview, remote stream report, received-media preview, and
  packet/runtime evidence can be confused. Meter bars can appear while local
  metering failed.
- Minimal remediation strategy: Rename/copy-adjust existing status labels to
  identify evidence type. Gate meter bars on actual local metering active state
  or show a degraded/error empty state.
- Files likely affected: `Sources/open-lola-app/AppPreviewReceiverView.swift`,
  `Sources/open-lola-app/AppChannelMeterView.swift`,
  `Sources/open-lola-app/AppShellRootView.swift`,
  `Sources/open-lola-app/AppConsoleModels.swift`,
  `Tests/OpenLolaCoreTests/AppShellSlice05Tests.swift`
- User behavior affected: Users can tell local monitoring from remote/runtime
  evidence and do not mistake failed meters for active metering.
- Runtime behavior affected, if any: None; this is presentation/state
  truthfulness.
- Tests/manual checks to add: Policy test for supervisor-running plus failed
  audio preview; text tests for local versus remote evidence labels; manual
  microphone denied smoke.
- Verification commands/checklist: `swift test --filter AppShellSlice05 --no-parallel`;
  manual preview window and Streams route check.
- Risk level: Medium.
- Rollback strategy: Revert meter gating/copy changes and tests.
- Definition of Done: Local preview/meter UI does not imply remote media or
  active local metering without the matching state evidence.

### UIUX-R16 - Decide live session state semantics

- Slice ID: UIUX-R16
- Title: INVESTIGATION - `.live` state reachability and criteria
- Findings addressed: `MASTER-SB-008`
- Problem: `.live` banner copy exists, but the audit did not trace a producer
  in `AppSessionState.derive(...)`.
- Minimal remediation strategy: Trace all session state producers and decide
  whether `.live` is required. If required, define evidence criteria; if stale,
  remove/rename it in a later implementation slice.
- Files likely affected: `Sources/open-lola-app/AppSessionStateBanner.swift`,
  `Sources/open-lola-app/AppConsoleModels.swift`,
  `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift`
- User behavior affected: Users either get a real live state or stale live copy
  is removed.
- Runtime behavior affected, if any: None in investigation; later
  implementation may affect state display.
- Tests/manual checks to add: Lifecycle reachability test or stale-state
  removal test after decision.
- Verification commands/checklist: Source trace of every `AppSessionState`
  producer; later `swift test --filter AppShellBehavior --no-parallel`.
- Risk level: Low for investigation, medium for implementation.
- Rollback strategy: Keep current state model until decision is accepted.
- Definition of Done: A written decision states whether `.live` is active,
  future, or stale and names the exact proof needed for implementation.
- Decision recorded 2026-05-20: `.live` is a future/stale presentation state,
  not an active derived runtime state. Source trace found `.live` enum,
  presentation, navigation, preview-warning, topology, and stop-confirmation
  consumers, but no `AppSessionState.derive(...)` branch that returns `.live`.
  Implementation proof needed before enabling `.live`: measured active remote
  media/session evidence with validated runtime criteria, not just supervisor
  process running, local preview, or completed report validation.

### UIUX-R17 - Add synthetic metrics refresh feedback

- Slice ID: UIUX-R17
- Title: Show source/synthetic refresh progress and outcome
- Findings addressed: `MASTER-SB-009`
- Problem: Refresh Synthetic Metrics can look like a no-op and may be confused
  with live runtime metrics.
- Minimal remediation strategy: Add a small in-flight flag and last refresh
  outcome for source/synthetic metrics, or rename/copy-adjust if the operation
  is guaranteed immediate and non-failing.
- Files likely affected: `Sources/open-lola-app/OpenLolaApp.swift`,
  `Sources/open-lola-app/AppConsoleChromeView.swift`,
  `Sources/open-lola-app/AppConsoleModels.swift`,
  `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift`
- User behavior affected: Users see whether source/synthetic refresh is
  running, complete, or failed.
- Runtime behavior affected, if any: None; source/synthetic report only.
- Tests/manual checks to add: Test refresh in-flight and last-outcome state,
  possibly with a delayed stub.
- Verification commands/checklist: `swift test --filter AppShell --no-parallel`;
  manual menu/topbar refresh check.
- Risk level: Low.
- Rollback strategy: Revert refresh state/copy and tests.
- Definition of Done: Refresh action has visible state and cannot be mistaken
  for live runtime measurement.

### UIUX-R18 - Centralize copy failure and missing-log feedback

- Slice ID: UIUX-R18
- Title: Make copy/log unavailable states explicit
- Findings addressed: `MASTER-SB-010`, `MASTER-SB-011`
- Problem: Several copy actions ignore pasteboard failure, and disabled log
  open buttons do not explain why logs are unavailable.
- Minimal remediation strategy: Use one copy helper/status path for all copy
  buttons. Add disabled help or adjacent reason text for stdout/stderr buttons.
- Files likely affected: `Sources/open-lola-app/AppPasteboard.swift`,
  `Sources/open-lola-app/AppShellSupportViews.swift`,
  `Sources/open-lola-app/AppExecutionView.swift`,
  `Sources/open-lola-app/AppPacketMonitorView.swift`,
  `Sources/open-lola-app/AppShellRootView.swift`,
  `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift`
- User behavior affected: Users know when copy failed and why logs cannot be
  opened.
- Runtime behavior affected, if any: None.
- Tests/manual checks to add: Failing pasteboard helper test for representative
  copy controls; missing-log state test.
- Verification commands/checklist: `swift test --filter AppShell --no-parallel`;
  manual copy and log-button check.
- Risk level: Low-medium.
- Rollback strategy: Revert shared copy helper/status and log copy.
- Definition of Done: Copy failure is surfaced consistently and disabled log
  buttons explain the missing/unavailable state.

### UIUX-R19 - Reconcile preview window request state

- Slice ID: UIUX-R19
- Title: Confirm or constrain Local Preview window request feedback
- Findings addressed: `MASTER-SB-014`
- Problem: The app says the preview window was requested, but source does not
  confirm display success or timeout/failure.
- Minimal remediation strategy: Keep copy limited to request sent, or add a
  lightweight lifecycle confirmation if SwiftUI/AppKit exposes a reliable
  signal. Do not build a new window manager.
- Files likely affected: `Sources/open-lola-app/OpenLolaApp.swift`,
  `Sources/open-lola-app/AppPreviewReceiverView.swift`,
  `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift`
- User behavior affected: Users are not told more than the app can prove about
  preview window display.
- Runtime behavior affected, if any: None.
- Tests/manual checks to add: Manual menu action check; optional state test for
  request-copy wording.
- Verification commands/checklist: `swift test --filter AppShellBehavior --no-parallel`
  if model/copy changes; manual app menu/window smoke.
- Risk level: Low-medium.
- Rollback strategy: Revert lifecycle/copy changes.
- Definition of Done: Preview window request feedback is truthful and failure
  or non-display has a named manual recovery path if detectable.

### UIUX-R20 - Improve long operational value readability

- Slice ID: UIUX-R20
- Title: Add full-value affordances for paths, UIDs, and hosts
- Findings addressed: `MASTER-VA-001`
- Problem: Long paths, UIDs, device IDs, and hostnames can be hidden by
  truncation or horizontal scrolling.
- Minimal remediation strategy: For reusable value/device/topology components,
  add middle truncation, full-value disclosure, copy/open affordance, or help
  text where already consistent with the component. Avoid per-screen redesign.
- Files likely affected: `Sources/open-lola-app/AppShellSupportViews.swift`,
  `Sources/open-lola-app/AppDeviceCard.swift`,
  `Sources/open-lola-app/AppConnectionTopologyView.swift`,
  `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift`
- User behavior affected: Users can inspect full operational identifiers.
- Runtime behavior affected, if any: None.
- Tests/manual checks to add: Long-value fixtures for paths, UIDs, hostnames,
  and topology labels; manual minimum-window check.
- Verification commands/checklist: `swift test --filter AppShell --no-parallel`;
  manual 1024x720 long-value visual check.
- Risk level: Low-medium.
- Rollback strategy: Revert component affordance changes.
- Definition of Done: Full values are discoverable without relying on hidden
  horizontal scroll alone.

### UIUX-R21 - Stabilize generated command readability

- Slice ID: UIUX-R21
- Title: Make generated command review predictable
- Findings addressed: `MASTER-VA-002`
- Problem: Long generated commands can overflow, require awkward scrolling, or
  consume unstable space.
- Minimal remediation strategy: Preserve exact copy output while improving
  display: stable max height, wrapping, token grouping, or an expanded command
  detail area.
- Files likely affected: `Sources/open-lola-app/AppExecutionView.swift`,
  `Sources/open-lola-app/AppOperatorPlanViews.swift`,
  `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift`
- User behavior affected: Users can visually review commands before copying.
- Runtime behavior affected, if any: None.
- Tests/manual checks to add: Long executable/peer path fixtures; verify copy
  output remains exact.
- Verification commands/checklist: `swift test --filter AppShell --no-parallel`;
  manual generated-command review and copy check.
- Risk level: Medium.
- Rollback strategy: Revert display-only changes; generated command builders
  remain unchanged.
- Definition of Done: Long commands stay reviewable and copy remains exact.

### UIUX-R22 - Add packet row detail access

- Slice ID: UIUX-R22
- Title: Expose full packet row data without relying on truncation
- Findings addressed: `MASTER-VA-003`
- Problem: Packet table cells truncate diagnostic payloads, addresses, and
  stream/candidate data.
- Minimal remediation strategy: Add selected-row detail or disclosure using
  existing packet row model. Do not create live packet tailing.
- Files likely affected: `Sources/open-lola-app/AppPacketMonitorView.swift`,
  `Tests/OpenLolaCoreTests/AppShellSlice05Tests.swift`
- User behavior affected: Users can inspect exact packet evidence.
- Runtime behavior affected, if any: None.
- Tests/manual checks to add: Long payload/candidate fixture; keyboard access
  and copy/detail tests.
- Verification commands/checklist: `swift test --filter AppShellSlice05 --no-parallel`;
  manual Packet Monitor check with long rows.
- Risk level: Medium.
- Rollback strategy: Revert detail pane/disclosure.
- Definition of Done: Full packet values are reachable visually and by
  keyboard without depending only on tooltip/copy.

### UIUX-R23 - Normalize compact control hit targets

- Slice ID: UIUX-R23
- Title: Apply shared compact button sizing where safe
- Findings addressed: `MASTER-VA-004`
- Problem: Plain copy/dismiss/banner controls may have smaller hit targets than
  transport controls.
- Minimal remediation strategy: Add a shared compact-control modifier or
  targeted minimum frame for icon/copy/dismiss controls where it does not break
  dense layouts.
- Files likely affected: `Sources/open-lola-app/AppShellSupportViews.swift`,
  `Sources/open-lola-app/AppPacketMonitorView.swift`,
  `Sources/open-lola-app/AppSessionStateBanner.swift`,
  `Sources/open-lola-app/AppOperatorPlanViews.swift`
- User behavior affected: Dense copy/dismiss controls become easier to click
  and focus.
- Runtime behavior affected, if any: None.
- Tests/manual checks to add: Manual Accessibility Inspector hit-target check;
  keyboard traversal check.
- Verification commands/checklist: `swift test --filter AppShell --no-parallel`
  if reusable component changes are testable; manual 1024x720 layout check.
- Risk level: Low-medium.
- Rollback strategy: Revert sizing modifier or per-control frame changes.
- Definition of Done: Targeted compact controls have a visible/focusable hit
  area that does not destabilize layout.

### UIUX-R24 - Make disabled reasons persistent for settings and preview controls

- Slice ID: UIUX-R24
- Title: Do not rely only on hover help for disabled controls
- Findings addressed: `MASTER-VA-005`
- Problem: Disabled settings and preview controls rely on `.help(...)`, which
  may be hidden from keyboard or low-vision users.
- Minimal remediation strategy: Add persistent adjacent reason text for locked
  settings and unsupported preview controls using existing copy.
- Files likely affected: `Sources/open-lola-app/AppShellSettingsView.swift`,
  `Sources/open-lola-app/AppShellSettingsTabs.swift`,
  `Sources/open-lola-app/AppPreviewReceiverView.swift`,
  `Tests/OpenLolaCoreTests/AppShellSlice05Tests.swift`
- User behavior affected: Users can understand disabled controls without
  pointer hover.
- Runtime behavior affected, if any: None.
- Tests/manual checks to add: Locked settings and unsupported preview state
  tests; manual keyboard/VoiceOver pass.
- Verification commands/checklist: `swift test --filter AppShellSlice05 --no-parallel`;
  manual disabled controls check.
- Risk level: Low-medium.
- Rollback strategy: Revert persistent reason copy.
- Definition of Done: Disabled states have visible or accessible reason text
  without requiring hover.

### UIUX-R25 - Decide focus-visible policy outside transport

- Slice ID: UIUX-R25
- Title: INVESTIGATION - focus visibility for dense operator controls
- Findings addressed: `MASTER-VA-006`
- Problem: Transport controls have explicit focus treatment, while other dense
  controls rely on unverified defaults.
- Minimal remediation strategy: Run keyboard traversal and screenshot focused
  states before changing code. Decide whether default macOS focus is sufficient
  or a small shared focus modifier is needed.
- Files likely affected: `docs/uiux-remediation-plan.md`,
  `Sources/open-lola-app/AppShellSupportViews.swift`,
  `Sources/open-lola-app/AppConsoleChromeView.swift`,
  `Sources/open-lola-app/AppDeviceCard.swift`
- User behavior affected: Keyboard users get a predictable focus model if an
  implementation slice follows.
- Runtime behavior affected, if any: None.
- Tests/manual checks to add: Manual keyboard traversal screenshots for
  sidebar, topbar, packet monitor, device cards, warning banners, settings, and
  dialogs.
- Verification commands/checklist: Manual app-bundle keyboard traversal in
  light/dark/high-contrast modes; later focused tests only if behavior changes.
- Risk level: Low for investigation, medium for implementation.
- Rollback strategy: No code change in investigation; later revert focus
  modifier if it harms platform behavior.
- Definition of Done: Decision records which controls need custom focus
  treatment and what evidence supports it.
- Decision, 2026-05-20: DEFER implementation. Source inspection confirms
  transport controls have explicit `@FocusState`, `.focused(...)`, keyboard
  shortcuts, and `transportFocusRing(...)` treatment, while sidebar/topbar,
  search, settings controls, device cards, Packet Monitor actions, copy buttons,
  warning dismissal, preview controls, and session banner CTAs rely on platform
  defaults plus labels/help. This shell-only pass did not capture manual
  keyboard traversal screenshots in light, dark, or increased-contrast modes at
  1024x720. Do not add custom focus styling until manual app-bundle evidence
  identifies a specific invisible or ambiguous focused control family. If that
  evidence exists, the follow-up implementation should target only the failing
  family.

### UIUX-R26 - Expand contrast and non-color status proof

- Slice ID: UIUX-R26
- Title: Verify contrast and color-independent status cues
- Findings addressed: `MASTER-VA-007`
- Problem: Some contrast pairs are tested, but many opacity/status/video
  overlay pairs are not, and some meaning uses color/opacity.
- Minimal remediation strategy: Add representative contrast checks and add text
  or shape cues only where a status depends on color/opacity alone. Avoid
  palette redesign.
- Files likely affected: `Sources/open-lola-app/AppDesignSystem.swift`,
  `Sources/open-lola-app/AppShellSupportViews.swift`,
  `Sources/open-lola-app/AppConsoleChromeView.swift`,
  `Sources/open-lola-app/AppLatencyHeroView.swift`,
  `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift`
- User behavior affected: Status and warning states remain readable across
  appearance and color-vision conditions.
- Runtime behavior affected, if any: None.
- Tests/manual checks to add: Contrast tests for badges, warnings, disabled
  text, selected cards, search, panels, and overlays; manual color-blind and
  increased-contrast check.
- Verification commands/checklist: `swift test --filter AppShellBehavior --no-parallel`;
  manual appearance-mode screenshots.
- Risk level: Medium.
- Rollback strategy: Revert token/cue changes and contrast tests.
- Definition of Done: Critical status meanings are not color-only, and tested
  contrast pairs cover representative components.

### UIUX-R27 - Establish minimum-window and long-text layout proof

- Slice ID: UIUX-R27
- Title: Add manual acceptance gate for 1024x720 and long text
- Findings addressed: `MASTER-VA-008`
- Problem: The app has a 1024x720 minimum, but layout scaling with long values,
  larger text, and constrained width is unproven.
- Minimal remediation strategy: Create a repeatable manual checklist and fixture
  values first. Only implement targeted layout fixes after failing evidence is
  captured.
- Files likely affected: `docs/testing.md`,
  `docs/uiux-remediation-plan.md`,
  later targeted UI files depending on failures found
- User behavior affected: Users on constrained displays or with large text get
  verified layout behavior after follow-up fixes.
- Runtime behavior affected, if any: None.
- Tests/manual checks to add: Minimum-window screenshots for every section in
  light/dark/increased-contrast with long paths, UIDs, commands, errors, and
  hostnames.
- Verification commands/checklist: Manual app-bundle screenshot pass; later
  focused UI tests if stable fixtures are available.
- Risk level: Low for checklist, variable for later fixes.
- Rollback strategy: Revert checklist changes if they do not match real
  workflow; code changes go in later slices.
- Definition of Done: There is a repeatable manual proof path for minimum
  window and long text before layout changes are made.

### UIUX-R28 - Decide audio meter diagnostic accessibility scope

- Slice ID: UIUX-R28
- Title: DECISION - audio meters overview or diagnostic control
- Findings addressed: `MASTER-VA-009`
- Problem: Meter accessibility exposes aggregate level data, but not
  per-channel values or clipping by channel.
- Minimal remediation strategy: Decide whether meters are overview-only or
  diagnostic. If diagnostic, plan a later small slice for per-channel detail or
  clipping summary.
- Files likely affected: `Sources/open-lola-app/AppChannelMeterView.swift`,
  `Sources/open-lola-app/AppPreviewReceiverView.swift`,
  `Tests/OpenLolaCoreTests/AppShellSlice05Tests.swift`
- User behavior affected: Screen-reader and low-vision expectations for meter
  detail become explicit.
- Runtime behavior affected, if any: None.
- Tests/manual checks to add: Manual VoiceOver check for 2, 8, 32, and 64
  channels; later accessibility value tests if scope expands.
- Verification commands/checklist: Manual meter accessibility pass; later
  `swift test --filter AppShellSlice05 --no-parallel`.
- Risk level: Low for decision, medium for implementation.
- Rollback strategy: Keep current overview semantics unless diagnostic scope is
  accepted.
- Definition of Done: A written decision states whether aggregate meter
  accessibility is sufficient and what proof is required.
- Decision, 2026-05-20: Current meters are overview-only. Source evidence shows
  `AppChannelMeterView` is a compact canvas strip with an aggregate
  accessibility value, and `AppCompactMeterStrip` limits the main operator
  surface to 8 visible channels. Do not add per-channel diagnostic UI to this
  surface without a product decision and 2/8/32/64 channel VoiceOver evidence.
  Current remediation is limited to making the overview scope explicit in the
  meter accessibility value and hint.

### UIUX-R29 - Verify preview overlay contrast before changing style

- Slice ID: UIUX-R29
- Title: INVESTIGATION - preview overlay and empty audio contrast
- Findings addressed: `MASTER-VA-010`
- Problem: Preview overlay and empty audio state contrast were not screenshot
  sampled.
- Minimal remediation strategy: Capture runtime screenshots with bright, dark,
  and noisy preview frames and long device names. Only make targeted contrast or
  wrapping changes if evidence fails.
- Files likely affected: `Sources/open-lola-app/AppPreviewReceiverView.swift`,
  `Tests/OpenLolaCoreTests/AppShellSlice05Tests.swift`
- User behavior affected: Preview captions and empty states become verified
  before style changes.
- Runtime behavior affected, if any: None.
- Tests/manual checks to add: Manual contrast sample and VoiceOver output for
  preview overlay/empty audio states.
- Verification commands/checklist: Manual local preview screenshot pass with
  camera enabled/disabled and representative frames.
- Risk level: Low for investigation, low-medium for localized implementation.
- Rollback strategy: No code change in investigation; revert localized overlay
  style if it regresses readability.
- Definition of Done: Runtime evidence either confirms current overlay/empty
  state readability or defines a targeted failing case to fix.
- Decision, 2026-05-20: Defer style changes until screenshot evidence exists.
  Source inspection found the video subtitle overlay rendered as white text on
  a black 55% opacity scrim over `AppVideoPreviewLayerView`, and the empty audio
  meter state rendered as caption/caption2 text on a secondary-opacity panel.
  The source audit finding is specifically that these states were not sampled
  against bright, dark, and noisy runtime frames. No targeted code change is
  justified without that runtime visual evidence. Required proof remains:
  light/dark/increased-contrast screenshots with camera enabled, camera
  disabled, audio preview disabled, audio meter idle, and audio meter failed
  states, plus manual contrast sampling where overlay text sits on real frames.

### UIUX-R30 - Establish visual/accessibility regression baseline

- Slice ID: UIUX-R30
- Title: Build repeatable app-shell visual/accessibility checks
- Findings addressed: `MASTER-VA-011`
- Problem: No automated screenshot, focus traversal, VoiceOver tree,
  hit-target, text-overflow, or full component contrast gate was found.
- Minimal remediation strategy: Start with a documented manual checklist and
  stable evidence paths. Automate only stable checks after manual pass proves
  value.
- Files likely affected: `docs/testing.md`,
  `scripts/`,
  `Tests/OpenLolaCoreTests/`,
  app-shell UI files only for later targeted fixes
- User behavior affected: Reduces chance of invisible accessibility/layout
  regressions.
- Runtime behavior affected, if any: None.
- Tests/manual checks to add: Manual checklist covering route screenshots,
  keyboard traversal, disabled states, long values, contrast, and VoiceOver
  spot checks.
- Verification commands/checklist: Manual checklist first; later automation
  command documented in `docs/testing.md`.
- Risk level: Low-medium for docs/checklist, medium-high for automation.
- Rollback strategy: Revert checklist/automation separately from UI changes.
- Definition of Done: A repeatable visual/accessibility verification path
  exists and is referenced by future UI slices.

### UIUX-R31 - Decide search scope before implementation

- Slice ID: UIUX-R31
- Title: DECISION - current-section filter versus global search
- Findings addressed: `MASTER-FLOW-012`
- Problem: The visible search field filters the current operator surface, but
  users may expect global route/task search.
- Minimal remediation strategy: Decide whether to rename it to "Filter current
  section" or implement global route/task search. Prefer rename unless a global
  search index is explicitly needed.
- Files likely affected: `Sources/open-lola-app/AppConsoleChromeView.swift`,
  `Sources/open-lola-app/AppShellRootView.swift`,
  `Tests/OpenLolaCoreTests/AppShellSlice05Tests.swift`
- User behavior affected: Search expectations become truthful.
- Runtime behavior affected, if any: None.
- Tests/manual checks to add: Placeholder/copy tests and filtered-empty state
  tests; if global search chosen, route navigation tests.
- Verification commands/checklist: `swift test --filter AppShellSlice05 --no-parallel`;
  manual search behavior check.
- Risk level: Low for rename, medium for global search.
- Rollback strategy: Revert copy/search-scope changes.
- Definition of Done: The search field label and behavior match exactly.
- Decision, 2026-05-20: Keep this as a section filter, not global route/task
  search. Source evidence shows `NativeAppShellSectionSearch.visibleSections`
  filters only section titles/IDs and there is no global index over current
  section content, tasks, commands, packet rows, settings, or docs. Rename copy
  to `Filter sections` and add an accessibility hint saying it filters the
  sidebar section list and does not search inside the current section.

### UIUX-R32 - Normalize evidence and LoLa vocabulary

- Slice ID: UIUX-R32
- Title: Create and apply a copy vocabulary map
- Findings addressed: `MASTER-FLOW-013`
- Problem: Labels vary across LoLa mode, Windows connector, source/synthetic
  evidence, runtime validation, remote stream, and packet evidence.
- Minimal remediation strategy: Create a small vocabulary map, then update only
  inconsistent copy where the source audit identified confusion. Do not rename
  public CLI commands or contracts casually.
- Files likely affected: `Sources/open-lola-app/AppConsoleModels.swift`,
  `Sources/open-lola-app/AppShellRootView.swift`,
  `Sources/open-lola-app/AppTransportView.swift`,
  `Sources/OpenLolaCore/Platform/NativeAppShellSurfaceContract.swift`,
  `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift`
- User behavior affected: Users can distinguish workflow, connector, source
  report, runtime validation, and packet evidence terms.
- Runtime behavior affected, if any: None.
- Tests/manual checks to add: Copy contract tests for key labels; manual scan
  of Overview, Validation, Session, Streams, Diagnostics, and menu labels.
- Verification commands/checklist: `swift test --filter AppShell --no-parallel`;
  manual route copy review.
- Risk level: Low-medium; broad copy updates can disturb literal tests.
- Rollback strategy: Revert copy map and label changes.
- Definition of Done: The app uses one documented vocabulary for evidence
  categories, and visible copy no longer mixes terms for the same concept.
- Decision, 2026-05-20: Add an app-local vocabulary map and normalize visible
  copy without renaming command IDs or CLI commands. Standard terms are
  `Windows LoLa connector`, `source/synthetic report`, `source/synthetic
  PARTIAL`, `current runtime evidence`, `packet evidence`, `remote packet
  evidence`, `remote plan unavailable`, and `remote plan only`. Updated labels
  include the refresh action title, Windows LoLa workflow display text,
  topbar/overview validation copy, remote evidence status, transport mode
  badge, validation row copy, and launch-verifier required accessibility
  labels. Protocol constants, environment variables, CLI names, and LoLa control
  message strings are intentionally unchanged.

## 1. Recommended Execution Order

1. UIUX-R01
2. UIUX-R02
3. UIUX-R03
4. UIUX-R04
5. UIUX-R05
6. UIUX-R06
7. UIUX-R07
8. UIUX-R08
9. UIUX-R09
10. UIUX-R10
11. UIUX-R11
12. UIUX-R12
13. UIUX-R13
14. UIUX-R14
15. UIUX-R15
16. UIUX-R16
17. UIUX-R17
18. UIUX-R18
19. UIUX-R19
20. UIUX-R31
21. UIUX-R20
22. UIUX-R21
23. UIUX-R22
24. UIUX-R23
25. UIUX-R24
26. UIUX-R25
27. UIUX-R26
28. UIUX-R27
29. UIUX-R28
30. UIUX-R29
31. UIUX-R30
32. UIUX-R32

## 2. P0/P1 Slices

- UIUX-R01: P0 stale validation/runtime evidence before Start.
- UIUX-R02: P1 unwired Stop-looking control.
- UIUX-R03: P1 stale validation shortcut.
- UIUX-R04: P1 first-run validation/evidence sequence.
- UIUX-R05: P1 planning-only connector workflows.

## 3. Low-Risk Quick Wins

- UIUX-R03: remove or wire stale validation shortcut text.
- UIUX-R17: add source/synthetic refresh feedback.
- UIUX-R18: surface copy failure and missing-log reasons.
- UIUX-R19: constrain preview window request copy.
- UIUX-R31: rename search field if current-section filtering remains the
  intended behavior.
- UIUX-R32: copy vocabulary map, provided no public command names are changed.

## 4. Blocked/Decision-Needed Items

- UIUX-R05: needs decision on planning-only connector mode treatment and exact
  CLI/docs handoff.
- UIUX-R16: needs decision on whether `.live` is active, future, or stale.
- UIUX-R25: needs runtime keyboard/focus evidence before custom focus styling.
- UIUX-R28: needs decision on whether audio meters are overview-only or
  diagnostic.
- UIUX-R29: needs screenshot/contrast evidence before visual changes.
- UIUX-R31: needs decision on current-section filter versus global search.

## 5. Final UI Verification Checklist

- Run focused Swift tests for each edited app-shell area before broader checks.
- Run `swift test --filter AppShell --no-parallel` after app-shell behavior,
  copy, readiness, and UI model changes.
- Run `swift test --filter NativeAppShell --no-parallel` after menu/action
  contract, surface contract, or native shell changes.
- Run `bash scripts/verify-docs.sh` for every docs or visible-copy plan update.
- For bundle-visible UI changes, run `./script/build_and_run.sh --verify` when
  practical, rerunning outside the sandbox if SwiftPM sandboxing fails.
- Manually verify the current app bundle for every slice that changes visible
  UI: route, state before action, action, state after action, and recovery path.
- For runtime-sensitive slices, verify no UI says connected, live, healthy,
  validated, ready, or PASS without current evidence.
- For accessibility/readability slices, capture 1024x720 screenshots in light,
  dark, and increased-contrast modes with long paths, UIDs, commands, packet
  payloads, and errors.
- Keyboard-tab through sidebar, topbar, transport, Packet Monitor, device
  cards, settings, dialogs, and warning banners.
- Check disabled controls have visible or accessible reasons.
- Check copy, open-log, artifact write, refresh, validation, Start, Stop, and
  preview-window actions have success/failure or unavailable feedback.
