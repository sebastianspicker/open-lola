# P04 Status

## Current status

- Status: Partial.
- Canonical prototype milestone: [P04 Integrated A/V Proof](../P04_INTEGRATED_AV_PROOF.md)
- Objective: prove 30-minute coexistence of RME audio plus video/capture/control
  load without worsening audio timing.
- Assumptions: P02 provides audio baseline; P03 provides capture/control
  evidence; video/control degrade before audio target growth.
- Dependencies: baseline audio-only report, integrated A/V report shape,
  capture/control metrics, and a 30-minute run window.
- Affected modules/files: integrated A/V report, video capture probe, UDP PCM
  route certification, and this status companion.
- Implementation sequence: run baseline, run integrated measurement, record
  CPU/GPU/network/audio/video/control metrics, record degradation, compare audio
  metrics, validate report.
- Acceptance criteria: at least 1,800 seconds integrated duration, unchanged
  audio callback p99/max, underruns, playout target, and route verdict, with
  visible subordinate video/control metrics.
- Rollback/recovery notes: if integrated load worsens audio timing, reject the
  report and reduce/disable video or control before rerunning.

## Completed work

- Added the P04 prototype milestone contract.
- Added this live P04 companion.
- Added source-level `integrated-av-run` support that writes a PARTIAL
  integrated report with baseline, video capture/transport, OSC, and ATEM
  read-only proof fields.

## Verified work

- Baseline documentation verifier and shellcheck passed before adding the
  prototype layer.
- Post-change `swift build` passed.
- Post-change `swift test` passed with 128 Swift Testing tests.
- Post-change `bash scripts/verify-docs.sh` passed with prototype docs included.
- Post-change `shellcheck scripts/*.sh` passed.
- Existing valid integrated A/V fixture passed
  `swift run open-lola validate-integrated-av-report`.

## Partially completed work

- Existing M10 report contract includes integrated A/V validation.
- M10 can now emit a bounded PARTIAL integrated report for wiring proof and
  CLI validation.
- No P02 baseline or P03 capture/control evidence was produced in this session.

## Deferred work

- Baseline report ID is deferred until P02 produces a measured route.
- Integrated report ID and 30-minute run evidence are deferred until P02/P03
  are ready.

## Open tasks

- [ ] Record baseline report ID.
- [ ] Record integrated report ID.
- [ ] Record 30-minute run start and end.
- [ ] Record CPU, GPU, network, callback, packet, underrun, frame, drop, and
  control-jitter metrics.
- [ ] Record degradation actions taken.
- [ ] Record audio comparison verdict.
- [ ] Validate integrated A/V report.

## Known blockers

- P02 audio baseline is not complete.
- P03 capture/control evidence is not complete.
- Full PASS requires an uninterrupted 1,800 second run.

## Test coverage status

- Required general gates: `swift build`, `swift test`,
  `bash scripts/verify-docs.sh`, `shellcheck scripts/*.sh`.
- Required hardware gate: `swift run open-lola validate-integrated-av-report
  <path>`.
- Coverage state: integrated report validator and bounded source-level
  `integrated-av-run` writer exist; real 30-minute integrated hardware run is
  not recorded yet.

## Relevant files touched

- [../P04_INTEGRATED_AV_PROOF.md](../P04_INTEGRATED_AV_PROOF.md)
- [P04_STATUS.md](P04_STATUS.md)
- [../../../Sources/OpenLolaCore/IntegratedAvReport.swift](../../../Sources/OpenLolaCore/IntegratedAvReport.swift)
- [../../../Sources/open-lola/main.swift](../../../Sources/open-lola/main.swift)
- [../../../Tests/OpenLolaCoreTests/IntegratedAvReportTests.swift](../../../Tests/OpenLolaCoreTests/IntegratedAvReportTests.swift)

## Latest verification

- 2026-05-02: `swift build` passed.
- 2026-05-02: `swift test` passed with 128 Swift Testing tests.
- 2026-05-02: `bash scripts/verify-docs.sh` passed.
- 2026-05-02: `shellcheck scripts/*.sh` passed.
- 2026-05-02: `swift run open-lola validate-integrated-av-report
  Tests/OpenLolaCoreTests/Fixtures/IntegratedAvReports/valid/integrated-av-partial.json`
  passed with `VERDICT: PARTIAL`.
- 2026-05-03: `swift test --filter IntegratedAv` passed with 21 tests after
  adding `integrated-av-run` parser and PARTIAL report generation.
- 2026-05-03: Full G10/P04 source verification passed with `swift test`
  (259 tests), `swift build` after rerunning outside the SwiftPM sandbox
  failure, `integrated-av-run`, generated-report validation, fixture
  validation, synthetic smoke, `bash scripts/verify-docs.sh`, and
  `shellcheck scripts/*.sh`.
- VERDICT: PARTIAL

## Next recommended steps

After P02 and P03 have measured evidence, run `integrated-av-run` as a short
source-level wiring proof, then run the 1,800 second measured integrated proof
and compare it against the accepted audio-only baseline.

## Resume here

Resume after P02 records an audio baseline and P03 records capture/control
state. Start by filling the baseline report ID and producing a short
`integrated-av-run` report.
