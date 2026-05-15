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
