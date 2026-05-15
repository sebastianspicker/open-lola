# M06 Status

## Current status

- Status: Partial.
- Canonical milestone: [M06 Drift And Same-Deadline PLC](../milestones/M06_DRIFT_AND_SAME_DEADLINE_PLC.md)

Canonical objective:

Add drift telemetry and same-deadline PLC policy without increasing default
audio playout latency.

Canonical assumptions:

- Silence is the baseline PLC.
- Repeat or simple bounded substitute may be tested before complex PLC.
- Fractional resampling, if used, runs outside the callback.

Canonical dependencies:

- M03 fastest endpoint mode.
- M04 packet timestamps and sender frame index.
- M05 route certification.
- Long-run report schema.

Canonical affected modules/files:

- [../../Sources/OpenLolaCore/DriftPlcReport.swift](../../Sources/OpenLolaCore/DriftPlcReport.swift)
- [../../Sources/open-lola/main.swift](../../Sources/open-lola/main.swift)
- [../../Tests/OpenLolaCoreTests/DriftPlcReportTests.swift](../../Tests/OpenLolaCoreTests/DriftPlcReportTests.swift)
- [../../Tests/OpenLolaCoreTests/Fixtures/DriftPlcReports/valid/drift-plc-partial.json](../../Tests/OpenLolaCoreTests/Fixtures/DriftPlcReports/valid/drift-plc-partial.json)
- Future 60-minute run report fixture.
- [../RISK_REGISTER.md](../RISK_REGISTER.md)

Canonical implementation sequence:

1. Add drift counters from sender frame index and receiver playout position.
2. Add same-deadline PLC policy options: silence, repeat, and optional bounded
   candidates.
3. Add tests proving PLC does not change playout target.
4. Add long-run report fields for drift slope, correction events, underruns,
   and artifacts.
5. Run 60-minute fixed-target test.

Canonical acceptance criteria:

- Drift telemetry is visible.
- Same-deadline PLC never waits for retransmission.
- Correction work is outside callback or branch-bounded inside the due block.
- PASS requires a 60-minute fixed-target route run with no playout-target
  growth, non-empty artifact notes, drift telemetry, correction evidence
  outside the realtime callback, completed artifact assessment, and a validated
  report.
- 60-minute report has a verdict.

Rollback/recovery notes:

- Documentation-only changes: restore the preserved historical copy when one exists, or revert the specific changed file.
- Source changes: revert the smallest affected change set and rerun `swift test`.
- Hardware, network, audio, video, lighting, recording, or packaging reports: mark the report invalid rather than deleting it, then rerun measurement.

## Completed work

- Added `DriftPlcReport` and supporting telemetry, same-deadline PLC event,
  correction event, metric, PLC policy, and correction-location models.
- Added validation for required fields, packet mode, telemetry drift math,
  callback p99/max ordering, event counts, max drift, same-deadline PLC target
  stability, no retransmission wait, branch-bounded PLC substitution, no hidden
  playout growth, and no unbounded correction inside the callback.
- Added PASS guards requiring a 60-minute run, zero underruns, and completed
  artifact assessment.
- Tightened PASS validation so correction evidence must be outside the
  realtime callback, even though PARTIAL reports may still document
  branch-bounded due-block behavior for comparison.
- Added a synthetic PARTIAL drift/PLC fixture.
- Added `open-lola validate-drift-plc-report <path>`.
- Added `open-lola drift-plc-synthetic-smoke`.
- Added `DriftPlcRunConfiguration` and `open-lola drift-plc-run
  --route-report <path> --duration-seconds <n> --policy
  silence|repeat|bounded-substitute --artifact-assessment-completed true|false
  --artifact-notes <text> --output <path>`.
- Added `DriftPlcFixedTargetRunner`, which reads a validated M05 route report,
  keeps a fixed playout target, emits drift telemetry checkpoints, records a
  same-deadline PLC policy event, records outside-callback correction evidence,
  preserves artifact notes, and writes a validated M06 report.
- Added the G05 `DriftPlcFixedTargetCertificationReport` wrapper around an
  accepted G04 route certification and a PASS drift/PLC report.
- Added G05 PASS guards for measured run mode, accepted route certification,
  accepted drift/PLC report, packet-mode parity, route identity parity, run
  artifact path, and placeholder evidence.
- Added `open-lola validate-drift-plc-certification-report <path>` and
  `open-lola drift-plc-certification-synthetic-smoke`.
- Kept silence as the baseline PLC policy. Repeat-last-good-block and bounded
  substitute are only represented as same-deadline, branch-bounded comparisons
  with unchanged playout target.
- Added [../reports/M06_DRIFT_PLC_2026-05-02.md](../reports/M06_DRIFT_PLC_2026-05-02.md).

## Verified work

- Red test run before implementation failed on missing M06 drift/PLC types.
- `swift test --filter DriftPlcReportTests` passed with 8 M06 tests.
- `swift test` passed with 41 tests.
- `swift build` passed after rerunning outside the SwiftPM sandbox failure.
- `.build/debug/open-lola validate-drift-plc-report
  Tests/OpenLolaCoreTests/Fixtures/DriftPlcReports/valid/drift-plc-partial.json`
  passed.
- `.build/debug/open-lola drift-plc-synthetic-smoke` emitted a PARTIAL report
  and passed validation.
- Red test run for `drift-plc-run` failed on missing
  `DriftPlcRunConfiguration`, `DriftPlcFixedTargetRunner`, and
  `passCorrectionNotOutsideCallback` before implementation.
- `swift test --filter DriftPlcReportTests` passed with 13 M06 tests after the
  fixed-target runner and CLI support were added.
- `swift build` passed after the fixed-target runner and CLI support were
  added.
- `swift test` passed with 146 tests after the fixed-target runner and CLI
  support were added.
- `.build/debug/open-lola drift-plc-run --route-report
  Tests/OpenLolaCoreTests/Fixtures/UdpPcmRoutes/valid/direct-link-pass.json
  --duration-seconds 3600 --policy silence --artifact-assessment-completed true
  --artifact-notes "Fixture-based artifact note for CLI validation only."
  --output /private/tmp/open-lola-drift-plc-run.json` wrote a validated
  fixture-derived report with `VERDICT: PASS`. This proves the report contract
  only; it is not physical M06 closure.
- `.build/debug/open-lola validate-drift-plc-report
  /private/tmp/open-lola-drift-plc-run.json` passed.
- Red G05 certification test-first run failed on missing
  `DriftPlcFixedTargetCertificationReport`, validation errors, and synthetic
  smoke.
- `swift test --filter DriftPlcFixedTargetCertification` passed with 13 G05
  tests after adding the certification wrapper and CLI branch.
- `swift build` passed after sandbox escalation for SwiftPM manifest
  compilation.
- `swift test` passed with 232 tests after adding the G05 wrapper.
- `.build/debug/open-lola validate-drift-plc-certification-report
  Tests/OpenLolaCoreTests/Fixtures/DriftPlcFixedTargetCertificationReports/valid/g05-drift-plc-certification-partial.json`
  passed and emitted `VERDICT: PARTIAL`.
- `.build/debug/open-lola drift-plc-certification-synthetic-smoke` passed and
  emitted `VERDICT: PARTIAL`.
- `.build/debug/open-lola validate-drift-plc-report
  Tests/OpenLolaCoreTests/Fixtures/DriftPlcReports/valid/drift-plc-partial.json`
  passed and emitted `VERDICT: PARTIAL`.
- `.build/debug/open-lola drift-plc-synthetic-smoke` passed and emitted
  `VERDICT: PARTIAL`.
- `shellcheck scripts/*.sh` passed after the G05 wrapper implementation.
- `bash scripts/verify-docs.sh` passed after the G05 wrapper implementation.
- `bash scripts/verify-docs.sh` passed after the M06 status update.
- `shellcheck scripts/*.sh` passed after the M06 status update.

## Partially completed work

- M06 source validation, synthetic smoke, fixed-target report generation,
  `drift-plc-run` CLI support, and G05 certification wrapper validation are
  complete.
- No real 60-minute fixed-target physical route run has been executed.
- No real artifact listening notes exist.
- No real drift behavior has been measured on a stable M05 route.

## Deferred work

- Use a stable M05 physical route report for a real 60-minute fixed-target
  drift/PLC run.
- Use silence as the baseline PLC policy first. Compare repeat and any bounded
  substitute only as same-deadline, branch-bounded policies with no playout
  growth.
- Record artifact notes from human listening or an accepted artifact assessment
  process.
- Evaluate Audio Workgroups only after measured missed-deadline benefit.

## Open tasks

Canonical progress checklist:

- [x] Add drift telemetry.
- [x] Add silence baseline.
- [x] Add same-deadline substitute policy tests.
- [x] Add long-run report fields.
- [x] Add fixed-target drift/PLC run CLI.
- [x] Add G05 fixed-target certification wrapper validator.
- [ ] Run 60-minute fixed-target test.
- [ ] Record artifact notes.
- [x] Update [../PROGRESS.md](../PROGRESS.md).

SOTA 2026 routing:

- Rows: SOTA001, SOTA002, SOTA003, SOTA006, SOTA010, SOTA018, SOTA022 in [../SOTA_2026_OPEN_QUESTION_MATRIX.md](../SOTA_2026_OPEN_QUESTION_MATRIX.md).
- Closure rule: drift correction and PLC remain same-deadline, measurable, and unable to grow the default playout target.

Faster-than-LoLa companion implementation plan:

- [x] Add a 60-minute drift/PLC runner after M05 has a stable physical route.
  The CLI surface should be `open-lola drift-plc-run --route-report <path>
  --duration-seconds 3600 --policy silence|repeat --output <path>`.
- [x] Keep silence as the baseline PLC policy. Add repeat or another bounded
  substitute only after silence validates with unchanged playout target.
- [x] Derive drift from sender frame index and fixed local playout position in
  the route report conversion path. The live 60-minute physical run still needs
  sender host timestamp and receiver host timestamp capture from the route
  runner.
- [x] Keep PASS correction evidence outside the realtime callback. PARTIAL
  comparison reports may still document branch-bounded due-block behavior.
  Never wait for retransmission.
- [x] Record human listening notes or an accepted artifact assessment in the
  report. Numeric timing alone is not enough to accept a PLC substitute.
- [x] Add a G05 certification wrapper so fixture-derived drift/PLC PASS reports
  cannot be mistaken for physical closure.
- [ ] Evaluate Audio Workgroups only after the simple callback plus network
  thread design shows missed deadlines that Audio Workgroups plausibly reduce.

## Known blockers

- Requires stable M05 route.
- Artifact assessment may need human listening notes in addition to metrics.
- M06 cannot PASS until a 60-minute fixed-target report validates.
- Source-level PASS fixtures prove the report contract only; they do not close
  M06 without a real M05/G04 physical route, artifact notes, and a passing G05
  certification wrapper.

## Test coverage status

Canonical test plan:

Before: long run creeps or lacks telemetry.

After:

- unit tests prove target depth does not grow;
- long-run report validates;
- synthetic drift/PLC smoke emits a PARTIAL report;
- fixed-target runner emits a validated M06 report from a validated M05 route
  report;
- G05 fixed-target certification wrapper validates the accepted route/drift
  evidence boundary;
- 60-minute fixed-target run records drift and PLC behavior;
- `swift build` and `swift test` pass.

Coverage state: Swift tests cover valid drift/PLC report decoding, JSON round
trip, retransmission-wait rejection, playout-target-growth rejection, unbounded
callback correction rejection, PASS correction-outside-callback enforcement,
hidden playout growth rejection, PASS duration guard, drift-plc-run
configuration parsing, invalid policy rejection, fixed-target 60-minute report
generation, repeat policy same-deadline invariants, and synthetic smoke
validation. G05 wrapper tests cover partial fixture validation, synthetic smoke,
measured-run requirement, route-certification requirement, drift-report
requirement, accepted-route requirement, accepted-drift requirement,
packet-mode mismatch rejection, route mismatch rejection, run-artifact
requirement, placeholder rejection, PASS candidate validation, and JSON round
trip.

## Relevant files touched

Planned affected modules/files:

- Future drift telemetry module.
- Future PLC policy module.
- Future 60-minute run report fixture.
- [../RISK_REGISTER.md](../RISK_REGISTER.md)

Live files touched:

- [../../Sources/OpenLolaCore/DriftPlcReport.swift](../../Sources/OpenLolaCore/DriftPlcReport.swift)
- [../../Sources/OpenLolaCore/DriftPlcFixedTargetCertification.swift](../../Sources/OpenLolaCore/DriftPlcFixedTargetCertification.swift)
- [../../Sources/open-lola/main.swift](../../Sources/open-lola/main.swift)
- [../../Tests/OpenLolaCoreTests/DriftPlcReportTests.swift](../../Tests/OpenLolaCoreTests/DriftPlcReportTests.swift)
- [../../Tests/OpenLolaCoreTests/DriftPlcFixedTargetCertificationTests.swift](../../Tests/OpenLolaCoreTests/DriftPlcFixedTargetCertificationTests.swift)
- [../../Tests/OpenLolaCoreTests/Fixtures/DriftPlcReports/valid/drift-plc-partial.json](../../Tests/OpenLolaCoreTests/Fixtures/DriftPlcReports/valid/drift-plc-partial.json)
- `../../Tests/OpenLolaCoreTests/Fixtures/DriftPlcFixedTargetCertificationReports/`
- [../reports/M06_DRIFT_PLC_2026-05-02.md](../reports/M06_DRIFT_PLC_2026-05-02.md)
- [../milestones/M06_DRIFT_AND_SAME_DEADLINE_PLC.md](../milestones/M06_DRIFT_AND_SAME_DEADLINE_PLC.md)
- [../PROGRESS.md](../PROGRESS.md)
- [../STATUS_INDEX.md](../STATUS_INDEX.md)
- [../../MAC_PORT_PLAN.md](../../MAC_PORT_PLAN.md)
- [../VALIDATION_CHECKLIST.md](../VALIDATION_CHECKLIST.md)
- [../MILESTONE_INDEX.md](../MILESTONE_INDEX.md)
- [../SOTA_2026_OPEN_QUESTION_MATRIX.md](../SOTA_2026_OPEN_QUESTION_MATRIX.md)
- [../RISK_REGISTER.md](../RISK_REGISTER.md)

## Latest verification

- 2026-05-02: `swift test --filter DriftPlcReportTests` passed with 8 M06 tests.
- 2026-05-02: `swift test` passed with 41 tests.
- 2026-05-02: `swift build` passed after sandbox escalation.
- 2026-05-02: `.build/debug/open-lola validate-drift-plc-report
  Tests/OpenLolaCoreTests/Fixtures/DriftPlcReports/valid/drift-plc-partial.json`
  passed.
- 2026-05-02: `.build/debug/open-lola drift-plc-synthetic-smoke` passed and
  emitted `VERDICT: PARTIAL`.
- 2026-05-02: `bash scripts/verify-docs.sh` passed.
- 2026-05-02: `shellcheck scripts/*.sh` passed.
- 2026-05-02: faster-than-LoLa companion plan update passed
  `bash scripts/verify-docs.sh` and `shellcheck scripts/*.sh`.
- 2026-05-02: red test-first `drift-plc-run` pass failed on missing runner
  types and stricter PASS correction validation before implementation.
- 2026-05-02: `swift test --filter DriftPlcReportTests` passed with 13 M06
  tests after fixed-target runner implementation.
- 2026-05-02: `swift build` passed.
- 2026-05-02: `swift test` passed with 146 tests.
- 2026-05-02: fixture-derived `.build/debug/open-lola drift-plc-run` wrote
  `/private/tmp/open-lola-drift-plc-run.json` for a 3600-second silence
  baseline with outside-callback correction evidence and `VERDICT: PASS`.
- 2026-05-02: `.build/debug/open-lola validate-drift-plc-report
  /private/tmp/open-lola-drift-plc-run.json` passed.
- 2026-05-02: red G05 certification test-first run failed on missing
  `DriftPlcFixedTargetCertificationReport`, validation errors, and synthetic
  smoke.
- 2026-05-02: `swift test --filter DriftPlcFixedTargetCertification` passed
  with 13 G05 tests after implementation.
- 2026-05-02: `swift build` passed after sandbox escalation for SwiftPM
  manifest compilation.
- 2026-05-02: `swift test` passed with 232 tests.
- 2026-05-02: `.build/debug/open-lola validate-drift-plc-certification-report
  Tests/OpenLolaCoreTests/Fixtures/DriftPlcFixedTargetCertificationReports/valid/g05-drift-plc-certification-partial.json`
  passed and emitted `VERDICT: PARTIAL`.
- 2026-05-02: `.build/debug/open-lola drift-plc-certification-synthetic-smoke`
  passed and emitted `VERDICT: PARTIAL`.
- 2026-05-02: `.build/debug/open-lola validate-drift-plc-report
  Tests/OpenLolaCoreTests/Fixtures/DriftPlcReports/valid/drift-plc-partial.json`
  passed and emitted `VERDICT: PARTIAL`.
- 2026-05-02: `.build/debug/open-lola drift-plc-synthetic-smoke` passed and
  emitted `VERDICT: PARTIAL`.
- 2026-05-02: `shellcheck scripts/*.sh` passed.
- 2026-05-02: `bash scripts/verify-docs.sh` passed after the G05 status
  update.
- 2026-05-02: `bash scripts/verify-docs.sh` passed.
- 2026-05-02: `shellcheck scripts/*.sh` passed.
- VERDICT: PARTIAL

## Next recommended steps

Use a stable M05 physical route to run `drift-plc-run` for a 60-minute
fixed-target measurement. Validate the resulting report with
`open-lola validate-drift-plc-report <path>`, then validate the G05 wrapper
with `open-lola validate-drift-plc-certification-report <path>`.

## Resume here

Use the implemented M06 report schema, synthetic smoke, fixed-target runner,
and invariant tests to record a real 60-minute fixed-target run. Start with:

```bash
swift run open-lola drift-plc-run --route-report <m05-direct-route-report.json> --duration-seconds 3600 --policy silence --artifact-assessment-completed true --artifact-notes "<listening/artifact notes>" --output reports/m06-drift-plc-direct-silence.json
```

Do not mark M06 PASS until the report uses stable M05/G04 physical route
evidence, records artifact notes, proves the playout target did not grow under
silence and any tested substitute policy, and passes the G05 certification
wrapper.
