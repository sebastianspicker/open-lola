# P04 Integrated A/V Proof

## Objective

Prove that RME audio plus ATEM/capture load can coexist for 30 minutes without
worsening audio timing.

## Background/Context

The integrated proof composes P02 audio metrics with P03 capture/control
metrics. It must run a baseline audio-only measurement first, then run an
integrated measurement with audio, video capture, optional video transport or
local preview, and ATEM read-only polling.

## Canonical Roadmap Links

- [../milestones/M10_INTEGRATED_HEADLESS_AV.md](../milestones/M10_INTEGRATED_HEADLESS_AV.md)
- [P02_REALTIME_AUDIO_ENGINE.md](P02_REALTIME_AUDIO_ENGINE.md)
- [P03_BLACKMAGIC_ATEM_PATH.md](P03_BLACKMAGIC_ATEM_PATH.md)
- [status/P04_STATUS.md](status/P04_STATUS.md)

## Assumptions

- P02 has a measured RME audio route.
- P03 has concrete capture/control evidence.
- Video/control degradation is accepted before any audio target growth.
- The proof remains headless unless the app shell is explicitly part of the
  measured load.

## Dependencies

- Baseline audio-only report from P02.
- Integrated report shape from M10.
- Capture/control report evidence from P03.
- 30-minute uninterrupted run window.

## Affected Modules/Files

- [../../Sources/OpenLolaCore/IntegratedAvReport.swift](../../Sources/OpenLolaCore/IntegratedAvReport.swift)
- [../../Sources/OpenLolaCore/VideoCaptureProbe.swift](../../Sources/OpenLolaCore/VideoCaptureProbe.swift)
- [../../Sources/OpenLolaCore/UdpPcmRouteCertification.swift](../../Sources/OpenLolaCore/UdpPcmRouteCertification.swift)
- [status/P04_STATUS.md](status/P04_STATUS.md)

## Implementation Plan

1. Run baseline audio-only measurement first.
2. Run integrated measurement with RME audio, video capture, optional video
   transport or local preview, and ATEM read-only polling.
3. Record CPU, GPU, network load, callback p99/max, packet age, lost/late
   packets, underruns, frame age, capture drops, control jitter, and
   degradation events.
4. Enforce video/control degradation before any audio target growth.
5. Compare integrated audio metrics against baseline and record a dated
   verdict.

2026-05-03 source-level support: `open-lola integrated-av-run` can now write a
bounded PARTIAL integrated report from an audio baseline ID plus video/control
participation switches. It is a report-wiring proof only; P04 still requires a
measured 1,800 second hardware run for PASS.

## Companion Status Fields

[status/P04_STATUS.md](status/P04_STATUS.md) records:

- baseline report ID;
- integrated report ID;
- 30-minute run start and end;
- degradation actions taken;
- audio comparison verdict.

## Test Plan

Before: P02 and P03 evidence exist separately or remain partial.

After:

- `swift build` passes;
- `swift test` passes;
- `bash scripts/verify-docs.sh` passes;
- `shellcheck scripts/*.sh` passes;
- `swift run open-lola validate-integrated-av-report <path>` passes;
- `swift run open-lola integrated-av-run --audio-baseline <report-id>
  --video-capture on --video-transport on --osc-control on --atem-readonly
  <host|off> --duration-seconds 60 --output <path>` writes a PARTIAL source
  report;
- integrated run duration is at least 1,800 seconds;
- baseline and integrated audio metrics are compared.

## Validation Method

Reject the integrated proof if callback p99/max, underruns, packet age, playout
target, or route verdict worsens compared with the audio-only baseline. Video
frame drops, lower preview quality, disabled control polling, or disabled video
transport are acceptable only when they preserve audio timing.

## Acceptance Criteria

- Integrated run duration is at least 1,800 seconds.
- Audio callback p99/max, underruns, playout target, and route verdict do not
  worsen.
- Video/control metrics are visible and subordinate.
- Degradation events are recorded when video/control load is reduced or
  disabled.

## Risks and Mitigations

- Integrated load can hide audio regressions behind averaged metrics.
  Mitigation: record p99/max and explicit route verdict comparison.
- Control polling can add jitter. Mitigation: degrade or disable polling before
  audio timing changes.
- Local preview can consume GPU/CPU unexpectedly. Mitigation: measure with and
  without preview when preview is enabled.

## Known Blockers

- Requires P02 audio baseline.
- Requires P03 capture/control state.
- Requires a 30-minute uninterrupted run.

## Progress Checklist

- [ ] Record baseline audio-only report ID.
- [ ] Run integrated audio plus capture/control measurement.
- [ ] Run for at least 1,800 seconds.
- [ ] Record CPU, GPU, network, audio, video, and control metrics.
- [ ] Record any degradation actions.
- [ ] Compare audio metrics against baseline.
- [ ] Validate integrated A/V report.
- [ ] Update [status/P04_STATUS.md](status/P04_STATUS.md).

## Next Recommended Action

After P02 and P03 have measured evidence, run `integrated-av-run` for a short
PARTIAL wiring proof, then run the full 1,800 second measured proof and compare
against the latest accepted audio-only baseline.

## Resume here

Start from [status/P04_STATUS.md](status/P04_STATUS.md). P04 remains PARTIAL
until a validated 1,800 second integrated report preserves the audio baseline.
