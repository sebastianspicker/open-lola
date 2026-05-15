# M13 E2E Integrated Benchmark

Date: 2026-05-04  
Status: source-level implementation complete; physical two-peer evidence open  
Verdict: PARTIAL

## Objective

Produce two-machine benchmark evidence for full-duplex multichannel audio,
direct P2P transport, Blackmagic video, optional multi-stream video, latency,
jitter, packet loss, CPU, GPU, memory, recovery, and shutdown.

## Scope

In scope:

- two-peer direct LAN/manual IP benchmark;
- RME MADI or compatible high-channel-count audio;
- Blackmagic-compatible capture/output;
- audio-only and AV benchmark profiles;
- packet impairment runs;
- reconnect and clean shutdown runs;
- machine-readable report artifacts;
- documented methodology.

Out of scope:

- claiming WAN lowest-latency PASS;
- relay latency claims;
- benchmarks without hardware identity and configuration.

## Affected Files

Implemented source files:

- `Sources/OpenLolaCore/E2EBenchmarkReport.swift`
- `Sources/OpenLolaCore/E2EBenchmarkReportValidation.swift`
- `Sources/OpenLolaCore/E2EBenchmarkSyntheticSmoke.swift`
- `Sources/OpenLolaCore/E2EBenchmarkRunner.swift`
- `Sources/open-lola/E2EBenchmarkCommands.swift`
- `Sources/open-lola/main.swift`
- `Tests/OpenLolaCoreTests/E2EBenchmarkReportTests.swift`
- `docs/benchmarks/e2e-av-benchmark-methodology.md`
- `docs/current-state.md`
- `mac-port/reports/M13_E2E_INTEGRATED_BENCHMARK_2026-05-04.md`

## Implementation Tasks

1. Define benchmark report schema before collecting data. Done with
   `E2EBenchmarkReport`.
2. Add tests for required report fields and failure classification. Done with
   `E2EBenchmarkReportTests`.
3. Implement audio-only direct peer benchmark. Done as an aggregate profile row
   sourced from validated latency/audio benchmark reports.
4. Implement AV direct peer benchmark. Done as aggregate AV and video profile
   rows sourced from validated integrated A/V and video transport reports.
5. Add impairment profiles for loss, jitter, reorder, duplicate, and late
   packets. Done in the report schema, validator, and synthetic smoke.
6. Collect CPU, GPU, memory, packet loss, jitter, callback, and frame metrics.
   Done in the source contract; physical collection remains open.
7. Produce PASS/PARTIAL/FAIL classification from evidence. Done in
   `E2EBenchmarkRunner` and the PASS validator.

## Test Plan

Tests first:

- report schema validation;
- missing hardware evidence produces PARTIAL, not PASS;
- audio one-way and round-trip fields required;
- video capture/render fields required when video is enabled;
- reconnect/shutdown events required;
- impairment counters required.

Implemented commands:

```bash
swift test --filter E2EBenchmark
swift run open-lola e2e-benchmark-synthetic-smoke
swift run open-lola validate-e2e-benchmark-report <report.json>
swift run open-lola e2e-benchmark-run --audio-benchmark <latency.json> --integrated-av <integrated-av.json> --video-transport <video-transport.json> --performance-audit <performance.json> --duration-seconds <n> --output <e2e.json>
```

## Benchmark Plan

Required measurements:

- audio callback duration;
- audio one-way latency;
- audio round-trip latency;
- MADI max stable channel count;
- 8/16/32/64-frame stability;
- jitter distribution;
- underrun count;
- packet loss behavior;
- video capture latency;
- video encode/packetization latency;
- video receive/render latency;
- multi-video CPU/GPU/memory cost;
- end-to-end AV latency;
- network throughput;
- memory allocations on hot paths.

## Acceptance Criteria

- Benchmark methodology is reproducible.
- Reports include hardware identity, driver path, sample rate, channel count,
  frame size, network path, video format, and profile.
- Missing physical evidence cannot produce PASS.
- Direct Audio First audio evidence is reported separately from AV evidence.

Source-level acceptance is implemented. Physical acceptance still requires a
measured two-peer report with physical Apple Silicon, RME/MADI, Blackmagic,
packet-capture, clock-alignment, impairment, recovery, and shutdown evidence.

## Risks

- Two-machine measurements can be invalid if clock alignment is not described.
- Hardware driver updates can change latency and format behavior.

## Blockers

- M03-M12 implementation complete enough to benchmark.
- Two Apple Silicon peers, RME-compatible MADI, Blackmagic-compatible hardware,
  and a direct network route.

## Rollback Plan

Keep benchmark runner read-only with respect to configuration. If an integrated
run fails, preserve partial reports and classify the missing evidence precisely.

## Progress Checklist

- [x] Add benchmark schema tests.
- [x] Implement audio-only E2E aggregate benchmark.
- [x] Implement AV E2E aggregate benchmark.
- [x] Add impairment benchmark modes.
- [x] Add CLI validator, synthetic smoke, and aggregate runner.
- [ ] Collect physical two-peer reports.
- [x] Update current-state evidence.

## Resume Point

Use `e2e-benchmark-synthetic-smoke` for source-shape validation, then replace
the synthetic component reports with measured two-peer reports and aggregate
them with `e2e-benchmark-run`. Keep this milestone `PARTIAL` until the aggregate
report validates as measured physical evidence.

VERDICT: PARTIAL
