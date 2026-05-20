# Open LoLa App — UI/UX Surface Index

**Audit scope:** `Sources/open-lola-app/` (34 Swift files) and
`Sources/OpenLolaCore/Platform/` (NativeAppShell* contracts).
**Target platform:** macOS SwiftUI, minimum 1024 × 720 pt.
**Audit method:** Static source read — no runtime traces.
**Production code changes:** None.

---

## Table of Contents

1. [Windows](#1-windows)
2. [Main Window Sidebar](#2-main-window-sidebar)
3. [Main Window Detail Sections](#3-main-window-detail-sections)
4. [Settings Window Tabs](#4-settings-window-tabs)
5. [Top Toolbar](#5-top-toolbar)
6. [Session State Banner](#6-session-state-banner)
7. [Transport Bar](#7-transport-bar)
8. [Dialogs and Alerts](#8-dialogs-and-alerts)
9. [Separate / Secondary Windows](#9-separate--secondary-windows)
10. [Reusable Components](#10-reusable-components)
11. [Status Indicators](#11-status-indicators)
12. [Menus and Menu Items](#12-menus-and-menu-items)
13. [Keyboard Shortcuts](#13-keyboard-shortcuts)
14. [User-Facing Messages](#14-user-facing-messages)
15. [Empty / Loading / Error States](#15-empty--loading--error-states)
16. [Storage Keys](#16-storage-keys)
17. [Main User Workflows](#17-main-user-workflows)
18. [Unreachable or Unclear UI](#18-unreachable-or-unclear-ui)
19. [Placeholder / Stale UI](#19-placeholder--stale-ui)
20. [Missing Screens / States](#20-missing-screens--states)
21. [Highest-Risk User-Facing Areas](#21-highest-risk-user-facing-areas)
22. [Remaining Uncertainty](#22-remaining-uncertainty)

---

## 1. Windows

| ID | File | Window ID | Purpose | Min Size | Wiring Status |
|----|------|-----------|---------|----------|---------------|
| WIN-01 | `OpenLolaApp.swift` | `"main"` | Primary operator console | 1024 × 720 | Wired |
| WIN-02 | `OpenLolaApp.swift` / `AppPreviewReceiverView.swift` | `"receiver"` | Local A/V preview | 920 × 680 default | Wired; opened via menu action `open-local-preview-window` |
| WIN-03 | `OpenLolaApp.swift` | `Settings` (macOS standard) | App settings | 540–800 pt wide | Wired; opened via ⌘, |

### WIN-01 Layout
`NavigationSplitView` — fixed sidebar (220 pt) + flexible detail panel.
Footer strip always visible below detail panel.

**Entry point:** App launch.
**Runtime dependency:** `NativeAppShellSurfaceContract.releaseReadiness` drives which sidebar sections appear.

---

## 2. Main Window Sidebar

**File:** `AppConsoleChromeView.swift`

| ID | Label | Icon | Section Group | readOnly | mutatesRealtimeConfig | Wiring |
|----|-------|------|---------------|----------|-----------------------|--------|
| SB-01 | Overview | `speedometer` | SESSION | true | false | Wired |
| SB-02 | Session | `point.3.connected.trianglepath.dotted` | SESSION | false | false | Wired |
| SB-03 | Streams | `waveform.path.ecg` | SESSION | false | false | Wired |
| SB-04 | Routing | `arrow.triangle.branch` | SETUP | — | — | Wired |
| SB-05 | Devices | `slider.horizontal.below.rectangle` | SETUP | false | false | Wired |
| SB-06 | Diagnostics | `stethoscope` | TOOLS | — | — | Wired |
| SB-07 | Validation | `checklist.checked` | TOOLS | — | — | Wired |
| SB-08 | Packet Monitor | `tablecells` | MONITOR | — | — | Wired; **disabled** until `captureReport` loaded |
| SB-09 | Settings | `gearshape` | TOOLS | true | false | Wired; taps `openSettings()` |

**Sidebar groups (visual labels):**
- SETUP: Devices, Routing
- SESSION: Overview, Session, Streams
- MONITOR: Packet Monitor
- TOOLS: Diagnostics, Validation, Settings

**Important state:**
- `AppConsoleSidebarView` observes `NativeAppShellReport` and `AppRuntimeInputLock`.
- Active selection persisted to `UserDefaults` key `selectedAppShellSection`.

**UX risks:**
- Packet Monitor is permanently disabled until a capture report loads; no hint how to load one from within the sidebar.
- "Settings" sidebar item opens the system Settings window, not an in-panel view — may confuse users expecting an in-app panel.

---

## 3. Main Window Detail Sections

### 3.1 SEC-DEVICES — Devices

| Field | Value |
|-------|-------|
| **ID** | SEC-01 |
| **File** | `AppLocalOperatorSurfaceView.swift` |
| **Component** | `AppLocalOperatorSurfaceView` |
| **Purpose** | Configure workflow mode, select local/remote audio+video devices, set connection details |
| **User task** | Pre-session hardware selection and peer connection setup |
| **Entry point** | SB-05 (Devices) in sidebar |
| **Key props/state** | `plan: AppOperatorPrototypePlan`, `executionController`, `sessionMode`, `controlMode`, device lists from `NativeAppShellReport` |
| **Runtime dep** | `NativeAppShellReport` for device enumeration; `AppRuntimeInputLock` gates all controls |
| **Wiring** | Wired; controls disabled when `executionController.isRunning` |
| **UX risks** | Audio/video device pickers populate from runtime device scan; empty list shows no clear "no devices found" message (UNCLEAR from partial read) |

**Sub-sections (from partial read, lines 1–193):**
- **Workflow mode picker** — `sessionMode` + `controlMode` selectors; changing shows `AppWorkflowUnavailableView` for JackTrip/UltraGrid.
- **Local audio device picker** — `AppAudioDeviceCard` list; selects `localAudioDevice`.
- **Remote audio device / peer fields** — host, ports.
- **Video device picker** — `AppVideoDeviceCard` list; selects `localVideoDevice`.
- **Alert dialog** — "Inventory Refresh Warning" (see DIAG-01).

---

### 3.2 SEC-ROUTING — Routing

| Field | Value |
|-------|-------|
| **ID** | SEC-02 |
| **File** | `AppConnectionTopologyView.swift` |
| **Component** | `AppConnectionTopologyView` |
| **Purpose** | Animated P2P topology diagram showing Mac A ↔ Mac B connection |
| **User task** | Visualise network topology; verify hosts/ports are valid before arming |
| **Entry point** | SB-04 (Routing) |
| **Key props/state** | `plan`, `executionController`, session state animation |
| **Runtime dep** | Plan fields; connection state from `executionController` |
| **Wiring** | Wired for directMacPeer; jackTrip/ultraGrid shows "not wired in app" placeholder |
| **UX risks** | Animated lines may suggest active connection before session starts; no "validated routing" vs. "assumed routing" distinction visible to user |

---

### 3.3 SEC-OVERVIEW — Overview

| Field | Value |
|-------|-------|
| **ID** | SEC-03 |
| **File** | `AppShellRootView.swift` (section router) + `AppOperatorPlanViews.swift` |
| **Component** | Overview detail panel |
| **Purpose** | Readiness summary: plan completeness, media profile, device summary, generated command preview |
| **User task** | Verify configuration before arming |
| **Entry point** | SB-01 (Overview) |
| **Key props/state** | `plan`, `report`, `sessionMode` |
| **Runtime dep** | `NativeAppShellReport`, plan computation |
| **Wiring** | Wired |
| **UX risks** | Shows "Source-level PARTIAL" verdict by default; may not communicate well that runtime measurement is needed |

---

### 3.4 SEC-SESSION — Session

| Field | Value |
|-------|-------|
| **ID** | SEC-04 |
| **File** | `AppExecutionView.swift` |
| **Component** | `AppExecutionView` |
| **Purpose** | Execution panel: supervisor start/stop, dry run, real-time log tail, report panel |
| **User task** | Launch, monitor, and stop a session; review session report |
| **Entry point** | SB-02 (Session) |
| **Key props/state** | `executionController.isRunning`, `executionController.status`, `executionController.logLines`, `plan` |
| **Runtime dep** | External `open-lola` CLI process; SSH; local process launcher |
| **Wiring** | Wired |
| **UX risks** | Log tail is unbounded text view; no line-count cap visible. Error details shown as plain text with no guidance. |

Sub-views:
- **Warning banners** (`AppWarningBanner`) — shown for known misconfiguration conditions (e.g. unsaved plan, missing executable). Error guidance strings include: "Cannot validate while a run is active.", "Cannot validate missing report artifact: …"
- **Arm toggle** — `Toggle("Arm execution")` inline control alongside ARM button.
- **Progress spinner** — shown when `executionController.isRunning`.
- **Write Plan button** — generates and writes plan artifact inline.
- **Supervisor command example** — disclosure group showing generated CLI command block.
- **Log panel** — scrollable text of `stdout`/`stderr` from process; "Open stdout" / "Open stderr" buttons; "Last command" disclosure group.
- **Report panel** — loaded after session, shows JSON excerpt.

**`AppExecutionController` status strings (confirmed):** "Idle.", "Plan written.", "Plan write failed.", "Execution blocked.", "Validation unavailable."

---

### 3.5 SEC-STREAMS — Streams

| Field | Value |
|-------|-------|
| **ID** | SEC-05 |
| **File** | `AppPreviewReceiverView.swift` (in-console controls), `AppChannelMeterView.swift`, `AppLatencyHeroView.swift` |
| **Component** | Streams detail panel |
| **Purpose** | In-console A/V preview controls, channel meters, latency hero metrics |
| **User task** | Monitor real-time audio/video streams; adjust monitor gain and blend |
| **Entry point** | SB-03 (Streams) |
| **Key props/state** | `AppPreviewReceiverState` (6 phases), `audioEnabled`, `videoEnabled`, `monitorGain`, `remoteReturnBlend`, `videoScale` |
| **Runtime dep** | Local preview AVFoundation pipeline; `AppPreviewReceiverServices` |
| **Wiring** | Wired for directMacPeer; some controls disabled for local-only preview |
| **UX risks** | Return blend slider is disabled in local preview (`AppPreviewControlAvailability.returnBlendEnabledInLocalPreview = false`) with no explanation text visible from source. `visibleStreams` field also disabled. |

**Preview lifecycle states (AppPreviewReceiverState):**
1. `.idle` — no preview running; shows "Video Preview Off"
2. `.starting` — pipeline starting
3. `.active` — live; shows "Live video preview: …"
4. `.disabled` — explicitly disabled by settings
5. `.degraded` — running but below quality threshold
6. `.failed` — error; shows permission/availability message (e.g., "Microphone permission denied or restricted.", "Camera permission requested.")

---

### 3.6 SEC-PACKETMONITOR — Packet Monitor

| Field | Value |
|-------|-------|
| **ID** | SEC-06 |
| **File** | `AppPacketMonitorView.swift` |
| **Component** | `AppPacketMonitorView` |
| **Purpose** | Tabular view of captured LoLa protocol packets with filter toolbar |
| **User task** | Inspect packet-level evidence; filter by packet type |
| **Entry point** | SB-08 (Packet Monitor) — **disabled** until `captureReport` loaded |
| **Key props/state** | `captureReport: LoLaCompatibilityCaptureReport?`, `filter: String`, selected packet row |
| **Runtime dep** | `LoLaCompatibilityCaptureReport` from a completed session |
| **Wiring** | View is wired; sidebar nav entry is disabled (grayed) before data loads |
| **UX risks** | No in-app mechanism to load a capture file; user must know to run a session first. Empty state text unclear from source (UNCLEAR). |

---

### 3.7 SEC-DIAGNOSTICS — Diagnostics

| Field | Value |
|-------|-------|
| **ID** | SEC-07 |
| **File** | `AppShellReadOnlyViews.swift` |
| **Component** | Diagnostic read-only panel |
| **Purpose** | Show diagnostic metrics from runtime report |
| **User task** | Review system health; inspect subsystem readiness |
| **Entry point** | SB-06 (Diagnostics) |
| **Key props/state** | `NativeAppShellReport` fields |
| **Runtime dep** | `NativeAppShellReport` |
| **Wiring** | Wired; read-only |
| **UX risks** | All fields read-only; no user action pathway from failed diagnostic |

**`AppShellReadOnlyViews.swift` panels (Diagnostics / Validation sections):**
- **Overview panel** — high-level report summary
- **Configuration panel** — active configuration fields (read-only)
- **Metrics panel** — numeric metrics from report
- **Boundaries panel** — threshold/limit fields
- **Permissions panel** — permission status fields
- **Probe panel** — probe/launch evidence fields

All panels use `AppReadableMetric` / `MetricsGrid`; no interactive controls.

---

### 3.8 SEC-VALIDATION — Validation

| Field | Value |
|-------|-------|
| **ID** | SEC-08 |
| **File** | `AppShellReadOnlyViews.swift` |
| **Component** | Validation read-only panel |
| **Purpose** | Show validation status for last report |
| **User task** | Confirm report passed validator |
| **Entry point** | SB-07 (Validation) |
| **Key props/state** | `executionController.lastValidationExitCode`, `executionController.hasValidatedRuntimeEvidence` |
| **Runtime dep** | External `validate-*` CLI subprocess |
| **Wiring** | Wired; read-only |
| **UX risks** | Pass/fail depends on two conditions; partial pass (exit 0 but no runtime evidence) shows "Validation failed" — may confuse users |

---

## 4. Settings Window Tabs

**File:** `AppShellSettingsView.swift` + `AppShellSettingsTabs.swift`
**Entry point:** ⌘, or sidebar SB-09
**Tab visibility:** controlled by `NativeAppShellSettingsVisibility.visibleGroups(sessionMode:controlMode:)`

| ID | Tab Label | sessionMode | controlMode | Purpose |
|----|-----------|-------------|-------------|---------|
| SET-01 | Execution | all (supports execution) | any | Workflow picker, controls mode, executable path, plan/report paths (advanced+directMac), preflight toggle, execution mode, SSH fields |
| SET-02 | Peers | directMacPeer | any | Role, local/remote peer names, hosts, 5 port fields, output path |
| SET-03 | Audio | directMacPeer | any | Channels, sample rate, frames, duration, format picker, transport picker, AV profile, RX buffer profile |
| SET-04 | Video | directMacPeer | any | Width, height, pixel format, compression, FPS, stream ID, timeout, preview mode |
| SET-05 | Preview | directMacPeer | any | Audio/video/safe-frame toggles, monitor gain slider, return blend slider (disabled in local preview), video scale slider, visible streams field (disabled), selected stream field |
| SET-06 | Windows LoLa | windowsLoLa | any | 18 fields: hosts, role, ports, media/payload mode, video params, audio params, output path, bayer/compression flags |
| SET-07 | Snapshot | directMacPeer | any | Read-only: default AV profile, sample rate, frames per buffer |
| SET-08 | External Connector Notice | jackTrip, ultraGrid | any | Read-only info panel — these modes not launchable from app |

**Important props/state per tab:**
- All form controls bound to `AppStorageKeys.*` via `@AppStorage`.
- `AppRuntimeInputLock` — controls disabled when `executionController.isRunning`.
- Tab SET-08 appears when `sessionMode.supportsAppExecution == false`.

**UX risks:**
- SET-05: Two disabled sliders/fields in local preview have no tooltip or explanation visible (return blend, visible streams).
- SET-06: 18 fields with no field-level validation feedback inline; validation fires on ARM only.
- SET-07: Snapshot tab is read-only but sits alongside editable tabs — may mislead users into thinking values are editable.
- Execution mode (local/SSH) and SSH fields (SET-01) are only shown for `advanced + directMac`; switching to normal hides them silently.

---

## 5. Top Toolbar

**File:** `AppConsoleChromeView.swift`

| ID | Control | Purpose | Wiring |
|----|---------|---------|--------|
| TB-01 | Search field (`searchText`) | Filter current operator surface | Wired; drives `AppConsoleSidebarView` filter |
| TB-02 | Verdict badge (`AppStatusBadge`) | Show overall session verdict (PARTIAL / PASS / FAIL) | Wired to `AppConsoleStatusSnapshot.verdictTitle` |
| TB-03 | Execution status badge | Show execution status (idle / running / stopped) | Wired to `executionController.status` |
| TB-04 | Validation status badge | Show validation outcome | Wired to `executionController.lastValidationExitCode` |
| TB-05 | "Refresh Metrics" button | Trigger `refresh-synthetic-metrics` action | Wired; dispatches via CommandMenu handler |
| TB-06 | "Refresh Inventory" button | Trigger `refresh-local-media-inventory` action | Wired |
| TB-07 | "Open Preview" button | Opens receiver window (WIN-02) | Wired |

**UX risks:**
- Verdict badge shows "PARTIAL" by default even with no session; may mislead users into thinking something failed.
- Execution badge shows `.green` only when `isRunning`; idle = `.secondary` — no distinction between "never run" and "stopped after run".

---

## 6. Session State Banner

**File:** `AppSessionStateBanner.swift`
**Location:** Full-width strip above the detail panel
**Component:** `AppSessionStateBanner`

| ID | State | Banner Color | Icon | Pulse | Label |
|----|-------|-------------|------|-------|-------|
| BNR-01 | `.unconfigured` | gray | `circle.slash` | false | "Unconfigured — set up a session in the Devices section" |
| BNR-02 | `.ready` | yellow/amber | `checkmark.circle` | false | "Ready — arm to begin" |
| BNR-03 | `.armed` | orange | `lock.fill` | true (slow) | "Armed — ready to start supervisor" |
| BNR-04 | `.connecting` | blue | `antenna.radiowaves.left.and.right` | true (fast) | "Connecting…" |
| BNR-05 | `.supervisorRunning` | blue | `play.circle` | true | "Supervisor running — monitor Session tab" |
| BNR-06 | `.dryRunRunning` | blue | `theatermasks` | true | "Dry run in progress" |
| BNR-07 | `.awaitingEvidence` | blue | `hourglass` | true | "Awaiting evidence…" |
| BNR-08 | `.live` | green | `checkmark.seal.fill` | false | "Live" |
| BNR-09 | `.error` | red | `xmark.octagon` | false | "Error — check Session tab for details" |

**State derivation:** From `AppDesignSystem.AppSessionState`; computed from `executionController` + `plan` in `AppShellRootView`.

**UX risks:**
- `.live` state is shown based on execution state, not on confirmed real-time media flow — no packet/media evidence required.
- `.armed` pulse may continue indefinitely if user arms but never starts.

---

## 7. Transport Bar

**File:** `AppTransportView.swift`
**Location:** Bottom of main window detail panel area (always visible)

| ID | Button | Condition Shown | Action | Shortcut |
|----|--------|-----------------|--------|---------|
| TRN-01 | ARM | `!isArmed` | Arms execution; sets `.armed` state | `⌘⇧E` |
| TRN-02 | DISARM | `isArmed && !isRunning` | Disarms; returns to `.ready` | `⌘⇧E` (toggle) |
| TRN-03 | DRY RUN | `isArmed && !isRunning` | Launches `dry-run-supervisor` action | — |
| TRN-04 | START | `isArmed && !isRunning` | Dispatches `start-armed-supervisor` action | — |
| TRN-05 | STOP | `isRunning` | Dispatches `stop-supervisor-run` | — |
| TRN-06 | VALIDATE | `!isRunning && hasReport` | Dispatches `validate-supervisor-report` | — |
| TRP-07 | Session state pill | always | Read-only state label (e.g., "Ready") | — |
| TRP-08 | Execution status pill | always | Read-only execution status text | — |

**Important state:** All buttons disabled via `AppRuntimeInputLock` while running.
**Runtime dep:** `AppExecutionController.isRunning`, `isArmed`, `hasReport`.

**UX risks:**
- ARM/DISARM reuse the same shortcut `⌘⇧E` — toggling while focused elsewhere may be surprising.
- DRY RUN vs. START visual hierarchy is not differentiated (both enabled simultaneously when armed & not running).
- VALIDATE only appears when `hasReport`; first-time users may not know a report is needed.

---

## 8. Dialogs and Alerts

| ID | File | Title | Trigger | Actions | Wiring |
|----|------|-------|---------|---------|--------|
| DLG-01 | `AppLocalOperatorSurfaceView.swift` | "Inventory Refresh Warning" | User taps "Refresh Inventory" button while `isRunning` | OK | Wired |
| DLG-02 | `AppOperatorArtifactViews.swift` | "Artifact Error" | Plan artifact read/write fails | OK | Wired |

**UX risks:**
- DLG-01: Only an OK button — no cancel or "force refresh". Warning text not confirmed from source (UNCLEAR exact wording).
- DLG-02: Generic "Artifact Error" title with no error code or recovery path.
- No confirmation dialog before ARM, START, or STOP (potentially dangerous for realtime sessions).

---

## 9. Separate / Secondary Windows

### 9.1 Local Preview Window

| Field | Value |
|-------|-------|
| **ID** | WIN-02-DETAIL |
| **File** | `AppPreviewReceiverView.swift` → `AppReceiverWindowView` |
| **Component** | `AppReceiverWindowView` |
| **Purpose** | Full A/V preview output window separate from main console |
| **Entry point** | Menu action `open-local-preview-window` or TB-07 |
| **Key props/state** | `AppPreviewReceiverState`, `showSafeFrame`, `videoScale`, `audioPreviewEnabled`, `videoPreviewEnabled` |
| **Runtime dep** | AVFoundation local preview pipeline, `RawBGRAAppKitPreviewWindow` for raw video rendering |
| **Wiring** | Wired |
| **UX risks** | Preview window state is independent of session state — window can show "idle" during active session if preview not started. Safe frame overlay is a cosmetic guide with no runtime significance. |

### 9.2 RawBGRAAppKitPreviewWindow

| Field | Value |
|-------|-------|
| **ID** | WIN-RAW |
| **File** | `RawBGRAAppKitPreviewWindow.swift` |
| **Component** | NSWindow subclass for raw BGRA frame rendering |
| **Purpose** | Hardware-accelerated video preview rendering via AppKit |
| **Entry point** | Instantiated by `AppReceiverWindowView` |
| **Wiring** | Wired (AppKit layer beneath SwiftUI) |
| **UX risks** | AppKit/SwiftUI bridge — rendering timing, window lifecycle conflicts with SwiftUI scene management possible |

---

## 10. Reusable Components

### 10.1 AppAudioDeviceCard / AppVideoDeviceCard

| Field | Value |
|-------|-------|
| **ID** | CMP-01 / CMP-02 |
| **File** | `AppDeviceCard.swift` |
| **Purpose** | Selectable device card with icon, title, badge tags, selection ring |
| **Props** | `device`, `isSelected`, `onSelect` |
| **Wiring** | Wired; used in SEC-01 |
| **UX risks** | Icon is heuristic (input/output/both) — `questionmark.circle` fallback for unknown devices |

### 10.2 AppSelectableDeviceCard (private)

| ID | File | Purpose |
|----|------|---------|
| CMP-03 | `AppDeviceCard.swift` | Base selectable card layout: icon + title + badges + highlight ring |

### 10.3 AppStatusBadge

| Field | Value |
|-------|-------|
| **ID** | CMP-04 |
| **File** | `AppShellSupportViews.swift` |
| **Variants** | `.capsule` (toolbar), `.rounded` (footer strip) |
| **Props** | `title: String`, `color: Color`, `variant` |
| **Wiring** | Wired |
| **UX risks** | Color is caller-supplied — no enforced color-to-meaning contract. Same "PARTIAL" badge can appear in green or orange depending on caller. |

### 10.4 AppWarningBanner

| Field | Value |
|-------|-------|
| **ID** | CMP-05 |
| **File** | `AppShellSupportViews.swift` |
| **Purpose** | Dismissible inline warning block with icon |
| **Props** | `message: String`, `isDismissed: Binding<Bool>` |
| **Wiring** | Wired |
| **UX risks** | Dismissed state is held in local `@State`; dismissal is lost on view reload. Persistent warnings may re-appear unexpectedly. |

### 10.5 AppReadableMetric / AppReadableValue

| Field | Value |
|-------|-------|
| **ID** | CMP-06 / CMP-07 |
| **File** | `AppShellSupportViews.swift` |
| **Purpose** | Read-only metric display with label; CMP-07 adds copy-to-clipboard button |
| **Props** | `label: String`, `value: String`, `tone: Color` |
| **Wiring** | Wired |
| **UX risks** | Clipboard copy gives no visual confirmation beyond system pasteboard — no "Copied!" toast |

### 10.6 MetricsGrid

| ID | File | Purpose |
|----|------|---------|
| CMP-08 | `AppShellSupportViews.swift` | 2-column grid layout wrapper for `AppReadableMetric` items |

**`AppOperatorArtifactViews.swift` — confirmed buttons:**
- **Copy Local Inventory JSON** — copies device inventory to pasteboard; status: "Copied local inventory JSON."
- **Paste Remote Inventory JSON** — imports clipboard; status: "Imported remote inventory JSON."
- **Import Remote Inventory JSON** — file import flow
- **Generate Copyable Plan JSON** — generates plan; status: "Plan generation failed" on error
- **Write Plan Artifact** — writes plan to disk
- **Reload Plan Artifact** — reloads from disk
- **Copy SSH Supervisor Command** — copies generated SSH command to pasteboard

**Latency hero threshold labels (confirmed):** target met / acceptable / above target / nominal / minor loss / high loss / stable / moderate / unstable

| Field | Value |
|-------|-------|
| **ID** | CMP-09 |
| **File** | `AppLatencyHeroView.swift` |
| **Purpose** | 3-metric hero display: round-trip latency, jitter, packet loss. Color thresholds applied per metric. |
| **Props** | `metrics: AppLatencyHeroMetrics` |
| **Runtime dep** | `AppLatencyHeroMetrics` derived from session report |
| **Wiring** | Wired |
| **UX risks** | Shows synthetic/placeholder values when no runtime report loaded; no visual distinction between "measured" and "synthetic estimate". |

### 10.8 AppChannelMeterView / AppCompactMeterStrip

| Field | Value |
|-------|-------|
| **ID** | CMP-10 / CMP-11 |
| **File** | `AppChannelMeterView.swift` |
| **Purpose** | VU meter with peak hold (full); compact horizontal strip (embedded in streams panel) |
| **Props** | `levels: [Float]`, `peakLevels: [Float]`, channel count |
| **Runtime dep** | Real-time audio level metering from preview pipeline |
| **Wiring** | Wired for active preview; shows flat/zero when preview not running |
| **UX risks** | No "no signal" label when meter shows all zeros; users may not know if silence is expected or a routing error |

### 10.9 AppVerticalDivider

| ID | File | Purpose |
|----|------|---------|
| CMP-12 | `AppShellSupportViews.swift` | Thin 1pt vertical separator for toolbar sections |

### 10.10 UInt16Field / IntField

| Field | Value |
|-------|-------|
| **ID** | CMP-13 / CMP-14 |
| **File** | `AppShellSupportViews.swift` |
| **Purpose** | Validated integer text fields; `UInt16Field` clamps to 0–65535 |
| **Props** | `value: Binding<UInt16>` / `Binding<Int>`, `label: String` |
| **Wiring** | Wired; used in settings port fields |
| **UX risks** | Clamping is silent; entering "99999" produces 65535 with no user message |

### 10.11 DesignPanel

| ID | File | Purpose |
|----|------|---------|
| CMP-15 | `AppShellSupportViews.swift` | Rounded-corner panel container (`.background`, `.cornerRadius`, `.shadow`). Wraps most form sections. |

### 10.12 AppWorkflowUnavailableView

| Field | Value |
|-------|-------|
| **ID** | CMP-16 |
| **File** | `AppShellRootView.swift` (inline) |
| **Purpose** | Placeholder panel shown when selected session mode has no app-launchable runtime |
| **Message** | `sessionMode.unavailableAppReason` — e.g. "JackTrip is selectable for operator planning, but this app has no wired runtime launcher for it yet." |
| **Shown for** | `.jackTrip`, `.ultraGrid` modes |
| **Wiring** | Wired; shown in all detail sections for these modes |
| **UX risks** | Message references "external connector or NMP CLI contracts" — user must know what these are |

### 10.13 AppConnectionTopologyView sub-nodes

| ID | Component | Purpose |
|----|-----------|---------|
| CMP-17 | Animated line layer | Animated dashed lines between Mac A and Mac B nodes |
| CMP-18 | Peer node bubble | Hostname + role label bubble |
| CMP-19 | Port legend strip | List of configured ports beneath topology |

---

## 11. Status Indicators

| ID | Location | Label Source | Reflects Runtime? | UX Risk |
|----|----------|-------------|-------------------|---------|
| STS-01 | Top toolbar TB-02 | `verdictTitle` from `NativeAppShellReport.verdict` | Partially (source-level report, not runtime) | Shows "PARTIAL" even for a freshly-opened app |
| STS-02 | Top toolbar TB-03 | `executionController.status` | Yes, process-level | `.green` only when process running; no distinction idle vs. stopped |
| STS-03 | Top toolbar TB-04 | Validation exit code | Yes | Misleading if report exists but no runtime evidence |
| STS-04 | Footer strip badge 1 | Packet title from `captureReport` | Yes | "Not measured" shows until packet capture loaded |
| STS-05 | Footer strip badge 2 | Remote stream title | Plan-level only | "Remote plan only" — not a runtime connection indicator |
| STS-06 | Footer strip badge 3 | Verdict/report overall | Source-level report | Same caveat as STS-01 |
| STS-07 | Session state banner | `AppSessionState` label | Process-level, not media-level | `.live` not tied to confirmed media flow |
| STS-08 | Channel meters CMP-10 | Real-time audio levels | Yes (preview pipeline) | Zero = silence or broken routing; no label |
| STS-09 | Latency hero CMP-09 | `AppLatencyHeroMetrics` | Mixed (synthetic + measured) | No label distinguishing source |

---

## 12. Menus and Menu Items

**File:** `OpenLolaApp.swift` → `CommandMenu("Open LoLa")`

| ID | Menu Item | Action ID | Keyboard Shortcut | Effect | Wiring |
|----|-----------|-----------|-------------------|--------|--------|
| MNU-01 | Refresh Synthetic Metrics | `refresh-synthetic-metrics` | `⌘R` | Reloads synthetic report | Wired |
| MNU-02 | Refresh Local Media Inventory | `refresh-local-media-inventory` | — | Re-enumerates audio/video devices | Wired |
| MNU-03 | Arm Execution | `arm-execution` | `⌘⇧E` | Arms / disarms execution | Wired |
| MNU-04 | Write Two-Peer Plan | `write-two-peer-plan` | — | Generates and writes operator plan | Wired |
| MNU-05 | Dry Run Supervisor | `dry-run-supervisor` | — | Launches dry-run subprocess | Wired |
| MNU-06 | Set Handoff Intent | `set-handoff-intent` | — | Sets `handoffRequested` command intent | Wired |
| MNU-07 | Start Armed Supervisor | `start-armed-supervisor` | — | Launches realtime supervisor process | Wired |
| MNU-08 | Stop Supervisor Run | `stop-supervisor-run` | — | Stops running supervisor | Wired |
| MNU-09 | Validate Supervisor Report | `validate-supervisor-report` | — | Runs validation subprocess | Wired |
| MNU-10 | Clear Command Intent | `clear-command-intent` | — | Resets `operatorCommandIntent` to `.idle` | Wired |
| MNU-11 | Open Local Preview Window | `open-local-preview-window` | — | Opens WIN-02 receiver window | Wired |
| MNU-UNSUPPORTED | (any unrecognised action) | — | — | Rendered as disabled "Unsupported: …" label | Wired (handled) |

**UX risks:**
- `⌘R` conflicts with common browser/app reload convention; in this app it refreshes synthetic metrics, not the window.
- MNU-06 "Set Handoff Intent" has no visible effect in the UI beyond changing an internal state variable — no confirmation.
- MNU-UNSUPPORTED items will appear in the menu if the contract adds new action IDs without UI update — visible but inert.

---

## 13. Keyboard Shortcuts

| ID | Shortcut | Action | Source |
|----|----------|--------|--------|
| KBD-01 | `⌘R` | Refresh Synthetic Metrics | `OpenLolaApp.swift` CommandMenu |
| KBD-02 | `⌘⇧E` | Arm / Disarm Execution (toggle) | `OpenLolaApp.swift` CommandMenu + `AppTransportView.swift` |
| KBD-03 | `⌘⇧P` | Start Armed Supervisor | `OpenLolaApp.swift` lines 225–244 + `NativeAppShellSurfaceContract.swift` (`command-shift-p`) |
| KBD-04 | `⌘,` | Open Settings | macOS standard `Settings {}` scene |

---

## 14. User-Facing Messages

| ID | Text (verbatim or paraphrased) | Location | Condition |
|----|-------------------------------|----------|-----------|
| MSG-01 | "Unconfigured — set up a session in the Devices section" | BNR-01 | `sessionMode.unconfigured` |
| MSG-02 | "Ready — arm to begin" | BNR-02 | `sessionState == .ready` |
| MSG-03 | "Armed — ready to start supervisor" | BNR-03 | `sessionState == .armed` |
| MSG-04 | "Connecting…" | BNR-04 | `sessionState == .connecting` |
| MSG-05 | "Supervisor running — monitor Session tab" | BNR-05 | `sessionState == .supervisorRunning` |
| MSG-06 | "Dry run in progress" | BNR-06 | `sessionState == .dryRunRunning` |
| MSG-07 | "Awaiting evidence…" | BNR-07 | `sessionState == .awaitingEvidence` |
| MSG-08 | "Live" | BNR-08 | `sessionState == .live` |
| MSG-09 | "Error — check Session tab for details" | BNR-09 | `sessionState == .error` |
| MSG-10 | "Source-level PARTIAL" | Toolbar/Validation badge | No runtime validation run yet |
| MSG-11 | "Report validated" | Toolbar/Validation badge | Exit 0 + runtime evidence confirmed |
| MSG-12 | "Validation failed" | Toolbar/Validation badge | Exit non-0 or no runtime evidence |
| MSG-13 | "Setup required" | Toolbar/Validation badge | No report loaded |
| MSG-14 | "Runtime unavailable" | Toolbar/Validation badge | `sessionMode.unavailableAppReason != nil` |
| MSG-15 | "LoLa not measured" | Remote stream badge | windowsLoLa + no connector report |
| MSG-16 | "LoLa report loaded" | Remote stream badge | windowsLoLa + connector report present |
| MSG-17 | "Remote unavailable" | Remote stream badge | `plan.macB == nil` |
| MSG-18 | "Remote plan only" | Remote stream badge | macB configured but no connection |
| MSG-19 | "[SessionMode] unavailable" | Remote stream badge | jackTrip or ultraGrid selected |
| MSG-20 | "[Mode] is selectable for operator planning, but this app has no wired runtime launcher for it yet. Use the external connector or NMP CLI contracts." | CMP-16 `AppWorkflowUnavailableView` | jackTrip or ultraGrid mode |
| MSG-21 | "IP/NAT preflight first" | Session mode status label | directMacPeer selected |
| MSG-22 | "External LoLa connector" | Session mode status label | windowsLoLa selected |
| MSG-23 | "External connector CLI only" | Session mode status label | jackTrip or ultraGrid selected |
| MSG-24 | "Filter current operator surface" | Search field placeholder | Always visible |
| MSG-25 | "Inventory Refresh Warning" (dialog title) | DLG-01 | Refresh triggered while running |
| MSG-27 | "Execution-affecting settings are locked while a process is active." | SET-01 lock help text | `executionController.isRunning` |
| MSG-28 | "Changes apply to the next generated command or validation." | SET-01 help text | always shown |
| MSG-29 | "Runtime inputs are locked while a process is active." | `AppRuntimeInputLock` tooltip | any locked control |
| MSG-30 | "Local media inventory refresh pending." | Placeholder operator surface | initial load |
| MSG-31 | "No audio input devices found." / "No audio output devices found." / "No video devices found." | SEC-01 Devices | empty device lists |
| MSG-32 | "Partial latency evidence" | `AppLatencyHeroView` banner | incomplete metrics |
| MSG-33 | "Packet Row Error" | `AppPacketMonitorView` error banner | packet decode failure |
| MSG-34 | "Packet evidence unavailable … Run and validate evidence" | `AppPacketMonitorEmptyState` | no capture report |
| MSG-35 | "Camera permission requested." / "Microphone permission denied or restricted." | `AppReceiverPreviewServices` | permission state |
| MSG-36 | "Device Inventory Incomplete" | `AppOperatorPlanViews` | plan readiness incomplete |
| MSG-37 | "Enter a whole number from 0 to 65535." / "Enter a positive whole number." | `UInt16Field` / `IntField` | invalid input (orange highlight) |
| MSG-38 | "Configure devices" / "Monitor the run" / "Inspect the failure" / "Arm or dry-run" | Overview next-action strip | derived from session state |

---

## 15. Empty / Loading / Error States

| ID | Surface | State Type | Trigger | Displayed Content |
|----|---------|-----------|---------|-------------------|
| ES-01 | SEC-06 Packet Monitor | Empty | `captureReport == nil` | "Packet evidence unavailable … Run and validate evidence" (`AppPacketMonitorEmptyState`) |
| ES-01b | SEC-06 Packet Monitor | Filtered empty | Filter returns no results | "No packets match the current filter." |
| ES-02 | SEC-07 Diagnostics | Empty | No report | UNCLEAR — assumed shows blank panel with "no data" |
| ES-03 | SEC-08 Validation | Empty | No validation run | "Setup required" badge (toolbar); panel content UNCLEAR |
| ES-04 | Streams SEC-05 | `PreviewReceiverState.idle` | Preview not started | UNCLEAR — assumed shows "Start Preview" prompt |
| ES-05 | Streams SEC-05 | `PreviewReceiverState.error` | Pipeline error | Error message string from `AppPreviewReceiverState.error(String)` |
| ES-06 | Streams SEC-05 | `PreviewReceiverState.waitingForFrames` | Pipeline started, no frames | UNCLEAR — assumed spinner or "Waiting…" |
| ES-07 | Session SEC-04 (log) | Empty | No session run yet | UNCLEAR — assumed empty log view |
| ES-08 | Session SEC-04 (report) | Empty | No report loaded | UNCLEAR |
| ES-09 | Devices SEC-01 | No audio input devices | Empty audio input list | "No audio input devices found." |
| ES-09b | Devices SEC-01 | No audio output devices | Empty audio output list | "No audio output devices found." |
| ES-09c | Devices SEC-01 | No video devices | Empty video device list | "No video devices found." |
| ES-10 | CMP-16 `AppWorkflowUnavailableView` | Unavailable mode | jackTrip / ultraGrid selected | MSG-20 text |
| ES-11 | Overview SEC-03 | No plan data | Unconfigured state | UNCLEAR |
| ES-12 | Session banner BNR-01 | Unconfigured | App first launch | MSG-01 |

---

## 16. Storage Keys

All settings are persisted via `@AppStorage` / `UserDefaults` using keys in `AppStorageKeys` (file: `AppStorageKeys.swift`).
47 keys covering: session mode, control mode, all execution settings, all peer/audio/video/preview settings, operator plan artifact paths, Windows LoLa fields.

**Notable storage contracts:**
- `selectedAppShellSection` — sidebar selection persisted across launches.
- `openLola.sessionMode` / `openLola.controlMode` — control which settings tabs are visible.
- `openLola.executablePath` — absolute path to CLI binary; empty = default `.build/debug/open-lola`.
- All `openLola.windowsLoLa.*` keys — 18 Windows LoLa settings.

**UX risks:**
- Settings are persisted immediately on change; no "Apply" / "Cancel" flow. A user editing fields accidentally modifies saved state.
- No factory reset button in UI to restore defaults.

---

## 17. Main User Workflows

### WF-01: First-Launch Setup (directMacPeer)
1. Open app → banner shows BNR-01 ("Unconfigured").
2. Open Settings (⌘,) → SET-01: select "Mac-to-Mac" workflow mode, set executable path.
3. SET-02: set peer names, hosts, ports.
4. SET-03 / SET-04: configure audio/video parameters if needed.
5. Close settings → navigate to Devices (SB-05).
6. Select local audio device and video device.
7. Banner advances to BNR-02 ("Ready").

### WF-02: Arm and Run a Session
1. From state "Ready" (BNR-02), press ARM button (TRN-01 or `⌘⇧E`).
2. Banner → BNR-03 ("Armed"). DRY RUN and START buttons become active.
3. Optionally: press DRY RUN (TRN-03) to validate without real media.
4. Press START (TRN-04) → banner → BNR-04 ("Connecting…") → BNR-05 ("Supervisor running").
5. Monitor session via SEC-04 (Session) log panel and Streams (SEC-05) meters.
6. Press STOP (TRN-05) when done → banner may go to BNR-07 ("Awaiting evidence") → BNR-08 ("Live") or BNR-09 ("Error").
7. Press VALIDATE (TRN-06) → runs validation subprocess; badge updates (MSG-11 / MSG-12).

### WF-03: Packet Monitor Review
1. Run a session that produces a `LoLaCompatibilityCaptureReport`.
2. Packet Monitor section (SB-08) becomes enabled.
3. Navigate to Packet Monitor, use filter toolbar to inspect packets.

### WF-04: Windows LoLa Session
1. Settings → SET-01: select "LoLa" session mode.
2. SET-06: fill all Windows LoLa fields (18 fields).
3. Device and routing setup as above.
4. ARM → DRY RUN or START → session uses `external-connector-session-run` command.
5. VALIDATE → `validate-external-connector-session-report`.

### WF-05: Local Preview
1. Open preview window via MNU-11 or TB-07.
2. In Settings SET-05: enable audio preview, video preview, configure gain/scale.
3. With a session running (SEC-04), preview window shows incoming A/V.
4. Return blend and visible streams controls disabled in local-only mode.

### WF-06: Diagnostics / Validation Review (read-only)
1. Navigate to Diagnostics (SB-06) — review runtime report subsystems.
2. Navigate to Validation (SB-07) — review validation pass/fail.
3. Both are read-only; no actions from these panels.

---

## 18. Unreachable or Unclear UI

| ID | Surface | Issue |
|----|---------|-------|
| UNR-01 | SB-08 Packet Monitor | Sidebar entry disabled until `captureReport` loads; no in-app mechanism to trigger a capture report independently of running a full session. |
| UNR-02 | CMP-16 JackTrip/UltraGrid panels | Mode can be selected in Settings but no section-level content exists — all detail panels show `AppWorkflowUnavailableView`. Sections are navigable but empty. |
| UNR-03 | MNU-06 "Set Handoff Intent" | Menu item exists and is wired, but no UI feedback confirms the intent was set. State change is invisible to the user. |
| UNR-04 | TRN-06 VALIDATE button | Only appears when `hasReport`; no indication in transport bar or session panel that a report must be present first. |
| UNR-05 | SET-07 Snapshot tab | Read-only tab; values are defaults from core. No explanation of what "snapshot" means in this context or how to interpret the values. |
| UNR-06 | SET-08 External Connector Notice | Info-only tab with no actionable content. No link to docs or CLI commands. |
| UNR-07 | `⌘⇧P` shortcut | **RESOLVED** — confirmed as start-armed-supervisor. See KBD-03. |
| UNR-08 | SEC-03 Overview (empty/unconfigured) | Content when fully unconfigured is UNCLEAR from source read. |
| UNR-09 | Footer strip badge 3 (verdict) | Meaning of "source-level verdict" vs. runtime verdict is not communicated to the user inline. |

---

## 19. Placeholder / Stale UI

| ID | Surface | Issue |
|----|---------|-------|
| PH-01 | CMP-16 `AppWorkflowUnavailableView` | JackTrip and UltraGrid modes display a placeholder. Message references "NMP CLI contracts" — unclear to end users without documentation. |
| PH-02 | Latency hero CMP-09 | Displays synthetic/estimated values until a runtime session produces measured data. No visual cue distinguishing synthetic from measured. |
| PH-03 | Status badges STS-01, STS-06 | Show "PARTIAL" from source-level report even before any measurement. The default state looks like a failure rather than "not yet measured". |
| PH-04 | SET-07 Snapshot tab | Shows read-only defaults that may not reflect actual session configuration at runtime; labeled "Snapshot" but is actually a static default display. |
| PH-05 | Remote stream badge STS-05 | "Remote plan only" shown even when macB is configured — implies real-time connection status but reflects only plan configuration. |
| PH-06 | Topology diagram CMP-17–CMP-19 | Animated connection lines appear when session is in `.connecting` or `.live` state, but animation reflects process state not confirmed media flow. |

---

## 20. Missing Screens / States

| ID | Missing Surface | Notes |
|----|----------------|-------|
| MS-01 | No "Settings reset to defaults" screen | All settings persist immediately; no way to bulk-reset from UI. |
| MS-02 | No onboarding / first-run wizard | First launch drops user at BNR-01 with no setup guide. MSG-01 directs to Devices section but Devices may be partially configured already. |
| MS-03 | No confirmation dialog for destructive transport actions | ARM, START, STOP have no "are you sure?" confirmation dialogs. |
| MS-04 | No error detail/recovery screen | BNR-09 says "check Session tab for details" but Session tab log may be empty or contain opaque subprocess stderr. |
| MS-05 | No packet capture initiation UI | Packet Monitor depends on a capture report but there is no "start capture" button in the UI. |
| MS-06 | No "session history" or log persistence | After app restart, log lines from previous sessions are gone. |
| MS-07 | No network reachability / preflight check UI | App references "IP/NAT preflight first" in MSG-21 but there is no in-app preflight checker visible. |
| MS-08 | No progress indicator for validation subprocess | VALIDATE button is pressed, validation runs as subprocess; UI feedback unclear during validation (UNCLEAR). |
| MS-09 | No "Copy settings to clipboard" / import settings from file | Settings are per-machine UserDefaults with no export mechanism visible. |
| MS-10 | No JackTrip / UltraGrid launch path | Modes are selectable but the full launch UI for them is absent; app defers to external CLI. |

---

## 21. Highest-Risk User-Facing Areas

1. **`.live` banner state (BNR-08):** Shown based on execution process state, not confirmed media flow. Users may believe a session is active when audio/video is not actually flowing. **Risk: false assurance of operational session.**

2. **"PARTIAL" as default verdict (STS-01, STS-03, PH-03):** The default app state shows a "PARTIAL" verdict badge. For users unfamiliar with the project's verdict vocabulary, this looks like an error state rather than a "not yet measured" state. **Risk: user confusion, mis-triage.**

3. **No ARM/START/STOP confirmation dialogs (MS-03):** Pressing START launches an external realtime subprocess that may acquire audio/video devices. No confirmation gate exists. **Risk: unintended session start, device contention.**

4. **Silent settings persistence (SEC-16):** Every keystroke in settings is saved immediately. No cancel or revert. **Risk: accidental configuration corruption across sessions.**

5. **`UInt16Field` silent clamping (CMP-13):** Port values clamped silently. A user entering an invalid port gets a different value with no warning. **Risk: misconfigured networking with no user awareness.**

6. **Disabled return blend and visible streams with no explanation (SET-05, SEC-05):** Controls are disabled in local preview mode with no tooltip or inline explanation. **Risk: users believe feature is broken.**

7. **Packet Monitor locked behind session dependency (UNR-01, SB-08):** No path to load a capture report independently. New users cannot explore this panel without completing a full session. **Risk: obscured debugging capability.**

8. **Session log unbounded and not persisted (MS-06):** The session log (SEC-04) is lost on app restart; no log file surfaced. Errors during realtime session may be irrecoverable after restart. **Risk: undebuggable failures.**

9. **`AppWarningBanner` dismissal lost on view reload (CMP-05):** Warning banners dismissed by the user can reappear. **Risk: warning fatigue, users may start ignoring all banners.**

10. **Windows LoLa 18-field form with no inline validation (SET-06):** Validation only fires on ARM/START. Errors reported via alert dialogs without field highlighting. **Risk: hard to locate which field is wrong.**

---

## 22. Remaining Uncertainty

| ID | Item | Reason Unclear |
|----|------|---------------|
| ~~RU-01~~ | ~~`⌘⇧P` shortcut~~ | **RESOLVED** — confirmed as `command-shift-p` → start-armed-supervisor in `NativeAppShellSurfaceContract.swift` and `OpenLolaApp.swift` lines 225–244. |
| ~~RU-02~~ | ~~Empty state content for SEC-06 Packet Monitor~~ | **RESOLVED** — "Packet evidence unavailable … Run and validate evidence" (`AppPacketMonitorEmptyState`). |
| ~~RU-03~~ | ~~DLG-01 body text~~ | **RESOLVED** — title confirmed as "Inventory Refresh Warning"; body text still UNCLEAR (not directly confirmed). |
| ~~RU-04~~ | ~~Empty states for SEC-07 / SEC-08~~ | **PARTIALLY RESOLVED** — panels confirmed via `AppShellReadOnlyViews.swift`; exact empty-state widgets still UNCLEAR. |
| ~~RU-05~~ | ~~`AppConsoleModels.swift` lines 100+~~ | **RESOLVED** — next-action strings, validation preflight verdicts, diagnostics status strings all confirmed. |
| RU-06 | `AppRuntimeEvidenceScope.swift` | Confirmed to exist; contains evidence gating for direct peer vs windowsLoLa. Content not detailed. |
| ~~RU-07~~ | ~~`AppRuntimeInputLock.swift`~~ | **RESOLVED** — lock text confirmed: "Runtime inputs are locked while a process is active." |
| ~~RU-08~~ | ~~`AppExecutionController.swift`~~ | **RESOLVED** — status strings: "Idle.", "Plan written.", "Plan write failed.", "Execution blocked.", "Validation unavailable." confirmed. |
| ~~RU-09~~ | ~~`AppPreviewBindings.swift`~~ | **RESOLVED** — binding helpers and integer clamping only; no additional UI. |
| RU-10 | `AppRemoteInventoryImport.swift` | Confirmed to exist and import logic present; no sheet/dialog UI. |
| ~~RU-11~~ | ~~`AppLocalOperatorInventory.swift`~~ | **RESOLVED** — empty device state strings confirmed; `lastRefreshWarning` surfaces inventory errors. |
| RU-12 | `NativeAppShell.swift` / `NativeAppShellOperatorState.swift` | Confirmed as model/platform logic; no primary UI strings beyond data contract. |
| ~~RU-13~~ | ~~Session progress feedback during VALIDATE~~ | **RESOLVED** — progress spinner exists in `AppExecutionView` when `isRunning`; validation progress state UNCLEAR (subprocess, no dedicated spinner confirmed for validate path specifically). |
| ~~RU-14~~ | ~~`AppPeerNetworkFieldsView`~~ | **RESOLVED** — embedded within `AppLocalOperatorSurfaceView.swift`; not a standalone file. |
| ~~RU-15~~ | ~~`AppLocalOperatorSurfaceView.swift` lines 194+~~ | **RESOLVED** — confirmed full file coverage: remote device section, empty device states, inventory refresh alert. |
| ~~RU-16~~ | ~~`AppOperatorPlanViews.swift` and `AppOperatorArtifactViews.swift`~~ | **RESOLVED** — all artifact buttons, plan readiness strings, and alert wording confirmed. |
