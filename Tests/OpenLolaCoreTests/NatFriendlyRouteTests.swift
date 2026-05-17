import Darwin
import Dispatch
import Foundation
import Testing

@testable import OpenLolaCore


@Test
func natFriendlyRouteConfigurationsParseArgumentsAndRejectInvalidPortShapes() throws {
    let routeConfiguration = try NatFriendlyRouteRunConfiguration.parse([
        "--role", "sender",
        "--bind-host", "127.0.0.1",
        "--peer-id", "looper-a",
        "--rendezvous-host", "127.0.0.1",
        "--rendezvous-port", "7000",
        "--relay-host", "127.0.0.1",
        "--relay-port", "7001",
        "--session-id", "session-1",
        "--port", "5004",
        "--duration-seconds", "2",
        "--keepalive-interval-ms", "250",
        "--raw-rtt-microseconds", "120",
        "--output", "reports/nat.json",
        "--debug-output", "reports/nat-debug.jsonl"
    ])

    #expect(routeConfiguration.role == .sender)
    #expect(routeConfiguration.bindHost == "127.0.0.1")
    #expect(routeConfiguration.peerID == "looper-a")
    #expect(routeConfiguration.rendezvousHost == "127.0.0.1")
    #expect(routeConfiguration.rendezvousPort == 7_000)
    #expect(routeConfiguration.relayHost == "127.0.0.1")
    #expect(routeConfiguration.relayPort == 7_001)
    #expect(routeConfiguration.sessionID == "session-1")
    #expect(routeConfiguration.localUdpPort == 5_004)
    #expect(routeConfiguration.durationSeconds == 2)
    #expect(routeConfiguration.keepaliveIntervalMilliseconds == 250)
    #expect(routeConfiguration.rawRouteRttMicroseconds == 120)
    #expect(routeConfiguration.outputPath == "reports/nat.json")
    #expect(routeConfiguration.debugOutputPath == "reports/nat-debug.jsonl")

    let rendezvousConfiguration = try NatRendezvousRunConfiguration.parse([
        "--bind-host", "127.0.0.1",
        "--port", "7000",
        "--session-id", "session-1",
        "--mode", "rendezvousOnly",
        "--expected-peers", "2",
        "--timeout-seconds", "5",
        "--output", "reports/rendezvous.json"
    ])

    #expect(rendezvousConfiguration.bindHost == "127.0.0.1")
    #expect(rendezvousConfiguration.port == 7_000)
    #expect(rendezvousConfiguration.sessionID == "session-1")
    #expect(rendezvousConfiguration.mode == .rendezvousOnly)
    #expect(rendezvousConfiguration.expectedPeerCount == 2)
    #expect(rendezvousConfiguration.timeoutSeconds == 5)
    #expect(rendezvousConfiguration.outputPath == "reports/rendezvous.json")

    let relayConfiguration = try NatRelayRunConfiguration.parse([
        "--bind-host", "127.0.0.1",
        "--port", "7001",
        "--session-id", "session-1",
        "--expected-peers", "2",
        "--timeout-seconds", "5",
        "--output", "reports/relay.json"
    ])

    #expect(relayConfiguration.bindHost == "127.0.0.1")
    #expect(relayConfiguration.port == 7_001)
    #expect(relayConfiguration.sessionID == "session-1")
    #expect(relayConfiguration.expectedPeerCount == 2)
    #expect(relayConfiguration.timeoutSeconds == 5)
    #expect(relayConfiguration.outputPath == "reports/relay.json")

    let launcherConfiguration = try NatRendezvousForwarderLauncherConfiguration.parse([
        "--bind-host", "127.0.0.1",
        "--rendezvous-port", "7000",
        "--forwarder-port", "7001",
        "--session-id", "session-1",
        "--expected-peers", "2",
        "--timeout-seconds", "5",
        "--output", "reports/launcher.json"
    ])

    #expect(launcherConfiguration.bindHost == "127.0.0.1")
    #expect(launcherConfiguration.rendezvousPort == 7_000)
    #expect(launcherConfiguration.forwarderPort == 7_001)
    #expect(launcherConfiguration.sessionID == "session-1")
    #expect(launcherConfiguration.expectedPeerCount == 2)
    #expect(launcherConfiguration.timeoutSeconds == 5)
    #expect(launcherConfiguration.outputPath == "reports/launcher.json")

    #expect(throws: NatFriendlyRouteRunConfigurationError.conflictingPorts(
        "--rendezvous-port and --forwarder-port must differ"
    )) {
        try NatRendezvousForwarderLauncherConfiguration.parse([
            "--bind-host", "127.0.0.1",
            "--rendezvous-port", "7000",
            "--forwarder-port", "7000",
            "--session-id", "session-1",
            "--output", "reports/launcher.json"
        ])
    }

    let ephemeralConfiguration = try NatFriendlyRouteRunConfiguration.parse([
        "--role", "sender",
        "--bind-host", "127.0.0.1",
        "--peer-id", "sender-a",
        "--rendezvous-host", "127.0.0.1",
        "--rendezvous-port", "7000",
        "--session-id", "session-1",
        "--port", "0",
        "--duration-seconds", "2",
        "--output", "reports/nat.json"
    ])

    #expect(ephemeralConfiguration.localUdpPort == 0)
}

@Test
func natRegistrationHelpersRejectDuplicateAndUnsafePeerIDs() {
    var rendezvousRegistrations: [String: NatRendezvousRegistration] = [:]
    let firstLocal = NatEndpoint(host: "127.0.0.1", port: 5_004)
    let firstObserved = NatEndpoint(host: "203.0.113.10", port: 40_000)
    let secondLocal = NatEndpoint(host: "127.0.0.1", port: 5_005)
    let secondObserved = NatEndpoint(host: "203.0.113.11", port: 40_001)

    #expect(recordNatRendezvousRegistration(
        peerID: "peer-a",
        localEndpoint: firstLocal,
        observedEndpoint: firstObserved,
        registrations: &rendezvousRegistrations
    ))
    #expect(!recordNatRendezvousRegistration(
        peerID: "peer-a",
        localEndpoint: secondLocal,
        observedEndpoint: secondObserved,
        registrations: &rendezvousRegistrations
    ))
    #expect(rendezvousRegistrations["peer-a"]?.localEndpoint == firstLocal)
    #expect(rendezvousRegistrations["peer-a"]?.observedExternalEndpoint == firstObserved)

    var relayRegistrations: [String: NatRelayRegistration] = [:]
    var endpointsByPeerID: [String: NatEndpoint] = [:]
    #expect(recordNatRelayRegistration(
        peerID: "peer-a",
        sourceEndpoint: firstObserved,
        registrations: &relayRegistrations,
        endpointsByPeerID: &endpointsByPeerID
    ))
    #expect(!recordNatRelayRegistration(
        peerID: "peer-a",
        sourceEndpoint: secondObserved,
        registrations: &relayRegistrations,
        endpointsByPeerID: &endpointsByPeerID
    ))
    #expect(relayRegistrations["peer-a"]?.observedRelayEndpoint == firstObserved)
    #expect(endpointsByPeerID["peer-a"] == firstObserved)

    let local = NatEndpoint(host: "127.0.0.1", port: 5_004)
    let observed = NatEndpoint(host: "203.0.113.10", port: 40_000)
    var unsafeRendezvousRegistrations: [String: NatRendezvousRegistration] = [:]
    var unsafeRelayRegistrations: [String: NatRelayRegistration] = [:]
    var unsafeEndpointsByPeerID: [String: NatEndpoint] = [:]

    for peerID in ["", " peer-a", "peer a", "peer/a"] {
        #expect(!recordNatRendezvousRegistration(
            peerID: peerID,
            localEndpoint: local,
            observedEndpoint: observed,
            registrations: &unsafeRendezvousRegistrations
        ))
        #expect(!recordNatRelayRegistration(
            peerID: peerID,
            sourceEndpoint: observed,
            registrations: &unsafeRelayRegistrations,
            endpointsByPeerID: &unsafeEndpointsByPeerID
        ))
    }

    #expect(unsafeRendezvousRegistrations.isEmpty)
    #expect(unsafeRelayRegistrations.isEmpty)
    #expect(unsafeEndpointsByPeerID.isEmpty)
    #expect(natPeerIDIsSafe("peer-a_1.test"))
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
        timeoutSeconds: 2,
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
            sessionID: configuration.sessionID,
            peerID: "peer-a",
            localEndpoint: localEndpoint
        )),
        socket: clientSocket,
        port: port
    )

    guard done.wait(timeout: .now() + 3) == .success else {
        Issue.record("Timed out waiting for rendezvous report")
        return
    }
    let report = try #require(result.get()).get()
    try report.validate()

    #expect(report.registrations.map(\.peerID) == ["peer-a"])
    #expect(report.skippedDatagrams.malformed == 1)
    #expect(report.skippedDatagrams.wrongSession == 1)
    #expect(report.skippedDatagrams.wrongPeer == 0)
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
            sessionID: configuration.sessionID,
            peerID: "peer-a"
        )),
        socket: clientSocket,
        port: port
    )

    guard done.wait(timeout: .now() + 3) == .success else {
        Issue.record("Timed out waiting for relay report")
        return
    }
    let report = try #require(result.get()).get()
    try report.validate()

    #expect(report.registrations.map(\.peerID) == ["peer-a"])
    #expect(report.skippedDatagrams.malformed == 1)
    #expect(report.skippedDatagrams.wrongSession == 1)
    #expect(report.skippedDatagrams.wrongPeer == 2)
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
