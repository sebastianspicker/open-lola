# UI/UX Flow Audit

Status: static source audit of the current checkout on 2026-05-20.

Scope: user flows, navigation, information architecture, menu structure, screen
transitions, discoverability, naming, progressive disclosure, destructive
actions, settings paths, duplicate workflows, dead ends, and recovery paths in
the native app and related terminal surfaces.

Method: findings below are inferred from source, tests, labels, visible
structure, and active docs only. The app was not launched. No production code,
tests, or UI behavior were changed. If intended UX was unclear from the code, it
is called out as unclear.

No P0 finding was proven by static evidence. The most dangerous start/run path
is safety-gated in source and tests, but several P1/P2 flow issues can still
block or confuse task completion.

## Findings

### UXF-001 - Settings advertises a validation shortcut that is not wired

- ID: UXF-001
- Severity: P1
- File/component/menu: `Sources/open-lola-app/AppShellSettingsTabs.swift` `AppExecutionSettingsTab`; `Sources/OpenLolaCore/Platform/NativeAppShellSurfaceContract.swift` `validate-supervisor-report`
- User flow affected: Keyboard-driven validation from Settings or app menu.
- Evidence: `AppExecutionSettingsTab` shows `Shortcut: Command-Shift-V` in the Execution tab. The action inventory defines `validate-supervisor-report` with `keyboardShortcut: nil`, while `CommandMenu("Open LoLa")` applies shortcuts only from the action contract.
- Why it hurts task completion: A user trying to validate the supervisor report from the advertised shortcut gets no visible action. Validation is a core step before start/run, so this is a serious discoverability and trust problem.
- Suggested remediation: Either wire `Command-Shift-V` to `Validate Supervisor Report` in the action contract and menu tests, or remove the shortcut text from Settings.
- Verification needed: Focused app-shell/menu contract test for the validation shortcut plus launch/accessibility label verification that the shortcut copy matches the menu action.
- Confidence: High.

### UXF-002 - JackTrip and UltraGrid are selectable in the primary workflow picker but cannot run in the app

- ID: UXF-002
- Severity: P1
- File/component/menu: `AppWorkflowModeSelectorView`, `AppWorkflowUnavailableView`, `NativeAppShellSessionMode`
- User flow affected: Selecting a workflow and attempting to configure/run it.
- Evidence: The Devices workflow picker iterates `NativeAppShellSessionMode.allCases`, including `JackTrip` and `UltraGrid`. `NativeAppShellSessionMode.supportsAppExecution` returns false for both, and `unavailableAppReason` says they are selectable for operator planning but have no wired runtime launcher. The unavailable view says to switch to a supported workflow in Settings.
- Why it hurts task completion: The main setup flow presents non-runnable modes beside runnable modes, then dead-ends users who thought they were choosing an executable workflow. The recovery copy points to Settings even though the same picker is on Devices.
- Suggested remediation: Separate executable app workflows from planning-only connector workflows, or make the picker label and recovery action explicitly say "planning only" with a direct link to the relevant external CLI/documented workflow.
- Verification needed: App-shell tests for picker labels, unsupported-mode recovery target, and disabled run/arm behavior; launch screenshot or accessibility verification for the visible copy.
- Confidence: High.

### UXF-003 - The first-run start path can read as circular around validation and evidence

- ID: UXF-003
- Severity: P1
- File/component/menu: `AppTransportView`, `AppTransportStartPolicy`, `AppValidationPreflightModel`, `AppOverviewOperatorSummary`
- User flow affected: Configure, dry-run, validate, and start a first session.
- Evidence: `AppTransportStartPolicy.canStart` requires armed execution, dry-run availability, `lastValidationResult == .passed`, and `hasValidatedRuntimeEvidence`. Start help says to run a passing validation with current runtime evidence before starting. Validation preflight can say "Run or load a current PASS supervisor or external connector report." Overview can say "Arm or dry-run" or "Resolve evidence gap."
- Why it hurts task completion: The safety gate is correct, but the flow copy does not present one linear path for a new operator: configure, create/run report, validate current evidence, then start. A user can see Start disabled and Validate blocked without understanding which artifact-producing step comes next.
- Suggested remediation: Add a single evidence/readiness stepper or next-action sequence that distinguishes "write plan", "dry run / produce report", "validate report", and "start live run".
- Verification needed: Unit tests for next-action text across unconfigured, configured-no-report, dry-run-complete, validation-failed, evidence-incomplete, and ready-to-start states; visual smoke of the Session and Validation surfaces.
- Confidence: Medium.

### UXF-004 - Packet Monitor is both dimmed/unavailable and a recovery destination

- ID: UXF-004
- Severity: P2
- File/component/menu: `AppConsoleSidebarView`, `AppUnavailableSectionView`, `AppPacketMonitorView`, `AppPacketMonitorEmptyState`
- User flow affected: Discovering packet evidence after a run.
- Evidence: Sidebar dims Packet Monitor with help `Available after session validation` when no capture report exists. `AppUnavailableSectionView` can say Packet Monitor is unavailable until a decoded capture report is loaded. The Packet Monitor route itself has a `No capture data yet` empty state with a `Run and validate evidence` action once the route is reachable.
- Why it hurts task completion: A user may avoid a dimmed route that actually contains the explanation for how to produce packet evidence. Search/unavailable copy and route empty-state copy also describe slightly different states.
- Suggested remediation: Keep Packet Monitor reachable after setup, but make sidebar state say "No capture yet" rather than implying the section is unavailable. Align the search/no-match state with the route empty state.
- Verification needed: Tests for sidebar copy, search copy, and Packet Monitor empty-state route availability; launch/accessibility evidence that Packet Monitor remains reachable with no capture.
- Confidence: High.

### UXF-005 - Settings are split across a read-only sidebar route, the macOS Settings scene, and Devices

- ID: UXF-005
- Severity: P2
- File/component/menu: `AppShellSettingsSummaryView`, `AppShellSettingsView`, `AppWorkflowModeSelectorView`, `AppShellSlice05Tests`
- User flow affected: Finding where to change workflow, execution, peer, media, and preview settings.
- Evidence: The sidebar Settings section is a read-only summary with an `Open Settings` button. The native Settings scene is the mutable editor. Devices also contains the workflow/control mode picker and writes to `AppSettings`. Tests assert the sidebar is read-only and the native Settings scene is mutable.
- Why it hurts task completion: The same mental category, "settings", appears in two places, while a high-level setting, workflow mode, is also editable in Devices. Users may not know which surface is authoritative or whether changes are saved immediately.
- Suggested remediation: Make the Settings summary describe which settings can be changed on Devices versus the macOS Settings window, and keep one visible "edit settings" path per category.
- Verification needed: UI behavior tests for settings summary copy and workflow persistence; manual app smoke confirming the Settings route and native Settings scene are easy to distinguish.
- Confidence: High.

### UXF-006 - Execution controls compete across menu, transport, footer/topbar, and Command Intent

- ID: UXF-006
- Severity: P2
- File/component/menu: `CommandMenu("Open LoLa")`, `AppTransportView`, `AppConsoleTopBarView`, `AppConsoleFooterStripView`, `AppCommandIntentView`
- User flow affected: Choosing the right action to arm, dry-run, start, stop, validate, or set intent.
- Evidence: The app menu exposes `Write Two-Peer Plan`, `Dry Run Supervisor`, `Set Handoff Intent`, `Start Armed Supervisor`, `Stop Supervisor Run`, `Validate Supervisor Report`, and `Clear Command Intent`. The Session transport exposes Arm/Dry Run/Start/Stop/Validate. The topbar and footer also expose Stop. Devices exposes intent-only buttons: Handoff, Start, Run, Stop, Clear.
- Why it hurts task completion: Users must understand the difference between real execution, dry-run, generated plan, and command intent. The UI has several affordances with overlapping names but different side effects.
- Suggested remediation: Define one primary execution path in Session, move intent-only controls behind Advanced/diagnostic context, and make menu items mirror the primary controls with the same names and disabled reasons.
- Verification needed: App-shell tests that menu actions and transport actions share labels, enabled states, and intent side effects; launch/accessibility check that intent controls are not presented as primary run controls.
- Confidence: High.

### UXF-007 - Stop is available through several paths with different confirmation copy and policy

- ID: UXF-007
- Severity: P2
- File/component/menu: `OpenLolaApp`, `AppTransportView`, `AppConsoleTopBarView`, `AppConsoleFooterStripView`, `AppTransportStopConfirmationPolicy`
- User flow affected: Stopping or quitting while a supervisor/session is active.
- Evidence: The app has a quit confirmation, app-level stop confirmation, transport stop confirmation, topbar Stop, footer Stop, and menu Stop. Tests cover stop confirmation for live/supervisor-running states and skip confirmation for dry runs.
- Why it hurts task completion: Stop is a destructive runtime action, but users see several stop entry points and slightly different copy (`active session`, `live session`, `active supervisor run`). This increases the chance of uncertainty under pressure.
- Suggested remediation: Centralize stop copy and confirmation policy, and show the same active process/session identity from every stop entry point.
- Verification needed: Tests for one shared stop confirmation title/message and policy across menu, transport, topbar, and footer.
- Confidence: High.

### UXF-008 - Normal/Advanced progressive disclosure can hide fields needed to resolve blockers

- ID: UXF-008
- Severity: P2
- File/component/menu: `AppWorkflowModeSelectorView`, `AppLocalOperatorSurfaceView`, `AppShellSettingsTabVisibility`, `AppShellSlice05Tests`
- User flow affected: Resolving setup and validation blockers.
- Evidence: Normal direct mode shows only basic Mac-to-Mac connection fields; advanced direct mode adds artifact tools and peer network fields. Normal settings for direct mode show `Execution`, `Preview`, and `Snapshot`; advanced adds `Peers`, `Audio`, and `Video`. Windows LoLa advanced exposes ports, payload, and duration, while normal mode hides them.
- Why it hurts task completion: Validation failures often involve paths, ports, report artifacts, peer IDs, or media parameters. If the relevant controls are hidden behind Advanced, a user may not discover how to fix a blocker.
- Suggested remediation: When a blocker references a hidden advanced field, show an inline "Show Advanced" recovery action or reveal the specific field group needed for that blocker.
- Verification needed: Tests that blocker models identify target field groups and that normal-mode UI exposes an advanced recovery affordance.
- Confidence: Medium.

### UXF-009 - Remote inventory import is a fragile task path with weak recovery

- ID: UXF-009
- Severity: P2
- File/component/menu: `AppLocalOperatorSurfaceView`, `AppOperatorArtifactsView`, `AppRemoteInventoryImport`
- User flow affected: Completing a direct Mac-to-Mac two-peer plan.
- Evidence: Direct mode asks for remote input UID, output UID, and video device ID. Advanced artifact tools support Copy Local Inventory JSON, Paste Remote Inventory JSON, Import Remote Inventory JSON, a TextEditor, plan path fields, and reload/write plan actions. Artifact errors are shown in a generic `Artifact Error` alert.
- Why it hurts task completion: The flow depends on exchanging or manually entering exact remote device identifiers. There is no file picker, guided remote capture step, or structured recovery path if pasted JSON or manual IDs are wrong.
- Suggested remediation: Provide a guided remote inventory import path with explicit steps, import validation summary, and direct recovery to the field that failed.
- Verification needed: Tests for invalid JSON, missing device IDs, successful import, and next-action copy; manual smoke with pasteboard and file path failures.
- Confidence: High.

### UXF-010 - Local preview, remote stream status, and runtime evidence use overlapping mental models

- ID: UXF-010
- Severity: P2
- File/component/menu: `AppStreamsSectionView`, `AppPreviewReceiverView`, `AppReceiverWindowView`, `AppReceiverPreviewServices`, `RawBGRAAppKitPreviewSink`
- User flow affected: Monitoring media during setup or runtime.
- Evidence: Streams contains local Preview Controls/Routing and a remote stream panel. `Open Local Preview Window` opens a separate Local Device Preview window. Runtime code can create an AppKit RX preview window titled `Open LoLa RX Preview`. Preview services report local camera/meter statuses such as selected device unavailable, camera permission denied, and live video preview.
- Why it hurts task completion: A user may read local camera/meter health as remote media health, or confuse the local preview window with a received-stream preview. The app has multiple preview concepts but no single IA boundary naming local monitoring versus received media evidence.
- Suggested remediation: Rename or group preview surfaces by evidence type: local device monitor, remote stream report, and received media preview. Add a short status line that explicitly says local preview is not packet/media validation.
- Verification needed: UI text tests for preview/evidence labels and a manual launch check with preview enabled/disabled and no remote evidence.
- Confidence: Medium.

### UXF-011 - Empty device inventory and permission failures do not expose a complete recovery path

- ID: UXF-011
- Severity: P2
- File/component/menu: `AppLocalOperatorSurfaceView`, `AppLocalOperatorInventory`, `AppReceiverPreviewServices`
- User flow affected: First setup with missing audio/video devices or denied camera/microphone access.
- Evidence: Device sections show empty messages such as `No audio input devices found.` and `No video devices found.` Inventory warnings appear as an `Inventory Refresh Warning` alert. Preview services set status strings for camera permission denied/restricted, selected device unavailable, and video preview unavailable.
- Why it hurts task completion: Missing devices or denied permissions block setup, but the flow gives status/alert text rather than a recovery path to permissions, refresh, device selection, or diagnostics.
- Suggested remediation: Add a recovery panel for no devices/permission failures with links/actions to refresh inventory, open Diagnostics, and explain macOS privacy requirements.
- Verification needed: Unit tests for empty inventory models and permission-denied status copy; manual smoke with camera/microphone denied.
- Confidence: Medium.

### UXF-012 - Search discoverability is limited to the current operator surface

- ID: UXF-012
- Severity: P2
- File/component/menu: `AppConsoleTopBarView`, `AppConsoleStatusSnapshot`, `AppUnavailableSectionView`
- User flow affected: Finding routes, settings, packet evidence, or commands.
- Evidence: The search placeholder is `Filter current operator surface`. `AppUnavailableSectionView` shows `No matching section` when search text is active. Static inspection did not find a global search/index of routes, menu items, settings fields, or commands.
- Why it hurts task completion: Users may use the only visible search field to look for a task like "validate", "packet", or "settings", but it filters the current surface rather than navigating to all matching tasks.
- Suggested remediation: Either rename the field to "Filter current section" and constrain expectations, or implement route/task search with clear results and navigation targets.
- Verification needed: Tests for search placeholder/copy and filtered empty state; manual UI smoke of route/task search expectations.
- Confidence: High.

### UXF-013 - App-to-CLI handoff is unclear for planning-only connector workflows

- ID: UXF-013
- Severity: P2
- File/component/menu: `NativeAppShellSessionMode`, `AppExternalConnectorNoticeTab`, Swift CLI command registry
- User flow affected: Moving from app planning to external JackTrip/UltraGrid or connector CLI execution.
- Evidence: JackTrip and UltraGrid unavailable copy says to use external connector or NMP CLI contracts. The active app surfaces do not show a concrete next command for those modes in the inspected source. The Swift CLI exposes many commands through `open-lola`, and Python connector tools exist separately.
- Why it hurts task completion: The user is told to leave the app but not given a precise handoff target. That turns a blocked app workflow into a documentation/terminal search task.
- Suggested remediation: For planning-only modes, show the exact supported CLI command family or a copyable command template, with evidence that it is not run by the app.
- Verification needed: Command inventory tests that exposed app copy references an existing CLI command or docs path; launch/accessibility evidence for the connector notice.
- Confidence: Medium.

### UXF-014 - Naming varies across closely related LoLa and evidence concepts

- ID: UXF-014
- Severity: P3
- File/component/menu: `NativeAppShellSessionMode`, `AppTransportView`, `AppShellRootView`, `AppConsoleStatusSnapshot`, `NativeAppShellActionInventory`
- User flow affected: Understanding current mode, evidence source, and refresh semantics.
- Evidence: The app uses labels including `LoLa`, `Windows LoLa connector`, status mode `LOLA`, `Refresh Synthetic Metrics`, `Source-level PARTIAL`, `Remote unavailable`, and `LoLa not measured`.
- Why it hurts task completion: The varied naming is not necessarily wrong, but it forces users to learn which labels mean workflow mode, external connector, source baseline, synthetic report, or measured runtime evidence.
- Suggested remediation: Create a small vocabulary map for app copy and tests: workflow names, connector names, source/synthetic evidence, current runtime evidence, and packet evidence.
- Verification needed: Copy contract tests or snapshot/accessibility label checks for the shared vocabulary.
- Confidence: High.

### UXF-015 - Menus expose high-risk actions without visible disabled reasons

- ID: UXF-015
- Severity: P2
- File/component/menu: `CommandMenu("Open LoLa")`, `AppMenuActionPolicy`, `AppTransportView`
- User flow affected: Understanding why run, dry-run, validate, or arm actions are disabled.
- Evidence: Menu buttons are disabled by policy, but the menu button helper only applies the title, disabled state, and keyboard shortcut. Transport buttons have help text such as "Run a passing validation with current runtime evidence before starting" and "Validate the session report artifact."
- Why it hurts task completion: A disabled menu item gives less recovery guidance than the equivalent in-window control. Users who work from the menu bar can hit a dead end without knowing whether they need setup, arm, report generation, validation, or evidence.
- Suggested remediation: Mirror disabled reason text from transport/menu policy into menu help or add a status panel that updates when a menu action is unavailable.
- Verification needed: Policy tests for disabled reasons and launch/accessibility capture proving menu help/status text is visible.
- Confidence: Medium.

## Blocked Core Workflows

- JackTrip and UltraGrid app execution is blocked by design: the modes are
  selectable, but source and tests state that no app runtime launcher is wired.
- A first live start can be blocked by the validation/evidence gate without a
  single visible linear checklist explaining how to produce and validate the
  required current report.
- Direct Mac-to-Mac setup can be blocked by missing remote inventory IDs or
  invalid pasted inventory JSON, with limited guided recovery.
- First setup can be blocked by empty local device inventory or macOS privacy
  denial; static source shows status messages but no full recovery workflow.

## Confusing Workflows

- Settings are split between Devices, a read-only sidebar Settings route, and
  the native macOS Settings editor.
- Execution actions compete across menu, Session transport, Devices command
  intent, topbar, and footer.
- Local preview, remote stream status, packet evidence, and runtime validation
  are separate concepts but appear near each other in the operator console.
- Packet Monitor is dimmed when no capture is loaded even though its empty state
  is the place that explains how to produce packet evidence.
- Normal/Advanced controls hide some fields that can become necessary when a
  blocker or validation failure occurs.

## Navigation and Menu Issues

- The sidebar hierarchy is clear at a high level, but Setup, Session, Monitor,
  and Tools do not fully encode the actual task sequence from configuration to
  report evidence.
- The only visible search field filters the current operator surface; it does
  not appear to be global route/task search.
- Menu actions expose high-risk runtime tasks, but disabled menu items do not
  appear to carry the same recovery help as transport controls.
- Several stop entry points exist, and stop confirmation copy differs between
  app-level and transport-level surfaces.
- The Settings sidebar route is a gateway to a separate macOS scene rather than
  the editable settings surface itself.

## Suggested Information-Architecture Cleanup

1. Make the primary task sequence explicit: Configure, Produce Report, Validate
   Evidence, Start Live Run, Monitor Evidence.
2. Separate executable workflows from planning-only connector workflows in
   labels, grouping, and recovery actions.
3. Treat Session as the single primary execution surface; move intent/artifact
   tools into Advanced or Diagnostics unless they are part of the normal run
   path.
4. Align Settings, Devices, and Advanced controls around field ownership:
   workflow selection, device selection, execution paths, report paths, and
   media tuning should each have one obvious edit location.
5. Group evidence surfaces by proof type: source baseline, generated plan,
   current runtime report, packet capture, local preview, and remote stream.
6. Standardize vocabulary for LoLa mode, Windows LoLa connector, source-level
   PARTIAL, synthetic metrics, runtime validation, and packet evidence.

## Remaining Uncertainty

- This audit did not launch the app, inspect screenshots, use VoiceOver, or
  exercise keyboard navigation beyond explicit shortcut/source inspection.
- No hardware, camera, microphone, local network peer, Windows LoLa peer,
  JackTrip peer, UltraGrid peer, or external connector runtime was exercised.
- Some flow behavior depends on dynamic runtime reports and app launch evidence;
  static source can identify states but cannot prove how clearly they render.
- Command-specific CLI help was not exhaustively executed; terminal workflow
  consistency is therefore only partially audited.
- Archived UI/UX remediation docs were not treated as current authority.
