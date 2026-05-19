import Foundation

public struct SessionLatencyProfileBenchmarkMetrics: Codable, Equatable, Sendable {
    public var sessionProfile: SessionLatencyProfile
    public var rxBufferProfile: RxBufferProfile
    public var callbackDurationP99Microseconds: Double
    public var routeAge: UdpPcmPacketAgeMetrics
    public var packetAge: UdpPcmPacketAgeMetrics
    public var jitter: LatencyJitterMetrics
    public var underruns: Int
    public var overruns: Int
    public var addedBufferCostFrames: Int
    public var addedBufferCostPackets: Int
    public var addedBufferCostMicroseconds: Double
    public var fastestPassClaimed: Bool

    public init(
        sessionProfile: SessionLatencyProfile,
        rxBufferProfile: RxBufferProfile,
        callbackDurationP99Microseconds: Double,
        routeAge: UdpPcmPacketAgeMetrics,
        packetAge: UdpPcmPacketAgeMetrics,
        jitter: LatencyJitterMetrics,
        underruns: Int,
        overruns: Int,
        addedBufferCostFrames: Int,
        addedBufferCostPackets: Int,
        addedBufferCostMicroseconds: Double,
        fastestPassClaimed: Bool
    ) {
        self.sessionProfile = sessionProfile
        self.rxBufferProfile = rxBufferProfile
        self.callbackDurationP99Microseconds = callbackDurationP99Microseconds
        self.routeAge = routeAge
        self.packetAge = packetAge
        self.jitter = jitter
        self.underruns = underruns
        self.overruns = overruns
        self.addedBufferCostFrames = addedBufferCostFrames
        self.addedBufferCostPackets = addedBufferCostPackets
        self.addedBufferCostMicroseconds = addedBufferCostMicroseconds
        self.fastestPassClaimed = fastestPassClaimed
    }

    public func validate() throws {
        let policy = SessionLatencyProfilePolicy.policy(for: sessionProfile)
        guard policy.allowedRxBufferProfiles.contains(rxBufferProfile) else {
            throw SessionValidationError.unsupportedRxBufferProfile(rxBufferProfile)
        }
        try SessionProfileBenchmarkValidator.requireNonNegative(
            callbackDurationP99Microseconds,
            "sessionProfileMetrics.callbackDurationP99Microseconds"
        )
        try validateProfilePacketAge(routeAge, "sessionProfileMetrics.routeAge")
        try validateProfilePacketAge(packetAge, "sessionProfileMetrics.packetAge")
        try validateProfileJitter(jitter)
        try SessionProfileBenchmarkValidator.requireNonNegative(underruns, "sessionProfileMetrics.underruns")
        try SessionProfileBenchmarkValidator.requireNonNegative(overruns, "sessionProfileMetrics.overruns")
        try SessionProfileBenchmarkValidator.requireNonNegative(
            addedBufferCostFrames,
            "sessionProfileMetrics.addedBufferCostFrames"
        )
        try SessionProfileBenchmarkValidator.requireNonNegative(
            addedBufferCostPackets,
            "sessionProfileMetrics.addedBufferCostPackets"
        )
        try SessionProfileBenchmarkValidator.requireNonNegative(
            addedBufferCostMicroseconds,
            "sessionProfileMetrics.addedBufferCostMicroseconds"
        )
    }
}

public enum LatencyProfileBenchmarkSyntheticSmoke {
    public static func run() throws -> LatencyBenchmarkReport {
        var report = try LatencyBenchmarkSyntheticSmoke.run()
        let rxPolicy = try RxBufferPolicy.direct(
            framesPerPacket: 32,
            sampleRateHertz: 48_000,
            targetPackets: 1
        )
        report.id = "m07-latency-profile-synthetic-smoke"
        report.title = "M07 latency profile source-validation smoke"
        report.rxBufferImpact = RxBufferBenchmarkImpact(
            profile: rxPolicy,
            targetFramesOverTime: [rxPolicy.targetFrames],
            targetChangeEvents: [],
            impairmentSummary: report.rxBufferImpact?.impairmentSummary
        )
        report.sessionProfileMetrics = SessionLatencyProfileBenchmarkMetrics(
            sessionProfile: .directAudioFirst,
            rxBufferProfile: .direct,
            callbackDurationP99Microseconds: 180,
            routeAge: UdpPcmPacketAgeMetrics(
                p50Microseconds: 120,
                p95Microseconds: 260,
                p99Microseconds: 310,
                maxMicroseconds: 360
            ),
            packetAge: UdpPcmPacketAgeMetrics(
                p50Microseconds: 80,
                p95Microseconds: 160,
                p99Microseconds: 240,
                maxMicroseconds: 320
            ),
            jitter: report.timing.jitter,
            underruns: report.faults.underruns,
            overruns: report.faults.overruns,
            addedBufferCostFrames: rxPolicy.latencyCostFrames,
            addedBufferCostPackets: rxPolicy.latencyCostPackets,
            addedBufferCostMicroseconds: rxPolicy.latencyCostMicroseconds,
            fastestPassClaimed: false
        )
        report.notes = "M07 source-validation smoke; physical profile matrix evidence is still required."
        return report
    }
}

private func validateProfilePacketAge(
    _ metrics: UdpPcmPacketAgeMetrics,
    _ field: String
) throws {
    try SessionProfileBenchmarkValidator.requireNonNegative(metrics.p50Microseconds, "\(field).p50Microseconds")
    try SessionProfileBenchmarkValidator.requireNonNegative(metrics.p95Microseconds, "\(field).p95Microseconds")
    try SessionProfileBenchmarkValidator.requireNonNegative(metrics.p99Microseconds, "\(field).p99Microseconds")
    try SessionProfileBenchmarkValidator.requireNonNegative(metrics.maxMicroseconds, "\(field).maxMicroseconds")
    guard timingPercentilesAreOrdered(
        p50: metrics.p50Microseconds,
        p95: metrics.p95Microseconds,
        p99: metrics.p99Microseconds,
        max: metrics.maxMicroseconds
    ) else {
        throw LatencyBenchmarkValidationError.unorderedJitter
    }
}

private func validateProfileJitter(_ metrics: LatencyJitterMetrics) throws {
    try SessionProfileBenchmarkValidator.requireNonNegative(
        metrics.p50Microseconds,
        "sessionProfileMetrics.jitter.p50Microseconds"
    )
    try SessionProfileBenchmarkValidator.requireNonNegative(
        metrics.p95Microseconds,
        "sessionProfileMetrics.jitter.p95Microseconds"
    )
    try SessionProfileBenchmarkValidator.requireNonNegative(
        metrics.p99Microseconds,
        "sessionProfileMetrics.jitter.p99Microseconds"
    )
    try SessionProfileBenchmarkValidator.requireNonNegative(
        metrics.maxMicroseconds,
        "sessionProfileMetrics.jitter.maxMicroseconds"
    )
    guard timingPercentilesAreOrdered(
        p50: metrics.p50Microseconds,
        p95: metrics.p95Microseconds,
        p99: metrics.p99Microseconds,
        max: metrics.maxMicroseconds
    ) else {
        throw LatencyBenchmarkValidationError.unorderedJitter
    }
}

private enum SessionProfileBenchmarkValidator: ReportValidationProtocol {
    typealias ValidationError = LatencyBenchmarkValidationError
}
