# Source Restructure Proposal

Date: 2026-05-04  
Status: proposal with C02 first batch implemented  
Scope: SwiftPM target names unchanged; only low-risk Core support moved  
Verdict: PARTIAL

## Objective

Keep the SwiftPM target shape while making source responsibilities visible. The
current source tree is valid, but `Sources/OpenLolaCore/` is still mostly flat
and contains many unrelated functional areas. C02 implemented the first
behavior-neutral split by moving shared support files into
`Sources/OpenLolaCore/Core/`.

## Current Source Shape

```text
Sources/
  OpenLolaCore/
    Core/
  open-lola/
  open-lola-app/

Tests/
  OpenLolaCoreTests/
    Fixtures/
```

Current package targets:

- `OpenLolaCore`: library target.
- `open-lola`: executable target depending on `OpenLolaCore`.
- `open-lola-app`: executable target depending on `OpenLolaCore`.
- `OpenLolaCoreTests`: test target with processed fixtures.

## Proposed Source Shape

This keeps SwiftPM target names unchanged.

```text
Sources/
  OpenLolaCore/
    Core/
    Protocol/
    Audio/
      CoreAudio/
      MADI/
      Realtime/
      Routing/
    Network/
      UDP/
      P2P/
      NAT/
      Diagnostics/
    Timing/
      Clock/
      DriftPLC/
      LatencyProfiles/
      Buffering/
    Video/
      Capture/
      Transport/
      Blackmagic/
      MultiStream/
    Control/
      OSC/
      ATEM/
      Lighting/
    Evidence/
      Reports/
      Validation/
      Fixtures/
    Benchmarks/
    Release/
    Platform/
    Support/
  open-lola/
    Commands/
    Parsing/
    main.swift
  open-lola-app/
    Views/
    OpenLolaApp.swift

Tests/
  OpenLolaCoreTests/
    Core/
    Protocol/
    Audio/
    Network/
    Timing/
    Video/
    Control/
    Evidence/
    Benchmarks/
    Release/
    Fixtures/

tools/
  verification/
  analysis/
  release/
```

## Proposed Source Ownership

| Proposed area | Current files | Responsibility | What should not belong there | Validation after move |
|---|---|---|---|---|
| `Core/` | `Core/CapabilitySummary.swift`, `Core/OpenLolaCLI.swift`, `Core/PeerIdentity.swift`, `Core/DebugTrace.swift`, `Core/PrettyJSONCodable.swift` | Shared identity, capability, JSON/debug support. | Hardware-specific run logic. | `swift build`, capability tests, source ownership inventory tests. |
| `Protocol/` | `SessionControlMessage.swift`, `SessionProtocol.swift`, `SessionNegotiation.swift`, packet description files shared across media. | Versioned session/control/protocol contracts. | Raw reverse-engineering grammar. | Session/protocol tests. |
| `Audio/CoreAudio/` | `CoreAudioInventory.swift`, `CoreAudioInventoryReader.swift`, `AudioStreamDescription.swift` | macOS Core Audio inventory and format models. | Network route logic. | CoreAudio tests. |
| `Audio/MADI/` | `Madi*`, `Rme*`, `ReceiverMixSnapshot.swift` | RME/MADI TX/RX/full-duplex and matrix metadata. | Generic UDP socket operations. | MADI/RME tests. |
| `Audio/Realtime/` | `RealtimeAudio*`, `AudioBaselineEvidence.swift`, `RealtimeAudioPayloadCaptureRing.swift` | Realtime engine, buffers, handoff, audio proof contracts. | UI/app shell code. | Realtime audio tests and future benchmarks. |
| `Audio/Routing/` | `DirectAudioMediaRouter.swift`, `AudioRoutingAssumptionLedger.swift` | Audio route/mix assumptions and direct media routing. | Release packaging proof. | Routing-related tests. |
| `Network/UDP/` | `UdpPcm*`, `UdpMediaTransport.swift`, `MultichannelTransport.swift` | UDP PCM packets, sockets, loopback, route configs. | NAT/rendezvous service logic. | UDP packet/route tests. |
| `Network/P2P/` | `PeerSessionRunner.swift`, `DirectPeerSessionReport.swift`, `DirectP2PLocalhostSmoke.swift`, `MacToMacRouteCertification.swift`, `EndpointLoopbackReport.swift` | Direct P2P route/session proof. | WAN fallback and relay implementation. | P2P/session/route tests. |
| `Network/NAT/` | `Nat*` | Rendezvous/relay/fallback route proof. | Fastest-direct route claims. | NAT route tests and smokes. |
| `Network/Diagnostics/` | `NetworkDiagnostics.swift`, `AoipEvaluationReport.swift`, `NetworkAoipCertification.swift` | Network diagnostics and AoIP/AVB certification reports. | Audio callback code. | Diagnostics/AoIP tests. |
| `Timing/` | `MediaClock.swift`, `DriftPlc*`, `Latency*`, `Rx*`, `SessionProfileBenchmark.swift` | Clock, drift, PLC, latency profiles, RX buffering. | Video capture device code. | Timing, latency, RX tests. |
| `Video/` | `Video*`, `BlackmagicOutputBoundary.swift`, `MultiVideoStreams.swift` | Capture, transport, packet/reassembly, output, Blackmagic boundary, multi-stream. | Audio latency policy source of truth. | Video tests and future hardware probe. |
| `Control/` | `Osc*`, `AtemReadOnlyControl*`, `LightingFixtureGate*` | OSC cue loop, ATEM read-only, sACN/Art-Net fixture gate. | Destructive control without explicit gate. | Control/lighting tests. |
| `Evidence/` | `MeasurementReport.swift`, `ReferenceRig*`, `HardwareValidation*`, report validation files | Shared report schemas, validators, evidence acceptance. | Raw generated `.build` output. | Report fixture tests. |
| `Benchmarks/` | `PerformanceAudit*`, `LatencyBenchmark*`, `E2EBenchmark*` | Synthetic and measured benchmark contracts. | Release/legal policy. | Benchmark tests. |
| `Release/` | `RecordingSession*`, `PackagingFieldTest*`, `FieldReadyRuntimeProof*`, `FieldReadinessRun.swift`, `ReleaseHardening.swift`, `FasterThanLoLaClosure*`, `LoLaParityDeferredFeatures.swift` | Packaging, recording, field proof, release hardening, parity/closure ledgers. | Raw Windows binaries. | Release/field proof tests and smokes. |
| `Platform/` | `NativeAppShell.swift`, `NativeAppShellSurface.swift` | macOS app-shell runtime boundary, UI surface contract, and launch probe plan. | SwiftUI view layout. | Native app shell tests and C11 surface probe. |
| `open-lola/Commands/` | Current command files | CLI command families by domain. | Core runtime implementation. | CLI smoke plus `swift test`. |
| `open-lola-app/Views/` | Private views in `OpenLolaApp.swift` if split later. | SwiftUI presentation. | Realtime runtime ownership. | App build and launch probe. |

## Proposed Test Shape

Tests should mirror source folders after the source tree is moved:

```text
Tests/OpenLolaCoreTests/
  Audio/
  Network/
  Timing/
  Video/
  Control/
  Evidence/
  Benchmarks/
  Release/
  Fixtures/
```

The fixture directory can remain a single SwiftPM resource bundle, but add a
fixture index that maps each fixture folder to:

- source validator,
- test file,
- provenance,
- public/internal status,
- expected verdict.

## Proposed Tool Shape

`scripts/` is working and should not be churned without need. C10 adds
`scripts/verify-release-readiness.sh` as the shared local/CI entrypoint. A
future move to `tools/` is only useful if the repository gains more tool
families:

```text
tools/
  verification/  # current scripts/verify-release-readiness.sh and verify_docs
  analysis/      # reverse-engineering static inventory tools if promoted
  release/       # future release/export checks
```

## Refactor Guardrails

Before moving any source file:

1. Build a source/test/doc crosswalk.
2. Move one functional area at a time.
3. Keep target names unchanged.
4. Run `swift build` and `swift test` after every batch.
5. Run `bash scripts/verify-docs.sh` if docs or paths are updated.
6. Run a relevant CLI smoke after command or runtime moves.

## C02 Implemented First Batch

C02 added [source-ownership-inventory.md](source-ownership-inventory.md) and
the executable `SourceOwnershipInventory` crosswalk, then moved only the
low-risk `Core/` support group. The remaining source areas are still proposals
and should move only through one batch at a time with tests, docs, fixtures,
CLI ownership, and rollback scope kept explicit.

VERDICT: PARTIAL
