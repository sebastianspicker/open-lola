// Verifies that NAT-friendly route run configuration parses arguments.
import Darwin
import Dispatch
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func natFriendlyRouteRunConfigurationParsesArguments() throws {
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
}

@Test
func natRendezvousRunConfigurationParsesArguments() throws {
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
}

@Test
func natRelayRunConfigurationParsesArguments() throws {
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
}

@Test
func natForwarderLauncherConfigurationParsesArgumentsAndRejectsConflictingPorts() throws {
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
}

@Test
func natFriendlyRouteConfigurationAcceptsEphemeralLocalPort() throws {
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
func natRendezvousRegistrationRejectsDuplicatePeerID() {
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
}

@Test
func natRelayRegistrationRejectsDuplicatePeerID() {
    let firstObserved = NatEndpoint(host: "203.0.113.10", port: 40_000)
    let secondObserved = NatEndpoint(host: "203.0.113.11", port: 40_001)
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
func natRelayRegistrationRejectsEndpointAliasesAcrossPeerIDs() {
    var registrations: [String: NatRelayRegistration] = [:]
    var endpoints: [String: NatEndpoint] = [:]
    let endpoint = NatEndpoint(host: "192.0.2.10", port: 50_000)

    #expect(recordNatRelayRegistration(
        peerID: "peer-a",
        sourceEndpoint: endpoint,
        registrations: &registrations,
        endpointsByPeerID: &endpoints
    ))
    #expect(!recordNatRelayRegistration(
        peerID: "peer-b",
        sourceEndpoint: endpoint,
        registrations: &registrations,
        endpointsByPeerID: &endpoints
    ))
    #expect(registrations.count == 1)
    #expect(endpoints == ["peer-a": endpoint])
}

@Test
func natRegistrationHelpersRejectUnsafePeerIDs() {
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
