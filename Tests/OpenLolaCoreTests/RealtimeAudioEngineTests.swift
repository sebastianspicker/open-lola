import Foundation
import Testing

@testable import OpenLolaCore

@Test
func realtimeAudioEnginePartialFixtureDecodesAndValidates() throws {
    let report = try loadRealtimeAudioEngineFixture(named: "realtime-audio-engine-partial")

    try report.validate()

    #expect(report.verdict == .partial)
    #expect(report.runMode == .synthetic)
    #expect(report.safety.noAllocationInCallback)
    #expect(report.runtime.handoff.ringCapacityBlocks == 4)
}

@Test
func realtimeAudioEngineSyntheticSmokeEmitsPartialReport() throws {
    let report = try RealtimeAudioEngineSyntheticSmoke.run()

    try report.validate()

    #expect(report.verdict == .partial)
    #expect(report.runMode == .synthetic)
    #expect(report.runtime.handoff.outputUnderrunBlocks == 1)
    #expect(report.runtime.handoff.maximumBufferedBlocks <= report.runtime.handoff.ringCapacityBlocks)
}

@Test
func realtimeAudioEngineRejectsSyntheticPassFixture() throws {
    let report = try loadRealtimeAudioEngineFixture(named: "realtime-audio-engine-synthetic-pass")

    #expect(throws: RealtimeAudioEngineValidationError.passWithoutMeasuredRun) {
        try report.validate()
    }
}

@Test
func realtimeAudioEngineReportsUnorderedHandoffPerformanceCounterField() throws {
    var report = try loadRealtimeAudioEngineFixture(named: "realtime-audio-engine-partial")
    report.runtime.handoff.packetizationDuration = PerformanceCounterSummary(
        sampleCount: 3,
        p50Microseconds: 20,
        p95Microseconds: 10,
        p99Microseconds: 30,
        maxMicroseconds: 40
    )

    #expect(throws: RealtimeAudioEngineValidationError.unorderedPerformanceCounter(
        "runtime.handoff.packetizationDuration"
    )) {
        try report.validate()
    }
}

@Test
func realtimeAudioBuffersClampStalePacketAccountingUnderflow() throws {
    let source = try readRealtimeAudioEngineSource("Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioBuffers.swift")

    #expect(source.contains("precondition(bufferedPackets >= dropped"))
    #expect(source.contains("bufferedPackets = max(0, bufferedPackets - dropped)"))
}

@Test
func realtimeAudioBuffersLatchHiddenPlayoutGrowthForFinalMetrics() throws {
    let source = try readRealtimeAudioEngineSource("Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioBuffers.swift")

    #expect(source.contains("maximumBufferedBlocks = max(maximumBufferedBlocks, bufferedPackets)"))
    #expect(source.contains("if maximumBufferedBlocks > capacityBlocks"))
    #expect(source.contains("hiddenPlayoutGrowthDetected = true"))
}

@Test
func realtimeAudioPayloadShapeChecksByteCountMultiplication() throws {
    let source = try readRealtimeAudioEngineSource("Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioBuffers.swift")

    #expect(source.contains("checkedRealtimeAudioPayloadByteCount"))
    #expect(source.contains("multipliedReportingOverflow"))
    #expect(source.contains("RealtimeAudioPayloadShape byte count must not overflow"))
}

@Test
func realtimeAudioHandoffMetricsUsesSynthesizedCodable() throws {
    let source = try readRealtimeAudioEngineSource("Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngine.swift")
    let handoffStart = try #require(source.range(of: "public struct RealtimeAudioHandoffMetrics"))
    let runtimeStart = try #require(source.range(
        of: "public struct RealtimeAudioRuntimeEvidence",
        range: handoffStart.upperBound..<source.endIndex
    ))
    let handoffSource = String(source[handoffStart.lowerBound..<runtimeStart.lowerBound])

    #expect(!handoffSource.contains("CodingKeys"))
    #expect(!handoffSource.contains("init(from decoder: Decoder)"))
    #expect(!handoffSource.contains("func encode(to encoder: Encoder)"))
}

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
func realtimeAudioPlayoutUsesDueBlockThenSilenceWhenMissing() {
    var playout = RealtimeAudioDueBlockPlayout(
        startFrame: 0,
        framesPerBlock: 32,
        capacity: 2
    )
    let block = RealtimeAudioFrameBlock(startFrame: 0, frameCount: 32, payloadByteCount: 128)

    #expect(playout.enqueue(block) == .stored)
    #expect(playout.renderNextBlock() == .played(block))
    #expect(playout.renderNextBlock() == .silence(startFrame: 32, frameCount: 32))
}

@Test
func realtimeAudioPlayoutUsesDueFrameWhenPacketsArriveOutOfOrder() {
    var playout = RealtimeAudioDueBlockPlayout(
        startFrame: 0,
        framesPerBlock: 32,
        capacity: 3
    )
    let first = RealtimeAudioFrameBlock(startFrame: 0, frameCount: 32, payloadByteCount: 128)
    let second = RealtimeAudioFrameBlock(startFrame: 32, frameCount: 32, payloadByteCount: 128)
    let third = RealtimeAudioFrameBlock(startFrame: 64, frameCount: 32, payloadByteCount: 128)

    #expect(playout.enqueue(third) == .stored)
    #expect(playout.enqueue(first) == .stored)
    #expect(playout.enqueue(second) == .stored)

    #expect(playout.renderNextBlock() == .played(first))
    #expect(playout.renderNextBlock() == .played(second))
    #expect(playout.renderNextBlock() == .played(third))
    #expect(playout.droppedBlocks == 0)
}

@Test
func realtimeAudioPlayoutRejectsBlocksOutsideBoundedWindow() {
    var playout = RealtimeAudioDueBlockPlayout(
        startFrame: 0,
        framesPerBlock: 32,
        capacity: 2
    )
    let outsideWindow = RealtimeAudioFrameBlock(startFrame: 64, frameCount: 32, payloadByteCount: 128)

    #expect(playout.enqueue(outsideWindow) == .droppedAhead)
    #expect(playout.droppedBlocks == 1)
    #expect(playout.bufferedBlockCount == 0)
}

@Test
func realtimeAudioPlayoutRejectsOverflowingWindowEnd() {
    var playout = RealtimeAudioDueBlockPlayout(
        startFrame: UInt64.max - 10,
        framesPerBlock: 32,
        capacity: 2
    )
    let currentBlock = RealtimeAudioFrameBlock(
        startFrame: UInt64.max - 10,
        frameCount: 32,
        payloadByteCount: 128
    )

    #expect(playout.enqueue(currentBlock) == .droppedAhead)
    #expect(playout.droppedBlocks == 1)
    #expect(playout.bufferedBlockCount == 0)
}

@Test
func realtimeAudioPlayoutClassifiesLateBlocksSeparatelyFromFullBuffers() {
    var playout = RealtimeAudioDueBlockPlayout(
        startFrame: 0,
        framesPerBlock: 32,
        capacity: 2
    )
    let oldBlock = RealtimeAudioFrameBlock(startFrame: 0, frameCount: 32, payloadByteCount: 128)

    #expect(playout.renderNextBlock() == .silence(startFrame: 0, frameCount: 32))
    #expect(playout.enqueue(oldBlock) == .droppedLate)
    #expect(playout.droppedBlocks == 1)
    #expect(playout.bufferedBlockCount == 0)
}

@Test
func realtimeAudioPacketHandoffUsesOnePacketPerCapturedBlock() throws {
    var handoff = RealtimeAudioPacketHandoff(configuration: realtimeHandoffConfiguration())

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
}

@Test
func realtimeAudioPacketHandoffPacketizesCapturedBlockAsUdpPcmV2Fragments() throws {
    let configuration = RealtimeAudioEngineConfiguration(
        inputDeviceUID: "rme-madi-uid",
        outputDeviceUID: "rme-madi-uid",
        sampleRateHertz: 48_000,
        framesPerBuffer: 32,
        channelCount: 64,
        packetFormat: .float32LittleEndian,
        inputChannelMap: Array(0..<64),
        outputChannelMap: Array(0..<64),
        playoutTargetFrames: 32,
        preallocatedBlockCount: 4
    )
    let fragments = try UdpPcmV2FragmentPlanner.plan(
        UdpPcmV2FragmentPlanRequest(
            streamID: 1,
            totalChannelCount: 64,
            framesPerPacket: 32,
            sampleRateHertz: 48_000,
            sampleFormat: .float32LittleEndian,
            maxTransmissionUnitBytes: 1_200,
            maxFragmentsPerDeadline: 16,
            metadataRevision: 4,
            packingMode: .interleavedChannelRange
        )
    )
    let mode = AudioTransportMode(
        protocolVersion: .udpPcmV2,
        sampleRateHertz: 48_000,
        framesPerPacket: 32,
        channelCount: 64,
        sampleFormat: .float32LittleEndian,
        latencyProfile: .safeLowLatency,
        rxBufferProfile: .direct,
        maxTransmissionUnitBytes: 1_200,
        channelOrder: AudioChannelSet.defaultInput(count: 64).sortedByStableSourceIndex,
        fragments: fragments
    )
    var handoff = RealtimeAudioPacketHandoff(configuration: configuration)

    #expect(handoff.captureCallback(startFrame: 0, hostTimeNanoseconds: 100) == .stored)
    let capturedPackets = try handoff.sendNextV2Packets(mode: mode)
    let packets = try #require(capturedPackets)
    let reassembled = try UdpPcmV2FragmentReassembler.reassemble(packets)

    #expect(packets.count == 8)
    #expect(packets.allSatisfy { $0.header.packetByteCount <= 1_200 })
    #expect(reassembled.isComplete)
    #expect(reassembled.payload == Data(repeating: 0, count: 32 * 64 * 4))
    #expect(handoff.metrics.networkSendBlocks == 1)
}

@Test
func realtimeAudioPacketHandoffDropsLatePacketsWithoutGrowingPlayout() throws {
    var handoff = RealtimeAudioPacketHandoff(configuration: realtimeHandoffConfiguration())
    let latePacket = UdpPcmPacket.silence(
        sequenceNumber: 7,
        senderFrameIndex: 0,
        senderHostTimeNanoseconds: 100,
        mode: realtimePacketMode()
    )

    #expect(handoff.renderCallback() == .silence(startFrame: 0, frameCount: 32))
    #expect(handoff.renderCallback() == .silence(startFrame: 32, frameCount: 32))
    #expect(try handoff.receive(latePacket) == .droppedLate)

    #expect(handoff.metrics.latePackets == 1)
    #expect(handoff.metrics.droppedNetworkBlocks == 1)
    #expect(handoff.metrics.outputUnderrunBlocks == 2)
    #expect(handoff.metrics.maximumBufferedBlocks == 0)
    #expect(!handoff.metrics.hiddenPlayoutGrowthDetected)
}

@Test
func realtimeAudioPacketHandoffRejectsMismatchedPacketMode() {
    var handoff = RealtimeAudioPacketHandoff(configuration: realtimeHandoffConfiguration())
    let packet = UdpPcmPacket.silence(
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
        _ = try handoff.receive(packet)
    }
}

@Test
func realtimeAudioEngineRejectsPassWithCallbackAllocation() throws {
    var report = try realtimeAudioEnginePassCandidateReport()
    report.safety.noAllocationInCallback = false

    #expect(throws: RealtimeAudioEngineValidationError.passWithCallbackSafetyViolation(
        "noAllocationInCallback"
    )) {
        try report.validate()
    }
}

@Test
func realtimeAudioEngineRejectsPassWithoutMeasuredRmePath() throws {
    var report = try realtimeAudioEnginePassCandidateReport()
    report.hardwarePath = .builtIn

    #expect(throws: RealtimeAudioEngineValidationError.passWithoutRmeMadiPath) {
        try report.validate()
    }
}

@Test
func realtimeAudioEngineRejectsPassWithoutAcceptedRmeFastestAudioReport() throws {
    var report = try realtimeAudioEnginePassCandidateReport()
    report.sourceRmeFastestAudioReport = nil

    #expect(throws: RealtimeAudioEngineValidationError.passWithoutAcceptedRmeFastestAudioReport) {
        try report.validate()
    }
}

@Test
func realtimeAudioEngineRejectsPassWithoutAcceptedRouteCertification() throws {
    var report = try realtimeAudioEnginePassCandidateReport()
    report.sourceRouteCertificationReport = nil

    #expect(throws: RealtimeAudioEngineValidationError.passWithoutAcceptedRouteCertification) {
        try report.validate()
    }
}

@Test
func realtimeAudioEngineRejectsPassWithRmeModeMismatch() throws {
    var report = try realtimeAudioEnginePassCandidateReport()
    report.configuration.sampleRateHertz = 96_000

    #expect(throws: RealtimeAudioEngineValidationError.passWithRmeModeMismatch) {
        try report.validate()
    }
}

@Test
func realtimeAudioEngineRejectsPassWithRouteModeMismatch() throws {
    var report = try realtimeAudioEnginePassCandidateReport()
    report.configuration.packetFormat = .float32LittleEndian

    #expect(throws: RealtimeAudioEngineValidationError.passWithRouteModeMismatch) {
        try report.validate()
    }
}

@Test
func realtimeAudioEngineRejectsPassWhenRoutePointsAtDifferentEngineReport() throws {
    var report = try realtimeAudioEnginePassCandidateReport()
    report.sourceRouteCertificationReport?.sourceRealtimeEngineReportId = "different-g03-report"

    #expect(throws: RealtimeAudioEngineValidationError.passWithRouteSourceMismatch(
        expected: report.id,
        actual: "different-g03-report"
    )) {
        try report.validate()
    }
}

@Test
func realtimeAudioEngineRejectsPassWithBufferedPlayoutTarget() throws {
    var report = try realtimeAudioEnginePassCandidateReport()
    report.configuration.playoutTargetFrames = 64
    report.configuration.rxBufferPolicy = nil
    report.runtime.handoff.rxBuffer = nil

    #expect(throws: RealtimeAudioEngineValidationError.passWithBufferedPlayoutTarget(
        playoutTargetFrames: 64,
        framesPerBuffer: 32
    )) {
        try report.validate()
    }
}

@Test
func realtimeAudioEngineRejectsPassWithRuntimeOnlyAdaptiveRxBuffer() throws {
    var report = try realtimeAudioEnginePassCandidateReport()
    let adaptive = try RxBufferPolicy.adaptive(
        framesPerPacket: 32,
        sampleRateHertz: 48_000,
        minimumPackets: 1,
        initialPackets: 2,
        maximumPackets: 4
    )
    report.configuration.rxBufferPolicy = nil
    report.runtime.handoff.rxBuffer = RxBufferRuntimeSnapshot(policy: adaptive)

    #expect(throws: RealtimeAudioEngineValidationError.passWithFastestIneligibleRxBuffer(
        .adaptive
    )) {
        try report.validate()
    }
}

@Test
func realtimeAudioEngineRejectsPassWithRuntimeRxBufferPolicyMismatch() throws {
    var report = try realtimeAudioEnginePassCandidateReport()
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
    report.configuration.rxBufferPolicy = configured
    report.runtime.handoff.rxBuffer = RxBufferRuntimeSnapshot(policy: observed)

    #expect(throws: RealtimeAudioEngineValidationError.rxBufferRuntimePolicyMismatch(
        configured: .direct,
        observed: .small
    )) {
        try report.validate()
    }
}

@Test
func realtimeAudioEngineRejectsPassWithoutRuntimeRxBufferSnapshot() throws {
    var report = try realtimeAudioEnginePassCandidateReport()
    report.configuration.rxBufferPolicy = try .direct(
        framesPerPacket: 32,
        sampleRateHertz: 48_000,
        targetPackets: 1
    )
    report.runtime.handoff.rxBuffer = nil

    #expect(throws: RealtimeAudioEngineValidationError.passWithoutRuntimeRxBufferSnapshot(
        .direct
    )) {
        try report.validate()
    }
}

@Test
func realtimeAudioEngineRejectsPassWithoutExplicitRxBufferAccounting() throws {
    var report = try realtimeAudioEnginePassCandidateReport()
    report.configuration.rxBufferPolicy = nil
    report.runtime.handoff.rxBuffer = nil

    #expect(throws: RealtimeAudioEngineValidationError.passWithoutRuntimeRxBufferSnapshot(
        .direct
    )) {
        try report.validate()
    }
}

@Test
func realtimeAudioEngineRejectsPassWithRingCapacityMismatch() throws {
    var report = try realtimeAudioEnginePassCandidateReport()
    report.runtime.handoff.ringCapacityBlocks = 8

    #expect(throws: RealtimeAudioEngineValidationError.passWithRingCapacityMismatch(
        configured: 4,
        actual: 8
    )) {
        try report.validate()
    }
}

@Test
func realtimeAudioEngineRejectsPassWithPacketHandoffMismatch() throws {
    var report = try realtimeAudioEnginePassCandidateReport()
    report.runtime.handoff.networkReceiveBlocks = 999

    #expect(throws: RealtimeAudioEngineValidationError.passWithPacketHandoffMismatch) {
        try report.validate()
    }
}

@Test
func realtimeAudioEngineRejectsPassWithLatePackets() throws {
    var report = try realtimeAudioEnginePassCandidateReport()
    report.runtime.handoff.latePackets = 1

    #expect(throws: RealtimeAudioEngineValidationError.passWithHandoffDropsOrUnderruns) {
        try report.validate()
    }
}

@Test
func realtimeAudioEngineRejectsMeasuredZeroBlockDirectRxPolicy() throws {
    #expect(throws: RxBufferPolicyValidationError.directTargetOutOfRange(targetPackets: 0)) {
        _ = try RxBufferPolicy.direct(
            framesPerPacket: 32,
            sampleRateHertz: 48_000,
            targetPackets: 0
        )
    }
}

@Test
func realtimeAudioEngineRejectsImplicitZeroBlockDirectRxPolicy() throws {
    var report = try realtimeAudioEnginePassCandidateReport()
    report.configuration.playoutTargetFrames = 0
    report.configuration.rxBufferPolicy = nil

    #expect(throws: RxBufferPolicyValidationError.directTargetOutOfRange(targetPackets: 0)) {
        try report.validate()
    }
}

@Test
func realtimeAudioEngineDefaultDirectRxPolicyGuardsFramesPerBuffer() throws {
    let source = try readRealtimeAudioEngineSource(
        "Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngineReportValidation.swift"
    )

    #expect(source.contains("try requireRealtimePositive(configuration.framesPerBuffer"))
    #expect(source.contains("let targetPackets = configuration.playoutTargetFrames / configuration.framesPerBuffer"))
}

@Test
func realtimeAudioEnginePlaceholderFieldsUseExplicitChecklist() throws {
    let source = try readRealtimeAudioEngineSource(
        "Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngineReportValidation.swift"
    )

    #expect(source.contains("private static let requiredStaticPlaceholderFieldNames = ["))
    #expect(source.contains("\"hardware.driverVersion\""))
    #expect(source.contains("\"configuration.outputDeviceUID\""))
    #expect(source.contains("Realtime audio engine placeholder field checklist mismatch"))
    #expect(source.contains("Set(staticFields.map { $0.name }) == Set(Self.requiredStaticPlaceholderFieldNames)"))
}

@Test
func realtimeAudioEngineRejectsPassWithoutRunArtifactPath() throws {
    var report = try realtimeAudioEnginePassCandidateReport()
    report.runArtifactPath = nil

    #expect(throws: RealtimeAudioEngineValidationError.passWithoutRunArtifactPath) {
        try report.validate()
    }
}

@Test
func realtimeAudioEngineRejectsPassWithUnboundedHandoff() throws {
    var report = try realtimeAudioEnginePassCandidateReport()
    report.runtime.handoff.maximumBufferedBlocks = 5
    report.runtime.handoff.ringCapacityBlocks = 4

    #expect(throws: RealtimeAudioEngineValidationError.passWithUnboundedHandoff) {
        try report.validate()
    }
}

@Test
func realtimeAudioEngineRejectsPassWhenCallbackMaxExceedsPeriod() throws {
    var report = try realtimeAudioEnginePassCandidateReport()
    report.runtime.callback.maxMicroseconds = 800
    let periodMicroseconds = (
        Double(report.configuration.framesPerBuffer) / Double(report.configuration.sampleRateHertz)
    ) * 1_000_000

    #expect(throws: RealtimeAudioEngineValidationError.passCallbackExceededPeriod(
        maxMicroseconds: 800,
        periodMicroseconds: periodMicroseconds
    )) {
        try report.validate()
    }
}

@Test
func realtimeAudioEnginePassCandidateValidates() throws {
    let report = try realtimeAudioEnginePassCandidateReport()

    try report.validate()

    #expect(report.verdict == .pass)
    #expect(report.hardwarePath == .rmeMadi)
}

@Test
func realtimeAudioEngineJSONRoundTripPreservesReport() throws {
    let report = try loadRealtimeAudioEngineFixture(named: "realtime-audio-engine-partial")
    let jsonData = try report.prettyJSONData()
    let decoded = try RealtimeAudioEngineReport.decode(from: jsonData)

    #expect(decoded == report)
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

private func readRealtimeAudioEngineSource(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
