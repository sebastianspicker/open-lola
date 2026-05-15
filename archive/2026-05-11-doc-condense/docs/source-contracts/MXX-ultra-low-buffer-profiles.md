# MXX Ultra Low Buffer Profiles

Date: 2026-05-04  
Status: source contract implemented; physical evidence pending  
Verdict: PARTIAL

## Objective

Add explicit low-latency profiles for 32/64-frame safe operation, 16-frame
ultra-low-latency operation, and 8-frame experimental operation without making
unstable settings the default.

## Scope

This file covers M06 and M07:

- M06 Add 16-frame ultra-low-latency profile;
- M07 Add 8-frame experimental profile.

Out of scope: adaptive RX buffering, matrix metadata, video and lighting
runtime changes.

## Affected Files

Planned source/test/docs surfaces:

- `Sources/OpenLolaCore/Network/UDP/MultichannelTransport.swift`
- `Sources/OpenLolaCore/Audio/CoreAudio/CoreAudioInventoryReader.swift`
- `Sources/OpenLolaCore/Network/P2P/EndpointLoopbackReport.swift`
- `Sources/OpenLolaCore/Audio/Routing/AudioLoopbackRun.swift`
- `Sources/OpenLolaCore/Benchmarks/Latency/LatencyBenchmarkReport.swift`
- `Sources/OpenLolaCore/Timing/LatencyTuningReport.swift`
- `Sources/OpenLolaCore/Audio/MADI/RmeFastestAudioPath.swift`
- `Tests/OpenLolaCoreTests/EndpointLoopbackReportTests.swift`
- `Tests/OpenLolaCoreTests/LatencyBenchmarkReportTests.swift`
- `Tests/OpenLolaCoreTests/LatencyTuningReportTests.swift`
- `Tests/OpenLolaCoreTests/RmeFastestAudioPathTests.swift`
- `docs/architecture/latency-profiles.md`
- `docs/architecture/latency-budget.md`
- `docs/benchmarks/audio-latency-methodology.md`

## Implementation Tasks

| Milestone | Tasks |
|---|---|
| M06 | Define `ultraLowLatency16` profile validation, CLI/config opt-in, theoretical latency accounting, hardware support gate, route benchmark gate, and rollback profile. |
| M07 | Define `extremeLowLatency8` profile validation, stronger opt-in warning, experimental verdict handling, max stable channel count benchmark, and hidden-by-default policy. |

Implemented source surfaces:

- `LatencyProfilePolicy`, `LatencyProfileSelectionRequest`,
  `LatencyProfileSelection`, `LatencyProfileBudget`, and
  `LatencyProfileEvidence` define the executable profile contract;
- `LatencyBenchmarkReport` and `LatencyTuningReport` now carry optional
  low-buffer profile evidence and reject PASS claims when 16/8-frame evidence is
  missing or insufficient;
- `EndpointLoopbackReport` now requires 8/16/32/64/128 frame rows for supported
  sample rates and requires longer stability evidence for 8-frame PASS;
- `audio-loopback-run` parses `--latency-profile`, `--rx-buffer-profile`, and
  `--experimental-8-frame` so 16/8-frame operation is opt-in at the CLI/config
  boundary;
- `open-lola latency-profile-synthetic-smoke` emits the machine-readable
  low-buffer evidence shape and remains `PARTIAL`.

Profile behavior:

- Safe Low Latency: 32 frames preferred, 64 frames fallback;
- Ultra Low Latency 16: 16 frames, explicit opt-in, RME/direct route required
  for PASS;
- Extreme Low Latency 8: 8 frames, experimental opt-in, never default without
  long-run physical evidence.

## Test Plan

Tests first:

- 16-frame profile configuration accepts only supported hardware reports;
- 16-frame profile rejects missing physical RME/direct-route evidence for PASS;
- 8-frame profile requires explicit opt-in;
- 8-frame profile emits warning and `PARTIAL` without physical long-run data;
- profile latency calculation covers 48 kHz and 96 kHz;
- packet rate and bandwidth calculation includes channel count;
- profile default maps to direct RX unless explicitly overridden.

Existing tests to extend:

- endpoint loopback frame-size matrix;
- latency benchmark report validation;
- latency tuning selected-candidate validation;
- RME fastest audio selected-mode validation.

## Benchmark Plan

Benchmark method:

- local Core Audio loopback at 8/16/32/64/128 frames where supported;
- callback p50/p95/p99/max and deadline misses;
- CPU p50/p95/p99/max;
- critical-path allocation warnings;
- analog loopback corrected one-way latency;
- two-machine P2P packet age and jitter;
- max stable channel count at each frame size;
- 30-minute minimum for stable profile claims, longer for 8-frame promotion.

## Acceptance Criteria

M06 is accepted when:

- 16-frame profile is explicit opt-in;
- tests prove unsupported hardware cannot claim PASS;
- physical RME/direct route benchmark can close PASS;
- rollback to safe profile is documented and machine-readable.

M07 is accepted when:

- 8-frame profile is experimental and opt-in;
- user-visible warnings are required;
- max stable channel count is measured;
- no default path uses 8 frames without long-run physical PASS evidence.

## Risks

- Tiny frame sizes increase packet rate and scheduling sensitivity.
- 8-frame operation may be stable only for small channel counts.
- CPU, thermal, or OS scheduling spikes can dominate theoretical buffer gains.
- A low buffer reported by Core Audio may not be reliable in a full-duplex run.

## Blockers

- Real RME hardware and cabling are required for physical PASS.
- Allocation/scheduling probes must exist before promoting the profiles.
- Two-machine P2P route evidence must be captured for networked claims.

## Rollback Plan

If 16-frame or 8-frame profiles fail, keep Safe Low Latency as the default and
mark the lower profile `PARTIAL` or hidden. Existing 32/64-frame route reports
remain valid.

## Progress Checklist

- [x] Profile identifiers exist in source-level transport models.
- [x] 16-frame profile validation tests written.
- [x] 8-frame opt-in warning tests written.
- [x] profile latency calculator implemented.
- [x] max stable channel count benchmark evidence implemented in benchmark and
  tuning report contracts.
- [ ] RME 16-frame physical evidence attached.
- [ ] RME 8-frame physical evidence attached.

## Resume Point

Resume at M06/M07 physical proof: run the RME/direct-route 8/16/32/64/128
matrix with real hardware, attach max stable channel counts, and promote only
the measured profiles whose report validators can close PASS.

VERDICT: PARTIAL
