// Implements RxBuffering bounded buffering, isolating real-time ownership rules from audio and network loops.
import Foundation

/// Reports `emptyField`, `nonPositiveField`, `negativeField`, and `nonFiniteField` failures that stop invalid timing and drift control work before it reaches a live path.
public enum RxBufferPolicyValidationError: Error, Equatable, Sendable {
    case emptyField(String)
    case nonPositiveField(String)
    case negativeField(String)
    case nonFiniteField(String)
    case targetBelowMinimum(targetFrames: Int, minimumFrames: Int)
    case targetAboveMaximum(targetFrames: Int, maximumFrames: Int)
    case targetNotPacketAligned(targetFrames: Int, framesPerPacket: Int)
    case directTargetOutOfRange(targetPackets: Int)
    case directTargetTooLarge(targetPackets: Int)
    case smallTargetOutOfRange(targetPackets: Int)
    case adaptiveRequiresOutsideCallbackChanges
    case stableWanTargetTooSmall(targetPackets: Int)
    case fastestIneligibleProfile(RxBufferProfile)
    case targetChangeInsideAudioCallback(sequenceNumber: UInt64)
    case hiddenGrowthDetected
    case arithmeticOverflow(String)
}

extension RxBufferPolicyValidationError: ValidationEmptyFieldError, ValidationNonPositiveFieldError,
    ValidationNegativeFieldError, ValidationNonFiniteFieldError {}

/// Constrains `profile`, `framesPerPacket`, `sampleRateHertz`, and `minimumTargetFrames` so timing and drift control tradeoffs remain explicit and testable.
public struct RxBufferPolicy: Codable, Equatable, Sendable {
    public var profile: RxBufferProfile
    public var framesPerPacket: Int
    public var sampleRateHertz: Int
    public var minimumTargetFrames: Int
    public var targetFrames: Int
    public var maximumTargetFrames: Int
    public var fastestAudioPassEligible: Bool
    public var adaptationChangesOutsideCallback: Bool
    public var notes: String

    public var targetPackets: Int {
        guard framesPerPacket > 0 else {
            return 0
        }
        return targetFrames / framesPerPacket
    }

    public var maximumTargetPackets: Int {
        guard framesPerPacket > 0 else {
            return 0
        }
        return maximumTargetFrames / framesPerPacket
    }

    public var latencyCostFrames: Int {
        targetFrames
    }

    public var latencyCostPackets: Int {
        targetPackets
    }

    public var latencyCostMicroseconds: Double {
        RxBufferPolicy.microseconds(frames: latencyCostFrames, sampleRateHertz: sampleRateHertz)
    }

    public struct Transport: Equatable, Sendable {
        public var framesPerPacket: Int
        public var sampleRateHertz: Int

        public init(framesPerPacket: Int, sampleRateHertz: Int) {
            self.framesPerPacket = framesPerPacket
            self.sampleRateHertz = sampleRateHertz
        }
    }

    public struct Targets: Equatable, Sendable {
        public var minimumFrames: Int
        public var targetFrames: Int
        public var maximumFrames: Int

        public init(minimumFrames: Int, targetFrames: Int, maximumFrames: Int) {
            self.minimumFrames = minimumFrames
            self.targetFrames = targetFrames
            self.maximumFrames = maximumFrames
        }
    }

    public struct Eligibility: Equatable, Sendable {
        public var fastestAudioPassEligible: Bool
        public var adaptationChangesOutsideCallback: Bool
        public var notes: String

        public init(
            fastestAudioPassEligible: Bool,
            adaptationChangesOutsideCallback: Bool,
            notes: String
        ) {
            self.fastestAudioPassEligible = fastestAudioPassEligible
            self.adaptationChangesOutsideCallback = adaptationChangesOutsideCallback
            self.notes = notes
        }
    }

    public init(
        profile: RxBufferProfile,
        transport: Transport,
        targets: Targets,
        eligibility: Eligibility
    ) {
        self.profile = profile
        self.framesPerPacket = transport.framesPerPacket
        self.sampleRateHertz = transport.sampleRateHertz
        self.minimumTargetFrames = targets.minimumFrames
        self.targetFrames = targets.targetFrames
        self.maximumTargetFrames = targets.maximumFrames
        self.fastestAudioPassEligible = eligibility.fastestAudioPassEligible
        self.adaptationChangesOutsideCallback = eligibility.adaptationChangesOutsideCallback
        self.notes = eligibility.notes
    }
}

/// Records each receive-target change with its sequence point and governing reason.
public struct RxBufferTargetChangeEvent: Codable, Equatable, Sendable {
    public var sequenceNumber: UInt64
    public var targetFramesBefore: Int
    public var targetFramesAfter: Int
    public var reason: String
    public var changedInsideAudioCallback: Bool
    public var latencyCostMicrosecondsBefore: Double
    public var latencyCostMicrosecondsAfter: Double

    public init(
        sequenceNumber: UInt64,
        targetFramesBefore: Int,
        targetFramesAfter: Int,
        reason: String,
        changedInsideAudioCallback: Bool,
        latencyCostMicrosecondsBefore: Double,
        latencyCostMicrosecondsAfter: Double
    ) {
        self.sequenceNumber = sequenceNumber
        self.targetFramesBefore = targetFramesBefore
        self.targetFramesAfter = targetFramesAfter
        self.reason = reason
        self.changedInsideAudioCallback = changedInsideAudioCallback
        self.latencyCostMicrosecondsBefore = latencyCostMicrosecondsBefore
        self.latencyCostMicrosecondsAfter = latencyCostMicrosecondsAfter
    }

}

public extension RxBufferProfile {
    func policy(framesPerPacket: Int, sampleRateHertz: Int) throws -> RxBufferPolicy {
        switch self {
        case .direct:
            try .direct(framesPerPacket: framesPerPacket, sampleRateHertz: sampleRateHertz)
        case .small:
            try .small(framesPerPacket: framesPerPacket, sampleRateHertz: sampleRateHertz)
        case .adaptive:
            try .adaptive(framesPerPacket: framesPerPacket, sampleRateHertz: sampleRateHertz)
        case .stableWan:
            try .stableWan(framesPerPacket: framesPerPacket, sampleRateHertz: sampleRateHertz)
        }
    }
}

/// Captures the active receive policy, target, and observed queue high-water marks.
public struct RxBufferRuntimeSnapshot: Codable, Equatable, Sendable {
    public var policy: RxBufferPolicy
    public var currentTargetFrames: Int
    public var maximumObservedTargetFrames: Int
    public var maximumObservedBufferedPackets: Int
    public var latePackets: Int
    public var futurePackets: Int
    public var lostPackets: Int
    public var fragmentLostPackets: Int
    public var duplicatePackets: Int
    public var reorderedPackets: Int
    public var underruns: Int
    public var overruns: Int
    public var plcEvents: Int
    public var hiddenGrowthDetected: Bool
    public var targetChangeEvents: [RxBufferTargetChangeEvent]

    public var latencyCostMicroseconds: Double {
        RxBufferPolicy.microseconds(
            frames: currentTargetFrames,
            sampleRateHertz: policy.sampleRateHertz
        )
    }

    public struct TargetObservation: Equatable, Sendable {
        public var currentTargetFrames: Int?
        public var maximumObservedTargetFrames: Int?
        public var maximumObservedBufferedPackets: Int
        public var hiddenGrowthDetected: Bool
        public var targetChangeEvents: [RxBufferTargetChangeEvent]

        public init(
            currentTargetFrames: Int? = nil,
            maximumObservedTargetFrames: Int? = nil,
            maximumObservedBufferedPackets: Int = 0,
            hiddenGrowthDetected: Bool = false,
            targetChangeEvents: [RxBufferTargetChangeEvent] = []
        ) {
            self.currentTargetFrames = currentTargetFrames
            self.maximumObservedTargetFrames = maximumObservedTargetFrames
            self.maximumObservedBufferedPackets = maximumObservedBufferedPackets
            self.hiddenGrowthDetected = hiddenGrowthDetected
            self.targetChangeEvents = targetChangeEvents
        }
    }

    public struct PacketCounters: Equatable, Sendable {
        public var latePackets: Int
        public var futurePackets: Int
        public var lostPackets: Int
        public var fragmentLostPackets: Int
        public var duplicatePackets: Int
        public var reorderedPackets: Int

        public init(
            latePackets: Int = 0,
            futurePackets: Int = 0,
            lostPackets: Int = 0,
            fragmentLostPackets: Int = 0,
            duplicatePackets: Int = 0,
            reorderedPackets: Int = 0
        ) {
            self.latePackets = latePackets
            self.futurePackets = futurePackets
            self.lostPackets = lostPackets
            self.fragmentLostPackets = fragmentLostPackets
            self.duplicatePackets = duplicatePackets
            self.reorderedPackets = reorderedPackets
        }
    }

    public struct PlayoutCounters: Equatable, Sendable {
        public var underruns: Int
        public var overruns: Int
        public var plcEvents: Int

        public init(underruns: Int = 0, overruns: Int = 0, plcEvents: Int = 0) {
            self.underruns = underruns
            self.overruns = overruns
            self.plcEvents = plcEvents
        }
    }

    public init(
        policy: RxBufferPolicy,
        targetObservation: TargetObservation = .init(),
        packetCounters: PacketCounters = .init(),
        playoutCounters: PlayoutCounters = .init()
    ) {
        self.policy = policy
        self.currentTargetFrames = targetObservation.currentTargetFrames ?? policy.targetFrames
        self.maximumObservedTargetFrames = targetObservation.maximumObservedTargetFrames ?? policy.targetFrames
        self.maximumObservedBufferedPackets = targetObservation.maximumObservedBufferedPackets
        self.latePackets = packetCounters.latePackets
        self.futurePackets = packetCounters.futurePackets
        self.lostPackets = packetCounters.lostPackets
        self.fragmentLostPackets = packetCounters.fragmentLostPackets
        self.duplicatePackets = packetCounters.duplicatePackets
        self.reorderedPackets = packetCounters.reorderedPackets
        self.underruns = playoutCounters.underruns
        self.overruns = playoutCounters.overruns
        self.plcEvents = playoutCounters.plcEvents
        self.hiddenGrowthDetected = targetObservation.hiddenGrowthDetected
        self.targetChangeEvents = targetObservation.targetChangeEvents
    }

}

/// Records the jitter, lateness, and underrun observations used for one adaptation step.
public struct RxBufferAdaptationSample: Equatable, Sendable {
    public var sequenceNumber: UInt64
    public var jitterP99Microseconds: Double
    public var latePackets: Int
    public var underruns: Int

    public init(
        sequenceNumber: UInt64,
        jitterP99Microseconds: Double,
        latePackets: Int = 0,
        underruns: Int = 0
    ) {
        self.sequenceNumber = sequenceNumber
        self.jitterP99Microseconds = jitterP99Microseconds
        self.latePackets = latePackets
        self.underruns = underruns
    }

    public static func sample(
        _ sequenceNumber: UInt64,
        jitterP99Microseconds: Double,
        latePackets: Int = 0,
        underruns: Int = 0
    ) -> RxBufferAdaptationSample {
        RxBufferAdaptationSample(
            sequenceNumber: sequenceNumber,
            jitterP99Microseconds: jitterP99Microseconds,
            latePackets: latePackets,
            underruns: underruns
        )
    }
}

/// States the target chosen by an adaptive receive-buffer evaluation and whether it changed.
public struct RxBufferAdaptiveDecision: Equatable, Sendable {
    public var targetFrames: Int
    public var changed: Bool
}

/// Adjusts the receive target from bounded adaptation samples without changing callback-owned state.
public struct RxBufferAdaptiveController: Sendable {
    public private(set) var snapshot: RxBufferRuntimeSnapshot
    public private(set) var targetChangeEvents: [RxBufferTargetChangeEvent] = []

    private let increaseAfterSamples: Int
    private let decreaseAfterSamples: Int
    private let highJitterMicroseconds: Double
    private let lowJitterMicroseconds: Double
    private var highSampleCount = 0
    private var lowSampleCount = 0

    public init(
        policy: RxBufferPolicy,
        increaseAfterSamples: Int,
        decreaseAfterSamples: Int,
        highJitterMicroseconds: Double,
        lowJitterMicroseconds: Double
    ) throws {
        try policy.validate()
        guard policy.profile == .adaptive else {
            throw RxBufferPolicyValidationError.fastestIneligibleProfile(policy.profile)
        }
        try RxBufferPolicyValidator.requirePositive(increaseAfterSamples, "increaseAfterSamples")
        try RxBufferPolicyValidator.requirePositive(decreaseAfterSamples, "decreaseAfterSamples")
        try RxBufferPolicyValidator.requireNonNegative(highJitterMicroseconds, "highJitterMicroseconds")
        try RxBufferPolicyValidator.requireNonNegative(lowJitterMicroseconds, "lowJitterMicroseconds")
        self.snapshot = RxBufferRuntimeSnapshot(policy: policy)
        self.increaseAfterSamples = increaseAfterSamples
        self.decreaseAfterSamples = decreaseAfterSamples
        self.highJitterMicroseconds = highJitterMicroseconds
        self.lowJitterMicroseconds = lowJitterMicroseconds
    }

    public static func runtimeController(policy: RxBufferPolicy) throws -> RxBufferAdaptiveController {
        try RxBufferAdaptiveController(
            policy: policy,
            increaseAfterSamples: 2,
            decreaseAfterSamples: 8,
            highJitterMicroseconds: max(policy.latencyCostMicroseconds * 2, 2_000),
            lowJitterMicroseconds: max(policy.latencyCostMicroseconds / 2, 250)
        )
    }

    public mutating func observe(_ sample: RxBufferAdaptationSample) -> RxBufferAdaptiveDecision {
        // Thresholds are inclusive: exactly high jitter increases pressure, exactly low jitter counts as quiet.
        let stressed = sample.jitterP99Microseconds >= highJitterMicroseconds
            || sample.latePackets > 0
            || sample.underruns > 0
        let quiet = sample.jitterP99Microseconds <= lowJitterMicroseconds
            && sample.latePackets == 0
            && sample.underruns == 0

        if stressed {
            return observeStressedSample(sample)
        }

        if quiet {
            return observeQuietSample(sample)
        } else {
            highSampleCount = 0
            lowSampleCount = 0
        }

        return RxBufferAdaptiveDecision(targetFrames: snapshot.currentTargetFrames, changed: false)
    }

    private mutating func observeStressedSample(
        _ sample: RxBufferAdaptationSample
    ) -> RxBufferAdaptiveDecision {
        highSampleCount += 1
        lowSampleCount = 0
        if highSampleCount >= increaseAfterSamples {
            highSampleCount = 0
            return changeTarget(
                byPackets: 1,
                sample: sample,
                reason: "sustained high jitter, late packets, or underruns"
            )
        }
        return RxBufferAdaptiveDecision(targetFrames: snapshot.currentTargetFrames, changed: false)
    }

    private mutating func observeQuietSample(
        _ sample: RxBufferAdaptationSample
    ) -> RxBufferAdaptiveDecision {
        lowSampleCount += 1
        highSampleCount = 0
        if lowSampleCount >= decreaseAfterSamples {
            lowSampleCount = 0
            return changeTarget(
                byPackets: -1,
                sample: sample,
                reason: "sustained low jitter without late packets or underruns"
            )
        }
        return RxBufferAdaptiveDecision(targetFrames: snapshot.currentTargetFrames, changed: false)
    }

    private mutating func changeTarget(
        byPackets packetDelta: Int,
        sample: RxBufferAdaptationSample,
        reason: String
    ) -> RxBufferAdaptiveDecision {
        let before = snapshot.currentTargetFrames
        let proposed = before + packetDelta * snapshot.policy.framesPerPacket
        let after = min(
            max(proposed, snapshot.policy.minimumTargetFrames),
            snapshot.policy.maximumTargetFrames
        )
        guard after != before else {
            return RxBufferAdaptiveDecision(targetFrames: before, changed: false)
        }

        let event = RxBufferTargetChangeEvent(
            sequenceNumber: sample.sequenceNumber,
            targetFramesBefore: before,
            targetFramesAfter: after,
            reason: reason,
            changedInsideAudioCallback: false,
            latencyCostMicrosecondsBefore: RxBufferPolicy.microseconds(
                frames: before,
                sampleRateHertz: snapshot.policy.sampleRateHertz
            ),
            latencyCostMicrosecondsAfter: RxBufferPolicy.microseconds(
                frames: after,
                sampleRateHertz: snapshot.policy.sampleRateHertz
            )
        )
        targetChangeEvents.append(event)
        snapshot.targetChangeEvents.append(event)
        snapshot.recordTargetFrames(after)
        return RxBufferAdaptiveDecision(targetFrames: after, changed: true)
    }
}
