# Implementation Companions

Date: 2026-05-05
Status: four active domain companions under the canonical implementation handoff
Verdict: PARTIAL

The single source of truth is
[../IMPLEMENTATION_COMPANION.md](../IMPLEMENTATION_COMPANION.md). This folder
contains only the active companion files needed to keep that canonical handoff
readable. The previous F01-F12 finding-level companions were moved to
[../../archive/2026-05-05-doc-consolidation/mac-port/implementation-companions/](../../archive/2026-05-05-doc-consolidation/mac-port/implementation-companions/).

## Active Companions

| File | Domain |
|---|---|
| [audio-network.md](audio-network.md) | Audio hardware, realtime engine, UDP PCM route, diagnostics, drift/PLC, AoIP, and NAT/ISP evidence. |
| [video-control.md](video-control.md) | Blackmagic/ATEM capture, video transport, integrated A/V, OSC, sACN, Art-Net, and lighting safety. |
| [app-release-field.md](app-release-field.md) | App shell, recording, packaging, clean-Mac field tests, faster-than-LoLa closure, runtime closure, and G16 parity deferral. |
| [evidence-compliance.md](evidence-compliance.md) | Documentation topology, archive policy, release hygiene, clean-room boundary, and source/test/doc evidence crosswalk. |

## Operating Rule

Audio is the latency gate. Video, UI, recording, lighting, QoS, PLC, codecs,
and retransmission may support the workflow only when they preserve default
audio playout latency and degrade before audio timing changes.

## Resume here

Resume here: read [../IMPLEMENTATION_COMPANION.md](../IMPLEMENTATION_COMPANION.md),
then open the one domain companion matching the current task. Do not edit the
archived F01-F12 snapshots as live status.

VERDICT: PARTIAL
