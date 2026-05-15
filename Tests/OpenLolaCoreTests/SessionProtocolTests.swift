import Foundation
import Testing

@testable import OpenLolaCore

@Test
func peerIdentityRequiresStableNonEmptyFields() throws {
    let peer = PeerIdentity(
        peerID: "peer-a",
        displayName: "Reference Mac A",
        implementationName: "open-lola",
        implementationVersion: "0.0.0-m02"
    )

    try peer.validate()
    #expect(peer.peerID == "peer-a")
    #expect(peer.implementationVersion == "0.0.0-m02")
}

@Test
func peerIdentityRejectsEmptyStableID() {
    let peer = PeerIdentity(
        peerID: "",
        displayName: "Reference Mac A",
        implementationName: "open-lola",
        implementationVersion: "0.0.0-m02"
    )

    #expect(throws: SessionValidationError.emptyField("peer.peerID")) {
        try peer.validate()
    }
}

@Test
func peerIdentityRejectsCLIBreakingStableID() {
    let peer = PeerIdentity(
        peerID: "peer a",
        displayName: "Reference Mac A",
        implementationName: "open-lola",
        implementationVersion: "0.0.0-m02"
    )

    #expect(throws: SessionValidationError.invalidCLIIdentifier(
        field: "peer.peerID",
        value: "peer a"
    )) {
        try peer.validate()
    }
}

@Test
func peerIdentityRejectsShellMetacharactersInStableID() {
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
func audioStreamRejectsNegativeStableSourceIndexWithNegativeFieldError() {
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
}

@Test
func controlMessageJSONRoundTripIsDeterministic() throws {
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
}

@Test
func audioMetadataControlMessageCarriesAdvisoryRmeSnapshotOffMediaPath() throws {
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
    let message = SessionControlMessage.audioMetadata(snapshot)
    let encoded = try SessionControlCodec.encode(message)
    let decoded = try SessionControlCodec.decode(encoded)
    var stateMachine = SessionStateMachine(state: .accepted)

    try snapshot.validate()
    try stateMachine.apply(decoded)

    #expect(decoded == message)
    #expect(decoded.audioMetadata?.revision == 7)
    #expect(decoded.audioMetadata?.requiresMetadataForPlayback == false)
    #expect(stateMachine.state == .accepted)
    #expect(String(decoding: encoded, as: UTF8.self).contains("\"type\" : \"audioMetadata\""))
}

@Test
func controlErrorMessageDoesNotCrashStateMachine() throws {
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
}

@Test
func stateMachineRejectsSkippedHandshakeTransitions() {
    var stateMachine = SessionStateMachine()

    #expect(throws: SessionStateMachineError.invalidTransition(
        from: .idle,
        message: .sessionAccept
    )) {
        try stateMachine.apply(.sessionAccept(referenceSessionConfiguration()))
    }
    #expect(stateMachine.state == .idle)
}

@Test
func stateMachineAcceptsExplicitHandshakeOrder() throws {
    var stateMachine = SessionStateMachine()

    try stateMachine.apply(.hello(
        peer: referencePeerA(),
        supportedControlVersions: [SessionControlProtocol.currentVersion]
    ))
    try stateMachine.apply(.capabilities(OpenLolaCLI.localCapabilitySet()))
    try stateMachine.apply(.sessionPropose(referenceSessionProposal(
        proposer: referencePeerA(),
        responder: referencePeerB(),
        latencyProfile: .directAudioFirst,
        rxBufferProfile: .direct
    )))
    try stateMachine.apply(.sessionAccept(referenceSessionConfiguration()))
    try stateMachine.apply(.mediaStart(SessionMediaCommand(
        sessionID: "session-a",
        hostTimeNanoseconds: 1
    )))
    try stateMachine.apply(.mediaStart(SessionMediaCommand(
        sessionID: "session-a",
        hostTimeNanoseconds: 2
    )))

    #expect(stateMachine.state == .running)
}

@Test
func shutdownMessageIsIdempotent() throws {
    var stateMachine = SessionStateMachine()
    let shutdown = SessionControlMessage.shutdown(SessionShutdown(reason: "operator stop"))

    try stateMachine.apply(shutdown)
    try stateMachine.apply(shutdown)

    #expect(stateMachine.state == .stopped)
}

@Test
func localCapabilityDocumentRoundTripsAndValidates() throws {
    let data = try OpenLolaCLI.sessionCapabilitiesData()
    let capabilities = try CapabilitySet.decode(from: data)

    try capabilities.validate()
    #expect(capabilities.peer.peerID == "local-open-lola")
    #expect(capabilities.audio.channelSet.channels.count == 64)
    #expect(capabilities.video.maxEnabledStreams == VideoTransportRunConfiguration.maximumStreamCount)
    #expect(capabilities.video.supportedRoles.contains(.testPattern))
    #expect(capabilities.latencyProfiles.contains(.directAudioFirst))
}

@Test
func sessionNegotiationAppliesLatencyProfileRxBufferPolicy() throws {
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
}

@Test
func capabilitySetValidationDelegatesDomainCapabilityChecks() throws {
    var capabilities = try CapabilitySet.decode(from: OpenLolaCLI.sessionCapabilitiesData())
    capabilities.audio.channelSet = AudioChannelSet(channels: [])

    #expect(throws: SessionValidationError.unsupportedChannelCount(requested: 1, available: 0)) {
        try capabilities.validate()
    }
}

@Test
func transportCapabilitiesRejectInvalidMTURangeSeparately() {
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
func sessionNegotiationDependsOnCapabilityProtocolsForDomainChecks() throws {
    let source = try String(
        contentsOf: repositoryRoot
            .appendingPathComponent("Sources/OpenLolaCore/Protocol/SessionNegotiation.swift"),
        encoding: .utf8
    )

    #expect(source.contains("some SessionAudioCapabilityNegotiating"))
    #expect(source.contains("some SessionVideoCapabilityNegotiating"))
    #expect(!source.contains("proposer: AudioTransportCapabilities"))
    #expect(!source.contains("proposer: VideoCapabilities"))
}

@Test
func capabilitySummaryIncludesM02SurfaceWithoutReplacingM00() {
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
