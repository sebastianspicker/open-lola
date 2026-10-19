# Documentation

Start with the root [README](../README.md). The documents below cover topics in
more depth.

## Repository and development

| Document | What it covers |
|---|---|
| [Architecture](architecture.md) | Components, Swift target graph, runtime and data flows, state, and invariants |
| [Configuration](configuration.md) | Configuration precedence, storage, environment variables, and trusted inputs |
| [Source contracts](source-contracts.md) | Stable interfaces and how long old forms stay supported |
| [Testing](testing.md) | Local and CI checks, evidence labels, and what the checks cannot prove |
| [Current state](current-state.md) | What is implemented and what still lacks field or release evidence |
| [Releasing](RELEASING.md) | How a source candidate is prepared and approved |
| [Release boundary and manifest](release-boundary.md) | Plain summary of the candidate export policy and vendored-code rules |

## Runtime design

| Area | Documents |
|---|---|
| Session and transport | [Running a session](running-a-session.md), [P2P networking](p2p-networking.md), [Open LoLa protocol](open-lola-protocol.md), [latency-first architecture](latency-first-architecture.md) |
| Audio | [Audio routing](audio-routing.md), [multichannel transport](multichannel-transport.md), [RX buffering](rx-buffering.md), [RME MADI](audio-rme-madi.md), [RME routing](rme-madi-routing.md) |
| Video and control | [Blackmagic/ATEM video](video-blackmagic-atem.md), [lighting and control](lighting-control.md) |
| Performance | [Latency budget](latency-budget.md), [latency profiles](latency-profiles.md), [benchmark methodology](benchmark-methodology.md) |
| User interface | [Signal Desk design system](design-system.md) |
| Clean-room interoperability | [Clean-room design rules](clean-room-design-rules.md), [reverse-engineering boundary](reverse-engineering-boundary.md), [legal notes](../LEGAL.md), [third-party notices](../THIRD_PARTY_NOTICES.md) |

## Components

- [Rust station](../runtimes/rust-station/README.md)
- [Native Linux and migration](linux-migration.md)
- [Packet capture](packet-capture.md)
- [LoLa 2 compatibility corpus](../interop/lola2/README.md)
- [Repository tools](../tools/README.md)

Documentation under `third_party/` belongs to the upstream projects and is not
maintained here.
