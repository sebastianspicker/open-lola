# Documentation

This directory contains the active technical documentation for Open LoLa.
Source code, tests, manifests, and executable help remain authoritative when a
document and the implementation disagree.

## Start here

| Document | Purpose |
|---|---|
| [../README.md](../README.md) | Project scope, installation, configuration, usage, development, and operation. |
| [current-state.md](current-state.md) | Current capabilities, verified local checks, limitations, and release blockers. |
| [source-contracts.md](source-contracts.md) | Module ownership and compatibility boundaries. |
| [testing.md](testing.md) | Automated checks, manual evidence gates, and CI behavior. |
| [RELEASING.md](RELEASING.md) | Candidate export, review, approval, and publication procedure. |
| [release-boundary.md](release-boundary.md) | Repository and source-candidate exclusions. |
| [release-manifest.md](release-manifest.md) | Candidate allowlist and vendor fence. |

## Architecture

| Area | Documents |
|---|---|
| System design | [latency-first-architecture.md](latency-first-architecture.md), [e2e-p2p-session.md](e2e-p2p-session.md), [source-contracts.md](source-contracts.md) |
| Networking and protocol | [p2p-networking.md](p2p-networking.md), [open-lola-protocol.md](open-lola-protocol.md), [mac-to-mac-connection.md](mac-to-mac-connection.md) |
| Audio and routing | [audio-routing.md](audio-routing.md), [audio-rme-madi.md](audio-rme-madi.md), [madi-full-rx-tx.md](madi-full-rx-tx.md), [multichannel-audio-routing.md](multichannel-audio-routing.md), [multichannel-transport.md](multichannel-transport.md), [rme-madi-routing.md](rme-madi-routing.md) |
| Timing and buffering | [latency-budget.md](latency-budget.md), [latency-profiles.md](latency-profiles.md), [rx-buffering.md](rx-buffering.md), [av-sync-and-timing.md](av-sync-and-timing.md) |
| Video and control | [video-blackmagic-atem.md](video-blackmagic-atem.md), [multiple-video-streams.md](multiple-video-streams.md), [lighting-control.md](lighting-control.md) |

## Measurement and evidence

| Document | Purpose |
|---|---|
| [benchmark-methodology.md](benchmark-methodology.md) | Common benchmark rules and evidence classification. |
| [benchmark-audio-latency.md](benchmark-audio-latency.md) | Audio latency measurement matrix. |
| [benchmark-e2e-av.md](benchmark-e2e-av.md) | End-to-end audio and video aggregation. |
| [validation-methodology.md](validation-methodology.md) | Claim and evidence labels. |
| [risk-register.md](risk-register.md) | Active technical and release risks. |
| [open-questions.md](open-questions.md) | Decisions and physical inputs still required. |

## Product and interface

| Document | Purpose |
|---|---|
| [product.md](product.md) | Intended users, operator tasks, scope, and non-goals. |
| [design-system.md](design-system.md) | Signal Desk layout, terminology, colors, controls, and accessibility rules. |

## Compliance and compatibility

| Document | Purpose |
|---|---|
| [clean-room-design-rules.md](clean-room-design-rules.md) | Allowed sources and implementation boundaries. |
| [compatibility-scope.md](compatibility-scope.md) | Supported and unsupported compatibility claims. |
| [reverse-engineering-boundary.md](reverse-engineering-boundary.md) | Publication boundary for compatibility research. |

Linux connector documentation is indexed separately at
[linux_connector/docs/index.md](../linux_connector/docs/index.md).
Repository scripts are documented in
[scripts/README.md](../scripts/README.md).

## Documentation rules

- Describe implemented behavior and identify missing physical evidence.
- Use exact commands, paths, arguments, and environment variables.
- Link to source or tests when a contract is not obvious.
- Keep synthetic, localhost, hardware, and reference-peer evidence distinct.
- Remove obsolete guidance rather than retaining historical instructions.
- Keep private captures, credentials, licensed binaries, and local machine
  details outside the repository.

The local archive is governed by [archive/README.md](../archive/README.md).
Archive payloads are not active documentation or release inputs.

VERDICT: PARTIAL
