# Open LoLa design system

Status: current macOS source-alpha presentation, Quiet signal

## Purpose and task flow

Open LoLa serves technicians who configure low-latency audiovisual sessions,
operate the run, and inspect its evidence. The macOS interface follows four
stages, all reachable without starting or authorizing execution:

1. **Configure** selects media devices and peer connection settings. The
   existing mode-specific fields, routing, validation, and settings remain.
2. **Check** presents the selected formats and peers in a worksheet, alongside
   local readiness. Configuration is not negotiated peer agreement.
3. **Run** presents the configured signal path, process status, recorded report
   observations, and an explicitly labeled local device preview.
4. **Review** distinguishes process completion from validated runtime evidence
   and links to reports, packet evidence, and another configuration.

Workspaces retains Session, Devices, Routing, Streams, Packet Monitor,
Validation, and Diagnostics. Options offers inventory and report refresh,
appearance, and Settings. The Evidence inspector stays available independently
of the task stage. Detailed topology, the evidence chain, measured latency,
commands, and logs remain available through disclosures, and navigation returns
content to its top.

The bottom transport shelf owns Arm, Start, and Stop, while Dry Run and Validate
remain available in More. Existing start prerequisites, configuration-driven
disarming, runtime input locks, and real-run stop confirmation remain intact.
Navigation never grants execution authority.

## Identity

The public product name remains **Open LoLa**. The live header wordmark uses
lowercase "open lola" and a small yellow marker, and the source-alpha designation
and independent open-source identity stay visible. "Quiet signal" names this
design direction; it is not a separate product.

Rounded lettering and sparse yellow details recall the requested HfMT visual
reference. The application does not use the institution's logo, font assets, or
product branding. The existing bundle identifier and persisted settings are
retained. The decorative `sample[0]` footer is a small technical easter egg and
is hidden from accessibility traversal.

Open LoLa is an independent interoperability project and is not affiliated with
or endorsed by the LoLa project, Conservatorio di Musica Giuseppe Tartini, or
GARR. The established [LoLa system](https://lola.conts.it/) remains a separate
project. This is attribution, not trademark clearance.

The existing app icon and public identity assets under `.github/assets/` are
unchanged by this native interface redesign. Historical Signal Desk screenshots
are earlier offline renders and do not document the current composition.

## Color, type, and spacing

| Role | Light | Dark |
|---|---|---|
| Canvas | Porcelain `#F6F6F3` | Graphite `#121415` |
| Panel | Warm near-white | `#1B1E20` |
| Interaction ink | `#121415` | `#F6F6F3` |
| Decorative signal | `#FFE200` | `#FFE200` |

Yellow is a marker, not small text or evidence of health. Semantic colors keep
explicit words and icons. Green belongs to evidence-backed outcomes; process
activity and configured routes do not imply healthy media. The palette defines
increased-contrast variants, and tests check semantic badge and warning contrast
against the 4.5:1 normal-text threshold. That check does not replace a complete
accessibility review.

Native system typography keeps controls familiar. The wordmark uses the rounded
system face. Workspace headings establish hierarchy, and SF Mono is reserved for
formats, endpoints, exact values, and timing. Spacing uses 4/8/12/16/24/32-point
steps. Open worksheets, tonal surfaces, 8-point corners, and hairline separators
provide grouping without ornamental gradients or glow.

## Adaptation and interaction states

The native desktop window retains its minimum supported size. Check, Run, and
Review use two columns when space permits and stack in narrower windows or
alongside the inspector. The transport switches to its compact form before
controls clip, and labeled Arm, Start/Stop, and More remain available. Long
content scrolls independently of the transport. This is a desktop design, not a
mobile web interface.

Native buttons, menus, pickers, and fields retain keyboard traversal, focus,
labels, and selection behavior. The phase rail exposes the selected step to
assistive technology. Appearance is System, Light, or Dark through Options and
applies to the main, preview, and settings windows. Existing application command
shortcuts remain available, and yellow is never the only indicator of selection.

- Loading uses existing inventory and execution progress state.
- Missing devices and incomplete configuration retain recovery actions and
  disabled-start explanations.
- Missing report observations read "Not measured." An inactive preview explains
  its current state rather than showing a stock image.
- Errors retain the controller's detailed failure and logs. Failed or stopped
  processes retain their actual exit state.
- Process success and validated evidence are separate results. Loaded report
  metrics are labeled as recorded observations, not live telemetry.
- Runtime-locked inputs remain readable. Stop keeps the existing confirmation
  for a real run. Reduce Motion does not remove access to any information.

## Verification scope

The implementation is SwiftUI/AppKit presentation over existing application
controllers. Generated references guide composition; generated text, controls,
room images, and invented measurements are not runtime assets.

`OpenLolaAppSupportTests` checks navigation, start prerequisites, contrast, and
optional deterministic rendering. Set `OPEN_LOLA_UI_RENDER_DIR` to an absolute
external directory when running its screenshot tests to produce offline PNGs.
Those images exercise the actual view hierarchy with isolated synthetic state.
They do not prove live capture, peer exchange, physical latency, VoiceOver
usability, signing, distribution, or hardware interoperability.
