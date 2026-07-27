// Collects source inventory evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
extension FixtureSmokeMatrix {
    public static let syntheticSmokes: [CLISmokeMatrixEntry] = [
        smoke(
            "aoip-synthetic-smoke",
            "Sources/open-lola/Commands/MilestoneCommands.swift",
            "AoipEvaluationReports",
            "Audio/network AoIP"
        ),
        smoke(
            "drift-plc-certification-synthetic-smoke",
            "Sources/open-lola/Commands/MilestoneCommands.swift",
            "DriftPlcFixedTargetCertificationReports",
            "Timing and drift"
        ),
        smoke(
            "drift-plc-synthetic-smoke",
            "Sources/open-lola/Commands/MilestoneCommands.swift",
            "DriftPlcReports",
            "Timing and drift"
        ),
        smoke(
            "direct-p2p-mesh-topology-synthetic-smoke",
            "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            nil,
            "Network route"
        ),
        smoke(
            "e2e-benchmark-synthetic-smoke",
            "Sources/open-lola/Commands/Benchmarks/E2EBenchmarkCommands.swift",
            nil,
            "Benchmark aggregation"
        ),
        smoke(
            "external-connector-synthetic-smoke",
            "Sources/open-lola/Commands/MilestoneCommands.swift",
            "ExternalConnectorReports",
            "External connectors"
        ),
        smoke(
            "faster-than-lola-closure-synthetic-smoke",
            "Sources/open-lola/Commands/MilestoneCommands.swift",
            nil,
            "Release closure"
        ),
        smoke(
            "field-runtime-synthetic-smoke",
            "Sources/open-lola/Commands/MilestoneCommands.swift",
            "FieldReadyRuntimeProofs",
            "Field runtime"
        ),
        smoke(
            "hardware-validation-synthetic-smoke",
            "Sources/open-lola/Commands/MilestoneCommands.swift",
            "HardwareValidationReports",
            "Hardware validation"
        ),
        smoke(
            "integrated-av-synthetic-smoke",
            "Sources/open-lola/Commands/MilestoneCommands.swift",
            "IntegratedAvReports",
            "Integrated AV"
        ),
        smoke(
            "integrated-profile-synthetic-smoke",
            "Sources/open-lola/Commands/MilestoneCommands.swift",
            "IntegratedProfileReports",
            "Integrated profile"
        ),
        smoke(
            "latency-benchmark-synthetic-smoke",
            "Sources/open-lola/Commands/MilestoneCommands.swift",
            "LatencyBenchmarkReports",
            "Latency benchmark"
        ),
        smoke(
            "latency-profile-benchmark-synthetic-smoke",
            "Sources/open-lola/Commands/Audio/LatencyProfileCommands.swift",
            nil,
            "Latency profile"
        ),
        smoke(
            "latency-profile-synthetic-smoke",
            "Sources/open-lola/Commands/MilestoneCommands.swift",
            nil,
            "Latency profile"
        ),
        smoke(
            "latency-tuning-synthetic-smoke",
            "Sources/open-lola/Commands/MilestoneCommands.swift",
            "LatencyTuningReports",
            "Latency tuning"
        ),
        smoke(
            "lighting-gate-synthetic-smoke",
            "Sources/open-lola/Commands/MilestoneCommands.swift",
            "LightingFixtureGateReports",
            "Lighting control"
        ),
        smoke(
            "madi-full-duplex-synthetic-smoke",
            "Sources/open-lola/Commands/Audio/MadiFullDuplexCommands.swift",
            nil,
            "MADI full-duplex"
        ),
        smoke(
            "madi-rx-synthetic-smoke",
            "Sources/open-lola/Commands/Audio/MadiReceiveCommands.swift",
            nil,
            "MADI receive"
        ),
        smoke("madi-tx-synthetic-smoke", "Sources/open-lola/Commands/MilestoneCommands.swift", nil, "MADI transmit"),
        smoke(
            "native-app-shell-synthetic-smoke",
            "Sources/open-lola/Commands/MilestoneCommands.swift",
            "NativeAppShellReports",
            "macOS app shell"
        ),
        smoke(
            "network-aoip-certification-synthetic-smoke",
            "Sources/open-lola/Commands/MilestoneCommands.swift",
            "NetworkAoipCertificationReports",
            "Network AoIP"
        ),
        smoke(
            "osc-cue-synthetic-smoke",
            "Sources/open-lola/Commands/MilestoneCommands.swift",
            "OscCueReports",
            "OSC control"
        ),
        smoke(
            "packaging-field-synthetic-smoke",
            "Sources/open-lola/Commands/MilestoneCommands.swift",
            "PackagingFieldTests",
            "Packaging and release"
        ),
        smoke(
            "performance-audit-synthetic-smoke",
            "Sources/open-lola/Commands/Benchmarks/PerformanceCommands.swift",
            nil,
            "Performance audit"
        ),
        smoke(
            "realtime-audio-synthetic-smoke",
            "Sources/open-lola/Commands/MilestoneCommands.swift",
            "RealtimeAudioEngineReports",
            "Realtime audio"
        ),
        smoke(
            "recording-session-synthetic-smoke",
            "Sources/open-lola/Commands/MilestoneCommands.swift",
            "RecordingSessionArtifacts",
            "Recording session"
        ),
        smoke(
            "release-hardening-synthetic-smoke",
            "Sources/open-lola/Commands/MilestoneCommands.swift",
            "ReleaseHardeningReports",
            "Release hardening"
        ),
        smoke(
            "route-certification-synthetic-smoke",
            "Sources/open-lola/Commands/MilestoneCommands.swift",
            "MacToMacRouteCertificationReports",
            "Network route"
        ),
        smoke(
            "video-capture-synthetic-smoke",
            "Sources/open-lola/Commands/MilestoneCommands.swift",
            "VideoCaptureReports",
            "Video capture"
        ),
        smoke(
            "video-transport-synthetic-smoke",
            "Sources/open-lola/Commands/MilestoneCommands.swift",
            "VideoTransportReports",
            "Video transport"
        )
    ]
}

private func smoke(
    _ command: String,
    _ sourceFile: String,
    _ fixtureGroup: String?,
    _ owner: String
) -> CLISmokeMatrixEntry {
    CLISmokeMatrixEntry(
        command: command,
        sourceFile: sourceFile,
        expectedVerdict: .partial,
        syntheticOnly: true,
        relatedFixtureGroup: fixtureGroup,
        owner: owner
    )
}
