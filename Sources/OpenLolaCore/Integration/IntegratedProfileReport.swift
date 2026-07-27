// Defines and validates profile options, subordinate evidence, benchmarks, degradation, and verdicts.
import Foundation
import OpenLolaContracts

/// Records the evidence and outcome for integrated profile report.
public struct IntegratedProfileReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public enum IdentityDomain {}
    public typealias Identity = ImmutableReportIdentity<IdentityDomain>

    public struct Profile: Sendable {
        public let defaultLabel: IntegratedProfileLabel
        public let options: [IntegratedProfileOption]

        public init(defaultLabel: IntegratedProfileLabel, options: [IntegratedProfileOption]) {
            self.defaultLabel = defaultLabel
            self.options = options
        }
    }

    public struct Evidence: Sendable {
        public let subordinate: [IntegratedProfileSubordinateEvidence]
        public let degradationOrder: [IntegratedProfileDegradationStep]
        public let benchmarkMatrix: [IntegratedProfileBenchmarkRow]

        public init(
            subordinate: [IntegratedProfileSubordinateEvidence],
            degradationOrder: [IntegratedProfileDegradationStep],
            benchmarkMatrix: [IntegratedProfileBenchmarkRow]
        ) {
            self.subordinate = subordinate
            self.degradationOrder = degradationOrder
            self.benchmarkMatrix = benchmarkMatrix
        }
    }

    public enum OutcomeDomain {}
    public typealias Outcome = ImmutableReportOutcome<OutcomeDomain>

    public var id: String
    public var title: String
    public var capturedAt: String
    public var runMode: ReportRunMode
    public var defaultProfile: IntegratedProfileLabel
    public var profileOptions: [IntegratedProfileOption]
    public var subordinateEvidence: [IntegratedProfileSubordinateEvidence]
    public var degradationOrder: [IntegratedProfileDegradationStep]
    public var benchmarkMatrix: [IntegratedProfileBenchmarkRow]
    public var verdict: MeasurementVerdict
    public var notes: String

    public var aggregateSubordinateVerdict: MeasurementVerdict {
        aggregateIntegratedProfileVerdicts(
            profileOptions.map(\.verdict)
                + subordinateEvidence.map(\.verdict)
                + benchmarkMatrix.map(\.verdict)
        )
    }

    public init(
        identity: Identity,
        profile: Profile,
        evidence: Evidence,
        outcome: Outcome
    ) {
        self.id = identity.id
        self.title = identity.title
        self.capturedAt = identity.capturedAt
        self.runMode = identity.runMode
        self.defaultProfile = profile.defaultLabel
        self.profileOptions = profile.options
        self.subordinateEvidence = evidence.subordinate
        self.degradationOrder = evidence.degradationOrder
        self.benchmarkMatrix = evidence.benchmarkMatrix
        self.verdict = outcome.verdict
        self.notes = outcome.notes
    }
}

let requiredIntegratedProfileOptions: [IntegratedProfileLabel] = [
    .fastestAudio,
    .audioVideo,
    .audioLighting,
    .audioVideoLighting
]

// swiftlint:disable:next identifier_name
let requiredIntegratedProfileSubordinateLanes: [IntegratedProfileSubordinateLane] = [
    .fastestAudio,
    .audioRoute,
    .videoCapture,
    .videoTransport,
    .integratedAv,
    .lightingControl
]

// swiftlint:disable:next identifier_name
let requiredIntegratedProfileBenchmarkScenarios: [IntegratedProfileBenchmarkScenario] = [
    .audioOnly,
    .audioVideo,
    .audioControl,
    .audioVideoControl
]

let integratedProfileCostScenarios: [
    (IntegratedProfileLabel, IntegratedProfileBenchmarkScenario)
] = [
    (.audioVideo, .audioVideo),
    (.audioLighting, .audioControl),
    (.audioVideoLighting, .audioVideoControl)
]

private func aggregateIntegratedProfileVerdicts(_ verdicts: [MeasurementVerdict]) -> MeasurementVerdict {
    if verdicts.contains(.fail) {
        return .fail
    }
    if verdicts.allSatisfy({ $0 == .pass }) {
        return .pass
    }
    return .partial
}

func requireIntegratedProfileNonEmpty(_ value: String, _ field: String) throws {
    if value.isEmpty {
        throw IntegratedProfileValidationError.emptyField(field)
    }
}

func requireIntegratedProfilePassText(_ value: String, field: String) throws {
    try requireIntegratedProfileNonEmpty(value, field)
    if isIntegratedProfilePlaceholder(value) {
        throw IntegratedProfileValidationError.passWithPlaceholderEvidenceField(field)
    }
}

func requireIntegratedProfileList<T>(_ value: [T], _ field: String) throws {
    if value.isEmpty {
        throw IntegratedProfileValidationError.emptyList(field)
    }
}

func requireIntegratedProfileNonNegative(_ value: Int, _ field: String) throws {
    if value < 0 {
        throw IntegratedProfileValidationError.negativeField(field)
    }
}

func requireIntegratedProfileNonNegative(_ value: Double, _ field: String) throws {
    if !value.isFinite {
        throw IntegratedProfileValidationError.nonFiniteField(field)
    }
    if value < 0 {
        throw IntegratedProfileValidationError.negativeField(field)
    }
}

func requireIntegratedProfilePercent(_ value: Double, _ field: String) throws {
    if !value.isFinite {
        throw IntegratedProfileValidationError.nonFiniteField(field)
    }
    if value < 0 || value > 100 {
        throw IntegratedProfileValidationError.percentOutOfRange(field: field, value: value)
    }
}

private func isIntegratedProfilePlaceholder(_ value: String) -> Bool {
    PlaceholderDetection.matches(
        value,
        containing: [
            PlaceholderDetection.manualEvidenceToken,
            "placeholder",
            "fixture",
            "synthetic",
            "required",
            "not-measured"
        ],
        exactly: ["unknown", "tbd"]
    )
}
