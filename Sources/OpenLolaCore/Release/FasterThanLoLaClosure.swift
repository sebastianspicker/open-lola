import Foundation

public typealias FasterThanLoLaClosureRunMode = MeasurementMethodology

public enum FasterThanLoLaClaimScope: String, Codable, Equatable, Sendable {
    case audioOnly
    case audioVideo
    case audioVideoLighting
    case fieldReady

    public var requiredEvidenceLanes: [FasterThanLoLaEvidenceLane] {
        switch self {
        case .audioOnly:
            [
                .f01RmeMadiHardwareBaseline,
                .f02RealtimeDuplexAudioEngine,
                .f03PeerToPeerRoute,
                .f04DriftPlcLolaBaseline,
            ]
        case .audioVideo:
            FasterThanLoLaClaimScope.audioOnly.requiredEvidenceLanes + [
                .f05BlackmagicAtemCapture,
                .f06VideoTransport,
                .f07IntegratedRuntime,
            ]
        case .audioVideoLighting:
            FasterThanLoLaClaimScope.audioVideo.requiredEvidenceLanes + [
                .f08LightingWorkflow,
            ]
        case .fieldReady:
            FasterThanLoLaClaimScope.audioVideoLighting.requiredEvidenceLanes + [
                .f09FieldReadiness,
            ]
        }
    }
}

public enum FasterThanLoLaEvidenceLane: String, Codable, Equatable, Hashable, Sendable {
    case f01RmeMadiHardwareBaseline
    case f02RealtimeDuplexAudioEngine
    case f03PeerToPeerRoute
    case f04DriftPlcLolaBaseline
    case f05BlackmagicAtemCapture
    case f06VideoTransport
    case f07IntegratedRuntime
    case f08LightingWorkflow
    case f09FieldReadiness
}

public struct FasterThanLoLaEvidenceReference: Codable, Equatable, Sendable {
    public var lane: FasterThanLoLaEvidenceLane
    public var reportId: String
    public var verdict: MeasurementVerdict
    public var measured: Bool
    public var physicalOrCleanMacEvidence: Bool
    public var packetCaptureOrArtifactEvidence: Bool
    public var notes: String

    public init(
        lane: FasterThanLoLaEvidenceLane,
        reportId: String,
        verdict: MeasurementVerdict,
        measured: Bool,
        physicalOrCleanMacEvidence: Bool,
        packetCaptureOrArtifactEvidence: Bool,
        notes: String
    ) {
        self.lane = lane
        self.reportId = reportId
        self.verdict = verdict
        self.measured = measured
        self.physicalOrCleanMacEvidence = physicalOrCleanMacEvidence
        self.packetCaptureOrArtifactEvidence = packetCaptureOrArtifactEvidence
        self.notes = notes
    }
}

public struct FasterThanLoLaBenchmarkComparison: Codable, Equatable, Sendable {
    public var lolaBaselineReportId: String
    public var openLolaReportId: String
    public var lolaVersion: String
    public var lolaSettings: String
    public var routeLabel: String
    public var packetMode: UdpPcmPacketMode
    public var fixedPlayoutTargetFrames: Int
    public var durationSeconds: Int
    public var lolaBaselineMeasured: Bool
    public var measuredOnSameHardwareAndRoute: Bool
    public var openLolaLatency: LolaBaselineLatencyMetrics
    public var lolaLatency: LolaBaselineLatencyMetrics
    public var lostPackets: Int
    public var latePackets: Int
    public var underruns: Int
    public var maxAbsoluteDriftPpm: Double
    public var artifactsDetected: Bool
    public var result: LolaBaselineComparisonResult

    public init(
        lolaBaselineReportId: String,
        openLolaReportId: String,
        lolaVersion: String,
        lolaSettings: String,
        routeLabel: String,
        packetMode: UdpPcmPacketMode,
        fixedPlayoutTargetFrames: Int,
        durationSeconds: Int,
        lolaBaselineMeasured: Bool,
        measuredOnSameHardwareAndRoute: Bool,
        openLolaLatency: LolaBaselineLatencyMetrics,
        lolaLatency: LolaBaselineLatencyMetrics,
        lostPackets: Int,
        latePackets: Int,
        underruns: Int,
        maxAbsoluteDriftPpm: Double,
        artifactsDetected: Bool,
        result: LolaBaselineComparisonResult
    ) {
        self.lolaBaselineReportId = lolaBaselineReportId
        self.openLolaReportId = openLolaReportId
        self.lolaVersion = lolaVersion
        self.lolaSettings = lolaSettings
        self.routeLabel = routeLabel
        self.packetMode = packetMode
        self.fixedPlayoutTargetFrames = fixedPlayoutTargetFrames
        self.durationSeconds = durationSeconds
        self.lolaBaselineMeasured = lolaBaselineMeasured
        self.measuredOnSameHardwareAndRoute = measuredOnSameHardwareAndRoute
        self.openLolaLatency = openLolaLatency
        self.lolaLatency = lolaLatency
        self.lostPackets = lostPackets
        self.latePackets = latePackets
        self.underruns = underruns
        self.maxAbsoluteDriftPpm = maxAbsoluteDriftPpm
        self.artifactsDetected = artifactsDetected
        self.result = result
    }
}

public enum FasterThanLoLaClosureValidationError: Error, Equatable, Sendable,
    ValidationEmptyFieldError,
    ValidationEmptyListError,
    ValidationNonPositiveFieldError,
    ValidationNegativeFieldError,
    ValidationNonFiniteFieldError {
    case emptyField(String)
    case emptyList(String)
    case duplicateEvidenceLane(FasterThanLoLaEvidenceLane)
    case nonPositiveField(String)
    case negativeField(String)
    case nonFiniteField(String)
    case unorderedLatencyMetrics(String)
    case passWithoutMeasuredRun
    case passWithoutRequiredEvidence(FasterThanLoLaEvidenceLane)
    case passWithoutMeasuredEvidence(FasterThanLoLaEvidenceLane)
    case passWithoutPassEvidence(FasterThanLoLaEvidenceLane, MeasurementVerdict)
    case passWithoutPhysicalOrCleanMacEvidence(FasterThanLoLaEvidenceLane)
    case passWithoutPacketCaptureOrArtifactEvidence(FasterThanLoLaEvidenceLane)
    case passWithoutMeasuredLolaBaseline
    case passWithoutSameHardwareAndRoute
    case passWithoutOpenLolaFaster(LolaBaselineComparisonResult)
    case passWithoutLatencyWin(String)
    case passWithRunShorterThanSixtyMinutes
    case passWithoutFixedPlayoutTarget
    case passWithLossLateUnderrunOrArtifacts
    case passWithoutParityLedger
    case passWithoutParityDeferral
    case passBlocksFastestPathByParity
}

enum FasterThanLoLaClosureValidator: ReportPrimitiveValidating {
    typealias ValidationError = FasterThanLoLaClosureValidationError
}

public struct FasterThanLoLaClosureReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var capturedAt: String
    public var runMode: FasterThanLoLaClosureRunMode
    public var claimScope: FasterThanLoLaClaimScope
    public var evidence: [FasterThanLoLaEvidenceReference]
    public var comparison: FasterThanLoLaBenchmarkComparison
    public var parityLedgerId: String
    public var parityFeaturesDeferred: Bool
    public var windowsWireCompatibilityDeferred: Bool
    public var fastestPathBlockedByParity: Bool
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        title: String,
        capturedAt: String,
        runMode: FasterThanLoLaClosureRunMode,
        claimScope: FasterThanLoLaClaimScope,
        evidence: [FasterThanLoLaEvidenceReference],
        comparison: FasterThanLoLaBenchmarkComparison,
        parityLedgerId: String,
        parityFeaturesDeferred: Bool,
        windowsWireCompatibilityDeferred: Bool,
        fastestPathBlockedByParity: Bool,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
        self.runMode = runMode
        self.claimScope = claimScope
        self.evidence = evidence
        self.comparison = comparison
        self.parityLedgerId = parityLedgerId
        self.parityFeaturesDeferred = parityFeaturesDeferred
        self.windowsWireCompatibilityDeferred = windowsWireCompatibilityDeferred
        self.fastestPathBlockedByParity = fastestPathBlockedByParity
        self.verdict = verdict
        self.notes = notes
    }
}

public enum FasterThanLoLaClosureSyntheticSmoke {
    public static func run() -> FasterThanLoLaClosureReport {
        FasterThanLoLaClosureReport(
            id: "f10-faster-than-lola-closure-synthetic-smoke",
            title: "Synthetic F10 faster-than-LoLa closure",
            capturedAt: "2026-05-03T00:00:00Z",
            runMode: .synthetic,
            claimScope: .fieldReady,
            evidence: FasterThanLoLaClaimScope.fieldReady.requiredEvidenceLanes.map { lane in
                FasterThanLoLaEvidenceReference(
                    lane: lane,
                    reportId: "\(lane.rawValue)-required",
                    verdict: .partial,
                    measured: false,
                    physicalOrCleanMacEvidence: false,
                    packetCaptureOrArtifactEvidence: false,
                    notes: "Required F10 evidence lane; measured PASS report not supplied."
                )
            },
            comparison: unavailableFasterThanLoLaComparison(),
            parityLedgerId: "g16-lola-parity-deferred-synthetic-smoke",
            parityFeaturesDeferred: true,
            windowsWireCompatibilityDeferred: true,
            fastestPathBlockedByParity: false,
            verdict: .partial,
            notes: "Synthetic F10 closure ledger; no faster-than-LoLa claim is made."
        )
    }
}

/// CLI and programmatic input contract for faster-than-LoLa closure evidence aggregation.
public struct FasterThanLoLaClosureRunConfiguration: Codable, Equatable, Sendable {
    public let claimScope: FasterThanLoLaClaimScope
    public let reportIds: [FasterThanLoLaEvidenceLane: String]
    public let outputPath: String

    public init(
        claimScope: FasterThanLoLaClaimScope,
        reportIds: [FasterThanLoLaEvidenceLane: String],
        outputPath: String
    ) {
        self.claimScope = claimScope
        self.reportIds = reportIds
        self.outputPath = outputPath
    }

    public static func parse(_ arguments: [String]) throws -> FasterThanLoLaClosureRunConfiguration {
        let laneArguments = fasterThanLoLaLaneArguments()
        let allowed = Set(["--claim-scope", "--output"] + laneArguments.keys)
        let values = try KeyValueArgumentParser.parseValues(
            arguments,
            allowed: allowed,
            unknown: FasterThanLoLaClosureRunConfigurationError.unknownArgument,
            duplicate: FasterThanLoLaClosureRunConfigurationError.duplicateArgument,
            missingValue: FasterThanLoLaClosureRunConfigurationError.missingValue
        )

        let claimScope = try requiredFasterThanLoLaClaimScope(values)
        var reportIds: [FasterThanLoLaEvidenceLane: String] = [:]
        for lane in claimScope.requiredEvidenceLanes {
            let argument = laneArguments.first { $0.value == lane }?.key ?? ""
            reportIds[lane] = try requiredFasterThanLoLaRunString(argument, values)
        }

        return FasterThanLoLaClosureRunConfiguration(
            claimScope: claimScope,
            reportIds: reportIds,
            outputPath: try requiredFasterThanLoLaRunString("--output", values)
        )
    }
}

public enum FasterThanLoLaClosureRunConfigurationError: Error, Equatable, Sendable {
    case missingRequiredArgument(String)
    case missingValue(String)
    case unknownArgument(String)
    case duplicateArgument(String)
    case invalidClaimScope(String)
}

public enum FasterThanLoLaClosureRunner {
    public static func run(configuration: FasterThanLoLaClosureRunConfiguration) -> FasterThanLoLaClosureReport {
        FasterThanLoLaClosureReport(
            id: "f10-faster-than-lola-closure-run",
            title: "F10 faster-than-LoLa closure handoff",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            runMode: .synthetic,
            claimScope: configuration.claimScope,
            evidence: configuration.claimScope.requiredEvidenceLanes.map { lane in
                FasterThanLoLaEvidenceReference(
                    lane: lane,
                    reportId: configuration.reportIds[lane] ?? "\(lane.rawValue)-required",
                    verdict: .partial,
                    measured: false,
                    physicalOrCleanMacEvidence: false,
                    packetCaptureOrArtifactEvidence: false,
                    notes: "Bounded F10 handoff records the report reference; measured PASS evidence still has to be validated."
                )
            },
            comparison: unavailableFasterThanLoLaComparison(),
            parityLedgerId: "g16-lola-parity-deferred-ledger-required",
            parityFeaturesDeferred: true,
            windowsWireCompatibilityDeferred: true,
            fastestPathBlockedByParity: false,
            verdict: .partial,
            notes: "Bounded F10 closure handoff; faster-than-LoLa PASS requires measured F01-F04 evidence and a measured LoLa baseline."
        )
    }
}

private func unavailableFasterThanLoLaComparison() -> FasterThanLoLaBenchmarkComparison {
    FasterThanLoLaBenchmarkComparison(
        lolaBaselineReportId: "measured-lola-baseline-required",
        openLolaReportId: "measured-open-lola-baseline-required",
        lolaVersion: "not-measured",
        lolaSettings: "not-measured",
        routeLabel: "not-measured",
        packetMode: UdpPcmPacketMode(
            sampleRateHertz: 48_000,
            framesPerPacket: 32,
            channelCount: 2,
            sampleFormat: .float32LittleEndian
        ),
        fixedPlayoutTargetFrames: 0,
        durationSeconds: 0,
        lolaBaselineMeasured: false,
        measuredOnSameHardwareAndRoute: false,
        openLolaLatency: LolaBaselineLatencyMetrics(
            p50Milliseconds: 1,
            p95Milliseconds: 1,
            p99Milliseconds: 1,
            maxMilliseconds: 1
        ),
        lolaLatency: LolaBaselineLatencyMetrics(
            p50Milliseconds: 1,
            p95Milliseconds: 1,
            p99Milliseconds: 1,
            maxMilliseconds: 1
        ),
        lostPackets: 0,
        latePackets: 0,
        underruns: 0,
        maxAbsoluteDriftPpm: 0,
        artifactsDetected: false,
        result: .unavailable
    )
}

private func fasterThanLoLaLaneArguments() -> [String: FasterThanLoLaEvidenceLane] {
    [
        "--f01-report": .f01RmeMadiHardwareBaseline,
        "--f02-report": .f02RealtimeDuplexAudioEngine,
        "--f03-report": .f03PeerToPeerRoute,
        "--f04-report": .f04DriftPlcLolaBaseline,
        "--f05-report": .f05BlackmagicAtemCapture,
        "--f06-report": .f06VideoTransport,
        "--f07-report": .f07IntegratedRuntime,
        "--f08-report": .f08LightingWorkflow,
        "--f09-report": .f09FieldReadiness,
    ]
}

private func requiredFasterThanLoLaClaimScope(
    _ values: [String: String]
) throws -> FasterThanLoLaClaimScope {
    let value = try requiredFasterThanLoLaRunString("--claim-scope", values)
    guard let scope = FasterThanLoLaClaimScope(rawValue: value) else {
        throw FasterThanLoLaClosureRunConfigurationError.invalidClaimScope(value)
    }
    return scope
}

private func requiredFasterThanLoLaRunString(
    _ argument: String,
    _ values: [String: String]
) throws -> String {
    guard let value = values[argument], !value.isEmpty else {
        throw FasterThanLoLaClosureRunConfigurationError.missingRequiredArgument(argument)
    }
    return value
}
