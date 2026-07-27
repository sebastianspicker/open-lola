// Handles MADI receiver runtime bookkeeping around deadlines, mixing, and output callback work.
import Foundation

extension MadiReceiveEngine {
    func currentLatency() -> MadiReceiveBufferLatency {
        let packets = currentTargetFrames / mode.framesPerPacket
        return MadiReceiveBufferLatency(
            frames: currentTargetFrames,
            packets: packets,
            microseconds: RxBufferPolicy.microseconds(
                frames: currentTargetFrames,
                sampleRateHertz: rxBufferPolicy.sampleRateHertz
            )
        )
    }

    mutating func removePendingDeadline(
        playoutFrame: UInt64
    ) -> MadiReceivePendingDeadline? {
        let targetFrames = currentTargetFrames
        return pendingDeadlines.remove { pending in
            guard let pendingPlayoutFrame = try? Self.targetPlayoutFrame(
                senderFrameIndex: pending.reference.senderFrameIndex,
                targetFrames: targetFrames
            ) else {
                return false
            }
            return pendingPlayoutFrame == playoutFrame
        }
    }

    static func targetPlayoutFrame(senderFrameIndex: UInt64, targetFrames: Int) throws -> UInt64 {
        let target = UInt64(targetFrames)
        let result = senderFrameIndex.addingReportingOverflow(target)
        guard !result.overflow else {
            throw MadiReceiveError.playoutFrameOverflow(
                senderFrameIndex: senderFrameIndex,
                targetFrames: targetFrames
            )
        }
        return result.partialValue
    }

    func recoveryBlock(
        sequenceNumber: UInt64,
        startFrame: UInt64,
        missingFragmentIndices: [UInt16]
    ) -> MadiReceiveRecoveryBlock {
        MadiReceiveRecoveryBlock(
            sequenceNumber: sequenceNumber,
            startFrame: startFrame,
            frameCount: mode.framesPerPacket,
            missingFragmentIndices: missingFragmentIndices,
            payloadByteCount: mode.framesPerPacket
                * outputChannelCount
                * mode.sampleFormat.bytesPerSample
        )
    }

    func missingSequenceNumber(dueFrame: UInt64) -> UInt64 {
        guard dueFrame >= UInt64(currentTargetFrames) else {
            return 0
        }
        return (dueFrame - UInt64(currentTargetFrames)) / UInt64(mode.framesPerPacket)
    }

    mutating func recordLateDrop() {
        metrics.latePackets += 1
        metrics.droppedNetworkFragments += 1
        metrics.lostPackets += 1
        metrics.rxBuffer.latePackets += 1
        metrics.rxBuffer.lostPackets += 1
    }

    mutating func recordDuplicate() {
        metrics.duplicatePackets += 1
        metrics.droppedNetworkFragments += 1
        metrics.rxBuffer.duplicatePackets += 1
    }

    mutating func recordFragmentLoss() {
        metrics.lostPackets += 1
        metrics.fragmentLostPackets += 1
        metrics.sameDeadlineRecoveries += 1
        metrics.rxBuffer.lostPackets += 1
        metrics.rxBuffer.fragmentLostPackets += 1
        metrics.rxBuffer.plcEvents += 1
    }

    mutating func recordUnderrun() {
        guard warmupComplete else {
            return
        }
        metrics.underruns += 1
        metrics.rxBuffer.underruns += 1
    }

    mutating func recordOverrun() {
        metrics.overruns += 1
        metrics.droppedNetworkFragments += 1
        metrics.rxBuffer.overruns += 1
    }

    mutating func recordFutureDrop() {
        metrics.futurePackets += 1
        metrics.droppedNetworkFragments += 1
        metrics.rxBuffer.futurePackets += 1
    }

    mutating func recordSameDeadlineRecovery() {
        metrics.sameDeadlineRecoveries += 1
        metrics.rxBuffer.plcEvents += 1
    }

    mutating func updateMaximumBufferedBlocks() {
        metrics.maximumBufferedBlocks = max(metrics.maximumBufferedBlocks, readyBlocks.count)
        metrics.rxBuffer.recordBufferedPacketCount(readyBlocks.count)
    }

    mutating func recordPacketAge(
        senderHostTimeNanoseconds: UInt64,
        receivedAtHostTimeNanoseconds: UInt64
    ) -> Double? {
        guard receivedAtHostTimeNanoseconds >= senderHostTimeNanoseconds else {
            return nil
        }
        let age = Double(receivedAtHostTimeNanoseconds - senderHostTimeNanoseconds) / 1_000
        metrics.lastPacketAgeMicroseconds = age
        metrics.maximumPacketAgeMicroseconds = max(metrics.maximumPacketAgeMicroseconds ?? age, age)
        return age
    }

    mutating func observeAdaptiveRxBuffer(
        sequenceNumber: UInt64,
        packetAgeMicroseconds: Double?,
        pressure: Bool
    ) {
        guard var controller = adaptiveRxBufferController else {
            return
        }
        let previousEventCount = controller.targetChangeEvents.count
        let decision = controller.observe(
            RxBufferAdaptationSample(
                sequenceNumber: sequenceNumber,
                jitterP99Microseconds: packetAgeMicroseconds ?? 0,
                latePackets: pressure ? 1 : 0
            )
        )
        adaptiveRxBufferController = controller
        guard decision.changed else {
            return
        }
        currentTargetFrames = decision.targetFrames
        metrics.rxBuffer.recordTargetFrames(decision.targetFrames)
        for event in controller.targetChangeEvents.dropFirst(previousEventCount) {
            metrics.rxBuffer.targetChangeEvents.append(event)
        }
    }
}
