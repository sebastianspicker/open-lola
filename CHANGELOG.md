# Changelog

Notable product changes are recorded here, newest first.

## Unreleased

- Redesigned the static `web/demo` walkthrough ("Patch sheet"): token-based
  styles aligned with the native porcelain, graphite, and yellow-marker
  palette, pencil-versus-ink evidence styling, a phone index strip instead of a
  drawer, and re-rendered tour images. Behavior, ids, and fixture data are
  unchanged.
- Extracted the external connector families, show-control bridges, and the
  managed process runner from `OpenLolaApplication` into a new
  `OpenLolaIntegrations` SwiftPM target. `OpenLolaCore` re-exports it, so the
  public product surface is unchanged.
- Renamed macOS source folders to match their targets and responsibilities
  (`OpenLolaAppSupport`, `open-lola-app`, `AppShell`, `IntegratedAV`,
  `Evidence/Certification`).
- Made `station::profile` the owner of Rust `.ssn` session files, which removes
  the `config` and `station` module cycle; the `.ssn` format is unchanged.
- Organized the repository around explicit macOS, Rust station, and Linux
  compatibility runtime boundaries.
- Reorganized the Swift implementation by application, session, media,
  transport, integration, evidence, and platform ownership, while preserving
  public SwiftPM products and CLI and report contracts.
- Moved the static demonstration to `web/demo` and retained packaging tools
  under `tools`.
- Replaced the Python connector catch-all implementation modules with explicit
  lifecycle, receive, and support responsibilities and removed the obsolete
  root compatibility wrapper surface.
- Removed internal source-ownership, command, route, runtime-path, report
  schema, goal-closure, and evidence-task catalogs from the production CLI.
- Added a root Cargo workspace and cross-runtime build lanes.
- Kept raw audio and video paths available while leaving Opus and JPEG XS
  codec-backed selections unavailable in the public source.

### Proposed `v0.1.0-alpha.1` source alpha

#### Added

- Add the Open LoLa signal-path identity, adaptive SVG marks, reproducible
  social-preview and macOS icon assets, and a compact native Signal Desk
  signature.
- Establish public contribution, security, conduct, issue-reporting, and pull
  request evidence boundaries, plus an explicit support scope, for the
  experimental source alpha.
- Add a source-only release procedure and reproducible light/dark documentation
  renders of the real SwiftUI hierarchy.

#### Changed

- Standardize public naming on Open LoLa and document independent LoLa
  interoperability positioning and attribution.
- Establish a curated public documentation and release-candidate boundary.
- Rework the native Signal Desk around configuration, measured evidence, and a
  persistent guarded transport.
- Keep source-candidate export outside the checkout and reject dirty source
  state unless an explicit inspection-only override is set.
- Document the unauthenticated control/media boundary, process-adapter trust
  model, and UltraGrid passphrase limitations.
- Make the Linux synthetic self-test use paired localhost ports instead of
  requiring a nonportable `127.0.0.2` loopback alias.
- Coordinate direct-peer audio/video stop boundaries with a bounded
  `mediaPause` exchange before connected UDP transports close, and distinguish
  peer pause from fatal shutdown in the control loop.
- Refresh the README, platform matrix, Linux onboarding, release manifest,
  third-party inventory, and current-state documentation.
- Replace low-information source comments with concise
  responsibility, invariant, fallback, protocol, and evidence-boundary
  explanations for technical readers.

#### Release posture

- Record that the public product and release verdict remains `PARTIAL`.
- Exclude redistributed Opus and JPEG XS implementations from the public source.

The source alpha does not imply field deployment validation.
