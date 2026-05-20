# UI/UX State Behavior Audit

Date: 2026-05-20

Scope: macOS SwiftUI app UI surfaces under `Sources/open-lola-app/`, the native
app surface contract in `Sources/OpenLolaCore/Platform/NativeAppShellSurfaceContract.swift`,
and related UI behavior tests in `Tests/OpenLolaCoreTests/`.

This audit is docs-only. It traces controls through handlers, state, props, and
runtime dependencies where visible in source. If runtime behavior is not proven
from source or tests, it is marked as UNCLEAR.

## Method

- Reviewed SwiftUI views, menu command wiring, app state derivation, settings
  draft handling, execution controller state transitions, artifact actions,
  packet monitor states, receiver preview state, and app shell tests.
- Treated `connected`, `healthy`, `streaming`, `valid`, `ready`, `PASS`, and
  similar wording as requiring runtime/report evidence.
- Did not run the macOS app manually or inspect live screenshots in this audit.

## Positive State Behavior Evidence

- Menu actions are routed through `OpenLolaApp.handleAction(_:)`, and
  `Tests/OpenLolaCoreTests/AppShellSlice05Tests.swift:8-15` asserts that every
  contract action ID is handled by the app shell.
- Start is not a simple button press. `Sources/open-lola-app/AppTransportView.swift:241-247`
  requires an armed controller, available dry-run workflow, passing validation,
  and `executionController.hasValidatedRuntimeEvidence`.
- Validation blocks missing, stale, unreadable, and incomplete evidence through
  `Sources/open-lola-app/AppExecutionController.swift:303-401`, and the
  preflight model includes report readiness blockers in
  `Sources/open-lola-app/AppConsoleModels.swift:491-539`.
- Stop and quit flows use confirmation for active non-dry-run sessions through
  `Sources/open-lola-app/AppShellRootView.swift:144-172` and
  `Sources/open-lola-app/OpenLolaApp.swift:65-84`.
- Packet Monitor has a truthful empty state for missing capture reports in
  `Sources/open-lola-app/AppPacketMonitorView.swift:20-49`, and row generation
  errors surface a warning in `Sources/open-lola-app/AppPacketMonitorView.swift:174-185`.
- Inventory refresh exposes loading and warning states in
  `Sources/open-lola-app/AppLocalOperatorSurfaceView.swift:18-45` and
  `Sources/open-lola-app/AppLocalOperatorSurfaceView.swift:154-168`.
- Preview receiver services track permission, device, capture, and metering
  failures in `Sources/open-lola-app/AppReceiverPreviewServices.swift:83-155`
  and `Sources/open-lola-app/AppReceiverPreviewServices.swift:196-268`.

## Findings

### SB-001 - Start can remain enabled from stale validation evidence after runtime-affecting UI edits

- ID: SB-001
- Severity: P0
- File/component/control: `Sources/open-lola-app/AppTransportView.swift` /
  Start button; `Sources/open-lola-app/AppSettings.swift`; inline settings in
  `Sources/open-lola-app/AppLocalOperatorSurfaceView.swift`
- State or action affected: Runtime start gating after validation.
- Evidence:
  - Start availability is derived from `armedForExecution`,
    `dryRunAvailable`, `lastValidationResult`, and
    `hasValidatedRuntimeEvidence` in `Sources/open-lola-app/AppTransportView.swift:241-247`.
  - Runtime evidence scope checks report path, session token, latency metrics,
    and external connector report evidence in
    `Sources/open-lola-app/AppRuntimeEvidenceScope.swift:44-108`; it does not
    prove the current UI settings match the settings used for the validated
    report.
  - Settings commits mutate `operatorSurface`, `executionController.settings`,
    and preview defaults in `Sources/open-lola-app/AppSettings.swift:394-404`
    and `Sources/open-lola-app/AppSettings.swift:482-565`; no validation
    invalidation is visible there.
  - Inline controls mutate `operatorSurface` and `appSettings` directly, for
    example `Sources/open-lola-app/AppLocalOperatorSurfaceView.swift:268-279`
    and `Sources/open-lola-app/AppLocalOperatorSurfaceView.swift:486-534`.
- What the UI claims: A user can start after the current plan has been
  validated and backed by runtime evidence.
- What is actually proven: The previous report/session token can be validated;
  this audit did not find proof that every later runtime-affecting UI edit
  invalidates that validation.
- User/runtime impact: A user can validate one configuration, change ports,
  report path, connector settings, devices, buffer policy, or peer fields, and
  still see Start as available if the prior evidence remains accepted. In this
  project, a false run-readiness state can trigger wrong runtime behavior.
- Suggested remediation: Invalidate `lastValidationResult`, session-scoped
  evidence, and any run-readiness flag on every runtime-affecting settings or
  operator surface mutation. Add a report/config fingerprint and compare it
  before enabling Start.
- Test or manual verification needed: Add a UI/model test that validates a
  report, mutates a runtime setting, and asserts Start/preflight returns
  blocked until validation runs again. Manually repeat with settings and inline
  controls.
- Confidence: High for the missing traced invalidation; medium for exact
  runtime blast radius because not every mutated field has equal runtime effect.

### SB-002 - Command Intent Stop is metadata-only and does not stop a running process

- ID: SB-002
- Severity: P1
- File/component/control: `Sources/open-lola-app/AppLocalOperatorSurfaceView.swift`
  / `Intent: Stop` button in `AppCommandIntentPanel`
- State or action affected: Stop command intent versus actual supervisor stop.
- Evidence:
  - `Intent: Stop` only assigns
    `operatorSurface.commandIntent = .stopRequested` in
    `Sources/open-lola-app/AppLocalOperatorSurfaceView.swift:560`.
  - The same panel disables Handoff, Start, Run, and Clear Intent while inputs
    are locked, but Stop is not disabled there in
    `Sources/open-lola-app/AppLocalOperatorSurfaceView.swift:553-562`.
  - Actual stop paths call `executionController.stop()` through
    `Sources/open-lola-app/AppTransportView.swift:300-303` and
    `Sources/open-lola-app/AppShellRootView.swift:156-172`.
- What the UI claims: The user can request Stop from the command intent panel.
- What is actually proven: The button updates local intent state only; no
  traced runtime stop request or confirmation path is invoked.
- User/runtime impact: During an active run, the UI can show a stop-requested
  intent while the process continues running. This is a misleading state/action
  split on a high-risk runtime surface.
- Suggested remediation: Either wire this control to the same confirmed stop
  path as the transport/menu Stop controls, or relabel it as intent metadata and
  disable it during locked/running states with help text.
- Test or manual verification needed: Add a test that presses this control
  while `executionController.isRunning == true` and asserts whether the process
  stop path is invoked or the control is unavailable.
- Confidence: High.

### SB-003 - Remote host label remains editable while runtime inputs are locked

- ID: SB-003
- Severity: P2
- File/component/control: `Sources/open-lola-app/AppLocalOperatorSurfaceView.swift`
  / Remote host label text field
- State or action affected: Locked runtime input state.
- Evidence:
  - The remote host text field binds directly to
    `operatorSurface.remoteInventory.hostName` in
    `Sources/open-lola-app/AppLocalOperatorSurfaceView.swift:94`.
  - The remote UID grid is disabled with `.disabled(inputsLocked)` in
    `Sources/open-lola-app/AppLocalOperatorSurfaceView.swift:107-118`, but the
    host label field is outside that disabled block.
  - Local selection and connection fields are disabled while inputs are locked
    in `Sources/open-lola-app/AppLocalOperatorSurfaceView.swift:48-87` and
    `Sources/open-lola-app/AppLocalOperatorSurfaceView.swift:124-148`.
- What the UI claims: Runtime-affecting inputs are locked while a run is active
  or the UI is otherwise in an input-locked state.
- What is actually proven: At least one remote inventory field remains mutable
  while adjacent remote fields are locked. Whether `hostName` affects runtime
  behavior or only display metadata is UNCLEAR from this audit.
- User/runtime impact: The user can create inconsistent remote inventory state
  during a run. If the label is serialized into plans or reports, displayed
  state can diverge from the active run.
- Suggested remediation: Apply the same input lock policy to the host label, or
  explicitly mark it as editable metadata and keep it out of runtime plans.
- Test or manual verification needed: Add a UI policy test for each remote
  inventory field under `inputsLocked`. Manually verify whether host label
  changes are serialized into run plans.
- Confidence: High for the lock mismatch; medium for runtime impact.

### SB-004 - Inventory refresh can overwrite user edits made during refresh

- ID: SB-004
- Severity: P2
- File/component/control: `Sources/open-lola-app/AppLocalOperatorInventory.swift`
  and `Sources/open-lola-app/AppLocalOperatorSurfaceView.swift` / Refresh
  Inventory
- State or action affected: Async inventory refresh and editable operator
  surface fields.
- Evidence:
  - Refresh snapshots the current surface, sets `isRefreshingInventory = true`,
    then asynchronously captures inventory in
    `Sources/open-lola-app/AppLocalOperatorInventory.swift:17-47`.
  - The captured next surface preserves many values from the old snapshot,
    including command intent, session mode, control mode, remote inventory, and
    connector fields in `Sources/open-lola-app/AppLocalOperatorInventory.swift:21-40`
    and `Sources/open-lola-app/AppLocalOperatorInventory.swift:59-79`.
  - The visible refresh button is disabled while refreshing in
    `Sources/open-lola-app/AppLocalOperatorSurfaceView.swift:34-44`, but this
    audit did not find a global edit lock tied to `isRefreshingInventory`.
- What the UI claims: Refresh updates local media inventory.
- What is actually proven: A late refresh result can reapply values captured
  before user edits made during the refresh.
- User/runtime impact: Edits made while inventory refresh is in flight can be
  lost or made stale without warning, creating an unexpected plan/runtime
  configuration.
- Suggested remediation: Merge only the inventory fields returned by capture,
  preserve current user-edited fields at apply time, or lock the affected
  controls during refresh with visible reason text.
- Test or manual verification needed: Add a model test that starts refresh,
  mutates a field, completes refresh, and verifies the user edit is preserved or
  explicitly blocked.
- Confidence: Medium-high.

### SB-005 - Settings window draft can overwrite newer main-window settings

- ID: SB-005
- Severity: P2
- File/component/control: `Sources/open-lola-app/AppShellSettingsView.swift` /
  Settings window Save
- State or action affected: Stale settings draft versus current app/operator
  state.
- Evidence:
  - The settings draft loads from app state on appear in
    `Sources/open-lola-app/AppShellSettingsView.swift:290-292`.
  - Save commits the draft to `appSettings`, `operatorSurface`,
    `executionController.settings`, and preview state in
    `Sources/open-lola-app/AppShellSettingsView.swift:335-343`.
  - The commit mutates runtime-relevant fields in
    `Sources/open-lola-app/AppSettings.swift:394-404` and
    `Sources/open-lola-app/AppSettings.swift:482-565`.
  - This audit did not find source synchronization from later main-window
    changes back into an already open settings draft.
- What the UI claims: Unsaved edits stay local until Save.
- What is actually proven: A stale open draft can later be saved over newer
  app/operator state edited elsewhere.
- User/runtime impact: A user can open Settings, change routing/devices in the
  main window, then save old Settings values and silently revert those newer
  changes.
- Suggested remediation: Track draft dirtiness and source revision, warn on
  conflicts, or reload/disable save when source settings changed outside the
  window.
- Test or manual verification needed: Add a settings model test that opens a
  draft, mutates the live operator surface externally, saves the draft, and
  asserts conflict handling or preservation.
- Confidence: Medium-high.

### SB-006 - Artifact panel can show stale generated content after paste, import, or failure

- ID: SB-006
- Severity: P2
- File/component/control: `Sources/open-lola-app/AppOperatorArtifactViews.swift`
  / artifact actions and generated artifact display
- State or action affected: Generated artifact status and displayed content.
- Evidence:
  - The panel keeps shared `status` and `generatedArtifact` state in
    `Sources/open-lola-app/AppOperatorArtifactViews.swift:9-12`.
  - Paste/import actions update status but do not clear `generatedArtifact` in
    `Sources/open-lola-app/AppOperatorArtifactViews.swift:109-125`.
  - `setFailureStatus` updates status and error only, without clearing the
    previously generated artifact, in
    `Sources/open-lola-app/AppOperatorArtifactViews.swift:213-217`.
  - The generated artifact display remains visible whenever
    `generatedArtifact` is non-nil in
    `Sources/open-lola-app/AppOperatorArtifactViews.swift:75-82`.
- What the UI claims: The visible generated artifact corresponds to the latest
  artifact action/status.
- What is actually proven: After paste/import/failure, the visible artifact can
  be content from an earlier unrelated action.
- User/runtime impact: The user can copy or trust stale plan/inventory/command
  content after a later failed or different operation.
- Suggested remediation: Clear generated content on unrelated actions and all
  failures, or store action-scoped generated artifacts with labels that identify
  the producing action and timestamp.
- Test or manual verification needed: Add a UI state test that generates an
  artifact, triggers a failing import or paste, and asserts stale content is not
  displayed as current.
- Confidence: High.

### SB-007 - Audio meters can be displayed during supervisor running even when local audio preview failed

- ID: SB-007
- Severity: P2
- File/component/control: `Sources/open-lola-app/AppPreviewReceiverView.swift`
  / audio meters
- State or action affected: Audio meter visibility and preview failure state.
- Evidence:
  - Meter visibility returns true when audio preview is enabled and either the
    execution phase is `.supervisorRunning` or audio preview phase is `.active`
    in `Sources/open-lola-app/AppPreviewReceiverView.swift:430-437`.
  - Audio meter start can fail because there is no input, permission is denied,
    or tap installation fails in
    `Sources/open-lola-app/AppReceiverPreviewServices.swift:196-268`.
  - The meter view displays level bars when visibility is true, then status text
    below, in `Sources/open-lola-app/AppPreviewReceiverView.swift:328-357`.
- What the UI claims: Audio meters are present during an active session or
  active preview.
- What is actually proven: During `.supervisorRunning`, the meter surface can
  be visible even if local preview metering is not active. The status text may
  show failure, but the meter presence itself is not proof of active metering.
- User/runtime impact: A user can mistake blank or static meters for working
  live metering while input permission/device setup failed.
- Suggested remediation: Gate meter bars on actual audio preview phase
  `.active`; show an explicit degraded/error empty state when a supervisor is
  running but local metering is unavailable.
- Test or manual verification needed: Add a policy test for
  `.supervisorRunning` plus failed audio preview phase, and manually verify the
  receiver window with microphone permission denied.
- Confidence: Medium-high.

### SB-008 - Live session state appears stale or unreachable from traced state derivation

- ID: SB-008
- Severity: P2
- File/component/control: `Sources/open-lola-app/AppSessionStateBanner.swift`
  / live banner state
- State or action affected: Session lifecycle banner and runtime state model.
- Evidence:
  - The banner has a `.live` state with "Live session in progress" messaging in
    `Sources/open-lola-app/AppSessionStateBanner.swift:120-125`.
  - The traced `AppSessionState.derive(...)` implementation returns running,
    validating, supervisor running, error, ready, validated, awaiting evidence,
    connecting, armed, and unconfigured states in
    `Sources/open-lola-app/AppSessionStateBanner.swift:209-258`.
  - This audit did not find a branch in that derivation that returns `.live`.
- What the UI claims: "Live session in progress" is a supported operator state.
- What is actually proven: The source contains a live presentation state, but
  no traced producer for it in the current derivation. Reachability is UNCLEAR.
- User/runtime impact: If live is intended to represent a real streaming state,
  the operator may never see it. If it is obsolete, tests and warning policies
  can preserve a stale mental model.
- Suggested remediation: Define the evidence required for `.live` and produce
  it from measured runtime state, or remove/rename the stale state and tests.
- Test or manual verification needed: Add a lifecycle test that drives the
  runtime state expected to be live and asserts the banner state. Manually
  verify after a real or simulated validated session.
- Confidence: Medium.

### SB-009 - Synthetic metrics refresh has no visible loading or failure state

- ID: SB-009
- Severity: P3
- File/component/control: `Sources/open-lola-app/OpenLolaApp.swift` /
  Refresh Metrics menu/toolbar action
- State or action affected: Synthetic report refresh feedback.
- Evidence:
  - Refresh starts a detached synthetic smoke run and assigns the result in
    `Sources/open-lola-app/OpenLolaApp.swift:202-210`.
  - The handler is exposed through menu/contract actions in
    `Sources/open-lola-app/OpenLolaApp.swift:115-120`.
  - This audit did not find an `isRefreshingReport` flag, progress indicator,
    or user-facing failure state for this refresh path.
- What the UI claims: The user can refresh metrics.
- What is actually proven: The report is replaced after completion; progress
  and failure visibility are not traced in this path.
- User/runtime impact: A slow or unchanged refresh can look like a no-op, and
  stale placeholder/source-level metrics can remain visible without explaining
  whether refresh is still running.
- Suggested remediation: Add a small loading state and last-refresh outcome for
  synthetic metrics refresh, or make the action unavailable when refresh cannot
  fail and completes immediately.
- Test or manual verification needed: Add a UI model test for refresh in-flight
  state, or manually verify visible feedback while delaying the refresh.
- Confidence: Medium.

### SB-010 - Several copy actions hide pasteboard failures

- ID: SB-010
- Severity: P3
- File/component/control: Copy controls in
  `Sources/open-lola-app/AppPacketMonitorView.swift`,
  `Sources/open-lola-app/AppExecutionView.swift`,
  `Sources/open-lola-app/AppShellSupportViews.swift`, and
  `Sources/open-lola-app/AppShellRootView.swift`
- State or action affected: Copy-to-pasteboard feedback.
- Evidence:
  - `AppPasteboard.copyString(_:)` returns `Bool` in
    `Sources/open-lola-app/AppPasteboard.swift:11-20`.
  - Packet row copy ignores the result in
    `Sources/open-lola-app/AppPacketMonitorView.swift:165-173` and
    `Sources/open-lola-app/AppPacketMonitorView.swift:215-217`.
  - Command/log/report copy helpers ignore the result in
    `Sources/open-lola-app/AppExecutionView.swift:141-148` and
    `Sources/open-lola-app/AppExecutionView.swift:172-174`.
  - Additional support/root copy actions ignore the result in
    `Sources/open-lola-app/AppShellSupportViews.swift:164-173`,
    `Sources/open-lola-app/AppShellSupportViews.swift:286-287`, and
    `Sources/open-lola-app/AppShellRootView.swift:955-964`.
- What the UI claims: Copy buttons perform a copy action.
- What is actually proven: Some copy paths do not surface pasteboard failure.
  Artifact copy paths do check the result, so behavior is inconsistent.
- User/runtime impact: A user can believe a command/path/packet detail was
  copied when the pasteboard write failed.
- Suggested remediation: Centralize copy handling with success/failure status
  or a non-intrusive alert, and use it for every copy control.
- Test or manual verification needed: Inject a failing pasteboard helper and
  assert all copy controls surface failure consistently.
- Confidence: High.

### SB-011 - Disabled log-open buttons do not explain why logs are unavailable

- ID: SB-011
- Severity: P3
- File/component/control: `Sources/open-lola-app/AppExecutionView.swift` /
  `AppLogsView` stdout/stderr buttons
- State or action affected: Disabled state for opening logs.
- Evidence:
  - `stdout` and `stderr` buttons are disabled when
    `executionController.canOpenLogFile(...)` is false in
    `Sources/open-lola-app/AppExecutionView.swift:356-365`.
  - The `openLogFile` path can record errors when called in
    `Sources/open-lola-app/AppExecutionController.swift:424-433`, but disabled
    buttons cannot reach that error path.
  - This audit did not find help text beside these disabled controls.
- What the UI claims: Logs are unavailable when disabled.
- What is actually proven: The user is not told whether logs are missing,
  not created yet, removed, or inaccessible.
- User/runtime impact: The user cannot distinguish expected "no run yet" state
  from a failed log capture or filesystem problem.
- Suggested remediation: Add disabled help text or adjacent state explaining
  the missing log condition and expected path.
- Test or manual verification needed: Add a UI snapshot/model test for missing
  log paths and manually verify disabled button help.
- Confidence: High.

### SB-012 - Write Plan Artifact overwrites existing files without confirmation

- ID: SB-012
- Severity: P2
- File/component/control: `Sources/open-lola-app/AppOperatorArtifactViews.swift`
  / Write Plan Artifact
- State or action affected: Destructive artifact write.
- Evidence:
  - The Write Plan Artifact button directly calls `writePlanArtifact()` in
    `Sources/open-lola-app/AppOperatorArtifactViews.swift:51-57`.
  - The artifact writer creates the directory and writes JSON atomically to the
    target URL in
    `Sources/OpenLolaCore/Platform/NativeAppShellArtifacts.swift:137-147`.
  - This audit did not find an existence check, overwrite warning, or count of
    processed/skipped/failed artifacts for this write action.
- What the UI claims: Write the current two-peer run plan artifact.
- What is actually proven: The target file is written if possible; an existing
  file can be replaced without confirmation.
- User/runtime impact: A user can overwrite a previous plan artifact and lose
  the prior local configuration snapshot without warning.
- Suggested remediation: If the target file exists, show a confirmation with
  path and last modified time, or write a timestamped artifact and report
  written/skipped/failed counts.
- Test or manual verification needed: Add a test using an existing artifact
  path and assert confirmation or non-destructive behavior.
- Confidence: High.

### SB-013 - Can I Run? can show Ready before validation has proven current runtime evidence

- ID: SB-013
- Severity: P2
- File/component/control: `Sources/open-lola-app/AppConsoleModels.swift` and
  `Sources/open-lola-app/AppShellRootView.swift` / Validation `Can I Run?`
  preflight panel
- State or action affected: Run-readiness wording versus validation state.
- Evidence:
  - The preflight model returns `.ready` with "Ready" when there are no setup
    blockers, and the detail says the configuration is complete enough to
    "run or validate the current report path" in
    `Sources/open-lola-app/AppConsoleModels.swift:541-545`.
  - Start itself remains stricter because `AppTransportView` checks
    `lastValidationResult` and `hasValidatedRuntimeEvidence` in
    `Sources/open-lola-app/AppTransportView.swift:241-247`.
- What the UI claims: The `Can I Run?` panel can present Ready.
- What is actually proven: The model has enough setup to run or validate, but
  Start may still be blocked until validation and runtime evidence are current.
- User/runtime impact: The panel title and "Ready" label can be read as full
  run readiness even when the actual Start control remains disabled.
- Suggested remediation: Split setup readiness from run readiness, for example
  "Ready to validate" versus "Ready to start", or include the remaining
  validation/evidence requirement in the state label.
- Test or manual verification needed: Add a UI state test for no setup blockers
  plus no successful validation, and verify the copy distinguishes validate
  readiness from start readiness.
- Confidence: High.

### SB-014 - Open Preview Window request status is not reconciled with window launch success

- ID: SB-014
- Severity: P3
- File/component/control: `Sources/open-lola-app/OpenLolaApp.swift` /
  `openPreviewWindow` action
- State or action affected: Preview window request feedback.
- Evidence:
  - The handler sets `receiverStatus = "Local preview window requested."` and
    calls `openWindow(id: "receiver-preview")` in
    `Sources/open-lola-app/OpenLolaApp.swift:159-163`.
  - Receiver preview content has detailed runtime error states after the window
    exists, but this audit did not find a failure or timeout state for the
    window-open request itself.
- What the UI claims: A local preview window was requested.
- What is actually proven: The request handler ran; window creation/display is
  not explicitly confirmed in the traced state.
- User/runtime impact: If the window fails to appear or is blocked, the user
  gets no reconciled error in the source traced here.
- Suggested remediation: Track preview window lifecycle or avoid implying more
  than "request sent"; surface a recovery hint when the window is unavailable.
- Test or manual verification needed: Manually verify the preview menu action
  under normal and failure/unavailable window scenarios.
- Confidence: Medium.

## 1. False-success UI states

- SB-001 is the highest-risk false-success state: current run readiness can be
  based on evidence validated before runtime-affecting UI edits.
- SB-013 is a wording/model false-success risk: `Can I Run?` can say Ready for
  setup readiness while actual Start remains blocked by validation/evidence.
- SB-007 can visually imply active metering when local audio meter startup has
  failed, although status text may still show the failure.
- SB-008 is an UNCLEAR/stale state risk: `.live` exists as a presentation state
  but was not traced to a producer in `AppSessionState.derive(...)`.

## 2. Broken or unwired controls

- SB-002: `Intent: Stop` is not wired to the same runtime stop path as the
  transport/menu Stop controls.
- SB-010: several copy controls ignore pasteboard failure even though the
  pasteboard helper returns success/failure.
- SB-014: preview window request status is not reconciled with confirmed window
  display.

## 3. Missing loading/empty/error states

- SB-009: synthetic metrics refresh has no visible loading/failure state.
- SB-011: disabled log-open buttons do not explain the missing-log state.
- SB-006: artifact failure states can leave stale generated content visible.
- Positive evidence: Packet Monitor, inventory refresh, validation readiness,
  execution errors, and preview receiver failures have explicit empty/error
  states in the traced source.

## 4. Settings/runtime mismatch

- SB-001: runtime-affecting edits do not visibly invalidate validation evidence.
- SB-003: one remote inventory field remains editable while adjacent fields are
  locked.
- SB-004: async inventory refresh can reapply stale snapshot fields.
- SB-005: the settings draft can overwrite newer main-window edits.

## 5. Suggested UI State Tests

- Validate report, mutate each runtime-affecting setting category, and assert
  Start/preflight/validation evidence are invalidated.
- Press or model `Intent: Stop` during a running session and assert either the
  real stop path is invoked or the control is disabled/relabelled.
- Enter `inputsLocked` and assert every runtime-affecting field is disabled or
  explicitly marked as metadata-only.
- Complete inventory refresh after editing a field during refresh and assert
  the user edit is preserved or the edit was blocked.
- Save a stale settings draft after external settings changes and assert
  conflict handling.
- Generate an artifact, trigger a failing import/paste/write, and assert stale
  generated content is cleared or labelled as old.
- Deny microphone permission and start a supervisor state; assert audio meter
  bars do not imply active local metering.
- Drive the session lifecycle expected to be `.live` and assert whether the
  banner reaches `.live` or the state is removed.
- Inject pasteboard failure and assert all copy controls surface an error.
- Render missing-log states and assert disabled controls include reason text.

## 6. Remaining uncertainty

- This audit did not launch the app or capture live screenshots, so window
  lifecycle, focus behavior, and actual macOS menu enablement were not manually
  verified.
- Exact runtime impact of `remoteInventory.hostName` is UNCLEAR without tracing
  every downstream plan/report use.
- `.live` reachability is UNCLEAR from the traced derivation. It may be
  intentionally reserved for future runtime evidence, but no current producer
  was found in this audit.
- The synthetic metrics refresh path may be practically instantaneous and
  nonthrowing; the UI still lacks traced in-flight feedback.
- Some source line numbers may drift after later edits; findings should be
  verified against current source before implementation.
