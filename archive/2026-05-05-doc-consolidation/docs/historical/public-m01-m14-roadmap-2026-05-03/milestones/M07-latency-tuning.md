# M07 Latency Tuning

Date: 2026-05-03  
Status: source implementation complete; physical tuning pending  
Verdict: PARTIAL

## Objective

Select the fastest stable measured audio profile and record the tuning evidence
needed for later integrated comparisons.

## Scope

Cover buffer-size comparison, sample-rate comparison, route comparison,
callback timing, resource use, and same-hardware baseline comparison.

## Affected Files

- [../architecture/latency-budget.md](../architecture/latency-budget.md)
- [../architecture/benchmark-methodology.md](../architecture/benchmark-methodology.md)
- `Sources/OpenLolaCore/LatencyTuningReport.swift`
- `Sources/OpenLolaCore/LatencyTuningReportValidation.swift`
- `Sources/open-lola/MilestoneCommands.swift`
- `Tests/OpenLolaCoreTests/LatencyTuningReportTests.swift`
- `Tests/OpenLolaCoreTests/Fixtures/LatencyTuningReports/valid/latency-tuning-partial.json`
- [../../mac-port/reports/M07_LATENCY_TUNING_2026-05-03.md](../../mac-port/reports/M07_LATENCY_TUNING_2026-05-03.md)
- Existing F10 faster-than-LoLa closure reports and validators

## Implementation Tasks

- [x] Add a latency-tuning report contract for candidate sample rates and frame
  sizes.
- [x] Compare direct, switch, and campus routes only within matching route and
  hardware identity.
- [x] Record before/after latency for every major tuning change.
- [x] Reject PASS when the selected mode is not the fastest stable comparable
  candidate.
- [ ] Collect comparable physical reports for accepted M03-M06 modes.
- [ ] Promote only the fastest stable physical mode.

## Test Plan

- [x] Report comparison tests.
- [x] Threshold regression tests.
- [x] Negative tests for comparing reports with mismatched hardware or route
  identity.
- [x] Negative tests for synthetic PASS, unstable selection, non-fastest
  selection, missing same-hardware baseline comparison, and promoted changes
  without lower one-way latency.

## Benchmark Plan

Run regression benchmark matrix over the accepted M03-M06 modes. Record
corrected one-way latency, RTT, jitter, CPU, allocation warnings, callback
deadline warnings, and artifacts.

## Acceptance Criteria

- A single fastest stable audio profile is selected.
- Comparison excludes non-comparable hardware or route reports.
- Every promoted tuning change has before/after data.
- PASS requires measured physical-reference evidence, a rollback candidate,
  same-hardware LoLa baseline comparison, thresholds inside the latency budget,
  no callback deadline warnings, no allocation warnings, and no artifact
  warnings.

## Risks

- A lower-latency mode may be unstable over performance duration.
- CPU load from later video can invalidate audio-only tuning.
- Same-hardware legacy baseline may not be available.

## Blockers

Accepted M03-M06 evidence and any same-hardware baseline required for external
latency claims.

## Rollback Plan

Return to the last stable PASS audio profile. Do not keep a tuning change that
requires extra default buffering.

## Progress Checklist

- [ ] Candidate modes measured.
- [x] Reports compared with matching identity in source validation.
- [ ] Fastest stable mode selected.
- [x] Regression thresholds recorded in the M07 report contract.
- [x] M07 source-validation report stored.
- [ ] M07 physical tuning report stored.

## Resume Point

Resume at physical M07 tuning after accepted M03-M06 evidence exists. Resume at
M08 only after the audio profile is stable enough to detect video impact.

VERDICT: PARTIAL
