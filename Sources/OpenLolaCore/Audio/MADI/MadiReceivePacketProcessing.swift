// Applies received MADI packets to pending deadlines and selects playout or recovery blocks so sequence handling stays inside the receive engine.
import Foundation

extension MadiReceiveEngine {
    mutating func packetReception(
        _ packet: UdpPcmV2Packet,
        receivedAtHostTimeNanoseconds: UInt64
    ) throws -> MadiReceivePacketReception {
        let playoutFrame = try Self.targetPlayoutFrame(
            senderFrameIndex: packet.header.senderFrameIndex,
            targetFrames: currentTargetFrames
        )
        let packetAge = recordPacketAge(
            senderHostTimeNanoseconds: packet.header.senderHostTimeNanoseconds,
            receivedAtHostTimeNanoseconds: receivedAtHostTimeNanoseconds
        )
        guard playoutFrame >= nextDueFrame else {
            recordLateDrop()
            observeAdaptiveRxBuffer(
                sequenceNumber: packet.header.sequenceNumber,
                packetAgeMicroseconds: packetAge,
                pressure: true
            )
            return .finished(.droppedLate)
        }
        return .proceed(
            MadiReceivePacketTiming(playoutFrame: playoutFrame, packetAgeMicroseconds: packetAge)
        )
    }

    mutating func recordPacketOrdering(_ packet: UdpPcmV2Packet) {
        if let highest = highestReceivedSequenceNumber,
           packet.header.sequenceNumber < highest {
            metrics.reorderedPackets += 1
            metrics.rxBuffer.reorderedPackets += 1
        }
        highestReceivedSequenceNumber = max(
            highestReceivedSequenceNumber ?? packet.header.sequenceNumber,
            packet.header.sequenceNumber
        )
    }

    mutating func pendingPacketState(
        for packet: UdpPcmV2Packet
    ) throws -> MadiReceivePendingPacketState {
        let key = MadiReceiveDeadlineKey(
            streamID: packet.header.streamID,
            sequenceNumber: packet.header.sequenceNumber
        )
        var pending = pendingDeadlines.pending(for: key)
            ?? MadiReceivePendingDeadline(reference: packet.header)
        let insertResult: MadiReceivePendingInsertResult
        do {
            insertResult = try pending.insert(packet)
        } catch let error as UdpPcmV2FragmentReassemblyError {
            throw MadiReceiveError.reassembly(error)
        }
        switch insertResult {
        case .duplicate:
            recordDuplicate()
            return .waiting(.droppedDuplicate)
        case .stored:
            break
        }
        guard pending.isComplete else {
            return try storePendingPacket(pending, for: key)
        }
        _ = pendingDeadlines.remove(for: key)
        do {
            return .complete(
                MadiReceiveCompletedPendingPacket(
                    reassembled: try pending.reassemble(),
                    receivedFragmentCount: pending.receivedFragmentCount,
                    expectedFragmentCount: pending.expectedFragmentCount
                )
            )
        } catch let error as UdpPcmV2FragmentReassemblyError {
            throw MadiReceiveError.reassembly(error)
        }
    }

    mutating func storePendingPacket(
        _ pending: MadiReceivePendingDeadline,
        for key: MadiReceiveDeadlineKey
    ) throws -> MadiReceivePendingPacketState {
        guard pendingDeadlines.store(pending, for: key) else {
            metrics.allocationWarnings += 1
            throw MadiReceiveError.pendingDeadlineLimitExceeded(Self.maxPendingDeadlines)
        }
        return .waiting(
            .waitingForFragments(
                receivedFragmentCount: pending.receivedFragmentCount,
                expectedFragmentCount: pending.expectedFragmentCount
            )
        )
    }

    func playoutBlock(
        packet: UdpPcmV2Packet,
        playoutFrame: UInt64,
        mixedPayload: Data
    ) -> MadiReceivePlayoutBlock {
        MadiReceivePlayoutBlock(
            streamID: packet.header.streamID,
            sequenceNumber: packet.header.sequenceNumber,
            startFrame: playoutFrame,
            senderFrameIndex: packet.header.senderFrameIndex,
            frameCount: Int(packet.header.framesPerPacket),
            inputChannelCount: Int(packet.header.totalChannelCount),
            outputChannelCount: outputChannelCount,
            sampleFormat: packet.header.sampleFormat,
            payload: mixedPayload,
            mixRevision: mixStore.revision,
            latency: currentLatency()
        )
    }

    mutating func storeReadyBlock(
        _ block: MadiReceivePlayoutBlock,
        sequenceNumber: UInt64,
        packetAgeMicroseconds: Double?
    ) -> MadiReceivePacketResult? {
        switch readyBlocks.store(block, nextDueFrame: nextDueFrame, overrunPolicy: overrunPolicy) {
        case .stored:
            return nil
        case .droppedNewest:
            recordOverrun()
            observeAdaptiveRxBuffer(
                sequenceNumber: sequenceNumber,
                packetAgeMicroseconds: packetAgeMicroseconds,
                pressure: true
            )
            return .droppedFull
        case .droppedOldest(let droppedBlock):
            _ = droppedBlock.sequenceNumber
            recordOverrun()
            return nil
        case .droppedFuture:
            recordFutureDrop()
            observeAdaptiveRxBuffer(
                sequenceNumber: sequenceNumber,
                packetAgeMicroseconds: packetAgeMicroseconds,
                pressure: true
            )
            return .droppedFull
        }
    }

    mutating func completeQueuedPacket(
        _ packet: UdpPcmV2Packet,
        timing: MadiReceivePacketTiming
    ) -> MadiReceivePacketResult {
        metrics.completedBlocks += 1
        updateMaximumBufferedBlocks()
        observeAdaptiveRxBuffer(
            sequenceNumber: packet.header.sequenceNumber,
            packetAgeMicroseconds: timing.packetAgeMicroseconds,
            pressure: false
        )
        return .queued
    }

    mutating func missingPayloadResult(
        _ completed: MadiReceiveCompletedPendingPacket
    ) -> MadiReceivePacketResult {
        recordFragmentLoss()
        return .waitingForFragments(
            receivedFragmentCount: completed.receivedFragmentCount,
            expectedFragmentCount: completed.expectedFragmentCount
        )
    }

    public mutating func renderCallback() -> MadiReceiveRenderResult {
        let dueFrame = nextDueFrame
        nextDueFrame &+= UInt64(mode.framesPerPacket)

        guard dueFrame >= UInt64(currentTargetFrames) else {
            return .silence(startFrame: dueFrame, frameCount: mode.framesPerPacket)
        }
        warmupComplete = true

        if let block = readyBlocks.remove(playoutFrame: dueFrame) {
            metrics.renderedBlocks += 1
            updateMaximumBufferedBlocks()
            return .played(block)
        }

        if let pending = removePendingDeadline(playoutFrame: dueFrame) {
            pending.appendMissingFragmentIndices(to: &missingFragmentScratch)
            let missing = missingFragmentScratch
            recordFragmentLoss()
            return .sameDeadlineRecovery(
                recoveryBlock(
                    sequenceNumber: pending.reference.sequenceNumber,
                    startFrame: dueFrame,
                    missingFragmentIndices: missing
                )
            )
        }

        recordUnderrun()
        recordSameDeadlineRecovery()
        return .sameDeadlineRecovery(
            recoveryBlock(
                sequenceNumber: missingSequenceNumber(dueFrame: dueFrame),
                startFrame: dueFrame,
                missingFragmentIndices: allMissingFragmentIndices
            )
        )
    }

}
