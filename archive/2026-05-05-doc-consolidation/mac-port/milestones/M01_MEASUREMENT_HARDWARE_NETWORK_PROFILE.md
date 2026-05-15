# M01 Measurement Hardware Network Profile

## Objective

Define the measurement rig, reference Macs, audio interfaces, network profiles,
and report formats used by every later benchmark.

## Background/Context

The project needs repeatable measurement before any fastest-mode claim. A
benchmark without stable hardware identity, route labels, and report fixtures is
not evidence.

## Reverse-Engineering Findings

Runtime gap:
[../../reverse-engineering/REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md](../../reverse-engineering/REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md)
does not prove Windows hardware timing, exact packet grammar, packet loss
behavior, or 48 kHz interop. Mac measurements must stand on their own.

## Research Findings

[../../research/RESEARCH_BENCHMARK_ROADMAP_2026.md](../../research/RESEARCH_BENCHMARK_ROADMAP_2026.md)
requires endpoint audio latency, network packet timing, playout target, callback
deadline behavior, resource interference, hardware identity, p50/p95/p99/max,
loss/drop counts, and explicit verdicts.

## Assumptions

- At least two Macs can be made available before Mac-to-Mac route tests.
- Audio interface and network route names are stable enough for report labels.
- Fixtures can be validated before real hardware reports exist.

## Dependencies

- M00 scaffold.
- Reference Macs and audio interfaces.
- Wired network routes for direct link, dedicated switch, and campus path.
- A report schema or typed fixture model.

## Affected Modules/Files

- Future measurement fixture directory.
- Future report schema or model tests.
- [../OPEN_QUESTIONS.md](../OPEN_QUESTIONS.md)
- [../PROGRESS.md](../PROGRESS.md)

## Implementation Plan

1. Define report fields for hardware, route, audio mode, timing metrics, and
   verdict.
2. Add sample fixture reports for endpoint, route, video, lighting, and field
   test shapes.
3. Add validation tests for required fields and verdict values.
4. Record reference hardware and route labels when known.
5. Update open questions that remain hardware-dependent.

## Test Plan

Before: no repeatable measurement method exists.

After:

- fixture validation passes;
- invalid fixture tests fail for missing hardware, route, timing, or verdict
  fields;
- documentation link and topic gates pass.

## Validation Method

Run `swift test` after M00 exists and include fixture validation output in the
M01 report.

## Acceptance Criteria

- Report fixtures cover endpoint, network, video, lighting, and field-test
  cases.
- Required fields include hardware identity, route identity, p50/p95/p99/max,
  loss/drop counts, and verdict.
- Measurement reports can be compared across milestones.

SOTA 2026 gate:

- Rows: Q001, SOTA004, SOTA074, SOTA075 in [../SOTA_2026_OPEN_QUESTION_MATRIX.md](../SOTA_2026_OPEN_QUESTION_MATRIX.md).
- Closure rule: hardware identity, route labels, report fields, and pass/fail thresholds are recorded before measurements are treated as comparable.

## Risks and Mitigations

- R002: hardware may not support target frame sizes. Mitigation: fixture schema
  records accepted and rejected modes.
- R006: network claims may drift by route. Mitigation: route identity is
  mandatory.

## Known Blockers

- Exact reference Macs, interfaces, and network paths may require user input.

TODO(human): [M01 hardware inventory] -> Identify reference Macs and audio interfaces for Q001 -> [Use current HfMT Mac pairs / borrow dedicated test Macs / defer hardware closure]

## Progress Checklist

- [x] Define report schema.
- [x] Add valid fixtures.
- [x] Add invalid fixture tests.
- [ ] Record known hardware.
- [ ] Record known network routes.
- [x] Update [../OPEN_QUESTIONS.md](../OPEN_QUESTIONS.md).
- [x] Update [../PROGRESS.md](../PROGRESS.md).

## Next Recommended Action

Provide exact reference Macs, audio interfaces, and route labels to close Q001;
otherwise continue source work only as PARTIAL evidence.

## Resume here

Resume at Q001 in [../OPEN_QUESTIONS.md](../OPEN_QUESTIONS.md): record exact
reference Macs, audio interfaces, OS versions, driver versions, and initial
route labels, then replace placeholder fixture identities with measured
hardware inventory.
