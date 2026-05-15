# Realtime Audio Path Inventory

Date: 2026-05-04  
Status: executable C06 inventory implemented  
Milestone: C06  
Verdict: PARTIAL

## Purpose

This document summarizes the C06 realtime audio buffering and latency
crosswalk. The executable source of truth is:

- `Sources/OpenLolaCore/RealtimeAudioPathInventory.swift`
- `Tests/OpenLolaCoreTests/RealtimeAudioPathInventoryTests.swift`

The user-facing probe is:

```bash
.build/debug/open-lola realtime-audio-path-inventory
```

Expected output is machine-readable JSON followed by:

```text
VERDICT: PARTIAL
```

`PARTIAL` is intentional. The inventory labels source ownership and latency
risk. It does not prove real RME/MADI hardware, direct-route, or benchmark
readiness.

## Summary

| Scope | Count |
|---|---:|
| Inventory entries | 24 |
| Realtime path files | 6 |
| Near-realtime path files | 9 |
| Report-only files | 6 |
| Synthetic-only files | 3 |
| Fastest-PASS relevant files | 19 |

## Path Classes

| Class | Meaning |
|---|---|
| `realtimePath` | Callback-facing or packet-deadline code where hidden allocation, waits, buffering, or queue growth can affect audio latency directly. |
| `nearRealtimePath` | Configuration, routing, timing, or mode-selection code that changes the realtime path but is not itself the callback loop. |
| `reportOnly` | Validation/report code that gates evidence claims but should not execute on the realtime callback path. |
| `syntheticOnly` | Synthetic smoke, simulator, or fixture-generation code that can test contracts but cannot close real hardware readiness. |

## Source Map

| Source file | Class | Role | Fastest PASS relevant |
|---|---|---|---|
| `RealtimeAudioBuffers.swift` | `realtimePath` | Bounded block rings, due-block playout, fixed-target jitter buffering. | yes |
| `RealtimeAudioPayloadCaptureRing.swift` | `realtimePath` | Preallocated payload capture ring and channel remap copy. | yes |
| `RealtimeAudioPacketHandoff.swift` | `realtimePath` | Capture-to-UDP packetization and receive-to-playout handoff. | yes |
| `MadiReceive.swift` | `realtimePath` | MADI receive packet depacketization and same-deadline recovery. | yes |
| `MadiTransmit.swift` | `realtimePath` | MADI transmit packetization and channel ordering. | yes |
| `MadiFullDuplexRuntime.swift` | `realtimePath` | Full-duplex MADI runtime pairing and drift simulation. | yes |
| `RealtimeAudioEngine.swift` | `nearRealtimePath` | Engine configuration, runtime evidence, and handoff metrics. | yes |
| `RealtimeAudioEngineHelpers.swift` | `nearRealtimePath` | Runtime helper construction and measured report assembly. | yes |
| `RxBuffering.swift` | `nearRealtimePath` | Direct, small, adaptive, and stable/WAN RX policy contracts. | yes |
| `MediaClock.swift` | `nearRealtimePath` | Host-time and frame-index timing conversion. | yes |
| `DirectAudioMediaRouter.swift` | `nearRealtimePath` | Audio-first media router policy. | yes |
| `LatencyProfileContracts.swift` | `nearRealtimePath` | Low-buffer profile selection and opt-in policy. | yes |
| `AudioLoopbackRun.swift` | `nearRealtimePath` | Source-level loopback run shape and selected mode evidence. | yes |
| `MadiFullDuplexTypes.swift` | `nearRealtimePath` | MADI full-duplex configuration and mode types. | yes |
| `MadiReceiveTypes.swift` | `nearRealtimePath` | MADI receive configuration and buffer types. | yes |
| `RealtimeAudioEngineReportValidation.swift` | `reportOnly` | Strict validation for realtime engine reports. | yes |
| `LatencyBenchmarkReport.swift` | `reportOnly` | Latency benchmark report schema and PASS gates. | yes |
| `LatencyTuningReport.swift` | `reportOnly` | Latency tuning report schema and selected-candidate gates. | yes |
| `RmeFastestAudioPath.swift` | `reportOnly` | RME fastest-path report and hardware evidence gate. | yes |
| `MadiReceiveReport.swift` | `reportOnly` | MADI receive synthetic report schema. | no |
| `MadiFullDuplexReport.swift` | `reportOnly` | MADI full-duplex source-level report schema. | no |
| `RealtimeAudioEngineSyntheticSmoke.swift` | `syntheticOnly` | Synthetic realtime engine report generator. | no |
| `RxImpairmentSimulator.swift` | `syntheticOnly` | Deterministic packet impairment simulator. | no |
| `LatencyBenchmarkSyntheticSmoke.swift` | `syntheticOnly` | Synthetic latency benchmark report generator. | no |

## C06 Runtime Guard

C06 also tightens realtime report PASS validation:

- fastest PASS must have explicit runtime RX policy accounting,
- runtime RX policy must match configured RX policy,
- runtime-only adaptive or stable/WAN buffering cannot support fastest PASS,
- runtime RX target and observed buffer depth cannot hide extra playout growth.

These checks preserve source-level and synthetic `PARTIAL` reports while making
measured fastest PASS stricter.

## Test Contract

`RealtimeAudioPathInventoryTests.swift` verifies:

- summary counts match executable entries,
- every source, test, and documentation path exists,
- all C06 path classes are present,
- `OpenLolaCLI.realtimeAudioPathInventoryData()` round-trips through JSON.

`RealtimeAudioEngineTests.swift` verifies the new RX runtime/config guards.

## Resume Here

C05 and C06 are implemented. Continue with
[companions/C07_VIDEO_CONTROL_DEGRADE_FIRST_PATH.md](companions/C07_VIDEO_CONTROL_DEGRADE_FIRST_PATH.md).

VERDICT: PARTIAL
