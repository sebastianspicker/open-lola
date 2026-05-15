# M02 Latency Budget And Benchmarks

Date: 2026-05-03  
Status: implemented source-validation contract  
Verdict: PARTIAL

## Objective

Turn the latency budget into a benchmark/report contract that prevents
false-green latency claims.

## Scope

Define report fields, benchmark categories, baseline dry runs, and acceptance
thresholds for later source and hardware work. This milestone does not certify
RME, Blackmagic, route, or lighting hardware.

The latency-first benchmark schema is `original open-lola design`; required
hardware, route, timing, resource, warning, threshold, and verdict fields are an
`experimentally derived requirement`; and synthetic reports staying PARTIAL is
an `implementation hypothesis`.

## Affected Files

- [../architecture/latency-budget.md](../architecture/latency-budget.md)
- [../architecture/benchmark-methodology.md](../architecture/benchmark-methodology.md)
- [../architecture/implementation-roadmap.md](../architecture/implementation-roadmap.md)
- `Sources/OpenLolaCore/LatencyBenchmarkReport.swift`
- `Sources/open-lola/MilestoneCommands.swift`
- `Sources/open-lola/main.swift`
- `Tests/OpenLolaCoreTests/LatencyBenchmarkReportTests.swift`
- `Tests/OpenLolaCoreTests/Fixtures/LatencyBenchmarkReports/`
- `mac-port/reports/M02_LATENCY_BENCHMARKS_2026-05-03.md`

## Implementation Tasks

- Define the shared report fields for hardware, route, media mode, timing,
  resource use, warnings, and verdict.
- Add valid and invalid fixtures for latency report shapes.
- Add validators for required one-way latency, RTT, jitter, loss, CPU,
  allocation, underrun, dropped-frame, and thread-warning fields.
- Classify every reported component as critical path, near-critical path, off
  critical path, optional, or debug-only.
- Add `open-lola validate-latency-benchmark-report <path>` and
  `open-lola latency-benchmark-synthetic-smoke`.

## Test Plan

- Unit tests for report parsing and verdict validation.
- Negative tests for missing hardware, route, timing, threshold, and verdict
  fields.
- Documentation verifier and link checks.

## Benchmark Plan

Run baseline dry runs on available local hardware only as `PARTIAL` evidence.
Record whether a result is synthetic, built-in-device, sandbox-limited, or
physical reference-rig evidence.

Current source validation adds a synthetic dry run only. PASS is guarded behind
`measured` run mode plus `physicalReferenceRig` evidence.

## Acceptance Criteria

- Reports contain one-way estimate, RTT, jitter, loss, underruns, dropped
  frames, CPU, allocation warnings, thread warnings, and verdict.
- Thresholds are explicit and tied to the latency budget.
- Synthetic reports cannot produce physical PASS claims.

## Risks

- Benchmarks can become too broad and delay audio work.
- Built-in-device measurements can be misread as RME evidence.
- Thresholds can hide routing differences if route identity is optional.

## Blockers

No hardware blocker for schema work. Q001 hardware facts are required before
physical benchmark closure.

## Rollback Plan

Revert schema and fixture additions to the previous report contract. No runtime
media path is affected.

## Progress Checklist

- [x] Define benchmark schema.
- [x] Add valid fixtures.
- [x] Add invalid fixtures.
- [x] Add validator tests.
- [x] Run docs verifier and source tests.

## Resume Point

Resume at M03 with the benchmark schema in place. Use
`open-lola validate-latency-benchmark-report <path>` for measured reports and
keep physical PASS blocked until the report uses `measured` run mode with
`physicalReferenceRig` evidence.

VERDICT: PARTIAL
