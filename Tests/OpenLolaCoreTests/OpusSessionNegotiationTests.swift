// Verifies that session negotiation accepts matching Opus direct AV audio stream.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func sessionNegotiationAcceptsMatchingOpusDirectAVAudioStream() throws {
    let proposal = opusSessionProposal(audio: opusAudioStream())

    let configuration = try SessionNegotiation.negotiate(
        proposal: proposal,
        proposerCapabilities: opusCapabilities(peerID: "peer-a"),
        responderCapabilities: opusCapabilities(peerID: "peer-b")
    )

    #expect(configuration.audioStreams[0].payloadType == .audioOpusCeltLowDelayFrame)
    #expect(configuration.audioStreams[0].framesPerPacket == 120)
    #expect(configuration.audioStreams[0].channelCount == 2)
}

@Test
func sessionNegotiationRejectsUnsupportedOpusAudioShape() {
    let proposal = opusSessionProposal(audio: opusAudioStream(framesPerPacket: 64))

    #expect(throws: OpusCELTLowDelayCodecError.invalidFrameCount(64)) {
        _ = try SessionNegotiation.negotiate(
            proposal: proposal,
            proposerCapabilities: opusCapabilities(peerID: "peer-a"),
            responderCapabilities: opusCapabilities(peerID: "peer-b")
        )
    }
}

@Test
func sessionNegotiationRejectsResponderWithoutOpusPayloadSupport() {
    let proposal = opusSessionProposal(audio: opusAudioStream())
    var responder = opusCapabilities(peerID: "peer-b")
    responder.audio.supportedPayloadTypes = [.audioPcmV2]

    #expect(throws: SessionValidationError.unsupportedPayloadType(.audioOpusCeltLowDelayFrame)) {
        _ = try SessionNegotiation.negotiate(
            proposal: proposal,
            proposerCapabilities: opusCapabilities(peerID: "peer-a"),
            responderCapabilities: responder
        )
    }
}

private func opusSessionProposal(audio: AudioStreamDescription) -> SessionProposal {
    SessionProposal(
        identity: .init(sessionID: "opus-session", proposer: opusPeer("peer-a"), responder: opusPeer("peer-b")),
        profile: .init(latencyProfile: .balancedAV, rxBufferProfile: .small),
        streams: .init(audioStreams: [audio], videoStreams: [.disabled(id: 100, sourceLabel: "video-disabled")]),
        endpoints: .init(control: .init(host: "192.0.2.10", port: 40_000), audio: .init(host: "192.0.2.10", port: 40_001),
                         video: .init(host: "192.0.2.10", port: 40_002), metrics: .init(host: "192.0.2.10", port: 40_003)),
        transport: .init(mtuBytes: 1_200)
    )
}

private func opusAudioStream(
    framesPerPacket: Int = 120,
    channelCount: Int = 2
) -> AudioStreamDescription {
    AudioStreamDescription(
            identity: .init(id: 1, direction: .bidirectional, clockDomain: "core-audio-device:opus-test"),
            format: .init(sampleRateHertz: 48_000, sampleFormat: .float32LittleEndian, channelCount: channelCount, channelOrder: Array(AudioChannelSet.defaultInput(count: channelCount).sortedByStableSourceIndex)),
            packet: .init(framesPerPacket: framesPerPacket, payloadType: .audioOpusCeltLowDelayFrame)
        )
}

private func opusCapabilities(peerID: String) -> CapabilitySet {
    CapabilitySet(
        peer: opusPeer(peerID),
        supportedControlVersions: [SessionControlProtocol.currentVersion],
        audio: AudioTransportCapabilities(
            transport: .init(protocolVersions: [.udpPcmV2], payloadTypes: [.audioPcmV2, .audioOpusCeltLowDelayFrame], audioTransports: [.openLolaRaw, .openLolaOpusCeltLowDelay]),
            audio: .init(channelSet: .defaultInput(count: 2), sampleRatesHertz: [48_000], framesPerPacketOptions: [32, 64, 120], sampleFormats: [.float32LittleEndian]),
            limits: .init(maxTransmissionUnitBytes: 1_200, maxFragmentsPerDeadline: 16, latencyProfiles: [.safeLowLatency], rxBufferProfiles: [.direct, .small], supportsMatrixMetadata: true)
        ),
        video: VideoCapabilities(
            supportedRoles: [.disabled],
            supportedPixelFormats: [.disabled],
            supportedTransportFormats: [.disabled],
            maxWidth: 1_920,
            maxHeight: 1_080,
            maxFrameRateNumerator: 60,
            maxEnabledStreams: 1
        ),
        transport: SessionTransportCapabilities(
            supportsDirectUDP: true,
            supportsRendezvous: true,
            minMTUBytes: 576,
            maxMTUBytes: 1_200
        ),
        latencyProfiles: [.balancedAV],
        rxBufferProfiles: [.small]
    )
}

private func opusPeer(_ peerID: String) -> PeerIdentity {
    PeerIdentity(
        peerID: peerID,
        displayName: peerID,
        implementationName: "open-lola",
        implementationVersion: "test"
    )
}
