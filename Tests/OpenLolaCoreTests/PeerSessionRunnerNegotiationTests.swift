// Verifies that direct peer session loopback and socket runner exchange media over UDP.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func directPeerSessionLoopbackAndSocketRunnerExchangeMediaOverUdp() throws {
    let result = try DirectP2PLocalhostSmoke.run(packetCount: 3)
    try result.report.validate()
    #expect(result.first.state == .closed)
    #expect(result.second.state == .closed)
    #expect(result.report.configuration.peerMediaEndpoints?.count == 2)
    #expect(result.report.metrics.packetsSent == 3)
    #expect(result.report.metrics.packetsReceived == 3)
    #expect(result.report.metrics.audioPacketsRouted == 3)
    #expect(result.report.metrics.controlMessagesSent > 0)
    #expect(result.report.metrics.audioPayloadsSentOnControlChannel == 0)
    #expect(result.report.verdict == .partial)

    let report = try DirectPeerSessionSocketRunner.runLoopback(packetCount: 4)
    try report.validate()
    #expect(report.configuration.peerMediaEndpoints?.count == 2)
    #expect(report.metrics.controlDatagramsSent == 10)
    #expect(report.metrics.controlDatagramsReceived == 10)
    #expect(report.metrics.controlMessagesSent == 10)
    #expect(report.metrics.audioMetadataMessagesSent == 2)
    #expect(report.metrics.audioMetadataMessagesReceived == 2)
    #expect(report.metrics.timingProbePacketsSent == 2)
    #expect(report.metrics.timingProbePacketsReceived == 2)
    #expect(report.metrics.timingProbeMaxAgeMicroseconds >= 0)
    #expect(report.metrics.packetsSent == 4)
    #expect(report.metrics.packetsReceived == 4)
    #expect(report.metrics.audioPacketsRouted == 4)
    #expect(report.metrics.audioPayloadsSentOnControlChannel == 0)
    #expect(report.verdict == .partial)
}

@Test
func directPeerSessionAudioVideoProposalNegotiatesProfilesAndCompression() throws {
    let balancedConfiguration = try negotiatedAudioVideoConfiguration(NegotiatedAudioVideoConfigurationFixture(
            sampleRateHertz: 48_000,
            framesPerPacket: 32,
            sampleFormat: .float32LittleEndian,
            audioChannelCount: 2,
            videoStreamID: 120,
            videoWidth: 1_280,
            videoHeight: 720,
            videoPixelFormat: "bgra8",
            videoFrameRate: 60,
            videoCompression: .raw,
            avProfile: .balanced
        ))
    #expect(balancedConfiguration.latencyProfile == .balancedAV)
    #expect(balancedConfiguration.rxBufferProfile == .small)
    #expect(balancedConfiguration.audioStreams.first?.direction == .bidirectional)
    #expect(balancedConfiguration.audioStreams.first?.sampleFormat == .float32LittleEndian)
    #expect(balancedConfiguration.videoStreams.count == 1)
    #expect(balancedConfiguration.videoStreams[0].id == 120)
    #expect(balancedConfiguration.videoStreams[0].role == .avFoundationDevice)
    #expect(balancedConfiguration.videoStreams[0].resolution == VideoResolution(width: 1_280, height: 720))
    #expect(balancedConfiguration.videoStreams[0].frameRate == VideoFrameRate(numerator: 60, denominator: 1))
    #expect(balancedConfiguration.videoStreams[0].pixelFormat == .bgra8)
    #expect(balancedConfiguration.videoStreams[0].transportFormat == .rawFrameFragment)
    #expect(balancedConfiguration.videoStreams[0].payloadType == .videoRawFrameFragment)
    #expect(balancedConfiguration.peerMediaEndpoints?.count == 2)

    let jpegXSConfiguration = try negotiatedAudioVideoConfiguration(NegotiatedAudioVideoConfigurationFixture(
            audioChannelCount: 2,
            videoStreamID: 121,
            videoCompression: .jpegXS,
            avProfile: .balanced
        ))

    #expect(jpegXSConfiguration.videoStreams[0].transportFormat == .jpegXSFrameFragment)
    #expect(jpegXSConfiguration.videoStreams[0].payloadType == .videoJpegXSFrameFragment)

    let fastestConfiguration = try negotiatedAudioVideoConfiguration(NegotiatedAudioVideoConfigurationFixture(
            sampleRateHertz: 48_000,
            framesPerPacket: 32,
            sampleFormat: .float32LittleEndian,
            audioChannelCount: 2,
            videoStreamID: 120,
            videoFrameRate: 30,
            videoCompression: .raw,
            avProfile: .fastest
        ))

    #expect(fastestConfiguration.latencyProfile == .directAudioFirst)
    #expect(fastestConfiguration.rxBufferProfile == .direct)
    #expect(fastestConfiguration.audioStreams.first?.framesPerPacket == 32)
}

@Test
// swiftlint:disable:next function_body_length
func directPeerVideoHelpersRejectUnsafeOrOutOfRangeInputs() throws {
    #expect(try nextDirectPeerVideoSequence(after: 1) == 2)
    #expect(throws: DirectPeerSessionAVRuntimeError.videoSequenceExhausted) {
        _ = try nextDirectPeerVideoSequence(after: UInt64.max)
    }

    let manual = DirectPeerManualTestFixture().configuration()
    var fixture = DirectPeerSyntheticAVFixture(manual: manual)
    fixture.videoWidth = 1_280
    fixture.videoHeight = 720
    fixture.rxBufferProfile = .small
    let configuration = fixture.configuration()

    #expect(throws: DirectPeerSessionAVRuntimeError.unsafeRawVideoPacketBudget(
        estimatedFragmentsPerFrame: 3_468,
        maxFragmentsPerFrame: 512
    )) {
        _ = try DirectPeerVideoPacketBudget.validate(configuration)
    }

    var anchor = DirectPeerAVPlayoutAnchor(policy: .policy(for: .balancedAV))
    anchor.observeAudio(hostTimeNanoseconds: 1_000_000_000)

    #expect(directPeerVideoSyncDecision(
        videoTimestampNanoseconds: 1_010_000_000,
        playoutAnchor: anchor
    )?.action == .renderNow)
    #expect(directPeerVideoSyncDecision(
        videoTimestampNanoseconds: 1_030_000_000,
        playoutAnchor: anchor
    )?.action == .deferVideo)
    #expect(directPeerVideoSyncDecision(
        videoTimestampNanoseconds: 950_000_000,
        playoutAnchor: anchor
    )?.action == .dropVideo)
}

@Test
func directPeerAES67RTPHelpersMapWireWidthAndRejectUnsupportedClock() throws {
    var mapper = DirectPeerAES67RTPHostTimeMapper(sampleRateHertz: 48_000)

    let firstMapped = mapper.hostTimeNanoseconds(
        rtpTimestamp: 48_000,
        observedHostTimeNanoseconds: 1_000_000_000
    )
    let secondMapped = mapper.hostTimeNanoseconds(
        rtpTimestamp: 48_048,
        observedHostTimeNanoseconds: 9_000_000_000
    )
    let first = try #require(firstMapped)
    let second = try #require(secondMapped)

    #expect(first == 1_000_000_000)
    #expect(second == 1_001_000_000)

    var overflowMapper = DirectPeerAES67RTPHostTimeMapper(sampleRateHertz: 48_000)

    _ = overflowMapper.hostTimeNanoseconds(
        rtpTimestamp: 0,
        observedHostTimeNanoseconds: UInt64.max - 1
    )
    let overflowed = overflowMapper.hostTimeNanoseconds(
        rtpTimestamp: 48_000,
        observedHostTimeNanoseconds: 1
    )

    #expect(overflowed == nil)

    #expect(directPeerRTPSequenceNumber(65_535) == 65_535)
    #expect(directPeerRTPSequenceNumber(65_536) == 0)
    #expect(directPeerRTPSequenceNumber(65_537) == 1)

    #expect(try directPeerAES67RTPTimestamp(
        senderFrameIndex: 4_294_967_295,
        sampleRateHertz: AES67ST2110L24Profile.clockRateHertz
    ) == 4_294_967_295)
    #expect(try directPeerAES67RTPTimestamp(
        senderFrameIndex: 4_294_967_296,
        sampleRateHertz: AES67ST2110L24Profile.clockRateHertz
    ) == 0)
    #expect(throws: PeerSessionRunnerError.unsupportedRTPAudioClock(sampleRateHertz: 96_000)) {
        _ = try directPeerAES67RTPTimestamp(senderFrameIndex: 0, sampleRateHertz: 96_000)
    }
}

private struct NegotiatedAudioVideoConfigurationFixture {
    var sampleRateHertz = 48_000
    var framesPerPacket = 32
    var sampleFormat: UdpPcmSampleFormat = .float32LittleEndian
    var audioChannelCount: Int
    var videoStreamID: Int
    var videoWidth = 1_280
    var videoHeight = 720
    var videoPixelFormat = "bgra8"
    var videoFrameRate = 30
    var videoCompression: DirectPeerSessionVideoCompression
    var avProfile: DirectPeerSessionAVProfile
}

private func negotiatedAudioVideoConfiguration(
    _ fixture: NegotiatedAudioVideoConfigurationFixture
) throws -> SessionConfiguration {
    try negotiatedAudioVideoConfiguration(request: audioVideoProposalRequest(fixture))
}

func negotiatedAudioVideoConfiguration(
    request: PeerSessionAVProposalRequest
) throws -> SessionConfiguration {
    var pair = try PeerSessionRunnerLoopbackPair.make()
    _ = try pair.first.beginHandshake()
    try pair.second.receiveControlMessages(pair.first.controlTranscript)
    _ = try pair.second.beginHandshake()
    try pair.first.receiveControlMessages(pair.second.controlTranscript)

    let proposal = try pair.first.makeAudioVideoSessionProposal(request)
    let accept = try pair.second.acceptProposal(
        proposal,
        proposerCapabilities: pair.first.localCapabilities
    )
    try pair.first.receiveControlMessages([accept])
    return try #require(pair.first.acceptedConfiguration)
}

private func audioVideoProposalRequest(
    _ fixture: NegotiatedAudioVideoConfigurationFixture
) -> PeerSessionAVProposalRequest {
    var request = PeerSessionAVProposalRequest()
    request.sampleRateHertz = fixture.sampleRateHertz
    request.framesPerPacket = fixture.framesPerPacket
    request.sampleFormat = fixture.sampleFormat
    request.audioChannelCount = fixture.audioChannelCount
    request.videoStreamID = fixture.videoStreamID
    request.videoWidth = fixture.videoWidth
    request.videoHeight = fixture.videoHeight
    request.videoPixelFormat = fixture.videoPixelFormat
    request.videoCompression = fixture.videoCompression
    request.videoFrameRate = fixture.videoFrameRate
    request.avProfile = fixture.avProfile
    return request
}
