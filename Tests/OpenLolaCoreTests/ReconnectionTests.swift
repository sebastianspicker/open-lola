// Verifies that reconnect after media socket failure preserves accepted session configuration.
import Testing

@testable import OpenLolaCore

@Test
func reconnectAfterMediaSocketFailurePreservesAcceptedSessionConfiguration() throws {
    var pair = try PeerSessionRunnerLoopbackPair.make()
    try pair.negotiate()
    try pair.startMedia()
    let accepted = try #require(pair.first.acceptedConfiguration)

    try pair.first.markMediaSocketFailed(reason: "receiver disappeared")

    #expect(pair.first.state == .recovering)
    #expect(pair.first.acceptedConfiguration == accepted)
    #expect(pair.first.metrics.mediaStopBoundaries == 1)

    try pair.first.restartMedia()

    #expect(pair.first.state == .running)
    #expect(pair.first.acceptedConfiguration == accepted)
    #expect(pair.first.metrics.recoveryEvents == 1)
}

@Test
func reconnect_sequenceCounterResetsAfterMediaSocketFailure() throws {
    var pair = try PeerSessionRunnerLoopbackPair.make()
    try pair.negotiate()
    try pair.startMedia()

    try pair.first.sendAudioPacket(sequenceNumber: 10)
    let preFailure = try pair.second.receiveAudioMediaPacket()
    #expect(preFailure.header.sequenceNumber == 10)
    #expect(pair.second.transportMetrics().latePackets == 0)

    try pair.second.markMediaSocketFailed(reason: "receiver media socket failed")
    try pair.second.restartMedia()

    try pair.first.sendAudioPacket(sequenceNumber: 0)
    let postReconnect = try pair.second.receiveAudioMediaPacket()

    #expect(postReconnect.header.sequenceNumber == 0)
    #expect(pair.second.transportMetrics().latePackets == 0)
    #expect(pair.second.transportMetrics().packetsLost == 0)
}

@Test
func reconnect_rxBufferIsFlushedAfterMediaSocketFailure() throws {
    var pair = try PeerSessionRunnerLoopbackPair.make()
    try pair.negotiate()
    try pair.startMedia()

    try pair.first.sendAudioPacket(sequenceNumber: 3)
    #expect(try pair.second.waitForIncomingMedia(timeoutMicroseconds: 50_000))

    try pair.second.markMediaSocketFailed(reason: "receiver media socket failed")
    try pair.second.restartMedia()

    #expect(try pair.second.receiveAudioMediaPacketIfAvailable() == nil)
}

@Test
func reconnect_preFailurePacketsDoNotCorruptPostReconnectStream() throws {
    var pair = try PeerSessionRunnerLoopbackPair.make()
    try pair.negotiate()
    try pair.startMedia()

    for sequence in UInt64(0)..<UInt64(10) {
        try pair.sendAudioPacketFromFirstToSecond(sequenceNumber: sequence)
    }

    try pair.first.sendAudioPacket(sequenceNumber: 99)
    #expect(try pair.second.waitForIncomingMedia(timeoutMicroseconds: 50_000))

    try pair.second.markMediaSocketFailed(reason: "receiver media socket failed")
    try pair.second.restartMedia()

    for sequence in UInt64(0)..<UInt64(10) {
        try pair.first.sendAudioPacket(sequenceNumber: sequence)
        let received = try pair.second.receiveAudioMediaPacket()
        #expect(received.header.sequenceNumber == sequence)
    }
    #expect(pair.second.transportMetrics().duplicatePackets == 0)
    #expect(pair.second.transportMetrics().latePackets == 0)
    #expect(pair.second.transportMetrics().packetsLost == 0)
}
