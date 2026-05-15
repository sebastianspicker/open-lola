# Video Control Degrade Matrix

Date: 2026-05-04  
Status: executable C07 inventory implemented  
Milestone: C07  
Verdict: PARTIAL

## Purpose

This document summarizes the C07 video/control degrade-first crosswalk. The
executable source of truth is:

- `Sources/OpenLolaCore/VideoControlDegradeMatrix.swift`
- `Tests/OpenLolaCoreTests/VideoControlDegradeMatrixTests.swift`

The user-facing probe is:

```bash
.build/debug/open-lola video-control-degrade-matrix
```

Expected output is machine-readable JSON followed by:

```text
VERDICT: PARTIAL
```

`PARTIAL` is intentional. The matrix proves source ownership and validation
boundaries. It does not prove real Blackmagic, ATEM, lighting, direct-route, or
benchmark readiness.

## Summary

| Scope | Count |
|---|---:|
| Matrix entries | 9 |
| CLI-backed entries | 9 |
| Audio-protected entries | 9 |
| Degrade-before-audio-latency entries | 5 |
| Audio-baseline-required PASS entries | 8 |
| PASS-evidence-required entries | 9 |
| Read-only control entries | 1 |
| Armed-by-default entries | 0 |

## Source Map

| Surface | Primary source | Boundary | Audio baseline for PASS | Commands |
|---|---|---|---|---|
| `videoCapture` | `VideoCaptureReport.swift` | AVFoundation is generic capture only; production PASS needs Blackmagic evidence and unchanged audio metrics. | yes | `validate-video-capture-report`, `video-capture-synthetic-smoke`, `video-capture-run` |
| `videoTransport` | `VideoTransportReport.swift` | Frame drop or video disable must happen before audio target, route, callback, playout, or underrun impact. | yes | `validate-video-transport-report`, `video-transport-synthetic-smoke`, `video-transport-run` |
| `videoRenderOutput` | `VideoOutputRenderer.swift` | Output PASS is owned by video transport validation and requires Blackmagic physical output evidence. | yes | `validate-video-transport-report` |
| `multiVideoStreams` | `MultiVideoStreams.swift` | Lower-priority video is dropped before adding audio route or buffer pressure. | yes | `validate-video-transport-report` |
| `atemReadOnlyControl` | `AtemReadOnlyControl.swift` | ATEM defaults to disarmed read-only polling; PASS rejects armed commands. | no | `validate-atem-control-report`, `atem-readonly-probe` |
| `oscCueControl` | `OscCueProbe.swift` | OSC cue PASS requires live loopback, first external peer evidence, no playout change, no underruns, and no hidden audio impact. | yes | `validate-osc-cue-report`, `osc-cue-synthetic-smoke`, `osc-cue-run`, `osc-cue-external-run` |
| `lightingFixtureGate` | `LightingFixtureGateReport.swift` | Lighting PASS requires isolated allowed universe, packet capture, fixture owner match, and unchanged audio metrics. | yes | `validate-lighting-gate-report`, `lighting-gate-synthetic-smoke`, `lighting-gate-run` |
| `integratedAv` | `IntegratedAvReportValidation.swift` | Integrated AV PASS requires audio master clock, audio-only baseline first, degrade-before-impact evidence, read-only ATEM, and stable audio/route metrics. | yes | `validate-integrated-av-report`, `integrated-av-synthetic-smoke`, `integrated-av-run` |
| `integratedProfile` | `IntegratedProfileReport.swift` | Fastest audio stays default; video quality, frame rate, and disable-video degradation must precede audio latency increase. | yes | `validate-integrated-profile-report`, `integrated-profile-synthetic-smoke`, `integrated-profile-run` |

## C07 Runtime Guards

C07 tightens integrated-profile validation:

- degradation steps cannot be duplicated,
- video profiles must still lead with quality reduction and frame-rate
  reduction,
- video profiles must disable video before audio latency may increase,
- audio latency remains the last degradation step,
- lighting disable still precedes audio latency increase.

Integrated AV validation already required audio-master sync and video
degradation before audio impact. C07 adds direct tests for:

- video changing the audio playout target,
- sync declarations that do not require video degradation before audio impact,
- PASS reports where video degradation does not happen before route or audio
  impact.

## Test Contract

`VideoControlDegradeMatrixTests.swift` verifies:

- summary counts match executable entries,
- every source, test, and documentation path exists,
- related matrix commands are covered by `CLICommandInventory`,
- control surfaces are disarmed by default,
- integrated AV requires an audio baseline and degrade-before-impact behavior,
- `OpenLolaCLI.videoControlDegradeMatrixData()` round-trips through JSON.

`IntegratedProfileReportTests.swift` verifies the new degradation-order guards.
`IntegratedAvDegradeFirstTests.swift` verifies the missing C07 integrated AV
negative cases.

## Resume Here

C07 and C12 are implemented at source/tooling level. Run the full verification
matrix before starting the next milestone.

VERDICT: PARTIAL
