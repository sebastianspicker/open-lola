import Foundation
import Testing

@testable import OpenLolaCore

@Test
func peerSessionShutdownIsSessionBoundAndClosesMediaTransports() throws {
    var pair = try PeerSessionRunnerLoopbackPair.make()
    defer {
        try? pair.first.shutdown(reason: "session-bound shutdown test complete")
        try? pair.second.shutdown(reason: "session-bound shutdown test complete")
    }
    try pair.negotiate()
    try pair.startMedia()
    let sessionID = try #require(pair.second.acceptedConfiguration?.sessionID)

    #expect(throws: PeerSessionRunnerError.unsupportedControlMessage(.shutdown)) {
        try pair.second.receiveControlMessages([.shutdown(SessionShutdown(
            reason: "stale shutdown",
            sessionID: "stale-\(sessionID)"
        ))])
    }
    #expect(pair.second.state == .running)

    try pair.second.receiveControlMessages([.shutdown(SessionShutdown(
        reason: "current shutdown",
        sessionID: sessionID
    ))])

    #expect(pair.second.state == .closed)
    #expect(pair.second.metrics.mediaStopBoundaries == 1)
    #expect(throws: (any Error).self) {
        _ = try pair.second.receiveMediaPacket()
    }
}

@Test
func directPeerAVControlDrainStopsOnCurrentShutdownAndIgnoresStaleShutdown() throws {
    var pair = try PeerSessionRunnerLoopbackPair.make()
    let localControl = try DirectPeerSessionControlSocket.bindLoopback()
    let remoteControl = try DirectPeerSessionControlSocket.bindLoopback()
    defer {
        localControl.close()
        remoteControl.close()
        try? pair.first.shutdown(reason: "control drain test complete")
        try? pair.second.shutdown(reason: "control drain test complete")
    }
    try pair.negotiate()
    try pair.startMedia()
    let sessionID = try #require(pair.second.acceptedConfiguration?.sessionID)

    try remoteControl.send(
        .shutdown(SessionShutdown(reason: "stale shutdown", sessionID: "stale-\(sessionID)")),
        to: localControl.endpoint
    )
    let staleResult = try drainDirectPeerAVControlEventually(
        runner: &pair.second,
        control: localControl,
        remoteControl: remoteControl.endpoint
    )

    #expect(staleResult.controlMessagesDropped == 1)
    #expect(!staleResult.shouldStop)
    #expect(pair.second.state == .running)

    try remoteControl.send(
        .shutdown(SessionShutdown(reason: "current shutdown", sessionID: sessionID)),
        to: localControl.endpoint
    )
    let currentResult = try drainDirectPeerAVControlEventually(
        runner: &pair.second,
        control: localControl,
        remoteControl: remoteControl.endpoint
    )

    #expect(currentResult.controlMessagesReceived == 1)
    #expect(currentResult.shouldStop)
    #expect(pair.second.state == .closed)
}

@Test
func peerSessionReceiveByteBudgetFollowsAcceptedMTUWithBoundedCap() throws {
    var pair = try PeerSessionRunnerLoopbackPair.make()
    defer {
        try? pair.first.shutdown(reason: "receive byte budget test complete")
        try? pair.second.shutdown(reason: "receive byte budget test complete")
    }
    try pair.negotiate()
    var configuration = try #require(pair.first.acceptedConfiguration)

    #expect(peerSessionMediaReceiveByteBudget(acceptedConfiguration: nil) == 1_200)

    configuration.mtuBytes = 1_400
    #expect(peerSessionMediaReceiveByteBudget(acceptedConfiguration: configuration) == 1_400)

    configuration.mtuBytes = 100_000
    #expect(peerSessionMediaReceiveByteBudget(acceptedConfiguration: configuration) == 65_507)
}

private func drainDirectPeerAVControlEventually(
    runner: inout PeerSessionRunner,
    control: DirectPeerSessionControlSocket,
    remoteControl: SessionNetworkEndpoint,
    timeoutNanoseconds: UInt64 = 50_000_000
) throws -> DirectPeerAVControlServiceResult {
    let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
    repeat {
        let result = try serviceDirectPeerAVControl(
            runner: &runner,
            control: control,
            remoteControl: remoteControl
        )
        if result.controlMessagesReceived > 0 || result.controlMessagesDropped > 0 || result.shouldStop {
            return result
        }
        Thread.sleep(forTimeInterval: 0.001)
    } while DispatchTime.now().uptimeNanoseconds < deadline
    return DirectPeerAVControlServiceResult()
}
