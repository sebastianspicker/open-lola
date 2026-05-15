# M02 Latency Benchmark Contract Validation Report

Date: 2026-05-03  
Public surface: [Current State](../../docs/current-state.md)  
Status: PARTIAL

## Scope

This report validates the M02 source-level latency benchmark contract. It
proves the JSON schema, validation rules, fixtures, CLI validator, and synthetic
smoke path. It does not certify RME, Blackmagic, lighting, direct P2P route, or
physical reference-rig latency.

## Contract

`LatencyBenchmarkReport` records:

- report ID, title, timestamp, run mode, evidence kind, and verdict;
- hardware identity, route identity, and media mode;
- one-way latency estimate, RTT, and jitter p50/p95/p99/max;
- lost packets, late packets, and packet-loss percent;
- underruns, overruns, missed deadlines, and dropped frames;
- CPU p50/p95/p99/max, resident memory, allocation warnings, and thread
  warnings;
- explicit thresholds tied to
  `docs/architecture/latency-budget.md#audio-budget`;
- component measurements classified as `criticalPath`, `nearCriticalPath`,
  `offCriticalPath`, `optional`, or `debugOnly`;
- notes explaining evidence scope.

PASS reports require measured run mode, `physicalReferenceRig` evidence, a
latency-budget threshold reference, at least one measured critical-path
component, and metrics within the configured one-way, RTT, jitter, loss, CPU,
underrun, dropped-frame, allocation-warning, and thread-warning thresholds.
Synthetic evidence can validate source shape only.

## Commands

```bash
swift test --filter LatencyBenchmark
swift test
swift build
.build/debug/open-lola validate-latency-benchmark-report Tests/OpenLolaCoreTests/Fixtures/LatencyBenchmarkReports/valid/latency-benchmark-partial.json
.build/debug/open-lola latency-benchmark-synthetic-smoke
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
```

## Results

- `swift test --filter LatencyBenchmark` passed with 9 focused tests.
- `swift test` passed with 396 tests.
- `swift build` passed after rerunning outside the sandbox to avoid the known
  SwiftPM `sandbox-exec: sandbox_apply: Operation not permitted` manifest
  failure.
- `bash scripts/verify-docs.sh` passed.
- `shellcheck scripts/*.sh` passed.
- `.build/debug/open-lola validate-latency-benchmark-report
  Tests/OpenLolaCoreTests/Fixtures/LatencyBenchmarkReports/valid/latency-benchmark-partial.json`
  passed with `VERDICT: PARTIAL`.
- `.build/debug/open-lola latency-benchmark-synthetic-smoke` emitted a valid
  source-validation report with `VERDICT: PARTIAL`.

## Deferred Runtime Evidence

M02 remains PARTIAL until a physical reference rig records:

- exact Mac hardware, OS, RME driver/interface, route, sample rate, frame size,
  channel count, and media format;
- one-way latency, RTT, jitter, packet loss, underruns, dropped frames, CPU,
  allocation warnings, and thread warnings;
- packet capture or equivalent evidence for route timing;
- final PASS, FAIL, or PARTIAL verdict.

## Verdict

M02 source validation is implemented. Physical benchmark closure remains open.

VERDICT: PARTIAL

## Resume here

Run the full command list above after any schema change. Use
`open-lola validate-latency-benchmark-report <path>` for the first measured
report, and keep the milestone PARTIAL until `physicalReferenceRig` evidence
exists.
