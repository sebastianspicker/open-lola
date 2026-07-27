// Verifies that MADI receive depacketizes required channels and recovers missing fragments.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func madiReceiveDepacketizesRequiredChannelsAndRecoversMissingFragments() throws {
    for channelCount in madiSyntheticRequiredChannelCounts {
        try expectMadiReceiveDepacketizesRequiredChannels(channelCount)
    }
    try expectMadiReceiveSameDeadlineRecoveryForMissingFragment()
}

private func expectMadiReceiveDepacketizesRequiredChannels(_ channelCount: Int) throws {
    let mode = try madiRxV2Mode(channelCount: channelCount)
    let payload = patternedPayload(mode: mode)
    let packets = try madiRxPackets(payload: payload, mode: mode)
    var receiver = try MadiReceiveEngine(configuration: MadiReceiveConfiguration(mode: mode))

    for packet in packets.reversed() {
        _ = try receiver.receive(packet, receivedAtHostTimeNanoseconds: 2)
    }

    #expect(receiver.renderCallback() == .silence(startFrame: 0, frameCount: 32))
    guard case .played(let block) = receiver.renderCallback() else {
        Issue.record("expected played block for \(channelCount) channels")
        return
    }
    #expect(block.payload == payload)
    #expect(block.sequenceNumber == 0)
    #expect(block.inputChannelCount == channelCount)
    #expect(block.outputChannelCount == channelCount)
    #expect(block.latency.frames == 32)
    expectCompletedMadiReceiveMetrics(receiver.metrics)
}

private func expectMadiReceiveSameDeadlineRecoveryForMissingFragment() throws {
    let recoveryMode = try madiRxV2Mode(channelCount: 64)
    let recoveryPayload = patternedPayload(mode: recoveryMode)
    let recoveryPackets = try madiRxPackets(payload: recoveryPayload, mode: recoveryMode)
    var recoveryReceiver = try MadiReceiveEngine(configuration: MadiReceiveConfiguration(mode: recoveryMode))

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
    try expectMadiReceiveRejectsLatePacket()
    try expectMadiReceiveRejectsOverflowingPacket()
    try expectMadiReceiveRejectsFarFuturePacket()
}

private func expectMadiReceiveRejectsLatePacket() throws {
    let mode = try madiRxV2Mode(channelCount: 2)
    let payload = patternedPayload(mode: mode)
    let packets = try madiRxPackets(payload: payload, mode: mode)
    var receiver = try MadiReceiveEngine(configuration: MadiReceiveConfiguration(mode: mode))

    #expect(receiver.renderCallback() == .silence(startFrame: 0, frameCount: 32))
    _ = receiver.renderCallback()

    #expect(try receiver.receive(packets[0], receivedAtHostTimeNanoseconds: 2) == .droppedLate)
    #expect(receiver.metrics.latePackets == 1)
    #expect(receiver.metrics.droppedNetworkFragments == 1)
    #expect(receiver.metrics.rxBuffer.latePackets == 1)
    #expect(receiver.metrics.rxBuffer.lostPackets == 1)
}

private func expectMadiReceiveRejectsOverflowingPacket() throws {
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
        transport: .init(
            framesPerPacket: overflowMode.framesPerPacket,
            sampleRateHertz: overflowMode.sampleRateHertz
        ),
        targets: .init(minimumFrames: 0, targetFrames: 64, maximumFrames: 128),
        eligibility: .init(
            fastestAudioPassEligible: false,
            adaptationChangesOutsideCallback: true,
            notes: "test overflow policy"
        )
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
}

private func expectMadiReceiveRejectsFarFuturePacket() throws {
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
    try expectMadiReceiveSmallRxBufferLatency()
    try expectMadiReceiveAdaptiveTargetChangesOutsideCallback()
}

private func expectMadiReceiveSmallRxBufferLatency() throws {
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

private func expectMadiReceiveAdaptiveTargetChangesOutsideCallback() throws {
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
    try expectMadiReceiveRejectsInvalidPoolCapacities()
    try expectMadiReceiveReadyPoolOverrun()
    try expectMadiReceivePendingDeadlineLimit()
    try expectMadiReceivePendingDeadlineCollision()
    try expectMadiReceiveReusesFreedReadySlot()
}

private func expectMadiReceiveRejectsInvalidPoolCapacities() throws {
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
}

private func expectMadiReceiveReadyPoolOverrun() throws {
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

private func expectMadiReceivePendingDeadlineLimit() throws {
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
}

private func expectMadiReceivePendingDeadlineCollision() throws {
    let fragmentedMode = try madiRxV2Mode(channelCount: 64)
    let payload = patternedPayload(mode: fragmentedMode)
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
    #expect(
        try collidingReceiver.receive(
            collidingPackets[0],
            receivedAtHostTimeNanoseconds: 4
        ) == .waitingForFragments(
            receivedFragmentCount: 1,
            expectedFragmentCount: fragmentedMode.fragments.count
        )
    )
    #expect(collidingReceiver.metrics.allocationWarnings == 0)
}

private func expectMadiReceiveReusesFreedReadySlot() throws {
    let fragmentedMode = try madiRxV2Mode(channelCount: 64)
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
