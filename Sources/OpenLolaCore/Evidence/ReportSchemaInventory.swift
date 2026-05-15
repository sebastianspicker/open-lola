import Foundation

public enum ReportEvidenceClass: String, Codable, Sendable {
    case synthetic
    case sourceLevel
    case measured
    case cleanMac
    case externalWitnessed
}

public struct ReportSchemaInventoryEntry: Codable, Equatable, Sendable {
    public let schemaName: String
    public let schemaFamily: String
    public let schemaVersion: Int
    public let schemaChangePolicy: String
    public let evidenceClass: ReportEvidenceClass
    public let sourceFile: String
    public let validationFiles: [String]
    public let validatorCommands: [String]
    public let fixtureGroup: String?
    public let syntheticSmokeCommand: String?
    public let relatedTestFiles: [String]
    public let passRequiresMeasuredEvidence: Bool
    public let falsePassFixtureCount: Int
    public let notes: String

    public init(
        schemaName: String,
        schemaFamily: String,
        schemaVersion: Int = 1,
        schemaChangePolicy: String = "Increment schemaVersion when the JSON contract changes; update validators, fixtures, and related tests in the same change.",
        evidenceClass: ReportEvidenceClass,
        sourceFile: String,
        validationFiles: [String] = [],
        validatorCommands: [String] = [],
        fixtureGroup: String? = nil,
        syntheticSmokeCommand: String? = nil,
        relatedTestFiles: [String],
        passRequiresMeasuredEvidence: Bool,
        falsePassFixtureCount: Int = 0,
        notes: String
    ) {
        self.schemaName = schemaName
        self.schemaFamily = schemaFamily
        self.schemaVersion = schemaVersion
        self.schemaChangePolicy = schemaChangePolicy
        self.evidenceClass = evidenceClass
        self.sourceFile = sourceFile
        self.validationFiles = validationFiles
        self.validatorCommands = validatorCommands
        self.fixtureGroup = fixtureGroup
        self.syntheticSmokeCommand = syntheticSmokeCommand
        self.relatedTestFiles = relatedTestFiles
        self.passRequiresMeasuredEvidence = passRequiresMeasuredEvidence
        self.falsePassFixtureCount = falsePassFixtureCount
        self.notes = notes
    }
}

public struct ReportSchemaInventorySummary: Codable, Equatable, Sendable {
    public let schemaCount: Int
    public let validatorCommandCount: Int
    public let fixtureBackedSchemaCount: Int
    public let measuredEvidenceRequiredCount: Int
    public let cleanMacGateCount: Int
    public let falsePassFixtureCount: Int
}

public struct ReportSchemaInventoryReport: PrettyJSONCodable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let verdict: MeasurementVerdict
    public let summary: ReportSchemaInventorySummary
    public let schemas: [ReportSchemaInventoryEntry]
    public let notes: String
}

public enum ReportSchemaInventory {
    public static func report() -> ReportSchemaInventoryReport {
        ReportSchemaInventoryReport(
            id: "c03-report-schema-inventory",
            title: "C03 report validator and evidence schema inventory",
            verdict: .partial,
            summary: summary(),
            schemas: entries,
            notes: "Executable report schema index. It documents validation ownership and evidence class; it does not claim real release readiness."
        )
    }

    public static func summary() -> ReportSchemaInventorySummary {
        ReportSchemaInventorySummary(
            schemaCount: entries.count,
            validatorCommandCount: entries.flatMap(\.validatorCommands).count,
            fixtureBackedSchemaCount: entries.filter { $0.fixtureGroup != nil }.count,
            measuredEvidenceRequiredCount: entries.filter(\.passRequiresMeasuredEvidence).count,
            cleanMacGateCount: entries.filter { $0.evidenceClass == .cleanMac }.count,
            falsePassFixtureCount: entries.map(\.falsePassFixtureCount).reduce(0, +)
        )
    }

    public static let entries: [ReportSchemaInventoryEntry] = [
        schema("ReferenceRigReport", "hardware baseline", .externalWitnessed, "Sources/OpenLolaCore/Evidence/ReferenceRigReport.swift", validation: ["Sources/OpenLolaCore/Evidence/ReferenceRigReportValidation.swift"], validators: ["validate-reference-rig-report"], fixture: "ReferenceRigReports", tests: ["Tests/OpenLolaCoreTests/ReferenceRigReportTests.swift"], measured: true, notes: "PASS requires two reference Macs, RME MADI path, direct wired profile, and DSCP classification."),
        schema("EndpointLoopbackReport", "audio endpoint loopback", .measured, "Sources/OpenLolaCore/Network/P2P/EndpointLoopbackReport.swift", validators: ["validate-loopback-report"], fixture: "EndpointLoopback", tests: ["Tests/OpenLolaCoreTests/EndpointLoopbackReportTests.swift"], measured: true, notes: "PASS requires measured loopback metrics and stable accepted buffer rows."),
        schema("RmeFastestAudioPathReport", "RME fastest audio path", .externalWitnessed, "Sources/OpenLolaCore/Audio/MADI/RmeFastestAudioPath.swift", validators: ["validate-rme-fastest-audio-report"], fixture: "RmeFastestAudioPathReports", tests: ["Tests/OpenLolaCoreTests/RmeFastestAudioPathTests.swift"], measured: true, notes: "PASS requires visible RME device, driver evidence, and accepted loopback matrix."),
        schema("RealtimeAudioEngineReport", "realtime audio engine", .measured, "Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngine.swift", validators: ["validate-realtime-audio-engine-report"], fixture: "RealtimeAudioEngineReports", smoke: "realtime-audio-synthetic-smoke", tests: ["Tests/OpenLolaCoreTests/RealtimeAudioEngineTests.swift"], measured: true, falsePass: 1, notes: "PASS rejects synthetic runs, callback allocation, unbounded handoff, and buffered playout targets."),
        schema("UdpPcmPacket", "UDP PCM packet contract", .sourceLevel, "Sources/OpenLolaCore/Network/UDP/UdpPcmPacket.swift", validators: ["validate-udp-pcm-packet"], fixture: "UdpPcmPackets", tests: ["Tests/OpenLolaCoreTests/UdpPcmPacketTests.swift"], measured: false, notes: "Packet validator proves binary contract shape, not runtime route readiness."),
        schema("UdpPcmRouteReport", "UDP PCM route", .measured, "Sources/OpenLolaCore/Network/UDP/UdpPcmRouteCertification.swift", validators: ["validate-route-report"], fixture: "UdpPcmRoutes", tests: ["Tests/OpenLolaCoreTests/UdpPcmRouteReportTests.swift"], measured: true, notes: "PASS requires measured physical route evidence and bounded packet-age metrics."),
        schema("MacToMacRouteCertificationReport", "Mac-to-Mac route certification", .measured, "Sources/OpenLolaCore/Network/P2P/MacToMacRouteCertification.swift", validators: ["validate-route-certification-report"], fixture: "MacToMacRouteCertificationReports", smoke: "route-certification-synthetic-smoke", tests: ["Tests/OpenLolaCoreTests/MacToMacRouteCertificationTests.swift"], measured: true, notes: "PASS requires direct-link route first and capture artifacts."),
        schema("UdpPcmLoopbackReport", "UDP PCM loopback", .measured, "Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackLatency.swift", validators: ["validate-udp-pcm-loopback-report", "validate-udp-pcm-loopback-session"], tests: ["Tests/OpenLolaCoreTests/UdpPcmLoopbackLatencyTests.swift"], measured: true, notes: "Session-pair validator compares two loopback reports for role, peer, port, packet-mode, and duration consistency."),
        schema("NetworkDiagnosticsReport", "network diagnostics", .sourceLevel, "Sources/OpenLolaCore/Network/Diagnostics/NetworkDiagnostics.swift", validators: ["validate-network-diagnostics-report"], tests: ["Tests/OpenLolaCoreTests/NetworkDiagnosticsTests.swift"], measured: false, notes: "Diagnostics are supporting evidence and cannot replace route certification."),
        schema("NatFriendlyRouteReport", "NAT-friendly route", .measured, "Sources/OpenLolaCore/Network/NAT/NatFriendlyRoute.swift", validators: ["validate-nat-friendly-route-report"], tests: ["Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift"], measured: true, notes: "PASS requires direct traversal, raw P2P preference, passing loopback evidence, and a raw-route baseline; rendezvous-only and relay fallback remain compatibility-only."),
        schema("DirectPeerSessionReport", "direct P2P session", .measured, "Sources/OpenLolaCore/Network/P2P/DirectPeerSessionReport.swift", validators: ["validate-direct-p2p-session-report"], tests: ["Tests/OpenLolaCoreTests/PeerSessionRunnerTests.swift"], measured: true, notes: "Direct peer session evidence covers socket-backed control agreement and media endpoint startup; PASS still requires direct-LAN evidence."),
        schema("DirectPeerTwoPeerRunPlanReport", "direct P2P two-peer run plan", .sourceLevel, "Sources/OpenLolaCore/Network/P2P/DirectPeerTwoPeerRunPlan.swift", validators: ["validate-direct-p2p-two-peer-plan-report"], tests: ["Tests/OpenLolaCoreTests/DirectPeerTwoPeerRunPlanTests.swift"], measured: false, notes: "Builds the responder/initiator command pair, explicit DirectPeerSessionReport references, and required evidence gates; PASS remains blocked until measured subordinate reports exist."),
        schema("DirectPeerTwoPeerPrototypeReport", "direct P2P two-peer prototype", .measured, "Sources/OpenLolaCore/Network/P2P/DirectPeerTwoPeerRunPlan.swift", validators: ["validate-direct-p2p-two-peer-prototype-report"], tests: ["Tests/OpenLolaCoreTests/DirectPeerTwoPeerRunPlanTests.swift"], measured: true, notes: "Aggregates two validated DirectPeerSessionReport files and optional RX proof artifacts; PASS requires both subordinate reports and both RX proofs."),
        schema("DirectPeerTwoPeerLocalRunReport", "direct P2P two-peer local supervisor", .sourceLevel, "Sources/OpenLolaCore/Network/P2P/DirectPeerTwoPeerLocalRunReport.swift", validators: ["validate-direct-p2p-two-peer-local-run-report"], tests: ["Tests/OpenLolaCoreTests/DirectPeerTwoPeerRunPlanTests.swift"], measured: false, notes: "Records dry-run or same-host supervisor launch state for the two planned peer commands; physical two-Mac PASS still requires measured subordinate reports."),
        schema("DirectPeerMeshTopologyReport", "direct P2P mesh topology", .sourceLevel, "Sources/OpenLolaCore/Network/P2P/DirectPeerMeshTopologyReport.swift", validators: ["validate-direct-p2p-mesh-topology-report"], smoke: "direct-p2p-mesh-topology-synthetic-smoke", tests: ["Tests/OpenLolaCoreTests/PeerSessionRunnerTests.swift"], measured: false, notes: "Source-level topology smoke validates three-or-more-peer endpoint and directed route shape; PASS still requires physical multi-peer media evidence."),
        schema("DirectPeerMeshRuntimeReport", "direct P2P mesh runtime", .measured, "Sources/OpenLolaCore/Network/P2P/DirectPeerMeshRuntimeReport.swift", validators: ["validate-direct-p2p-mesh-runtime-report"], tests: ["Tests/OpenLolaCoreTests/PeerSessionRunnerTests.swift"], measured: true, notes: "Localhost runtime smoke routes UDP PCM v2 audio fragments across every directed three-or-more-peer route; PASS still requires physical multi-peer media evidence."),
        schema("LatencyBenchmarkReport", "latency benchmark", .measured, "Sources/OpenLolaCore/Benchmarks/Latency/LatencyBenchmarkReport.swift", validators: ["validate-latency-benchmark-report"], fixture: "LatencyBenchmarkReports", smoke: "latency-benchmark-synthetic-smoke", tests: ["Tests/OpenLolaCoreTests/LatencyBenchmarkReportTests.swift"], measured: true, notes: "PASS requires measured critical-path evidence and one-way threshold compliance."),
        schema("RxBufferBenchmarkReport", "RX buffer benchmark", .measured, "Sources/OpenLolaCore/Timing/RxBufferBenchmarkReport.swift", validators: ["validate-rx-buffer-benchmark-report"], tests: ["Tests/OpenLolaCoreTests/RxBufferingTests.swift"], measured: true, notes: "Local runtime benchmark covers all RX profiles; PASS still requires same-route two-Mac physical benchmark evidence."),
        schema("LatencyTuningReport", "latency tuning", .measured, "Sources/OpenLolaCore/Timing/LatencyTuningReport.swift", validators: ["validate-latency-tuning-report"], fixture: "LatencyTuningReports", smoke: "latency-tuning-synthetic-smoke", tests: ["Tests/OpenLolaCoreTests/LatencyTuningReportTests.swift"], measured: true, notes: "PASS requires baseline comparison and evidence for promoted latency changes."),
        schema("DriftPlcReport", "drift and PLC", .measured, "Sources/OpenLolaCore/Timing/DriftPlcReport.swift", validators: ["validate-drift-plc-report"], fixture: "DriftPlcReports", smoke: "drift-plc-synthetic-smoke", tests: ["Tests/OpenLolaCoreTests/DriftPlcReportTests.swift"], measured: true, notes: "PASS rejects callback correction, retransmission waits, hidden playout growth, and target-depth growth."),
        schema("DriftPlcFixedTargetCertificationReport", "fixed-target drift PLC certification", .measured, "Sources/OpenLolaCore/Timing/DriftPlcFixedTargetCertification.swift", validators: ["validate-drift-plc-certification-report"], fixture: "DriftPlcFixedTargetCertificationReports", smoke: "drift-plc-certification-synthetic-smoke", tests: ["Tests/OpenLolaCoreTests/DriftPlcFixedTargetCertificationFixtures+TestSupport.swift"], measured: true, notes: "PASS requires accepted route, realtime engine, drift report, and LoLa baseline comparison."),
        schema("AoipEvaluationReport", "AoIP evaluation", .measured, "Sources/OpenLolaCore/Network/Diagnostics/AoipEvaluationReport.swift", validators: ["validate-aoip-report"], fixture: "AoipEvaluationReports", smoke: "aoip-synthetic-smoke", tests: ["Tests/OpenLolaCoreTests/AoipEvaluationReportTests.swift"], measured: true, notes: "PASS requires measured superiority and same-path baseline; AoIP cannot replace direct-first defaults."),
        schema("NetworkAoipCertificationReport", "network AoIP certification", .measured, "Sources/OpenLolaCore/Network/Diagnostics/NetworkAoipCertification.swift", validators: ["validate-network-aoip-certification-report"], fixture: "NetworkAoipCertificationReports", smoke: "network-aoip-certification-synthetic-smoke", tests: ["Tests/OpenLolaCoreTests/NetworkAoipCertificationFixtures+TestSupport.swift"], measured: true, notes: "PASS requires accepted route, drift certification, and AoIP reports."),
        schema("VideoCaptureReport", "video capture", .externalWitnessed, "Sources/OpenLolaCore/Video/VideoCaptureReport.swift", validators: ["validate-video-capture-report"], fixture: "VideoCaptureReports", smoke: "video-capture-synthetic-smoke", tests: ["Tests/OpenLolaCoreTests/VideoCaptureReportTests.swift"], measured: true, notes: "PASS requires production capture evidence and audio impact metrics."),
        schema("AVFoundationVideoDeviceInventoryReport", "video capture inventory", .sourceLevel, "Sources/OpenLolaCore/Video/VideoCaptureAVFoundation.swift", validators: ["validate-video-capture-inventory"], tests: ["Tests/OpenLolaCoreTests/VideoCaptureReportTests.swift"], measured: false, notes: "Inventory records device visibility and Blackmagic candidate detection; it is not a capture PASS."),
        schema("VideoTransportReport", "video transport", .measured, "Sources/OpenLolaCore/Video/VideoTransportReport.swift", validators: ["validate-video-transport-report"], fixture: "VideoTransportReports", smoke: "video-transport-synthetic-smoke", tests: ["Tests/OpenLolaCoreTests/VideoTransportReportTests.swift", "Tests/OpenLolaCoreTests/VideoTransportRunnerTests.swift"], measured: true, notes: "Socket-backed UDP raw-fragment reports exist, including staged multi-stream test-pattern probes; PASS still requires Blackmagic or ATEM source/output, raw route baseline, AV sync, and audio-protective degradation."),
        schema("IntegratedAvReport", "integrated AV", .measured, "Sources/OpenLolaCore/Integration/IntegratedAvReport.swift", validation: ["Sources/OpenLolaCore/Integration/IntegratedAvReportValidation.swift"], validators: ["validate-integrated-av-report"], fixture: "IntegratedAvReports", smoke: "integrated-av-synthetic-smoke", tests: ["Tests/OpenLolaCoreTests/IntegratedAvReportTests.swift"], measured: true, falsePass: 1, notes: "PASS rejects synthetic reports and requires audio-only baseline, P04 proof, video/control evidence, and stable audio metrics."),
        schema("IntegratedProfileReport", "integrated profile", .measured, "Sources/OpenLolaCore/Integration/IntegratedProfileReport.swift", validators: ["validate-integrated-profile-report"], fixture: "IntegratedProfileReports", smoke: "integrated-profile-synthetic-smoke", tests: ["Tests/OpenLolaCoreTests/IntegratedProfileReportTests.swift", "Tests/OpenLolaCoreTests/IntegratedProfileRunEvidenceTests.swift"], measured: true, notes: "integrated-profile-run can aggregate measured runtime reports; PASS still requires physical subordinate evidence and full matrix benchmarks."),
        schema("HardwareValidationReport", "hardware validation", .externalWitnessed, "Sources/OpenLolaCore/Evidence/HardwareValidationReport.swift", validators: ["validate-hardware-validation-report"], fixture: "HardwareValidationReports", smoke: "hardware-validation-synthetic-smoke", tests: ["Tests/OpenLolaCoreTests/HardwareValidationReportTests.swift"], measured: true, notes: "PASS requires RME MADI, Blackmagic/ATEM identity, fastest profile acceptance, and campus route evidence."),
        schema("OscCueReport", "OSC cue control", .externalWitnessed, "Sources/OpenLolaCore/Control/OscCueProbe.swift", validators: ["validate-osc-cue-report"], fixture: "OscCueReports", smoke: "osc-cue-synthetic-smoke", tests: ["Tests/OpenLolaCoreTests/OscCueReportTests.swift"], measured: true, notes: "PASS requires live/external peer evidence and no audio-latency impact."),
        schema("AtemReadOnlyControlReport", "ATEM read-only control", .externalWitnessed, "Sources/OpenLolaCore/Control/AtemReadOnlyControl.swift", validators: ["validate-atem-control-report"], tests: ["Tests/OpenLolaCoreTests/IntegratedAvReportTests.swift"], measured: true, notes: "PASS must keep commands disarmed and evidence read-only control status."),
        schema("LightingFixtureGateReport", "lighting fixture gate", .externalWitnessed, "Sources/OpenLolaCore/Control/LightingFixtureGateReport.swift", validators: ["validate-lighting-gate-report"], fixture: "LightingFixtureGateReports", smoke: "lighting-gate-synthetic-smoke", tests: ["Tests/OpenLolaCoreTests/LightingFixtureGateTests.swift"], measured: true, notes: "PASS requires armed isolated universe, fixture owner match, and audio-safe policy."),
        schema("NativeAppShellReport", "macOS app shell", .sourceLevel, "Sources/OpenLolaCore/Platform/NativeAppShell.swift", validators: ["validate-native-app-shell-report"], fixture: "NativeAppShellReports", smoke: "native-app-shell-synthetic-smoke", tests: ["Tests/OpenLolaCoreTests/NativeAppShellTests.swift"], measured: false, notes: "Source-level app shell report ensures UI does not own realtime paths."),
        schema("NativeAppShellSurfaceProbeReport", "macOS app shell surface", .sourceLevel, "Sources/OpenLolaCore/Platform/NativeAppShellSurfaceContract.swift", validators: ["validate-native-app-shell-surface-probe-report"], tests: ["Tests/OpenLolaCoreTests/NativeAppShellTests.swift"], measured: false, notes: "C11 source-level SwiftUI surface probe; PASS remains blocked until a launched app window is observed and recorded."),
        schema("RecordingSessionArtifactReport", "recording session artifacts", .sourceLevel, "Sources/OpenLolaCore/Release/RecordingSessionArtifacts.swift", validators: ["validate-recording-session-report"], fixture: "RecordingSessionArtifacts", smoke: "recording-session-synthetic-smoke", tests: ["Tests/OpenLolaCoreTests/RecordingSessionArtifactTests.swift"], measured: false, notes: "Opt-in raw audio/video artifact entries are validated separately; PASS still requires side-lane artifact writing without realtime file I/O, hidden playout growth, or missing physical recording evidence."),
        schema("PackagingFieldTestReport", "packaging field test", .cleanMac, "Sources/OpenLolaCore/Release/PackagingFieldTest.swift", validation: ["Sources/OpenLolaCore/Release/PackagingFieldTestValidation.swift"], validators: ["validate-packaging-field-report"], fixture: "PackagingFieldTests", smoke: "packaging-field-synthetic-smoke", tests: ["Tests/OpenLolaCoreTests/PackagingFieldTestTests.swift"], measured: true, falsePass: 5, notes: "PASS requires Developer ID, notarization, stapled ticket, Gatekeeper, package hashes, and clean-Mac install evidence."),
        schema("FieldReadyRuntimeProofReport", "field-ready runtime proof", .cleanMac, "Sources/OpenLolaCore/Release/FieldReadyRuntimeProof.swift", validation: ["Sources/OpenLolaCore/Release/FieldReadyRuntimeProofValidation.swift"], validators: ["validate-field-runtime-proof"], fixture: "FieldReadyRuntimeProofs", smoke: "field-runtime-synthetic-smoke", tests: ["Tests/OpenLolaCoreTests/FieldReadyRuntimeProofTests.swift"], measured: true, falsePass: 1, notes: "PASS requires signed app runtime, Gatekeeper distribution, clean-Mac target, RME visibility, ATEM status, and CLI report-writing evidence."),
        schema("LoLaParityDeferredLedgerReport", "LoLa parity deferred ledger", .sourceLevel, "Sources/OpenLolaCore/Release/LoLaParityDeferredFeatures.swift", validators: ["validate-lola-parity-deferred-ledger"], fixture: "LoLaParityDeferredLedgers", tests: ["Tests/OpenLolaCoreTests/LoLaParityDeferredFeaturesTests.swift"], measured: false, notes: "Ledger documents deferred compatibility features and blocks PASS with native-default or latency-risk changes."),
        schema("ExternalConnectorReport", "external connector source contracts", .sourceLevel, "Sources/OpenLolaCore/Connectors/Core/ExternalConnectorReport.swift", validators: ["validate-external-connector-report"], fixture: "ExternalConnectorReports", smoke: "external-connector-synthetic-smoke", tests: ["Tests/OpenLolaCoreTests/ExternalConnectorReportTests.swift"], measured: false, notes: "Code-only connector report. LoLa includes recovered control grammar, outer Ethernet/IPv4/UDP wire framing, little-endian media bodies, normal fragments, audio block sizing, video prelude-plus-fragment packetization, and passive capture media classification; real-world connector interoperability remains PARTIAL until measured external endpoint evidence exists."),
        schema("ExternalConnectorSessionReport", "external connector TX/RX session", .sourceLevel, "Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSession.swift", validation: ["Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSessionRunner.swift", "Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSessionRuntime.swift"], validators: ["validate-external-connector-session-report"], tests: ["Tests/OpenLolaCoreTests/ExternalConnectorSessionTests.swift", "Tests/OpenLolaCoreTests/ExternalConnectorAvMatrixTests.swift", "Tests/OpenLolaCoreTests/ExternalConnectorProcessGroupTests.swift"], measured: false, notes: "Protocol-aware TX/RX launch reports for LoLa numeric-SID status-check and quick-connect ACK control over UDP or TCP, advertised-host preflight notes, post-control LoLa UDP socket media TX/RX, optional LoLa raw-link media TX/RX wiring, static media-envelope facts, outer Ethernet/IPv4/UDP wire-frame codec, visible auxiliary control messages, configurable UltraGrid uv capture/playback/display modules, JackTrip RtAudio, JackTrip-plus-auxiliary-UltraGrid AV mode, and structured FAIL reports for early clean or non-zero external process exits. PASS remains blocked until measured external endpoint evidence exists."),
        schema("ExternalConnectorConnectionPlanReport", "external connector bidirectional connection plan", .sourceLevel, "Sources/OpenLolaCore/Connectors/NMP/ExternalConnectorConnectionPlan.swift", validators: ["validate-external-connector-connection-plan"], tests: ["Tests/OpenLolaCoreTests/ExternalConnectorConnectionPlanTests.swift"], measured: false, notes: "Builds explicit bidirectional endpoint commands with concrete run-directory outputs, exact shell-command validation, connector-scoped executable preflight commands, peer-specific LoLa raw-link tuples, and JackTrip P2P server/client endpoints. It is an executable handoff plan, not interoperability proof."),
        schema("ExternalConnectorNmpPlanReport", "external connector universal NMP A/V plan", .sourceLevel, "Sources/OpenLolaCore/Connectors/NMP/ExternalConnectorNmpPlan.swift", validators: ["validate-external-connector-nmp-plan"], tests: ["Tests/OpenLolaCoreTests/ExternalConnectorNmpPlanTests.swift"], measured: false, notes: "Builds one machine-readable LoLa, MVTP/UltraGrid, and JackTrip A/V connection-plan bundle with connector-scoped preflights, endpoint commands, and LoLa-only raw-link interface/MAC propagation. Raw-link NMP inputs are rejected unless LoLa is selected. It is a universal handoff artifact, not interoperability proof."),
        schema("ExternalConnectorNmpPreflightReport", "external connector universal NMP preflight", .sourceLevel, "Sources/OpenLolaCore/Connectors/NMP/ExternalConnectorNmpPreflight.swift", validators: ["validate-external-connector-nmp-preflight"], tests: ["Tests/OpenLolaCoreTests/ExternalConnectorNmpPreflightTests.swift"], measured: false, notes: "Runs every connector-scoped executable preflight embedded in an NMP A/V plan and aggregates host readiness before endpoint attempts. It is not endpoint interoperability proof."),
        schema("ExternalConnectorNmpEndpointRunReport", "external connector universal NMP endpoint run", .sourceLevel, "Sources/OpenLolaCore/Connectors/NMP/ExternalConnectorNmpEndpointRun.swift", validators: ["validate-external-connector-nmp-endpoint-run"], tests: ["Tests/OpenLolaCoreTests/ExternalConnectorNmpEndpointRunTests.swift"], measured: false, notes: "Consumes an NMP A/V plan and runs each selected connector's local or remote side endpoint session through the existing connector runners, with an optional dry-run override and optional preflight report so discovered UltraGrid/JackTrip executables are reused. It is not bidirectional endpoint interoperability proof."),
        schema("ExternalConnectorNmpWorkflowReport", "external connector universal NMP workflow", .sourceLevel, "Sources/OpenLolaCore/Connectors/NMP/ExternalConnectorNmpWorkflow.swift", validators: ["validate-external-connector-nmp-workflow"], tests: ["Tests/OpenLolaCoreTests/ExternalConnectorNmpWorkflowTests.swift"], measured: false, notes: "Single-command NMP workflow that builds the universal A/V plan, runs connector-scoped executable preflight, runs each selected connector's endpoint-side TX/RX pair concurrently, and emits all subordinate reports. It is not bidirectional endpoint interoperability proof."),
        schema("ExternalConnectorExecutablePreflightReport", "external connector executable preflight", .sourceLevel, "Sources/OpenLolaCore/Connectors/Core/ExternalConnectorExecutablePreflight.swift", validators: ["validate-external-connector-executable-preflight-report"], tests: ["Tests/OpenLolaCoreTests/ExternalConnectorExecutablePreflightTests.swift"], measured: false, notes: "Checks local executable identity for connector-scoped UltraGrid uv and JackTrip binaries so PATH collisions such as Python uv are reported before A/V endpoint attempts. It is host readiness evidence, not interoperability proof."),
        schema("LoLaCompatibilityCaptureReport", "LoLa passive capture decoder", .sourceLevel, "Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityCaptureReport.swift", validation: ["Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityMediaCodec.swift"], validators: ["validate-lola-capture-report"], tests: ["Tests/OpenLolaCoreTests/LoLaCompatibilityCaptureReportTests.swift"], measured: false, notes: "Passive pcap/pcapng decoder for LoLa control/audio/video evidence. It validates capture structure, default ports, recovered control message names, audio fragments, video preludes, video fragments, MJPEG candidates, malformed fragments, and unknown payloads without claiming real-world interoperability."),
        schema("LoLaCompatibilityPacketFixtureReport", "LoLa synthetic packet fixture generator", .sourceLevel, "Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityPacketFixture.swift", validation: ["Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityMediaCodec.swift"], validators: ["validate-lola-packet-fixture-report"], tests: ["Tests/OpenLolaCoreTests/LoLaCompatibilityPacketFixtureTests.swift"], measured: false, notes: "Generates open-lola-owned synthetic Ethernet/IPv4/UDP LoLa packet fixtures with recovered audio fragments and video prelude/fragment datagrams, then decodes optional classic pcap files through the passive capture decoder. It is not Windows LoLa capture evidence."),
        schema("LoLaCompatibilityMediaSessionReport", "LoLa media source-level TX/RX", .sourceLevel, "Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityMediaSession.swift", validation: ["Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityMediaCodec.swift", "Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityUdpMedia.swift"], validators: ["validate-lola-media-session-report"], tests: ["Tests/OpenLolaCoreTests/LoLaCompatibilityMediaSessionTests.swift"], measured: false, notes: "Source-level, post-control UDP socket, and opt-in raw-link LoLa media TX/RX generation and validation. It covers recovered Ethernet/IPv4/UDP framing, little-endian media bodies, audio normal fragments, video preludes, and video normal fragments while real Windows interoperability remains partial."),
        schema("FasterThanLoLaClosureReport", "faster-than-LoLa closure", .measured, "Sources/OpenLolaCore/Release/FasterThanLoLaClosure.swift", validators: ["validate-faster-than-lola-closure"], smoke: "faster-than-lola-closure-synthetic-smoke", tests: ["Tests/OpenLolaCoreTests/FasterThanLoLaClosureTests.swift"], measured: true, notes: "PASS requires measured LoLa baseline, latency win, no artifacts, and enough run duration."),
        schema("GoalCodewiseClosureReport", "GOAL.md codewise closure", .sourceLevel, "Sources/OpenLolaCore/Release/Goal/GoalCodewiseClosure.swift", validators: ["validate-goal-codewise-closure-report"], tests: ["Tests/OpenLolaCoreTests/GoalCodewiseClosureTests.swift"], measured: false, notes: "Codewise PASS ledger; real-world verdict remains PARTIAL because physical measurement, hardware, signing, and clean-Mac evidence live in runtime gates."),
        schema("GoalRuntimeEvidenceTemplateReport", "GOAL.md runtime evidence template", .sourceLevel, "Sources/OpenLolaCore/Release/Goal/GoalRuntimeEvidenceTemplate.swift", validators: ["validate-goal-runtime-evidence-template-report"], tests: ["Tests/OpenLolaCoreTests/GoalRuntimeEvidenceTemplateTests.swift"], measured: false, notes: "Machine-readable runtime handoff; every deliverable remains PARTIAL until physical hardware, route, signing, and clean-Mac evidence is attached."),
        schema("GoalRuntimePreflightReport", "GOAL.md runtime host preflight", .sourceLevel, "Sources/OpenLolaCore/Release/Goal/GoalRuntimePreflight.swift", validators: ["validate-goal-runtime-preflight-report"], tests: ["Tests/OpenLolaCoreTests/GoalRuntimePreflightTests.swift"], measured: false, notes: "Executable current-host blocker report; it records visible audio/video/signing prerequisites but cannot replace physical two-Mac or clean-Mac evidence."),
        schema("GoalCompletionAuditReport", "GOAL.md prompt-to-artifact completion audit", .sourceLevel, "Sources/OpenLolaCore/Release/Goal/GoalCompletionAudit.swift", validators: ["validate-goal-completion-audit-report"], tests: ["Tests/OpenLolaCoreTests/GoalCompletionAuditTests.swift"], measured: false, notes: "Traceability audit maps every product goal, Apple Silicon path, professional AV deliverable, release blocker, and verification gate to source artifacts while keeping real-world evidence partial."),
        schema("CurrentEvidenceStatusMatrixReport", "current evidence status matrix", .sourceLevel, "Sources/OpenLolaCore/Release/CurrentEvidenceStatusMatrix.swift", validators: ["validate-current-evidence-status-matrix-report"], tests: ["Tests/OpenLolaCoreTests/CurrentEvidenceStatusMatrixTests.swift"], measured: false, notes: "Machine-readable crosswalk from research, evidence matrix, reverse-engineering findings, and mac-port plan to current source status and RWT tasks; PASS remains blocked until real-world evidence is attached."),
        schema("ReleaseHardeningReport", "release hardening", .cleanMac, "Sources/OpenLolaCore/Release/ReleaseHardening.swift", validators: ["validate-release-hardening-report"], fixture: "ReleaseHardeningReports", smoke: "release-hardening-synthetic-smoke", tests: ["Tests/OpenLolaCoreTests/ReleaseHardeningTests.swift"], measured: true, falsePass: 1, notes: "PASS requires measured reports, verification gates, public-doc audit, package PASS, signing PASS, clean-Mac PASS, and no remaining partial gates."),
        schema("OpenSourceReleaseReadinessReport", "open-source release readiness", .sourceLevel, "Sources/OpenLolaCore/Release/OpenSourceReleaseReadiness.swift", validators: ["validate-open-source-release-readiness-report"], tests: ["Tests/OpenLolaCoreTests/OpenSourceReleaseReadinessTests.swift"], measured: false, notes: "PASS requires final source and documentation licenses, final notices, fixture provenance, allowlist release staging, reviewer signoff, and public approval."),
        schema("MadiReceiveSyntheticReport", "MADI receive", .sourceLevel, "Sources/OpenLolaCore/Audio/MADI/MadiReceiveReport.swift", validators: ["validate-madi-rx-report"], smoke: "madi-rx-synthetic-smoke", tests: ["Tests/OpenLolaCoreTests/MadiReceiveTests.swift"], measured: false, notes: "Synthetic receive report validates bounded buffers, overrun policy, and same-deadline recovery contracts."),
        schema("MadiFullDuplexReport", "MADI full-duplex", .sourceLevel, "Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexReport.swift", validators: ["validate-madi-full-duplex-report"], smoke: "madi-full-duplex-synthetic-smoke", tests: ["Tests/OpenLolaCoreTests/MadiFullDuplexSessionTests.swift"], measured: false, notes: "Report validates source-level and socket-backed full-duplex plus receiver-mix evidence; PASS still requires physical RME evidence."),
        schema("PerformanceAuditReport", "performance audit", .sourceLevel, "Sources/OpenLolaCore/Benchmarks/Performance/PerformanceAuditReport.swift", validation: ["Sources/OpenLolaCore/Benchmarks/Performance/PerformanceAuditReportValidation.swift"], validators: ["validate-performance-audit-report"], smoke: "performance-audit-synthetic-smoke", tests: ["Tests/OpenLolaCoreTests/PerformanceAuditTests.swift"], measured: false, notes: "PASS requires documented hot paths, worker boundaries, counter evidence, and acceleration decisions."),
        schema("E2EBenchmarkReport", "E2E benchmark", .measured, "Sources/OpenLolaCore/Benchmarks/E2E/E2EBenchmarkReport.swift", validation: ["Sources/OpenLolaCore/Benchmarks/E2E/E2EBenchmarkReportValidation.swift"], validators: ["validate-e2e-benchmark-report"], smoke: "e2e-benchmark-synthetic-smoke", tests: ["Tests/OpenLolaCoreTests/E2EBenchmarkReportTests.swift"], measured: true, notes: "PASS requires measured run, physical two-peer evidence, required profile, and no video-induced audio timing regression."),
        schema("CoreAudioInventoryReport", "CoreAudio inventory", .sourceLevel, "Sources/OpenLolaCore/Audio/CoreAudio/CoreAudioInventory.swift", fixture: "CoreAudioInventory", tests: ["Tests/OpenLolaCoreTests/CoreAudioInventoryTests.swift"], measured: false, notes: "Inventory report is source/platform discovery evidence, not runtime PASS."),
        schema("MeasurementReport", "generic measurement fixture", .sourceLevel, "Sources/OpenLolaCore/Evidence/MeasurementReport.swift", fixture: "MeasurementReports", tests: ["Tests/OpenLolaCoreTests/MeasurementReportFixtureTests.swift"], measured: false, notes: "Generic measurement fixtures preserve legacy/source contract shape for docs and validation tests."),
    ]
}

private func schema(
    _ name: String,
    _ family: String,
    _ evidence: ReportEvidenceClass,
    _ source: String,
    validation: [String] = [],
    validators: [String] = [],
    fixture: String? = nil,
    smoke: String? = nil,
    tests: [String],
    measured: Bool,
    falsePass: Int = 0,
    notes: String
) -> ReportSchemaInventoryEntry {
    ReportSchemaInventoryEntry(
        schemaName: name,
        schemaFamily: family,
        schemaVersion: 1,
        schemaChangePolicy: "Increment schemaVersion when the JSON contract changes; update validators, fixtures, and related tests in the same change.",
        evidenceClass: evidence,
        sourceFile: source,
        validationFiles: validation,
        validatorCommands: validators,
        fixtureGroup: fixture,
        syntheticSmokeCommand: smoke,
        relatedTestFiles: tests,
        passRequiresMeasuredEvidence: measured,
        falsePassFixtureCount: falsePass,
        notes: notes
    )
}
