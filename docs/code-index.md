# Open LoLa Source Code Index

_Generated: 2026-05-19_

## Purpose
This document inventories the repository's source-bearing files before cleanup or refactor work. It focuses on what each target and directory contains, which files appear to define primary contracts, runtime entrypoints, adapters, reports, or UI surfaces, and where usage/status is still uncertain without deeper call-site tracing.

## Repository Structure Overview

| Area | What lives here | Notes |
| --- | --- | --- |
| `Sources/OpenLolaContracts/` | Shared verdict, methodology, JSON coding, buffer-profile contracts | Small public-schema target |
| `Sources/OpenLolaCore/` | Main runtime, protocol, reporting, media, integration, release, UI support back-end | Largest and highest-risk target |
| `Sources/open-lola/` | CLI entrypoint and command routing | Thin executable over `OpenLolaCore` |
| `Sources/open-lola-app/` | SwiftUI app support target | Views, controllers, stored defaults, preview services |
| `Sources/open-lola-app-main/` | App executable `@main` wrapper | Tiny launcher target |
| `Sources/COpenLolaAtomics/` | C11 atomics bridge | Used by ring buffers / realtime paths |
| `Sources/xs_ref_sw_ed2/libjxs/` | Vendored JPEG-XS reference codec | Treat as vendor boundary |
| `Sources/opus-1.5.2/` | Vendored Opus 1.5.2 + bridge | Treat as vendor boundary |
| `linux_connector/` | Python LoLa compatibility seed + tests/tools | Separate from SwiftPM |
| `scripts/`, `script/` | Verification, parity, release, bundle assembly helpers | Mixed active and compatibility lanes |
| `Tests/OpenLolaCoreTests/` | Swift Testing suite | Broad contract-heavy coverage |

## Target: COpenLolaAtomics

| File | Language/type | Responsibility / main exports | Runtime role | Dependencies | Status | Smells |
| --- | --- | --- | --- | --- | --- | --- |
| `Sources/COpenLolaAtomics/OpenLolaAtomics.c` | C / bridge | C11 wrappers around `uint64_t` atomics; backs Swift ring-buffer code. Main exports match header API. | adapter | C11 atomics | active | Thin ABI layer whose correctness depends on memory-order assumptions |
| `Sources/COpenLolaAtomics/include/OpenLolaAtomics.h` | C header / public API | Declares `OpenLolaAtomicUInt64`, `init/load/store/fetch_add/compare_exchange`. | adapter | C11 atomics | active | Low-level contract surface |

## Target: OpenLolaContracts

| File | Language/type | Responsibility / main exports | Runtime role | Dependencies | Status | Smells |
| --- | --- | --- | --- | --- | --- | --- |
| `Sources/OpenLolaContracts/MeasurementMethodology.swift` | Swift / enum contract | Shared provenance enum: `MeasurementMethodology`. | domain logic | none | active | none |
| `Sources/OpenLolaContracts/MeasurementVerdict.swift` | Swift / enum contract | Shared verdict enum: `MeasurementVerdict` (`pass`, `fail`, `partial`). | domain logic | none | active | none |
| `Sources/OpenLolaContracts/PrettyJSONCodable.swift` | Swift / utility contract | `JSONReportCoder`, `PrettyJSONCodable` for stable report encode/decode. | adapter | `Foundation` | active | Small generic utility, but public surface |
| `Sources/OpenLolaContracts/RxBufferProfile.swift` | Swift / enum contract | Shared RX buffering profile enum: `RxBufferProfile`. | domain logic | none | active | none |

## Target: OpenLolaCore

### Audio/Codecs

| File | Language/type | Responsibility / main exports | Runtime role | Dependencies | Status | Smells |
| --- | --- | --- | --- | --- | --- | --- |
| `Sources/OpenLolaCore/Audio/Codecs/OpusCELTLowDelayCodec.swift` | Swift / codec wrapper | `OpusCELTLowDelayConstants`, validation, encoder/decoder types for low-delay Opus/CELT. | adapter | `COpus`, `Foundation` | active | C-pointer lifecycle, fixed-size assumptions, codec boundary risk |

### Audio/CoreAudio

| File | Language/type | Responsibility / main exports | Runtime role | Dependencies | Status | Smells |
| --- | --- | --- | --- | --- | --- | --- |
| `Sources/OpenLolaCore/Audio/CoreAudio/AudioStreamDescription.swift` | Swift / stream contract | Defines `MediaStreamDirection`, `SessionPayloadType`, `AudioStreamDescription`. | domain logic | shared session/media types | active | `SessionPayloadType` spans more than pure audio |
| `Sources/OpenLolaCore/Audio/CoreAudio/CoreAudioInventory.swift` | Swift / inventory model | `CoreAudioDeviceInventory`, layout and buffer-frame snapshot structs. | report | `CoreAudio`, `Foundation` | active | Broad diagnostic payload |
| `Sources/OpenLolaCore/Audio/CoreAudio/CoreAudioInventoryReader.swift` | Swift / hardware probe | Enumerates CoreAudio devices and properties via `CoreAudioInventoryReader.capture()`. | adapter | `CoreAudio`, `Foundation` | active | Hardware-dependent probing, many property helpers |

### Audio/MADI

| File | Language/type | Responsibility / main exports | Runtime role | Dependencies | Status | Smells |
| --- | --- | --- | --- | --- | --- | --- |
| `Sources/OpenLolaCore/Audio/MADI/MadiChannelCounts.swift` | Swift / constants | Channel-count constants used by MADI flows. | config | none | unclear | Very small constants file |
| `Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexReport.swift` | Swift / report | `MadiFullDuplexReport`, mix-evidence types, synthetic smoke output. | report | `Foundation` | active | Report file also contains smoke logic |
| `Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexRuntime.swift` | Swift / runtime orchestration | `MadiFullDuplexMetrics`, `MadiFullDuplexSessionConfiguration`, session runtime. | runtime | `Foundation`, `OpenLolaContracts` | active | Large orchestration file, timing/correction complexity |
| `Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexSocketRunner.swift` | Swift / socket runner | `MadiFullDuplexSocketRunner` for duplex network execution. | runtime | `Darwin`, `Dispatch`, `Foundation` | active | Socket-heavy realtime path |
| `Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexTypes.swift` | Swift / type hub | Run mode, correction actions, errors, audio-pair contracts. | domain logic | `Foundation`, `OpenLolaContracts` | active | Large validation surface |
| `Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexValidation.swift` | Swift / validation helpers | `requireM05*` validation helpers for MADI report/runtime inputs. | adapter | `Foundation` | active | Repeated helper pattern |
| `Sources/OpenLolaCore/Audio/MADI/MadiReceive.swift` | Swift / receive engine | `MadiReceiveEngine` receive-side execution path. | runtime | `Foundation` | active | Receive path complexity not fully traced |
| `Sources/OpenLolaCore/Audio/MADI/MadiReceiveBuffers.swift` | Swift / buffer store | Deadline-slot and ready-block storage for receive playout. | domain logic | `Foundation` | active | Buffer-state complexity |
| `Sources/OpenLolaCore/Audio/MADI/MadiReceiveReport.swift` | Swift / report | Synthetic receive measurement/report types. | report | `Dispatch`, `Foundation` | active | Report + smoke coupling |
| `Sources/OpenLolaCore/Audio/MADI/MadiReceiveTypes.swift` | Swift / receive schema | Errors, overrun policy, configuration, playout/recovery block types. | domain logic | `Foundation` | active | Many closely related state structs |
| `Sources/OpenLolaCore/Audio/MADI/MadiTransmit.swift` | Swift / transmit measurement | Packetization measurement, synthetic report, validation, smoke. | runtime | `Dispatch`, `Foundation` | active | Mixes measurement, validation, and transport setup |
| `Sources/OpenLolaCore/Audio/MADI/RmeFastestAudioPath.swift` | Swift / evidence report | Driver-mode and fastest-path evidence for RME hardware. | report | `Foundation` | unclear | May be compatibility/perf ledger rather than live runtime |
| `Sources/OpenLolaCore/Audio/MADI/RmeMatrixMetadata.swift` | Swift / metadata model | Matrix-route metadata and validation snapshot types. | domain logic | `Foundation` | unclear | Specialized hardware metadata |
| `Sources/OpenLolaCore/Audio/MADI/SyntheticAudioPayload.swift` | Swift / synthetic helper | Generates synthetic audio payloads for tests/smokes. | adapter | `Foundation` | active | none |

### Audio/Realtime

| File | Language/type | Responsibility / main exports | Runtime role | Dependencies | Status | Smells |
| --- | --- | --- | --- | --- | --- | --- |
| `Sources/OpenLolaCore/Audio/Realtime/DirectPeerAudioPayloadRing.swift` | Swift / ring buffer | `DirectPeerAudioPayloadRing` single-purpose payload ring for direct-peer audio. | domain logic | `COpenLolaAtomics`, `Foundation` | active | `@unchecked Sendable`-style risk around concurrency boundaries |
| `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift` | Swift / CoreAudio graph | Main direct-peer realtime audio graph implementation. | runtime | `CoreAudio`, `COpenLolaAtomics`, `Darwin`, `Foundation` | active | Callback-driven realtime complexity |
| `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraphCallbacks.swift` | Swift / callback layer | IOProc callbacks, channel-map validation, audio-buffer pointer helpers. | adapter | `CoreAudio`, `Foundation` | active | Highest-risk callback file in audio scope |
| `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraphRxBuffering.swift` | Swift / buffering helper | RX buffering support for direct-peer realtime graph. | adapter | `Foundation` | active | Body not fully reviewed |
| `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraphTypes.swift` | Swift / type hub | Graph errors, cleanup results, preflight, configuration types. | domain logic | `CoreAudio`, `Foundation` | active | Contract-heavy support file |
| `Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioBuffers.swift` | Swift / buffering algorithms | Block rings, payload shapes, jitter-buffer primitives. | domain logic | `Foundation` | active | Algorithmic and stateful |
| `Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngine.swift` | Swift / engine contract | Run mode, hardware path, engine config, report-related engine types. | runtime | `Foundation` | active | Large central engine surface |
| `Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngineHelpers.swift` | Swift / validation helpers | `requireRealtime*`, hardware-path checks, placeholder helpers. | adapter | `Foundation` | active | Repeated helper pattern |
| `Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngineReportValidation.swift` | Swift / validation | Report validator extensions for realtime engine output. | adapter | `Foundation` | active | thin validator file |
| `Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngineSyntheticSmoke.swift` | Swift / smoke | Synthetic smoke for realtime engine contract. | test | `Foundation` | active | none |
| `Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPacketHandoff.swift` | Swift / handoff boundary | Packet receive result, handoff error, handoff protocol/type. | adapter | `CoreAudio`, `Darwin`, `Foundation` | active | Boundary between callback and network layers |
| `Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPayloadCaptureRing.swift` | Swift / capture ring | Capture-copy policy, captured payload, buffer-list reader, payload ring. | adapter | `CoreAudio`, `Darwin`, `Foundation` | active | Realtime memory-copy sensitivity |

### Audio/Routing

| File | Language/type | Responsibility / main exports | Runtime role | Dependencies | Status | Smells |
| --- | --- | --- | --- | --- | --- | --- |
| `Sources/OpenLolaCore/Audio/Routing/AudioBaselineEvidence.swift` | Swift / evidence helper | Sample-rate conversion and baseline path checks. | report | `Foundation` | unclear | Could be compatibility/evidence-only lane |
| `Sources/OpenLolaCore/Audio/Routing/AudioLoopbackHelpers.swift` | Swift / helper set | Report builders, parsing helpers, CoreAudio helper routines. | adapter | `CoreAudio`, `Darwin`, `Foundation` | active | Dense helper file |
| `Sources/OpenLolaCore/Audio/Routing/AudioLoopbackRun.swift` | Swift / runner | Loopback runner state, preflight, report-generation path. | runtime | `COpenLolaAtomics`, `CoreAudio`, `Darwin`, `Foundation` | active | High-risk realtime/hardware path |
| `Sources/OpenLolaCore/Audio/Routing/AudioLoopbackRunConfiguration.swift` | Swift / config | `AudioLoopbackRunConfiguration` model. | config | `Foundation` | active | none |
| `Sources/OpenLolaCore/Audio/Routing/AudioRoutingAssumptionLedger.swift` | Swift / ledger | Classification/status ledger for routing assumptions. | report | `Foundation` | active | Policy-heavy evidence file |
| `Sources/OpenLolaCore/Audio/Routing/DirectAudioMediaRouter.swift` | Swift / router | Direct audio media routing engine and audio-mode selector. | runtime | `Foundation` | active | Stateful routing logic |
| `Sources/OpenLolaCore/Audio/Routing/ReceiverMixSnapshot.swift` | Swift / snapshot model | Receiver-mix route, snapshot, prepared-route types. | domain logic | `Foundation` | active | none |

### Benchmarks/E2E

| File | Language/type | Responsibility / main exports | Runtime role | Dependencies | Status | Smells |
| --- | --- | --- | --- | --- | --- | --- |
| `Sources/OpenLolaCore/Benchmarks/E2E/E2EBenchmarkReport.swift` | Swift / aggregate report | End-to-end benchmark profile, impairment, peer/hardware identity, component metrics. | report | `Foundation` | active | Very large schema file |
| `Sources/OpenLolaCore/Benchmarks/E2E/E2EBenchmarkReportValidation.swift` | Swift / validation | Validation extension for E2E benchmark reports. | adapter | `Foundation` | active | thin validator file |
| `Sources/OpenLolaCore/Benchmarks/E2E/E2EBenchmarkRunner.swift` | Swift / runner | Run configuration, runner, aggregate benchmark execution. | runtime | `Foundation` | active | Cross-subsystem orchestration |
| `Sources/OpenLolaCore/Benchmarks/E2E/E2EBenchmarkSyntheticSmoke.swift` | Swift / smoke | Synthetic smoke path for E2E benchmark contract. | test | `Foundation` | active | none |

### Benchmarks/Latency

| File | Language/type | Responsibility / main exports | Runtime role | Dependencies | Status | Smells |
| --- | --- | --- | --- | --- | --- | --- |
| `Sources/OpenLolaCore/Benchmarks/Latency/LatencyBenchmark.swift` | Swift / benchmark engine | Sampling config, sample summary, latency benchmark runtime helpers. | runtime | `Darwin`, `Glibc`, `Foundation`, `os` | active | Cross-platform imports in macOS package are notable |
| `Sources/OpenLolaCore/Benchmarks/Latency/LatencyBenchmarkReport.swift` | Swift / report | `LatencyBenchmarkReport` aggregate artifact. | report | `Foundation` | active | Schema body not fully reviewed |
| `Sources/OpenLolaCore/Benchmarks/Latency/LatencyBenchmarkSyntheticSmoke.swift` | Swift / smoke | Synthetic latency benchmark smoke. | test | `Foundation` | active | none |
| `Sources/OpenLolaCore/Benchmarks/Latency/LatencyBenchmarkTypes.swift` | Swift / type hub | Run mode, evidence kind, category, media modes, validation errors. | domain logic | `Foundation` | active | Very broad type/validation surface |

### Benchmarks/Performance

| File | Language/type | Responsibility / main exports | Runtime role | Dependencies | Status | Smells |
| --- | --- | --- | --- | --- | --- | --- |
| `Sources/OpenLolaCore/Benchmarks/Performance/PerformanceAuditReport.swift` | Swift / report | Performance counter summaries and audit report schema. | report | `Foundation` | active | Large schema with many policy enums |
| `Sources/OpenLolaCore/Benchmarks/Performance/PerformanceAuditReportValidation.swift` | Swift / validation | `PerformanceAuditValidator`. | adapter | `Foundation` | active | none |
| `Sources/OpenLolaCore/Benchmarks/Performance/PerformanceAuditSyntheticSmoke.swift` | Swift / smoke | Synthetic performance-audit smoke path. | test | `Foundation` | active | none |

### Connectors/Core

| File | Language/type | Responsibility / main exports | Runtime role | Dependencies | Status | Smells |
| --- | --- | --- | --- | --- | --- | --- |
| `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorExecutablePreflight.swift` | Swift / preflight | Executable identity, probe, preflight report, runner. | adapter | `Foundation` | active | Install/runtime readiness mixed together |
| `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorParsingDefaults.swift` | Swift / parsing defaults | `parse*`, `required*`, `validate*`, and connector-specific defaults. | adapter | `Foundation` | active | Overgrown utility file with cross-connector coupling |
| `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorProcessRunner.swift` | Swift / subprocess runner | Process run config, running-process state, start/wait/cleanup helpers. | adapter | `Darwin`, `Foundation` | active | Process-group management complexity |
| `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorReport.swift` | Swift / report contract | Connector kind, handshake kind, evidence class, media provider/sink reports. | report | `Foundation` | active | Large shared report surface |
| `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSession.swift` | Swift / session model | Core session config, launch plan, process result, report types. | domain logic | `Darwin`, `Foundation` | active | Dense model hub |
| `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSessionModels.swift` | Swift / enum bundle | Shared session-role, media-mode, transport, encryption/FEC enums. | domain logic | `Foundation` | active | Cross-connector enum coupling |
| `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSessionRunner.swift` | Swift / runner | High-level `ExternalConnectorSessionRunner`. | runtime | `Foundation` | active | Thin wrapper over many subsystems |
| `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSessionRuntime.swift` | Swift / runtime process control | `runExternalProcess*`, invocation/running state, real process runner. | runtime | `Darwin`, `Foundation` | active | Low-level process lifecycle and cleanup risk |
| `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSessionValidation.swift` | Swift / validation | `validateExternalConnectorRuntimeInputs`. | adapter | none | active | thin validation file |

### Connectors/JackTrip

| File | Language/type | Responsibility / main exports | Runtime role | Dependencies | Status | Smells |
| --- | --- | --- | --- | --- | --- | --- |
| `Sources/OpenLolaCore/Connectors/JackTrip/JackTripAdvancedModes.swift` | Swift / advanced-mode codec | `JackTripAdvancedModeCodec`, WebRTC signaling support. | adapter | `Foundation` | unclear | Advanced/experimental surface |
| `Sources/OpenLolaCore/Connectors/JackTrip/JackTripAudioPayloadCodec.swift` | Swift / codec | `JackTripAudioPayloadCodec`. | adapter | `Foundation` | active | none |
| `Sources/OpenLolaCore/Connectors/JackTrip/JackTripAuxiliaryVideoPlan.swift` | Swift / plan helper | `jackTripAuxiliaryProcesses` auxiliary process builder. | adapter | none | unclear | Compatibility-support path |
| `Sources/OpenLolaCore/Connectors/JackTrip/JackTripCompatibility.swift` | Swift / compatibility runtime | Datagram/media report types and runtime/media bridge. | runtime | `Darwin`, `Foundation` | unclear | Large compatibility façade |
| `Sources/OpenLolaCore/Connectors/JackTrip/JackTripLaunchPlan.swift` | Swift / plan builder | `buildJackTripPlan`. | adapter | `Foundation` | active | none |
| `Sources/OpenLolaCore/Connectors/JackTrip/JackTripPassValidation.swift` | Swift / validation | Pass/setup validation for JackTrip path. | adapter | `Foundation` | unclear | Body not fully inspected |
| `Sources/OpenLolaCore/Connectors/JackTrip/JackTripProtocolModel.swift` | Swift / wire model | Sample rate, bit depth, headers, packet, transport/plugin/payload enums. | domain logic | `Foundation` | active | Many enums/types in one file |
| `Sources/OpenLolaCore/Connectors/JackTrip/JackTripReceiveAnalysis.swift` | Swift / analysis helper | Receive-side analysis support. | adapter | none | unclear | Body not reviewed |
| `Sources/OpenLolaCore/Connectors/JackTrip/JackTripRunConfiguration.swift` | Swift / config | `JackTripRunConfiguration`. | config | `Foundation` | active | none |
| `Sources/OpenLolaCore/Connectors/JackTrip/JackTripTCPHandshake.swift` | Swift / handshake codec | TCP handshake state/report/codec types. | runtime | `Foundation` | active | Connection setup complexity |
| `Sources/OpenLolaCore/Connectors/JackTrip/JackTripTCPHandshakeReportBuilder.swift` | Swift / report builder | Derived handshake-report assembly. | adapter | `Foundation` | active | Builder split from core types |
| `Sources/OpenLolaCore/Connectors/JackTrip/JackTripTopology.swift` | Swift / topology contract | Topology mode, role, state, patch mode, report, parsers. | domain logic | `Foundation` | active | none |
| `Sources/OpenLolaCore/Connectors/JackTrip/JackTripTopologyReportBuilder.swift` | Swift / report builder | Derived topology-report assembly. | adapter | none | active | Builder layering |

### Connectors/LoLa

| File | Language/type | Responsibility / main exports | Runtime role | Dependencies | Status | Smells |
| --- | --- | --- | --- | --- | --- | --- |
| `Sources/OpenLolaCore/Connectors/LoLa/LoLaAVFoundationLiveRaw8Source.swift` | Swift / capture source | `LoLaLiveRaw8VideoSource`, AVFoundation live raw-8 video source. | adapter | `Dispatch`, `Foundation`, `CoreMedia`, `CoreVideo` | active | Framework-heavy live capture path |
| `Sources/OpenLolaCore/Connectors/LoLa/LoLaAVFoundationPayloadCollectors.swift` | Swift / capture helpers | MJPEG/JPEG-XS payload collectors for AVFoundation frames. | adapter | `Foundation`, `Dispatch`, `CoreGraphics`, `CoreImage`, `CoreVideo` | active | Format-collection complexity |
| `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityCaptureReport.swift` | Swift / report decoder | Capture-report decoding helpers. | report | `Foundation` | unclear | Compatibility/report-only lane |
| `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityCaptureReportTypes.swift` | Swift / report types | Capture format, stream, packet summary, validation error. | report | `Foundation` | unclear | Compatibility schema surface |
| `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityControlMessage.swift` | Swift / control schema | `LoLaCompatibilityControlMessage`. | domain logic | none | unclear | Compatibility path |
| `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityControlSocket.swift` | Swift / socket helpers | Bind helpers and UDP bind errno support for LoLa transmit control. | adapter | `Darwin` | unclear | Compatibility transport shim |
| `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityMediaCodec.swift` | Swift / media codec | Media packet kind, fragment/prelude/body, codec encode/decode types. | adapter | `Foundation` | active | Central compatibility codec surface |
| `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityMediaEnvelopeValidation.swift` | Swift / validation | Envelope validation for compatibility packets. | adapter | `Foundation` | active | none |
| `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityMediaModel.swift` | Swift / model | `LoLaCompatibilityMediaModel`. | domain logic | none | unclear | Thin compatibility contract |
| `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityMediaSession.swift` | Swift / session report/model | Stream/session/frame/report types for compatibility media sessions. | domain logic | `Foundation` | active | Large compatibility contract surface |
| `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityMediaSessionReportFactory.swift` | Swift / report builder | `makeLoLaMediaSessionReport`. | adapter | `Foundation`, `OpenLolaContracts` | active | Builder split |
| `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityPacketFixture.swift` | Swift / fixture runner | Fixture run configuration and packet-fixture report. | test | `Foundation` | active | Fixture-specific runtime support |
| `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityRawLink.swift` | Swift / raw-link transport | Raw-link transmit/receive abstractions, memory/BPF variants, run config. | runtime | `Darwin`, `Foundation` | unclear | Specialized compatibility/runtime boundary |
| `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityUdpMedia.swift` | Swift / UDP media layer | Datagram, transmitter/receiver, memory variants, run config. | runtime | `Foundation` | active | Compatibility shim cluster |
| `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityUdpMediaHelpers.swift` | Swift / helper set | Datagram builders/parsers and CLI argument parsing for LoLa UDP media. | adapter | `Foundation` | active | Dense transport helper file |
| `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityUdpMediaLive.swift` | Swift / live UDP bridge | Live-socket transmitter and bidirectional live-media helpers. | runtime | `Foundation` | active | Live shim path |
| `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityUdpMediaSocket.swift` | Swift / socket bridge | Socket receiver and socket factory for LoLa UDP media. | adapter | `Darwin`, `Foundation` | active | Socket-edge complexity |
| `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityWireFrame.swift` | Swift / wire-frame codec | Ethernet/IPv4 types, wire-frame error, frame codec. | adapter | `Foundation` | active | Byte-level compatibility boundary |
| `Sources/OpenLolaCore/Connectors/LoLa/LoLaConnectorLaunchPlan.swift` | Swift / plan builder | `buildLoLaPlan`. | adapter | none | active | none |
| `Sources/OpenLolaCore/Connectors/LoLa/LoLaConnectorRawLinkMediaEvidence.swift` | Swift / evidence type | Raw-link media evidence contract. | report | none | unclear | Evidence-only file |
| `Sources/OpenLolaCore/Connectors/LoLa/LoLaControlExchangeOutgoing.swift` | Swift / control sender | Parsed/received control message helpers and outgoing attempt sender. | adapter | `Darwin` | active | Handshake serialization complexity |
| `Sources/OpenLolaCore/Connectors/LoLa/LoLaControlExchangeRuntime.swift` | Swift / control runtime | Control retry report, exchange attempt runtime. | runtime | `Darwin`, `Dispatch`, `Foundation` | active | Control state/retry complexity |
| `Sources/OpenLolaCore/Connectors/LoLa/LoLaControlHandshakeValidation.swift` | Swift / validation | Expected field sets and handshake failure builders. | adapter | `Darwin` | active | Protocol-specific helper clutter |
| `Sources/OpenLolaCore/Connectors/LoLa/LoLaControlNetworkPreflight.swift` | Swift / network preflight | Control-network preflight notes and IPv4 sockaddr checks. | adapter | `Darwin` | active | Low-level network helper |
| `Sources/OpenLolaCore/Connectors/LoLa/LoLaCoreAudioLiveBridge.swift` | Swift / audio bridge | CoreAudio live snapshot and bridge implementation. | adapter | `CoreAudio`, `Foundation` | active | Hardware bridge complexity |
| `Sources/OpenLolaCore/Connectors/LoLa/LoLaSocketUdpMediaTransmitter.swift` | Swift / UDP transmitter | Socket media transmitter and send/retry helpers. | runtime | `Darwin`, `Dispatch`, `Foundation` | active | Timing/retry sensitivity |
| `Sources/OpenLolaCore/Connectors/LoLa/LoLaTcpControlExchangeRuntime.swift` | Swift / TCP control runtime | `runLoLaTcpControlExchangeAttempt`. | runtime | `Darwin` | unclear | Alternate/legacy transport path |
| `Sources/OpenLolaCore/Connectors/LoLa/LoLaVideoPayloadProvider.swift` | Swift / video provider | `LoLaVideoPayloadProvider` and payload errors for image/video extraction. | adapter | `Foundation`, `Dispatch`, `CoreGraphics`, `CoreImage`, `CoreVideo`, `ImageIO`, `UniformTypeIdentifiers` | active | Framework-heavy media formatting path |

### Connectors/NMP

| File | Language/type | Responsibility / main exports | Runtime role | Dependencies | Status | Smells |
| --- | --- | --- | --- | --- | --- | --- |
| `Sources/OpenLolaCore/Connectors/NMP/ExternalConnectorConnectionPlan.swift` | Swift / plan contract | Endpoint/side/direction enums, plan config, report, runner. | domain logic | `Foundation` | active | none |
| `Sources/OpenLolaCore/Connectors/NMP/ExternalConnectorNmpEndpointRun.swift` | Swift / runner | Endpoint-run config, result, report, runner. | runtime | `Foundation` | active | none |
| `Sources/OpenLolaCore/Connectors/NMP/ExternalConnectorNmpPlan.swift` | Swift / plan contract | NMP plan config, report, runner. | domain logic | `Foundation` | active | none |
| `Sources/OpenLolaCore/Connectors/NMP/ExternalConnectorNmpPreflight.swift` | Swift / preflight | NMP preflight config, result, report, runner. | adapter | `Foundation` | active | none |
| `Sources/OpenLolaCore/Connectors/NMP/ExternalConnectorNmpWorkflow.swift` | Swift / workflow | NMP workflow config, report, runner. | runtime | `Foundation` | active | Report-heavy layering |

### Connectors/UltraGrid

| File | Language/type | Responsibility / main exports | Runtime role | Dependencies | Status | Smells |
| --- | --- | --- | --- | --- | --- | --- |
| `Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridAudioPayloadCodec.swift` | Swift / codec | `UltraGridAudioPayloadHeader`, `UltraGridAudioPayload`. | adapter | `Foundation` | active | none |
| `Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridCompatibility.swift` | Swift / compatibility façade | Compatibility error/datagram/topology/media report/runtime types. | runtime | `Darwin`, `Foundation` | unclear | Large compatibility surface |
| `Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridCompatibilityRunner.swift` | Swift / runner | Entry runner for compatibility workflow. | runtime | `Foundation` | active | none |
| `Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridControl.swift` | Swift / control codec | Control commands/state/report and codec. | adapter | `Foundation` | active | Control codec + report builder combined |
| `Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridEncryption.swift` | Swift / crypto helper | Encryption config, cipher mode, crypto payload header, OpenSSL wrapper. | adapter | `CryptoKit`, `Foundation`, `Security` | active | Security-sensitive codepath |
| `Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridFEC.swift` | Swift / FEC | FEC headers/payloads and recovery logic. | adapter | `Foundation` | active | Recovery-algorithm complexity |
| `Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridLaunchPlan.swift` | Swift / plan builder | UltraGrid defaults and `buildUltraGridPlan`. | adapter | none | active | none |
| `Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridMediaFormatRegistry.swift` | Swift / registry | FourCC and media-format registry. | domain logic | `Foundation` | active | none |
| `Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridMediaIO.swift` | Swift / media IO | Memory/socket transmitter and receiver abstractions. | adapter | `Darwin`, `Foundation` | active | Network adapter complexity |
| `Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridMediaProvider.swift` | Swift / provider abstraction | Provider protocol, synthetic provider, lifecycle protocol. | adapter | `Foundation` | active | none |
| `Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridProtocolModel.swift` | Swift / wire model | Payload types, RTP classifications, codec registry, packing helpers. | domain logic | `Foundation` | active | Large protocol utility file |
| `Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridRTPPacketCodec.swift` | Swift / RTP codec | `UltraGridRTPPacketCodec`. | adapter | `Foundation` | active | none |
| `Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridTopology.swift` | Swift / topology enums | Topology mode and role enums. | domain logic | `Foundation` | active | none |
| `Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridVideoPayloadCodec.swift` | Swift / video codec | Video payload header and raw/JPEG/H264 RTP payload support. | adapter | `Foundation` | active | Multi-codec responsibility |

### Control

| File | Language/type | Responsibility / main exports | Runtime role | Dependencies | Status | Smells |
| --- | --- | --- | --- | --- | --- | --- |
| `Sources/OpenLolaCore/Control/AtemReadOnlyControl.swift` | Swift / probe runtime | ATEM health/report/probe config/runtime and validation error surface. | runtime | `Foundation`, `Darwin` | active | Large socket/probe/report file |
| `Sources/OpenLolaCore/Control/AtemReadOnlyControlValidation.swift` | Swift / validation | Validation helpers for ATEM read-only control reports. | adapter | `Foundation` | active | none |
| `Sources/OpenLolaCore/Control/LightingFixtureGate.swift` | Swift / policy model | Lighting safety, protocol, interop, workflow evidence, decision model. | domain logic | `Foundation` | active | Very large policy file |
| `Sources/OpenLolaCore/Control/LightingFixtureGateHelpers.swift` | Swift / validation helpers | `requireLighting*`, placeholder checks, standard evidence helpers. | adapter | `Foundation` | active | Repeated helper pattern |
| `Sources/OpenLolaCore/Control/LightingFixtureGateReport.swift` | Swift / report | Run mode and `LightingFixtureGateReport`. | report | `Foundation` | active | none |
| `Sources/OpenLolaCore/Control/LightingFixtureGateRun.swift` | Swift / runner config | Run configuration, config errors, runner support. | runtime | `Foundation` | active | Runtime and report shaping coupled |
| `Sources/OpenLolaCore/Control/OscCueHelpers.swift` | Swift / OSC helpers | OSC string/packet helpers, UDP send/receive, validation helpers. | adapter | `Darwin`, `Dispatch`, `Foundation` | active | Low-level packet parsing in helper file |
| `Sources/OpenLolaCore/Control/OscCueProbe.swift` | Swift / OSC model | Peer kind, message/packet/error/evidence types for OSC cue probing. | domain logic | `Darwin`, `Foundation` | active | Large protocol/report file |
| `Sources/OpenLolaCore/Control/OscCueRunners.swift` | Swift / runner | External runner, UDP loopback runner, synthetic loopback. | runtime | `Darwin`, `Dispatch`, `Foundation` | active | Network/runtime helpers split across files |

### Core

| File | Language/type | Responsibility / main exports | Runtime role | Dependencies | Status | Smells |
| --- | --- | --- | --- | --- | --- | --- |
| `Sources/OpenLolaCore/Core/CapabilitySummary.swift` | Swift / summary model | `DevelopmentStage`, `CapabilitySummary`. | report | none | active | none |
| `Sources/OpenLolaCore/Core/DebugTrace.swift` | Swift / tracing | Structured trace events, field policy, JSONL trace writer. | adapter | `Foundation` | active | Large trace/policy surface |
| `Sources/OpenLolaCore/Core/KeyValueArgumentParser.swift` | Swift / CLI parser | Strict key/value argument parsing and typed helpers. | adapter | none | active | Custom parsing logic rather than shared parser library |
| `Sources/OpenLolaCore/Core/OpenLolaCLI.swift` | Swift / CLI contract | `OpenLolaCLI` shared CLI-facing helpers/types. | entrypoint | none | active | Thin glue surface |
| `Sources/OpenLolaCore/Core/OpenLolaContractsAliases.swift` | Swift / alias layer | Re-exports `OpenLolaContracts` symbols via aliases. | adapter | `OpenLolaContracts` | unclear | Compatibility alias layer may age poorly |
| `Sources/OpenLolaCore/Core/PeerIdentity.swift` | Swift / identity + validation | `PeerIdentity`, `SessionValidationError`, `SessionValidation`. | domain logic | `Foundation` | active | Large error enum and cross-domain validation hooks |
| `Sources/OpenLolaCore/Core/ValidationPrimitives.swift` | Swift / primitive validation | Shared validation error types, protocols, `ValidationPrimitives`. | adapter | `Foundation` | active | Broad utility surface |

### Evidence

| File | Language/type | Responsibility / main exports | Runtime role | Dependencies | Status | Smells |
| --- | --- | --- | --- | --- | --- | --- |
| `Sources/OpenLolaCore/Evidence/HardwareValidationReport.swift` | Swift / report | Run mode/lane/hardware/evidence report surface for hardware validation. | report | `Foundation` | active | Broad report schema |
| `Sources/OpenLolaCore/Evidence/HardwareValidationRun.swift` | Swift / run config | Synthetic smoke and run configuration for hardware validation. | runtime | `Foundation` | active | none |
| `Sources/OpenLolaCore/Evidence/MeasurementReport.swift` | Swift / canonical report | Measurement kind, hardware/route identity, timing/loss metrics, validator, report. | report | `Foundation` | active | Validation logic embedded in model file |
| `Sources/OpenLolaCore/Evidence/ReferenceRigHelpers.swift` | Swift / validation helpers | Validator helpers for reference-rig reports and placeholder checks. | adapter | `Foundation` | active | Helper sprawl |
| `Sources/OpenLolaCore/Evidence/ReferenceRigReport.swift` | Swift / reference rig schema | Network topology, Mac profile, audio path, thresholds, validation-heavy report. | report | `Foundation` | active | Large and policy-heavy |
| `Sources/OpenLolaCore/Evidence/ReferenceRigReportValidation.swift` | Swift / validation | Additional validation for reference-rig report. | adapter | `Foundation` | active | none |
| `Sources/OpenLolaCore/Evidence/ReportSchemaInventory.swift` | Swift / inventory | Evidence-class inventory entry/summary/report and schema inventory builder. | report | `Foundation` | active | Inventory can drift from implementation |
| `Sources/OpenLolaCore/Evidence/ReportValidatorSurface.swift` | Swift / validation surface | Report-validating artifact types and console output helpers. | adapter | `Foundation` | active | none |
| `Sources/OpenLolaCore/Evidence/VerdictValidationPolicy.swift` | Swift / policy | Invalid-pass rules and shared verdict-forbid policy. | domain logic | none | active | Policy complexity |

### Integration

| File | Language/type | Responsibility / main exports | Runtime role | Dependencies | Status | Smells |
| --- | --- | --- | --- | --- | --- | --- |
| `Sources/OpenLolaCore/Integration/IntegratedAvHelpers.swift` | Swift / validation helpers | Shared validation helpers for integrated AV reports/runs. | adapter | `Foundation` | active | Repeated helper file |
| `Sources/OpenLolaCore/Integration/IntegratedAvReport.swift` | Swift / report schema | Integrated AV run mode, sync policy, metrics, frame identity, render policy types. | report | `Foundation` | active | Large report surface |
| `Sources/OpenLolaCore/Integration/IntegratedAvReportValidation.swift` | Swift / validation | Additional integrated AV report validation. | adapter | `Foundation` | active | none |
| `Sources/OpenLolaCore/Integration/IntegratedAvRun.swift` | Swift / runner | Run configuration, config error, integrated AV runner. | runtime | `Foundation` | active | Orchestration complexity |
| `Sources/OpenLolaCore/Integration/IntegratedProfileReport.swift` | Swift / report | `IntegratedProfileReport`. | report | `Foundation` | active | none |
| `Sources/OpenLolaCore/Integration/IntegratedProfileRun.swift` | Swift / runner | Synthetic smoke, run config, run error, profile runner. | runtime | `Foundation` | active | none |
| `Sources/OpenLolaCore/Integration/IntegratedProfileRuntimeEvidence.swift` | Swift / evidence helper | Runtime-evidence structure and report-application helper. | report | `Foundation` | active | Evidence-mutation helper |
| `Sources/OpenLolaCore/Integration/IntegratedProfileTypes.swift` | Swift / type hub | Run mode, labels, features, lanes, scenarios, steps, options, metrics. | domain logic | `Foundation` | active | Broad cross-cutting type set |

### Network/Diagnostics

| File | Language/type | Responsibility / main exports | Runtime role | Dependencies | Status | Smells |
| --- | --- | --- | --- | --- | --- | --- |
| `Sources/OpenLolaCore/Network/Diagnostics/AoipEvaluationReport.swift` | Swift / report | AoIP mode/usage/PTP/endpoint/switch/stress evaluation schema. | report | `Foundation` | active | Large schema |
| `Sources/OpenLolaCore/Network/Diagnostics/NetworkAoipCertification.swift` | Swift / certification report | Run mode, validation error, AoIP certification report. | report | `Foundation` | active | none |
| `Sources/OpenLolaCore/Network/Diagnostics/NetworkDiagnostics.swift` | Swift / diagnostics runner | Ping/traceroute results, parser, thresholds, run config, runner, smoke. | runtime | `Dispatch`, `Foundation` | active | Process parsing + runner bundled together |

### Network/NAT

| File | Language/type | Responsibility / main exports | Runtime role | Dependencies | Status | Smells |
| --- | --- | --- | --- | --- | --- | --- |
| `Sources/OpenLolaCore/Network/NAT/NatFriendlyRoute.swift` | Swift / core NAT contract | Role, compatibility mode, endpoint, evidence, validation, report, run configs. | domain logic | `Darwin`, `Dispatch`, `Foundation` | active | Dense core NAT surface |
| `Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteHelpers.swift` | Swift / helper set | Argument parsing, endpoint/relay helpers, datagram send/receive, port helpers. | adapter | `Darwin`, `Foundation` | active | Overgrown helper file |
| `Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteReports.swift` | Swift / report types | Rendezvous/relay report and registration models. | report | `Foundation` | active | none |
| `Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteRunner.swift` | Swift / runner | Keepalive message and top-level route runner. | runtime | `Darwin`, `Dispatch`, `Foundation` | active | Stateful transport logic |
| `Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteSmokes.swift` | Swift / smoke harness | Synthetic/localhost NAT smokes and result boxes. | test | `Darwin`, `Dispatch`, `Foundation` | active | Environment-sensitive tests |
| `Sources/OpenLolaCore/Network/NAT/NatProtocolConstants.swift` | Swift / constants | `NatProtocolMagic`. | config | `Foundation` | active | none |
| `Sources/OpenLolaCore/Network/NAT/NatRendezvousRelayRunners.swift` | Swift / rendezvous runtime | Rendezvous, client, relay, and forwarder-launcher runtime. | runtime | `Darwin`, `Dispatch`, `Foundation` | active | Multi-role runtime in one file |

### Network/P2P

| File | Language/type | Responsibility / main exports | Runtime role | Dependencies | Status | Smells |
| --- | --- | --- | --- | --- | --- | --- |
| `Sources/OpenLolaCore/Network/P2P/DirectP2PLocalhostSmoke.swift` | Swift / smoke | Localhost smoke result and runner for direct P2P. | test | `Foundation` | active | none |
| `Sources/OpenLolaCore/Network/P2P/DirectPeerAVFoundationRawFrameSource.swift` | Swift / capture source | Raw AVFoundation frame source for direct-peer video. | adapter | `Dispatch`, `Foundation`, `os`, `CoreMedia`, `CoreVideo` | active | Live capture complexity |
| `Sources/OpenLolaCore/Network/P2P/DirectPeerFNV1A.swift` | Swift / utility | `directPeerFNV1A32` hash helper. | adapter | `Foundation` | active | none |
| `Sources/OpenLolaCore/Network/P2P/DirectPeerManualValidation.swift` | Swift / manual validation | Endpoint/media-shape validation helpers for manual direct-peer setups. | adapter | `Darwin`, `Foundation` | unclear | Manual/compatibility path |
| `Sources/OpenLolaCore/Network/P2P/DirectPeerMeshRuntimeReport.swift` | Swift / runtime report | Mesh route/runtime metrics and report. | report | `Dispatch`, `Foundation` | active | none |
| `Sources/OpenLolaCore/Network/P2P/DirectPeerMeshTopologyReport.swift` | Swift / topology report | Mesh route/topology metrics and report. | report | `Foundation` | active | none |
| `Sources/OpenLolaCore/Network/P2P/DirectPeerMeshValidation.swift` | Swift / validation | Non-empty/non-negative mesh validators. | adapter | none | active | thin validator file |
| `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVAudioLoops.swift` | Swift / audio runtime | TX loop, RX drain, RTP host-time mapping, raw audio reassembly support. | runtime | `Dispatch`, `Foundation` | active | Heavy low-latency loop logic |
| `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVControlService.swift` | Swift / service | Control service result and service loop. | runtime | `Foundation` | active | none |
| `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVMetricsService.swift` | Swift / service | Metrics-service result and service loop. | runtime | `Foundation` | active | none |
| `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVReportBuilder.swift` | Swift / report builder | `buildAVReport`. | adapter | `Foundation` | active | none |
| `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVRunTypes.swift` | Swift / type hub | Media mode/profile/quality/compression/runtime-error/run-budget types. | domain logic | `Foundation` | active | Large option matrix |
| `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVRuntimeReport.swift` | Swift / metadata | Runtime metadata for AV session reports. | report | none | active | none |
| `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVSocketRunner.swift` | Swift / socket runner | Socket-backed AV session runtime. | runtime | `Darwin`, `CoreAudio`, `Dispatch`, `Foundation` | active | High-risk realtime/network bridge |
| `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVVideoLoops.swift` | Swift / video runtime | RX drain, playout anchor, sync decision, video loop runtime. | runtime | `Foundation` | active | Timing-sensitive loop logic |
| `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVVideoReportSupport.swift` | Swift / report helper | Runtime result, frame proof, payload digest, synthetic video-format report. | adapter | `Foundation` | active | none |
| `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionControlSocket.swift` | Swift / control socket | Direct-peer session control socket abstraction. | adapter | `Dispatch`, `Foundation` | active | none |
| `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionEvidence.swift` | Swift / evidence types | Measured-evidence kind, DSCP/clock evidence, baseline comparison types. | report | none | active | Broad evidence surface |
| `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionProductionAVPreflight.swift` | Swift / preflight | Production AV preflight report and blocker helper. | adapter | `Foundation` | active | none |
| `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionReceiveProofArtifact.swift` | Swift / artifact model | Receive-proof evidence metadata and artifact types. | report | `Foundation` | active | none |
| `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionReport.swift` | Swift / report | Primary direct-peer session report. | report | `Foundation` | active | none |
| `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionReportTypes.swift` | Swift / report support | Report metric structs for session and AV runtime metrics. | report | `Foundation` | active | none |
| `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionSocketRunner.swift` | Swift / socket runner | Manual-role socket runner and related config/error types. | runtime | `Darwin`, `Dispatch`, `Foundation` | active | Socket lifecycle complexity |
| `Sources/OpenLolaCore/Network/P2P/DirectPeerTwoPeerLocalRunReport.swift` | Swift / report | Local two-peer run report, preflight, process result. | report | `Foundation` | active | none |
| `Sources/OpenLolaCore/Network/P2P/DirectPeerTwoPeerRunPlan.swift` | Swift / plan | Two-peer run plan config and peer-plan types. | domain logic | `Foundation` | active | none |
| `Sources/OpenLolaCore/Network/P2P/DirectPeerTwoPeerRunPlanReportTypes.swift` | Swift / report types | Command, report reference, plan report, peer evidence types. | report | `Foundation` | active | none |
| `Sources/OpenLolaCore/Network/P2P/EndpointLoopbackReport.swift` | Swift / report | Loopback device/callback metrics and report. | report | `Foundation` | active | none |
| `Sources/OpenLolaCore/Network/P2P/MacToMacConnectionEstablishment.swift` | Swift / compatibility report | Setup mode, selected route, validation error, connection-establishment report. | report | `Foundation` | unclear | Compatibility-specific naming |
| `Sources/OpenLolaCore/Network/P2P/MacToMacRouteCertification.swift` | Swift / certification report | Run mode, candidate, validation error, certification report. | report | `Foundation` | unclear | Compatibility-specific naming |
| `Sources/OpenLolaCore/Network/P2P/PeerSessionRunner.swift` | Swift / central runner | Main peer-session runner. | runtime | `Darwin`, `Foundation` | active | High fan-out orchestrator |
| `Sources/OpenLolaCore/Network/P2P/PeerSessionRunnerAudioHelpers.swift` | Swift / helpers | Audio-specific helpers for peer-session runner. | adapter | `Foundation` | active | body not fully reviewed |
| `Sources/OpenLolaCore/Network/P2P/PeerSessionRunnerLoopbackPair.swift` | Swift / helper type | Loopback-pair support type. | adapter | none | active | none |
| `Sources/OpenLolaCore/Network/P2P/PeerSessionRunnerMediaIO.swift` | Swift / media IO helper | Media receive byte-budget helper and media-IO support. | adapter | `Foundation` | active | thin helper split |
| `Sources/OpenLolaCore/Network/P2P/PeerSessionRunnerMetrics.swift` | Swift / metrics helper | Metrics support for peer-session runtime. | adapter | `Dispatch`, `Foundation` | active | body not fully reviewed |
| `Sources/OpenLolaCore/Network/P2P/PeerSessionRunnerRTPAudio.swift` | Swift / RTP helper | RTP sequence-number and timestamp helpers. | adapter | `Foundation` | active | none |
| `Sources/OpenLolaCore/Network/P2P/PeerSessionRunnerSupport.swift` | Swift / support helper | Control-endpoint allocation and video pixel-format description helpers. | adapter | `Foundation` | active | utility sprawl risk |
| `Sources/OpenLolaCore/Network/P2P/PeerSessionRunnerTypes.swift` | Swift / runner types | Lifecycle state, runner errors, metrics, received media packet types. | domain logic | `Foundation` | active | central type surface |

### Network/RTP

| File | Language/type | Responsibility / main exports | Runtime role | Dependencies | Status | Smells |
| --- | --- | --- | --- | --- | --- | --- |
| `Sources/OpenLolaCore/Network/RTP/AES67ST2110L24Transport.swift` | Swift / transport + codec | AES67/ST2110 L24 RTP packet, codec, receive validator, SDP types. | runtime | `Foundation` | active | Packet, codec, SDP, and validation combined in one file |

### Network/UDP

| File | Language/type | Responsibility / main exports | Runtime role | Dependencies | Status | Smells |
| --- | --- | --- | --- | --- | --- | --- |
| `Sources/OpenLolaCore/Network/UDP/AudioOpusCeltLowDelayPacket.swift` | Swift / packet model | Codec-specific audio packet header and packet. | domain logic | `Foundation` | active | none |
| `Sources/OpenLolaCore/Network/UDP/MultichannelTransport.swift` | Swift / transport contract | Transport version, wire packing, latency profile, channel descriptors/capabilities. | domain logic | `Foundation` | active | Large contract file |
| `Sources/OpenLolaCore/Network/UDP/NetworkByteReader.swift` | Swift / parsing helper | Byte reader for packet decoding. | adapter | none | active | none |
| `Sources/OpenLolaCore/Network/UDP/PacketCodec.swift` | Swift / protocol | Packet codec protocol. | adapter | `Foundation` | active | none |
| `Sources/OpenLolaCore/Network/UDP/UdpMediaTransport.swift` | Swift / UDP transport | Media packet header/error/datagram types for UDP transport. | runtime | `Darwin`, `Dispatch`, `Foundation` | active | Low-level packet parsing + transport in one file |
| `Sources/OpenLolaCore/Network/UDP/UdpPcmContinuousRouteRunner.swift` | Swift / continuous runner | Continuous route runner and localhost smoke. | runtime | `Darwin`, `Dispatch`, `Foundation` | active | Long-running socket orchestration |
| `Sources/OpenLolaCore/Network/UDP/UdpPcmDataHelpers.swift` | Swift / byte helpers | Checked little-endian reads/appends for UDP PCM packets. | adapter | `Foundation` | active | none |
| `Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackDefaults.swift` | Swift / defaults | Loopback default settings. | config | `Foundation` | active | none |
| `Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackHelpers.swift` | Swift / helper set | Diagnostics comparison, reports, percentiles, loopback argument parsing. | adapter | `Foundation` | active | Large helper file |
| `Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackLatency.swift` | Swift / latency runtime | Loopback role/state/configuration and latency path. | runtime | `Darwin`, `Dispatch`, `Foundation` | active | Latency/runtime state complexity |
| `Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackSmokes.swift` | Swift / smokes | Synthetic and localhost loopback smokes. | test | `Dispatch`, `Foundation` | active | Environment-sensitive |
| `Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackSocketRunners.swift` | Swift / socket runners | Established socket runner, sender/looper results, sender runtime. | runtime | `Darwin`, `Dispatch`, `Foundation` | active | Socket management complexity |
| `Sources/OpenLolaCore/Network/UDP/UdpPcmPacket.swift` | Swift / packet model | Sample format, packet header/error, UDP PCM packet. | domain logic | `Darwin`, `Foundation` | active | none |
| `Sources/OpenLolaCore/Network/UDP/UdpPcmRouteCertification.swift` | Swift / certification report | Route kind, DSCP observation, packet capture, network profile, certification types. | report | `Darwin`, `Dispatch`, `Foundation` | active | Report and transport details mixed |
| `Sources/OpenLolaCore/Network/UDP/UdpPcmRouteHelpers.swift` | Swift / helper set | Probe packets and route-run argument parsing helpers. | adapter | `Darwin`, `Dispatch`, `Foundation` | active | Helper sprawl |
| `Sources/OpenLolaCore/Network/UDP/UdpPcmRouteLocalhostSmoke.swift` | Swift / smoke | One-shot sender/receiver localhost smoke. | test | `Darwin`, `Dispatch`, `Foundation` | active | none |
| `Sources/OpenLolaCore/Network/UDP/UdpPcmRouteRunConfiguration.swift` | Swift / config | Route role and run configuration. | config | `Foundation`, `OpenLolaContracts` | active | none |
| `Sources/OpenLolaCore/Network/UDP/UdpPcmSocketOperations.swift` | Swift / socket helpers | Socket creation, bind, DSCP, non-blocking, close helpers. | adapter | `Darwin`, `Foundation`, `os` | active | Low-level system-call surface |
| `Sources/OpenLolaCore/Network/UDP/UdpPcmV2FragmentPlanner.swift` | Swift / fragmentation planner | V2 packet header, fragment-plan request, planning errors, fragment plan. | domain logic | `Foundation` | active | Newer protocol path may be compatibility-sensitive |
| `Sources/OpenLolaCore/Network/UDP/UdpPcmV2Packet.swift` | Swift / packet model | V2 packet error and packet implementation. | domain logic | `Foundation` | active | Newer protocol path may be compatibility-sensitive |

### Platform

| File | Language/type | Responsibility / main exports | Runtime role | Dependencies | Status | Smells |
| --- | --- | --- | --- | --- | --- | --- |
| `Sources/OpenLolaCore/Platform/NativeAppShell.swift` | Swift / app-shell contract | Run mode, config snapshot, metrics observer profile, permissions, smoke probe. | domain logic | `Foundation` | active | Broad app-shell surface |
| `Sources/OpenLolaCore/Platform/NativeAppShellArtifacts.swift` | Swift / artifact handling | Artifact kind, artifact error, generated-artifact state. | adapter | `AppKit`, `Foundation` | active | macOS-specific artifact path |
| `Sources/OpenLolaCore/Platform/NativeAppShellDirectPeerCommand.swift` | Swift / command fields | Direct-peer command field model for native app shell. | adapter | `Foundation` | active | none |
| `Sources/OpenLolaCore/Platform/NativeAppShellDirectPeerSettingsValidation.swift` | Swift / validation | Validation helpers for direct-peer settings in app shell. | adapter | `Foundation` | active | body not reviewed |
| `Sources/OpenLolaCore/Platform/NativeAppShellExecution.swift` | Swift / execution settings | Execution paths, validation error, execution settings. | adapter | `Foundation`, `OpenLolaContracts` | active | Settings/validation coupling |
| `Sources/OpenLolaCore/Platform/NativeAppShellMediaDevices.swift` | Swift / device option model | Audio/video device option types. | domain logic | `Foundation` | active | none |
| `Sources/OpenLolaCore/Platform/NativeAppShellMediaInventory.swift` | Swift / media inventory | Local media selection and inventory. | report | `Foundation` | active | none |
| `Sources/OpenLolaCore/Platform/NativeAppShellOperatorPrototypeState+RunPlan.swift` | Swift / extension | Run-plan extension for operator prototype state. | adapter | `Foundation` | active | Fragmented type split |
| `Sources/OpenLolaCore/Platform/NativeAppShellOperatorState.swift` | Swift / operator state | `NativeAppShellOperatorPrototypeState`. | domain logic | `Foundation` | active | none |
| `Sources/OpenLolaCore/Platform/NativeAppShellSearchAndPacketMonitor.swift` | Swift / packet monitor | Packet-stream filters, packet-monitor rows, search helpers. | UI | `Foundation` | active | UI-facing state and parsing together |
| `Sources/OpenLolaCore/Platform/NativeAppShellSessionMode.swift` | Swift / app-shell enums | Session/control mode and settings-group/visibility enums. | domain logic | `Foundation` | active | none |
| `Sources/OpenLolaCore/Platform/NativeAppShellSurfaceContract.swift` | Swift / UI contract | Surface section IDs, command intents, sections, actions. | UI | `Foundation` | active | Public app-surface contract |

### Protocol

| File | Language/type | Responsibility / main exports | Runtime role | Dependencies | Status | Smells |
| --- | --- | --- | --- | --- | --- | --- |
| `Sources/OpenLolaCore/Protocol/SessionCapabilityValidating.swift` | Swift / protocol contract | Capability negotiation protocols for audio/video/session validation. | domain logic | none | active | none |
| `Sources/OpenLolaCore/Protocol/SessionControlMessage.swift` | Swift / control plane | Control-message types, rejection/media/metrics/error/shutdown messages, codec, state machine. | domain logic | `Foundation` | active | Central and complex protocol/state-machine file |
| `Sources/OpenLolaCore/Protocol/SessionNegotiation.swift` | Swift / enum | `SessionNegotiation`. | domain logic | none | active | none |
| `Sources/OpenLolaCore/Protocol/SessionProtocol.swift` | Swift / session schema | Control protocol, latency/video pressure policies, endpoints, capabilities, proposal/configuration. | domain logic | `Foundation` | active | Large top-level session contract |

### Release

| File | Language/type | Responsibility / main exports | Runtime role | Dependencies | Status | Smells |
| --- | --- | --- | --- | --- | --- | --- |
| `Sources/OpenLolaCore/Release/CurrentEvidenceStatusMatrix.swift` | Swift / matrix report | Current evidence status matrix, task crosswalk, summary report. | report | `Foundation` | unclear | Static-matrix inventory may age quickly |
| `Sources/OpenLolaCore/Release/FasterThanLoLaClosure.swift` | Swift / closure report | Claim scope, evidence lane, benchmark comparison, closure report. | report | `Foundation` | active | Policy-heavy release report |
| `Sources/OpenLolaCore/Release/FasterThanLoLaClosureValidation.swift` | Swift / validation | Closure validation helpers. | adapter | `Foundation` | active | none |
| `Sources/OpenLolaCore/Release/FieldReadinessRun.swift` | Swift / runner | Run config, error, result, `FieldReadinessRunner`. | runtime | `Foundation` | active | Release orchestration complexity |
| `Sources/OpenLolaCore/Release/FieldReadyRuntimeProof.swift` | Swift / proof schema | Field-ready runtime evidence, permission/recording/distribution proof types. | report | `Foundation` | active | Large proof schema |
| `Sources/OpenLolaCore/Release/FieldReadyRuntimeProofValidation.swift` | Swift / validation | Validation helpers for runtime proof. | adapter | `Foundation` | active | none |
| `Sources/OpenLolaCore/Release/LoLaParityDeferredFeatures.swift` | Swift / deferred-feature ledger | Feature category/status, deferred feature, ledger report, validator. | report | `Foundation` | unclear | Compatibility/debt ledger rather than runtime code |
| `Sources/OpenLolaCore/Release/OpenSourceReleaseReadiness.swift` | Swift / readiness report | Open-source release requirement kinds, validator, readiness report. | report | `Foundation` | active | Policy-heavy |
| `Sources/OpenLolaCore/Release/PackagingFieldTest.swift` | Swift / report | Packaging field-test report/contracts. | report | `Foundation` | active | exact body not fully reviewed |
| `Sources/OpenLolaCore/Release/PackagingFieldTestHelpers.swift` | Swift / helper set | Packaging field-test helper routines. | adapter | `Foundation` | active | body not fully reviewed |
| `Sources/OpenLolaCore/Release/PackagingFieldTestRun.swift` | Swift / runner | Field-run config/error and runner. | runtime | `CryptoKit`, `Foundation` | active | Packaging orchestration |
| `Sources/OpenLolaCore/Release/PackagingFieldTestValidation.swift` | Swift / validation | Packaging field-test validation. | adapter | `Foundation` | active | none |
| `Sources/OpenLolaCore/Release/RecordingSessionArtifactValidationError.swift` | Swift / error type | Artifact validation error enum for recording sessions. | domain logic | `Foundation` | active | none |
| `Sources/OpenLolaCore/Release/RecordingSessionArtifacts.swift` | Swift / artifact schema | Recording modes, artifact kinds, capture selections, artifact metrics. | report | `Foundation` | active | Large artifact contract |
| `Sources/OpenLolaCore/Release/RecordingSessionHelpers.swift` | Swift / helper set | Artifact validator plus run-argument parsing helpers. | adapter | `CryptoKit`, `Foundation` | active | Helper sprawl |
| `Sources/OpenLolaCore/Release/RecordingSessionLiveCapture.swift` | Swift / live capture runtime | Live media capture, capture wait, raw CoreAudio input recorder. | runtime | `Foundation`, `Dispatch`, `COpenLolaAtomics`, `CoreAudio`, `Darwin`, `CoreMedia`, `CoreVideo` | active | Highest-risk release file; live capture + atomics + hardware |
| `Sources/OpenLolaCore/Release/RecordingSessionMediaArtifacts.swift` | Swift / artifact writer | Captured audio/video/media types and artifact writer. | adapter | `Foundation` | active | none |
| `Sources/OpenLolaCore/Release/RecordingSessionRun.swift` | Swift / runner | Pressure simulator and recording-session run configuration. | runtime | `Foundation` | active | Runtime not fully traced |
| `Sources/OpenLolaCore/Release/ReleaseHardening.swift` | Swift / hardening report | Release hardening modes, evidence references, verification gates, comparisons. | report | `Foundation` | active | Policy-heavy |
| `Sources/OpenLolaCore/Release/ReleaseHardeningSyntheticSmoke.swift` | Swift / smoke + runner | Synthetic smoke and release hardening runner. | test | `Foundation` | active | Runner/smoke coupling |
| `Sources/OpenLolaCore/Release/Goal/GoalCodewiseClosure.swift` | Swift / goal ledger | Codewise requirement area/status/id and requirement types. | report | `Foundation` | active | Audit/ledger surface |
| `Sources/OpenLolaCore/Release/Goal/GoalCompletionAudit.swift` | Swift / audit report | Audit items, next actions, summary, validator, completion-audit report. | report | `Foundation` | active | Conceptually dense audit surface |
| `Sources/OpenLolaCore/Release/Goal/GoalRuntimeEvidenceTemplate.swift` | Swift / template report | Deliverable IDs, template summary, validator, runtime-evidence template report. | report | `Foundation` | active | Template/report layering |
| `Sources/OpenLolaCore/Release/Goal/GoalRuntimePreflight.swift` | Swift / preflight report | Preflight validator plus audio/video/signing probe types. | report | `Foundation` | active | Preflight contract size |

### Support

| File | Language/type | Responsibility / main exports | Runtime role | Dependencies | Status | Smells |
| --- | --- | --- | --- | --- | --- | --- |
| `Sources/OpenLolaCore/Support/BoundedFileReader.swift` | Swift / utility | Bounded file reads with `BoundedFileReader`. | adapter | `Foundation` | active | none |
| `Sources/OpenLolaCore/Support/BoundedPipeCapture.swift` | Swift / utility | Captures bounded subprocess pipe output. | adapter | `Foundation` | active | none |
| `Sources/OpenLolaCore/Support/FileDescriptorSet.swift` | Swift / FD wrapper | `fd_set` manipulation helpers. | adapter | `Darwin` | active | Low-level C interop |
| `Sources/OpenLolaCore/Support/ManagedProcessRunner.swift` | Swift / process wrapper | Managed process lifecycle, cleanup warnings, termination result. | adapter | `Darwin`, `Dispatch`, `Foundation` | active | Process cleanup and sendability risk |
| `Sources/OpenLolaCore/Support/MonotonicDeadline.swift` | Swift / timing utility | Monotonic deadline helper. | adapter | `Dispatch`, `Foundation` | active | none |
| `Sources/OpenLolaCore/Support/PlaceholderDetection.swift` | Swift / heuristic utility | Detects placeholder/synthetic values. | adapter | `Foundation` | active | Heuristic policy can drift |
| `Sources/OpenLolaCore/Support/PlaceholderFieldCollection.swift` | Swift / metadata | Placeholder-sensitive field collections and indexed field helpers. | config | none | active | Static metadata can drift |
| `Sources/OpenLolaCore/Support/SPSCAtomicRing.swift` | Swift / ring buffer | `SPSCAtomicRingResult`, `SPSCUInt64Ring`. | domain logic | `COpenLolaAtomics`, `Darwin`, `Foundation` | active | Concurrency-sensitive core primitive |
| `Sources/OpenLolaCore/Support/Inventories/CLICommandInventory.swift` | Swift / inventory | CLI command inventory entry/summary/report builder. | report | `Foundation` | active | Inventory drift risk |
| `Sources/OpenLolaCore/Support/Inventories/FixtureSmokeMatrix.swift` | Swift / inventory | Fixture provenance, release posture, smoke-matrix report. | report | `Foundation` | active | Inventory drift risk |
| `Sources/OpenLolaCore/Support/Inventories/FixtureSmokeMatrixData.swift` | Swift / static data | Backing data for fixture smoke matrix. | config | none | active | Static data maintenance burden |
| `Sources/OpenLolaCore/Support/Inventories/NetworkRouteCommandMatrix.swift` | Swift / inventory | Route-mode/evidence-boundary command matrix and report. | report | `Foundation` | active | Inventory drift risk |
| `Sources/OpenLolaCore/Support/Inventories/RealtimeAudioPathInventory.swift` | Swift / inventory | Realtime-audio path classes, entries, report. | report | `Foundation` | active | Inventory drift risk |
| `Sources/OpenLolaCore/Support/Inventories/SourceOwnershipInventory.swift` | Swift / inventory | Ownership/risk/status/confidence inventory and coverage report. | report | `Foundation` | active | Inventory can become stale quickly |
| `Sources/OpenLolaCore/Support/Inventories/VideoControlDegradeMatrix.swift` | Swift / inventory | Video control degradation matrix and report. | report | `Foundation` | active | Static matrix maintenance burden |

### Timing

| File | Language/type | Responsibility / main exports | Runtime role | Dependencies | Status | Smells |
| --- | --- | --- | --- | --- | --- | --- |
| `Sources/OpenLolaCore/Timing/DriftPlcFixedTargetCertification.swift` | Swift / certification report | Baseline availability/method/comparison/certification report surface. | report | `Foundation` | active | Large certification schema |
| `Sources/OpenLolaCore/Timing/DriftPlcHelpers.swift` | Swift / helper set | Drift estimation, fixed-target telemetry, checkpoint helpers. | adapter | `Foundation` | active | none |
| `Sources/OpenLolaCore/Timing/DriftPlcReport.swift` | Swift / report | PLC policy, correction events, telemetry, metrics. | report | `Foundation` | active | Complex timing model |
| `Sources/OpenLolaCore/Timing/DriftPlcRun.swift` | Swift / runner | Drift/PLC run config, error, fixed-target runner. | runtime | `Foundation` | active | Timing/runtime complexity |
| `Sources/OpenLolaCore/Timing/LatencyProfileContracts.swift` | Swift / policy contract | Latency profile warnings, validation, policy, budget. | domain logic | `Foundation` | active | Config-gating contract |
| `Sources/OpenLolaCore/Timing/LatencyTuningReport.swift` | Swift / tuning report | Run mode, evidence kind, thresholds, candidate report surface. | report | `Foundation` | active | none |
| `Sources/OpenLolaCore/Timing/LatencyTuningReportValidation.swift` | Swift / validation | `LatencyTuningValidator`. | adapter | `Foundation` | active | none |
| `Sources/OpenLolaCore/Timing/MediaClock.swift` | Swift / clocking | `MediaClock`, anchors, timestamp origins, timing packets, drift estimates. | domain logic | `Foundation` | active | High-risk time math |
| `Sources/OpenLolaCore/Timing/RxBufferBenchmarkReport.swift` | Swift / benchmark report | RX buffer benchmark rows, validator, report. | report | `Foundation` | active | none |
| `Sources/OpenLolaCore/Timing/RxBufferBenchmarkRunner.swift` | Swift / runner | RX buffer benchmark runner and error type. | runtime | `Foundation` | active | none |
| `Sources/OpenLolaCore/Timing/RxBuffering.swift` | Swift / buffering policy | RX buffer policy and adaptive buffering runtime support. | domain logic | `Foundation` | active | Central buffering logic |
| `Sources/OpenLolaCore/Timing/RxImpairmentSimulator.swift` | Swift / simulator | Impairment profile, packet events, summary/result, simulator. | test | `Foundation` | active | Simulation logic complexity |
| `Sources/OpenLolaCore/Timing/SessionProfileBenchmark.swift` | Swift / benchmark helper | Session latency-profile benchmark metrics and synthetic smoke. | test | `Foundation` | active | none |
| `Sources/OpenLolaCore/Timing/TimingValidationHelpers.swift` | Swift / validation helper | Ordered-percentile validation. | adapter | none | active | none |

### Video

| File | Language/type | Responsibility / main exports | Runtime role | Dependencies | Status | Smells |
| --- | --- | --- | --- | --- | --- | --- |
| `Sources/OpenLolaCore/Video/BlackmagicOutputBoundary.swift` | Swift / boundary report | Blackmagic SDK/output availability report and boundary wrapper. | report | `Foundation` | unclear | Specialized compatibility boundary |
| `Sources/OpenLolaCore/Video/JPEGXSReferenceCodec.swift` | Swift / codec wrapper | `JPEGXSReferenceCodec` over vendored JPEG-XS reference target. | adapter | `Foundation`, `CJpegXSReference` | active | Vendor-bridge risk |
| `Sources/OpenLolaCore/Video/MediaGeometrySizing.swift` | Swift / geometry utility | `MediaGeometrySizing` helpers and errors. | adapter | `Foundation` | active | none |
| `Sources/OpenLolaCore/Video/MultiVideoStreams.swift` | Swift / multi-stream model | Receiver selection, multiview layout, transport metrics. | domain logic | `Foundation` | active | none |
| `Sources/OpenLolaCore/Video/RawBGRAAppKitPreviewWindow.swift` | Swift / preview UI | AppKit preview sink/window and image factory. | UI | `AppKit`, `CoreGraphics`, `Foundation` | active | UI + sink logic combined |
| `Sources/OpenLolaCore/Video/VideoCaptureAVFoundation.swift` | Swift / capture adapter | AVFoundation device inventory, permission/status, source policy and format description. | adapter | `Foundation`, `Dispatch`, `CoreMedia`, `CoreVideo` | active | Hardware/framework-heavy path |
| `Sources/OpenLolaCore/Video/VideoCaptureHelpers.swift` | Swift / helper set | Video-capture validation helpers and utility formatting. | adapter | `Foundation` | active | Repeated helper pattern |
| `Sources/OpenLolaCore/Video/VideoCaptureProbe.swift` | Swift / capture model | Source kind, queue policy, camera source, timestamp basis, captured frame types. | domain logic | `Foundation`, `Darwin`, `CoreMedia`, `CoreVideo` | active | Large type bundle |
| `Sources/OpenLolaCore/Video/VideoCaptureReport.swift` | Swift / capture report | Production hardware evidence and capture report/validation errors. | report | `Foundation` | active | Large evidence schema |
| `Sources/OpenLolaCore/Video/VideoCaptureRunConfiguration.swift` | Swift / config | Capture run config, config error, production evidence input. | config | `Foundation`, `OpenLolaContracts` | active | none |
| `Sources/OpenLolaCore/Video/VideoCaptureRunner.swift` | Swift / capture runner | Capture probe error, camera snapshot, synthetic smoke, runtime. | runtime | `Foundation`, `Dispatch`, `os`, `Darwin`, `CoreMedia`, `CoreVideo` | active | Hardware/runtime complexity |
| `Sources/OpenLolaCore/Video/VideoMediaSocket.swift` | Swift / packetizer | `VideoMediaPacketizer`. | adapter | `Foundation` | active | none |
| `Sources/OpenLolaCore/Video/VideoOutputRenderer.swift` | Swift / output abstraction | Backend kind, pacing policy, output frame, metrics, renderer. | adapter | `Foundation` | active | Render/output policy complexity |
| `Sources/OpenLolaCore/Video/VideoStreamDescription.swift` | Swift / stream contract | Video role, pixel format, transport format, resolution, frame rate, stream description. | domain logic | none | active | none |
| `Sources/OpenLolaCore/Video/VideoTransportHelpers.swift` | Swift / helper set | Validation helpers, format normalization, byte math, CLI parsing. | adapter | `Foundation` | active | Utility sprawl |
| `Sources/OpenLolaCore/Video/VideoTransportMultiStreamRuntime.swift` | Swift / runtime helper | Multistream state/metric helpers for transport runs. | runtime | `Foundation` | active | none |
| `Sources/OpenLolaCore/Video/VideoTransportPacket.swift` | Swift / packet model | Transport packet and fragment. | domain logic | `Foundation` | active | none |
| `Sources/OpenLolaCore/Video/VideoTransportProbe.swift` | Swift / route/config model | Transport mode, degradation action, profile, route evidence, run config. | domain logic | `Foundation` | active | Large config surface |
| `Sources/OpenLolaCore/Video/VideoTransportReassembly.swift` | Swift / reassembly logic | Fragmentation metrics, reassembly metrics, latest-frame receiver, reassembler. | runtime | `Dispatch`, `Foundation` | active | Stateful packet reassembly |
| `Sources/OpenLolaCore/Video/VideoTransportReport.swift` | Swift / report | Main video transport report. | report | `Foundation` | active | Broad transport accounting |
| `Sources/OpenLolaCore/Video/VideoTransportRunner.swift` | Swift / runner | Synthetic smoke, receive-render smoke, main transport runner. | runtime | `Darwin`, `Dispatch`, `Foundation` | active | Highest-risk video runtime file |

## Target: open-lola (CLI)

| File | Language/type | Responsibility / main exports | Runtime role | Dependencies | Status | Smells |
| --- | --- | --- | --- | --- | --- | --- |
| `Sources/open-lola/main.swift` | Swift / executable main | `runOpenLolaCommand`, command registry, top-level `Command`/`RegisteredCommand` flow. | entrypoint | `Darwin`, `Foundation`, `OpenLolaCore` | active | Large registry fan-out |
| `Sources/open-lola/Commands/Audio/LatencyProfileCommands.swift` | Swift / command handler | `handleLatencyProfileCommand`. | entrypoint | `Foundation`, `OpenLolaCore` | active | thin handler |
| `Sources/open-lola/Commands/Audio/MadiFullDuplexCommands.swift` | Swift / command handler | `handleMadiFullDuplexCommand`. | entrypoint | `Foundation`, `OpenLolaCore` | active | thin handler |
| `Sources/open-lola/Commands/Audio/MadiReceiveCommands.swift` | Swift / command handler | `handleMadiReceiveCommand`. | entrypoint | `Foundation`, `OpenLolaCore` | active | thin handler |
| `Sources/open-lola/Commands/Benchmarks/E2EBenchmarkCommands.swift` | Swift / command handler | `handleE2EBenchmarkCommand`. | entrypoint | `Foundation`, `OpenLolaCore` | active | thin handler |
| `Sources/open-lola/Commands/Benchmarks/PerformanceCommands.swift` | Swift / command handler | `handlePerformanceCommand`. | entrypoint | `Foundation`, `OpenLolaCore` | active | thin handler |
| `Sources/open-lola/Commands/CLICommandHelpers.swift` | Swift / CLI helper | `validateReport` shared helper. | adapter | `Foundation`, `OpenLolaCore` | active | tiny utility layer |
| `Sources/open-lola/Commands/MilestoneCommands.swift` | Swift / command handler | `handleMilestoneCommand`. | entrypoint | `Foundation`, `OpenLolaCore` | active | thin handler |
| `Sources/open-lola/Commands/Network/DirectP2PMeasuredEvidenceCommandSupport.swift` | Swift / support helper | Measured-evidence/artifact write helpers for direct P2P commands. | adapter | `Foundation`, `OpenLolaCore` | active | file-output helper clutter |
| `Sources/open-lola/Commands/Network/DirectP2PMeshArgumentSupport.swift` | Swift / parsing helper | Mesh topology/runtime argument parsing and output-path helpers. | adapter | `Foundation`, `OpenLolaCore` | active | CLI parsing sprawl |
| `Sources/open-lola/Commands/Network/DirectP2PSessionQualityPolicyCommandSupport.swift` | Swift / policy helper | `directP2PQualityPolicy`. | adapter | `OpenLolaCore` | active | none |
| `Sources/open-lola/Commands/Network/DirectP2PSessionRunArgumentSupport.swift` | Swift / argument list | Allowed/public argument lists for direct P2P session run. | config | none | active | static argument metadata |
| `Sources/open-lola/Commands/Network/DirectP2PSessionRunCommandSupport.swift` | Swift / command parser | Usage text, argument parsing, ready-file writer, AV config shaping. | entrypoint | `Foundation`, `OpenLolaCore` | active | dense CLI support file |
| `Sources/open-lola/Commands/Network/DirectP2PTwoPeerLocalRunCommandSupport.swift` | Swift / command runner | Runs local two-peer direct P2P command. | entrypoint | `Dispatch`, `Foundation`, `OpenLolaCore` | active | runtime + CLI coupled |
| `Sources/open-lola/Commands/Network/DirectP2PTwoPeerPrototypeCommandSupport.swift` | Swift / command runner | Usage text and prototype report command runner. | entrypoint | `Foundation`, `OpenLolaCore` | active | none |
| `Sources/open-lola/Commands/Network/NetworkCommands.swift` | Swift / main command router | `handleNetworkCommand` top-level router for network/P2P/NAT/compat commands. | entrypoint | `Darwin`, `Foundation`, `OpenLolaCore` | active | Very large switch/router file |
| `Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift` | Swift / command handler | `handleMilestoneValidationCommand`. | entrypoint | `Foundation`, `OpenLolaCore` | active | thin handler |

## Target: open-lola-app / OpenLolaAppSupport (SwiftUI app)

| File | Language/type | Responsibility / main exports | Runtime role | Dependencies | Status | Smells |
| --- | --- | --- | --- | --- | --- | --- |
| `Sources/open-lola-app/AppChannelMeterView.swift` | Swift / SwiftUI view | Channel-meter UI. | UI | `SwiftUI` | active | none |
| `Sources/open-lola-app/AppConnectionTopologyView.swift` | Swift / SwiftUI view | Connection topology UI using core report types. | UI | `OpenLolaCore`, `SwiftUI` | active | none |
| `Sources/open-lola-app/AppConsoleChromeView.swift` | Swift / SwiftUI view | Console sidebar and top-bar views. | UI | `OpenLolaCore`, `SwiftUI` | active | none |
| `Sources/open-lola-app/AppConsoleModels.swift` | Swift / UI model | `AppConsoleStatusSnapshot` and console state support. | UI | `OpenLolaCore`, `SwiftUI` | active | Model + UI imports are mixed |
| `Sources/open-lola-app/AppDesignSystem.swift` | Swift / design system | `AppDesignSystem`, `AppColorRole`. | UI | `Foundation`, `AppKit`, `SwiftUI` | active | none |
| `Sources/open-lola-app/AppDeviceCard.swift` | Swift / SwiftUI view | Audio/video device cards. | UI | `OpenLolaCore`, `SwiftUI` | active | none |
| `Sources/open-lola-app/AppExecutablePathResolver.swift` | Swift / resolver | Executable path resolution and error handling for app-launched binaries. | adapter | `Foundation`, `OSLog` | active | none |
| `Sources/open-lola-app/AppExecutionController.swift` | Swift / controller | Execution phases/kinds/readiness and main app execution controller. | UI | `Foundation`, `AppKit`, `Observation`, `OpenLolaCore` | active | Large stateful coordinator |
| `Sources/open-lola-app/AppExecutionView.swift` | Swift / SwiftUI view | Main execution panel. | UI | `OpenLolaCore`, `SwiftUI` | active | none |
| `Sources/open-lola-app/AppLatencyHeroMetrics.swift` | Swift / UI helper | Latency hero metric extraction for UI. | UI | `Foundation`, `OpenLolaCore` | active | none |
| `Sources/open-lola-app/AppLatencyHeroView.swift` | Swift / SwiftUI view | Latency hero summary view. | UI | `OpenLolaCore`, `SwiftUI` | active | none |
| `Sources/open-lola-app/AppLocalOperatorInventory.swift` | Swift / controller/model | Local operator inventory controller and model. | UI | `Foundation`, `Observation`, `OpenLolaCore` | active | none |
| `Sources/open-lola-app/AppLocalOperatorSurfaceView.swift` | Swift / SwiftUI view | Operator surface view. | UI | `OpenLolaCore`, `SwiftUI` | active | none |
| `Sources/open-lola-app/AppOperatorArtifactViews.swift` | Swift / SwiftUI view | Artifact display views for operator output. | UI | `AppKit`, `OpenLolaCore`, `SwiftUI` | active | none |
| `Sources/open-lola-app/AppOperatorPlanViews.swift` | Swift / SwiftUI view | Operator plan view(s), including `AppOperatorPrototypePlan`. | UI | `OpenLolaCore`, `SwiftUI` | active | none |
| `Sources/open-lola-app/AppPacketMonitorView.swift` | Swift / SwiftUI view | Packet monitor UI. | UI | `Foundation`, `OpenLolaCore`, `SwiftUI` | active | none |
| `Sources/open-lola-app/AppPasteboard.swift` | Swift / utility | Pasteboard abstraction and copy status. | adapter | `AppKit` | active | none |
| `Sources/open-lola-app/AppPreviewBindings.swift` | Swift / preview helper | Preview/test binding helpers. | UI | `SwiftUI` | active | preview-only helper |
| `Sources/open-lola-app/AppPreviewReceiverView.swift` | Swift / SwiftUI view | Preview receiver state/view support. | UI | `Observation`, `OpenLolaCore`, `SwiftUI` | active | preview/runtime boundary |
| `Sources/open-lola-app/AppReceiverPreviewServices.swift` | Swift / preview service | Video preview controller and preview-side services. | UI | `AppKit`, `COpenLolaAtomics`, `CoreAudio`, `Foundation`, `Observation`, `OpenLolaCore`, `SwiftUI`, `os` | active | Heavy framework/controller file |
| `Sources/open-lola-app/AppRemoteInventoryImport.swift` | Swift / import helper | Remote inventory import support. | adapter | `Foundation`, `OpenLolaCore` | unclear | Body not reviewed |
| `Sources/open-lola-app/AppRuntimeEvidenceScope.swift` | Swift / enum/helper | App runtime evidence scoping. | UI | `OpenLolaCore` | active | none |
| `Sources/open-lola-app/AppRuntimeInputLock.swift` | Swift / utility | Input-lock state for runtime UI. | UI | none | active | none |
| `Sources/open-lola-app/AppSessionStateBanner.swift` | Swift / SwiftUI view | Session-state banner view. | UI | `OpenLolaCore`, `SwiftUI` | active | none |
| `Sources/open-lola-app/AppSettings.swift` | Swift / settings model | App settings model. | UI | `Foundation`, `Observation`, `OpenLolaCore` | active | none |
| `Sources/open-lola-app/AppShellReadOnlyViews.swift` | Swift / SwiftUI views | Overview/configuration/metrics/boundaries/permissions/probe views. | UI | `OpenLolaCore`, `SwiftUI` | active | Large multi-view file |
| `Sources/open-lola-app/AppShellRootView.swift` | Swift / root view | Main app-shell root view. | UI | `OpenLolaCore`, `SwiftUI` | active | High-fan-out composition file |
| `Sources/open-lola-app/AppShellSettingsTabs.swift` | Swift / SwiftUI views | Execution, connector notice, Windows LoLa settings tabs. | UI | `OpenLolaCore`, `SwiftUI` | active | none |
| `Sources/open-lola-app/AppShellSettingsView.swift` | Swift / SwiftUI view | Settings container view. | UI | `OpenLolaCore`, `SwiftUI` | active | none |
| `Sources/open-lola-app/AppShellStoredDefaults.swift` | Swift / persistence helper | App shell stored defaults. | adapter | `Foundation`, `OpenLolaCore`, `OSLog` | active | none |
| `Sources/open-lola-app/AppShellSupportViews.swift` | Swift / SwiftUI helpers | Field widgets, metrics grid, readable metric helpers. | UI | `AppKit`, `OpenLolaCore`, `SwiftUI` | active | Utility/view blend |
| `Sources/open-lola-app/AppStorageKeys.swift` | Swift / storage contract | App storage keys and operator-artifact defaults. | config | `OpenLolaCore` | active | Public persistence contract |
| `Sources/open-lola-app/AppTransportView.swift` | Swift / SwiftUI view | Transport settings/status view. | UI | `OpenLolaCore`, `SwiftUI` | active | none |
| `Sources/open-lola-app/OpenLolaApp.swift` | Swift / app composition | `OpenLolaApp`, `OpenLolaAppScene`; main SwiftUI scene/menu/window composition. | UI | `OpenLolaCore`, `SwiftUI` | active | Large composition/coordinator file |
| `Sources/open-lola-app-main/OpenLolaAppMain.swift` | Swift / executable main | `@main` app entry wrapping `OpenLolaAppSupport`. | entrypoint | `AppKit`, `OpenLolaAppSupport`, `SwiftUI` | active | none |

## Target: CJpegXSReference (vendored)

| File/target | Language/type | Responsibility / main exports | Runtime role | Dependencies | Status | Smells |
| --- | --- | --- | --- | --- | --- | --- |
| `Sources/xs_ref_sw_ed2/libjxs/` | C / vendored codec | Vendored JPEG-XS reference implementation exposed via `CJpegXSReference`; used by `JPEGXSReferenceCodec.swift`. | adapter | vendored C sources + public headers | generated | Vendor boundary; do not infer internal ownership from local code style |

## Target: COpus (vendored)

| File/target | Language/type | Responsibility / main exports | Runtime role | Dependencies | Status | Smells |
| --- | --- | --- | --- | --- | --- | --- |
| `Sources/opus-1.5.2/` | C / vendored codec | Vendored Opus 1.5.2 sources plus `openlola_bridge/COpusBridge.c`; used by low-delay Opus codec wrapper. | adapter | vendored `src/`, `celt/`, `silk/` code | generated | Vendor boundary; large imported code surface |

## linux_connector (Python package)

### `linux_connector/lola_connector/`

| File | Language/type | Responsibility / main exports | Runtime role | Dependencies | Status | Smells |
| --- | --- | --- | --- | --- | --- | --- |
| `linux_connector/lola_connector/__init__.py` | Python / package surface | Re-exports ethernet, backend, media, runtime, protocol symbols. | adapter | internal package modules | active | Large re-export surface |
| `linux_connector/lola_connector/backends.py` | Python / backend layer | Audio/video capture/playback/display protocols and concrete subprocess/memory/test backends. | adapter | `asyncio`, `dataclasses`, subprocess protocols | active | Large lifecycle-heavy module |
| `linux_connector/lola_connector/cli.py` | Python / CLI entry | Parser, CLI flags, validation, top-level runtime dispatch. | entrypoint | `argparse`, `asyncio`, package modules | active | Large branching CLI surface |
| `linux_connector/lola_connector/connector.py` | Python / session/connectivity runtime | `Session`, status/quick-connect results, control/media session management. | runtime | `asyncio`, `socket`, `dataclasses` | active | Central complex module |
| `linux_connector/lola_connector/ethernet.py` | Python / packet helper | MAC/IP/UDP helpers and ethernet+IPv4+UDP frame builders. | adapter | `ipaddress`, `struct` | active | none |
| `linux_connector/lola_connector/media.py` | Python / media codec | Frame serialization, fragmentation, parsing, reassembly support. | adapter | `dataclasses`, `logging`, `math`, `struct` | active | Core codec complexity |
| `linux_connector/lola_connector/protocol.py` | Python / control protocol | `MediaSettings`, control-message encode/decode, defaults, validation. | domain logic | `dataclasses`, `ipaddress`, `struct`, `.media` | active | Broad protocol surface |
| `linux_connector/lola_connector/runtime.py` | Python / runtime loop | `RuntimeStats`, backend protocols, `LolaLinuxRuntime` media/control loop. | runtime | `asyncio`, `socket`, package backends | active | Cleanup/lifecycle complexity |
| `linux_connector/lola_connector/selftest.py` | Python / self-test runner | Local loopback capability checks and bidirectional self-test entrypoint. | test | package backends, connector, protocol, runtime | active | Environment-sensitive integration support |

### Other linux_connector code

| File | Language/type | Responsibility / main exports | Runtime role | Dependencies | Status | Smells |
| --- | --- | --- | --- | --- | --- | --- |
| `linux_connector/__init__.py` | Python / package marker | Package marker for linux connector tree. | config | none | active | none |
| `linux_connector/tools/lola_packet_decoder.py` | Python / tool | Packet decoder utility for connector debugging. | script | Python stdlib | active | Tooling-only code path |
| `linux_connector/tests/conftest.py` | Python / test support | Shared pytest fixtures/configuration. | test | `pytest` | active | none |
| `linux_connector/tests/test_codec.py` | Python / tests | Codec, fragmentation, packet parsing coverage. | test | `pytest`, package codecs | active | none |
| `linux_connector/tests/test_process_backends.py` | Python / tests | Process backend lifecycle and subprocess edge-case coverage. | test | `pytest`, backends | active | none |
| `linux_connector/tests/test_process_runtime.py` | Python / tests | Runtime/process orchestration coverage. | test | `pytest`, runtime | active | none |
| `linux_connector/tests/test_runtime_contracts.py` | Python / tests | Runtime/control/media contract and integration-like coverage. | test | `pytest`, runtime, protocol | active | none |

## scripts/ and script/

### `scripts/`

| File | Language/type | Responsibility / main exports | Runtime role | Dependencies | Status | Smells |
| --- | --- | --- | --- | --- | --- | --- |
| `scripts/README.md` | Markdown / docs | Operator-facing inventory for helper scripts. | config | none | active | none |
| `scripts/build-local-ultragrid-docker.sh` | Shell / script | Build local UltraGrid Docker image. | script | Docker | active | external-env dependency |
| `scripts/code-line-budget-exceptions.txt` | Text / policy | Exceptions list for code-line budget tests. | config | none | active | policy can drift |
| `scripts/compare-local-jacktrip-parity-docker.sh` | Shell / script | Docker-based JackTrip parity comparison harness. | script | Docker, repo scripts | active | environment-heavy |
| `scripts/compare-local-ultragrid-parity-docker.sh` | Shell / script | Docker-based UltraGrid parity comparison harness. | script | Docker, repo scripts | active | environment-heavy |
| `scripts/compare-local-ultragrid-parity-native.sh` | Shell / script | Native UltraGrid parity comparison harness. | script | local executables | active | environment-heavy |
| `scripts/export-release-candidate.sh` | Shell / release helper | Export curated release-candidate tree and strip generated/vendor-only artifacts. | script | shell utilities | active | Release packaging is policy-sensitive |
| `scripts/open-lola-jacktrip-docker-client.sh` | Shell / client helper | JackTrip Docker client bootstrap. | script | Docker | unclear | Compatibility/helper lane |
| `scripts/open-lola-jacktrip-docker-policy.sh` | Shell / policy helper | Required Docker image policy for JackTrip lane. | config | shell | active | none |
| `scripts/open-lola-ultragrid-docker-client.sh` | Shell / client helper | UltraGrid Docker client bootstrap. | script | Docker | unclear | Compatibility/helper lane |
| `scripts/open-lola-ultragrid-docker-policy.sh` | Shell / policy helper | Required Docker image policy for UltraGrid lane. | config | shell | active | none |
| `scripts/open-lola-ultragrid-native-client.sh` | Shell / client helper | Native UltraGrid client bootstrap. | script | local executables | unclear | Compatibility/helper lane |
| `scripts/release-boundary-policy.txt` | Text / policy | Release-boundary policy document consumed by verification tooling. | config | none | active | none |
| `scripts/run-local-jacktrip-rxtx-docker.sh` | Shell / harness | Local JackTrip RX/TX docker run. | script | Docker | active | environment-heavy |
| `scripts/run-local-ultragrid-rxtx-docker.sh` | Shell / harness | Local UltraGrid RX/TX docker run with metrics capture. | script | Docker, Python helpers | active | environment-heavy |
| `scripts/run-local-ultragrid-rxtx-native.sh` | Shell / harness | Local UltraGrid RX/TX native run with metrics capture. | script | local executables | active | environment-heavy |
| `scripts/run-reference-peer-parity-gate.sh` | Shell / gate | Reference-peer parity gate runner. | script | shell utilities | active | body not reviewed |
| `scripts/start-local-jacktrip-docker.sh` | Shell / bootstrap | Start local JackTrip docker helper. | script | Docker | active | environment-heavy |
| `scripts/start-local-ultragrid-docker.sh` | Shell / bootstrap | Start local UltraGrid docker helper. | script | Docker | active | environment-heavy |
| `scripts/stress-local-ultragrid-parity-docker.sh` | Shell / stress harness | Stress UltraGrid docker parity lane. | script | Docker | active | environment-heavy |
| `scripts/stress-local-ultragrid-parity-native.sh` | Shell / stress harness | Stress UltraGrid native parity lane. | script | local executables | active | environment-heavy |
| `scripts/verify-docs.sh` | Shell / verification | Entrypoint for docs verification. | script | Python verifier | active | none |
| `scripts/verify-release-hygiene.sh` | Shell / verification | Release hygiene policy and repository checks. | script | shell utilities | active | policy-heavy |
| `scripts/verify-release-readiness.sh` | Shell / verification | End-to-end release readiness probe orchestration. | script | built CLI, shell utilities | active | Large orchestrator |
| `scripts/ultragrid-docker/Dockerfile` | Dockerfile / build config | Docker image definition for UltraGrid parity lane. | config | Docker | active | external dependency |
| `scripts/lib/common.sh` | Shell / shared library | Common shell helpers. | adapter | shell | active | none |
| `scripts/lib/extract-preflight-executable.py` | Python / helper | Extracts executable information from JSON/report input. | script | `json`, `sys` | active | none |
| `scripts/lib/parity.sh` | Shell / shared library | Parity timing/assert/log helpers. | adapter | shell | active | helper sprawl |
| `scripts/lib/write-connection-metrics.py` | Python / helper | Writes connection metrics JSON. | script | `json`, `sys` | active | none |
| `scripts/lib/write-ultragrid-parity-metrics.py` | Python / helper | Parses UltraGrid runtime text into parity metrics. | script | `argparse`, `json`, `re`, `pathlib` | active | parsing logic is format-sensitive |
| `scripts/verify_docs/__init__.py` | Python / package marker | Package marker for docs verifier. | config | none | active | none |
| `scripts/verify_docs/__main__.py` | Python / entrypoint | Python `-m` entrypoint for docs verifier. | entrypoint | `.main` | active | none |
| `scripts/verify_docs/archive_inventory.py` | Python / archive checks | Archive inventory and archive-doc pattern checks. | script | `re`, `sys`, `pathlib` | active | repo-structure coupling |
| `scripts/verify_docs/archive_topology.txt` | Text / verifier data | Archive topology reference data. | config | none | active | static data drift risk |
| `scripts/verify_docs/constants.py` | Python / constants | Root paths and verifier constants. | config | `pathlib` | active | none |
| `scripts/verify_docs/main.py` | Python / verifier main | Main docs verifier dispatcher with Windows/doc checks. | script | internal verifier modules | active | Central policy hub |
| `scripts/verify_docs/markdown_checks.py` | Python / verifier checks | Markdown link/path checks. | script | `re`, `pathlib`, `urllib.parse` | active | repo-structure coupling |
| `scripts/verify_docs/windows_binary_checks.py` | Python / verifier checks | Windows PE inventory/hash/metadata checks. | script | `json`, `re`, `subprocess` | active | niche platform policy surface |
| `scripts/verify_docs/windows_control_checks.py` | Python / verifier checks | Windows control-message and file-type verification. | script | `subprocess`, verifier modules | active | niche platform policy surface |
| `scripts/verify_docs/windows_docs.py` | Python / verifier checks | Windows inventory/runtime/control documentation extraction and validation. | script | `hashlib`, `re` | active | policy-heavy |
| `scripts/verify_docs/windows_media_checks.py` | Python / verifier checks | Windows network/audio surface verification. | script | verifier modules | active | niche platform policy surface |

### `script/`

| File | Language/type | Responsibility / main exports | Runtime role | Dependencies | Status | Smells |
| --- | --- | --- | --- | --- | --- | --- |
| script/build_and_run.sh | Shell / bundle helper | Legacy-style app bundle build/run/verify helper. | script | SwiftPM, shell utilities | active | Compatibility lane; multi-purpose script |
| script/build_cli_app_bundle.sh | Shell / bundle helper | CLI/app bundle assembly helper. | script | SwiftPM, shell utilities | active | compatibility/packaging lane |

## Tests/OpenLolaCoreTests

The Swift test suite is broad and mostly contract-oriented. It skews toward report-schema validation, protocol codecs, runtime smoke paths, and inventory/policy gates rather than end-user UI behavior.

| Area | Representative test files | Coverage pattern |
| --- | --- | --- |
| Contracts / core validation | `OpenLolaContractsTargetTests`, `MeasurementMethodologyTests`, `CapabilitySummaryTests`, `KeyValueArgumentParserTests`, `ValidationPrimitivesTests`, `ReportSchemaInventoryTests`, `VerdictValidationPolicyTests` | Strong schema/validation coverage for small core types and report policies |
| Audio codecs / CoreAudio / loopback | `OpusCELTLowDelayCodecTests`, `CoreAudioInventoryTests`, `AudioLoopbackRunTests`, `DirectAudioMediaRouterTests`, `AudioOpusCeltLowDelayPacketTests` | Good unit coverage for codecs, inventories, and loopback/report shaping |
| MADI | `MadiFullDuplexSessionTests`, `MadiReceiveTests`, `MadiReceiveSourceAndReportTests`, `MadiTransmitTests`, `RmeFastestAudioPathTests` | Good contract coverage; likely synthetic rather than real hardware coverage |
| Realtime audio | `RealtimeAudioEngineTests`, `RealtimeAudioPacketHandoffTests`, `DirectPeerAudioPayloadRingTests`, `DirectPeerRealtimeAudioGraphTests`, `DirectPeerRealtimeAudioGraphRxBufferingTests` | Focused low-level buffering/handoff/runtime tests on critical audio path |
| Timing / latency / buffering | `MediaClockTests`, `RxBufferingTests`, `LatencyProfileTests`, `LatencyBenchmarkReportTests`, `LatencyTuningReportTests`, `DriftPlc*Tests`, `ClockDriftSimulationTests` | Strong math/policy/report coverage for timing subsystem |
| Video | `VideoCaptureReportTests`, `VideoTransportRunnerTests`, `VideoTransportReportTests`, `VideoTransportReportPolicyTests`, `JPEGXSReferenceCodecTests`, `MultiVideoTransportTests`, `Blackmagic*Tests` | Good report/codec/runtime coverage; hardware output still likely partially synthetic |
| Connectors / compatibility | `JackTrip*Tests`, `UltraGrid*Tests`, `ExternalConnector*Tests`, `LoLaCompatibility*Tests`, `LoLaLive*Tests`, `LoLaVideoPayloadProviderTests` | Heavy compatibility, handshake, and report coverage |
| Network / NAT / RTP / UDP | `AES67ST2110L24TransportTests`, `UdpPcm*Tests`, `UdpMediaTransportTests`, `NetworkDiagnosticsTests`, `NetworkAoipCertificationTests`, `NatFriendlyRouteTests` | Good protocol and localhost-path coverage |
| Direct P2P / peer sessions | `PeerSessionRunner*Tests`, `DirectPeerSession*Tests`, `MacToMac*Tests`, `EndpointLoopbackReportTests`, `DirectP2PLocalhostSmoke`-related tests | Broad session/report/plan/preflight coverage |
| Platform / app shell | `NativeAppShell*Tests`, `AppShellBehaviorTests`, `AppShellSlice05Tests`, `NativeAppShellWindowsLoLaTests` | Strong contract coverage for app-shell backend, minimal direct SwiftUI view coverage |
| Release / readiness / inventories / scripts | `OpenSourceReleaseReadinessTests`, `FieldReadyRuntimeProofTests`, `Goal*Tests`, `ReleaseHardeningTests`, `ReleaseArtifactHygieneContractTests`, `VerificationTooling*Tests`, `DocsVerifierPolicyTests`, `CodeLineBudgetTests`, `SourceOwnershipInventoryTests`, `CLICommandInventoryTests`, `FixtureSmokeMatrixTests` | Extensive policy/inventory/gate coverage |
| Test support files | `*+TestSupport.swift`, shared fixture builders, reserved port helpers, loopback helpers | Shared harness/support code for synthetic and socket-heavy tests |

Conspicuous gaps:
- Little obvious direct coverage for SwiftUI view rendering/state transitions inside `Sources/open-lola-app/`.
- Hardware-backed capture, device I/O, and external-tool parity lanes still appear to rely heavily on synthetic/localhost evidence.
- Many report/inventory files are tested for schema, not necessarily for field freshness against live codepaths.

---

## Summary: Highest-Risk Files
- `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraphCallbacks.swift` — CoreAudio callback boundary.
- `Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexRuntime.swift` — duplex timing/correction orchestration.
- `Sources/OpenLolaCore/Audio/Routing/AudioLoopbackRun.swift` — hardware + atomics + loopback runtime.
- `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVSocketRunner.swift` and `DirectPeerSessionAVAudioLoops.swift` — direct-peer AV runtime core.
- `Sources/OpenLolaCore/Network/RTP/AES67ST2110L24Transport.swift` — packet/codec/SDP/state bundled together.
- `Sources/OpenLolaCore/Release/RecordingSessionLiveCapture.swift` — live capture, CoreAudio, atomics, media frameworks.
- `Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridEncryption.swift` — crypto boundary.
- `linux_connector/lola_connector/connector.py` and `runtime.py` — Python session/runtime heart.
- `Sources/open-lola/Commands/Network/NetworkCommands.swift` — oversized CLI command router.
- `Sources/open-lola-app/AppExecutionController.swift` and `OpenLolaApp.swift` — app-side state orchestration.

## Summary: Likely Dead Files
These are only candidates, not confirmed dead code:
- `Sources/OpenLolaCore/Release/CurrentEvidenceStatusMatrix.swift` — static matrix/report inventory style file.
- `Sources/OpenLolaCore/Release/LoLaParityDeferredFeatures.swift` — deferred-feature ledger rather than runtime.
- `Sources/OpenLolaCore/Core/OpenLolaContractsAliases.swift` — alias layer that may only preserve older naming/import patterns.
- `Sources/OpenLolaCore/Audio/MADI/RmeFastestAudioPath.swift` and `Sources/OpenLolaCore/Video/BlackmagicOutputBoundary.swift` — specialized evidence boundaries that may be niche or legacy.
- script/build_and_run.sh — still documented as active, but clearly a compatibility/legacy-feeling assembly lane.

What would prove deadness: call-site grep across CLI/app/tests, removal from inventories/docs, and lack of validator/report references.

## Summary: Likely Overcomplicated Files
- `Sources/OpenLolaCore/Control/LightingFixtureGate.swift`
- `Sources/OpenLolaCore/Evidence/ReferenceRigReport.swift`
- `Sources/OpenLolaCore/Benchmarks/E2E/E2EBenchmarkReport.swift`
- `Sources/OpenLolaCore/Benchmarks/Performance/PerformanceAuditReport.swift`
- `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorParsingDefaults.swift`
- `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityMediaCodec.swift`
- `Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteHelpers.swift`
- `Sources/OpenLolaCore/Protocol/SessionControlMessage.swift`
- `Sources/OpenLolaCore/Support/Inventories/SourceOwnershipInventory.swift`
- `scripts/verify_docs/main.py`

## Summary: Likely Deprecated Compatibility Paths
- `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibility*.swift` cluster.
- `Sources/OpenLolaCore/Connectors/JackTrip/JackTripCompatibility.swift` and adjacent auxiliary/advanced-mode helpers.
- `Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridCompatibility.swift`.
- `Sources/OpenLolaCore/Network/P2P/MacToMac*` reports/certification flows.
- Docker/native parity helper scripts in `scripts/` and bundle helpers in `script/`.

These may still be required; “deprecated” here means compatibility-oriented or legacy-looking, not safe to remove.

## Summary: Recommended Next Audit Targets
1. `Sources/OpenLolaCore/Network/P2P/` direct-peer AV runtime cluster.
2. `Sources/OpenLolaCore/Audio/Realtime/` CoreAudio callback and ring-buffer paths.
3. `Sources/OpenLolaCore/Release/RecordingSession*` live capture/artifact pipeline.
4. `Sources/OpenLolaCore/Connectors/LoLa/` compatibility surface versus active runtime requirements.
5. `Sources/open-lola-app/` controller/state files (`AppExecutionController`, `AppShellRootView`, preview services).
6. Inventory/report files in `Support/Inventories/` and `Release/` for freshness vs real call sites.
7. `linux_connector/lola_connector/connector.py` + `runtime.py` for lifecycle and protocol parity drift.

## Summary: Coverage Gaps and Uncertainty
- This index is based on key-file reads, header/first-100-line scans for larger files, file-name/export inspection, and test/script inventories.
- Many helper, validation, and report-builder files were only partially inspected; when exact usage was unclear they are marked `unclear` rather than guessed active/inactive.
- “Likely dead”, “overcomplicated”, and “deprecated compatibility” sections are hypotheses for audit prioritization, not removal recommendations.
- A true cleanup plan still needs call-site tracing (`grep`/symbol references), CLI registration checks, app navigation checks, and test-to-source mapping for every candidate file.
