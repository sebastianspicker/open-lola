# Current state

Date: 2026-09-08
Status: experimental source alpha
Verdict: PARTIAL

Open LoLa contains two independent runtime implementations:

- a modular macOS SwiftPM app and CLI with direct-peer, media, integration,
  evidence, and operator-interface source;
- a Windows and native Linux Rust station with PortAudio/XIMEA and ALSA/V4L2
  backends, explicit diagnostic media, and optional egui presentation.

The runtimes share documented protocol conventions but no runtime code. The
public source omits the synthetic regression corpus and redistributed Opus and
JPEG XS implementations. Packaging tools remain under `tools`, and the
fixture-backed browser walkthrough under `web/demo`.

The current source defines direct-peer session negotiation, UDP audio and video
transport, buffering and drift models, report validation, Rust LoLa 2 station
behavior, native Linux device APIs, and bounded offline capture decoding. Local
bundle helpers are validation surfaces, not a deployment platform.

The macOS app follows Configure → Check → Run → Review with a persistent
transport shelf. Check summarizes the current configuration; Run separates
process status, local device preview, and recorded observations. Workspaces keeps
media, routing, packets, validation, and diagnostics accessible, while Configure
separates media selection from peer connection fields. Light, dark, and system
appearance use the Quiet signal design described in
[design-system.md](design-system.md). Explicit arming, input locks, stop
confirmation, and report validation requirements remain in effect. Local preview
is not received peer-video proof.

Local build checks do not
establish:

- physical two-peer latency, jitter, loss, or long-run stability;
- RME MADI, Blackmagic, ATEM, DeckLink, UltraStudio, XIMEA, ASIO, or Npcap
  operation on a claimed production configuration;
- current interoperability with a reference Windows LoLa, UltraGrid, or
  JackTrip peer;
- native production Linux capture/playback latency;
- authenticated identity, replay protection, or media integrity and
  confidentiality;
- signed distribution, notarization, Gatekeeper acceptance, or clean-machine
  installation; or
- publication approval for physical or binary deployment claims.

The macOS bundle helpers use ad-hoc signing, and the static UI images are
offline renders. Report validators evaluate supplied observations but cannot
upgrade synthetic, localhost, source, or historical evidence into field proof.

See [architecture.md](architecture.md) for ownership,
[configuration.md](configuration.md) for runtime inputs,
[source-contracts.md](source-contracts.md) for compatibility surfaces, and
[RELEASING.md](RELEASING.md) for the source-candidate boundary.

VERDICT: PARTIAL
