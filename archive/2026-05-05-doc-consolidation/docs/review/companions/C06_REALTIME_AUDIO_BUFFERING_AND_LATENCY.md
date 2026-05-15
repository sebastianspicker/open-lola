# C06 Realtime Audio Buffering And Latency

Date: 2026-05-04  
Status: source-level realtime path inventory and RX PASS guard implemented  
Priority: P1  
Verdict: PARTIAL

## Code Evidence

- Realtime and latency-sensitive code spans `RealtimeAudioEngine.swift`,
  `RealtimeAudioBuffers.swift`, `RealtimeAudioPacketHandoff.swift`,
  `RealtimeAudioPayloadCaptureRing.swift`, `RxBuffering.swift`,
  `RxImpairmentSimulator.swift`, `LatencyProfileContracts.swift`,
  `MediaClock.swift`, `Madi*`, and `Rme*`.
- The project has tests for realtime audio, packet handoff, RX buffering,
  latency profiles, MADI, and RME fastest path.
- C06 now adds `Sources/OpenLolaCore/RealtimeAudioPathInventory.swift`, which
  classifies realtime path, near-realtime path, report-only, and synthetic-only
  audio/latency files.
- C06 now tightens `RealtimeAudioEngineReport` PASS validation so runtime RX
  buffering evidence must match configuration and cannot hide adaptive/stable
  buffering in a fastest PASS claim.
- Real hardware and benchmark evidence remains incomplete.

## Objective

Protect latency-sensitive audio behavior while preparing targeted refactors and
benchmarks.

## Affected Files

- `Sources/OpenLolaCore/RealtimeAudio*.swift`
- `Sources/OpenLolaCore/Rx*.swift`
- `Sources/OpenLolaCore/Latency*.swift`
- `Sources/OpenLolaCore/MediaClock.swift`
- `Sources/OpenLolaCore/Madi*.swift`
- `Sources/OpenLolaCore/Rme*.swift`
- related tests and benchmark/report fixtures

## Improvement Plan

1. Identify which files are realtime path, near-realtime path, report-only, or
   synthetic-only. Done in `RealtimeAudioPathInventory`.
2. Add microbenchmark or deterministic stress tests for buffer/latency logic
   before refactoring. Existing deterministic RX impairment and buffer tests
   are preserved and the C06 inventory links them explicitly.
3. Keep explicit latency-cost accounting for RX buffering and impairment modes.
   Strengthened in PASS validation by requiring runtime RX snapshots to match
   configured RX policy.
4. Avoid hidden audio buffering changes in video/control integration work.
5. Record hardware evidence requirements for RME/MADI PASS.

## Implemented Changes

- Added `RealtimeAudioPathInventory`, `RealtimeAudioPathInventoryEntry`,
  `RealtimeAudioPathInventorySummary`, and `RealtimeAudioPathInventoryReport`.
- Added `open-lola realtime-audio-path-inventory`.
- Added `RealtimeAudioPathInventoryTests.swift` with path existence, class
  coverage, summary, and JSON round-trip checks.
- Added realtime PASS regression tests for runtime-only adaptive RX buffering,
  runtime/config RX policy mismatch, and missing runtime RX snapshots.
- Added `passWithoutRuntimeRxBufferSnapshot` and
  `rxBufferRuntimePolicyMismatch` validation errors.
- Tightened realtime PASS validation to reject missing explicit runtime RX
  accounting, runtime RX policy mismatch, fastest-ineligible runtime RX
  buffering, and hidden target/buffer growth in runtime RX snapshots.
- Updated embedded realtime PASS fixtures used by Drift/PLC and Network/AoIP
  certification tests so nested PASS evidence also carries explicit RX policy
  and matching runtime snapshots.

## Current Inventory

| Scope | Count |
|---|---:|
| Inventory entries | 24 |
| Realtime path files | 6 |
| Near-realtime path files | 9 |
| Report-only files | 6 |
| Synthetic-only files | 3 |
| Fastest-PASS relevant files | 19 |

## Acceptance Criteria

- Realtime path files are labeled and isolated in the crosswalk.
  Implemented in [../realtime-audio-path-inventory.md](../realtime-audio-path-inventory.md).
- Refactors preserve latency profile semantics.
  Covered by existing latency profile and focused realtime tests.
- Tests cover direct, small, adaptive, and stable WAN buffer profile behavior
  where supported.
  Existing RX buffer tests cover these profiles; C06 adds realtime PASS guards
  for runtime/config RX drift.
- No code path silently increases audio latency for integrated AV.
  Realtime PASS now rejects runtime-only adaptive/stable buffering and hidden
  RX target growth.

## Verification

```bash
swift test
swift build
swift test --filter RealtimeAudioEngine
swift test --filter RealtimeAudioPathInventory
.build/debug/open-lola latency-profile-synthetic-smoke
.build/debug/open-lola realtime-audio-synthetic-smoke
.build/debug/open-lola realtime-audio-path-inventory
.build/debug/open-lola madi-full-duplex-synthetic-smoke
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
```

## Resume Here

C05 and C06 are implemented at source level. Continue with
[C07_VIDEO_CONTROL_DEGRADE_FIRST_PATH.md](C07_VIDEO_CONTROL_DEGRADE_FIRST_PATH.md).

VERDICT: PARTIAL
