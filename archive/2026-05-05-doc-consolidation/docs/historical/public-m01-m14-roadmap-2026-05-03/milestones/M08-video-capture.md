# M08 Video Capture

Date: 2026-05-03  
Status: source implementation complete; physical validation gated  
Verdict: PARTIAL

## Objective

Prototype Blackmagic/ATEM-oriented video capture without compromising the
accepted audio profile.

## Scope

Cover AVFoundation inventory, Blackmagic/ATEM/DeckLink/UltraStudio selection,
optional Desktop Video SDK adapter decision, frame-age measurement, and
audio-on/video-on impact checks.

## Affected Files

- [../architecture/video-blackmagic-atem.md](../architecture/video-blackmagic-atem.md)
- `Sources/OpenLolaCore/VideoCaptureAVFoundation.swift`
- `Sources/OpenLolaCore/VideoCaptureProbe.swift`
- `Sources/OpenLolaCore/VideoCaptureRunner.swift`
- `Tests/OpenLolaCoreTests/VideoCaptureReportTests.swift`
- Future Desktop Video SDK adapter files only if measurement justifies them

## Implementation Tasks

- Inventory macOS-exposed video devices.
- Prefer Blackmagic/ATEM production sources where available.
- Keep AVFoundation fallback as the first smoke path.
- Capture real AVFoundation sample buffers into a latest-frame queue.
- Record frame-age, frame-interval, drop-count, CPU, and memory metrics.
- Accept measured audio-off/video-on and audio-on/video-on callback metrics as
  report inputs.
- Decide on Desktop Video SDK only after inventory and frame-age evidence.

## Test Plan

- Video inventory tests.
- Test-pattern capture tests.
- Latest-frame queue tests.
- Negative tests for missing device, permission denial, and synthetic PASS.

## Benchmark Plan

Measure frame age, frame interval, dropped frames, CPU load, memory pressure,
and audio callback impact with the accepted audio profile running.

## Acceptance Criteria

- Target capture path is identified.
- Production capture report exists or Desktop Video SDK need is documented.
- Video capture does not increase default audio playout latency.
- PASS requires authorized AVFoundation capture, concrete Blackmagic/ATEM,
  DeckLink, UltraStudio, or Blackmagic capture evidence, CPU and memory metrics,
  unchanged audio callback p99/max, unchanged playout target, zero underruns,
  and no hidden audio impact.

## Risks

- Camera permission can block local tests.
- AVFoundation may add latency or hide device-specific controls.
- SDK integration can add complexity before audio proof is stable.

## Blockers

Accepted audio baseline, target Blackmagic/ATEM hardware, and macOS capture
permission.

## Rollback Plan

Disable production video capture and keep test-pattern/AVFoundation inventory
only.

## Progress Checklist

- [x] Device inventory command implemented.
- [x] Capture permission state recorded by inventory and run reports.
- [x] Frame-age and frame-interval benchmark fields implemented.
- [x] Latest-frame queue drop accounting implemented.
- [x] Process CPU and memory fields implemented.
- [x] Audio impact comparison fields implemented.
- [x] M08 report schema, fixture, tests, and CLI validator stored.
- [ ] Target Blackmagic/ATEM hardware inventory recorded.
- [ ] Audio impact comparison recorded on the target rig.

## Resume Point

Resume at M09 only after target Blackmagic/ATEM capture is measured without
audio impact.

VERDICT: PARTIAL
