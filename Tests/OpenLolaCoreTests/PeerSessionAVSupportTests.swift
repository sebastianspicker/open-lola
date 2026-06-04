import CoreGraphics
import Dispatch
import Foundation
import Testing

@testable import OpenLolaCore


@Test
func directPeerOpenLolaRawAudioReassemblyHandlesFragmentsLimitsAndIncompleteDeadlines() throws {
    let mode = try directPeerFragmentedRawAudioMode()
    let payload = Data(repeating: 0x7d, count: mode.framesPerPacket * mode.channelCount * mode.sampleFormat.bytesPerSample)

    var completeState = DirectPeerOpenLolaRawAudioReassemblyState()
    let completePackets = try UdpPcmV2Packetizer.packetize(
        payload,
        sequenceNumber: 11,
        senderFrameIndex: 352,
        senderHostTimeNanoseconds: 99_000,
        mode: mode
    )

    #expect(completePackets.count > 1)
    for packet in completePackets.dropLast() {
        #expect(try completeState.receive(packet) == nil)
    }
    let lastCompletePacket = try #require(completePackets.last)
    let block = try #require(try completeState.receive(lastCompletePacket))

    #expect(block.payload == payload)
    #expect(block.senderFrameIndex == 352)
    #expect(block.senderHostTimeNanoseconds == 99_000)

    var duplicateFloodState = DirectPeerOpenLolaRawAudioReassemblyState()
    let duplicateFloodPackets = try UdpPcmV2Packetizer.packetize(
        payload,
        sequenceNumber: 18,
        senderFrameIndex: 576,
        senderHostTimeNanoseconds: 99_007,
        mode: mode
    )
    let duplicateFirstFragment = try #require(duplicateFloodPackets.first)
    #expect(try duplicateFloodState.receive(duplicateFirstFragment) == nil)
    for _ in 0..<10_000 {
        #expect(try duplicateFloodState.receive(duplicateFirstFragment) == nil)
    }
    #expect(duplicateFloodState.consumeDroppedDuplicateFragments() == 10_000)
    for packet in duplicateFloodPackets.dropFirst().dropLast() {
        #expect(try duplicateFloodState.receive(packet) == nil)
    }
    let duplicateFloodLastFragment = try #require(duplicateFloodPackets.last)
    let duplicateFloodBlock = try #require(try duplicateFloodState.receive(duplicateFloodLastFragment))
    #expect(duplicateFloodBlock.payload == payload)
    #expect(duplicateFloodState.consumeDroppedDuplicateFragments() == 0)

    var cappedState = DirectPeerOpenLolaRawAudioReassemblyState(maxFragmentCount: 2)
    var cappedPacket = try #require(UdpPcmV2Packetizer.packetize(
        payload,
        sequenceNumber: 12,
        senderFrameIndex: 384,
        senderHostTimeNanoseconds: 99_001,
        mode: mode
    ).first)
    cappedPacket.header.fragmentCount = UInt16.max

    #expect(throws: UdpPcmV2FragmentReassemblyError.fragmentCountExceedsLimit(actual: UInt16.max, max: 2)) {
        _ = try cappedState.receive(cappedPacket)
    }

    var deadlineState = DirectPeerOpenLolaRawAudioReassemblyState(maxPendingDeadlines: 1)
    let firstDeadline = try UdpPcmV2Packetizer.packetize(
        payload,
        sequenceNumber: 13,
        senderFrameIndex: 416,
        senderHostTimeNanoseconds: 99_002,
        mode: mode
    )
    let secondDeadline = try UdpPcmV2Packetizer.packetize(
        payload,
        sequenceNumber: 14,
        senderFrameIndex: 448,
        senderHostTimeNanoseconds: 99_003,
        mode: mode
    )

    #expect(try deadlineState.receive(try #require(firstDeadline.first)) == nil)
    #expect(deadlineState.consumeDroppedIncompleteDeadlines() == 0)
    #expect(try deadlineState.receive(try #require(secondDeadline.first)) == nil)
    #expect(deadlineState.consumeDroppedIncompleteDeadlines() == 1)

    var reorderedState = DirectPeerOpenLolaRawAudioReassemblyState(maxPendingDeadlines: 2)
    let firstPayload = Data(repeating: 0x7d, count: mode.framesPerPacket * mode.channelCount * mode.sampleFormat.bytesPerSample)
    let secondPayload = Data(repeating: 0x7e, count: mode.framesPerPacket * mode.channelCount * mode.sampleFormat.bytesPerSample)
    let firstReorderedDeadline = try UdpPcmV2Packetizer.packetize(
        firstPayload,
        sequenceNumber: 16,
        senderFrameIndex: 512,
        senderHostTimeNanoseconds: 99_005,
        mode: mode
    )
    let secondReorderedDeadline = try UdpPcmV2Packetizer.packetize(
        secondPayload,
        sequenceNumber: 17,
        senderFrameIndex: 544,
        senderHostTimeNanoseconds: 99_006,
        mode: mode
    )

    #expect(firstReorderedDeadline.count > 1)
    #expect(secondReorderedDeadline.count > 1)
    #expect(try reorderedState.receive(try #require(firstReorderedDeadline.first)) == nil)
    #expect(try reorderedState.receive(try #require(secondReorderedDeadline.first)) == nil)
    for packet in firstReorderedDeadline.dropFirst().dropLast() {
        #expect(try reorderedState.receive(packet) == nil)
    }
    let firstLast = try #require(firstReorderedDeadline.last)
    let firstBlock = try #require(try reorderedState.receive(firstLast))
    for packet in secondReorderedDeadline.dropFirst().dropLast() {
        #expect(try reorderedState.receive(packet) == nil)
    }
    let secondLast = try #require(secondReorderedDeadline.last)
    let secondBlock = try #require(try reorderedState.receive(secondLast))

    #expect(firstBlock.payload == firstPayload)
    #expect(secondBlock.payload == secondPayload)
    #expect(reorderedState.consumeDroppedIncompleteDeadlines() == 0)

    var flushState = DirectPeerOpenLolaRawAudioReassemblyState()
    let flushPackets = try UdpPcmV2Packetizer.packetize(
        payload,
        sequenceNumber: 15,
        senderFrameIndex: 480,
        senderHostTimeNanoseconds: 99_004,
        mode: mode
    )

    #expect(try flushState.receive(try #require(flushPackets.first)) == nil)
    #expect(flushState.flushIncomplete() == 1)
    #expect(flushState.flushIncomplete() == 0)
}

@Test
func directPeerAVAudioTXDrainsWithPacketBudgetAndLeavesBacklogForNextIteration() throws {
    var pair = try startedAVLoopbackPair(
        audioTransport: .openLolaRaw,
        framesPerPacket: 32
    )
    defer {
        pair.first.shutdown(reason: "bounded audio tx test complete")
        pair.second.shutdown(reason: "bounded audio tx test complete")
    }
    let graph = try DirectPeerRealtimeAudioGraph(
        configuration: testAudioGraphConfiguration(framesPerBuffer: 32)
    )
    let payload = Data(repeating: 0x25, count: 32 * 2 * UdpPcmSampleFormat.float32LittleEndian.bytesPerSample)
    #expect(graph.captureInjectedPayload(payload, hostTimeNanoseconds: 1_000) == .stored)
    #expect(graph.captureInjectedPayload(payload, hostTimeNanoseconds: 2_000) == .stored)
    #expect(graph.captureInjectedPayload(payload, hostTimeNanoseconds: 3_000) == .stored)

    let firstDrain = try runAudioTXLoop(
        runner: &pair.first,
        audioGraph: graph,
        configuration: DirectPeerAudioTXLoopConfiguration(
            transport: .openLolaRaw,
            opusEncoder: nil,
            rtpSSRC: 1,
            maxPackets: 2
        )
    )
    let secondDrain = try runAudioTXLoop(
        runner: &pair.first,
        audioGraph: graph,
        configuration: DirectPeerAudioTXLoopConfiguration(
            transport: .openLolaRaw,
            opusEncoder: nil,
            rtpSSRC: 1,
            maxPackets: 2
        )
    )

    #expect(firstDrain.payloadsSent == 2)
    #expect(firstDrain.budgetExhausted)
    #expect(secondDrain.payloadsSent == 1)
    #expect(!secondDrain.budgetExhausted)
}

@Test
func directPeerAVAudioRXCountsMalformedTransportPayloadsAsDrops() throws {
    var rawPair = try startedAVLoopbackPair(
        audioTransport: .openLolaRaw,
        framesPerPacket: 32
    )
    defer {
        rawPair.first.shutdown(reason: "malformed audio envelope test complete")
        rawPair.second.shutdown(reason: "malformed audio envelope test complete")
    }
    try #require(rawPair.first.audioTransport).sendRawDatagram(Data([0x00, 0x01, 0x02]))
    _ = try rawPair.second.waitForIncomingMedia(timeoutMicroseconds: 50_000)
    let rawGraph = try DirectPeerRealtimeAudioGraph(
        configuration: testAudioGraphConfiguration(framesPerBuffer: 32)
    )
    var rawAudioRXState = directPeerAudioRXLoopState()

    let rawResult = try runAudioRXLoop(
        runner: &rawPair.second,
        audioGraph: rawGraph,
        state: &rawAudioRXState,
        configuration: DirectPeerAudioRXLoopConfiguration(
            transport: .openLolaRaw,
            opusDecoder: nil,
            maxPackets: 4
        )
    )

    #expect(rawResult.queuedForPlayout == 0)
    #expect(rawResult.droppedBeforePlayout == 1)
    #expect(rawPair.second.transportMetrics().malformedPackets == 1)

    var opusPair = try startedAVLoopbackPair(
        audioTransport: .openLolaOpusCeltLowDelay,
        framesPerPacket: OpusCELTLowDelayConstants.frameCount
    )
    defer {
        opusPair.first.shutdown(reason: "malformed opus test complete")
        opusPair.second.shutdown(reason: "malformed opus test complete")
    }
    try opusPair.first.sendOpusAudioPayload(
        Data([0xff]),
        sequenceNumber: 1,
        senderFrameIndex: 0,
        hostTimeNanoseconds: 1,
        channelCount: 2
    )
    _ = try opusPair.second.waitForIncomingMedia(timeoutMicroseconds: 50_000)
    let opusGraph = try DirectPeerRealtimeAudioGraph(
        configuration: testAudioGraphConfiguration(framesPerBuffer: OpusCELTLowDelayConstants.frameCount)
    )
    var opusAudioRXState = directPeerAudioRXLoopState()

    let opusResult = try runAudioRXLoop(
        runner: &opusPair.second,
        audioGraph: opusGraph,
        state: &opusAudioRXState,
        configuration: DirectPeerAudioRXLoopConfiguration(
            transport: .openLolaOpusCeltLowDelay,
            opusDecoder: try OpusCELTLowDelayDecoder(channelCount: 2),
            maxPackets: 4
        )
    )

    #expect(opusResult.queuedForPlayout == 0)
    #expect(opusResult.droppedBeforePlayout == 1)

    var aes67Sender = try PeerSessionRunner.localhost(peerID: "peer-a", remotePeerID: "peer-b")
    var aes67Receiver = try PeerSessionRunner.localhost(peerID: "peer-b", remotePeerID: "peer-a")
    defer {
        aes67Sender.shutdown(reason: "malformed aes67 test complete")
        aes67Receiver.shutdown(reason: "malformed aes67 test complete")
    }
    try #require(aes67Sender.audioTransport).connect(to: aes67Receiver.localEndpoints.audioEndpoint)
    try #require(aes67Sender.audioTransport).sendRawDatagram(try RTPPacket(
        header: RTPPacketHeader(sequenceNumber: 1, timestamp: 48, ssrc: 42),
        payload: Data([0x01, 0x02, 0x03])
    ).encoded())
    _ = try aes67Receiver.waitForIncomingMedia(timeoutMicroseconds: 50_000)
    let aes67Graph = try DirectPeerRealtimeAudioGraph(
        configuration: testAudioGraphConfiguration(framesPerBuffer: AES67ST2110L24Profile.framesPerPacket)
    )
    var aes67AudioRXState = directPeerAudioRXLoopState()

    let aes67Result = try runAudioRXLoop(
        runner: &aes67Receiver,
        audioGraph: aes67Graph,
        state: &aes67AudioRXState,
        configuration: DirectPeerAudioRXLoopConfiguration(
            transport: .aes67ST2110L24,
            opusDecoder: nil,
            maxPackets: 4
        )
    )

    #expect(aes67Result.queuedForPlayout == 0)
    #expect(aes67Result.droppedBeforePlayout == 1)
}

@Test
func directPeerAVAudioRXCountsUnexpectedPayloadTypesAsDrops() throws {
    var pair = try startedAVLoopbackPair(
        audioTransport: .openLolaRaw,
        framesPerPacket: 32
    )
    defer {
        pair.first.shutdown(reason: "unexpected audio payload test complete")
        pair.second.shutdown(reason: "unexpected audio payload test complete")
    }
    let videoPacket = try directPeerUnexpectedVideoMediaPacket(sequenceNumber: 1)
    try #require(pair.first.audioTransport).send(videoPacket)
    _ = try pair.second.waitForIncomingMedia(timeoutMicroseconds: 50_000)
    let graph = try DirectPeerRealtimeAudioGraph(
        configuration: testAudioGraphConfiguration(framesPerBuffer: 32)
    )
    var audioRXState = directPeerAudioRXLoopState()

    let result = try runAudioRXLoop(
        runner: &pair.second,
        audioGraph: graph,
        state: &audioRXState,
        configuration: DirectPeerAudioRXLoopConfiguration(
            transport: .openLolaRaw,
            opusDecoder: nil,
            maxPackets: 4
        )
    )

    #expect(result.queuedForPlayout == 0)
    #expect(result.unexpectedPayloadTypes == 1)
    #expect(result.droppedBeforePlayout == 1)
}

@Test
func directPeerAVVideoRXCountsUnexpectedPayloadTypesAsDrops() throws {
    var pair = try startedAVLoopbackPair(
        audioTransport: .openLolaRaw,
        framesPerPacket: 32
    )
    defer {
        pair.first.shutdown(reason: "unexpected video payload test complete")
        pair.second.shutdown(reason: "unexpected video payload test complete")
    }
    let audioPacket = try directPeerUnexpectedAudioMediaPacket(
        runner: pair.first,
        sequenceNumber: 1
    )
    try #require(pair.first.videoTransport).send(audioPacket)
    _ = try pair.second.waitForIncomingMedia(timeoutMicroseconds: 50_000)
    var reassembler = VideoFrameReassembler(maxFragmentsPerFrame: 4)
    var deferredFrame: RawCapturedVideoFrame?

    let result = try runVideoRXLoop(
        runner: &pair.second,
        reassembler: &reassembler,
        deferredFrame: &deferredFrame,
        configuration: DirectPeerVideoRXLoopConfiguration(
            previewSink: nil,
            playoutAnchor: DirectPeerAVPlayoutAnchor(policy: .policy(for: .balancedAV)),
            compression: .raw,
            maxPackets: 4
        )
    )

    #expect(result.fragmentsReceived == 0)
    #expect(result.unexpectedPayloadTypes == 1)
    #expect(result.framesReassembled == 0)
}

@Test
func directPeerAVAudioRXFailsMissingInternalRawAudioRouter() throws {
    var pair = try startedAVLoopbackPair(
        audioTransport: .openLolaRaw,
        framesPerPacket: 32
    )
    defer {
        pair.first.shutdown(reason: "missing audio router test complete")
        pair.second.shutdown(reason: "missing audio router test complete")
    }
    let payload = Data(repeating: 0x44, count: 32 * 2 * UdpPcmSampleFormat.float32LittleEndian.bytesPerSample)
    try pair.first.sendAudioPayload(
        payload,
        sequenceNumber: 1,
        senderFrameIndex: 0,
        hostTimeNanoseconds: 1
    )
    _ = try pair.second.waitForIncomingMedia(timeoutMicroseconds: 50_000)
    pair.second.audioRouter = nil
    let graph = try DirectPeerRealtimeAudioGraph(
        configuration: testAudioGraphConfiguration(framesPerBuffer: 32)
    )
    var audioRXState = directPeerAudioRXLoopState()

    #expect(throws: PeerSessionRunnerError.missingAudioRouter) {
        _ = try runAudioRXLoop(
            runner: &pair.second,
            audioGraph: graph,
            state: &audioRXState,
            configuration: DirectPeerAudioRXLoopConfiguration(
                transport: .openLolaRaw,
                opusDecoder: nil,
                maxPackets: 4
            )
        )
    }
}

@Test
func directPeerAVAudioRXRecoversAfterAES67ForwardGap() throws {
    var sender = try PeerSessionRunner.localhost(peerID: "peer-a", remotePeerID: "peer-b")
    var receiver = try PeerSessionRunner.localhost(peerID: "peer-b", remotePeerID: "peer-a")
    defer {
        sender.shutdown(reason: "aes67 gap recovery test complete")
        receiver.shutdown(reason: "aes67 gap recovery test complete")
    }
    try #require(sender.audioTransport).connect(to: receiver.localEndpoints.audioEndpoint)
    let payload = Data(repeating: 0, count: AES67ST2110L24Profile.payloadByteCount)
    try #require(sender.audioTransport).sendRawDatagram(try RTPPacket(
        header: RTPPacketHeader(sequenceNumber: 1, timestamp: 48, ssrc: 42),
        payload: payload
    ).encoded())
    try #require(sender.audioTransport).sendRawDatagram(try RTPPacket(
        header: RTPPacketHeader(sequenceNumber: 3, timestamp: 144, ssrc: 42),
        payload: payload
    ).encoded())
    _ = try receiver.waitForIncomingMedia(timeoutMicroseconds: 50_000)
    let graph = try DirectPeerRealtimeAudioGraph(
        configuration: testAudioGraphConfiguration(framesPerBuffer: AES67ST2110L24Profile.framesPerPacket)
    )
    var audioRXState = directPeerAudioRXLoopState()

    let result = try runAudioRXLoop(
        runner: &receiver,
        audioGraph: graph,
        state: &audioRXState,
        configuration: DirectPeerAudioRXLoopConfiguration(
            transport: .aes67ST2110L24,
            opusDecoder: nil,
            maxPackets: 4
        )
    )

    #expect(result.queuedForPlayout == 2)
    #expect(result.rtpPacketsLost == 1)
    #expect(result.droppedBeforePlayout == 1)
}

@Test
func directPeerAVConfigurationValidationRequiresSplitAudioDeviceUIDs() throws {
    var valid = directPeerAVSupportConfiguration(mediaSourceMode: .syntheticFixture)
    valid.videoWidth = 16
    valid.videoHeight = 16
    try validateAVConfiguration(valid)

    let missingOutput = DirectPeerSessionAVRunConfiguration(
        manual: valid.manual,
        durationSeconds: valid.durationSeconds,
        audioDeviceUID: valid.audioDeviceUID,
        inputDeviceUID: valid.inputDeviceUID,
        outputDeviceUID: "",
        videoDeviceID: valid.videoDeviceID,
        videoWidth: valid.videoWidth,
        videoHeight: valid.videoHeight,
        preview: valid.preview,
        mediaSourceMode: .syntheticFixture
    )

    #expect(throws: DirectPeerSessionAVRuntimeError.missingOutputDeviceUID) {
        try validateAVConfiguration(missingOutput)
    }
}

@Test
func directPeerAVAudioRXDrainMetricsDoNotDoubleCountPlayoutQueueDrops() {
    var metrics = DirectPeerSessionAVRuntimeMetrics(audioPayloadsDroppedBeforePlayout: 2)
    let drain = DirectPeerAudioRXDrainResult(
        queuedForPlayout: 7,
        droppedBeforePlayout: 3,
        droppedByPlayoutQueue: 2
    )

    accumulateAudioRXDrainMetrics(drain, into: &metrics)

    #expect(metrics.audioPayloadsQueuedForPlayout == 7)
    #expect(metrics.audioPayloadsDroppedBeforePlayout == 5)
    #expect(metrics.audioPayloadsDroppedByPlayoutQueue == 2)
}

@Test
func directPeerAVMetricsServicePublishesDrainsAndPersistsTransportFields() throws {
    var pair = try PeerSessionRunnerLoopbackPair.make()
    defer {
        pair.first.shutdown(reason: "metrics test complete")
        pair.second.shutdown(reason: "metrics test complete")
    }
    try pair.negotiate()
    try pair.startMedia()

    var firstNextMetricsPublish: UInt64 = 1
    let publish = serviceDirectPeerAVMetrics(
        runner: &pair.first,
        nextMetricsPublishTimeNanoseconds: &firstNextMetricsPublish,
        nowNanoseconds: 1
    )
    var secondNextMetricsPublish = UInt64.max
    var receive = DirectPeerAVMetricsServiceResult()
    let deadline = DispatchTime.now().uptimeNanoseconds + 50_000_000
    repeat {
        receive = serviceDirectPeerAVMetrics(
            runner: &pair.second,
            nextMetricsPublishTimeNanoseconds: &secondNextMetricsPublish,
            nowNanoseconds: 1
        )
        if receive.peerMetricsMessagesReceived > 0 {
            break
        }
        Thread.sleep(forTimeInterval: 0.001)
    } while DispatchTime.now().uptimeNanoseconds < deadline

    #expect(publish.metricsMessagesPublished == 1)
    #expect(pair.first.metrics.metricsMessagesSent == 1)
    #expect(receive.peerMetricsMessagesReceived == 1)
    #expect(pair.second.metrics.remoteMetricsMessagesReceived == 1)

    let remote = SessionMetricsMessage(
        sessionID: try #require(pair.second.acceptedConfiguration).sessionID,
        packetsLost: 4,
        jitterMicroseconds: 55,
        latePackets: 3,
        callbackDurationP99Microseconds: 120,
        queueDepthPackets: 2,
        cpuPercent: 8.5,
        memoryResidentBytes: 900_000,
        underruns: 1,
        overruns: 2,
        videoFramesDropped: 6
    )
    pair.second.recordRemoteMetrics(remote)
    let control = try DirectPeerSessionControlSocket.bindLoopback()
    defer { control.close() }

    let report = try buildAVReport(
        configuration: directPeerAVSupportConfiguration(mediaSourceMode: .syntheticFixture),
        runner: pair.second,
        control: control,
        runtime: DirectPeerSessionAVRuntimeResult(
            metrics: DirectPeerSessionAVRuntimeMetrics(
                metricsMessagesPublished: 1,
                peerMetricsMessagesReceived: 1
            ),
            videoFormat: nil,
            receiveProof: nil
        )
    )

    #expect(report.metrics.remoteMetricsMessagesReceived == 2)
    #expect(report.metrics.remotePacketsLost == 4)
    #expect(report.metrics.remoteJitterMicroseconds == 55)
    #expect(report.metrics.remoteQueueDepthPackets == 2)
    #expect(report.metrics.remoteVideoFramesDropped == 6)
}

func directPeerAVSupportConfiguration(
    mediaSourceMode: DirectPeerSessionAVMediaSourceMode
) -> DirectPeerSessionAVRunConfiguration {
    DirectPeerSessionAVRunConfiguration(
        manual: DirectPeerSessionManualRunConfiguration(
            role: .initiator,
            localPeerID: "peer-a",
            remotePeerID: "peer-b",
            localHost: "127.0.0.1",
            remoteHost: "127.0.0.1",
            controlPort: 10_001,
            remoteControlPort: 10_002,
            audioPort: 10_003,
            videoPort: 10_004,
            metricsPort: 10_005,
            packetCount: 1,
            audioChannelCount: 2,
            timeoutSeconds: 1
        ),
        durationSeconds: 1,
        audioDeviceUID: "input-a",
        inputDeviceUID: "input-a",
        outputDeviceUID: "output-b",
        videoDeviceID: "synthetic-test-device",
        mediaSourceMode: mediaSourceMode
    )
}

private func startedAVLoopbackPair(
    audioTransport: DirectPeerSessionAudioTransport,
    framesPerPacket: Int
) throws -> PeerSessionRunnerLoopbackPair {
    var pair = try PeerSessionRunnerLoopbackPair.make()
    let firstHandshake = try pair.first.beginHandshake()
    let secondHandshake = try pair.second.beginHandshake()
    try pair.first.receiveControlMessages(secondHandshake)
    try pair.second.receiveControlMessages(firstHandshake)
    let proposal = try pair.first.makeAudioVideoSessionProposal(
        sampleRateHertz: 48_000,
        framesPerPacket: framesPerPacket,
        sampleFormat: .float32LittleEndian,
        audioTransport: audioTransport,
        audioChannelCount: 2,
        videoWidth: 16,
        videoHeight: 16,
        videoFrameRate: 30
    )
    let accept = try pair.second.acceptProposal(proposal, proposerCapabilities: pair.first.localCapabilities)
    try pair.first.receiveControlMessages([accept])
    try pair.startMedia()
    return pair
}

private func testAudioGraphConfiguration(framesPerBuffer: Int) -> DirectPeerRealtimeAudioGraphConfiguration {
    DirectPeerRealtimeAudioGraphConfiguration(
        audioDeviceUID: "test-audio",
        sampleRateHertz: 48_000,
        framesPerBuffer: framesPerBuffer,
        channelCount: 2,
        sampleFormat: .float32LittleEndian,
        inputChannelMap: [0, 1],
        outputChannelMap: [0, 1]
    )
}

private func directPeerFragmentedRawAudioMode() throws -> AudioTransportMode {
    let fragments = try UdpPcmV2FragmentPlanner.plan(
        UdpPcmV2FragmentPlanRequest(
            streamID: 1,
            totalChannelCount: 64,
            framesPerPacket: 32,
            sampleRateHertz: 48_000,
            sampleFormat: .float32LittleEndian,
            maxTransmissionUnitBytes: 1_200,
            maxFragmentsPerDeadline: 16,
            metadataRevision: 1,
            packingMode: .interleavedChannelRange
        )
    )
    return AudioTransportMode(
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
}

private func directPeerUnexpectedVideoMediaPacket(sequenceNumber: UInt64) throws -> UdpMediaPacket {
    let frame = RawCapturedVideoFrame(
        metadata: CapturedVideoFrame(
            streamID: 1,
            sequenceNumber: sequenceNumber,
            timestampNanoseconds: 1_000 + sequenceNumber,
            timestampBasis: .hostUptimeNanoseconds,
            sourceRole: .avFoundationDevice,
            width: 2,
            height: 2,
            pixelFormat: "bgra8",
            frameRate: VideoFrameRate(numerator: 30, denominator: 1),
            fingerprint: "unexpected-video-\(sequenceNumber)"
        ),
        payload: Data(repeating: UInt8(sequenceNumber & 0xff), count: 16)
    )
    let fragment = try #require(RawVideoFrameTransport.fragments(for: frame, maxPacketBytes: 512).first)
    return UdpMediaPacket(
        header: UdpMediaPacketHeader(
            payloadType: .videoRawFrameFragment,
            streamID: fragment.streamID,
            sequenceNumber: fragment.frameSequenceNumber,
            timestampNanoseconds: fragment.timestampNanoseconds
        ),
        payload: try fragment.encoded()
    )
}

private func directPeerUnexpectedAudioMediaPacket(
    runner: PeerSessionRunner,
    sequenceNumber: UInt64
) throws -> UdpMediaPacket {
    let packet = try #require(runner.makeAudioPackets(streamID: 1, sequenceNumber: sequenceNumber).first)
    return UdpMediaPacket(
        header: UdpMediaPacketHeader(
            payloadType: .audioPcmV2,
            streamID: packet.header.streamID,
            sequenceNumber: packet.header.sequenceNumber,
            timestampNanoseconds: packet.header.senderHostTimeNanoseconds
        ),
        payload: try packet.encoded()
    )
}

private func directPeerAudioRXLoopState() -> DirectPeerAudioRXLoopState {
    DirectPeerAudioRXLoopState(
        rtpValidator: AES67ST2110L24RTPReceiveValidator(),
        aes67ClockMapper: DirectPeerAES67RTPHostTimeMapper(sampleRateHertz: 48_000),
        rawAudioReassembly: DirectPeerOpenLolaRawAudioReassemblyState()
    )
}
