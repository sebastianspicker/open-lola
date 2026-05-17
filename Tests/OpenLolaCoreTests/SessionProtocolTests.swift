import Foundation
import Testing

@testable import OpenLolaCore

@Test
func peerIdentityRequiresStableNonEmptyFieldsAndRejectsInvalidIDs() throws {
    let peer = PeerIdentity(
        peerID: "peer-a",
        displayName: "Reference Mac A",
        implementationName: "open-lola",
        implementationVersion: "0.0.0-m02"
    )

    try peer.validate()
    #expect(peer.peerID == "peer-a")
    #expect(peer.implementationVersion == "0.0.0-m02")

    #expect(throws: SessionValidationError.emptyField("peer.peerID")) {
        try PeerIdentity(
            peerID: "",
            displayName: "Reference Mac A",
            implementationName: "open-lola",
            implementationVersion: "0.0.0-m02"
        ).validate()
    }
    #expect(throws: SessionValidationError.invalidCLIIdentifier(
        field: "peer.peerID",
        value: "peer a"
    )) {
        try PeerIdentity(
            peerID: "peer a",
            displayName: "Reference Mac A",
            implementationName: "open-lola",
            implementationVersion: "0.0.0-m02"
        ).validate()
    }
    for character in ["$", "`", "\\", "(", ")", "&", "|", ">", "<", "!"] {
        let peerID = "peer\(character)a"
        let peer = PeerIdentity(
            peerID: peerID,
            displayName: "Reference Mac A",
            implementationName: "open-lola",
            implementationVersion: "0.0.0-m02"
        )

        #expect(throws: SessionValidationError.invalidCLIIdentifier(
            field: "peer.peerID",
            value: peerID
        )) {
            try peer.validate()
        }
    }
}

@Test
func sessionProtocolDomainValidationRejectsInvalidCapabilities() throws {
    let stream = AudioStreamDescription(
        id: 1,
        direction: .send,
        sampleRateHertz: 48_000,
        sampleFormat: .float32LittleEndian,
        channelCount: 1,
        channelOrder: [AudioChannelDescriptor(stableSourceIndex: -1)],
        clockDomain: "local-clock",
        framesPerPacket: 32,
        payloadType: .audioPcmV2
    )

    #expect(throws: SessionValidationError.negativeField("audioStream.channelOrder.stableSourceIndex")) {
        try stream.validate()
    }

    var proposer = OpenLolaCLI.localCapabilitySet()
    var responder = OpenLolaCLI.localCapabilitySet()
    proposer.peer.peerID = "peer-a"
    responder.peer.peerID = "peer-b"
    let proposal = referenceSessionProposal(
        proposer: proposer.peer,
        responder: responder.peer,
        latencyProfile: .balancedAV,
        rxBufferProfile: .direct
    )

    #expect(throws: SessionValidationError.unsupportedRxBufferProfile(.direct)) {
        _ = try SessionNegotiation.negotiate(
            proposal: proposal,
            proposerCapabilities: proposer,
            responderCapabilities: responder
        )
    }

    var capabilities = OpenLolaCLI.localCapabilitySet()
    capabilities.audio.channelSet = AudioChannelSet(channels: [])

    #expect(throws: SessionValidationError.unsupportedChannelCount(requested: 1, available: 0)) {
        try capabilities.validate()
    }

    let transport = SessionTransportCapabilities(
        supportsDirectUDP: true,
        supportsRendezvous: false,
        minMTUBytes: 1_500,
        maxMTUBytes: 1_200
    )

    #expect(throws: SessionValidationError.invalidMTURange(minimum: 1_500, maximum: 1_200)) {
        try transport.validate()
    }
}

@Test
func controlMessageCodingIsDeterministicAndCarriesAdvisoryMetadata() throws {
    let message = SessionControlMessage.hello(
        peer: referencePeerA(),
        supportedControlVersions: [SessionControlProtocol.currentVersion]
    )
    let firstEncoding = try SessionControlCodec.encode(message)
    let secondEncoding = try SessionControlCodec.encode(message)
    let decoded = try SessionControlCodec.decode(firstEncoding)

    #expect(firstEncoding == secondEncoding)
    #expect(decoded == message)
    #expect(String(decoding: firstEncoding, as: UTF8.self).contains("\"type\" : \"hello\""))

    let snapshot = RmeMatrixMetadataSnapshot(
        snapshotID: "operator-snapshot-1",
        provider: .userProvidedSnapshot,
        revision: 7,
        capturedAt: "2026-05-05T00:00:00Z",
        legalBasis: "operator-provided public channel labels",
        confidence: .operatorConfirmed,
        channels: [
            AudioChannelDescriptor(stableSourceIndex: 0, label: "madi-input-1"),
            AudioChannelDescriptor(stableSourceIndex: 1, label: "madi-input-2"),
        ],
        routes: [
            RmeMatrixRouteMetadata(
                sourceChannelIndex: 0,
                destinationBusID: "receiver-main",
                gainDb: -3,
                muted: false,
                solo: false,
                pan: -1,
                stereoPairID: "main-1",
                label: "left main"
            ),
        ],
        notes: "Advisory metadata only; playback must not depend on it."
    )
    let metadataMessage = SessionControlMessage.audioMetadata(snapshot)
    let metadataEncoded = try SessionControlCodec.encode(metadataMessage)
    let metadataDecoded = try SessionControlCodec.decode(metadataEncoded)
    var stateMachine = SessionStateMachine(state: .accepted)

    try snapshot.validate()
    try stateMachine.apply(metadataDecoded)

    #expect(metadataDecoded == metadataMessage)
    #expect(metadataDecoded.audioMetadata?.revision == 7)
    #expect(metadataDecoded.audioMetadata?.requiresMetadataForPlayback == false)
    #expect(stateMachine.state == .accepted)
    #expect(String(decoding: metadataEncoded, as: UTF8.self).contains("\"type\" : \"audioMetadata\""))
}

@Test
func stateMachineAppliesExplicitHandshakeAndRejectsInvalidTransitions() throws {
    var stateMachine = SessionStateMachine()
    try stateMachine.apply(.hello(
        peer: referencePeerA(),
        supportedControlVersions: [SessionControlProtocol.currentVersion]
    ))
    try stateMachine.apply(.error(SessionErrorMessage(
        code: "unsupported-sample-rate",
        message: "sample rate was rejected",
        fatal: false
    )))

    #expect(stateMachine.state == .failed)

    var skippedHandshakeStateMachine = SessionStateMachine()

    #expect(throws: SessionStateMachineError.invalidTransition(
        from: .idle,
        message: .sessionAccept
    )) {
        try skippedHandshakeStateMachine.apply(.sessionAccept(referenceSessionConfiguration()))
    }
    #expect(skippedHandshakeStateMachine.state == .idle)

    var runningStateMachine = SessionStateMachine()

    try runningStateMachine.apply(.hello(
        peer: referencePeerA(),
        supportedControlVersions: [SessionControlProtocol.currentVersion]
    ))
    try runningStateMachine.apply(.capabilities(OpenLolaCLI.localCapabilitySet()))
    try runningStateMachine.apply(.sessionPropose(referenceSessionProposal(
        proposer: referencePeerA(),
        responder: referencePeerB(),
        latencyProfile: .directAudioFirst,
        rxBufferProfile: .direct
    )))
    try runningStateMachine.apply(.sessionAccept(referenceSessionConfiguration()))
    try runningStateMachine.apply(.mediaStart(SessionMediaCommand(
        sessionID: "session-a",
        hostTimeNanoseconds: 1
    )))
    try runningStateMachine.apply(.mediaStart(SessionMediaCommand(
        sessionID: "session-a",
        hostTimeNanoseconds: 2
    )))

    #expect(runningStateMachine.state == .running)

    var shutdownStateMachine = SessionStateMachine()
    let shutdown = SessionControlMessage.shutdown(SessionShutdown(reason: "operator stop"))

    try shutdownStateMachine.apply(shutdown)
    try shutdownStateMachine.apply(shutdown)

    #expect(shutdownStateMachine.state == .stopped)
}

@Test
func capabilitySurfaceRoundTripsAndPreservesProtocolContracts() throws {
    let data = try OpenLolaCLI.localCapabilitySet().prettyJSONData()
    let capabilities = try CapabilitySet.decode(from: data)

    try capabilities.validate()
    #expect(capabilities.peer.peerID == "local-open-lola")
    #expect(capabilities.audio.channelSet.channels.count == 64)
    #expect(capabilities.video.maxEnabledStreams == VideoTransportRunConfiguration.maximumStreamCount)
    #expect(capabilities.video.supportedRoles.contains(.testPattern))
    #expect(capabilities.latencyProfiles.contains(.directAudioFirst))

    let summary = CapabilitySummary.m02ProtocolSession

    #expect(CapabilitySummary.m00Scaffold.stage == .m00Scaffold)
    #expect(summary.version == "0.0.0-m02")
    #expect(summary.stage == .m02ProtocolSession)
    #expect(summary.capabilities.contains("session-capabilities"))
    #expect(summary.capabilities.contains("clean-room-control-json"))
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

private func referenceSessionConfiguration() -> SessionConfiguration {
    SessionConfiguration(
        sessionID: "session-a",
        peers: [referencePeerA(), referencePeerB()],
        latencyProfile: .directAudioFirst,
        rxBufferProfile: .direct,
        audioStreams: [],
        videoStreams: [],
        controlEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: 49152),
        audioEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: 49153),
        videoEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: 49154),
        metricsEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: 49155),
        mtuBytes: 1_200,
        metricIntervalMilliseconds: 1_000,
        reconnectDeadlineMilliseconds: 2_000
    )
}

private func referenceSessionProposal(
    proposer: PeerIdentity,
    responder: PeerIdentity,
    latencyProfile: SessionLatencyProfile,
    rxBufferProfile: RxBufferProfile
) -> SessionProposal {
    SessionProposal(
        sessionID: "session-a",
        proposer: proposer,
        responder: responder,
        latencyProfile: latencyProfile,
        rxBufferProfile: rxBufferProfile,
        audioStreams: [
            AudioStreamDescription(
                id: 1,
                direction: .bidirectional,
                sampleRateHertz: 48_000,
                sampleFormat: .float32LittleEndian,
                channelCount: 2,
                channelOrder: [
                    AudioChannelDescriptor(stableSourceIndex: 0),
                    AudioChannelDescriptor(stableSourceIndex: 1),
                ],
                clockDomain: "local-clock",
                framesPerPacket: 32,
                payloadType: .audioPcmV2
            ),
        ],
        videoStreams: [],
        controlEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: 49152),
        audioEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: 49153),
        videoEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: 49154),
        metricsEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: 49155),
        mtuBytes: 1_200
    )
}

private var repositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
