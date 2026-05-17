# Code Index

Date: 2026-05-16
Status: first-pass source inventory before cleanup/refactor
Verdict: PARTIAL

This document indexes the live code surface enough to route future audits and
refactors. It is intentionally descriptive: it does not delete, move, or
recommend broad rewrites by itself.

## Scope And Method

Commands used for this pass:

```bash
find Sources Tests linux_connector scripts script .github -type f \( -name '*.swift' -o -name '*.c' -o -name '*.h' -o -name '*.py' -o -name '*.sh' -o -name '*.yml' -o -name '*.yaml' -o -name '*.toml' \) | sort
find Sources/OpenLolaCore Sources/OpenLolaContracts Sources/open-lola Sources/open-lola-app Sources/open-lola-app-main Tests/OpenLolaCoreTests linux_connector/lola_connector linux_connector/tests scripts script -type f \( -name '*.swift' -o -name '*.py' -o -name '*.sh' \) | sed 's#/[^/]*$##' | sort | uniq -c
find Sources Tests linux_connector scripts script .github -type f \( -name '*.swift' -o -name '*.c' -o -name '*.h' -o -name '*.py' -o -name '*.sh' -o -name '*.yml' -o -name '*.yaml' -o -name '*.toml' \) -exec wc -l {} + | sort -nr | head -80
rg -n "^(public |private |internal |@main|struct |class |enum |protocol |func |actor |final class|extension |def |async def )" Sources/OpenLolaCore Sources/OpenLolaContracts Sources/open-lola Sources/open-lola-app Sources/open-lola-app-main linux_connector/lola_connector scripts/verify_docs scripts/lib
```

Measured surface:

- 1,271 source/config/script files under `Sources`, `Tests`,
  `linux_connector`, `scripts`, `script`, and `.github` when vendored C trees
  are included.
- 277,523 total source lines in that measured set, dominated by vendored Opus
  and JPEG XS sources.
- Owned active Swift/Python/shell surface by count: 4 Swift contract files,
  248 Swift core files, 31 Swift app support files, 17 Swift CLI files, 168
  Swift test files, 9 Python connector modules, 3 Python connector test files,
  35 shell/Python verification/helper scripts.

Because the full measured set is too large for honest file-by-file semantic
inspection in one pass, this index is directory-first for broad subsystems and
file-level for entry points, public contracts, high-risk runtime files, and
small Python/script surfaces. Files requiring deeper inspection are listed in
the coverage section instead of guessed.

## Inventory Legend

- Runtime role: `entrypoint`, `domain logic`, `adapter`, `UI`, `test`,
  `config`, `script`, `generated`, `unknown`.
- Status: `active`, `unused`, `generated`, `deprecated`, `duplicate`,
  `unclear`.
- UNCLEAR means usage was not proven by this pass; the row states what would
  prove it.

## Entrypoints And Manifests

| File path | Language/type | Primary responsibility | Main exports/classes/functions | Runtime role | Direct dependencies worth knowing | Status | Obvious smells |
|---|---|---|---|---|---|---|---|
| `Package.swift` | SwiftPM manifest | Defines macOS Swift package products, targets, linked frameworks, and vendored C targets. | Products `OpenLolaCore`, `OpenLolaContracts`, `OpenLolaAppSupport`, `open-lola`, `open-lola-app`; targets `COpenLolaAtomics`, `CJpegXSReference`, `COpus`. | config | AppKit, AVFoundation, CoreAudio, CoreGraphics, CoreImage, ImageIO, CoreMedia, UniformTypeIdentifiers; vendored Opus/JPEG XS. | active | Large explicit COpus source list is maintenance-heavy. |
| `pyproject.toml` | Python project config | Declares Linux connector package metadata and dev tool bounds. | `[project]`, `[project.optional-dependencies].dev`, pytest and ruff config. | config | pytest, pytest-asyncio, ruff, mypy, optional scapy. | active | None obvious. |
| `.github/workflows/release-readiness.yml` | GitHub Actions workflow | Runs the release-readiness gate in CI. | Workflow jobs not line-inspected in this pass. | config | `scripts/verify-release-readiness.sh`; Python dev extras. | active | UNCLEAR: exact job parity should be checked against script before CI edits. |
| `Sources/open-lola/main.swift` | Swift | CLI entry point and top-level command dispatcher. | `runOpenLolaCommand`, `openLolaCommands`, `openLolaCommandRegistry`, `RegisteredCommand`, `printTopLevelUsage`. | entrypoint | `OpenLolaCore`, Darwin, command handlers under `Sources/open-lola/Commands`. | active | Many commands share a single registry and switch chain; risk of command-surface sprawl. |
| `Sources/open-lola-app-main/OpenLolaAppMain.swift` | SwiftUI | Native macOS app executable entry point. | `OpenLolaAppMain`. | entrypoint | AppKit, SwiftUI, `OpenLolaAppSupport`. | active | None obvious. |
| `Sources/open-lola-app/OpenLolaApp.swift` | SwiftUI | App scene composition, windows, settings, menu command wiring, app lifecycle refresh. | `OpenLolaApp`, `OpenLolaAppScene`, `AppMenuActionHandling`. | UI | SwiftUI, `OpenLolaCore`, app state/controllers. | active | Menu/action wiring is dense; UI truth depends on report-backed state. |
| `linux_connector/lola_connector/cli.py` | Python | Python LoLa connector command-line parser and command runner. | `build_parser`, `validate_cli_args`, `run`, backend construction helpers. | entrypoint | argparse, connector/runtime/backends/protocol modules. | active | Many flags and bounds; risk of argument drift from Swift path. |
| `script/build_and_run.sh` | Shell | Builds SwiftPM app/CLI products and stages runnable macOS app bundle for probes. | Shell procedure with `--verify` support. | script | `swift build`, app Info.plist/entitlements, bundled CLI. | active | Legacy singular `script/` path is active but differs from `scripts/`. |
| `script/build_cli_app_bundle.sh` | Shell | Builds and stages the CLI app bundle. | Shell build procedure. | script | `swift build --product open-lola`. | active | Legacy path; keep shellcheck coverage. |

## Core Contracts

| File path | Language/type | Primary responsibility | Main exports/classes/functions | Runtime role | Direct dependencies worth knowing | Status | Obvious smells |
|---|---|---|---|---|---|---|---|
| `Sources/OpenLolaContracts/MeasurementMethodology.swift` | Swift | Shared evidence-methodology vocabulary. | `MeasurementMethodology`. | domain logic | Swift Codable/Equatable/Sendable. | active | None obvious. |
| `Sources/OpenLolaContracts/MeasurementVerdict.swift` | Swift | Shared PASS/PARTIAL/FAIL verdict vocabulary. | `MeasurementVerdict`. | domain logic | Codable/Hashable/Sendable. | active | Public contract; changes require fixture/test updates. |
| `Sources/OpenLolaContracts/PrettyJSONCodable.swift` | Swift | Stable pretty JSON encoding/decoding helper for reports. | `JSONReportCoder`, `PrettyJSONCodable`. | adapter | Foundation JSONEncoder/JSONDecoder. | active | Central serialization contract. |
| `Sources/OpenLolaContracts/RxBufferProfile.swift` | Swift | Shared RX buffering profile vocabulary. | `RxBufferProfile`. | domain logic | Codable/CaseIterable. | active | Compatibility-sensitive naming. |
| `Sources/OpenLolaCore/Core/` | Swift directory | Shared CLI/core support, capability summary, peer identity, validation helpers, debug trace. | `CapabilitySummary`, `OpenLolaCLI`, `PeerIdentity`, `DebugTrace`, `KeyValueArgumentParser`, `ValidationPrimitives`. | domain logic | Foundation; many downstream report and command surfaces. | active | `OpenLolaCLI` can become a facade bottleneck if new features accumulate there. |
| `Sources/OpenLolaCore/Protocol/` | Swift directory | Session capabilities, negotiation, control messages, and protocol contract types. | `SessionControlMessage`, `SessionProtocol`, `SessionNegotiation`, `SessionCapabilityValidating`. | domain logic | Core contracts, audio/video stream descriptors. | active | Protocol compatibility risk; no cleanup without test-backed migration. |

## Audio, Timing, And Realtime Runtime

| File path | Language/type | Primary responsibility | Main exports/classes/functions | Runtime role | Direct dependencies worth knowing | Status | Obvious smells |
|---|---|---|---|---|---|---|---|
| `Sources/COpenLolaAtomics/OpenLolaAtomics.c` and `include/OpenLolaAtomics.h` | C bridge | Local atomics used by realtime Swift paths. | C atomic ring helpers from header/source. | adapter | C11 atomics; Swift `COpenLolaAtomics` target. | active | High-risk memory-order surface; changes require realtime tests. |
| `Sources/OpenLolaCore/Audio/Codecs/OpusCELTLowDelayCodec.swift` | Swift | Low-delay Opus CELT encode/decode wrapper. | `OpusCELTLowDelayConstants`, `OpusCELTLowDelayCodecValidation`, `OpusCELTLowDelayEncoder`, `OpusCELTLowDelayDecoder`. | adapter | `COpus`, Foundation. | active | Native codec bridge; error handling and lifetime management are high risk. |
| `Sources/OpenLolaCore/Audio/CoreAudio/` | Swift directory | Core Audio device inventory and stream description modeling. | `CoreAudioInventoryReader`, `CoreAudioInventoryReport`, `AudioStreamDescription`, device/channel layout snapshots. | adapter | CoreAudio, Foundation. | active | Platform API complexity; fallback device identity cache should be audited before refactors. |
| `Sources/OpenLolaCore/Audio/MADI/` | Swift directory | RME/MADI TX/RX/full-duplex synthetic and socket runtime, reports, buffering, matrix metadata. | `MadiReceiveEngine`, `MadiFullDuplexSession`, `MadiFullDuplexSocketRunner`, `MadiTransmitSyntheticSmoke`, `RmeFastestAudioPathReport`, `RmeMatrixMetadataSnapshot`. | domain logic | Foundation, Dispatch, UDP PCM v2, realtime/routing types, contracts. | active | High-risk state transitions, buffering, and synthetic-vs-measured verdict boundaries. |
| `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift` | Swift | Core direct-peer Core Audio graph runtime. | `DirectPeerRealtimeAudioGraph`. | domain logic | CoreAudio, Darwin, Foundation, `COpenLolaAtomics`, graph callbacks/types. | active | 713 lines; high-risk realtime path with unclear state transitions worth a dedicated audit. |
| `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraphCallbacks.swift` | Swift | Core Audio IOProc callback glue. | `directPeerRealtimeAudioIOProc`, input/output IOProc helpers, channel map validation. | adapter | CoreAudio callback ABI. | active | Callback work must stay bounded and nonblocking. |
| `Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioBuffers.swift` | Swift | Bounded audio rings, playout queues, fixed-target jitter buffer. | `RealtimeAudioBlockRing`, `RealtimeAudioDueBlockPlayout`, `RealtimeAudioFixedTargetJitterBuffer`. | domain logic | Foundation; packet/frame types. | active | Timing/drop semantics are critical; audit for hidden buffering before latency work. |
| `Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPayloadCaptureRing.swift` | Swift | Captures realtime audio payloads from Core Audio buffers. | `RealtimeAudioPayloadCaptureRing`, `RealtimeAudioBufferListReader`. | adapter | CoreAudio, Darwin, Foundation. | active | Buffer-list pointer arithmetic and copy bounds are high risk. |
| `Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngine*.swift` | Swift files | Realtime engine reports, validation, helpers, and synthetic smoke. | `RealtimeAudioEngineReport`, `RealtimeAudioEngineConfiguration`, validation helpers. | domain logic | Foundation, report contracts. | active | Synthetic evidence can be mistaken for field evidence; keep verdict gates explicit. |
| `Sources/OpenLolaCore/Audio/Routing/` | Swift directory | Audio loopback runs, direct media routing, baseline evidence, receiver mix snapshots. | `AudioLoopbackRunReport`, `AudioLoopbackRunConfiguration`, `DirectAudioMediaRouter`, `ReceiverMixSnapshot`. | domain logic | CoreAudio/Darwin for runtime loopback; UDP/audio contracts. | active | Loopback reports are measured-like but not field proof; avoid false PASS. |
| `Sources/OpenLolaCore/Timing/` | Swift directory | Media clock, latency tuning, RX buffering, drift/PLC reports, impairment simulation. | `MediaClock`, `AVSyncPolicy`, `RxBuffering`, `RxBufferBenchmarkRunner`, `DriftPlcReport`, `LatencyTuningReport`. | domain logic | Foundation, UDP packet age metrics, report contracts. | active | Timing policy is spread across several files; duplicate or conflicting buffer semantics are possible. |

## Network And Media Transport

| File path | Language/type | Primary responsibility | Main exports/classes/functions | Runtime role | Direct dependencies worth knowing | Status | Obvious smells |
|---|---|---|---|---|---|---|---|
| `Sources/OpenLolaCore/Network/UDP/` | Swift directory | UDP PCM v1/v2 packet contracts, socket operations, route certification, loopback, Opus packet wrapper, multichannel transport. | `UdpPcmPacket`, `UdpPcmV2Packet`, `UdpMediaTransport`, `UdpPcmSocketOperations`, `UdpPcmRouteCertification`, `MultichannelTransport`, `PacketCodec`. | domain logic | Foundation/Darwin sockets, timing/report types, Opus codec. | active | Several packet versions and route report types create compatibility-shim risk. |
| `Sources/OpenLolaCore/Network/P2P/PeerSessionRunner.swift` | Swift | Main direct peer session runner for audio/control paths. | `PeerSessionRunner`. | domain logic | UDP PCM, control sockets, timing, report builders, media I/O helpers. | active | High-risk orchestration; audit lifecycle and error paths before refactor. |
| `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVSocketRunner.swift` | Swift | Socket-backed Direct AV runtime runner. | `DirectPeerSessionAVSocketRunner`. | domain logic | Audio/video loops, AV run types, report builder, UDP sockets. | active | 685 lines; likely overcomplicated due to runtime orchestration. |
| `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionReport.swift` | Swift | Direct peer report schema and validation. | `DirectPeerSessionReport` and validation helpers. | domain logic | Contracts, evidence/report validators. | active | 698 lines; public report contract with many PASS/PARTIAL gates. |
| `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAV*.swift` | Swift files | Direct AV audio/video loops, metrics, control service, run types, runtime reports, report builder. | `DirectPeerSessionAVAudioLoops`, `DirectPeerSessionAVVideoLoops`, `DirectPeerSessionAVMetricsService`, `DirectPeerSessionAVReportBuilder`, AV run/report types. | domain logic | Realtime audio graph, video packet/reassembly, UDP sockets, report contracts. | active | State and metrics spread across many helpers; verify behavior before simplification. |
| `Sources/OpenLolaCore/Network/P2P/DirectPeerTwoPeer*.swift` | Swift files | Two-peer run plans, local supervisor reports, prototype aggregation. | `DirectPeerTwoPeerRunPlan`, `DirectPeerTwoPeerLocalRunReport`, report types. | domain logic | Direct peer report schemas, command support. | active | Source-level plan can be mistaken for measured proof. |
| `Sources/OpenLolaCore/Network/P2P/DirectPeerMesh*.swift` | Swift files | Synthetic/runtime mesh topology and validation reports. | `DirectPeerMeshTopologyReport`, `DirectPeerMeshRuntimeReport`, `DirectPeerMeshValidation`. | domain logic | Peer session and report types. | active | Mesh PASS requires external evidence; local smokes are insufficient. |
| `Sources/OpenLolaCore/Network/P2P/EndpointLoopbackReport.swift` and `MacToMacRouteCertification.swift` | Swift files | Endpoint loopback and Mac-to-Mac route evidence reports. | `EndpointLoopbackReport`, `MacToMacRouteCertificationReport`. | domain logic | Measurement/report contracts. | active | Evidence classification matters; avoid promoting synthetic/local evidence. |
| `Sources/OpenLolaCore/Network/NAT/` | Swift directory | NAT-friendly route reports, rendezvous/relay runners, protocol constants, localhost smokes. | `NatFriendlyRouteReport`, `NatFriendlyRouteRunner`, `NatRendezvousRelayRunners`, `NatProtocolConstants`. | domain logic | Foundation/Darwin networking, direct route reports. | active | Compatibility path risk: relay/rendezvous must not become default success. |
| `Sources/OpenLolaCore/Network/RTP/AES67ST2110L24Transport.swift` | Swift | Optional AES67/ST 2110-30-shaped RTP/L24 transport. | `AES67ST2110L24Transport` types/functions. | domain logic | RTP/SDP concepts, Direct P2P audio transport. | active | Standards-shaped but not interop proof; requires external timing/capture evidence. |
| `Sources/OpenLolaCore/Network/Diagnostics/` | Swift directory | AoIP reports/certification and generic network diagnostics. | `AoipEvaluationReport`, `NetworkAoipCertification`, `NetworkDiagnostics`. | domain logic | Process runner, report contracts. | active | Diagnostics can be mistaken for certification. |

## External Connector And LoLa Compatibility

| File path | Language/type | Primary responsibility | Main exports/classes/functions | Runtime role | Direct dependencies worth knowing | Status | Obvious smells |
|---|---|---|---|---|---|---|---|
| `Sources/OpenLolaCore/Connectors/Core/` | Swift directory | External connector reports, executable preflight, process running, session runtime. | `ExternalConnectorSession`, `ExternalConnectorSessionRunner`, `ExternalConnectorSessionRuntime`, `ExternalConnectorProcessRunner`, `ExternalConnectorExecutablePreflight`. | adapter | Foundation processes, UDP/TCP connector integrations, report contracts. | active | Process lifecycle and failure reporting are high risk; avoid swallowing exits. |
| `Sources/OpenLolaCore/Connectors/LoLa/` | Swift directory | Swift LoLa compatibility lane: control socket/runtime, media codecs, UDP media, raw-link evidence, AVFoundation/CoreAudio live bridges. | `LoLaCompatibilityControlMessage`, `LoLaCompatibilityControlSocket`, `LoLaCompatibilityMediaCodec`, `LoLaCompatibilityMediaSession`, `LoLaCompatibilityUdpMedia`, `LoLaControlExchangeRuntime`, `LoLaTcpControlExchangeRuntime`, `LoLaCoreAudioLiveBridge`, `LoLaAVFoundationLiveRaw8Source`. | adapter | Foundation/Darwin sockets, AVFoundation/CoreAudio, raw packet codecs, Linux connector protocol docs. | active | Explicit compatibility path with many recovered behaviors; do not generalize into native defaults. |
| `Sources/OpenLolaCore/Connectors/JackTrip/` | Swift directory | JackTrip external launch and auxiliary video plans. | `JackTripLaunchPlan`, `JackTripAuxiliaryVideoPlan`. | adapter | External connector session reports. | active | Compatibility wrapper; local process proof is not audio parity. |
| `Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridLaunchPlan.swift` | Swift | UltraGrid/MVTP external launch plan. | `UltraGridLaunchPlan`. | adapter | External connector session runners. | active | Compatibility wrapper; local process proof is not AV parity. |
| `Sources/OpenLolaCore/Connectors/NMP/` | Swift directory | Universal external connector NMP plan, preflight, endpoint run, and workflow reports. | `ExternalConnectorConnectionPlan`, `ExternalConnectorNmpPlan`, `ExternalConnectorNmpPreflight`, `ExternalConnectorNmpEndpointRun`, `ExternalConnectorNmpWorkflow`. | adapter | Connector launch plans, process runner, report validators. | active | Could become a single-use abstraction layer if not kept tied to real workflows. |
| `linux_connector/lola_connector/` | Python package | Python LoLa compatibility seed for Linux/WSL validation and synthetic media exchange. | `LolaConnector`, `Session`, `LolaLinuxRuntime`, `RuntimeStats`, media/protocol builders, process backends. | adapter | asyncio, socket, struct, optional process media backends. | active | Compatibility seed; keep separate from SwiftPM packaging. |
| `linux_connector/lola_connector/backends.py` | Python | Audio/video capture/playback/display backends, process lifecycle wrappers, diagnostic media. | `AudioCapture`, `SineAudioCapture`, `DiagnosticVideoCapture`, `ProcessAudioCapture`, `ProcessRawVideoCapture`, `ProcessJpegVideoCapture`, `ProcessVideoDisplay`, `JpegFrameExtractor`. | adapter | asyncio subprocesses, process pipes. | active | 591 lines; process cleanup and buffer caps need careful audit. |
| `linux_connector/lola_connector/connector.py` | Python | Control/media session protocol handling for Python connector. | `Session`, `LolaConnector`. | domain logic | protocol, media, socket, backends. | active | Stateful connector; prove usage via tests before edits. |
| `linux_connector/lola_connector/runtime.py` | Python | Runtime orchestration around connector and media backends. | `RuntimeStats`, `LolaLinuxRuntime`. | domain logic | asyncio tasks, connector, backends. | active | Startup/stop task failure handling is high-risk. |
| `linux_connector/lola_connector/media.py`, `protocol.py`, `ethernet.py`, `selftest.py` | Python files | Media packet sizing/reassembly, control protocol, raw Ethernet/IP/UDP framing, self-test orchestration. | Media packet builders/reassemblers, `MediaSettings`, control parsers, raw frame builders, self-test helpers. | domain logic | socket, struct, protocol constants. | active | Compatibility contract; avoid guessing fields. |

## Video, Control, Integration, Evidence, Release

| File path | Language/type | Primary responsibility | Main exports/classes/functions | Runtime role | Direct dependencies worth knowing | Status | Obvious smells |
|---|---|---|---|---|---|---|---|
| `Sources/OpenLolaCore/Video/` | Swift directory | Video device inventory, AVFoundation capture, raw preview, video packet transport/reassembly, reports, multi-stream policy, JPEG XS bridge wrapper. | `VideoCaptureAVFoundation`, `VideoCaptureReport`, `VideoTransportPacket`, `VideoTransportReassembly`, `VideoTransportRunner`, `VideoOutputRenderer`, `MultiVideoStreams`, `JPEGXSReferenceCodec`. | domain logic | AVFoundation, AppKit/CoreGraphics, UDP/video packet contracts, `CJpegXSReference`. | active | Capture/render/packet fragmentation are high-risk; JPEG XS integration is opt-in and should not be overclaimed. |
| `Sources/OpenLolaCore/Control/` | Swift directory | OSC cue reports, ATEM read-only control, lighting fixture gates. | `OscCueProbe`, `OscCueRunners`, `AtemReadOnlyControl`, `LightingFixtureGate`, `LightingFixtureGateReport`, `LightingFixtureGateRun`. | domain logic | Foundation/network/process/report contracts. | active | Control must degrade before audio; read-only ATEM path should not become command/control path accidentally. |
| `Sources/OpenLolaCore/Integration/` | Swift directory | Integrated AV/profile reports and runtime aggregation. | `IntegratedAvReport`, `IntegratedAvRun`, `IntegratedProfileReport`, `IntegratedProfileRun`, `IntegratedProfileRuntimeEvidence`. | domain logic | Subordinate evidence reports. | active | Aggregation can hide partial subordinate evidence if validators loosen. |
| `Sources/OpenLolaCore/Evidence/` | Swift directory | Hardware/reference rig reports, generic measurement reports, schema inventory, validator surface, verdict policy. | `HardwareValidationReport`, `ReferenceRigReport`, `MeasurementReport`, `ReportSchemaInventory`, `ReportValidatorSurface`, `VerdictValidationPolicy`. | domain logic | Report contracts and fixtures. | active | Public schema contract; high risk for false green claims. |
| `Sources/OpenLolaCore/Release/` | Swift directory | Release readiness, field/runtime proof, packaging, recording artifacts, faster-than-LoLa closure, current evidence matrix. | `OpenSourceReleaseReadiness`, `ReleaseHardening`, `PackagingFieldTest`, `RecordingSessionArtifacts`, `FieldReadyRuntimeProof`, `FasterThanLoLaClosure`, `CurrentEvidenceStatusMatrix`. | domain logic | Evidence reports, validation primitives, filesystem artifacts. | active | Many source-level reports are blockers, not approvals; false PASS risk. |
| `Sources/OpenLolaCore/Release/Goal/` | Swift directory | GOAL.md codewise/runtime/preflight/completion audit reports. | `GoalCodewiseClosure`, `GoalRuntimeEvidenceTemplate`, `GoalRuntimePreflight`, `GoalCompletionAudit`. | domain logic | Current docs/goals and report validators. | active | Goal status can drift from docs; keep routers current. |
| `Sources/OpenLolaCore/Benchmarks/` | Swift directory | Latency, E2E, and performance audit reports and synthetic smokes. | `LatencyBenchmarkReport`, `E2EBenchmarkReport`, `PerformanceAuditReport`, runners/validators. | domain logic | Timing, media, evidence reports. | active | Synthetic benchmark reports are not field proof. |

## App UI

| File path | Language/type | Primary responsibility | Main exports/classes/functions | Runtime role | Direct dependencies worth knowing | Status | Obvious smells |
|---|---|---|---|---|---|---|---|
| `Sources/OpenLolaCore/Platform/` | Swift directory | App shell data contracts, command generation, media inventory, operator state, search/packet monitor models. | `NativeAppShellReport`, `NativeAppShellSurfaceContract`, `NativeAppShellOperatorPrototypeState`, `NativeAppShellExecution`, `NativeAppShellMediaInventory`, `NativeAppShellDirectPeerCommand`. | domain logic | Core reports, CLI command surfaces, app storage state. | active | UI truth depends on these reports; fake state is high risk. |
| `Sources/open-lola-app/AppExecutionController.swift` | SwiftUI support | App-side command execution state and supervisor/report validation. | `AppExecutionController`. | UI | Native app shell execution, process/report surfaces. | active | 699 lines; process state and UI state are tightly coupled. |
| `Sources/open-lola-app/AppShellRootView.swift` | SwiftUI | Main console root layout and navigation. | `AppShellRootView`. | UI | App view models, report-backed state. | active | 632 lines; large view composition likely overcomplicated. |
| `Sources/open-lola-app/AppShellSettingsView.swift` | SwiftUI | Settings surface for app/runtime/transport choices. | `AppShellSettingsView`, `AppSettingsMutationPolicy`. | UI | App settings/defaults, operator state. | active | Settings must map to runtime behavior; audit for dead controls before UI edits. |
| `Sources/open-lola-app/AppLocalOperatorSurfaceView.swift` | SwiftUI | Operator device, network, and command-intent controls. | `AppLocalOperatorSurfaceView`, device/network sections. | UI | Operator state, inventory, app settings. | active | Dense form/state surface; misleading disabled/enabled states possible. |
| `Sources/open-lola-app/AppPacketMonitorView.swift` | SwiftUI | Packet monitor display rows and state. | `AppPacketMonitorView`, `AppPacketMonitorRowsState`. | UI | Operator/report packet state. | active | Must not invent packet rows or counters. |
| `Sources/open-lola-app/` other Swift files | SwiftUI directory | UI components, design system, preview receiver, stored defaults, import helpers, latency/status/device/transport views. | `AppConsole*`, `AppDeviceCard`, `AppSettings`, `AppPreview*`, `AppTransportView`, `AppStorageKeys`. | UI | SwiftUI, AppKit where relevant, core platform contracts. | active | File-level inspection still needed for dead controls and duplicated state logic. |

## CLI Command Surface

| File path | Language/type | Primary responsibility | Main exports/classes/functions | Runtime role | Direct dependencies worth knowing | Status | Obvious smells |
|---|---|---|---|---|---|---|---|
| `Sources/open-lola/Commands/Network/NetworkCommands.swift` | Swift | Main network command handler and routing for many CLI commands. | `handleNetworkCommand`, network command usage printers. | entrypoint | OpenLolaCore network/audio/video reports and parsers. | active | Large switch/if command handler; likely overcomplicated. |
| `Sources/open-lola/Commands/Network/DirectP2PSessionRunCommandSupport.swift` | Swift | Parses and validates direct P2P session run flags. | `parseDirectP2PSessionRunArguments`, `directP2PSessionAVConfiguration`, `directP2PValidateAudioTransportShape`, many helpers. | adapter | Key-value parser, DirectPeerSession config/report types. | active | Many validation branches; compatibility alias risk. |
| `Sources/open-lola/Commands/Network/DirectP2P*Support.swift` | Swift files | Direct P2P measured evidence, mesh, quality policy, two-peer plan/prototype/local-run argument support. | Direct P2P parser/config helpers. | adapter | Direct peer report/run-plan types. | active | Command argument drift risk across helpers. |
| `Sources/open-lola/Commands/Audio/` | Swift directory | MADI receive/full-duplex and latency profile command handlers. | `handleMadiReceiveCommand`, `handleMadiFullDuplexCommand`, `handleLatencyProfileCommand`. | entrypoint | MADI reports/runtime, latency/rx-buffer reports. | active | Synthetic and runtime commands must keep verdict boundaries clear. |
| `Sources/open-lola/Commands/Benchmarks/` | Swift directory | E2E and performance command handlers. | `handleE2EBenchmarkCommand`, `handlePerformanceCommand`. | entrypoint | Benchmark reports/validators. | active | None obvious beyond synthetic-vs-measured gates. |
| `Sources/open-lola/Commands/MilestoneCommands.swift` | Swift | Milestone smoke/run commands. | `handleMilestoneCommand` and many command branches. | entrypoint | Most report families. | active | 610 lines; likely overcomplicated command router. |
| `Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift` | Swift | Validator command router for report schemas. | Validator command handlers. | entrypoint | `ReportValidatorSurface` and report schema types. | active | Validator router must stay in lockstep with schema inventory. |
| `Sources/open-lola/Commands/CLICommandHelpers.swift` | Swift | Shared CLI output/read/write helpers. | JSON/report helper functions. | adapter | Foundation, report contracts. | active | None obvious. |

## Scripts And Verification Helpers

| File path | Language/type | Primary responsibility | Main exports/classes/functions | Runtime role | Direct dependencies worth knowing | Status | Obvious smells |
|---|---|---|---|---|---|---|---|
| `scripts/verify-release-readiness.sh` | Shell | Broad release-readiness matrix and CLI probes. | Shell gate orchestration. | script | docs verifier, shellcheck, ruff, pytest, mypy, Swift build/test, CLI probes. | active | Long orchestration; failures can mix pre-existing and new issues. |
| `scripts/verify-docs.sh` | Shell | Markdown inventory and documentation contract checks. | Shell docs gate. | script | `python3 -m scripts.verify_docs`. | active | Currently repo-wide and sensitive to archived broken links. |
| `scripts/verify-release-hygiene.sh` | Shell | Release artifact boundary and hygiene checks. | Shell hygiene gate. | script | release policy files, find/grep, staged candidate optional. | active | Must not be loosened without release review. |
| `scripts/export-release-candidate.sh` | Shell | Stages a public release candidate and runs hygiene. | Shell export procedure. | script | release hygiene script, allowlisted source/doc paths. | active | Release boundary critical. |
| `scripts/verify_docs/` | Python package | Markdown/archive/windows artifact policy checks. | `main`, `markdown_checks`, `archive_inventory`, windows check modules. | script | pathlib, markdown link parsing, repo docs. | active | Policy checker can encode repo history; audit before broad docs moves. |
| `scripts/lib/*.py` | Python scripts | Extract preflight executable and write machine-readable connection/parity metrics. | `extract-preflight-executable.py`, `write-connection-metrics.py`, `write-ultragrid-parity-metrics.py`. | script | JSON, process logs/metrics. | active | Metrics shape must match shell probes. |
| `scripts/lib/*.sh` | Shell library | Common shell helpers and parity helpers. | sourced functions. | script | Called by connector probe scripts. | active | Shared shell library; shellcheck required after edits. |
| `scripts/open-lola-*`, `scripts/start-local-*`, `scripts/run-local-*`, `scripts/compare-local-*`, `scripts/stress-local-*` | Shell scripts | JackTrip/UltraGrid Docker/native compatibility probes and parity runs. | Shell procedures. | script | Docker, native UltraGrid/JackTrip, `open-lola` CLI, metric writers. | active | Compatibility/probe scripts can be mistaken for production proof. |
| `linux_connector/env/*.sh`, `linux_connector/env/npcap_udp_relay.py`, `linux_connector/env/compose.yaml` | Shell/Python/YAML | WSL/Windows LoLa lab helpers and relay. | probe/setup scripts and relay helper. | script | Windows/WSL networking, Python connector. | active | Host-specific; usage depends on lab environment. |
| `linux_connector/tools/lola_packet_decoder.py` | Python | Packet capture decoding helper. | Decoder CLI/functions not deeply inspected in this pass. | script | Optional scapy extra. | active | UNCLEAR: active use requires packet-capture workflow evidence. |

## Tests

| File path | Language/type | Primary responsibility | Main exports/classes/functions | Runtime role | Direct dependencies worth knowing | Status | Obvious smells |
|---|---|---|---|---|---|---|---|
| `Tests/OpenLolaCoreTests/` | Swift Testing directory | 168 active Swift test files covering contracts, reports, runtime slices, CLI routers, app shell, release gates, and test support fixtures. | Top-level `@Test` functions and `+TestSupport` fixture builders. | test | Swift Testing, Foundation, Darwin/CoreGraphics where needed, OpenLolaCore and contracts. | active | Prior audit found source-text guards and duplicate/low-signal risk; use `docs/testing/test-quality-audit.md` before test cleanup. |
| `Tests/OpenLolaCoreTests/CodeLineBudgetTests.swift` | Swift Testing | Enforces source size budget and exceptions. | Code-line budget tests. | test | Filesystem source scan. | active | Can become a policy gate rather than behavior coverage; keep threshold explicit. |
| `Tests/OpenLolaCoreTests/*+TestSupport.swift` | Swift Testing support | Shared fixtures, socket port helpers, measured report builders, and socket-heavy test gates. | Helper functions/builders. | test | Test-only support and report types. | active | Shared test support can hide fixture duplication. |
| `linux_connector/tests/test_codec.py` | pytest | Python control/media codec, raw frame, self-test, connector socket behavior. | pytest functions for parser/codec/runtime behavior. | test | pytest, socket, Linux connector package. | active | Large file; multiple concern clusters. |
| `linux_connector/tests/test_process_runtime.py` | pytest | Python process backend, CLI validation, subprocess cleanup, UDP runtime self-tests. | pytest functions for process/runtime behavior. | test | pytest, asyncio, process backends, env relay. | active | Large file; process lifecycle failure paths are high risk. |
| `linux_connector/tests/test_runtime_contracts.py` | pytest | Runtime start/stop/error contracts and logging behavior. | pytest functions for runtime contracts. | test | pytest, connector/runtime/backends. | active | State-machine coverage should stay behavior-first. |

## Vendored And Third-Party Source

| File path | Language/type | Primary responsibility | Main exports/classes/functions | Runtime role | Direct dependencies worth knowing | Status | Obvious smells |
|---|---|---|---|---|---|---|---|
| `Sources/opus-1.5.2/openlola_bridge/COpusBridge.c` and `openlola_bridge/include/*` | C bridge | Local bridge between Swift codec wrapper and vendored Opus. | C bridge functions exposed to `COpus`. | adapter | Vendored Opus C implementation. | active | Bridge must match Swift lifetime/error expectations. |
| `Sources/opus-1.5.2/` | C/C/Python/shell vendored tree | Vendored Opus 1.5.2 source drop. `Package.swift` compiles an explicit subset into `COpus`. | Opus encoder/decoder/multistream/repacketizer and supporting CELT/SILK files listed in manifest. | adapter | COpus target. | partially active | Most upstream files are not compiled by SwiftPM; treat as vendored, not cleanup fodder. |
| `Sources/xs_ref_sw_ed2/libjxs/public/open_lola_jxs_bridge.h` and `libjxs/src/open_lola_jxs_bridge.c` | C bridge | Local bridge into JPEG XS reference code. | Open LoLa JPEG XS bridge functions. | adapter | `CJpegXSReference`, Swift `JPEGXSReferenceCodec`. | active | Bridge/toolchain availability must be verified before codec changes. |
| `Sources/xs_ref_sw_ed2/libjxs/` | C vendored/reference code | JPEG XS reference library target used by SwiftPM `CJpegXSReference`. | `libjxs` public headers and implementation files. | adapter | C target, Swift video codec wrapper. | active | Reference code; do not broadly refactor. |
| `Sources/xs_ref_sw_ed2/programs/`, `extras/`, `std/` | C/shell vendored utilities | Upstream command-line tools and helpers outside SwiftPM target path. | Encoder/decoder program helpers. | unknown | Upstream JPEG XS tree; not referenced by `Package.swift` target path. | unclear | UNCLEAR: likely inactive in SwiftPM; prove with build manifest or external tooling workflow before deletion. |

## File Areas Needing Deeper Inspection

These files/areas are represented above but not semantically inspected file by
file in this pass:

- Every individual Swift file under `Sources/OpenLolaCore/Network/P2P/` beyond
  the high-risk runner/report files called out above.
- Every individual Swift file under `Sources/OpenLolaCore/Connectors/LoLa/`.
- Every individual SwiftUI component under `Sources/open-lola-app/`.
- The full 168-file Swift test suite under `Tests/OpenLolaCoreTests/`.
- Vendored Opus files not compiled by `Package.swift`.
- JPEG XS upstream `programs/`, `extras/`, and `std/` helpers.
- `.github/workflows/release-readiness.yml` job-level behavior.

What would prove usage for unclear files:

- A `Package.swift` target/source entry.
- A direct import/call from owned Swift/Python/shell code.
- A documented command in active `README.md`, `docs/testing/README.md`, or
  `scripts/README.md`.
- A passing test or CI job that executes the file.
- A release candidate manifest that intentionally includes it.

## Highest-Risk Files

1. `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift` and
   `DirectPeerRealtimeAudioGraphCallbacks.swift`: realtime Core Audio graph and
   IOProc callback behavior.
2. `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVSocketRunner.swift`:
   socket-backed AV runtime orchestration.
3. `Sources/OpenLolaCore/Network/P2P/PeerSessionRunner.swift`: direct P2P
   audio/control runtime orchestration.
4. `Sources/OpenLolaCore/Network/UDP/UdpMediaTransport.swift`,
   `UdpPcmV2Packet.swift`, and `UdpPcmSocketOperations.swift`: packet/socket
   contracts.
5. `Sources/OpenLolaCore/Connectors/LoLa/LoLaControlExchangeRuntime.swift`,
   `LoLaCompatibilityUdpMedia.swift`, and live CoreAudio/AVFoundation bridge
   files: compatibility state and media behavior.
6. `Sources/open-lola-app/AppExecutionController.swift`: app-runner state and
   report validation UI path.
7. `scripts/verify-release-readiness.sh` and
   `scripts/verify-release-hygiene.sh`: release gate truthfulness.

## Likely Dead Files

No owned active source file is proven dead by this pass.

Likely inactive or non-SwiftPM-compiled areas:

- `Sources/opus-1.5.2/` files not listed in the explicit `COpus` source list in
  `Package.swift`. These are vendored upstream files, not deletion candidates
  without a third-party-source policy decision.
- `Sources/xs_ref_sw_ed2/programs/`, `Sources/xs_ref_sw_ed2/extras/`, and
  `Sources/xs_ref_sw_ed2/std/`. They appear outside the SwiftPM
  `CJpegXSReference` target path; prove with external tooling/docs before
  pruning.

## Likely Overcomplicated Files

1. `Sources/open-lola/Commands/Network/NetworkCommands.swift`: broad command
   routing surface.
2. `Sources/open-lola/Commands/MilestoneCommands.swift`: broad milestone command
   router.
3. `Sources/open-lola/Commands/Network/DirectP2PSessionRunCommandSupport.swift`:
   many flag parsing and compatibility branches.
4. `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVSocketRunner.swift`:
   runtime orchestration plus metrics/report responsibilities.
5. `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionReport.swift`: large
   public report and validation surface.
6. `Sources/open-lola-app/AppExecutionController.swift`,
   `AppShellRootView.swift`, and `AppShellSettingsView.swift`: large UI/state
   files with runtime-facing behavior.
7. `linux_connector/lola_connector/backends.py`: many backend variants and
   process lifecycle paths in one file.

## Likely Deprecated Compatibility Paths

- JackTrip and UltraGrid Docker/native helpers under `scripts/` and
  `Sources/OpenLolaCore/Connectors/JackTrip`, `UltraGrid`, and `NMP`: active as
  compatibility/process probes, but not native product defaults.
- NAT relay/rendezvous runners under `Sources/OpenLolaCore/Network/NAT/`:
  compatibility/fallback path; direct raw P2P remains the preferred proof.
- `--audio-compression` alias in Direct P2P command support: compatibility
  alias for newer transport selection semantics; inspect before removal.
- Linux connector compatibility behavior: active seed, but must stay separate
  from Mac-native runtime paths unless explicitly scoped.

## Recommended Next Audit Targets

1. Realtime audio audit: `Audio/Realtime`, `Audio/Routing`, and direct peer
   audio handoff tests.
2. Direct AV runtime audit: `Network/P2P/DirectPeerSessionAV*`, video transport,
   and associated CLI argument support.
3. LoLa compatibility audit: Swift `Connectors/LoLa` versus
   `linux_connector/docs/protocol-reference.md` and Python seed behavior.
4. App truthfulness audit: `Sources/open-lola-app/` plus `Platform/` contracts
   for fake or stale UI state.
5. Command router simplification audit: `Sources/open-lola/Commands/`.
6. Test quality audit continuation: use `docs/testing/test-quality-audit.md`
   before deleting or rewriting tests.
7. Vendored-source policy audit: separate compiled bridge files from upstream
   retained source drops.

## Coverage Gaps And Uncertainty

- This is not a full file-by-file semantic read of all 1,271 measured files.
- The 168 Swift test files were indexed by suite and representative high-risk
  files, not individually classified.
- Vendored Opus and JPEG XS upstream files were classified by target inclusion
  and directory role, not line-read.
- Usage for files marked UNCLEAR must be proven by manifest, call graph, active
  docs, tests, CI, or release-candidate evidence before cleanup.
- The worktree had unrelated modifications before this pass; this document
  describes the live filesystem as inspected and does not assert committed
  repository history.

VERDICT: PARTIAL
