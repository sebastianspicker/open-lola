extension FixtureSmokeMatrix {
    public static let fixtureGroups: [FixtureMatrixEntry] =
        syntheticReportFixtureGroups
        + syntheticValidationFixtureGroups
        + supportFixtureGroups

    private static let syntheticReportFixtureGroups: [FixtureMatrixEntry] = [
        fixture("AoipEvaluationReports", 1, .syntheticReport, validator: "validate-aoip-report", smoke: "aoip-synthetic-smoke", source: "Sources/OpenLolaCore/Network/Diagnostics/AoipEvaluationReport.swift", test: "Tests/OpenLolaCoreTests/AoipEvaluationReportTests.swift"),
        fixture("DriftPlcFixedTargetCertificationReports", 1, .syntheticReport, validator: "validate-drift-plc-certification-report", smoke: "drift-plc-certification-synthetic-smoke", source: "Sources/OpenLolaCore/Timing/DriftPlcFixedTargetCertification.swift", test: "Tests/OpenLolaCoreTests/DriftPlcFixedTargetCertificationFixtures+TestSupport.swift"),
        fixture("DriftPlcReports", 1, .syntheticReport, validator: "validate-drift-plc-report", smoke: "drift-plc-synthetic-smoke", source: "Sources/OpenLolaCore/Timing/DriftPlcReport.swift", test: "Tests/OpenLolaCoreTests/DriftPlcReportTests.swift"),
        fixture("ExternalConnectorReports", 1, .syntheticReport, validator: "validate-external-connector-report", smoke: "external-connector-synthetic-smoke", source: "Sources/OpenLolaCore/Connectors/Core/ExternalConnectorReport.swift", test: "Tests/OpenLolaCoreTests/ExternalConnectorReportTests.swift"),
        fixture("HardwareValidationReports", 1, .syntheticReport, validator: "validate-hardware-validation-report", smoke: "hardware-validation-synthetic-smoke", source: "Sources/OpenLolaCore/Evidence/HardwareValidationReport.swift", test: "Tests/OpenLolaCoreTests/HardwareValidationReportTests.swift"),
        fixture("IntegratedProfileReports", 1, .syntheticReport, validator: "validate-integrated-profile-report", smoke: "integrated-profile-synthetic-smoke", source: "Sources/OpenLolaCore/Integration/IntegratedProfileReport.swift", test: "Tests/OpenLolaCoreTests/IntegratedProfileReportTests.swift"),
        fixture("LatencyTuningReports", 1, .syntheticReport, validator: "validate-latency-tuning-report", smoke: "latency-tuning-synthetic-smoke", source: "Sources/OpenLolaCore/Timing/LatencyTuningReport.swift", test: "Tests/OpenLolaCoreTests/LatencyTuningReportTests.swift"),
        fixture("LightingFixtureGateReports", 1, .syntheticReport, validator: "validate-lighting-gate-report", smoke: "lighting-gate-synthetic-smoke", source: "Sources/OpenLolaCore/Control/LightingFixtureGateReport.swift", test: "Tests/OpenLolaCoreTests/LightingFixtureGateTests.swift"),
        fixture("LoLaParityDeferredLedgers", 1, .syntheticReport, validator: "validate-lola-parity-deferred-ledger", source: "Sources/OpenLolaCore/Release/LoLaParityDeferredFeatures.swift", test: "Tests/OpenLolaCoreTests/LoLaParityDeferredFeaturesTests.swift"),
        fixture("MacToMacRouteCertificationReports", 1, .syntheticReport, validator: "validate-route-certification-report", smoke: "route-certification-synthetic-smoke", source: "Sources/OpenLolaCore/Network/P2P/MacToMacRouteCertification.swift", test: "Tests/OpenLolaCoreTests/MacToMacRouteCertificationTests.swift"),
        fixture("NativeAppShellReports", 1, .syntheticReport, validator: "validate-native-app-shell-report", smoke: "native-app-shell-synthetic-smoke", source: "Sources/OpenLolaCore/Platform/NativeAppShell.swift", test: "Tests/OpenLolaCoreTests/NativeAppShellTests.swift"),
        fixture("NetworkAoipCertificationReports", 1, .syntheticReport, validator: "validate-network-aoip-certification-report", smoke: "network-aoip-certification-synthetic-smoke", source: "Sources/OpenLolaCore/Network/Diagnostics/NetworkAoipCertification.swift", test: "Tests/OpenLolaCoreTests/NetworkAoipCertificationFixtures+TestSupport.swift"),
        fixture("OscCueReports", 1, .syntheticReport, validator: "validate-osc-cue-report", smoke: "osc-cue-synthetic-smoke", source: "Sources/OpenLolaCore/Control/OscCueProbe.swift", test: "Tests/OpenLolaCoreTests/OscCueReportTests.swift"),
        fixture("RecordingSessionArtifacts", 1, .syntheticReport, validator: "validate-recording-session-report", smoke: "recording-session-synthetic-smoke", source: "Sources/OpenLolaCore/Release/RecordingSessionArtifacts.swift", test: "Tests/OpenLolaCoreTests/RecordingSessionArtifactTests.swift"),
        fixture("ReferenceRigReports", 1, .syntheticReport, validator: "validate-reference-rig-report", source: "Sources/OpenLolaCore/Evidence/ReferenceRigReport.swift", test: "Tests/OpenLolaCoreTests/ReferenceRigReportTests.swift"),
        fixture("RmeFastestAudioPathReports", 1, .syntheticReport, validator: "validate-rme-fastest-audio-report", source: "Sources/OpenLolaCore/Audio/MADI/RmeFastestAudioPath.swift", test: "Tests/OpenLolaCoreTests/RmeFastestAudioPathTests.swift"),
        fixture("VideoCaptureReports", 1, .syntheticReport, validator: "validate-video-capture-report", smoke: "video-capture-synthetic-smoke", source: "Sources/OpenLolaCore/Video/VideoCaptureReport.swift", test: "Tests/OpenLolaCoreTests/VideoCaptureReportTests.swift"),
        fixture("VideoTransportReports", 1, .syntheticReport, validator: "validate-video-transport-report", smoke: "video-transport-synthetic-smoke", source: "Sources/OpenLolaCore/Video/VideoTransportReport.swift", test: "Tests/OpenLolaCoreTests/VideoTransportReportTests.swift"),
    ]

    private static let syntheticValidationFixtureGroups: [FixtureMatrixEntry] = [
        fixture("EndpointLoopback", 2, .syntheticValidationFixture, validator: "validate-loopback-report", source: "Sources/OpenLolaCore/Network/P2P/EndpointLoopbackReport.swift", test: "Tests/OpenLolaCoreTests/EndpointLoopbackReportTests.swift"),
        fixture("FieldReadyRuntimeProofs", 2, .syntheticValidationFixture, validator: "validate-field-runtime-proof", smoke: "field-runtime-synthetic-smoke", source: "Sources/OpenLolaCore/Release/FieldReadyRuntimeProof.swift", test: "Tests/OpenLolaCoreTests/FieldReadyRuntimeProofTests.swift", falsePass: ["field-runtime-proof-synthetic-pass.json"]),
        fixture("IntegratedAvReports", 2, .syntheticValidationFixture, validator: "validate-integrated-av-report", smoke: "integrated-av-synthetic-smoke", source: "Sources/OpenLolaCore/Integration/IntegratedAvReport.swift", test: "Tests/OpenLolaCoreTests/IntegratedAvReportTests.swift", falsePass: ["integrated-av-synthetic-pass.json"]),
        fixture("LatencyBenchmarkReports", 6, .syntheticValidationFixture, validator: "validate-latency-benchmark-report", smoke: "latency-benchmark-synthetic-smoke", source: "Sources/OpenLolaCore/Benchmarks/Latency/LatencyBenchmarkReport.swift", test: "Tests/OpenLolaCoreTests/LatencyBenchmarkReportTests.swift"),
        fixture("PackagingFieldTests", 6, .syntheticValidationFixture, validator: "validate-packaging-field-report", smoke: "packaging-field-synthetic-smoke", source: "Sources/OpenLolaCore/Release/PackagingFieldTest.swift", test: "Tests/OpenLolaCoreTests/PackagingFieldTestTests.swift", falsePass: ["packaging-field-test-synthetic-pass.json", "packaging-field-test-missing-signing.json", "packaging-field-test-missing-notarization.json", "packaging-field-test-missing-gatekeeper.json", "packaging-field-test-missing-clean-mac.json"]),
        fixture("RealtimeAudioEngineReports", 2, .syntheticValidationFixture, validator: "validate-realtime-audio-engine-report", smoke: "realtime-audio-synthetic-smoke", source: "Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngine.swift", test: "Tests/OpenLolaCoreTests/RealtimeAudioEngineTests.swift", falsePass: ["realtime-audio-engine-synthetic-pass.json"]),
        fixture("ReleaseHardeningReports", 2, .syntheticValidationFixture, validator: "validate-release-hardening-report", smoke: "release-hardening-synthetic-smoke", source: "Sources/OpenLolaCore/Release/ReleaseHardening.swift", test: "Tests/OpenLolaCoreTests/ReleaseHardeningTests.swift", falsePass: ["release-hardening-synthetic-pass.json"]),
    ]

    private static let supportFixtureGroups: [FixtureMatrixEntry] = [
        fixture("CoreAudioInventory", 2, .syntheticInventory, source: "Sources/OpenLolaCore/Audio/CoreAudio/CoreAudioInventory.swift", test: "Tests/OpenLolaCoreTests/CoreAudioInventoryTests.swift"),
        fixture("MeasurementReports", 10, .syntheticMeasurementReport, source: "Sources/OpenLolaCore/Evidence/MeasurementReport.swift", test: "Tests/OpenLolaCoreTests/MeasurementReportFixtureTests.swift"),
        fixture("UdpPcmPackets", 3, .openLolaGeneratedPacket, validator: "validate-udp-pcm-packet", source: "Sources/OpenLolaCore/Network/UDP/UdpPcmPacket.swift", test: "Tests/OpenLolaCoreTests/UdpPcmPacketTests.swift", fileExtensions: ["hex"]),
        fixture("UdpPcmRoutes", 1, .sourceContract, validator: "validate-route-report", source: "Sources/OpenLolaCore/Network/UDP/UdpPcmRouteCertification.swift", test: "Tests/OpenLolaCoreTests/UdpPcmRouteReportTests.swift"),
    ]

    public static let syntheticSmokes: [CLISmokeMatrixEntry] = [
        smoke("aoip-synthetic-smoke", "Sources/open-lola/Commands/MilestoneCommands.swift", "AoipEvaluationReports", "Audio/network AoIP"),
        smoke("drift-plc-certification-synthetic-smoke", "Sources/open-lola/Commands/MilestoneCommands.swift", "DriftPlcFixedTargetCertificationReports", "Timing and drift"),
        smoke("drift-plc-synthetic-smoke", "Sources/open-lola/Commands/MilestoneCommands.swift", "DriftPlcReports", "Timing and drift"),
        smoke("direct-p2p-mesh-topology-synthetic-smoke", "Sources/open-lola/Commands/Network/NetworkCommands.swift", nil, "Network route"),
        smoke("e2e-benchmark-synthetic-smoke", "Sources/open-lola/Commands/Benchmarks/E2EBenchmarkCommands.swift", nil, "Benchmark aggregation"),
        smoke("external-connector-synthetic-smoke", "Sources/open-lola/Commands/MilestoneCommands.swift", "ExternalConnectorReports", "External connectors"),
        smoke("faster-than-lola-closure-synthetic-smoke", "Sources/open-lola/Commands/MilestoneCommands.swift", nil, "Release closure"),
        smoke("field-runtime-synthetic-smoke", "Sources/open-lola/Commands/MilestoneCommands.swift", "FieldReadyRuntimeProofs", "Field runtime"),
        smoke("hardware-validation-synthetic-smoke", "Sources/open-lola/Commands/MilestoneCommands.swift", "HardwareValidationReports", "Hardware validation"),
        smoke("integrated-av-synthetic-smoke", "Sources/open-lola/Commands/MilestoneCommands.swift", "IntegratedAvReports", "Integrated AV"),
        smoke("integrated-profile-synthetic-smoke", "Sources/open-lola/Commands/MilestoneCommands.swift", "IntegratedProfileReports", "Integrated profile"),
        smoke("latency-benchmark-synthetic-smoke", "Sources/open-lola/Commands/MilestoneCommands.swift", "LatencyBenchmarkReports", "Latency benchmark"),
        smoke("latency-profile-benchmark-synthetic-smoke", "Sources/open-lola/Commands/Audio/LatencyProfileCommands.swift", nil, "Latency profile"),
        smoke("latency-profile-synthetic-smoke", "Sources/open-lola/Commands/MilestoneCommands.swift", nil, "Latency profile"),
        smoke("latency-tuning-synthetic-smoke", "Sources/open-lola/Commands/MilestoneCommands.swift", "LatencyTuningReports", "Latency tuning"),
        smoke("lighting-gate-synthetic-smoke", "Sources/open-lola/Commands/MilestoneCommands.swift", "LightingFixtureGateReports", "Lighting control"),
        smoke("madi-full-duplex-synthetic-smoke", "Sources/open-lola/Commands/Audio/MadiFullDuplexCommands.swift", nil, "MADI full-duplex"),
        smoke("madi-rx-synthetic-smoke", "Sources/open-lola/Commands/Audio/MadiReceiveCommands.swift", nil, "MADI receive"),
        smoke("madi-tx-synthetic-smoke", "Sources/open-lola/Commands/MilestoneCommands.swift", nil, "MADI transmit"),
        smoke("native-app-shell-synthetic-smoke", "Sources/open-lola/Commands/MilestoneCommands.swift", "NativeAppShellReports", "macOS app shell"),
        smoke("network-aoip-certification-synthetic-smoke", "Sources/open-lola/Commands/MilestoneCommands.swift", "NetworkAoipCertificationReports", "Network AoIP"),
        smoke("osc-cue-synthetic-smoke", "Sources/open-lola/Commands/MilestoneCommands.swift", "OscCueReports", "OSC control"),
        smoke("packaging-field-synthetic-smoke", "Sources/open-lola/Commands/MilestoneCommands.swift", "PackagingFieldTests", "Packaging and release"),
        smoke("performance-audit-synthetic-smoke", "Sources/open-lola/Commands/Benchmarks/PerformanceCommands.swift", nil, "Performance audit"),
        smoke("realtime-audio-synthetic-smoke", "Sources/open-lola/Commands/MilestoneCommands.swift", "RealtimeAudioEngineReports", "Realtime audio"),
        smoke("recording-session-synthetic-smoke", "Sources/open-lola/Commands/MilestoneCommands.swift", "RecordingSessionArtifacts", "Recording session"),
        smoke("release-hardening-synthetic-smoke", "Sources/open-lola/Commands/MilestoneCommands.swift", "ReleaseHardeningReports", "Release hardening"),
        smoke("route-certification-synthetic-smoke", "Sources/open-lola/Commands/MilestoneCommands.swift", "MacToMacRouteCertificationReports", "Network route"),
        smoke("video-capture-synthetic-smoke", "Sources/open-lola/Commands/MilestoneCommands.swift", "VideoCaptureReports", "Video capture"),
        smoke("video-transport-synthetic-smoke", "Sources/open-lola/Commands/MilestoneCommands.swift", "VideoTransportReports", "Video transport"),
    ]
}

private func fixture(
    _ group: String,
    _ count: Int,
    _ provenance: FixtureProvenanceClass,
    validator: String? = nil,
    smoke: String? = nil,
    source: String,
    test: String,
    fileExtensions: [String] = ["json"],
    falsePass: [String] = []
) -> FixtureMatrixEntry {
    FixtureMatrixEntry(
        group: group,
        expectedFileCount: count,
        fileExtensions: fileExtensions,
        provenanceClass: provenance,
        validatorCommand: validator,
        smokeCommand: smoke,
        relatedSourceFiles: [source],
        relatedTestFiles: [test],
        requiresFalsePassFixture: !falsePass.isEmpty,
        falsePassFixtures: falsePass
    )
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
