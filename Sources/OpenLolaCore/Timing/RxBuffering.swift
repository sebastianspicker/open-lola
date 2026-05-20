import Foundation

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
}

extension RxBufferPolicyValidationError: ValidationEmptyFieldError, ValidationNonPositiveFieldError,
    ValidationNegativeFieldError, ValidationNonFiniteFieldError {}

enum RxBufferPolicyValidator: ReportPrimitiveValidating {
    typealias ValidationError = RxBufferPolicyValidationError
}

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

    public init(
        profile: RxBufferProfile,
        framesPerPacket: Int,
        sampleRateHertz: Int,
        minimumTargetFrames: Int,
        targetFrames: Int,
        maximumTargetFrames: Int,
        fastestAudioPassEligible: Bool,
        adaptationChangesOutsideCallback: Bool,
        notes: String
    ) {
        self.profile = profile
        self.framesPerPacket = framesPerPacket
        self.sampleRateHertz = sampleRateHertz
        self.minimumTargetFrames = minimumTargetFrames
        self.targetFrames = targetFrames
        self.maximumTargetFrames = maximumTargetFrames
        self.fastestAudioPassEligible = fastestAudioPassEligible
        self.adaptationChangesOutsideCallback = adaptationChangesOutsideCallback
        self.notes = notes
    }

    public static func direct(
        framesPerPacket: Int,
        sampleRateHertz: Int,
        targetPackets: Int = 1
    ) throws -> RxBufferPolicy {
        let policy = RxBufferPolicy(
            profile: .direct,
            framesPerPacket: framesPerPacket,
            sampleRateHertz: sampleRateHertz,
            minimumTargetFrames: 0,
            targetFrames: targetPackets * framesPerPacket,
            maximumTargetFrames: framesPerPacket,
            fastestAudioPassEligible: true,
            adaptationChangesOutsideCallback: true,
            notes: "Direct RX: one packet target, no adaptive growth."
        )
        try policy.validate()
        return policy
    }

    public static func small(
        framesPerPacket: Int,
        sampleRateHertz: Int,
        targetPackets: Int = 2
    ) throws -> RxBufferPolicy {
        let policy = RxBufferPolicy(
            profile: .small,
            framesPerPacket: framesPerPacket,
            sampleRateHertz: sampleRateHertz,
            minimumTargetFrames: framesPerPacket,
            targetFrames: targetPackets * framesPerPacket,
            maximumTargetFrames: 2 * framesPerPacket,
            fastestAudioPassEligible: false,
            adaptationChangesOutsideCallback: true,
            notes: "Small RX: fixed one- or two-packet target with visible latency cost."
        )
        try policy.validate()
        return policy
    }

    public static func adaptive(
        framesPerPacket: Int,
        sampleRateHertz: Int,
        minimumPackets: Int = 1,
        initialPackets: Int = 1,
        maximumPackets: Int = 4
    ) throws -> RxBufferPolicy {
        let policy = RxBufferPolicy(
            profile: .adaptive,
            framesPerPacket: framesPerPacket,
            sampleRateHertz: sampleRateHertz,
            minimumTargetFrames: minimumPackets * framesPerPacket,
            targetFrames: initialPackets * framesPerPacket,
            maximumTargetFrames: maximumPackets * framesPerPacket,
            fastestAudioPassEligible: false,
            adaptationChangesOutsideCallback: true,
            notes: "Adaptive RX: target changes outside the audio callback within configured bounds."
        )
        try policy.validate()
        return policy
    }

    public static func stableWan(
        framesPerPacket: Int,
        sampleRateHertz: Int,
        targetPackets: Int = 8,
        maximumPackets: Int = 16
    ) throws -> RxBufferPolicy {
        let policy = RxBufferPolicy(
            profile: .stableWan,
            framesPerPacket: framesPerPacket,
            sampleRateHertz: sampleRateHertz,
            minimumTargetFrames: targetPackets * framesPerPacket,
            targetFrames: targetPackets * framesPerPacket,
            maximumTargetFrames: maximumPackets * framesPerPacket,
            fastestAudioPassEligible: false,
            adaptationChangesOutsideCallback: true,
            notes: "Stable/WAN RX: continuity-first target, never fastest direct audio."
        )
        try policy.validate()
        return policy
    }

    public func validate() throws {
        try RxBufferPolicyValidator.requirePositive(framesPerPacket, "framesPerPacket")
        try RxBufferPolicyValidator.requirePositive(sampleRateHertz, "sampleRateHertz")
        try RxBufferPolicyValidator.requireNonNegative(minimumTargetFrames, "minimumTargetFrames")
        try RxBufferPolicyValidator.requireNonNegative(targetFrames, "targetFrames")
        try RxBufferPolicyValidator.requireNonNegative(maximumTargetFrames, "maximumTargetFrames")
        try RxBufferPolicyValidator.requireNonEmpty(notes, "notes")

        guard targetFrames >= minimumTargetFrames else {
            throw RxBufferPolicyValidationError.targetBelowMinimum(
                targetFrames: targetFrames,
                minimumFrames: minimumTargetFrames
            )
        }
        guard targetFrames <= maximumTargetFrames else {
            throw RxBufferPolicyValidationError.targetAboveMaximum(
                targetFrames: targetFrames,
                maximumFrames: maximumTargetFrames
            )
        }
        for target in [minimumTargetFrames, targetFrames, maximumTargetFrames]
            where target % framesPerPacket != 0 {
            throw RxBufferPolicyValidationError.targetNotPacketAligned(
                targetFrames: target,
                framesPerPacket: framesPerPacket
            )
        }

        switch profile {
        case .direct:
            guard targetPackets == 1 else {
                throw RxBufferPolicyValidationError.directTargetOutOfRange(
                    targetPackets: targetPackets
                )
            }
        case .small:
            guard targetPackets == 1 || targetPackets == 2 else {
                throw RxBufferPolicyValidationError.smallTargetOutOfRange(
                    targetPackets: targetPackets
                )
            }
            guard !fastestAudioPassEligible else {
                throw RxBufferPolicyValidationError.fastestIneligibleProfile(profile)
            }
        case .adaptive:
            guard adaptationChangesOutsideCallback else {
                throw RxBufferPolicyValidationError.adaptiveRequiresOutsideCallbackChanges
            }
            guard !fastestAudioPassEligible else {
                throw RxBufferPolicyValidationError.fastestIneligibleProfile(profile)
            }
        case .stableWan:
            guard targetPackets >= 8 else {
                throw RxBufferPolicyValidationError.stableWanTargetTooSmall(
                    targetPackets: targetPackets
                )
            }
            guard !fastestAudioPassEligible else {
                throw RxBufferPolicyValidationError.fastestIneligibleProfile(profile)
            }
        }
    }

    public static func microseconds(frames: Int, sampleRateHertz: Int) -> Double {
        guard sampleRateHertz > 0 else {
            return 0
        }
        return (Double(frames) / Double(sampleRateHertz)) * 1_000_000
    }
}

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

    public func validate() throws {
        try RxBufferPolicyValidator.requireNonNegative(targetFramesBefore, "targetFramesBefore")
        try RxBufferPolicyValidator.requireNonNegative(targetFramesAfter, "targetFramesAfter")
        try RxBufferPolicyValidator.requireNonNegative(latencyCostMicrosecondsBefore, "latencyCostMicrosecondsBefore")
        try RxBufferPolicyValidator.requireNonNegative(latencyCostMicrosecondsAfter, "latencyCostMicrosecondsAfter")
        try RxBufferPolicyValidator.requireNonEmpty(reason, "reason")
        guard !changedInsideAudioCallback else {
            throw RxBufferPolicyValidationError.targetChangeInsideAudioCallback(
                sequenceNumber: sequenceNumber
            )
        }
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

    public init(
        policy: RxBufferPolicy,
        currentTargetFrames: Int? = nil,
        maximumObservedTargetFrames: Int? = nil,
        maximumObservedBufferedPackets: Int = 0,
        latePackets: Int = 0,
        futurePackets: Int = 0,
        lostPackets: Int = 0,
        fragmentLostPackets: Int = 0,
        duplicatePackets: Int = 0,
        reorderedPackets: Int = 0,
        underruns: Int = 0,
        overruns: Int = 0,
        plcEvents: Int = 0,
        hiddenGrowthDetected: Bool = false,
        targetChangeEvents: [RxBufferTargetChangeEvent] = []
    ) {
        self.policy = policy
        self.currentTargetFrames = currentTargetFrames ?? policy.targetFrames
        self.maximumObservedTargetFrames = maximumObservedTargetFrames ?? policy.targetFrames
        self.maximumObservedBufferedPackets = maximumObservedBufferedPackets
        self.latePackets = latePackets
        self.futurePackets = futurePackets
        self.lostPackets = lostPackets
        self.fragmentLostPackets = fragmentLostPackets
        self.duplicatePackets = duplicatePackets
        self.reorderedPackets = reorderedPackets
        self.underruns = underruns
        self.overruns = overruns
        self.plcEvents = plcEvents
        self.hiddenGrowthDetected = hiddenGrowthDetected
        self.targetChangeEvents = targetChangeEvents
    }

    public mutating func recordBufferedPacketCount(_ count: Int) {
        maximumObservedBufferedPackets = max(maximumObservedBufferedPackets, count)
        hiddenGrowthDetected = hiddenGrowthDetected || count > policy.maximumTargetPackets
    }

    public mutating func recordTargetFrames(_ frames: Int) {
        currentTargetFrames = frames
        maximumObservedTargetFrames = max(maximumObservedTargetFrames, frames)
        hiddenGrowthDetected = hiddenGrowthDetected || frames > policy.maximumTargetFrames
    }

    public func validate() throws {
        try policy.validate()
        try RxBufferPolicyValidator.requireNonNegative(currentTargetFrames, "currentTargetFrames")
        try RxBufferPolicyValidator.requireNonNegative(maximumObservedTargetFrames, "maximumObservedTargetFrames")
        try RxBufferPolicyValidator.requireNonNegative(maximumObservedBufferedPackets, "maximumObservedBufferedPackets")
        try RxBufferPolicyValidator.requireNonNegative(latePackets, "latePackets")
        try RxBufferPolicyValidator.requireNonNegative(futurePackets, "futurePackets")
        try RxBufferPolicyValidator.requireNonNegative(lostPackets, "lostPackets")
        try RxBufferPolicyValidator.requireNonNegative(fragmentLostPackets, "fragmentLostPackets")
        try RxBufferPolicyValidator.requireNonNegative(duplicatePackets, "duplicatePackets")
        try RxBufferPolicyValidator.requireNonNegative(reorderedPackets, "reorderedPackets")
        try RxBufferPolicyValidator.requireNonNegative(underruns, "underruns")
        try RxBufferPolicyValidator.requireNonNegative(overruns, "overruns")
        try RxBufferPolicyValidator.requireNonNegative(plcEvents, "plcEvents")
        for event in targetChangeEvents {
            try event.validate()
        }
    }
}

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

public struct RxBufferAdaptiveDecision: Equatable, Sendable {
    public var targetFrames: Int
    public var changed: Bool
}

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

        if quiet {
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
        } else {
            highSampleCount = 0
            lowSampleCount = 0
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
