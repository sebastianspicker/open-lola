# M09 Video Transport

Date: 2026-05-03  
Status: source implementation complete; physical validation pending  
Verdict: PARTIAL

## Objective

Add low-latency video TX/RX transport that degrades before audio timing changes.

## Scope

Cover raw or intra-frame packetization, fragmentation, reassembly, latest-frame
render policy, frame dropping, and optional VideoToolbox evaluation.

## Affected Files

- [../architecture/video-blackmagic-atem.md](../architecture/video-blackmagic-atem.md)
- [../architecture/p2p-networking.md](../architecture/p2p-networking.md)
- `Sources/OpenLolaCore/VideoTransportProbe.swift`
- `Sources/OpenLolaCore/VideoTransportRunner.swift`
- `Sources/OpenLolaCore/VideoTransportReport.swift`
- `Tests/OpenLolaCoreTests/VideoTransportReportTests.swift`

## Implementation Tasks

- Keep raw/intra transport as the first physical benchmark mode.
- Fragment frames into bounded packet payloads with frame sequence, timestamp,
  fragment index/count, payload offset, and fingerprint fields.
- Encode/decode video fragments so malformed datagrams fail before reassembly.
- Reassemble only complete useful frames; when a newer frame starts, drop the
  incomplete older frame rather than waiting.
- Render through latest-frame receiver policy and drop stale video frames
  rather than delaying audio.
- Keep VideoToolbox only as an optional measured bandwidth mode behind report
  gates for realtime mode, queue depth, and frame reordering.

## Test Plan

- Fragmentation and encoded packet-size tests.
- Complete and out-of-order reassembly tests.
- Incomplete-frame and stale-fragment drop-policy tests.
- Malformed encoded fragment tests.
- Audio-impact guard tests for callback p99/max, playout target, underruns, and
  hidden impact.

## Benchmark Plan

Run physical video route with packet capture. Record fragments per frame,
complete reassembly, dropped frames, frame age, route loss, CPU, and audio
callback comparison.

## Acceptance Criteria

- Video transport works on a physical route.
- Audio callback metrics remain within accepted baseline.
- Video drops or degrades before audio buffers grow.

## Risks

- Raw video can saturate route bandwidth.
- Fragment loss can create high frame drop rates.
- Compression can add hidden queueing.

## Blockers

Accepted M08 capture and accepted audio/network baseline.

## Rollback Plan

Disable video transport and keep local test-pattern transport as source
validation only.

## Progress Checklist

- [x] Raw/intra mode selected.
- [x] Fragmentation tests pass.
- [ ] Physical route measured.
- [ ] Audio impact comparison recorded.
- [x] M09 source report stored.

## Resume Point

Resume at M10 after physical video transport proves that video degrades first.

VERDICT: PARTIAL
