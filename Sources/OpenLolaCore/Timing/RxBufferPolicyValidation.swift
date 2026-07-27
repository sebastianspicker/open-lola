// Validates RxBufferPolicyValidation acceptance rules, keeping failure policy close to its contract rather than the runtime path.
import Foundation

extension RxBufferPolicy {

    public static func direct(
        framesPerPacket: Int,
        sampleRateHertz: Int,
        targetPackets: Int = 1
    ) throws -> RxBufferPolicy {
        let targetFrames = try checkedFrameProduct(
            targetPackets,
            framesPerPacket,
            field: "targetFrames"
        )
        let policy = RxBufferPolicy(
            profile: .direct,
            transport: .init(framesPerPacket: framesPerPacket, sampleRateHertz: sampleRateHertz),
            targets: .init(minimumFrames: 0, targetFrames: targetFrames, maximumFrames: framesPerPacket),
            eligibility: .init(
                fastestAudioPassEligible: true,
                adaptationChangesOutsideCallback: true,
                notes: "Direct RX: one packet target, no adaptive growth."
            )
        )
        try policy.validate()
        return policy
    }

    public static func small(
        framesPerPacket: Int,
        sampleRateHertz: Int,
        targetPackets: Int = 2
    ) throws -> RxBufferPolicy {
        let minimumTargetFrames = try checkedFrameProduct(
            1,
            framesPerPacket,
            field: "minimumTargetFrames"
        )
        let targetFrames = try checkedFrameProduct(
            targetPackets,
            framesPerPacket,
            field: "targetFrames"
        )
        let maximumTargetFrames = try checkedFrameProduct(
            2,
            framesPerPacket,
            field: "maximumTargetFrames"
        )
        let policy = RxBufferPolicy(
            profile: .small,
            transport: .init(framesPerPacket: framesPerPacket, sampleRateHertz: sampleRateHertz),
            targets: .init(
                minimumFrames: minimumTargetFrames,
                targetFrames: targetFrames,
                maximumFrames: maximumTargetFrames
            ),
            eligibility: .init(
                fastestAudioPassEligible: false,
                adaptationChangesOutsideCallback: true,
                notes: "Small RX: fixed one- or two-packet target with visible latency cost."
            )
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
        let minimumTargetFrames = try checkedFrameProduct(
            minimumPackets,
            framesPerPacket,
            field: "minimumTargetFrames"
        )
        let targetFrames = try checkedFrameProduct(
            initialPackets,
            framesPerPacket,
            field: "targetFrames"
        )
        let maximumTargetFrames = try checkedFrameProduct(
            maximumPackets,
            framesPerPacket,
            field: "maximumTargetFrames"
        )
        let policy = RxBufferPolicy(
            profile: .adaptive,
            transport: .init(framesPerPacket: framesPerPacket, sampleRateHertz: sampleRateHertz),
            targets: .init(
                minimumFrames: minimumTargetFrames,
                targetFrames: targetFrames,
                maximumFrames: maximumTargetFrames
            ),
            eligibility: .init(
                fastestAudioPassEligible: false,
                adaptationChangesOutsideCallback: true,
                notes: "Adaptive RX: target changes outside the audio callback within configured bounds."
            )
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
        let targetFrames = try checkedFrameProduct(
            targetPackets,
            framesPerPacket,
            field: "targetFrames"
        )
        let maximumTargetFrames = try checkedFrameProduct(
            maximumPackets,
            framesPerPacket,
            field: "maximumTargetFrames"
        )
        let policy = RxBufferPolicy(
            profile: .stableWan,
            transport: .init(framesPerPacket: framesPerPacket, sampleRateHertz: sampleRateHertz),
            targets: .init(
                minimumFrames: targetFrames,
                targetFrames: targetFrames,
                maximumFrames: maximumTargetFrames
            ),
            eligibility: .init(
                fastestAudioPassEligible: false,
                adaptationChangesOutsideCallback: true,
                notes: "Stable/WAN RX: continuity-first target, never fastest direct audio."
            )
        )
        try policy.validate()
        return policy
    }

    public func validate() throws {
        try validateScalarFields()
        try validateTargetRange()
        try validatePacketAlignment()
        try validateProfileRules()
    }

    private func validateScalarFields() throws {
        try RxBufferPolicyValidator.requirePositive(framesPerPacket, "framesPerPacket")
        try RxBufferPolicyValidator.requirePositive(sampleRateHertz, "sampleRateHertz")
        try RxBufferPolicyValidator.requireNonNegative(minimumTargetFrames, "minimumTargetFrames")
        try RxBufferPolicyValidator.requireNonNegative(targetFrames, "targetFrames")
        try RxBufferPolicyValidator.requireNonNegative(maximumTargetFrames, "maximumTargetFrames")
        try RxBufferPolicyValidator.requireNonEmpty(notes, "notes")
    }

    private func validateTargetRange() throws {
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
    }

    private func validatePacketAlignment() throws {
        for target in [minimumTargetFrames, targetFrames, maximumTargetFrames]
            where target % framesPerPacket != 0 {
            throw RxBufferPolicyValidationError.targetNotPacketAligned(
                targetFrames: target,
                framesPerPacket: framesPerPacket
            )
        }
    }

    private func validateProfileRules() throws {
        switch profile {
        case .direct:
            try validateDirectProfile()
        case .small:
            try validateSmallProfile()
        case .adaptive:
            try validateAdaptiveProfile()
        case .stableWan:
            try validateStableWanProfile()
        }
    }

    private func validateDirectProfile() throws {
        guard targetPackets == 1 else {
            throw RxBufferPolicyValidationError.directTargetOutOfRange(
                targetPackets: targetPackets
            )
        }
    }

    private func validateSmallProfile() throws {
        guard targetPackets == 1 || targetPackets == 2 else {
            throw RxBufferPolicyValidationError.smallTargetOutOfRange(
                targetPackets: targetPackets
            )
        }
        try validateFastestAudioIneligibleProfile()
    }

    private func validateAdaptiveProfile() throws {
        guard adaptationChangesOutsideCallback else {
            throw RxBufferPolicyValidationError.adaptiveRequiresOutsideCallbackChanges
        }
        try validateFastestAudioIneligibleProfile()
    }

    private func validateStableWanProfile() throws {
        guard targetPackets >= 8 else {
            throw RxBufferPolicyValidationError.stableWanTargetTooSmall(
                targetPackets: targetPackets
            )
        }
        try validateFastestAudioIneligibleProfile()
    }

    private func validateFastestAudioIneligibleProfile() throws {
        guard !fastestAudioPassEligible else {
            throw RxBufferPolicyValidationError.fastestIneligibleProfile(profile)
        }
    }

    public static func microseconds(frames: Int, sampleRateHertz: Int) -> Double {
        guard sampleRateHertz > 0 else {
            return 0
        }
        return (Double(frames) / Double(sampleRateHertz)) * 1_000_000
    }

    private static func checkedFrameProduct(
        _ packetCount: Int,
        _ framesPerPacket: Int,
        field: String
    ) throws -> Int {
        let product = packetCount.multipliedReportingOverflow(by: framesPerPacket)
        guard !product.overflow else {
            throw RxBufferPolicyValidationError.arithmeticOverflow(field)
        }
        return product.partialValue
    }
}
