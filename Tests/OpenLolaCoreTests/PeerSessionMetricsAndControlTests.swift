// Verifies that session metrics messages carry the M06 runtime fields.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func peerSessionRunnerRejectsConfiguredPeerIdentityMismatchBeforeStateMutation() throws {
    var wrongHelloRunner = try PeerSessionRunner.localhost(
        peerID: "peer-a",
        remotePeerID: "peer-b"
    )
    defer { wrongHelloRunner.shutdown(reason: "wrong hello identity test complete") }
    var wrongCapabilities = OpenLolaCLI.localCapabilitySet()
    wrongCapabilities.peer = PeerIdentity(
        peerID: "peer-c",
        displayName: "Peer C",
        implementationName: "open-lola-test",
        implementationVersion: "1"
    )

    #expect(throws: SessionValidationError.peerMismatch(expected: "peer-b", actual: "peer-c")) {
        try wrongHelloRunner.receiveControlMessages([.hello(
            peer: wrongCapabilities.peer,
            supportedControlVersions: [SessionControlProtocol.currentVersion]
        )])
    }
    #expect(wrongHelloRunner.state == .idle)
    #expect(wrongHelloRunner.remoteCapabilities == nil)

    var capabilityRunner = try PeerSessionRunner.localhost(
        peerID: "peer-a",
        remotePeerID: "peer-b"
    )
    defer { capabilityRunner.shutdown(reason: "wrong capability identity test complete") }
    var expectedCapabilities = wrongCapabilities
    expectedCapabilities.peer = PeerIdentity(
        peerID: "peer-b",
        displayName: "Peer B",
        implementationName: "open-lola-test",
        implementationVersion: "1"
    )
    try capabilityRunner.receiveControlMessages([.hello(
        peer: expectedCapabilities.peer,
        supportedControlVersions: [SessionControlProtocol.currentVersion]
    )])

    #expect(throws: SessionValidationError.peerMismatch(expected: "peer-b", actual: "peer-c")) {
        try capabilityRunner.receiveControlMessages([.capabilities(wrongCapabilities)])
    }
    #expect(capabilityRunner.state == .handshaking)
    #expect(capabilityRunner.remoteCapabilities == nil)

    var inconsistentCapabilities = expectedCapabilities
    inconsistentCapabilities.peer.displayName = "Different Peer B"
    #expect(throws: PeerSessionRunnerError.unsupportedControlMessage(.capabilities)) {
        try capabilityRunner.receiveControlMessages([.capabilities(inconsistentCapabilities)])
    }
    #expect(capabilityRunner.state == .handshaking)
    #expect(capabilityRunner.remoteCapabilities == nil)
}

@Test
func peerSessionRunnerRejectsProposalFromIdentityOutsideConfiguredPair() throws {
    var pair = try PeerSessionRunnerLoopbackPair.make()
    defer {
        pair.first.shutdown(reason: "wrong proposal identity test complete")
        pair.second.shutdown(reason: "wrong proposal identity test complete")
    }
    let firstHandshake = try pair.first.beginHandshake()
    let secondHandshake = try pair.second.beginHandshake()
    try pair.first.receiveControlMessages(secondHandshake)
    try pair.second.receiveControlMessages(firstHandshake)

    let proposalMessage = try pair.first.makeSessionProposal()
    var forgedProposal = try #require(proposalMessage.proposal)
    var forgedCapabilities = pair.first.localCapabilities
    let forgedPeer = PeerIdentity(
        peerID: "peer-c",
        displayName: "Peer C",
        implementationName: "open-lola-test",
        implementationVersion: "1"
    )
    forgedProposal.proposer = forgedPeer
    forgedCapabilities.peer = forgedPeer

    #expect(throws: SessionValidationError.peerMismatch(expected: "peer-a", actual: "peer-c")) {
        _ = try pair.second.acceptProposal(
            .sessionPropose(forgedProposal),
            proposerCapabilities: forgedCapabilities
        )
    }
    #expect(pair.second.state == .handshaking)
    #expect(pair.second.acceptedConfiguration == nil)
}

@Test
func sessionMetricsMessageCarriesM06RuntimeFields() throws {
    let metrics = SessionMetricsMessage(
        sessionID: "m06-session",
        delivery: .init(packetsLost: 1, jitterMicroseconds: 25, latePackets: 2,
                        callbackDurationP99Microseconds: 180, queueDepthPackets: 1),
        runtime: .init(cpuPercent: 12.5, memoryResidentBytes: 1_000_000,
                       underruns: 0, overruns: 0, videoFramesDropped: 0)
    )
    let message = SessionControlMessage.metrics(metrics)
    let decoded = try SessionControlCodec.decode(try SessionControlCodec.encode(message))

    #expect(decoded.metrics?.latePackets == 2)
    #expect(decoded.metrics?.callbackDurationP99Microseconds == 180)
    #expect(decoded.metrics?.queueDepthPackets == 1)
    #expect(decoded.metrics?.cpuPercent == 12.5)
    #expect(decoded.metrics?.memoryResidentBytes == 1_000_000)
}

@Test
func directPeerSessionStoresRemoteMetricsFromControlAndMetricsTransport() throws {
    var pair = try PeerSessionRunnerLoopbackPair.make()
    try pair.negotiate()
    try pair.startMedia()

    let expectedSessionID = try #require(pair.second.acceptedConfiguration?.sessionID)
    let controlMetrics = SessionMetricsMessage(
        sessionID: expectedSessionID,
        delivery: .init(packetsLost: 3, jitterMicroseconds: 42, latePackets: 2,
                        callbackDurationP99Microseconds: 125, queueDepthPackets: 4),
        runtime: .init(cpuPercent: 18.5, memoryResidentBytes: 1_500_000,
                       underruns: 1, overruns: 0, videoFramesDropped: 2)
    )
    try pair.second.receiveControlMessages([.metrics(controlMetrics)])

    #expect(pair.second.metrics.remoteMetricsMessagesReceived == 1)
    #expect(pair.second.metrics.remotePacketsLost == 3)
    #expect(pair.second.metrics.remoteJitterMicroseconds == 42)
    #expect(pair.second.metrics.remoteLatePackets == 2)
    #expect(pair.second.metrics.remoteQueueDepthPackets == 4)
    #expect(pair.second.metrics.remoteVideoFramesDropped == 2)

    try pair.first.publishMetricsSnapshot()
    let receivedMetricsCandidate = try receivePeerMetricsEventually(from: &pair.second)
    let receivedMetrics = try #require(receivedMetricsCandidate)

    #expect(receivedMetrics.sessionID == expectedSessionID)
    #expect(pair.first.metrics.metricsMessagesSent == 1)
    #expect(pair.second.metrics.remoteMetricsMessagesReceived == 2)
}

@Test
func directPeerMetricsRejectsWrongSessionStreamAndInvalidValuesWithoutPoisoningMetrics() throws {
    var pair = try PeerSessionRunnerLoopbackPair.make()
    defer {
        pair.first.shutdown(reason: "metrics validation test complete")
        pair.second.shutdown(reason: "metrics validation test complete")
    }
    try pair.negotiate()
    try pair.startMedia()

    let sessionID = try #require(pair.second.acceptedConfiguration?.sessionID)
    let sender = try #require(pair.first.metricsTransport)
    let baseline = pair.second.metrics

    try sender.send(peerMetricsPacket(
        sessionID: "stale-session",
        streamID: peerSessionMetricsStreamID,
        packetsLost: 3
    ))
    #expect(try receivePeerMetricsEventually(from: &pair.second) == nil)

    try sender.send(peerMetricsPacket(sessionID: sessionID, streamID: 2, packetsLost: 3))
    #expect(try receivePeerMetricsEventually(from: &pair.second) == nil)

    try sender.send(peerMetricsPacket(
        sessionID: sessionID,
        streamID: peerSessionMetricsStreamID,
        packetsLost: -1
    ))
    #expect(try receivePeerMetricsEventually(from: &pair.second) == nil)

    let nonFiniteMetrics = SessionMetricsMessage(
        sessionID: sessionID,
        delivery: .init(packetsLost: 1, jitterMicroseconds: .nan),
        runtime: .init(cpuPercent: .infinity, memoryResidentBytes: 1, underruns: 0, overruns: 0,
                       videoFramesDropped: 0)
    )
    #expect(throws: PeerSessionRunnerError.unsupportedControlMessage(.metrics)) {
        try pair.second.receiveControlMessages([.metrics(nonFiniteMetrics)])
    }

    #expect(pair.second.metrics.remoteMetricsMessagesReceived == baseline.remoteMetricsMessagesReceived)
    #expect(pair.second.metrics.remotePacketsLost == baseline.remotePacketsLost)
    #expect(pair.second.remoteMetricsMessagesRejected == 4)

    try sender.send(peerMetricsPacket(
        sessionID: sessionID,
        streamID: peerSessionMetricsStreamID,
        packetsLost: 7
    ))
    let acceptedCandidate = try receivePeerMetricsEventually(from: &pair.second)
    let accepted = try #require(acceptedCandidate)
    #expect(accepted.sessionID == sessionID)
    #expect(pair.second.metrics.remoteMetricsMessagesReceived == 1)
    #expect(pair.second.metrics.remotePacketsLost == 7)
    #expect(pair.second.remoteMetricsMessagesRejected == 4)
}

@Test
func directPeerTransportMetricsSaturatesAudioAndVideoLossMerges() throws {
    var pair = try PeerSessionRunnerLoopbackPair.make()
    defer {
        pair.first.shutdown(reason: "transport metrics saturation test complete")
        pair.second.shutdown(reason: "transport metrics saturation test complete")
    }
    try pair.negotiate()
    try pair.startMedia()

    try recordSaturatingLoss(
        sender: try #require(pair.first.audioTransport),
        receiver: try #require(pair.second.audioTransport)
    )
    try recordSaturatingLoss(
        sender: try #require(pair.first.videoTransport),
        receiver: try #require(pair.second.videoTransport)
    )

    #expect(pair.second.transportMetrics().packetsLost == Int.max)
}

private func peerMetricsPacket(sessionID: String, streamID: UInt32, packetsLost: Int) throws -> UdpMediaPacket {
    let metrics = SessionMetricsMessage(
        sessionID: sessionID,
        delivery: .init(packetsLost: packetsLost, jitterMicroseconds: 1),
        runtime: .init(cpuPercent: 1, memoryResidentBytes: 1, underruns: 0, overruns: 0,
                       videoFramesDropped: 0)
    )
    return UdpMediaPacket(
        header: UdpMediaPacketHeader(
            payloadType: .metrics,
            streamID: streamID,
            sequenceNumber: 1,
            timestampNanoseconds: 1
        ),
        payload: try JSONEncoder().encode(metrics)
    )
}

private func recordSaturatingLoss(sender: UdpMediaTransport, receiver: UdpMediaTransport) throws {
    for sequenceNumber in [UInt64(0), UInt64(Int.max), UInt64(Int.max) + 2] {
        try sender.send(keepaliveMediaPacket(streamID: 1, sequenceNumber: sequenceNumber, timestamp: 1))
        _ = try receiver.receive(maxByteCount: 1_200)
    }
    #expect(receiver.metrics.packetsLost == Int.max)
}

@Test
func directPeerSessionIDsUseFreshLowercase128BitNonces() throws {
    var firstPair = PeerSessionRunnerLoopbackPair(
        first: try .localhost(peerID: "peer-a", remotePeerID: "peer-b"),
        second: try .localhost(peerID: "peer-b", remotePeerID: "peer-a")
    )
    var secondPair = PeerSessionRunnerLoopbackPair(
        first: try .localhost(peerID: "peer-a", remotePeerID: "peer-b"),
        second: try .localhost(peerID: "peer-b", remotePeerID: "peer-a")
    )
    defer {
        firstPair.first.shutdown(reason: "first ID fixture complete")
        firstPair.second.shutdown(reason: "first ID fixture complete")
        secondPair.first.shutdown(reason: "second ID fixture complete")
        secondPair.second.shutdown(reason: "second ID fixture complete")
    }

    try firstPair.negotiate()
    try secondPair.negotiate()

    let firstID = try #require(firstPair.first.acceptedConfiguration?.sessionID)
    let secondID = try #require(secondPair.first.acceptedConfiguration?.sessionID)
    let noncePattern = #"^m06-direct-p2p/audio/nonce:[0-9a-f]{32}$"#

    #expect(firstID.range(of: noncePattern, options: .regularExpression) != nil)
    #expect(secondID.range(of: noncePattern, options: .regularExpression) != nil)
    #expect(firstID != secondID)
    #expect(firstPair.second.acceptedConfiguration?.sessionID == firstID)
    #expect(secondPair.second.acceptedConfiguration?.sessionID == secondID)
}

@Test
func directPeerSessionRejectsControlFromPriorSessionWithSamePeers() throws {
    var priorPair = try PeerSessionRunnerLoopbackPair.make()
    var currentPair = try PeerSessionRunnerLoopbackPair.make()
    defer {
        priorPair.first.shutdown(reason: "prior session fixture complete")
        priorPair.second.shutdown(reason: "prior session fixture complete")
        currentPair.first.shutdown(reason: "current session fixture complete")
        currentPair.second.shutdown(reason: "current session fixture complete")
    }

    try priorPair.negotiate()
    try currentPair.negotiate()

    let priorSessionID = try #require(priorPair.first.acceptedConfiguration?.sessionID)
    let currentSessionID = try #require(currentPair.first.acceptedConfiguration?.sessionID)
    #expect(priorSessionID != currentSessionID)

    #expect(throws: PeerSessionRunnerError.unsupportedControlMessage(.shutdown)) {
        try currentPair.first.receiveControlMessages([.shutdown(SessionShutdown(
            reason: "stale prior-session shutdown",
            sessionID: priorSessionID
        ))])
    }
    #expect(currentPair.first.state == .configured)
}

@Test
func directPeerSessionProposalNonceGenerationFailsBeforeControlStateMutation() throws {
    var pair = try PeerSessionRunnerLoopbackPair.make()
    defer {
        pair.first.shutdown(reason: "nonce failure fixture complete")
        pair.second.shutdown(reason: "nonce failure fixture complete")
    }

    let firstHandshake = try pair.first.beginHandshake()
    let secondHandshake = try pair.second.beginHandshake()
    try pair.first.receiveControlMessages(secondHandshake)
    try pair.second.receiveControlMessages(firstHandshake)
    pair.first.sessionIDNonceGenerator = {
        throw PeerSessionRunnerError.secureSessionIDGenerationFailed(-42)
    }

    #expect(throws: PeerSessionRunnerError.secureSessionIDGenerationFailed(-42)) {
        _ = try pair.first.makeSessionProposal()
    }
    #expect(pair.first.state == .handshaking)
    #expect(pair.first.lastSentProposal == nil)
    #expect(pair.first.controlTranscript.last?.type == .capabilities)
}

@Test
func directPeerSessionAVProposalUsesInjectedNonceWithoutWideningPublicAPI() throws {
    var pair = try PeerSessionRunnerLoopbackPair.make()
    defer {
        pair.first.shutdown(reason: "injected AV nonce fixture complete")
        pair.second.shutdown(reason: "injected AV nonce fixture complete")
    }

    let firstHandshake = try pair.first.beginHandshake()
    let secondHandshake = try pair.second.beginHandshake()
    try pair.first.receiveControlMessages(secondHandshake)
    try pair.second.receiveControlMessages(firstHandshake)
    pair.first.sessionIDNonceGenerator = { Array(0..<16) }

    let proposal = try pair.first.makeAudioVideoSessionProposal()
    #expect(proposal.proposal?.sessionID == "m06-direct-p2p/av/nonce:000102030405060708090a0b0c0d0e0f")
}

@Test
func directPeerSessionPublishesRateLimitedAdvisoryMetadataOffMediaPath() throws {
    var pair = try PeerSessionRunnerLoopbackPair.make()
    try pair.negotiate()

    let firstMetadata = makePeerMetadataSnapshot(peerID: "peer-a", revision: 1)
    let duplicateMetadata = try pair.first.publishAudioMetadata(
        firstMetadata,
        nowNanoseconds: 2_000
    )
    let rateLimitedMetadata = try pair.first.publishAudioMetadata(
        makePeerMetadataSnapshot(peerID: "peer-a", revision: 2),
        nowNanoseconds: 2_500
    )

    #expect(duplicateMetadata != nil)
    #expect(rateLimitedMetadata == nil)
    #expect(pair.first.metrics.controlMessagesSent == 4)
    #expect(pair.first.metrics.audioMetadataMessagesSent == 1)
    #expect(pair.first.metrics.audioMetadataUpdatesRateLimited == 1)

    try pair.second.receiveControlMessages([SessionControlMessage.audioMetadata(firstMetadata)])

    #expect(pair.second.remoteAudioMetadata?.revision == 1)
    #expect(pair.second.metrics.audioMetadataMessagesReceived == 1)
    #expect(pair.second.state == .configured)
}

@Test
func directPeerSessionControlMessagesNeverCarryAudioMedia() throws {
    var pair = try PeerSessionRunnerLoopbackPair.make()
    try pair.negotiate()
    try pair.startMedia()
    try pair.sendAudioPacketFromFirstToSecond(sequenceNumber: 1)

    #expect(pair.first.metrics.mediaPacketsSent == 1)
    #expect(pair.first.metrics.audioPayloadsSentOnControlChannel == 0)
    #expect(pair.first.controlTranscript.allSatisfy { $0.type != .metrics || $0.metrics != nil })
}
