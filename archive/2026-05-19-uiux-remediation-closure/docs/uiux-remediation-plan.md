# Open LoLa App — UI/UX Remediation Plan

**Source:** `docs/uiux-master-audit.md`
**Audit scope:** Static source analysis, macOS SwiftUI app (`Sources/open-lola-app/`)
**Production code changes in this document:** None — planning only.
**Date:** 2026-05-19

---

## How to Read This Plan

Each slice is one independently reviewable PR. Slices are named with a prefix:

- **REM-** — implementation slice: clear problem, minimal targeted fix, verifiable outcome.
- **INV-** — investigation slice: answer a specific open question before implementing.
- **DEC-** — decision slice: requires a product or architecture decision before code can be written.

Within each category, slices are ordered by the priority framework:

1. P0 false runtime/status UI
2. P1 blocked core workflows
3. Missing/broken controls or unreachable views
4. Controls not wired to behavior
5. Missing error/loading/empty states
6. Serious readability/accessibility issues
7. Settings/runtime mismatch
8. Duplicated or confusing flows
9. Cosmetic polish

**Never start an INV- or DEC- slice's downstream REM- slice until the INV/DEC is resolved and documented.**

---

## Table of Contents

- [Investigation Slices (INV)](#investigation-slices)
- [Decision Slices (DEC)](#decision-slices)
- [Implementation Slices (REM)](#implementation-slices)
  - [P0 — False Runtime Status](#p0--false-runtime-status)
  - [P1 — Blocked Core Workflows](#p1--blocked-core-workflows)
  - [P1 — Serious Accessibility](#p1--serious-accessibility)
  - [P2 — Missing States and Behavior Correctness](#p2--missing-states-and-behavior-correctness)
  - [P2 — Accessibility and Discoverability](#p2--accessibility-and-discoverability)
  - [P3 — Polish](#p3--polish)
- [Execution Order](#1-recommended-execution-order)
- [P0/P1 Slices Summary](#2-p0p1-slices)
- [Quick Wins](#3-low-risk-quick-wins)
- [Blocked / Decision-Needed Items](#4-blockeddecision-needed-items)
- [Final UI Verification Checklist](#5-final-ui-verification-checklist)

---

## Investigation Slices

Investigation slices have no code output. Their output is a written answer added to `docs/uiux-remediation-plan.md` (in the "Investigation Results" appendix at the end) and, if the answer changes a downstream slice's approach, an update to that slice.

---

### INV-01 — Confirm SIGTERM exit code from `Process.terminate()`

| Field | Value |
|---|---|
| **Findings addressed** | M-SB-01, M-SB-07, M-SB-15 (Uncertainty U-03) |
| **Problem** | `AppSessionState.derive` produces a false `.error` state when the operator presses Stop, because a non-zero `lastExitCode` triggers the error branch. The exact exit code produced by macOS `Process.terminate()` is unconfirmed (may be `-15`, `143`, or other). The fix for REM-01 must match the actual value(s). |
| **Investigation steps** | 1. Add a temporary `print("terminationStatus: \(process.terminationStatus)")` to `AppExecutionController`'s process termination handler. 2. Launch a session, press Stop, read the console log. 3. Also check `process.terminationReason` (`.uncaughtSignal` vs `.exit`). 4. Document the result in the appendix below. |
| **Files to read** | `AppExecutionController.swift` — `launchProcess()` termination handler block |
| **Output required** | The exact `terminationStatus` and `terminationReason` values produced by `stop()`. Whether `terminationReason == .uncaughtSignal` can be used as a reliable "user-initiated stop" signal regardless of the status code. |
| **Blocking** | REM-01 |
| **Effort** | 30 minutes |

---

### INV-02 — Confirm log file persistence path from `prepareLogFiles()`

| Field | Value |
|---|---|
| **Findings addressed** | M-F-11, Conflict CONFLICT-01 (Uncertainty U-05) |
| **Problem** | `AppExecutionController.prepareLogFiles()` writes stdout/stderr to `stdoutPath`/`stderrPath`. It is unknown whether these paths point to a persistent location (e.g., `~/Library/Logs/`, app container, user-chosen directory) or to a temporary directory that may be wiped. If persistent, REM-11 (log file open affordance) is straightforward. If temporary, the fix requires either moving the path or archiving the file before the next run. |
| **Investigation steps** | 1. Read `prepareLogFiles()` in full. 2. Trace the path construction — look for `NSTemporaryDirectory()`, `FileManager.default.temporaryDirectory`, `applicationSupportDirectory`, or a user-configurable path in `AppSettings`. 3. Run a session and confirm a file exists at the resolved path after the run ends. 4. Run a second session and confirm whether the first session's log file was overwritten. |
| **Files to read** | `AppExecutionController.swift` — `prepareLogFiles()` method |
| **Output required** | The absolute path pattern used. Whether it persists across runs. Whether it is overwritten or uniquely named per run. |
| **Blocking** | REM-11 |
| **Effort** | 30 minutes |

---

### INV-03 — Confirm sidebar count badge data source

| Field | Value |
|---|---|
| **Findings addressed** | M-F-16 (Uncertainty U-06) |
| **Problem** | Sidebar section count badges appear to always be zero. It is unknown whether they are intended to be live (e.g., count of active channels, pending items) but not wired, or are structural placeholders with no intended meaning. |
| **Investigation steps** | 1. Search `AppShellRootView.swift` for the badge count binding. 2. Trace the binding to its source in `AppConsoleModels`. 3. Determine if any code path ever sets it to a non-zero value. |
| **Files to read** | `AppShellRootView.swift`, `AppConsoleModels.swift` |
| **Output required** | Whether the badge is a dead placeholder (→ remove it) or an unwired live feature (→ wire or disable until wired). |
| **Blocking** | REM-24 (Polish batch B) |
| **Effort** | 15 minutes |

---

### INV-04 — Confirm ARM control co-visibility in Session section layout

| Field | Value |
|---|---|
| **Findings addressed** | M-F-07 (Uncertainty U-02) |
| **Problem** | Three ARM entry points exist: transport bar button, `AppExecutionView` toggle, and the `⌘⇧E` menu item. It is unknown whether the transport bar button and the `AppExecutionView` toggle are simultaneously visible in the Session section, or in separate sub-views that cannot co-exist. If co-visible, they must show identical state at all times. If not co-visible, the duplicate-control risk is lower. |
| **Investigation steps** | 1. Read `AppShellRootView.swift` Session section rendering logic. 2. Determine whether `AppTransportView` and `AppExecutionView` are both in the same view hierarchy branch or exclusive branches. 3. Launch the app, navigate to Session, and inspect visually. |
| **Files to read** | `AppShellRootView.swift`, `AppTransportView.swift`, `AppExecutionView.swift` |
| **Output required** | Whether both ARM controls are co-visible. Whether they share the same `armedForExecution` binding (i.e., already in sync). |
| **Blocking** | REM-08 (scoping only — does not block the fix, but affects the fix's focus) |
| **Effort** | 15 minutes |

---

## Decision Slices

Decision slices require a human product or architecture decision. The output of each is a written decision recorded in the "Decision Log" appendix. Implementation cannot begin until the decision is recorded.

---

### DEC-01 — Settings save/discard lifecycle

| Field | Value |
|---|---|
| **Findings addressed** | M-F-02 (P0) |
| **Problem** | `AppSettings` currently writes every property to `UserDefaults` on every keystroke via `didSet`. This is a P0: accidental edits are immediately permanent with no recovery. Three distinct approaches exist, each with different implementation cost and user model implications. |
| **Decision required** | Choose one of the following strategies: |
| **Option A** | **Transient copy + explicit Save/Discard (Recommended).** Create a mutable `SettingsDraft` copy of `AppSettings` for the settings window. The window binds to the draft. Pressing Save writes the draft to `UserDefaults`. Pressing Discard or closing without saving reverts to the previous values. Risk: requires refactoring all 50+ `AppSettings` bindings to bind to the draft. Effort: 2–3 days. |
| **Option B** | **Guard during active run only.** Keep keystroke-immediate persistence but disable the settings window (or individual fields) when a session is running, preventing mid-session accidents. Risk: settings remain permanently changed for edits made outside of a run. Does not fully address the P0 for pre-run accidental edits. Effort: 0.5 day. |
| **Option C** | **Add a "Reset to defaults" button only.** Keep keystroke-immediate persistence but add a visible "Reset to defaults" escape hatch. Risk: does not allow per-field recovery; only a nuclear reset is available. Partial mitigation. Effort: 0.5 day. |
| **Files affected** | `AppSettings.swift`, `AppShellSettingsView.swift`, `AppShellSettingsTabs.swift` |
| **Blocking** | REM-02 (settings architecture) |

---

### DEC-02 — Evidence archive strategy before run start

| Field | Value |
|---|---|
| **Findings addressed** | M-SB-03 (P0) |
| **Problem** | `launchProcess()` clears all prior session evidence (latency metrics, capture/connector reports, error log, exit code) before the new process starts. This is a P0: if the previous run failed, its diagnostic evidence is lost the moment the operator tries again. An archive strategy is needed before this can be fixed in code. |
| **Decision required** | Choose one: |
| **Option A** | **In-memory ring buffer (Recommended for MVP).** Keep the last N (e.g., 3) runs' evidence in an in-memory array. Show a "Previous runs" disclosure section in the evidence panels. No disk I/O change required. Cleared on app quit. Effort: 1 day. |
| **Option B** | **Persist prior run snapshot to disk.** Write a JSON snapshot of evidence data to a session-scoped file before clearing. Surface a "Last session" section in the evidence panels reading from the file. More durable; survives app restart. Effort: 2 days. Adds a file I/O contract. |
| **Option C** | **Warn before clearing.** Show a confirmation dialog: "Starting a new session will clear the current evidence. Continue?" No archival. Preserves data if the operator cancels; loses it if they confirm. Effort: 0.5 day. |
| **Files affected** | `AppExecutionController.swift`, evidence panel views, `AppRuntimeEvidenceScope.swift` |
| **Blocking** | REM-03 |

---

### DEC-03 — Persistent transport bar location

| Field | Value |
|---|---|
| **Findings addressed** | M-F-04 (P1) |
| **Problem** | ARM/START/STOP controls are only visible in the "Session" section. When the operator is viewing Meters, Evidence, or Logs, these critical controls are hidden. A layout decision is required for where to place a persistent transport affordance. |
| **Decision required** | Choose one: |
| **Option A** | **Add a compact transport strip to the window footer (Recommended).** The footer strip already exists below the detail panel. Add ARM/START/STOP state + a compact status indicator there. The full `AppTransportView` remains in the Session section for detailed interaction. Effort: 1 day. |
| **Option B** | **Add ARM state + STOP button to the window toolbar.** Use SwiftUI `.toolbar` to add a compact indicator and Stop button visible in all sections. Effort: 0.5 day. Simpler but less contextual. |
| **Option C** | **No layout change — add a toast/callout** that auto-navigates the operator to the Session section when a state transition is imminent. Effort: 1 day. Does not solve the emergency-stop problem. |
| **Files affected** | `AppShellRootView.swift`, `AppTransportView.swift` |
| **Blocking** | REM-07 (transport bar visibility) |

---

### DEC-04 — Preview receiver state integration

| Field | Value |
|---|---|
| **Findings addressed** | M-SB-05, M-SB-09, M-F-15 (P1) (Uncertainties U-04, U-08) |
| **Problem** | The preview window (`WIN-02`) may maintain its own `AppPreviewReceiverState` with a `receiverStatus` that is not incorporated into `AppSessionState.derive`. If so, the main session banner can show "Live" while the local preview receiver has failed or stalled. Before fixing, the sharing/isolation relationship must be understood. |
| **Decision required** | First resolve U-04 and U-08 (INV-04 equivalent — check if `receiverStatus` appears in main window and whether models are shared). Then decide: |
| **Option A** | **Integrate `receiverStatus` into `AppSessionState.derive`.** Add a `.liveWithReceiverWarning` or similar derived state. Surface degraded receiver as a warning callout inside the session banner. |
| **Option B** | **Show receiver status in preview window only.** Accept that the preview window is the authoritative surface for receiver health; document this explicitly. |
| **Files affected** | `AppPreviewBindings.swift`, `AppConsoleModels.swift`, `AppSessionStateBanner.swift`, `OpenLolaApp.swift` |
| **Blocking** | REM-12 (preview receiver status wiring) |

---

## Implementation Slices

---

## P0 — False Runtime Status

---

### REM-01 — Fix false Error banner after user-initiated Stop

| Field | Value |
|---|---|
| **Slice ID** | REM-01 |
| **Findings addressed** | M-SB-01 (P0), M-SB-07 (P1) |
| **Prerequisite** | INV-01 completed |
| **Problem** | `AppSessionState.derive` maps a non-zero `lastExitCode` to `.error` regardless of whether the exit was user-initiated. SIGTERM (from `stop()`) produces a non-zero exit code. Result: every normal Stop shows a red "Error" banner, conditioning operators to ignore error states. |
| **Minimal remediation strategy** | In `AppSessionState.derive` (in `AppSessionStateBanner.swift`), add an explicit case for the `.stopRequested` → `.runFinished` transition path: if `terminationReason == .uncaughtSignal` AND `commandWasStop == true`, return `.idle` (or a new `.stopped` state) rather than falling through to the exit-code error check. If `terminationReason` is not available at the derive call site, pass a `wasUserStop: Bool` flag from `AppExecutionController` through the model to `derive`. Do not change any other logic in `derive`. |
| **Files likely affected** | `AppSessionStateBanner.swift` (`AppSessionState.derive`), `AppConsoleModels.swift` (if a `wasUserStop` flag is needed), `AppExecutionController.swift` (set `wasUserStop = true` in `stop()` handler) |
| **User behavior affected** | After pressing Stop, the banner transitions to a neutral/idle state instead of red Error. Operators can distinguish a clean stop from a real failure. |
| **Runtime behavior affected** | None. State derivation is purely presentational. |
| **Tests/manual checks to add** | Unit test: call `derive` with `phase == .runFinished`, `lastExitCode == 143` (or the SIGTERM value from INV-01), `wasUserStop == true` → assert result is NOT `.error`. Unit test: call `derive` with same exit code but `wasUserStop == false` → assert result IS `.error`. Manual: press Stop → banner must NOT show red Error. |
| **Verification checklist** | `[ ]` Run `swift test --filter AppSessionStateTests` (or equivalent). `[ ]` Launch app, start a session, press Stop — banner shows neutral/idle, not Error. `[ ]` Deliberately cause a real failure — verify banner still shows Error. |
| **Risk level** | Low. Isolated to `derive` switch statement. |
| **Rollback strategy** | Revert the `derive` change. No data migration required. |
| **Definition of Done** | Pressing Stop in any session state produces a non-error banner. A real process failure (non-SIGTERM non-zero exit) still produces an error banner. Unit tests pass. |

---

### REM-02 — Fix `commandIntent` race on startup failure

| Field | Value |
|---|---|
| **Slice ID** | REM-02 |
| **Findings addressed** | M-SB-02 (P0) |
| **Problem** | In `OpenLolaApp.swift`, the menu action sets `commandIntent = .runRequested` before calling `executionController.startArmed()`. If `startArmed()` fails, the intent is left as `.runRequested` with no active run. |
| **Minimal remediation strategy** | Move `commandIntent = .runRequested` to after `startArmed()` returns success. Wrap the call in `do { try startArmed(); commandIntent = .runRequested } catch { commandIntent = .none; /* show error */ }`. If `startArmed()` is not currently `throws`, check whether it returns a result type or sets an error flag — use that to conditionally set the intent. |
| **Files likely affected** | `OpenLolaApp.swift` (menu command handler for START) |
| **User behavior affected** | If a session fails to start, the UI does not falsely display "run requested" intent. |
| **Runtime behavior affected** | None. `commandIntent` is a UI-facing model property. |
| **Tests/manual checks to add** | Unit test: mock `startArmed()` to throw/fail → assert `commandIntent != .runRequested` after the call. Manual: trigger a START in a condition that fails — verify no stale intent indicator in the UI. |
| **Verification checklist** | `[ ]` Inspect `commandIntent` value after a failed START (log or breakpoint). `[ ]` Verify intent is cleared/reset on failure. |
| **Risk level** | Very low. Two-line reorder in a single call site. |
| **Rollback strategy** | Revert the two lines. |
| **Definition of Done** | `commandIntent` is `.none` (or previous value) after a START failure. `commandIntent` is `.runRequested` only when `startArmed()` confirms success. |

---

### REM-03 — Add Stop confirmation dialog in live state

| Field | Value |
|---|---|
| **Slice ID** | REM-03 |
| **Findings addressed** | M-F-03 (P0), M-F-20 (P2) |
| **Problem** | Pressing Stop while a live session is running terminates audio/video streams to remote participants with no confirmation. A single accidental click causes immediate, unrecoverable disruption. |
| **Minimal remediation strategy** | In `AppTransportView.swift`, wrap the Stop button action with a confirmation check: if `sessionState == .live`, present a `.confirmationDialog` with "Stop live session?" / "Stop" (destructive) / "Cancel". If `sessionState` is not `.live` (e.g., `.armed`, `.awaitingEvidence`), Stop may proceed without confirmation — the stakes are lower. Do not add confirmations to ARM or START; those are lower-risk and add friction to the normal workflow. |
| **Files likely affected** | `AppTransportView.swift` |
| **User behavior affected** | When a session is live, pressing Stop triggers a confirmation sheet. Cancel returns to the live state. Stop proceeds to terminate. In non-live states, Stop is immediate as before. |
| **Runtime behavior affected** | None — the confirmation only delays the `stop()` call, it does not change the call itself. |
| **Tests/manual checks to add** | Manual test: with a live session, press Stop — verify the confirmation dialog appears. Press Cancel — verify session continues. Press Stop in dialog — verify session stops. Manual test: with an armed (not yet live) session, press Stop — verify no dialog (Stop is immediate). |
| **Verification checklist** | `[ ]` `.confirmationDialog` is present in `AppTransportView`. `[ ]` Dialog does NOT appear in `.armed` state. `[ ]` Dialog DOES appear in `.live` state. `[ ]` Cancel leaves session running. `[ ]` Confirm terminates session. |
| **Risk level** | Very low. Adds one `.confirmationDialog` modifier. |
| **Rollback strategy** | Remove the `.confirmationDialog` — Stop reverts to immediate. |
| **Definition of Done** | A live session cannot be stopped without a confirmation step. Non-live Stop remains immediate. |

---

### REM-04 — Fix warning banner contrast in light mode (WCAG P0)

| Field | Value |
|---|---|
| **Slice ID** | REM-04 |
| **Findings addressed** | M-VA-01 (P0) |
| **Problem** | The session state warning banner uses SwiftUI `.orange` for its background/text. Computed WCAG contrast ratio: **1.95:1** against white in light mode (minimum required: 4.5:1 for normal text, 3:1 for large). Critical runtime warnings may be invisible to users with reduced contrast sensitivity. |
| **Minimal remediation strategy** | In `AppSessionStateBanner.swift` (or wherever the `.warning` state color is applied), replace SwiftUI `.orange` with a new `AppDesignSystem.stateWarning` light-mode token that achieves ≥4.5:1 contrast against the window background. Proposed target: dark amber/brown text (e.g., RGB ~0.50, 0.28, 0.00) on a pale amber background (e.g., RGB ~1.00, 0.95, 0.80) — computed contrast ≈ 5.2:1. Run the WCAG Python script from the VA audit to verify before committing. Do not change dark mode colors if they already pass. |
| **Files likely affected** | `AppDesignSystem.swift` (add `stateWarning` light variant), `AppSessionStateBanner.swift` (reference the token) |
| **User behavior affected** | Warning banner text is clearly readable in light mode. Visual appearance changes (less saturated orange; more accessible amber/brown). |
| **Runtime behavior affected** | None. |
| **Tests/manual checks to add** | Run the WCAG Python contrast script against the new RGB values before and after — assert ≥4.5:1. Manual: enable Light Mode, trigger a warning state — text must be clearly legible. |
| **Verification checklist** | `[ ]` Python WCAG script reports ≥4.5:1 for new light token. `[ ]` Visual check in Light Mode on a real device. `[ ]` No dark mode regression — run WCAG script for dark mode values. |
| **Risk level** | Very low. Color token change only. |
| **Rollback strategy** | Revert color token change. |
| **Definition of Done** | Warning banner text contrast ≥4.5:1 in light mode, confirmed by WCAG script. Dark mode unchanged. |

---

## P1 — Blocked Core Workflows

---

### REM-05 — Disable transport controls for unavailable workflow modes

| Field | Value |
|---|---|
| **Slice ID** | REM-05 |
| **Findings addressed** | M-F-05 (P1) |
| **Problem** | Selecting JackTrip or UltraGrid workflow shows `AppWorkflowUnavailableView` ("not available in this build") but ARM/START/STOP remain active. Operator can attempt to launch an unsupported workflow — outcome is undefined. Also, `AppWorkflowUnavailableView` uses internal jargon ("workflow," "build") with no user-facing guidance. |
| **Minimal remediation strategy** | 1. In `AppConsoleModels` (or `AppTransportView`), add a computed property `isWorkflowAvailable: Bool` that returns `false` for `.jacktrip` and `.ultragrid`. 2. In `AppTransportView`, wrap ARM and START button enablement with `isWorkflowAvailable` — disabled when false. STOP may remain available as a safety control. 3. In `AppWorkflowUnavailableView`, replace "This workflow is not yet available in this build" with "This mode is not available yet. Switch to a supported workflow in Settings to continue." Do not change any other view logic. |
| **Files likely affected** | `AppConsoleModels.swift` (add `isWorkflowAvailable`), `AppTransportView.swift` (disable ARM/START), `AppWorkflowUnavailableView.swift` (copy update) |
| **User behavior affected** | In unsupported mode: ARM and START are visually disabled. Operator receives plain-language guidance. STOP is still accessible. |
| **Runtime behavior affected** | Prevents `armSession()` and `startArmed()` from being called in unsupported modes. |
| **Tests/manual checks to add** | Manual: select JackTrip mode → ARM button must be disabled. Manual: select supported mode → ARM button must be enabled. Unit test: `isWorkflowAvailable` returns `false` for `.jacktrip`/`.ultragrid`, `true` for the default workflow. |
| **Verification checklist** | `[ ]` JackTrip → ARM disabled. `[ ]` UltraGrid → ARM disabled. `[ ]` Default mode → ARM enabled. `[ ]` Copy in `AppWorkflowUnavailableView` uses no jargon. |
| **Risk level** | Low. Adding a guard property and a copy change. |
| **Rollback strategy** | Remove `isWorkflowAvailable` guard — transport reverts to always active. |
| **Definition of Done** | ARM/START are disabled in unsupported workflow modes. Operator sees plain-language guidance. |

---

### REM-06 — Packet Monitor: replace blank view with meaningful empty state

| Field | Value |
|---|---|
| **Slice ID** | REM-06 |
| **Findings addressed** | M-F-06 (P1) |
| **Problem** | Packet Monitor sidebar item is navigable in `.ready`, `.armed`, `.live`, `.awaitingEvidence`, and `.error` states. In all pre-capture states, `captureReport == nil` and the section renders blank — no explanation, no loading indicator, no context. Operators waste time trying to diagnose a blank screen. |
| **Minimal remediation strategy** | In the Packet Monitor detail view (wherever `captureReport == nil` is rendered): add an explicit empty state `ContentUnavailableView` (or equivalent for the macOS target) with: title "No capture data yet", description "Packet capture data appears here after a session completes and report evidence is validated." Also: in the sidebar, visually dim the Packet Monitor item (`.opacity(0.5)`) and add a `.help("Available after session validation")` tooltip when `captureReport == nil`. Do not change availability gating logic. |
| **Files likely affected** | Packet Monitor detail view file (identify during implementation), `AppShellRootView.swift` (sidebar item opacity/tooltip) |
| **User behavior affected** | Operator immediately understands the section is data-conditional, not broken. |
| **Runtime behavior affected** | None. |
| **Tests/manual checks to add** | Manual: navigate to Packet Monitor in `.ready` state → empty state message visible. Manual: sidebar item visually dimmed. Manual: after a completed session with a report → empty state replaced by data (or still shows empty state if `captureReport` remains nil, confirming the data path). |
| **Verification checklist** | `[ ]` Empty state message appears when `captureReport == nil`. `[ ]` Sidebar item is dimmed when `captureReport == nil`. `[ ]` Tooltip reads "Available after session validation" on hover. |
| **Risk level** | Very low. No logic change — view-layer only. |
| **Rollback strategy** | Remove the empty state view and sidebar dimming. |
| **Definition of Done** | Packet Monitor never shows a blank view. A clear explanation is always present when data is unavailable. |

---

### REM-07 — Add persistent transport strip or toolbar indicator

| Field | Value |
|---|---|
| **Slice ID** | REM-07 |
| **Findings addressed** | M-F-04 (P1) |
| **Prerequisite** | DEC-03 completed |
| **Problem** | ARM/START/STOP controls disappear when the operator navigates away from the "Session" sidebar section. An emergency stop requires sidebar navigation. |
| **Minimal remediation strategy** | Implement whichever option was chosen in DEC-03. For Option A (recommended): add a compact `AppTransportStripView` to the footer/bottom of `AppShellRootView` that shows current session state label + a Stop button (only when `sessionState == .live` or `.armed`). The strip should be always visible. Keep the full `AppTransportView` in the Session section unchanged — the strip is additive only. |
| **Files likely affected** | `AppShellRootView.swift` (footer layout), new `AppTransportStripView.swift` (compact strip component) |
| **User behavior affected** | STOP button visible from any section when a session is active. No section navigation required for emergency stop. |
| **Runtime behavior affected** | None. The strip calls the same `executionController.stop()` as the existing transport bar. |
| **Tests/manual checks to add** | Manual: navigate to Meters section with a live session → compact Stop button visible in footer. Manual: navigate to Settings → Stop button visible. Manual: with no active session → Stop button hidden (strip shows nothing or a minimal status indicator). |
| **Verification checklist** | `[ ]` Stop button visible in footer from at least 3 non-Session sections. `[ ]` Stop button hidden when `sessionState == .idle`. `[ ]` Stop button triggers same `stop()` as Session-section transport bar. |
| **Risk level** | Low-medium. Additive layout change; does not modify existing transport logic. |
| **Rollback strategy** | Remove `AppTransportStripView` from footer. |
| **Definition of Done** | Operator can press Stop from any sidebar section during a live session. DEC-03 option implemented as specified. |

---

### REM-08 — Show distinct validation-in-progress state in session banner

| Field | Value |
|---|---|
| **Slice ID** | REM-08 |
| **Findings addressed** | M-F-09 (P1), M-F-12 (P1), M-SB-12 (P2), M-SB-13 (P2) |
| **Problem** | When validation is running (`phase == .validationRunning`), `AppSessionState.derive` returns `.awaitingEvidence` — the same state as when validation has never been run. The operator cannot tell whether validation is running or idle. Additionally, settings are locked during validation with no explanation visible. `AppRuntimeInputLock` has a `reason` property that is never read by the UI. |
| **Minimal remediation strategy** | 1. In `AppSessionState.derive`, add a branch: if `phase == .validationRunning`, return a new `.validating` state (or re-use an existing equivalent if one exists). If adding a new case to `AppSessionState` is too broad, use a separate `isValidating: Bool` computed property on the model. 2. In `AppSessionStateBanner`, when `.validating` / `isValidating == true`, show: "Validating…" label + a `ProgressView()` spinner. 3. In `AppShellSettingsView`, when the input lock is active, add a `Text(lockReason)` overlay (e.g., "Settings locked while validation is running") sourced from `AppRuntimeInputLock.reason`. Do not change any other lock logic. |
| **Files likely affected** | `AppSessionStateBanner.swift` (`AppSessionState.derive` + banner view), `AppConsoleModels.swift` (if `isValidating` property added), `AppShellSettingsView.swift` (lock reason overlay), `AppRuntimeInputLock.swift` (read `reason` in view) |
| **User behavior affected** | Operator sees "Validating…" with a spinner during validation. Settings show a clear explanation when locked by validation. |
| **Runtime behavior affected** | None. |
| **Tests/manual checks to add** | Manual: trigger `⌘⇧V` validation → banner shows "Validating…" + spinner. Manual: open Settings during validation → lock reason label visible. Unit test: `derive` with `phase == .validationRunning` → returns `.validating` (or `isValidating == true`). |
| **Verification checklist** | `[ ]` "Validating…" + spinner visible during validation run. `[ ]` Banner does NOT show "validate the runtime report" during active validation. `[ ]` Settings panel shows lock reason during validation. `[ ]` Unit test passes for the new `derive` branch. |
| **Risk level** | Low. Additive to `derive` switch; view label change. |
| **Rollback strategy** | Remove the `.validating` case from `derive`; remove settings overlay. |
| **Definition of Done** | Operator can always distinguish "validation running" from "validation not yet started." Settings lock reason is visible. |

---

### REM-09 — Add session banner CTAs in Ready and Armed states

| Field | Value |
|---|---|
| **Slice ID** | REM-09 |
| **Findings addressed** | M-F-08 (P1) |
| **Problem** | The session banner only shows a CTA (`onGoToSetup`) in `.unconfigured` state. In `.ready` and `.armed`, the banner shows a status label only. New operators see "Ready" but have no obvious next step — they must independently discover the transport controls. |
| **Minimal remediation strategy** | In `AppSessionStateBanner.swift`, add conditional CTA buttons for two additional states: — In `.ready`: add a "Go to Session →" `Button` that calls `onGoToSetup` or a new `onGoToSession` callback that sets the sidebar selection to the Session section. — In `.armed`: add a "Start Session" `Button` that calls `executionController.startArmed()`. Ensure the ARM state button is styled distinctly from destructive actions (use a secondary/bordered style, not a `.destructive` role). |
| **Files likely affected** | `AppSessionStateBanner.swift`, `AppShellRootView.swift` (if `onGoToSession` callback needs wiring) |
| **User behavior affected** | Operators in `.ready` state see a clear "Go to Session →" next-step button. Operators in `.armed` state see a "Start Session" button. |
| **Runtime behavior affected** | "Start Session" CTA calls `startArmed()` — same as existing transport START button. No new runtime paths. |
| **Tests/manual checks to add** | Manual: put app in `.ready` state → "Go to Session →" button visible in banner. Manual: put app in `.armed` state → "Start Session" button visible. Manual: click "Go to Session →" → sidebar navigates to Session section. Manual: click "Start Session" → session starts (same as existing START button). |
| **Verification checklist** | `[ ]` `.ready` → "Go to Session →" CTA present. `[ ]` `.armed` → "Start Session" CTA present. `[ ]` `.unconfigured` → existing "Go to Setup" CTA unchanged. `[ ]` `.live` → no extra CTA (transport bar handles it). |
| **Risk level** | Low. Additive banner content. |
| **Rollback strategy** | Remove the new CTA branches from `AppSessionStateBanner`. |
| **Definition of Done** | Operator in `.ready` or `.armed` state has a visible next-step action in the banner. |

---

### REM-10 — Surface `commandIntent` as a read-only indicator

| Field | Value |
|---|---|
| **Slice ID** | REM-10 |
| **Findings addressed** | M-F-10 (P1) |
| **Problem** | "Set Handoff Intent" and "Clear Command Intent" menu items mutate `commandIntent` but there is no visible UI element showing the current value. Operators cannot verify the handoff state from the UI. |
| **Minimal remediation strategy** | Add a small read-only `Text` label showing the current `commandIntent` value to the session detail section (or transport area). Use a neutral style — this is informational, not actionable. Show only when `commandIntent != .none` (do not clutter the UI in the default state). Example: small caption "Handoff intent: runRequested" or a formatted human-readable equivalent. Do not add a control — read-only only. |
| **Files likely affected** | Session detail view or `AppTransportView.swift` (add the label), `AppConsoleModels.swift` (ensure `commandIntent` is observable from the view) |
| **User behavior affected** | After using the Handoff Intent menu items, the operator can see the current intent value in the UI. |
| **Runtime behavior affected** | None. Read-only display. |
| **Tests/manual checks to add** | Manual: use "Set Handoff Intent" → label appears in session area showing the intent. Manual: use "Clear Command Intent" → label disappears. |
| **Verification checklist** | `[ ]` `commandIntent != .none` → label visible. `[ ]` `commandIntent == .none` → no label shown. `[ ]` Label is read-only (not a `TextField` or `Toggle`). |
| **Risk level** | Very low. Additive read-only label. |
| **Rollback strategy** | Remove the label. |
| **Definition of Done** | Operator can always see the current `commandIntent` value without opening a menu. |

---

### REM-11 — Fix "Last validated" label to show pass/fail result

| Field | Value |
|---|---|
| **Slice ID** | REM-11 |
| **Findings addressed** | M-SB-06 (P1), M-F-13 (P1) |
| **Problem** | (1) The "Last validated: [timestamp]" label updates on every validation run regardless of exit code, implying validation passed. A failed validation looks identical to a passed one. (2) The `⌘⇧V` shortcut for triggering validation is not shown in the Settings > Validation tab. |
| **Minimal remediation strategy** | 1. Track `lastValidationResult: ValidationResult` (`.passed`, `.failed`, `.unknown`) in `AppExecutionController` alongside the timestamp. Set it from the validation exit code in the `runOneShot()` completion handler. 2. In the Settings Validation tab label, append the result: "Last validated [time] — PASSED ✓" or "Last validated [time] — FAILED ✗". Use green/red tint on the result token (but not as the only differentiator — include text). 3. Add a `Text("Shortcut: ⌘⇧V")` hint below the Validate button in the Settings Validation tab. |
| **Files likely affected** | `AppExecutionController.swift` (add `lastValidationResult`), `AppShellSettingsTabs.swift` (update label + shortcut hint), `AppConsoleModels.swift` (expose property to view) |
| **User behavior affected** | Operator can immediately see whether the last validation passed or failed. Keyboard-first operators discover the `⌘⇧V` shortcut from the UI. |
| **Runtime behavior affected** | None. |
| **Tests/manual checks to add** | Manual: run a passing validation → label shows "PASSED". Manual: simulate a failing validation → label shows "FAILED". Manual: Settings Validation tab → shortcut hint visible. Unit test: `lastValidationResult` set from exit code 0 → `.passed`; non-zero → `.failed`. |
| **Verification checklist** | `[ ]` Label shows PASSED after passing validation. `[ ]` Label shows FAILED after failing validation. `[ ]` `⌘⇧V` hint visible in Settings Validation tab. `[ ]` Unit test for `lastValidationResult` derivation. |
| **Risk level** | Low. New model property + label update. |
| **Rollback strategy** | Revert `lastValidationResult` property and label change. |
| **Definition of Done** | Operator always knows the outcome of the last validation run from the Settings UI. |

---

### REM-12 — Fix validation-failed preflight blocker: require re-validation, not phase change

| Field | Value |
|---|---|
| **Slice ID** | REM-12 |
| **Findings addressed** | M-SB-08 (P1) |
| **Problem** | When `phase == .validationFailed`, the preflight blocker prevents START. The blocker clears when `phase` changes to any other value (e.g., `.idle`) — without a new passing validation. Operator can clear the blocker by resetting the phase without fixing the underlying problem. |
| **Minimal remediation strategy** | Use the `lastValidationResult` property introduced in REM-11. Change the preflight blocker condition from `phase == .validationFailed` to `lastValidationResult == .failed`. The blocker clears only when `lastValidationResult` transitions to `.passed` (i.e., a new validation that passes). `lastValidationResult` is reset to `.unknown` at run start (after evidence archive from DEC-02). |
| **Files likely affected** | `AppExecutionView.swift` (preflight blocker condition), `AppExecutionController.swift` (reset `lastValidationResult` at run start) |
| **User behavior affected** | Pressing Validate and failing → START is blocked. Running another validation and passing → START unblocked. Simply resetting the phase does NOT unblock START. |
| **Runtime behavior affected** | None. |
| **Tests/manual checks to add** | Manual: fail a validation → confirm START is blocked. Idle the session (reset phase) → confirm START is STILL blocked. Run a passing validation → confirm START is unblocked. Unit test: preflight condition with `lastValidationResult == .failed` → blocked; with `.passed` → not blocked. |
| **Verification checklist** | `[ ]` Phase reset alone does not clear the preflight blocker after a failed validation. `[ ]` Only a passing validation clears the blocker. `[ ]` Unit test passes. |
| **Risk level** | Low. Depends on REM-11. |
| **Rollback strategy** | Revert blocker condition to `phase == .validationFailed`. |
| **Definition of Done** | The only way to clear a validation-failed preflight blocker is a passing validation run. |

---

## P1 — Serious Accessibility

---

### REM-13 — Fix state color WCAG contrast failures in light mode

| Field | Value |
|---|---|
| **Slice ID** | REM-13 |
| **Findings addressed** | M-VA-02 (P1), M-VA-03 (P1), M-VA-04 (P1), M-VA-05 (P1) |
| **Problem** | Three session-state color tokens fail WCAG 2.1 AA in light mode: `stateArmed` (2.53:1), `stateReady` (4.21:1), `stateLive` (4.08:1). Additionally, no increased-contrast macOS variants exist for any state color token, despite the infrastructure existing for meter colors. |
| **Minimal remediation strategy** | In `AppDesignSystem.swift`: 1. Add a distinct `lightMode` variant for `stateArmed` (darker amber — target ≥4.5:1 on white). 2. Darken the existing `stateReady` light variant slightly to achieve ≥4.5:1. 3. Darken the existing `stateLive` light variant slightly to achieve ≥4.5:1. 4. Add `@Environment(\.accessibilityDifferentiateWithoutColor)` / increased-contrast variants for `stateArmed`, `stateReady`, `stateLive`, `stateError`, `stateWarning` following the same pattern already used for meter colors. Run the WCAG Python script to confirm all ratios before committing. Do NOT change dark-mode values (they already pass). |
| **Files likely affected** | `AppDesignSystem.swift` only |
| **User behavior affected** | State indicators (armed, ready, live) are clearly readable in light mode and with increased contrast enabled. |
| **Runtime behavior affected** | None. |
| **Tests/manual checks to add** | Run WCAG Python script for all five light-mode state color tokens — assert ≥4.5:1. Manual: Light Mode + Increase Contrast → all state labels legible. |
| **Verification checklist** | `[ ]` Python WCAG script confirms all five tokens ≥4.5:1 in light mode. `[ ]` Dark mode values unchanged (script confirms no regression). `[ ]` Increased-contrast environment renders darker variants. |
| **Risk level** | Very low. Color token changes only. |
| **Rollback strategy** | Revert `AppDesignSystem.swift`. |
| **Definition of Done** | All five state color tokens pass WCAG AA (≥4.5:1) in light mode, confirmed by script. Increased-contrast variants defined. |

---

### REM-14 — Add accessibility semantics to warning banner

| Field | Value |
|---|---|
| **Slice ID** | REM-14 |
| **Findings addressed** | M-VA-06 (P1), M-VA-13 (P2) |
| **Problem** | (1) The warning/error session banner has no `.accessibilityRole(.alert)` — VoiceOver does not auto-announce state transitions to `.warning` or `.error`. (2) Session states are distinguished by color only — no icon or text shape prefix differentiates them for color-blind users. |
| **Minimal remediation strategy** | In `AppSessionStateBanner.swift`: 1. Add `.accessibilityRole(.alert)` to the banner `HStack` or container view when `sessionState == .warning || sessionState == .error`. For other states, use `.accessibilityRole(.text)` or `.none`. 2. Add a state-specific SF Symbol prefix to the banner label text: `.warning` → `exclamationmark.triangle.fill`, `.error` → `xmark.circle.fill`, `.live` → `circle.fill` (green), `.armed` → `bolt.circle.fill`. Add as `Image(systemName:)` before the label `Text`. Keep the existing text label unchanged — the icon is additive. |
| **Files likely affected** | `AppSessionStateBanner.swift` |
| **User behavior affected** | VoiceOver users hear warning/error state changes announced automatically. Color-blind users can distinguish session states by icon shape. |
| **Runtime behavior affected** | None. |
| **Tests/manual checks to add** | Manual: enable VoiceOver, trigger `.error` state → VoiceOver announces the change. Manual: color-blind simulation (Xcode simulator accessibility) → states distinguishable by icon. |
| **Verification checklist** | `[ ]` `.accessibilityRole(.alert)` on warning/error states. `[ ]` SF Symbol prefix visible for each state. `[ ]` VoiceOver announces state change (manual test). |
| **Risk level** | Very low. Additive modifiers and icons. |
| **Rollback strategy** | Remove `.accessibilityRole` and icon additions. |
| **Definition of Done** | VoiceOver announces warning and error state transitions. Each session state has a unique visible icon. |

---

### REM-15 — Add `accessibilityReduceMotion` guards to all animations

| Field | Value |
|---|---|
| **Slice ID** | REM-15 |
| **Findings addressed** | M-VA-07 (P1), M-VA-14 (P2) |
| **Problem** | Banner pulse animation (`AppSessionStateBanner`) and topology dot animations (`AppConnectionTopologyView`) both run without checking `@Environment(\.accessibilityReduceMotion)`. Channel meter bar animations (`AppChannelMeterView`) also lack this guard. This violates WCAG SC 2.3.3 and may cause vestibular distress. |
| **Minimal remediation strategy** | In each affected view, read `@Environment(\.accessibilityReduceMotion) var reduceMotion`. Wrap existing `.animation(...)` calls: replace `.animation(.easeInOut(duration: 0.8).repeatForever(), value: ...)` with `.animation(reduceMotion ? nil : .easeInOut(duration: 0.8).repeatForever(), value: ...)`. For topology dots that use explicit `withAnimation { }` blocks, guard with `if !reduceMotion { withAnimation { ... } } else { /* apply final state without animation */ }`. This is a pure additive guard — no animation logic changes. |
| **Files likely affected** | `AppSessionStateBanner.swift` (pulse), `AppConnectionTopologyView.swift` (dots), `AppChannelMeterView.swift` (bar animation) |
| **User behavior affected** | Users with macOS "Reduce Motion" enabled see no animations — static state display. Users without the preference see unchanged animations. |
| **Runtime behavior affected** | None. |
| **Tests/manual checks to add** | Manual: enable "Reduce Motion" in macOS Accessibility → banner, topology, and meters show no animation. Manual: disable "Reduce Motion" → animations present. |
| **Verification checklist** | `[ ]` Banner pulse absent when `reduceMotion == true`. `[ ]` Topology dot animation absent when `reduceMotion == true`. `[ ]` Meter bar animation absent when `reduceMotion == true`. `[ ]` All three animations present when `reduceMotion == false`. |
| **Risk level** | Very low. Conditional animation guard only. |
| **Rollback strategy** | Remove the `reduceMotion` condition — animations always run. |
| **Definition of Done** | All three animation surfaces respect macOS "Reduce Motion" preference. |

---

### REM-16 — Restore keyboard focus ring on transport buttons

| Field | Value |
|---|---|
| **Slice ID** | REM-16 |
| **Findings addressed** | M-VA-08 (P1) |
| **Problem** | Transport buttons (ARM/START/STOP) may have their SwiftUI default focus ring suppressed by a custom button style, preventing keyboard-only users from visually tracking focus. Requires runtime verification (INV resolved by manual test). |
| **Minimal remediation strategy** | 1. Enable Full Keyboard Access in macOS and Tab through the transport bar. If focus ring is absent: check the custom `ButtonStyle` in `AppTransportView` — ensure it does not call `.focusEffectDisabled(true)`. If it does, remove that modifier. If the style uses `.overlay()` that covers the system ring, add an explicit focus overlay: `.overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.accentColor, lineWidth: 2).opacity(isFocused ? 1 : 0))` using `@FocusState`. 2. Add `.focusable(true)` to any button that is not receiving focus. Do not change any non-focus-related button style properties. |
| **Files likely affected** | `AppTransportView.swift` (button style modifier or explicit focus overlay) |
| **User behavior affected** | Keyboard-only users can visually navigate to and between transport buttons. |
| **Runtime behavior affected** | None. |
| **Tests/manual checks to add** | Manual: Full Keyboard Access → Tab to transport bar → all three buttons show visible focus ring. Manual: Space/Return activates the focused button. |
| **Verification checklist** | `[ ]` ARM button shows focus ring when focused via keyboard. `[ ]` START button shows focus ring. `[ ]` STOP button shows focus ring. `[ ]` Focus ring does not break button visual design in non-focused state. |
| **Risk level** | Low. Focus-related modifier only. |
| **Rollback strategy** | Revert focus modifier change. |
| **Definition of Done** | All three transport buttons are keyboard-navigable with a visible focus ring. |

---

## P2 — Missing States and Behavior Correctness

---

### REM-17 — Fix topology animation key: use `phase`, not derived session state

| Field | Value |
|---|---|
| **Slice ID** | REM-17 |
| **Findings addressed** | M-F-22 (P2), M-SB-11 (P2) |
| **Problem** | `AppConnectionTopologyView` keys its animated "active connection" display on `sessionState == .live`. Because `.live` can derive from stale on-disk evidence (M-F-01), the topology can animate as "connected" when no session is running. `phase` is the authoritative runtime truth. |
| **Minimal remediation strategy** | In `AppConnectionTopologyView`, replace the animation condition `sessionState == .live` with `executionController.phase == .supervisorRunning` (or expose a simpler `isSessionRunning: Bool` from `AppConsoleModels` that reads `phase`). Do not change the animation itself — only the condition that enables it. (Note: REM-15 adds the `reduceMotion` guard — apply both in the same file, but these are independent changes.) |
| **Files likely affected** | `AppConnectionTopologyView.swift` |
| **User behavior affected** | Topology animates only when the supervisor process is actively running, not when stale evidence files happen to exist. |
| **Runtime behavior affected** | None. Presentational only. |
| **Tests/manual checks to add** | Manual: produce stale evidence (prior run report on disk), relaunch app → topology must NOT animate. Manual: run a live session → topology animates. Manual: stop the session → topology stops animating. |
| **Verification checklist** | `[ ]` Topology does NOT animate on app launch with stale evidence. `[ ]` Topology animates during an active supervisor run. `[ ]` Topology stops when session stops. |
| **Risk level** | Very low. Single condition change in one view. |
| **Rollback strategy** | Revert condition to `sessionState == .live`. |
| **Definition of Done** | Topology animation state is driven by `phase == .supervisorRunning`, not by derived session state. |

---

### REM-18 — Clear ARM state after Stop

| Field | Value |
|---|---|
| **Slice ID** | REM-18 |
| **Findings addressed** | M-SB-10 (P2) |
| **Problem** | `AppExecutionController.stop()` sends SIGTERM but does not reset `armedForExecution`. After a stop, the operator remains armed and can immediately re-START without explicitly re-arming — bypassing the intentional ARM gate. |
| **Minimal remediation strategy** | In `AppExecutionController.stop()` (or in the process termination handler), add `armedForExecution = false` after the SIGTERM is sent. Confirm this happens regardless of whether the stop was triggered from the transport bar, menu, or compact strip. |
| **Files likely affected** | `AppExecutionController.swift` |
| **User behavior affected** | After Stop, the user must ARM again before they can START. This is the intended safety pattern. |
| **Runtime behavior affected** | None beyond the ARM state reset. |
| **Tests/manual checks to add** | Unit test: call `stop()` → assert `armedForExecution == false`. Manual: ARM → Stop (without starting) → START is not available immediately → must re-ARM. |
| **Verification checklist** | `[ ]` `armedForExecution == false` immediately after `stop()`. `[ ]` START button is not available until re-ARM. `[ ]` Unit test passes. |
| **Risk level** | Low. One-line addition. |
| **Rollback strategy** | Remove the `armedForExecution = false` line. |
| **Definition of Done** | ARM state is always cleared by Stop. Operator must explicitly re-ARM after every Stop. |

---

### REM-19 — Auto-expand error disclosure when session is in error state

| Field | Value |
|---|---|
| **Slice ID** | REM-19 |
| **Findings addressed** | M-F-24 (P2) |
| **Problem** | The error log in `AppOperatorArtifactViews` is inside a `DisclosureGroup` that defaults to collapsed. When a session fails (`.error` state), the operator must manually expand the disclosure to see error messages — at the most critical moment. |
| **Minimal remediation strategy** | In the `DisclosureGroup` wrapping the error log, bind `isExpanded` to a computed property or a `@State` variable that defaults to `sessionState == .error`. When `sessionState` transitions to `.error`, set `isExpanded = true`. When the operator manually collapses it, respect that choice (do not force-reopen on every render). |
| **Files likely affected** | `AppOperatorArtifactViews.swift` |
| **User behavior affected** | When a session fails, the error log disclosure is automatically expanded. Operator sees error messages immediately without interaction. |
| **Runtime behavior affected** | None. |
| **Tests/manual checks to add** | Manual: trigger an error state → error log disclosure auto-opens. Manual: collapse disclosure manually → it stays collapsed until the next error transition. |
| **Verification checklist** | `[ ]` Error log disclosure opens automatically when `sessionState == .error`. `[ ]` Manual collapse is respected. `[ ]` No spurious re-opening during normal operation. |
| **Risk level** | Very low. One `isExpanded` binding change. |
| **Rollback strategy** | Remove the binding — disclosure reverts to always-collapsed default. |
| **Definition of Done** | Operator never has to manually expand error details after a session failure. |

---

### REM-20 — Add log file open affordance (pending INV-02)

| Field | Value |
|---|---|
| **Slice ID** | REM-20 |
| **Findings addressed** | M-F-11 (P1) |
| **Prerequisite** | INV-02 completed |
| **Problem** | The in-memory `errorLog` is cleared at every run start, and there is no "Open log file" button in the UI even if `stdoutPath`/`stderrPath` exist on disk. Operators cannot access historical log output. |
| **Minimal remediation strategy** | After INV-02 confirms path persistence: 1. In `AppOperatorArtifactViews.swift`, add an "Open Log in Console" `Button` (using `NSWorkspace.shared.open(URL)` to open the file in Console.app) shown when `stdoutPath != nil && FileManager.default.fileExists(atPath: stdoutPath)`. 2. If INV-02 reveals the paths are temporary, instead: copy the log file to the app container before `launchProcess()` clears it (save as `lastRun.log`), and surface that path. Do not change `launchProcess()` clearing behavior beyond the copy. |
| **Files likely affected** | `AppOperatorArtifactViews.swift`, possibly `AppExecutionController.swift` (log file copy if needed) |
| **User behavior affected** | Operator can open the current or last-run log in Console.app with one click. |
| **Runtime behavior affected** | Minimal: `NSWorkspace.open` is a UI-layer call. Log file copy (if needed) is a small disk operation before process launch. |
| **Tests/manual checks to add** | Manual: run a session → "Open Log" button appears → clicking it opens Console.app with the log. Manual: start a new run → prior log accessible (either same path or archived copy). |
| **Verification checklist** | `[ ]` "Open Log" button visible after a session run. `[ ]` Button opens the log file in Console.app. `[ ]` Prior run log not lost when new run starts (per INV-02 path and DEC-02 archiving decision). |
| **Risk level** | Low. Additive button; no change to the run lifecycle. |
| **Rollback strategy** | Remove the button. |
| **Definition of Done** | Operator can always access the last session's log file from the UI. |

---

### REM-21 — Add evidence freshness token to prevent stale Live state

| Field | Value |
|---|---|
| **Slice ID** | REM-21 |
| **Findings addressed** | M-F-01 (P0), M-SB-04 (P1) |
| **Problem** | `hasValidatedRuntimeEvidence` and `validationReadiness` both check only for file existence — not for whether the file belongs to the current session. A report from a prior run causes the "Live" state to appear on app relaunch. |
| **Minimal remediation strategy** | 1. In `AppExecutionController`, generate a `sessionToken = UUID().uuidString` at the start of each run (in `launchProcess()`). 2. Write the token to a small sidecar file (e.g., `session.token`) alongside the evidence files when the run starts. 3. In `AppRuntimeEvidenceScope.hasValidatedRuntimeEvidence` and `validationReadiness`, add: read `session.token`, compare with `executionController.sessionToken`. If mismatch → evidence is stale → return `false`. 4. Clear `sessionToken` on `stop()` / `runFinished`. This is a small, isolated change to the evidence contract — no change to report file formats. |
| **Files likely affected** | `AppExecutionController.swift` (generate + clear token, write sidecar), `AppRuntimeEvidenceScope.swift` (token check in readiness/evidence methods) |
| **User behavior affected** | "Live" badge only appears when the current session's own evidence is present. Stale prior-run evidence never triggers "Live." |
| **Runtime behavior affected** | One small sidecar file written per run start. |
| **Tests/manual checks to add** | Unit test: `hasValidatedRuntimeEvidence` with a matching session token → `true`. Same method with a mismatching token → `false`. Manual: run a session, stop it, relaunch the app → "Live" badge does NOT appear. |
| **Verification checklist** | `[ ]` App relaunch after a completed session → no "Live" badge. `[ ]` Unit test for token mismatch → `false`. `[ ]` Unit test for token match → `true`. `[ ]` Session token cleared after stop. |
| **Risk level** | Medium. Touches the evidence contract. Ensure evidence file directory logic is understood before adding the sidecar. |
| **Rollback strategy** | Remove token generation and the token check in `AppRuntimeEvidenceScope` — reverts to file-presence-only check. |
| **Definition of Done** | "Live" state is impossible on app relaunch without an active session. Session-token mismatch reliably returns `false` from evidence checks. |

---

## P2 — Accessibility and Discoverability

---

### REM-22 — Add accessibility labels, values, and hit targets

| Field | Value |
|---|---|
| **Slice ID** | REM-22 |
| **Findings addressed** | M-VA-09 (P2), M-VA-10 (P2), M-VA-11 (P2), M-VA-12 (P2) |
| **Problem** | Multiple interactive and data-display components have missing accessibility metadata: hit targets ~25 pt (below 44 pt), channel meters have no `accessibilityValue`, the latency hero has no unit label for VoiceOver, and sidebar items may not have explicit `accessibilityLabel`. |
| **Minimal remediation strategy** | In each affected view: 1. **Hit targets** (`AppTransportView`, interactive buttons): add `.contentShape(Rectangle())` and `.frame(minWidth: 44, minHeight: 44)` to all interactive elements that are currently smaller. 2. **Channel meters** (`AppChannelMeterView`): add `.accessibilityValue("\(levelPercent)%")` or `"\(levelDb) dB"` to each meter bar. 3. **Latency hero** (`AppLatencyHeroView`): add `.accessibilityLabel("Round-trip latency: \(value) milliseconds")`. 4. **Sidebar items** (`AppShellRootView`): add `.accessibilityLabel("Section Name")` to each `Label` in the sidebar `List`. Batch all four changes in one PR since they are all additive-only accessibility metadata. |
| **Files likely affected** | `AppTransportView.swift`, `AppChannelMeterView.swift`, `AppLatencyHeroView.swift`, `AppShellRootView.swift` |
| **User behavior affected** | VoiceOver users hear meaningful descriptions for meters and latency values. Keyboard/pointer users have larger tap targets. |
| **Runtime behavior affected** | None. |
| **Tests/manual checks to add** | Manual: VoiceOver → focus meter → hear level value announced. Manual: VoiceOver → focus latency hero → hear "Round-trip latency: X milliseconds". Manual: pointer targets feel larger. Xcode Accessibility Inspector → no "No label" warnings on sidebar items. |
| **Verification checklist** | `[ ]` Meter bars have `accessibilityValue`. `[ ]` Latency hero has `accessibilityLabel` with unit. `[ ]` Sidebar items have explicit labels. `[ ]` Interactive elements ≥44×44 pt (inspect with layout debugger). |
| **Risk level** | Very low. Additive accessibility metadata only. |
| **Rollback strategy** | Remove added accessibility modifiers. |
| **Definition of Done** | No interactive element smaller than 44 pt. VoiceOver announces correct values for meters and latency. Sidebar items have explicit labels. |

---

### REM-23 — Add channel meter and pre-session empty states

| Field | Value |
|---|---|
| **Slice ID** | REM-23 |
| **Findings addressed** | M-F-23 (P2) |
| **Problem** | Channel meters are visible even when no audio session is active. They display zero/idle state with no explanation. Operators may spend time checking meters when there is nothing to see. |
| **Minimal remediation strategy** | In `AppChannelMeterView` (or the section containing it), add an explicit empty state: when `sessionState == .unconfigured || sessionState == .ready`, overlay or replace the meter bars with a `ContentUnavailableView` (or `VStack { Image(systemName: "waveform") Text("No audio session active") Text("Meters appear during an active session.").font(.caption).foregroundStyle(.secondary) }`. When a session is active (`phase == .supervisorRunning`), show the meters normally. This is a view-layer conditional only — no model changes. |
| **Files likely affected** | `AppChannelMeterView.swift` (or its parent section container) |
| **User behavior affected** | Pre-session: empty state instead of idle zeroed meters. During session: meters shown as before. |
| **Runtime behavior affected** | None. |
| **Tests/manual checks to add** | Manual: app in `.ready` state → meters section shows empty state message. Manual: session running → meters visible. |
| **Verification checklist** | `[ ]` Empty state message shows in `.ready` and `.unconfigured`. `[ ]` Meters visible during `phase == .supervisorRunning`. `[ ]` Transition from empty state to meters is smooth (no layout jump). |
| **Risk level** | Very low. Conditional view rendering. |
| **Rollback strategy** | Remove the empty state conditional — always show meters. |
| **Definition of Done** | Meter section never shows unexplained idle bars. Clear context is always provided. |

---

### REM-24 — Rename misleading "App Readiness" verdict label

| Field | Value |
|---|---|
| **Slice ID** | REM-24 |
| **Findings addressed** | M-F-14 (P2), M-SB-14 (P3) |
| **Problem** | The "App Readiness" verdict badge is sourced from `NativeAppShellSyntheticSmoke.run()` — a static compile-time check. Its name implies the full system (audio device, network, session) is ready, misleading operators before a session. |
| **Minimal remediation strategy** | In `AppShellSettingsTabs.swift`, rename the label from "App Readiness" (or equivalent) to "Static checks" or "Build verification". Add a secondary caption: "Confirms app components are correctly assembled. Does not test network or audio devices." No logic change — label only. |
| **Files likely affected** | `AppShellSettingsTabs.swift` |
| **User behavior affected** | Operator understands this badge reflects build-time checks, not runtime readiness. Reduces false confidence before a session. |
| **Runtime behavior affected** | None. |
| **Verification checklist** | `[ ]` Settings tab shows "Static checks" or "Build verification" (not "App Readiness"). `[ ]` Caption explains the scope. `[ ]` Badge value/color unchanged. |
| **Risk level** | Trivial. String change. |
| **Rollback strategy** | Revert string. |
| **Definition of Done** | Label no longer implies full system readiness. |

---

### REM-25 — Sidebar auto-navigate to Session section on live transition

| Field | Value |
|---|---|
| **Slice ID** | REM-25 |
| **Findings addressed** | M-F-18 (P2) |
| **Problem** | When a session goes live, the sidebar does not navigate to the "Session" section. Operator viewing Meters or Evidence does not see the transition. |
| **Minimal remediation strategy** | In `AppShellRootView.swift`, observe `sessionState`. When `sessionState` transitions to `.live`, if `selectedSection != .session`, set `selectedSection = .session`. Use `.onChange(of: sessionState)` to detect the transition. Do not auto-navigate for other transitions (`.ready`, `.armed`, etc.) to avoid disorienting the operator. |
| **Files likely affected** | `AppShellRootView.swift` |
| **User behavior affected** | When a session goes live, the sidebar automatically switches to Session view. |
| **Runtime behavior affected** | None. |
| **Tests/manual checks to add** | Manual: navigate to Meters section, start a session → sidebar auto-navigates to Session on `.live` transition. Manual: manually navigate away from Session while live → no forced re-navigation (only triggers on transition, not on every render). |
| **Verification checklist** | `[ ]` Sidebar selection changes to Session on `.live` transition. `[ ]` Operator can navigate away from Session during a live session without forced re-navigation. |
| **Risk level** | Low. `.onChange` observer. |
| **Rollback strategy** | Remove the `.onChange`. |
| **Definition of Done** | Operator never misses the live session transition. |

---

### REM-26 — Verify and handle dark mode `stateError` contrast

| Field | Value |
|---|---|
| **Slice ID** | REM-26 |
| **Findings addressed** | M-VA-15 (P2) |
| **Problem** | `stateError` dark-mode contrast was reported as passing WCAG AA but was not computed against the actual dark macOS window background (not pure black). This requires explicit verification before closing. |
| **Minimal remediation strategy** | 1. Measure the actual macOS dark-mode window background color (use Xcode's color picker or `NSColor.windowBackgroundColor` introspection). 2. Run the WCAG Python script with the `stateError` dark token against the measured background. 3. If it passes (≥4.5:1): document the result in the appendix and close. 4. If it fails: darken the dark `stateError` token until it passes and add the result to the REM-13 PR (since both affect `AppDesignSystem.swift`). |
| **Files likely affected** | `AppDesignSystem.swift` (only if contrast fails) |
| **Verification checklist** | `[ ]` WCAG Python script run against actual dark background. `[ ]` Result documented in appendix. `[ ]` If fail: new token value passes ≥4.5:1. |
| **Risk level** | Very low. Verification step; code change only if contrast fails. |
| **Definition of Done** | `stateError` dark mode contrast ratio documented and confirmed ≥4.5:1 against actual window background. |

---

## P3 — Polish

---

### REM-27 — Polish batch A: terminology, labels, and empty states

| Field | Value |
|---|---|
| **Slice ID** | REM-27 |
| **Findings addressed** | M-F-19 (P2), M-F-21 (P2), M-F-26 (P3), M-F-28 (P3), M-SB-15 (P3), M-VA-16 (P3) |
| **Problem** | Multiple low-risk label and copy issues: inconsistent terminology (ARM/Live/Execution/Session), no dry-run badge on session detail, "Execution" vs "Session" in sidebar, empty "Session Details" section, raw exit codes not human-readable, inconsistent font weights. |
| **Minimal remediation strategy** | Batch the following string/label-only changes in one PR: 1. Standardise sidebar label "Execution" → "Session" throughout (`AppShellRootView.swift`). 2. Add a `Text("DRY RUN")` badge to the session detail when `phase == .dryRunRunning` or `phase == .runFinished` and the run was a dry run (`AppShellReadOnlyViews.swift`, `AppExecutionView.swift`). 3. Add empty state to "Session Details" section: "Session details appear here after a session completes." 4. Map known exit codes to human-readable labels: `0` → "Exited cleanly", `-15`/`143` → "Stopped by operator", other non-zero → "Unexpected exit (code \(n))" (`AppShellReadOnlyViews.swift`). 5. Audit and align font weights in status labels to a documented scale (e.g., `.semibold` for state label, `.regular` for description). |
| **Files likely affected** | `AppShellRootView.swift`, `AppShellReadOnlyViews.swift`, `AppExecutionView.swift`, `AppShellSupportViews.swift` |
| **User behavior affected** | Cleaner, more consistent UI language. Dry runs clearly identified. No more raw exit code numbers. |
| **Runtime behavior affected** | None. |
| **Verification checklist** | `[ ]` No "Execution" label where "Session" is the correct term. `[ ]` Dry-run badge visible after a dry run. `[ ]` "Session Details" shows empty state before any run. `[ ]` Exit code 0 shows "Exited cleanly". `[ ]` Exit code 143 shows "Stopped by operator". |
| **Risk level** | Very low. String and label changes only. |
| **Rollback strategy** | Revert string changes. |
| **Definition of Done** | All five items above verified. No pre-existing behavior changed. |

---

### REM-28 — Polish batch B: settings persistence, shortcuts, sidebar badges, ⌘R, ⌘Q

| Field | Value |
|---|---|
| **Slice ID** | REM-28 |
| **Findings addressed** | M-F-25 (P2), M-F-16 (P2 — pending INV-03), M-F-17 (P2), M-F-27 (P3), M-F-29 (P3), M-F-30 (P3) |
| **Problem** | Several low-risk quality-of-life issues: selected settings tab not preserved, possibly dummy sidebar count badges, ⌘R shortcut conflict risk, no ⌘Q live-session guard, no back-navigation from detail panels, no visual feedback that a settings change was accepted. |
| **Minimal remediation strategy** | 1. **Settings tab persistence** (`AppShellSettingsView.swift`): persist selected tab index to `UserDefaults` using a `@AppStorage` binding. 2. **Sidebar count badges**: after INV-03, either remove them (if dead placeholder) or document as "wired, future feature" and add a `.hidden()` modifier to suppress until they carry data. 3. **⌘R reassignment** (`OpenLolaApp.swift`): if INV verifies no `WKWebView`/`NavigationStack` conflict, add a comment documenting why ⌘R is used; if a conflict exists, reassign to ⌘⌥R. 4. **⌘Q guard** (`OpenLolaApp.swift`): check for `applicationShouldTerminate` — if absent and session is live, add a guard using `NSApplication.shared.presentationOptions` or a custom `@NSApplicationDelegateAdaptor`. 5. **Settings save feedback**: add a brief `.animation(.easeOut)` opacity flash on a "✓ Saved" `Text` label after every `UserDefaults` write commits — uses existing `didSet` path if DEC-01 chooses Option B or C. |
| **Files likely affected** | `AppShellSettingsView.swift`, `AppShellRootView.swift`, `OpenLolaApp.swift` |
| **User behavior affected** | Settings tab remembered across launches. ⌘Q warns when live. Settings writes give visual feedback. |
| **Runtime behavior affected** | ⌘Q guard delays quit while live. |
| **Verification checklist** | `[ ]` Settings tab selection persists across app relaunch. `[ ]` Sidebar badges: removed or hidden if unwired (per INV-03 result). `[ ]` ⌘Q while live → confirmation dialog or warning. `[ ]` "✓ Saved" flash appears after settings change. |
| **Risk level** | Very low (tab persistence, badges, settings feedback). Low (⌘Q guard — touches app lifecycle). |
| **Rollback strategy** | Revert each item independently. |
| **Definition of Done** | All items above verified. No functional behavior changed except ⌘Q guard. |

---

### REM-29 — Visual polish: spacing, disabled states, hover/active states

| Field | Value |
|---|---|
| **Slice ID** | REM-29 |
| **Findings addressed** | M-VA-17 (P3), M-VA-18 (P3), M-VA-19 (P3), M-VA-20 (P3) |
| **Problem** | Minor visual polish issues: inconsistent spacing between transport bar and sidebar items, no dynamic-type consideration for `.fixedSize()` uses, no opacity/tooltip for disabled transport buttons, no hover/active state on custom buttons. |
| **Minimal remediation strategy** | 1. **Spacing** (`AppTransportView.swift`, `AppShellRootView.swift`): align padding values to spacing tokens defined in `AppDesignSystem` (or add tokens if not present). 2. **Dynamic type** (`AppTransportView.swift`, `AppSessionStateBanner.swift`): audit for `.fixedSize()` calls that suppress dynamic type. Remove or narrow them where layout allows. 3. **Disabled tooltip** (`AppTransportView.swift`): add `.help("Session must be armed before starting")` (or relevant reason) to disabled START and ARM buttons. 4. **Hover state** (`AppTransportView.swift`, `AppShellSupportViews.swift`): in custom `ButtonStyle`, use `configuration.isPressed` to adjust opacity slightly (e.g., `.opacity(configuration.isPressed ? 0.75 : 1.0)`). |
| **Files likely affected** | `AppTransportView.swift`, `AppShellRootView.swift`, `AppSessionStateBanner.swift`, `AppShellSupportViews.swift`, `AppDesignSystem.swift` |
| **User behavior affected** | Cleaner visual polish. Disabled buttons have tooltips. Buttons give subtle press feedback. |
| **Runtime behavior affected** | None. |
| **Verification checklist** | `[ ]` Transport bar spacing matches sidebar item spacing (or both use tokens). `[ ]` Disabled START button shows tooltip explaining why. `[ ]` Pressing a button shows `.opacity(0.75)` during press. `[ ]` Dynamic type at "Accessibility XXL" does not clip visible labels. |
| **Risk level** | Very low. Visual styling only. |
| **Rollback strategy** | Revert style changes. |
| **Definition of Done** | Spacing is consistent with design tokens. Disabled buttons explain themselves. Buttons respond visually to press. |

---

## Investigation Results Appendix

*This appendix is populated as each INV- slice is completed. Record the result here before marking the INV slice done.*

### INV-01 Result
> **Status:** Completed 2026-05-19.
> **Required before:** REM-01.
> **Result:** A local Foundation `Process` check using `/bin/sleep 30` followed by `process.terminate()` produced `terminationStatus == 15` and `terminationReason == .uncaughtSignal` on this macOS runtime. The app already records user intent through `stopWasRequested` and leaves `phase == .stopRequested` after the managed process exits, so REM-01 can treat a finished `.stopRequested` phase as an operator stop rather than an error. This result was produced without temporary production-code edits.

### INV-02 Result
> **Status:** Completed 2026-05-19.
> **Required before:** REM-20.
> **Result:** `AppExecutionController.defaultLogURLs()` places stdout/stderr under `FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first` with an `NSTemporaryDirectory()` fallback, then appends `<bundle-id>/logs/execution-stdout.log` and `execution-stderr.log`. `prepareLogFiles()` creates the directory and writes empty `Data()` to both stable paths before each run, so the path is persistent enough for current-log open controls but each new run overwrites the prior run's logs unless the app snapshots them first. `AppLogsView` already exposes current `Open stdout` and `Open stderr` buttons; REM-20 should focus on preserving and surfacing the previous run's log files before truncation.

### INV-03 Result
> **Status:** Completed 2026-05-19.
> **Required before:** REM-28.
> **Result:** Current sidebar rows in `AppConsoleChromeView.AppConsoleSidebarRow` render `Label(section.title, systemImage: section.systemImage)` with accessibility/help metadata and no count/badge view. Searches for `badge` and sidebar count bindings found no active count source in `AppShellRootView.swift`, `AppConsoleChromeView.swift`, or `AppConsoleModels.swift`. The audit item is stale for the current sidebar implementation; there is no placeholder count to remove or hide.

### INV-04 Result
> **Status:** Completed 2026-05-19.
> **Required before:** REM-05 (scoping only).
> **Result:** `AppShellRootView.AppSessionSectionView` renders `AppTransportView`, `AppConnectionTopologyView`, and `AppExecutionView` in the same `VStack`, so the transport ARM button and the `AppExecutionView` "Arm execution" toggle are co-visible in the Session section. Both controls mutate the same `executionController.armedForExecution` state, so they are already synchronized. REM-05 should focus on disabling unsupported workflow modes at the transport controls while preserving STOP availability.

### REM-26 Result
> **Status:** Completed 2026-05-19.
> **Result:** A local AppKit contrast probe resolved `NSColor.windowBackgroundColor` under `.darkAqua` to sRGB `0.1176, 0.1176, 0.1176` with alpha `1.0`. The existing dark `stateError` token `1.0, 0.270, 0.250` measures `4.90:1` against that background, passing the WCAG AA normal-text threshold of `4.5:1`. No `AppDesignSystem.swift` token change is required.

---

## Decision Log Appendix

*This appendix is populated as each DEC- slice is resolved. Record the chosen option and rationale here before marking the DEC slice done.*

### DEC-01 Decision
> **Status:** Completed 2026-05-19.
> **Decision:** Option A — transient settings draft with explicit Save/Discard.
> **Rationale:** This is the only option that prevents pre-run accidental edits from becoming permanent immediately. Settings controls should bind to an in-window draft; Save commits the draft to persisted settings and runtime-facing models, while Discard reloads the last committed values.
> **Required before:** REM-28 settings persistence/save feedback.

### DEC-02 Decision
> **Status:** Completed 2026-05-19.
> **Decision:** Option A — in-memory previous-run evidence ring.
> **Rationale:** Preserve diagnostic evidence before a new run clears current state without adding a disk-format contract. Keep the last three snapshots for the app lifetime and surface them in existing evidence/log views.
> **Required before:** Evidence archive implementation.

### DEC-03 Decision
> **Status:** Completed 2026-05-19.
> **Decision:** Option A — compact footer transport strip.
> **Rationale:** A footer control keeps Stop reachable from every sidebar section while preserving the full Session transport surface unchanged.
> **Required before:** REM-07 (transport bar location).

### DEC-04 Decision
> **Status:** Completed 2026-05-19.
> **Decision:** Option A — integrate shared Local Preview receiver degradation into the main session banner.
> **Rationale:** `AppPreviewReceiverState` is shared by the main shell, settings scene, and Local Preview window, so the main UI can truthfully surface degraded/failed local preview state instead of leaving the operator to discover it only in the preview window.
> **Required before:** Preview receiver warning implementation.

### Final Verification Result
> **Status:** Completed 2026-05-19.
> **Result:** All actionable slices in this plan are COMPLETE in `docs/uiux-remediation-ledger.md`. Final focused checks passed: `swift test --filter AppShellBehavior --no-parallel`, `swift test --filter AppShellSlice05 --no-parallel`, `swift build --product open-lola-app` outside the SwiftPM manifest sandbox, `git diff --check`, and `bash scripts/verify-docs.sh`. Final native app UI smoke passed with `bash script/build_and_run.sh --verify` after setting `selectedAppShellSection` to `session` so the verifier's required Session-only `Operator Plan` accessibility evidence was present. Launch evidence was written to `dist/app-launch-evidence`.
> **Remaining uncertainty:** Live VoiceOver announcement behavior, Command-Q confirmation dialog interaction, settings relaunch behavior, and live-session footer Stop reachability were not manually exercised; they are covered by focused source/policy tests and the bundle launch smoke, not by full live hardware/runtime verification.

---

## 1. Recommended Execution Order

Group slices into four waves. Complete all slices in a wave before starting the next unless a slice is explicitly independent.

### Wave 0 — Investigations (parallel, no code)
Run all investigation slices simultaneously. No code changes. Output: documented answers.

| Slice | Title | Effort |
|---|---|---|
| INV-01 | Confirm SIGTERM exit code | 30 min |
| INV-02 | Confirm log file persistence path | 30 min |
| INV-03 | Confirm sidebar badge data source | 15 min |
| INV-04 | Confirm ARM control co-visibility | 15 min |

### Wave 0b — Decisions (parallel, architecture/product decisions)
Must be resolved before their dependent implementation slices. Can happen in parallel with Wave 0 or immediately after.

| Slice | Title | Decision Needed From |
|---|---|---|
| DEC-01 | Settings save/discard lifecycle | Product + engineering |
| DEC-02 | Evidence archive strategy | Engineering |
| DEC-03 | Persistent transport bar location | Product + engineering |
| DEC-04 | Preview receiver state integration | Architecture |

### Wave 1 — P0 Critical Fixes (sequential within file groups, otherwise parallel)
These are the safest, highest-impact changes. Start immediately after INV-01 and DEC-02 are done.

| Slice | Title | Priority | Depends On |
|---|---|---|---|
| REM-01 | Fix false Error banner after Stop | P0 | INV-01 |
| REM-02 | Fix `commandIntent` race | P0 | — |
| REM-03 | Add Stop confirmation in live state | P0 | — |
| REM-04 | Fix warning banner contrast | P0 | — |
| REM-13 | Fix state color WCAG contrast | P1 | — |
| REM-14 | Add accessibility semantics to banner | P1 | — |
| REM-15 | Add reduce-motion guards | P1 | — |
| REM-05 | Disable transport for unavailable modes | P1 | INV-04 (scoping) |
| REM-06 | Packet Monitor empty state | P1 | — |

### Wave 2 — P1 Workflow Fixes
Start after Wave 1 is merged and stable.

| Slice | Title | Priority | Depends On |
|---|---|---|---|
| REM-07 | Persistent transport strip | P1 | DEC-03 |
| REM-08 | Validation progress in banner | P1 | — |
| REM-09 | Session banner CTAs | P1 | — |
| REM-10 | Surface commandIntent display | P1 | — |
| REM-11 | Fix validation result label | P1 | — |
| REM-12 | Fix validation-failed preflight blocker | P1 | REM-11 |
| REM-16 | Restore transport focus ring | P1 | — |
| REM-21 | Evidence freshness session token | P0/P1 | — |

### Wave 3 — P2 Correctness and Accessibility
Start after Wave 2 is merged.

| Slice | Title | Priority | Depends On |
|---|---|---|---|
| REM-17 | Topology animation key fix | P2 | — |
| REM-18 | Clear ARM state after Stop | P2 | — |
| REM-19 | Auto-expand error disclosure | P2 | — |
| REM-20 | Log file open affordance | P1 | INV-02 |
| REM-22 | Accessibility labels, values, hit targets | P2 | — |
| REM-23 | Channel meter pre-session empty state | P2 | — |
| REM-24 | Rename "App Readiness" label | P2/P3 | — |
| REM-25 | Sidebar auto-navigate to Session | P2 | — |
| REM-26 | Dark mode stateError contrast verification | P2 | — |

### Wave 4 — Polish (can be batched or deferred)

| Slice | Title | Priority | Depends On |
|---|---|---|---|
| REM-27 | Polish batch A: labels, dry-run, exit codes | P2/P3 | REM-01 (exit code mapping) |
| REM-28 | Polish batch B: tab persistence, ⌘Q, badges | P2/P3 | INV-03, DEC-01 |
| REM-29 | Visual polish: spacing, disabled, hover | P3 | — |

### Deferred — Pending Architecture Decision

| Slice | Title | Depends On |
|---|---|---|
| DEC-01 / REM-02 | Settings save/discard lifecycle | DEC-01 option selected |
| DEC-02 / REM-03 | Evidence archive implementation | DEC-02 option selected |
| DEC-04 | Preview receiver state integration | DEC-04 architecture decision |

---

## 2. P0/P1 Slices

| Slice | Findings | Severity | Title | Wave |
|---|---|---|---|---|
| REM-01 | M-SB-01, M-SB-07 | P0 | Fix false Error banner after Stop | 1 |
| REM-02 | M-SB-02 | P0 | Fix `commandIntent` race | 1 |
| REM-03 | M-F-03, M-F-20 | P0 | Add Stop confirmation in live state | 1 |
| REM-04 | M-VA-01 | P0 | Fix warning banner contrast | 1 |
| REM-21 | M-F-01, M-SB-04 | P0/P1 | Evidence freshness session token | 2 |
| DEC-01 | M-F-02 | P0 | Settings save/discard (architecture decision required) | Decision |
| DEC-02 | M-SB-03 | P0 | Evidence archive before wipe (architecture decision required) | Decision |
| REM-05 | M-F-05 | P1 | Disable transport for unavailable modes | 1 |
| REM-06 | M-F-06 | P1 | Packet Monitor empty state | 1 |
| REM-07 | M-F-04 | P1 | Persistent transport strip | 2 |
| REM-08 | M-F-09, M-F-12, M-SB-12, M-SB-13 | P1 | Validation progress in banner | 2 |
| REM-09 | M-F-08 | P1 | Session banner CTAs in Ready/Armed | 2 |
| REM-10 | M-F-10 | P1 | Surface commandIntent display | 2 |
| REM-11 | M-SB-06, M-F-13 | P1 | Fix validation result label | 2 |
| REM-12 | M-SB-08 | P1 | Fix validation-failed preflight blocker | 2 |
| REM-13 | M-VA-02–05 | P1 | State color WCAG contrast fixes | 1 |
| REM-14 | M-VA-06, M-VA-13 | P1 | Banner accessibility semantics + icons | 1 |
| REM-15 | M-VA-07, M-VA-14 | P1 | Reduce-motion guards on animations | 1 |
| REM-16 | M-VA-08 | P1 | Restore transport focus ring | 2 |
| REM-20 | M-F-11 | P1 | Log file open affordance | 3 |
| DEC-04 | M-SB-05, M-SB-09, M-F-15 | P1 | Preview receiver state integration | Decision |

---

## 3. Low-Risk Quick Wins

Slices with very low risk, minimal effort, and no blocking dependencies. Can be done in any order within Wave 1 or batched as a single "quick-wins" PR.

| Slice | Title | Files | Effort |
|---|---|---|---|
| REM-02 | Fix commandIntent race | `OpenLolaApp.swift` | 30 min |
| REM-03 | Stop confirmation dialog | `AppTransportView.swift` | 30 min |
| REM-04 | Warning banner contrast | `AppDesignSystem.swift`, `AppSessionStateBanner.swift` | 1 hour |
| REM-06 | Packet Monitor empty state | Detail view + `AppShellRootView.swift` | 1 hour |
| REM-10 | Surface commandIntent label | Session detail view | 1 hour |
| REM-11 | Validation result label + shortcut hint | `AppShellSettingsTabs.swift`, `AppExecutionController.swift` | 1 hour |
| REM-13 | State color WCAG fixes | `AppDesignSystem.swift` | 1 hour |
| REM-14 | Banner alert role + state icons | `AppSessionStateBanner.swift` | 1 hour |
| REM-15 | Reduce-motion guards | `AppSessionStateBanner.swift`, `AppConnectionTopologyView.swift`, `AppChannelMeterView.swift` | 1 hour |
| REM-17 | Topology animation key fix | `AppConnectionTopologyView.swift` | 30 min |
| REM-18 | Clear ARM state after Stop | `AppExecutionController.swift` | 15 min |
| REM-19 | Auto-expand error disclosure | `AppOperatorArtifactViews.swift` | 30 min |
| REM-24 | Rename "App Readiness" | `AppShellSettingsTabs.swift` | 15 min |

---

## 4. Blocked / Decision-Needed Items

These items cannot proceed without a human decision or investigation result.

| Slice | Blocked By | What's needed |
|---|---|---|
| REM-01 | INV-01 | Confirm exact SIGTERM exit code and termination reason |
| REM-07 | DEC-03 | Decide transport bar layout strategy |
| REM-12 | REM-11 | `lastValidationResult` property must exist first |
| REM-20 | INV-02 | Confirm log file path persistence |
| REM-21 | None (but medium risk) | Review evidence file contract before adding sidecar |
| DEC-01 settings fix | DEC-01 | Product decision on save/discard strategy |
| DEC-02 evidence wipe | DEC-02 | Decide evidence archive strategy |
| DEC-04 preview status | DEC-04 | Architecture decision on receiver state sharing |
| REM-28 badge fix | INV-03 | Confirm badge data source before removing or wiring |

---

## 5. Final UI Verification Checklist

Run this checklist after all Wave 1 + Wave 2 slices are merged to confirm the highest-risk issues are resolved. Mark each item with ✅ when confirmed by direct observation.

### P0 State/Behavior

```
[ ] REM-01: Press Stop → banner shows idle/stopped state, NOT red Error.
[ ] REM-01: Trigger a real process failure → banner shows Error.
[ ] REM-02: Trigger a START that fails → commandIntent is NOT .runRequested afterward.
[ ] REM-03: Press Stop during a live session → confirmation dialog appears.
[ ] REM-03: Cancel the dialog → session continues live.
[ ] REM-21: Quit and relaunch app after a completed session → "Live" badge does NOT appear.
[ ] DEC-02: Start a new run with prior evidence → a "Previous run" snapshot is accessible (once DEC-02 implemented).
```

### P0 Accessibility

```
[ ] REM-04: Light Mode enabled → warning banner text is clearly legible.
[ ] REM-13: Light Mode enabled → armed, ready, live state labels are legible.
[ ] REM-13: Light Mode + Increase Contrast → all state labels legible.
[ ] REM-15: macOS Reduce Motion enabled → banner, topology, meters show no animation.
```

### P1 Workflow

```
[ ] REM-05: Select JackTrip workflow → ARM and START buttons are disabled.
[ ] REM-06: Navigate to Packet Monitor in .ready state → empty state message shown.
[ ] REM-07: Navigate to Meters section during live session → Stop button visible in footer/toolbar.
[ ] REM-08: Trigger ⌘⇧V validation → banner shows "Validating…" + spinner.
[ ] REM-08: Open Settings during validation → lock reason visible.
[ ] REM-09: App in .ready state → "Go to Session →" CTA visible in banner.
[ ] REM-09: App in .armed state → "Start Session" CTA visible in banner.
[ ] REM-11: Run a passing validation → Settings Validation tab shows "PASSED".
[ ] REM-11: Run a failing validation → Settings Validation tab shows "FAILED".
[ ] REM-12: Fail a validation → reset phase to idle → START remains blocked.
[ ] REM-12: Pass a validation → START is unblocked.
```

### P1 Accessibility

```
[ ] REM-14: Enable VoiceOver → transition to .error state → VoiceOver announces change.
[ ] REM-14: Session state icons visible (armed = bolt, error = xmark, live = circle).
[ ] REM-16: Full Keyboard Access → Tab through transport bar → focus ring visible on all buttons.
```

### P2 Behavior Correctness

```
[ ] REM-17: App relaunch with prior run report on disk → topology does NOT animate.
[ ] REM-17: Active supervisor run → topology animates.
[ ] REM-18: ARM → Stop (without starting) → ARM state cleared → START unavailable immediately.
[ ] REM-19: Trigger error state → error log disclosure auto-expands.
[ ] REM-20: Run a session → "Open Log" button visible → clicking opens log file.
```

### P2 Accessibility

```
[ ] REM-22: VoiceOver focus on channel meter → level value announced.
[ ] REM-22: VoiceOver focus on latency hero → "Round-trip latency: X milliseconds" announced.
[ ] REM-22: Transport button hit targets ≥44×44 pt (layout debugger).
[ ] REM-23: App in .ready state → meter section shows "No audio session active" empty state.
[ ] REM-25: Start a session from a non-Session sidebar section → sidebar auto-navigates to Session on .live transition.
```

### Hardware / Runtime Gates (require live session hardware)

```
[ ] Stop flow verified with a real audio session and real network participant.
[ ] Topology animation vs. real packet flow (requires live P2P session).
[ ] Preview receiver status race (requires concurrent main + preview window state test).
[ ] SIGTERM exit code confirmed from real process (INV-01 output).
```

---

*End of Open LoLa App — UI/UX Remediation Plan.*
*Production code changes: None. This document is planning only.*
