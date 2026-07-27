# Product Scope

Date: 2026-07-24
Status: experimental source alpha
Verdict: PARTIAL

## Users and operating context

Open LoLa targets musicians, audio engineers, teachers, and production
operators who configure and supervise low-latency networked media sessions on
macOS. Operators need clear route state, bounded transport controls, and an
accurate distinction between configured, observed, and validated behavior.

Open LoLa is an independent interoperability project. It is not affiliated
with or endorsed by the [LoLa system](https://lola.conts.it/), Conservatorio di
Musica Giuseppe Tartini, or GARR.

## Application purpose

The Signal Desk application exposes the macOS runtime through a native SwiftUI
interface. It supports:

- local and peer endpoint configuration;
- route and capability preflight;
- guarded session execution;
- audio-first transport status;
- diagnostics, reports, and evidence review.

The application descriptor is: Configure, run, and verify low-latency media
sessions.

Signal Desk is a workspace label within Open LoLa, not a separate product.
Public prose uses `Open LoLa`; code and command surfaces retain identifiers
such as `OpenLolaCore`, `open-lola`, and `OPEN_LOLA_*`.

## Current interface

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../.github/assets/open-lola-signal-desk-dark.png">
  <img src="../.github/assets/open-lola-signal-desk-light.png" alt="Open LoLa Signal Desk Session workspace showing route readiness, evidence scope, topology, and transport controls">
</picture>

The light and dark images are 1586 by 992 pixel offline renders of the current
SwiftUI view hierarchy with fixed source and synthetic state. They document
layout and appearance only. They are not app-launch, live-media, measured
latency, hardware, or interoperability evidence.

## Interaction requirements

The interface follows these rules:

1. Audio latency, loss, jitter, underruns, and route readiness take priority
   over video, control, and implementation detail.
2. Setup, execution, and evidence review remain part of one visible operating
   path.
3. Source capability, configuration readiness, observed runtime data, packet
   evidence, and validated proof use distinct status labels.
4. Protocol detail, artifacts, logs, and diagnostics appear in contextual
   inspectors and disclosures.
5. Standard macOS navigation, menus, keyboard access, selection, settings, and
   window behavior remain available.
6. Destructive or field-affecting actions require explicit operator intent.

## Accessibility requirements

Every state requires a non-color cue, keyboard access, VoiceOver meaning,
visible focus, increased-contrast support, and a reduced-motion alternative.
Status announcements must avoid unnecessary repetition. Long paths, device
names, peer identifiers, and errors must remain readable without clipping.

## Limitations

The current source and offline renders do not establish:

- a supported application distribution;
- complete keyboard, VoiceOver, contrast, zoom, or reduced-motion validation;
- physical media-device operation;
- measured end-to-end latency;
- reference-peer interoperability;
- signing, notarization, Gatekeeper, or clean-Mac installation.

Implementation details and component rules are documented in
[design-system.md](design-system.md). Current repository-wide evidence is in
[current-state.md](current-state.md).

VERDICT: PARTIAL
