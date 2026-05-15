# Mac Port Roadmap

Date: 2026-05-05
Status: short roadmap router after documentation consolidation
Verdict: PARTIAL

This file is the Mac port overview. It is not the active status source. Use
[mac-port/IMPLEMENTATION_COMPANION.md](mac-port/IMPLEMENTATION_COMPANION.md)
for current implementation progress, evidence gates, risk posture, and resume
instructions.

Publication posture: review-only mixed roadmap. Public wording belongs in
[docs/roadmap/](docs/roadmap/README.md) and
[docs/current-state.md](docs/current-state.md).

## Current Direction

The product target is a clean-room, Mac-native, audio-first peer-to-peer AV
system:

- lowest stable audio latency first;
- full-duplex multichannel audio over RME MADI or equivalent hardware;
- direct UDP PCM P2P route as the gold-standard path;
- receiver-side routing/mixing and visible latency profiles;
- video, UI, recording, lighting, QoS, PLC, codecs, and retransmission
  subordinate to audio timing;
- public APIs, public standards, original protocol design, original tests, and
  measured evidence.

## Active Status Source

| Surface | Role |
|---|---|
| [mac-port/IMPLEMENTATION_COMPANION.md](mac-port/IMPLEMENTATION_COMPANION.md) | Single active implementation source of truth. |
| [mac-port/implementation-companions/audio-network.md](mac-port/implementation-companions/audio-network.md) | Core Audio, AudioDeviceIOProc/AUHAL, RME/MADI, UDP PCM, DSCP, PTP, AVB/AoIP, drift, PLC, route diagnostics, and NAT/ISP route work. |
| [mac-port/implementation-companions/video-control.md](mac-port/implementation-companions/video-control.md) | AVFoundation, Blackmagic/ATEM, VideoToolbox, integrated A/V, OSC, sACN, Art-Net, and lighting safety. |
| [mac-port/implementation-companions/app-release-field.md](mac-port/implementation-companions/app-release-field.md) | App shell, recording, packaging, clean-Mac field tests, faster-than-LoLa closure, GOAL.md closure, and G16 parity deferral. |
| [mac-port/implementation-companions/evidence-compliance.md](mac-port/implementation-companions/evidence-compliance.md) | Documentation topology, archive policy, release hygiene, clean-room boundary, and evidence classification. |

## Evidence Verdicts

| Area | Verdict | Rule |
|---|---|---|
| M00, M02, M04 | PASS | Source and local validation surfaces are complete. |
| M01, M03, M05-M15 | PARTIAL | Hardware, route, timing, media, app, package, clean-Mac, and field evidence remains required. |
| MXX multichannel, low-buffer, RX buffering | PARTIAL | Source contracts exist; physical RME/direct/impaired-route evidence remains required. |
| G16 parity deferral | PARTIAL | Deferred ledger exists; parity features need explicit promotion and measured evidence. |
| F10 faster-than-LoLa | PARTIAL | Requires measured F01-F04 plus same-hardware LoLa baseline before PASS. |
| GOAL.md codewise closure | PASS | Codewise source/report/validator surface exists. |
| GOAL.md runtime completion | PARTIAL | Product remains blocked by real hardware, route, video, lighting, signing, notarization, Gatekeeper, clean-Mac, and benchmark evidence. |

## Archive

Superseded milestone plans, report notes, old progress indexes, review docs,
deprecated research, deprecated reverse-engineering notes, and F01-F12
companions are preserved under
[archive/2026-05-05-doc-consolidation/](archive/2026-05-05-doc-consolidation/).
Do not edit archived snapshots as active status.

## Resume here

Resume here: open
[mac-port/IMPLEMENTATION_COMPANION.md](mac-port/IMPLEMENTATION_COMPANION.md),
then close Q001 and the audio/network evidence chain before moving video,
control, app, recording, packaging, field, or faster-than-LoLa claims toward
PASS.

VERDICT: PARTIAL
