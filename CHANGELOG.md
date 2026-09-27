# Changelog

Notable repository changes are recorded here, newest first. Open LoLa does not
publish releases; these entries describe repository state and preparation only.

## Unreleased

- Extracted the external connector families, show-control bridges, and the
  managed process runner from `OpenLolaApplication` into a new
  `OpenLolaIntegrations` SwiftPM target. `OpenLolaCore` re-exports it, so the
  public product surface is unchanged.
- Renamed macOS source folders to match their targets and responsibilities
  (`OpenLolaAppSupport`, `open-lola-app`, `AppShell`, `IntegratedAV`,
  `Evidence/Certification`) and moved Swift tests to `runtimes/macos/Tests`.
- Made `station::profile` the owner of Rust `.ssn` session files, which removes
  the `config` and `station` module cycle; the `.ssn` format is unchanged and
  now pinned by a characterization test.
- The E2E benchmark PASS gate accepts the current
  `docs/benchmark-methodology.md` reference as well as the retired
  `benchmark-e2e-av.md` name.
- Organized the repository around explicit macOS, Rust station, and Linux
  compatibility runtime boundaries.
- Reorganized the Swift implementation by application, session, media,
  transport, integration, evidence, and platform ownership, while preserving
  public SwiftPM products and CLI and report contracts.
- Moved vendored codecs to `third_party`, shared protocol evidence to
  `interop/lola2`, development tooling to `tools`, and the static demo to
  `web/demo`.
- Replaced the Python connector catch-all implementation modules with explicit
  lifecycle, receive, and support responsibilities and removed the obsolete
  root compatibility wrapper surface.
- Removed internal source-ownership, command, route, runtime-path, report
  schema, goal-closure, and evidence-task catalogs from the production CLI.
- Added Swift behavioral tests, a root Cargo workspace, cross-runtime CI lanes,
  and mechanical architecture-boundary verification.

### Proposed `v0.1.0-alpha.1` source alpha

#### Added

- Add the Open LoLa signal-path identity, adaptive SVG marks, reproducible
  social-preview and macOS icon assets, and a compact native Signal Desk
  signature.
- Establish public contribution, security, conduct, issue-reporting, and pull
  request evidence boundaries, plus an explicit support scope, for the
  experimental source alpha.
- Add a public release-status snapshot, a source-only release procedure, and
  reproducible light/dark documentation renders of the real SwiftUI hierarchy.
- Add a deterministic source-documentation gate covering every active
  first-party Swift, Python, shell, PowerShell, C, C-header, and Dockerfile
  source, plus public API and command-entry contracts.

#### Changed

- Standardize public naming on Open LoLa, rename the unpublished Python
  distribution to `open-lola-linux-connector`, and document independent LoLa
  interoperability positioning and attribution.
- Establish a curated public documentation and release-candidate boundary.
- Rework the native Signal Desk around configuration, measured evidence, and a
  persistent guarded transport.
- Harden candidate export against unapproved screenshots and Opus C sources not
  selected by `Package.swift`; reject dirty source state unless an explicit
  inspection-only override is set; make forbidden-path-only changes run CI.
- Make tracked-boundary verification fail closed outside Git, force the
  lower-bound CI lane to execute Python 3.11, and pin third-party checkout
  steps by commit.
- Document the unauthenticated control/media boundary, process-adapter trust
  model, and UltraGrid passphrase limitations.
- Make the Linux synthetic self-test use paired localhost ports instead of
  requiring a nonportable `127.0.0.2` loopback alias.
- Coordinate direct-peer audio/video stop boundaries with a bounded
  `mediaPause` exchange before connected UDP transports close, and distinguish
  peer pause from fatal shutdown in the control loop.
- Refresh the README, platform matrix, Linux onboarding, testing evidence,
  release manifest, third-party inventory, and current-state documentation.
- Replace low-information source comments with concise
  responsibility, invariant, fallback, protocol, and evidence-boundary
  explanations for technical readers.

#### Release posture

- Record that the public product and release verdict remains `PARTIAL`.
- Restrict source-candidate Opus content to selected C files, headers, and the
  four required upstream notice files.

This is preparation for source-alpha collaboration only. It does not announce
or imply that `v0.1.0-alpha.1` has been tagged, pushed, published, supported, or
validated for field deployment.
