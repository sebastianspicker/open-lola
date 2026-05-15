# M12 Integrated Profile Validation Report

Date: 2026-05-03
Public surface: [Current State](../../docs/current-state.md)
Status: PARTIAL

## Scope

This report validates the source-level integrated profile contract requested by
the public M12 milestone. It covers profile selection, optional profile cost
labels, degradation order, subordinate evidence aggregation, the four-row
benchmark matrix shape, fixture decoding, synthetic smoke output, and bounded
CLI report generation.

It does not validate a physical audio/video/control benchmark matrix, real RME
hardware, accepted M10/M11 physical evidence, or clean field hardware.

## Implemented Contract

`Sources/OpenLolaCore/IntegratedProfileReport.swift` now records:

- the default profile, which must be `fastest-audio`;
- optional `audio-video`, `audio-lighting`, and `audio-video-lighting`
  profiles, each with explicit latency cost and source/cost report IDs;
- subordinate evidence lanes for fastest audio, audio route, video capture,
  video transport, integrated A/V, and lighting/control;
- degradation order with video quality and frame-rate reduction first,
  lighting disable before audio impact, and audio latency last;
- matrix rows for audio only, audio plus video, audio plus control, and audio
  plus video plus control;
- latency, jitter, loss, late packets, underruns, dropped frames, cue timing,
  CPU, memory, callback warnings, allocation warnings, and scheduling warnings;
- PASS, FAIL, or PARTIAL verdict.

PASS validation rejects:

- any default profile other than `fastest-audio`;
- optional profile promotion into the default slot;
- a missing optional video or lighting/control profile;
- audio-latency degradation before video/control degradation;
- any `PARTIAL` subordinate lane in a PASS report;
- missing measured or physical evidence for subordinate lanes;
- missing matrix scenarios;
- missing measured or physical evidence for matrix rows;
- optional profile latency-cost labels that underreport observed matrix cost;
- hidden aggregate FAIL evidence behind a non-FAIL report.

## Commands

```bash
swift test --filter IntegratedProfileReportTests
swift test
swift build
.build/debug/open-lola validate-integrated-profile-report Tests/OpenLolaCoreTests/Fixtures/IntegratedProfileReports/valid/integrated-profile-partial.json
.build/debug/open-lola integrated-profile-synthetic-smoke
.build/debug/open-lola integrated-profile-run --fastest-audio m07-fastest-audio-required --integrated-av m10-integrated-av-required --lighting-control m11-lighting-control-required --audio-only matrix-audio-only-required --audio-video matrix-audio-video-required --audio-control matrix-audio-control-required --audio-video-control matrix-audio-video-control-required --output /private/tmp/open-lola-m12-integrated-profile-run.json
.build/debug/open-lola validate-integrated-profile-report /private/tmp/open-lola-m12-integrated-profile-run.json
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
```

## Results

- Red focused test run failed before implementation because the M12 integrated
  profile types did not exist.
- `swift test --filter IntegratedProfileReportTests` passed with 12 tests after
  implementation.
- The fixture validates as a `PARTIAL` report with `fastest-audio` as the
  default profile and all four matrix rows present.
- The synthetic smoke emits a `PARTIAL` report.
- The bounded `integrated-profile-run` command writes a `PARTIAL` handoff
  report that records subordinate and matrix report IDs without promoting them
  to PASS.

## Deferred Runtime Evidence

M12 cannot be marked PASS until real reports exist for:

- accepted M07 fastest-audio physical selection;
- accepted M05/M06 audio route and drift/PLC evidence;
- accepted M08/M09 physical video capture and transport evidence;
- accepted M10 integrated A/V physical run;
- accepted M11 lighting/control physical timing and safety evidence;
- measured audio only, audio plus video, audio plus control, and audio plus
  video plus control matrix rows on the same reference route;
- proof that optional profile latency costs are visible to field users and do
  not change the default fastest-audio profile.

## Verdict

M12 source validation is implemented. Physical integrated profile measurement
remains open.

VERDICT: PARTIAL

## Resume here

Run `open-lola integrated-profile-run` with real report IDs once M10 and M11
evidence exists, then validate the generated report with
`open-lola validate-integrated-profile-report <path>`. Keep M12 `PARTIAL` until
the full physical matrix passes.
