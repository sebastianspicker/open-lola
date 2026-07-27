// Verifies that peer session initiator rejects mutated accepted configuration before state change.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func peerSessionInitiatorRejectsMutatedAcceptedConfigurationBeforeStateChange() throws {
    var pair = try PeerSessionRunnerLoopbackPair.make()
    defer {
        pair.first.shutdown(reason: "mutated accept test complete")
        pair.second.shutdown(reason: "mutated accept test complete")
    }

    let firstHandshake = try pair.first.beginHandshake()
    let secondHandshake = try pair.second.beginHandshake()
    try pair.first.receiveControlMessages(secondHandshake)
    try pair.second.receiveControlMessages(firstHandshake.map { $0 })
    let proposal = try pair.first.makeAudioVideoSessionProposal()
    let accept = try pair.second.acceptProposal(
        proposal,
        proposerCapabilities: pair.first.localCapabilities
    )

    var mutatedAccept = accept
    mutatedAccept.configuration?.audioStreams[0].sampleRateHertz = 44_100

    #expect(throws: PeerSessionRunnerError.unsupportedControlMessage(.sessionAccept)) {
        try pair.first.receiveControlMessages([mutatedAccept])
    }
    #expect(pair.first.acceptedConfiguration == nil)
    #expect(pair.first.state == .handshaking)

    try pair.first.receiveControlMessages([accept])
    #expect(pair.first.acceptedConfiguration == accept.configuration)
    #expect(pair.first.state == .configured)
}

@Test
func peerSessionRejectsSimultaneousProposalWithoutAcceptingEitherSide() throws {
    var pair = try PeerSessionRunnerLoopbackPair.make()
    defer {
        pair.first.shutdown(reason: "simultaneous proposal test complete")
        pair.second.shutdown(reason: "simultaneous proposal test complete")
    }
    let firstHandshake = try pair.first.beginHandshake()
    let secondHandshake = try pair.second.beginHandshake()
    try pair.first.receiveControlMessages(secondHandshake)
    try pair.second.receiveControlMessages(firstHandshake)

    let firstProposal = try pair.first.makeSessionProposal()
    let secondProposal = try pair.second.makeSessionProposal()

    #expect(throws: PeerSessionRunnerError.unsupportedControlMessage(.sessionPropose)) {
        try pair.first.receiveControlMessages([secondProposal])
    }
    #expect(throws: PeerSessionRunnerError.unsupportedControlMessage(.sessionPropose)) {
        try pair.second.receiveControlMessages([firstProposal])
    }
    #expect(pair.first.acceptedConfiguration == nil)
    #expect(pair.second.acceptedConfiguration == nil)
    #expect(pair.first.state == .handshaking)
    #expect(pair.second.state == .handshaking)
}

@Test
func peerSessionRejectsUnboundShutdownBeforeAcceptedSession() throws {
    var runner = try PeerSessionRunner.localhost(peerID: "peer-a", remotePeerID: "peer-b")
    defer { runner.shutdown(reason: "unbound shutdown test complete") }
    let shutdown = SessionControlMessage.shutdown(SessionShutdown(reason: "stale pre-session shutdown"))

    #expect(throws: PeerSessionRunnerError.unsupportedControlMessage(.shutdown)) {
        try runner.receiveControlMessages([shutdown])
    }
    #expect(runner.state == .idle)

    _ = try runner.beginHandshake()
    #expect(throws: PeerSessionRunnerError.unsupportedControlMessage(.shutdown)) {
        try runner.receiveControlMessages([shutdown])
    }
    #expect(runner.state == .handshaking)
}

@Test
func peerSessionRejectsUnboundOrWrongFatalErrorBeforeFailingLifecycle() throws {
    var pair = try PeerSessionRunnerLoopbackPair.make()
    defer {
        pair.first.shutdown(reason: "fatal error binding test complete")
        pair.second.shutdown(reason: "fatal error binding test complete")
    }

    let firstHandshake = try pair.first.beginHandshake()
    let secondHandshake = try pair.second.beginHandshake()
    try pair.first.receiveControlMessages(secondHandshake)
    try pair.second.receiveControlMessages(firstHandshake)
    _ = try pair.first.makeSessionProposal()

    #expect(throws: PeerSessionRunnerError.unsupportedControlMessage(.error)) {
        try pair.first.receiveControlMessages([.error(SessionErrorMessage(
            code: "fatal-before-accept",
            message: "fatal error before accepted session",
            fatal: true
        ))])
    }
    #expect(pair.first.state == .handshaking)

    var acceptedPair = try PeerSessionRunnerLoopbackPair.make()
    defer {
        acceptedPair.first.shutdown(reason: "accepted fatal error binding test complete")
        acceptedPair.second.shutdown(reason: "accepted fatal error binding test complete")
    }
    try acceptedPair.negotiate()
    let sessionID = try #require(acceptedPair.first.acceptedConfiguration?.sessionID)

    #expect(throws: PeerSessionRunnerError.unsupportedControlMessage(.error)) {
        try acceptedPair.first.receiveControlMessages([.error(SessionErrorMessage(
            sessionID: "wrong-\(sessionID)",
            code: "wrong-session",
            message: "wrong session fatal error",
            fatal: true
        ))])
    }
    #expect(acceptedPair.first.state == .configured)

    try acceptedPair.first.receiveControlMessages([.error(SessionErrorMessage(
        sessionID: sessionID,
        code: "current-session",
        message: "current session fatal error",
        fatal: true
    ))])
    #expect(acceptedPair.first.state == .failed)
}

@Test
func peerSessionShutdownIsSessionBoundAndClosesMediaTransports() throws {
    var pair = try PeerSessionRunnerLoopbackPair.make()
    defer {
        pair.first.shutdown(reason: "session-bound shutdown test complete")
        pair.second.shutdown(reason: "session-bound shutdown test complete")
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
func peerSessionErrorDuringRecoveryFailsSessionAndClosesMediaTransports() throws {
    var pair = try PeerSessionRunnerLoopbackPair.make()
    defer {
        pair.first.shutdown(reason: "recovery error test complete")
        pair.second.shutdown(reason: "recovery error test complete")
    }
    try pair.negotiate()
    try pair.startMedia()
    let sessionID = try #require(pair.second.acceptedConfiguration?.sessionID)

    try pair.second.receiveControlMessages([.mediaPause(SessionMediaCommand(
        sessionID: sessionID,
        hostTimeNanoseconds: 1
    ))])

    #expect(pair.second.state == .recovering)

    try pair.second.receiveControlMessages([.error(SessionErrorMessage(
        sessionID: sessionID,
        code: "peer-recovery-failed",
        message: "peer failed during recovery",
        fatal: true
    ))])

    #expect(pair.second.state == .failed)
    #expect(pair.second.metrics.mediaStopBoundaries == 1)
    #expect(throws: (any Error).self) {
        _ = try pair.second.receiveMediaPacket()
    }
}

@Test
func peerSessionRunnerControlTranscriptIsBoundedUnderHighFrequencyMessages() throws {
    var pair = try PeerSessionRunnerLoopbackPair.make()
    defer {
        pair.first.shutdown(reason: "transcript cap test complete")
        pair.second.shutdown(reason: "transcript cap test complete")
    }
    let firstHandshake = try pair.first.beginHandshake()
    let secondHandshake = try pair.second.beginHandshake()
    try pair.first.receiveControlMessages(secondHandshake)
    try pair.second.receiveControlMessages(firstHandshake)
    let proposal = try pair.first.makeSessionProposal()

    let transcriptLimit = 1_000
    let sentMetadataMessages = transcriptLimit + 200
    for revision in 0..<sentMetadataMessages {
        let message = try #require(try pair.first.publishAudioMetadata(
            makePeerMetadataSnapshot(peerID: "peer-a", revision: revision),
            nowNanoseconds: UInt64(revision + 1) * 1_000_000_000
        ))
        #expect(message.audioMetadata?.revision == revision)
    }

    #expect(pair.first.metrics.audioMetadataMessagesSent == sentMetadataMessages)
    #expect(pair.first.controlTranscript.count == transcriptLimit)
    #expect(pair.first.controlTranscript.allSatisfy { $0.type == .audioMetadata })
    #expect(pair.first.controlTranscript.first?.audioMetadata?.revision == sentMetadataMessages - transcriptLimit)
    #expect(pair.first.controlTranscript.last?.audioMetadata?.revision == sentMetadataMessages - 1)

    let accept = try pair.second.acceptProposal(proposal, proposerCapabilities: pair.first.localCapabilities)
    try pair.first.receiveControlMessages([accept])
    #expect(pair.first.state == .configured)
}

@Test
func peerSessionRunnerDoesNotReportRunningBeforePeerMediaStart() throws {
    var pair = try PeerSessionRunnerLoopbackPair.make()
    defer {
        pair.first.shutdown(reason: "peer-confirmed start test complete")
        pair.second.shutdown(reason: "peer-confirmed start test complete")
    }
    try pair.negotiate()

    try pair.first.startMedia()
    let firstMediaStart = try #require(pair.first.controlTranscript.last)

    #expect(pair.first.state == .mediaStarting)
    #expect(throws: PeerSessionRunnerError.missingAcceptedConfiguration) {
        try pair.first.sendAudioPacket(sequenceNumber: 1)
    }

    try pair.second.startMedia()
    let secondMediaStart = try #require(pair.second.controlTranscript.last)

    #expect(pair.second.state == .mediaStarting)

    try pair.first.receiveControlMessages([secondMediaStart])
    #expect(pair.first.state == .running)

    try pair.second.receiveControlMessages([firstMediaStart])
    #expect(pair.second.state == .running)
}

@Test
func peerSessionRunnerDoesNotReportRunningWhenPeerMediaStartArrivesBeforeLocalStart() throws {
    var pair = try PeerSessionRunnerLoopbackPair.make()
    defer {
        pair.first.shutdown(reason: "peer-first start test complete")
        pair.second.shutdown(reason: "peer-first start test complete")
    }
    try pair.negotiate()

    try pair.second.startMedia()
    let secondMediaStart = try #require(pair.second.controlTranscript.last)
    try pair.first.receiveControlMessages([secondMediaStart])

    #expect(pair.first.state == .configured)

    try pair.first.startMedia()
    #expect(pair.first.state == .running)
}

@Test
func directPeerAVControlDrainStopsOnCurrentShutdownAndIgnoresStaleShutdown() throws {
    var pair = try PeerSessionRunnerLoopbackPair.make()
    let localControl = try DirectPeerSessionControlSocket.bindLoopback()
    let remoteControl = try DirectPeerSessionControlSocket.bindLoopback()
    defer {
        localControl.close()
        remoteControl.close()
        pair.first.shutdown(reason: "control drain test complete")
        pair.second.shutdown(reason: "control drain test complete")
    }
    try pair.negotiate()
    try pair.startMedia()
    let sessionID = try #require(pair.second.acceptedConfiguration?.sessionID)

    try remoteControl.send(
        .shutdown(SessionShutdown(reason: "stale shutdown", sessionID: "stale-\(sessionID)")),
        to: localControl.endpoint
    )
    try remoteControl.send(
        .shutdown(SessionShutdown(reason: "current shutdown", sessionID: sessionID)),
        to: localControl.endpoint
    )
    let result = try drainDirectPeerAVControlEventually(
        runner: &pair.second,
        control: localControl,
        remoteControl: remoteControl.endpoint
    )

    #expect(result.controlMessagesDropped == 1)
    #expect(result.controlMessagesReceived == 1)
    #expect(result.shouldStop)
    #expect(result.stopReason == .terminal)
    #expect(pair.second.state == .closed)
}

@Test
func directPeerAVControlDrainIdentifiesCurrentMediaPause() throws {
    var pair = try PeerSessionRunnerLoopbackPair.make()
    let localControl = try DirectPeerSessionControlSocket.bindLoopback()
    let remoteControl = try DirectPeerSessionControlSocket.bindLoopback()
    defer {
        localControl.close()
        remoteControl.close()
        pair.first.shutdown(reason: "control media pause test complete")
        pair.second.shutdown(reason: "control media pause test complete")
    }
    try pair.negotiate()
    try pair.startMedia()
    let sessionID = try #require(pair.second.acceptedConfiguration?.sessionID)

    try remoteControl.send(
        .mediaPause(SessionMediaCommand(sessionID: sessionID, hostTimeNanoseconds: 1)),
        to: localControl.endpoint
    )
    let result = try drainDirectPeerAVControlEventually(
        runner: &pair.second,
        control: localControl,
        remoteControl: remoteControl.endpoint
    )

    #expect(result.controlMessagesReceived == 1)
    #expect(result.stopReason == .peerMediaPause)
    #expect(pair.second.state == .recovering)
    #expect(pair.second.metrics.mediaStopBoundaries == 1)
}

@Test
func peerSessionReceiveByteBudgetFollowsAcceptedMTUWithBoundedCap() throws {
    var pair = try PeerSessionRunnerLoopbackPair.make()
    defer {
        pair.first.shutdown(reason: "receive byte budget test complete")
        pair.second.shutdown(reason: "receive byte budget test complete")
    }
    try pair.negotiate()
    var configuration = try #require(pair.first.acceptedConfiguration)

    #expect(peerSessionMediaReceiveByteBudget(acceptedConfiguration: nil) == 1_200)

    configuration.mtuBytes = 1_400
    #expect(peerSessionMediaReceiveByteBudget(acceptedConfiguration: configuration) == 1_400)

    configuration.mtuBytes = 100_000
    #expect(peerSessionMediaReceiveByteBudget(acceptedConfiguration: configuration) == 65_507)
}

@Test
func peerSessionShutdownCleanupDoesNotSilentlyDiscardProductionP2PErrors() throws {
    let p2pRoot = peerSessionRunnerLifecycleRepositoryRoot.appendingPathComponent(
        "Sources/OpenLolaCore/Network/P2P"
    )
    let sourceFiles = try peerSessionRunnerLifecycleSwiftSourceFiles(under: p2pRoot)
    var discardedShutdownErrors: [String] = []

    for sourceFile in sourceFiles {
        let relativePath = sourceFile.path.replacingOccurrences(
            of: peerSessionRunnerLifecycleRepositoryRoot.path + "/",
            with: ""
        )
        let source = try String(contentsOf: sourceFile, encoding: .utf8)
        for (index, line) in source.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            if line.contains("try?"), line.contains("shutdown(") {
                discardedShutdownErrors.append("\(relativePath):\(index + 1)")
            }
        }
    }

    #expect(discardedShutdownErrors.isEmpty)

    let runnerSource = try String(
        contentsOf: p2pRoot.appendingPathComponent("PeerSessionRunner.swift"),
        encoding: .utf8
    )
    #expect(runnerSource.contains("public mutating func shutdown(reason: String) {"))
    #expect(!runnerSource.contains("public mutating func shutdown(reason: String) throws"))
}
