// Verifies that session negotiation accepts 64-channel audio, disabled video, and a reconnect deadline.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func sessionNegotiationAcceptsSixtyFourChannelAudioDisabledVideoAndReconnectDeadline() throws {
    let proposal = referenceProposal(
        audio: referenceAudioStream(sampleFormat: .float32LittleEndian),
        video: [.disabled(id: 100, sourceLabel: "video-disabled")]
    )

    let configuration = try SessionNegotiation.negotiate(
        proposal: proposal,
        proposerCapabilities: referenceCapabilities(peer: referencePeerA()),
        responderCapabilities: referenceCapabilities(peer: referencePeerB())
    )

    #expect(configuration.sessionID == "session-001")
    #expect(configuration.audioStreams.count == 1)
    #expect(configuration.audioStreams[0].channelCount == 64)
    #expect(configuration.audioStreams[0].sampleFormat == .float32LittleEndian)
    #expect(configuration.videoStreams[0].isEnabled == false)
    #expect(configuration.latencyProfile == .directAudioFirst)
    #expect(configuration.rxBufferProfile == .direct)
    #expect(configuration.mtuBytes == 1_200)
    #expect(configuration.reconnectDeadlineMilliseconds == 5_000)

    var deadlineProposal = referenceProposal(
        audio: referenceAudioStream(sampleFormat: .float32LittleEndian),
        video: [.disabled(id: 100, sourceLabel: "video-disabled")]
    )
    deadlineProposal.reconnectDeadlineMilliseconds = 7_500

    let deadlineConfiguration = try SessionNegotiation.negotiate(
        proposal: deadlineProposal,
        proposerCapabilities: referenceCapabilities(peer: referencePeerA()),
        responderCapabilities: referenceCapabilities(peer: referencePeerB())
    )

    #expect(deadlineConfiguration.reconnectDeadlineMilliseconds == 7_500)
}

@Test
// swiftlint:disable:next function_body_length
func sessionNegotiationRejectsUnsupportedAudioTransportContracts() {
    var proposal = referenceProposal(
        audio: referenceAudioStream(sampleRateHertz: 44_100),
        video: [.disabled(id: 100, sourceLabel: "video-disabled")]
    )

    #expect(throws: SessionValidationError.unsupportedSampleRate(44_100)) {
        _ = try SessionNegotiation.negotiate(
            proposal: proposal,
            proposerCapabilities: referenceCapabilities(peer: referencePeerA()),
            responderCapabilities: referenceCapabilities(peer: referencePeerB())
        )
    }

    var responder = referenceCapabilities(peer: referencePeerB())
    responder.audio.sampleFormats = [.int16LittleEndian]
    proposal = referenceProposal(
        audio: referenceAudioStream(sampleFormat: .float32LittleEndian),
        video: [.disabled(id: 100, sourceLabel: "video-disabled")]
    )

    #expect(throws: SessionValidationError.unsupportedSampleFormat(.float32LittleEndian)) {
        _ = try SessionNegotiation.negotiate(
            proposal: proposal,
            proposerCapabilities: referenceCapabilities(peer: referencePeerA()),
            responderCapabilities: responder
        )
    }

    var proposer = referenceCapabilities(peer: referencePeerA())
    responder = referenceCapabilities(peer: referencePeerB())
    proposer.transport.minMTUBytes = 1_400
    proposer.transport.maxMTUBytes = 1_500
    responder.transport.minMTUBytes = 1_000
    responder.transport.maxMTUBytes = 1_200

    #expect(throws: SessionValidationError.invalidMTURange(minimum: 1_400, maximum: 1_200)) {
        _ = try SessionNegotiation.negotiate(
            proposal: referenceProposal(
                audio: referenceAudioStream(),
                video: [.disabled(id: 100, sourceLabel: "video-disabled")]
            ),
            proposerCapabilities: proposer,
            responderCapabilities: responder
        )
    }

    proposal = referenceProposal(
        audio: referenceAudioStream(id: 7),
        video: [.disabled(id: 7, sourceLabel: "video-disabled")]
    )

    #expect(throws: SessionValidationError.duplicateStreamID(7)) {
        _ = try SessionNegotiation.negotiate(
            proposal: proposal,
            proposerCapabilities: referenceCapabilities(peer: referencePeerA()),
            responderCapabilities: referenceCapabilities(peer: referencePeerB())
        )
    }

    proposal = referenceProposal(
        audio: referenceAudioStream(id: 0),
        video: [.disabled(id: 100, sourceLabel: "video-disabled")]
    )

    #expect(throws: SessionValidationError.invalidStreamID(0)) {
        _ = try SessionNegotiation.negotiate(
            proposal: proposal,
            proposerCapabilities: referenceCapabilities(peer: referencePeerA()),
            responderCapabilities: referenceCapabilities(peer: referencePeerB())
        )
    }
}

@Test
// swiftlint:disable:next function_body_length
func sessionNegotiationEnforcesTransportSpecificAudioSampleQuanta() throws {
    var capabilities = referenceCapabilities(peer: referencePeerA())
    capabilities.audio.supportedPayloadTypes = [
        .audioPcmV2,
        .audioOpusCeltLowDelayFrame,
        .audioRtpL24
    ]
    capabilities.audio.supportedAudioTransports = [
        .openLolaRaw,
        .openLolaOpusCeltLowDelay,
        .aes67ST2110L24
    ]
    capabilities.audio.sampleRatesHertz = [48_000, 96_000]
    capabilities.audio.framesPerPacketOptions = [6, 8, 16, 32, 48, 64, 120]

    var responder = capabilities
    responder.peer = referencePeerB()
    let disabledVideo = [VideoStreamDescription.disabled(id: 100, sourceLabel: "video-disabled")]

    for framesPerPacket in [6, 48, 120] {
        var raw = referenceAudioStream()
        raw.framesPerPacket = framesPerPacket
        #expect(throws: SessionValidationError.unsupportedPayloadType(.audioPcmV2)) {
            _ = try SessionNegotiation.negotiate(
                proposal: referenceProposal(audio: raw, video: disabledVideo),
                proposerCapabilities: capabilities,
                responderCapabilities: responder
            )
        }
    }

    var opus = referenceAudioStream(sampleFormat: .float32LittleEndian)
    opus.payloadType = .audioOpusCeltLowDelayFrame
    opus.channelCount = 2
    opus.channelOrder = AudioChannelSet.defaultInput(count: 2).sortedByStableSourceIndex
    opus.framesPerPacket = 120
    _ = try SessionNegotiation.negotiate(
        proposal: referenceProposal(audio: opus, video: disabledVideo),
        proposerCapabilities: capabilities,
        responderCapabilities: responder
    )

    var rtp = opus
    rtp.payloadType = .audioRtpL24
    rtp.framesPerPacket = 48
    _ = try SessionNegotiation.negotiate(
        proposal: referenceProposal(audio: rtp, video: disabledVideo),
        proposerCapabilities: capabilities,
        responderCapabilities: responder
    )

    rtp.framesPerPacket = 32
    #expect(throws: SessionValidationError.unsupportedPayloadType(.audioRtpL24)) {
        _ = try SessionNegotiation.negotiate(
            proposal: referenceProposal(audio: rtp, video: disabledVideo),
            proposerCapabilities: capabilities,
            responderCapabilities: responder
        )
    }
}

@Test
func directAndBalancedProfilesNegotiateVideoWithinPolicy() throws {
    let directProposal = referenceProposal(
        audio: referenceAudioStream(),
        video: [referenceVideoStream()],
        latencyProfile: .directAudioFirst
    )

    let directConfiguration = try SessionNegotiation.negotiate(
        proposal: directProposal,
        proposerCapabilities: referenceCapabilities(peer: referencePeerA()),
        responderCapabilities: referenceCapabilities(peer: referencePeerB())
    )

    #expect(directConfiguration.latencyProfile == .directAudioFirst)
    #expect(directConfiguration.rxBufferProfile == .direct)
    #expect(directConfiguration.videoStreams.filter(\.isEnabled).count == 1)

    let balancedProposal = referenceProposal(
        audio: referenceAudioStream(),
        video: [referenceVideoStream(frameRateNumerator: 30_000, frameRateDenominator: 1_001)],
        latencyProfile: .balancedAV,
        rxBufferProfile: .small
    )

    let balancedConfiguration = try SessionNegotiation.negotiate(
        proposal: balancedProposal,
        proposerCapabilities: referenceCapabilities(peer: referencePeerA()),
        responderCapabilities: referenceCapabilities(peer: referencePeerB())
    )

    #expect(balancedConfiguration.videoStreams[0].isEnabled)
    #expect(balancedConfiguration.videoStreams[0].transportFormat == .rawFrameFragment)
    #expect(balancedConfiguration.videoStreams[0].frameRate.numerator == 30_000)
    #expect(balancedConfiguration.videoStreams[0].frameRate.denominator == 1_001)
    #expect(balancedConfiguration.latencyProfile == .balancedAV)
    #expect(balancedConfiguration.rxBufferProfile == .small)
}

@Test
func controlAcceptMessageRoundTripsWithConfiguration() throws {
    let configuration = try SessionNegotiation.negotiate(
        proposal: referenceProposal(
            audio: referenceAudioStream(),
            video: [.disabled(id: 100, sourceLabel: "video-disabled")]
        ),
        proposerCapabilities: referenceCapabilities(peer: referencePeerA()),
        responderCapabilities: referenceCapabilities(peer: referencePeerB())
    )
    let message = SessionControlMessage.sessionAccept(configuration)
    let decoded = try SessionControlCodec.decode(try SessionControlCodec.encode(message))

    #expect(decoded == message)
}

private func referenceCapabilities(peer: PeerIdentity) -> CapabilitySet {
    SessionNegotiationTestFixtures.capabilities(
        peer: peer,
        supportedVideoRoles: [.disabled, .blackmagicInput, .atemProgram],
        maxEnabledVideoStreams: 2,
        latencyProfiles: [.directAudioFirst, .balancedAV, .multiVideoPerformance, .wanStable],
        rxBufferProfiles: [.direct, .small, .adaptive, .stableWan]
    )
}

private func referenceAudioStream(
    id: Int = 1,
    sampleRateHertz: Int = 48_000,
    sampleFormat: UdpPcmSampleFormat = .float32LittleEndian
) -> AudioStreamDescription {
    AudioStreamDescription(
            identity: .init(id: id, direction: .bidirectional, clockDomain: "core-audio-device:reference-rme"),
            format: .init(sampleRateHertz: sampleRateHertz, sampleFormat: sampleFormat, channelCount: 64, channelOrder: AudioChannelSet.defaultInput(count: 64).sortedByStableSourceIndex),
            packet: .init(framesPerPacket: 32, payloadType: .audioPcmV2)
        )
}

private func referenceVideoStream(
    id: Int = 100,
    frameRateNumerator: Int = 60,
    frameRateDenominator: Int = 1
) -> VideoStreamDescription {
    VideoStreamDescription(
        identity: .init(
            id: id,
            direction: .send,
            role: .blackmagicInput,
            sourceLabel: "Blackmagic input",
            payloadType: .videoRawFrameFragment
        ),
        format: .init(
            resolution: .init(width: 1_920, height: 1_080),
            frameRate: .init(numerator: frameRateNumerator, denominator: frameRateDenominator),
            pixelFormat: .bgra8,
            transportFormat: .rawFrameFragment
        )
    )
}

private func referenceProposal(
    audio: AudioStreamDescription,
    video: [VideoStreamDescription],
    latencyProfile: SessionLatencyProfile = .directAudioFirst,
    rxBufferProfile: RxBufferProfile = .direct
) -> SessionProposal {
    SessionNegotiationTestFixtures.proposal(.init(
        sessionID: "session-001",
        proposer: referencePeerA(),
        responder: referencePeerB(),
        audio: audio,
        video: video,
        latencyProfile: latencyProfile,
        rxBufferProfile: rxBufferProfile
    ))
}

private func referencePeerMediaEndpoints(
    peerID: String,
    host: String = "192.0.2.10",
    portBase: UInt16
) -> SessionPeerMediaEndpoints {
    SessionPeerMediaEndpoints(
        peerID: peerID,
        controlEndpoint: SessionNetworkEndpoint(host: host, port: portBase),
        audioEndpoint: SessionNetworkEndpoint(host: host, port: portBase + 1),
        videoEndpoint: SessionNetworkEndpoint(host: host, port: portBase + 2),
        metricsEndpoint: SessionNetworkEndpoint(host: host, port: portBase + 3)
    )
}
