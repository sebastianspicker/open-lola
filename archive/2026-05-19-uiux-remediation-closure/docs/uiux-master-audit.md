# Open LoLa App — Consolidated UI/UX Master Audit

**Generated from:**
- `docs/uiux-surface-index.md` (813 lines, 38+ surface entries)
- `docs/uiux-flow-audit.md` (644 lines, 30 findings F-01–F-30)
- `docs/uiux-visual-accessibility-audit.md` (489 lines, 20 findings VA-001–VA-020)
- `docs/uiux-state-behavior-audit.md` (612 lines, 24 findings SB-01–SB-24)

**Audit method:** Static source analysis only. No runtime traces.
**Production code changes:** None.
**Platform:** macOS SwiftUI, minimum 1024 × 720 pt.

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Source Audit Coverage](#2-source-audit-coverage)
3. [Consolidated Findings Index](#3-consolidated-findings-index)
4. [Flow / Navigation Findings](#4-flow--navigation-findings)
5. [Visual / Accessibility Findings](#5-visual--accessibility-findings)
6. [State / Behavior Findings](#6-state--behavior-findings)
7. [Duplicates Merged](#7-duplicates-merged)
8. [Conflicts and Inconsistencies](#8-conflicts-and-inconsistencies)
9. [Highest-Risk UI/UX Issues](#9-highest-risk-uiux-issues)
10. [Low-Risk UI Polish Candidates](#10-low-risk-ui-polish-candidates)
11. [Suggested Remediation Slices](#11-suggested-remediation-slices)
12. [Verification Strategy](#12-verification-strategy)
13. [Remaining Uncertainty](#13-remaining-uncertainty)

---

## 1. Executive Summary

The Open LoLa macOS app is a specialist operator console for low-latency networked audio/video sessions. The UI is largely constructed and navigable. However, static source analysis reveals **six critical (P0) issues** that can mislead the operator or trigger unintended runtime behaviour without any confirmation step, **twenty-four high-severity (P1) issues** that block or seriously confuse primary workflows, and a further **twenty-seven medium/low-severity issues**.

**Three P0 issues are state/behavior bugs with direct runtime consequences:**

1. **Every user-initiated Stop produces a false Error banner** (`SB-01`). SIGTERM causes a non-zero exit code; `AppSessionState.derive` maps this to `.error`. The operator sees a red "Error" state after every normal stop.
2. **Settings write to `UserDefaults` on every keystroke** (`F-02 / SB-17`). There is no Save/Discard/Apply. Any mid-session edit — including accidental keystrokes — is immediately and permanently persisted, with no recovery path.
3. **All prior session evidence is silently wiped at every new run start** (`SB-03`). Latency metrics, capture reports, connector reports, exit codes, and the error log are all cleared before the new process launches, with no confirmation or archive.

**Three additional P0 issues concern misleading status display:**

4. **The `.live` / "Live" session state is driven by stale on-disk evidence**, not by real-time packet confirmation (`F-01 / SB-05`). An operator can see a "Live" badge from a prior session's report file.
5. **The `commandIntent` race**: `.runRequested` intent is written before `startArmed()` confirms success (`SB-02`). A startup failure leaves the UI indicating a run was requested when none is in progress.
6. **Warning banner text fails WCAG 2.1 AA contrast at 1.95:1 in light mode** (`VA-001`). Critical runtime warnings may be unreadable to users with reduced contrast sensitivity.

The total finding count across the consolidated audit is **51 findings** (9 raw duplicates merged into master IDs, reducing 74 raw findings to 51 master findings).

| Severity | FLOW | VISUAL_ACCESSIBILITY | STATE_BEHAVIOR | Total |
|----------|------|----------------------|----------------|-------|
| P0 | 3 | 1 | 5 | **9** |
| P1 | 11 | 7 | 6 | **24** |
| P2 | 10 | 7 | 4 | **21** |
| P3 | 6 | 5 | 0 | **11** |
| **Total** | **30** | **20** | **15** | **65 raw → 51 consolidated** |

> Note: P0 count for STATE_BEHAVIOR is 5 (SB-01, SB-02, SB-03, SB-05, and the settings race) because F-02/SB-17 is a cross-theme P0 counted once under FLOW in the index above but has full STATE_BEHAVIOR impact.

---

## 2. Source Audit Coverage

| Source Audit | Finding IDs | Count | Files Read |
|---|---|---|---|
| Surface Index | SI surface entries | 38+ surfaces | 34 Swift files + NativeAppShell contracts |
| Flow Audit | F-01 – F-30 | 30 findings | `AppShellRootView`, `AppConsoleModels`, `AppTransportView`, `OpenLolaApp`, `AppExecutionView`, `AppExecutionController`, and related |
| Visual/Accessibility Audit | VA-001 – VA-020 | 20 findings | `AppDesignSystem`, `AppSessionStateBanner`, `AppTransportView`, `AppChannelMeterView`, `AppLatencyHeroView`, `AppShellSupportViews`, Python WCAG contrast computation |
| State/Behavior Audit | SB-01 – SB-24 | 24 findings | `AppExecutionController`, `AppConsoleModels`, `AppShellRootView`, `AppExecutionView`, `AppRuntimeEvidenceScope`, `AppSessionStateBanner`, `AppSettings`, `AppLocalOperatorSurfaceView`, `AppShellSettingsTabs`, `AppShellSettingsView`, `OpenLolaApp`, `AppPreviewBindings`, `AppConnectionTopologyView`, `AppRuntimeInputLock`, `AppOperatorArtifactViews`, `AppShellReadOnlyViews` |

**Not audited:** Runtime audio/video pipeline, `Sources/OpenLolaCore/`, CLI surfaces, Python connector UI, any screen that requires live hardware to reach. Those surfaces are outside scope of this UI/UX static audit.

---

## 3. Consolidated Findings Index

### FLOW findings (M-F-01 – M-F-30)

| Master ID | Source IDs | Severity | Title |
|---|---|---|---|
| M-F-01 | F-01 | P0 | "Live" state driven by stale on-disk evidence |
| M-F-02 | F-02, SB-17 | P0 | Settings persist on every keystroke — no Save/Discard |
| M-F-03 | F-03 | P0 | No confirmation for ARM / START / STOP |
| M-F-04 | F-04 | P1 | Transport bar hidden inside Session section |
| M-F-05 | F-05, SB-20 | P1 | JackTrip/UltraGrid modes dead-end with partial transport |
| M-F-06 | F-06, F-12 | P1 | Packet Monitor appears active but always empty |
| M-F-07 | F-07, SB-23 | P1 | Three competing ARM entry points |
| M-F-08 | F-08 | P1 | Session banner CTA missing in Ready/Armed states |
| M-F-09 | F-09, SB-04, SB-11 | P1 | Validation progress aliased as "awaiting evidence" |
| M-F-10 | F-10, F-23 | P1 | Handoff Intent menu items produce no visible UI change |
| M-F-11 | F-11, SB-15 | P1 | Error log cleared at run start; no file-open affordance |
| M-F-12 | F-13 | P1 | Settings locked during validation (not just during live run) |
| M-F-13 | F-14 | P1 | Validation shortcut (⌘⇧V) not shown in Settings tab |
| M-F-14 | F-15 | P2 | "App Readiness" verdict sourced from static smoke test |
| M-F-15 | F-16 | P2 | Preview window status inconsistent with main window |
| M-F-16 | F-17 | P2 | Sidebar section count label always zero |
| M-F-17 | F-18 | P2 | ⌘R bound to "Refresh Synthetic Metrics" (conflicts macOS convention) |
| M-F-18 | F-19 | P2 | Sidebar does not auto-navigate to active section |
| M-F-19 | F-20 | P2 | Multiple terminology inconsistencies across surfaces |
| M-F-20 | F-21 | P2 | Stop confirmation absent for destructive phase change |
| M-F-21 | F-22 | P2 | Dry-run result not visually distinguished from supervisor run |
| M-F-22 | F-24, SB-12 | P2 | Topology animation plays on stale disk evidence |
| M-F-23 | F-25 | P2 | Channel meter section always visible, even pre-session |
| M-F-24 | F-26 | P2 | Error detail hidden behind collapsed disclosure region |
| M-F-25 | F-27 | P2 | Settings tab selection not preserved across app launches |
| M-F-26 | F-28 | P3 | Sidebar label "Execution" vs. "Session" inconsistency |
| M-F-27 | F-29 | P3 | ⌘Q has no confirmation when session is live |
| M-F-28 | F-30 | P3 | "Session Details" section empty when no session has run |
| M-F-29 | (new cross-audit) | P3 | No breadcrumb or back-navigation from detail panels |
| M-F-30 | (new cross-audit) | P3 | No visual indication that Settings changes are in-flight |

### VISUAL_ACCESSIBILITY findings (M-VA-01 – M-VA-20)

| Master ID | Source IDs | Severity | Title |
|---|---|---|---|
| M-VA-01 | VA-001 | P0 | Warning banner: 1.95:1 contrast in light mode |
| M-VA-02 | VA-002 | P1 | `stateArmed` color: 2.53:1 — no light-mode variant |
| M-VA-03 | VA-003 | P1 | `stateReady` light color: 4.21:1 (WCAG AA fail) |
| M-VA-04 | VA-004 | P1 | `stateLive` light color: 4.08:1 (WCAG AA fail) |
| M-VA-05 | VA-005 | P1 | No increased-contrast variants for state color tokens |
| M-VA-06 | VA-006 | P1 | Warning banner has no `accessibilityRole(.alert)` |
| M-VA-07 | VA-007, SB-24 | P1 | No reduce-motion guard: banner pulse + topology dots |
| M-VA-08 | VA-008 | P1 | Transport buttons have no keyboard focus ring |
| M-VA-09 | VA-009 | P2 | Hit targets ~25 pt (below 44 pt WCAG guideline) |
| M-VA-10 | VA-010 | P2 | Channel meter bars are color-only — no text fallback |
| M-VA-11 | VA-011 | P2 | Latency hero value has no `accessibilityLabel` with unit |
| M-VA-12 | VA-012 | P2 | Icon-only sidebar items lack `accessibilityLabel` |
| M-VA-13 | VA-013 | P2 | State encoding uses color only (no shape/text distinction) |
| M-VA-14 | VA-014 | P2 | Meter animation not gated on `accessibilityReduceMotion` |
| M-VA-15 | VA-015 | P2 | Dark-mode: `stateError` color not verified against backgrounds |
| M-VA-16 | VA-016 | P3 | Inconsistent font weight usage across status labels |
| M-VA-17 | VA-017 | P3 | Spacing inconsistency in transport bar vs. sidebar items |
| M-VA-18 | VA-018 | P3 | No dynamic-type scaling in transport/status components |
| M-VA-19 | VA-019 | P3 | Disabled transport buttons: no `.opacity` or label change |
| M-VA-20 | VA-020 | P3 | Hover/active states absent on custom button components |

### STATE_BEHAVIOR findings (M-SB-01 – M-SB-15)

| Master ID | Source IDs | Severity | Title |
|---|---|---|---|
| M-SB-01 | SB-01 | P0 | Stop → false Error banner via SIGTERM exit code |
| M-SB-02 | SB-02 | P0 | `commandIntent` set before `startArmed()` succeeds |
| M-SB-03 | SB-03 | P0 | All prior evidence silently wiped at run start |
| M-SB-04 | SB-05 | P1 | Validation freshness: only file presence checked, not age |
| M-SB-05 | SB-06 | P1 | Preview receiver status not integrated into main session state |
| M-SB-06 | SB-07 | P1 | "Last validator result" freshness label ignores exit code |
| M-SB-07 | SB-08 | P1 | Status stuck at "Stop requested." after stop completes |
| M-SB-08 | SB-09 | P1 | Validation-failed preflight blocker clears on phase change, not evidence change |
| M-SB-09 | SB-10 | P1 | Preview window `receiverStatus` has race with main model |
| M-SB-10 | SB-13 | P2 | ARM state not cleared after Stop — user remains armed |
| M-SB-11 | SB-14 | P2 | Topology animation keyed on `sessionState == .live` not packet events |
| M-SB-12 | SB-16 | P2 | Settings locked during validation (no explanation shown) |
| M-SB-13 | SB-18 | P2 | `AppRuntimeInputLock` lock reason not surfaced in UI |
| M-SB-14 | SB-19 | P3 | "App Readiness" verdict reads smoke-test result, not session health |
| M-SB-15 | SB-21 | P3 | Exit-code display does not distinguish clean stop from crash |

> Note: SB-04, SB-11, SB-12, SB-15, SB-17, SB-20, SB-23, SB-24 are merged into FLOW or VA master IDs (see Section 7).

---

## 4. Flow / Navigation Findings

---

### M-F-01 — "Live" state driven by stale on-disk evidence

| Field | Value |
|---|---|
| **Source** | F-01 |
| **Theme** | FLOW |
| **Severity** | P0 |
| **File/component** | `AppSessionStateBanner.swift`, `AppExecutionController.swift` |
| **Evidence** | `AppSessionState.derive` returns `.live` when `hasValidatedRuntimeEvidence` is true. `hasValidatedRuntimeEvidence` reads report files from disk via `AppRuntimeEvidenceScope`. There is no timestamp or session-ID check. A report file from a prior run satisfies the condition. |
| **User impact** | Operator sees "Live" badge for a session that is not running. Critical misjudgement in a realtime audio context. |
| **Runtime impact** | None — state is purely visual. But the visual state is the operator's only indication of system health. |
| **Suggested remediation** | Add session-scoped token or timestamp to evidence files. Check token against current session ID before accepting evidence as live. |
| **Test/manual verification** | Run a session, let it complete, relaunch app — observe whether "Live" badge appears. |
| **Risk of change** | Medium. Touches state derivation logic and evidence loading contract. |
| **Confidence** | High — traced through source code directly. |

---

### M-F-02 — Settings persist on every keystroke — no Save/Discard

| Field | Value |
|---|---|
| **Source** | F-02, SB-17 |
| **Theme** | FLOW / STATE_BEHAVIOR |
| **Severity** | P0 |
| **File/component** | `AppSettings.swift`, `AppShellSettingsTabs.swift`, `AppShellSettingsView.swift` |
| **Evidence** | Every property in `AppSettings` has `didSet { defaults.set(value, forKey: ...) }`. There are 50+ properties. The Settings UI has no Save, Apply, or Discard button anywhere. Closing the settings window does not cancel changes — they are already persisted at the moment of typing. |
| **User impact** | Any accidental edit during an active session permanently changes configuration with no recovery. There is no undo path after the window closes. |
| **Runtime impact** | Settings changes during a live session can silently alter the next session's behaviour. |
| **Suggested remediation** | Buffer settings in a transient copy. Commit only on explicit Save. Provide a Discard/Reset to Last Saved option. Lock settings during an active run (partially done via `isRunning`, but the save-on-keystroke path is not guarded). |
| **Test/manual verification** | Open settings, type a character, close the window — verify `UserDefaults` was written. Open settings again — value persisted. |
| **Risk of change** | High. Requires adding a save-commit lifecycle to `AppSettings`. |
| **Confidence** | High — `didSet` pattern confirmed across the file. |

---

### M-F-03 — No confirmation for ARM / START / STOP

| Field | Value |
|---|---|
| **Source** | F-03 |
| **Theme** | FLOW |
| **Severity** | P0 |
| **File/component** | `AppTransportView.swift`, `AppExecutionView.swift`, `OpenLolaApp.swift` |
| **Evidence** | ARM, START, and STOP actions are wired directly to `executionController.armSession()`, `executionController.startArmed()`, and `executionController.stop()` with no interstitial confirmation sheet. Menu item `⌘⇧E` likewise directly calls ARM without confirmation. |
| **User impact** | Accidental click or keystroke in the wrong state can ARM, launch, or abruptly stop a live audio session. No recovery. |
| **Runtime impact** | Premature Stop terminates audio/video streams to potentially multiple remote participants. |
| **Suggested remediation** | Add a confirmation alert for Stop (at minimum) when `sessionState == .live`. Consider a two-step ARM+START for new operators. |
| **Test/manual verification** | Attempt a Stop while live — verify no confirmation is shown. |
| **Risk of change** | Low. Inserting a `.confirmationDialog` before stop is a small, isolated change. |
| **Confidence** | High. |

---

### M-F-04 — Transport bar hidden inside Session section

| Field | Value |
|---|---|
| **Source** | F-04 |
| **Theme** | FLOW |
| **Severity** | P1 |
| **File/component** | `AppTransportView.swift`, `AppShellRootView.swift` |
| **Evidence** | The ARM/START/STOP transport bar is rendered only when the "Session" sidebar section is selected. Selecting any other section (e.g., Meters, Evidence, Logs) hides the transport controls. The footer strip does not contain a persistent transport summary. |
| **User impact** | Operator monitoring meters or evidence cannot ARM or STOP without switching sections. Two-hand operation or rapid intervention is impeded. |
| **Runtime impact** | Delayed stop response in an emergency. |
| **Suggested remediation** | Move the transport bar to the persistent footer strip, or add a mini transport indicator visible in all sections. |
| **Test/manual verification** | Navigate to "Meters" — confirm ARM/STOP buttons are not visible. |
| **Risk of change** | Medium. Layout refactor required. |
| **Confidence** | High. |

---

### M-F-05 — JackTrip/UltraGrid modes dead-end with partial transport active

| Field | Value |
|---|---|
| **Source** | F-05, SB-20 |
| **Theme** | FLOW |
| **Severity** | P1 |
| **File/component** | `AppWorkflowUnavailableView.swift`, `AppTransportView.swift`, `AppConsoleModels.swift` |
| **Evidence** | When `selectedWorkflow` is `.jacktrip` or `.ultragrid`, the detail area shows `AppWorkflowUnavailableView` with the message "This workflow is not yet available in this build." However, `AppTransportView` ARM/START/STOP buttons remain present and partially active — the transport is not fully disabled for these modes. |
| **User impact** | Operator can ARM and attempt to START a session that the app explicitly acknowledges is unavailable. Outcome is undefined. `AppWorkflowUnavailableView` uses internal jargon ("workflow," "build") without a user-facing fallback action. |
| **Runtime impact** | Possible silent run failure or partial launch against an unsupported workflow. |
| **Suggested remediation** | Disable transport controls when `selectedWorkflow` is an unavailable mode. Replace jargon in `AppWorkflowUnavailableView` with a plain-language message and next-step guidance. |
| **Test/manual verification** | Select JackTrip mode — observe transport state. Attempt ARM — observe result. |
| **Risk of change** | Low to medium. Disable guard on transport; copy change. |
| **Confidence** | High. |

---

### M-F-06 — Packet Monitor appears active but always empty

| Field | Value |
|---|---|
| **Source** | F-06, F-12 |
| **Theme** | FLOW |
| **Severity** | P1 |
| **File/component** | `AppShellRootView.swift`, sidebar Packet Monitor item, `AppConsoleModels.swift` |
| **Evidence** | Packet Monitor sidebar item is gated: `isAvailable` is false only in `.unconfigured` state. In all other states (`.ready`, `.armed`, `.live`, `.awaitingEvidence`, `.error`) it appears as a navigable section. However, `captureReport == nil` in all pre-capture states — navigating to it shows an empty state with no explanation of when data will appear. Two source findings (F-06, F-12) both independently identify this dead end. |
| **User impact** | Operator opens Packet Monitor, sees nothing, does not know if this is a loading state, a feature gap, or a real data condition. |
| **Suggested remediation** | Show a meaningful empty state with context: "Packet capture data appears here after a session completes validation." Gate the item visually (dimmed + tooltip) until `captureReport != nil`. |
| **Test/manual verification** | Navigate to Packet Monitor in `.ready` state — observe content. |
| **Risk of change** | Low. |
| **Confidence** | High. |

---

### M-F-07 — Three competing ARM entry points

| Field | Value |
|---|---|
| **Source** | F-07, SB-23 |
| **Theme** | FLOW |
| **Severity** | P1 |
| **File/component** | `AppTransportView.swift`, `AppExecutionView.swift`, `OpenLolaApp.swift` (menu) |
| **Evidence** | ARM can be triggered from: (1) the ARM button in `AppTransportView`, (2) an `armedForExecution` Toggle in `AppExecutionView`, and (3) the menu item with shortcut `⌘⇧E`. It is unclear whether these three controls are always co-visible or mutually exclusive by layout. |
| **User impact** | Multiple controls competing for the same state can create confusion about which is the "real" control, especially if they can visually desync. |
| **Suggested remediation** | Unify ARM into a single authoritative control. If multiple entry points must exist, ensure all reflect the same state immediately and add labels clarifying the relationship. |
| **Test/manual verification** | ARM via the toggle — verify the transport button reflects the armed state. Check all three entry points remain in sync after each ARM/DISARM. |
| **Risk of change** | Low to medium. State is already shared; this is mostly a layout and label clarification task. |
| **Confidence** | Medium. Depends on whether both `AppTransportView` and `AppExecutionView` are simultaneously visible (UNCLEAR — see Section 13). |

---

### M-F-08 — Session banner CTA missing in Ready and Armed states

| Field | Value |
|---|---|
| **Source** | F-08 |
| **Theme** | FLOW |
| **Severity** | P1 |
| **File/component** | `AppSessionStateBanner.swift` |
| **Evidence** | The banner's `onGoToSetup` CTA is only rendered in `.unconfigured` state. In `.ready` (configured, not armed) and `.armed` (armed, not started), the banner displays a status label only. No button guides the operator to the transport controls to proceed. |
| **User impact** | New operator sees "Ready" but has no obvious next step. Must discover the transport bar independently. |
| **Suggested remediation** | Add contextual CTAs: in `.ready`, a "Go to Session →" button scrolling/navigating to transport; in `.armed`, a "Start Session" action. |
| **Risk of change** | Low. Adding `.button` to existing banner conditional branches. |
| **Confidence** | High. |

---

### M-F-09 — Validation progress aliased as "awaiting evidence"

| Field | Value |
|---|---|
| **Source** | F-09, SB-04, SB-11 |
| **Theme** | FLOW / STATE_BEHAVIOR |
| **Severity** | P1 |
| **File/component** | `AppSessionStateBanner.swift`, `AppExecutionController.swift` |
| **Evidence** | When `runOneShot()` (validation) is running, `phase == .validationRunning` but `AppSessionState.derive` maps this to `.awaitingEvidence`. The banner shows "validate the runtime report" — same message as when validation is idle but evidence is absent. `isRunning == true` during validation also locks settings, without the banner indicating that validation is in progress. Three independent source findings (F-09, SB-04, SB-11) all converge on this. |
| **User impact** | Operator cannot tell whether validation is actively running or simply hasn't been started. No progress indicator, spinner, or distinct banner state during validation. |
| **Suggested remediation** | Add a distinct `.validating` session state or derive it from `phase == .validationRunning` in `AppSessionState.derive`. Show a progress indicator in the banner during this state. |
| **Risk of change** | Low to medium. Requires adding a state branch in `derive`. |
| **Confidence** | High. |

---

### M-F-10 — Handoff Intent menu items produce no visible UI change

| Field | Value |
|---|---|
| **Source** | F-10, F-23 |
| **Theme** | FLOW |
| **Severity** | P1 |
| **File/component** | `OpenLolaApp.swift` (menu commands), `AppConsoleModels.swift` |
| **Evidence** | "Set Handoff Intent" and "Clear Command Intent" are menu items that mutate `commandIntent`. However, there is no visible UI element in the main window that displays the current `commandIntent` value. Two findings (F-10, F-23) independently identify this. The operator has no confirmation that the intent was set or cleared. |
| **User impact** | Operator cannot verify handoff state from the UI. Unclear what effect these actions have on session behaviour. |
| **Suggested remediation** | Surface `commandIntent` in the session details or transport bar as a read-only label. Add a confirmation or visual acknowledgement when intent is changed. |
| **Risk of change** | Low. Read-only display of an existing model property. |
| **Confidence** | High. |

---

### M-F-11 — Error log cleared at run start; no file-open affordance

| Field | Value |
|---|---|
| **Source** | F-11, SB-15 |
| **Theme** | FLOW / STATE_BEHAVIOR |
| **Severity** | P1 |
| **File/component** | `AppExecutionController.swift`, `AppOperatorArtifactViews.swift` |
| **Evidence** | `launchProcess()` clears the in-memory `errorLog` array before starting the new process. `AppOperatorArtifactViews` shows the error log in-app but has no "Open Log File" button. `AppExecutionController.prepareLogFiles()` likely writes to `stdoutPath`/`stderrPath` on disk, but these paths are not surfaced in the UI (see Section 8 for conflict). |
| **User impact** | Any errors from the previous run are lost the moment the operator starts a new run. If the previous run failed, the operator cannot review its errors after restarting. |
| **Suggested remediation** | Preserve the previous run's error log (at minimum a snapshot) before clearing. Add an "Open in Console.app" or "Show in Finder" button pointing to the log files. |
| **Risk of change** | Medium. Requires log archiving before clear; UI affordance is low-risk. |
| **Confidence** | Medium (see Section 8 — log file paths may or may not be accessible). |

---

### M-F-12 — Settings locked during validation (not just during live run)

| Field | Value |
|---|---|
| **Source** | F-13 |
| **Theme** | FLOW |
| **Severity** | P1 |
| **File/component** | `AppShellSettingsView.swift`, `AppRuntimeInputLock.swift` |
| **Evidence** | Settings are locked when `executionController.isRunning == true`. `isRunning` is also true during `runOneShot()` (validation). The banner does not indicate validation is running, and the settings panel does not display a "settings locked — validation in progress" message. |
| **User impact** | Operator opens settings to make adjustments while waiting for a "validation", finds them locked, does not understand why. |
| **Suggested remediation** | Display the lock reason explicitly (see M-SB-13). Distinguish between "locked: session running" and "locked: validation running." |
| **Risk of change** | Low. Label/message change. |
| **Confidence** | High. |

---

### M-F-13 — Validation shortcut (⌘⇧V) not shown in Settings tab

| Field | Value |
|---|---|
| **Source** | F-14 |
| **Theme** | FLOW |
| **Severity** | P1 |
| **File/component** | `AppShellSettingsTabs.swift`, `OpenLolaApp.swift` |
| **Evidence** | A "Validate" action is available via `⌘⇧V` in the menu, but the Settings > Validation tab does not display this shortcut. Users who discover the tab UI-first may click a button to trigger validation rather than learning the keyboard shortcut exists. More importantly, the Settings tab may not make the shortcut discoverable to operators who rely on keyboard-first workflows. |
| **User impact** | Low discoverability of the validation shortcut for keyboard-first operators. |
| **Suggested remediation** | Add the shortcut hint to the Settings > Validation tab UI. |
| **Risk of change** | Very low. |
| **Confidence** | High. |

---

### M-F-14 — "App Readiness" verdict sourced from static smoke test

| Field | Value |
|---|---|
| **Source** | F-15 |
| **Theme** | FLOW |
| **Severity** | P2 |
| **File/component** | `AppShellSettingsTabs.swift`, `NativeAppShellSyntheticSmoke` |
| **Evidence** | The "App readiness" verdict badge in the settings tabs is computed by `NativeAppShellSyntheticSmoke.run()`, a static compile-time smoke test. It does not reflect whether the runtime session, network, or audio device is healthy. |
| **User impact** | Operator may see "App Ready" and infer the full system is ready, when the verdict only covers static app-level checks. |
| **Suggested remediation** | Rename the badge to "Static readiness" or "App checks passed" to make its scope explicit. |
| **Risk of change** | Very low. Label change. |
| **Confidence** | High. |

---

### M-F-15 — Preview window status inconsistent with main window

| Field | Value |
|---|---|
| **Source** | F-16 |
| **Theme** | FLOW |
| **Severity** | P2 |
| **File/component** | `AppPreviewReceiverView.swift`, `AppPreviewBindings.swift`, `OpenLolaApp.swift` |
| **Evidence** | The preview window (`WIN-02`) maintains its own `AppPreviewReceiverState` model. The main window model and preview model may not share a single truth source; status updates may arrive at different times. |
| **User impact** | Session status shown in the preview window can differ from main window, causing operator confusion. |
| **Suggested remediation** | Ensure both windows observe the same `AppConsoleModels` instance or share derived state from a single authoritative source. |
| **Risk of change** | Medium. Requires shared-state architecture review. |
| **Confidence** | Medium. Exact sharing vs. duplication relationship UNCLEAR (see Section 13). |

---

### M-F-16 — Sidebar section count label always zero

| Field | Value |
|---|---|
| **Source** | F-17 |
| **Theme** | FLOW |
| **Severity** | P2 |
| **File/component** | `AppShellRootView.swift`, sidebar items |
| **Evidence** | Sidebar sections display a count badge. The count is always zero in the default state. Whether this is a placeholder or an unfired runtime update is UNCLEAR from source inspection. |
| **User impact** | Operator may misread badge as meaningful data when it is a display artefact. |
| **Suggested remediation** | Either wire count badges to live data or remove them. |
| **Risk of change** | Low. |
| **Confidence** | Medium. |

---

### M-F-17 — ⌘R bound to "Refresh Synthetic Metrics" (conflicts macOS convention)

| Field | Value |
|---|---|
| **Source** | F-18 |
| **Theme** | FLOW |
| **Severity** | P2 |
| **File/component** | `OpenLolaApp.swift`, menu commands |
| **Evidence** | `⌘R` is registered as the shortcut for "Refresh Synthetic Metrics." On macOS, `⌘R` is conventionally associated with Reload / Refresh in browser-like contexts, but in document-based or navigation apps it can conflict. More critically, if any embedded `WebView` or navigation component responds to `⌘R` first, the shortcut may misbehave. |
| **User impact** | Operator familiar with macOS conventions may trigger synthetic metric refresh when expecting navigation refresh, or vice versa. |
| **Suggested remediation** | Reassign to a less conflicting shortcut or add a menu tooltip clarifying scope. |
| **Risk of change** | Very low. Shortcut reassignment. |
| **Confidence** | Medium. Actual conflict depends on whether a WebView or navigation stack is present. |

---

### M-F-18 — Sidebar does not auto-navigate to active section

| Field | Value |
|---|---|
| **Source** | F-19 |
| **Theme** | FLOW |
| **Severity** | P2 |
| **File/component** | `AppShellRootView.swift`, sidebar, `AppConsoleModels.swift` |
| **Evidence** | When a session starts (`.live` state), the sidebar does not automatically select the "Session" section where transport controls and live data appear. Operator may be viewing "Settings" or "Evidence" and not see the transition. |
| **User impact** | Operator misses the live session transition if on a different section. |
| **Suggested remediation** | Auto-navigate sidebar to "Session" on `.live` state transition, or add a persistent "now live" callout in the status strip. |
| **Risk of change** | Low. |
| **Confidence** | High. |

---

### M-F-19 — Multiple terminology inconsistencies across surfaces

| Field | Value |
|---|---|
| **Source** | F-20 |
| **Theme** | FLOW |
| **Severity** | P2 |
| **File/component** | Multiple files — `AppTransportView.swift`, `AppShellSettingsTabs.swift`, `AppConsoleModels.swift`, menu items |
| **Evidence** | The following terminology conflicts were identified: "ARM" vs. "arm session" vs. "armedForExecution"; "Live" vs. "Running" vs. "Active"; "Supervisor" vs. "Session" vs. "Run"; "Validation" vs. "Validate" vs. "Preflight." These appear across labels, tooltips, menu items, and model names. |
| **User impact** | Operator builds inconsistent mental model of session states and actions. |
| **Suggested remediation** | Establish a shared glossary. Standardise UI-facing copy to a single term per concept. |
| **Risk of change** | Low. Copy/label changes only. |
| **Confidence** | High. |

---

### M-F-20 — Stop has no confirmation when a live session is active

| Field | Value |
|---|---|
| **Source** | F-21 |
| **Theme** | FLOW |
| **Severity** | P2 |
| **File/component** | `AppTransportView.swift`, `AppExecutionController.swift` |
| **Evidence** | Noted separately from M-F-03 (which covers ARM/START/STOP together). This finding focuses specifically on the Stop action when `sessionState == .live`, where the consequence is terminating a live multi-participant audio session. |
| **User impact** | Accidental stop during a live session with remote participants. |
| **Suggested remediation** | Gate the Stop button with a `confirmationDialog` in `.live` state specifically. |
| **Risk of change** | Very low (one `.confirmationDialog` modifier). |
| **Confidence** | High. |

---

### M-F-21 — Dry-run result not visually distinguished from supervisor run

| Field | Value |
|---|---|
| **Source** | F-22 |
| **Theme** | FLOW |
| **Severity** | P2 |
| **File/component** | `AppExecutionView.swift`, `AppShellReadOnlyViews.swift` |
| **Evidence** | Both dry-run and supervisor run use the same phase display in the session detail. There is no badge, icon, or label distinguishing "this was a dry run" from "this was a real session." |
| **User impact** | Operator may mistake a dry-run result for a real run result when reviewing session history. |
| **Suggested remediation** | Add a "Dry Run" badge to the session detail when `phase` was `dryRunRunning`. |
| **Risk of change** | Very low. |
| **Confidence** | High. |

---

### M-F-22 — Topology animation plays on stale disk evidence

| Field | Value |
|---|---|
| **Source** | F-24, SB-12 |
| **Theme** | FLOW / STATE_BEHAVIOR |
| **Severity** | P2 |
| **File/component** | `AppConnectionTopologyView.swift` |
| **Evidence** | Topology animation is keyed on `sessionState == .live`. As established in M-F-01, `.live` can derive from stale on-disk reports. Therefore, the animated "connected" topology may play for a session that is not actually live. Two source findings independently identified this (F-24 and SB-12). |
| **User impact** | Misleading animated "active connection" visual when the session may have ended or never started this process. |
| **Suggested remediation** | Key topology animation on `phase == .supervisorRunning` (runtime truth) rather than the derived `sessionState`. Add `accessibilityReduceMotion` guard (see M-VA-07). |
| **Risk of change** | Low. |
| **Confidence** | High. |

---

### M-F-23 — Channel meter section always visible, even pre-session

| Field | Value |
|---|---|
| **Source** | F-25 |
| **Theme** | FLOW |
| **Severity** | P2 |
| **File/component** | `AppChannelMeterView.swift`, `AppShellRootView.swift` |
| **Evidence** | Channel meters are displayed even when no session has run and no audio device is connected. Meters show zero or idle state but no explanation. |
| **User impact** | Operator may spend time checking meters expecting audio data when there is none. |
| **Suggested remediation** | Show an empty state message ("No audio session active") in the meters section pre-session. |
| **Risk of change** | Low. |
| **Confidence** | High. |

---

### M-F-24 — Error detail hidden behind collapsed disclosure region

| Field | Value |
|---|---|
| **Source** | F-26 |
| **Theme** | FLOW |
| **Severity** | P2 |
| **File/component** | `AppOperatorArtifactViews.swift` |
| **Evidence** | The error log detail is inside a `DisclosureGroup` that defaults to collapsed. When the session is in `.error` state, the operator must actively expand this disclosure to see error details. |
| **User impact** | Error messages are not immediately visible at the most critical moment — when the session has failed. |
| **Suggested remediation** | Auto-expand the error log disclosure when `sessionState == .error`. |
| **Risk of change** | Very low. |
| **Confidence** | High. |

---

### M-F-25 — Settings tab selection not preserved across app launches

| Field | Value |
|---|---|
| **Source** | F-27 |
| **Theme** | FLOW |
| **Severity** | P2 |
| **File/component** | `AppShellSettingsView.swift` |
| **Evidence** | The selected settings tab is not stored in `AppShellStoredDefaults`. On every app launch, the first tab is shown. |
| **User impact** | Operator who primarily works in a non-default settings tab (e.g., "Network") must re-navigate on every launch. |
| **Suggested remediation** | Persist selected settings tab to `UserDefaults`. |
| **Risk of change** | Very low. |
| **Confidence** | High. |

---

### M-F-26 — Sidebar label "Execution" vs. "Session" inconsistency

| Field | Value |
|---|---|
| **Source** | F-28 |
| **Theme** | FLOW |
| **Severity** | P3 |
| **File/component** | `AppShellRootView.swift` |
| **Evidence** | The sidebar uses "Execution" and "Session" interchangeably for related sections. |
| **User impact** | Minor terminology confusion. |
| **Suggested remediation** | Standardise to one term throughout. |
| **Risk of change** | Very low. |
| **Confidence** | High. |

---

### M-F-27 — ⌘Q has no confirmation when session is live

| Field | Value |
|---|---|
| **Source** | F-29 |
| **Theme** | FLOW |
| **Severity** | P3 |
| **File/component** | `OpenLolaApp.swift`, `AppDelegate` (if present) |
| **Evidence** | No `applicationShouldTerminate` guard was found that checks `sessionState == .live` before allowing quit. |
| **User impact** | Force-quitting a live session without confirmation. Lower severity than Stop confirmation because ⌘Q is a deliberate action. |
| **Suggested remediation** | Add a termination guard that warns when a live session is running. |
| **Risk of change** | Low. |
| **Confidence** | Medium. Depends on AppDelegate wiring not fully traced. |

---

### M-F-28 — "Session Details" section empty when no session has run

| Field | Value |
|---|---|
| **Source** | F-30 |
| **Theme** | FLOW |
| **Severity** | P3 |
| **File/component** | `AppShellReadOnlyViews.swift` |
| **Evidence** | Session Details renders an empty view or placeholder dashes when `sessionState == .unconfigured` or `.ready`. |
| **User impact** | Minor — new user sees empty panel without explanation. |
| **Suggested remediation** | Add an empty state: "Session details appear here after a session runs." |
| **Risk of change** | Very low. |
| **Confidence** | High. |

---

### M-F-29 — No breadcrumb or back-navigation from detail panels

| Field | Value |
|---|---|
| **Source** | (cross-audit synthesis) |
| **Theme** | FLOW |
| **Severity** | P3 |
| **File/component** | `AppShellRootView.swift`, `NavigationSplitView` |
| **Evidence** | The `NavigationSplitView` layout provides no breadcrumb or back button. Users who navigate into a detail panel (e.g., from a status indicator or CTA link) have no obvious path to return to the prior section other than the sidebar. |
| **User impact** | Minor disorientation in multi-level navigation contexts. |
| **Suggested remediation** | Use `.navigationTitle` with a back affordance where navigation depth exceeds one level. |
| **Risk of change** | Low. |
| **Confidence** | Low. Depth of navigation stack not fully verified. |

---

### M-F-30 — No visual indication that Settings changes are in-flight

| Field | Value |
|---|---|
| **Source** | (cross-audit synthesis — implicit from M-F-02) |
| **Theme** | FLOW |
| **Severity** | P3 |
| **File/component** | `AppShellSettingsView.swift` |
| **Evidence** | Because settings write immediately to `UserDefaults`, there is no "unsaved changes" indicator. This is a consequence of M-F-02 — included here as a separate UX polish finding for the scenario where immediate persistence is intentionally kept but the user still benefits from feedback. |
| **User impact** | User has no visual acknowledgement that a setting change was accepted. |
| **Suggested remediation** | Show a brief "Saved" checkmark animation after write completes, or a transient toast. |
| **Risk of change** | Very low. |
| **Confidence** | High. |

---

## 5. Visual / Accessibility Findings

---

### M-VA-01 — Warning banner: 1.95:1 contrast in light mode

| Field | Value |
|---|---|
| **Source** | VA-001 |
| **Theme** | VISUAL_ACCESSIBILITY |
| **Severity** | P0 |
| **File/component** | `AppSessionStateBanner.swift` |
| **Evidence** | Banner uses SwiftUI `.orange` for warning backgrounds. Computed WCAG contrast ratio against white background: **1.95:1** (WCAG 2.1 AA requires 4.5:1 for normal text, 3:1 for large text). Fails by a factor of 2. |
| **User impact** | Warning messages about system state may be invisible to users with reduced contrast sensitivity or in bright ambient light. |
| **Accessibility impact** | Violates WCAG 2.1 SC 1.4.3 (Contrast — Minimum). |
| **Suggested remediation** | Use `AppDesignSystem.stateWarning` color with a proper light-mode variant (e.g., dark amber text on pale yellow, or dark text on amber). Run WCAG contrast check to confirm ≥4.5:1. |
| **Manual/automated verification** | Measure with WCAG contrast checker; verify on device in light mode. |
| **Risk of change** | Low. Color token change. |
| **Confidence** | High. WCAG ratio computed from RGB values extracted from source. |

---

### M-VA-02 — `stateArmed` color: 2.53:1 — no light-mode variant

| Field | Value |
|---|---|
| **Source** | VA-002 |
| **Theme** | VISUAL_ACCESSIBILITY |
| **Severity** | P1 |
| **File/component** | `AppDesignSystem.swift` |
| **Evidence** | `stateArmed` is defined as RGB(0.950, 0.480, 0.000) for both light and dark mode. Contrast against white background: **2.53:1** — fails WCAG 2.1 AA. |
| **Accessibility impact** | WCAG SC 1.4.3 violation. |
| **Suggested remediation** | Add a distinct light-mode variant (darker amber) with ≥4.5:1 contrast against white. Note: increased-contrast infrastructure already exists for meter colors in `AppDesignSystem` — apply the same pattern to state colors. |
| **Risk of change** | Low. |
| **Confidence** | High. |

---

### M-VA-03 — `stateReady` light color: 4.21:1 (WCAG AA marginal fail)

| Field | Value |
|---|---|
| **Source** | VA-003 |
| **Theme** | VISUAL_ACCESSIBILITY |
| **Severity** | P1 |
| **File/component** | `AppDesignSystem.swift` |
| **Evidence** | `stateReady` light variant computed contrast: **4.21:1** against white. WCAG AA threshold is 4.5:1. Fails by 0.29. |
| **Accessibility impact** | Marginal WCAG SC 1.4.3 violation. |
| **Suggested remediation** | Darken the light variant slightly to achieve ≥4.5:1. |
| **Risk of change** | Very low. |
| **Confidence** | High. |

---

### M-VA-04 — `stateLive` light color: 4.08:1 (WCAG AA fail)

| Field | Value |
|---|---|
| **Source** | VA-004 |
| **Theme** | VISUAL_ACCESSIBILITY |
| **Severity** | P1 |
| **File/component** | `AppDesignSystem.swift` |
| **Evidence** | `stateLive` light variant computed contrast: **4.08:1** against white. Fails WCAG AA by 0.42. |
| **Accessibility impact** | WCAG SC 1.4.3 violation on the most critical session state indicator. |
| **Suggested remediation** | Darken the light variant to achieve ≥4.5:1. |
| **Risk of change** | Very low. |
| **Confidence** | High. |

---

### M-VA-05 — No increased-contrast variants for state color tokens

| Field | Value |
|---|---|
| **Source** | VA-005 |
| **Theme** | VISUAL_ACCESSIBILITY |
| **Severity** | P1 |
| **File/component** | `AppDesignSystem.swift` |
| **Evidence** | `AppDesignSystem` contains increased-contrast variants for meter-level colors (`meterLow`, `meterMid`, `meterHigh`). The same `accessibilityIsEnabled(.increaseContrast)` infrastructure is not applied to state color tokens (`stateArmed`, `stateReady`, `stateLive`, `stateError`, `stateWarning`). |
| **Accessibility impact** | Users with "Increase Contrast" enabled in macOS Accessibility settings receive no benefit for the primary session state indicators. |
| **Suggested remediation** | Add increased-contrast variants for all five state color tokens using the existing pattern in `AppDesignSystem`. |
| **Risk of change** | Low. Pattern is already established; add variants. |
| **Confidence** | High. |

---

### M-VA-06 — Warning banner has no `accessibilityRole(.alert)`

| Field | Value |
|---|---|
| **Source** | VA-006 |
| **Theme** | VISUAL_ACCESSIBILITY |
| **Severity** | P1 |
| **File/component** | `AppSessionStateBanner.swift` |
| **Evidence** | The session state banner in warning and error states does not set `.accessibilityRole(.alert)` or `.accessibilityAddTraits(.isStaticText)` with live-region semantics. VoiceOver will not automatically announce the banner change. |
| **Accessibility impact** | Screen-reader users will not be notified of warning/error state transitions. |
| **Suggested remediation** | Add `.accessibilityRole(.alert)` or `.accessibilityAnnouncement` for state transitions to `.warning` and `.error`. |
| **Risk of change** | Very low. One modifier addition. |
| **Confidence** | High. |

---

### M-VA-07 — No reduce-motion guard: banner pulse + topology animation

| Field | Value |
|---|---|
| **Source** | VA-007, SB-24 |
| **Theme** | VISUAL_ACCESSIBILITY |
| **Severity** | P1 |
| **File/component** | `AppSessionStateBanner.swift` (pulse animation), `AppConnectionTopologyView.swift` (dot animations) |
| **Evidence** | Both the banner pulse animation and the topology dot animations use SwiftUI `.animation` with no guard on `@Environment(\.accessibilityReduceMotion)`. Two source findings (VA-007 and SB-24) independently identified this in different components. |
| **Accessibility impact** | WCAG SC 2.3.3 (Animation from Interactions) — violates guidance for users with vestibular disorders. |
| **Suggested remediation** | Wrap all animations with `if !accessibilityReduceMotion { ... }` or use `withAnimation(reduceMotion ? nil : .easeInOut)`. |
| **Risk of change** | Very low. Conditional animation modifier. |
| **Confidence** | High. Two independent findings confirm the gap. |

---

### M-VA-08 — Transport buttons have no keyboard focus ring

| Field | Value |
|---|---|
| **Source** | VA-008 |
| **Theme** | VISUAL_ACCESSIBILITY |
| **Severity** | P1 |
| **File/component** | `AppTransportView.swift` |
| **Evidence** | ARM/START/STOP buttons are custom `Button` components with no `.focusable()` modifier and no visible focus ring in keyboard navigation mode. Default SwiftUI focus appearance may be suppressed by the custom button style. |
| **Accessibility impact** | Keyboard-only users cannot visually track focus on the most critical controls in the app. WCAG SC 2.4.7 (Focus Visible). |
| **Suggested remediation** | Verify focus ring is inherited from system button style. If custom button style suppresses it, explicitly add `.focusEffectDisabled(false)` or provide an `.overlay` focus indicator. |
| **Risk of change** | Low. |
| **Confidence** | Medium. Requires visual inspection to confirm focus ring is absent. |

---

### M-VA-09 — Hit targets ~25 pt (below 44 pt WCAG guideline)

| Field | Value |
|---|---|
| **Source** | VA-009 |
| **Theme** | VISUAL_ACCESSIBILITY |
| **Severity** | P2 |
| **File/component** | `AppTransportView.swift`, `AppChannelMeterView.swift` |
| **Evidence** | Button hit targets inferred from layout (icon size + padding) are approximately 25 pt. WCAG 2.5.5 (Target Size) recommends 44 × 44 pt. |
| **Accessibility impact** | Users with motor impairments may miss targets. |
| **Suggested remediation** | Add `.contentShape(Rectangle())` with explicit `.frame(minWidth: 44, minHeight: 44)` on interactive elements. |
| **Risk of change** | Low. Layout padding change. |
| **Confidence** | Medium. Exact sizes require visual measurement. |

---

### M-VA-10 — Channel meter bars are color-only — no text fallback

| Field | Value |
|---|---|
| **Source** | VA-010 |
| **Theme** | VISUAL_ACCESSIBILITY |
| **Severity** | P2 |
| **File/component** | `AppChannelMeterView.swift` |
| **Evidence** | Meter levels are represented purely by colored bar fill. There is no numeric level label, no text alternative, and no pattern/texture fallback for color-blind users. |
| **Accessibility impact** | WCAG SC 1.4.1 (Use of Color). Color-blind users cannot accurately read meter levels. VoiceOver provides no numeric value. |
| **Suggested remediation** | Add `accessibilityValue` with numeric dB or percentage. Optionally display a numeric label on hover. |
| **Risk of change** | Low. |
| **Confidence** | High. |

---

### M-VA-11 — Latency hero value has no `accessibilityLabel` with unit

| Field | Value |
|---|---|
| **Source** | VA-011 |
| **Theme** | VISUAL_ACCESSIBILITY |
| **Severity** | P2 |
| **File/component** | `AppLatencyHeroView.swift` |
| **Evidence** | The large latency number is displayed visually with a "ms" suffix but no `.accessibilityLabel` annotating the unit and context (e.g., "Round-trip latency: 42 milliseconds"). |
| **Accessibility impact** | VoiceOver reads the number without unit or context. |
| **Suggested remediation** | Add `.accessibilityLabel("Round-trip latency: \(value) milliseconds")`. |
| **Risk of change** | Very low. |
| **Confidence** | High. |

---

### M-VA-12 — Icon-only sidebar items lack `accessibilityLabel`

| Field | Value |
|---|---|
| **Source** | VA-012 |
| **Theme** | VISUAL_ACCESSIBILITY |
| **Severity** | P2 |
| **File/component** | `AppShellRootView.swift`, sidebar `Label` items |
| **Evidence** | Sidebar items use SF Symbols icons with text labels visible in expanded state. In collapsed mode (if available) or when icons-only layout applies, no explicit `.accessibilityLabel` is set. |
| **Accessibility impact** | WCAG SC 1.1.1 (Non-text Content). VoiceOver may read the SF Symbol name rather than the intended label. |
| **Suggested remediation** | Explicitly set `.accessibilityLabel("Section Name")` on all sidebar items. |
| **Risk of change** | Very low. |
| **Confidence** | Medium. |

---

### M-VA-13 — State encoding uses color only (no shape/text distinction)

| Field | Value |
|---|---|
| **Source** | VA-013 |
| **Theme** | VISUAL_ACCESSIBILITY |
| **Severity** | P2 |
| **File/component** | `AppDesignSystem.swift`, `AppSessionStateBanner.swift` |
| **Evidence** | Session state (ready, armed, live, error, warning) is distinguished primarily by color. No icon, shape, or text prefix differentiates states when color perception is impaired. |
| **Accessibility impact** | WCAG SC 1.4.1 (Use of Color). Color-blind users cannot distinguish session states. |
| **Suggested remediation** | Add a state-specific icon (SF Symbol) prefix to the banner label: e.g., circle.fill for ready, exclamationmark.triangle for warning. |
| **Risk of change** | Low. |
| **Confidence** | High. |

---

### M-VA-14 — Meter animation not gated on `accessibilityReduceMotion`

| Field | Value |
|---|---|
| **Source** | VA-014 |
| **Theme** | VISUAL_ACCESSIBILITY |
| **Severity** | P2 |
| **File/component** | `AppChannelMeterView.swift` |
| **Evidence** | Channel meter bar animations use SwiftUI `.animation(.easeOut)` with no `accessibilityReduceMotion` guard. Separate from topology/banner animations in M-VA-07. |
| **Accessibility impact** | Continuous meter animations may cause distraction or vestibular discomfort for affected users. |
| **Suggested remediation** | Apply the same `accessibilityReduceMotion` guard as recommended in M-VA-07. |
| **Risk of change** | Very low. |
| **Confidence** | Medium. |

---

### M-VA-15 — Dark-mode: `stateError` color not verified against backgrounds

| Field | Value |
|---|---|
| **Source** | VA-015 |
| **Theme** | VISUAL_ACCESSIBILITY |
| **Severity** | P2 |
| **File/component** | `AppDesignSystem.swift` |
| **Evidence** | All dark-mode state colors were reported as passing WCAG AA in the visual audit. However, the `stateError` dark variant was not separately computed against the actual dark-mode window background (not pure black). Confidence is medium. |
| **User impact** | Error state may be less visible in dark mode than believed. |
| **Suggested remediation** | Verify `stateError` dark-mode contrast against the actual macOS dark window background (`NSColor.windowBackgroundColor`). |
| **Risk of change** | None for the audit; very low for a fix. |
| **Confidence** | Medium. |

---

### M-VA-16 — Inconsistent font weight usage across status labels

| Field | Value |
|---|---|
| **Source** | VA-016 |
| **Theme** | VISUAL_ACCESSIBILITY |
| **Severity** | P3 |
| **File/component** | `AppShellSupportViews.swift`, `AppSessionStateBanner.swift` |
| **Evidence** | Status labels mix `.semibold`, `.medium`, and default weight with no documented hierarchy rule. |
| **User impact** | Minor — visual inconsistency reduces perceived polish. |
| **Suggested remediation** | Define a type scale in `AppDesignSystem` and apply consistently. |
| **Risk of change** | Low. |
| **Confidence** | Medium. |

---

### M-VA-17 — Spacing inconsistency in transport bar vs. sidebar items

| Field | Value |
|---|---|
| **Source** | VA-017 |
| **Theme** | VISUAL_ACCESSIBILITY |
| **Severity** | P3 |
| **File/component** | `AppTransportView.swift`, `AppShellRootView.swift` |
| **Evidence** | Transport bar padding values differ from sidebar item padding values with no apparent design rationale. |
| **User impact** | Minor visual inconsistency. |
| **Suggested remediation** | Align to spacing tokens in `AppDesignSystem`. |
| **Risk of change** | Very low. |
| **Confidence** | Medium. |

---

### M-VA-18 — No dynamic-type scaling in transport/status components

| Field | Value |
|---|---|
| **Source** | VA-018 |
| **Theme** | VISUAL_ACCESSIBILITY |
| **Severity** | P3 |
| **File/component** | `AppTransportView.swift`, `AppSessionStateBanner.swift` |
| **Evidence** | Fixed `.font(.caption)` and `.font(.title3)` used in transport and banner. SwiftUI does scale these with dynamic type, but explicit `.fixedSize()` calls in some subviews may suppress scaling. |
| **Accessibility impact** | Users with large text accessibility setting may see clipped or fixed-size text. |
| **Suggested remediation** | Remove `.fixedSize()` constraints that suppress dynamic type where layout allows. |
| **Risk of change** | Low. |
| **Confidence** | Low. Specific `.fixedSize()` usage requires visual verification. |

---

### M-VA-19 — Disabled transport buttons: no opacity or label change

| Field | Value |
|---|---|
| **Source** | VA-019 |
| **Theme** | VISUAL_ACCESSIBILITY |
| **Severity** | P3 |
| **File/component** | `AppTransportView.swift` |
| **Evidence** | When transport buttons are disabled (not in an actionable state), the custom button style may not visually indicate disabled state beyond the default SwiftUI disabled opacity. No alternative label ("Not available") is shown. |
| **User impact** | Minor — operator may try clicking disabled buttons without visual feedback. |
| **Suggested remediation** | Add explicit `.opacity(0.4)` and a tooltip explaining why the button is disabled. |
| **Risk of change** | Very low. |
| **Confidence** | Medium. |

---

### M-VA-20 — Hover/active states absent on custom button components

| Field | Value |
|---|---|
| **Source** | VA-020 |
| **Theme** | VISUAL_ACCESSIBILITY |
| **Severity** | P3 |
| **File/component** | `AppTransportView.swift`, `AppShellSupportViews.swift` |
| **Evidence** | Custom button styles do not define explicit hover or pressed states. macOS default button behavior may provide minimal visual feedback for hover. |
| **User impact** | Minor — no visual confirmation that a button is interactive before click. |
| **Suggested remediation** | Add `.onHover` or use `ButtonStyle` with `.isPressed` to provide hover/press feedback. |
| **Risk of change** | Very low. |
| **Confidence** | Medium. |

---

## 6. State / Behavior Findings

---

### M-SB-01 — Stop → false Error banner via SIGTERM exit code

| Field | Value |
|---|---|
| **Source** | SB-01 |
| **Theme** | STATE_BEHAVIOR |
| **Severity** | P0 |
| **File/component** | `AppExecutionController.swift`, `AppSessionStateBanner.swift` (`AppSessionState.derive`) |
| **Evidence** | `AppExecutionController.stop()` sends SIGTERM to the managed process. On macOS, SIGTERM produces a non-zero exit code. `AppSessionState.derive` in `AppSessionStateBanner` has a `default: break` for `.stopRequested` phase, then falls through to: `if let code = lastExitCode, code != 0 { return .error }`. Result: every user-initiated stop produces a `.error` session state and a red Error banner. |
| **What UI claims** | "Error" — something went wrong. |
| **What is proven** | User pressed Stop. Session ended normally. |
| **User/runtime impact** | Critical false positive. Operator is trained to respond to red Error banners. Every normal stop is a false alarm. Over time, operators ignore Error states — dangerous when a real error occurs. |
| **Suggested remediation** | In `derive`, explicitly handle `.stopRequested` phase by returning `.idle` or `.stopped` rather than falling through to the exit-code check. |
| **Test/manual verification** | Start a session. Press Stop. Observe banner state — should NOT be `.error`. |
| **Risk of change** | Low. One case branch in `derive`. |
| **Confidence** | High. Code path traced directly. |

---

### M-SB-02 — `commandIntent` set before `startArmed()` succeeds

| Field | Value |
|---|---|
| **Source** | SB-02 |
| **Theme** | STATE_BEHAVIOR |
| **Severity** | P0 |
| **File/component** | `OpenLolaApp.swift`, `AppExecutionController.swift` |
| **Evidence** | In `OpenLolaApp.swift`, the menu action sets `commandIntent = .runRequested` before calling `executionController.startArmed()`. If `startArmed()` throws or fails synchronously, the `commandIntent` is left as `.runRequested` with no active run. |
| **What UI claims** | "Run requested" intent — a run is either starting or started. |
| **What is proven** | Run was requested but may have failed to start. |
| **User/runtime impact** | Stale intent can mislead operators and confuse any downstream systems that read `commandIntent` to determine session state. |
| **Suggested remediation** | Set `commandIntent` only after `startArmed()` returns success. Use a `do/catch` to reset intent on failure. |
| **Risk of change** | Low. Reorder two lines in the call site. |
| **Confidence** | High. |

---

### M-SB-03 — All prior evidence silently wiped at run start

| Field | Value |
|---|---|
| **Source** | SB-03 |
| **Theme** | STATE_BEHAVIOR |
| **Severity** | P0 |
| **File/component** | `AppExecutionController.swift` (`launchProcess()`) |
| **Evidence** | `launchProcess()` clears: `latencyMetrics`, `captureReport`, `connectorReport`, `lastExitCode`, and `errorLog` before launching the new process. No snapshot is preserved. No confirmation is requested. |
| **What UI claims** | (Implicit) — prior session data is available in the evidence panels. |
| **What is proven** | Prior data is destroyed the moment the operator presses Start. |
| **User/runtime impact** | If the previous session produced a diagnostic report (e.g., showing a latency spike), it is unrecoverable once Start is pressed. Evidence for a failing session is lost before a recovery attempt. |
| **Suggested remediation** | Archive the prior run's evidence to a timestamped snapshot before clearing. Provide a "Previous run" view or at minimum a "Last run ended with errors" persistent indicator. |
| **Risk of change** | Medium. Requires an evidence archive structure. |
| **Confidence** | High. `launchProcess()` cleanup sequence confirmed in source. |

---

### M-SB-04 — Validation freshness: only file presence checked, not age

| Field | Value |
|---|---|
| **Source** | SB-05 |
| **Theme** | STATE_BEHAVIOR |
| **Severity** | P1 |
| **File/component** | `AppExecutionController.swift` (`validationReadiness`) |
| **Evidence** | `validationReadiness` calls `FileManager.default.fileExists(atPath:)` only. It does not check the file's modification date, size, or a session-scoped token. A report from a previous session (or a previous app run) passes the readiness check. |
| **What UI claims** | "Ready to validate" / "Evidence available." |
| **What is proven** | A file with the expected name exists at the expected path. |
| **Suggested remediation** | Add a session-scoped token (UUID written at run start) to the evidence file and check it during `validationReadiness`. Also check file modification date is within the current session window. |
| **Risk of change** | Medium. Touches evidence file contract. |
| **Confidence** | High. |

---

### M-SB-05 — Preview receiver status not integrated into main session state

| Field | Value |
|---|---|
| **Source** | SB-06 |
| **Theme** | STATE_BEHAVIOR |
| **Severity** | P1 |
| **File/component** | `AppPreviewReceiverView.swift`, `AppPreviewBindings.swift`, `AppConsoleModels.swift` |
| **Evidence** | The preview window (`WIN-02`) maintains `AppPreviewReceiverState` with its own `receiverStatus`. This status is not incorporated into `AppConsoleModels` or `AppSessionState.derive`. The main session banner can show `.live` while the local preview receiver has failed. |
| **What UI claims** | Main window says "Live" — session is running. |
| **What is proven** | Supervisor process is running. Local preview may or may not be receiving audio/video. |
| **Suggested remediation** | Integrate `receiverStatus` into `AppSessionState.derive`. If receiver is degraded, reflect this in the session banner (e.g., `.liveWithWarning`). |
| **Risk of change** | Medium. State derivation and model sharing change. |
| **Confidence** | Medium. Exact sharing vs. isolation is UNCLEAR (see Section 13). |

---

### M-SB-06 — "Last validator result" freshness label ignores exit code

| Field | Value |
|---|---|
| **Source** | SB-07 |
| **Theme** | STATE_BEHAVIOR |
| **Severity** | P1 |
| **File/component** | `AppShellSettingsTabs.swift`, `AppShellReadOnlyViews.swift` |
| **Evidence** | A "Last validated: [timestamp]" label is shown in the validation settings tab. This label updates when validation runs complete, regardless of whether the exit code was pass or fail. A failed validation still updates the freshness timestamp. |
| **What UI claims** | "Last validated [time]" — implies validation was recently performed and passed. |
| **What is proven** | Validation was run at that time. It may have failed. |
| **Suggested remediation** | Append the result to the freshness label: "Last validated [time] — PASSED" or "Last validated [time] — FAILED." |
| **Risk of change** | Very low. Label text change. |
| **Confidence** | High. |

---

### M-SB-07 — Status stuck at "Stop requested." after stop completes

| Field | Value |
|---|---|
| **Source** | SB-08 |
| **Theme** | STATE_BEHAVIOR |
| **Severity** | P1 |
| **File/component** | `AppSessionStateBanner.swift`, `AppExecutionController.swift` |
| **Evidence** | When `stop()` is called, `phase` transitions to `.stopRequested`. The banner displays "Stop requested." Once the process actually terminates and `phase` moves to `.runFinished`, the banner does not update immediately — it briefly shows the `.stopRequested` label. However, given M-SB-01, the banner then transitions to `.error`. The net effect is: "Stop requested." → (brief) → "Error." Neither state accurately represents a clean stop. |
| **What UI claims** | "Stop requested." then "Error." |
| **What is proven** | User pressed Stop; process terminated normally. |
| **Suggested remediation** | Fix M-SB-01 (SIGTERM exit code handling) first — this may resolve the stuck label as a side effect. Additionally ensure `.runFinished` phase with a clean stop produces a `.stopped`/`.idle` banner state, not `.error`. |
| **Risk of change** | Low (follows from M-SB-01 fix). |
| **Confidence** | High. |

---

### M-SB-08 — Validation-failed preflight blocker clears on phase change, not evidence change

| Field | Value |
|---|---|
| **Source** | SB-09 |
| **Theme** | STATE_BEHAVIOR |
| **Severity** | P1 |
| **File/component** | `AppExecutionView.swift`, `AppExecutionController.swift` |
| **Evidence** | When `phase == .validationFailed`, the preflight blocker is shown preventing START. This blocker clears when `phase` changes to any other value (e.g., `.idle`), regardless of whether new evidence was provided or whether the underlying failure was addressed. |
| **What UI claims** | Blocker cleared → "ready to start." |
| **What is proven** | Phase was reset. Validation failure condition may still be present. |
| **Suggested remediation** | Track a `lastValidationResult` flag separately from phase. Require a new validation pass (not merely a phase change) to clear the preflight blocker. |
| **Risk of change** | Medium. Requires separate validation-result state. |
| **Confidence** | High. |

---

### M-SB-09 — Preview window `receiverStatus` has race with main model

| Field | Value |
|---|---|
| **Source** | SB-10 |
| **Theme** | STATE_BEHAVIOR |
| **Severity** | P1 |
| **File/component** | `AppPreviewBindings.swift`, `OpenLolaApp.swift` |
| **Evidence** | `AppPreviewReceiverState` is instantiated in `OpenLolaApp`. Updates to `receiverStatus` from the background receiver thread may arrive out of order with main model updates if no explicit synchronisation is enforced. `@Observable` does not automatically serialise cross-actor updates. |
| **User impact** | Preview window status may briefly show a stale state (e.g., "connected" while main session is stopping). |
| **Suggested remediation** | Ensure `receiverStatus` mutations are dispatched on `@MainActor`. Audit `AppPreviewBindings` for async update paths. |
| **Risk of change** | Low to medium. |
| **Confidence** | Medium. Requires runtime observation to confirm race. |

---

### M-SB-10 — ARM state not cleared after Stop

| Field | Value |
|---|---|
| **Source** | SB-13 |
| **Theme** | STATE_BEHAVIOR |
| **Severity** | P2 |
| **File/component** | `AppExecutionController.swift` |
| **Evidence** | `stop()` sends SIGTERM but does not reset `armedForExecution`. After Stop completes, the operator remains in an armed state and can immediately re-start by pressing START — without re-confirming intent. |
| **What UI claims** | (Implicit) — ARM state persists. |
| **What is proven** | ARM state is not reset after stop. |
| **User/runtime impact** | Unintentional rapid restart of a session that was just stopped. |
| **Suggested remediation** | Reset `armedForExecution = false` in `stop()` or in the process termination handler. |
| **Risk of change** | Low. |
| **Confidence** | High. |

---

### M-SB-11 — Topology animation keyed on session state, not packet events

| Field | Value |
|---|---|
| **Source** | SB-14 |
| **Theme** | STATE_BEHAVIOR |
| **Severity** | P2 |
| **File/component** | `AppConnectionTopologyView.swift` |
| **Evidence** | The "live connection" topology animation is enabled when `sessionState == .live`. As noted in M-F-22, `.live` can be stale. Even when live state is real-time correct, the topology animates as "connected" without any packet-flow confirmation. There is no per-link packet-arrival indicator. |
| **What UI claims** | Active animated connection between nodes. |
| **What is proven** | `sessionState == .live`. Packets may or may not be flowing. |
| **Suggested remediation** | Short-term: key topology animation on `phase == .supervisorRunning`. Long-term: integrate packet arrival timestamps into topology node state. |
| **Risk of change** | Low (phase-based key). Medium (packet integration). |
| **Confidence** | High. |

---

### M-SB-12 — Settings locked during validation — no explanation

| Field | Value |
|---|---|
| **Source** | SB-16 |
| **Theme** | STATE_BEHAVIOR |
| **Severity** | P2 |
| **File/component** | `AppShellSettingsView.swift`, `AppRuntimeInputLock.swift` |
| **Evidence** | `AppRuntimeInputLock` locks the settings view when `isRunning == true`. Validation (`runOneShot`) also sets `isRunning = true`. The settings panel displays no message explaining why controls are locked. The banner does not indicate validation is running (see M-F-09). Net result: operator opens settings during validation and finds them locked with no explanation. |
| **Suggested remediation** | Surface the lock reason as a text overlay on the settings panel: "Settings locked — [validation / session] is running." |
| **Risk of change** | Very low. |
| **Confidence** | High. |

---

### M-SB-13 — `AppRuntimeInputLock` lock reason not surfaced in UI

| Field | Value |
|---|---|
| **Source** | SB-18 |
| **Theme** | STATE_BEHAVIOR |
| **Severity** | P2 |
| **File/component** | `AppRuntimeInputLock.swift` |
| **Evidence** | `AppRuntimeInputLock` has a `reason` property but it is not read by any UI component to display a tooltip or overlay message to the user. Controls simply become disabled/unresponsive. |
| **Suggested remediation** | Read `lockReason` in locked views and display it as a tooltip or inline label. |
| **Risk of change** | Very low. |
| **Confidence** | High. |

---

### M-SB-14 — "App Readiness" verdict reads smoke-test result, not session health

| Field | Value |
|---|---|
| **Source** | SB-19 |
| **Theme** | STATE_BEHAVIOR |
| **Severity** | P3 |
| **File/component** | `AppShellSettingsTabs.swift`, `NativeAppShellSyntheticSmoke` |
| **Evidence** | The "App readiness" verdict badge is produced by `NativeAppShellSyntheticSmoke.run()` — a static compile-time check. It does not test audio device availability, network connectivity, or runtime session health. |
| **What UI claims** | "App Ready" — the system is ready for a session. |
| **What is proven** | Static compile-time smoke test passed. |
| **Suggested remediation** | Rename to "Static checks passed" or "Build verified." Separately surface runtime readiness indicators. |
| **Risk of change** | Very low. Label change only. |
| **Confidence** | High. |

---

### M-SB-15 — Exit-code display does not distinguish clean stop from crash

| Field | Value |
|---|---|
| **Source** | SB-21 |
| **Theme** | STATE_BEHAVIOR |
| **Severity** | P3 |
| **File/component** | `AppShellReadOnlyViews.swift`, `AppExecutionController.swift` |
| **Evidence** | The session detail displays `lastExitCode` as a raw integer. A SIGTERM exit (code typically -15 or 143 on macOS) looks identical to a crash or unexpected termination to the operator. |
| **What UI claims** | Exit code [number]. |
| **What is proven** | Process exited with this code. No human-readable interpretation. |
| **Suggested remediation** | Map known exit codes to human-readable labels: "Terminated by operator (SIGTERM)", "Exited cleanly (0)", "Crashed (non-zero, unexpected)." |
| **Risk of change** | Very low. |
| **Confidence** | High. |

---

## 7. Duplicates Merged

The following raw source findings were merged into single master findings. All source IDs remain traceable.

| Master ID | Merged Source IDs | Reason for Merge |
|---|---|---|
| M-F-02 | F-02 + SB-17 | Same root cause: `AppSettings.didSet` writes `UserDefaults` on every keystroke. Identified independently by flow and state/behavior audits. |
| M-VA-07 | VA-007 + SB-24 | Same missing guard (`accessibilityReduceMotion`). VA-007 identified it on the banner pulse; SB-24 identified it on the topology dots. Both components need the same fix. |
| M-F-07 | F-07 + SB-23 | Same observation: three ARM entry points. Audits approached from navigation (F-07) and state coherence (SB-23) angles. |
| M-F-06 | F-06 + F-12 | Two flow findings independently noting the Packet Monitor dead-end. Merged as they describe the same surface. |
| M-F-05 | F-05 + SB-20 | Dead-end workflow modes with partially active transport. F-05 noted from navigation; SB-20 noted from behavior (transport not disabled). |
| M-F-11 | F-11 + SB-15 | Both note the in-memory `errorLog` cleared at run start. See also Section 8 for conflict over log-file disk persistence. |
| M-F-22 | F-24 + SB-12 | Topology animation on stale/non-packet-confirmed evidence. F-24 from navigation; SB-12 from state/behavior. Same root: `sessionState == .live` as the animation key. |
| M-F-10 | F-10 + F-23 | Two flow findings noting `commandIntent` menu items with no visible UI feedback. |
| M-F-09 | F-09 + SB-04 + SB-11 | Three findings converging on the validation-running state being aliased as `.awaitingEvidence`. |

**Total merges:** 9 merge groups reducing 19 raw findings to 9 master findings (net reduction: 10 findings).

---

## 8. Conflicts and Inconsistencies

### CONFLICT-01 — Log file disk persistence: "not persisted" vs. "files probably exist"

| Field | Value |
|---|---|
| **Source A** | F-11 (Flow audit, Medium confidence) |
| **Source B** | SB-03, SB-15 (State/Behavior audit) |
| **Claim A** | F-11: "The error log is not persisted. The UI does not surface a log file path or an 'Open in Finder' action." |
| **Claim B** | SB-03/SB-15: "The in-memory `errorLog` array is cleared at run start. `AppExecutionController.prepareLogFiles()` writes stdout/stderr to `stdoutPath`/`stderrPath` on disk — these files likely exist after a run." |
| **Nature of conflict** | F-11 focuses on in-memory persistence and UI surfacing (correct — neither is present). SB-03/SB-15 confirm the in-memory loss and note that disk files probably exist but are unreachable from the UI. The claims are complementary but differ in emphasis: F-11 implies no persistence at all; SB context implies disk persistence exists but is hidden. |
| **Resolution** | Both audits agree the UI has no "Open log file" affordance and the in-memory log is cleared. The open question is whether `stdoutPath`/`stderrPath` are written and accessible. **This cannot be resolved without either reading `prepareLogFiles()` output at runtime or tracing the method fully.** F-11's Medium confidence is appropriate. Master finding M-F-11 preserves this ambiguity and flags it as a verification gap. |
| **Verification needed** | Inspect `AppExecutionController.prepareLogFiles()` fully and check whether `stdoutPath`/`stderrPath` point to persistent on-disk locations. Run a session and check `~/Library/Logs/` or `NSTemporaryDirectory()` for log files after the in-memory log is cleared. |

### CONFLICT-02 — ARM control visibility: simultaneous vs. exclusive

| Field | Value |
|---|---|
| **Source A** | F-07 (Flow audit) — notes three ARM entry points but does not confirm co-visibility. |
| **Source B** | SB-23 (State/Behavior audit) — notes the same three entry points. |
| **Nature of conflict** | Neither audit fully resolved whether `AppTransportView` and `AppExecutionView` ARM controls are simultaneously visible in the same layout or are in different sections. If they are in different sections, the finding is navigation-style (user switches sections); if co-visible, the finding is a UI coherence bug where two controls can both display ARM state. |
| **Resolution** | Master finding M-F-07 preserves Medium confidence and flags this as UNCLEAR. |
| **Verification needed** | Open the app, navigate to "Session" section — confirm whether both the transport bar ARM button and the `AppExecutionView` toggle are visible simultaneously. |

---

## 9. Highest-Risk UI/UX Issues

The following issues represent the greatest combined risk to operator safety, session integrity, and user trust. Ordered by impact.

### 1. M-SB-01 (P0) — False Error banner after every normal Stop

Every successful Stop produces a red Error banner. This conditions operators to ignore Error states, causing them to miss real errors. This is a safety-critical false positive in a realtime audio production context.

**Immediate action:** Fix `AppSessionState.derive` to handle `.stopRequested` → `.runFinished` transition with a clean exit code as `.stopped`/`.idle`, not `.error`.

---

### 2. M-F-02 / M-SB-03 (P0) — Settings persist on keystroke; evidence wiped at run start

Two independent P0 issues with no recovery path: (a) any settings edit is immediately permanent, and (b) all diagnostic evidence from the prior run is unrecoverably destroyed the moment a new run starts. Together, these leave the operator with no ability to compare runs or roll back a setting change.

**Immediate action:** Add evidence archiving before `launchProcess()` clears state; add Save/Discard lifecycle to settings.

---

### 3. M-F-01 (P0) — "Live" state from stale on-disk evidence

The session state machine's most important claim — that a session is live — is not backed by realtime proof. Any operator decision based on the "Live" badge may be wrong.

**Immediate action:** Add session-scoped tokens to evidence files; check token before accepting evidence as live.

---

### 4. M-VA-01 (P0) — Warning banner 1.95:1 contrast in light mode

The most safety-relevant UI messages may be invisible to a significant portion of users. This compounds the false-alarm risk from M-SB-01: the operator cannot see a warning they should act on.

**Immediate action:** Replace SwiftUI `.orange` in the banner with a WCAG-compliant color token.

---

### 5. M-F-03 (P0) — No confirmation for ARM / START / STOP

A single accidental click or menu shortcut can terminate a live multi-participant audio session or unexpectedly arm/start a session. No confirmation dialog, no undo.

**Immediate action:** Add a confirmation dialog for Stop in `.live` state (minimum). Consider ARM confirmation for new users.

---

### 6. M-SB-02 (P0) — `commandIntent` race on startup failure

Stale intent state after a startup failure can mislead the operator and any monitoring system reading `commandIntent`. Less immediately dangerous than the above five, but represents a correctness violation in the state machine.

---

### 7. M-F-05 (P1) — JackTrip/UltraGrid dead-end with active transport

The operator can ARM and START against an explicitly unavailable workflow. Outcome is undefined and untested.

---

### 8. M-F-09 (P1) — Validation indistinguishable from "not started"

The operator cannot tell whether validation is running or has never started. Combined with M-F-12 (settings locked during validation with no explanation), this creates a confusing dead zone with no feedback.

---

### 9. M-VA-02 – M-VA-05 (P1) — Multiple state-color WCAG failures

Three of the five session state indicators fail WCAG 2.1 AA in light mode. Session states are the primary communication channel between the app and the operator. Unreliable contrast undermines the entire operator interface.

---

### 10. M-SB-03 + M-F-11 (P0/P1) — Evidence wipe + no log access

Evidence is destroyed silently and the operator has no way to recover it. If a session fails and the operator presses Start to retry, the failure evidence is gone.

---

## 10. Low-Risk UI Polish Candidates

These P3 findings carry no risk to operator safety or session integrity but would improve polish:

| Master ID | Title | Effort |
|---|---|---|
| M-F-26 | Sidebar "Execution" vs "Session" label inconsistency | Trivial |
| M-F-28 | Empty "Session Details" section — add empty state | Trivial |
| M-F-30 | No visual feedback that settings were saved | Very low |
| M-F-29 | No breadcrumb/back-navigation from detail panels | Low |
| M-VA-16 | Inconsistent font weight usage | Low |
| M-VA-17 | Spacing inconsistency: transport bar vs. sidebar | Very low |
| M-VA-19 | Disabled transport buttons — no tooltip | Very low |
| M-VA-20 | No hover/active states on custom buttons | Very low |
| M-SB-14 | "App Readiness" badge label misleading | Trivial |
| M-SB-15 | Exit code not human-readable | Very low |

---

## 11. Suggested Remediation Slices

These slices group findings by fix surface and effort to allow incremental delivery.

---

### Slice 1 — Critical State Machine Fixes (Highest Priority)

**Scope:** P0 state/behavior bugs with direct operator impact.
**Files:** `AppExecutionController.swift`, `AppSessionStateBanner.swift` (`derive`), `OpenLolaApp.swift`

1. Fix `AppSessionState.derive` for `stopRequested` → clean exit → not `.error` (M-SB-01, M-SB-07)
2. Move `commandIntent = .runRequested` to after `startArmed()` succeeds (M-SB-02)
3. Archive prior evidence before `launchProcess()` clears it (M-SB-03)
4. Add a distinct `.stopRequested` phase handling in the derive switch

**Estimated effort:** 1–2 days. High impact.

---

### Slice 2 — Warning Banner Contrast and Accessibility (P0/P1)

**Scope:** WCAG contrast failures on the banner and state color tokens.
**Files:** `AppDesignSystem.swift`, `AppSessionStateBanner.swift`

1. Replace banner warning color with WCAG-compliant token (M-VA-01)
2. Add light-mode variant for `stateArmed`, darken `stateReady`, `stateLive` (M-VA-02–04)
3. Add increased-contrast variants for all state color tokens (M-VA-05)
4. Add `.accessibilityRole(.alert)` to the banner (M-VA-06)
5. Add `accessibilityReduceMotion` guard to banner pulse animation (M-VA-07)

**Estimated effort:** 0.5–1 day. No logic changes.

---

### Slice 3 — Settings Save/Discard Lifecycle (P0)

**Scope:** Replace keystroke-immediate persistence with explicit Save/Discard.
**Files:** `AppSettings.swift`, `AppShellSettingsView.swift`

1. Replace `didSet` writes with a buffer-and-commit pattern (M-F-02)
2. Add Save and Discard buttons to the settings window toolbar
3. Add confirmation if settings window is closed with unsaved changes

**Estimated effort:** 2–3 days. Requires settings architecture change.

---

### Slice 4 — Stop Confirmation and ARM Reset (P0/P2)

**Scope:** Prevent accidental stop and stale ARM state.
**Files:** `AppTransportView.swift`, `AppExecutionController.swift`

1. Add `.confirmationDialog` before Stop when `sessionState == .live` (M-F-03, M-F-20)
2. Reset `armedForExecution = false` in `stop()` (M-SB-10)

**Estimated effort:** 0.5 day.

---

### Slice 5 — Validation State Display (P1)

**Scope:** Make validation running state visible and distinct.
**Files:** `AppSessionStateBanner.swift`, `AppExecutionController.swift`, `AppShellSettingsTabs.swift`

1. Add `.validating` to `AppSessionState.derive` when `phase == .validationRunning` (M-F-09)
2. Show progress indicator in banner during validation (M-F-09)
3. Add lock reason overlay on settings when locked by validation (M-F-12, M-SB-12, M-SB-13)
4. Append pass/fail to "Last validated" timestamp label (M-SB-06)
5. Add keyboard shortcut hint (⌘⇧V) to Settings > Validation tab (M-F-13)

**Estimated effort:** 1 day.

---

### Slice 6 — Dead-End Workflow Modes (P1)

**Scope:** Prevent transport from being active in unavailable modes.
**Files:** `AppWorkflowUnavailableView.swift`, `AppTransportView.swift`, `AppConsoleModels.swift`

1. Disable ARM/START/STOP when `selectedWorkflow` is unavailable (M-F-05)
2. Replace jargon in `AppWorkflowUnavailableView` with user-facing copy (M-F-05)
3. Add meaningful empty state to Packet Monitor (M-F-06)

**Estimated effort:** 0.5 day.

---

### Slice 7 — Session State Accuracy (P1)

**Scope:** Prevent stale evidence from triggering Live state or topology animation.
**Files:** `AppExecutionController.swift`, `AppRuntimeEvidenceScope.swift`, `AppConnectionTopologyView.swift`

1. Add session-scoped token to evidence files; check in `validationReadiness` and `hasValidatedRuntimeEvidence` (M-F-01, M-SB-04)
2. Key topology animation on `phase == .supervisorRunning` not `sessionState == .live` (M-F-22, M-SB-11)
3. Add `accessibilityReduceMotion` guard to topology animation (M-VA-07)

**Estimated effort:** 1–2 days.

---

### Slice 8 — Transport Bar Visibility and Session Banner CTAs (P1)

**Scope:** Make primary controls discoverable.
**Files:** `AppShellRootView.swift`, `AppSessionStateBanner.swift`

1. Move transport bar to persistent footer or global toolbar (M-F-04)
2. Add CTA to session banner in `.ready` and `.armed` states (M-F-08)
3. Auto-navigate sidebar to "Session" on `.live` transition (M-F-18)

**Estimated effort:** 1–2 days. Layout change required.

---

### Slice 9 — Handoff Intent and Command Intent Visibility (P1)

**Scope:** Surface `commandIntent` in the UI.
**Files:** `OpenLolaApp.swift`, `AppConsoleModels.swift`, detail panel views

1. Add read-only `commandIntent` display to session details or transport bar (M-F-10)
2. Add visual acknowledgement when intent changes via menu actions

**Estimated effort:** 0.5 day.

---

### Slice 10 — Accessibility: Focus, Labels, Hit Targets (P1/P2)

**Scope:** VoiceOver and keyboard accessibility improvements.
**Files:** `AppTransportView.swift`, `AppChannelMeterView.swift`, `AppLatencyHeroView.swift`, `AppShellRootView.swift`

1. Verify/restore focus ring on transport buttons (M-VA-08)
2. Add `accessibilityValue` to channel meters (M-VA-10)
3. Add `accessibilityLabel` with unit to latency hero (M-VA-11)
4. Add explicit `accessibilityLabel` to sidebar items (M-VA-12)
5. Add `contentShape` + minimum 44 pt hit targets to interactive elements (M-VA-09)
6. Add state-specific icon prefix to session banner (M-VA-13)
7. Add `accessibilityReduceMotion` guard to meter animations (M-VA-14)

**Estimated effort:** 1 day.

---

### Slice 11 — Error Log Access and Session Evidence UX (P1/P2)

**Scope:** Give operators access to diagnostic evidence.
**Files:** `AppOperatorArtifactViews.swift`, `AppExecutionController.swift`

1. Auto-expand error disclosure in `.error` state (M-F-24)
2. Add "Open in Console.app" / "Show in Finder" log file button if `stdoutPath`/`stderrPath` are on disk (M-F-11 — verify first per CONFLICT-01)
3. Archive previous run's evidence snapshot before clearing (M-SB-03, follow-up from Slice 1)

**Estimated effort:** 0.5–1 day (pending CONFLICT-01 resolution).

---

### Slice 12 — Polish and Terminology (P2/P3)

Lower priority. Batch with any existing refactor pass.

1. Standardise ARM/Live/Run/Session/Execution terminology (M-F-19, M-F-26)
2. Add dry-run badge to session detail (M-F-21)
3. Rename "App Readiness" to "Static checks passed" (M-F-14, M-SB-14)
4. Persist selected settings tab (M-F-25)
5. Human-readable exit code display (M-SB-15)
6. Remove or wire sidebar count badges (M-F-16)
7. Reassign ⌘R shortcut or document it (M-F-17)
8. Add "Session Details" empty state (M-F-28)
9. Add ⌘Q confirmation when live (M-F-27)

---

## 12. Verification Strategy

### Automated checks

| Check | Scope | Tool |
|---|---|---|
| WCAG contrast ratios | All color tokens in `AppDesignSystem.swift` | Python `colorsys` script (used in VA audit); automate in CI |
| Accessibility label coverage | All interactive components | Xcode accessibility inspector; UI test with `XCUIElement.label` checks |
| Settings persistence test | `AppSettings.didSet` writes `UserDefaults` | XCTest: write setting, read `UserDefaults` — verify not written without explicit save (once Slice 3 lands) |
| Exit code handling | `AppSessionState.derive` for `stopRequested` phase | XCTest unit test on `derive` with mocked phase + exit code |
| Session token validation | `validationReadiness` and `hasValidatedRuntimeEvidence` | XCTest: provide stale file without session token — verify `false` returned |

### Manual test checklist

1. **Stop flow:** Start a session, press Stop — verify banner shows `.stopped`/`.idle`, NOT `.error`. (M-SB-01)
2. **Stale evidence:** Run a session, quit app, relaunch — verify "Live" badge does NOT appear. (M-F-01, M-SB-04)
3. **Settings race:** Open settings, type in a text field, immediately close — open settings again — verify value persisted (documents current P0 behavior pre-fix). (M-F-02)
4. **Evidence wipe:** Start a session with evidence present — verify evidence panels clear before new run output appears. (M-SB-03)
5. **Validation progress:** Trigger validation (⌘⇧V) — verify banner shows distinct "Validating…" state and not "awaiting evidence." (M-F-09)
6. **JackTrip mode:** Switch to JackTrip workflow — verify ARM/START are disabled. (M-F-05)
7. **Packet Monitor:** Navigate to Packet Monitor in `.ready` state — verify meaningful empty state, not blank. (M-F-06)
8. **Topology on stale:** Produce stale evidence (prior run report), launch app — verify topology is NOT animated. (M-F-22)
9. **Keyboard navigation:** Tab through the transport bar — verify all controls are focusable and focus ring is visible. (M-VA-08)
10. **VoiceOver session state:** Enable VoiceOver, trigger `.error` state — verify VoiceOver announces the state change. (M-VA-06)
11. **Reduce Motion:** Enable "Reduce Motion" in macOS accessibility — verify banner and topology do not animate. (M-VA-07)
12. **Light mode contrast:** Enable Light Mode — verify warning banner, armed, ready, and live state labels are legible. (M-VA-01–04)
13. **Settings lock reason:** Trigger validation — open settings — verify a reason label is visible explaining why settings are locked. (M-SB-12, M-SB-13)
14. **ARM state after stop:** ARM the session, then stop without starting — verify ARM state is cleared. (M-SB-10)
15. **commandIntent cleanup:** Trigger a START that fails — verify `commandIntent` is NOT `.runRequested` after failure. (M-SB-02)

### Hardware / runtime gates (not fully coverable by static analysis)

- Audio device availability under live session conditions
- Real-time packet-flow confirmation for topology (requires live P2P session)
- SIGTERM exact exit code verification on macOS
- Preview receiver status race (requires concurrent main + preview window state testing)

---

## 13. Remaining Uncertainty

The following questions could not be resolved from static source analysis alone. They are preserved from source audits and noted explicitly to prevent false closure.

| # | Question | Affected Master IDs | How to resolve |
|---|---|---|---|
| U-01 | Does `lastValidationExitCode` or any validation result persist across app launches in `AppShellStoredDefaults`? | M-SB-04, M-SB-08 | Inspect `AppShellStoredDefaults` key list and the stored defaults read path in `AppExecutionController`. |
| U-02 | Are `AppTransportView` ARM button and `AppExecutionView` ARM toggle simultaneously visible in any layout configuration? | M-F-07 | Open the app, navigate to the Session section, and inspect the layout with both controls in view. |
| U-03 | What exact exit code does SIGTERM produce on macOS (from `Process.terminate()`)? Is it `-15`, `143`, or another value? | M-SB-01, M-SB-07, M-SB-15 | Run a session with `Process.terminate()`, capture `terminationStatus` via print/log. |
| U-04 | Does `AppPreviewReceiverState.receiverStatus` appear in the main window or only in the preview window? | M-SB-05, M-SB-09, M-F-15 | Inspect `AppShellRootView` for any `receiverStatus` binding. Check whether `AppConsoleModels` exposes it. |
| U-05 | Does `AppExecutionController.prepareLogFiles()` write to a persistent on-disk path (not a temp directory)? | M-F-11, CONFLICT-01 | Read `prepareLogFiles()` fully; check `stdoutPath`/`stderrPath` computation. Run a session and check for log files in `~/Library/Logs/` or app container. |
| U-06 | Are sidebar count badges wired to any live data source, or are they always zero? | M-F-16 | Search for assignments to the badge count property in `AppShellRootView` and `AppConsoleModels`. |
| U-07 | Does `⌘R` ("Refresh Synthetic Metrics") conflict with any embedded web view or navigation stack in the app? | M-F-17 | Check whether any `WKWebView` or `NavigationStack` is present in the view hierarchy. |
| U-08 | Is `AppPreviewReceiverState` shared with the main window model (same instance) or independent? | M-SB-09, M-F-15 | Trace the `AppPreviewReceiverState` instantiation in `OpenLolaApp.swift` and its injection into both the main and preview windows. |
| U-09 | Do custom button styles in `AppTransportView` suppress the default SwiftUI focus ring? | M-VA-08 | Enable keyboard navigation (Full Keyboard Access in macOS), Tab to transport buttons, observe focus ring. |
| U-10 | Does the app have an `applicationShouldTerminate` or `NSApplicationDelegate` guard for live sessions before ⌘Q? | M-F-27 | Search `AppDelegate` (if present) and `OpenLolaApp.swift` for termination lifecycle hooks. |

---

*End of Open LoLa App — Consolidated UI/UX Master Audit.*
*Production code changes: None. All findings are from static source analysis only.*
