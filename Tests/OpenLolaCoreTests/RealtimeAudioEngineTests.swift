import Foundation
import Testing

@testable import OpenLolaCore


@Test
func realtimeAudioBlockRingStaysBoundedAndReportsDrops() {
    for capacity in [1, 2, 4, 8, 16, 256] {
        var ring = RealtimeAudioBlockRing(capacity: capacity)
        let blocks = (0..<capacity).map {
            RealtimeAudioFrameBlock(
                startFrame: UInt64($0 * 32),
                frameCount: 32,
                payloadByteCount: 128
            )
        }
        let overflow = RealtimeAudioFrameBlock(
            startFrame: UInt64(capacity * 32),
            frameCount: 32,
            payloadByteCount: 128
        )

        for block in blocks {
            #expect(ring.push(block) == .stored)
        }
        #expect(ring.push(overflow) == .droppedFull)
        #expect(ring.droppedBlocks == 1)
        #expect(ring.count == capacity)
        for block in blocks {
            #expect(ring.pop() == block)
        }
        #expect(ring.pop() == nil)
    }
}

@Test
func realtimeAudioPlayoutUsesDueFrameSilenceAndDropClassifications() {
    var playout = RealtimeAudioDueBlockPlayout(
        startFrame: 0,
        framesPerBlock: 32,
        capacity: 2
    )
    let block = RealtimeAudioFrameBlock(startFrame: 0, frameCount: 32, payloadByteCount: 128)

    #expect(playout.enqueue(block) == .stored)
    #expect(playout.renderNextBlock() == .played(block))
    #expect(playout.renderNextBlock() == .silence(startFrame: 32, frameCount: 32))

    var outOfOrderPlayout = RealtimeAudioDueBlockPlayout(
        startFrame: 0,
        framesPerBlock: 32,
        capacity: 3
    )
    let first = RealtimeAudioFrameBlock(startFrame: 0, frameCount: 32, payloadByteCount: 128)
    let second = RealtimeAudioFrameBlock(startFrame: 32, frameCount: 32, payloadByteCount: 128)
    let third = RealtimeAudioFrameBlock(startFrame: 64, frameCount: 32, payloadByteCount: 128)

    #expect(outOfOrderPlayout.enqueue(third) == .stored)
    #expect(outOfOrderPlayout.enqueue(first) == .stored)
    #expect(outOfOrderPlayout.enqueue(second) == .stored)

    #expect(outOfOrderPlayout.renderNextBlock() == .played(first))
    #expect(outOfOrderPlayout.renderNextBlock() == .played(second))
    #expect(outOfOrderPlayout.renderNextBlock() == .played(third))
    #expect(outOfOrderPlayout.droppedBlocks == 0)

    var aheadPlayout = RealtimeAudioDueBlockPlayout(
        startFrame: 0,
        framesPerBlock: 32,
        capacity: 2
    )
    let outsideWindow = RealtimeAudioFrameBlock(startFrame: 64, frameCount: 32, payloadByteCount: 128)

    #expect(aheadPlayout.enqueue(outsideWindow) == .droppedAhead)
    #expect(aheadPlayout.droppedBlocks == 1)
    #expect(aheadPlayout.bufferedBlockCount == 0)

    var overflowingPlayout = RealtimeAudioDueBlockPlayout(
        startFrame: UInt64.max - 10,
        framesPerBlock: 32,
        capacity: 2
    )
    let currentBlock = RealtimeAudioFrameBlock(
        startFrame: UInt64.max - 10,
        frameCount: 32,
        payloadByteCount: 128
    )

    #expect(overflowingPlayout.enqueue(currentBlock) == .droppedAhead)
    #expect(overflowingPlayout.droppedBlocks == 1)
    #expect(overflowingPlayout.bufferedBlockCount == 0)

    var latePlayout = RealtimeAudioDueBlockPlayout(
        startFrame: 0,
        framesPerBlock: 32,
        capacity: 2
    )
    let oldBlock = RealtimeAudioFrameBlock(startFrame: 0, frameCount: 32, payloadByteCount: 128)

    #expect(latePlayout.renderNextBlock() == .silence(startFrame: 0, frameCount: 32))
    #expect(latePlayout.enqueue(oldBlock) == .droppedLate)
    #expect(latePlayout.droppedBlocks == 1)
    #expect(latePlayout.bufferedBlockCount == 0)
}

@Test
func realtimeAudioPacketHandoffUsesOnePacketPerBlockAndRejectsLateOrMismatchedPackets() throws {
    var handoff = try RealtimeAudioPacketHandoff(configuration: realtimeHandoffConfiguration())

    #expect(handoff.captureCallback(startFrame: 0, hostTimeNanoseconds: 100) == .stored)
    let capturedPacket = try handoff.sendNextPacket()
    let packet = try #require(capturedPacket)

    #expect(packet.header.sequenceNumber == 0)
    #expect(packet.header.senderFrameIndex == 0)
    #expect(packet.header.framesPerPacket == 32)
    #expect(packet.payload.count == 128)

    #expect(try handoff.receive(packet) == .queued)
    #expect(handoff.renderCallback() == .silence(startFrame: 0, frameCount: 32))
    #expect(handoff.renderCallback() == .played(
        RealtimeAudioFrameBlock(
            startFrame: 32,
            frameCount: 32,
            payloadByteCount: 128,
            hostTimeNanoseconds: 100
        )
    ))
    handoff.markShutdownCompleted()

    #expect(handoff.metrics.inputBlocks == 1)
    #expect(handoff.metrics.networkSendBlocks == 1)
    #expect(handoff.metrics.networkReceiveBlocks == 1)
    #expect(handoff.metrics.outputBlocks == 2)
    #expect(handoff.metrics.outputUnderrunBlocks == 1)
    #expect(handoff.metrics.maximumBufferedBlocks <= handoff.metrics.ringCapacityBlocks)
    #expect(handoff.metrics.latePackets == 0)
    #expect(handoff.metrics.shutdownCompleted)

    var lateHandoff = try RealtimeAudioPacketHandoff(configuration: realtimeHandoffConfiguration())
    let latePacket = UdpPcmPacket.silence(
        sequenceNumber: 7,
        senderFrameIndex: 0,
        senderHostTimeNanoseconds: 100,
        mode: realtimePacketMode()
    )

    #expect(lateHandoff.renderCallback() == .silence(startFrame: 0, frameCount: 32))
    #expect(lateHandoff.renderCallback() == .silence(startFrame: 32, frameCount: 32))
    #expect(try lateHandoff.receive(latePacket) == .droppedLate)

    #expect(lateHandoff.metrics.latePackets == 1)
    #expect(lateHandoff.metrics.droppedNetworkBlocks == 1)
    #expect(lateHandoff.metrics.outputUnderrunBlocks == 2)
    #expect(lateHandoff.metrics.maximumBufferedBlocks == 0)
    #expect(!lateHandoff.metrics.hiddenPlayoutGrowthDetected)

    var mismatchedHandoff = try RealtimeAudioPacketHandoff(configuration: realtimeHandoffConfiguration())
    let mismatchedPacket = UdpPcmPacket.silence(
        sequenceNumber: 0,
        senderFrameIndex: 0,
        senderHostTimeNanoseconds: 100,
        mode: UdpPcmPacketMode(
            sampleRateHertz: 96_000,
            framesPerPacket: 32,
            channelCount: 2,
            sampleFormat: .int16LittleEndian
        )
    )

    #expect(throws: RealtimeAudioPacketHandoffError.packetModeMismatch) {
        _ = try mismatchedHandoff.receive(mismatchedPacket)
    }
}

@Test
func realtimeAudioEngineRejectsInvalidReportEvidence() throws {
    let syntheticPass = try loadRealtimeAudioEngineFixture(named: "realtime-audio-engine-synthetic-pass")

    #expect(throws: RealtimeAudioEngineValidationError.passWithoutMeasuredRun) {
        try syntheticPass.validate()
    }

    var unordered = try loadRealtimeAudioEngineFixture(named: "realtime-audio-engine-partial")
    unordered.runtime.handoff.packetizationDuration = PerformanceCounterSummary(
        sampleCount: 3,
        p50Microseconds: 20,
        p95Microseconds: 10,
        p99Microseconds: 30,
        maxMicroseconds: 40
    )

    #expect(throws: RealtimeAudioEngineValidationError.unorderedPerformanceCounter(
        "runtime.handoff.packetizationDuration"
    )) {
        try unordered.validate()
    }

    try expectRealtimeAudioEngineError(.passWithCallbackSafetyViolation("noAllocationInCallback")) {
        $0.safety.noAllocationInCallback = false
    }
    try expectRealtimeAudioEngineError(.passWithoutRmeMadiPath) {
        $0.hardwarePath = .builtIn
    }
    try expectRealtimeAudioEngineError(.passWithoutAcceptedRmeFastestAudioReport) {
        $0.sourceRmeFastestAudioReport = nil
    }
    try expectRealtimeAudioEngineError(.passWithoutAcceptedRouteCertification) {
        $0.sourceRouteCertificationReport = nil
    }
    try expectRealtimeAudioEngineError(.passWithRmeModeMismatch) {
        $0.configuration.sampleRateHertz = 96_000
    }
    try expectRealtimeAudioEngineError(.passWithRouteModeMismatch) {
        $0.configuration.packetFormat = .float32LittleEndian
    }
    try expectRealtimeAudioEngineError(.passWithRouteSourceMismatch(
        expected: "g03-realtime-audio-engine-partial-template",
        actual: "different-g03-report"
    )) {
        $0.sourceRouteCertificationReport?.sourceRealtimeEngineReportId = "different-g03-report"
    }
    try expectRealtimeAudioEngineError(.passWithBufferedPlayoutTarget(
        playoutTargetFrames: 64,
        framesPerBuffer: 32
    )) {
        $0.configuration.playoutTargetFrames = 64
        $0.configuration.rxBufferPolicy = nil
        $0.runtime.handoff.rxBuffer = nil
    }
    try expectRealtimeAudioEngineError(.passWithFastestIneligibleRxBuffer(.adaptive)) {
        let adaptive = try RxBufferPolicy.adaptive(
            framesPerPacket: 32,
            sampleRateHertz: 48_000,
            minimumPackets: 1,
            initialPackets: 2,
            maximumPackets: 4
        )
        $0.configuration.rxBufferPolicy = nil
        $0.runtime.handoff.rxBuffer = RxBufferRuntimeSnapshot(policy: adaptive)
    }
    try expectRealtimeAudioEngineError(.rxBufferRuntimePolicyMismatch(
        configured: .direct,
        observed: .small
    )) {
        let configured = try RxBufferPolicy.direct(
            framesPerPacket: 32,
            sampleRateHertz: 48_000,
            targetPackets: 1
        )
        let observed = try RxBufferPolicy.small(
            framesPerPacket: 32,
            sampleRateHertz: 48_000,
            targetPackets: 2
        )
        $0.configuration.rxBufferPolicy = configured
        $0.runtime.handoff.rxBuffer = RxBufferRuntimeSnapshot(policy: observed)
    }
    try expectRealtimeAudioEngineError(.passWithoutRuntimeRxBufferSnapshot(.direct)) {
        $0.configuration.rxBufferPolicy = try .direct(
            framesPerPacket: 32,
            sampleRateHertz: 48_000,
            targetPackets: 1
        )
        $0.runtime.handoff.rxBuffer = nil
    }
    try expectRealtimeAudioEngineError(.passWithoutRuntimeRxBufferSnapshot(.direct)) {
        $0.configuration.rxBufferPolicy = nil
        $0.runtime.handoff.rxBuffer = nil
    }
    try expectRealtimeAudioEngineError(.passWithRingCapacityMismatch(configured: 4, actual: 8)) {
        $0.runtime.handoff.ringCapacityBlocks = 8
    }
    try expectRealtimeAudioEngineError(.passWithPacketHandoffMismatch) {
        $0.runtime.handoff.networkReceiveBlocks = 999
    }
    try expectRealtimeAudioEngineError(.passWithHandoffDropsOrUnderruns) {
        $0.runtime.handoff.latePackets = 1
    }
    try expectRealtimeAudioEngineError(.passWithRxBufferDegradation(
        "runtime.handoff.rxBuffer.latePackets"
    )) {
        $0.runtime.handoff.rxBuffer?.latePackets = 1
    }
    try expectRealtimeAudioEngineError(.passWithRxBufferDegradation(
        "runtime.handoff.rxBuffer.futurePackets"
    )) {
        $0.runtime.handoff.rxBuffer?.futurePackets = 1
    }
    try expectRealtimeAudioEngineError(.passWithRxBufferDegradation(
        "runtime.handoff.rxBuffer.lostPackets"
    )) {
        $0.runtime.handoff.rxBuffer?.lostPackets = 1
    }
    try expectRealtimeAudioEngineError(.passWithRxBufferDegradation(
        "runtime.handoff.rxBuffer.fragmentLostPackets"
    )) {
        $0.runtime.handoff.rxBuffer?.fragmentLostPackets = 1
    }
    try expectRealtimeAudioEngineError(.passWithRxBufferDegradation(
        "runtime.handoff.rxBuffer.duplicatePackets"
    )) {
        $0.runtime.handoff.rxBuffer?.duplicatePackets = 1
    }
    try expectRealtimeAudioEngineError(.passWithRxBufferDegradation(
        "runtime.handoff.rxBuffer.reorderedPackets"
    )) {
        $0.runtime.handoff.rxBuffer?.reorderedPackets = 1
    }
    try expectRealtimeAudioEngineError(.passWithRxBufferDegradation(
        "runtime.handoff.rxBuffer.underruns"
    )) {
        $0.runtime.handoff.rxBuffer?.underruns = 1
    }
    try expectRealtimeAudioEngineError(.passWithRxBufferDegradation(
        "runtime.handoff.rxBuffer.overruns"
    )) {
        $0.runtime.handoff.rxBuffer?.overruns = 1
    }
    try expectRealtimeAudioEngineError(.passWithRxBufferDegradation(
        "runtime.handoff.rxBuffer.plcEvents"
    )) {
        $0.runtime.handoff.rxBuffer?.plcEvents = 1
    }
    try expectRealtimeAudioEngineError(.passWithoutRunArtifactPath) {
        $0.runArtifactPath = nil
    }
    try expectRealtimeAudioEngineError(.passWithUnboundedHandoff) {
        $0.runtime.handoff.maximumBufferedBlocks = 5
        $0.runtime.handoff.ringCapacityBlocks = 4
    }
    try expectRealtimeAudioEngineError(.passCallbackExceededPeriod(
        maxMicroseconds: 800,
        periodMicroseconds: 666.6666666666666
    )) {
        $0.runtime.callback.maxMicroseconds = 800
    }
}

@Test
func safetyChecklistSelfAttestationGateRejectsReportWithAnyViolationField() throws {
    try expectRealtimeAudioEngineError(.passWithCallbackSafetyViolation("noAllocationInCallback")) {
        $0.safety.noAllocationInCallback = false
    }
}

private func expectRealtimeAudioEngineError(
    _ expected: RealtimeAudioEngineValidationError,
    mutate: (inout RealtimeAudioEngineReport) throws -> Void
) throws {
    var report = try realtimeAudioEnginePassCandidateReport()
    try mutate(&report)

    #expect(throws: expected) {
        try report.validate()
    }
}

private func realtimeHandoffConfiguration() -> RealtimeAudioEngineConfiguration {
    RealtimeAudioEngineConfiguration(
        inputDeviceUID: "rme-madi-uid",
        outputDeviceUID: "rme-madi-uid",
        sampleRateHertz: 48_000,
        framesPerBuffer: 32,
        channelCount: 2,
        packetFormat: .int16LittleEndian,
        inputChannelMap: [0, 1],
        outputChannelMap: [0, 1],
        playoutTargetFrames: 32,
        preallocatedBlockCount: 4
    )
}

private func realtimePacketMode() -> UdpPcmPacketMode {
    UdpPcmPacketMode(
        sampleRateHertz: 48_000,
        framesPerPacket: 32,
        channelCount: 2,
        sampleFormat: .int16LittleEndian
    )
}
