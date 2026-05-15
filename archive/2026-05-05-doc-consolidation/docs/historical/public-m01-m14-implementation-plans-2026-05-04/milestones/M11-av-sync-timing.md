# M11 AV Sync And Timing

Date: 2026-05-04  
Status: source-level timing contract implemented; physical evidence pending  
Verdict: PARTIAL

## Objective

Define and implement the shared timing model for audio and video while keeping
audio latency as the primary constraint and allowing video to align, drop, or
defer without blocking audio.

## Scope

In scope:

- monotonic local host timestamps;
- sender media frame indexes;
- audio packet playout timing;
- video capture/render timing;
- metrics timing packets;
- AV offset reporting;
- video drop/align policy;
- drift reporting and correction boundaries.

Out of scope:

- lip-sync over lowest audio latency when the trade-off would add audio buffer;
- external genlock implementation;
- hidden audio delay to make video look better.

## Affected Files

Changed files:

- `Sources/OpenLolaCore/MediaClock.swift`
- `Sources/OpenLolaCore/VideoTransportReport.swift`
- `Sources/OpenLolaCore/VideoTransportRunner.swift`
- `Sources/OpenLolaCore/VideoTransportProbe.swift`
- `Tests/OpenLolaCoreTests/MediaClockTests.swift`
- `Tests/OpenLolaCoreTests/AVTimestampAlignmentTests.swift`
- `Tests/OpenLolaCoreTests/ClockDriftSimulationTests.swift`
- `Tests/OpenLolaCoreTests/VideoTransportReportTests.swift`
- `Tests/OpenLolaCoreTests/Fixtures/VideoTransportReports/valid/video-transport-partial.json`
- `docs/architecture/av-sync-and-timing.md`

## Implementation Tasks

1. Done: `MediaClockTests` cover monotonic timestamp conversion and validation.
2. Done: `MediaTimingPacket` records stream ID, sequence, observed payload type,
   sender frame index, remote sender time, local observation time, and timestamp
   origin.
3. Done: `AVSyncTimingMetrics` reports audio route age and video frame age
   separately.
4. Done: `AVSyncPolicy` keeps audio as master and records that audio delay for
   video is forbidden for Direct Audio First.
5. Done: `AVTimestampAligner` renders, defers, or drops video according to
   Direct Audio First, Balanced AV, Multi-Video Performance, and WAN Stable
   policies.
6. Done: `MediaClockDriftEstimate` carries M05-compatible outside-callback
   correction boundary, offset, duration, and drift slope telemetry.
7. Done: `AVSyncTimingMetrics` exposes AV offset and jitter percentile metrics.

## Test Plan

Tests first:

- `MediaClockTests`: timestamp conversion, monotonic ordering, timing packet
  encode/decode, and audio/video packet-derived timing packets.
- `AVTimestampAlignmentTests`: Direct Audio First video drop without audio delay,
  Balanced AV alignment/defer behavior, Multi-Video Performance stale-video
  drop, and synthetic transport AV sync reporting.
- `ClockDriftSimulationTests`: offset and drift slope estimation plus rejection
  of backwards observations.
- `VideoTransportReportTests`: fixture AV timing decode/round trip and PASS
  rejection when AV sync timing metrics are missing.

## Benchmark Plan

- audio route age;
- video capture-to-render age;
- AV offset p50/p95/p99/max;
- drift slope;
- timing packet overhead;
- impact of sync policy on frame drops and underruns.

Current implementation status: the source reports expose these benchmark fields,
but there is no physical synchronized audio/video benchmark artifact yet.

## Acceptance Criteria

- Source-level: video transport reports carry `avSync.audioTimestampOrigin`,
  `avSync.videoTimestampOrigin`, audio route age, video frame age, AV offset,
  jitter, drift, and sync decision counters.
- Source-level: Direct Audio First decisions drop/defer video instead of adding
  audio delay.
- Source-level: Balanced AV renders frames inside the policy window and defers
  future frames on the video side.
- Source-level: synthetic reports compute AV offset from the reported audio route
  age and video frame age.

Remaining PASS evidence: a physical synchronized A/V run must prove the same
fields with real devices and packet/timing capture.

## Risks

- Sync terminology can imply stronger guarantees than the system can measure.
- Video timestamps from capture APIs may include hidden buffering and need clear
  labeling.

## Remaining Evidence Gates

- Physical reference Macs and synchronized audio/video devices.
- Packet/timing capture that correlates audio playout, video capture/render, and
  remote sender timestamps.
- PTP/external-clock comparison only where hardware supports it.

## Rollback Plan

Keep timing metrics report-only if active sync decisions are unstable. Disable
video alignment while retaining video frame age and audio route age reporting.

## Progress Checklist

- [x] Add media clock tests.
- [x] Add timing packet tests.
- [x] Add AV timestamp alignment tests.
- [x] Implement audio-priority sync policy.
- [x] Add video align/drop policy.
- [x] Add source-level AV offset and jitter benchmark fields.
- [ ] Capture physical synchronized A/V timing evidence.

## Resume Point

Next resume point: run the physical M11 benchmark with real audio/video devices
and attach the measured AV offset, jitter, drift, and timestamp-origin evidence.

VERDICT: PARTIAL
