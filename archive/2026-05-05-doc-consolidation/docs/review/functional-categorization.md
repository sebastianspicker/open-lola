# Functional Categorization

Date: 2026-05-04  
Status: functional categorization with C11 app-shell and C12 release hygiene updates  
Scope: current filesystem snapshot after C11 and C12 implementation  
Verdict: PARTIAL

## Repository Overview

open-lola is currently a Mac-native SwiftPM project plus a substantial evidence
and documentation corpus. The implementation direction is audio-first:
low-latency audio is the hard gate, while video, lighting, recording, UI,
packaging, and network fallbacks are accepted only when they preserve explicit
audio latency contracts.

Main subsystems:

- SwiftPM runtime: `Sources/OpenLolaCore/`, `Sources/open-lola/`,
  `Sources/open-lola-app/`, `Package.swift`.
- Swift tests and fixtures: `Tests/OpenLolaCoreTests/`.
- Public documentation: `docs/`.
- Internal Mac port handoff: `mac-port/`.
- Research notes: `research/`.
- Reverse-engineering evidence: `reverse-engineering/`.
- Legacy Windows artifact corpus: `win-compiled/`.
- Verification tooling: `scripts/`, `.github/workflows/`.
- Generated SwiftPM output: `.build/`.

Obvious inconsistencies:

- The repository is not a Git worktree, but it contains `.gitignore` and a
  generated `.build/` tree. That makes current cleanup and publication proof
  filesystem-based only.
- `Sources/OpenLolaCore/` is flat even though it contains many distinct
  functional modules.
- Public, internal, historical, research, and reverse-engineering docs are
  deliberately separate but still have overlapping roadmap/milestone language.
- `docs/review/` is requested as an audit destination under `docs/`; it should
  be treated as internal review material unless explicitly promoted.
- C10 now adds a read-only release-readiness GitHub Actions workflow. Live CI
  read-back is still unavailable because this filesystem snapshot is not a Git
  worktree.
- C12 now adds an executable release hygiene gate, but no approved release
  export script exists yet.

## Functional Categories

| Category | Purpose | Files/folders included | Status | Importance | Quality/risk notes | Owner/responsibility | Recommended improvements |
|---|---|---|---|---|---|---|---|
| Core application logic | Common runtime model, capability surface, reports, validation helpers, CLI-facing primitives. | `Sources/OpenLolaCore/Core/CapabilitySummary.swift`, `Core/OpenLolaCLI.swift`, `Core/PeerIdentity.swift`, `Core/DebugTrace.swift`, `Core/PrettyJSONCodable.swift`, `CLICommandInventory.swift`, `SourceOwnershipInventory.swift`, `ReportValidatorSurface.swift`, `ReportSchemaInventory.swift`, `RealtimeAudioPathInventory.swift`, `VideoControlDegradeMatrix.swift`, many report/validation files. | active | critical | Broad responsibilities still share a mostly flat directory, but C02 moved low-risk core support into `Core/`. C01/C03/C05/C06/C07 added executable command/schema/route/audio/video ownership inventories. | Core runtime maintainer. | Continue source moves only via C02 follow-up batches with source/test/doc ownership checks. |
| CLI application | User-facing command dispatcher and command families. | `Sources/open-lola/main.swift`, `NetworkCommands.swift`, `MilestoneCommands.swift`, `MilestoneValidationCommands.swift`, `CLICommandHelpers.swift`, `MadiFullDuplexCommands.swift`, `MadiReceiveCommands.swift`, `LatencyProfileCommands.swift`, `PerformanceCommands.swift`, `E2EBenchmarkCommands.swift`. | active | critical | C01 split milestone validators, C03 centralized validator semantics in core, C05 added the route command matrix, C06 added the realtime audio path inventory command, C07 added the video/control degrade matrix command, and C11 added the app-shell surface probe. Runtime command routers remain broad. | CLI/runtime maintainer. | Continue scoped command/source movement only after release hygiene verification. |
| SwiftUI app shell | Native macOS UI shell around synthetic runtime state and release-readiness boundary status. | `Sources/open-lola-app/OpenLolaApp.swift`, `Sources/OpenLolaCore/NativeAppShell.swift`, `Sources/OpenLolaCore/NativeAppShellSurface.swift`. | active but source-level only | high | C11 keeps UI sections, read-only actions, and launch-probe requirements core-owned. UI is still not proof of hardware/runtime ownership. | macOS app maintainer. | Collect real launched-window evidence before field-ready UI claims; keep SwiftUI separate from realtime ownership. |
| Audio processing | Core Audio inventory, loopback, realtime buffers/engine, MADI TX/RX/full-duplex, RME routing, receiver mix. | `CoreAudioInventory*`, `AudioLoopback*`, `RealtimeAudio*`, `Madi*`, `Rme*`, `ReceiverMixSnapshot.swift`, `DirectAudioMediaRouter.swift`, `AudioStreamDescription.swift`, `RealtimeAudioPathInventory.swift`. | active, partial hardware proof | critical | C06 labels realtime/near-realtime/report/synthetic audio files and tightens runtime RX PASS validation. Real RME/MADI proof remains open. | Audio/realtime owner. | Add hardware evidence lanes and benchmarks before declaring PASS; keep C06 inventory synchronized with audio-sensitive files. |
| Video processing | AVFoundation capture, video transport, packet/reassembly, Blackmagic/ATEM boundaries, multi-video streams, C07 degrade matrix. | `Video*`, `BlackmagicOutputBoundary.swift`, `MultiVideoStreams.swift`, `AtemReadOnlyControl*`, `IntegratedAv*`, `IntegratedProfile*`, `VideoControlDegradeMatrix.swift`. | active, partial hardware proof | high | C07 now indexes every release-critical video/control surface and tightens integrated-profile and integrated-AV guards. Real Blackmagic/ATEM/lighting evidence remains unproven. | Video/AV owner. | Keep the C07 matrix synchronized; add measured Blackmagic/ATEM evidence and benchmark gates before PASS claims. |
| Networking / P2P transport | UDP PCM routes, sockets, loopback, route certification, NAT-friendly route, diagnostics, relay/rendezvous, route command matrix. | `UdpPcm*`, `UdpMediaTransport.swift`, `NetworkDiagnostics.swift`, `Nat*`, `MacToMacRouteCertification.swift`, `DirectP2PLocalhostSmoke.swift`, `PeerSessionRunner.swift`, `NetworkRouteCommandMatrix.swift`. | active, partial route proof | critical | C05 now separates direct-route evidence contributors from NAT, relay, diagnostics, loopback, packet-only, and direct-P2P partial evidence. Real direct-route and WAN claims still need physical route and packet-capture evidence. | Network/P2P owner. | Keep the route matrix synchronized and add measured route evidence before PASS release claims. |
| Protocol / serialization | Session negotiation/control, peer identity, UDP PCM packet formats, video transport packets, JSON reports. | `SessionControlMessage.swift`, `SessionProtocol.swift`, `SessionNegotiation.swift`, `UdpPcmPacket.swift`, `UdpPcmV2Packet.swift`, `VideoTransportPacket.swift`, `Core/PeerIdentity.swift`, `Core/PrettyJSONCodable.swift`. | active | critical | Protocol compatibility should remain clean-room and original unless explicitly gated. | Protocol owner. | Maintain packet diagrams and fixture crosswalks; avoid leaking raw reverse-engineering grammar into public docs. |
| Timing / synchronization | Clock, drift/PLC, latency profiles, AV timestamp alignment, benchmark profiles. | `MediaClock.swift`, `DriftPlc*`, `LatencyProfileContracts.swift`, `LatencyBenchmark*`, `LatencyTuning*`, `SessionProfileBenchmark.swift`. | active, partial measured evidence | critical | Performance claims require measured hardware and benchmark evidence. | Timing/performance owner. | Add benchmark result index and thresholds by profile. |
| Buffering / jitter handling | RX buffering, impairment simulation, payload capture, realtime packet handoff. | `RxBuffering.swift`, `RxImpairmentSimulator.swift`, `RealtimeAudioPayloadCaptureRing.swift`, `RealtimeAudioPacketHandoff.swift`, `RealtimeAudioBuffers.swift`. | active | critical | C06 rejects runtime/config RX mismatch and hidden runtime RX growth for fastest PASS. Buffer changes directly affect latency claims. | Realtime audio owner. | Keep explicit latency-cost accounting and add measured hardware benchmarks. |
| Hardware integration | Core Audio devices, RME/MADI, Blackmagic, ATEM read-only, lighting fixtures, reference rig. | `CoreAudioInventoryReader.swift`, `RmeFastestAudioPath.swift`, `RmeMatrixMetadata.swift`, `BlackmagicOutputBoundary.swift`, `AtemReadOnlyControl.swift`, `LightingFixtureGate*`, `ReferenceRig*`, `HardwareValidation*`. | partial hardware proof | critical | Most hardware paths need real device evidence. | Hardware validation owner. | Create a hardware evidence ledger keyed to reports and fixtures. |
| macOS platform integration | macOS SwiftPM target, CoreAudio, CoreMedia, AVFoundation, SwiftUI app. | `Package.swift`, `Sources/open-lola-app/`, `NativeAppShell*.swift`, CoreAudio/AVFoundation-related source. | active | high | SwiftPM package targets macOS 14; no Xcode project visible. C11 provides a source-level launch probe plan but no real GUI evidence. | macOS platform owner. | Keep SwiftPM as canonical; record launched-app evidence before UI release PASS. |
| Windows / legacy compatibility | Preserved Windows LoLa binaries, DLLs, installers, camera configs, tester/converter/splitter tools. | `win-compiled/1-5/`, `win-compiled/2-0/`, `reverse-engineering/lola-2-windows/`. | external/internal-only | high | Strong publication, license, and contamination boundary risk. | Reverse-engineering/compliance owner. | Keep static-only; document inclusion/exclusion policy per release manifest. |
| Reverse-engineering research | Internal evidence, generated Ghidra/static summaries, compatibility roadmap. | `reverse-engineering/`, `reverse-engineering/evidence-packages/folder-analysis-20260503-1747/`. | active internal, some generated | high | Generated evidence packages should not become public docs by accident. | RE owner. | Add generated evidence package manifest and retention policy. |
| Compliance / clean-room documentation | Public/internal boundary, clean-room rules, license, notices, release checklists, fixture provenance. | `docs/compliance/`, `LICENSE`, `THIRD_PARTY_NOTICES.md`. | active, partial | critical | Root license and notices are explicitly draft/pending; C12 now checks dependency/notice drift but cannot replace legal signoff. | Compliance/release owner. | Resolve license/notices before public release; keep `docs/review/**` excluded unless reviewed. |
| Tests | Swift unit/integration-style tests for reports, packets, networking, audio, video, release gates. | `Tests/OpenLolaCoreTests/*.swift`. | active | critical | Strong source-contract coverage; real hardware still mostly absent. | Test owner per module. | Mirror future source folders in tests; add benchmark/performance gates for critical paths. |
| Fixtures / sample data | JSON/HEX fixtures for validators and packet contracts. | `Tests/OpenLolaCoreTests/Fixtures/`. | active | high | Fixture provenance matters for public release. | Test/compliance owner. | Add fixture index with provenance and public-safety classification. |
| Benchmarks | Benchmark methodology and synthetic benchmark/report code. | `docs/benchmarks/`, `docs/architecture/benchmark-methodology.md`, `LatencyBenchmark*`, `E2EBenchmark*`, performance audit files. | active, partial measured data | high | Methodology exists; measured evidence is still incomplete. | Performance owner. | Separate synthetic smoke outputs from measured benchmark reports. |
| Build system | SwiftPM manifest and ignored build output. | `Package.swift`, `.build/`, `.gitignore`. | active/generated | high | `.build/` is present despite being ignored; no lockfile/dependency manifest beyond SwiftPM manifest. C12 now fails release candidates that include generated output. | Build/release owner. | Remove generated output only after approval; make any future export script call C12 candidate scanning. |
| Packaging / release | Packaging field tests, release hardening, notices, release manifests, artifact hygiene. | `PackagingFieldTest*`, `ReleaseHardening.swift`, `scripts/verify-release-hygiene.sh`, `docs/compliance/release-*`, `docs/review/release-artifact-hygiene.md`, `mac-port/reports/M14*`, `mac-port/reports/M15*`. | active, partial | critical | Signing, notarization, Gatekeeper, and clean-Mac evidence remain blockers. C12 protects source/archive hygiene only. | Release owner. | Keep `PARTIAL` until real package evidence exists; add an export script only after license/notices and manual evidence boundaries are approved. |
| CI / automation | Automation workflows. | `.github/workflows/release-readiness.yml`. | active but not live-read-back in this filesystem snapshot | high | Workflow runs the same local release-readiness script and contains no publish/upload step. | Build/release owner. | Verify live CI after restoring Git context. |
| Developer tooling | Documentation verifier, release-readiness script, release hygiene script, and Python checks. | `scripts/verify-release-readiness.sh`, `scripts/verify-release-hygiene.sh`, `scripts/verify-docs.sh`, `scripts/verify_docs/*.py`, `scripts/README.md`. | active | high | C10 makes local and future CI verification share one script; C11 adds the app-shell surface probe to that script; C12 adds a non-destructive candidate hygiene scanner. Generated review docs must keep links valid. | Tooling/docs owner. | Keep the release-readiness script non-publishing and update probes when Cxx inventories or release exclusions change. |
| Documentation | Public docs, roadmap, source contracts, architecture, current-state. | `README.md`, `docs/`, `MAC_PORT_PLAN.md`, `mac-port/`. | active plus historical | critical | Duplicate roadmap/history material exists by design but needs navigation. | Docs owner. | Add status/index layer; archive or demote superseded plans after review. |
| Diagrams | Architecture and generated evidence diagrams. | Mermaid in reverse-engineering docs, `reverse-engineering/evidence-packages/.../diagrams.md`; proposed diagrams in this review. | active/inferred | medium | Diagrams are scattered. | Docs/architecture owner. | Centralize generated/source architecture diagrams under docs if promoted. |
| Configuration | Ignore rules, camera presets, INI files, package config. | `.gitignore`, `Package.swift`, `win-compiled/**/CAMERAFILES/*`, `XimeaColors.ini`. | mixed active/external | high | Camera/vendor configs are external evidence, not app config. | Build/compliance/RE owner. | Separate runtime config from legacy evidence config in docs. |
| Assets / resources | Test resources and Windows camera/resource files. | `Tests/OpenLolaCoreTests/Fixtures/`, `win-compiled/**/CAMERAFILES/`. | active/external | high | Fixture provenance and camera config license status need tracking. | Test/compliance owner. | Add asset/resource inventory and release inclusion rule. |
| Logs / generated output | SwiftPM build output, object files, debug symbols, indexes, build DB. | `.build/`. No non-build `*.log` files found. | generated, needs cleanup | high | Large generated tree can pollute review/export and hides source inventory; C12 blocks it from staged candidates. | Build owner. | Delete only after user approval; keep ignored and release-excluded. |
| Archive / deprecated | Superseded research, reverse-engineering notes, public/handoff snapshots. | `research/deprecated-research/`, `reverse-engineering/deprecated-reverse-engineering/`, `docs/historical/`, `mac-port/historical/`. | stale but useful | medium | Archive material remains link-checked in some paths and may duplicate current claims. | Docs/RE owner. | Add archive manifest and freeze policy. |
| Unknown / needs review | Ambiguous publication state and ownership boundaries. | `docs/review/` after this pass, root non-Git state, generated evidence packages, Windows corpus license boundaries. | needs human review | high | The requested review docs live under `docs/` but should not automatically become public; C12 excludes them by default. | Human maintainer. | Decide whether `docs/review/` is internal-only, public-safe, or release-excluded long term. |

## Functional Category Findings

The implementation surface is source-contract rich and test-heavy, but the
dominant readiness issue is evidence classification rather than missing code.
The system has many validators for structured reports, yet the highest-value
runtime claims still depend on external hardware, real routes, real packaging,
and clean-Mac validation.

The repository is best treated as four overlapping products:

1. A SwiftPM prototype/runtime implementation.
2. A public documentation and clean-room release surface.
3. An internal reverse-engineering/evidence archive.
4. A legacy Windows binary/config corpus used only for static context.

Future cleanup should preserve those boundaries rather than merging everything
into one public documentation tree.

VERDICT: PARTIAL
