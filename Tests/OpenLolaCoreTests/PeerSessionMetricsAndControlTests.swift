// Verifies that session metrics messages carry the M06 runtime fields.
import Testing

@testable import OpenLolaCore

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

    let expectedSessionID = "m06-direct-p2p/audio/local:6:peer-a/remote:6:peer-b"
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
func directPeerSessionIDsUseStructuredLengthPrefixedPeerIDs() throws {
    var pair = PeerSessionRunnerLoopbackPair(
        first: try .localhost(peerID: "peer-a", remotePeerID: "peer-b"),
        second: try .localhost(peerID: "peer-b", remotePeerID: "peer-a")
    )

    try pair.negotiate()

    let expectedSessionID = "m06-direct-p2p/audio/local:6:peer-a/remote:6:peer-b"
    #expect(pair.first.acceptedConfiguration?.sessionID == expectedSessionID)
    #expect(pair.second.acceptedConfiguration?.sessionID == expectedSessionID)
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
