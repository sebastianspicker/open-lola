// Validates packet-age, jitter, and fault metrics attached to a session latency profile so profile evidence uses benchmark-grade checks.
import Foundation

/// Tracks `sessionProfile`, `rxBufferProfile`, `callbackDurationP99Microseconds`, and `routeAge` to expose latency, pressure, and delivery outcomes in timing and drift control.
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

    public struct Profiles: Equatable, Sendable {
        public var sessionProfile: SessionLatencyProfile
        public var rxBufferProfile: RxBufferProfile

        public init(sessionProfile: SessionLatencyProfile, rxBufferProfile: RxBufferProfile) {
            self.sessionProfile = sessionProfile
            self.rxBufferProfile = rxBufferProfile
        }
    }

    public struct Timing: Equatable, Sendable {
        public var callbackDurationP99Microseconds: Double
        public var routeAge: UdpPcmPacketAgeMetrics
        public var packetAge: UdpPcmPacketAgeMetrics
        public var jitter: LatencyJitterMetrics

        public init(
            callbackDurationP99Microseconds: Double,
            routeAge: UdpPcmPacketAgeMetrics,
            packetAge: UdpPcmPacketAgeMetrics,
            jitter: LatencyJitterMetrics
        ) {
            self.callbackDurationP99Microseconds = callbackDurationP99Microseconds
            self.routeAge = routeAge
            self.packetAge = packetAge
            self.jitter = jitter
        }
    }

    public struct Runtime: Equatable, Sendable {
        public var underruns: Int
        public var overruns: Int
        public var fastestPassClaimed: Bool

        public init(underruns: Int, overruns: Int, fastestPassClaimed: Bool) {
            self.underruns = underruns
            self.overruns = overruns
            self.fastestPassClaimed = fastestPassClaimed
        }
    }

    public enum BufferCostDomain {}
    public typealias BufferCost = PacketBufferLatency<BufferCostDomain>

    public init(
        profiles: Profiles,
        timing: Timing,
        runtime: Runtime,
        bufferCost: BufferCost
    ) {
        self.sessionProfile = profiles.sessionProfile
        self.rxBufferProfile = profiles.rxBufferProfile
        self.callbackDurationP99Microseconds = timing.callbackDurationP99Microseconds
        self.routeAge = timing.routeAge
        self.packetAge = timing.packetAge
        self.jitter = timing.jitter
        self.underruns = runtime.underruns
        self.overruns = runtime.overruns
        self.addedBufferCostFrames = bufferCost.frames
        self.addedBufferCostPackets = bufferCost.packets
        self.addedBufferCostMicroseconds = bufferCost.microseconds
        self.fastestPassClaimed = runtime.fastestPassClaimed
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

/// Exercises a deterministic timing and drift control path so regressions remain reproducible without hardware.
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
            profiles: .init(sessionProfile: .directAudioFirst, rxBufferProfile: .direct),
            timing: .init(
                callbackDurationP99Microseconds: SourceValidationMetrics.callback.p99Microseconds,
                routeAge: SourceValidationMetrics.localPacketAge,
                packetAge: SourceValidationMetrics.audioPacketAge,
                jitter: report.timing.jitter
            ),
            runtime: .init(
                underruns: report.faults.underruns,
                overruns: report.faults.overruns,
                fastestPassClaimed: false
            ),
            bufferCost: .init(
                frames: rxPolicy.latencyCostFrames,
                packets: rxPolicy.latencyCostPackets,
                microseconds: rxPolicy.latencyCostMicroseconds
            )
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
