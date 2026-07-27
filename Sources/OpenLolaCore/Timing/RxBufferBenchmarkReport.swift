// Validates per-profile RX buffer timing, jitter, loss, and fault rows before a candidate can contribute to benchmark conclusions.
import Foundation

/// Labels whether a receive-buffer benchmark row came from synthetic, modeled, or measured evidence.
public enum RxBufferBenchmarkEvidenceKind: String, Codable, Equatable, Sendable {
    case localRuntime
    case physicalReferenceRig
}

/// Reports `emptyField`, `emptyList`, `missingProfile`, and `duplicateProfile` failures that stop invalid timing and drift control work before it reaches a live path.
public enum RxBufferBenchmarkValidationError: Error, Equatable, Sendable,
    ValidationEmptyFieldError,
    ValidationNonPositiveFieldError,
    ValidationNegativeFieldError,
    ValidationNonFiniteFieldError,
    ValidationPercentOutOfRangeFieldError {
    case emptyField(String)
    case emptyList(String)
    case missingProfile(RxBufferProfile)
    case duplicateProfile(RxBufferProfile)
    case rowProfileMismatch(row: RxBufferProfile, policy: RxBufferProfile)
    case nonPositiveField(String)
    case negativeField(String)
    case nonFiniteField(String)
    case percentOutOfRange(field: String, value: Double)
    case unorderedJitter(String)
    case oneWayExceedsRoundTrip(row: RxBufferProfile)
    case passWithoutPhysicalReferenceRig
    case passWithNonPhysicalRow(RxBufferProfile)
// swiftlint:disable:next identifier_name
case passWithAdaptiveTargetChangeInsideCallback(RxBufferProfile)
}

/// Records the policy, benchmark, timing, and loss observations for one receive-buffer trial.
public struct RxBufferBenchmarkRow: Codable, Equatable, Sendable {
    public var profile: RxBufferProfile
    public var benchmark: RxBufferBenchmarkImpact
    public var timing: LatencyBenchmarkTimingMetrics
    public var loss: LatencyBenchmarkLossMetrics
    public var faults: LatencyBenchmarkFaultMetrics
    public var addedLatencyFrames: Int
    public var addedLatencyPackets: Int
    public var addedLatencyMicroseconds: Double
    public var physicalEvidence: Bool
    public var fastestPassEligible: Bool
    public var notes: String

    public struct Measurements: Equatable, Sendable {
        public var benchmark: RxBufferBenchmarkImpact
        public var timing: LatencyBenchmarkTimingMetrics
        public var loss: LatencyBenchmarkLossMetrics
        public var faults: LatencyBenchmarkFaultMetrics

        public init(
            benchmark: RxBufferBenchmarkImpact,
            timing: LatencyBenchmarkTimingMetrics,
            loss: LatencyBenchmarkLossMetrics,
            faults: LatencyBenchmarkFaultMetrics
        ) {
            self.benchmark = benchmark
            self.timing = timing
            self.loss = loss
            self.faults = faults
        }
    }

    public struct Evidence: Equatable, Sendable {
        public var physicalEvidence: Bool
        public var fastestPassEligible: Bool
        public var notes: String

        public init(physicalEvidence: Bool, fastestPassEligible: Bool, notes: String) {
            self.physicalEvidence = physicalEvidence
            self.fastestPassEligible = fastestPassEligible
            self.notes = notes
        }
    }

    public init(
        profile: RxBufferProfile,
        measurements: Measurements,
        evidence: Evidence
    ) {
        self.profile = profile
        self.benchmark = measurements.benchmark
        self.timing = measurements.timing
        self.loss = measurements.loss
        self.faults = measurements.faults
        self.addedLatencyFrames = measurements.benchmark.addedLatencyFrames
        self.addedLatencyPackets = measurements.benchmark.profile.latencyCostPackets
        self.addedLatencyMicroseconds = measurements.benchmark.addedLatencyMicroseconds
        self.physicalEvidence = evidence.physicalEvidence
        self.fastestPassEligible = evidence.fastestPassEligible
        self.notes = evidence.notes
    }

    public func validate() throws {
        try RxBufferBenchmarkValidator.requireNonEmpty(notes, "rows.notes")
        try benchmark.validate()
        guard profile == benchmark.profile.profile else {
            throw RxBufferBenchmarkValidationError.rowProfileMismatch(
                row: profile,
                policy: benchmark.profile.profile
            )
        }
        try validateRxBenchmarkTiming(timing, "rows.timing", profile)
        try validateRxBenchmarkLoss(loss, "rows.loss")
        try validateRxBenchmarkFaults(faults, "rows.faults")
        try RxBufferBenchmarkValidator.requireNonNegative(addedLatencyFrames, "rows.addedLatencyFrames")
        try RxBufferBenchmarkValidator.requireNonNegative(addedLatencyPackets, "rows.addedLatencyPackets")
        try RxBufferBenchmarkValidator.requireNonNegative(
            addedLatencyMicroseconds,
            "rows.addedLatencyMicroseconds"
        )
    }
}

/// Records `id`, `title`, `capturedAt`, and `evidenceKind` so timing and drift control measurements and verdicts can be checked after a run.
public struct RxBufferBenchmarkReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public struct Identity: Equatable, Sendable {
        public var id: String
        public var title: String
        public var capturedAt: String
        public var evidenceKind: RxBufferBenchmarkEvidenceKind

        public init(
            id: String,
            title: String,
            capturedAt: String,
            evidenceKind: RxBufferBenchmarkEvidenceKind
        ) {
            self.id = id
            self.title = title
            self.capturedAt = capturedAt
            self.evidenceKind = evidenceKind
        }
    }

    public struct Environment: Equatable, Sendable {
        public var hardware: HardwareIdentity
        public var route: RouteIdentity
        public var audioMode: AudioMode

        public init(hardware: HardwareIdentity, route: RouteIdentity, audioMode: AudioMode) {
            self.hardware = hardware
            self.route = route
            self.audioMode = audioMode
        }
    }

    public struct Outcome: Equatable, Sendable {
        public var rows: [RxBufferBenchmarkRow]
        public var verdict: MeasurementVerdict
        public var notes: String

        public init(rows: [RxBufferBenchmarkRow], verdict: MeasurementVerdict, notes: String) {
            self.rows = rows
            self.verdict = verdict
            self.notes = notes
        }
    }

    public var id: String
    public var title: String
    public var capturedAt: String
    public var evidenceKind: RxBufferBenchmarkEvidenceKind
    public var hardware: HardwareIdentity
    public var route: RouteIdentity
    public var audioMode: AudioMode
    public var rows: [RxBufferBenchmarkRow]
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(identity: Identity, environment: Environment, outcome: Outcome) {
        self.id = identity.id
        self.title = identity.title
        self.capturedAt = identity.capturedAt
        self.evidenceKind = identity.evidenceKind
        self.hardware = environment.hardware
        self.route = environment.route
        self.audioMode = environment.audioMode
        self.rows = outcome.rows
        self.verdict = outcome.verdict
        self.notes = outcome.notes
    }

    public func validate() throws {
        try RxBufferBenchmarkValidator.requireNonEmpty(id, "id")
        try RxBufferBenchmarkValidator.requireNonEmpty(title, "title")
        try RxBufferBenchmarkValidator.requireNonEmpty(capturedAt, "capturedAt")
        try RxBufferBenchmarkValidator.requireNonEmpty(hardware.referenceMac, "hardware.referenceMac")
        try RxBufferBenchmarkValidator.requireNonEmpty(hardware.audioInterface, "hardware.audioInterface")
        try RxBufferBenchmarkValidator.requireNonEmpty(hardware.osVersion, "hardware.osVersion")
        try RxBufferBenchmarkValidator.requireNonEmpty(hardware.driverVersion, "hardware.driverVersion")
        try RxBufferBenchmarkValidator.requireNonEmpty(route.label, "route.label")
        try RxBufferBenchmarkValidator.requireNonEmpty(route.topology, "route.topology")
        try RxBufferBenchmarkValidator.requirePositive(audioMode.sampleRateHertz, "audioMode.sampleRateHertz")
        try RxBufferBenchmarkValidator.requirePositive(audioMode.framesPerBuffer, "audioMode.framesPerBuffer")
        try RxBufferBenchmarkValidator.requirePositive(audioMode.channelCount, "audioMode.channelCount")
        try RxBufferBenchmarkValidator.requireNonEmpty(audioMode.sampleFormat, "audioMode.sampleFormat")
        try RxBufferBenchmarkValidator.requireNonEmpty(notes, "notes")
        try validateRows()
        try validatePass()
    }

    private func validateRows() throws {
        guard !rows.isEmpty else {
            throw RxBufferBenchmarkValidationError.emptyList("rows")
        }
        var seen = Set<RxBufferProfile>()
        for row in rows {
            guard seen.insert(row.profile).inserted else {
                throw RxBufferBenchmarkValidationError.duplicateProfile(row.profile)
            }
            try row.validate()
        }
        for profile in RxBufferProfile.allCases where !seen.contains(profile) {
            throw RxBufferBenchmarkValidationError.missingProfile(profile)
        }
    }

    private func validatePass() throws {
        guard verdict == .pass else {
            return
        }
        guard evidenceKind == .physicalReferenceRig else {
            throw RxBufferBenchmarkValidationError.passWithoutPhysicalReferenceRig
        }
        for row in rows {
            guard row.physicalEvidence else {
                throw RxBufferBenchmarkValidationError.passWithNonPhysicalRow(row.profile)
            }
            if row.benchmark.targetChangeEvents.contains(where: \.changedInsideAudioCallback) {
                throw RxBufferBenchmarkValidationError.passWithAdaptiveTargetChangeInsideCallback(
                    row.profile
                )
            }
        }
    }
}

private func validateRxBenchmarkTiming(
    _ timing: LatencyBenchmarkTimingMetrics,
    _ field: String,
    _ profile: RxBufferProfile
) throws {
    try RxBufferBenchmarkValidator.requireNonNegative(
        timing.oneWayEstimateMicroseconds,
        "\(field).oneWayEstimateMicroseconds"
    )
    try RxBufferBenchmarkValidator.requireNonNegative(
        timing.roundTripMicroseconds,
        "\(field).roundTripMicroseconds"
    )
    guard timing.oneWayEstimateMicroseconds <= timing.roundTripMicroseconds else {
        throw RxBufferBenchmarkValidationError.oneWayExceedsRoundTrip(row: profile)
    }
    try validateRxBenchmarkJitter(timing.jitter, "\(field).jitter")
}

private func validateRxBenchmarkJitter(_ jitter: LatencyJitterMetrics, _ field: String) throws {
    try RxBufferBenchmarkValidator.requireNonNegative(jitter.p50Microseconds, "\(field).p50Microseconds")
    try RxBufferBenchmarkValidator.requireNonNegative(jitter.p95Microseconds, "\(field).p95Microseconds")
    try RxBufferBenchmarkValidator.requireNonNegative(jitter.p99Microseconds, "\(field).p99Microseconds")
    try RxBufferBenchmarkValidator.requireNonNegative(jitter.maxMicroseconds, "\(field).maxMicroseconds")
    guard timingPercentilesAreOrdered(
        p50: jitter.p50Microseconds,
        p95: jitter.p95Microseconds,
        p99: jitter.p99Microseconds,
        max: jitter.maxMicroseconds
    ) else {
        throw RxBufferBenchmarkValidationError.unorderedJitter(field)
    }
}

private func validateRxBenchmarkLoss(_ loss: LatencyBenchmarkLossMetrics, _ field: String) throws {
    try RxBufferBenchmarkValidator.requireNonNegative(loss.lostPackets, "\(field).lostPackets")
    try RxBufferBenchmarkValidator.requireNonNegative(loss.latePackets, "\(field).latePackets")
    try RxBufferBenchmarkValidator.requirePercent(loss.lossPercent, "\(field).lossPercent")
}

private func validateRxBenchmarkFaults(_ faults: LatencyBenchmarkFaultMetrics, _ field: String)
    throws {
    try RxBufferBenchmarkValidator.requireNonNegative(faults.underruns, "\(field).underruns")
    try RxBufferBenchmarkValidator.requireNonNegative(faults.overruns, "\(field).overruns")
    try RxBufferBenchmarkValidator.requireNonNegative(faults.missedDeadlines, "\(field).missedDeadlines")
    try RxBufferBenchmarkValidator.requireNonNegative(faults.droppedFrames, "\(field).droppedFrames")
}
