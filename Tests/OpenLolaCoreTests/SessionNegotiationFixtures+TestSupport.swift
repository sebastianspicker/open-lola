// Builds repeatable session capability and proposal fixtures for negotiation test cases.
@testable import OpenLolaCore

enum SessionNegotiationTestFixtures {
    static func capabilities(
        peer: PeerIdentity,
        supportedVideoRoles: [VideoStreamRole],
        maxEnabledVideoStreams: Int,
        latencyProfiles: [SessionLatencyProfile],
        rxBufferProfiles: [RxBufferProfile]
    ) -> CapabilitySet {
        CapabilitySet(
            peer: peer,
            supportedControlVersions: [SessionControlProtocol.currentVersion],
            audio: AudioTransportCapabilities(
                transport: .init(protocolVersions: [.udpPcmV2]),
                audio: .init(channelSet: .defaultInput(count: 64), sampleRatesHertz: [48_000, 96_000], framesPerPacketOptions: [32, 64], sampleFormats: [.float32LittleEndian, .int16LittleEndian]),
                limits: .init(maxTransmissionUnitBytes: 1_200, maxFragmentsPerDeadline: 16, latencyProfiles: [.safeLowLatency], rxBufferProfiles: [.direct, .small], supportsMatrixMetadata: true)
            ),
            video: VideoCapabilities(
                supportedRoles: supportedVideoRoles,
                supportedPixelFormats: [.bgra8],
                supportedTransportFormats: [.disabled, .rawFrameFragment],
                maxWidth: 1_920,
                maxHeight: 1_080,
                maxFrameRateNumerator: 60,
                maxEnabledStreams: maxEnabledVideoStreams
            ),
            transport: SessionTransportCapabilities(
                supportsDirectUDP: true,
                supportsRendezvous: true,
                minMTUBytes: 576,
                maxMTUBytes: 1_200
            ),
            latencyProfiles: latencyProfiles,
            rxBufferProfiles: rxBufferProfiles
        )
    }

    struct ProposalInput {
        let sessionID: String
        let proposer: PeerIdentity
        let responder: PeerIdentity
        let audio: AudioStreamDescription
        let video: [VideoStreamDescription]
        let latencyProfile: SessionLatencyProfile
        let rxBufferProfile: RxBufferProfile
    }

    static func proposal(_ input: ProposalInput) -> SessionProposal {
        let endpoint = { (port: UInt16) in SessionNetworkEndpoint(host: "192.0.2.10", port: port) }
        let endpoints = SessionMediaEndpoints(
            control: endpoint(41_000),
            audio: endpoint(41_001),
            video: endpoint(41_002),
            metrics: endpoint(41_003)
        )
        return SessionProposal(
            identity: .init(sessionID: input.sessionID, proposer: input.proposer, responder: input.responder),
            profile: .init(latencyProfile: input.latencyProfile, rxBufferProfile: input.rxBufferProfile),
            streams: .init(audioStreams: [input.audio], videoStreams: input.video),
            endpoints: endpoints,
            transport: SessionProposalTransport(mtuBytes: 1_200)
        )
    }
}
