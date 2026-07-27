// Shared peer session avruntime helpers keep related tests deterministic and focused on their contract.
import CoreGraphics
import Dispatch
import Foundation
import Testing

@testable import OpenLolaCore

func assertMalformedRawAudioPayloadDrops() throws {
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
}

func assertMalformedOpusAudioPayloadDrops() throws {
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

    let opusDecoder = try OpusCELTLowDelayDecoder(channelCount: 2)
    let opusResult = try runAudioRXLoop(
        runner: &opusPair.second,
        audioGraph: opusGraph,
        state: &opusAudioRXState,
        configuration: DirectPeerAudioRXLoopConfiguration(
            transport: .openLolaOpusCeltLowDelay,
            opusDecoder: opusDecoder,
            opusScratch: DirectPeerOpusSessionScratch(decodedByteCount: opusDecoder.outputPCMByteCount),
            maxPackets: 4
        )
    )

 #expect(opusResult.queuedForPlayout == 0)
 #expect(opusResult.droppedBeforePlayout == 1)
}

func assertMalformedAES67PayloadDrops() throws {
 var aes67Pair = try startedAVLoopbackPair(
        audioTransport: .aes67ST2110L24,
        framesPerPacket: 48
    )
    defer {
        aes67Pair.first.shutdown(reason: "malformed aes67 test complete")
        aes67Pair.second.shutdown(reason: "malformed aes67 test complete")
    }
    try #require(aes67Pair.first.audioTransport).sendRawDatagram(try RTPPacket(
        header: RTPPacketHeader(sequenceNumber: 1, timestamp: 48, ssrc: 42),
        payload: Data([0x01, 0x02, 0x03])
    ).encoded())
    #expect(try aes67Pair.second.waitForIncomingMedia(timeoutMicroseconds: 50_000))
    let aes67Graph = try DirectPeerRealtimeAudioGraph(
        configuration: testAudioGraphConfiguration(framesPerBuffer: AES67ST2110L24Profile.framesPerPacket)
    )
    var aes67AudioRXState = directPeerAudioRXLoopState()

    let aes67Result = try runAudioRXLoop(
        runner: &aes67Pair.second,
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

func serviceDirectPeerAVMetricsUntilReceived(
 runner: inout PeerSessionRunner
) -> DirectPeerAVMetricsServiceResult {
 var nextMetricsPublish = UInt64.max
 var receive = DirectPeerAVMetricsServiceResult()
 let deadline = DispatchTime.now().uptimeNanoseconds + 50_000_000
 repeat {
 receive = serviceDirectPeerAVMetrics(
 runner: &runner,
 nextMetricsPublishTimeNanoseconds: &nextMetricsPublish,
 nowNanoseconds: 1
 )
 if receive.peerMetricsMessagesReceived > 0 {
 break
 }
 Thread.sleep(forTimeInterval: 0.001)
 } while DispatchTime.now().uptimeNanoseconds < deadline
 return receive
}

func assertMetricsReportPersistsTransportFields(pair: inout PeerSessionRunnerLoopbackPair) throws {
 let remote = SessionMetricsMessage(
 sessionID: try #require(pair.second.acceptedConfiguration).sessionID,
 delivery: .init(packetsLost: 4, jitterMicroseconds: 55, latePackets: 3,
                 callbackDurationP99Microseconds: 120, queueDepthPackets: 2),
 runtime: .init(cpuPercent: 8.5, memoryResidentBytes: 900_000,
                underruns: 1, overruns: 2, videoFramesDropped: 6)
    )
    pair.second.recordRemoteMetrics(remote)
    let control = try DirectPeerSessionControlSocket.bindLoopback()
    defer { control.close() }

    let report = try buildAVReport(
        configuration: directPeerAVSupportConfiguration(mediaSourceMode: .syntheticFixture),
        runner: pair.second,
        control: control,
        runtime: DirectPeerSessionAVRuntimeResult(
            metrics: publishedRuntimeMetrics(),
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

private func publishedRuntimeMetrics() -> DirectPeerSessionAVRuntimeMetrics {
    var metrics = DirectPeerSessionAVRuntimeMetrics()
    metrics.metricsMessagesPublished = 1
    metrics.peerMetricsMessagesReceived = 1
    return metrics
}
func directPeerAVSupportConfiguration(
    mediaSourceMode: DirectPeerSessionAVMediaSourceMode
) -> DirectPeerSessionAVRunConfiguration {
    var fixture = DirectPeerSyntheticAVFixture(manual: directPeerAVSupportManualConfiguration())
    fixture.audioDeviceUID = "input-a"
    fixture.inputDeviceUID = "input-a"
    fixture.outputDeviceUID = "output-b"
    fixture.videoWidth = 1_280
    fixture.videoHeight = 720
    fixture.rxBufferProfile = nil
    fixture.preview = .on
    fixture.mediaSourceMode = mediaSourceMode
    return fixture.configuration()
}

private func directPeerAVSupportManualConfiguration() -> DirectPeerSessionManualRunConfiguration {
    DirectPeerSessionManualRunConfiguration(
        identity: .init(role: .initiator, localPeerID: "peer-a", remotePeerID: "peer-b"),
        network: .init(
            localHost: "127.0.0.1",
            remoteHost: "127.0.0.1",
            ports: .init(controlPort: 10_001, remoteControlPort: 10_002, audioPort: 10_003, videoPort: 10_004, metricsPort: 10_005)
        ),
        tuning: .init(packetCount: 1, audioChannelCount: 2, timeoutSeconds: 1, dscp: nil)
    )
}

func startedAVLoopbackPair(
    audioTransport: DirectPeerSessionAudioTransport,
    framesPerPacket: Int
) throws -> PeerSessionRunnerLoopbackPair {
    var pair = try PeerSessionRunnerLoopbackPair.make()
    let firstHandshake = try pair.first.beginHandshake()
    let secondHandshake = try pair.second.beginHandshake()
    try pair.first.receiveControlMessages(secondHandshake)
    try pair.second.receiveControlMessages(firstHandshake)
    var request = PeerSessionAVProposalRequest()
    request.sampleRateHertz = 48_000
    request.framesPerPacket = framesPerPacket
    request.sampleFormat = .float32LittleEndian
    request.audioTransport = audioTransport
    request.audioChannelCount = 2
    request.videoWidth = 16
    request.videoHeight = 16
    request.videoFrameRate = 30
    let proposal = try pair.first.makeAudioVideoSessionProposal(request)
    let accept = try pair.second.acceptProposal(proposal, proposerCapabilities: pair.first.localCapabilities)
    try pair.first.receiveControlMessages([accept])
    try pair.startMedia()
    return pair
}

func testAudioGraphConfiguration(framesPerBuffer: Int) -> DirectPeerRealtimeAudioGraphConfiguration {
    DirectPeerRealtimeAudioGraphConfiguration(
            devices: .init(audioDeviceUID: "test-audio", inputDeviceUID: nil, outputDeviceUID: nil),
            format: .init(sampleRateHertz: 48_000, framesPerBuffer: framesPerBuffer, channelCount: 2, sampleFormat: .float32LittleEndian),
            channelMaps: .init(input: [0, 1], output: [0, 1]),
            buffering: .init(ringCapacityBlocks: 8, rxBufferPolicy: nil)
        )
}

func directPeerUnexpectedVideoMediaPacket(sequenceNumber: UInt64) throws -> UdpMediaPacket {
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

func directPeerUnexpectedAudioMediaPacket(
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

func directPeerAudioRXLoopState() -> DirectPeerAudioRXLoopState {
    DirectPeerAudioRXLoopState(
        rtpValidator: AES67ST2110L24RTPReceiveValidator(),
        aes67ClockMapper: DirectPeerAES67RTPHostTimeMapper(sampleRateHertz: 48_000),
        rawAudioReassembly: DirectPeerOpenLolaRawAudioReassemblyState()
    )
}
