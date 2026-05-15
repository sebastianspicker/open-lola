# M08 Blackmagic Capture TX

Date: 2026-05-04  
Status: source implemented; physical Blackmagic proof still open  
Verdict: PARTIAL

## Objective

Capture low-latency video frames from Blackmagic-compatible hardware and
transmit them to a peer with explicit stream metadata, timestamps, packetization
policy, and benchmark telemetry.

## Scope

In scope:

- public macOS capture APIs first;
- optional Desktop Video SDK boundary after measurement;
- one video stream initially;
- stream ID and source role;
- resolution, frame rate, pixel format, transport format, and timestamp
  negotiation;
- frame drop policy before audio pressure is affected;
- raw or lightly processed frame transport experiments;
- no audio-critical thread interaction.

Out of scope:

- received video output;
- multi-stream capture;
- WAN adaptation;
- proprietary SDK-private behavior.

## Affected Files

Implemented files:

- `Sources/OpenLolaCore/VideoCaptureAVFoundation.swift`
- `Sources/OpenLolaCore/VideoCaptureProbe.swift`
- `Sources/OpenLolaCore/VideoCaptureRunConfiguration.swift`
- `Sources/OpenLolaCore/VideoCaptureRunner.swift`
- `Sources/OpenLolaCore/VideoCaptureReport.swift`
- `Sources/OpenLolaCore/VideoMediaSocket.swift`
- `Sources/OpenLolaCore/VideoTransportPacket.swift`
- `Sources/OpenLolaCore/VideoTransportRunner.swift`
- `Sources/OpenLolaCore/SessionNegotiation.swift`
- `Sources/OpenLolaCore/OpenLolaCLI.swift`
- `Sources/OpenLolaCore/UdpMediaTransport.swift`
- `Tests/OpenLolaCoreTests/BlackmagicCaptureTransmitTests.swift`
- `Tests/OpenLolaCoreTests/UdpMediaTransportTests.swift`
- `Tests/OpenLolaCoreTests/VideoTransportReportTests.swift`
- `Tests/OpenLolaCoreTests/VideoCaptureReportTests.swift`
- `Tests/OpenLolaCoreTests/SessionNegotiationTests.swift`
- `docs/architecture/blackmagic-video-rx-tx.md`

## Implementation Tasks

1. Added tests for video stream negotiation and TX packet metadata.
2. Extended capture reports to include stream ID, timestamp basis, frame format,
   frame rate, and source role.
3. Capture frame payloads into bounded, preallocated video queues where the API
   permits it.
4. Packetized frames with stream ID, frame sequence, capture timestamp, fragment
   index/count, pixel format, width, height, and frame rate.
5. Added drop policy for late or backpressured video frames.
6. Kept video capture, packetization, and network work on video/network queues,
   never on audio callbacks.
7. Still benchmark raw, low-copy, and hardware-assisted transport candidates before
   selecting a default.

## Test Plan

Tests first:

- Blackmagic-compatible capture smoke test can run when hardware is present.
- Video stream description negotiation is covered.
- Frame format/resolution/framerate negotiation is covered.
- Video TX packet metadata round trip is covered.
- UDP media envelope rejects mismatched video stream IDs.
- UDP media transport can send and receive a video fragment over loopback.
- Fragment loss rejects incomplete frames.
- Video drop policy increments counters.
- Video backpressure does not change audio RX buffer target.

## Benchmark Plan

- capture callback-to-queue latency;
- frame packetization latency;
- memory copies per frame;
- dropped frames under network backpressure;
- CPU, GPU, and memory bandwidth for raw transport;
- VideoToolbox or Metal cost if used;
- audio callback duration while video TX is active.

## Acceptance Criteria

- One negotiated video stream can capture and packetize frames in tests.
- Hardware smoke can produce a Blackmagic-compatible capture report when
  hardware is attached.
- Video TX reports frame timing and drops.
- Audio-critical metrics are unchanged by video TX.

## Risks

- AVFoundation may add hidden buffering or format conversion for some devices.
- Raw frames can saturate network or memory bandwidth at high resolutions.
- Desktop Video SDK integration may require a separate local dependency setup.

## Blockers

- Physical Blackmagic-compatible hardware required for PASS.
- M02/M06 required for negotiated peer TX.

## Rollback Plan

Keep existing AVFoundation capture report command as a probe. If live TX is
unstable, disable video media start while preserving capture inventory and
metadata negotiation.

## Progress Checklist

- [x] Add video stream negotiation tests.
- [x] Add TX packet metadata tests.
- [x] Extend capture report fields.
- [x] Implement one-stream frame packetization.
- [x] Add video drop counters.
- [x] Add UDP media-envelope video TX loopback.
- [ ] Run Blackmagic-compatible capture smoke.
- [ ] Benchmark video TX impact on audio.

## Resume Point

Run `video-capture-inventory` with the target Blackmagic/ATEM hardware attached,
then run `video-capture-run` and `video-transport-run` on the measured route.
Keep M08 PARTIAL until the hardware report and audio-on/video-on benchmark show
unchanged audio p99/max, unchanged playout target, and zero underruns.

VERDICT: PARTIAL
