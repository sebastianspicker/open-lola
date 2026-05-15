# M07 Latency Tuning Validation Report

Date: 2026-05-03  
Public surface: [Current State](../../docs/current-state.md)  
Status: PARTIAL

## Scope

This report validates the M07 source-level latency tuning contract. It proves
the report schema, PASS guards, fixture, CLI validator, synthetic smoke, and
focused tests for selecting the fastest stable comparable audio profile. It
does not select a physical production profile because accepted M03-M06 measured
evidence and the same-hardware LoLa baseline are still missing.

## Contract

`LatencyTuningReport` records:

- comparison hardware and route identity;
- source report IDs and candidate report rows;
- sample rate, frame size, channel count, corrected one-way latency, RTT,
  jitter, packet loss, underruns, overruns, callback deadline warnings, CPU,
  allocation warnings, and artifact warnings for every candidate;
- whether each candidate is included in the selection matrix or excluded as
  non-comparable hardware/route evidence;
- selected and rollback candidate IDs;
- same-hardware LoLa baseline comparison state;
- latency budget thresholds;
- before/after tuning-change records.

PASS reports require measured physical-reference evidence, at least two
comparable candidates, a selected candidate that is accepted, stable, and the
fastest by corrected one-way latency, a stable rollback candidate, promoted
before/after tuning evidence, same-hardware LoLa baseline comparison, and all
selected-candidate metrics inside the configured thresholds.

## Commands

```bash
swift test --filter LatencyTuning
swift test
swift build
.build/debug/open-lola validate-latency-tuning-report Tests/OpenLolaCoreTests/Fixtures/LatencyTuningReports/valid/latency-tuning-partial.json
.build/debug/open-lola latency-tuning-synthetic-smoke
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
```

## Results

- Red test run before implementation failed because the M07 latency tuning
  report, candidate model, thresholds, change records, validation errors, and
  synthetic smoke did not exist.
- `swift test --filter LatencyTuning` passed with 11 focused tests.
- `swift test` passed with 429 tests.
- `bash scripts/verify-docs.sh` passed.
- `shellcheck scripts/*.sh` passed.
- `.build/debug/open-lola validate-latency-tuning-report
  Tests/OpenLolaCoreTests/Fixtures/LatencyTuningReports/valid/latency-tuning-partial.json`
  passed with `VERDICT: PARTIAL`.
- `.build/debug/open-lola latency-tuning-synthetic-smoke` emitted a valid
  source-validation report with `VERDICT: PARTIAL`.
- `swift build` failed inside the sandbox with SwiftPM manifest
  `sandbox-exec: sandbox_apply: Operation not permitted`, then passed outside
  the sandbox.

## Deferred Runtime Evidence

M07 remains PARTIAL until a physical benchmark matrix records:

- accepted M03-M06 source reports on the same hardware and route;
- direct, switch, and campus rows compared only within matching route labels;
- callback timing, CPU, allocation warning, callback deadline warning, and
  artifact evidence for every candidate;
- stable rollback profile;
- same-hardware LoLa baseline comparison if any external latency claim is made;
- final selected fastest stable measured profile.

## Verdict

M07 source validation is implemented. Physical tuning closure remains open.

VERDICT: PARTIAL

## Resume here

Run the command list above after any M07 schema change. Use
`open-lola validate-latency-tuning-report <path>` for the first measured tuning
matrix after M03-M06 physical evidence exists. Do not resume M08 production
impact claims until the selected M07 audio profile is stable.
