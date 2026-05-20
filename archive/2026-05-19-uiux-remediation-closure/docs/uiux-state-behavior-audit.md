# UI/UX State & Behavior Audit — Open LoLa App

**Scope:** Static source audit of `Sources/open-lola-app/` state machines, controls,
wiring, and runtime dependencies. No production code changes. All evidence is source-level
only; runtime behavior requires manual or automated integration verification.

**Audit date:** 2025
**Auditor:** Copilot static review
**Related docs:** `docs/uiux-surface-index.md`, `docs/uiux-flow-audit.md`,
`docs/uiux-visual-accessibility-audit.md`

---

## Findings

---

### SB-01 — User-initiated Stop shows `.error` session state banner
**Severity:** P0
**File/component:** `AppSessionStateBanner.swift` (`AppSessionState.derive`), `AppExecutionController.swift` (`launchProcess` termination handler, `stop`)
**State or action affected:** Session state banner after user clicks Stop

**Evidence:**
- `stop()` calls `process.terminate()` (SIGTERM) and sets `stopWasRequested = true`.
- The termination handler sets `phase = .stopRequested` and records `lastExitCode = Int(finished.terminationStatus)`.
- On macOS, a process killed via SIGTERM exits with a non-zero status (signal 15 → exit code 143 or platform-specific non-zero).
- `AppSessionState.derive`: after stop, `isRunning = false` and `phase = .stopRequested`. The switch statement hits `default: break`. The code then evaluates `if let code = lastExitCode, code != 0 { return .error }`.
- Result: **the banner shows `.error` (red, "Error — check execution log for details") after every user-initiated Stop**, even when the stop was intentional and clean.

**What the UI claims:** An error has occurred; the user should check the execution log.
**What is actually proven:** The user clicked Stop. The process was terminated by SIGTERM.
**User/runtime impact:** Every normal Stop workflow ends in a false error state. The error banner persists until the next successful run or app restart. Users cannot distinguish a real crash from a clean stop.
**Suggested remediation:** In `AppSessionState.derive`, check `phase == .stopRequested` before evaluating `lastExitCode`. Return `.ready` (or a dedicated `.stopped` state) when stop was requested.
**Test or manual verification needed:** Manually: ARM → Start → Stop. Observe session state banner. Expected: no error. Actual: error.
**Confidence:** High — source path is unambiguous.

---

### SB-02 — `commandIntent = .runRequested` set before `startArmed()` completes
**Severity:** P0
**File/component:** `OpenLolaApp.swift` (`appMenuActionButton`, `start-armed-supervisor`), `AppTransportView.swift` (Start button handler)
**State or action affected:** Session state banner, `commandIntent` on run start failure

**Evidence:**
- In `OpenLolaApp.swift` (line 109): `operatorSurface.commandIntent = .runRequested` is set on the binding, then `executionController.startArmed(operatorSurface:)` is called.
- `AppSessionStateBanner.swift`: when `commandIntent == .handoffRequested`, state is `.connecting`. For `.runRequested`, state resolves after `isRunning` check.
- If `startArmed()` fails (e.g., `writePlanOrLogError` throws, or process launch fails), `phase = .failedToStart` or `phase = .runFailed`, but `commandIntent` remains `.runRequested`. The binding write is not rolled back.
- `AppTransportView.swift` follows the same pattern: `operatorSurface.commandIntent = .runRequested` is set before `executionController.startArmed`.

**What the UI claims:** A run was requested (intent `.runRequested` in state).
**What is actually proven:** The intent was written but the run may not have started.
**User/runtime impact:** If `startArmed` fails synchronously, `commandIntent` is stale and the banner/overview panel may show `.connecting` or an inconsistent state from which there is no automatic recovery. The stale intent persists across subsequent state refreshes.
**Suggested remediation:** Set `commandIntent = .runRequested` only after confirming the process was launched (i.e., only from within the `onPrepared` callback or after `startArmed` returns success). Roll back on failure.
**Test or manual verification needed:** Set an invalid executable path. Click Start. Check `commandIntent` after failure.
**Confidence:** High.

---

### SB-03 — `launchProcess()` silently wipes all prior evidence at run start
**Severity:** P0
**File/component:** `AppExecutionController.swift` (`launchProcess`, lines 455–461)
**State or action affected:** All prior run evidence: `lastExitCode`, `lastValidationExitCode`, `lastError`, `errorLog`, `lastExternalConnectorReport`, `lastLatencyMetrics`, `lastCaptureReport`

**Evidence:**
```swift
lastExitCode = nil
lastValidationExitCode = nil
lastError = nil
errorLog = []
lastExternalConnectorReport = nil
lastLatencyMetrics = nil
lastCaptureReport = nil
```
All of these are cleared unconditionally at the start of every `launchProcess()` call. There is no user prompt, no warning, and no archive of prior evidence. `runOneShot()` (validation) also clears `lastExitCode`, `lastValidationExitCode`, `lastError`, and `errorLog`.

**What the UI claims:** Reports, evidence, and logs are available to inspect.
**What is actually proven:** Evidence is only available until the next run or validation starts. A single click of Start or Validate discards all previous artifacts.
**User/runtime impact:** A user reviewing latency metrics or a capture report from a successful session loses all evidence the moment a new run starts (intentionally or accidentally). Error logs from a failed run are also discarded. No recovery path once overwritten.
**Suggested remediation:** Archive at minimum the previous `lastReport`, `lastLatencyMetrics`, `lastCaptureReport` under a "previous run" slot before clearing. Show a warning if prior validated evidence is about to be overwritten by a new run start.
**Test or manual verification needed:** Complete a run with validated evidence; click Start again; observe that `lastLatencyMetrics` and `lastCaptureReport` are nil.
**Confidence:** High — source path is explicit.

---

### SB-04 — `awaitingEvidence` banner during active validation uses an instruction-as-status label
**Severity:** P1
**File/component:** `AppSessionStateBanner.swift`, `AppExecutionController.swift` (`runOneShot`)
**State or action affected:** Session state banner during validation in progress

**Evidence:**
- During `runOneShot`, `phase = .validationRunning` and `isRunning = true`.
- `AppSessionState.derive`: `isRunning == true`, `phase == .validationRunning` → returns `.awaitingEvidence`.
- `AppSessionState.awaitingEvidence` banner label: "Awaiting evidence — validate the runtime report before treating the session as live."
- This message instructs the user to validate, but validation is already running.

**What the UI claims:** User should validate the runtime report.
**What is actually proven:** Validation is actively running.
**User/runtime impact:** The user sees an instruction to do something they are already doing. There is no distinct "Validation in progress" state or label; the validation state is aliased with the pre-validation waiting state.
**Suggested remediation:** Add a dedicated `.validating` case to `AppSessionState` returned when `isRunning == true && phase == .validationRunning`. Display a distinct "Validating — please wait." label.
**Test or manual verification needed:** Click Validate while report exists. Observe banner label during validation.
**Confidence:** High.

---

### SB-05 — Validate button enabled for any existing file, regardless of freshness
**Severity:** P1
**File/component:** `AppExecutionController.swift` (`validationReadiness`, lines 272–284), `AppTransportView.swift`
**State or action affected:** Validate button enabled state; evidence freshness

**Evidence:**
```swift
guard !trimmedPath.isEmpty, FileManager.default.fileExists(atPath: trimmedPath) else {
    return .missingReport(...)
}
return .ready
```
`validationReadiness` returns `.ready` as long as the file exists at the configured path. It does not check:
- File modification date vs. the current session's `startedAt`.
- Whether the file was produced by the current executable or the current run.
- Whether the file is a valid JSON report.
- Whether `lastExitCode` is set (i.e., a run was actually completed).

**What the UI claims:** The session is ready to validate (Validate button enabled).
**What is actually proven:** A file exists at the supervisor report path. That file may be from a previous session, a previous app launch, or a different configuration entirely.
**User/runtime impact:** User validates a stale report from a previous session. `hasValidatedRuntimeEvidence` becomes `true`, potentially advancing the session state to `.live` based on evidence that does not correspond to the current run.
**Suggested remediation:** Compare the report file's modification date (or `startedAt` field inside the report) with `executionController.startedAt`. Only enable Validate if the file post-dates the current run start.
**Test or manual verification needed:** Run a session. Let it complete. Restart the app without deleting the report file. Without starting a new run, click Validate. Observe that validation proceeds on a stale file.
**Confidence:** High.

---

### SB-06 — "Remote unavailable" shown with neutral tone for a configuration error
**Severity:** P1
**File/component:** `AppSessionStateBanner.swift` (`remoteStreamTitle`, `remoteStreamTone`)
**State or action affected:** Top bar remote stream badge for `directMacPeer` mode

**Evidence:**
```swift
// directMacPeer: macB == nil
→ title: "Remote unavailable"
→ tone: .secondary  // neutral gray
```
When `plan.macB == nil` (remote peer not configured), the top bar badge reads "Remote unavailable" in a neutral secondary color. No error or warning color is applied. The `.secondary` tone is the same as a standard informational label.

**What the UI claims:** The remote status is neutral/informational.
**What is actually proven:** The remote peer is not configured — this is a prerequisite for any real session.
**User/runtime impact:** A missing remote peer appears as a routine status, not a configuration error. Users unfamiliar with the app may miss that this is a required setup step before a session can proceed.
**Suggested remediation:** Use `.orange` or `.red` tone for "Remote unavailable" when in `directMacPeer` mode to signal it as a configuration requirement.
**Test or manual verification needed:** Switch to `directMacPeer` mode with no remote peer configured. Observe the top bar badge color.
**Confidence:** High.

---

### SB-07 — Evidence freshness label shows "Last validator result" for any exit code, including failure
**Severity:** P1
**File/component:** `AppConsoleModels.swift` (`AppOverviewEvidenceSummary.freshness`)
**State or action affected:** Evidence summary panel freshness label

**Evidence:** `freshness` returns `"Last validator result"` whenever `lastValidationExitCode != nil`, without checking whether that exit code was 0 (pass) or non-zero (fail). A user who ran validation and saw it fail still sees "Last validator result" as the freshness label, which implies recent valid evidence.

**What the UI claims:** There is a recent validator result that can be used as evidence.
**What is actually proven:** The validator ran at some point. The result may be a failure.
**User/runtime impact:** Failed validation evidence is presented with the same freshness label as passed validation. Users may interpret "Last validator result" as positive evidence.
**Suggested remediation:** Distinguish freshness labels: "Last validator result: PASS" vs. "Last validator result: FAILED" (or use the exit code). Alternatively, only show the "Last validator result" label when `lastValidationExitCode == 0`.
**Test or manual verification needed:** Run validation with a corrupt or wrong report file (non-zero exit). Observe freshness label.
**Confidence:** High.

---

### SB-08 — Status stays "Stop requested." indefinitely after a user-initiated stop
**Severity:** P1
**File/component:** `AppExecutionController.swift` (`stop`, termination handler lines 481–483), `AppTransportView.swift` (`statusTone`)
**State or action affected:** Transport bar status pill after Stop

**Evidence:**
- `stop()` sets `status = "Stop requested."`.
- The termination handler, when `wasStopRequested`, sets `status = "Stop requested."` again (line 482).
- There is no subsequent transition that resets `status` to "Idle.", "Stopped.", or any completion message.
- `statusTone` in `AppTransportView`: shows `.stateConnecting` (yellow/orange) while `isRunning`, then `.secondary` unless "fail" appears in `status`. After stop, `status = "Stop requested."` → tone is `.secondary`. So the pill shows "Stop requested." in gray indefinitely, even days later.

**What the UI claims:** A stop was requested (implying it's in progress or just completed).
**What is actually proven:** The process was already terminated. The session is idle.
**User/runtime impact:** Persistent "Stop requested." message creates false impression of an ongoing operation. The user has no clear visual confirmation that the stop completed.
**Suggested remediation:** After `finishReport(stopRequested: true)` completes, transition `status` to "Stopped." or "Idle." to confirm completion.
**Test or manual verification needed:** ARM → Start → Stop → Wait 30 seconds. Observe status pill still reads "Stop requested."
**Confidence:** High.

---

### SB-09 — Validation-failed preflight blocker clears when phase changes
**Severity:** P1
**File/component:** `AppConsoleModels.swift` (`AppValidationPreflightModel`)
**State or action affected:** Validation preflight warning in Overview panel

**Evidence:**
```swift
// Only shows the "last validation failed" blocker when phase == .validationFailed
if executionController.phase == .validationFailed {
    // show blocker
}
```
If the user starts a new run after a failed validation, `phase` transitions from `.validationFailed` to `.supervisorRunning`. The blocker disappears even though `lastValidationExitCode` is still non-zero and the evidence gap was never resolved.

**What the UI claims:** There is no validation failure to address.
**What is actually proven:** The phase changed, but the underlying evidence gap (failed validation) was not resolved.
**User/runtime impact:** A user who had a failed validation can start a new run without the warning being visible. They may not realize the prior validation failure is unresolved.
**Suggested remediation:** Persist the validation-failed blocker in the preflight model until `lastValidationExitCode == 0` is explicitly achieved (not just until phase changes). Clear it only when `hasValidatedRuntimeEvidence == true`.
**Test or manual verification needed:** Run a session → validate with a corrupt report (fail) → start a new run → check Overview panel for validation-failed blocker during the new run.
**Confidence:** High.

---

### SB-10 — Preview window status set to "requested" before window is actually open
**Severity:** P1
**File/component:** `OpenLolaApp.swift` (`appMenuActionButton`, "open-local-preview-window")
**State or action affected:** `previewState.receiverStatus`

**Evidence:**
```swift
case "open-local-preview-window":
    menuButton(action) {
        previewState.receiverStatus = "Local preview window requested."
        openWindow(id: "receiver")
    }
```
`receiverStatus` is set to "Local preview window requested." synchronously, before `openWindow(id: "receiver")` completes (window open is asynchronous). If the window fails to open, the status stays "Local preview window requested." with no error feedback.

**What the UI claims:** The local preview window was successfully requested.
**What is actually proven:** The `openWindow` call was issued. The window may or may not have opened successfully.
**User/runtime impact:** If the preview window fails to open (e.g., resource issue), the user sees "Local preview window requested." with no indication of failure. No error path exists in the status update.
**Suggested remediation:** Only set `receiverStatus` to a "ready" label after the window's `onAppear` fires, or add error handling for window open failure.
**Test or manual verification needed:** Open the preview window; observe the status message timing.
**Confidence:** High (wiring confirmed in source).

---

### SB-11 — No in-progress indicator for validation running state in transport bar
**Severity:** P1
**File/component:** `AppTransportView.swift`, `AppExecutionController.swift` (`runOneShot`)
**State or action affected:** Transport bar feedback during validation

**Evidence:**
- During validation: `phase = .validationRunning`, `status = "Validation running."`, `isRunning = true`.
- `statusTone = .stateConnecting` (yellow) when `isRunning`.
- The Validate button is `.disabled(true)` because `validateAvailable = validationReadiness.isReady` and `isRunning` causes `.running` readiness.
- There is no `ProgressView`, no spinner, no distinct label in the transport bar that says "Validating…". The status pill shows the yellow "Validation running." text.
- The session banner shows `.awaitingEvidence` (yellow): "Awaiting evidence — validate the runtime report before treating the session as live." (confusingly an instruction, per SB-04).

**What the UI claims:** The yellow status pill "Validation running." is the only in-progress indicator.
**What is actually proven:** Validation is running. The only visual feedback is the disabled Validate button and a status pill text that may be missed.
**User/runtime impact:** No spinner or animation in the transport bar. A user who isn't watching the status pill may not know validation is in progress and might try to interact with other controls.
**Suggested remediation:** Add a `ProgressView().controlSize(.small)` adjacent to the Validate button or status pill when `phase == .validationRunning`.
**Test or manual verification needed:** Click Validate on a valid report. Observe transport bar for visual in-progress indicator.
**Confidence:** High.

---

### SB-12 — Topology animation runs on stale disk-loaded evidence
**Severity:** P2
**File/component:** `AppConnectionTopologyView.swift` (`isLive`, `updateAnimationState`), `AppRuntimeEvidenceScope.swift` (`hasValidatedRuntimeEvidence`)
**State or action affected:** Data-flow animation in topology diagram

**Evidence:**
```swift
private var isLive: Bool { sessionState == .live }
// Animation starts when isLive == true
```
`sessionState == .live` is reached when `hasValidatedRuntimeEvidence == true`, which is satisfied by a validation report loaded from disk — even if that report is from a previous app session or a previous run.

After app launch, if a supervisor report exists at the configured path from a prior session and a validation exit code of 0 exists (stored in `UserDefaults` or stale controller state), `hasValidatedRuntimeEvidence` could return `true` without any live audio session, causing the flow animation to run on data that is not live.

**What the UI claims:** Audio, video, control, and metrics data is actively flowing between peers.
**What is actually proven:** The evidence files (report JSON) exist on disk from a prior session.
**User/runtime impact:** Users see animated data-flow arrows suggesting an active live session when no audio/video session is running.
**Suggested remediation:** Gate `isLive` on both `hasValidatedRuntimeEvidence` AND `isRunning == true` (for the supervisorRunning phase). Or add a session-start timestamp comparison against the evidence file's timestamp.
**Test or manual verification needed:** Run a session. Validate it. Stop it. Restart the app (without deleting reports). Observe whether the topology shows animation.
**Confidence:** Medium — depends on UserDefaults persistence of `lastValidationExitCode` and `hasValidatedRuntimeEvidence` computation. Full confidence requires tracing `AppShellStoredDefaults`.

---

### SB-13 — Topology arrows show all channel types regardless of session mode
**Severity:** P2
**File/component:** `AppConnectionTopologyView.swift` (`channelArrows`)
**State or action affected:** Topology diagram channel rows

**Evidence:**
```swift
arrowRow(label: "audio ×\(channelCount)", icon: "waveform", color: AppDesignSystem.stateLive)
arrowRow(label: "video", icon: "video.fill", color: .blue)
arrowRow(label: "control", icon: "slider.horizontal.3", color: AppDesignSystem.stateArmed)
if sessionMode == .directMacPeer {
    arrowRow(label: "metrics", icon: "chart.line.uptrend.xyaxis", color: .secondary)
}
```
Audio, video, and control rows are always shown regardless of `sessionMode`. For `windowsLoLa` mode, the session may not support all channel types. No channel is conditionally shown based on whether that channel is actually configured and active.

**What the UI claims:** Audio, video, and control channels are always active in any session.
**What is actually proven:** These are static UI rows; they reflect the session mode's theoretical channels, not actual channel state.
**User/runtime impact:** A video-disabled session still shows a video row with animated flow dots. Users see misleading channel activity indicators.
**Suggested remediation:** Gate each row on the relevant `operatorSurface` configuration (e.g., hide video row when video is disabled, reference `directPeerCommandFields.videoWidth == 0` or similar).
**Test or manual verification needed:** Configure a session in audio-only mode. Observe topology diagram.
**Confidence:** Medium (mode-specific channel gating requires runtime/plan-level knowledge not visible in the UI file alone).

---

### SB-14 — ARM state persists after Stop with no visual warning
**Severity:** P2
**File/component:** `AppExecutionController.swift` (`stop`), `AppTransportView.swift` (ARM/Start buttons)
**State or action affected:** `armedForExecution` boolean after Stop

**Evidence:**
- `stop()` does NOT reset `armedForExecution`.
- After stop: `armedForExecution = true`, `isRunning = false`.
- The Start button in the transport bar: `disabled(!startAvailable)` where `startAvailable = armedForExecution && dryRunAvailable`. After stop, if dry run is still available, the Start button remains enabled.
- No warning or prompt is shown that the session is still armed.

**What the UI claims:** The ARM button shows the current armed state (the toggle still shows armed).
**What is actually proven:** The session remains armed from before the stop; the next click of Start will immediately launch a new process.
**User/runtime impact:** After Stop, a user intending to review results before a new run can accidentally re-launch the session immediately. There is no re-arming step required.
**Suggested remediation:** Reset `armedForExecution = false` in the termination handler when `wasStopRequested == true`, or show a re-arm prompt before enabling Start after a stop.
**Test or manual verification needed:** ARM → Start → Stop immediately. Observe Start button remains enabled.
**Confidence:** High.

---

### SB-15 — `errorLog` silently discarded at new run start
**Severity:** P2
**File/component:** `AppExecutionController.swift` (`launchProcess`, `runOneShot`, line 458)
**State or action affected:** Error log panel (`AppLogsView`, `AppExecutionErrorLogView`)

**Evidence:**
```swift
errorLog = []  // cleared unconditionally in launchProcess and runOneShot
```
When a new run or validation starts, all prior error log entries are cleared. The user has no opportunity to save the error log before it disappears.

**What the UI claims:** The execution error log shows errors from the current session.
**What is actually proven:** The log only contains errors from the most recent `launchProcess` or `runOneShot` call. Prior errors are permanently gone.
**User/runtime impact:** Investigating a failed run is interrupted by accidentally starting a new run or validation, destroying the only evidence. No file-based backup of the error log exists at the UI level.
**Suggested remediation:** Before clearing `errorLog`, append it to a "previous run errors" slot. Display both current and previous error logs in the log panel.
**Test or manual verification needed:** Cause an error (e.g., set an invalid executable). Click Start (fails, errors logged). Click Start again. Check that error log is empty.
**Confidence:** High.

---

### SB-16 — All execution settings locked during validation (`runOneShot`)
**Severity:** P2
**File/component:** `AppShellSettingsView.swift` (`executionSettingsLocked`), `AppExecutionController.swift` (`isRunning` during `runOneShot`)
**State or action affected:** Settings window during validation

**Evidence:**
```swift
var executionSettingsLocked: Bool {
    executionController.isRunning
}
```
`isRunning == true` during `runOneShot` (shares `process` pointer). Therefore all settings tabs in the Settings window are `.disabled(true)` during validation. The help text says "Execution-affecting settings are locked while a process is active."

**What the UI claims:** Settings are locked because an execution process is active.
**What is actually proven:** A validation process (not a session process) is active.
**User/runtime impact:** The lock message is accurate ("a process is active") but users may find it unexpected that running a validator locks all settings. This creates unnecessary friction between validation and settings review.
**Suggested remediation:** Consider a separate `isValidating` flag, and only lock the subset of settings that affect validation (e.g., report path, executable path). Or distinguish the lock message: "Execution settings locked while validation is running."
**Test or manual verification needed:** Click Validate. Immediately open Settings. Observe lock state.
**Confidence:** High.

---

### SB-17 — Settings persist to UserDefaults immediately on every keystroke
**Severity:** P2
**File/component:** `AppSettings.swift` (all `didSet` implementations)
**State or action affected:** All settings fields (50+ properties)

**Evidence:** Every property in `AppSettings` has a `didSet` that immediately calls `defaults.set(...)`. There is no save, discard, or confirm button. A partial host name or port number typed mid-edit is immediately written to `UserDefaults.standard` and propagates to `operatorSurface` via the settings binding.

**What the UI claims:** Implicit — settings are always current.
**What is actually proven:** Every in-progress edit, even a partial or accidental keystroke, overwrites the previously valid stored configuration with no recovery path.
**User/runtime impact:** Typing a partial IP address (e.g., "192.168.") immediately corrupts the stored configuration. Closing the app and reopening restores the corrupted value. No undo or discard option exists.
**Suggested remediation:** Use a "pending changes" model: buffer settings changes in-memory and only write to `UserDefaults` on an explicit "Apply" action or on window close. Alternatively, validate and reject malformed values in `didSet`.
**Test or manual verification needed:** Open settings. Partially edit a host field. Close and reopen the settings window. Verify that the partial value was persisted.
**Confidence:** High.

---

### SB-18 — `Write Plan` button disabled for non-directMacPeer with no visible explanation
**Severity:** P2
**File/component:** `AppExecutionView.swift` (Write Plan button), `AppTransportView.swift` (`prepareExecution`)
**State or action affected:** Write Plan button in Execution section

**Evidence:**
```swift
// AppExecutionView.swift: button disabled for non-directMacPeer
Button("Write Plan") { ... }
    .disabled(executionController.isRunning || operatorSurface.sessionMode != .directMacPeer)
```
In `windowsLoLa` mode, the button is disabled. For `jackTrip`/`ultraGrid`, it's also disabled. No tooltip or explanatory text explains why — just a disabled state.

**What the UI claims:** Nothing; the button is simply not interactive.
**What is actually proven:** Plan writing is not applicable to the current mode.
**User/runtime impact:** A user in `windowsLoLa` mode clicking Write Plan gets no feedback explaining it's not needed. They may think the feature is broken or that they're missing a step.
**Suggested remediation:** Add `.help(...)` text explaining: "Plan writing is only available in Direct Mac-to-Mac mode. Windows LoLa mode uses an implicit plan." or hide the button for modes where it's not applicable.
**Test or manual verification needed:** Switch to `windowsLoLa` mode. Hover over the Write Plan button. Observe tooltip content.
**Confidence:** High (confirmed disabled condition in source; tooltip absence confirmed).

---

### SB-19 — Top-bar verdict badge reflects static smoke test, not runtime session evidence
**Severity:** P2
**File/component:** `OpenLolaApp.swift` (`refreshSyntheticMetricsAsync`), `AppShellReadOnlyViews.swift` (`AppShellOverviewView`)
**State or action affected:** "App readiness" verdict in Overview section; top bar verdict badge

**Evidence:**
```swift
@State private var report = NativeAppShellReport.placeholder()
// Updated only by:
report = await Task.detached { NativeAppShellSyntheticSmoke.run() }.value
```
The `report` shown in the Overview "App readiness" panel is sourced from `NativeAppShellSyntheticSmoke.run()`, a build-time static smoke test. It is refreshed on launch and via the "Refresh Synthetic Metrics" menu item. It is never updated from actual session execution results (`executionController.lastReport`).

**What the UI claims:** The verdict badge ("App readiness → PARTIAL/PASS/FAIL") reflects the app's current readiness.
**What is actually proven:** The build smoke ran at launch and produced a static verdict. No real session was executed or validated.
**User/runtime impact:** A `PARTIAL` verdict from the smoke test may cause confusion after a user completes a successful real session. The verdict never improves in response to real runtime evidence.
**Suggested remediation:** Distinguish the smoke verdict from the session verdict. Label the smoke result "Build readiness" and the session result "Session readiness." Consider updating the session verdict badge from `executionController.lastReport.verdict` after a validated run.
**Test or manual verification needed:** Complete a session and validate it with a passing report. Observe whether the verdict badge changes.
**Confidence:** High.

---

### SB-20 — `AppWorkflowUnavailableView` shown for jackTrip/ultraGrid but transport bar remains partially active
**Severity:** P2
**File/component:** `AppLocalOperatorSurfaceView.swift` (`AppWorkflowUnavailableView`), `AppTransportView.swift` (`prepareExecution`)
**State or action affected:** Transport bar and execution controls for unsupported session modes

**Evidence:**
- When `sessionMode == .jackTrip || .ultraGrid`, `AppWorkflowUnavailableView` is shown in the local operator panel.
- `prepareExecution()` returns `false` for these modes, so Start/Dry Run do nothing.
- However, the transport bar is still rendered. The ARM button, Dry Run, and Start buttons are visible but disable silently (Start is disabled because `prepareExecution` returns false, but the user sees no explanation).
- `statusModeTitle` returns "JACKTRIP UNAVAILABLE" / "ULTRAGRID UNAVAILABLE" in the transport bar, which is informative but may not be sufficient.

**What the UI claims:** The transport bar presents execution controls.
**What is actually proven:** These modes cannot be executed from the app.
**User/runtime impact:** ARM and Start buttons are visible and partially interactive for unsupported modes. Users may try to use them and get no response. The only feedback is the "UNAVAILABLE" label in the status mode badge.
**Suggested remediation:** Disable the entire transport bar (or hide Start/DryRun/ARM) when `sessionMode` is unsupported. Add a tooltip explaining why.
**Test or manual verification needed:** Switch to `jackTrip` mode. Observe transport bar state and button behavior.
**Confidence:** High.

---

### SB-21 — Paste Remote Inventory overwrites editor without parse/preview guard
**Severity:** P2
**File/component:** `AppOperatorArtifactViews.swift` (`pasteRemoteInventoryJSON`)
**State or action affected:** Remote inventory JSON editor, subsequent Import operation

**Evidence:**
```swift
private func pasteRemoteInventoryJSON() {
    guard let json = NSPasteboard.general.string(forType: .string),
          !json.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        status = "Pasteboard does not contain remote inventory JSON."
        return
    }
    remoteInventoryJSON = json
    status = "Pasted remote inventory JSON."
}
```
The guard only checks that the pasteboard contains a non-empty string. Any non-empty string — not just valid JSON — overwrites the `remoteInventoryJSON` editor. The user may have previously typed or pasted valid JSON that is now destroyed without confirmation.

**What the UI claims:** "Pasted remote inventory JSON." — implies success.
**What is actually proven:** Any non-empty string from the pasteboard was placed in the editor. It may not be valid inventory JSON.
**User/runtime impact:** If the user accidentally has non-JSON content on the pasteboard, valid inventory data in the editor is silently replaced. The status message "Pasted remote inventory JSON." incorrectly implies the content is valid JSON.
**Suggested remediation:** Validate the pasted content as parseable JSON (or as `NativeAppShellMediaInventory`) before overwriting the editor. Show a preview or confirmation if the editor already contains content.
**Test or manual verification needed:** Copy a plain text string to the pasteboard. Click Paste. Observe editor and status message.
**Confidence:** High.

---

### SB-22 — Menu action falls back to "Unsupported: [title]" disabled button for unknown actions
**Severity:** P3
**File/component:** `OpenLolaApp.swift` (`unsupportedMenuAction`, `AppMenuActionHandling.handledActionIDs`)
**State or action affected:** App menu items

**Evidence:**
```swift
private func unsupportedMenuAction(_ action: NativeAppShellSurfaceAction) -> some View {
    Button("Unsupported: \(action.title)") {}
        .disabled(true)
        .help("Unsupported menu action: \(action.id)")
}
```
The `handledActionIDs` set is hardcoded. If `NativeAppShellSurfaceContract.releaseReadiness` adds new actions whose IDs are not in `AppMenuActionHandling.handledActionIDs`, they render as disabled buttons with "Unsupported: [title]" labels in the menu.

**What the UI claims:** A menu item exists with its contract-defined title.
**What is actually proven:** The action is not handled; it does nothing.
**User/runtime impact:** Any future contract addition leaks as a visible disabled "Unsupported:" item in the Open LoLa menu. This is a developer-visible defect but may be user-visible in production.
**Suggested remediation:** Hide (not just disable) unhandled menu actions, or generate an assertion/error log entry so the gap is caught during development.
**Test or manual verification needed:** Add a new action to the surface contract without adding it to `handledActionIDs`. Open the menu.
**Confidence:** High.

---

### SB-23 — ARM toggle in execution panel and ARM button in transport bar are duplicate entry points
**Severity:** P3
**File/component:** `AppExecutionView.swift` (ARM `Toggle`), `AppTransportView.swift` (ARM button)
**State or action affected:** `executionController.armedForExecution` boolean

**Evidence:** Both `AppExecutionView` and `AppTransportView` write to `executionController.armedForExecution`. `AppShellDerivedSurface.make` defers one tick via `Task { await Task.yield(); refreshDerivedSurface() }`. During that tick, one control may show the new state while derived state is stale.

**What the UI claims:** ARM is controlled from the transport bar.
**What is actually proven:** ARM can be toggled from both the execution detail panel and the transport bar.
**User/runtime impact:** Minimal — both write to the same boolean and the state resolves correctly after one tick. Risk of confusion if both controls are visible simultaneously and one appears out of sync momentarily.
**Suggested remediation:** Document the dual entry point explicitly. Ensure both controls are always visible together or that only one is shown at a time.
**Test or manual verification needed:** Open Execution section. Observe ARM toggle. Click ARM in transport bar. Verify toggle in execution panel updates.
**Confidence:** Medium (one-tick lag confirmed; whether both are simultaneously visible requires runtime check).

---

### SB-24 — `AppConnectionTopologyView` animation has no `accessibilityReduceMotion` guard
**Severity:** P3
**File/component:** `AppConnectionTopologyView.swift` (`restartAnimation`)
**State or action affected:** Flow dot animation when session is live

**Evidence:**
```swift
withAnimation(.linear(duration: Animation.flowDurationSeconds).repeatForever(autoreverses: false)) {
    flowOffset = trackWidth
}
```
No `@Environment(\.accessibilityReduceMotion)` check. When the session enters `.live` state, the flow dot animation repeats indefinitely regardless of system accessibility settings.

**What the UI claims:** Session data is flowing (animation).
**What is actually proven:** The session is in `.live` state.
**User/runtime impact:** Users with vestibular disorders or motion sensitivity who have enabled Reduce Motion in System Settings will still see the repeating animation. This was also noted in `docs/uiux-visual-accessibility-audit.md` as VA-03.
**Suggested remediation:** Add `@Environment(\.accessibilityReduceMotion) var reduceMotion` and skip the repeating animation when `reduceMotion == true`, showing a static indicator instead.
**Test or manual verification needed:** Enable Reduce Motion in System Settings → Accessibility. Enter a `.live` session state. Observe topology animation.
**Confidence:** High.

---

## Summary

### 1. False-Success UI States

| ID | Summary | Severity |
|----|---------|----------|
| SB-01 | Stop → `.error` banner (false error after clean stop) | P0 |
| SB-06 | "Remote unavailable" shows as neutral, not as a config error | P1 |
| SB-07 | "Last validator result" freshness label regardless of pass/fail | P1 |
| SB-08 | Status stuck at "Stop requested." after stop completes | P1 |
| SB-10 | "Local preview window requested." before window opens | P1 |
| SB-12 | Topology animation runs on stale disk-loaded evidence | P2 |
| SB-19 | Top-bar verdict from static smoke, not real session evidence | P2 |

---

### 2. Broken or Unwired Controls

| ID | Summary | Severity |
|----|---------|----------|
| SB-02 | `commandIntent = .runRequested` written before run succeeds | P0 |
| SB-18 | Write Plan disabled for non-directMacPeer with no explanation | P2 |
| SB-20 | Transport bar partially active for unsupported (jackTrip/ultraGrid) modes | P2 |
| SB-22 | Unhandled menu actions render as visible "Unsupported:" disabled buttons | P3 |
| SB-23 | ARM has two entry points (toggle + button) with one-tick desync risk | P3 |

---

### 3. Missing Loading / Empty / Error States

| ID | Summary | Severity |
|----|---------|----------|
| SB-04 | No distinct "Validation in progress" banner state — aliased with "Awaiting evidence" | P1 |
| SB-11 | No spinner or animated indicator in transport bar during validation | P1 |
| SB-08 | No "Stopped" completion state — "Stop requested." never resolves | P1 |

---

### 4. Settings / Runtime Mismatch

| ID | Summary | Severity |
|----|---------|----------|
| SB-03 | All prior run evidence cleared at new run start with no user warning | P0 |
| SB-05 | Validate enabled for any existing file regardless of freshness or session match | P1 |
| SB-09 | Validation-failed preflight blocker cleared when phase changes, not when evidence improves | P1 |
| SB-15 | Error log silently cleared at new run start | P2 |
| SB-16 | All execution settings locked during validation | P2 |
| SB-17 | Settings write to UserDefaults immediately on every keystroke — no save/discard | P2 |
| SB-13 | Topology shows all channel types regardless of session mode configuration | P2 |
| SB-14 | ARM state persists after Stop with no warning | P2 |

---

### 5. Suggested UI State Tests

1. **ARM → Start → Stop → Check banner**: Verify banner shows a non-error state after user-initiated stop. (Tests SB-01.)
2. **ARM → Start with invalid executable → Check `commandIntent`**: Verify `commandIntent` is not left as `.runRequested` after a failed start. (Tests SB-02.)
3. **Complete run with validated evidence → Start new run → Check evidence**: Verify that `lastLatencyMetrics` and `lastCaptureReport` are nil at the start of the new run, and that the user was warned. (Tests SB-03.)
4. **Validate with stale report from previous session**: Verify `validationReadiness` rejects a report whose modification date pre-dates the current `startedAt`. (Tests SB-05.)
5. **Validate → run passes validation → Start new run → observe preflight blocker**: Verify that `lastValidationExitCode` freshness is correctly tracked through phase transitions. (Tests SB-09.)
6. **Settings edit mid-run**: Verify that settings writes during `isRunning == true` are blocked or shown as pending. (Tests SB-17.)
7. **jackTrip mode**: Verify transport bar buttons are fully disabled or hidden and explain why. (Tests SB-20.)
8. **Freshness label for failed validation**: Verify "Last validator result" is qualified with pass/fail status. (Tests SB-07.)
9. **`accessibilityReduceMotion` in topology view**: Verify no repeating animation when system Reduce Motion is enabled. (Tests SB-24.)

---

### 6. Remaining Uncertainty

- **`hasValidatedRuntimeEvidence` across app launches:** Whether `lastValidationExitCode` is re-initialized from `UserDefaults` at startup (which would make SB-05 and SB-12 more severe) was not fully traced in `AppShellStoredDefaults`. If this value is persisted across launches, the stale-evidence window is unbounded.
- **Dual ARM entry point desync:** Whether `AppExecutionView` (ARM toggle) and `AppTransportView` (ARM button) are simultaneously visible in the same layout was not confirmed by runtime inspection. If one is always hidden when the other is visible, SB-23 severity may drop.
- **`ManagedProcessRunner.start` exit code on SIGTERM:** The exact exit code returned by `terminate()` on macOS was not confirmed by running the process. If any targeted open-lola process handles SIGTERM and exits 0, SB-01 would only be a problem for processes that don't handle SIGTERM gracefully.
- **`AppPreviewReceiverState.receiverStatus` display location:** The full rendering surface for `receiverStatus` was not traced. If this message is displayed in the preview window itself (not the main window), SB-10 impact is limited to the preview window.
- **Stale `commandIntent` persistence across window hide/show:** Whether `commandIntent` persists across scene phase changes (background/foreground) and whether it is cleared in `handleScenePhaseChange` was not fully traced.
- **`AppShellStoredDefaults.placeholderOperatorSurface()` initialization with stale path data:** If the stored executable path from UserDefaults points to a non-existent file, the initial `isConfigured` state at launch is unknown. This may affect SB-19 verdict display at cold launch.
