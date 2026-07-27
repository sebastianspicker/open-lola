// Verifies that NAT relay skips control decoding for registered media source.
import Darwin
import Dispatch
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func natRelaySkipsControlDecodingForRegisteredMediaSource() {
    let endpoint = NatEndpoint(host: "127.0.0.1", port: 50_000)
    #expect(!natRelayShouldAttemptRegistrationDecode(
        sourceEndpoint: endpoint,
        data: Data("{media-like-payload".utf8),
        endpointsByPeerID: ["peer-a": endpoint]
    ))
    #expect(natRelayShouldAttemptRegistrationDecode(
        sourceEndpoint: NatEndpoint(host: "127.0.0.1", port: 50_001),
        data: Data("{}".utf8),
        endpointsByPeerID: ["peer-a": endpoint]
    ))
}

@Test
func natRelayRegistrationCapacityIsBoundedByExpectedPeers() {
    let registrations = [
        "peer-a": NatRelayRegistration(
            peerID: "peer-a",
            observedRelayEndpoint: NatEndpoint(host: "127.0.0.1", port: 50_000),
            registeredAt: "2026-07-15T00:00:00Z"
        )
    ]
    #expect(natRelayRegistrationCapacityAllows(
        peerID: "peer-a",
        expectedPeerCount: 1,
        registrations: registrations
    ))
    #expect(!natRelayRegistrationCapacityAllows(
        peerID: "peer-b",
        expectedPeerCount: 1,
        registrations: registrations
    ))
}

@Test
func natRendezvousReportCountsSkippedMalformedAndWrongSessionDatagrams() throws {
    let port = try availableNatRendezvousPort()
    let configuration = NatRendezvousRunConfiguration(
        bindHost: "127.0.0.1",
        port: port,
        sessionID: "rendezvous-skip-counts",
        mode: .rendezvousOnly,
        expectedPeerCount: 1,
        timeoutSeconds: 1,
        outputPath: "stdout"
    )
    let ready = DispatchSemaphore(value: 0)
    let done = DispatchSemaphore(value: 0)
    let result = NatSmokeResultBox<NatRendezvousReport>()

    DispatchQueue.global(qos: .userInitiated).async {
        result.set(Result {
            try NatRendezvousRunner.run(configuration: configuration) {
                ready.signal()
            }
        })
        done.signal()
    }
    guard ready.wait(timeout: .now() + 2) == .success else {
        Issue.record("Timed out waiting for rendezvous listener readiness")
        return
    }

    let clientSocket = try makeUdpSocket(receiveTimeoutSeconds: 1)
    defer { close(clientSocket) }
    try bindIPv4(clientSocket, host: "127.0.0.1", port: 0)
    try sendRendezvousSkipCountDatagrams(
        socket: clientSocket,
        port: port,
        sessionID: configuration.sessionID
    )

    guard done.wait(timeout: .now() + 3) == .success else {
        Issue.record("Timed out waiting for rendezvous report")
        return
    }
    let relayReport = try validatedNatSmokeResult(result)

    assertNatSkipCounts(
        peerIDs: relayReport.registrations.map(\.peerID),
        malformed: relayReport.skippedDatagrams.malformed,
        wrongSession: relayReport.skippedDatagrams.wrongSession,
        wrongPeer: relayReport.skippedDatagrams.wrongPeer,
        expectedWrongPeer: 0
    )
}

private func sendRendezvousSkipCountDatagrams(socket clientSocket: Int32, port: UInt16, sessionID: String) throws {
    let localEndpoint = NatEndpoint(host: "127.0.0.1", port: UInt16(bigEndian: try boundPort(clientSocket)))
    try sendNatTestDatagram(Data("{".utf8), socket: clientSocket, port: port)
    try sendNatTestDatagram(
        try JSONEncoder().encode(NatRendezvousRegistrationRequest(
            sessionID: "wrong-session",
            peerID: "peer-a",
            localEndpoint: localEndpoint
        )),
        socket: clientSocket,
        port: port
    )
    try sendNatTestDatagram(
        try JSONEncoder().encode(NatRendezvousRegistrationRequest(
            sessionID: sessionID,
            peerID: "peer-a",
            localEndpoint: localEndpoint
        )),
        socket: clientSocket,
        port: port
    )
}

@Test
func natRelayReportCountsSkippedMalformedWrongSessionAndWrongPeerDatagrams() throws {
    let port = try availableNatRendezvousPort()
    let configuration = NatRelayRunConfiguration(
        bindHost: "127.0.0.1",
        port: port,
        sessionID: "relay-skip-counts",
        expectedPeerCount: 1,
        timeoutSeconds: 1,
        outputPath: "stdout"
    )
    let ready = DispatchSemaphore(value: 0)
    let done = DispatchSemaphore(value: 0)
    let result = NatSmokeResultBox<NatRelayReport>()

    DispatchQueue.global(qos: .userInitiated).async {
        result.set(Result {
            try NatRelayRunner.run(configuration: configuration) {
                ready.signal()
            }
        })
        done.signal()
    }
    guard ready.wait(timeout: .now() + 2) == .success else {
        Issue.record("Timed out waiting for relay listener readiness")
        return
    }

    let clientSocket = try makeUdpSocket(receiveTimeoutSeconds: 1)
    defer { close(clientSocket) }
    try bindIPv4(clientSocket, host: "127.0.0.1", port: 0)

    try sendRelaySkipCountDatagrams(
        socket: clientSocket,
        port: port,
        sessionID: configuration.sessionID
    )

    guard done.wait(timeout: .now() + 3) == .success else {
        Issue.record("Timed out waiting for relay report")
        return
    }
    let report = try validatedNatSmokeResult(result)

    assertNatSkipCounts(
        peerIDs: report.registrations.map(\.peerID),
        malformed: report.skippedDatagrams.malformed,
        wrongSession: report.skippedDatagrams.wrongSession,
        wrongPeer: report.skippedDatagrams.wrongPeer,
        expectedWrongPeer: 2
    )
    #expect(report.forwardingBackpressureDrops == 0)
}

private func sendRelaySkipCountDatagrams(socket clientSocket: Int32, port: UInt16, sessionID: String) throws {
    try sendNatTestDatagram(Data("{".utf8), socket: clientSocket, port: port)
    try sendNatTestDatagram(Data("unknown peer payload".utf8), socket: clientSocket, port: port)
    try sendNatTestDatagram(
        try JSONEncoder().encode(NatRelayRegistrationRequest(
            sessionID: "wrong-session",
            peerID: "peer-a"
        )),
        socket: clientSocket,
        port: port
    )
    try sendNatTestDatagram(
        try JSONEncoder().encode(NatRelayRegistrationRequest(
            sessionID: sessionID,
            peerID: "peer-a"
        )),
        socket: clientSocket,
        port: port
    )
}

private func validatedNatSmokeResult(
    _ result: NatSmokeResultBox<NatRendezvousReport>
) throws -> NatRendezvousReport {
    let report = try #require(result.get()).get()
    try report.validate()
    return report
}

private func validatedNatSmokeResult(
    _ result: NatSmokeResultBox<NatRelayReport>
) throws -> NatRelayReport {
    let report = try #require(result.get()).get()
    try report.validate()
    return report
}

private func assertNatSkipCounts(
    peerIDs: [String],
    malformed: Int,
    wrongSession: Int,
    wrongPeer: Int,
    expectedWrongPeer: Int
) {
    #expect(peerIDs == ["peer-a"])
    #expect(malformed == 1)
    #expect(wrongSession == 1)
    #expect(wrongPeer == expectedWrongPeer)
}

@Test
func relayFallbackSmokeUsesRelayOnlyAfterDirectTraversalFails() throws {
    let result = try NatRelayFallbackLocalhostSmoke.run()

    try result.rendezvousReport.validate()
    try result.relayReport.validate()
    for report in result.routeReports {
        try report.validate()
    }

    #expect(result.relayReport.registrations.count == 2)
    #expect(result.relayReport.forwardedDatagrams > 0)
    #expect(result.rendezvousReport.skippedDatagrams == .zero)
    #expect(result.relayReport.skippedDatagrams == .zero)
    #expect(result.routeReports.count == 2)
    #expect(result.routeReports.allSatisfy { $0.compatibilityMode == .relayFallback })
    #expect(result.routeReports.allSatisfy { $0.rawP2PPreferred })
    #expect(result.routeReports.allSatisfy { $0.traversal.directCandidateDiscovered })
    #expect(result.routeReports.allSatisfy { !$0.traversal.directTraversalSucceeded })
    #expect(result.routeReports.allSatisfy { $0.traversal.relayUsed })
    #expect(result.routeReports.allSatisfy { $0.traversal.relayFallbackRttMicroseconds != nil })
}

@Test
func natFriendlyRouteReportRejectsInvalidEvidence() throws {
    try expectNatFriendlyRouteError(.relayFallbackWithoutFailedDirectTraversal) {
        $0.compatibilityMode = .relayFallback
        $0.traversal.relayUsed = true
        $0.traversal.directCandidateDiscovered = true
        $0.traversal.directTraversalSucceeded = true
    }
    try expectNatFriendlyRouteError(.passWithRelayAsFastestPath) {
        $0.verdict = .pass
        $0.compatibilityMode = .relayFallback
        $0.rawP2PPreferred = false
    }
    try expectNatFriendlyRouteError(.passWithRendezvousOnlyMode) {
        var loopback = try #require($0.loopback)
        loopback.verdict = .pass
        $0.loopback = loopback
        $0.verdict = .pass
        $0.compatibilityMode = .rendezvousOnly
        $0.traversal.rawRouteRttMicroseconds = 0
    }
    try expectNatFriendlyRouteError(.passWithoutPassingLoopback) {
        $0.verdict = .pass
        $0.traversal.rawRouteRttMicroseconds = 0
    }
    try expectNatFriendlyRouteError(.passWithoutRawRouteBaseline) {
        var loopback = try #require($0.loopback)
        loopback.verdict = .pass
        $0.loopback = loopback
        $0.verdict = .pass
        $0.traversal.rawRouteRttMicroseconds = nil
    }
    try expectNatFriendlyRouteError(.directTraversalWithFailedLoopback) {
        var loopback = try #require($0.loopback)
        loopback.metrics.byteExactEcho = false
        $0.loopback = loopback
        $0.traversal.directTraversalSucceeded = true
    }
}

@Test
func natFriendlyLocalhostSmokeKeepsRawP2PPreferred() throws {
    let report = try NatFriendlyRouteLocalhostSmoke.run()

    try report.validate()

    #expect(report.rawP2PPreferred)
    #expect(report.compatibilityMode == .directTraversal)
    #expect(report.verdict == .partial)
    #expect(report.traversal.observedExternalEndpoint != nil)
    #expect(report.traversal.peerEndpoint != nil)
}

private func expectNatFriendlyRouteError(
    _ expected: NatFriendlyRouteValidationError,
    mutate: (inout NatFriendlyRouteReport) throws -> Void
) throws {
    var report = NatFriendlyRouteSyntheticSmoke.run()
    try mutate(&report)

    #expect(throws: expected) {
        try report.validate()
    }
}

private func sendNatTestDatagram(_ data: Data, socket: Int32, port: UInt16) throws {
    try sendDatagram(data, socket: socket, host: "127.0.0.1", port: port.bigEndian)
}
