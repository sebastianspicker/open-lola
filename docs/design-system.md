# Open LoLa design system

This describes the current macOS source-alpha interface. The design direction is
called "Quiet signal".

## Task flow

The interface is for technicians who configure a low-latency audiovisual session,
run it, and inspect the results. It has four stages. You can move between them
without starting or authorizing a run.

1. **Configure**: pick media devices and peer connection settings. Mode-specific
   fields, routing, validation, and settings work as before.
2. **Check**: a worksheet of the selected formats and peers, next to local
   readiness. This shows your configuration, not what the peer has agreed to.
3. **Run**: the configured signal path, process status, values recorded in the
   report, and a clearly labeled local device preview.
4. **Review**: shows whether the process finished and, separately, whether the
   report validated. Links to reports, packet evidence, and another
   configuration.

Workspaces holds Session, Devices, Routing, Streams, Packet Monitor, Validation,
and Diagnostics. Options has inventory and report refresh, appearance, and
Settings. The Evidence inspector is available in every stage. Topology, the
evidence chain, measured latency, commands, and logs sit behind disclosures.
Navigating to a page scrolls it to the top.

The transport shelf at the bottom holds Arm, Start, and Stop; Dry Run and
Validate are under More. Start prerequisites, disarming on configuration change,
input locks during a run, and the stop confirmation for real runs are unchanged.
Navigating never arms or starts anything.

## Identity

The product name is **Open LoLa**. The header wordmark reads "open lola" in
lowercase with a small yellow marker, and the source-alpha label and independent
open-source identity stay visible. "Quiet signal" is the name of the design
direction, not a separate product.

Rounded lettering and sparse yellow details nod to the HfMT visual reference that
was requested. The app does not use the institution's logo, fonts, or branding.
The bundle identifier and persisted settings are unchanged. The `sample[0]`
footer is a small easter egg and is hidden from accessibility.

Open LoLa is an independent interoperability project. It is not affiliated with
or endorsed by the LoLa project, Conservatorio di Musica Giuseppe Tartini, or
GARR. The [LoLa system](https://lola.conts.it/) is a separate project. Naming it
here is attribution, not trademark clearance.

This redesign does not change the app icon or the identity assets under
`.github/assets/`. The older Signal Desk screenshots are offline renders of an
earlier layout.

## Color, type, and spacing

| Role | Light | Dark |
|---|---|---|
| Canvas | Porcelain `#F6F6F3` | Graphite `#121415` |
| Panel | Warm near-white | `#1B1E20` |
| Interaction ink | `#121415` | `#F6F6F3` |
| Decorative signal | `#FFE200` | `#FFE200` |

Yellow is a marker only. Do not use it for small text or to signal health.
Status colors always come with a word and an icon. Green means a validated
result; a running process or a configured route is not green. The palette has
increased-contrast variants, and the design-system code computes the contrast of
status and warning colors against the 4.5:1 normal-text threshold. That is not a
full accessibility review.

Controls use the native system font. The wordmark uses the rounded system face.
Workspace headings set the hierarchy, and SF Mono is used only for formats,
endpoints, exact values, and timing. Spacing steps are 4, 8, 12, 16, 24, and 32
points. Grouping comes from open worksheets, tonal backgrounds, 8-point corners,
and hairline separators, without gradients or glow.

## Layout and interaction states

The window keeps its minimum supported size. Check, Run, and Review use two
columns when there is room and stack when the window is narrow or the inspector
is open. The transport switches to a compact form before its controls clip;
Arm, Start/Stop, and More stay labeled. Long content scrolls separately from the
transport. This is a desktop layout, not a mobile web design.

Native buttons, menus, pickers, and fields keep keyboard navigation, focus,
labels, and selection. The phase rail exposes the selected step to assistive
technology. Options sets appearance to System, Light, or Dark for the main,
preview, and settings windows. Existing command shortcuts still work, and
selection is never shown by yellow alone.

- Loading uses the existing inventory and run progress state.
- Missing devices and incomplete configuration keep their recovery actions and
  explain why Start is disabled.
- Report values that are missing read "Not measured." An inactive preview says
  why it is inactive instead of showing a stock image.
- Errors keep the controller's detailed failure and logs. Failed or stopped
  processes show their actual exit state.
- Process success and validated evidence are shown as separate results. Metrics
  loaded from a report are labeled as recorded values, not live telemetry.
- Inputs locked during a run stay readable. Stop still asks for confirmation on
  a real run. Reduce Motion does not hide any information.

## Verification

The interface is SwiftUI/AppKit on top of the existing application controllers.
Generated reference images guided the layout; their text, controls, room images,
and invented measurements are not app assets.

Tests whose sources are not published cover the start-gate policy and the
run-failure message text. No test renders views, checks contrast or navigation,
or reads `OPEN_LOLA_UI_RENDER_DIR`. Check layout, contrast, and navigation by
hand in the running app with synthetic state, and keep screenshots outside the
repository. Neither the tests nor that manual check show that live capture, peer
exchange, physical latency, VoiceOver, signing, distribution, or hardware
interoperability work.
