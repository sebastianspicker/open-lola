import Foundation
import Testing

@testable import OpenLolaCore

@Test
func reportFixturesDecodeAndValidateThroughSharedContract() throws {
    let cases = reportFixtureValidationCases()
    let duplicateGroups = duplicateFixtureValidationGroups(in: cases)

    #expect(duplicateGroups.isEmpty)

    for testCase in cases {
        #expect(!testCase.group.isEmpty)
        #expect(!testCase.schemaName.isEmpty)
        #expect(!testCase.acceptedValidFixtures.isEmpty)

        for fixture in testCase.acceptedValidFixtures {
            let url = reportFixtureRoot
                .appendingPathComponent(testCase.group)
                .appendingPathComponent("valid")
                .appendingPathComponent(fixture)
            let data = try Data(contentsOf: url)

            try testCase.validate(data)
        }
    }
}

struct ReportFixtureValidationCase {
    let group: String
    let schemaName: String
    let acceptedValidFixtures: [String]
    let validate: (Data) throws -> Void
}

func reportFixtureValidationCases() -> [ReportFixtureValidationCase] {
    [
        reportValidator(
            group: "AoipEvaluationReports",
            schemaName: "AoipEvaluationReport",
            fixtures: ["aoip-avb-partial.json"],
            as: AoipEvaluationReport.self
        ),
        reportValidator(
            group: "CoreAudioInventory",
            schemaName: "CoreAudioInventoryReport",
            fixtures: ["core-audio-inventory-valid.json"]
        ) { data in
            let report = try CoreAudioInventoryReport.decode(from: data)
            try report.validate()
        },
        reportValidator(
            group: "DriftPlcFixedTargetCertificationReports",
            schemaName: "DriftPlcFixedTargetCertificationReport",
            fixtures: ["g05-drift-plc-certification-partial.json"],
            as: DriftPlcFixedTargetCertificationReport.self
        ),
        reportValidator(
            group: "DriftPlcReports",
            schemaName: "DriftPlcReport",
            fixtures: ["drift-plc-partial.json"],
            as: DriftPlcReport.self
        ),
        reportValidator(
            group: "EndpointLoopback",
            schemaName: "EndpointLoopbackReport",
            fixtures: ["endpoint-loopback-valid.json"],
            as: EndpointLoopbackReport.self
        ),
        reportValidator(
            group: "ExternalConnectorReports",
            schemaName: "ExternalConnectorReport",
            fixtures: ["external-connectors-source-pass.json"],
            as: ExternalConnectorReport.self
        ),
        reportValidator(
            group: "ExternalConnectorSessionReports",
            schemaName: "ExternalConnectorSessionReport",
            fixtures: ["external-connector-session-partial.json"],
            as: ExternalConnectorSessionReport.self
        ),
        reportValidator(
            group: "FieldReadyRuntimeProofs",
            schemaName: "FieldReadyRuntimeProofReport",
            fixtures: ["field-runtime-proof-partial.json"],
            as: FieldReadyRuntimeProofReport.self
        ),
        reportValidator(
            group: "HardwareValidationReports",
            schemaName: "HardwareValidationReport",
            fixtures: ["hardware-validation-partial.json"],
            as: HardwareValidationReport.self
        ),
        reportValidator(
            group: "IntegratedAvReports",
            schemaName: "IntegratedAvReport",
            fixtures: ["integrated-av-partial.json"],
            as: IntegratedAvReport.self
        ),
        reportValidator(
            group: "IntegratedProfileReports",
            schemaName: "IntegratedProfileReport",
            fixtures: ["integrated-profile-partial.json"],
            as: IntegratedProfileReport.self
        ),
        reportValidator(
            group: "LatencyBenchmarkReports",
            schemaName: "LatencyBenchmarkReport",
            fixtures: ["latency-benchmark-partial.json"],
            as: LatencyBenchmarkReport.self
        ),
        reportValidator(
            group: "LatencyTuningReports",
            schemaName: "LatencyTuningReport",
            fixtures: ["latency-tuning-partial.json"],
            as: LatencyTuningReport.self
        ),
        reportValidator(
            group: "LightingFixtureGateReports",
            schemaName: "LightingFixtureGateReport",
            fixtures: ["lighting-gate-partial.json"],
            as: LightingFixtureGateReport.self
        ),
        reportValidator(
            group: "LoLaParityDeferredLedgers",
            schemaName: "LoLaParityDeferredLedgerReport",
            fixtures: ["lola-parity-deferred-ledger-partial.json"],
            as: LoLaParityDeferredLedgerReport.self
        ),
        reportValidator(
            group: "MacToMacRouteCertificationReports",
            schemaName: "MacToMacRouteCertificationReport",
            fixtures: ["g04-route-certification-partial.json"],
            as: MacToMacRouteCertificationReport.self
        ),
        reportValidator(
            group: "MeasurementReports",
            schemaName: "MeasurementReport",
            fixtures: [
                "endpoint-valid.json",
                "field-test-valid.json",
                "lighting-valid.json",
                "network-valid.json",
                "video-valid.json",
            ]
        ) { data in
            let report = try MeasurementReport.decode(from: data)
            try report.validate()
        },
        reportValidator(
            group: "NativeAppShellReports",
            schemaName: "NativeAppShellReport",
            fixtures: ["native-app-shell-partial.json"],
            as: NativeAppShellReport.self
        ),
        reportValidator(
            group: "NetworkAoipCertificationReports",
            schemaName: "NetworkAoipCertificationReport",
            fixtures: ["g06-network-aoip-certification-partial.json"],
            as: NetworkAoipCertificationReport.self
        ),
        reportValidator(
            group: "OscCueReports",
            schemaName: "OscCueReport",
            fixtures: ["osc-cue-partial.json"],
            as: OscCueReport.self
        ),
        reportValidator(
            group: "OpenSourceReleaseReadinessReports",
            schemaName: "OpenSourceReleaseReadinessReport",
            fixtures: ["open-source-release-readiness-pass.json"],
            as: OpenSourceReleaseReadinessReport.self
        ),
        reportValidator(
            group: "PackagingFieldTests",
            schemaName: "PackagingFieldTestReport",
            fixtures: ["packaging-field-test-partial.json"],
            as: PackagingFieldTestReport.self
        ),
        reportValidator(
            group: "RealtimeAudioEngineReports",
            schemaName: "RealtimeAudioEngineReport",
            fixtures: ["realtime-audio-engine-partial.json"],
            as: RealtimeAudioEngineReport.self
        ),
        reportValidator(
            group: "RecordingSessionArtifacts",
            schemaName: "RecordingSessionArtifactReport",
            fixtures: ["recording-session-partial.json"],
            as: RecordingSessionArtifactReport.self
        ),
        reportValidator(
            group: "ReferenceRigReports",
            schemaName: "ReferenceRigReport",
            fixtures: ["reference-rig-partial.json"],
            as: ReferenceRigReport.self
        ),
        reportValidator(
            group: "ReleaseHardeningReports",
            schemaName: "ReleaseHardeningReport",
            fixtures: ["release-hardening-partial.json"],
            as: ReleaseHardeningReport.self
        ),
        reportValidator(
            group: "RmeFastestAudioPathReports",
            schemaName: "RmeFastestAudioPathReport",
            fixtures: ["rme-fastest-audio-partial.json"],
            as: RmeFastestAudioPathReport.self
        ),
        reportValidator(
            group: "UdpPcmPackets",
            schemaName: "UdpPcmPacket",
            fixtures: ["valid-stereo-float32.hex", "valid-stereo-int16.hex"]
        ) { data in
            let packetData = try UdpPcmHexFixture.decode(data)
            let packet = try UdpPcmPacket.decode(packetData)
            #expect(try packet.encoded() == packetData)
        },
        reportValidator(
            group: "UdpPcmRoutes",
            schemaName: "UdpPcmRouteReport",
            fixtures: ["direct-link-pass.json"],
            as: UdpPcmRouteReport.self
        ),
        reportValidator(
            group: "VideoCaptureReports",
            schemaName: "VideoCaptureReport",
            fixtures: ["video-capture-partial.json"],
            as: VideoCaptureReport.self
        ),
        reportValidator(
            group: "VideoTransportReports",
            schemaName: "VideoTransportReport",
            fixtures: ["video-transport-partial.json"],
            as: VideoTransportReport.self
        ),
    ]
}

private var reportFixtureRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")
}

private func reportValidator<Report: ReportValidatingArtifact>(
    group: String,
    schemaName: String,
    fixtures: [String],
    as type: Report.Type
) -> ReportFixtureValidationCase {
    reportValidator(group: group, schemaName: schemaName, fixtures: fixtures) { data in
        _ = try ReportValidatorSurface.validate(data, as: type, label: schemaName)
    }
}

private func reportValidator(
    group: String,
    schemaName: String,
    fixtures: [String],
    validate: @escaping (Data) throws -> Void
) -> ReportFixtureValidationCase {
    ReportFixtureValidationCase(
        group: group,
        schemaName: schemaName,
        acceptedValidFixtures: fixtures,
        validate: validate
    )
}

private func duplicateFixtureValidationGroups(
    in cases: [ReportFixtureValidationCase]
) -> [String] {
    var seen: Set<String> = []
    var duplicates: Set<String> = []

    for testCase in cases where !seen.insert(testCase.group).inserted {
        duplicates.insert(testCase.group)
    }

    return duplicates.sorted()
}
