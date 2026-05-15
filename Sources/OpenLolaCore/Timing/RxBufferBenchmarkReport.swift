import Foundation

public enum RxBufferBenchmarkEvidenceKind: String, Codable, Equatable, Sendable {
    case localRuntime
    case physicalReferenceRig
}

public enum RxBufferBenchmarkValidationError: Error, Equatable, Sendable,
    ValidationEmptyFieldError,
    ValidationNonPositiveFieldError,
    ValidationNegativeFieldError,
    ValidationNonFiniteFieldError {
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
    case passWithAdaptiveTargetChangeInsideCallback(RxBufferProfile)
}

enum RxBufferBenchmarkValidator: ReportPrimitiveValidating {
    typealias ValidationError = RxBufferBenchmarkValidationError
}

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

    public init(
        profile: RxBufferProfile,
        benchmark: RxBufferBenchmarkImpact,
        timing: LatencyBenchmarkTimingMetrics,
        loss: LatencyBenchmarkLossMetrics,
        faults: LatencyBenchmarkFaultMetrics,
        physicalEvidence: Bool,
        fastestPassEligible: Bool,
        notes: String
    ) {
        self.profile = profile
        self.benchmark = benchmark
        self.timing = timing
        self.loss = loss
        self.faults = faults
        self.addedLatencyFrames = benchmark.addedLatencyFrames
        self.addedLatencyPackets = benchmark.profile.latencyCostPackets
        self.addedLatencyMicroseconds = benchmark.addedLatencyMicroseconds
        self.physicalEvidence = physicalEvidence
        self.fastestPassEligible = fastestPassEligible
        self.notes = notes
    }

    public func validate() throws {
        try requireRxBenchmarkNonEmpty(notes, "rows.notes")
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
        try requireRxBenchmarkNonNegative(addedLatencyFrames, "rows.addedLatencyFrames")
        try requireRxBenchmarkNonNegative(addedLatencyPackets, "rows.addedLatencyPackets")
        try requireRxBenchmarkNonNegative(
            addedLatencyMicroseconds,
            "rows.addedLatencyMicroseconds"
        )
    }
}

public struct RxBufferBenchmarkReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
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

    public init(
        id: String,
        title: String,
        capturedAt: String,
        evidenceKind: RxBufferBenchmarkEvidenceKind,
        hardware: HardwareIdentity,
        route: RouteIdentity,
        audioMode: AudioMode,
        rows: [RxBufferBenchmarkRow],
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
        self.evidenceKind = evidenceKind
        self.hardware = hardware
        self.route = route
        self.audioMode = audioMode
        self.rows = rows
        self.verdict = verdict
        self.notes = notes
    }

    public func validate() throws {
        try requireRxBenchmarkNonEmpty(id, "id")
        try requireRxBenchmarkNonEmpty(title, "title")
        try requireRxBenchmarkNonEmpty(capturedAt, "capturedAt")
        try requireRxBenchmarkNonEmpty(hardware.referenceMac, "hardware.referenceMac")
        try requireRxBenchmarkNonEmpty(hardware.audioInterface, "hardware.audioInterface")
        try requireRxBenchmarkNonEmpty(hardware.osVersion, "hardware.osVersion")
        try requireRxBenchmarkNonEmpty(hardware.driverVersion, "hardware.driverVersion")
        try requireRxBenchmarkNonEmpty(route.label, "route.label")
        try requireRxBenchmarkNonEmpty(route.topology, "route.topology")
        try requireRxBenchmarkPositive(audioMode.sampleRateHertz, "audioMode.sampleRateHertz")
        try requireRxBenchmarkPositive(audioMode.framesPerBuffer, "audioMode.framesPerBuffer")
        try requireRxBenchmarkPositive(audioMode.channelCount, "audioMode.channelCount")
        try requireRxBenchmarkNonEmpty(audioMode.sampleFormat, "audioMode.sampleFormat")
        try requireRxBenchmarkNonEmpty(notes, "notes")
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
    try requireRxBenchmarkNonNegative(
        timing.oneWayEstimateMicroseconds,
        "\(field).oneWayEstimateMicroseconds"
    )
    try requireRxBenchmarkNonNegative(
        timing.roundTripMicroseconds,
        "\(field).roundTripMicroseconds"
    )
    guard timing.oneWayEstimateMicroseconds <= timing.roundTripMicroseconds else {
        throw RxBufferBenchmarkValidationError.oneWayExceedsRoundTrip(row: profile)
    }
    try validateRxBenchmarkJitter(timing.jitter, "\(field).jitter")
}

private func validateRxBenchmarkJitter(_ jitter: LatencyJitterMetrics, _ field: String) throws {
    try requireRxBenchmarkNonNegative(jitter.p50Microseconds, "\(field).p50Microseconds")
    try requireRxBenchmarkNonNegative(jitter.p95Microseconds, "\(field).p95Microseconds")
    try requireRxBenchmarkNonNegative(jitter.p99Microseconds, "\(field).p99Microseconds")
    try requireRxBenchmarkNonNegative(jitter.maxMicroseconds, "\(field).maxMicroseconds")
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
    try requireRxBenchmarkNonNegative(loss.lostPackets, "\(field).lostPackets")
    try requireRxBenchmarkNonNegative(loss.latePackets, "\(field).latePackets")
    try requireRxBenchmarkPercent(loss.lossPercent, "\(field).lossPercent")
}

private func validateRxBenchmarkFaults(_ faults: LatencyBenchmarkFaultMetrics, _ field: String)
    throws {
    try requireRxBenchmarkNonNegative(faults.underruns, "\(field).underruns")
    try requireRxBenchmarkNonNegative(faults.overruns, "\(field).overruns")
    try requireRxBenchmarkNonNegative(faults.missedDeadlines, "\(field).missedDeadlines")
    try requireRxBenchmarkNonNegative(faults.droppedFrames, "\(field).droppedFrames")
}

private func requireRxBenchmarkNonEmpty(_ value: String, _ field: String) throws {
    try RxBufferBenchmarkValidator.requireNonEmpty(value, field)
}

private func requireRxBenchmarkPositive(_ value: Int, _ field: String) throws {
    try RxBufferBenchmarkValidator.requirePositive(value, field)
}

private func requireRxBenchmarkNonNegative(_ value: Int, _ field: String) throws {
    try RxBufferBenchmarkValidator.requireNonNegative(value, field)
}

private func requireRxBenchmarkNonNegative(_ value: Double, _ field: String) throws {
    try RxBufferBenchmarkValidator.requireNonNegative(value, field)
}

private func requireRxBenchmarkPercent(_ value: Double, _ field: String) throws {
    guard value.isFinite else {
        throw RxBufferBenchmarkValidationError.nonFiniteField(field)
    }
    guard value >= 0, value <= 100 else {
        throw RxBufferBenchmarkValidationError.percentOutOfRange(field: field, value: value)
    }
}
