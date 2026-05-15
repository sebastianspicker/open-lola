import Darwin
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func natFriendlyRouteConfigurationParsesSenderArguments() throws {
    let configuration = try NatFriendlyRouteRunConfiguration.parse([
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

    #expect(configuration.role == .sender)
    #expect(configuration.bindHost == "127.0.0.1")
    #expect(configuration.peerID == "looper-a")
    #expect(configuration.rendezvousHost == "127.0.0.1")
    #expect(configuration.rendezvousPort == 7_000)
    #expect(configuration.relayHost == "127.0.0.1")
    #expect(configuration.relayPort == 7_001)
    #expect(configuration.sessionID == "session-1")
    #expect(configuration.localUdpPort == 5_004)
    #expect(configuration.durationSeconds == 2)
    #expect(configuration.keepaliveIntervalMilliseconds == 250)
    #expect(configuration.rawRouteRttMicroseconds == 120)
    #expect(configuration.outputPath == "reports/nat.json")
    #expect(configuration.debugOutputPath == "reports/nat-debug.jsonl")
}

@Test
func natRendezvousConfigurationParsesListenerArguments() throws {
    let configuration = try NatRendezvousRunConfiguration.parse([
        "--bind-host", "127.0.0.1",
        "--port", "7000",
        "--session-id", "session-1",
        "--mode", "rendezvousOnly",
        "--expected-peers", "2",
        "--timeout-seconds", "5",
        "--output", "reports/rendezvous.json"
    ])

    #expect(configuration.bindHost == "127.0.0.1")
    #expect(configuration.port == 7_000)
    #expect(configuration.sessionID == "session-1")
    #expect(configuration.mode == .rendezvousOnly)
    #expect(configuration.expectedPeerCount == 2)
    #expect(configuration.timeoutSeconds == 5)
    #expect(configuration.outputPath == "reports/rendezvous.json")
}

@Test
func natRelayConfigurationParsesListenerArguments() throws {
    let configuration = try NatRelayRunConfiguration.parse([
        "--bind-host", "127.0.0.1",
        "--port", "7001",
        "--session-id", "session-1",
        "--expected-peers", "2",
        "--timeout-seconds", "5",
        "--output", "reports/relay.json"
    ])

    #expect(configuration.bindHost == "127.0.0.1")
    #expect(configuration.port == 7_001)
    #expect(configuration.sessionID == "session-1")
    #expect(configuration.expectedPeerCount == 2)
    #expect(configuration.timeoutSeconds == 5)
    #expect(configuration.outputPath == "reports/relay.json")
}

@Test
func natRendezvousForwarderLauncherParsesArguments() throws {
    let configuration = try NatRendezvousForwarderLauncherConfiguration.parse([
        "--bind-host", "127.0.0.1",
        "--rendezvous-port", "7000",
        "--forwarder-port", "7001",
        "--session-id", "session-1",
        "--expected-peers", "2",
        "--timeout-seconds", "5",
        "--output", "reports/launcher.json"
    ])

    #expect(configuration.bindHost == "127.0.0.1")
    #expect(configuration.rendezvousPort == 7_000)
    #expect(configuration.forwarderPort == 7_001)
    #expect(configuration.sessionID == "session-1")
    #expect(configuration.expectedPeerCount == 2)
    #expect(configuration.timeoutSeconds == 5)
    #expect(configuration.outputPath == "reports/launcher.json")
}

@Test
func natRendezvousForwarderLauncherRejectsSharedPorts() throws {
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
}

@Test
func natFriendlyRouteConfigurationAllowsEphemeralClientPort() throws {
    let configuration = try NatFriendlyRouteRunConfiguration.parse([
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

    #expect(configuration.localUdpPort == 0)
}

@Test
func natEndpointFallbackFormatsRawIPv4Address() {
    #expect(numericIPv4AddressFallback(in_addr(s_addr: UInt32(bigEndian: 0xC0A8_0107))) == "192.168.1.7")
}

@Test
func natRegistrationHelpersRejectDuplicatePeerIDsWithoutOverwrite() {
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
}

@Test
func natRegistrationHelpersRejectUnsafePeerIDs() {
    let local = NatEndpoint(host: "127.0.0.1", port: 5_004)
    let observed = NatEndpoint(host: "203.0.113.10", port: 40_000)
    var rendezvousRegistrations: [String: NatRendezvousRegistration] = [:]
    var relayRegistrations: [String: NatRelayRegistration] = [:]
    var endpointsByPeerID: [String: NatEndpoint] = [:]

    for peerID in ["", " peer-a", "peer a", "peer/a"] {
        #expect(!recordNatRendezvousRegistration(
            peerID: peerID,
            localEndpoint: local,
            observedEndpoint: observed,
            registrations: &rendezvousRegistrations
        ))
        #expect(!recordNatRelayRegistration(
            peerID: peerID,
            sourceEndpoint: observed,
            registrations: &relayRegistrations,
            endpointsByPeerID: &endpointsByPeerID
        ))
    }

    #expect(rendezvousRegistrations.isEmpty)
    #expect(relayRegistrations.isEmpty)
    #expect(endpointsByPeerID.isEmpty)
    #expect(natPeerIDIsSafe("peer-a_1.test"))
}

@Test
func natRendezvousClientRejectsIncompleteRegistrationResponses() {
    let configuration = NatRendezvousClientConfiguration(
        sessionID: "session-1",
        peerID: "peer-a",
        localEndpoint: NatEndpoint(host: "127.0.0.1", port: 5_004),
        rendezvousEndpoint: NatEndpoint(host: "127.0.0.1", port: 7_000),
        timeoutSeconds: 1
    )
    let valid = NatRendezvousRegistrationResponse(
        sessionID: "session-1",
        peerID: "peer-a",
        observedExternalEndpoint: NatEndpoint(host: "203.0.113.10", port: 40_000),
        peerEndpoint: nil,
        registeredPeerCount: 1,
        sessionComplete: false
    )

    #expect(natRendezvousRegistrationResponseIsUsable(valid, configuration: configuration))
    #expect(!natRendezvousRegistrationResponseIsUsable(
        NatRendezvousRegistrationResponse(
            sessionID: "session-2",
            peerID: "peer-a",
            observedExternalEndpoint: NatEndpoint(host: "203.0.113.10", port: 40_000),
            peerEndpoint: nil,
            registeredPeerCount: 1,
            sessionComplete: false
        ),
        configuration: configuration
    ))
    #expect(!natRendezvousRegistrationResponseIsUsable(
        NatRendezvousRegistrationResponse(
            sessionID: "session-1",
            peerID: "peer-a",
            observedExternalEndpoint: NatEndpoint(host: "", port: 40_000),
            peerEndpoint: nil,
            registeredPeerCount: 1,
            sessionComplete: false
        ),
        configuration: configuration
    ))
    #expect(!natRendezvousRegistrationResponseIsUsable(
        NatRendezvousRegistrationResponse(
            sessionID: "session-1",
            peerID: "peer-a",
            observedExternalEndpoint: NatEndpoint(host: "203.0.113.10", port: 0),
            peerEndpoint: nil,
            registeredPeerCount: 1,
            sessionComplete: false
        ),
        configuration: configuration
    ))
    #expect(!natRendezvousRegistrationResponseIsUsable(
        NatRendezvousRegistrationResponse(
            sessionID: "session-1",
            peerID: "peer-a",
            observedExternalEndpoint: NatEndpoint(host: "203.0.113.10", port: 40_000),
            peerEndpoint: NatEndpoint(host: "", port: 40_001),
            registeredPeerCount: 2,
            sessionComplete: false
        ),
        configuration: configuration
    ))
    #expect(!natRendezvousRegistrationResponseIsUsable(
        NatRendezvousRegistrationResponse(
            sessionID: "session-1",
            peerID: "peer-a",
            observedExternalEndpoint: NatEndpoint(host: "203.0.113.10", port: 40_000),
            peerEndpoint: nil,
            peerEndpoints: [NatEndpoint(host: "203.0.113.11", port: 0)],
            registeredPeerCount: 2,
            sessionComplete: false
        ),
        configuration: configuration
    ))
    #expect(!natRendezvousRegistrationResponseIsUsable(
        NatRendezvousRegistrationResponse(
            sessionID: "session-1",
            peerID: "peer-a",
            observedExternalEndpoint: NatEndpoint(host: "203.0.113.10", port: 40_000),
            peerEndpoint: nil,
            registeredPeerCount: 0,
            sessionComplete: false
        ),
        configuration: configuration
    ))
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
    #expect(result.routeReports.count == 2)
    #expect(result.routeReports.allSatisfy { $0.compatibilityMode == .relayFallback })
    #expect(result.routeReports.allSatisfy { $0.rawP2PPreferred })
    #expect(result.routeReports.allSatisfy { $0.traversal.directCandidateDiscovered })
    #expect(result.routeReports.allSatisfy { !$0.traversal.directTraversalSucceeded })
    #expect(result.routeReports.allSatisfy { $0.traversal.relayUsed })
    #expect(result.routeReports.allSatisfy { $0.traversal.relayFallbackRttMicroseconds != nil })
}

@Test
func rendezvousForwarderLauncherStartsBothServicesAndWarns() throws {
    let report = try NatRendezvousForwarderLauncherLocalhostSmoke.run()

    try report.validate()

    #expect(report.verdict == .partial)
    #expect(report.performanceWarning.contains("may degrade performance"))
    #expect(report.performanceWarning.contains("raw-vs-NAT latency"))
    #expect(report.rendezvousReport.endpoint.host == "127.0.0.1")
    #expect(report.forwarderReport.endpoint.host == "127.0.0.1")
    #expect(report.rendezvousReport.endpoint.port != report.forwarderReport.endpoint.port)
    #expect(report.rendezvousReport.registrations.isEmpty)
    #expect(report.forwarderReport.registrations.isEmpty)
    #expect(report.forwarderReport.forwardedDatagrams == 0)
}

@Test
func rendezvousServiceRegistersTwoLocalClientsAndReturnsPeerEndpoints() throws {
    let result = try NatRendezvousLocalhostSmoke.run()

    try result.serverReport.validate()
    for report in result.routeReports {
        try report.validate()
    }

    #expect(result.serverReport.registrations.count == 2)
    #expect(result.routeReports.count == 2)
    #expect(result.routeReports.allSatisfy { $0.rawP2PPreferred })
    #expect(result.routeReports.allSatisfy { $0.traversal.observedExternalEndpoint != nil })
    #expect(result.routeReports.allSatisfy { $0.traversal.peerEndpoint != nil })
    #expect(result.routeReports.allSatisfy { $0.traversal.directCandidateDiscovered })
    #expect(result.routeReports.allSatisfy { !$0.traversal.relayUsed })
}

@Test
func directTraversalFeedsEstablishedSocketIntoLoopbackMeasurement() throws {
    let result = try NatRendezvousLocalhostSmoke.run()

    try result.serverReport.validate()
    for report in result.routeReports {
        try report.validate()
    }

    let sender = try #require(result.routeReports.first { $0.role == .sender })
    let looper = try #require(result.routeReports.first { $0.role == .looper })

    #expect(sender.traversal.directTraversalSucceeded)
    #expect(looper.traversal.directTraversalSucceeded)
    #expect(sender.traversal.directTraversalRttMicroseconds != nil)
    #expect(sender.traversal.rawRouteRttMicroseconds == 0)
    #expect(sender.traversal.addedLatencyMicroseconds >= 0)
    #expect(sender.loopback?.metrics.byteExactEcho == true)
    #expect(sender.loopback?.metrics.packetsEchoed ?? 0 > 0)
    #expect(looper.loopback?.metrics.packetsEchoed ?? 0 > 0)
}

@Test
func relayFallbackPartialReportRequiresFailedDirectTraversal() throws {
    var report = NatFriendlyRouteSyntheticSmoke.run()
    report.compatibilityMode = .relayFallback
    report.traversal.relayUsed = true
    report.traversal.directCandidateDiscovered = true
    report.traversal.directTraversalSucceeded = true

    #expect(throws: NatFriendlyRouteValidationError.relayFallbackWithoutFailedDirectTraversal) {
        try report.validate()
    }
}

@Test
func natFriendlyRouteReportRejectsFastestPassWithRelayFallback() throws {
    var report = NatFriendlyRouteSyntheticSmoke.run()
    report.verdict = .pass
    report.compatibilityMode = .relayFallback
    report.rawP2PPreferred = false

    #expect(throws: NatFriendlyRouteValidationError.passWithRelayAsFastestPath) {
        try report.validate()
    }
}

@Test
func natFriendlyRouteReportRejectsFastestPassWithRendezvousOnlyMode() throws {
    var report = NatFriendlyRouteSyntheticSmoke.run()
    var loopback = try #require(report.loopback)
    loopback.verdict = .pass
    report.loopback = loopback
    report.verdict = .pass
    report.compatibilityMode = .rendezvousOnly
    report.traversal.rawRouteRttMicroseconds = 0

    #expect(throws: NatFriendlyRouteValidationError.passWithRendezvousOnlyMode) {
        try report.validate()
    }
}

@Test
func natFriendlyRouteReportRejectsFastestPassWithoutPassingLoopback() throws {
    var report = NatFriendlyRouteSyntheticSmoke.run()
    report.verdict = .pass
    report.traversal.rawRouteRttMicroseconds = 0

    #expect(throws: NatFriendlyRouteValidationError.passWithoutPassingLoopback) {
        try report.validate()
    }
}

@Test
func natFriendlyRouteReportRejectsDirectTraversalSuccessWithFailedLoopback() throws {
    var report = NatFriendlyRouteSyntheticSmoke.run()
    var loopback = try #require(report.loopback)
    loopback.metrics.byteExactEcho = false
    report.loopback = loopback
    report.traversal.directTraversalSucceeded = true

    #expect(throws: NatFriendlyRouteValidationError.directTraversalWithFailedLoopback) {
        try report.validate()
    }
}

@Test
func natFriendlyRouteReportRejectsFastestPassWithoutRawRouteBaseline() throws {
    var report = NatFriendlyRouteSyntheticSmoke.run()
    var loopback = try #require(report.loopback)
    loopback.verdict = .pass
    report.loopback = loopback
    report.verdict = .pass
    report.traversal.rawRouteRttMicroseconds = nil

    #expect(throws: NatFriendlyRouteValidationError.passWithoutRawRouteBaseline) {
        try report.validate()
    }
}

@Test
func natFriendlyRouteReportRoundTrips() throws {
    let report = NatFriendlyRouteSyntheticSmoke.run()
    let decoded = try NatFriendlyRouteReport.decode(from: try report.prettyJSONData())

    try decoded.validate()

    #expect(decoded == report)
}

@Test
func natFriendlyRouteRunnerRequiresExplicitAckAndNonEmptyPeerID() throws {
    let source = try readNatFriendlyRouteSource("Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteRunner.swift")

    #expect(source.contains("!message.peerID.isEmpty"))
    #expect(source.contains("`configuration.peerID` is this client's local ID"))
    #expect(source.contains("message.peerID != configuration.peerID"))
    #expect(source.contains("if let ackSequence = message.ackSequence, ackSequence == sequence"))
}

@Test
func natFriendlyRouteRunnerNamesDirectTraversalPerAttemptTimeout() throws {
    let source = try readNatFriendlyRouteSource("Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteRunner.swift")

    #expect(source.contains("let perAttemptTimeoutNanoseconds = keepaliveIntervalNanoseconds"))
    #expect(source.contains("wrapping subtraction preserves elapsed-time checks across overflow"))
    #expect(source.contains("if now &- lastSend >= perAttemptTimeoutNanoseconds"))
    #expect(source.contains("nat-direct-traversal-finished"))
}

@Test
func natProtocolMagicStringsComeFromSharedConstants() throws {
    let constants = try readNatFriendlyRouteSource(
        "Sources/OpenLolaCore/Network/NAT/NatProtocolConstants.swift"
    )
    let runner = try readNatFriendlyRouteSource(
        "Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteRunner.swift"
    )
    let relay = try readNatFriendlyRouteSource(
        "Sources/OpenLolaCore/Network/NAT/NatRendezvousRelayRunners.swift"
    )
    let reports = try readNatFriendlyRouteSource(
        "Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteReports.swift"
    )

    #expect(constants.contains("static let keepalive = \"open-lola-nat-keepalive-v1\""))
    #expect(constants.contains("static let relayRegistration = \"open-lola-nat-relay-register-v1\""))
    #expect(runner.contains("magic: NatProtocolMagic.keepalive"))
    #expect(runner.contains("message.magic == NatProtocolMagic.keepalive"))
    #expect(relay.contains("request.magic == NatProtocolMagic.relayRegistration"))
    #expect(reports.contains("self.magic = NatProtocolMagic.relayRegistration"))
}

@Test
func natFriendlyLocalhostSmokeGuardsMissingRouteReports() throws {
    let source = try readNatFriendlyRouteSource("Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteSmokes.swift")

    #expect(source.contains("routeReports.first"))
    #expect(!source.contains("routeReports[0]"))
}

@Test
func natFriendlySmokePropagatesBackgroundErrors() throws {
    let source = try readNatFriendlyRouteSource("Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteSmokes.swift")

    #expect(source.contains("NatSmokeResultBox"))
    #expect(source.contains("let result = Result {"))
    #expect(source.contains("try sender.get()"))
    #expect(source.contains("try looper.get()"))
    #expect(!source.contains("print("))
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

private func readNatFriendlyRouteSource(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
