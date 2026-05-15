# M03 Endpoint Loopback Fastest Mode

## Objective

Measure endpoint loopback and select the fastest stable hardware mode using a
16/32/64/128 frame matrix and a 30-minute stability run.

## Background/Context

Fastest mode is not the smallest requested buffer. It is the smallest mode that
the selected hardware accepts and sustains with measured analog latency and
deadline stability.

## Reverse-Engineering Findings

Strong inference:
[../../reverse-engineering/REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md](../../reverse-engineering/REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md)
records Windows LoLa 64-frame int16 behavior around 44.1 kHz. That is a
benchmark baseline, not the Mac-native target.

## Research Findings

[../../research/RESEARCH_BENCHMARK_ROADMAP_2026.md](../../research/RESEARCH_BENCHMARK_ROADMAP_2026.md)
requires accepted frame size, callback p99/max, missed deadline count, reported
latency, analog loopback latency, and proof of no hidden playout growth.

## Assumptions

- M02 can enumerate devices and reported candidate-mode ranges; M03 owns any
  requested-mode probe.
- 32 frames is the main target; 16 frames is accepted only if measured results
  improve.
- 64 and 128 frames are fallback or diagnostic modes.

## Dependencies

- M00 scaffold.
- M01 report schema.
- M02 device inventory.
- Analog loopback cable or measurement interface.

## Affected Modules/Files

- Future audio loopback rig.
- Future endpoint latency report fixtures.
- Future callback metrics module.
- [../RISK_REGISTER.md](../RISK_REGISTER.md)

## Implementation Plan

1. Add loopback rig with fixed test signal and capture path.
2. Probe 48/96/192 kHz where supported.
3. Probe 16/32/64/128 frame modes.
4. Record callback p50/p95/p99/max, misses, underruns, overruns, and measured
   analog round-trip.
5. Run a 30-minute fixed-target stability test on candidate fastest mode.
6. Select fastest stable mode with a dated verdict.

## Test Plan

Before: no loopback report exists.

After:

- mode matrix report validates;
- callback metric tests pass;
- 30-minute stability report exists for selected mode;
- `swift build` and `swift test` pass.

## Validation Method

Compare reported Core Audio latency against measured analog loopback and accept
only the measured result for the fastest-mode decision.

## Acceptance Criteria

- 16/32/64/128 frame matrix is recorded for each tested rate.
- Selected mode has stable callback p99/max and no hidden buffer growth.
- Report includes `VERDICT: PASS`, `VERDICT: FAIL`, or `VERDICT: PARTIAL`.

SOTA 2026 gate:

- Rows: Q002, Q003, SOTA004, SOTA021, SOTA024, SOTA074, SOTA075 in [../SOTA_2026_OPEN_QUESTION_MATRIX.md](../SOTA_2026_OPEN_QUESTION_MATRIX.md).
- Closure rule: analog loopback and 16/32/64/128-frame plus 48/96/192 kHz matrix select fastest stable mode by measurement only.

## Risks and Mitigations

- R002: hardware may reject 16/32 frames. Mitigation: record rejected modes and
  select fastest stable fallback.
- R003: callback safety may regress under measurement. Mitigation: keep logging
  and report writing outside the callback.

## Known Blockers

- Requires physical loopback setup.
- Some interfaces may hide real conversion or safety buffering.

## Progress Checklist

- [ ] Add loopback rig.
- [x] Add mode matrix report.
- [x] Add callback metrics.
- [ ] Run short matrix.
- [ ] Run 30-minute stability test.
- [ ] Select fastest stable mode.
- [x] Update [../PROGRESS.md](../PROGRESS.md).

## Next Recommended Action

Use the M02 inventory output to pick target input/output devices, connect the
analog loopback path, then run the first real 32-frame probe and save it in the
validated M03 report format.

## Resume here

Run `swift run open-lola device-inventory`, choose the target devices, connect
the analog loopback path, then fill a real
`EndpointLoopbackReport` beginning with the 32-frame row.
