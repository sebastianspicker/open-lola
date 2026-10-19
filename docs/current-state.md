# Current state

Last updated 2026-09-08. Open LoLa is an experimental source alpha.

The repository has two independent runtimes:

- a macOS SwiftPM app and CLI covering direct-peer sessions, media, external
  integrations, report validation, and the operator interface;
- a Windows and native Linux Rust station with PortAudio, XIMEA or Media
  Foundation (USB/UVC webcams), and ALSA/V4L2 backends, diagnostic media you
  select by hand, and an optional egui UI.

Both runtimes use the versioned synthetic regression corpus in `interop/lola2`.
It is not a packet capture from LoLa or a current reference peer. The Rust
station and the macOS connector replay it in tests whose sources are not
published. Vendored codecs live in `third_party`, repository scripts in `tools`,
and the fixture-backed browser walkthrough in `web/demo`.

## What the source implements

- direct-peer session negotiation;
- UDP audio and video transport;
- receive buffering and clock drift models;
- report validation;
- the Rust LoLa 2 station;
- native Linux device access;
- offline decoding of packet captures, with size limits.

Python is used for repository tooling. The local bundle, native helper, and
external proof scripts are for testing, not deployment.

The macOS app follows Configure, Check, Run, Review, with a transport shelf that
stays visible. Check summarizes the current configuration. Run shows process
status, local device preview, and recorded values separately. Workspaces gives
access to media, routing, packets, validation, and diagnostics. Light, dark, and
system appearance follow [design-system.md](design-system.md). Arming, input
locks, stop confirmation, and report validation still apply. The local preview
does not show that peer video was received.

## What has not been shown

The local checks in [testing.md](testing.md) do not show:

- physical two-peer latency, jitter, loss, or long-run stability;
- RME MADI, Blackmagic, ATEM, DeckLink, UltraStudio, XIMEA, ASIO, or Npcap
  working in a production setup;
- interoperability with a current reference Windows LoLa, UltraGrid, or
  JackTrip peer;
- native Linux capture and playback latency in production;
- peer authentication, replay protection, or media integrity and
  confidentiality;
- signed distribution, notarization, Gatekeeper acceptance, or installation on
  a clean machine;
- approval to publish the exact vendored codec and fixture set.

The macOS bundle scripts use ad-hoc signing, and the static UI images are
offline renders. Report validators check the values they are given. They cannot
turn synthetic, localhost, source, or historical results into field evidence.

See [architecture.md](architecture.md) for code layout,
[configuration.md](configuration.md) for runtime inputs,
[source-contracts.md](source-contracts.md) for compatibility promises, and
[RELEASING.md](RELEASING.md) for what goes into a source release.

VERDICT: PARTIAL
