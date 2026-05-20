# Open LoLa App — UI/UX Flow Audit

**Date:** 2026-05-19
**Scope:** `Sources/open-lola-app/` (34 Swift UI files) and `Sources/OpenLolaCore/Platform/`.
**Method:** Static source read of all UI Swift files; cross-reference with `docs/uiux-surface-index.md`.
**Production code changes:** None.

---

## Table of Contents

1. [All Findings by Severity](#1-all-findings-by-severity)
2. [Blocked Core Workflows](#2-blocked-core-workflows)
3. [Confusing Workflows](#3-confusing-workflows)
4. [Navigation and Menu Issues](#4-navigation-and-menu-issues)
5. [Suggested Information-Architecture Cleanup](#5-suggested-information-architecture-cleanup)
6. [Remaining Uncertainty](#6-remaining-uncertainty)

---

## 1. All Findings by Severity

---

### F-01 · P0 · False "Live" status without confirmed media flow

| Field | Value |
|-------|-------|
| **Severity** | P0 |
| **File / Component** | `AppDesignSystem.swift` → `AppSessionState.derive`, `AppSessionStateBanner.swift` |
| **User flow affected** | WF-02 Run a session; any active session monitoring |
| **Evidence** | `AppSessionState.derive` sets `.live` from `hasValidatedRuntimeEvidence == true`. `hasValidatedRuntimeEvidence` is set by the execution controller based on report validation, not on confirmed real-time packet or media flow. The banner shows "Live" with green color and `checkmark.seal.fill`. |
| **Why it hurts** | Users see a green "Live" banner and believe audio/video is actively flowing when in fact only a report validation has passed. A session where media never flowed but whose report passed syntactic validation will show as "Live". |
| **Suggested remediation** | Label the state "Validated" or "Evidence confirmed" rather than "Live". Reserve green "Live" only if a confirmed real-time frame or packet stream is measurable. If live-stream confirmation is not technically feasible, add a sub-label clarifying "last validation passed — not a real-time stream indicator". |
| **Verification needed** | Confirm what `hasValidatedRuntimeEvidence` actually certifies at the protocol level. Inspect `AppExecutionController` validation logic. |
| **Confidence** | High — source reads confirmed state derivation. |

---

### F-02 · P0 · Settings persist immediately with no Apply / Cancel

| Field | Value |
|-------|-------|
| **Severity** | P0 |
| **File / Component** | `AppSettings.swift` (`didSet` → `UserDefaults`), all settings tab files |
| **User flow affected** | WF-01 First-launch setup; WF-04 Windows LoLa session setup; any settings edit |
| **Evidence** | `AppSettings.swift`: every property uses `didSet { UserDefaults.standard.set(...) }`. There is no pending-change buffer, Apply button, or Cancel/Revert option in any settings tab. The Settings window help text reads "Changes apply to the next generated command or validation." |
| **Why it hurts** | A user who accidentally changes a port number, sample rate, or executable path during an active session immediately corrupts the saved config for all subsequent sessions. There is no undo. This is especially dangerous during arming (when the configuration is supposed to be locked) because settings mutation can happen from the Settings window even when `AppRuntimeInputLock` is active in the main console — Settings window inputs are not confirmed to be locked by the same mechanism (UNCLEAR — see RU-01). |
| **Suggested remediation** | Buffer settings changes in a local copy; expose an Apply button or at minimum a Revert to Saved button. At minimum, ensure all Settings window controls are locked (disabled) via the same `AppRuntimeInputLock` while a process is active. |
| **Verification needed** | Confirm whether Settings window text fields are disabled when `executionController.isRunning`. Inspect `AppShellSettingsView` lock behavior. |
| **Confidence** | High — `AppSettings.didSet` confirmed from source. |

---

### F-03 · P0 · No confirmation before ARM, START, or STOP

| Field | Value |
|-------|-------|
| **Severity** | P0 |
| **File / Component** | `AppTransportView.swift`, `OpenLolaApp.swift` (CommandMenu), `AppExecutionView.swift` (arm toggle) |
| **User flow affected** | WF-02 Run a session |
| **Evidence** | ARM, DRY RUN, START, STOP buttons in `AppTransportView` have direct action handlers — no `Alert` or confirmation sheet before dispatching. Same for `⌘⇧E` menu shortcut. `AppExecutionView` includes a `Toggle("Arm execution")` that arms/disarms with a tap. |
| **Why it hurts** | START launches an external realtime subprocess that acquires audio and video devices and initiates UDP traffic. An accidental keypress (`⌘⇧E`) arms execution; a subsequent `⌘⇧P` starts the supervisor. STOP terminates a live session without warning, potentially causing an abrupt audio cut for connected peers. |
| **Suggested remediation** | Show a confirmation `Alert` for START (listing the CLI command that will run and the peer endpoints) and for STOP during a `.live` / `.supervisorRunning` state. ARM does not need confirmation but should have clear visual state so the accidental arm is obvious before START. |
| **Verification needed** | Test `⌘⇧E` then `⌘⇧P` sequence to confirm no intervening confirmation. |
| **Confidence** | High — source confirms no `Alert` before transport actions. |

---

### F-04 · P1 · No first-run onboarding; app opens to a misleading state

| Field | Value |
|-------|-------|
| **Severity** | P1 |
| **File / Component** | `AppShellRootView.swift` default `selectedSection = .overview`, `AppConsoleModels.swift` `AppOverviewOperatorSummary` |
| **User flow affected** | WF-01 First-launch setup |
| **Evidence** | On first launch, `@SceneStorage` defaults to `.overview`. The Overview section shows: source verdict "PARTIAL" (orange), a status strip with "Setup required", a Next Action panel with "Configure devices" → button "Open Devices". The session state banner shows MSG-01 "Configure your audio devices and peer addresses to get started." |
| **Why it hurts** | The first thing a new user sees is a panel labeled "Overview" dominated by orange "PARTIAL" indicator and several fields showing "Missing" / "Not run" / "Idle." The correct starting action is in the Devices section but requires clicking through the Overview's "Next Action" button or navigating the sidebar. The `AppUnavailableSectionView` "Go to Devices Setup" button only appears when `selectedSection` is nil/unavailable — it does not appear when Overview is selected. |
| **Suggested remediation** | Either (a) change the first-launch default section to `.devices` when the plan is unconfigured, or (b) make the Overview "Next Action" button more prominent, or (c) add a one-time welcome / setup dialog. The "Go to Devices Setup" button in `AppUnavailableSectionView` is already written — consider routing first-launch users there. |
| **Verification needed** | Confirm `@SceneStorage` initial value behavior on a fresh install (no stored key). Verify whether Overview can detect "first launch" vs. "configured but incomplete". |
| **Confidence** | High — `@SceneStorage` default `.overview` confirmed; Overview content confirmed. |

---

### F-05 · P1 · JackTrip and UltraGrid are selectable modes that lead to a dead end

| Field | Value |
|-------|-------|
| **Severity** | P1 |
| **File / Component** | `AppShellSettingsTabs.swift` workflow picker, `AppShellRootView.swift` `AppShellDetailView` section router, `NativeAppShellSessionMode.swift` |
| **User flow affected** | Any user selecting JackTrip or UltraGrid mode (WF-01 variant) |
| **Evidence** | The Execution settings tab includes a Workflow picker with all four modes (directMacPeer, windowsLoLa, jackTrip, ultraGrid). For jackTrip/ultraGrid, `sessionMode.supportsAppExecution == false` and all detail panels show `AppWorkflowUnavailableView`. The transport bar is presumably inoperative. `unavailableAppReason` text: "…this app has no wired runtime launcher for it yet. Use the external connector or NMP CLI contracts." |
| **Why it hurts** | A user who selects "JackTrip" finds every main section of the app non-functional with no clear path forward. The message references "NMP CLI contracts" — unfamiliar jargon. There is no link to documentation, the CLI, or the `linux_connector` path. |
| **Suggested remediation** | (a) Clearly mark JackTrip and UltraGrid in the Workflow picker as "External CLI only" with a `ℹ` tooltip before the user selects them. (b) In the unavailable view, replace "NMP CLI contracts" with an actionable link or path: e.g. "Use `python -m linux_connector.lola_connector.cli …` — see README for details." |
| **Verification needed** | Confirm the transport bar ARM button is disabled (not just the section panels) for these modes. |
| **Confidence** | High — `unavailableAppReason` string and detail panel routing confirmed. |

---

### F-06 · P1 · Packet Monitor is unreachable without completing a full session

| Field | Value |
|-------|-------|
| **Severity** | P1 |
| **File / Component** | `AppConsoleSectionSelection.isAvailable`, `AppConsoleSidebarView`, `AppPacketMonitorView.swift`, `AppConsoleModels.swift` `AppPacketMonitorEmptyState` |
| **User flow affected** | WF-03 Packet monitor review |
| **Evidence** | `AppConsoleSectionSelection.isAvailable` gates Packet Monitor only from `.unconfigured` state. However, the section shows an empty state ("Packet evidence unavailable … No decoded LoLa compatibility capture report is loaded") whenever `captureReport == nil`. The empty state action button reads "Run and validate evidence" and navigates to `.session`. There is no mechanism in the app to load a capture report file directly from disk. |
| **Why it hurts** | The Packet Monitor panel is navigable (sidebar item active in non-unconfigured states) but shows nothing useful until a full supervisor session has been run AND produced a capture report. New users who navigate there see a dead-end empty state. The "Run and validate evidence" CTA is accurate but puts a full realtime session between the user and this debugging tool. |
| **Suggested remediation** | Add a "Load report file…" button to the empty state (opens a file picker for the capture report JSON). This matches the existing file-path model used in artifact views. Separately, clarify the sidebar item's visual treatment — should it remain fully active or be visually muted while no data is loaded? |
| **Verification needed** | Confirm whether the sidebar visually grays out the Packet Monitor item when `captureReport == nil` (source unclear from read; may depend on `AppConsoleSidebarView` implementation). |
| **Confidence** | High for the empty state logic; Medium for sidebar visual treatment. |

---

### F-07 · P1 · Three independent ARM entry points with no unified state

| Field | Value |
|-------|-------|
| **Severity** | P1 |
| **File / Component** | `AppTransportView.swift` ARM button, `AppExecutionView.swift` `Toggle("Arm execution")`, `OpenLolaApp.swift` CommandMenu MNU-03 `⌘⇧E` |
| **User flow affected** | WF-02 Run a session |
| **Evidence** | ARM can be triggered from: (1) transport bar ARM/DISARM button, (2) `Toggle("Arm execution")` in the Session section's `AppExecutionView`, (3) CommandMenu "Arm Execution" / `⌘⇧E`. All three dispatch the same `arm-execution` action. |
| **Why it hurts** | Users encounter the ARM concept in two different sections (Session header and Session body) plus the menu. The toggle in `AppExecutionView` and the button in `AppTransportView` are both visible when the user is in the Session section. If they diverge visually (e.g. one refreshes slower), users may try both and be confused about which is authoritative. |
| **Suggested remediation** | Consolidate ARM into a single canonical location (the transport bar) and remove the duplicate `Toggle("Arm execution")` from `AppExecutionView`, or ensure the toggle is clearly labeled as an alias with consistent state synchronization. The menu shortcut `⌘⇧E` can remain as it mirrors the transport bar. |
| **Verification needed** | Confirm whether `AppExecutionView` toggle and transport bar ARM button share the same `executionController.armedForExecution` binding and render identically. |
| **Confidence** | High — three entry points confirmed in source. |

---

### F-08 · P1 · Session is the execution hub but navigation defaults to Overview

| Field | Value |
|-------|-------|
| **Severity** | P1 |
| **File / Component** | `AppShellRootView.swift` `@SceneStorage selectedSection = .overview`, `AppConsoleModels.swift` next-action routing |
| **User flow affected** | WF-02 Run a session (most critical path) |
| **Evidence** | The default section is `.overview`. Overview's "Next Action" panel provides a button to navigate to `.session` when configuration is complete ("Arm or dry-run → Open Session"). This requires: (1) user reads Overview, (2) notices Next Action panel, (3) clicks "Open Session" button, (4) arrives at Session. The transport bar is in the Session section, not globally visible. |
| **Why it hurts** | The transport bar (ARM/START/STOP) is hidden in the Session section. Users who skip Overview and navigate directly to a non-Session section miss it. There is no persistent global transport control across all sections. The session state banner tells users to ARM but the ARM button is not visible from that banner. |
| **Suggested remediation** | Either (a) move the transport bar to the app chrome (always visible below the session state banner, above the section content) so ARM/STOP are reachable from any section, or (b) add an inline ARM button to the session state banner in the `.ready` state. Option (a) aligns with how professional audio tools (DAWs, broadcast controllers) position transport controls. |
| **Verification needed** | Confirm the session state banner's `onGoToSetup` CTA only fires for `.unconfigured` — not for `.ready` state. If so, the banner gives no navigation CTA for the most common action (ARM). |
| **Confidence** | High — banner `onGoToSetup` limited to `.unconfigured` confirmed in source. |

---

### F-09 · P1 · VALIDATE button absent when no report exists; no guidance

| Field | Value |
|-------|-------|
| **Severity** | P1 |
| **File / Component** | `AppTransportView.swift` VALIDATE button condition, `AppExecutionView.swift` validation error messages |
| **User flow affected** | WF-02 Step 7 — Validate session |
| **Evidence** | VALIDATE button renders conditionally when `!isRunning && hasReport`. When `hasReport == false`, the button is not shown at all — not disabled with a tooltip, not replaced by an explanation. `AppExecutionController` does have error strings "Cannot validate missing report artifact: …" but these are shown after a failed attempt, not proactively. |
| **Why it hurts** | After a first session, a user who stops the run looks at the transport bar and sees no VALIDATE button. They have no in-context guidance that a report must exist at the configured path before validation can run. They might assume validation is unavailable for their workflow. |
| **Suggested remediation** | Show VALIDATE as a disabled button with a tooltip ("No report artifact found at `[path]`") rather than hiding it entirely. The path in the tooltip gives the user a direct diagnostic clue. |
| **Verification needed** | Confirm the exact condition for `hasReport`. Inspect whether it checks file existence on disk or only whether the controller has a path configured. |
| **Confidence** | High — conditional render confirmed; no tooltip/disabled state path found. |

---

### F-10 · P1 · "Set Handoff Intent" menu item has no visible effect

| Field | Value |
|-------|-------|
| **Severity** | P1 |
| **File / Component** | `OpenLolaApp.swift` MNU-06, `NativeAppShellSurfaceContract.swift` action `set-handoff-intent` |
| **User flow affected** | Operator handoff workflow (unclear — see RU) |
| **Evidence** | MNU-06 "Set Handoff Intent" dispatches `set-handoff-intent` which sets `operatorCommandIntent = .handoffRequested`. No panel, badge, dialog, or banner reflects this state change visibly. The action contract sets `operatorCommandIntent: .handoffRequested` and `launchesExternalProcess: false`. |
| **Why it hurts** | A user who invokes this item sees nothing happen. There is no feedback confirming the intent was set, no indication of what happens next, and no way to clear the intent except via the separate "Clear Command Intent" menu item. The workflow is invisible and confusing. |
| **Suggested remediation** | Either (a) add a banner or badge that shows "Handoff intent set — waiting for supervisor pickup" with a Clear button, or (b) remove this item from the public menu if it is an internal development tool not intended for end users. |
| **Verification needed** | Determine whether handoff intent is used in any visible UI path. Search for `.handoffRequested` rendering in all views. |
| **Confidence** | High — action confirmed; no visual response found in any view read. |

---

### F-11 · P1 · Session log not persisted; failures irrecoverable after restart

| Field | Value |
|-------|-------|
| **Severity** | P1 |
| **File / Component** | `AppExecutionView.swift` log panel, `AppExecutionController.swift` |
| **User flow affected** | WF-02 error recovery; any post-session debugging |
| **Evidence** | The session log panel in `AppExecutionView` shows `executionController.logLines` (stdout/stderr from the subprocess). No log file path is surfaced in the UI. No persistence mechanism is visible. On app restart, `AppExecutionController` re-initializes and log lines are gone. |
| **Why it hurts** | If a session fails with a cryptic error at 3 AM and the user closes the app (or it crashes), all diagnostic output is lost. The session banner for `.error` state says "check Session tab for details" but after a restart, Session tab shows nothing. |
| **Suggested remediation** | Write subprocess stdout/stderr to a file (e.g. in the same output directory as the session report). Surface the log file path in `AppExecutionView` with an "Open log file" button. At minimum, persist the last `N` log lines to `UserDefaults` across restarts. |
| **Verification needed** | Confirm whether `AppExecutionController` already writes to a file and `AppExecutionView` simply doesn't surface it. Inspect controller subprocess launch. |
| **Confidence** | Medium — no log file path surface found; log persistence not confirmed from source. |

---

### F-12 · P1 · Packet Monitor section availability logic inconsistency

| Field | Value |
|-------|-------|
| **Severity** | P1 |
| **File / Component** | `AppConsoleModels.swift` `AppConsoleSectionSelection.isAvailable`, sidebar description |
| **User flow affected** | WF-03 Packet monitor review |
| **Evidence** | `AppConsoleSectionSelection.isAvailable` gates Packet Monitor only when `sessionState == .unconfigured`. In all other states (ready, armed, live, error, etc.), Packet Monitor is returned as "available" regardless of `captureReportAvailable`. However, the sidebar was documented as "disabled until `captureReport` loaded". The `AppUnavailableSectionView` special-cases packet monitor text when `!captureReportAvailable`. |
| **Why it hurts** | The Packet Monitor sidebar item appears navigable (no visual lock) in states beyond `.unconfigured`, but navigating to it with no data produces an empty-state dead end. Users click a seemingly available section and find nothing. The inconsistency between "sidebar looks active" and "panel has nothing" is a broken affordance. |
| **Suggested remediation** | Apply a consistent visual treatment: either (a) gray/badge the sidebar item when `captureReport == nil` (matching the `AppUnavailableSectionView` message), or (b) show the empty state with a "Load report file…" button (see F-06). |
| **Verification needed** | Read `AppConsoleSidebarView` fully to confirm whether it passes `captureReportAvailable` to any per-item rendering. |
| **Confidence** | Medium — `isAvailable` logic confirmed; sidebar visual treatment not fully confirmed. |

---

### F-13 · P2 · DRY RUN and START have equal visual weight; no sequence guidance

| Field | Value |
|-------|-------|
| **Severity** | P2 |
| **File / Component** | `AppTransportView.swift` |
| **User flow affected** | WF-02 Run a session |
| **Evidence** | After arming, both DRY RUN and START are active simultaneously. Both are rendered as buttons in the transport bar. `DRY RUN` dispatches `dry-run-supervisor` (no realtime media, `launchesExternalRealtimeProcess: false`). `START` dispatches `start-armed-supervisor` (`launchesExternalRealtimeProcess: true`). No tooltip or label distinguishes the consequence. |
| **Why it hurts** | Users unfamiliar with the dry-run concept may press START immediately after arming without trying DRY RUN first. The recommended safe sequence (dry-run first, then START) is not communicated. Users may also accidentally press DRY RUN when they intend START, not understanding the difference. |
| **Suggested remediation** | Visually differentiate DRY RUN (secondary/outlined style) from START (primary/filled style). Add a tooltip to DRY RUN: "Test command generation without starting real-time audio/video." Consider showing DRY RUN first in tab order or adding an ordered sequence hint (e.g. "Step 1 (optional)" label). |
| **Verification needed** | Confirm button rendering styles in `AppTransportView`. |
| **Confidence** | High — both buttons active simultaneously confirmed; no distinguishing tooltips found. |

---

### F-14 · P2 · Overview status strip largely duplicates toolbar and footer badges

| Field | Value |
|-------|-------|
| **Severity** | P2 |
| **File / Component** | `AppShellRootView.swift` `AppOverviewStatusStrip`, `AppConsoleChromeView.swift` top bar + footer |
| **User flow affected** | WF-01 and WF-02 — overview monitoring |
| **Evidence** | Overview shows 5 status cards: Readiness, Session, Execution, Validation, Packet Evidence. The toolbar shows Verdict, Execution, Validation badges. The footer shows Packet, Remote Stream, Verdict badges. Many values overlap: Execution appears in both Overview status strip and toolbar; Verdict appears in both Overview (via evidence panel) and toolbar and footer. |
| **Why it hurts** | Users see the same status information in 3 places. When they diverge (due to refresh timing), it creates confusion about which is authoritative. The duplicated badges consume cognitive space without adding value. |
| **Suggested remediation** | Reserve the toolbar/footer for persistent global status. Make the Overview status strip additive (e.g., show only information not in the persistent chrome: plan readiness, remote inventory status, evidence freshness). Remove direct Execution and Validation duplication. |
| **Verification needed** | Confirm exact field mapping between Overview strip and toolbar/footer badges. |
| **Confidence** | High — field names confirmed from both source locations. |

---

### F-15 · P2 · Search field filters sidebar sections, not panel content — misleading label

| Field | Value |
|-------|-------|
| **Severity** | P2 |
| **File / Component** | `AppConsoleChromeView.swift` top bar search field, `AppShellRootView.swift` `NativeAppShellSectionSearch.visibleSections` |
| **User flow affected** | All users trying to find content |
| **Evidence** | The search field placeholder reads "Filter current operator surface" and `searchText` is passed to `NativeAppShellSectionSearch.visibleSections(contract.sections, query:)`, which filters the sidebar section list. When sections are filtered away, `clampSelectedSection()` redirects to a still-visible section or `AppUnavailableSectionView`. |
| **Why it hurts** | "Filter current operator surface" implies filtering content within the current panel (e.g., log lines, packet rows, settings fields). In reality, it filters which sidebar navigation items are visible. A user typing "audio" to find audio settings fields instead hides most sections and redirects them to an empty state. |
| **Suggested remediation** | Rename placeholder to "Filter sections" or "Find section…". Alternatively, if panel-level content filtering is intended for the future, reserve this field for that purpose and add a separate section list with a smaller filter. |
| **Verification needed** | Confirm `NativeAppShellSectionSearch` only filters section list and does not pass `searchText` into panel content. |
| **Confidence** | High — `visibleSections` filter confirmed; no content-level filtering found. |

---

### F-16 · P2 · Settings tab visibility changes silently when switching session mode

| Field | Value |
|-------|-------|
| **Severity** | P2 |
| **File / Component** | `AppShellSettingsView.swift` `TabView`, `NativeAppShellSettingsVisibility.visibleGroups` |
| **User flow affected** | WF-01 and WF-04 — settings configuration |
| **Evidence** | `NativeAppShellSettingsVisibility.visibleGroups(sessionMode:controlMode:)` returns a filtered list. Switching from `directMacPeer` to `windowsLoLa` hides the Audio, Video, and Snapshot tabs. Switching from `normal` to `advanced` shows SSH Fallback, Report Paths, Audio Codec, Video Codec, Ports, Buffers. These changes happen immediately when the picker is changed in the Execution tab. |
| **Why it hurts** | A user configuring audio parameters in the Audio tab who then changes the session mode to windowsLoLa finds the Audio tab silently gone — with the TabView jumping to a different selected tab with no explanation. Confusion is compounded by immediate persistence (F-02): the mode switch is already saved. |
| **Suggested remediation** | When session mode changes and removes currently-visible tabs, show a brief informational message (e.g. "Audio/Video settings are not used in LoLa mode") rather than silently removing them. Consider animating the tab removal or keeping a grayed "not applicable" tab as a visual placeholder. |
| **Verification needed** | Confirm the TabView selected tab index behavior when visible tabs shrink (does it crash, jump, or handle gracefully). |
| **Confidence** | High — visibility logic confirmed. |

---

### F-17 · P2 · Routing section contains mixed concerns: topology + artifacts + Windows LoLa routing

| Field | Value |
|-------|-------|
| **Severity** | P2 |
| **File / Component** | `AppShellRootView.swift` `AppRoutingSectionView`, `AppConnectionTopologyView.swift`, `AppOperatorArtifactViews.swift` |
| **User flow affected** | WF-01 pre-session configuration, WF-04 Windows LoLa setup |
| **Evidence** | The Routing section (`AppRoutingSectionView`) contains: `AppConnectionTopologyView` (animated P2P diagram), plan artifact views (`AppOperatorArtifactViews` with 7 buttons: copy/paste/import inventory, generate/write/reload plan, copy SSH command), and Windows LoLa routing summary. These are three conceptually different tasks: visualization, file I/O operations, and external connector setup. |
| **Why it hurts** | Users looking for "how to import a remote device inventory" have to navigate to "Routing" — which sounds like it's about network topology. Users looking for the topology diagram find it alongside 7 artifact operation buttons that have nothing to do with routing. The section title misleads discoverability. |
| **Suggested remediation** | Rename "Routing" to "Setup" or "Plan Setup". Or split artifact operations into the Devices section (inventory import/export belongs there) and keep Routing for topology visualization only. |
| **Verification needed** | Confirm full content of `AppRoutingSectionView` — whether it also contains peer connection fields. |
| **Confidence** | High — section content confirmed from source read. |

---

### F-18 · P2 · `⌘R` conflicts with the macOS Refresh convention

| Field | Value |
|-------|-------|
| **Severity** | P2 |
| **File / Component** | `OpenLolaApp.swift` MNU-01, `NativeAppShellSurfaceContract.swift` |
| **User flow affected** | Any user pressing ⌘R expecting a window reload |
| **Evidence** | MNU-01 "Refresh Synthetic Metrics" is bound to `⌘R`. In most macOS applications, `⌘R` reloads or refreshes the current view. Here it specifically invokes a synthetic metrics refresh, which is a narrow background operation. |
| **Why it hurts** | Users who press `⌘R` intending to reload the main view or re-check device enumeration instead trigger a synthetic metrics refresh that has no visible UI change. The action is invisible in its effect unless the user knows to watch specific badge values. |
| **Suggested remediation** | Consider removing this shortcut entirely or remapping to a less-conflicting key (e.g. `⌘⌥R`). Alternatively, make the refresh operation's effect clearly visible (e.g. a brief spinner on the verdict badge). |
| **Verification needed** | Confirm whether any other macOS app system handler claims `⌘R` in this app's context. |
| **Confidence** | High — shortcut assignment confirmed. |

---

### F-19 · P2 · "Next Action" in Overview can conflict with session state banner guidance

| Field | Value |
|-------|-------|
| **Severity** | P2 |
| **File / Component** | `AppShellRootView.swift` `AppOverviewNextActionPanel`, `AppSessionStateBanner.swift` |
| **User flow affected** | WF-02 Run a session |
| **Evidence** | The session state banner and the Overview's "Next Action" panel both provide user guidance. Example of potential conflict: when armed, the banner says "Armed — ready to start supervisor" (no action button) while Overview's Next Action says "Start armed supervisor → Open Session". The banner is always visible; Overview is only visible when that section is selected. If a user is in a different section (e.g. Devices), the banner guidance is the only visible prompt, but it provides no CTA. |
| **Why it hurts** | Two guidance systems compete. The banner is the primary always-visible guide, but it provides no navigation actions except in `.unconfigured` state. Overview's Next Action has navigation buttons, but only when the user is in Overview. Users in other sections get partial guidance. |
| **Suggested remediation** | Extend the session state banner with a "Go to Session →" action button in `.ready`, `.armed`, and `.error` states (not just `.unconfigured`). This makes the banner the single authoritative guide. The Overview Next Action can then focus on evidence/reporting tasks rather than duplicating transport guidance. |
| **Verification needed** | Confirm banner `onGoToSetup` is only wired for `.unconfigured`. Confirm no other state has a banner CTA. |
| **Confidence** | High — banner CTA logic confirmed from source. |

---

### F-20 · P2 · Windows LoLa 18-field form has no inline validation; errors surface only on ARM

| Field | Value |
|-------|-------|
| **Severity** | P2 |
| **File / Component** | `AppShellSettingsTabs.swift` `AppWindowsLoLaSettingsTab`, `NativeAppShellSessionMode.swift` `validateAppSettings()` |
| **User flow affected** | WF-04 Windows LoLa session |
| **Evidence** | `NativeAppShellWindowsLoLaPeerFields.validateAppSettings()` runs on `sessionArguments(...)` call at ARM/START time. The settings tab is 18 fields with no per-field validation feedback. `UInt16Field` clamps ports silently (F-21). Empty/zero fields produce `NativeAppShellSurfaceValidationError.invalidCommandField(fieldName)` at ARM time, surfaced as... UNCLEAR — need to confirm where this error surfaces to the user. |
| **Why it hurts** | A user filling out 18 fields in a settings tab cannot see which fields are valid as they type. They may complete all fields, close settings, arm, and only then discover a typo in field #7. The round-trip (settings → arm → error → settings) is disruptive. |
| **Suggested remediation** | Add per-field validation inline (red outline + error text below field) using the same validation logic already present in `validateAppSettings()`. At minimum, show a validation summary in the settings tab footer before closing. |
| **Verification needed** | Confirm where `NativeAppShellSurfaceValidationError` is displayed to the user when ARM fails due to invalid Windows LoLa fields. |
| **Confidence** | High — field count and validation timing confirmed. Error surface location UNCLEAR. |

---

### F-21 · P2 · `UInt16Field` silently clamps to 65535 with no user message

| Field | Value |
|-------|-------|
| **Severity** | P2 |
| **File / Component** | `AppShellSupportViews.swift` `UInt16Field` |
| **User flow affected** | WF-01 / WF-04 — port field configuration |
| **Evidence** | `UInt16Field` clamps values to `0–65535` and shows help text "Enter a whole number from 0 to 65535." However, the clamping behavior when a user types "99999" or pastes an invalid value is to silently substitute 65535. The binding receives the clamped value immediately. |
| **Why it hurts** | A user who types a port number of 17777 followed by a typo (177771) instantly has a saved configuration of 65535 — a wrong port that will cause connection failure. No warning appears. If settings save immediately (F-02), this wrong value is persisted silently. |
| **Suggested remediation** | Show the help/error text in orange when the entered value was outside the valid range and was clamped. The text already exists ("Enter a whole number from 0 to 65535.") — show it as a validation warning, not just a placeholder hint. |
| **Verification needed** | Confirm the exact clamping behavior and whether the orange invalid-input highlight in `UInt16Field` is triggered on out-of-range input (vs. only on non-numeric input). |
| **Confidence** | High — clamping behavior confirmed from source. Orange highlight trigger UNCLEAR. |

---

### F-22 · P2 · "Settings" sidebar entry opens a separate window, not an inline panel

| Field | Value |
|-------|-------|
| **Severity** | P2 |
| **File / Component** | `AppConsoleSidebarView` SB-09 Settings entry, `AppShellRootView.swift` section router → `AppShellSettingsSummaryView` |
| **User flow affected** | WF-01 settings discovery |
| **Evidence** | SB-09 "Settings" in the sidebar navigates to the Settings section of the main panel, which shows `AppShellSettingsSummaryView` — a read-only summary with a "Open Settings" button that calls `openSettings()`. The actual editable settings are in the separate Settings window (⌘,). So: sidebar → summary panel → "Open Settings" button → separate window. Two clicks and a new window to reach settings. |
| **Why it hurts** | The sidebar entry labeled "Settings" sets the expectation of showing settings inline (consistent with other sections). Instead, it's a two-step redirect to a system-managed window. This is inconsistent with the rest of the navigation model and adds friction. |
| **Suggested remediation** | (a) Surface the Settings window on the first sidebar click (call `openSettings()` directly from the sidebar action, skip the summary intermediate). Or (b) embed the most frequently changed settings (session mode, executable path) in the summary panel so it functions as a standalone settings panel. |
| **Verification needed** | Confirm what `AppShellSettingsSummaryView` contains and whether it has any interactive controls. |
| **Confidence** | High — two-step flow confirmed. |

---

### F-23 · P2 · "Clear Command Intent" menu item has no visible purpose or documentation

| Field | Value |
|-------|-------|
| **Severity** | P2 |
| **File / Component** | `OpenLolaApp.swift` MNU-10 `clear-command-intent` |
| **User flow affected** | Recovery after F-10 "Set Handoff Intent" |
| **Evidence** | MNU-10 "Clear Command Intent" resets `operatorCommandIntent` to `.idle`. There is no UI element that shows the current command intent state (making F-10 invisible). Therefore "Clear Command Intent" is a corrective action for an invisible condition with no guidance on when or why to use it. |
| **Why it hurts** | An expert user who accidentally triggered "Set Handoff Intent" has no way to know the intent is set, and thus no reason to seek out "Clear Command Intent". A new user who explores the menu and sees "Clear Command Intent" has no idea what it clears. |
| **Suggested remediation** | If handoff intent is a supported workflow, show a persistent badge or banner when `commandIntent != .idle`, with a visible "Clear" button. If handoff intent is an internal development feature, remove both MNU-06 and MNU-10 from the user-facing menu. |
| **Verification needed** | Determine intended use case for handoff intent in the current release scope. |
| **Confidence** | High — action wiring confirmed; no visible state indicator found. |

---

### F-24 · P2 · Topology animation implies active connection before media is confirmed

| Field | Value |
|-------|-------|
| **Severity** | P2 |
| **File / Component** | `AppConnectionTopologyView.swift` animated flow dots |
| **User flow affected** | WF-02 session monitoring |
| **Evidence** | Topology shows animated flow dots between Mac A and Mac B when `sessionState == .live` (or connecting). As established in F-01, `.live` does not confirm actual media flow. The animated dots visually imply data is flowing through the connection. |
| **Why it hurts** | Reinforces the false assurance from F-01. A user watching animated dots between the two nodes believes audio/video is flowing, which may not be the case. |
| **Suggested remediation** | Add an explicit data-confidence indicator to the topology (e.g. "Topology: configured / Packets: not confirmed" rather than an animation that visually claims packet flow). Animation should only appear with confirmed packet-level evidence. |
| **Verification needed** | Confirm the condition that triggers animation (session state vs. packet evidence). |
| **Confidence** | High — animation tied to session state confirmed; session state ≠ media flow confirmed (F-01). |

---

### F-25 · P3 · "Snapshot" tab is misnamed — it shows static defaults, not a configuration snapshot

| Field | Value |
|-------|-------|
| **Severity** | P3 |
| **File / Component** | `AppShellSettingsTabs.swift` `AppSnapshotSettingsTab`, Settings tab SET-07 |
| **User flow affected** | Settings discovery |
| **Evidence** | The "Snapshot" tab (`AppSnapshotSettingsTab`) shows: default AV profile, sample rate, frames per buffer — all read-only. These are the hardcoded defaults from the core library, not a snapshot of the current session configuration. |
| **Why it hurts** | "Snapshot" implies a capture of the current state (like a config export). Users looking to export or review their current settings will look here and find static defaults, not their configuration. Users looking for "defaults" won't look under "Snapshot". |
| **Suggested remediation** | Rename to "Defaults" or "System Defaults". If the intent is to show a snapshot of the current session parameters, populate it with live values from `AppSettings`. |
| **Verification needed** | Confirm tab content is entirely static defaults and not derived from `AppSettings`. |
| **Confidence** | High — tab content confirmed as defaults from core. |

---

### F-26 · P3 · Copy buttons have no confirmation feedback

| Field | Value |
|-------|-------|
| **Severity** | P3 |
| **File / Component** | `AppShellSupportViews.swift` `AppReadableValue`, `AppOperatorArtifactViews.swift` copy buttons |
| **User flow affected** | Any copy-to-clipboard action |
| **Evidence** | `AppReadableValue` has a copy button ("Copy … value"). `AppOperatorArtifactViews` has "Copy Local Inventory JSON", "Generate Copyable Plan JSON", "Copy SSH Supervisor Command". None include a "Copied!" toast or any visual confirmation of success. Status strings like "Copied local inventory JSON." exist in `AppOperatorArtifactViews` but it is UNCLEAR if these are shown in the UI as transient feedback or only internally. |
| **Why it hurts** | Users who copy a long command string have no confirmation the copy succeeded. They may paste into a terminal and find nothing, having missed the copy. |
| **Suggested remediation** | Show a brief transient label change ("Copied!") or a system notification on copy. This is a standard macOS pattern for copy buttons. |
| **Verification needed** | Confirm whether `AppOperatorArtifactViews` status strings ("Copied local inventory JSON.") are displayed as transient UI feedback or only as internal state. |
| **Confidence** | Medium — status strings confirmed; UI rendering of those strings UNCLEAR. |

---

### F-27 · P3 · "IP/NAT preflight first" label is jargon; meaning is opaque

| Field | Value |
|-------|-------|
| **Severity** | P3 |
| **File / Component** | `NativeAppShellSessionMode.swift` `appStatusLabel` for `.directMacPeer`, displayed in session mode status contexts |
| **User flow affected** | WF-01 first-launch setup; mode selection |
| **Evidence** | `NativeAppShellSessionMode.directMacPeer.appStatusLabel = "IP/NAT preflight first"`. This label appears in session-mode status display when directMacPeer is selected. |
| **Why it hurts** | "IP/NAT preflight" is meaningful to network engineers but opaque to musicians or non-technical users who are the likely audience for a low-latency audio tool. They may not understand what preflight is, what NAT means, or what they are supposed to do "first". |
| **Suggested remediation** | Change to "Network check required before connecting" or "Check network reachability before starting". Add a tooltip or info icon linking to documentation. |
| **Verification needed** | Confirm where this label is displayed in the UI (in what views/components). |
| **Confidence** | High — label string confirmed. Display location partially confirmed. |

---

### F-28 · P3 · Footer badges are largely redundant with toolbar badges

| Field | Value |
|-------|-------|
| **Severity** | P3 |
| **File / Component** | `AppConsoleChromeView.swift` footer strip, top bar |
| **User flow affected** | All — persistent status chrome |
| **Evidence** | Top toolbar: Verdict, Execution, Validation badges. Footer: Packet, Remote Stream, Verdict badges. Verdict appears in both. |
| **Why it hurts** | Low signal-to-noise in the persistent chrome. Users may check both strips looking for the canonical status. |
| **Suggested remediation** | Deduplicate: remove Verdict from the footer (it's already in the toolbar), and move Packet and Remote Stream to the toolbar if they are high-priority. Or group all persistent status in one location. |
| **Verification needed** | Confirm exact badge count and labels in both strips. |
| **Confidence** | High — badge field names confirmed from both source locations. |

---

### F-29 · P3 · "NMP CLI contracts" in unavailable mode message is undocumented jargon

| Field | Value |
|-------|-------|
| **Severity** | P3 |
| **File / Component** | `NativeAppShellSessionMode.swift` `unavailableAppReason`, `AppShellRootView.swift` `AppWorkflowUnavailableView` |
| **User flow affected** | Any user selecting JackTrip or UltraGrid (F-05) |
| **Evidence** | `unavailableAppReason`: "…Use the external connector or NMP CLI contracts." |
| **Why it hurts** | "NMP CLI contracts" is a project-internal term with no public documentation link. Users cannot act on this guidance. |
| **Suggested remediation** | Replace with actionable text: "Use the command-line interface: `python -m linux_connector.lola_connector.cli …`. See README for setup." |
| **Verification needed** | None required. |
| **Confidence** | High. |

---

### F-30 · P3 · `AppWarningBanner` dismissals lost on view reload

| Field | Value |
|-------|-------|
| **Severity** | P3 |
| **File / Component** | `AppShellSupportViews.swift` `AppWarningBanner` |
| **User flow affected** | Any section with active warning banners |
| **Evidence** | `AppWarningBanner` uses `isDismissed: Binding<Bool>`. In callers, this is held in `@State`, which resets on view reload. |
| **Why it hurts** | Users dismiss a warning, navigate away, return, and see the same warning reappear. Repeated unexpected reappearances cause warning fatigue and may train users to dismiss warnings without reading them. |
| **Suggested remediation** | Persist dismissal state to `@AppStorage` keyed to the specific warning ID, so dismissed warnings stay dismissed until the underlying condition changes. |
| **Verification needed** | Confirm that dismissal state is `@State` and not already persisted. |
| **Confidence** | High — `Binding<Bool>` pattern confirmed; `@State` holder inferred from usage pattern. |

---

## 2. Blocked Core Workflows

### 2.1 First-run setup (WF-01) is discovery-hostile

**Primary gap:** No onboarding path. App opens to Overview showing "PARTIAL" and "Setup required" with no call-to-action on the banner for the `.unconfigured` state. The CTA "Go to Devices Setup" only appears in `AppUnavailableSectionView`, not in the Overview section which is the actual default landing view. First-time users are not guided to the correct starting point.

**Findings:** F-04, F-08

---

### 2.2 Session execution requires navigating to a non-default section

**Primary gap:** The transport bar (ARM/START/STOP) lives in the Session section, not in the app chrome. A user in any other section cannot ARM or START without navigating. The session state banner provides no CTA in the `.ready` or `.armed` states.

**Findings:** F-08, F-19

---

### 2.3 JackTrip and UltraGrid workflows are dead ends

**Primary gap:** Both modes are selectable but lead to entirely non-functional panels. The guidance message references internal jargon and no actionable path.

**Findings:** F-05, F-29

---

### 2.4 Post-session validation is opaque

**Primary gap:** VALIDATE button only appears when a report exists; no guidance when absent. The path to produce a report (run a session), locate the output file, and then trigger validation is not communicated in the transport bar.

**Findings:** F-09

---

## 3. Confusing Workflows

### 3.1 Three ARM entry points create inconsistency

ARM can be triggered from the transport bar, the Execution view toggle, and the menu shortcut. Users encounter the concept in multiple places without a clear canonical location.

**Findings:** F-07

### 3.2 "Set Handoff Intent" / "Clear Command Intent" are invisible actions

Both menu items modify internal state with no visible UI effect. Neither has any in-app documentation or contextual help. Both are in the user-facing menu.

**Findings:** F-10, F-23

### 3.3 `.live` state provides false assurance

The green "Live" banner and animated topology imply active media flow when the session state is derived from execution + report evidence, not from confirmed packet/frame-level activity.

**Findings:** F-01, F-24

### 3.4 Settings-change feedback loop is broken

Settings save immediately, tabs disappear silently when mode changes, and errors from invalid values only surface at ARM time — not inline.

**Findings:** F-02, F-16, F-20, F-21

### 3.5 Overview status information is redundant with persistent chrome

The Overview section repeats status information already shown in the toolbar and footer badges, reducing the utility of navigating there. The one unique value — the "Next Action" panel — competes with the session state banner for guidance authority.

**Findings:** F-14, F-19

---

## 4. Navigation and Menu Issues

### 4.1 Navigation hierarchy: flat sidebar with implicit sequencing

The sidebar presents 9 sections as a flat list in three unlabeled groups (SETUP, SESSION, MONITOR, TOOLS visible only as visual groupings). The correct setup sequence is: Devices → Settings → Routing → Session — but this sequence is not communicated structurally. Users may access sections in any order.

### 4.2 Two-step redirect to Settings from sidebar

Sidebar "Settings" → Summary Panel → "Open Settings" button → separate window. Three steps to reach editable controls.

**Findings:** F-22

### 4.3 Search filters navigation, not content

The search field affects section visibility, not panel content. Label is misleading.

**Findings:** F-15

### 4.4 Keyboard shortcut set is minimal and partially conflicting

| Shortcut | Action | Issue |
|----------|--------|-------|
| `⌘R` | Refresh synthetic metrics | Conflicts with standard reload conventions |
| `⌘⇧E` | ARM/DISARM toggle | Same shortcut for two opposite actions; state-sensitive |
| `⌘⇧P` | Start Armed Supervisor | No visible label in any menu item per audit (shortcut assigned in contract but not confirmed in menu rendering) |
| `⌘,` | Settings | Standard macOS settings shortcut — correct |

`⌘⇧P` should be confirmed in the UI with a visible menu item label and shortcut indicator. `⌘R` should be reconsidered.

**Findings:** F-18

### 4.5 Menu items without visible in-app effects

"Set Handoff Intent", "Clear Command Intent" — modify internal state with no visible feedback. "Refresh Synthetic Metrics" — triggers a refresh with no visible progress. These reduce menu trustworthiness.

**Findings:** F-10, F-23

---

## 5. Suggested Information-Architecture Cleanup

The following changes are recommended (not mandatory), ordered by impact. None require changes to business logic.

### 5.1 Flatten to a 3-phase IA

The current sidebar has 9 sections. Most users need 3 phases:

```
Phase 1: Configure
  → Devices (select hardware, set peer addresses)
  → Settings (executable path, session mode, codec params)

Phase 2: Run
  → Session (ARM / DRY RUN / START / STOP / VALIDATE + log + topology)
  → Streams (preview meters)

Phase 3: Review
  → Overview (evidence summary, latency hero)
  → Diagnostics
  → Validation
  → Packet Monitor
```

Routing could be merged into Devices (topology and peer settings belong together). The MONITOR group could be renamed REVIEW.

### 5.2 Promote transport controls to the app chrome

The ARM/START/STOP transport bar should be visible from any section, not only when Session is selected. This is the highest-impact single change.

### 5.3 Extend session state banner with navigation CTAs

Add a navigation button to the session state banner for each actionable state:
- `.unconfigured` → "Go to Devices" (already exists)
- `.ready` → "Go to Session" (new)
- `.armed` → "Go to Session" (new)
- `.error` → "Go to Diagnostics" (new)
- `.awaitingEvidence` → "Go to Validation" (new)

### 5.4 Remove or defer JackTrip / UltraGrid from UI until launchable

If these modes are not launchable from the app, remove them from the Workflow picker and document them as CLI-only in the Settings window or help text. Alternatively, disable (gray) the picker options with a tooltip rather than allowing selection that leads to a dead end.

### 5.5 Rename "Routing" to "Plan Setup"

Or split into Devices (inventory, device selection) and Session (topology, command generation). The current mixing of inventory operations, topology, and Windows LoLa routing in one section creates discoverability failures.

---

## 6. Remaining Uncertainty

| ID | Item | Impact |
|----|------|--------|
| RU-01 | Whether Settings window controls (`AppShellSettingsView` text fields) are locked via `AppRuntimeInputLock` while `isRunning` | High — if not locked, F-02 is worse than described (config can be mutated during a live session) |
| RU-02 | Exact condition for `hasReport` in transport bar VALIDATE rendering | Medium — affects F-09 precision |
| RU-03 | Where `NativeAppShellSurfaceValidationError` from Windows LoLa validation is shown to user | Medium — affects F-20 severity assessment |
| RU-04 | Whether `AppConsoleSidebarView` visually grays or badges Packet Monitor when `captureReport == nil` | Medium — affects F-12 severity |
| RU-05 | Whether `AppOperatorArtifactViews` status strings ("Copied local inventory JSON.") are rendered as transient UI feedback | Low — affects F-26 |
| RU-06 | Whether `⌘⇧P` appears with a visible label in the rendered CommandMenu | Medium — if absent, the shortcut is undiscoverable |
| RU-07 | Whether `AppShellSettingsSummaryView` has any interactive controls or is pure read-only summary | Low — affects F-22 remediation framing |
| RU-08 | Intended purpose and release scope of "handoff intent" / `NativeAppShellOperatorCommandIntent.handoffRequested` | High — determines if F-10 / F-23 are P1 bugs or P0 incomplete features that should be hidden |
| RU-09 | Full content of `AppExecutionView` — whether it includes progress feedback during validation subprocess | Medium — affects F-09 and F-11 |
