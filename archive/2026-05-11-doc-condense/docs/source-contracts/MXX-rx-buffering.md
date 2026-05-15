# MXX Configurable RX Buffering

Date: 2026-05-04  
Status: source implementation complete; physical RX validation pending  
Verdict: PARTIAL

## Objective

Add optional receive-side buffering profiles for unstable links while keeping
the fastest/direct audio profile as low-latency as possible and making every
added buffer visible in the latency budget.

## Scope

This file covers M08 through M10:

- M08 Implement configurable RX buffer modes;
- M09 Add jitter/loss simulation and benchmark harness;
- M10 Validate on real RME MADI / Thunderbolt hardware.

Out of scope: changing the fastest direct profile to adaptive buffering by
default, retransmission waits for fastest audio, or video/lighting changes.

## Affected Files

Planned source/test/docs surfaces:

- `Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioBuffers.swift`
- `Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPacketHandoff.swift`
- `Sources/OpenLolaCore/Timing/RxBuffering.swift`
- `Sources/OpenLolaCore/Timing/DriftPlcReport.swift`
- `Sources/OpenLolaCore/Timing/DriftPlcFixedTargetCertification.swift`
- `Sources/OpenLolaCore/Network/UDP/UdpPcmContinuousRouteRunner.swift`
- `Sources/OpenLolaCore/Network/UDP/UdpPcmRouteCertification.swift`
- `Sources/OpenLolaCore/Benchmarks/Latency/LatencyBenchmarkReport.swift`
- `Sources/OpenLolaCore/Benchmarks/Latency/LatencyBenchmarkSyntheticSmoke.swift`
- `Tests/OpenLolaCoreTests/RealtimeAudioEngineTests.swift`
- `Tests/OpenLolaCoreTests/RxBufferingTests.swift`
- `Tests/OpenLolaCoreTests/DriftPlcReportTests.swift`
- `Tests/OpenLolaCoreTests/UdpPcmRouteReportTests.swift`
- `Tests/OpenLolaCoreTests/LatencyBenchmarkReportTests.swift`
- `docs/architecture/rx-buffering.md`
- `docs/architecture/latency-budget.md`
- `docs/benchmarks/audio-latency-methodology.md`

## Implementation Tasks

| Milestone | Tasks |
|---|---|
| M08 | Implemented Direct, Small, Adaptive, and Stable/WAN RX policies with explicit min/max frames, target frames, latency cost, callback-change boundary, and fastest-eligibility rules. |
| M09 | Implemented deterministic jitter, whole-packet loss, fragment loss, duplicate, reorder, and late-packet simulation plus benchmark RX impact fields. |
| M10 | Pending physical RME/direct and impaired-route validation for 8/16/32/64 frame profiles and each RX buffer mode. |

Buffer behavior:

- Direct: 0-1 packet, no growth, late drop or same-deadline PLC;
- Small: fixed 1-2 packets, visible cost, no growth;
- Adaptive: outside-callback target changes with hysteresis inside bounds;
- Stable/WAN: configured continuity-first buffer, not fastest eligible.

## Test Plan

Tests first:

- Direct mode keeps existing late-drop behavior;
- Small mode uses fixed target and reports added latency;
- Adaptive mode increases after sustained jitter and decreases only after
  hysteresis;
- Adaptive mode never exceeds configured max;
- Stable/WAN mode is rejected for fastest PASS;
- jitter simulation is deterministic;
- packet loss simulation distinguishes fragment loss and deadline loss;
- underrun/overrun counters are preserved;
- hidden buffer growth still fails fastest validation.

## Benchmark Plan

Benchmark method:

- run synthetic impairment tests for reproducible policy behavior;
- run localhost route for source-shape checks;
- run direct two-machine P2P route for fastest profile;
- run managed/campus or impaired route for adaptive/stable profiles;
- record packet age, jitter, loss, late, duplicate, reorder, underrun,
  overrun, drift slope, PLC events, target changes, and latency cost;
- compare RX profiles on identical route conditions.

## Acceptance Criteria

M08 source acceptance is met: every RX profile has explicit target, bounds,
latency cost, telemetry, and PASS eligibility rules.

M09 source acceptance is met: impairment simulation is deterministic and can
reproduce late, whole-packet loss, fragment loss, duplicate, reorder, underrun,
and overrun accounting cases.

M10 is accepted when real RME hardware evidence proves the direct profile and
quantifies the latency/continuity tradeoff for buffered profiles. Without real
hardware evidence the verdict remains `PARTIAL`.

## Risks

- Adaptive buffers can hide network problems by silently growing latency.
- WAN buffering may be useful for monitoring but unsuitable for performance.
- Drift correction and RX buffering can be conflated if telemetry is weak.
- Fragment loss in v2 can complicate late/loss accounting.

## Blockers

- Physical RME route and at least one impaired route are required for complete
  validation.
- Jitter/loss simulator must be deterministic before benchmark results are
  comparable.
- Callback allocation and blocking rules must remain enforced.

## Rollback Plan

Keep Direct mode as the default. If Small, Adaptive, or Stable/WAN behavior is
not stable, disable those profiles in negotiation and preserve fixed-target
playout. Existing direct route validators remain the rollback gate.

## Progress Checklist

- [x] RX profile identifiers exist in source-level transport models.
- [x] Direct profile policy tests written.
- [x] Small fixed buffer tests written.
- [x] Adaptive hysteresis tests written.
- [x] Stable/WAN PASS rejection tests written.
- [x] deterministic impairment simulator implemented.
- [x] RX latency impact benchmark report implemented.
- [x] hidden buffer growth remains a fastest validation failure.
- [ ] RME/direct physical validation complete.

## Resume Point

Resume at M10: run physical RME/direct and impaired-route validation across
8/16/32/64 frame modes and Direct, Small, Adaptive, and Stable/WAN RX profiles.
Keep `VERDICT: PARTIAL` until those real hardware reports exist.

VERDICT: PARTIAL
