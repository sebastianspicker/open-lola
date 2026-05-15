# M10 AV Sync

Date: 2026-05-03  
Status: source implementation complete; measured hardware stress pending  
Verdict: PARTIAL

## Objective

Integrate audio and video timing with audio as the master clock.

## Scope

Cover audio-master sync, video timestamping, nearest/latest frame rendering,
integrated report cross-references, and audio-on/video-on stress.

## Affected Files

- [../architecture/latency-first-architecture.md](../architecture/latency-first-architecture.md)
- [../architecture/video-blackmagic-atem.md](../architecture/video-blackmagic-atem.md)
- `Sources/OpenLolaCore/IntegratedAvReport.swift`
- `Sources/OpenLolaCore/IntegratedAvRun.swift`
- `Sources/OpenLolaCore/IntegratedAvReportValidation.swift`
- `Tests/OpenLolaCoreTests/IntegratedAvReportTests.swift`
- `Tests/OpenLolaCoreTests/Fixtures/IntegratedAvReports/valid/integrated-av-partial.json`

## Implementation Tasks

- Use audio clock as master.
- Timestamp video frames with monotonic time and frame identity.
- Render nearest/latest useful video frame without holding audio.
- Cross-reference audio, route, capture, and transport reports.

**Implemented Source Contract**

`IntegratedAvReport` now records an explicit `sync` policy with audio as the
master clock, no audio blocking on video, no video-driven audio playout target
changes, and video degradation before audio impact. `IntegratedVideoMetrics`
records monotonic video frame identity/timestamps plus renderer sync state:
nearest/latest policy, stale-frame boundary, rendered frame age, stale drops,
stale renders, and audio-hold events.

PASS validation rejects:

- non-audio master clocks;
- audio waits caused by video;
- video changes to the audio playout target;
- non-monotonic video frame timestamps;
- duplicate video frame identities;
- stale video rendered past the explicit boundary;
- rendered stale frames;
- missing subordinate audio, capture, transport, preview, OSC, or ATEM proof;
- placeholder proof fields;
- any measured integrated run shorter than 1,800 seconds.

## Test Plan

- Integrated report tests.
- Negative tests for audio ownership violations.
- Cross-reference tests for missing subordinate reports.
- Sync-boundary tests for stale video handling.

## Benchmark Plan

Run a 30-minute integrated headless A/V stress. Record audio latency, callback
timing, video frame age, dropped frames, packet loss, CPU, memory, and thread
warnings.

## Acceptance Criteria

- Audio timing remains within the accepted audio baseline.
- Video sync is bounded by explicit nearest/latest policy.
- Integrated report references physical audio and video evidence.

## Risks

- Sync attempts can accidentally add audio delay.
- Integrated CPU load can invalidate audio-only tuning.
- Stale video can look smooth while hiding excessive latency.

## Blockers

Accepted M07 audio tuning, M08 capture, and M09 transport evidence.

## Rollback Plan

Disable integrated AV and return to audio-only PASS plus video PARTIAL reports.

## Progress Checklist

- [x] Audio-master sync policy implemented.
- [x] Integrated report validation passes.
- [ ] 30-minute stress recorded.
- [ ] Audio impact accepted.
- [x] M10 source report stored.

## Resume Point

Resume at the 30-minute measured integrated A/V stress. Keep M10 PARTIAL until
the measured run proves audio remains master under active video load.

VERDICT: PARTIAL
