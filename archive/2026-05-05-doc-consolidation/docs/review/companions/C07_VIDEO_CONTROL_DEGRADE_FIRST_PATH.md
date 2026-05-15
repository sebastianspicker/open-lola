# C07 Video Control Degrade-First Path

Date: 2026-05-04  
Status: implemented source-level guard and executable matrix  
Priority: P1  
Verdict: PARTIAL

## Code Evidence

- Video and control code spans `VideoCapture*`, `VideoTransport*`,
  `VideoOutputRenderer.swift`, `MultiVideoStreams.swift`,
  `AtemReadOnlyControl.swift`, `OscCueProbe.swift`,
  `LightingFixtureGate*`, `IntegratedAv*`, and `IntegratedProfile*`.
- The project architecture says video, lighting, and control must degrade or
  drop before audio latency changes.
- Tests exist for video capture/transport, Blackmagic receive/render/capture,
  OSC, lighting gates, integrated AV, and integrated profile reports.
- `VideoControlDegradeMatrix.swift` now indexes each C07 surface, its CLI
  commands, test coverage, audio-protection boundary, and default arming state.

## Objective

Make audio-protective degradation behavior explicit in video/control code and
tests.

## Implemented Source Changes

1. Added `Sources/OpenLolaCore/VideoControlDegradeMatrix.swift`.
2. Added `open-lola video-control-degrade-matrix`.
3. Added `Tests/OpenLolaCoreTests/VideoControlDegradeMatrixTests.swift`.
4. Tightened `IntegratedProfileReport.validateDegradationOrder()`:
   - duplicate degradation steps are rejected,
   - video profiles must disable video before audio latency can increase,
   - the existing audio-latency-last and video-leads checks remain intact.
5. Added integrated AV tests for:
   - video changing audio playout target,
   - sync policies without pre-audio-impact degradation,
   - PASS reports without video degradation before route/audio impact.
6. Added [../video-control-degrade-matrix.md](../video-control-degrade-matrix.md)
   as the human-readable C07 matrix.

## Affected Files

- `Sources/OpenLolaCore/Video*.swift`
- `Sources/OpenLolaCore/MultiVideoStreams.swift`
- `Sources/OpenLolaCore/BlackmagicOutputBoundary.swift`
- `Sources/OpenLolaCore/AtemReadOnlyControl*.swift`
- `Sources/OpenLolaCore/Osc*.swift`
- `Sources/OpenLolaCore/LightingFixtureGate*.swift`
- `Sources/OpenLolaCore/IntegratedAv*.swift`
- `Sources/OpenLolaCore/IntegratedProfile*.swift`
- `Sources/OpenLolaCore/VideoControlDegradeMatrix.swift`
- related tests and fixtures

## Improvement Plan

1. Done: every release-critical video/control surface is indexed in
   `VideoControlDegradeMatrix`.
2. Done: integrated profile tests prove video degradation precedes audio
   latency increase.
3. Done: ATEM defaults remain read-only/disarmed and are indexed as such.
4. Done: AVFoundation generic capture and Blackmagic production evidence are
   separated in the matrix and existing validators.
5. Done: PASS evidence requirements are indexed and existing validators retain
   measured/external proof boundaries.

## Acceptance Criteria

- Done: integrated profile degradation order is covered by tests.
- Done: video transport reports expose frame drop/degrade behavior through the
  C07 matrix and existing PASS guards.
- Done: ATEM/lighting reports cannot imply armed production control by default.
- Done: audio baseline is a prerequisite for integrated AV PASS.

## Verification

```bash
swift test
.build/debug/open-lola video-control-degrade-matrix
.build/debug/open-lola video-transport-synthetic-smoke
.build/debug/open-lola validate-integrated-av-report Tests/OpenLolaCoreTests/Fixtures/IntegratedAvReports/valid/integrated-av-partial.json
bash scripts/verify-docs.sh
```

## Resume Here

C07 is implemented at source level. Continue with
[C12_ARTIFACT_DEPENDENCY_GENERATED_OUTPUT_HYGIENE.md](C12_ARTIFACT_DEPENDENCY_GENERATED_OUTPUT_HYGIENE.md)
after the full verification matrix passes.

VERDICT: PARTIAL
