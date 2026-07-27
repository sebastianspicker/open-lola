// Collects source inventory evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
extension FixtureSmokeMatrix {
    public static let fixtureGroups: [FixtureMatrixEntry] =
        syntheticReportFixtureGroups
        + syntheticValidationFixtureGroups
        + supportFixtureGroups

    private static let syntheticReportFixtureGroups: [FixtureMatrixEntry] = [
        fixture(
            "AoipEvaluationReports",
            1,
            .syntheticReport,
            validator: "validate-aoip-report",
            smoke: "aoip-synthetic-smoke",
            source: "Sources/OpenLolaCore/Network/Diagnostics/AoipEvaluationReport.swift",
            test: "Tests/OpenLolaCoreTests/AoipEvaluationReportTests.swift"
        ),
        fixture(
            "DriftPlcFixedTargetCertificationReports",
            1,
            .syntheticReport,
            validator: "validate-drift-plc-certification-report",
            smoke: "drift-plc-certification-synthetic-smoke",
            source: "Sources/OpenLolaCore/Timing/DriftPlcFixedTargetCertification.swift",
            test: "Tests/OpenLolaCoreTests/DriftPlcFixedTargetCertificationFixtures+TestSupport.swift"
        ),
        fixture(
            "DriftPlcReports",
            1,
            .syntheticReport,
            validator: "validate-drift-plc-report",
            smoke: "drift-plc-synthetic-smoke",
            source: "Sources/OpenLolaCore/Timing/DriftPlcReport.swift",
            test: "Tests/OpenLolaCoreTests/DriftPlcReportTests.swift"
        ),
        fixture(
            "ExternalConnectorReports",
            1,
            .syntheticReport,
            validator: "validate-external-connector-report",
            smoke: "external-connector-synthetic-smoke",
            source: "Sources/OpenLolaCore/Connectors/Core/ExternalConnectorReport.swift",
            test: "Tests/OpenLolaCoreTests/ExternalConnectorReportTests.swift"
        ),
        fixture(
            "HardwareValidationReports",
            1,
            .syntheticReport,
            validator: "validate-hardware-validation-report",
            smoke: "hardware-validation-synthetic-smoke",
            source: "Sources/OpenLolaCore/Evidence/HardwareValidationReport.swift",
            test: "Tests/OpenLolaCoreTests/HardwareValidationReportTests.swift"
        ),
        fixture(
            "IntegratedProfileReports",
            1,
            .syntheticReport,
            validator: "validate-integrated-profile-report",
            smoke: "integrated-profile-synthetic-smoke",
            source: "Sources/OpenLolaCore/Integration/IntegratedProfileReport.swift",
            test: "Tests/OpenLolaCoreTests/IntegratedProfileReportTests.swift"
        ),
        fixture(
            "LatencyTuningReports",
            1,
            .syntheticReport,
            validator: "validate-latency-tuning-report",
            smoke: "latency-tuning-synthetic-smoke",
            source: "Sources/OpenLolaCore/Timing/LatencyTuningReport.swift",
            test: "Tests/OpenLolaCoreTests/LatencyTuningReportTests.swift"
        ),
        fixture(
            "LightingFixtureGateReports",
            1,
            .syntheticReport,
            validator: "validate-lighting-gate-report",
            smoke: "lighting-gate-synthetic-smoke",
            source: "Sources/OpenLolaCore/Control/LightingFixtureGateReport.swift",
            test: "Tests/OpenLolaCoreTests/LightingFixtureGateTests.swift"
        ),
        fixture(
            "LoLaParityDeferredLedgers",
            1,
            .syntheticReport,
            validator: "validate-lola-parity-deferred-ledger",
            source: "Sources/OpenLolaCore/Release/LoLaParityDeferredFeatures.swift",
            test: "Tests/OpenLolaCoreTests/LoLaParityDeferredFeaturesTests.swift"
        ),
        fixture(
            "MacToMacRouteCertificationReports",
            1,
            .syntheticReport,
            validator: "validate-route-certification-report",
            smoke: "route-certification-synthetic-smoke",
            source: "Sources/OpenLolaCore/Network/P2P/MacToMacRouteCertification.swift",
            test: "Tests/OpenLolaCoreTests/MacToMacRouteCertificationTests.swift"
        ),
        fixture(
            "NativeAppShellReports",
            1,
            .syntheticReport,
            validator: "validate-native-app-shell-report",
            smoke: "native-app-shell-synthetic-smoke",
            source: "Sources/OpenLolaCore/Platform/NativeAppShell.swift",
            test: "Tests/OpenLolaCoreTests/NativeAppShellTests.swift"
        ),
        fixture(
            "NetworkAoipCertificationReports",
            1,
            .syntheticReport,
            validator: "validate-network-aoip-certification-report",
            smoke: "network-aoip-certification-synthetic-smoke",
            source: "Sources/OpenLolaCore/Network/Diagnostics/NetworkAoipCertification.swift",
            test: "Tests/OpenLolaCoreTests/NetworkAoipCertificationFixtures+TestSupport.swift"
        ),
        fixture(
            "OscCueReports",
            1,
            .syntheticReport,
            validator: "validate-osc-cue-report",
            smoke: "osc-cue-synthetic-smoke",
            source: "Sources/OpenLolaCore/Control/OscCueProbe.swift",
            test: "Tests/OpenLolaCoreTests/OscCueReportTests.swift"
        ),
        fixture(
            "RecordingSessionArtifacts",
            1,
            .syntheticReport,
            validator: "validate-recording-session-report",
            smoke: "recording-session-synthetic-smoke",
            source: "Sources/OpenLolaCore/Release/RecordingSessionArtifacts.swift",
            test: "Tests/OpenLolaCoreTests/RecordingSessionArtifactTests.swift"
        ),
        fixture(
            "ReferenceRigReports",
            1,
            .syntheticReport,
            validator: "validate-reference-rig-report",
            source: "Sources/OpenLolaCore/Evidence/ReferenceRigReport.swift",
            test: "Tests/OpenLolaCoreTests/ReferenceRigReportTests.swift"
        ),
        fixture(
            "RmeFastestAudioPathReports",
            1,
            .syntheticReport,
            validator: "validate-rme-fastest-audio-report",
            source: "Sources/OpenLolaCore/Audio/MADI/RmeFastestAudioPath.swift",
            test: "Tests/OpenLolaCoreTests/RmeFastestAudioPathTests.swift"
        ),
        fixture(
            "VideoCaptureReports",
            1,
            .syntheticReport,
            validator: "validate-video-capture-report",
            smoke: "video-capture-synthetic-smoke",
            source: "Sources/OpenLolaCore/Video/VideoCaptureReport.swift",
            test: "Tests/OpenLolaCoreTests/VideoCaptureReportTests.swift"
        ),
        fixture(
            "VideoTransportReports",
            1,
            .syntheticReport,
            validator: "validate-video-transport-report",
            smoke: "video-transport-synthetic-smoke",
            source: "Sources/OpenLolaCore/Video/VideoTransportReport.swift",
            test: "Tests/OpenLolaCoreTests/VideoTransportReportTests.swift"
        )
    ]

    private static let syntheticValidationFixtureGroups: [FixtureMatrixEntry] = [
        fixture(
            "EndpointLoopback",
            2,
            .syntheticValidationFixture,
            validator: "validate-loopback-report",
            source: "Sources/OpenLolaCore/Network/P2P/EndpointLoopbackReport.swift",
            test: "Tests/OpenLolaCoreTests/EndpointLoopbackReportTests.swift"
        ),
        fixture(
            "ExternalConnectorSessionReports",
            2,
            .syntheticValidationFixture,
            validator: "validate-external-connector-session-report",
            source: "Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSession.swift",
            test: "Tests/OpenLolaCoreTests/ExternalConnectorSessionTests.swift",
            filePolicy: FixtureFilePolicy(falsePass: ["external-connector-session-missing-media-pass.json"])
        ),
        fixture(
            "FieldReadyRuntimeProofs",
            2,
            .syntheticValidationFixture,
            validator: "validate-field-runtime-proof",
            smoke: "field-runtime-synthetic-smoke",
            source: "Sources/OpenLolaCore/Release/FieldReadyRuntimeProof.swift",
            test: "Tests/OpenLolaCoreTests/FieldReadyRuntimeProofTests.swift",
            filePolicy: FixtureFilePolicy(falsePass: ["field-runtime-proof-synthetic-pass.json"])
        ),
        fixture(
            "IntegratedAvReports",
            2,
            .syntheticValidationFixture,
            validator: "validate-integrated-av-report",
            smoke: "integrated-av-synthetic-smoke",
            source: "Sources/OpenLolaCore/Integration/IntegratedAvReport.swift",
            test: "Tests/OpenLolaCoreTests/IntegratedAvReportTests.swift",
            filePolicy: FixtureFilePolicy(falsePass: ["integrated-av-synthetic-pass.json"])
        ),
        fixture(
            "JackTripCompatibilityMediaReports",
            1,
            .syntheticValidationFixture,
            source: "Sources/OpenLolaCore/Connectors/JackTrip/JackTripCompatibility.swift",
            test: "Tests/OpenLolaCoreTests/JackTripPassValidationTests.swift"
        ),
        fixture(
            "LatencyBenchmarkReports",
            6,
            .syntheticValidationFixture,
            validator: "validate-latency-benchmark-report",
            smoke: "latency-benchmark-synthetic-smoke",
            source: "Sources/OpenLolaCore/Benchmarks/Latency/LatencyBenchmarkReport.swift",
            test: "Tests/OpenLolaCoreTests/LatencyBenchmarkReportTests.swift"
        ),
        fixture(
            "PackagingFieldTests",
            6,
            .syntheticValidationFixture,
            validator: "validate-packaging-field-report",
            smoke: "packaging-field-synthetic-smoke",
            source: "Sources/OpenLolaCore/Release/PackagingFieldTest.swift",
            test: "Tests/OpenLolaCoreTests/PackagingFieldTestTests.swift",
            filePolicy: FixtureFilePolicy(falsePass: [
                            "packaging-field-test-synthetic-pass.json",
                            "packaging-field-test-missing-signing.json",
                            "packaging-field-test-missing-notarization.json",
                            "packaging-field-test-missing-gatekeeper.json",
                            "packaging-field-test-missing-clean-mac.json"
            ])
        ),
        fixture(
            "RealtimeAudioEngineReports",
            2,
            .syntheticValidationFixture,
            validator: "validate-realtime-audio-engine-report",
            smoke: "realtime-audio-synthetic-smoke",
            source: "Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngine.swift",
            test: "Tests/OpenLolaCoreTests/RealtimeAudioEngineTests.swift",
            filePolicy: FixtureFilePolicy(falsePass: ["realtime-audio-engine-synthetic-pass.json"])
        ),
        fixture(
            "ReleaseHardeningReports",
            2,
            .syntheticValidationFixture,
            validator: "validate-release-hardening-report",
            smoke: "release-hardening-synthetic-smoke",
            source: "Sources/OpenLolaCore/Release/ReleaseHardening.swift",
            test: "Tests/OpenLolaCoreTests/ReleaseHardeningTests.swift",
            filePolicy: FixtureFilePolicy(falsePass: ["release-hardening-synthetic-pass.json"])
        ),
        fixture(
            "OpenSourceReleaseReadinessReports",
            2,
            .syntheticValidationFixture,
            validator: "validate-open-source-release-readiness-report",
            source: "Sources/OpenLolaCore/Release/OpenSourceReleaseReadiness.swift",
            test: "Tests/OpenLolaCoreTests/OpenSourceReleaseReadinessTests.swift",
            filePolicy: FixtureFilePolicy(falsePass: ["open-source-release-readiness-missing-requirement-pass.json"])
        ),
        fixture(
            "UltraGridCompatibilityMediaReports",
            1,
            .syntheticValidationFixture,
            source: "Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridCompatibility.swift",
            test: "Tests/OpenLolaCoreTests/UltraGridCompatibilityTests.swift"
        )
    ]

    private static let supportFixtureGroups: [FixtureMatrixEntry] = [
        fixture(
            "CoreAudioInventory",
            2,
            .syntheticInventory,
            source: "Sources/OpenLolaCore/Audio/CoreAudio/CoreAudioInventory.swift",
            test: "Tests/OpenLolaCoreTests/CoreAudioInventoryTests.swift"
        ),
        fixture(
            "MeasurementReports",
            10,
            .syntheticMeasurementReport,
            source: "Sources/OpenLolaCore/Evidence/MeasurementReport.swift",
            test: "Tests/OpenLolaCoreTests/MeasurementReportFixtureTests.swift"
        ),
        fixture(
            "UdpPcmPackets",
            3,
            .openLolaGeneratedPacket,
            validator: "validate-udp-pcm-packet",
            source: "Sources/OpenLolaCore/Network/UDP/UdpPcmPacket.swift",
            test: "Tests/OpenLolaCoreTests/UdpPcmPacketTests.swift",
            filePolicy: FixtureFilePolicy(fileExtensions: ["hex"])
        ),
        fixture(
            "UdpPcmRoutes",
            1,
            .sourceContract,
            validator: "validate-route-report",
            source: "Sources/OpenLolaCore/Network/UDP/UdpPcmRouteCertification.swift",
            test: "Tests/OpenLolaCoreTests/UdpPcmRouteReportTests.swift"
        )
    ]
}

private struct FixtureFilePolicy {
    var fileExtensions: [String] = ["json"]
    var falsePass: [String] = []
}

private func fixture(
    _ group: String,
    _ count: Int,
    _ provenance: FixtureProvenanceClass,
    validator: String? = nil,
    smoke: String? = nil,
    source: String,
    test: String,
    filePolicy: FixtureFilePolicy = FixtureFilePolicy()
) -> FixtureMatrixEntry {
    FixtureMatrixEntry(
        identity: FixtureMatrixEntry.Identity(
            group: group,
            expectedFileCount: count,
            fileExtensions: filePolicy.fileExtensions,
            provenanceClass: provenance
        ),
        commands: FixtureMatrixEntry.Commands(validator: validator, smoke: smoke),
        references: FixtureMatrixEntry.References(sourceFiles: [source], testFiles: [test]),
        falsePassPolicy: FixtureMatrixEntry.FalsePassPolicy(
            required: !filePolicy.falsePass.isEmpty,
            fixtures: filePolicy.falsePass
        )
    )
}
