# M04 MADI RX

Date: 2026-05-04  
Status: source implementation complete; physical RME RX evidence pending  
Verdict: PARTIAL

## Objective

Implement multichannel MADI receive from original open-lola audio media packets
through depacketization, RX buffering, receiver-side routing/mix, and Core Audio
output.

## Scope

In scope:

- v2 audio packet validation;
- fragment reassembly by stream ID, sequence, and channel offset;
- direct and buffered playout policies;
- receiver-side channel map and local mix;
- underrun, overrun, late, duplicate, reordered, and lost-packet counters;
- no callback allocation, blocking I/O, locks, or logging;
- explicit latency accounting for every receiver buffer.

Out of scope:

- full-duplex drift correction;
- video sync;
- WAN relay.

## Implementation Surfaces

New or changed files:

- `Sources/OpenLolaCore/MadiReceive.swift`
- `Sources/OpenLolaCore/MadiReceiveReport.swift`
- `Sources/OpenLolaCore/MadiReceiveTypes.swift`
- `Sources/OpenLolaCore/OpenLolaCLI.swift`
- `Sources/open-lola/MadiReceiveCommands.swift`
- `Sources/open-lola/MilestoneCommands.swift`
- `Sources/open-lola/main.swift`
- `Tests/OpenLolaCoreTests/MadiReceiveTests.swift`
- `docs/architecture/madi-full-rx-tx.md`
- `docs/architecture/multichannel-audio-routing.md`
- `docs/architecture/rx-buffering.md`

Existing contracts reused:

- `Sources/OpenLolaCore/RealtimeAudioPacketHandoff.swift`
- `Sources/OpenLolaCore/RealtimeAudioBuffers.swift`
- `Sources/OpenLolaCore/ReceiverMixSnapshot.swift`
- `Sources/OpenLolaCore/RxBuffering.swift`
- `Sources/OpenLolaCore/RxImpairmentSimulator.swift`
- `Sources/OpenLolaCore/UdpPcmV2Packet.swift`
- `Sources/OpenLolaCore/MultichannelTransport.swift`
- `Tests/OpenLolaCoreTests/RxBufferingTests.swift`

## Implementation Tasks

1. Add tests for depacketizing complete and missing v2 fragments: done.
2. Add tests for 64-channel output routing with stable channel ordering: done.
3. Implement preallocated receive block pools sized by negotiated stream: done
   as a bounded ready-block pool.
4. Move packet validation, reassembly, and queueing off the audio callback: done
   in `MadiReceiveEngine.receive`.
5. Let the callback consume only ready playout blocks or same-deadline recovery:
   done in `MadiReceiveEngine.renderCallback`.
6. Apply receiver-side mix/routing through immutable snapshots: done through
   `ReceiverMixSnapshotStore` and pre-rendered output payloads.
7. Report every added RX buffer target in frames, packets, and microseconds:
   done through `MadiReceiveBufferLatency` and `RxBufferRuntimeSnapshot`.

## Test Plan

Tests first:

- full MADI RX depacketization for 2/8/16/32/64 channels: covered;
- missing fragment creates loss telemetry and recovery behavior: covered;
- late packet is dropped under direct mode: covered;
- fixed small RX buffer adds visible latency: covered;
- receiver mix maps remote channel N to local channel M: covered;
- sample rate mismatch is rejected before playout: covered;
- callback consumes preallocated blocks only: covered;
- underrun/overrun counters: covered in source-level RX tests and the existing
  deterministic RX impairment tests.

## Benchmark Plan

- depacketization duration per block;
- reassembly latency and memory pressure;
- output callback duration p50/p95/p99/max;
- underrun count under packet loss and jitter;
- receiver mix cost for 64 channels;
- direct, 16-frame, 8-frame, small, adaptive, and WAN buffer costs.

## Acceptance Criteria

- RX is symmetric with TX for negotiated channel count, sample rate, sample
  format, and channel map at the source-contract level.
- Receiver-side routing works without callback allocation.
- Direct mode adds no hidden buffering.
- Buffered modes expose exact latency cost.
- Physical PASS requires RME output evidence with negotiated multichannel media.

## Source Evidence

- `MadiReceiveEngine` validates UDP PCM v2 packet headers against the negotiated
  mode before playout.
- Fragments are accumulated by stream ID and sequence number; incomplete
  deadlines report missing fragment indexes and same-deadline recovery.
- Ready playout blocks are bounded by `preallocatedBlockCount`.
- Receiver mix is prepared once as an immutable snapshot and applied before the
  callback-facing render consumes the block.
- `madi-rx-synthetic-smoke` emits a machine-readable partial report for 2, 8,
  16, 32, and 64 channels.

## Risks

- Receiver mix can become an accidental hot-path abstraction if it is mutable or
  dynamically allocated.
- Fragment reassembly must reject malformed or cross-stream packets early.

## Blockers

- Physical output hardware required for PASS.
- Physical M03 v2 live TX evidence is still needed to supply realistic RX
  inputs for PASS.

## Rollback Plan

Keep RX buffering and receiver mix behind negotiated feature flags. If live
multichannel RX is unstable, retain packet decode tests and disable media start
for unsupported negotiated layouts.

## Progress Checklist

- [x] Add failing RX depacketization tests.
- [x] Add receiver routing tests.
- [x] Implement receive block pools.
- [x] Implement v2 fragment reassembly for playout.
- [x] Integrate RX buffer policy.
- [x] Add underrun/overrun telemetry.
- [ ] Run physical RME RX evidence.

## Resume Point

Run `open-lola madi-rx-synthetic-smoke` for the source-contract surface, then
move to physical RME RX proof with negotiated multichannel output and measured
Core Audio callback evidence before promoting this milestone to PASS.

VERDICT: PARTIAL
