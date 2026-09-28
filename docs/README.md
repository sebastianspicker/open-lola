# Documentation

The root [README](../README.md) is the entry point for users and contributors.
The documents below go deeper on subjects that need their own detail.

## Repository and development

| Document | Audience and purpose |
|---|---|
| [Architecture](architecture.md) | Component boundaries, Swift target graph, runtime/data flows, state, and invariants |
| [Configuration](configuration.md) | Configuration precedence, persistence, environment variables, and trusted inputs |
| [Source contracts](source-contracts.md) | Public compatibility surfaces and migration horizons |
| [Current state](current-state.md) | Implemented scope and unresolved field/release evidence |
| [Releasing](RELEASING.md) | Source-candidate procedure and approval sequence |
| [Release boundary and manifest](release-boundary.md) | Source-candidate path and codec boundaries |

## Runtime design

| Area | Maintained references |
|---|---|
| Session and transport | [P2P networking](p2p-networking.md), [Open LoLa protocol](open-lola-protocol.md), [latency-first architecture](latency-first-architecture.md) |
| Audio | [Audio routing](audio-routing.md), [multichannel transport](multichannel-transport.md), [RX buffering](rx-buffering.md), [RME MADI](audio-rme-madi.md), [RME routing](rme-madi-routing.md) |
| Video and control | [Blackmagic/ATEM video](video-blackmagic-atem.md), [lighting and control](lighting-control.md) |
| Performance evidence | [Latency budget](latency-budget.md), [latency profiles](latency-profiles.md), [benchmark methodology](benchmark-methodology.md) |
| Product interface | [Signal Desk design system](design-system.md) |
| Publication-safe interoperability | [Clean-room design rules](clean-room-design-rules.md), [reverse-engineering boundary](reverse-engineering-boundary.md), [legal notes](../LEGAL.md), [third-party notices](../THIRD_PARTY_NOTICES.md) |

## Component-specific operation

These live beside the component they describe:

- [Rust station](../runtimes/rust-station/README.md)
- [Native Linux and migration](linux-migration.md)
- [Packet capture](packet-capture.md)
- [Repository tools](../tools/README.md)
