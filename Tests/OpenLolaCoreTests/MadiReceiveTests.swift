import Foundation
import Testing

@testable import OpenLolaCore

@Test
func madiReceiveDepacketizesRequiredChannelCountsToReadyBlocks() throws {
    for channelCount in madiSyntheticRequiredChannelCounts {
        let mode = try madiRxV2Mode(channelCount: channelCount)
        let payload = patternedPayload(mode: mode)
        let packets = try UdpPcmV2Packetizer.packetize(
            payload,
            sequenceNumber: 0,
            senderFrameIndex: 0,
            senderHostTimeNanoseconds: 1,
            mode: mode
        )
        var receiver = try MadiReceiveEngine(
            configuration: MadiReceiveConfiguration(mode: mode)
        )

        for packet in packets.reversed() {
            _ = try receiver.receive(packet, receivedAtHostTimeNanoseconds: 2)
        }

        #expect(receiver.renderCallback() == .silence(startFrame: 0, frameCount: 32))
        let rendered = receiver.renderCallback()

        guard case .played(let block) = rendered else {
            Issue.record("expected played block for \(channelCount) channels")
            continue
        }
        #expect(block.payload == payload)
        #expect(block.sequenceNumber == 0)
        #expect(block.inputChannelCount == channelCount)
        #expect(block.outputChannelCount == channelCount)
        #expect(block.latency.frames == 32)
        #expect(receiver.metrics.completedBlocks == 1)
        #expect(receiver.metrics.allocationWarnings == 0)
        #expect(receiver.metrics.lastPacketAgeMicroseconds == 0.001)
        #expect(receiver.metrics.maximumPacketAgeMicroseconds == 0.001)
        #expect(receiver.metrics.rxBuffer.maximumObservedBufferedPackets == 1)
    }
}

@Test
func madiReceiveMissingFragmentReportsLossAndSameDeadlineRecovery() throws {
    let mode = try madiRxV2Mode(channelCount: 64)
    let payload = patternedPayload(mode: mode)
    let packets = try UdpPcmV2Packetizer.packetize(
        payload,
        sequenceNumber: 0,
        senderFrameIndex: 0,
        senderHostTimeNanoseconds: 1,
        mode: mode
    )
    var receiver = try MadiReceiveEngine(
        configuration: MadiReceiveConfiguration(mode: mode)
    )

    for packet in packets.dropLast() {
        _ = try receiver.receive(packet, receivedAtHostTimeNanoseconds: 2)
    }

    #expect(receiver.renderCallback() == .silence(startFrame: 0, frameCount: 32))
    let recovery = receiver.renderCallback()

    guard case .sameDeadlineRecovery(let block) = recovery else {
        Issue.record("expected same-deadline recovery for missing fragment")
        return
    }
    #expect(block.sequenceNumber == 0)
    #expect(block.missingFragmentIndices == [7])
    #expect(receiver.metrics.fragmentLostPackets == 1)
    #expect(receiver.metrics.lostPackets == 1)
    #expect(receiver.metrics.sameDeadlineRecoveries == 1)
    #expect(receiver.metrics.rxBuffer.fragmentLostPackets == 1)
    #expect(receiver.metrics.rxBuffer.plcEvents == 1)
}

@Test
func madiReceiveDropsLatePacketUnderDirectPolicy() throws {
    let mode = try madiRxV2Mode(channelCount: 2)
    let payload = patternedPayload(mode: mode)
    let packets = try UdpPcmV2Packetizer.packetize(
        payload,
        sequenceNumber: 0,
        senderFrameIndex: 0,
        senderHostTimeNanoseconds: 1,
        mode: mode
    )
    var receiver = try MadiReceiveEngine(
        configuration: MadiReceiveConfiguration(mode: mode)
    )

    #expect(receiver.renderCallback() == .silence(startFrame: 0, frameCount: 32))
    _ = receiver.renderCallback()

    #expect(try receiver.receive(packets[0], receivedAtHostTimeNanoseconds: 2) == .droppedLate)
    #expect(receiver.metrics.latePackets == 1)
    #expect(receiver.metrics.droppedNetworkFragments == 1)
    #expect(receiver.metrics.rxBuffer.latePackets == 1)
    #expect(receiver.metrics.rxBuffer.lostPackets == 1)
}

@Test
func madiReceiveRejectsPlayoutFrameOverflow() throws {
    let mode = try madiRxV2Mode(channelCount: 8)
    let payload = patternedPayload(mode: mode)
    let packets = try UdpPcmV2Packetizer.packetize(
        payload,
        sequenceNumber: 1,
        senderFrameIndex: UInt64.max - 63,
        senderHostTimeNanoseconds: 1,
        mode: mode
    )
    let policy = RxBufferPolicy(
        profile: .direct,
        framesPerPacket: mode.framesPerPacket,
        sampleRateHertz: mode.sampleRateHertz,
        minimumTargetFrames: 0,
        targetFrames: 64,
        maximumTargetFrames: 128,
        fastestAudioPassEligible: false,
        adaptationChangesOutsideCallback: true,
        notes: "test overflow policy"
    )
    var receiver = try MadiReceiveEngine(
        configuration: MadiReceiveConfiguration(mode: mode, rxBufferPolicy: policy)
    )

    #expect(throws: MadiReceiveError.playoutFrameOverflow(
        senderFrameIndex: UInt64.max - 63,
        targetFrames: 64
    )) {
        try receiver.receive(packets[0])
    }
}

@Test
func madiReceiveSampleReadersRejectMissingBaseAddress() {
    let raw = UnsafeRawBufferPointer(start: nil, count: 0)
    let mutable = UnsafeMutableBufferPointer<UInt8>(start: nil, count: 0)

    #expect(throws: MadiReceiveError.audioBufferBaseAddressUnavailable("input.int16")) {
        _ = try readInt16(raw, offset: 0)
    }
    #expect(throws: MadiReceiveError.audioBufferBaseAddressUnavailable("output.int16")) {
        _ = try readInt16(mutable, offset: 0)
    }
    #expect(throws: MadiReceiveError.audioBufferBaseAddressUnavailable("input.float32")) {
        _ = try readFloat32(raw, offset: 0)
    }
    #expect(throws: MadiReceiveError.audioBufferBaseAddressUnavailable("output.float32")) {
        _ = try readFloat32(mutable, offset: 0)
    }
}

@Test
func madiReceiveDropsFarFuturePacketBeforeReadyRingCollision() throws {
    let mode = try madiRxV2Mode(channelCount: 2)
    let payload = patternedPayload(mode: mode)
    let nearPackets = try UdpPcmV2Packetizer.packetize(
        payload,
        sequenceNumber: 0,
        senderFrameIndex: 0,
        senderHostTimeNanoseconds: 1,
        mode: mode
    )
    let packets = try UdpPcmV2Packetizer.packetize(
        payload,
        sequenceNumber: 99,
        senderFrameIndex: 99 * UInt64(mode.framesPerPacket),
        senderHostTimeNanoseconds: 1,
        mode: mode
    )
    var receiver = try MadiReceiveEngine(
        configuration: MadiReceiveConfiguration(mode: mode, preallocatedBlockCount: 1)
    )

    #expect(try receiver.receive(nearPackets[0], receivedAtHostTimeNanoseconds: 2) == .queued)
    #expect(try receiver.receive(packets[0], receivedAtHostTimeNanoseconds: 2) == .droppedFull)
    #expect(receiver.metrics.futurePackets == 1)
    #expect(receiver.metrics.droppedNetworkFragments == 1)
    #expect(receiver.metrics.rxBuffer.futurePackets == 1)
    #expect(receiver.metrics.overruns == 0)
}

@Test
func madiReceiveRejectsMetadataRevisionAndChecksPackingModeInPlanMatch() throws {
    let mode = try madiRxV2Mode(channelCount: 2)
    let payload = patternedPayload(mode: mode)
    let packets = try UdpPcmV2Packetizer.packetize(
        payload,
        sequenceNumber: 0,
        senderFrameIndex: 0,
        senderHostTimeNanoseconds: 1,
        mode: mode
    )
    let packet = try #require(packets.first)

    var metadataMismatch = packet
    metadataMismatch.header.metadataRevision = 999
    var receiver = try MadiReceiveEngine(configuration: MadiReceiveConfiguration(mode: mode))
    #expect(throws: MadiReceiveError.transportModeMismatch("metadataRevision")) {
        _ = try receiver.receive(metadataMismatch, receivedAtHostTimeNanoseconds: 2)
    }

    let source = try readOpenLolaCoreSource("Sources/OpenLolaCore/Audio/MADI/MadiReceive.swift")
    #expect(source.contains("transportModeMismatch(\"packingMode\")"))
    #expect(source.contains("fragment.packingMode == packet.header.packingMode"))
}

@Test
func madiReceiveSmallBufferExposesFixedLatencyCost() throws {
    let mode = try madiRxV2Mode(channelCount: 8, rxBufferProfile: .small)
    let policy = try RxBufferPolicy.small(
        framesPerPacket: mode.framesPerPacket,
        sampleRateHertz: mode.sampleRateHertz,
        targetPackets: 2
    )
    let payload = patternedPayload(mode: mode)
    let packets = try UdpPcmV2Packetizer.packetize(
        payload,
        sequenceNumber: 0,
        senderFrameIndex: 0,
        senderHostTimeNanoseconds: 1,
        mode: mode
    )
    var receiver = try MadiReceiveEngine(
        configuration: MadiReceiveConfiguration(
            mode: mode,
            rxBufferPolicy: policy
        )
    )

    for packet in packets {
        _ = try receiver.receive(packet, receivedAtHostTimeNanoseconds: 2)
    }

    #expect(receiver.renderCallback() == .silence(startFrame: 0, frameCount: 32))
    #expect(receiver.renderCallback() == .silence(startFrame: 32, frameCount: 32))
    guard case .played(let block) = receiver.renderCallback() else {
        Issue.record("expected played block after two-packet RX target")
        return
    }

    #expect(block.payload == payload)
    #expect(block.latency.frames == 64)
    #expect(block.latency.packets == 2)
    #expect(block.latency.microseconds == 1_333.3333333333333)
    #expect(receiver.metrics.rxBuffer.currentTargetFrames == 64)
    #expect(receiver.metrics.rxBuffer.latencyCostMicroseconds == 1_333.3333333333333)
}

@Test
func madiReceiveAdaptiveBufferChangesTargetOutsideRenderCallbackAfterLatePressure() throws {
    let mode = try madiRxV2Mode(channelCount: 2, rxBufferProfile: .adaptive)
    let policy = try RxBufferPolicy.adaptive(
        framesPerPacket: mode.framesPerPacket,
        sampleRateHertz: mode.sampleRateHertz,
        minimumPackets: 1,
        initialPackets: 1,
        maximumPackets: 2
    )
    let payload = patternedPayload(mode: mode)
    let firstPackets = try UdpPcmV2Packetizer.packetize(
        payload,
        sequenceNumber: 0,
        senderFrameIndex: 0,
        senderHostTimeNanoseconds: 1,
        mode: mode
    )
    let secondPackets = try UdpPcmV2Packetizer.packetize(
        payload,
        sequenceNumber: 1,
        senderFrameIndex: UInt64(mode.framesPerPacket),
        senderHostTimeNanoseconds: 1,
        mode: mode
    )
    var receiver = try MadiReceiveEngine(
        configuration: MadiReceiveConfiguration(mode: mode, rxBufferPolicy: policy)
    )

    _ = receiver.renderCallback()
    _ = receiver.renderCallback()
    _ = receiver.renderCallback()

    #expect(try receiver.receive(firstPackets[0], receivedAtHostTimeNanoseconds: 2) == .droppedLate)
    #expect(try receiver.receive(secondPackets[0], receivedAtHostTimeNanoseconds: 2) == .droppedLate)

    #expect(receiver.metrics.rxBuffer.currentTargetFrames == 64)
    #expect(receiver.metrics.rxBuffer.maximumObservedTargetFrames == 64)
    #expect(receiver.metrics.rxBuffer.targetChangeEvents.count == 1)
    #expect(receiver.metrics.rxBuffer.targetChangeEvents.allSatisfy { !$0.changedInsideAudioCallback })
}

@Test
func madiReceiveAppliesImmutableReceiverMixBeforeCallback() throws {
    let mode = try madiRxV2Mode(
        channelCount: 4,
        framesPerPacket: 2,
        sampleFormat: .int16LittleEndian
    )
    let inputPayload = int16InterleavedRxPayload(frameCount: 2, channelCount: 4)
    let expectedOutput = int16InterleavedRxPayload(
        frameCount: 2,
        sourceChannelCount: 4,
        selectedChannels: [3, 0]
    )
    let packets = try UdpPcmV2Packetizer.packetize(
        inputPayload,
        sequenceNumber: 0,
        senderFrameIndex: 0,
        senderHostTimeNanoseconds: 1,
        mode: mode
    )
    let mix = ReceiverMixSnapshot(
        routes: [
            ReceiverMixRoute(
                sourceChannelIndex: 3,
                destinationChannelIndex: 0,
                gainDb: 0,
                muted: false,
                pan: 0
            ),
            ReceiverMixRoute(
                sourceChannelIndex: 0,
                destinationChannelIndex: 1,
                gainDb: 0,
                muted: false,
                pan: 0
            ),
        ],
        requiresDestructiveDownmix: false
    )
    var receiver = try MadiReceiveEngine(
        configuration: MadiReceiveConfiguration(
            mode: mode,
            receiverMix: mix,
            outputChannelCount: 2
        )
    )

    for packet in packets {
        _ = try receiver.receive(packet, receivedAtHostTimeNanoseconds: 2)
    }

    #expect(receiver.renderCallback() == .silence(startFrame: 0, frameCount: 2))
    guard case .played(let block) = receiver.renderCallback() else {
        Issue.record("expected mixed played block")
        return
    }

    #expect(block.payload == expectedOutput)
    #expect(block.inputChannelCount == 4)
    #expect(block.outputChannelCount == 2)
    #expect(block.mixRevision == 1)
}

@Test
func madiReceiveAppliesStereoPanReceiverMixBeforeCallback() throws {
    let mode = try madiRxV2Mode(
        channelCount: 1,
        framesPerPacket: 2,
        sampleFormat: .int16LittleEndian
    )
    let inputPayload = int16RxPayload([10, 20])
    let expectedOutput = int16RxPayload([0, 10, 0, 20])
    let packets = try UdpPcmV2Packetizer.packetize(
        inputPayload,
        sequenceNumber: 0,
        senderFrameIndex: 0,
        senderHostTimeNanoseconds: 1,
        mode: mode
    )
    let mix = ReceiverMixSnapshot(
        routes: [
            ReceiverMixRoute(
                sourceChannelIndex: 0,
                destinationChannelIndex: 0,
                gainDb: 0,
                muted: false,
                pan: 1
            ),
        ],
        requiresDestructiveDownmix: false
    )
    var receiver = try MadiReceiveEngine(
        configuration: MadiReceiveConfiguration(
            mode: mode,
            receiverMix: mix,
            outputChannelCount: 2
        )
    )

    for packet in packets {
        _ = try receiver.receive(packet, receivedAtHostTimeNanoseconds: 2)
    }

    #expect(receiver.renderCallback() == .silence(startFrame: 0, frameCount: 2))
    guard case .played(let block) = receiver.renderCallback() else {
        Issue.record("expected panned played block")
        return
    }

    #expect(block.payload == expectedOutput)
    #expect(block.outputChannelCount == 2)
}

@Test
func madiReceiveRejectsSampleRateMismatchBeforePlayout() throws {
    let mode = try madiRxV2Mode(channelCount: 2)
    var packet = try UdpPcmV2Packetizer.packetize(
        patternedPayload(mode: mode),
        sequenceNumber: 0,
        senderFrameIndex: 0,
        senderHostTimeNanoseconds: 1,
        mode: mode
    )[0]
    packet.header.sampleRateHertz = 96_000
    var receiver = try MadiReceiveEngine(
        configuration: MadiReceiveConfiguration(mode: mode)
    )

    #expect(throws: MadiReceiveError.transportModeMismatch("sampleRateHertz")) {
        _ = try receiver.receive(packet, receivedAtHostTimeNanoseconds: 2)
    }
    #expect(receiver.metrics.completedBlocks == 0)
}

@Test
func madiReceiveUsesBoundedPreallocatedReadyBlockPool() throws {
    let mode = try madiRxV2Mode(channelCount: 2)
    var receiver = try MadiReceiveEngine(
        configuration: MadiReceiveConfiguration(
            mode: mode,
            preallocatedBlockCount: 1
        )
    )

    let first = try UdpPcmV2Packetizer.packetize(
        patternedPayload(mode: mode, seed: 0),
        sequenceNumber: 0,
        senderFrameIndex: 0,
        senderHostTimeNanoseconds: 1,
        mode: mode
    )
    let second = try UdpPcmV2Packetizer.packetize(
        patternedPayload(mode: mode, seed: 32),
        sequenceNumber: 1,
        senderFrameIndex: 32,
        senderHostTimeNanoseconds: 2,
        mode: mode
    )

    #expect(try receiver.receive(first[0], receivedAtHostTimeNanoseconds: 3) == .queued)
    #expect(try receiver.receive(second[0], receivedAtHostTimeNanoseconds: 4) == .droppedFull)
    #expect(receiver.metrics.preallocatedBlockPoolCapacity == 1)
    #expect(receiver.metrics.overruns == 1)
    #expect(receiver.metrics.rxBuffer.overruns == 1)
    #expect(receiver.metrics.allocationWarnings == 0)
}

@Test
func madiReceiveRejectsUnboundedIncompleteFutureDeadlines() throws {
    let mode = try madiRxV2Mode(channelCount: 64)
    let payload = patternedPayload(mode: mode)
    var receiver = try MadiReceiveEngine(
        configuration: MadiReceiveConfiguration(
            mode: mode,
            preallocatedBlockCount: 1
        )
    )

    for sequence in 0..<MadiReceiveEngine.maxPendingDeadlines {
        let packets = try UdpPcmV2Packetizer.packetize(
            payload,
            sequenceNumber: UInt64(sequence),
            senderFrameIndex: UInt64(sequence * mode.framesPerPacket),
            senderHostTimeNanoseconds: UInt64(sequence + 1),
            mode: mode
        )
        #expect(try receiver.receive(packets[0], receivedAtHostTimeNanoseconds: 2) == .waitingForFragments(
            receivedFragmentCount: 1,
            expectedFragmentCount: mode.fragments.count
        ))
    }

    let overflowPackets = try UdpPcmV2Packetizer.packetize(
        payload,
        sequenceNumber: UInt64(MadiReceiveEngine.maxPendingDeadlines),
        senderFrameIndex: UInt64(MadiReceiveEngine.maxPendingDeadlines * mode.framesPerPacket),
        senderHostTimeNanoseconds: UInt64(MadiReceiveEngine.maxPendingDeadlines + 1),
        mode: mode
    )
    #expect(throws: MadiReceiveError.pendingDeadlineLimitExceeded(MadiReceiveEngine.maxPendingDeadlines)) {
        _ = try receiver.receive(overflowPackets[0], receivedAtHostTimeNanoseconds: 2)
    }
    #expect(receiver.metrics.allocationWarnings == 1)
}

@Test
func madiReceiveAllowsPendingDeadlinesWithCollidingModuloSequenceNumbers() throws {
    let mode = try madiRxV2Mode(channelCount: 64)
    let payload = patternedPayload(mode: mode)
    var receiver = try MadiReceiveEngine(configuration: MadiReceiveConfiguration(mode: mode))
    let firstPackets = try UdpPcmV2Packetizer.packetize(
        payload,
        sequenceNumber: 0,
        senderFrameIndex: 0,
        senderHostTimeNanoseconds: 1,
        mode: mode
    )
    let collidingPackets = try UdpPcmV2Packetizer.packetize(
        payload,
        sequenceNumber: UInt64(MadiReceiveEngine.maxPendingDeadlines),
        senderFrameIndex: UInt64(MadiReceiveEngine.maxPendingDeadlines * mode.framesPerPacket),
        senderHostTimeNanoseconds: 2,
        mode: mode
    )

    #expect(try receiver.receive(firstPackets[0], receivedAtHostTimeNanoseconds: 3) == .waitingForFragments(
        receivedFragmentCount: 1,
        expectedFragmentCount: mode.fragments.count
    ))
    #expect(try receiver.receive(collidingPackets[0], receivedAtHostTimeNanoseconds: 4) == .waitingForFragments(
        receivedFragmentCount: 1,
        expectedFragmentCount: mode.fragments.count
    ))
    #expect(receiver.metrics.allocationWarnings == 0)
}

@Test
func madiReceiveReusesPendingDeadlineSlotAfterCompletion() throws {
    let mode = try madiRxV2Mode(channelCount: 64)
    let firstPayload = patternedPayload(mode: mode)
    let secondPayload = patternedPayload(mode: mode, seed: 17)
    let firstPackets = try UdpPcmV2Packetizer.packetize(
        firstPayload,
        sequenceNumber: 0,
        senderFrameIndex: 0,
        senderHostTimeNanoseconds: 1,
        mode: mode
    )
    let secondPackets = try UdpPcmV2Packetizer.packetize(
        secondPayload,
        sequenceNumber: UInt64(MadiReceiveEngine.maxPendingDeadlines),
        senderFrameIndex: UInt64(mode.framesPerPacket),
        senderHostTimeNanoseconds: UInt64(MadiReceiveEngine.maxPendingDeadlines + 1),
        mode: mode
    )
    var receiver = try MadiReceiveEngine(configuration: MadiReceiveConfiguration(mode: mode))

    for packet in firstPackets {
        _ = try receiver.receive(packet, receivedAtHostTimeNanoseconds: 2)
    }
    #expect(receiver.renderCallback() == .silence(startFrame: 0, frameCount: mode.framesPerPacket))
    guard case .played = receiver.renderCallback() else {
        Issue.record("expected first completed block to free the ready slot")
        return
    }
    for packet in secondPackets {
        _ = try receiver.receive(packet, receivedAtHostTimeNanoseconds: 3)
    }

    #expect(receiver.metrics.completedBlocks == 2)
    #expect(receiver.metrics.allocationWarnings == 0)
}

@Test
func madiReceiveReadyBlockRingReturnsDroppedOldestBlock() throws {
    var ring = MadiReceiveReadyBlockRing(capacity: 1, framesPerBlock: 32)
    let first = madiReceivePlayoutBlock(sequenceNumber: 11, startFrame: 32)
    let second = madiReceivePlayoutBlock(sequenceNumber: 12, startFrame: 64)

    #expect(ring.store(first, nextDueFrame: 0, overrunPolicy: .dropOldest) == .stored)
    let result = ring.store(second, nextDueFrame: 0, overrunPolicy: .dropOldest)

    guard case .droppedOldest(let droppedBlock) = result else {
        Issue.record("expected dropped oldest block result")
        return
    }
    #expect(droppedBlock.sequenceNumber == 11)
    #expect(ring.remove(playoutFrame: 64)?.sequenceNumber == 12)
}

@Test
func madiReceiveReadyBlockRingRejectsFarFutureFirstBlock() throws {
    var ring = MadiReceiveReadyBlockRing(capacity: 2, framesPerBlock: 32)
    let future = madiReceivePlayoutBlock(sequenceNumber: 99, startFrame: 4_096)

    #expect(ring.store(future, nextDueFrame: 0, overrunPolicy: .dropNewest) == .droppedFuture)
    #expect(ring.count == 0)
}

@Test
func madiReceiveReadyBlockRingPreconditionsStorageIndexInputs() throws {
    let source = try readOpenLolaCoreSource("Sources/OpenLolaCore/Audio/MADI/MadiReceiveBuffers.swift")

    #expect(source.contains("precondition(capacity > 0"))
    #expect(source.contains("precondition(framesPerBlock > 0"))
    #expect(source.contains("playoutFrame / UInt64(framesPerBlock)"))
    #expect(source.contains("% UInt64(storage.count)"))
}

private func madiRxV2Mode(
    channelCount: Int,
    framesPerPacket: Int = 32,
    sampleFormat: UdpPcmSampleFormat = .float32LittleEndian,
    rxBufferProfile: RxBufferProfile = .direct
) throws -> AudioTransportMode {
    let fragments = try UdpPcmV2FragmentPlanner.plan(
        UdpPcmV2FragmentPlanRequest(
            streamID: 1,
            totalChannelCount: channelCount,
            framesPerPacket: framesPerPacket,
            sampleRateHertz: 48_000,
            sampleFormat: sampleFormat,
            maxTransmissionUnitBytes: 1_200,
            maxFragmentsPerDeadline: 16,
            metadataRevision: 3,
            packingMode: .interleavedChannelRange
        )
    )
    return AudioTransportMode(
        protocolVersion: .udpPcmV2,
        sampleRateHertz: 48_000,
        framesPerPacket: framesPerPacket,
        channelCount: channelCount,
        sampleFormat: sampleFormat,
        latencyProfile: .safeLowLatency,
        rxBufferProfile: rxBufferProfile,
        maxTransmissionUnitBytes: 1_200,
        channelOrder: AudioChannelSet.defaultInput(count: channelCount).sortedByStableSourceIndex,
        fragments: fragments
    )
}

private func patternedPayload(mode: AudioTransportMode, seed: Int = 0) -> Data {
    Data((0..<mode.framesPerPacket * mode.channelCount * mode.sampleFormat.bytesPerSample)
        .map { UInt8(($0 + seed) % 251) })
}

private func int16InterleavedRxPayload(frameCount: Int, channelCount: Int) -> Data {
    var data = Data()
    for frame in 0..<frameCount {
        for channel in 0..<channelCount {
            appendRxInt16Sample(Int16(frame * 100 + channel), to: &data)
        }
    }
    return data
}

private func int16InterleavedRxPayload(
    frameCount: Int,
    sourceChannelCount: Int,
    selectedChannels: [Int]
) -> Data {
    var data = Data()
    for frame in 0..<frameCount {
        for channel in selectedChannels {
            appendRxInt16Sample(Int16(frame * 100 + channel), to: &data)
        }
    }
    _ = sourceChannelCount
    return data
}

private func int16RxPayload(_ values: [Int16]) -> Data {
    var data = Data()
    for value in values {
        appendRxInt16Sample(value, to: &data)
    }
    return data
}

private func appendRxInt16Sample(_ value: Int16, to data: inout Data) {
    let littleEndian = value.littleEndian
    withUnsafeBytes(of: littleEndian) { bytes in
        data.append(contentsOf: bytes)
    }
}

private func madiReceivePlayoutBlock(sequenceNumber: UInt64, startFrame: UInt64) -> MadiReceivePlayoutBlock {
    MadiReceivePlayoutBlock(
        streamID: 1,
        sequenceNumber: sequenceNumber,
        startFrame: startFrame,
        senderFrameIndex: startFrame,
        frameCount: 32,
        inputChannelCount: 2,
        outputChannelCount: 2,
        sampleFormat: .float32LittleEndian,
        payload: Data([UInt8(sequenceNumber & 0xff)]),
        mixRevision: 0,
        latency: MadiReceiveBufferLatency(frames: 32, packets: 1, microseconds: 666.67)
    )
}

private func readOpenLolaCoreSource(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
