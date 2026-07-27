// Joins claim scope, evidence lanes, benchmark comparison, and runtime inputs so faster-than-LoLa wording cannot exceed its measured proof.
import Foundation

/// Identifies the measurement methodology recorded with faster-than-LoLa closure artifacts so consumers distinguish measured, synthetic, and sandbox-limited results.
public typealias FasterThanLoLaClosureRunMode = MeasurementMethodology

/// Defines the finite structured result values recorded by faster-than-LoLa closure artifacts for deterministic validation and report interpretation.
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
                .f04DriftPlcLolaBaseline
            ]
        case .audioVideo:
            FasterThanLoLaClaimScope.audioOnly.requiredEvidenceLanes + [
                .f05BlackmagicAtemCapture,
                .f06VideoTransport,
                .f07IntegratedRuntime
            ]
        case .audioVideoLighting:
            FasterThanLoLaClaimScope.audioVideo.requiredEvidenceLanes + [
                .f08LightingWorkflow
            ]
        case .fieldReady:
            FasterThanLoLaClaimScope.audioVideoLighting.requiredEvidenceLanes + [
                .f09FieldReadiness
            ]
        }
    }
}

/// Defines the finite evidence provenance values recorded by faster-than-LoLa closure artifacts for deterministic validation and report interpretation.
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

/// Captures evidence provenance required to validate, interpret, and reproduce a faster-than-LoLa closure result.
public struct FasterThanLoLaEvidenceReference: Codable, Equatable, Sendable {
    public struct Identity: Codable, Equatable, Sendable {
        public var lane: FasterThanLoLaEvidenceLane
        public var reportId: String

        public init(lane: FasterThanLoLaEvidenceLane, reportId: String) {
            self.lane = lane
            self.reportId = reportId
        }
    }

    public struct Measurement: Codable, Equatable, Sendable {
        public var verdict: MeasurementVerdict
        public var measured: Bool

        public init(verdict: MeasurementVerdict, measured: Bool) {
            self.verdict = verdict
            self.measured = measured
        }
    }

    public struct Provenance: Codable, Equatable, Sendable {
        public var physicalOrCleanMacEvidence: Bool
        public var packetCaptureOrArtifactEvidence: Bool
        public var notes: String

        public init(
            physicalOrCleanMacEvidence: Bool,
            packetCaptureOrArtifactEvidence: Bool,
            notes: String
        ) {
            self.physicalOrCleanMacEvidence = physicalOrCleanMacEvidence
            self.packetCaptureOrArtifactEvidence = packetCaptureOrArtifactEvidence
            self.notes = notes
        }
    }

    public struct Input: Codable, Equatable, Sendable {
        public var identity: Identity
        public var measurement: Measurement
        public var provenance: Provenance

        public init(identity: Identity, measurement: Measurement, provenance: Provenance) {
            self.identity = identity
            self.measurement = measurement
            self.provenance = provenance
        }
    }

    public var lane: FasterThanLoLaEvidenceLane
    public var reportId: String
    public var verdict: MeasurementVerdict
    public var measured: Bool
    public var physicalOrCleanMacEvidence: Bool
    public var packetCaptureOrArtifactEvidence: Bool
    public var notes: String

    public init(_ input: Input) {
        self.lane = input.identity.lane
        self.reportId = input.identity.reportId
        self.verdict = input.measurement.verdict
        self.measured = input.measurement.measured
        self.physicalOrCleanMacEvidence = input.provenance.physicalOrCleanMacEvidence
        self.packetCaptureOrArtifactEvidence = input.provenance.packetCaptureOrArtifactEvidence
        self.notes = input.provenance.notes
    }
}

/// Describes failures that prevent faster-than-LoLa closure inputs or evidence from satisfying the required validation invariants.
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
    // swiftlint:disable:next identifier_name
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

/// Captures report contents required to validate, interpret, and reproduce a faster-than-LoLa closure result.
public struct FasterThanLoLaClosureReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public struct Metadata: Codable, Equatable, Sendable {
        public var id: String
        public var title: String
        public var capturedAt: String
        public var runMode: FasterThanLoLaClosureRunMode
        public var claimScope: FasterThanLoLaClaimScope

        public init(
            id: String,
            title: String,
            capturedAt: String,
            runMode: FasterThanLoLaClosureRunMode,
            claimScope: FasterThanLoLaClaimScope
        ) {
            self.id = id
            self.title = title
            self.capturedAt = capturedAt
            self.runMode = runMode
            self.claimScope = claimScope
        }
    }

    public struct ClaimEvidence: Codable, Equatable, Sendable {
        public var evidence: [FasterThanLoLaEvidenceReference]
        public var comparison: FasterThanLoLaBenchmarkComparison

        public init(
            evidence: [FasterThanLoLaEvidenceReference],
            comparison: FasterThanLoLaBenchmarkComparison
        ) {
            self.evidence = evidence
            self.comparison = comparison
        }
    }

    public struct Parity: Codable, Equatable, Sendable {
        public var ledgerID: String
        public var featuresDeferred: Bool
        public var windowsWireCompatibilityDeferred: Bool
        public var fastestPathBlocked: Bool

        public init(
            ledgerID: String,
            featuresDeferred: Bool,
            windowsWireCompatibilityDeferred: Bool,
            fastestPathBlocked: Bool
        ) {
            self.ledgerID = ledgerID
            self.featuresDeferred = featuresDeferred
            self.windowsWireCompatibilityDeferred = windowsWireCompatibilityDeferred
            self.fastestPathBlocked = fastestPathBlocked
        }
    }

    public enum OutcomeDomain {}
    public typealias Outcome = MutableReportOutcome<OutcomeDomain>

    public struct Input: Codable, Equatable, Sendable {
        public var metadata: Metadata
        public var claimEvidence: ClaimEvidence
        public var parity: Parity
        public var outcome: Outcome

        public init(
            metadata: Metadata,
            claimEvidence: ClaimEvidence,
            parity: Parity,
            outcome: Outcome
        ) {
            self.metadata = metadata
            self.claimEvidence = claimEvidence
            self.parity = parity
            self.outcome = outcome
        }
    }
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

    public init(_ input: Input) {
        ((self.id, self.title), (self.capturedAt, self.runMode)) = reportMetadataValues(input.metadata)
        self.claimScope = input.metadata.claimScope
        self.evidence = input.claimEvidence.evidence
        self.comparison = input.claimEvidence.comparison
        self.parityLedgerId = input.parity.ledgerID
        self.parityFeaturesDeferred = input.parity.featuresDeferred
        self.windowsWireCompatibilityDeferred = input.parity.windowsWireCompatibilityDeferred
        self.fastestPathBlockedByParity = input.parity.fastestPathBlocked
        self.verdict = input.outcome.verdict
        self.notes = input.outcome.notes
    }
}

extension FasterThanLoLaClosureReport.Metadata: ReportMetadataFields {}

/// Creates deterministic synthetic faster-than-LoLa closure evidence that exercises report validation without claiming physical measurement.
public enum FasterThanLoLaClosureSyntheticSmoke {
    public static func run() -> FasterThanLoLaClosureReport {
        let evidence = FasterThanLoLaClaimScope.fieldReady.requiredEvidenceLanes.map { lane in
            partialFasterThanLoLaEvidence(
                lane: lane,
                reportId: "\(lane.rawValue)-required",
                notes: "Required F10 evidence lane; measured PASS report not supplied."
            )
        }
        let metadata = FasterThanLoLaClosureReport.Metadata(
            id: "f10-faster-than-lola-closure-synthetic-smoke",
            title: "Synthetic F10 faster-than-LoLa closure",
            capturedAt: "2026-05-03T00:00:00Z",
            runMode: .synthetic,
            claimScope: .fieldReady
        )
        return makePartialFasterThanLoLaClosureReport(
            metadata: metadata,
            evidence: evidence,
            parityLedgerId: "g16-lola-parity-deferred-synthetic-smoke",
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

// swiftlint:disable:next type_name
/// Describes failures that prevent faster-than-LoLa closure inputs or evidence from satisfying the required validation invariants.
public enum FasterThanLoLaClosureRunConfigurationError: Error, Equatable, Sendable {
    case missingRequiredArgument(String)
    case missingValue(String)
    case unknownArgument(String)
    case duplicateArgument(String)
    case invalidClaimScope(String)
}

/// Runs the faster-than-LoLa closure evaluation from supplied artifacts while retaining their measurement provenance in the resulting report.
public enum FasterThanLoLaClosureRunner {
    public static func run(configuration: FasterThanLoLaClosureRunConfiguration) -> FasterThanLoLaClosureReport {
        let evidence = configuration.claimScope.requiredEvidenceLanes.map { lane in
            partialFasterThanLoLaEvidence(
                lane: lane,
                reportId: configuration.reportIds[lane] ?? "\(lane.rawValue)-required",
                notes: "Bounded F10 handoff records the report reference; measured PASS " +
                    "evidence still has to be validated."
            )
        }
        let metadata = FasterThanLoLaClosureReport.Metadata(
            id: "f10-faster-than-lola-closure-run",
            title: "F10 faster-than-LoLa closure handoff",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            runMode: .synthetic,
            claimScope: configuration.claimScope
        )
        return makePartialFasterThanLoLaClosureReport(
            metadata: metadata,
            evidence: evidence,
            parityLedgerId: "g16-lola-parity-deferred-ledger-required",
            notes: "Bounded F10 closure handoff; faster-than-LoLa PASS requires " +
                "measured F01-F04 evidence and a measured LoLa baseline."
        )
    }
}

private func unavailableFasterThanLoLaComparison() -> FasterThanLoLaBenchmarkComparison {
    let latency = LolaBaselineLatencyMetrics(
        p50Milliseconds: 1,
        p95Milliseconds: 1,
        p99Milliseconds: 1,
        maxMilliseconds: 1
    )
    let input = FasterThanLoLaBenchmarkComparison.Input(
        baselineIdentity: FasterThanLoLaBenchmarkComparison.BaselineIdentity(
            lolaBaselineReportID: "measured-lola-baseline-required",
            openLolaReportID: "measured-open-lola-baseline-required",
            lolaVersion: "not-measured",
            lolaSettings: "not-measured",
            routeLabel: "not-measured"
        ),
        packetRun: FasterThanLoLaBenchmarkComparison.PacketRun(
            packetMode: UdpPcmPacketMode(
                sampleRateHertz: 48_000,
                framesPerPacket: 32,
                channelCount: 2,
                sampleFormat: .float32LittleEndian
            ),
            fixedPlayoutTargetFrames: 0,
            durationSeconds: 0
        ),
        measurements: FasterThanLoLaBenchmarkComparison.Measurements(
            lolaBaselineMeasured: false,
            sameHardwareAndRoute: false,
            openLolaLatency: latency,
            lolaLatency: latency
        ),
        quality: FasterThanLoLaBenchmarkComparison.Quality(
            packetHealth: .init(lostPackets: 0, latePackets: 0, underruns: 0),
            assessment: .init(
                maxAbsoluteDriftPpm: 0,
                artifactsDetected: false,
                result: .unavailable
            )
        )
    )
    return FasterThanLoLaBenchmarkComparison(input)
}

private func partialFasterThanLoLaEvidence(
    lane: FasterThanLoLaEvidenceLane,
    reportId: String,
    notes: String
) -> FasterThanLoLaEvidenceReference {
    FasterThanLoLaEvidenceReference(
        FasterThanLoLaEvidenceReference.Input(
            identity: .init(lane: lane, reportId: reportId),
            measurement: .init(verdict: .partial, measured: false),
            provenance: .init(
                physicalOrCleanMacEvidence: false,
                packetCaptureOrArtifactEvidence: false,
                notes: notes
            )
        )
    )
}

private func makePartialFasterThanLoLaClosureReport(
    metadata: FasterThanLoLaClosureReport.Metadata,
    evidence: [FasterThanLoLaEvidenceReference],
    parityLedgerId: String,
    notes: String
) -> FasterThanLoLaClosureReport {
    let input = FasterThanLoLaClosureReport.Input(
        metadata: metadata,
        claimEvidence: .init(
            evidence: evidence,
            comparison: unavailableFasterThanLoLaComparison()
        ),
        parity: .init(
            ledgerID: parityLedgerId,
            featuresDeferred: true,
            windowsWireCompatibilityDeferred: true,
            fastestPathBlocked: false
        ),
        outcome: .init(verdict: .partial, notes: notes)
    )
    return FasterThanLoLaClosureReport(input)
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
        "--f09-report": .f09FieldReadiness
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
