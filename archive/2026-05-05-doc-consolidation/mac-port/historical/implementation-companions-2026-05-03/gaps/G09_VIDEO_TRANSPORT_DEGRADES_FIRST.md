# G09 Video Transport Degrades First

## LoLa Comparison

LoLa transports low-latency video and accepts substantial bandwidth demand to
avoid codec delay. The Mac path must first prove raw or intra-frame transport on
a physical path, then evaluate VideoToolbox only as a bandwidth-constrained
mode. Video must degrade before audio timing changes.

## Current Repo State

- Related milestone: [../milestones/M09_NATIVE_VIDEO_TRANSPORT.md](../milestones/M09_NATIVE_VIDEO_TRANSPORT.md)
- Live status: [../status/M09_STATUS.md](../status/M09_STATUS.md)
- Existing source has raw frame packetization, latest-frame receiver accounting,
  degradation gates, VideoToolbox policy gates, fixture validation, synthetic
  smoke, and `video-transport-run --mode raw` for a bounded test-pattern raw
  route report with explicit route kind and packet-capture-point metadata.
- Missing piece: physical packet-captured video route, real M08 capture input,
  and audio-plus-video stress evidence.

## Implementation Plan

1. Use G04 accepted route and G07 measured capture as inputs.
2. Run raw frame transport first with latest-frame receiver policy and packet
   capture.
3. Record frame age p50/p95/p99/max, sender drops, receiver drops, late frames,
   bandwidth, CPU/GPU load, and audio p99/max.
4. Add VideoToolbox only after raw transport has a measured baseline. Disable
   frame reordering for low latency.
5. Add degradation policy: reduce video frame rate, resolution, quality, or
   preview before audio target growth.
6. Reject any mode that needs reliable retransmission, frame reordering, or
   increased audio playout target to pass.

## Acceptance Tests

- `validate-video-transport-report` accepts measured physical reports and
  PARTIAL raw route reports.
- `video-transport-run --mode raw` writes a PARTIAL latest-frame report with
  frame/drop accounting and explicit route metadata.
- PASS rejects localhost-only evidence, reliable retransmission, missing raw
  baseline, frame reordering, audio p99/max increase, and audio route verdict
  changes.
- Packet capture proves the physical route used.

## Blockers / TODO(human)

- Depends on G04 and G07.
- TODO(human): [Video transport fallback] -> Choose the first degradation action for overload -> [drop frames / reduce resolution / disable video]

## Verification Commands

```bash
swift run open-lola validate-video-transport-report <video-transport-report.json>
swift run open-lola video-transport-run --mode raw --peer <ip> --port <port> --duration-seconds <n> --route-kind <localhost|directWired|switched|campus> --packet-capture-point <label> --output <path>
swift test --filter VideoTransport
swift test
```

## Resume here

Run `video-transport-run --mode raw` on the target route with packet capture
before any VideoToolbox work. Keep G09/M09 PARTIAL until the report is backed by
physical route evidence and audio-active stress.

VERDICT: PARTIAL
