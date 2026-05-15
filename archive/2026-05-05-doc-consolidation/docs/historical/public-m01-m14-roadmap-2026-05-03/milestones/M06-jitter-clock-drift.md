# M06 Jitter And Clock Drift

Date: 2026-05-03  
Status: source implementation complete; physical certification pending  
Verdict: PARTIAL

## Objective

Add fixed-target jitter handling, clock drift detection, and same-deadline PLC
without increasing default audio latency.

## Scope

Cover sequence tracking, packet age, drift estimation, correction outside the
callback, underrun handling, and 60-minute fixed-target certification.

## Affected Files

- [../architecture/latency-first-architecture.md](../architecture/latency-first-architecture.md)
- [../architecture/latency-budget.md](../architecture/latency-budget.md)
- `Sources/OpenLolaCore/DriftPlcHelpers.swift`
- `Sources/OpenLolaCore/DriftPlcReport.swift`
- `Sources/OpenLolaCore/DriftPlcRun.swift`
- `Sources/OpenLolaCore/RealtimeAudioEngine.swift`
- `Tests/OpenLolaCoreTests/DriftPlcReportTests.swift`
- `Tests/OpenLolaCoreTests/DriftPlcFixedTargetCertificationTests.swift`

## Implementation Tasks

- [x] Implement fixed playout target validation.
- [x] Estimate sender/receiver drift outside the callback.
- [x] Apply bounded correction without hidden buffer growth.
- [x] Use same-deadline silence, repeat, or bounded substitute PLC only when due
  media is unavailable.
- [ ] Record the 60-minute physical fixed-target certification report.

## Test Plan

- Jitter-buffer unit tests.
- Clock-drift estimator tests.
- PLC policy tests.
- Negative tests for hidden target growth and callback correction work.

## Benchmark Plan

Run a 60-minute physical route test after M04 and M05 PASS. Record drift,
corrections, PLC events, underruns, packet age, artifacts, and callback timing.

## Acceptance Criteria

- Fixed target remains zero or one block unless explicitly configured
  otherwise.
- Drift correction runs outside the audio callback.
- No hidden buffer growth.
- 60-minute physical report exists for PASS.

## Risks

- Drift can appear stable in short tests and fail over performance duration.
- PLC can mask a bad route if artifact reporting is weak.
- Correction can create audible artifacts if applied too aggressively.

## Blockers

Accepted M04 loopback, accepted M05 direct route, and long-run test availability.

## Rollback Plan

Disable drift correction and keep fixed-target packet accounting as source
validation only.

## Progress Checklist

- [x] Fixed target tests pass.
- [x] Drift estimator tests pass.
- [x] PLC policy tests pass.
- [ ] 60-minute run recorded.
- [x] M06 source-validation report stored.
- [ ] M06 physical certification report stored.

## Resume Point

Resume at the 60-minute fixed-target route run after M04/M05 physical evidence
is accepted. Do not mark M06 PASS until the measured report and artifact notes
validate.

VERDICT: PARTIAL
