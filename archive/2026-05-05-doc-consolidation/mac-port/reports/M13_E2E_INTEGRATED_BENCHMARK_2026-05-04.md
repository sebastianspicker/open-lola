# M13 E2E Integrated Benchmark Report

Date: 2026-05-04
Public surface: [Current public state](../../docs/current-state.md) and [E2E AV benchmark methodology](../../docs/benchmarks/e2e-av-benchmark-methodology.md)
Status: PARTIAL

## Scope

This report validates the source-level M13 E2E integrated benchmark contract.
It adds a machine-readable aggregate report for audio-only direct, audio/video
direct, multi-video direct, WAN-stable, impairment, recovery, shutdown, and
resource metrics.

It does not validate a real two-peer Apple Silicon run, RME/MADI hardware,
Blackmagic hardware, packet captures, clock alignment, or physical recovery and
shutdown behavior.

## Implemented Contract

`Sources/OpenLolaCore/E2EBenchmarkReport.swift` records:

- two-peer hardware identity and clock-alignment method;
- component report IDs for latency/audio, integrated A/V, video transport, and
  Apple Silicon performance evidence;
- profile rows for audio-only direct, audio/video direct, audio/multi-video
  direct, and WAN-stable behavior;
- loss, jitter, reorder, duplicate, and late-packet impairment rows;
- reconnect and clean-shutdown evidence;
- packet loss, CPU, underrun, and dropped-frame thresholds.

`Sources/OpenLolaCore/E2EBenchmarkReportValidation.swift` rejects `PASS` when:

- the report is synthetic or lacks physical two-peer evidence;
- required profile or impairment rows are missing;
- a video-enabled profile lacks video metrics;
- video increases audio p99 timing or hides audio buffer growth;
- audio underruns, packet loss, CPU, recovery, or shutdown evidence violates
  thresholds;
- hardware identity or evidence fields still contain placeholders.

`Sources/OpenLolaCore/E2EBenchmarkRunner.swift` adds a bounded aggregate runner
that reads existing validated component reports and emits an M13 report without
promoting synthetic inputs to `PASS`.

## Commands

```bash
swift test --filter E2EBenchmark
swift test --filter scopedCodeFilesStayWithinLineBudget
swift test
swift build
bash scripts/verify-docs.sh
.build/debug/open-lola e2e-benchmark-synthetic-smoke
.build/debug/open-lola validate-e2e-benchmark-report <report.json>
```

## Results

- Red focused test run failed before implementation because the M13 E2E
  benchmark types did not exist.
- `swift test --filter E2EBenchmark` passed with 10 focused M13 tests.
- `swift test --filter scopedCodeFilesStayWithinLineBudget` passed.
- `swift test` passed with 643 tests.
- `swift build` passed after rerunning outside the sandbox to avoid the known
  SwiftPM `sandbox-exec: sandbox_apply: Operation not permitted` manifest
  failure.
- `bash scripts/verify-docs.sh` passed.
- `e2e-benchmark-synthetic-smoke` emitted a valid `PARTIAL` report.
- `e2e-benchmark-run` wrote a valid aggregate `PARTIAL` report from component
  smoke reports.

## Deferred Runtime Evidence

M13 cannot be marked `PASS` until real reports exist for:

- two Apple Silicon peers with OS, driver, network, audio, and video identity;
- RME/MADI full-duplex audio at the selected channel count and frame size;
- Blackmagic-compatible capture/render/output path;
- direct route packet capture and clock-alignment method;
- audio-only, audio/video, and multi-video benchmark rows;
- loss, jitter, reorder, duplicate, and late-packet impairment runs;
- reconnect and clean-shutdown runs with no leaked realtime callbacks.

## Verdict

M13 source validation is implemented. Physical two-peer E2E benchmark evidence
remains open.

VERDICT: PARTIAL

## Resume here

Generate a source-shape report with `open-lola e2e-benchmark-synthetic-smoke`.
For physical closure, replace the component reports with measured two-peer
reports, aggregate them with `open-lola e2e-benchmark-run`, then validate the
output with `open-lola validate-e2e-benchmark-report <report.json>`.
