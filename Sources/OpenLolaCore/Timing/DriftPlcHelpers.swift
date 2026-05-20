import Foundation

public struct DriftClockEstimate: Equatable, Sendable {
    public var sampleCount: Int
    public var maxAbsoluteDriftFrames: Int
    public var driftSlopeFramesPerMinute: Double
    public var latestDriftFrames: Int

    public init(
        sampleCount: Int,
        maxAbsoluteDriftFrames: Int,
        driftSlopeFramesPerMinute: Double,
        latestDriftFrames: Int
    ) {
        self.sampleCount = sampleCount
        self.maxAbsoluteDriftFrames = maxAbsoluteDriftFrames
        self.driftSlopeFramesPerMinute = driftSlopeFramesPerMinute
        self.latestDriftFrames = latestDriftFrames
    }
}

public struct DriftClockEstimator: Sendable {
    private var samples: [DriftTelemetrySample] = []
    private let sampleRateHertz: Int
    private let correctionStepFrames: Int

    public init(sampleRateHertz: Int, correctionStepFrames: Int) {
        precondition(sampleRateHertz > 0, "sampleRateHertz must be positive")
        precondition(correctionStepFrames > 0, "correctionStepFrames must be positive")
        self.sampleRateHertz = sampleRateHertz
        self.correctionStepFrames = correctionStepFrames
    }

    public mutating func observe(
        sequenceNumber: UInt64,
        senderFrameIndex: Int,
        receiverPlayoutFrameIndex: Int,
        packetAgeMicroseconds: Double
    ) -> DriftTelemetrySample {
        let sample = DriftTelemetrySample(
            sequenceNumber: sequenceNumber,
            senderFrameIndex: senderFrameIndex,
            receiverPlayoutFrameIndex: receiverPlayoutFrameIndex,
            driftFrames: senderFrameIndex - receiverPlayoutFrameIndex,
            packetAgeMicroseconds: packetAgeMicroseconds
        )
        samples.append(sample)
        return sample
    }

    public var estimate: DriftClockEstimate {
        DriftClockEstimate(
            sampleCount: samples.count,
            maxAbsoluteDriftFrames: samples.map { abs($0.driftFrames) }.max() ?? 0,
            driftSlopeFramesPerMinute: driftSlopeFramesPerMinute(),
            latestDriftFrames: samples.last?.driftFrames ?? 0
        )
    }

    public func correctionEventIfNeeded(playoutFrameIndex: Int) -> DriftCorrectionEvent? {
        let driftFrames = estimate.latestDriftFrames
        guard abs(driftFrames) >= correctionStepFrames else {
            return nil
        }
        let correction = min(abs(driftFrames), correctionStepFrames)
        let driftFramesAfter = driftFrames > 0
            ? driftFrames - correction
            : driftFrames + correction

        return DriftCorrectionEvent(
            playoutFrameIndex: playoutFrameIndex,
            driftFramesBefore: driftFrames,
            driftFramesAfter: driftFramesAfter,
            location: .outsideCallback,
            targetGrowthFrames: 0,
            notes: "Bounded clock-drift correction scheduled outside the realtime callback."
        )
    }

    private func driftSlopeFramesPerMinute() -> Double {
        guard let first = samples.first, let last = samples.last, samples.count > 1 else {
            return 0
        }
        let elapsedFrames = last.senderFrameIndex - first.senderFrameIndex
        guard elapsedFrames > 0 else {
            return 0
        }

        let elapsedMinutes = Double(elapsedFrames) / Double(sampleRateHertz) / 60
        guard elapsedMinutes > 0 else {
            return 0
        }
        return Double(last.driftFrames - first.driftFrames) / elapsedMinutes
    }
}

func fixedPlayoutTargetFrames(routeReport: UdpPcmRouteReport) -> Int {
    routeReport.packetMode.framesPerPacket
}

func fixedTargetTelemetry(
    packetCount: Int,
    playoutTargetFrames: Int,
    packetMode: UdpPcmPacketMode,
    packetAgeMicroseconds: Double = 0
) -> [DriftTelemetrySample] {
    uniqueSortedCheckpoints(packetCount: packetCount).map { index in
        let frameIndex = index * packetMode.framesPerPacket
        return DriftTelemetrySample(
            sequenceNumber: UInt64(index),
            senderFrameIndex: frameIndex,
            receiverPlayoutFrameIndex: frameIndex,
            driftFrames: 0,
            packetAgeMicroseconds: packetAgeMicroseconds
        )
    }
}

func uniqueSortedCheckpoints(packetCount: Int) -> [Int] {
    Array(Set([0, packetCount / 3, (packetCount * 2) / 3, max(0, packetCount - 1)])).sorted()
}

func driftClockEstimate(
    telemetry: [DriftTelemetrySample],
    sampleRateHertz: Int
) -> DriftClockEstimate {
    var estimator = DriftClockEstimator(
        sampleRateHertz: sampleRateHertz,
        correctionStepFrames: 1
    )
    for sample in telemetry {
        _ = estimator.observe(
            sequenceNumber: sample.sequenceNumber,
            senderFrameIndex: sample.senderFrameIndex,
            receiverPlayoutFrameIndex: sample.receiverPlayoutFrameIndex,
            packetAgeMicroseconds: sample.packetAgeMicroseconds
        )
    }
    return estimator.estimate
}

func fixedTargetPlcEvents(
    routeReport: UdpPcmRouteReport,
    playoutTargetFrames: Int,
    policy: SameDeadlinePlcPolicy
) -> [SameDeadlinePlcEvent] {
    let unavailablePackets = routeReport.metrics.lostPackets + routeReport.metrics.latePackets
    guard unavailablePackets > 0 else {
        return []
    }

    let missingSequenceNumber = UInt64(max(0, routeReport.metrics.packetsReceived / 2))
    let dueFrameIndex = Int(missingSequenceNumber) * routeReport.packetMode.framesPerPacket
        + playoutTargetFrames
    return [
        SameDeadlinePlcEvent(
            dueFrameIndex: dueFrameIndex,
            missingSequenceNumber: missingSequenceNumber,
            policy: policy,
            waitedForRetransmission: false,
            playoutTargetFramesBefore: playoutTargetFrames,
            playoutTargetFramesAfter: playoutTargetFrames,
            branchBounded: true,
            notes: sameDeadlinePolicyNotes(policy)
        )
    ]
}

func fixedTargetCorrectionEvents(
    telemetry: [DriftTelemetrySample],
    sampleRateHertz: Int,
    correctionStepFrames: Int
) -> [DriftCorrectionEvent] {
    var estimator = DriftClockEstimator(
        sampleRateHertz: sampleRateHertz,
        correctionStepFrames: correctionStepFrames
    )
    var lastSample: DriftTelemetrySample?
    for sample in telemetry {
        lastSample = estimator.observe(
            sequenceNumber: sample.sequenceNumber,
            senderFrameIndex: sample.senderFrameIndex,
            receiverPlayoutFrameIndex: sample.receiverPlayoutFrameIndex,
            packetAgeMicroseconds: sample.packetAgeMicroseconds
        )
    }
    guard let lastSample,
          let event = estimator.correctionEventIfNeeded(
            playoutFrameIndex: lastSample.receiverPlayoutFrameIndex
          ) else {
        return []
    }
    return [event]
}

func sameDeadlinePolicyNotes(_ policy: SameDeadlinePlcPolicy) -> String {
    switch policy {
    case .silence:
        "Same-deadline PLC inserts silence without waiting for retransmission."
    case .repeatLastGoodBlock:
        "Same-deadline PLC repeats the last good block without waiting for retransmission."
    case .boundedSubstitute:
        "Same-deadline PLC uses a bounded substitute without changing the playout target."
    }
}

func requiredDriftRunString(
    _ argument: String,
    _ values: [String: String]
) throws -> String {
    guard let value = values[argument], !value.isEmpty else {
        throw DriftPlcRunConfigurationError.missingRequiredArgument(argument)
    }
    return value
}

func requiredDriftRunPositiveInteger(
    _ argument: String,
    _ values: [String: String]
) throws -> Int {
    let value = try requiredDriftRunString(argument, values)
    guard let integer = Int(value) else {
        throw DriftPlcRunConfigurationError.invalidInteger(argument: argument, value: value)
    }
    guard integer > 0 else {
        throw DriftPlcRunConfigurationError.nonPositiveArgument(argument)
    }
    return integer
}

func requiredDriftRunBoolean(
    _ argument: String,
    _ values: [String: String]
) throws -> Bool {
    let value = try requiredDriftRunString(argument, values)
    switch value.lowercased() {
    case "true", "yes", "1":
        return true
    case "false", "no", "0":
        return false
    default:
        throw DriftPlcRunConfigurationError.invalidBoolean(argument: argument, value: value)
    }
}

func parseDriftRunPolicy(_ value: String) throws -> SameDeadlinePlcPolicy {
    guard let policy = SameDeadlinePlcPolicy(rawValue: value) else {
        throw DriftPlcRunConfigurationError.invalidPolicy(value)
    }
    return policy
}

enum DriftPlcValidator: ReportPrimitiveValidating {
    typealias ValidationError = DriftPlcValidationError
}
