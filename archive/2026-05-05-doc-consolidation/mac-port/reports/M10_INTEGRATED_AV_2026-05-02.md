# M10 Integrated Headless A/V Validation Report

Date: 2026-05-02  
Updated: 2026-05-03  
Milestone: [M10 Integrated Headless A/V](../milestones/M10_INTEGRATED_HEADLESS_AV.md)  
Status: PARTIAL

## Scope

This report validates the M10 source-level integrated headless A/V harness:
unified report schema, synthetic headless audio/video runner, bounded
`integrated-av-run` report writer, ownership boundary checks, degradation PASS
gates, 30-minute PASS duration and overlap gates, subordinate report/capture
point cross-reference gates, fixture validation, and synthetic smoke output. It
does not validate a real 30-minute integrated stress run, physical audio route,
AVFoundation capture, physical video transport, VideoToolbox runtime behavior,
or CPU/GPU/network stress.

## Integrated A/V Contract

The report records:

- run mode and duration;
- run-window start, end, and audio/video overlap duration when available;
- audio-master sync policy, including whether audio may block on video and
  whether video may change the audio playout target;
- headless ownership for audio and video lanes, plus whether UI owns realtime
  paths;
- audio-only baseline route ID, baseline verdict, integrated audio verdict,
  callback p99/max, playout target, packet age, loss, late packets, underruns,
  and hidden playout growth;
- video source, format, capture frame age, capture drops, transport mode,
  transport frame age, receiver drops, receiver late frames, monotonic frame
  identity/timestamp evidence, nearest/latest render policy, stale-frame
  boundary, audio-hold events, and degradation policy;
- CPU, GPU, and network stress flags plus p99/load metrics;
- P04 proof evidence that cross-references audio, integrated-run, video capture,
  video transport or preview, OSC, and ATEM report IDs plus audio/video
  packet-capture points;
- PASS, FAIL, or PARTIAL verdict.

PASS reports require a measured run of at least 1,800 seconds, at least 1,800
seconds of explicit audio/video overlap, PASS audio baseline, PASS integrated
audio verdict, no UI ownership of realtime paths, non-placeholder subordinate
report IDs and packet-capture points, video degradation before audio target
changes, audio as the only master clock, no audio blocking on video, monotonic
video frame timing and identity, no stale video rendered past the explicit
boundary, unchanged callback p99/max, unchanged playout target, zero loss/late
packets, zero underruns, and no hidden playout growth.

## Commands

```bash
swift test --filter IntegratedAvReportTests
swift test
swift build
.build/debug/open-lola validate-integrated-av-report Tests/OpenLolaCoreTests/Fixtures/IntegratedAvReports/valid/integrated-av-partial.json
.build/debug/open-lola integrated-av-synthetic-smoke
.build/debug/open-lola integrated-av-run --audio-baseline m05-route-baseline-required --video-capture on --video-transport on --osc-control on --atem-readonly 192.0.2.10 --duration-seconds 60 --output /private/tmp/open-lola-m10-integrated-av-run.json
.build/debug/open-lola validate-integrated-av-report /private/tmp/open-lola-m10-integrated-av-run.json
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
```

## Results

- Red test run before implementation failed on missing M10 integrated A/V
  types.
- `swift test --filter IntegratedAvReportTests` passed with 9 M10 tests.
- `swift test` passed with 75 tests.
- `swift build` passed after rerunning outside the SwiftPM sandbox failure.
- The synthetic PARTIAL integrated A/V fixture passed CLI validation.
- The synthetic smoke command emitted a PARTIAL report.
- 2026-05-03 addendum: the bounded `integrated-av-run` command writes a
  PARTIAL report with operator-supplied baseline ID, video capture/transport
  participation, OSC participation, and ATEM read-only proof fields.
- 2026-05-03 F07 addendum: PASS validation now rejects missing run-window
  evidence, insufficient A/V overlap, audio/integrated report ID mismatches,
  missing video capture/transport report IDs, missing audio/video packet-capture
  points, and placeholder proof fields.
- `swift test --filter IntegratedAvReportTests` passed with 30 M10/F07 tests.
- 2026-05-03 F07 verification passed with `swift test` (334 tests),
  `swift build` after rerunning outside the SwiftPM sandbox failure,
  generated-report validation, fixture validation, synthetic smoke,
  documentation verification, and shellcheck. The generated bounded run recorded
  `audioVideoOverlapSeconds: 60`, `videoCaptureReportId:
  m08-video-capture-synthetic-smoke`, `videoTransportReportId:
  m09-video-transport-run`, and `videoTransportPacketCapturePoint:
  integrated-av-run-loopback`.
- 2026-05-03 M10 AV-sync addendum: the report schema now records explicit
  audio-master sync policy, monotonic video frame timing/identity, nearest/latest
  render policy, stale-frame boundary, stale renders, and audio-hold events.
  PASS validation rejects non-audio master clocks, video-induced audio waits,
  non-monotonic video timestamps, duplicate frame IDs, stale rendered video past
  the boundary, and stale rendered frame counts.
- `swift test --filter IntegratedAvReportTests` passed with 37 M10/F07 tests.
- `swift test` passed with 450 tests.
- `swift build` passed after the known SwiftPM sandbox rerun outside
  `sandbox-exec`.
- Fixture validation, synthetic smoke, bounded generated run, and generated-run
  validation all returned `VERDICT: PARTIAL`.
- Documentation verification passed.
- Shellcheck passed for the docs verifier script.

## Deferred Runtime Evidence

M10 cannot be marked PASS until real reports exist for:

- stable M05/M06 audio route baseline;
- measured M08 camera or file-pattern source;
- measured M09 physical video transport route;
- 30-minute integrated headless A/V run;
- CPU, GPU, and network stress metrics;
- proof that video, rendering, and transport degrade before any audio callback
  p99/max, route verdict, or playout-target change.

## Verdict

M10 source validation is complete, but integrated runtime stress certification
remains open.

VERDICT: PARTIAL

## Resume here

Use `open-lola validate-integrated-av-report <path>` for the first measured
integrated headless A/V report. Keep M10 PARTIAL until the 30-minute run proves
unchanged audio timing under video load.
