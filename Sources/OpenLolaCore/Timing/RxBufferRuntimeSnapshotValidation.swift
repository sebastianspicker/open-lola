// Validates RxBufferRuntimeSnapshotValidation acceptance rules, keeping failure policy close to its contract rather than the runtime path.
import Foundation

extension RxBufferTargetChangeEvent {
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

extension RxBufferRuntimeSnapshot {
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
