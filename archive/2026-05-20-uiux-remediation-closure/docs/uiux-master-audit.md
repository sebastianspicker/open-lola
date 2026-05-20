# UI/UX Master Audit

Date: 2026-05-20

Inputs:

- `docs/uiux-surface-index.md`
- `docs/uiux-flow-audit.md`
- `docs/uiux-visual-accessibility-audit.md`
- `docs/uiux-state-behavior-audit.md`

Output: consolidated UI/UX audit based only on the source documents above.

This document does not add new source-code findings. Consolidated findings
trace back to source audit IDs, preserve uncertainty from the inputs, and keep
conflicts or inconsistent source-audit framing visible.

## 1. Executive Summary

- Consolidated findings: 39.
- Severity distribution: 1 P0, 3 P1, 31 P2, 4 P3.
- Themes covered: FLOW, VISUAL_ACCESSIBILITY, and STATE_BEHAVIOR.
- Highest-risk issue: stale validation/runtime evidence can keep Start
  available after runtime-affecting UI edits (`MASTER-SB-001`, P0).
- Primary P1 flow risks: stale advertised validation shortcut, selectable
  planning-only workflows with no app launcher, and a circular first-run
  evidence path.
- The audits agree that core start/run paths have meaningful source-level
  safety gates, but the consolidated state audit identifies a high-risk stale
  validation gap that the flow audit did not cover as P0.
- The inputs are static audits. No source audit launched the current app bundle,
  used hardware, exercised peers/connectors, captured screenshots, ran
  VoiceOver, or manually verified menu/window runtime behavior.

## 2. Source Audit Coverage

| Source audit | Coverage used | Important limits preserved |
| --- | --- | --- |
| `docs/uiux-surface-index.md` | Inventory of screens, routes, menus, dialogs, settings, toolbars, sidebars, status indicators, forms, empty/loading/error/runtime states, reusable components, messages, shortcuts, workflows, unreachable/stale UI, missing states, and highest-risk surfaces. | Static source audit only. Some CLI/helper reachability, `RawBGRAAppKitPreviewSink`, old read-only views, settings visibility models, and helper terminal tools are marked UNCLEAR. |
| `docs/uiux-flow-audit.md` | 15 flow findings covering workflow blockers, navigation, IA, menu structure, duplicate workflows, dead ends, progressive disclosure, destructive actions, settings discoverability, and naming. | No app launch, no runtime peers/hardware, no command-specific CLI exhaustiveness. It states no P0 flow finding was proven by static evidence. |
| `docs/uiux-visual-accessibility-audit.md` | 14 visual/accessibility findings covering readability, truncation, contrast coverage, focus evidence, hit targets, disabled states, layout scaling, meter semantics, preview overlays, and missing visual/accessibility regression gates. | No screenshots, Accessibility Inspector, VoiceOver tree, or live app run. It states no confirmed P0/P1 visual or accessibility blocker was proven from static source alone. |
| `docs/uiux-state-behavior-audit.md` | 14 state/behavior findings covering stale validation evidence, unwired controls, input locking, async stale state, artifact state, preview/meters, live state reachability, copy errors, destructive writes, readiness wording, and window request reconciliation. | No live app/manual screenshots. Some runtime impact is UNCLEAR, especially `remoteInventory.hostName`, `.live` reachability, and synthetic metrics refresh behavior. |

## 3. Consolidated Findings Index

| ID | Theme | Severity | Source audits | Original finding IDs |
| --- | --- | --- | --- | --- |
| MASTER-FLOW-001 | FLOW | P1 | Flow, Surface Index | UXF-001, UI-MENU-009, UI-MSG-009 |
| MASTER-FLOW-002 | FLOW | P1 | Flow, Surface Index | UXF-002, UXF-013, UI-SCR-007 |
| MASTER-FLOW-003 | FLOW | P1 | Flow, Surface Index | UXF-003, UI-SCR-005, UI-SCR-010, UI-STATE-003 |
| MASTER-FLOW-004 | FLOW | P2 | Flow, Surface Index | UXF-004, UI-SCR-003, UI-STATE-004 |
| MASTER-FLOW-005 | FLOW | P2 | Flow, Surface Index | UXF-005, UI-SCR-012, UI-SCR-013 |
| MASTER-FLOW-006 | FLOW | P2 | Flow, Surface Index | UXF-006, UI-MENU-006 |
| MASTER-FLOW-007 | FLOW | P2 | Flow, Surface Index | UXF-007, UI-DLG-001, UI-DLG-002, UI-DLG-003, UI-MSG-001 |
| MASTER-FLOW-008 | FLOW | P2 | Flow | UXF-008 |
| MASTER-FLOW-009 | FLOW | P2 | Flow, Surface Index | UXF-009, UI-SCR-008, UI-MSG-006 |
| MASTER-FLOW-010 | FLOW | P2 | Flow, Surface Index | UXF-010, UI-SCR-006, UI-SCR-014, UI-SCR-015 |
| MASTER-FLOW-011 | FLOW | P2 | Flow, Surface Index | UXF-011, UI-STATE-006, UI-STATE-007, UI-STATE-010 |
| MASTER-FLOW-012 | FLOW | P2 | Flow, Surface Index | UXF-012, UI-SCR-002 |
| MASTER-FLOW-013 | FLOW | P3 | Flow, Surface Index | UXF-014, UI-MSG-003, UI-MSG-010, UI-MSG-011 |
| MASTER-FLOW-014 | FLOW | P2 | Flow, Surface Index | UXF-015, UI-MENU-001, UI-MENU-006 |
| MASTER-VA-001 | VISUAL_ACCESSIBILITY | P2 | Visual, Surface Index | VA-001, VA-004, UI-CMP-002, UI-CMP-005 |
| MASTER-VA-002 | VISUAL_ACCESSIBILITY | P2 | Visual, Surface Index | VA-002, UI-CMP-006 |
| MASTER-VA-003 | VISUAL_ACCESSIBILITY | P2 | Visual, Surface Index | VA-003, UI-SCR-011 |
| MASTER-VA-004 | VISUAL_ACCESSIBILITY | P2 | Visual, Surface Index | VA-005, VA-011, UI-CMP-003 |
| MASTER-VA-005 | VISUAL_ACCESSIBILITY | P2 | Visual | VA-006 |
| MASTER-VA-006 | VISUAL_ACCESSIBILITY | P2 | Visual | VA-007 |
| MASTER-VA-007 | VISUAL_ACCESSIBILITY | P2 | Visual, Surface Index | VA-008, VA-009, UI-CMP-003 |
| MASTER-VA-008 | VISUAL_ACCESSIBILITY | P2 | Visual | VA-010 |
| MASTER-VA-009 | VISUAL_ACCESSIBILITY | P2 | Visual, Surface Index | VA-012, UI-CMP-007 |
| MASTER-VA-010 | VISUAL_ACCESSIBILITY | P3 | Visual | VA-013 |
| MASTER-VA-011 | VISUAL_ACCESSIBILITY | P2 | Visual | VA-014 |
| MASTER-SB-001 | STATE_BEHAVIOR | P0 | State, Surface Index | SB-001, UI-SCR-005, UI-STATE-002 |
| MASTER-SB-002 | STATE_BEHAVIOR | P1 | State, Flow | SB-002, UXF-006 |
| MASTER-SB-003 | STATE_BEHAVIOR | P2 | State | SB-003 |
| MASTER-SB-004 | STATE_BEHAVIOR | P2 | State | SB-004 |
| MASTER-SB-005 | STATE_BEHAVIOR | P2 | State, Flow | SB-005, UXF-005 |
| MASTER-SB-006 | STATE_BEHAVIOR | P2 | State, Flow | SB-006, UXF-009 |
| MASTER-SB-007 | STATE_BEHAVIOR | P2 | State, Flow, Visual | SB-007, UXF-010, VA-012 |
| MASTER-SB-008 | STATE_BEHAVIOR | P2 | State, Surface Index | SB-008, UI-STATE-002 |
| MASTER-SB-009 | STATE_BEHAVIOR | P3 | State, Surface Index | SB-009, UI-MENU-002 |
| MASTER-SB-010 | STATE_BEHAVIOR | P3 | State, Surface Index | SB-010, UI-CMP-010 |
| MASTER-SB-011 | STATE_BEHAVIOR | P3 | State | SB-011 |
| MASTER-SB-012 | STATE_BEHAVIOR | P2 | State | SB-012 |
| MASTER-SB-013 | STATE_BEHAVIOR | P2 | State, Flow | SB-013, UXF-003 |
| MASTER-SB-014 | STATE_BEHAVIOR | P3 | State, Surface Index | SB-014, UI-SCR-014 |

## 4. Flow/Navigation Findings

### MASTER-FLOW-001 - Advertised validation shortcut is stale

- ID: MASTER-FLOW-001
- Source audit(s): `docs/uiux-flow-audit.md`, `docs/uiux-surface-index.md`
- Original finding ID(s): UXF-001, UI-MENU-009, UI-MSG-009
- Theme: FLOW
- Severity: P1
- File/component: `Sources/open-lola-app/AppShellSettingsTabs.swift` `AppExecutionSettingsTab`; `Sources/OpenLolaCore/Platform/NativeAppShellSurfaceContract.swift` `validate-supervisor-report`
- Evidence: Flow audit says Settings advertises `Command-Shift-V`, while the action inventory has `keyboardShortcut: nil`; the surface index separately marks the same shortcut text as stale.
- User impact: Keyboard-driven validation appears available but does nothing, undermining a core validation path.
- Runtime impact, if any: No direct runtime change, but users can fail to validate a supervisor report before run decisions.
- Suggested remediation: Wire `Command-Shift-V` to `Validate Supervisor Report` or remove the Settings shortcut text.
- Test/manual verification needed: Menu/action contract test plus app launch or accessibility verification that visible shortcut copy matches the menu.
- Risk of change: Low-medium; shortcut contracts and tests may need update.
- Confidence: High.

### MASTER-FLOW-002 - Planning-only connector workflows are selectable beside runnable workflows

- ID: MASTER-FLOW-002
- Source audit(s): `docs/uiux-flow-audit.md`, `docs/uiux-surface-index.md`
- Original finding ID(s): UXF-002, UXF-013, UI-SCR-007
- Theme: FLOW
- Severity: P1
- File/component: `AppWorkflowModeSelectorView`, `NativeAppShellSessionMode`, `AppExternalConnectorNoticeTab`, Routing surfaces
- Evidence: Flow audit says JackTrip and UltraGrid are selectable but `supportsAppExecution` is false and no app runtime launcher is wired; connector handoff copy points outside the app without a concrete command. The surface index marks these modes as selectable but constrained/planning-only.
- User impact: A user can choose a primary-looking workflow and hit a dead end when trying to run it.
- Runtime impact, if any: Prevents app execution for those modes by design; risk is misleading operator workflow rather than hidden runtime launch.
- Suggested remediation: Separate executable app workflows from planning-only connector workflows and show exact supported CLI/doc handoff for planning-only modes.
- Test/manual verification needed: Tests for picker labels, disabled run/arm behavior, unsupported-mode recovery copy, and CLI/doc target existence.
- Risk of change: Medium; affects workflow IA and copy across app and tests.
- Confidence: High for app non-runnability; medium for the best handoff target.

### MASTER-FLOW-003 - First-run evidence path is safety-gated but not linear enough

- ID: MASTER-FLOW-003
- Source audit(s): `docs/uiux-flow-audit.md`, `docs/uiux-surface-index.md`
- Original finding ID(s): UXF-003, UI-SCR-005, UI-SCR-010, UI-STATE-003
- Theme: FLOW
- Severity: P1
- File/component: `AppTransportView`, `AppTransportStartPolicy`, `AppValidationPreflightModel`, `AppOverviewOperatorSummary`
- Evidence: Flow audit says Start requires armed execution, dry-run availability, passing validation, and validated runtime evidence, while copy across Overview/Validation/Session does not present one clear first-run sequence.
- User impact: A new operator can see Start disabled and Validate blocked without knowing whether to write a plan, dry-run, produce/load a report, validate, or start.
- Runtime impact, if any: Safety gate reduces unsafe starts, but unclear sequencing can block task completion.
- Suggested remediation: Add one visible sequence: configure, produce report, validate evidence, start live run, monitor evidence.
- Test/manual verification needed: State tests for next-action text across unconfigured, configured-no-report, dry-run-complete, validation-failed, evidence-incomplete, and ready-to-start states; manual Session/Validation smoke.
- Risk of change: Medium; touches central operator copy and state model.
- Confidence: Medium.

### MASTER-FLOW-004 - Packet Monitor is dimmed as unavailable while also being a recovery destination

- ID: MASTER-FLOW-004
- Source audit(s): `docs/uiux-flow-audit.md`, `docs/uiux-surface-index.md`
- Original finding ID(s): UXF-004, UI-SCR-003, UI-STATE-004
- Theme: FLOW
- Severity: P2
- File/component: `AppConsoleSidebarView`, `AppUnavailableSectionView`, `AppPacketMonitorView`
- Evidence: Flow audit says the sidebar dims Packet Monitor and unavailable copy says a decoded capture report is needed, while Packet Monitor itself has a truthful "No capture data yet" recovery state. The surface index records the same dimmed route and empty state.
- User impact: Users may avoid the route that explains how to produce packet evidence.
- Runtime impact, if any: None direct; affects evidence discovery after runs.
- Suggested remediation: Keep Packet Monitor reachable after setup and label it "No capture yet" instead of implying the section is unavailable.
- Test/manual verification needed: Tests for sidebar copy, search/unavailable copy, and route empty-state reachability with no capture report.
- Risk of change: Low-medium; mostly navigation/copy.
- Confidence: High.

### MASTER-FLOW-005 - Settings ownership is split across Devices, a read-only Settings route, and the macOS Settings scene

- ID: MASTER-FLOW-005
- Source audit(s): `docs/uiux-flow-audit.md`, `docs/uiux-surface-index.md`
- Original finding ID(s): UXF-005, UI-SCR-012, UI-SCR-013
- Theme: FLOW
- Severity: P2
- File/component: `AppShellSettingsSummaryView`, `AppShellSettingsView`, `AppWorkflowModeSelectorView`
- Evidence: Flow audit says Settings is a read-only sidebar summary, mutable macOS Settings scene, and Devices also edits workflow/control mode. Surface index confirms the summary route and mutable Settings scene split.
- User impact: Users may not know where settings are authoritative or whether a setting saves immediately.
- Runtime impact, if any: Indirect; mis-edited settings can affect later runtime plans.
- Suggested remediation: Clarify field ownership by category and keep one obvious edit path per setting category.
- Test/manual verification needed: UI tests for settings summary copy and workflow persistence; manual smoke distinguishing Settings route from native Settings scene.
- Risk of change: Medium; IA changes can affect existing tests and stored settings workflows.
- Confidence: High.

### MASTER-FLOW-006 - Execution controls compete across menu, Session, footer/topbar, and Command Intent

- ID: MASTER-FLOW-006
- Source audit(s): `docs/uiux-flow-audit.md`, `docs/uiux-surface-index.md`
- Original finding ID(s): UXF-006, UI-MENU-006
- Theme: FLOW
- Severity: P2
- File/component: `CommandMenu("Open LoLa")`, `AppTransportView`, `AppConsoleTopBarView`, `AppConsoleFooterStripView`, `AppCommandIntentView`
- Evidence: Flow audit lists overlapping actions across menu, transport, topbar/footer, and Devices intent controls. Surface index inventories the menu execution and intent actions.
- User impact: Users must infer which controls actually run a process versus set intent metadata.
- Runtime impact, if any: Can cause wrong operational choice; related state-specific runtime risk is `MASTER-SB-002`.
- Suggested remediation: Make Session the primary execution path, move intent-only controls behind advanced/diagnostic context, and keep menu labels aligned with primary controls.
- Test/manual verification needed: Tests comparing menu and transport labels/enabled states/side effects; launch/accessibility check that intent controls are not presented as primary run controls.
- Risk of change: Medium-high; affects central task model and menu contract.
- Confidence: High.

### MASTER-FLOW-007 - Stop has several entry points with differing confirmation copy and policy

- ID: MASTER-FLOW-007
- Source audit(s): `docs/uiux-flow-audit.md`, `docs/uiux-surface-index.md`
- Original finding ID(s): UXF-007, UI-DLG-001, UI-DLG-002, UI-DLG-003, UI-MSG-001
- Theme: FLOW
- Severity: P2
- File/component: `OpenLolaApp`, `AppTransportView`, `AppConsoleTopBarView`, `AppConsoleFooterStripView`, stop confirmation dialogs
- Evidence: Flow audit records quit confirmation, app-level stop, transport stop, topbar Stop, footer Stop, and menu Stop with slightly different copy; surface index inventories the dialogs/messages.
- User impact: Under pressure, users can be unsure whether "active session", "live session", and "supervisor run" are the same stop target.
- Runtime impact, if any: Stop is destructive for an active supervisor/session.
- Suggested remediation: Centralize stop copy and confirmation policy with the same active process/session identity everywhere.
- Test/manual verification needed: Shared policy tests for stop title/message and confirmation behavior across all stop entry points.
- Risk of change: Medium; destructive action copy and policy need careful regression tests.
- Confidence: High.

### MASTER-FLOW-008 - Progressive disclosure can hide fields needed to resolve blockers

- ID: MASTER-FLOW-008
- Source audit(s): `docs/uiux-flow-audit.md`
- Original finding ID(s): UXF-008
- Theme: FLOW
- Severity: P2
- File/component: `AppWorkflowModeSelectorView`, `AppLocalOperatorSurfaceView`, `AppShellSettingsTabVisibility`
- Evidence: Flow audit says normal mode hides advanced peer, port, payload, duration, audio, and video fields that may be relevant to validation failures.
- User impact: Users may not discover the field required to clear a blocker.
- Runtime impact, if any: Misconfiguration can persist into generated plans until corrected.
- Suggested remediation: When a blocker refers to a hidden field, show a "Show Advanced" recovery action or reveal the specific field group.
- Test/manual verification needed: Tests that blockers map to field groups and expose advanced recovery affordances.
- Risk of change: Medium; progressive disclosure and blocker models need coordination.
- Confidence: Medium.

### MASTER-FLOW-009 - Remote inventory import path is fragile and weakly guided

- ID: MASTER-FLOW-009
- Source audit(s): `docs/uiux-flow-audit.md`, `docs/uiux-surface-index.md`
- Original finding ID(s): UXF-009, UI-SCR-008, UI-MSG-006
- Theme: FLOW
- Severity: P2
- File/component: `AppLocalOperatorSurfaceView`, `AppOperatorArtifactsView`, `AppRemoteInventoryImport`
- Evidence: Flow audit says direct mode depends on exact remote IDs and advanced artifact tools, with generic artifact errors. Surface index identifies device setup and artifact messages as active surfaces.
- User impact: Users can be blocked by invalid pasted JSON or wrong manual IDs without guided recovery.
- Runtime impact, if any: Incorrect remote inventory can produce unusable plans.
- Suggested remediation: Provide a guided import path with validation summary and direct recovery to failed fields.
- Test/manual verification needed: Tests for invalid JSON, missing IDs, successful import, pasteboard/file failures, and next-action copy.
- Risk of change: Medium; touches import validation and artifact UI.
- Confidence: High.

### MASTER-FLOW-010 - Local preview, remote stream status, and received-media preview share confusing mental models

- ID: MASTER-FLOW-010
- Source audit(s): `docs/uiux-flow-audit.md`, `docs/uiux-surface-index.md`
- Original finding ID(s): UXF-010, UI-SCR-006, UI-SCR-014, UI-SCR-015
- Theme: FLOW
- Severity: P2
- File/component: `AppStreamsSectionView`, `AppPreviewReceiverView`, `AppReceiverWindowView`, `RawBGRAAppKitPreviewSink`
- Evidence: Flow audit says local Preview, remote stream report, local preview window, and runtime RX preview can be confused. Surface index lists separate Streams, Local Preview, and `Open LoLa RX Preview` windows.
- User impact: Users may mistake local camera/meter health for remote media or packet evidence.
- Runtime impact, if any: Incorrect operational confidence about media health.
- Suggested remediation: Name/group surfaces by evidence type: local device monitor, remote stream report, received media preview, and packet/runtime validation.
- Test/manual verification needed: UI text tests for preview/evidence labels; manual launch with preview enabled/disabled and no remote evidence.
- Risk of change: Medium; naming changes may ripple through tests and docs.
- Confidence: Medium.

### MASTER-FLOW-011 - Empty device inventory and permission failures lack a complete recovery path

- ID: MASTER-FLOW-011
- Source audit(s): `docs/uiux-flow-audit.md`, `docs/uiux-surface-index.md`
- Original finding ID(s): UXF-011, UI-STATE-006, UI-STATE-007, UI-STATE-010
- Theme: FLOW
- Severity: P2
- File/component: `AppLocalOperatorSurfaceView`, `AppLocalOperatorInventory`, `AppReceiverPreviewServices`
- Evidence: Flow audit says missing device and permission states surface status text/alerts but no full recovery path. Surface index inventories device empty states, inventory warnings, and preview permission/error states.
- User impact: First setup can stall without a clear route to refresh, permissions, diagnostics, or device selection.
- Runtime impact, if any: Blocks setup and local preview.
- Suggested remediation: Add a recovery panel for no devices/permission failures with refresh, diagnostics, and macOS privacy guidance.
- Test/manual verification needed: Tests for empty inventory and permission-denied copy; manual smoke with camera/microphone denied.
- Risk of change: Medium; recovery UI must avoid overstating permission control.
- Confidence: Medium.

### MASTER-FLOW-012 - Search discoverability is limited to the current operator surface

- ID: MASTER-FLOW-012
- Source audit(s): `docs/uiux-flow-audit.md`, `docs/uiux-surface-index.md`
- Original finding ID(s): UXF-012, UI-SCR-002
- Theme: FLOW
- Severity: P2
- File/component: `AppConsoleTopBarView`, `AppConsoleStatusSnapshot`, `AppUnavailableSectionView`
- Evidence: Flow audit says the search placeholder is `Filter current operator surface` and no global route/task search was found. Surface index notes root search only filters the current operator surface.
- User impact: Users can search for tasks like validate, packet, or settings and get local filtering rather than navigation.
- Runtime impact, if any: None direct.
- Suggested remediation: Rename to "Filter current section" or implement explicit route/task search.
- Test/manual verification needed: Tests for search placeholder and filtered empty state; manual smoke for route/task search expectations.
- Risk of change: Low-medium; rename is low risk, global search is larger.
- Confidence: High.

### MASTER-FLOW-013 - Evidence and LoLa terminology is inconsistent

- ID: MASTER-FLOW-013
- Source audit(s): `docs/uiux-flow-audit.md`, `docs/uiux-surface-index.md`
- Original finding ID(s): UXF-014, UI-MSG-003, UI-MSG-010, UI-MSG-011
- Theme: FLOW
- Severity: P3
- File/component: `NativeAppShellSessionMode`, `AppTransportView`, `AppShellRootView`, `AppConsoleStatusSnapshot`, CLI messages
- Evidence: Flow audit lists varied labels such as `LoLa`, `Windows LoLa connector`, `LOLA`, `Refresh Synthetic Metrics`, `Source-level PARTIAL`, `Remote unavailable`, and `LoLa not measured`; surface index notes app and CLI evidence vocabulary drift.
- User impact: Users must learn which labels mean workflow, connector, source baseline, synthetic report, runtime evidence, or packet evidence.
- Runtime impact, if any: None direct, but confusing vocabulary can lead to wrong operational interpretation.
- Suggested remediation: Create and test a vocabulary map for workflow names, connector names, source/synthetic evidence, runtime validation, and packet evidence.
- Test/manual verification needed: Copy contract tests or snapshot/accessibility label checks against the vocabulary map.
- Risk of change: Low-medium; broad copy changes can affect tests.
- Confidence: High.

### MASTER-FLOW-014 - Disabled menu actions lack visible recovery reasons

- ID: MASTER-FLOW-014
- Source audit(s): `docs/uiux-flow-audit.md`, `docs/uiux-surface-index.md`
- Original finding ID(s): UXF-015, UI-MENU-001, UI-MENU-006
- Theme: FLOW
- Severity: P2
- File/component: `CommandMenu("Open LoLa")`, `AppMenuActionPolicy`, `AppTransportView`
- Evidence: Flow audit says menu buttons are policy-disabled but only apply title, disabled state, and shortcut; equivalent transport buttons have help text. Surface index also flags disabled reasons not visible in the menu.
- User impact: Menu-driven users can hit a dead end without knowing which prerequisite is missing.
- Runtime impact, if any: No direct runtime behavior; affects safe access to high-risk actions.
- Suggested remediation: Mirror disabled reasons into menu help/status or update a visible status panel when unavailable menu actions are selected.
- Test/manual verification needed: Policy tests for disabled reasons plus launch/accessibility evidence for visible help/status.
- Risk of change: Medium; macOS menu help capabilities may constrain implementation.
- Confidence: Medium.

## 5. Visual/Accessibility Findings

### MASTER-VA-001 - Long operational values can be hidden by truncation or horizontal scrolling

- ID: MASTER-VA-001
- Source audit(s): `docs/uiux-visual-accessibility-audit.md`, `docs/uiux-surface-index.md`
- Original finding ID(s): VA-001, VA-004, UI-CMP-002, UI-CMP-005
- Theme: VISUAL_ACCESSIBILITY
- Severity: P2
- File/component: `AppReadableValue`, `AppDeviceCard`, `AppConnectionTopologyView`, readable metrics/device cards
- Evidence: Visual audit says paths, UIDs, hostnames, and device IDs use single-line scroll/truncation patterns; surface index records these components as reusable value/device surfaces.
- User impact: Operators can miss the meaningful end of a path, UID, host, or report location.
- Runtime impact, if any: Misreading IDs/paths can cause wrong device or report choices.
- Suggested remediation: Add full-value affordances such as middle truncation plus copy/open, disclosure rows, or wrapping where vertical growth is acceptable.
- Test/manual verification needed: Minimum-window test with long report paths, Core Audio UIDs, video IDs, hostnames, and peer labels.
- Risk of change: Low-medium; visual layout changes can affect dense panels.
- Confidence: High.

### MASTER-VA-002 - Generated command displays can overflow or consume unstable space

- ID: MASTER-VA-002
- Source audit(s): `docs/uiux-visual-accessibility-audit.md`, `docs/uiux-surface-index.md`
- Original finding ID(s): VA-002, UI-CMP-006
- Theme: VISUAL_ACCESSIBILITY
- Severity: P2
- File/component: `AppExecutionView`, `AppOperatorPlanViews`, generated command displays
- Evidence: Visual audit cites two-axis command scroll views and long shell lines without stable wrapping/max-height behavior. Surface index identifies generated command display as an active operator component.
- User impact: Command review and copy verification are harder, especially for long executable or peer paths.
- Runtime impact, if any: Users may copy/run the wrong handoff command if review is poor.
- Suggested remediation: Keep copyability but add predictable wrapping, token grouping, or a stable expanded detail area.
- Test/manual verification needed: Use long executable paths and peer paths; verify visible review, keyboard scrolling, copy access, and focus order.
- Risk of change: Medium; command copy must remain exact.
- Confidence: High.

### MASTER-VA-003 - Packet table truncates diagnostic details

- ID: MASTER-VA-003
- Source audit(s): `docs/uiux-visual-accessibility-audit.md`, `docs/uiux-surface-index.md`
- Original finding ID(s): VA-003, UI-SCR-011
- Theme: VISUAL_ACCESSIBILITY
- Severity: P2
- File/component: `AppPacketMonitorView`
- Evidence: Visual audit says packet cells are caption-size monospaced text capped to two lines with middle truncation; surface index lists Packet Monitor as the packet capture inspection route.
- User impact: Exact payloads, addresses, candidates, or stream labels can be hidden during diagnostics.
- Runtime impact, if any: Misdiagnosis of packet evidence.
- Suggested remediation: Add selected-row detail or packet disclosure exposing full values without relying on tooltip/copy.
- Test/manual verification needed: Capture fixture with long payload/candidate strings; verify full row data through keyboard, screen reader, and visual inspection.
- Risk of change: Medium; packet monitor layout is dense and evidence-critical.
- Confidence: High.

### MASTER-VA-004 - Compact plain buttons and banner CTAs may have small hit targets

- ID: MASTER-VA-004
- Source audit(s): `docs/uiux-visual-accessibility-audit.md`, `docs/uiux-surface-index.md`
- Original finding ID(s): VA-005, VA-011, UI-CMP-003
- Theme: VISUAL_ACCESSIBILITY
- Severity: P2
- File/component: `AppShellSupportViews`, `AppPacketMonitorView`, `AppSessionStateBanner`, `AppOperatorPlanViews`
- Evidence: Visual audit says transport buttons have 44x44 hit targets, but copy/dismiss/banner controls often use `.buttonStyle(.plain)` without an explicit minimum.
- User impact: Copy, dismiss, and CTA controls can be harder to click in dense panels.
- Runtime impact, if any: None direct.
- Suggested remediation: Apply a shared compact-control minimum size and visible focus style where practical.
- Test/manual verification needed: Accessibility Inspector hit testing and keyboard traversal for copy/dismiss/banner controls.
- Risk of change: Low-medium; spacing changes can affect dense layouts.
- Confidence: High for small-control evidence; medium for banner truncation impact.

### MASTER-VA-005 - Disabled settings and preview controls rely on hidden help text

- ID: MASTER-VA-005
- Source audit(s): `docs/uiux-visual-accessibility-audit.md`
- Original finding ID(s): VA-006
- Theme: VISUAL_ACCESSIBILITY
- Severity: P2
- File/component: `AppShellSettingsView`, `AppShellSettingsTabs`, `AppPreviewReceiverView`
- Evidence: Visual audit says disabled settings/preview controls explain reasons with `.help(...)`, and tests assert help strings, but persistent visible explanation is not always present.
- User impact: Users may see disabled controls without knowing whether running state, unsupported mode, or another condition blocks editing.
- Runtime impact, if any: None direct, but can slow recovery from locked/unsupported states.
- Suggested remediation: Add nearby persistent reason text for locked settings and unsupported preview controls while keeping disabled states truthful.
- Test/manual verification needed: Keyboard-only and VoiceOver pass through locked settings and disabled preview controls.
- Risk of change: Low-medium; copy/layout changes.
- Confidence: High.

### MASTER-VA-006 - Focus treatment is clearer in transport than other dense controls

- ID: MASTER-VA-006
- Source audit(s): `docs/uiux-visual-accessibility-audit.md`
- Original finding ID(s): VA-007
- Theme: VISUAL_ACCESSIBILITY
- Severity: P2
- File/component: `AppTransportView` compared with sidebar, topbar, packet monitor, device cards, warning dismiss controls
- Evidence: Visual audit says transport controls define focus state/rings/hit targets, but equivalent custom focus treatment was not found for several other dense surfaces.
- User impact: Keyboard users may lose track of focus outside the transport strip.
- Runtime impact, if any: None direct.
- Suggested remediation: Define a consistent focus-visible policy and verify whether default macOS focus rings are sufficient before adding custom styling.
- Test/manual verification needed: Keyboard-tab through all sidebar sections and dense panels in light/dark/high-contrast modes with focused-state screenshots.
- Risk of change: Medium; focus styling can regress platform-native behavior if over-customized.
- Confidence: Medium.

### MASTER-VA-007 - Color, opacity, and contrast coverage is incomplete

- ID: MASTER-VA-007
- Source audit(s): `docs/uiux-visual-accessibility-audit.md`, `docs/uiux-surface-index.md`
- Original finding ID(s): VA-008, VA-009, UI-CMP-003
- Theme: VISUAL_ACCESSIBILITY
- Severity: P2
- File/component: `AppConsoleChromeView`, `AppShellSupportViews`, `AppLatencyHeroView`, `AppChannelMeterView`, `AppDesignSystem`
- Evidence: Visual audit says some contrast pairs are tested, but many system/opacity/status/video-overlay pairs are not; color/opacity cues appear in sidebar dots, dimmed rows, badges, latency cards, and meters.
- User impact: Status meaning can be missed under low vision, color-vision differences, light mode, or high-contrast mode.
- Runtime impact, if any: Misreading evidence or status severity.
- Suggested remediation: Pair color/opacity cues with persistent text/icon shape and expand contrast checks to representative component pairs.
- Test/manual verification needed: Contrast sampling and color-blind/grayscale/increased-contrast checks for badges, warnings, disabled text, search, panels, video overlay, and meters.
- Risk of change: Medium; design token changes can affect broad UI.
- Confidence: High.

### MASTER-VA-008 - Minimum-window and large-text layout scaling are unproven

- ID: MASTER-VA-008
- Source audit(s): `docs/uiux-visual-accessibility-audit.md`
- Original finding ID(s): VA-010
- Theme: VISUAL_ACCESSIBILITY
- Severity: P2
- File/component: `AppShellRootView`, `AppDesignSystem`
- Evidence: Visual audit says the app enforces 1024x720 minimum and a 240 point sidebar, but responsive breakpoints beyond that are not shown in source.
- User impact: Dense controls can become constrained on smaller displays, split-screen, large text, or localized strings.
- Runtime impact, if any: None direct.
- Suggested remediation: Treat 1024x720 as a tested minimum and add acceptance criteria for large text, long labels, and reduced visible width.
- Test/manual verification needed: Minimum-window screenshots for every section in light/dark/high-contrast mode with long text fixtures and larger system text.
- Risk of change: Medium; responsive layout changes can be broad.
- Confidence: High.

### MASTER-VA-009 - Audio meters lack proven diagnostic accessibility

- ID: MASTER-VA-009
- Source audit(s): `docs/uiux-visual-accessibility-audit.md`, `docs/uiux-surface-index.md`
- Original finding ID(s): VA-012, UI-CMP-007
- Theme: VISUAL_ACCESSIBILITY
- Severity: P2
- File/component: `AppChannelMeterView`
- Evidence: Visual audit says meters draw narrow canvas bars with color zones and expose aggregate accessibility, not per-channel values or clipping by channel. Surface index records the meter component as active local preview UI.
- User impact: Fine-grained channel diagnostics can be hard for many channels.
- Runtime impact, if any: Local metering diagnosis can be incomplete.
- Suggested remediation: Decide whether meters are overview-only or diagnostic. If diagnostic, expose selected/per-channel detail and non-color-coded clipping/warning summary.
- Test/manual verification needed: Test 2, 8, 32, and 64 channel displays with VoiceOver, high contrast, and color-blind simulation.
- Risk of change: Medium; meter semantics and performance should stay lightweight.
- Confidence: High.

### MASTER-VA-010 - Preview overlay and empty audio contrast need screenshot verification

- ID: MASTER-VA-010
- Source audit(s): `docs/uiux-visual-accessibility-audit.md`
- Original finding ID(s): VA-013
- Theme: VISUAL_ACCESSIBILITY
- Severity: P3
- File/component: `AppPreviewReceiverView`
- Evidence: Visual audit says video preview uses white subtitle text over semi-transparent black and empty audio state uses low-opacity secondary styling; no screenshot contrast sampling was done.
- User impact: Overlay readability can vary with bright/noisy video frames and long device names.
- Runtime impact, if any: None direct.
- Suggested remediation: Verify overlay contrast and caption length constraints before changing styling.
- Test/manual verification needed: Run preview with bright, dark, noisy frames and long device names; sample overlay contrast and VoiceOver output.
- Risk of change: Low-medium; overlay changes are localized.
- Confidence: Medium.

### MASTER-VA-011 - Visual/accessibility regression gates are incomplete

- ID: MASTER-VA-011
- Source audit(s): `docs/uiux-visual-accessibility-audit.md`
- Original finding ID(s): VA-014
- Theme: VISUAL_ACCESSIBILITY
- Severity: P2
- File/component: `Tests/OpenLolaCoreTests/` and app verification scripts
- Evidence: Visual audit says tests cover some labels, announcements, window minimums, and token contrast, but no automated screenshot, focus traversal, VoiceOver tree, hit-target, text-overflow, or full component contrast gate was found.
- User impact: Dense operator-console regressions can ship with source-level tests still green.
- Runtime impact, if any: None direct, but poor accessibility can block operation.
- Suggested remediation: Add a manual QA checklist first, then automate stable minimum-window screenshots, contrast samples, and accessibility-tree assertions.
- Test/manual verification needed: Create and document repeatable app-shell visual/accessibility smoke evidence.
- Risk of change: Low-medium for checklist, medium-high for automation infrastructure.
- Confidence: Medium.

## 6. State/Behavior Findings

### MASTER-SB-001 - Start can use stale validation evidence after runtime-affecting edits

- ID: MASTER-SB-001
- Source audit(s): `docs/uiux-state-behavior-audit.md`, `docs/uiux-surface-index.md`
- Original finding ID(s): SB-001, UI-SCR-005, UI-STATE-002
- Theme: STATE_BEHAVIOR
- Severity: P0
- File/component: `AppTransportView`, `AppSettings`, `AppLocalOperatorSurfaceView`, `AppRuntimeEvidenceScope`
- Evidence: State audit says Start availability uses prior validation/evidence, while settings and inline controls mutate runtime-affecting state without traced validation invalidation. Surface index marks execution/validation truthfulness as the highest-risk UI area.
- User impact: User can believe the current configuration is validated when evidence may belong to an earlier configuration.
- Runtime impact, if any: Can trigger wrong runtime behavior from a false run-readiness state.
- Suggested remediation: Invalidate validation result/session evidence on every runtime-affecting mutation and compare a report/config fingerprint before enabling Start.
- Test/manual verification needed: Validate a report, mutate each runtime-affecting setting category, and assert Start/preflight block until validation reruns.
- Risk of change: High; central safety gate and settings mutation paths.
- Confidence: High for missing traced invalidation; medium for per-field runtime blast radius.

### MASTER-SB-002 - Command Intent Stop is not wired to the runtime stop path

- ID: MASTER-SB-002
- Source audit(s): `docs/uiux-state-behavior-audit.md`, `docs/uiux-flow-audit.md`
- Original finding ID(s): SB-002, UXF-006
- Theme: STATE_BEHAVIOR
- Severity: P1
- File/component: `AppLocalOperatorSurfaceView` `AppCommandIntentPanel`
- Evidence: State audit says `Intent: Stop` only sets `operatorSurface.commandIntent = .stopRequested`; actual stop controls call `executionController.stop()`. Flow audit also flags competing execution/intent controls.
- User impact: User can press a Stop-looking control while the process keeps running.
- Runtime impact, if any: Misleading stop state on a high-risk runtime surface.
- Suggested remediation: Wire it to the confirmed stop path or relabel/disable it as intent metadata.
- Test/manual verification needed: Test pressing/modeling the control while running and assert stop path invocation or disabled/relabelled behavior.
- Risk of change: Medium-high; destructive stop semantics.
- Confidence: High.

### MASTER-SB-003 - Remote host label remains editable while inputs are locked

- ID: MASTER-SB-003
- Source audit(s): `docs/uiux-state-behavior-audit.md`
- Original finding ID(s): SB-003
- Theme: STATE_BEHAVIOR
- Severity: P2
- File/component: `AppLocalOperatorSurfaceView` remote host label field
- Evidence: State audit says remote UID fields are disabled under `inputsLocked`, but `operatorSurface.remoteInventory.hostName` text field is outside that disabled block.
- User impact: User can create inconsistent remote inventory state during locked/running state.
- Runtime impact, if any: UNCLEAR; source audit did not prove whether `hostName` is runtime-affecting or display metadata only.
- Suggested remediation: Apply the same lock policy or explicitly mark it editable metadata excluded from runtime plans.
- Test/manual verification needed: UI policy test for every remote inventory field under `inputsLocked`; trace whether host label is serialized into plans/reports.
- Risk of change: Low-medium; depends on downstream host label use.
- Confidence: High for lock mismatch; medium for runtime impact.

### MASTER-SB-004 - Inventory refresh can overwrite edits made while refresh is in flight

- ID: MASTER-SB-004
- Source audit(s): `docs/uiux-state-behavior-audit.md`
- Original finding ID(s): SB-004
- Theme: STATE_BEHAVIOR
- Severity: P2
- File/component: `AppLocalOperatorInventory`, `AppLocalOperatorSurfaceView`
- Evidence: State audit says refresh snapshots the current surface, then later applies captured values, while only the refresh button is visibly disabled.
- User impact: User edits during refresh can be lost or made stale without warning.
- Runtime impact, if any: Can produce unexpected plan/runtime configuration.
- Suggested remediation: Merge only captured inventory fields, preserve current user-edited values at apply time, or lock affected controls during refresh.
- Test/manual verification needed: Model test that starts refresh, mutates a field, completes refresh, and verifies preservation or explicit block.
- Risk of change: Medium; async state merge must be careful.
- Confidence: Medium-high.

### MASTER-SB-005 - Settings draft can overwrite newer main-window changes

- ID: MASTER-SB-005
- Source audit(s): `docs/uiux-state-behavior-audit.md`, `docs/uiux-flow-audit.md`
- Original finding ID(s): SB-005, UXF-005
- Theme: STATE_BEHAVIOR
- Severity: P2
- File/component: `AppShellSettingsView`, `AppSettings`
- Evidence: State audit says draft loads on appear and Save commits broad runtime settings without traced synchronization from later main-window edits. Flow audit separately identifies settings split across Devices and Settings.
- User impact: User can open Settings, edit elsewhere, then save stale Settings values over newer changes.
- Runtime impact, if any: Can revert runtime-relevant configuration.
- Suggested remediation: Track draft dirtiness/source revision, warn on conflicts, reload source changes, or make one editor authoritative.
- Test/manual verification needed: Settings test opening a draft, externally mutating live operator surface, saving, and asserting conflict handling or preservation.
- Risk of change: Medium-high; settings ownership and persistence.
- Confidence: Medium-high.

### MASTER-SB-006 - Artifact panel can display stale generated content after later actions fail or change context

- ID: MASTER-SB-006
- Source audit(s): `docs/uiux-state-behavior-audit.md`, `docs/uiux-flow-audit.md`
- Original finding ID(s): SB-006, UXF-009
- Theme: STATE_BEHAVIOR
- Severity: P2
- File/component: `AppOperatorArtifactViews`
- Evidence: State audit says shared `generatedArtifact` remains visible after paste/import/failure paths that only update status. Flow audit identifies remote inventory/artifact exchange as fragile.
- User impact: User can copy or trust an old plan/inventory/command after a later failed or unrelated artifact operation.
- Runtime impact, if any: Can feed stale artifact data into setup/run planning.
- Suggested remediation: Clear generated content on unrelated actions and failures, or label action-scoped artifacts with producer and timestamp.
- Test/manual verification needed: Generate artifact, trigger failing import/paste/write, assert stale content is cleared or labelled old.
- Risk of change: Medium; artifact panel state model.
- Confidence: High.

### MASTER-SB-007 - Audio meter surface can imply active metering despite local meter failure

- ID: MASTER-SB-007
- Source audit(s): `docs/uiux-state-behavior-audit.md`, `docs/uiux-flow-audit.md`, `docs/uiux-visual-accessibility-audit.md`
- Original finding ID(s): SB-007, UXF-010, VA-012
- Theme: STATE_BEHAVIOR
- Severity: P2
- File/component: `AppPreviewReceiverView`, `AppChannelMeterView`, `AppReceiverPreviewServices`
- Evidence: State audit says meter bars can show during `.supervisorRunning` even if audio preview phase is failed; flow audit flags local preview versus remote evidence confusion; visual audit flags meter semantic limitations.
- User impact: User can mistake blank/static meters for working local metering or remote media health.
- Runtime impact, if any: Misleading local monitoring state during runtime.
- Suggested remediation: Gate meter bars on actual metering phase and show degraded/error empty state when supervisor is running but local metering failed.
- Test/manual verification needed: Policy test for `.supervisorRunning` plus failed audio preview; manual microphone-denied receiver-window smoke.
- Risk of change: Medium; preview state and visual meter behavior.
- Confidence: Medium-high.

### MASTER-SB-008 - Live session state is stale or unreachable from traced derivation

- ID: MASTER-SB-008
- Source audit(s): `docs/uiux-state-behavior-audit.md`, `docs/uiux-surface-index.md`
- Original finding ID(s): SB-008, UI-STATE-002
- Theme: STATE_BEHAVIOR
- Severity: P2
- File/component: `AppSessionStateBanner`, `AppSessionState.derive(...)`
- Evidence: State audit says `.live` banner copy exists but no traced branch in `AppSessionState.derive(...)` returns `.live`. Surface index marks lifecycle state truthfulness as a key risk.
- User impact: If live is intended, users may never see it; if obsolete, it preserves a stale mental model.
- Runtime impact, if any: Potentially missing live/streaming operator state. Reachability is UNCLEAR.
- Suggested remediation: Define measured criteria for `.live` and produce it from runtime evidence, or remove/rename stale state and tests.
- Test/manual verification needed: Lifecycle test for expected live conditions plus manual verification after a real or simulated validated session.
- Risk of change: Medium; central session state vocabulary.
- Confidence: Medium.

### MASTER-SB-009 - Synthetic metrics refresh lacks visible loading/failure state

- ID: MASTER-SB-009
- Source audit(s): `docs/uiux-state-behavior-audit.md`, `docs/uiux-surface-index.md`
- Original finding ID(s): SB-009, UI-MENU-002
- Theme: STATE_BEHAVIOR
- Severity: P3
- File/component: `OpenLolaApp` refresh metrics action
- Evidence: State audit says refresh starts a detached synthetic smoke run and assigns the report without traced in-flight or failure UI. Surface index flags the synthetic metrics name as potentially confused with live runtime metrics.
- User impact: Refresh can look like a no-op or leave stale source/synthetic values without explaining progress.
- Runtime impact, if any: None direct; source/synthetic metrics only.
- Suggested remediation: Add loading and last-refresh outcome or make non-failing instantaneous behavior explicit.
- Test/manual verification needed: UI/model test for refresh in-flight state or manual delayed-refresh verification.
- Risk of change: Low.
- Confidence: Medium.

### MASTER-SB-010 - Copy actions hide pasteboard failures

- ID: MASTER-SB-010
- Source audit(s): `docs/uiux-state-behavior-audit.md`, `docs/uiux-surface-index.md`
- Original finding ID(s): SB-010, UI-CMP-010
- Theme: STATE_BEHAVIOR
- Severity: P3
- File/component: `AppPasteboard` callers in packet, execution, support, and root views
- Evidence: State audit says `AppPasteboard.copyString(_:)` returns `Bool`, but several callers ignore failure. Surface index notes copy failure surfaces vary by caller.
- User impact: User can believe a command/path/packet detail was copied when it was not.
- Runtime impact, if any: Possible wrong terminal handoff if user pastes stale clipboard content elsewhere.
- Suggested remediation: Centralize copy handling with success/failure status and use it for all copy controls.
- Test/manual verification needed: Inject failing pasteboard helper and assert every copy control surfaces failure.
- Risk of change: Low-medium; shared helper changes touch many call sites.
- Confidence: High.

### MASTER-SB-011 - Disabled log-open buttons do not explain missing logs

- ID: MASTER-SB-011
- Source audit(s): `docs/uiux-state-behavior-audit.md`
- Original finding ID(s): SB-011
- Theme: STATE_BEHAVIOR
- Severity: P3
- File/component: `AppExecutionView` `AppLogsView`
- Evidence: State audit says stdout/stderr buttons are disabled when files cannot be opened, but disabled controls do not expose the missing-log condition.
- User impact: User cannot tell no-run-yet, missing file, deleted file, and filesystem problem apart.
- Runtime impact, if any: None direct; affects diagnosis.
- Suggested remediation: Add disabled help or adjacent state with expected log path and reason.
- Test/manual verification needed: UI snapshot/model test for missing log paths plus manual disabled button help verification.
- Risk of change: Low.
- Confidence: High.

### MASTER-SB-012 - Write Plan Artifact overwrites existing files without confirmation or counts

- ID: MASTER-SB-012
- Source audit(s): `docs/uiux-state-behavior-audit.md`
- Original finding ID(s): SB-012
- Theme: STATE_BEHAVIOR
- Severity: P2
- File/component: `AppOperatorArtifactViews`, `NativeAppShellArtifacts`
- Evidence: State audit says Write Plan Artifact writes atomically to the target URL without traced existence check, overwrite warning, or processed/skipped/failed counts.
- User impact: User can overwrite prior plan artifacts without warning.
- Runtime impact, if any: Can lose previous configuration snapshots used for later runs or review.
- Suggested remediation: Confirm overwrite with path/last modified time, or write timestamped artifacts and report written/skipped/failed counts.
- Test/manual verification needed: Existing-artifact test asserting confirmation or non-destructive write behavior.
- Risk of change: Medium; file-write behavior and UX confirmation.
- Confidence: High.

### MASTER-SB-013 - Can I Run? can show Ready before current runtime evidence is validated

- ID: MASTER-SB-013
- Source audit(s): `docs/uiux-state-behavior-audit.md`, `docs/uiux-flow-audit.md`
- Original finding ID(s): SB-013, UXF-003
- Theme: STATE_BEHAVIOR
- Severity: P2
- File/component: `AppConsoleModels`, `AppShellRootView` Validation preflight
- Evidence: State audit says preflight can return `Ready` when setup blockers are clear even though Start still requires validation/evidence. Flow audit identifies the first-run validation/evidence path as circular.
- User impact: User can read "Can I Run? Ready" as full run readiness while Start remains disabled.
- Runtime impact, if any: Misleading readiness can cause wrong next action but Start gate still blocks.
- Suggested remediation: Split setup readiness from start readiness, for example "Ready to validate" versus "Ready to start".
- Test/manual verification needed: UI state test for no setup blockers plus no successful validation; verify copy distinguishes validation readiness from start readiness.
- Risk of change: Medium; central readiness copy and tests.
- Confidence: High.

### MASTER-SB-014 - Preview window request is not reconciled with display success

- ID: MASTER-SB-014
- Source audit(s): `docs/uiux-state-behavior-audit.md`, `docs/uiux-surface-index.md`
- Original finding ID(s): SB-014, UI-SCR-014
- Theme: STATE_BEHAVIOR
- Severity: P3
- File/component: `OpenLolaApp` `openPreviewWindow`, Local Preview window
- Evidence: State audit says handler sets `Local preview window requested.` and calls `openWindow`, but no traced confirmation, timeout, or failure state for window display exists. Surface index marks the Local Preview window as wired source-only.
- User impact: If the window fails to appear, the user receives no reconciled error.
- Runtime impact, if any: None direct; affects local preview access.
- Suggested remediation: Track preview window lifecycle or keep copy limited to request sent and surface recovery if unavailable.
- Test/manual verification needed: Manual menu action verification under normal and failure/unavailable window scenarios.
- Risk of change: Low-medium; window lifecycle tracking may need AppKit/SwiftUI hooks.
- Confidence: Medium.

## 7. Duplicates Merged

- `MASTER-FLOW-001` merges the stale validation shortcut from flow and surface
  inventory: UXF-001, UI-MENU-009, and UI-MSG-009 describe the same user-facing
  shortcut mismatch.
- `MASTER-FLOW-002` merges selectable non-runnable connector modes with unclear
  connector handoff: UXF-002 and UXF-013 are the same planning-only workflow
  problem at picker and handoff points.
- `MASTER-FLOW-004` merges Packet Monitor sidebar dimming/unavailable copy with
  its route-level empty/recovery state: UXF-004 and UI-STATE-004 describe the
  same route discoverability issue.
- `MASTER-VA-001` merges long-value readability risks across readable values,
  device cards, and topology labels: VA-001 and VA-004 are the same truncation
  pattern on operational identifiers.
- `MASTER-VA-004` merges small compact controls with banner CTA compactness:
  VA-005 and the CTA portion of VA-011 share the same hit-target/focus risk.
- Cross-theme overlaps were not flattened when they describe different failure
  modes. For example, `MASTER-FLOW-006` covers competing execution affordances,
  while `MASTER-SB-002` keeps the specific unwired Stop behavior.

## 8. Conflicts Or Inconsistencies

- Flow audit says no P0 finding was proven by static evidence; state audit
  records `SB-001` as P0. This is not treated as a direct contradiction because
  the flow audit focused on navigation/task clarity and the state audit traced
  validation invalidation. The master audit preserves the P0 state severity.
- Surface index says Packet Monitor is wired with a truthful empty state, while
  flow audit says sidebar/unavailable presentation can hide that recovery
  destination. The implementation can be wired and still be confusing.
- Visual audit says no confirmed P0/P1 visual/accessibility blocker was proven,
  while flow/state audits contain P0/P1 issues. This is scope difference, not a
  severity conflict.
- `Can I Run?` is split across flow and state concerns: flow audit frames the
  first-run path as circular; state audit frames `Ready` as a misleading
  readiness label. Both are preserved because they imply different remediations.
- Surface index marks several surfaces UNCLEAR or stale, including old read-only
  views, settings visibility model authority, runtime RX preview reachability,
  CLI per-command help, and helper terminal tools. These were not promoted to
  active findings unless a source audit supported a user-facing issue.

## 9. Highest-Risk UI/UX Issues

1. `MASTER-SB-001` P0: stale validation evidence can enable Start after
   runtime-affecting edits.
2. `MASTER-SB-002` P1: `Intent: Stop` does not stop the running process.
3. `MASTER-FLOW-002` P1: planning-only connector modes are selectable beside
   runnable workflows without a concrete app/CLI handoff.
4. `MASTER-FLOW-003` P1 and `MASTER-SB-013` P2: first-run readiness/evidence
   path can be circular or mislabeled.
5. `MASTER-FLOW-006` P2: overlapping execution controls make real execution,
   dry-run, generated plan, and command intent hard to distinguish.
6. `MASTER-SB-005` P2: stale Settings draft can overwrite newer main-window
   settings.
7. `MASTER-SB-007` P2 and `MASTER-FLOW-010` P2: preview/meter surfaces can
   imply the wrong media evidence type.

## 10. Low-Risk UI Polish Candidates

- `MASTER-FLOW-013`: vocabulary cleanup for LoLa/evidence terminology.
- `MASTER-SB-009`: add visible refresh feedback for synthetic metrics.
- `MASTER-SB-010`: centralize copy failure feedback.
- `MASTER-SB-011`: explain disabled log buttons.
- `MASTER-SB-014`: clarify preview window request/display status.
- `MASTER-VA-010`: screenshot-check preview overlay readability before
  changing styles.
- Parts of `MASTER-VA-004`: normalize compact button hit targets where layout
  impact is small.

## 11. Suggested Remediation Slices

1. Evidence truthfulness slice: fix `MASTER-SB-001` and add mutation invalidation tests for runtime-affecting settings and operator fields.
2. Execution control slice: fix `MASTER-SB-002`, then align `MASTER-FLOW-006`, `MASTER-FLOW-007`, and `MASTER-FLOW-014` around one primary execution/stop policy.
3. First-run readiness slice: resolve `MASTER-FLOW-003` and `MASTER-SB-013` with a linear readiness sequence and split setup-ready from start-ready copy.
4. Planning-only connector slice: resolve `MASTER-FLOW-002` with explicit planning-only labeling and concrete CLI/doc handoff.
5. Settings ownership slice: address `MASTER-FLOW-005`, `MASTER-SB-005`, `MASTER-SB-003`, and `MASTER-SB-004` by clarifying ownership, stale-draft handling, input locks, and refresh merge behavior.
6. Artifact/inventory slice: address `MASTER-FLOW-009`, `MASTER-SB-006`, and `MASTER-SB-012` with guided import, stale artifact clearing, and overwrite confirmation/counts.
7. Preview/evidence slice: address `MASTER-FLOW-010`, `MASTER-SB-007`, `MASTER-VA-009`, and `MASTER-VA-010` by naming evidence types and verifying metering/preview states.
8. Visual/accessibility baseline slice: address `MASTER-VA-001` through `MASTER-VA-011` with manual QA first, then stable automated gates for long text, focus, contrast, and minimum-window layout.

## 12. Verification Strategy

- Docs-only verification for this consolidation: run `bash scripts/verify-docs.sh`.
- For state/behavior fixes: start with model/policy tests in app-shell test files, then run focused Swift tests for the edited app-shell area.
- For evidence gating: add tests that validate a report, mutate settings, and prove Start/preflight are invalidated.
- For menu/shortcut fixes: add contract tests tying action inventory, menu labels, keyboard shortcuts, and visible copy together.
- For flow/IA fixes: add copy/availability tests for sidebar routes, Packet Monitor empty state, Settings ownership, and planning-only workflow handoff.
- For visual/accessibility fixes: perform manual app-bundle screenshots at 1024x720 in light/dark/increased-contrast modes, keyboard traversal, Accessibility Inspector checks, and long-value fixture review before adding automation.
- For preview/device fixes: manually test camera/microphone denied, no devices, selected device unavailable, preview disabled, and supervisor running with failed audio metering.
- For destructive actions: add confirmation tests and manual checks for Stop and artifact overwrite paths.

## 13. Remaining Uncertainty

- All four source audits are static. The current app bundle, menu bar, windows,
  dialogs, settings scene, preview window, and Packet Monitor were not launched
  or screenshot-verified in the source audits.
- No hardware, microphone, camera, local network peer, Windows LoLa peer,
  JackTrip peer, UltraGrid peer, `tshark`, or `scapy` runtime was exercised.
- Actual contrast, clipping, focus order, hit targets, VoiceOver output, and
  menu accessibility require runtime verification.
- `remoteInventory.hostName` runtime impact remains UNCLEAR.
- `.live` state reachability remains UNCLEAR.
- `RawBGRAAppKitPreviewSink` operator-app reachability remains UNCLEAR.
- Command-specific Swift CLI help and helper tool end-user entry points remain
  partially audited only.
- Some line numbers and source states can drift after later edits; findings
  should be checked against current source before implementation.
