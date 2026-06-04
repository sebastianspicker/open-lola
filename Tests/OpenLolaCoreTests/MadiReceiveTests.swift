import Foundation
import Testing

@testable import OpenLolaCore


@Test
func madiReceiveDepacketizesRequiredChannelsAndRecoversMissingFragments() throws {
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

    let recoveryMode = try madiRxV2Mode(channelCount: 64)
    let recoveryPayload = patternedPayload(mode: recoveryMode)
    let recoveryPackets = try UdpPcmV2Packetizer.packetize(
        recoveryPayload,
        sequenceNumber: 0,
        senderFrameIndex: 0,
        senderHostTimeNanoseconds: 1,
        mode: recoveryMode
    )
    var recoveryReceiver = try MadiReceiveEngine(
        configuration: MadiReceiveConfiguration(mode: recoveryMode)
    )

    for packet in recoveryPackets.dropLast() {
        _ = try recoveryReceiver.receive(packet, receivedAtHostTimeNanoseconds: 2)
    }

    #expect(recoveryReceiver.renderCallback() == .silence(startFrame: 0, frameCount: 32))
    let recovery = recoveryReceiver.renderCallback()

    guard case .sameDeadlineRecovery(let block) = recovery else {
        Issue.record("expected same-deadline recovery for missing fragment")
        return
    }
    #expect(block.sequenceNumber == 0)
    #expect(block.missingFragmentIndices == [7])
    #expect(recoveryReceiver.metrics.fragmentLostPackets == 1)
    #expect(recoveryReceiver.metrics.lostPackets == 1)
    #expect(recoveryReceiver.metrics.sameDeadlineRecoveries == 1)
    #expect(recoveryReceiver.metrics.rxBuffer.fragmentLostPackets == 1)
    #expect(recoveryReceiver.metrics.rxBuffer.plcEvents == 1)
}

@Test
func madiReceiveRejectsLateOverflowingAndFarFuturePackets() throws {
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

    let overflowMode = try madiRxV2Mode(channelCount: 8)
    let overflowPayload = patternedPayload(mode: overflowMode)
    let overflowPackets = try UdpPcmV2Packetizer.packetize(
        overflowPayload,
        sequenceNumber: 1,
        senderFrameIndex: UInt64.max - 63,
        senderHostTimeNanoseconds: 1,
        mode: overflowMode
    )
    let policy = RxBufferPolicy(
        profile: .direct,
        framesPerPacket: overflowMode.framesPerPacket,
        sampleRateHertz: overflowMode.sampleRateHertz,
        minimumTargetFrames: 0,
        targetFrames: 64,
        maximumTargetFrames: 128,
        fastestAudioPassEligible: false,
        adaptationChangesOutsideCallback: true,
        notes: "test overflow policy"
    )
    var overflowReceiver = try MadiReceiveEngine(
        configuration: MadiReceiveConfiguration(mode: overflowMode, rxBufferPolicy: policy)
    )

    #expect(throws: MadiReceiveError.playoutFrameOverflow(
        senderFrameIndex: UInt64.max - 63,
        targetFrames: 64
    )) {
        try overflowReceiver.receive(overflowPackets[0])
    }

    let futureMode = try madiRxV2Mode(channelCount: 2)
    let futurePayload = patternedPayload(mode: futureMode)
    let nearPackets = try UdpPcmV2Packetizer.packetize(
        futurePayload,
        sequenceNumber: 0,
        senderFrameIndex: 0,
        senderHostTimeNanoseconds: 1,
        mode: futureMode
    )
    let farFuturePackets = try UdpPcmV2Packetizer.packetize(
        futurePayload,
        sequenceNumber: 99,
        senderFrameIndex: 99 * UInt64(futureMode.framesPerPacket),
        senderHostTimeNanoseconds: 1,
        mode: futureMode
    )
    var futureReceiver = try MadiReceiveEngine(
        configuration: MadiReceiveConfiguration(mode: futureMode, preallocatedBlockCount: 1)
    )

    #expect(try futureReceiver.receive(nearPackets[0], receivedAtHostTimeNanoseconds: 2) == .queued)
    #expect(try futureReceiver.receive(farFuturePackets[0], receivedAtHostTimeNanoseconds: 2) == .droppedFull)
    #expect(futureReceiver.metrics.futurePackets == 1)
    #expect(futureReceiver.metrics.droppedNetworkFragments == 1)
    #expect(futureReceiver.metrics.rxBuffer.futurePackets == 1)
    #expect(futureReceiver.metrics.overruns == 0)
}

@Test
func madiReceiveRxBufferPoliciesExposeLatencyAndAdaptOutsideCallback() throws {
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

    let adaptiveMode = try madiRxV2Mode(channelCount: 2, rxBufferProfile: .adaptive)
    let adaptivePolicy = try RxBufferPolicy.adaptive(
        framesPerPacket: adaptiveMode.framesPerPacket,
        sampleRateHertz: adaptiveMode.sampleRateHertz,
        minimumPackets: 1,
        initialPackets: 1,
        maximumPackets: 2
    )
    let adaptivePayload = patternedPayload(mode: adaptiveMode)
    let firstPackets = try UdpPcmV2Packetizer.packetize(
        adaptivePayload,
        sequenceNumber: 0,
        senderFrameIndex: 0,
        senderHostTimeNanoseconds: 1,
        mode: adaptiveMode
    )
    let secondPackets = try UdpPcmV2Packetizer.packetize(
        adaptivePayload,
        sequenceNumber: 1,
        senderFrameIndex: UInt64(adaptiveMode.framesPerPacket),
        senderHostTimeNanoseconds: 1,
        mode: adaptiveMode
    )
    var adaptiveReceiver = try MadiReceiveEngine(
        configuration: MadiReceiveConfiguration(mode: adaptiveMode, rxBufferPolicy: adaptivePolicy)
    )

    _ = adaptiveReceiver.renderCallback()
    _ = adaptiveReceiver.renderCallback()
    _ = adaptiveReceiver.renderCallback()

    #expect(try adaptiveReceiver.receive(firstPackets[0], receivedAtHostTimeNanoseconds: 2) == .droppedLate)
    #expect(try adaptiveReceiver.receive(secondPackets[0], receivedAtHostTimeNanoseconds: 2) == .droppedLate)

    #expect(adaptiveReceiver.metrics.rxBuffer.currentTargetFrames == 64)
    #expect(adaptiveReceiver.metrics.rxBuffer.maximumObservedTargetFrames == 64)
    #expect(adaptiveReceiver.metrics.rxBuffer.targetChangeEvents.count == 1)
    #expect(adaptiveReceiver.metrics.rxBuffer.targetChangeEvents.allSatisfy { !$0.changedInsideAudioCallback })
}

@Test
func madiReceiveBoundsReadyPoolAndPendingDeadlines() throws {
    let mode = try madiRxV2Mode(channelCount: 2)
    #expect(throws: MadiReceiveError.nonPositiveField("pendingDeadlineSlotCapacity")) {
        _ = try MadiReceivePendingDeadlineSlots(capacity: 0)
    }
    #expect(throws: MadiReceiveError.nonPositiveField("preallocatedBlockCount")) {
        _ = try MadiReceiveReadyBlockRing(capacity: 0, framesPerBlock: mode.framesPerPacket)
    }
    #expect(throws: MadiReceiveError.nonPositiveField("framesPerBlock")) {
        _ = try MadiReceiveReadyBlockRing(capacity: 1, framesPerBlock: 0)
    }

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

    let fragmentedMode = try madiRxV2Mode(channelCount: 64)
    let payload = patternedPayload(mode: fragmentedMode)
    var pendingLimitReceiver = try MadiReceiveEngine(
        configuration: MadiReceiveConfiguration(
            mode: fragmentedMode,
            preallocatedBlockCount: 1
        )
    )

    for sequence in 0..<MadiReceiveEngine.maxPendingDeadlines {
        let packets = try UdpPcmV2Packetizer.packetize(
            payload,
            sequenceNumber: UInt64(sequence),
            senderFrameIndex: UInt64(sequence * fragmentedMode.framesPerPacket),
            senderHostTimeNanoseconds: UInt64(sequence + 1),
            mode: fragmentedMode
        )
        #expect(try pendingLimitReceiver.receive(packets[0], receivedAtHostTimeNanoseconds: 2) == .waitingForFragments(
            receivedFragmentCount: 1,
            expectedFragmentCount: fragmentedMode.fragments.count
        ))
    }

    let overflowPackets = try UdpPcmV2Packetizer.packetize(
        payload,
        sequenceNumber: UInt64(MadiReceiveEngine.maxPendingDeadlines),
        senderFrameIndex: UInt64(MadiReceiveEngine.maxPendingDeadlines * fragmentedMode.framesPerPacket),
        senderHostTimeNanoseconds: UInt64(MadiReceiveEngine.maxPendingDeadlines + 1),
        mode: fragmentedMode
    )
    #expect(throws: MadiReceiveError.pendingDeadlineLimitExceeded(MadiReceiveEngine.maxPendingDeadlines)) {
        _ = try pendingLimitReceiver.receive(overflowPackets[0], receivedAtHostTimeNanoseconds: 2)
    }
    #expect(pendingLimitReceiver.metrics.allocationWarnings == 1)

    var collidingReceiver = try MadiReceiveEngine(configuration: MadiReceiveConfiguration(mode: fragmentedMode))
    let firstPackets = try UdpPcmV2Packetizer.packetize(
        payload,
        sequenceNumber: 0,
        senderFrameIndex: 0,
        senderHostTimeNanoseconds: 1,
        mode: fragmentedMode
    )
    let collidingPackets = try UdpPcmV2Packetizer.packetize(
        payload,
        sequenceNumber: UInt64(MadiReceiveEngine.maxPendingDeadlines),
        senderFrameIndex: UInt64(MadiReceiveEngine.maxPendingDeadlines * fragmentedMode.framesPerPacket),
        senderHostTimeNanoseconds: 2,
        mode: fragmentedMode
    )

    #expect(try collidingReceiver.receive(firstPackets[0], receivedAtHostTimeNanoseconds: 3) == .waitingForFragments(
        receivedFragmentCount: 1,
        expectedFragmentCount: fragmentedMode.fragments.count
    ))
    #expect(try collidingReceiver.receive(collidingPackets[0], receivedAtHostTimeNanoseconds: 4) == .waitingForFragments(
        receivedFragmentCount: 1,
        expectedFragmentCount: fragmentedMode.fragments.count
    ))
    #expect(collidingReceiver.metrics.allocationWarnings == 0)

    let firstPayload = patternedPayload(mode: fragmentedMode)
    let secondPayload = patternedPayload(mode: fragmentedMode, seed: 17)
    let completingPackets = try UdpPcmV2Packetizer.packetize(
        firstPayload,
        sequenceNumber: 0,
        senderFrameIndex: 0,
        senderHostTimeNanoseconds: 1,
        mode: fragmentedMode
    )
    let secondPackets = try UdpPcmV2Packetizer.packetize(
        secondPayload,
        sequenceNumber: UInt64(MadiReceiveEngine.maxPendingDeadlines),
        senderFrameIndex: UInt64(fragmentedMode.framesPerPacket),
        senderHostTimeNanoseconds: UInt64(MadiReceiveEngine.maxPendingDeadlines + 1),
        mode: fragmentedMode
    )
    var reuseReceiver = try MadiReceiveEngine(configuration: MadiReceiveConfiguration(mode: fragmentedMode))

    for packet in completingPackets {
        _ = try reuseReceiver.receive(packet, receivedAtHostTimeNanoseconds: 2)
    }
    #expect(reuseReceiver.renderCallback() == .silence(startFrame: 0, frameCount: fragmentedMode.framesPerPacket))
    guard case .played = reuseReceiver.renderCallback() else {
        Issue.record("expected first completed block to free the ready slot")
        return
    }
    for packet in secondPackets {
        _ = try reuseReceiver.receive(packet, receivedAtHostTimeNanoseconds: 3)
    }

    #expect(reuseReceiver.metrics.completedBlocks == 2)
    #expect(reuseReceiver.metrics.allocationWarnings == 0)
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
