# Video And Control Companion

Date: 2026-05-05
Status: active domain companion for video, OSC, ATEM, and lighting work
Verdict: PARTIAL

Canonical status lives in
[../IMPLEMENTATION_COMPANION.md](../IMPLEMENTATION_COMPANION.md). This file
collects the video and control details previously spread across M08-M12,
F05-F08, report notes, and old milestone files.

## Scope

Covered lanes:

- M08 Blackmagic/ATEM-first capture, AVFoundation fallback, and Q007.
- M09 video transport, raw/intra-frame packetization, VideoToolbox policy, and
  degradation rules.
- M10 integrated A/V runtime.
- M11 OSC cue loop, ATEM read-only control, and Q008.
- M12 sACN, Art-Net, lighting fixture safety, OLA/QLC+ workflow, and Q009.

## Current Source Surfaces

| Area | Source-level state | PASS blocker |
|---|---|---|
| Capture | Blackmagic/ATEM-first policy, AVFoundation inventory, test-pattern source, latest-frame queue, video-only run, and capture validators exist. | Target production device, macOS capture path, optional Desktop Video SDK need, and audio-on/video-on measurement. |
| Transport | Raw packetization, encoded bounded fragments, socket-backed UDP loopback/runtime reports, staged multi-stream test-pattern transport, latest-frame receiver, incomplete-frame drops, and VideoToolbox policy gates exist. | Physical packet-captured route and video stress where video degrades before audio. |
| Integrated A/V | Synthetic headless smoke, bounded run writer, A/V overlap gate, subordinate report cross-reference gates, and measured video-transport aggregation exist. | 30-minute measured run with RME audio, Blackmagic/ATEM capture, OSC cue loop, ATEM read-only status, packet-capture points, and unchanged audio timing. |
| OSC | Packet contract, synthetic/live UDP loopback, and bounded external-peer handoff exist. | Live external peer with audio-active comparison. |
| ATEM | Read-only probe and validator exist with commands disarmed. | Real ATEM model, firmware, program/preview, tally, audio mixer status, and audio-impact evidence. |
| Lighting | OSC-first cue workflow, sACN/Art-Net safety gates, explicit arm, isolation, local fixture-owner guard, and packet-capture gates exist. | Allowed universe, isolated network, fixture/virtual output, blackout/hold/drop behavior, capture point, and no audio impact. |
| Integrated profile | M12 profile report, validator, fastest-audio default guard, degradation order guard, and runtime evidence aggregation from fastest-audio, integrated A/V, and lighting reports exist. | Physical full-matrix benchmark evidence proving each optional feature cost and degradation before audio latency impact. |

## Next Action

1. Attach target Blackmagic/ATEM hardware and run capture inventory.
2. Run video-only capture using the production path or document the AVFoundation
   fallback boundary.
3. Pair video capture with the accepted audio baseline and verify video drops or
   degrades before audio timing changes.
4. Run one-, two-, and four-stream physical video transport profiles on the
   accepted route.
5. Run OSC loopback with the first real peer, then ATEM read-only status.
6. Fill Q009 before any real sACN or Art-Net output.

## Archive Pointers

The older video, control, lighting, app-shell, and packaging files are preserved under
[../../archive/2026-05-05-doc-consolidation/mac-port/](../../archive/2026-05-05-doc-consolidation/mac-port/).
Use them only to trace superseded video/control decisions.

## Resume here

Resume here: do not start M10 integrated A/V until audio, route, drift, capture,
video transport, multi-video, OSC, and ATEM evidence exist.

VERDICT: PARTIAL
