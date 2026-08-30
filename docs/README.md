# Documentation

Start with [architecture.md](architecture.md) for runtime ownership and
dependency direction, [source-contracts.md](source-contracts.md) for preserved
external surfaces, and [testing.md](testing.md) for executable gates.

Operational and domain references:

- direct-peer networking: [e2e-p2p-session.md](e2e-p2p-session.md) and
  [p2p-networking.md](p2p-networking.md);
- audio and latency: [latency-first-architecture.md](latency-first-architecture.md),
  [audio-routing.md](audio-routing.md), [rx-buffering.md](rx-buffering.md), and
  [madi-full-rx-tx.md](madi-full-rx-tx.md);
- video and control: [multiple-video-streams.md](multiple-video-streams.md),
  [video-blackmagic-atem.md](video-blackmagic-atem.md), and
  [lighting-control.md](lighting-control.md);
- evidence: [validation-methodology.md](validation-methodology.md),
  [benchmark-methodology.md](benchmark-methodology.md), and
  [current-state.md](current-state.md);
- release boundary: [release-boundary.md](release-boundary.md),
  [release-manifest.md](release-manifest.md), and [RELEASING.md](RELEASING.md).

Linux connector documentation lives beside its runtime at
`runtimes/linux-compat-connector/linux_connector/docs/`.
