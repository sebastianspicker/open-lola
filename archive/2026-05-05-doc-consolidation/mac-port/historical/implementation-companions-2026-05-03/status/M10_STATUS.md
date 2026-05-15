# M10 Status

## Current status

- Status: Partial.
- Verdict: PARTIAL 2026-05-03.
- Canonical milestone: [M10 Integrated Headless A/V](../milestones/M10_INTEGRATED_HEADLESS_AV.md)
- Validation report: [M10 Integrated Headless A/V Validation Report](../reports/M10_INTEGRATED_AV_2026-05-02.md)

Canonical objective:

Prove integrated headless audio/video coexistence with a 30-minute stress run
that preserves the audio callback baseline.

Closure gate:

M10 closes only with P04-style integrated A/V proof. A PASS report must show an
audio-only baseline first, followed by a measured integrated run of at least
1,800 seconds with RME audio, video capture plus video transport or preview, OSC
polling, and ATEM read-only polling. The integrated run must leave audio
callback p99/max, underruns, route verdict, and playout target unchanged.

Canonical assumptions:

- M05/M06 audio path is stable.
- M08/M09 video probes exist and report frame age/drop counts.
- Headless integration precedes native UI.

Canonical dependencies:

- M05 Mac-to-Mac UDP PCM route certification.
- M06 drift/PLC telemetry where available.
- M08 video capture probe.
- M09 video transport probe.

## Completed work

- Added `IntegratedAvReport` schema and validation for headless ownership,
  audio baseline comparison, video capture/transport metrics, system load, and
  verdict.
- Added PASS guards for 30-minute measured runs, PASS audio baseline, PASS
  integrated audio verdict, unchanged callback p99/max, unchanged playout
  target, no UI-owned realtime paths, degradation before audio target changes,
  zero loss/late packets, zero underruns, and no hidden playout growth.
- Added P04 proof evidence to `IntegratedAvReport`. PASS now also requires an
  audio-only baseline first, RME Core Audio device visibility, video capture
  plus video transport or preview, OSC polling evidence, ATEM read-only polling
  evidence, no armed ATEM commands, and unchanged audio route verdict.
- Added `IntegratedHeadlessAvSyntheticSmoke` that composes the M08 synthetic
  capture lane, M09 synthetic transport lane, and explicit PARTIAL P04 proof
  evidence into one unified PARTIAL report.
- Added a synthetic PARTIAL integrated A/V report fixture.
- Added CLI validation with `open-lola validate-integrated-av-report <path>`.
- Added CLI smoke output with `open-lola integrated-av-synthetic-smoke`.
- Added `IntegratedAvRunConfiguration`, `IntegratedAvRunner`, and
  `open-lola integrated-av-run --audio-baseline <report-id> --video-capture
  on|off --video-transport on|off [--video-preview on|off] --osc-control
  on|off --atem-readonly <host|off> --duration-seconds <n> --output <path>`.
  This writes a bounded PARTIAL source-level report and does not claim measured
  P04 closure.
- Added [../reports/M10_INTEGRATED_AV_2026-05-02.md](../reports/M10_INTEGRATED_AV_2026-05-02.md).

## Verified work

- Red test run failed before implementation because M10 integrated A/V types did
  not exist.
- `swift test --filter IntegratedAvReportTests` passed with 9 tests.
- 2026-05-02: P04 proof gate red test failed before implementation because
  `IntegratedAvReport.proof`, `IntegratedProofEvidence`, and the P04 validation
  errors did not exist.
- 2026-05-02: `swift test --filter IntegratedAvReportTests` passed with 18
  tests after adding the P04 proof gate.
- 2026-05-02: `swift test` passed with 170 tests after the P04 proof gate.
- 2026-05-02: `swift build` passed after rerunning outside the SwiftPM
  sandbox failure.
- 2026-05-03: `swift test --filter IntegratedAv` passed with 21 tests after
  adding the source-level `integrated-av-run` parser, report writer, and CLI
  surface.
- `swift test` passed with 75 tests.
- `swift build` passed after rerunning outside the SwiftPM sandbox failure.
- The synthetic PARTIAL integrated A/V fixture passed CLI validation.
- The synthetic smoke command emits a PARTIAL report with explicit P04 proof
  evidence showing the unresolved hardware gates.
- Documentation verification passed.
- Shellcheck passed for the docs verifier script.

## Partially completed work

- Source validation exists for unified integrated reporting, headless ownership
  boundaries, degradation gates, P04 proof evidence, and synthetic A/V
  coexistence smoke.
- PASS-level runtime evidence is not complete because no real 30-minute
  integrated A/V stress run has been recorded.

## Deferred work

- Run a 30-minute integrated headless A/V stress test.
- Use stable M05/M06 audio-only baseline evidence first.
- Use measured M08 capture and M09 transport evidence.
- Use measured M11 OSC and ATEM read-only polling evidence.
- Record CPU, GPU, network, audio callback, packet age, video frame age, and
  control/degradation metrics from real hardware.
- Compare against the accepted audio-only baseline.

## Open tasks

Canonical progress checklist:

- [x] Add integrated runner.
- [x] Add unified report fixture.
- [x] Add degradation event reporting.
- [x] Add P04-style proof evidence and PASS gates.
- [x] Run short integrated smoke.
- [x] Add bounded `integrated-av-run` report writer.
- [ ] Run 30-minute stress.
- [ ] Compare against audio-only baseline.
- [ ] Attach RME, video, OSC, and ATEM read-only measured report IDs.
- [x] Update [../PROGRESS.md](../PROGRESS.md).

SOTA 2026 routing:

- Rows: SOTA007, SOTA008, SOTA035, SOTA039, SOTA045, SOTA047 in
  [../SOTA_2026_OPEN_QUESTION_MATRIX.md](../SOTA_2026_OPEN_QUESTION_MATRIX.md).
- Closure rule: integrated A/V stress proves video, rendering, and control load
  degrade before audio p99/max or playout target changes.

Faster-than-LoLa companion implementation plan:

- [x] Treat M10 as the faster-Mac proof gate. It cannot PASS until M03, M05,
  M06, M08, M09, and M11 have measured evidence or explicit PARTIAL blockers.
- [ ] Run a baseline audio-only report first using the selected RME/Core Audio
  mode and accepted UDP route. Record baseline report ID and route verdict.
- [x] Add an integrated runner CLI: `open-lola integrated-av-run
  --audio-baseline <report-id> --video-capture on|off --video-transport on|off
  [--video-preview on|off] --osc-control on|off --atem-readonly <host|off>
  --duration-seconds <n> --output <path>`.
- [x] Extend integrated reporting only as needed to include subordinate control
  evidence: OSC report ID, ATEM read-only report ID, armed-command state, and
  route comparison. Detailed OSC jitter and ATEM health stay in the M11 reports.
- [ ] Record CPU, GPU, network load, callback p99/max, packet age, lost/late
  packets, underruns, frame age, capture drops, control jitter, and every
  video/control degradation action.
- [ ] PASS requires unchanged audio callback p99/max, underruns, route verdict,
  and playout target for at least 1,800 seconds. Video/control may drop, pause,
  or disable before any audio target growth.

## Known blockers

- Requires stable audio and video probes from prior milestones.
- Hardware stress behavior may vary by Mac model.
- M05/M06 physical audio route, M08 measured capture, and M09 physical video
  transport remain open.

## Test coverage status

Canonical test plan:

Before: audio and video run separately.

After:

- integrated runner starts both lanes;
- unified report validates;
- 30-minute stress run preserves audio callback p99/max and playout target;
- `swift build` and `swift test` pass.

Coverage state: source-level M10 coverage exists for unified report decoding,
synthetic headless A/V smoke, JSON round trip, 30-minute PASS gate, audio p99
gate, playout target gate, UI realtime ownership rejection, non-PASS baseline
rejection, degradation-before-audio gate, P04 proof presence, audio-only
baseline ordering, RME audio visibility, video capture participation, video
transport-or-preview participation, OSC polling, ATEM read-only polling,
ATEM command disarming, unchanged route verdict, `integrated-av-run` argument
parsing, invalid switch rejection, and PARTIAL report generation. Runtime
30-minute stress coverage is still missing.

## Relevant files touched

- [../../Sources/OpenLolaCore/IntegratedAvReport.swift](../../Sources/OpenLolaCore/IntegratedAvReport.swift)
- [../../Sources/open-lola/main.swift](../../Sources/open-lola/main.swift)
- [../../Tests/OpenLolaCoreTests/IntegratedAvReportTests.swift](../../Tests/OpenLolaCoreTests/IntegratedAvReportTests.swift)
- [../../Tests/OpenLolaCoreTests/Fixtures/IntegratedAvReports/valid/integrated-av-partial.json](../../Tests/OpenLolaCoreTests/Fixtures/IntegratedAvReports/valid/integrated-av-partial.json)
- [../reports/M10_INTEGRATED_AV_2026-05-02.md](../reports/M10_INTEGRATED_AV_2026-05-02.md)
- [../milestones/M10_INTEGRATED_HEADLESS_AV.md](../milestones/M10_INTEGRATED_HEADLESS_AV.md)
- [../PROGRESS.md](../PROGRESS.md)
- [../STATUS_INDEX.md](../STATUS_INDEX.md)
- [../VALIDATION_CHECKLIST.md](../VALIDATION_CHECKLIST.md)
- [../MILESTONE_INDEX.md](../MILESTONE_INDEX.md)
- [../SOTA_2026_OPEN_QUESTION_MATRIX.md](../SOTA_2026_OPEN_QUESTION_MATRIX.md)
- [../RISK_REGISTER.md](../RISK_REGISTER.md)
- [../../MAC_PORT_PLAN.md](../../MAC_PORT_PLAN.md)

## Latest verification

Commands:

```bash
swift test --filter IntegratedAvReportTests
swift test --filter IntegratedAv
swift test
swift build
.build/debug/open-lola validate-integrated-av-report Tests/OpenLolaCoreTests/Fixtures/IntegratedAvReports/valid/integrated-av-partial.json
.build/debug/open-lola integrated-av-synthetic-smoke
.build/debug/open-lola integrated-av-run --audio-baseline m05-route-baseline-required --video-capture on --video-transport on --osc-control on --atem-readonly 192.0.2.10 --duration-seconds 60 --output /private/tmp/open-lola-m10-integrated-av-run.json
.build/debug/open-lola validate-integrated-av-report /private/tmp/open-lola-m10-integrated-av-run.json
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
```

Result:

- Swift tests and build pass.
- CLI fixture validation and synthetic smoke pass.
- Documentation verification and shellcheck pass.
- 2026-05-02: faster-than-LoLa companion plan update passed
  `bash scripts/verify-docs.sh` and `shellcheck scripts/*.sh`.
- 2026-05-02: P04 proof gate focused tests passed with
  `swift test --filter IntegratedAvReportTests`.
- 2026-05-02: Full verification passed with `swift test` (170 tests),
  `swift build`, CLI integrated report validation, CLI integrated synthetic
  smoke, `bash scripts/verify-docs.sh`, and `shellcheck scripts/*.sh`.
- 2026-05-03: Full G10 verification passed with `swift test` (259 tests),
  `swift build` after rerunning outside the SwiftPM sandbox failure,
  `integrated-av-run`, generated-report validation, fixture validation,
  synthetic smoke, `bash scripts/verify-docs.sh`, and `shellcheck scripts/*.sh`.
- VERDICT: PARTIAL

## Next recommended steps

Run the first measured P04 integrated proof after M03, M05, M06, M08, M09, and
M11 runtime evidence exists. Start with the RME/Core Audio audio-only baseline,
then run the 1,800-second integrated measurement with video and read-only
control load.

## Resume here

Start from a real M05/M06 audio-only baseline report. Then produce a measured
M10 integrated report with populated `proof` evidence and validate it with
`open-lola validate-integrated-av-report <path>`. Keep M10 PARTIAL until the
report proves unchanged audio timing and route verdict under video/control load.
