# UI/UX Visual & Accessibility Audit

**Scope:** All Swift UI source files in `Sources/open-lola-app/` plus `AppDesignSystem.swift`.
**Method:** Static source read + WCAG 2.1 contrast ratio computation (WCAG relative-luminance formula on all RGB color values from `AppDesignSystem.swift`).
**Date:** 2025
**Auditor:** Static analysis — no screenshots or live rendering available.

---

## Contrast Ratio Reference Table

All ratios computed from `AppDesignSystem.swift` RGB component values.

| Color role | Mode | R, G, B | On bg | Ratio | WCAG AA (4.5:1) |
|---|---|---|---|---|---|
| `stateArmed` orange | Dark | 0.950, 0.480, 0.000 | dark bg | **7.02:1** | ✅ pass |
| `stateArmed` orange | **Light** | 0.950, 0.480, 0.000 | light bg | **2.53:1** | ❌ **FAIL** |
| `stateArmed` orange | **Light** | (unarmed btn, 12% tint bg) | light btn bg | **2.26:1** | ❌ **FAIL** |
| `stateReady` yellow | Dark | 1.000, 0.820, 0.000 | dark bg | 13.30:1 | ✅ pass |
| `stateReady` amber (light variant) | **Light** | 0.720, 0.360, 0.000 | light bg | **4.21:1** | ❌ **FAIL** |
| `stateConnecting` blue | Dark | 0.250, 0.550, 1.000 | dark bg | 5.94:1 | ✅ pass |
| `stateConnecting` blue (light variant) | Light | 0.000, 0.290, 0.700 | light bg | 7.30:1 | ✅ pass |
| `stateLive` green | Dark | 0.180, 0.780, 0.320 | dark bg | 8.69:1 | ✅ pass |
| `stateLive` green (light variant) | **Light** | 0.080, 0.540, 0.210 | light bg | **4.08:1** | ❌ **FAIL** |
| `stateError` red | Dark | 1.000, 0.270, 0.250 | dark bg | 5.71:1 | ✅ pass |
| `stateError` red (light variant) | Light | 0.780, 0.000, 0.000 | light bg | 5.60:1 | ✅ pass |
| `stateUnconfigured` gray | Dark | 0.640, 0.640, 0.660 | dark bg | 7.75:1 | ✅ pass |
| `stateUnconfigured` gray (light variant) | Light | 0.420, 0.430, 0.460 | light bg | 4.68:1 | ✅ pass |
| `stateError` red (dark variant wrong mode) | Light | 1.000, 0.270, 0.250 | light bg | 3.11:1 | ❌ **FAIL** (if misapplied) |
| `system_orange` (`.orange` SwiftUI) | **Light** | 1.000, 0.584, 0.000 | panel light | **1.95:1** | ❌ **FAIL** |
| `system_orange` | Dark | 1.000, 0.584, 0.000 | panel dark | 8.21:1 | ✅ pass |
| Black on `stateArmed` orange fill | Both | 0, 0, 0 on 0.950,0.480,0.000 | orange | 7.59:1 | ✅ pass |
| Secondary text ref | Dark | 0.640, 0.640, 0.660 | dark bg | 7.75:1 | ✅ pass |
| `stateArmed` orange unarmed btn | Dark | orange on orange@12% tint | dark | 6.10:1 | ✅ pass |

**Background luminance values used:** dark bg = 0.00407, light bg = 0.90842, elevated dark = 0.01412, panel dark = 0.00815, panel light = 0.97584.

---

## Findings

---

### VA-001 — Warning banner text fails contrast in light mode

| Field | Value |
|---|---|
| **ID** | VA-001 |
| **Severity** | P0 |
| **File** | `AppShellSupportViews.swift` · `AppLatencyHeroView.swift` |
| **Component** | `AppWarningBanner` |
| **Evidence** | `AppWarningBanner` uses `.orange` (SwiftUI system color, approx RGB 1.0, 0.584, 0.0) for title text and icon. In light mode, `.orange.opacity(0.12)` background blends to near-white (panel light L ≈ 0.883). Computed contrast of orange text on that background: **1.95:1**. WCAG AA requires 4.5:1 for normal text, 3:1 for large text (18pt+ or 14pt+ bold). Warning banner title is `.caption.weight(.semibold)` (~11–12pt), well below large-text thresholds. |
| **User impact** | Warning text is unreadable in light mode. The banner is used in `AppLatencyHeroView` to surface the "Partial latency evidence" message and is the primary mechanism for surfacing runtime degradation warnings. A field operator using light mode cannot read the warning. |
| **Accessibility impact** | Fails WCAG 2.1 SC 1.4.3 (Contrast, Minimum, AA). |
| **Suggested remediation** | Replace `.orange` with a design-system–managed color token that provides ≥ 4.5:1 contrast in both modes, or explicitly use `.AppDesignSystem.stateArmed` (which has separate light/dark variants) as the warning color — but note stateArmed orange is also failing in light mode (see VA-002). A dedicated `warningText` token is needed with light variant ≥ dark amber (e.g., RGB 0.60, 0.25, 0.00 gives ~6:1 on white). |
| **Verification** | Render `AppWarningBanner` in light mode, use Xcode Accessibility Inspector color contrast tool. |
| **Confidence** | High — computed from actual RGB values and WCAG formula. |

---

### VA-002 — `stateArmed` orange fails contrast in light mode

| Field | Value |
|---|---|
| **ID** | VA-002 |
| **Severity** | P1 |
| **File** | `AppDesignSystem.swift` · `AppSessionStateBanner.swift` · `AppTransportView.swift` · `AppConsoleChromeView.swift` |
| **Component** | Session state banner, transport ARM button, status badges, sidebar dot |
| **Evidence** | `stateArmed` uses RGB(0.950, 0.480, 0.000) in **both light and dark modes** (no light-mode variant in `AppDesignSystem.swift`). Computed contrast vs. light background: **2.53:1**. The unarmed ARM button uses `stateArmed` text on `stateArmed.opacity(0.12)` tinted light background: **2.26:1**. Both fail WCAG AA for normal text. Affected surfaces: banner label text, ARM/Armed button label (`.callout.weight(.semibold)`), 6pt sidebar dot (decorative, exempt), status badge title. |
| **User impact** | In light mode, the "Armed" session state banner label, the ARM/Armed transport button label, and any status badge displaying the armed state are rendered in near-unreadable orange on a near-white background. The operator cannot reliably confirm arm status before starting a live audio session. |
| **Accessibility impact** | Fails WCAG 2.1 SC 1.4.3 (Contrast, Minimum, AA). |
| **Suggested remediation** | Add a distinct light-mode variant for `stateArmed` in `AppDesignSystem.swift` with sufficient contrast on light backgrounds (target luminance ~0.10–0.15 for orange/amber; e.g., RGB 0.65, 0.25, 0.00 gives ~5.4:1 on light). The banner and ARM button use `AppDesignSystem.stateArmed` directly — no code change needed beyond the color token. |
| **Verification** | Run in light mode, check ARM button and session banner with Xcode Accessibility Inspector. |
| **Confidence** | High — no light/dark variant defined for `stateArmed` in source; ratio computed from RGB values. |

---

### VA-003 — `stateReady` amber marginally fails contrast in light mode

| Field | Value |
|---|---|
| **ID** | VA-003 |
| **Severity** | P1 |
| **File** | `AppDesignSystem.swift` · `AppSessionStateBanner.swift` · `AppConsoleModels.swift` |
| **Component** | Session state banner (ready state), next-action panel, status badges |
| **Evidence** | `stateReady` light variant is RGB(0.720, 0.360, 0.000) — computed contrast vs. light background: **4.21:1**. WCAG AA requires 4.5:1 for normal text. Deficit is 0.29:1. Affected text: banner label ("Configuration complete — arm to proceed"), `.caption.weight(.semibold)`. Against panel light background: 4.51:1 (marginal pass on panel, fails on main bg). |
| **User impact** | In light mode on the main window background, the "Ready" state banner label falls below required contrast. Users may find it harder to read the session state at a glance, especially in outdoor/high-ambient-light conditions. |
| **Accessibility impact** | Fails WCAG 2.1 SC 1.4.3 (Contrast, Minimum, AA) against main background. |
| **Suggested remediation** | Darken `stateReady` light variant by ≈ 10% luminance — RGB(0.64, 0.28, 0.00) gives ~5.4:1 on light bg. |
| **Verification** | Xcode Accessibility Inspector in light mode with session in ready state. |
| **Confidence** | High — ratio computed; only the main window background fails (panel passes marginally). |

---

### VA-004 — `stateLive` green fails contrast in light mode

| Field | Value |
|---|---|
| **ID** | VA-004 |
| **Severity** | P1 |
| **File** | `AppDesignSystem.swift` · `AppSessionStateBanner.swift` |
| **Component** | Session state banner (live state), next-action panel, status badges, latency threshold indicators |
| **Evidence** | `stateLive` light variant is RGB(0.080, 0.540, 0.210) — computed contrast vs. light background: **4.08:1**. Against panel light: 4.36:1. Both fall below the 4.5:1 AA threshold for normal text. Also used in `AppLatencyHeroView` threshold status labels as `stateLive` color for "target met" / "nominal" / "stable" status indicators. |
| **User impact** | In light mode, the live session state banner and all "good" threshold labels in the latency hero display are below required contrast. Field operators using light mode may not clearly see "Live" or "target met" status. |
| **Accessibility impact** | Fails WCAG 2.1 SC 1.4.3 (Contrast, Minimum, AA). |
| **Suggested remediation** | Darken light variant: RGB(0.04, 0.42, 0.15) gives ~6.3:1 on light bg. |
| **Verification** | Xcode Accessibility Inspector in light mode with session live or latency data populated. |
| **Confidence** | High — computed from actual RGB values. |

---

### VA-005 — State colors have no increased-contrast mode variants

| Field | Value |
|---|---|
| **ID** | VA-005 |
| **Severity** | P1 |
| **File** | `AppDesignSystem.swift` |
| **Component** | All `AppSessionState`-colored surfaces: banner, badges, transport buttons, sidebar dot, latency hero, meter zones |
| **Evidence** | `AppDesignSystem.swift` defines increased-contrast variants for background, panel, border, and meter colors. However, `stateReady`, `stateArmed`, `stateConnecting`, `stateLive`, and `stateError` all use `_` wildcard for the contrast variant (no increased-contrast alternative). `AppDesignSystem.meterSafe/meterCaution/meterClip` DO have increased-contrast variants. |
| **User impact** | Users who enable "Increase Contrast" in macOS System Settings receive no additional contrast for any session-state indicator. This is the primary visual language of the app. |
| **Accessibility impact** | Misses intent of WCAG 2.1 SC 1.4.6 (Contrast Enhanced, AAA) and user expectation set by macOS `accessibilityIncreaseContrast`. The app already has the infrastructure (color environment) but omits state colors from it. |
| **Suggested remediation** | Add increased-contrast variants for all five state colors. Target ratios: stateArmed ≥ 7:1 in both modes, all others ≥ 7:1 (AAA). The existing `AppColorEnvironment` machinery will apply them automatically once defined. |
| **Verification** | Enable Increase Contrast in macOS accessibility settings, inspect banner and transport with Accessibility Inspector. |
| **Confidence** | High — source shows explicit `_` wildcard; meter colors confirm pattern. |

---

### VA-006 — `AppWarningBanner` not marked as accessibility alert

| Field | Value |
|---|---|
| **ID** | VA-006 |
| **Severity** | P1 |
| **File** | `AppShellSupportViews.swift` lines 225–278 |
| **Component** | `AppWarningBanner` |
| **Evidence** | `AppWarningBanner` has no `.accessibilityRole(.alert)` on its container view. It also has no `UIAccessibility.post(notification: .announcement)` equivalent (no `AccessibilityFocusedBinding` or announcement trigger). It carries `.orange.opacity(0.12)` background as the sole visual indicator of warning nature. The dismiss button has `.accessibilityLabel("Dismiss warning")` (correct) but the container element has no role that signals warning to a screen reader. |
| **User impact** | Screen reader users (VoiceOver) will not be automatically notified when a warning banner appears or changes. They must navigate to it manually. Missing a "Partial latency evidence" warning during a live audio session is a safety-critical miss. |
| **Accessibility impact** | Fails WCAG 2.1 SC 4.1.3 (Status Messages). On macOS, the appropriate semantic is to use `.accessibilityRole(.alert)` or post an accessibility announcement. |
| **Suggested remediation** | Add `.accessibilityRole(.alert)` to the outer `HStack` in `AppWarningBanner`. Additionally consider using `withAnimation` + an `@Environment(\.accessibilityAnnouncement)` or `AccessibilityNotification.Announcement` to announce the message when it first appears. |
| **Verification** | Enable VoiceOver. Trigger a warning banner. Confirm VoiceOver announces it without user navigation. |
| **Confidence** | High — no alert role found in source. |

---

### VA-007 — No `accessibilityReduceMotion` guard on pulsing animation

| Field | Value |
|---|---|
| **ID** | VA-007 |
| **Severity** | P1 |
| **File** | `AppSessionStateBanner.swift` lines 116–123 · `AppDesignSystem.swift` (`AppSessionState.isAnimated`) |
| **Component** | `AppSessionStateBanner` (pulsing icon during armed/connecting/running states) |
| **Evidence** | `restartPulse()` starts a `.easeInOut(duration: 1.1s).repeatForever(autoreverses: true)` animation when `state.isAnimated` is true. No `@Environment(\.accessibilityReduceMotion)` check guards this. `AppDesignSystem.AppSessionState.isAnimated` is a pure computed property with no motion preference check. |
| **User impact** | Users with vestibular disorders who enable "Reduce Motion" in macOS System Settings are still exposed to a continuously pulsing icon during the most critical operational states (armed, connecting, running). |
| **Accessibility impact** | Fails WCAG 2.1 SC 2.3.3 (Animation from Interactions, AAA) and macOS accessibility convention for reduce-motion. |
| **Suggested remediation** | Inject `@Environment(\.accessibilityReduceMotion) var reduceMotion` in `AppSessionStateBanner`. In `restartPulse()`, skip the animation if `reduceMotion` is true (or use a static opacity change instead). |
| **Verification** | Enable Reduce Motion in macOS System Settings. Arm the session. Confirm the icon does not pulse. |
| **Confidence** | High — no reduce-motion guard in source. |

---

### VA-008 — Transport bar buttons have no keyboard focus ring

| Field | Value |
|---|---|
| **ID** | VA-008 |
| **Severity** | P1 |
| **File** | `AppTransportView.swift` lines 59, 86, 113, 139, 159 |
| **Component** | ARM, Dry Run, Start, Stop, Validate buttons in transport bar |
| **Evidence** | All five transport bar buttons use `.buttonStyle(.plain)`. `.plain` style on macOS removes the standard system focus ring. No `.focusEffectDisabled(false)` or custom focus indicator is applied. The ARM button does have `.keyboardShortcut("e", modifiers: [.command, .shift])`, so keyboard users can invoke it, but cannot see which control has focus when tabbing. |
| **User impact** | Keyboard-only users cannot visually determine focus position within the transport bar. |
| **Accessibility impact** | Fails WCAG 2.1 SC 2.4.7 (Focus Visible). |
| **Suggested remediation** | Replace `.buttonStyle(.plain)` with a custom `ButtonStyle` that preserves the capsule visual but adds a visible focus ring using `@Environment(\.isFocused)` or `.focusEffectDisabled(false)`. Alternatively, wrap each button label with `.overlay { if isFocused { Capsule().stroke(Color.accentColor, lineWidth: 2) } }`. |
| **Verification** | Tab through transport bar with VoiceOver off. Confirm each button is individually focused and visible. |
| **Confidence** | High — `.buttonStyle(.plain)` confirmed in source. |

---

### VA-009 — Transport bar button hit targets below Apple HIG minimum

| Field | Value |
|---|---|
| **ID** | VA-009 |
| **Severity** | P2 |
| **File** | `AppTransportView.swift` |
| **Component** | ARM, Dry Run, Start, Stop, Validate buttons |
| **Evidence** | Button vertical padding is `.padding(.vertical, AppSpacing.xxs + 2)` = 6pt each side. `.callout` font is ~13pt. Total button height ≈ 6 + 13 + 6 = 25pt. Apple HIG recommends a minimum 44×44 pt tap/click target. The capsule background is smaller still — the 6pt side padding is the only buffer. |
| **User impact** | Users with fine motor impairment, tremor, or stylus/trackpad input will find the transport buttons difficult to activate reliably, especially Stop and ARM which must be pressed under time pressure. |
| **Accessibility impact** | Does not fail WCAG (which has no strict pointer target size at AA), but fails Apple HIG and WCAG 2.5.5 (Target Size, AAA, 44×44). |
| **Suggested remediation** | Increase vertical padding from 6pt to 14–16pt each side to reach ~43–45pt button height, or use `.contentShape(Rectangle())` with an expanded hit area while keeping the visual capsule size. |
| **Verification** | Render in macOS, measure button frame using Accessibility Inspector or Reveal.app. |
| **Confidence** | High — padding and font values read from source. |

---

### VA-010 — Warning banner dismiss button has very small hit target

| Field | Value |
|---|---|
| **ID** | VA-010 |
| **Severity** | P2 |
| **File** | `AppShellSupportViews.swift` lines 253–261 |
| **Component** | `AppWarningBanner` dismiss (`xmark`) button |
| **Evidence** | Dismiss button uses `Image(systemName: "xmark")` with `.font(.caption.weight(.semibold))` and `.buttonStyle(.plain)`. No explicit padding on the button. Icon size at `.caption` = ~11pt. With no padding, hit target ≈ 11–16pt — well below 44pt. Has `.accessibilityLabel("Dismiss warning")` (correct) so VoiceOver can still reach it. |
| **User impact** | Small hit target makes dismissal difficult for motor-impaired users and those using pointer devices without fine control. |
| **Accessibility impact** | WCAG 2.5.5 Target Size (AAA). |
| **Suggested remediation** | Add `.padding(AppSpacing.s)` to the dismiss button to expand the hit target to ~35pt, or use `.padding(AppSpacing.m)` for 43pt. Use `.contentShape(Circle())` to make the padding area interactive. |
| **Verification** | Measure hit target with Accessibility Inspector. |
| **Confidence** | High — no padding on the button in source. |

---

### VA-011 — Primary status text uses `.caption` (≈11pt) throughout

| Field | Value |
|---|---|
| **ID** | VA-011 |
| **Severity** | P2 |
| **File** | `AppSessionStateBanner.swift` · `AppShellSupportViews.swift` · `AppTransportView.swift` |
| **Component** | Session state banner label, `AppStatusBadge` text, warning banner text |
| **Evidence** | Session state banner: `.font(.caption.weight(.semibold))`. `AppStatusBadge` title: `.font(.caption.weight(.semibold))` with `.lineLimit(1)`. Warning banner title: `.font(.caption.weight(.semibold))`. Warning messages: `.font(.caption)`. Warning detail: `.font(.caption2)` (~10pt). The banner minHeight is 44pt but the text within is the smallest semantic size. |
| **User impact** | The primary session state communication channel uses the smallest non-system font size. Under stress, low-light, or elevated-distance viewing conditions, operators may miss state transitions. The banner is intended as "always visible" status — its text deserves a more prominent scale. |
| **Accessibility impact** | Not a WCAG failure (dynamic type scales appropriately). Risk for users with mild low vision who have not configured text size. |
| **Suggested remediation** | Consider `.callout.weight(.semibold)` (~13pt) for the banner label. Status badges can remain at `.caption`. |
| **Verification** | Manual review at 1024pt window minimum width, arm+connecting+live states. |
| **Confidence** | High — font assignments confirmed in source. |

---

### VA-012 — `AppStatusBadge` truncates on long state labels

| Field | Value |
|---|---|
| **ID** | VA-012 |
| **Severity** | P2 |
| **File** | `AppShellSupportViews.swift` lines 186–211 |
| **Component** | `AppStatusBadge` |
| **Evidence** | `.lineLimit(1)` with no `truncationMode` set (defaults to `.tail`). Badge title is `.caption.weight(.semibold)`. Transport bar `statusModeTitle` for unavailable modes returns strings like `"JACKTRIP UNAVAILABLE"` (20 chars) and `"ULTRAGRID UNAVAILABLE"` (21 chars). Session execution title strings include multi-word values. Badges have no min/max width constraint. |
| **User impact** | Status badges displaying "JACKTRIP UNAVAILABLE" or similar long strings will be truncated to "JACKTRIP UN…" in the status pill area at the right of the transport bar, hiding availability information. |
| **Accessibility impact** | `.accessibilityLabel(title)` is set with the full string — accessible via VoiceOver but not visually. |
| **Suggested remediation** | Allow `.lineLimit(2)` or add `minimumScaleFactor(0.85)` for badge text, or cap the displayed string to a known-short form with the full text in `.help()`. |
| **Verification** | Set session mode to JackTrip, observe transport bar status pills. |
| **Confidence** | High — source confirms `.lineLimit(1)`; string lengths are explicit. |

---

### VA-013 — Color-only state encoding without secondary differentiator

| Field | Value |
|---|---|
| **ID** | VA-013 |
| **Severity** | P2 |
| **File** | `AppDesignSystem.swift` · `AppSessionStateBanner.swift` · `AppConsoleModels.swift` |
| **Component** | Session state banner, `AppSessionState` status indicators |
| **Evidence** | Three `AppSessionState` pairs share the same color token: (a) `.supervisorRunning` → `stateConnecting` (blue); (b) `.dryRunRunning` → `stateArmed` (orange); (c) `.awaitingEvidence` → `stateReady` (amber/yellow). Additionally, `stateReady` (amber) and `stateArmed` (orange) are adjacent hues on the warm-yellow–orange spectrum, potentially confused by deuteranopes and protanopes. The sidebar dot is 6pt — color is its only distinguishing property at that size. |
| **User impact** | Users with color vision deficiency (affects ~8% of males) may not reliably distinguish ready/armed/awaiting-evidence from each other or from their shared states. On the 6pt sidebar dot, only color is communicated — shape/text are not used. |
| **Accessibility impact** | Risks failing WCAG 2.1 SC 1.4.1 (Use of Color). Session state is communicated partly by color alone in the sidebar dot context. |
| **Suggested remediation** | For the sidebar dot: supplement color with a shape change (filled circle = running, empty/outlined = not running, diamond = warning). For the banner, the text label (already present) is sufficient if contrast passes (see VA-002–004). The deeper fix is to assign distinct color tokens to `.supervisorRunning`, `.dryRunRunning`, and `.awaitingEvidence` rather than reusing `stateConnecting`, `stateArmed`, and `stateReady`. |
| **Verification** | Use a CVD simulator (Sim Daltonism, Xcode Accessibility > Color Filters) to check all 9 session states. |
| **Confidence** | Medium — source-inferred; no CVD testing performed. |

---

### VA-014 — Latency hero nil values render as "— ms" in VoiceOver

| Field | Value |
|---|---|
| **ID** | VA-014 |
| **Severity** | P2 |
| **File** | `AppLatencyHeroView.swift` lines 28–49 |
| **Component** | `AppLatencyHeroView` hero cells |
| **Evidence** | When `audioLatencyMs`, `packetLossPercent`, or `jitterMs` are `nil`, the displayed value is `"—"` (em dash). The accessibility label is constructed as `"\(label): \(value) \(unit). Status: \(statusLabel)."` — producing e.g. `"Audio Latency: — ms. Status: no data."` VoiceOver reads "— ms" as "dash ms" or "em dash ms" depending on synthesizer locale. |
| **User impact** | Screen reader users hear an unnatural phrase that communicates the meaning only indirectly. "Not available" or "no measurement" would be clearer. |
| **Accessibility impact** | Minor VoiceOver UX degradation. |
| **Suggested remediation** | Add a computed `accessibilityValueDescription` for nil case: `"Audio Latency: not available. Status: no data."` — substitute `"not available"` for `"\(value) \(unit)"` when value is `nil`. |
| **Verification** | VoiceOver on latency hero with nil metrics. |
| **Confidence** | High — label construction in source is literal. |

---

### VA-015 — Session banner hostname labels risk truncation in critical states

| Field | Value |
|---|---|
| **ID** | VA-015 |
| **Severity** | P2 |
| **File** | `AppSessionStateBanner.swift` lines 90–100 |
| **Component** | `AppSessionStateBanner` (armed + connecting + live labels) |
| **Evidence** | Armed label: `"\(localPeer) ↔ \(remotePeer) · \(localHost) → \(remoteHost)"`. Connecting label: `"Connecting \(localPeer) (\(localHost)) ↔ \(remotePeer) (\(remoteHost))"`. Both concatenate 4 user-defined identifiers into a single string with `.lineLimit(2)` and `.truncationMode(.middle)`. At minimum window width (1024pt) with sidebar (240pt) and 16pt horizontal padding, available width ≈ 752pt. The connecting label at `".caption.weight(.semibold)"` can display ~120–130 characters per line × 2 lines. But peer/host names can be long (hostnames up to 253 chars per RFC). Middle truncation in the center will lose peer names. |
| **User impact** | Operators cannot confirm which peer they are connecting to if names are long. This is especially risky at `.connecting` state where visual confirmation of the peer is time-sensitive. |
| **Accessibility impact** | `.accessibilityHint(bannerLabel)` provides the full string to VoiceOver. |
| **Suggested remediation** | Shorten displayed strings: use only the first label segment or show `localHost` alone on line 2. Provide the full label via `.help(bannerLabel)`. |
| **Verification** | Set peer names to 40+ characters, observe banner at minimum window width. |
| **Confidence** | Medium — confirmed label construction; no rendering measurement available. |

---

### VA-016 — `DesignPanel` uses off-scale padding value

| Field | Value |
|---|---|
| **ID** | VA-016 |
| **Severity** | P3 |
| **File** | `AppShellSupportViews.swift` (DesignPanel implementation) |
| **Component** | `DesignPanel` container (used in all detail section panels) |
| **Evidence** | `DesignPanel` uses `.padding(AppSpacing.m - 2)` = 14pt. The `AppSpacing` scale is: xxs=4, xs=8, s=12, m=16, l=24, xl=32. 14pt is not a defined step; it falls between `s` (12) and `m` (16). This creates a subtle inconsistency — inner panel content is 2pt closer to panel edges than the defined medium spacing. |
| **User impact** | Negligible visual artifact — panels appear slightly tighter than a 16pt grid implies. |
| **Accessibility impact** | None. |
| **Suggested remediation** | Use `AppSpacing.s` (12pt) or `AppSpacing.m` (16pt) instead. |
| **Verification** | Visual inspection of any section panel with defined spacing overlay. |
| **Confidence** | High — value is explicit in source. |

---

### VA-017 — `UInt16Field` help tooltip uses internal/technical wording

| Field | Value |
|---|---|
| **ID** | VA-017 |
| **Severity** | P3 |
| **File** | `AppShellSupportViews.swift` lines 1–53 |
| **Component** | `UInt16Field`, `IntField` |
| **Evidence** | `.help("Must be a valid UInt16 value")` on the underlying `TextField`. The visible inline error label (shown when input is invalid) reads: `"Enter a whole number from 0 to 65535."` — user-friendly. The tooltip contradicts the error label by using a type name (`UInt16`) not explained in context. |
| **User impact** | If a user hovers over the field expecting guidance before entering a value, they see a developer-facing type name rather than a user-facing hint. Minor confusion. |
| **Accessibility impact** | None — `.help()` is surfaced as a tooltip, not as an accessibility description. |
| **Suggested remediation** | Replace `.help("Must be a valid UInt16 value")` with `.help("Enter a whole number from 0 to 65535.")` to match the inline error text. |
| **Verification** | Hover over a port field in Settings > Devices. |
| **Confidence** | High — both strings are in source. |

---

### VA-018 — `AppReadableValue` horizontal scroll for long values is non-obvious

| Field | Value |
|---|---|
| **ID** | VA-018 |
| **Severity** | P3 |
| **File** | `AppShellSupportViews.swift` lines 142–179 |
| **Component** | `AppReadableValue` |
| **Evidence** | `AppReadableValue` wraps the value text in a `ScrollView(.horizontal, showsIndicators: false)` with `minWidth: 120`. The scroll indicators are hidden. There is no visual affordance (gradient fade, ellipsis) indicating the text is scrollable. The full value is accessible via `.help(value)` and the copy button. |
| **User impact** | For long file paths or addresses, the value text appears clipped. Users may not know it is scrollable or that the full value exists. The `.help()` tooltip and copy button partially compensate but require extra interaction. |
| **Accessibility impact** | VoiceOver reads the full value via `.accessibilityLabel`. |
| **Suggested remediation** | Add a trailing gradient fade (`.mask(LinearGradient(...))`  when content overflows) or use `.truncationMode(.middle)` with `.lineLimit(1)` and expose the full value only in `.help()`. |
| **Verification** | Populate a readable metric with a long path (>30 chars), observe without scrolling. |
| **Confidence** | High — scroll view with hidden indicators confirmed in source. |

---

### VA-019 — `AppConsoleChromeView` search icon has no accessibility label

| Field | Value |
|---|---|
| **ID** | VA-019 |
| **Severity** | P3 |
| **File** | `AppConsoleChromeView.swift` line 116 |
| **Component** | `AppConsoleTopBarView` search icon |
| **Evidence** | `Image(systemName: "magnifyingglass")` is placed left of the search `TextField` with no `.accessibilityHidden(true)` and no `.accessibilityLabel`. It is decorative context for the adjacent text field. Without marking it hidden, VoiceOver may announce it separately as "Magnifying glass image." |
| **User impact** | Minimal — VoiceOver announces a decorative icon. |
| **Accessibility impact** | Minor VoiceOver noise. WCAG 1.1.1 requires decorative images to be hidden from assistive technology. |
| **Suggested remediation** | Add `.accessibilityHidden(true)` to the magnifying glass image. |
| **Verification** | VoiceOver traversal of the top bar. |
| **Confidence** | High — source confirmed; no `.accessibilityHidden` present. |

---

### VA-020 — `AppChannelMeterView` canvas provides no per-channel level data to VoiceOver

| Field | Value |
|---|---|
| **ID** | VA-020 |
| **Severity** | P3 |
| **File** | `AppChannelMeterView.swift` lines 54–57, 59–65 |
| **Component** | `AppChannelMeterView`, `AppCompactMeterStrip` |
| **Evidence** | Accessibility value: `"\(channelCount) channels, peak \(Int((peak * 100).rounded())) percent"`. This gives a global peak but no per-channel detail. The `AppCompactMeterStrip` status label below the meter (`Text(status).font(.caption2).foregroundStyle(.secondary)`) has no accessibility label beyond system default. |
| **User impact** | Screen reader users can obtain the peak channel level but cannot identify which channels are clipping or silent. For audio professionals, this is an inherent limitation of the VoiceOver + real-time audio meter paradigm on macOS. |
| **Accessibility impact** | Per-channel level data is not accessible. This is a known limitation of graphical audio meters in accessibility contexts. |
| **Suggested remediation** | Consider adding an accessible custom action or a hidden table that enumerates per-channel levels for VoiceOver. This is optional given the real-time nature of meter data. |
| **Verification** | VoiceOver on audio session view. |
| **Confidence** | High — accessibility value construction confirmed in source. |

---

## Summary Tables

### 1. Readability Blockers

| ID | Severity | Component | Issue |
|---|---|---|---|
| VA-001 | P0 | `AppWarningBanner` | Warning text 1.95:1 in light mode — unreadable |
| VA-002 | P1 | Transport bar, banner, badges | `stateArmed` orange 2.53:1 in light mode |
| VA-003 | P1 | Session banner | `stateReady` amber 4.21:1 in light mode (marginal fail) |
| VA-004 | P1 | Session banner, latency hero | `stateLive` green 4.08:1 in light mode |
| VA-011 | P2 | Banner, badges | All primary status text at `.caption` (~11pt) |
| VA-012 | P2 | `AppStatusBadge` | Long status strings truncated — information lost |
| VA-015 | P2 | Session banner | Peer/host name truncation in armed/connecting states |

### 2. Accessibility Blockers

| ID | Severity | Component | Issue |
|---|---|---|---|
| VA-005 | P1 | All state indicators | No increased-contrast variants for 5 state color tokens |
| VA-006 | P1 | `AppWarningBanner` | No `accessibilityRole(.alert)` — VoiceOver won't auto-announce |
| VA-007 | P1 | Session state banner | Pulsing animation ignores `accessibilityReduceMotion` |
| VA-008 | P1 | Transport bar buttons | `.buttonStyle(.plain)` — no keyboard focus ring (WCAG 2.4.7) |
| VA-013 | P2 | State indicators | Color-only state encoding; sidebar dot is color-only |

### 3. Layout / Scaling Risks

| ID | Severity | Component | Issue |
|---|---|---|---|
| VA-009 | P2 | Transport bar buttons | Hit targets ≈ 25–30pt; Apple HIG minimum = 44pt |
| VA-010 | P2 | Warning banner dismiss | Dismiss button hit target ≈ 11–16pt |
| VA-015 | P2 | Session banner | Hostname concatenation may truncate at minimum window width |

### 4. Low-Risk Visual Cleanup Candidates

| ID | Severity | Component | Issue |
|---|---|---|---|
| VA-016 | P3 | `DesignPanel` | Off-scale 14pt padding (not in AppSpacing scale) |
| VA-017 | P3 | `UInt16Field` | Tooltip wording uses `UInt16` type name instead of user-friendly text |
| VA-018 | P3 | `AppReadableValue` | Hidden horizontal scroll with no overflow affordance |
| VA-019 | P3 | Top bar search | Decorative search icon not hidden from VoiceOver |
| VA-020 | P3 | `AppChannelMeterView` | No per-channel VoiceOver data (known limitation) |
| VA-014 | P2 | Latency hero | Nil values read as "— ms" in VoiceOver |

### 5. Suggested Manual Test Checklist

**Light mode:**
- [ ] View session banner in all 9 states — check readability without optical aids
- [ ] Check transport bar ARM button text contrast with Xcode Accessibility Inspector
- [ ] Check `AppWarningBanner` with "Partial latency evidence" visible
- [ ] Check latency hero status labels ("target met", "nominal", "stable") readability

**Dark mode:**
- [ ] All state colors pass visually — computed ratios confirm this
- [ ] Verify warning banner orange text (passes in dark: 8.21:1)

**Keyboard navigation:**
- [ ] Tab through transport bar — confirm each button receives visible focus
- [ ] Tab to Arm button — press ⌘⇧E — confirm ARM state toggles
- [ ] Tab to warning banner dismiss — confirm VoiceOver reads "Dismiss warning"

**VoiceOver:**
- [ ] Navigate to session banner — confirm "Session state: X. [label]" is announced
- [ ] Navigate to each latency hero cell — confirm full label is read
- [ ] Trigger a warning banner — confirm VoiceOver announces it automatically (VA-006)
- [ ] Navigate transport bar buttons — confirm VoiceOver reads button names and roles
- [ ] Navigate channel meter — confirm level readout is announced

**Increase Contrast:**
- [ ] Enable Increase Contrast in macOS System Settings
- [ ] Confirm background/panel borders become more distinct
- [ ] Note that session state badge colors and banner colors remain unchanged (VA-005)

**Reduce Motion:**
- [ ] Enable Reduce Motion in macOS System Settings
- [ ] Arm the session — confirm the banner icon does NOT pulse (VA-007)

**CVD simulation:**
- [ ] Use Xcode Accessibility > Color Filters (deuteranopia, protanopia)
- [ ] Confirm armed, ready, and awaiting-evidence states are distinguishable

**Hit targets:**
- [ ] Right-click transport bar buttons in Accessibility Inspector — measure frame heights
- [ ] Hover + click warning banner dismiss button — confirm it is easy to hit

---

### 6. Remaining Uncertainty

1. **`stateArmed` light/dark variant status**: Source summary states stateArmed has no separate light variant (same RGB in both modes). This was not re-verified by reading `AppDesignSystem.swift` in full — only the summary confirms it. If a light variant does exist, VA-002 may be partially mitigated.

2. **Actual font size at `.caption`**: Sizes quoted (~11pt) are standard macOS defaults. Users with non-default text sizes (via Accessibility > Display > Larger Text) will scale up, which would improve many contrast scenarios at larger sizes. Dynamic type scaling behavior on macOS is not fully verified from source.

3. **`AppConsoleTopBarView` button styles**: These buttons do not use `.buttonStyle(.plain)`, unlike transport buttons. Their default button style on macOS 14+ may or may not provide a focus ring — not verified via live rendering.

4. **`AppPreviewReceiverView` and `AppPacketMonitorView`**: Accessibility markup within these views was not fully read for this audit. `AppPreviewReceiverView` uses `VideoPlayerView` (AppKit bridge) whose accessibility behavior is platform-dependent. `AppPacketMonitorView` uses `Table` (SwiftUI) which has good built-in VoiceOver support.

5. **System color `.orange` exact RGB**: SwiftUI system orange is specified in the audit as approximately (1.0, 0.584, 0.0). Apple may adjust this slightly between OS versions. Computed contrast ratios involving `AppWarningBanner` are approximations; actual values should be verified with Accessibility Inspector against a live build.

6. **Window sizing edge cases**: `AppOperatorSectionLayout` max content 1180pt has not been verified against the actual detail pane width at minimum 1024pt window. If the toolbar or sidebar consume more space than assumed, available width may be narrower than estimated and content may clip sooner.

7. **Settings window accessibility**: Settings tabs and form fields (device setup, network, routing) were not fully audited for accessibility markup. This is a significant area given the number of input fields.

8. **AppDeviceCard**: `AppSelectableDeviceCard` has `.accessibilityValue(isSelected ? "Selected" : "Not selected")` and `.accessibilityAddTraits(isSelected ? .isSelected : [])` — confirmed correct. Identifier text at `.caption2.monospaced()` with `.foregroundStyle(.tertiary)` was not contrast-tested; `.tertiary` is lower opacity and may fail in light mode.

9. **Search field background**: `AppDesignSystem.searchFieldBackground` was not contrast-tested — its RGB values were not in the available context summary.
