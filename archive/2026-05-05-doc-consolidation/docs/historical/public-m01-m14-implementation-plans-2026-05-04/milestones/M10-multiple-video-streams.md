# M10 Multiple Video Streams

Date: 2026-05-04  
Status: source-level implementation complete; physical multi-input evidence open  
Verdict: PARTIAL

## Objective

Support multiple simultaneous video perspectives through negotiated stream IDs,
per-stream capture, packetization, receive selection, drop policy, and optional
multi-view layout while protecting audio priority.

## Scope

In scope:

- multiple logical video stream IDs;
- multiple camera or input descriptors;
- optional ATEM/perspective labels from public control surfaces;
- per-stream enable/disable;
- receiver-side stream selection;
- optional multi-view layout;
- per-stream drop policy and metrics;
- bandwidth and memory budgeting.

Out of scope:

- proprietary ATEM internals;
- audio latency sacrifices for extra video perspectives;
- relay distribution.

## Affected Files

New or changed files:

- `Sources/OpenLolaCore/VideoStreamDescription.swift`
- `Sources/OpenLolaCore/SessionNegotiation.swift`
- `Sources/OpenLolaCore/MultiVideoStreams.swift`
- `Sources/OpenLolaCore/VideoTransportRunner.swift`
- `Sources/OpenLolaCore/VideoTransportReport.swift`
- `Tests/OpenLolaCoreTests/MultiVideoStreamNegotiationTests.swift`
- `Tests/OpenLolaCoreTests/MultiVideoTransportTests.swift`
- `Tests/OpenLolaCoreTests/Fixtures/VideoTransportReports/valid/video-transport-partial.json`
- `docs/architecture/multiple-video-streams.md`

## Implementation Tasks

1. Added tests for negotiating zero, one, and multiple video streams.
2. Enforced globally unique stream IDs inside a session.
3. Added per-stream source role, label, resolution, frame rate, pixel format,
   priority, queue depth, and bandwidth budget.
4. Added per-stream capture enable/disable through `captureEnabled` and
   `canSendMedia`.
5. Added receiver stream selection and multi-view layout model.
6. Enforced per-stream bandwidth and queue budgets at negotiation/report time.
7. Added source-level priority drop decisions so lower-priority frames are
   dropped before audio-critical settings change.

## Test Plan

Tests first:

- multi-video stream negotiation;
- duplicate stream ID rejection;
- per-stream enable/disable;
- receiver selection;
- multi-view layout model;
- per-stream drop policy;
- video stream cannot change audio latency profile without renegotiation;
- per-stream report metrics in `video-transport-synthetic-smoke`.

## Benchmark Plan

- CPU/GPU/memory cost per stream remains a physical follow-up;
- network throughput per stream is estimated in source-level reports;
- frame drops per stream are reported by reason;
- render cost for selected stream versus multi-view remains a physical
  benchmark follow-up;
- audio callback duration with one, two, and four streams remains a physical
  benchmark follow-up;
- memory bandwidth pressure under raw and compressed candidates.

## Acceptance Criteria

- Multiple video streams can be described and negotiated.
- Receiver can select one stream or a multi-view layout.
- Per-stream metrics and drop counters are reported.
- Audio priority is preserved under multi-stream load.

## Risks

- Raw multi-stream transport can exceed direct network capacity quickly.
- Multi-view rendering can become the dominant GPU cost.
- Source labels from ATEM-like workflows must remain advisory, not proprietary
  protocol coupling.

## Blockers

- M08 and M09 one-stream video TX/RX required.
- Multiple physical inputs or an ATEM-like public control surface required for
  hardware PASS.

## Rollback Plan

Negotiate only the primary video stream by default. Keep secondary streams
disabled unless both peers explicitly accept Multi-Video Performance.

## Progress Checklist

- [x] Add multi-stream negotiation tests.
- [x] Add stream ID uniqueness validation.
- [x] Add receiver selection model.
- [x] Add per-stream metrics.
- [x] Add multi-view layout model.
- [x] Add source-level bandwidth and priority drop checks.
- [ ] Benchmark physical multi-stream load.
- [ ] Run physical multi-input smoke.

## Resume Point

Run physical multi-input/ATEM-like smoke with accepted `multiVideo` report
metrics. Source-level M10 now negotiates zero, one, and multiple video streams,
tracks per-stream budgets and metrics, models receiver selection/multiview, and
keeps PASS blocked until real multi-input/audio-priority evidence exists.

VERDICT: PARTIAL
