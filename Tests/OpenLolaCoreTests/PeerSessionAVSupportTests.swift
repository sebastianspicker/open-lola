import CoreGraphics
import Dispatch
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func directPeerSessionAVConfigurationCarriesSeparateAudioDevices() throws {
    let manual = DirectPeerSessionManualRunConfiguration(
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
    )
    let configuration = DirectPeerSessionAVRunConfiguration(
        manual: manual,
        durationSeconds: 1,
        audioDeviceUID: "input-a",
        inputDeviceUID: "input-a",
        outputDeviceUID: "output-b",
        videoDeviceID: "synthetic-test-device",
        mediaSourceMode: .syntheticFixture
    )

    #expect(configuration.audioDeviceUID == "input-a")
    #expect(configuration.inputDeviceUID == "input-a")
    #expect(configuration.outputDeviceUID == "output-b")
}

@Test
func directPeerPreviewOnUsesVisibleSinkForProductionAndTestSinkForSyntheticFixture() {
    let syntheticSink = makeDirectPeerPreviewSink(for: directPeerAVSupportConfiguration(mediaSourceMode: .syntheticFixture))
    let productionSink = makeDirectPeerPreviewSink(for: directPeerAVSupportConfiguration(mediaSourceMode: .production))

    #expect(syntheticSink is RawBGRATestablePreviewSink)
    #expect(productionSink is RawBGRAAppKitPreviewWindow)
}

@Test
func directPeerOpenLolaRawAudioReassemblyWaitsForCompleteFragmentSet() throws {
    var state = DirectPeerOpenLolaRawAudioReassemblyState()
    let mode = try directPeerFragmentedRawAudioMode()
    let payload = Data(repeating: 0x7d, count: mode.framesPerPacket * mode.channelCount * mode.sampleFormat.bytesPerSample)
    let packets = try UdpPcmV2Packetizer.packetize(
        payload,
        sequenceNumber: 11,
        senderFrameIndex: 352,
        senderHostTimeNanoseconds: 99_000,
        mode: mode
    )

    #expect(packets.count > 1)
    for packet in packets.dropLast() {
        #expect(try state.receive(packet) == nil)
    }
    let lastPacket = try #require(packets.last)
    let block = try #require(try state.receive(lastPacket))

    #expect(block.payload == payload)
    #expect(block.senderFrameIndex == 352)
    #expect(block.senderHostTimeNanoseconds == 99_000)
}

@Test
func directPeerOpenLolaRawAudioReassemblyRejectsFragmentCountsAboveNegotiatedCap() throws {
    var state = DirectPeerOpenLolaRawAudioReassemblyState(maxFragmentCount: 2)
    let mode = try directPeerFragmentedRawAudioMode()
    let payload = Data(repeating: 0x7d, count: mode.framesPerPacket * mode.channelCount * mode.sampleFormat.bytesPerSample)
    var packet = try #require(UdpPcmV2Packetizer.packetize(
        payload,
        sequenceNumber: 12,
        senderFrameIndex: 384,
        senderHostTimeNanoseconds: 99_001,
        mode: mode
    ).first)
    packet.header.fragmentCount = UInt16.max

    #expect(throws: UdpPcmV2FragmentReassemblyError.fragmentCountExceedsLimit(actual: UInt16.max, max: 2)) {
        _ = try state.receive(packet)
    }
}

@Test
func directPeerOpenLolaRawAudioReassemblyAccountsIncompleteNormalTrafficDeadline() throws {
    var state = DirectPeerOpenLolaRawAudioReassemblyState(maxPendingDeadlines: 1)
    let mode = try directPeerFragmentedRawAudioMode()
    let payload = Data(repeating: 0x7d, count: mode.framesPerPacket * mode.channelCount * mode.sampleFormat.bytesPerSample)
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

    #expect(try state.receive(try #require(firstDeadline.first)) == nil)
    #expect(state.consumeDroppedIncompleteDeadlines() == 0)
    #expect(try state.receive(try #require(secondDeadline.first)) == nil)
    #expect(state.consumeDroppedIncompleteDeadlines() == 1)
}

@Test
func directPeerOpenLolaRawAudioReassemblyKeepsAdjacentReorderedDeadlines() throws {
    var state = DirectPeerOpenLolaRawAudioReassemblyState(maxPendingDeadlines: 2)
    let mode = try directPeerFragmentedRawAudioMode()
    let firstPayload = Data(repeating: 0x7d, count: mode.framesPerPacket * mode.channelCount * mode.sampleFormat.bytesPerSample)
    let secondPayload = Data(repeating: 0x7e, count: mode.framesPerPacket * mode.channelCount * mode.sampleFormat.bytesPerSample)
    let firstDeadline = try UdpPcmV2Packetizer.packetize(
        firstPayload,
        sequenceNumber: 16,
        senderFrameIndex: 512,
        senderHostTimeNanoseconds: 99_005,
        mode: mode
    )
    let secondDeadline = try UdpPcmV2Packetizer.packetize(
        secondPayload,
        sequenceNumber: 17,
        senderFrameIndex: 544,
        senderHostTimeNanoseconds: 99_006,
        mode: mode
    )

    #expect(firstDeadline.count > 1)
    #expect(secondDeadline.count > 1)
    #expect(try state.receive(try #require(firstDeadline.first)) == nil)
    #expect(try state.receive(try #require(secondDeadline.first)) == nil)
    for packet in firstDeadline.dropFirst().dropLast() {
        #expect(try state.receive(packet) == nil)
    }
    let firstLast = try #require(firstDeadline.last)
    let firstBlock = try #require(try state.receive(firstLast))
    for packet in secondDeadline.dropFirst().dropLast() {
        #expect(try state.receive(packet) == nil)
    }
    let secondLast = try #require(secondDeadline.last)
    let secondBlock = try #require(try state.receive(secondLast))

    #expect(firstBlock.payload == firstPayload)
    #expect(secondBlock.payload == secondPayload)
    #expect(state.consumeDroppedIncompleteDeadlines() == 0)
}

@Test
func directPeerOpenLolaRawAudioReassemblyFlushesFinalIncompleteDeadline() throws {
    var state = DirectPeerOpenLolaRawAudioReassemblyState()
    let mode = try directPeerFragmentedRawAudioMode()
    let payload = Data(repeating: 0x7d, count: mode.framesPerPacket * mode.channelCount * mode.sampleFormat.bytesPerSample)
    let packets = try UdpPcmV2Packetizer.packetize(
        payload,
        sequenceNumber: 15,
        senderFrameIndex: 480,
        senderHostTimeNanoseconds: 99_004,
        mode: mode
    )

    #expect(try state.receive(try #require(packets.first)) == nil)
    #expect(state.flushIncomplete() == 1)
    #expect(state.flushIncomplete() == 0)
}

@Test
func directPeerAVRXUsesTransportDecodedPayloadsOnce() throws {
    let audioLoopSource = try readPeerSessionAVSupportRepositoryText(
        "Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVAudioLoops.swift"
    )
    let runnerSource = try readPeerSessionAVSupportRepositoryText(
        "Sources/OpenLolaCore/Network/P2P/PeerSessionRunnerMediaIO.swift"
    )
    let videoLoopSource = try readPeerSessionAVSupportRepositoryText(
        "Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVVideoLoops.swift"
    )
    let transportSource = try readPeerSessionAVSupportRepositoryText(
        "Sources/OpenLolaCore/Network/UDP/UdpMediaTransport.swift"
    )

    #expect(audioLoopSource.contains("receiveDecodedAudioMediaPacketIfAvailable()"))
    #expect(!audioLoopSource.contains("UdpPcmV2Packet.decode(packet.payload)"))
    #expect(videoLoopSource.contains("receiveDecodedVideoMediaPacketIfAvailable()"))
    #expect(!videoLoopSource.contains("VideoTransportFragment.decode(packet.payload)"))
    #expect(runnerSource.contains("receiveDecoded(maxByteCount: mediaReceiveByteBudget)"))
    #expect(runnerSource.contains("tryReceiveDecoded(maxByteCount: mediaReceiveByteBudget)"))
    #expect(runnerSource.contains("peerSessionMediaReceiveByteBudget(acceptedConfiguration: acceptedConfiguration)"))
    #expect(!runnerSource.contains("try UdpPcmV2Packet.decode(packet.payload)"))
    #expect(!runnerSource.contains("try VideoTransportFragment.decode(packet.payload)"))
    #expect(transportSource.contains("decodeWithNestedPayload"))
}

@Test
func directPeerAVAudioRXCountsMalformedMediaEnvelopeAsDrop() throws {
    var pair = try startedAVLoopbackPair(
        audioTransport: .openLolaRaw,
        framesPerPacket: 32
    )
    defer {
        try? pair.first.shutdown(reason: "malformed audio envelope test complete")
        try? pair.second.shutdown(reason: "malformed audio envelope test complete")
    }
    try #require(pair.first.audioTransport).sendRawDatagram(Data([0x00, 0x01, 0x02]))
    _ = try pair.second.waitForIncomingMedia(timeoutMicroseconds: 50_000)
    let graph = DirectPeerRealtimeAudioGraph(
        configuration: testAudioGraphConfiguration(framesPerBuffer: 32)
    )
    var rtpValidator = AES67ST2110L24RTPReceiveValidator()
    var clockMapper = DirectPeerAES67RTPHostTimeMapper(sampleRateHertz: 48_000)
    var rawReassembly = DirectPeerOpenLolaRawAudioReassemblyState()

    let result = try runAudioRXLoop(
        runner: &pair.second,
        audioGraph: graph,
        transport: .openLolaRaw,
        opusDecoder: nil,
        rtpValidator: &rtpValidator,
        aes67ClockMapper: &clockMapper,
        rawAudioReassembly: &rawReassembly,
        maxPackets: 4
    )

    #expect(result.queuedForPlayout == 0)
    #expect(result.droppedBeforePlayout == 1)
    #expect(pair.second.transportMetrics().malformedPackets == 1)
}

@Test
func directPeerAVAudioRXCountsMalformedOpusPayloadAsDrop() throws {
    var pair = try startedAVLoopbackPair(
        audioTransport: .openLolaOpusCeltLowDelay,
        framesPerPacket: OpusCELTLowDelayConstants.frameCount
    )
    defer {
        try? pair.first.shutdown(reason: "malformed opus test complete")
        try? pair.second.shutdown(reason: "malformed opus test complete")
    }
    try pair.first.sendOpusAudioPayload(
        Data([0xff]),
        sequenceNumber: 1,
        senderFrameIndex: 0,
        hostTimeNanoseconds: 1,
        channelCount: 2
    )
    _ = try pair.second.waitForIncomingMedia(timeoutMicroseconds: 50_000)
    let graph = DirectPeerRealtimeAudioGraph(
        configuration: testAudioGraphConfiguration(framesPerBuffer: OpusCELTLowDelayConstants.frameCount)
    )
    var rtpValidator = AES67ST2110L24RTPReceiveValidator()
    var clockMapper = DirectPeerAES67RTPHostTimeMapper(sampleRateHertz: 48_000)
    var rawReassembly = DirectPeerOpenLolaRawAudioReassemblyState()

    let result = try runAudioRXLoop(
        runner: &pair.second,
        audioGraph: graph,
        transport: .openLolaOpusCeltLowDelay,
        opusDecoder: try OpusCELTLowDelayDecoder(channelCount: 2),
        rtpValidator: &rtpValidator,
        aes67ClockMapper: &clockMapper,
        rawAudioReassembly: &rawReassembly,
        maxPackets: 4
    )

    #expect(result.queuedForPlayout == 0)
    #expect(result.droppedBeforePlayout == 1)
}

@Test
func directPeerAVVideoRXCountsMalformedMediaEnvelopeAsCorruptDrop() throws {
    var pair = try startedAVLoopbackPair(
        audioTransport: .openLolaRaw,
        framesPerPacket: 32
    )
    defer {
        try? pair.first.shutdown(reason: "malformed video envelope test complete")
        try? pair.second.shutdown(reason: "malformed video envelope test complete")
    }
    try #require(pair.first.videoTransport).sendRawDatagram(Data([0x10, 0x20, 0x30]))
    _ = try pair.second.waitForIncomingMedia(timeoutMicroseconds: 50_000)
    var reassembler = VideoFrameReassembler()
    var deferredFrame: RawCapturedVideoFrame?

    let result = try runVideoRXLoop(
        runner: &pair.second,
        reassembler: &reassembler,
        previewSink: nil,
        playoutAnchor: DirectPeerAVPlayoutAnchor(policy: .policy(for: .directAudioFirst)),
        deferredFrame: &deferredFrame,
        compression: .raw,
        maxPackets: 4
    )

    #expect(result.fragmentsReceived == 0)
    #expect(result.fragmentsDroppedCorrupt == 1)
    #expect(pair.second.videoTransportMetrics?.malformedPackets == 1)
}

@Test
func directPeerAVAudioRXCountsMalformedAES67PacketAsDrop() throws {
    var sender = try PeerSessionRunner.localhost(peerID: "peer-a", remotePeerID: "peer-b")
    var receiver = try PeerSessionRunner.localhost(peerID: "peer-b", remotePeerID: "peer-a")
    defer {
        try? sender.shutdown(reason: "malformed aes67 test complete")
        try? receiver.shutdown(reason: "malformed aes67 test complete")
    }
    try #require(sender.audioTransport).connect(to: receiver.localEndpoints.audioEndpoint)
    try #require(sender.audioTransport).sendRawDatagram(try RTPPacket(
        header: RTPPacketHeader(sequenceNumber: 1, timestamp: 48, ssrc: 42),
        payload: Data([0x01, 0x02, 0x03])
    ).encoded())
    _ = try receiver.waitForIncomingMedia(timeoutMicroseconds: 50_000)
    let graph = DirectPeerRealtimeAudioGraph(
        configuration: testAudioGraphConfiguration(framesPerBuffer: AES67ST2110L24Profile.framesPerPacket)
    )
    var rtpValidator = AES67ST2110L24RTPReceiveValidator()
    var clockMapper = DirectPeerAES67RTPHostTimeMapper(sampleRateHertz: 48_000)
    var rawReassembly = DirectPeerOpenLolaRawAudioReassemblyState()

    let result = try runAudioRXLoop(
        runner: &receiver,
        audioGraph: graph,
        transport: .aes67ST2110L24,
        opusDecoder: nil,
        rtpValidator: &rtpValidator,
        aes67ClockMapper: &clockMapper,
        rawAudioReassembly: &rawReassembly,
        maxPackets: 4
    )

    #expect(result.queuedForPlayout == 0)
    #expect(result.droppedBeforePlayout == 1)
}

@Test
func directPeerAVAudioRXRecoversAfterAES67ForwardGap() throws {
    var sender = try PeerSessionRunner.localhost(peerID: "peer-a", remotePeerID: "peer-b")
    var receiver = try PeerSessionRunner.localhost(peerID: "peer-b", remotePeerID: "peer-a")
    defer {
        try? sender.shutdown(reason: "aes67 gap recovery test complete")
        try? receiver.shutdown(reason: "aes67 gap recovery test complete")
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
    let graph = DirectPeerRealtimeAudioGraph(
        configuration: testAudioGraphConfiguration(framesPerBuffer: AES67ST2110L24Profile.framesPerPacket)
    )
    var rtpValidator = AES67ST2110L24RTPReceiveValidator()
    var clockMapper = DirectPeerAES67RTPHostTimeMapper(sampleRateHertz: 48_000)
    var rawReassembly = DirectPeerOpenLolaRawAudioReassemblyState()

    let result = try runAudioRXLoop(
        runner: &receiver,
        audioGraph: graph,
        transport: .aes67ST2110L24,
        opusDecoder: nil,
        rtpValidator: &rtpValidator,
        aes67ClockMapper: &clockMapper,
        rawAudioReassembly: &rawReassembly,
        maxPackets: 4
    )

    #expect(result.queuedForPlayout == 2)
    #expect(result.rtpPacketsLost == 1)
    #expect(result.droppedBeforePlayout == 1)
}

@Test
func directPeerAVMetricsServicePublishesAndDrainsPeerMetrics() throws {
    var pair = try PeerSessionRunnerLoopbackPair.make()
    defer {
        try? pair.first.shutdown(reason: "metrics service test complete")
        try? pair.second.shutdown(reason: "metrics service test complete")
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
}

@Test
func directPeerAVReportPersistsMetricsTransportFields() throws {
    var pair = try PeerSessionRunnerLoopbackPair.make()
    defer {
        try? pair.first.shutdown(reason: "metrics report test complete")
        try? pair.second.shutdown(reason: "metrics report test complete")
    }
    try pair.negotiate()
    try pair.startMedia()
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

    #expect(report.metrics.remoteMetricsMessagesReceived == 1)
    #expect(report.metrics.remotePacketsLost == 4)
    #expect(report.metrics.remoteJitterMicroseconds == 55)
    #expect(report.metrics.remoteQueueDepthPackets == 2)
    #expect(report.metrics.remoteVideoFramesDropped == 6)
}

@Test
func directPeerAudioReceivePathDoesNotDecodeVideoFragments() throws {
    let source = try readPeerSessionAVSupportRepositoryText(
        "Sources/OpenLolaCore/Network/P2P/PeerSessionRunnerMediaIO.swift"
    )
    let audioHelper = try #require(source.range(of: "private mutating func recordReceivedAudioOrTiming"))
    let helperSource = String(source[audioHelper.lowerBound..<source.endIndex])

    #expect(source.contains("""
public mutating func receiveMediaPacket() throws -> UdpMediaPacket {
        try receiveAudioMediaPacket()
    }
"""))
    #expect(!helperSource.contains("VideoTransportFragment.decode"))
    #expect(!helperSource.contains("videoPacketsRouted"))
}

@Test
func directPeerAcceptedVideoStreamComparesFrameRatesAsRationals() throws {
    let source = try readPeerSessionAVSupportRepositoryText(
        "Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVSocketRunner.swift"
    )

    #expect(source.contains("private func acceptedVideoFrameRateMatchesConfiguration"))
    #expect(source.contains("stream.frameRate.numerator == configuration.videoFrameRate * stream.frameRate.denominator"))
    #expect(!source.contains("stream.frameRate.denominator == 1"))
}

@Test
func directPeerAudioPollIntervalDocumentsTwicePerPacketPeriod() throws {
    let source = try readPeerSessionAVSupportRepositoryText(
        "Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVSocketRunner.swift"
    )

    #expect(source.contains("let audioPollsPerPacketPeriod = 2"))
    #expect(source.contains("Poll twice per audio packet period"))
    #expect(source.contains("/ audioPollsPerPacketPeriod"))
}

@Test
func directPeerVideoReceiveDrainPacketLimitDocumentsAudioStarvationBoundary() throws {
    let source = try readPeerSessionAVSupportRepositoryText(
        "Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVSocketRunner.swift"
    )

    #expect(source.contains("let videoReceiveDrainPacketLimit = 2_048"))
    #expect(source.contains("fragment burst cannot starve"))
    #expect(source.contains("audio polling; 2048 fragments still covers multiple jumbo raw frames"))
    #expect(source.contains("maxPackets: videoReceiveDrainPacketLimit"))
}

private func readPeerSessionAVSupportRepositoryText(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
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

@Test
func directPeerAVLoopWaitUsesEarliestMediaDeadline() {
    let now: UInt64 = 1_000_000

    #expect(directPeerAVLoopWaitTimeoutMicroseconds(
        nowNanoseconds: now,
        deadlineNanoseconds: now + 10_000_000,
        audioPollIntervalMicroseconds: 5_000,
        nextVideoFrameTimeNanoseconds: now + 2_000,
        nextMetricsPublishTimeNanoseconds: now + 9_000_000
    ) == 2)
    #expect(directPeerAVLoopWaitTimeoutMicroseconds(
        nowNanoseconds: now,
        deadlineNanoseconds: now + 10_000_000,
        audioPollIntervalMicroseconds: 250,
        nextVideoFrameTimeNanoseconds: now + 9_000_000,
        nextMetricsPublishTimeNanoseconds: now + 8_000_000
    ) == 250)
    #expect(directPeerAVLoopWaitTimeoutMicroseconds(
        nowNanoseconds: now,
        deadlineNanoseconds: now,
        audioPollIntervalMicroseconds: 250,
        nextVideoFrameTimeNanoseconds: now + 9_000_000,
        nextMetricsPublishTimeNanoseconds: now + 8_000_000
    ) == 1)
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
    try pair.first.startMedia()
    try pair.second.startMedia()
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
