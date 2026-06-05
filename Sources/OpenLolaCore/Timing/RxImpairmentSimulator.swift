import Foundation

public struct RxImpairmentProfile: Codable, Equatable, Sendable {
    public var seed: UInt64
    public var packetCount: Int
    public var framesPerPacket: Int
    public var sampleRateHertz: Int
    public var baseTransitMicroseconds: Double
    public var jitterAmplitudeMicroseconds: Double
    public var lossEveryNthPacket: Int?
    public var duplicateEveryNthPacket: Int?
    public var reorderEveryNthPacket: Int?
    public var lateEveryNthPacket: Int?
    public var fragmentCount: Int
    public var fragmentLossEveryNthPacket: Int?

    public init(
        seed: UInt64,
        packetCount: Int,
        framesPerPacket: Int,
        sampleRateHertz: Int,
        baseTransitMicroseconds: Double,
        jitterAmplitudeMicroseconds: Double,
        lossEveryNthPacket: Int?,
        duplicateEveryNthPacket: Int?,
        reorderEveryNthPacket: Int?,
        lateEveryNthPacket: Int?,
        fragmentCount: Int,
        fragmentLossEveryNthPacket: Int?
    ) {
        self.seed = seed
        self.packetCount = packetCount
        self.framesPerPacket = framesPerPacket
        self.sampleRateHertz = sampleRateHertz
        self.baseTransitMicroseconds = baseTransitMicroseconds
        self.jitterAmplitudeMicroseconds = jitterAmplitudeMicroseconds
        self.lossEveryNthPacket = lossEveryNthPacket
        self.duplicateEveryNthPacket = duplicateEveryNthPacket
        self.reorderEveryNthPacket = reorderEveryNthPacket
        self.lateEveryNthPacket = lateEveryNthPacket
        self.fragmentCount = fragmentCount
        self.fragmentLossEveryNthPacket = fragmentLossEveryNthPacket
    }
}

public struct RxImpairedPacketEvent: Codable, Equatable, Sendable {
    public var sequenceNumber: UInt64
    public var senderFrameIndex: Int
    public var arrivalMicroseconds: Double
    public var packetAgeMicroseconds: Double
    public var duplicate: Bool
    public var reordered: Bool
    public var deadlineLate: Bool
    public var fragmentLoss: Bool
    public var complete: Bool
}

public struct RxImpairmentSimulationSummary: Codable, Equatable, Sendable {
    public var sentPackets: Int
    public var deliveredPackets: Int
    public var wholePacketLosses: Int
    public var fragmentLosses: Int
    public var deadlineLatePackets: Int
    public var duplicatePackets: Int
    public var reorderedPackets: Int
    public var packetAge: UdpPcmPacketAgeMetrics
    public var jitter: LatencyJitterMetrics
}

public struct RxImpairmentSimulationResult: Codable, Equatable, Sendable {
    public var profile: RxImpairmentProfile
    public var events: [RxImpairedPacketEvent]
    public var summary: RxImpairmentSimulationSummary
}

public enum RxImpairmentSimulationError: Error, Equatable, Sendable {
    case packetCountAboveMaximum(packetCount: Int, maximum: Int)
    case duplicateArrivedBeforeOriginal(sequenceNumber: UInt64)
}

private struct RxPercentileMetrics {
    var p50: Double
    var p95: Double
    var p99: Double
    var max: Double
}

private struct RxImpairedEventGenerationResult {
    var events: [RxImpairedPacketEvent]
    var wholeLosses: Int
    var fragmentLosses: Int
}

private struct RxImpairedEventContext {
    var profile: RxImpairmentProfile
    var packetPeriodMicroseconds: Double
}

private struct RxImpairedArrival {
    var microseconds: Double
    var reordered: Bool
}

public enum RxImpairmentSimulator {
    public static let maximumPacketCount = 1_000_000

    public static func run(profile: RxImpairmentProfile) throws -> RxImpairmentSimulationResult {
        try validate(profile)

        var generation = impairedEvents(profile: profile)
        sortEventsByArrival(&generation.events)
        try validateDuplicateOrdering(generation.events)

        return RxImpairmentSimulationResult(
            profile: profile,
            events: generation.events,
            summary: simulationSummary(
                profile: profile,
                events: generation.events,
                wholeLosses: generation.wholeLosses,
                fragmentLosses: generation.fragmentLosses
            )
        )
    }

    private static func impairedEvents(
        profile: RxImpairmentProfile
    ) -> RxImpairedEventGenerationResult {
        var generator = RxDeterministicGenerator(seed: profile.seed)
        let context = RxImpairedEventContext(
            profile: profile,
            packetPeriodMicroseconds: RxBufferPolicy.microseconds(
                frames: profile.framesPerPacket,
                sampleRateHertz: profile.sampleRateHertz
            )
        )
        var events: [RxImpairedPacketEvent] = []
        var wholeLosses = 0
        var fragmentLosses = 0

        for sequence in 0..<profile.packetCount {
            if matchesEveryNth(sequence, profile.lossEveryNthPacket) {
                wholeLosses += 1
                continue
            }

            let event = impairedPacketEvent(
                sequence: sequence,
                context: context,
                generator: &generator
            )
            if event.fragmentLoss {
                fragmentLosses += 1
            }
            events.append(event)
            appendDuplicateIfNeeded(for: event, sequence: sequence, profile: profile, events: &events)
        }

        return RxImpairedEventGenerationResult(
            events: events,
            wholeLosses: wholeLosses,
            fragmentLosses: fragmentLosses
        )
    }

    private static func impairedPacketEvent(
        sequence: Int,
        context: RxImpairedEventContext,
        generator: inout RxDeterministicGenerator
    ) -> RxImpairedPacketEvent {
        let profile = context.profile
        let senderDeadline = Double(sequence) * context.packetPeriodMicroseconds
        var arrival = impairedArrival(
            sequence: sequence,
            senderDeadline: senderDeadline,
            context: context,
            generator: &generator
        )
        let deadlineLate = matchesEveryNth(sequence, profile.lateEveryNthPacket)
        if deadlineLate {
            arrival.microseconds += context.packetPeriodMicroseconds * 2
        }
        let fragmentLoss = profile.fragmentCount > 1
            && matchesEveryNth(sequence, profile.fragmentLossEveryNthPacket)
        return RxImpairedPacketEvent(
            sequenceNumber: UInt64(sequence),
            senderFrameIndex: sequence * profile.framesPerPacket,
            arrivalMicroseconds: max(0, arrival.microseconds),
            packetAgeMicroseconds: max(0, arrival.microseconds - senderDeadline),
            duplicate: false,
            reordered: arrival.reordered,
            deadlineLate: deadlineLate,
            fragmentLoss: fragmentLoss,
            complete: !fragmentLoss
        )
    }

    private static func impairedArrival(
        sequence: Int,
        senderDeadline: Double,
        context: RxImpairedEventContext,
        generator: inout RxDeterministicGenerator
    ) -> RxImpairedArrival {
        let arrival = senderDeadline
            + context.profile.baseTransitMicroseconds
            + generator.jitter(amplitudeMicroseconds: context.profile.jitterAmplitudeMicroseconds)
        let reorderedArrival = arrival - context.packetPeriodMicroseconds * 1.5
        guard matchesEveryNth(sequence, context.profile.reorderEveryNthPacket),
              reorderedArrival >= 0 else {
            return RxImpairedArrival(microseconds: arrival, reordered: false)
        }
        return RxImpairedArrival(microseconds: reorderedArrival, reordered: true)
    }

    private static func appendDuplicateIfNeeded(
        for event: RxImpairedPacketEvent,
        sequence: Int,
        profile: RxImpairmentProfile,
        events: inout [RxImpairedPacketEvent]
    ) {
        guard matchesEveryNth(sequence, profile.duplicateEveryNthPacket) else {
            return
        }
        var duplicate = event
        duplicate.arrivalMicroseconds += 10
        duplicate.packetAgeMicroseconds += 10
        duplicate.duplicate = true
        events.append(duplicate)
    }

    private static func sortEventsByArrival(_ events: inout [RxImpairedPacketEvent]) {
        events.sort {
            if $0.arrivalMicroseconds == $1.arrivalMicroseconds {
                return $0.sequenceNumber < $1.sequenceNumber
            }
            return $0.arrivalMicroseconds < $1.arrivalMicroseconds
        }
    }

    private static func simulationSummary(
        profile: RxImpairmentProfile,
        events: [RxImpairedPacketEvent],
        wholeLosses: Int,
        fragmentLosses: Int
    ) -> RxImpairmentSimulationSummary {
        let originalEvents = events.filter { !$0.duplicate }
        return RxImpairmentSimulationSummary(
            sentPackets: profile.packetCount,
            deliveredPackets: events.count,
            wholePacketLosses: wholeLosses,
            fragmentLosses: fragmentLosses,
            deadlineLatePackets: originalEvents.filter(\.deadlineLate).count,
            duplicatePackets: events.filter(\.duplicate).count,
            reorderedPackets: countReordered(events),
            packetAge: packetAgeMetrics(events.map(\.packetAgeMicroseconds)),
            jitter: jitterMetrics(adjacentDeltas(originalEvents.map(\.arrivalMicroseconds)))
        )
    }

    private static func validate(_ profile: RxImpairmentProfile) throws {
        try RxBufferPolicyValidator.requirePositive(profile.packetCount, "packetCount")
        guard profile.packetCount <= maximumPacketCount else {
            throw RxImpairmentSimulationError.packetCountAboveMaximum(
                packetCount: profile.packetCount,
                maximum: maximumPacketCount
            )
        }
        try RxBufferPolicyValidator.requirePositive(profile.framesPerPacket, "framesPerPacket")
        try RxBufferPolicyValidator.requirePositive(profile.sampleRateHertz, "sampleRateHertz")
        try RxBufferPolicyValidator.requirePositive(profile.fragmentCount, "fragmentCount")
        try RxBufferPolicyValidator.requireNonNegative(profile.baseTransitMicroseconds, "baseTransitMicroseconds")
        try RxBufferPolicyValidator.requireNonNegative(profile.jitterAmplitudeMicroseconds, "jitterAmplitudeMicroseconds")
        for optional in [
            profile.lossEveryNthPacket,
            profile.duplicateEveryNthPacket,
            profile.reorderEveryNthPacket,
            profile.lateEveryNthPacket,
            profile.fragmentLossEveryNthPacket,
        ] {
            if let optional {
                try RxBufferPolicyValidator.requirePositive(optional, "everyNthPacket")
            }
        }
    }

    private static func matchesEveryNth(_ sequence: Int, _ everyNth: Int?) -> Bool {
        guard let everyNth else {
            return false
        }
        return sequence % everyNth == everyNth - 1
    }

    private static func validateDuplicateOrdering(_ events: [RxImpairedPacketEvent]) throws {
        var originals: Set<UInt64> = []
        for event in events {
            if event.duplicate {
                guard originals.contains(event.sequenceNumber) else {
                    throw RxImpairmentSimulationError.duplicateArrivedBeforeOriginal(
                        sequenceNumber: event.sequenceNumber
                    )
                }
            } else {
                originals.insert(event.sequenceNumber)
            }
        }
    }

    private static func countReordered(_ events: [RxImpairedPacketEvent]) -> Int {
        var highestSequence: UInt64 = 0
        var reordered = 0
        for event in events where !event.duplicate {
            if event.sequenceNumber < highestSequence {
                reordered += 1
            }
            highestSequence = max(highestSequence, event.sequenceNumber)
        }
        return reordered
    }

    private static func adjacentDeltas(_ values: [Double]) -> [Double] {
        guard values.count > 1 else {
            return []
        }
        return zip(values.dropFirst(), values).map { current, previous in
            abs(current - previous)
        }
    }

    private static func packetAgeMetrics(_ values: [Double]) -> UdpPcmPacketAgeMetrics {
        let metrics = percentileMetrics(values)
        return UdpPcmPacketAgeMetrics(
            p50Microseconds: metrics.p50,
            p95Microseconds: metrics.p95,
            p99Microseconds: metrics.p99,
            maxMicroseconds: metrics.max
        )
    }

    private static func jitterMetrics(_ values: [Double]) -> LatencyJitterMetrics {
        let metrics = percentileMetrics(values)
        return LatencyJitterMetrics(
            p50Microseconds: metrics.p50,
            p95Microseconds: metrics.p95,
            p99Microseconds: metrics.p99,
            maxMicroseconds: metrics.max
        )
    }

    private static func percentileMetrics(_ values: [Double]) -> RxPercentileMetrics {
        guard !values.isEmpty else {
            return RxPercentileMetrics(p50: 0, p95: 0, p99: 0, max: 0)
        }
        let sorted = values.sorted()
        return RxPercentileMetrics(
            p50: percentile(sorted, 0.50),
            p95: percentile(sorted, 0.95),
            p99: percentile(sorted, 0.99),
            max: sorted.last ?? 0
        )
    }

    private static func percentile(_ sorted: [Double], _ quantile: Double) -> Double {
        guard !sorted.isEmpty else {
            return 0
        }
        let rawIndex = Int(Double(sorted.count - 1) * quantile)
        return sorted[min(max(rawIndex, 0), sorted.count - 1)]
    }
}

public struct RxBufferBenchmarkImpact: Codable, Equatable, Sendable {
    public var profile: RxBufferPolicy
    public var targetFramesOverTime: [Int]
    public var targetChangeEvents: [RxBufferTargetChangeEvent]
    public var impairmentSummary: RxImpairmentSimulationSummary?

    public var addedLatencyFrames: Int {
        profile.latencyCostFrames
    }

    public var addedLatencyMicroseconds: Double {
        profile.latencyCostMicroseconds
    }

    public init(
        profile: RxBufferPolicy,
        targetFramesOverTime: [Int],
        targetChangeEvents: [RxBufferTargetChangeEvent],
        impairmentSummary: RxImpairmentSimulationSummary?
    ) {
        self.profile = profile
        self.targetFramesOverTime = targetFramesOverTime
        self.targetChangeEvents = targetChangeEvents
        self.impairmentSummary = impairmentSummary
    }

    public func validate() throws {
        try profile.validate()
        guard !targetFramesOverTime.isEmpty else {
            throw RxBufferPolicyValidationError.nonPositiveField("targetFramesOverTime")
        }
        for target in targetFramesOverTime {
            try RxBufferPolicyValidator.requireNonNegative(target, "targetFramesOverTime")
            if target > profile.maximumTargetFrames {
                throw RxBufferPolicyValidationError.targetAboveMaximum(
                    targetFrames: target,
                    maximumFrames: profile.maximumTargetFrames
                )
            }
        }
        for event in targetChangeEvents {
            try event.validate()
        }
    }
}

private struct RxDeterministicGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0x4D595DF4D0F33173 : seed
    }

    mutating func jitter(amplitudeMicroseconds: Double) -> Double {
        guard amplitudeMicroseconds > 0 else {
            return 0
        }
        state = state &* 6364136223846793005 &+ 1442695040888963407
        let xorshifted = UInt32(truncatingIfNeeded: ((state >> 18) ^ state) >> 27)
        let rotation = UInt32(truncatingIfNeeded: state >> 59)
        let permuted = (xorshifted >> rotation) | (xorshifted << ((0 &- rotation) & 31))
        let unit = Double(permuted) / Double(UInt32.max)
        return (unit * 2 - 1) * amplitudeMicroseconds
    }
}
