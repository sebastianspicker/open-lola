# Signal Desk demo design brief

Scope: the static browser walkthrough in `web/demo`. The native SwiftUI surface
is described in `docs/design-system.md` and is not changed by this brief.

## Product summary

Open LoLa is an independent, source-alpha toolkit for running and measuring
low-latency audiovisual sessions between two sites. It ships a macOS operator
app and CLI and a Rust station for Windows and Linux. What sets it apart is how
strictly it keeps evidence honest. The repository separates *configured intent*
from *observed measurement* from *validated report*. It refuses to promote a
synthetic, localhost or offline result into field evidence, and every document
ends with a `VERDICT:` line.

The web demo is a fixture-backed rehearsal of the operator surface ("Signal
Desk"). It runs in any browser, changes only local interface state, and cannot
reach devices, peers or the network. Its job is to let someone understand the
operator workflow and the evidence boundary before building the native app.

### Key journeys (in order of importance)

1. **Rehearse a run.** Open Setup → stage a peer and devices → check readiness →
   Arm → Start → Stop → review. The persistent transport shelf and the
   `Setup → Ready → Live → Review` phase rail carry this journey.
2. **Understand the evidence boundary.** Session, Monitor and Evidence show that
   audio p99, loss and jitter stay *Not measured*, and that the historical
   validated sample is not about this run.
3. **Rehearse failure.** Setup's scenario selector produces the unavailable-input
   and empty-inventory states. An invalid peer address produces a validation
   error.
4. **See the native app.** The Screenshots workspace shows offline renders and
   links each card to its interactive workspace.

**Moment of value:** the operator presses Start, sees the session go Live, and
reads, at the point where a lesser tool would show a green number, that nothing
is measured and why. At that point trust is either earned or lost.

## Audience

**Primary: the session technician.** An audio or AV engineer at a conservatory,
music university or research network who runs networked music performance
between two halls. They patch MADI and Dante, read RME TotalMix and console
input lists, and have been burned by "connected" meaning "not actually passing
audio". They set buffer sizes by ear and by milliseconds.

- **Goals:** a predictable path from patch to sound, a clear arm/start
  discipline, and numbers they can defend in a post-mortem.
- **Anxieties:** a false green light, an accidental live start, and settings
  that silently change mid-run.
- **Distrusts:** marketing gloss, unexplained percentages, dashboards that show
  numbers nobody measured, and consumer "magic".
- **Quality signals for them:** exact units and sample counts, tabular numerals,
  monospaced identifiers, explicit states, labels like a patch list, and
  restraint. The physical reference is a well-kept input list taped to a
  console, not a SaaS landing page.

**Secondary:** musicians and researchers evaluating the project, and
contributors reading the source. They need the same honesty with less jargon on
the first screen.

## Brand traits

| Trait | Not tipping into |
|---|---|
| Exact: units, sample counts and states are named | pedantic walls of caveats |
| Candid: says "Not measured" plainly and proudly | apologetic or alarmist |
| Calm under pressure: a show is about to start | sleepy or low-contrast |
| Crafted like a tool: rules, legends, tabular numbers | skeuomorphic hardware kitsch |
| Independent and academic: open source from the music world | amateurish or hobbyist |

## Market observations

These notes come from product knowledge. No live browsing was done in this pass.

- **LoLa (reference system):** a sparse academic site. Its credibility comes
  from institutions, not design.
- **JackTrip / Virtual Studio:** a consumer-friendly web app with dark surfaces,
  saturated accents and rounded cards. It optimises for musicians joining a
  room.
- **SonoBus:** a dark plug-in aesthetic with green meters, dense controls and
  hobbyist warmth.
- **UltraGrid GUI / Dante Controller / RME TotalMix:** grey desktop utilities
  with matrix grids, small type and hardware metaphors. They are trusted but
  unloved.
- **Category conventions to honor:** meters and numeric readouts with units, a
  patch/route mental model, explicit arm → start → stop transport, and
  monospaced addresses.
- **Conventions to break:** dark "studio" theming by default, green as a
  synonym for "connected", decorative meters that imply live signal, and dense
  grey utility chrome with 9 px labels.

## Current state

- **Stack:** static HTML, two stylesheets (`styles.css`, `workflow.css`), and
  one vanilla script (`app.js`). There is no build step or dependency.
  `make web-lint` runs `node --check`. The 600-line file budget applies to all
  three file types.
- **Assets:** the Open LoLa signal-path mark (ink endpoints, cobalt path) and
  the app icon. Both are listed in the duplication ledger.
- **Worth keeping:** the mark (brand equity), the four-workspace structure
  that mirrors the native app, the phase rail, the persistent transport, the
  inspector, the relentless "Not measured" honesty, and the fixture
  addresses from RFC 5737.
- **Weaknesses:**
  - The visual language is a generic macOS utility with a blue accent. It no
    longer matches the native "Quiet signal" design (porcelain, graphite and
    a yellow marker).
  - `workflow.css` overrides `styles.css` in several layers: three redefinitions
    of `--subtle` and two grid templates. Some rules target markup that no
    longer exists (`.metric-hero`, `.proof-stack`).
  - Labels are 7–9 px in several places, and the amber "SIMULATED" text on
    grey buttons sits below AA contrast.
  - "Simulated" appears six times per screen (banner, chip, three button
    captions, footer), which dulls it.
  - The Screenshots copy says "as it appears in the app" about an earlier render
    that `docs/design-system.md` calls historical.
  - Mobile uses a hamburger drawer to hide five destinations, which wastes a tap
    on the most common action.
- **Constraints:**
  - Keep every id, `data-*` hook and template id that `app.js` binds to.
  - Keep behavior: gating, revision-guarded readiness, history and hash routing,
    Escape handling, and live regions.
  - The demo must make no network requests, so no web-font CDN is allowed.
  - Keep the files under 600 lines each. Keep WCAG 2.2 AA and reduced motion.
  - README links the tour PNGs, which must be re-rendered.

## Assumptions log

| Assumption | Evidence | Confidence |
|---|---|---|
| The deliverable is the web demo, not the SwiftUI app. | The brief asks for a "website"; `web/demo` is the only web surface; this host has no Xcode to build SwiftUI | high |
| The primary audience is session technicians at music institutions. | Vocabulary (MADI, p99, arm), the HfMT visual reference in `docs/design-system.md`, LoLa's conservatory origin | high |
| The demo should align with the native "Quiet signal" tokens rather than invent a new identity. | `docs/design-system.md` defines porcelain, graphite and a `#FFE200` marker as the product's identity; the demo still uses the pre-redesign blue | high |
| Light is the primary appearance; dark follows the system. | The native app defaults to System; technicians often work in lit control rooms; both renders exist in the README | medium |
| Use no vendored web fonts. Type personality comes from a deliberate system sans / system monospace pairing. | The demo claims no network access; hosted Google Fonts carry a known German GDPR ruling (LG München, 2022); vendoring font binaries needs a third-party notice review the user owns; the native app uses SF and SF Mono | medium |
| Collapsing the per-button "SIMULATED" captions into one transport legend keeps honesty intact. | The group already has `aria-label="Simulated run controls"`; the top strip and phase copy repeat the fact | medium |
| Visitors arrive from the README on desktop; mobile visitors are evaluators, not operators. | The operator app is desktop-only (`docs/design-system.md`: "not a mobile web interface") | medium |
| The HfMT reference allows a yellow marker, but no HfMT logo, font or name in UI. | `docs/design-system.md` identity section | high |

## Design direction

### Direction A: Patch sheet (chosen)

**Concept.** The Signal Desk is drawn as the paper worksheet that every show
technician already trusts: the input list or patch sheet taped next to the
console. Its rows are ruled, its legends are typed in monospace, and a strip of
yellow scribble tape marks what is live now. The sheet also carries the
product's central idea, **pencil versus ink**:

- Staged configuration is drawn in *pencil*: dashed rules and secondary ink.
- Observed values are in *ink*: solid rules and full ink.
- Validated evidence is *signed off*: a solid green rule and the word "Passed".
- "Not measured" is an empty ink slot, a dashed box waiting for a number.

This encodes the repository's evidence chain (Source → Planned → Observed →
Validated) in line style. Color is not needed to carry it.

- **Typography.** Two families, both local:
  - A system monospace (`ui-monospace`, SF Mono, Cascadia Mono, JetBrains Mono,
    DejaVu Sans Mono) is the *legend voice*. It sets uppercase engraved labels,
    channel numbers, addresses and every value. Tabular numerals are always on.
  - The system sans sets prose and headings, at semibold with tight tracking
    for headings.

  The personality comes from the contrast: the sans says what to do, the mono
  says what is true. The scale is 11 / 12 / 13 / 15 / 19 / 24 / 34 px, with no
  text below 11 px. Legends are 11 px mono uppercase with +0.08 em tracking.
- **Color.**

  | Role | Light | Dark |
  |---|---|---|
  | Paper (canvas) | `#F6F6F3` porcelain | `#121415` graphite |
  | Sheet (panel) | `#FCFCFA` | `#1A1D1F` |
  | Ink | `#121415` | `#F2F2EE` |
  | Ink 2 / Ink 3 | secondary / tertiary, both AA | secondary / tertiary, both AA |
  | Rule / Rule strong | hairline / structural | hairline / structural |
  | Tape `#FFE200` | current phase, current workspace, focus halo, always with ink text | same |
  | Pass (green) | validated evidence only | validated evidence only |
  | Fault (red) | validation errors and blocked scenarios only | same |

  No blue appears anywhere except inside the unchanged logo mark.
- **Layout.** The desktop shell mirrors the native app: index, sheet and
  inspector, with a transport shelf. The workspace is a single sheet column
  (maximum 60 rem) of *ruled sections*, not floating cards. Sections are divided
  by full-width rules with a legend in the margin, as on a printed form. Density
  is medium-high: 8 px base, 4/8/12/16/24/32/48 steps.
- **Motion.** Motion is almost none:
  - The tape marker slides between phases (transform, 180 ms).
  - The pencil route dashes crawl while a simulation is Live, which is the only
    ambient motion. It means "simulated signal", never "measured".
  - The toast rises 8 px.
  - With `prefers-reduced-motion`, all of this stops.
- **Signature details.**
  1. The empty ink slot: "Not measured" rendered as a dashed value box with the
     unit still printed (`— ms`). The absence reads as designed rather than
     broken.
  2. Scribble tape: a yellow strip under the current phase and workspace, and
     as the focus halo. It is the product's only saturated color.
- **Versus category.**
  - It is light, paper-like and typographic, where competitors are dark studio
    themes.
  - Green is reserved for signed-off evidence, never for "connected".
  - No decorative meters appear. The fixture meters are labeled and drawn in
    pencil.
- **Refuses.** Gradients, glow, shadows as depth (hairlines only), rounded cards
  (a 2 px radius on inputs and buttons only), icon fonts, and any number
  without a source.

### Direction B: Graticule

**Concept.** Every surface sits on an oscilloscope's millimetre graticule.
Session is a large timing plot with the p99 target band. Values are readouts
pinned to the grid, and the phase rail is a time axis. The palette is dark
graphite with one trace colour. Numerals use a condensed mono at large sizes,
and prose uses a humanist sans.

- **Signature:** the target-band plot, and a cursor readout that snaps to the
  grid.
- **Versus category:** more rigorous than competitors' meters.
- **Refuses:** skeuomorphic knobs.
- **Rejected because:** a graticule *promises* measurement. In a demo where
  every value is Not measured, the design would be an empty scope, and the
  empty state would become the whole product. Dark-with-one-trace also drifts
  toward the neon-on-dark cliché.

### Direction C: Rack units

**Concept.** Each workspace is a 19-inch rack. Sections are 1U or 2U panels
with engraved legends, screw-hole margins and LED state dots. The transport is
a hardware button row.

- **Palette:** anodised light grey and black, with the tape yellow as the panel
  label strip.
- **Typography:** a DIN-like system grotesk for legends.
- **Signature:** the rack-unit rhythm (every section height a multiple of 44 px)
  and LED dots with a text equivalent.
- **Rejected because:** hardware mimicry tips quickly into kitsch. The fixed
  unit rhythm fights the reading-heavy evidence copy, and it collapses poorly on
  a 390 px screen.

### Choice

Patch sheet fits all five traits.

- **Exact, candid:** pencil versus ink makes the evidence boundary visible
  without extra words.
- **Calm:** light paper, one accent, no ambient motion unless Live.
- **Crafted:** mono legends and ruled rows.
- **Academic:** it reads like a printed form, not a product launch.

It also converges with the native Quiet signal tokens, so the demo stops
contradicting the app it demonstrates. **Traded away:** spectacle. There is no
hero visualization, and the first impression relies on typography and rules.
Screenshots may look quieter than a competitor's dark studio UI. That is the
intended positioning.

## Mobile

At 390 px, the demo is a phone rehearsal, not a shrunken desk:

- The five destinations become a horizontal index strip under the title bar,
  with no hamburger.
- The inspector's facts move into the flow as a compact "Session sheet" summary
  (desktop keeps the side inspector).
- The transport shelf becomes a two-row dock: state line, then three equal
  buttons.
- Tables scroll inside their own frame, and the page never scrolls sideways.
