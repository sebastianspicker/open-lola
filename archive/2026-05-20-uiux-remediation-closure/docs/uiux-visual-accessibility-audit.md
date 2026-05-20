# UI/UX Visual And Accessibility Audit

Date: 2026-05-20

Scope: static audit of the macOS SwiftUI app surfaces under `Sources/open-lola-app/` plus relevant UI tests under `Tests/OpenLolaCoreTests/`. This audit did not redesign UI and did not inspect production behavior through fresh screenshots, VoiceOver, Accessibility Inspector, or a live app run. Any path that requires runtime confirmation is marked as manual verification needed.

## Evidence Summary

Observed safeguards:

- `AppDesignSystem` defines dynamic light/dark/high-contrast color roles and exposes contrast-ratio helpers for several critical foreground/background pairs (`Sources/open-lola-app/AppDesignSystem.swift`).
- `AppShellBehaviorTests` asserts secondary text and light-mode warning/state color contrast against the app background (`Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift`).
- Several icon-only toolbar actions have explicit accessibility labels (`Sources/open-lola-app/AppConsoleChromeView.swift`).
- The session banner posts accessibility announcements for error and receiver-warning states and honors reduce-motion for its pulse animation (`Sources/open-lola-app/AppSessionStateBanner.swift`).
- The audio meter canvas exposes an accessibility label/value and honors reduce-motion for peak decay (`Sources/open-lola-app/AppChannelMeterView.swift`).

Known limits of this audit:

- No screenshot evidence was generated in this pass, so contrast, clipping, focus rings, and layout scaling were evaluated from code and tests only.
- No Accessibility Inspector or VoiceOver tree was captured.
- Runtime-only preview, device, packet, and log contents can vary widely; long-string findings are based on component structure and likely real values such as paths, device UIDs, hosts, commands, and packet payloads.

## Findings

### VA-001

- ID: VA-001
- Severity: P2
- File/component: `Sources/open-lola-app/AppShellSupportViews.swift` / `AppReadableValue`
- Evidence: `AppReadableValue` renders the value inside a horizontal `ScrollView`, sets `.lineLimit(1)` and `.fixedSize(horizontal: true, vertical: false)`, and constrains the scroll view with `.frame(minWidth: 120, maxWidth: .infinity)` (`AppShellSupportViews.swift:152-162`). It is used for paths, UIDs, device identifiers, preview states, reports, stdout/stderr paths, and packet-monitor expected paths across multiple app views.
- User impact: Long values can require horizontal scrolling in dense panels. Operators may miss the meaningful end of a path, UID, host, or report location unless they notice the hidden scroll behavior or hover for help.
- Accessibility impact: The combined accessibility label includes the full value (`AppShellSupportViews.swift:176-177`), so screen readers may receive more complete information than sighted keyboard or low-vision users. The visible recovery path relies on selection, copy, or tooltip behavior.
- Suggested remediation: Add an explicit full-value affordance for long operational values, such as middle truncation plus copy/open, a disclosure row, or wrapping in panels where vertical growth is safer than horizontal scrolling.
- Manual or automated verification: Run the app at the 1024x720 minimum window with long report paths, long audio UIDs, and long video device identifiers; verify no important value is hidden without an obvious affordance. Add a snapshot or view-level test fixture with long values if the app test harness supports it.
- Confidence: high

### VA-002

- ID: VA-002
- Severity: P2
- File/component: `Sources/open-lola-app/AppExecutionView.swift` and `Sources/open-lola-app/AppOperatorPlanViews.swift` / command preview and generated command displays
- Evidence: The execution command preview uses a two-axis `ScrollView`, `.lineLimit(nil)`, and `.fixedSize(horizontal: true, vertical: true)` inside a 96-180 point high frame (`AppExecutionView.swift:150-158`). Generated operator commands render shell lines with `.lineLimit(nil)` but no visible wrapping constraints or max-height protection in the disclosure body (`AppOperatorPlanViews.swift:275-298`).
- User impact: Generated commands are core handoff artifacts. Long shell lines can expand horizontally, require scrolling, or consume large vertical space, which makes command review and copy verification harder.
- Accessibility impact: Long monospaced command text may be difficult to navigate with keyboard or assistive tech if focus lands inside nested scroll/disclosure content without a clear structured summary.
- Suggested remediation: Preserve copyability while adding predictable wrapping/truncation behavior, command token grouping, or an explicit expanded command detail area with stable dimensions.
- Manual or automated verification: Open generated commands with long executable paths and peer paths; verify visible review, keyboard scrolling, copy button access, and focus order.
- Confidence: high

### VA-003

- ID: VA-003
- Severity: P2
- File/component: `Sources/open-lola-app/AppPacketMonitorView.swift` / decoded packet table
- Evidence: Packet table cells render as caption-size monospaced text, cap content to two lines, and use middle truncation (`AppPacketMonitorView.swift:196-203`). Packet rows include source, destination, payload, candidate, and stream fields (`AppPacketMonitorView.swift:145-177`).
- User impact: Packet payloads and addresses are diagnostic content. Middle truncation helps preserve starts/ends but can hide the exact bytes or labels needed to compare captures.
- Accessibility impact: The table has an accessibility label and rows can be copied (`AppPacketMonitorView.swift:165-177`), but the visually available table can still under-communicate details for low-vision users or keyboard-only users who do not discover per-cell help.
- Suggested remediation: Add an explicit packet-detail disclosure or selected-row detail pane that exposes full values without relying on tooltip/copy.
- Manual or automated verification: Load a capture fixture with long payload/candidate strings and verify the full packet row is reachable with keyboard, screen reader, and visual inspection.
- Confidence: high

### VA-004

- ID: VA-004
- Severity: P2
- File/component: `Sources/open-lola-app/AppDeviceCard.swift` and `Sources/open-lola-app/AppConnectionTopologyView.swift` / device cards and topology peer nodes
- Evidence: Device identifiers are caption2 monospaced text with `.lineLimit(1)`, tail truncation, and `maxWidth: 220` (`AppDeviceCard.swift:126-132`). Topology peer labels and hosts are fixed-width, single-line text with tail/middle truncation (`AppConnectionTopologyView.swift:78-91`).
- User impact: Long device IDs and host names can become ambiguous in selection cards and topology views, especially when multiple devices share similar prefixes or suffixes.
- Accessibility impact: Device cards combine children and expose selected state (`AppDeviceCard.swift:155-159`), but the visible truncated identifier can still be ambiguous for sighted users. Host help exists for pointer users (`AppConnectionTopologyView.swift:89`).
- Suggested remediation: Use middle truncation for device identifiers, expose a secondary full-ID row or copy affordance, and verify host/device disambiguation with real hardware labels.
- Manual or automated verification: Test with long Core Audio UIDs, Blackmagic/AVFoundation device IDs, and IPv6/hostname inputs.
- Confidence: high

### VA-005

- ID: VA-005
- Severity: P2
- File/component: `Sources/open-lola-app/AppShellSupportViews.swift`, `Sources/open-lola-app/AppPacketMonitorView.swift`, `Sources/open-lola-app/AppSessionStateBanner.swift`, `Sources/open-lola-app/AppOperatorPlanViews.swift` / plain icon and compact action buttons
- Evidence: Transport buttons have an explicit 44x44 hit target helper (`AppTransportView.swift:341-345`), but several other compact controls use `.buttonStyle(.plain)` without an explicit minimum hit target: readable metric copy (`AppShellSupportViews.swift:164-173`), warning dismiss (`AppShellSupportViews.swift:264-273`), packet row copy (`AppPacketMonitorView.swift:165-173`), session banner CTAs (`AppSessionStateBanner.swift:193-204`), and generated command copy actions (`AppOperatorPlanViews.swift:267-293`).
- User impact: Copy and dismiss actions can be harder to click accurately in dense operator panels.
- Accessibility impact: Some icon-only buttons do have accessibility labels, but small hit targets still create motor-accessibility and keyboard focus visibility risk.
- Suggested remediation: Apply a shared compact-control minimum size and visible focus style to plain icon buttons, matching the transport hit-target discipline where appropriate.
- Manual or automated verification: Use Accessibility Inspector hit testing and keyboard traversal for copy/dismiss controls; verify a minimum target size equivalent to 44x44 where practical.
- Confidence: high

### VA-006

- ID: VA-006
- Severity: P2
- File/component: `Sources/open-lola-app/AppShellSettingsView.swift`, `Sources/open-lola-app/AppShellSettingsTabs.swift`, `Sources/open-lola-app/AppPreviewReceiverView.swift` / disabled settings and preview controls
- Evidence: Settings tabs are disabled when execution settings are locked and expose the reason via `.help(executionSettingsHelp)` (`AppShellSettingsView.swift:67-119`). Preview controls for return blend, visible streams, and selected stream are disabled and explain unsupported local preview behavior through `.help(...)` (`AppShellSettingsTabs.swift:290-303`; `AppPreviewReceiverView.swift:196-213` from search evidence). Tests assert help strings exist for locked/unsupported states (`AppShellSlice05Tests.swift:82-99`).
- User impact: Users can see controls that cannot be changed, but the reason may be hidden unless they hover or use a screen-reader path that surfaces help.
- Accessibility impact: Disabled controls can be skipped or announced without enough contextual recovery depending on platform behavior. Relying on `.help` alone may not provide an always-visible explanation.
- Suggested remediation: Keep disabled controls truthful, but add nearby persistent reason text for locked settings and unsupported preview controls.
- Manual or automated verification: Run keyboard-only and VoiceOver passes through locked settings and disabled preview controls; confirm the reason and recovery path are announced without pointer hover.
- Confidence: high

### VA-007

- ID: VA-007
- Severity: P2
- File/component: `Sources/open-lola-app/AppTransportView.swift` compared with other controls / focus states
- Evidence: Transport controls define a `@FocusState`, custom focus ring overlays, keyboard shortcut for Arm, and 44x44 hit targets (`AppTransportView.swift:13-15`, `48-207`, `341-345`). The audited source did not show equivalent custom focus treatment for sidebar rows, top bar icon buttons, packet table copy buttons, device cards, or warning dismiss controls.
- User impact: Keyboard users may get a clear focus model in the transport strip but less predictable focus visibility in other dense panels.
- Accessibility impact: Inconsistent focus indication can make navigation order and current position unclear, especially when plain buttons and tables are mixed.
- Suggested remediation: Define a consistent focus-visible policy for dense operator controls and verify whether default macOS focus rings are sufficient before adding custom styling.
- Manual or automated verification: Keyboard-tab through sidebar, top bar, packet monitor, device cards, warning banners, settings, and dialogs in light/dark/high-contrast modes; capture screenshots of each focused state.
- Confidence: medium

### VA-008

- ID: VA-008
- Severity: P2
- File/component: `Sources/open-lola-app/AppConsoleChromeView.swift`, `Sources/open-lola-app/AppShellSupportViews.swift`, `Sources/open-lola-app/AppLatencyHeroView.swift`, `Sources/open-lola-app/AppChannelMeterView.swift` / color and opacity cues
- Evidence: Sidebar section headers use a 6 point colored circle for session state (`AppConsoleChromeView.swift:82-89`). Dimmed sidebar rows use `.opacity(0.5)` (`AppConsoleChromeView.swift:101-107`). Status badges use colored foreground and low-opacity colored backgrounds (`AppShellSupportViews.swift:192-209`). Latency metrics include colored status circles plus text (`AppLatencyHeroView.swift:89-97`). Audio meters use green/yellow/red zones in a canvas (`AppChannelMeterView.swift:95-114`).
- User impact: Most major status areas include text labels, but dimming and small colored indicators can still be hard to interpret quickly or under color-vision differences.
- Accessibility impact: Assistive labels exist for several status elements, but color and opacity remain part of the visual hierarchy. The meter canvas exposes aggregate level data, not the per-channel visual detail.
- Suggested remediation: Pair every color/opacity-only cue with persistent text, icon shape, or explicit state wording. For meters, consider exposing per-channel details only if users need channel-level diagnostics from assistive tech.
- Manual or automated verification: Check color-blind simulation, grayscale, increased contrast, and VoiceOver announcements for sidebar state, dimmed Packet Monitor availability, status badges, latency cards, and audio meters.
- Confidence: high

### VA-009

- ID: VA-009
- Severity: P2
- File/component: `Sources/open-lola-app/AppDesignSystem.swift` and uses of system/opacity colors across app views / contrast coverage
- Evidence: The design system computes contrast ratios for app-background secondary text and several light-mode state colors (`AppDesignSystem.swift:44-59`, `267-291`). Tests assert those ratios meet the 4.5 threshold (`AppShellBehaviorTests.swift:415-424`). However, many UI elements use `Color.secondary`, `Color.tertiary`, `Color.accentColor`, low-opacity fills/borders, and video overlay text that are not covered by those constants (`AppDeviceCard.swift:126-150`; `AppPreviewReceiverView.swift:303-307`; `AppDesignSystem.swift:187-206`).
- User impact: Critical contrast pairs are partially protected, but unsupported pairs can regress silently, especially in light mode, high-contrast mode, and video overlay states.
- Accessibility impact: Low-vision users may encounter weak secondary text, borders, disabled controls, or overlays even when the primary app-background state colors pass tests.
- Suggested remediation: Expand contrast checks to cover representative component pairs: status badge text/background, warning banner text/background, disabled secondary text, selected device cards, video overlay captions, search fields, and panel borders.
- Manual or automated verification: Use Accessibility Inspector contrast sampling or screenshot-based contrast checks in light, dark, and increased-contrast appearances.
- Confidence: high

### VA-010

- ID: VA-010
- Severity: P2
- File/component: `Sources/open-lola-app/AppShellRootView.swift` and `Sources/open-lola-app/AppDesignSystem.swift` / window and responsive layout
- Evidence: The app root enforces `minWidth: AppWindowSize.operatorMinWidth` and `minHeight: AppWindowSize.operatorMinHeight` (`AppShellRootView.swift:117-118`). `AppWindowSize` defines an operator minimum of 1024x720 and a 240 point sidebar (`AppDesignSystem.swift:355-366`), and tests assert the 1024x720 minimum (`AppShellSlice05Tests.swift:98-99`).
- User impact: The operator console appears intentionally desktop-sized, but smaller displays, split-screen use, large text, or localized strings can push dense controls into constrained layouts at the minimum size.
- Accessibility impact: Users who need larger text or zoom may lose usable space quickly because the source does not show responsive breakpoints beyond the minimum window constraints.
- Suggested remediation: Treat 1024x720 as a tested minimum and add manual layout acceptance criteria for large text, long labels, and reduced visible width.
- Manual or automated verification: Capture minimum-window screenshots for every section in light/dark/high-contrast mode with long text fixtures and larger system text where supported.
- Confidence: high

### VA-011

- ID: VA-011
- Severity: P3
- File/component: `Sources/open-lola-app/AppSessionStateBanner.swift` / session state banner
- Evidence: The banner label uses caption semibold monospaced text, caps content to two lines, and middle-truncates (`AppSessionStateBanner.swift:48-55`). It also includes CTAs styled as plain compact buttons with small padding (`AppSessionStateBanner.swift:71-83`, `193-204`).
- User impact: Long session state copy can visually truncate in the banner. CTAs may be visually compact relative to their workflow importance.
- Accessibility impact: The combined accessibility label includes the full state and banner label (`AppSessionStateBanner.swift:95-97`), so the main risk is visual readability and target size rather than missing screen-reader text.
- Suggested remediation: Verify banner strings at minimum width and increase CTA hit target or wrapping only where truncation is observed.
- Manual or automated verification: Exercise unconfigured, ready, armed, validating, receiver warning, error, and live states with long host/peer names at 1024x720.
- Confidence: medium

### VA-012

- ID: VA-012
- Severity: P2
- File/component: `Sources/open-lola-app/AppChannelMeterView.swift` / canvas audio meters
- Evidence: The meter view draws 6 point wide channel bars with 2 point gaps in a `Canvas` and splits level zones by color (`AppChannelMeterView.swift:17-23`, `35-46`, `95-114`). Accessibility exposes "Audio level meters" plus channel count and peak percentage (`AppChannelMeterView.swift:62-73`).
- User impact: The compact visual meter works for quick scanning but may be hard to read for many channels or for users who need precise per-channel level detail.
- Accessibility impact: The screen-reader summary does not expose per-channel values, clipping by channel, or peak-hold state. That may be acceptable for overview use but is insufficient if per-channel diagnosis is a required task.
- Suggested remediation: Define whether meters are overview-only or diagnostic. If diagnostic, expose selected/per-channel details and a non-color-coded clipping/warning summary.
- Manual or automated verification: Test 2, 8, 32, and 64 channel displays; verify screen-reader output and visual legibility in high-contrast and color-blind simulations.
- Confidence: high

### VA-013

- ID: VA-013
- Severity: P3
- File/component: `Sources/open-lola-app/AppPreviewReceiverView.swift` / video preview overlay and empty audio state
- Evidence: The video preview uses a black 16:9 rectangle and overlays subtitle text on `.black.opacity(0.55)` with white foreground (`AppPreviewReceiverView.swift:295-308`). The no-audio empty state uses secondary text and a low-opacity secondary background (`AppPreviewReceiverView.swift:410-426`).
- User impact: Overlay readability likely depends on the underlying video frame and subtitle length. The empty state appears structurally labeled, but contrast was not sampled from screenshots.
- Accessibility impact: The empty audio state has a combined accessibility label (`AppPreviewReceiverView.swift:425-426`). The video overlay itself needs runtime verification because preview content and captions are dynamic.
- Suggested remediation: Verify overlay contrast against bright and noisy video frames; add caption length constraints or wrapping only if runtime evidence shows clipping.
- Manual or automated verification: Run local preview with bright/dark/noisy frames and long device names; sample overlay contrast and check VoiceOver output for the preview state.
- Confidence: medium

### VA-014

- ID: VA-014
- Severity: P2
- File/component: `Tests/OpenLolaCoreTests/` and app verification scripts / visual and accessibility regression coverage
- Evidence: Tests cover some accessibility labels, session announcement policy, truthful UI states, window minimums, and color contrast constants (`AppShellBehaviorTests.swift:99-110`, `415-424`; `AppShellSlice05Tests.swift:82-99`). This audit did not find an automated screenshot, focus traversal, VoiceOver tree, hit-target, text-overflow, or full component contrast gate in the inspected test evidence.
- User impact: Dense operator-console regressions can ship even when source-level state and label tests pass.
- Accessibility impact: Missing automated coverage increases the chance that focus, clipping, disabled-state explanations, and contrast regress without detection.
- Suggested remediation: Add a small manual QA checklist first, then automate the highest-risk stable checks: minimum-window screenshots, contrast samples for token/component pairs, and accessibility-tree assertions for icon-only controls and disabled reasons.
- Manual or automated verification: Create a repeatable app-shell visual/accessibility smoke pass and store the expected evidence path in the docs/testing surface.
- Confidence: medium

## Readability Blockers

- No confirmed P0/P1 readability blocker was proven from static source alone.
- The highest readability risks are VA-001, VA-002, VA-003, and VA-004: long operational values, commands, packet rows, device IDs, and host names can be hidden behind horizontal scroll, truncation, or tooltip/copy recovery.

## Accessibility Blockers

- No confirmed P0/P1 accessibility blocker was proven from static source alone.
- The highest accessibility risks are VA-005, VA-006, VA-007, VA-008, and VA-012: small plain controls, disabled reasons hidden in help text, inconsistent focus evidence outside transport, color/opacity cues, and limited meter semantics.

## Layout/Scaling Risks

- The operator console is explicitly constrained to a 1024x720 minimum window with a 240 point sidebar (VA-010).
- Several dense surfaces depend on caption text, monospaced command/path strings, tables, and nested scroll views.
- Localization and long-text risk remains open because many compact labels are hardcoded English strings and several surfaces use one-line or two-line caps.

## Low-Risk Visual Cleanup Candidates

- Normalize plain icon/copy/dismiss button sizing with the transport hit-target approach.
- Expand visual state labels where a colored dot, low opacity, or color fill carries meaning.
- Add explicit full-value reveal patterns for paths, IDs, hosts, and packet details.
- Broaden contrast tests for component-level pairs beyond the current design-token constants.

## Suggested Manual Test Checklist

1. Run the app at 1024x720 in dark, light, and increased-contrast appearances.
2. Navigate every sidebar section with keyboard only and capture focus-visible screenshots.
3. Inspect top bar icon buttons, packet copy buttons, warning dismiss buttons, device cards, and banner CTAs with Accessibility Inspector for labels, roles, focus, and hit targets.
4. Use long fixture values for paths, device UIDs, hosts, generated commands, packet payloads, and validation errors.
5. Verify disabled settings and preview controls explain why they are disabled without relying only on pointer hover.
6. Test video preview overlay readability against bright, dark, and noisy frames.
7. Test audio meters at 2, 8, 32, and 64 channels, including color-blind simulation and VoiceOver output.
8. Verify error, warning, success, selected, hover, active, disabled, and loading/empty states in both appearance modes.

## Remaining Uncertainty

- Actual contrast and clipping require screenshots or Accessibility Inspector sampling; this audit only used code/test evidence.
- Keyboard focus order and VoiceOver output need runtime verification.
- It is unclear whether all dense controls inherit sufficient default macOS focus rings in the final app bundle.
- It is unclear whether per-channel meter accessibility is required for the target operator workflow or whether aggregate meter accessibility is sufficient.
- It is unclear how localized or unusually long user/device strings will behave across every panel without fixture-driven visual testing.
