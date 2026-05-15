# Source Ownership Inventory

Date: 2026-05-04  
Status: executable C02 inventory and first source split implemented  
Milestone: C02  
Verdict: PARTIAL

## Purpose

This document summarizes the C02 source/test/doc ownership crosswalk. The
executable source of truth is:

- `Sources/OpenLolaCore/SourceOwnershipInventory.swift`
- `Tests/OpenLolaCoreTests/SourceOwnershipInventoryTests.swift`
- `Sources/OpenLolaCore/Core/OpenLolaCLI.swift`
- `Sources/open-lola/main.swift`

The user-facing probe is:

```bash
.build/debug/open-lola source-ownership-inventory
```

Expected output is machine-readable JSON followed by:

```text
VERDICT: PARTIAL
```

`PARTIAL` is intentional. C02 closes the first safe ownership split and creates
the executable crosswalk. It does not move high-risk realtime audio, UDP/NAT,
video/control, or release-proof code.

## C02 Move Boundary

C02 moved only the low-risk core support group:

```text
Sources/OpenLolaCore/Core/
  CapabilitySummary.swift
  OpenLolaCLI.swift
  PeerIdentity.swift
  DebugTrace.swift
  PrettyJSONCodable.swift
```

The SwiftPM target name remains `OpenLolaCore`; `Package.swift` did not need an
explicit source-path change because SwiftPM discovers target sources
recursively.

## Summary

| Scope | Count |
|---|---:|
| Ownership groups | 19 |
| First move candidates | 1 |
| Groups moved in C02 | 1 |
| Deferred high-risk groups | 8 |

## Ownership Groups

| Group | Current source area | Proposed area | Risk | C02 status |
|---|---|---|---|---|
| `coreSupport` | `Sources/OpenLolaCore/Core/*.swift` | `Sources/OpenLolaCore/Core/` | low | moved |
| `protocolSession` | `Session*.swift` | `Sources/OpenLolaCore/Protocol/` | medium | deferred |
| `audioCoreAudio` | `CoreAudio*`, `AudioStreamDescription.swift` | `Sources/OpenLolaCore/Audio/CoreAudio/` | medium | deferred |
| `audioMadiRme` | `Madi*`, `Rme*` | `Sources/OpenLolaCore/Audio/MADI/` | high | deferred |
| `audioRealtime` | `RealtimeAudio*` | `Sources/OpenLolaCore/Audio/Realtime/` | high | deferred |
| `audioRouting` | `DirectAudioMediaRouter.swift`, routing ledgers | `Sources/OpenLolaCore/Audio/Routing/` | medium | deferred |
| `networkUdp` | `UdpPcm*`, `UdpMediaTransport.swift` | `Sources/OpenLolaCore/Network/UDP/` | high | deferred |
| `networkP2P` | direct P2P and route certification files | `Sources/OpenLolaCore/Network/P2P/` | high | deferred |
| `networkNat` | `Nat*` | `Sources/OpenLolaCore/Network/NAT/` | high | deferred |
| `networkDiagnosticsAoip` | diagnostics and AoIP reports | `Sources/OpenLolaCore/Network/Diagnostics/` | medium | deferred |
| `timingLatencyBuffering` | clock, drift, latency, RX buffering | `Sources/OpenLolaCore/Timing/` | medium | deferred |
| `videoCaptureTransport` | `Video*`, renderer, multistream | `Sources/OpenLolaCore/Video/` | high | deferred |
| `controlLightingAtemOsc` | OSC, ATEM, lighting gate | `Sources/OpenLolaCore/Control/` | high | deferred |
| `evidenceReportsValidation` | report schemas, validators, measured fixtures | `Sources/OpenLolaCore/Evidence/` | medium | deferred |
| `benchmarksPerformance` | performance, latency, E2E benchmark reports | `Sources/OpenLolaCore/Benchmarks/` | medium | deferred |
| `releaseProofPackaging` | packaging, field proof, release hardening | `Sources/OpenLolaCore/Release/` | high | deferred |
| `platformAppShell` | `NativeAppShell.swift`, `NativeAppShellSurface.swift` | `Sources/OpenLolaCore/Platform/` | medium | deferred |
| `cliApplication` | `Sources/open-lola/*.swift` | `Sources/open-lola/Commands/` | medium | deferred |
| `releaseReadinessInventories` | executable review inventories | `Sources/OpenLolaCore/Support/Inventories/` | low | deferred |

## Test Contract

`SourceOwnershipInventoryTests.swift` verifies:

- the executable summary matches the inventory entries,
- every listed source, test, fixture, and documentation path exists,
- only `coreSupport` is marked as moved in C02,
- high-risk runtime groups remain deferred,
- `source-ownership-inventory` is covered by the C01 CLI inventory,
- `OpenLolaCLI.sourceOwnershipInventoryData()` round-trips through JSON.

## Resume Here

C02 is implemented for the first behavior-neutral ownership batch. Continue
source moves only through later incremental batches, starting with low-risk
inventory/support or protocol/report surfaces after each batch has explicit
test, fixture, command, and documentation coverage.

VERDICT: PARTIAL
