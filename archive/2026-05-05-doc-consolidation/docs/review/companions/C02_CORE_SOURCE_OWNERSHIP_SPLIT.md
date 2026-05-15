# C02 Core Source Ownership Split

Date: 2026-05-04  
Status: first ownership batch implemented  
Priority: P1  
Verdict: PARTIAL

## Code Evidence

- `Sources/OpenLolaCore/` previously contained the shared library as one flat
  directory.
- C02 now moves the low-risk shared support group into
  `Sources/OpenLolaCore/Core/`.
- The remaining mostly flat directory still mixes protocol, UDP transport, NAT,
  Core Audio, MADI/RME,
  realtime audio, RX buffering, AVFoundation video, ATEM/OSC/lighting, reports,
  validation, packaging, release hardening, and benchmark code.
- Several files are large enough to hide ownership boundaries, including
  `ReleaseHardening.swift`, `UdpPcmV2Packet.swift`, `AoipEvaluationReport.swift`,
  `OscCueProbe.swift`, `FieldReadyRuntimeProof.swift`, `RxBuffering.swift`,
  `MadiReceive.swift`, `VideoTransportPacket.swift`, and
  `NetworkDiagnostics.swift`.

## Objective

Create a stable source ownership structure before continuing broad feature work.

## Affected Files

- `Sources/OpenLolaCore/*.swift`
- `Sources/OpenLolaCore/Core/*.swift`
- `Tests/OpenLolaCoreTests/*.swift`
- `Tests/OpenLolaCoreTests/Fixtures/`
- `Package.swift`

## Improvement Plan

1. Build a source/test/doc crosswalk for every active source group. Done in
   `SourceOwnershipInventory.swift` and
   [source-ownership-inventory.md](../source-ownership-inventory.md).
2. Define target subfolders while keeping the SwiftPM target name
   `OpenLolaCore`. Done; `Package.swift` target names are unchanged.
3. Move only one low-risk ownership group first. Done for core support.
4. Defer realtime audio, UDP transport, and video moves until command/test
   coverage is explicit. Still deferred.
5. Keep generated `.build/` output out of the plan. Still deferred to C12.

## Proposed Ownership Groups

| Group | Example files | Risk |
|---|---|---|
| Core support | `Core/CapabilitySummary.swift`, `Core/OpenLolaCLI.swift`, `Core/PeerIdentity.swift`, `Core/DebugTrace.swift`, `Core/PrettyJSONCodable.swift` | low |
| Protocol | `SessionProtocol.swift`, `SessionControlMessage.swift`, packet contracts | medium |
| Evidence/report validation | `*Report.swift`, `*Validation.swift` | medium |
| Network/UDP/NAT | `UdpPcm*`, `Nat*`, `NetworkDiagnostics.swift` | high |
| Realtime audio/MADI/RME | `RealtimeAudio*`, `Madi*`, `Rme*`, `Rx*` | high |
| Video/control | `Video*`, `Atem*`, `Osc*`, `Lighting*` | high |
| Release/proof | `ReleaseHardening.swift`, `PackagingFieldTest*`, `FieldReadyRuntimeProof*` | high |

## Acceptance Criteria

- Source moves are mechanical and behavior-neutral. Done for `Core/`.
- Tests mirror or clearly map to new source groups. Done through
  `SourceOwnershipInventoryTests.swift`.
- Documentation links and references remain valid. Updated for active review
  and architecture docs; historical snapshots are intentionally unchanged.
- One batch can be reverted without affecting unrelated source groups. Done;
  only the core support group moved.

## Implemented Artifacts

- `Sources/OpenLolaCore/SourceOwnershipInventory.swift`
- `Tests/OpenLolaCoreTests/SourceOwnershipInventoryTests.swift`
- `Sources/OpenLolaCore/Core/CapabilitySummary.swift`
- `Sources/OpenLolaCore/Core/OpenLolaCLI.swift`
- `Sources/OpenLolaCore/Core/PeerIdentity.swift`
- `Sources/OpenLolaCore/Core/DebugTrace.swift`
- `Sources/OpenLolaCore/Core/PrettyJSONCodable.swift`
- `docs/review/source-ownership-inventory.md`
- CLI command: `open-lola source-ownership-inventory`

## Verification

```bash
swift build
swift test
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
```

## Resume Here

C02 first-batch implementation is complete. C12 release hygiene is also
implemented. Continue future source moves through incremental low-risk batches
only.

VERDICT: PARTIAL
