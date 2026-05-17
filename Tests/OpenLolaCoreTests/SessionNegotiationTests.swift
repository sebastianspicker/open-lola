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

private func referencePeerA() -> PeerIdentity {
    PeerIdentity(
        peerID: "peer-a",
        displayName: "Reference Mac A",
        implementationName: "open-lola",
        implementationVersion: "0.0.0-m02"
    )
}

private func referencePeerB() -> PeerIdentity {
    PeerIdentity(
        peerID: "peer-b",
        displayName: "Reference Mac B",
        implementationName: "open-lola",
        implementationVersion: "0.0.0-m02"
    )
}

private func referenceCapabilities(peer: PeerIdentity) -> CapabilitySet {
    CapabilitySet(
        peer: peer,
        supportedControlVersions: [SessionControlProtocol.currentVersion],
        audio: AudioTransportCapabilities(
            supportedProtocolVersions: [.udpPcmV2],
            channelSet: .defaultInput(count: 64),
            sampleRatesHertz: [48_000, 96_000],
            framesPerPacketOptions: [32, 64],
            sampleFormats: [.float32LittleEndian, .int16LittleEndian],
            maxTransmissionUnitBytes: 1_200,
            maxFragmentsPerDeadline: 16,
            latencyProfiles: [.safeLowLatency],
            rxBufferProfiles: [.direct, .small],
            supportsMatrixMetadata: true
        ),
        video: VideoCapabilities(
            supportedRoles: [.disabled, .blackmagicInput, .atemProgram],
            supportedPixelFormats: [.bgra8],
            supportedTransportFormats: [.disabled, .rawFrameFragment],
            maxWidth: 1_920,
            maxHeight: 1_080,
            maxFrameRateNumerator: 60,
            maxEnabledStreams: 2
        ),
        transport: SessionTransportCapabilities(
            supportsDirectUDP: true,
            supportsRendezvous: true,
            minMTUBytes: 576,
            maxMTUBytes: 1_200
        ),
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
        id: id,
        direction: .bidirectional,
        sampleRateHertz: sampleRateHertz,
        sampleFormat: sampleFormat,
        channelCount: 64,
        channelOrder: AudioChannelSet.defaultInput(count: 64).sortedByStableSourceIndex,
        clockDomain: "core-audio-device:reference-rme",
        framesPerPacket: 32,
        payloadType: .audioPcmV2
    )
}

private func referenceVideoStream(
    id: Int = 100,
    frameRateNumerator: Int = 60,
    frameRateDenominator: Int = 1
) -> VideoStreamDescription {
    VideoStreamDescription(
        id: id,
        direction: .send,
        role: .blackmagicInput,
        resolution: VideoResolution(width: 1_920, height: 1_080),
        frameRate: VideoFrameRate(numerator: frameRateNumerator, denominator: frameRateDenominator),
        pixelFormat: .bgra8,
        transportFormat: .rawFrameFragment,
        sourceLabel: "Blackmagic input",
        payloadType: .videoRawFrameFragment
    )
}

private func referenceProposal(
    audio: AudioStreamDescription,
    video: [VideoStreamDescription],
    latencyProfile: SessionLatencyProfile = .directAudioFirst,
    rxBufferProfile: RxBufferProfile = .direct
) -> SessionProposal {
    SessionProposal(
        sessionID: "session-001",
        proposer: referencePeerA(),
        responder: referencePeerB(),
        latencyProfile: latencyProfile,
        rxBufferProfile: rxBufferProfile,
        audioStreams: [audio],
        videoStreams: video,
        controlEndpoint: SessionNetworkEndpoint(host: "192.0.2.10", port: 41_000),
        audioEndpoint: SessionNetworkEndpoint(host: "192.0.2.10", port: 41_001),
        videoEndpoint: SessionNetworkEndpoint(host: "192.0.2.10", port: 41_002),
        metricsEndpoint: SessionNetworkEndpoint(host: "192.0.2.10", port: 41_003),
        mtuBytes: 1_200
    )
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
