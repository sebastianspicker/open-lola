# M12 Apple Silicon Performance

Date: 2026-05-04  
Status: source implementation complete; physical performance evidence open  
Verdict: PARTIAL

## Objective

Audit and optimize the Apple Silicon realtime and media paths for minimum
latency, bounded memory, stable scheduling, and clear separation of audio,
video, network, control, metrics, and UI work.

## Scope

In scope:

- audio callback allocation audit;
- copy audit for audio and video hot paths;
- ring buffer and queue sizing;
- thread and QoS audit;
- lock audit;
- monotonic clock usage;
- Metal and VideoToolbox decision records;
- memory bandwidth profiling;
- benchmark-driven profile tuning.

Out of scope:

- speculative SIMD rewrites without measured need;
- adding abstractions that do not remove hot-path cost;
- optimizing video at the expense of audio stability.

## Affected Files

Expected new or changed files:

- `Sources/OpenLolaCore/RealtimeAudioEngine.swift`
- `Sources/OpenLolaCore/RealtimeAudioPacketHandoff.swift`
- `Sources/OpenLolaCore/UdpMediaTransport.swift`
- `Sources/OpenLolaCore/VideoCaptureRunner.swift`
- `Sources/OpenLolaCore/VideoTransportReport.swift`
- `Sources/OpenLolaCore/VideoTransportRunner.swift`
- `Sources/OpenLolaCore/LatencyBenchmark.swift`
- `Sources/OpenLolaCore/PerformanceAuditReport.swift`
- `Tests/OpenLolaCoreTests/PerformanceAuditTests.swift`
- `Sources/open-lola/MilestoneCommands.swift`
- `Sources/open-lola/main.swift`
- `docs/architecture/apple-silicon-performance.md`

## Implementation Tasks

1. Add source tests that assert no callback-time allocation markers on known
   realtime paths. Done in `PerformanceAuditTests`.
2. Add runtime counters for callback duration, ring occupancy, drops, queue
   depth, packetization duration, depacketization/reassembly duration, and video
   frame age. Done in the handoff, media transport, video transport, and
   performance-audit report surfaces.
3. Audit audio copies and remove avoidable format conversions. Source report
   now distinguishes preallocated callback copies, packet-boundary copies, and
   avoidable copies that must be removed before PASS.
4. Audit video copies and document each unavoidable API boundary copy. Source
   report now rejects PASS when a retained copy is undocumented or unmeasured.
5. Assign audio, network, video, control, metrics, and UI queues explicitly.
   Source validator rejects PASS if video/control/metrics/UI can block audio.
6. Benchmark Metal and VideoToolbox options only after raw/low-copy baselines.
   Source validator rejects accelerated PASS claims without a raw baseline.
7. Add performance reports tied to latency profiles. Source validator requires
   safe, ultra, and experimental profile reports before PASS.

## Test Plan

Tests first:

- allocation audit fixtures;
- lock-free or bounded-lock usage assertions for realtime surfaces;
- queue-depth counter tests;
- copy-count report tests;
- profile-specific performance report validation.

Implemented focused gate:

```bash
swift test --filter PerformanceAudit
```

## Benchmark Plan

- audio callback duration p50/p95/p99/max;
- packetization and depacketization duration;
- network send/receive overhead;
- video capture, encode, packetize, receive, render timings;
- CPU, GPU, memory bandwidth, and allocation counts;
- multi-video load impact on audio;
- Direct Audio First versus Balanced AV versus Multi-Video Performance.

## Acceptance Criteria

- Realtime audio callback has no blocking I/O, heap allocation, logging, or
  unsafe lock usage.
- Video and UI cannot block audio-critical queues.
- Every hot-path copy is either removed or documented with measured cost.
- Profile reports include enough data to choose safe, ultra, and experimental
  settings.

Source-level PASS claims are rejected unless the run is measured, physical
Apple Silicon evidence is present, realtime surfaces are clean, copies are
documented and measured, accelerated paths reference a raw baseline, and safe,
ultra, and experimental profile reports are present.

## Risks

- Micro-optimizing before physical measurement can waste time.
- macOS scheduling behavior can differ between development and performance
  runs, so reports must include machine and process context.

## Blockers

- M03-M11 should provide realistic integrated paths before final tuning.
- Physical Apple Silicon hardware and AV devices required for full evidence.
- Raw, Metal, and VideoToolbox physical benchmark matrix required before PASS.

## Rollback Plan

Keep optimizations behind measurable profile or feature flags. If a low-copy
path is unstable, return to the simpler copy path and keep the benchmark result
as evidence.

## Progress Checklist

- [x] Add allocation/copy audit tests.
- [x] Add performance counters.
- [x] Audit audio hot path.
- [x] Audit video hot path.
- [x] Audit thread/QoS model.
- [x] Add raw-before-accelerated benchmark gates.
- [x] Publish source performance report contract.
- [ ] Run physical raw, Metal, and VideoToolbox benchmark matrix.
- [ ] Publish measured Apple Silicon performance report.

## Resume Point

Run the physical M12 closure after M03-M11 integrated paths have measured
reports:

```bash
swift run open-lola performance-audit-synthetic-smoke
swift run open-lola validate-performance-audit-report <measured-m12-report.json>
```

Keep the verdict `PARTIAL` until the measured Apple Silicon/RME/video matrix is
present.

VERDICT: PARTIAL
