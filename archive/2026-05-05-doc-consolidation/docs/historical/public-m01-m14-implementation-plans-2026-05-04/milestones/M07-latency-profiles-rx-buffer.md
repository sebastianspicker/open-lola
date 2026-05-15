# M07 Latency Profiles And RX Buffer Modes

Date: 2026-05-04  
Status: source implementation complete; physical validation pending  
Verdict: PARTIAL

## Objective

Expose benchmarked session-level latency profiles and explicit RX buffer modes
for direct audio-first, balanced AV, multi-video, and WAN-stable operation.

## Scope

In scope:

- Direct Audio First;
- Balanced AV;
- Multi-Video Performance;
- WAN Stable;
- direct, 16-frame, 8-frame experimental, small RX, adaptive RX, and WAN stable
  buffer modes;
- profile negotiation;
- profile-to-buffer validation;
- benchmark reports that show every added frame and packet.

Out of scope:

- making 8-frame mode a default;
- hidden adaptive buffering;
- video-specific optimization beyond protecting audio priority.

## Affected Files

Expected new or changed files:

- `Sources/OpenLolaCore/LatencyProfileContracts.swift`
- `Sources/OpenLolaCore/RxBuffering.swift`
- `Sources/OpenLolaCore/SessionProfileBenchmark.swift`
- `Sources/OpenLolaCore/SessionNegotiation.swift`
- `Sources/OpenLolaCore/SessionProtocol.swift`
- `Sources/OpenLolaCore/LatencyBenchmarkReport.swift`
- `Sources/open-lola/LatencyProfileCommands.swift`
- `Tests/OpenLolaCoreTests/LatencyProfileTests.swift`
- `Tests/OpenLolaCoreTests/RxBufferingTests.swift`
- `Tests/OpenLolaCoreTests/SessionNegotiationTests.swift`
- `Tests/OpenLolaCoreTests/LatencyBenchmarkReportTests.swift`
- `docs/architecture/latency-profiles.md`
- `docs/architecture/rx-buffering.md`

## Source Status

Implemented source-level M07 behavior:

- Direct Audio First negotiates direct RX only and remains the only fastest
  session profile.
- Balanced AV negotiates small fixed RX only; direct/adaptive RX is rejected
  before media starts.
- Multi-Video Performance negotiates small or adaptive RX, requires enabled
  video, and records `dropVideoBeforeAudioLatency` as the pressure policy.
- WAN Stable negotiates Stable/WAN RX only and records continuity-first
  priority.
- 16-frame and 8-frame audio-buffer profiles remain explicit opt-in contracts.
- RX buffer reports expose target frames, target packets, microsecond cost,
  hidden growth checks, target-change events, packet loss, late packets,
  jitter, underruns, and overruns.
- M07 benchmark reports can carry callback p99, route age, packet age, jitter,
  underrun/overrun counts, and added buffer cost.

The source-level smoke command is:

```sh
swift run open-lola latency-profile-benchmark-synthetic-smoke --output /tmp/m07-latency-profile.json
swift run open-lola validate-latency-benchmark-report /tmp/m07-latency-profile.json
```

## Implementation Tasks

1. Add tests for each profile and RX buffer combination.
2. Reject Direct Audio First with hidden adaptive buffering.
3. Require explicit opt-in for 8-frame experimental operation.
4. Map Balanced AV to small fixed RX only after benchmark evidence.
5. Map Multi-Video Performance to audio-protected video drop behavior.
6. Map WAN Stable to continuity-first RX buffering and no fastest PASS claim.
7. Add report fields for callback duration, route age, packet age, jitter,
   underrun/overrun count, and added buffer cost.

## Test Plan

Tests first:

- latency profile configuration;
- incompatible profile rejection;
- RX buffer target bounds;
- adaptive hysteresis outside the callback;
- packet loss simulation;
- jitter simulation;
- fastest PASS guard rejects hidden buffers;
- profile negotiation between peers.

## Benchmark Plan

- 8/16/32/64-frame stability;
- direct versus small RX latency delta;
- adaptive RX target-change cost;
- WAN stable continuity under jitter;
- callback duration under each profile;
- underrun count by profile;
- video load impact on audio profile.

## Acceptance Criteria

- Every session has exactly one negotiated latency profile.
- Every RX buffer target is explicit in reports.
- Direct Audio First is the default fastest profile.
- Buffered profiles cannot claim fastest PASS without measured evidence.
- Profile rollback is available and measurable.

## Risks

- Too many profiles can hide the real acceptance boundary. Keep profiles few,
  named, and benchmark-derived.
- Adaptive RX can mask broken networking if the report does not show target
  changes clearly.

## Blockers

- physical direct-route MADI/RME profile matrix;
- measured 8/16/32/64-frame stability runs;
- measured Balanced AV, Multi-Video, and WAN-stable impairment runs.

## Rollback Plan

Keep Safe Low Latency as the default. If new session-level profiles are
unstable, disable them in negotiation while preserving source-level policy
tests.

## Progress Checklist

- [x] Add profile compatibility tests.
- [x] Add RX buffer negotiation tests.
- [x] Implement session-level profiles.
- [x] Add report fields for buffer cost.
- [x] Run synthetic impairment benchmarks.
- [ ] Run physical direct route profile matrix.

## Resume Point

Run the physical matrix next. Source verification is available through
`swift test`, `latency-profile-benchmark-synthetic-smoke`, and
`validate-latency-benchmark-report`, but the milestone must stay `PARTIAL`
until real direct-route and hardware measurements are attached.

VERDICT: PARTIAL
