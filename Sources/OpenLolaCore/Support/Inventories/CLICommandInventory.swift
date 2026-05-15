import Foundation

public enum CLICommandKind: String, Codable, Sendable {
    case validator
    case run
    case syntheticSmoke
    case localhostSmoke
    case inventory
    case probe
}

public struct CLICommandInventoryEntry: Codable, Equatable, Sendable {
    public let command: String
    public let kind: CLICommandKind
    public let ownerSourceFile: String
    public let parser: String
    public let validationPath: String
    public let relatedTestFiles: [String]

    public init(
        command: String,
        kind: CLICommandKind,
        ownerSourceFile: String,
        parser: String,
        validationPath: String,
        relatedTestFiles: [String]
    ) {
        self.command = command
        self.kind = kind
        self.ownerSourceFile = ownerSourceFile
        self.parser = parser
        self.validationPath = validationPath
        self.relatedTestFiles = relatedTestFiles
    }
}

public struct CLICommandInventorySummary: Codable, Equatable, Sendable {
    public let commandCount: Int
    public let validatorCount: Int
    public let runCount: Int
    public let syntheticSmokeCount: Int
    public let localhostSmokeCount: Int
}

public struct CLICommandInventoryReport: PrettyJSONCodable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let verdict: MeasurementVerdict
    public let summary: CLICommandInventorySummary
    public let commands: [CLICommandInventoryEntry]
    public let notes: String

}

public enum CLICommandInventory {
    public static func report() -> CLICommandInventoryReport {
        CLICommandInventoryReport(
            id: "c01-cli-command-inventory",
            title: "C01 CLI command router and argument parsing inventory",
            verdict: .partial,
            summary: summary(),
            commands: entries,
            notes: "Executable source-level command ownership inventory. Command behavior remains unchanged."
        )
    }

    public static func summary() -> CLICommandInventorySummary {
        CLICommandInventorySummary(
            commandCount: entries.count,
            validatorCount: count(.validator),
            runCount: count(.run),
            syntheticSmokeCount: count(.syntheticSmoke),
            localhostSmokeCount: count(.localhostSmoke)
        )
    }

    public static let entries: [CLICommandInventoryEntry] = [
        main("session-capabilities", .inventory, tests: ["Tests/OpenLolaCoreTests/SessionProtocolTests.swift"]),
        main("fixture-smoke-matrix", .inventory, tests: ["Tests/OpenLolaCoreTests/FixtureSmokeMatrixTests.swift"]),
        main("command-inventory", .inventory, tests: ["Tests/OpenLolaCoreTests/CLICommandInventoryTests.swift"]),
        main("report-schema-inventory", .inventory, tests: ["Tests/OpenLolaCoreTests/ReportSchemaInventoryTests.swift"]),
        main("goal-codewise-closure", .inventory, tests: ["Tests/OpenLolaCoreTests/GoalCodewiseClosureTests.swift"]),
        main("goal-codewise-closure-run", .run, tests: ["Tests/OpenLolaCoreTests/GoalCodewiseClosureTests.swift"]),
        main("goal-runtime-evidence-template", .inventory, tests: ["Tests/OpenLolaCoreTests/GoalRuntimeEvidenceTemplateTests.swift"]),
        main("goal-runtime-evidence-template-run", .run, tests: ["Tests/OpenLolaCoreTests/GoalRuntimeEvidenceTemplateTests.swift"]),
        main("goal-runtime-preflight", .inventory, tests: ["Tests/OpenLolaCoreTests/GoalRuntimePreflightTests.swift"]),
        main("goal-runtime-preflight-run", .run, tests: ["Tests/OpenLolaCoreTests/GoalRuntimePreflightTests.swift"]),
        main("goal-completion-audit", .inventory, tests: ["Tests/OpenLolaCoreTests/GoalCompletionAuditTests.swift"]),
        main("goal-completion-audit-run", .run, tests: ["Tests/OpenLolaCoreTests/GoalCompletionAuditTests.swift"]),
        main("current-evidence-status-matrix", .inventory, tests: ["Tests/OpenLolaCoreTests/CurrentEvidenceStatusMatrixTests.swift"]),
        main("current-evidence-status-matrix-run", .run, tests: ["Tests/OpenLolaCoreTests/CurrentEvidenceStatusMatrixTests.swift"]),
        main("realtime-audio-path-inventory", .inventory, tests: ["Tests/OpenLolaCoreTests/RealtimeAudioPathInventoryTests.swift"]),
        main("network-route-command-matrix", .inventory, tests: ["Tests/OpenLolaCoreTests/NetworkRouteCommandMatrixTests.swift"]),
        main("video-control-degrade-matrix", .inventory, tests: ["Tests/OpenLolaCoreTests/VideoControlDegradeMatrixTests.swift"]),
        main("source-ownership-inventory", .inventory, tests: ["Tests/OpenLolaCoreTests/SourceOwnershipInventoryTests.swift"]),
        main("udp-pcm-send-once", .probe, tests: ["Tests/OpenLolaCoreTests/UdpPcmPacketTests.swift"]),
        main("udp-pcm-receive-once", .probe, tests: ["Tests/OpenLolaCoreTests/UdpPcmPacketTests.swift"]),
    ]
    + networkCommands
    + milestoneValidationCommands
    + milestoneRuntimeCommands
    + [
        command("validate-madi-rx-report", .validator, "Sources/open-lola/Commands/Audio/MadiReceiveCommands.swift", ["Tests/OpenLolaCoreTests/MadiReceiveTests.swift"]),
        command("madi-rx-synthetic-smoke", .syntheticSmoke, "Sources/open-lola/Commands/Audio/MadiReceiveCommands.swift", ["Tests/OpenLolaCoreTests/MadiReceiveTests.swift"]),
        command("validate-madi-full-duplex-report", .validator, "Sources/open-lola/Commands/Audio/MadiFullDuplexCommands.swift", ["Tests/OpenLolaCoreTests/MadiFullDuplexSessionTests.swift"]),
        command("madi-full-duplex-synthetic-smoke", .syntheticSmoke, "Sources/open-lola/Commands/Audio/MadiFullDuplexCommands.swift", ["Tests/OpenLolaCoreTests/MadiFullDuplexSessionTests.swift"]),
        command("madi-full-duplex-run", .run, "Sources/open-lola/Commands/Audio/MadiFullDuplexCommands.swift", ["Tests/OpenLolaCoreTests/MadiFullDuplexSessionTests.swift"]),
        command("latency-profile-benchmark-synthetic-smoke", .syntheticSmoke, "Sources/open-lola/Commands/Audio/LatencyProfileCommands.swift", ["Tests/OpenLolaCoreTests/LatencyProfileTests.swift"]),
        command("rx-buffer-benchmark-run", .run, "Sources/open-lola/Commands/Audio/LatencyProfileCommands.swift", ["Tests/OpenLolaCoreTests/RxBufferingTests.swift"]),
        command("validate-performance-audit-report", .validator, "Sources/open-lola/Commands/Benchmarks/PerformanceCommands.swift", ["Tests/OpenLolaCoreTests/PerformanceAuditTests.swift"]),
        command("performance-audit-synthetic-smoke", .syntheticSmoke, "Sources/open-lola/Commands/Benchmarks/PerformanceCommands.swift", ["Tests/OpenLolaCoreTests/PerformanceAuditTests.swift"]),
        command("validate-e2e-benchmark-report", .validator, "Sources/open-lola/Commands/Benchmarks/E2EBenchmarkCommands.swift", ["Tests/OpenLolaCoreTests/E2EBenchmarkReportTests.swift"]),
        command("e2e-benchmark-synthetic-smoke", .syntheticSmoke, "Sources/open-lola/Commands/Benchmarks/E2EBenchmarkCommands.swift", ["Tests/OpenLolaCoreTests/E2EBenchmarkReportTests.swift"]),
        command("e2e-benchmark-run", .run, "Sources/open-lola/Commands/Benchmarks/E2EBenchmarkCommands.swift", ["Tests/OpenLolaCoreTests/E2EBenchmarkReportTests.swift"]),
    ]

    private static func count(_ kind: CLICommandKind) -> Int {
        entries.filter { $0.kind == kind }.count
    }
}

private struct CLICommandCatalogFamily: Sendable {
    var ownerSourceFile: String
    var entries: [CLICommandCatalogEntry]

    func inventoryEntries() -> [CLICommandInventoryEntry] {
        entries.map {
            command($0.name, $0.kind, ownerSourceFile, $0.relatedTestFiles)
        }
    }
}

private struct CLICommandCatalogEntry: Sendable {
    var name: String
    var kind: CLICommandKind
    var relatedTestFiles: [String]
}

private let networkCommands: [CLICommandInventoryEntry] = CLICommandCatalogFamily(
    ownerSourceFile: "Sources/open-lola/Commands/Network/NetworkCommands.swift",
    entries: [
            CLICommandCatalogEntry(name: "device-inventory", kind: .inventory, relatedTestFiles: ["Tests/OpenLolaCoreTests/CoreAudioInventoryTests.swift"]),
            CLICommandCatalogEntry(name: "validate-reference-rig-report", kind: .validator, relatedTestFiles: ["Tests/OpenLolaCoreTests/ReferenceRigReportTests.swift"]),
            CLICommandCatalogEntry(name: "validate-loopback-report", kind: .validator, relatedTestFiles: ["Tests/OpenLolaCoreTests/EndpointLoopbackReportTests.swift"]),
            CLICommandCatalogEntry(name: "validate-rme-fastest-audio-report", kind: .validator, relatedTestFiles: ["Tests/OpenLolaCoreTests/RmeFastestAudioPathTests.swift"]),
            CLICommandCatalogEntry(name: "validate-realtime-audio-engine-report", kind: .validator, relatedTestFiles: ["Tests/OpenLolaCoreTests/RealtimeAudioEngineTests.swift"]),
            CLICommandCatalogEntry(name: "audio-loopback-run", kind: .run, relatedTestFiles: ["Tests/OpenLolaCoreTests/AudioLoopbackRunTests.swift"]),
            CLICommandCatalogEntry(name: "validate-udp-pcm-packet", kind: .validator, relatedTestFiles: ["Tests/OpenLolaCoreTests/UdpPcmPacketTests.swift"]),
            CLICommandCatalogEntry(name: "validate-route-report", kind: .validator, relatedTestFiles: ["Tests/OpenLolaCoreTests/UdpPcmRouteReportTests.swift"]),
            CLICommandCatalogEntry(name: "validate-route-certification-report", kind: .validator, relatedTestFiles: ["Tests/OpenLolaCoreTests/MacToMacRouteCertificationTests.swift"]),
            CLICommandCatalogEntry(name: "validate-udp-pcm-loopback-report", kind: .validator, relatedTestFiles: ["Tests/OpenLolaCoreTests/UdpPcmLoopbackLatencyTests.swift"]),
            CLICommandCatalogEntry(name: "validate-udp-pcm-loopback-session", kind: .validator, relatedTestFiles: ["Tests/OpenLolaCoreTests/UdpPcmLoopbackLatencyTests.swift"]),
            CLICommandCatalogEntry(name: "udp-pcm-route-run", kind: .run, relatedTestFiles: ["Tests/OpenLolaCoreTests/UdpPcmRouteReportTests.swift"]),
            CLICommandCatalogEntry(name: "udp-pcm-loopback-run", kind: .run, relatedTestFiles: ["Tests/OpenLolaCoreTests/UdpPcmLoopbackLatencyTests.swift"]),
            CLICommandCatalogEntry(name: "udp-pcm-loopback-localhost-smoke", kind: .localhostSmoke, relatedTestFiles: ["Tests/OpenLolaCoreTests/UdpPcmLoopbackLatencyTests.swift"]),
            CLICommandCatalogEntry(name: "validate-network-diagnostics-report", kind: .validator, relatedTestFiles: ["Tests/OpenLolaCoreTests/NetworkDiagnosticsTests.swift"]),
            CLICommandCatalogEntry(name: "network-diagnostics-run", kind: .run, relatedTestFiles: ["Tests/OpenLolaCoreTests/NetworkDiagnosticsTests.swift"]),
            CLICommandCatalogEntry(name: "validate-nat-friendly-route-report", kind: .validator, relatedTestFiles: ["Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift"]),
            CLICommandCatalogEntry(name: "validate-direct-p2p-session-report", kind: .validator, relatedTestFiles: ["Tests/OpenLolaCoreTests/PeerSessionRunnerTests.swift"]),
            CLICommandCatalogEntry(name: "validate-direct-p2p-mesh-topology-report", kind: .validator, relatedTestFiles: ["Tests/OpenLolaCoreTests/PeerSessionRunnerTests.swift"]),
            CLICommandCatalogEntry(name: "validate-direct-p2p-mesh-runtime-report", kind: .validator, relatedTestFiles: ["Tests/OpenLolaCoreTests/PeerSessionRunnerTests.swift"]),
            CLICommandCatalogEntry(name: "validate-direct-p2p-two-peer-plan-report", kind: .validator, relatedTestFiles: ["Tests/OpenLolaCoreTests/DirectPeerTwoPeerRunPlanTests.swift"]),
            CLICommandCatalogEntry(name: "validate-direct-p2p-two-peer-prototype-report", kind: .validator, relatedTestFiles: ["Tests/OpenLolaCoreTests/DirectPeerTwoPeerRunPlanTests.swift"]),
            CLICommandCatalogEntry(name: "validate-direct-p2p-two-peer-local-run-report", kind: .validator, relatedTestFiles: ["Tests/OpenLolaCoreTests/DirectPeerTwoPeerRunPlanTests.swift"]),
            CLICommandCatalogEntry(name: "nat-rendezvous-run", kind: .run, relatedTestFiles: ["Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift"]),
            CLICommandCatalogEntry(name: "nat-relay-run", kind: .run, relatedTestFiles: ["Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift"]),
            CLICommandCatalogEntry(name: "nat-rendezvous-forwarder-run", kind: .run, relatedTestFiles: ["Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift"]),
            CLICommandCatalogEntry(name: "nat-friendly-route-run", kind: .run, relatedTestFiles: ["Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift"]),
            CLICommandCatalogEntry(name: "nat-friendly-localhost-smoke", kind: .localhostSmoke, relatedTestFiles: ["Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift"]),
            CLICommandCatalogEntry(name: "nat-rendezvous-localhost-smoke", kind: .localhostSmoke, relatedTestFiles: ["Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift"]),
            CLICommandCatalogEntry(name: "nat-rendezvous-forwarder-localhost-smoke", kind: .localhostSmoke, relatedTestFiles: ["Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift"]),
            CLICommandCatalogEntry(name: "nat-relay-fallback-localhost-smoke", kind: .localhostSmoke, relatedTestFiles: ["Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift"]),
            CLICommandCatalogEntry(name: "direct-p2p-localhost-smoke", kind: .localhostSmoke, relatedTestFiles: ["Tests/OpenLolaCoreTests/PeerSessionRunnerTests.swift"]),
            CLICommandCatalogEntry(name: "direct-p2p-mesh-topology-synthetic-smoke", kind: .syntheticSmoke, relatedTestFiles: ["Tests/OpenLolaCoreTests/PeerSessionRunnerTests.swift"]),
            CLICommandCatalogEntry(name: "direct-p2p-mesh-runtime-localhost-smoke", kind: .localhostSmoke, relatedTestFiles: ["Tests/OpenLolaCoreTests/PeerSessionRunnerTests.swift"]),
            CLICommandCatalogEntry(name: "direct-p2p-two-peer-plan-run", kind: .run, relatedTestFiles: ["Tests/OpenLolaCoreTests/DirectPeerTwoPeerRunPlanTests.swift"]),
            CLICommandCatalogEntry(name: "direct-p2p-two-peer-prototype-report", kind: .run, relatedTestFiles: ["Tests/OpenLolaCoreTests/DirectPeerTwoPeerRunPlanTests.swift"]),
            CLICommandCatalogEntry(name: "direct-p2p-two-peer-local-run", kind: .run, relatedTestFiles: ["Tests/OpenLolaCoreTests/DirectPeerTwoPeerRunPlanTests.swift"]),
            CLICommandCatalogEntry(name: "direct-p2p-session-run", kind: .run, relatedTestFiles: ["Tests/OpenLolaCoreTests/PeerSessionRunnerTests.swift", "Tests/OpenLolaCoreTests/PeerSessionAVFastestTests.swift"]),
    ]
).inventoryEntries()

private let milestoneValidationCommands: [CLICommandInventoryEntry] = [
    command("validate-latency-benchmark-report", .validator, "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift", ["Tests/OpenLolaCoreTests/LatencyBenchmarkReportTests.swift"]),
    command("validate-rx-buffer-benchmark-report", .validator, "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift", ["Tests/OpenLolaCoreTests/RxBufferingTests.swift"]),
    command("validate-latency-tuning-report", .validator, "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift", ["Tests/OpenLolaCoreTests/LatencyTuningReportTests.swift"]),
    command("validate-drift-plc-report", .validator, "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift", ["Tests/OpenLolaCoreTests/DriftPlcReportTests.swift"]),
    command("validate-drift-plc-certification-report", .validator, "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift", ["Tests/OpenLolaCoreTests/DriftPlcFixedTargetCertificationFixtures+TestSupport.swift"]),
    command("validate-aoip-report", .validator, "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift", ["Tests/OpenLolaCoreTests/AoipEvaluationReportTests.swift"]),
    command("validate-network-aoip-certification-report", .validator, "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift", ["Tests/OpenLolaCoreTests/NetworkAoipCertificationFixtures+TestSupport.swift"]),
    command("validate-video-capture-report", .validator, "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift", ["Tests/OpenLolaCoreTests/VideoCaptureReportTests.swift"]),
    command("validate-video-capture-inventory", .validator, "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift", ["Tests/OpenLolaCoreTests/VideoCaptureReportTests.swift"]),
    command("validate-video-transport-report", .validator, "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift", ["Tests/OpenLolaCoreTests/VideoTransportReportTests.swift"]),
    command("validate-integrated-av-report", .validator, "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift", ["Tests/OpenLolaCoreTests/IntegratedAvReportTests.swift"]),
    command("validate-integrated-profile-report", .validator, "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift", ["Tests/OpenLolaCoreTests/IntegratedProfileReportTests.swift", "Tests/OpenLolaCoreTests/IntegratedProfileRunEvidenceTests.swift"]),
    command("validate-hardware-validation-report", .validator, "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift", ["Tests/OpenLolaCoreTests/HardwareValidationReportTests.swift"]),
    command("validate-osc-cue-report", .validator, "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift", ["Tests/OpenLolaCoreTests/OscCueReportTests.swift"]),
    command("validate-atem-control-report", .validator, "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift", ["Tests/OpenLolaCoreTests/IntegratedAvReportTests.swift"]),
    command("validate-lighting-gate-report", .validator, "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift", ["Tests/OpenLolaCoreTests/LightingFixtureGateTests.swift"]),
    command("validate-native-app-shell-report", .validator, "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift", ["Tests/OpenLolaCoreTests/NativeAppShellTests.swift"]),
    command("validate-native-app-shell-surface-probe-report", .validator, "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift", ["Tests/OpenLolaCoreTests/NativeAppShellTests.swift"]),
    command("validate-recording-session-report", .validator, "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift", ["Tests/OpenLolaCoreTests/RecordingSessionArtifactTests.swift"]),
    command("validate-packaging-field-report", .validator, "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift", ["Tests/OpenLolaCoreTests/PackagingFieldTestTests.swift"]),
    command("validate-field-runtime-proof", .validator, "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift", ["Tests/OpenLolaCoreTests/FieldReadyRuntimeProofTests.swift"]),
    command("validate-lola-parity-deferred-ledger", .validator, "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift", ["Tests/OpenLolaCoreTests/LoLaParityDeferredFeaturesTests.swift"]),
    command("validate-faster-than-lola-closure", .validator, "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift", ["Tests/OpenLolaCoreTests/FasterThanLoLaClosureTests.swift"]),
    command("validate-goal-codewise-closure-report", .validator, "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift", ["Tests/OpenLolaCoreTests/GoalCodewiseClosureTests.swift"]),
    command("validate-goal-runtime-evidence-template-report", .validator, "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift", ["Tests/OpenLolaCoreTests/GoalRuntimeEvidenceTemplateTests.swift"]),
    command("validate-goal-runtime-preflight-report", .validator, "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift", ["Tests/OpenLolaCoreTests/GoalRuntimePreflightTests.swift"]),
    command("validate-goal-completion-audit-report", .validator, "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift", ["Tests/OpenLolaCoreTests/GoalCompletionAuditTests.swift"]),
    command("validate-current-evidence-status-matrix-report", .validator, "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift", ["Tests/OpenLolaCoreTests/CurrentEvidenceStatusMatrixTests.swift"]),
    command("validate-release-hardening-report", .validator, "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift", ["Tests/OpenLolaCoreTests/ReleaseHardeningTests.swift"]),
    command("validate-open-source-release-readiness-report", .validator, "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift", ["Tests/OpenLolaCoreTests/OpenSourceReleaseReadinessTests.swift"]),
]

private let milestoneRuntimeCommands: [CLICommandInventoryEntry] = [
    command("udp-pcm-localhost-smoke", .localhostSmoke, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/UdpPcmPacketTests.swift"]),
    command("udp-pcm-route-localhost-smoke", .localhostSmoke, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/UdpPcmRouteReportTests.swift"]),
    command("route-certification-synthetic-smoke", .syntheticSmoke, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/MacToMacRouteCertificationTests.swift"]),
    command("latency-benchmark-synthetic-smoke", .syntheticSmoke, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/LatencyBenchmarkReportTests.swift"]),
    command("latency-tuning-synthetic-smoke", .syntheticSmoke, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/LatencyTuningReportTests.swift"]),
    command("latency-profile-synthetic-smoke", .syntheticSmoke, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/LatencyProfileTests.swift"]),
    command("realtime-audio-synthetic-smoke", .syntheticSmoke, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/RealtimeAudioEngineTests.swift"]),
    command("madi-tx-synthetic-smoke", .syntheticSmoke, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/MadiTransmitTests.swift"]),
    command("drift-plc-synthetic-smoke", .syntheticSmoke, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/DriftPlcReportTests.swift"]),
    command("drift-plc-certification-synthetic-smoke", .syntheticSmoke, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/DriftPlcFixedTargetCertificationFixtures+TestSupport.swift"]),
    command("aoip-synthetic-smoke", .syntheticSmoke, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/AoipEvaluationReportTests.swift"]),
    command("network-aoip-certification-synthetic-smoke", .syntheticSmoke, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/NetworkAoipCertificationFixtures+TestSupport.swift"]),
    command("video-capture-synthetic-smoke", .syntheticSmoke, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/VideoCaptureReportTests.swift"]),
    command("video-capture-inventory", .inventory, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/VideoCaptureReportTests.swift"]),
    command("video-capture-run", .run, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/VideoCaptureReportTests.swift"]),
    command("video-transport-synthetic-smoke", .syntheticSmoke, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/VideoTransportRunnerTests.swift"]),
    command("video-transport-run", .run, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/VideoTransportRunnerTests.swift"]),
    command("integrated-av-synthetic-smoke", .syntheticSmoke, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/IntegratedAvReportTests.swift"]),
    command("integrated-av-run", .run, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/IntegratedAvReportTests.swift"]),
    command("integrated-profile-synthetic-smoke", .syntheticSmoke, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/IntegratedProfileReportTests.swift"]),
    command("integrated-profile-run", .run, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/IntegratedProfileReportTests.swift", "Tests/OpenLolaCoreTests/IntegratedProfileRunEvidenceTests.swift"]),
    command("hardware-validation-synthetic-smoke", .syntheticSmoke, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/HardwareValidationReportTests.swift"]),
    command("hardware-validation-run", .run, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/HardwareValidationReportTests.swift"]),
    command("osc-cue-synthetic-smoke", .syntheticSmoke, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/OscCueReportTests.swift"]),
    command("osc-cue-run", .run, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/OscCueReportTests.swift"]),
    command("osc-cue-external-run", .run, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/OscCueReportTests.swift"]),
    command("atem-readonly-probe", .probe, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/IntegratedAvReportTests.swift"]),
    command("lighting-gate-synthetic-smoke", .syntheticSmoke, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/LightingFixtureGateTests.swift"]),
    command("lighting-gate-run", .run, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/LightingFixtureGateTests.swift"]),
    command("native-app-shell-synthetic-smoke", .syntheticSmoke, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/NativeAppShellTests.swift"]),
    command("native-app-shell-surface-probe", .probe, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/NativeAppShellTests.swift"]),
    command("native-app-runtime-smoke", .run, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/NativeAppShellTests.swift"]),
    command("recording-session-synthetic-smoke", .syntheticSmoke, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/RecordingSessionArtifactTests.swift"]),
    command("recording-session-run", .run, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/RecordingSessionArtifactTests.swift"]),
    command("packaging-field-run", .run, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/PackagingFieldTestTests.swift"]),
    command("packaging-field-synthetic-smoke", .syntheticSmoke, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/PackagingFieldTestTests.swift"]),
    command("field-runtime-proof-run", .run, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/FieldReadyRuntimeProofTests.swift"]),
    command("field-readiness-run", .run, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/FieldReadyRuntimeProofTests.swift"]),
    command("field-runtime-synthetic-smoke", .syntheticSmoke, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/FieldReadyRuntimeProofTests.swift"]),
    command("faster-than-lola-closure-synthetic-smoke", .syntheticSmoke, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/FasterThanLoLaClosureTests.swift"]),
    command("faster-than-lola-closure-run", .run, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/FasterThanLoLaClosureTests.swift"]),
    command("external-connector-synthetic-smoke", .syntheticSmoke, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/ExternalConnectorReportTests.swift"]),
    command("external-connector-report-run", .run, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/ExternalConnectorReportTests.swift"]),
    command("external-connector-session-run", .run, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/ExternalConnectorSessionTests.swift", "Tests/OpenLolaCoreTests/ExternalConnectorAvMatrixTests.swift"]),
    command("external-connector-connection-plan-run", .run, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/ExternalConnectorConnectionPlanTests.swift"]),
    command("external-connector-nmp-plan-run", .run, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/ExternalConnectorNmpPlanTests.swift"]),
    command("external-connector-nmp-preflight-run", .run, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/ExternalConnectorNmpPreflightTests.swift"]),
    command("external-connector-nmp-endpoint-run", .run, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/ExternalConnectorNmpEndpointRunTests.swift"]),
    command("external-connector-nmp-workflow-run", .run, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/ExternalConnectorNmpWorkflowTests.swift"]),
    command("external-connector-executable-preflight-run", .run, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/ExternalConnectorExecutablePreflightTests.swift"]),
    command("lola-capture-decode", .run, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/LoLaCompatibilityCaptureReportTests.swift"]),
    command("lola-packet-fixture-run", .run, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/LoLaCompatibilityPacketFixtureTests.swift"]),
    command("lola-media-report-run", .run, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/LoLaCompatibilityMediaSessionTests.swift"]),
    command("lola-raw-link-tx-run", .run, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/LoLaCompatibilityMediaSessionTests.swift"]),
    command("lola-raw-link-rx-run", .run, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/LoLaCompatibilityMediaSessionTests.swift"]),
    command("lola-udp-media-tx-run", .run, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/LoLaCompatibilityMediaSessionTests.swift"]),
    command("lola-udp-media-rx-run", .run, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/LoLaCompatibilityMediaSessionTests.swift"]),
    command("validate-external-connector-report", .validator, "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift", ["Tests/OpenLolaCoreTests/ExternalConnectorReportTests.swift"]),
    command("validate-external-connector-session-report", .validator, "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift", ["Tests/OpenLolaCoreTests/ExternalConnectorSessionTests.swift", "Tests/OpenLolaCoreTests/ExternalConnectorAvMatrixTests.swift"]),
    command("validate-external-connector-connection-plan", .validator, "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift", ["Tests/OpenLolaCoreTests/ExternalConnectorConnectionPlanTests.swift"]),
    command("validate-external-connector-nmp-plan", .validator, "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift", ["Tests/OpenLolaCoreTests/ExternalConnectorNmpPlanTests.swift"]),
    command("validate-external-connector-nmp-preflight", .validator, "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift", ["Tests/OpenLolaCoreTests/ExternalConnectorNmpPreflightTests.swift"]),
    command("validate-external-connector-nmp-endpoint-run", .validator, "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift", ["Tests/OpenLolaCoreTests/ExternalConnectorNmpEndpointRunTests.swift"]),
    command("validate-external-connector-nmp-workflow", .validator, "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift", ["Tests/OpenLolaCoreTests/ExternalConnectorNmpWorkflowTests.swift"]),
    command("validate-external-connector-executable-preflight-report", .validator, "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift", ["Tests/OpenLolaCoreTests/ExternalConnectorExecutablePreflightTests.swift"]),
    command("validate-lola-capture-report", .validator, "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift", ["Tests/OpenLolaCoreTests/LoLaCompatibilityCaptureReportTests.swift"]),
    command("validate-lola-packet-fixture-report", .validator, "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift", ["Tests/OpenLolaCoreTests/LoLaCompatibilityPacketFixtureTests.swift"]),
    command("validate-lola-media-session-report", .validator, "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift", ["Tests/OpenLolaCoreTests/LoLaCompatibilityMediaSessionTests.swift"]),
    command("release-hardening-synthetic-smoke", .syntheticSmoke, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/ReleaseHardeningTests.swift"]),
    command("release-hardening-run", .run, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/ReleaseHardeningTests.swift"]),
    command("open-source-release-readiness-run", .run, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/OpenSourceReleaseReadinessTests.swift"]),
    command("drift-plc-run", .run, "Sources/open-lola/Commands/MilestoneCommands.swift", ["Tests/OpenLolaCoreTests/DriftPlcReportTests.swift"]),
]

private func main(
    _ commandName: String,
    _ kind: CLICommandKind,
    tests: [String]
) -> CLICommandInventoryEntry {
    command(commandName, kind, "Sources/open-lola/main.swift", tests)
}

private func command(
    _ commandName: String,
    _ kind: CLICommandKind,
    _ owner: String,
    _ tests: [String]
) -> CLICommandInventoryEntry {
    CLICommandInventoryEntry(
        command: commandName,
        kind: kind,
        ownerSourceFile: owner,
        parser: parserDescription(for: kind),
        validationPath: validationDescription(for: kind),
        relatedTestFiles: tests
    )
}

private func parserDescription(for kind: CLICommandKind) -> String {
    switch kind {
    case .validator:
        return "fixed-arity path argument"
    case .run:
        return "typed run configuration parser or explicit requiredArgument checks"
    case .syntheticSmoke, .localhostSmoke, .inventory:
        return "fixed command or optional --output variant"
    case .probe:
        return "small explicit argument parser"
    }
}

private func validationDescription(for kind: CLICommandKind) -> String {
    switch kind {
    case .validator:
        return "decode input artifact, validate report contract, print verdict"
    case .run:
        return "parse configuration, run source-level runner, validate output report, print verdict"
    case .syntheticSmoke:
        return "generate synthetic source-level report, validate it, print PARTIAL verdict"
    case .localhostSmoke:
        return "run local deterministic probe, validate output, print verdict"
    case .inventory:
        return "build local inventory JSON and print verdict"
    case .probe:
        return "execute explicit one-shot probe and print verdict"
    }
}
