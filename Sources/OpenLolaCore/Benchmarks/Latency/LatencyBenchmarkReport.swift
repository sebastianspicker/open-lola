// Collects latency measurement evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
import Foundation

/// Captures report contents required to validate, interpret, and reproduce a latency benchmark result.
public struct LatencyBenchmarkReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public struct Identity: Sendable {
        public let id: String
        public let title: String
        public let capturedAt: String
        public let category: LatencyBenchmarkCategory
        public let runMode: LatencyBenchmarkRunMode
        public let evidenceKind: LatencyBenchmarkEvidenceKind

        public init(
            id: String,
            title: String,
            capturedAt: String,
            category: LatencyBenchmarkCategory,
            runMode: LatencyBenchmarkRunMode,
            evidenceKind: LatencyBenchmarkEvidenceKind
        ) {
            self.id = id
            self.title = title
            self.capturedAt = capturedAt
            self.category = category
            self.runMode = runMode
            self.evidenceKind = evidenceKind
        }
    }

    public struct Context: Sendable {
        public let hardware: HardwareIdentity
        public let route: RouteIdentity
        public let mediaMode: LatencyBenchmarkMediaMode

        public init(
            hardware: HardwareIdentity,
            route: RouteIdentity,
            mediaMode: LatencyBenchmarkMediaMode
        ) {
            self.hardware = hardware
            self.route = route
            self.mediaMode = mediaMode
        }
    }

    public struct Measurements: Sendable {
        public let timing: LatencyBenchmarkTimingMetrics
        public let loss: LatencyBenchmarkLossMetrics
        public let faults: LatencyBenchmarkFaultMetrics
        public let resources: LatencyBenchmarkResourceMetrics
        public let components: [LatencyBudgetComponentMeasurement]

        public init(
            timing: LatencyBenchmarkTimingMetrics,
            loss: LatencyBenchmarkLossMetrics,
            faults: LatencyBenchmarkFaultMetrics,
            resources: LatencyBenchmarkResourceMetrics,
            components: [LatencyBudgetComponentMeasurement]
        ) {
            self.timing = timing
            self.loss = loss
            self.faults = faults
            self.resources = resources
            self.components = components
        }
    }

    public struct Evidence: Sendable {
        public let rxBufferImpact: RxBufferBenchmarkImpact?
        public let latencyProfile: LatencyProfileEvidence?
        public let sessionProfileMetrics: SessionLatencyProfileBenchmarkMetrics?

        public init(
            rxBufferImpact: RxBufferBenchmarkImpact? = nil,
            latencyProfile: LatencyProfileEvidence? = nil,
            sessionProfileMetrics: SessionLatencyProfileBenchmarkMetrics? = nil
        ) {
            self.rxBufferImpact = rxBufferImpact
            self.latencyProfile = latencyProfile
            self.sessionProfileMetrics = sessionProfileMetrics
        }
    }

    public struct Outcome: Sendable {
        public let thresholds: LatencyBenchmarkThresholds
        public let verdict: MeasurementVerdict
        public let notes: String

        public init(
            thresholds: LatencyBenchmarkThresholds,
            verdict: MeasurementVerdict,
            notes: String
        ) {
            self.thresholds = thresholds
            self.verdict = verdict
            self.notes = notes
        }
    }

    public var id: String
    public var title: String
    public var capturedAt: String
    public var category: LatencyBenchmarkCategory
    public var runMode: LatencyBenchmarkRunMode
    public var evidenceKind: LatencyBenchmarkEvidenceKind
    public var hardware: HardwareIdentity
    public var route: RouteIdentity
    public var mediaMode: LatencyBenchmarkMediaMode
    public var timing: LatencyBenchmarkTimingMetrics
    public var loss: LatencyBenchmarkLossMetrics
    public var faults: LatencyBenchmarkFaultMetrics
    public var resources: LatencyBenchmarkResourceMetrics
    public var thresholds: LatencyBenchmarkThresholds
    public var components: [LatencyBudgetComponentMeasurement]
    public var rxBufferImpact: RxBufferBenchmarkImpact?
    public var latencyProfileEvidence: LatencyProfileEvidence?
    public var sessionProfileMetrics: SessionLatencyProfileBenchmarkMetrics?
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        identity: Identity,
        context: Context,
        measurements: Measurements,
        evidence: Evidence = Evidence(),
        outcome: Outcome
    ) {
        self.id = identity.id
        self.title = identity.title
        self.capturedAt = identity.capturedAt
        self.category = identity.category
        self.runMode = identity.runMode
        self.evidenceKind = identity.evidenceKind
        self.hardware = context.hardware
        self.route = context.route
        self.mediaMode = context.mediaMode
        self.timing = measurements.timing
        self.loss = measurements.loss
        self.faults = measurements.faults
        self.resources = measurements.resources
        self.thresholds = outcome.thresholds
        self.components = measurements.components
        self.rxBufferImpact = evidence.rxBufferImpact
        self.latencyProfileEvidence = evidence.latencyProfile
        self.sessionProfileMetrics = evidence.sessionProfileMetrics
        self.verdict = outcome.verdict
        self.notes = outcome.notes
    }

    public func validate() throws {
        // Keep report validation fail-fast so the first structural error is the reported context.
        // Cross-field pass-verdict checks only run after the base report shape is valid.
        try validateIdentity()
        try validateMediaMode()
        try validateTiming()
        try validateLoss()
        try validateFaults()
        try validateResources()
        try validateThresholds()
        try validateComponents()
        try validateRxBufferImpact()
        try validateLatencyProfileEvidence()
        try validateSessionProfileMetrics()
        try validatePassVerdict()
    }

}
