import Foundation
import Testing

@testable import OpenLolaCore

@Test
func realtimeAudioPacketHandoffSendsCapturedV1Payload() throws {
    var handoff = RealtimeAudioPacketHandoff(configuration: packetHandoffConfiguration())
    let payload = Data((0..<128).map(UInt8.init))

    #expect(handoff.captureCallback(
        startFrame: 0,
        hostTimeNanoseconds: 1,
        payload: payload
    ) == .stored)
    let capturedPacket = try handoff.sendNextPacket()
    let packet = try #require(capturedPacket)

    #expect(packet.payload == payload)
    #expect(packet.header.sequenceNumber == 0)
    #expect(packet.header.senderFrameIndex == 0)
    #expect(packet.header.senderHostTimeNanoseconds == 1)
    #expect(handoff.metrics.directInputBlocks == 1)
    #expect(handoff.metrics.packetFragmentCount == 1)
    #expect(handoff.metrics.allocationWarnings == 0)
}

@Test
func realtimeAudioPacketHandoffReportsFullCaptureRing() {
    var handoff = RealtimeAudioPacketHandoff(
        configuration: packetHandoffConfiguration(preallocatedBlockCount: 1)
    )

    #expect(handoff.captureCallback(startFrame: 0, hostTimeNanoseconds: 1) == .stored)
    #expect(handoff.captureCallback(startFrame: 32, hostTimeNanoseconds: 2) == .droppedFull)

    #expect(handoff.metrics.droppedInputBlocks == 1)
    #expect(handoff.metrics.fullCaptureRingBlocks == 1)
    #expect(handoff.metrics.callbackOverrunBlocks == 1)
    #expect(handoff.metrics.maximumBufferedBlocks == 1)
}

@Test
func realtimeAudioPacketHandoffReportsInvalidInterleavedInputShape() {
    var handoff = RealtimeAudioPacketHandoff(configuration: packetHandoffConfiguration())
    let payload = Data(repeating: 0, count: 64)

    let result = payload.withUnsafeBytes { bytes in
        handoff.captureInterleavedInputCallback(
            startFrame: 0,
            hostTimeNanoseconds: 1,
            sourceChannelCount: 1,
            sourceBytes: bytes
        )
    }

    #expect(result == .droppedInvalid)
    #expect(handoff.metrics.invalidInputBlocks == 1)
    #expect(handoff.metrics.droppedInputBlocks == 1)
    #expect(handoff.metrics.callbackOverrunBlocks == 0)
    #expect(handoff.metrics.fullCaptureRingBlocks == 0)
}

@Test
func realtimeAudioPacketHandoffRejectsOversizedInterleavedInputPayload() {
    var handoff = RealtimeAudioPacketHandoff(configuration: packetHandoffConfiguration())
    let payload = Data(repeating: 0, count: 129)

    #expect(handoff.captureCallback(
        startFrame: 0,
        hostTimeNanoseconds: 1,
        payload: payload
    ) == .droppedInvalid)
    #expect(handoff.metrics.invalidInputBlocks == 1)
    #expect(handoff.metrics.directInputBlocks == 0)
}

@Test
func realtimeAudioPacketHandoffDrainsBurstAfterCaptureRingDrop() throws {
    var handoff = RealtimeAudioPacketHandoff(
        configuration: packetHandoffConfiguration(preallocatedBlockCount: 2)
    )

    #expect(handoff.captureCallback(startFrame: 0, hostTimeNanoseconds: 1) == .stored)
    #expect(handoff.captureCallback(startFrame: 32, hostTimeNanoseconds: 2) == .stored)
    #expect(handoff.captureCallback(startFrame: 64, hostTimeNanoseconds: 3) == .droppedFull)

    let capturedFirst = try handoff.sendNextPacket()
    let capturedSecond = try handoff.sendNextPacket()
    let first = try #require(capturedFirst)
    let second = try #require(capturedSecond)

    #expect(first.header.senderFrameIndex == 0)
    #expect(second.header.senderFrameIndex == 32)
    #expect(try handoff.sendNextPacket() == nil)
    #expect(handoff.metrics.droppedInputBlocks == 1)
    #expect(handoff.metrics.networkSendBlocks == 2)
    #expect(handoff.metrics.maximumCaptureRingOccupancyBlocks == 2)
}

@Test
func realtimeAudioPacketHandoffReportsPlayoutBufferExhaustion() throws {
    var handoff = RealtimeAudioPacketHandoff(
        configuration: packetHandoffConfiguration(preallocatedBlockCount: 2, playoutTargetFrames: 32)
    )

    #expect(try handoff.receive(packet(sequence: 1, senderFrameIndex: 0)) == .queued)
    #expect(try handoff.receive(packet(sequence: 2, senderFrameIndex: 0)) == .droppedFull)

    #expect(handoff.metrics.networkReceiveBlocks == 2)
    #expect(handoff.metrics.droppedNetworkBlocks == 1)
    #expect(handoff.metrics.maximumPlayoutQueueDepthBlocks == 1)
}

@Test
func realtimeAudioPacketHandoffTracksReceiveSequenceGapsAndDuplicates() throws {
    let policy = try RxBufferPolicy.direct(framesPerPacket: 32, sampleRateHertz: 48_000)
    var handoff = RealtimeAudioPacketHandoff(
        configuration: packetHandoffConfiguration(preallocatedBlockCount: 4, rxBufferPolicy: policy)
    )

    #expect(try handoff.receive(packet(sequence: 1, senderFrameIndex: 0)) == .queued)
    #expect(try handoff.receive(packet(sequence: 3, senderFrameIndex: 32)) == .queued)
    #expect(handoff.metrics.rxBuffer?.lostPackets == 1)
    #expect(try handoff.receive(packet(sequence: 2, senderFrameIndex: 64)) == .queued)
    #expect(handoff.metrics.rxBuffer?.reorderedPackets == 1)
    #expect(try handoff.receive(packet(sequence: 2, senderFrameIndex: 0)) == .droppedFull)
    #expect(handoff.metrics.rxBuffer?.duplicatePackets == 1)
}

@Test
func realtimeAudioPacketHandoffUsesFrameBufferAsSafeFallbackTarget() throws {
    var handoff = RealtimeAudioPacketHandoff(
        configuration: packetHandoffConfiguration(playoutTargetFrames: 0)
    )

    #expect(try handoff.receive(packet(sequence: 1, senderFrameIndex: 0)) == .queued)
    #expect(handoff.renderCallback() == .silence(startFrame: 0, frameCount: 32))
    #expect(handoff.renderCallback() == .played(
        RealtimeAudioFrameBlock(
            startFrame: 32,
            frameCount: 32,
            payloadByteCount: 128,
            hostTimeNanoseconds: 1
        )
    ))
}

@Test
func realtimeAudioPacketHandoffRejectsOverflowingPlayoutFrame() throws {
    var handoff = RealtimeAudioPacketHandoff(configuration: packetHandoffConfiguration())

    #expect(try handoff.receive(packet(
        sequence: 1,
        senderFrameIndex: UInt64.max - 10
    )) == .droppedInvalid)
    #expect(handoff.metrics.networkReceiveBlocks == 1)
    #expect(handoff.metrics.droppedNetworkBlocks == 1)
    #expect(handoff.metrics.maximumPlayoutQueueDepthBlocks == 0)
}

@Test
func realtimeAudioPacketHandoffRejectsV2SampleFormatMismatchBeforeSend() throws {
    var handoff = RealtimeAudioPacketHandoff(configuration: packetHandoffConfiguration())
    let mode = try mismatchedV2Mode()

    #expect(handoff.captureCallback(startFrame: 0, hostTimeNanoseconds: 1) == .stored)
    #expect(throws: RealtimeAudioPacketHandoffError.transportModeMismatch) {
        _ = try handoff.sendNextV2Packets(mode: mode)
    }
}

@Test
func realtimeAudioPacketHandoffRejectsIncompleteV2FragmentPlanBeforeSend() throws {
    var handoff = RealtimeAudioPacketHandoff(configuration: packetHandoffConfiguration())
    let mode = incompleteV2Mode()

    #expect(handoff.captureCallback(startFrame: 0, hostTimeNanoseconds: 1) == .stored)
    #expect(throws: RealtimeAudioPacketHandoffError.transportModeMismatch) {
        _ = try handoff.sendNextV2Packets(mode: mode)
    }
}

@Test
func realtimeAudioPacketHandoffV2PacketizationBorrowsCaptureRingPayload() throws {
    let handoffSource = try readRealtimeAudioSource(
        "Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPacketHandoff.swift"
    )
    let ringSource = try readRealtimeAudioSource(
        "Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPayloadCaptureRing.swift"
    )
    let packetizerSource = try readRealtimeAudioSource(
        "Sources/OpenLolaCore/Network/UDP/UdpPcmV2Packet.swift"
    )

    #expect(handoffSource.contains("captureRing.withPoppedPayload"))
    #expect(handoffSource.contains("mach_absolute_time()"))
    #expect(handoffSource.contains("mach_timebase_info(&info)"))
    #expect(handoffSource.contains("UdpPcmV2Packetizer.packetize(\n                payloadBytes"))
    #expect(handoffSource.contains("case droppedInvalid"))
    #expect(handoffSource.contains("return .droppedInvalid"))
    #expect(!handoffSource.contains("DispatchTime.now()"))
    #expect(packetizerSource.contains("_ payload: UnsafeRawBufferPointer"))
    #expect(!ringSource.contains("Data(payloadStorage"))
    #expect(!ringSource.contains("payloadStorage[payloadStart..<payloadEnd]"))
    #expect(!ringSource.contains("&& Set(inputChannelMap).count == inputChannelMap.count"))
    #expect(!ringSource.contains("&& inputChannelMap == Array(0..<shape.channelCount)"))
}

@Test
func realtimeAudioPacketHandoffMetricsInitializationNamesEveryField() throws {
    let engineSource = try readRealtimeAudioSource("Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngine.swift")
    let handoffSource = try readRealtimeAudioSource(
        "Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPacketHandoff.swift"
    )

    #expect(!engineSource.contains("latePackets: Int = 0"))
    #expect(!engineSource.contains("packetizationDuration: PerformanceCounterSummary = .empty"))
    #expect(handoffSource.contains("fullCaptureRingBlocks: 0"))
    #expect(handoffSource.contains("maximumCaptureRingOccupancyBlocks: 0"))
    #expect(handoffSource.contains("packetizationDuration: .empty"))
    #expect(handoffSource.contains("depacketizationDuration: .empty"))
}

@Test
func realtimeAudioPayloadCaptureRingRequiresUniqueChannelMap() throws {
    let ringSource = try readRealtimeAudioSource(
        "Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPayloadCaptureRing.swift"
    )

    #expect(ringSource.contains("Set(inputChannelMap).count == inputChannelMap.count"))
    #expect(ringSource.contains("inputChannelMap must be unique"))
}

@Test
func realtimeAudioChannelMapNormalizationUsesSharedHelper() throws {
    let engineSource = try readRealtimeAudioSource("Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngine.swift")
    let handoffSource = try readRealtimeAudioSource(
        "Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPacketHandoff.swift"
    )
    let loopbackSource = try readRealtimeAudioSource(
        "Sources/OpenLolaCore/Audio/Routing/AudioLoopbackRunConfiguration.swift"
    )

    #expect(engineSource.contains("func normalizedRealtimeAudioChannelMap("))
    #expect(engineSource.contains("Array(0..<channelCount)"))
    #expect(handoffSource.contains("normalizedRealtimeAudioChannelMap("))
    #expect(!handoffSource.contains("private func normalizedChannelMap("))
    #expect(loopbackSource.contains("normalizedRealtimeAudioChannelMap(inputChannelMap"))
    #expect(loopbackSource.contains("normalizedRealtimeAudioChannelMap(outputChannelMap"))
}

@Test
func realtimeAudioPayloadCaptureRingSilentPushRequiresClearedSlot() throws {
    let ringSource = try readRealtimeAudioSource(
        "Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPayloadCaptureRing.swift"
    )

    #expect(ringSource.contains("guard zeroPayloadSlot(at: writeIndex) else"))
    #expect(ringSource.contains("return invalidDrop()"))
    #expect(ringSource.contains("guard let baseAddress = destination.baseAddress else"))
}

@Test
func realtimeAudioPacketHandoffRejectsSequenceNumberWrap() throws {
    let handoffSource = try readRealtimeAudioSource(
        "Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPacketHandoff.swift"
    )

    #expect(handoffSource.contains("case sequenceNumberExhausted"))
    #expect(handoffSource.contains("guard nextSequenceNumber < UInt64.max else"))
    #expect(handoffSource.contains("throw RealtimeAudioPacketHandoffError.sequenceNumberExhausted"))
    #expect(!handoffSource.contains("nextSequenceNumber &+="))
}

@Test
func realtimeAudioPayloadCaptureRingValidatesAudioBufferPointersAtCopy() throws {
    let ringSource = try readRealtimeAudioSource(
        "Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPayloadCaptureRing.swift"
    )

    #expect(!ringSource.contains("validAudioBuffers(inputBuffers)"))
    #expect(ringSource.contains("audioBufferForCopy(at: location.bufferIndex"))
    #expect(ringSource.contains("let buffer = inputBuffers[index]"))
    #expect(ringSource.contains("guard buffer.mData != nil else"))
    #expect(ringSource.contains("let sourceChannelCount = Int(source.mNumberChannels)"))
}

@Test
func realtimeAudioPayloadCaptureRingDocumentsDirectCopyPrecondition() throws {
    let ringSource = try readRealtimeAudioSource(
        "Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPayloadCaptureRing.swift"
    )

    #expect(ringSource.contains("guard sourceChannelCount > 0 else"))
    #expect(ringSource.contains("Caller has already validated sourceChannelCount > 0"))
    #expect(ringSource.contains("sourceChannelCount == shape.channelCount"))
}

@Test
func realtimeAudioPacketHandoffKeepsInputAudioBufferListReadOnly() throws {
    let handoffSource = try readRealtimeAudioSource(
        "Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPacketHandoff.swift"
    )
    let ringSource = try readRealtimeAudioSource(
        "Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPayloadCaptureRing.swift"
    )

    #expect(handoffSource.contains("let inputBuffers = RealtimeAudioBufferListReader(input)"))
    #expect(!handoffSource.contains("UnsafeMutablePointer(mutating: input)"))
    #expect(ringSource.contains("struct RealtimeAudioBufferListReader"))
    #expect(ringSource.contains("UnsafeRawPointer(pointer)"))
}

@Test
func realtimeAudioPacketHandoffRequiresNonNegativePlayoutTarget() throws {
    let handoffSource = try readRealtimeAudioSource(
        "Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPacketHandoff.swift"
    )

    #expect(handoffSource.contains("precondition(configuredPlayoutTargetFrames >= 0"))
    #expect(handoffSource.contains("playoutTargetFrames must be non-negative"))
}

@Test
func realtimeAudioPacketHandoffV1PacketizationUsesReusablePayloadStaging() throws {
    let handoffSource = try readRealtimeAudioSource(
        "Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPacketHandoff.swift"
    )
    let ringSource = try readRealtimeAudioSource(
        "Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPayloadCaptureRing.swift"
    )

    #expect(handoffSource.contains("private var packetPayloadScratch: Data"))
    #expect(handoffSource.contains("packetPayloadScratch.reserveCapacity(packetMode.payloadByteCount)"))
    #expect(handoffSource.contains("captureRing.popPayload(into: &packetPayloadScratch)"))
    #expect(!handoffSource.contains("Data(bytes: baseAddress, count: payloadBytes.count)"))
    #expect(ringSource.contains("destination.removeAll(keepingCapacity: true)"))
}

private func packetHandoffConfiguration(
    preallocatedBlockCount: Int = 4,
    playoutTargetFrames: Int = 32,
    rxBufferPolicy: RxBufferPolicy? = nil
) -> RealtimeAudioEngineConfiguration {
    RealtimeAudioEngineConfiguration(
        inputDeviceUID: "rme-madi-uid",
        outputDeviceUID: "rme-madi-uid",
        sampleRateHertz: 48_000,
        framesPerBuffer: 32,
        channelCount: 2,
        packetFormat: .int16LittleEndian,
        inputChannelMap: [0, 1],
        outputChannelMap: [0, 1],
        playoutTargetFrames: playoutTargetFrames,
        preallocatedBlockCount: preallocatedBlockCount,
        rxBufferPolicy: rxBufferPolicy
    )
}

private func packet(sequence: UInt64, senderFrameIndex: UInt64) -> UdpPcmPacket {
    UdpPcmPacket(
        header: UdpPcmPacketHeader(
            sequenceNumber: sequence,
            senderFrameIndex: senderFrameIndex,
            senderHostTimeNanoseconds: sequence,
            sampleRateHertz: 48_000,
            framesPerPacket: 32,
            channelCount: 2,
            sampleFormat: .int16LittleEndian
        ),
        payload: Data(repeating: UInt8(sequence), count: 128)
    )
}

private func readRealtimeAudioSource(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}

private func mismatchedV2Mode() throws -> AudioTransportMode {
    let fragments = try UdpPcmV2FragmentPlanner.plan(
        UdpPcmV2FragmentPlanRequest(
            streamID: 1,
            totalChannelCount: 2,
            framesPerPacket: 32,
            sampleRateHertz: 48_000,
            sampleFormat: .float32LittleEndian,
            maxTransmissionUnitBytes: 1_200,
            maxFragmentsPerDeadline: 16,
            metadataRevision: 0,
            packingMode: .interleavedChannelRange
        )
    )
    return AudioTransportMode(
        protocolVersion: .udpPcmV2,
        sampleRateHertz: 48_000,
        framesPerPacket: 32,
        channelCount: 2,
        sampleFormat: .float32LittleEndian,
        latencyProfile: .safeLowLatency,
        rxBufferProfile: .direct,
        maxTransmissionUnitBytes: 1_200,
        channelOrder: AudioChannelSet.defaultInput(count: 2).sortedByStableSourceIndex,
        fragments: fragments
    )
}

private func incompleteV2Mode() -> AudioTransportMode {
    AudioTransportMode(
        protocolVersion: .udpPcmV2,
        sampleRateHertz: 48_000,
        framesPerPacket: 32,
        channelCount: 2,
        sampleFormat: .int16LittleEndian,
        latencyProfile: .safeLowLatency,
        rxBufferProfile: .direct,
        maxTransmissionUnitBytes: 1_200,
        channelOrder: AudioChannelSet.defaultInput(count: 2).sortedByStableSourceIndex,
        fragments: [
            UdpPcmV2ChannelFragmentPlan(
                streamID: 1,
                totalChannelCount: 2,
                channelOffset: 0,
                channelsInFragment: 1,
                fragmentIndex: 0,
                fragmentCount: 1,
                framesPerPacket: 32,
                sampleRateHertz: 48_000,
                sampleFormat: .int16LittleEndian,
                metadataRevision: 0,
                packingMode: .interleavedChannelRange,
                payloadByteCount: 64,
                packetByteCount: 144
            ),
        ]
    )
}
