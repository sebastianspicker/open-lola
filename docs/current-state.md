# Current state

Date: 2026-08-27
Status: experimental source alpha
Verdict: PARTIAL

Open LoLa now has three explicit runtime boundaries: macOS Swift, the Rust
station, and the Python Linux compatibility connector. The macOS runtime owns
direct-peer A/V sessions, media and transport paths, external integrations,
operator UI, and evidence reports. The Rust station and Python connector are
independent implementations joined through documented wire behavior and the
`interop/lola2` corpus.

First-party code lives under those runtime boundaries, vendored codecs under
`third_party`, tooling under `tools`, and the static demo under `web/demo`.
Public package, command, wire, persistence, and report contracts are listed in
[source-contracts.md](source-contracts.md); module ownership is documented in
[architecture.md](architecture.md).

Locally executable software gates are defined in [testing.md](testing.md).
Their results are source evidence only. They do not establish:

- physical two-peer latency, jitter, loss, or long-run stability;
- RME MADI, Blackmagic, ATEM, DeckLink, or UltraStudio operation;
- closed Windows LoLa, UltraGrid, or JackTrip peer compatibility;
- native Linux low-latency capture and playback;
- authenticated identity, keyed integrity, or replay protection;
- signed distribution, notarization, Gatekeeper acceptance, or clean-machine
  installation; or
- publication approval for vendored JPEG XS material and fixture provenance.

The static Signal Desk demo is fixture-backed. Report validators evaluate
captured facts but do not elevate localhost or synthetic observations into
hardware or field evidence.

VERDICT: PARTIAL
