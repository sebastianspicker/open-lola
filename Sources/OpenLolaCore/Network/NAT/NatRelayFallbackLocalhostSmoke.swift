// Forces direct rendezvous failure and verifies relay registration, forwarding, and fallback over localhost without claiming an external NAT result.
import Darwin
import Dispatch
import Foundation

/// Represents the NatRelayFallbackLocalhostSmokeResult produced by NAT traversal and relay setup without exposing its execution state.
public struct NatRelayFallbackLocalhostSmokeResult: PrettyJSONCodable, Equatable, Sendable {
    public var rendezvousReport: NatRendezvousReport
    public var relayReport: NatRelayReport
    public var routeReports: [NatFriendlyRouteReport]
}

/// Provides deterministic NatRelayFallbackLocalhostSmoke coverage without requiring external NAT traversal and relay setup infrastructure.
public enum NatRelayFallbackLocalhostSmoke {
    public static func run() throws -> NatRelayFallbackLocalhostSmokeResult {
        let plan = try NatRelayFallbackSmokePlan.localhost()
        let sessionID = "localhost-relay-fallback-smoke"
        let rendezvous = startFailedDirectRendezvous(plan: plan, sessionID: sessionID)
        let relay = startRelay(plan: plan, sessionID: sessionID)
        try requireNatSmokeReady(rendezvous, timeoutLabel: "failed-direct rendezvous readiness")
        try requireNatSmokeReady(relay, timeoutLabel: "relay listener readiness")

        let sender = startRelayFallbackRouteClient(
            role: .sender,
            peerID: "sender-relay",
            plan: plan,
            sessionID: sessionID
        )
        let looper = startRelayFallbackRouteClient(
            role: .looper,
            peerID: "looper-relay",
            plan: plan,
            sessionID: sessionID
        )

        try requireNatSmokeDone(sender, timeoutLabel: "relay fallback sender client")
        try requireNatSmokeDone(looper, timeoutLabel: "relay fallback looper client")
        try requireNatSmokeDone(rendezvous, timeoutLabel: "failed-direct rendezvous listener")
        try requireNatSmokeDone(relay, timeoutLabel: "relay listener")

        return NatRelayFallbackLocalhostSmokeResult(
            rendezvousReport: try requireNatSmokeResult(
                rendezvous,
                timeoutLabel: "failed-direct rendezvous result"
            ).get(),
            relayReport: try requireNatSmokeResult(relay, timeoutLabel: "relay result").get(),
            routeReports: [
                try requireNatSmokeResult(sender, timeoutLabel: "relay fallback sender result").get(),
                try requireNatSmokeResult(looper, timeoutLabel: "relay fallback looper result").get()
            ]
        )
    }

    private static func startFailedDirectRendezvous(
        plan: NatRelayFallbackSmokePlan,
        sessionID: String
    ) -> NatReadySmokeWorker<NatRendezvousReport> {
        startReadyNatSmokeWorker { signalReady in
            try NatFailedDirectRendezvousRunner.run(
                request: NatFailedDirectRendezvousRunRequest(
                    bindHost: "127.0.0.1",
                    port: plan.rendezvousPort,
                    sessionID: sessionID,
                    peerEndpoint: plan.failedDirectEndpoint,
                    expectedPeerCount: 2,
                    timeoutSeconds: 5
                ),
                onReady: signalReady
            )
        }
    }

    private static func startRelay(
        plan: NatRelayFallbackSmokePlan,
        sessionID: String
    ) -> NatReadySmokeWorker<NatRelayReport> {
        let configuration = NatRelayRunConfiguration(
            bindHost: "127.0.0.1",
            port: plan.relayPort,
            sessionID: sessionID,
            expectedPeerCount: 2,
            timeoutSeconds: 4,
            outputPath: "stdout"
        )
        return startReadyNatSmokeWorker { signalReady in
            try NatRelayRunner.run(configuration: configuration, onReady: signalReady)
        }
    }

    private static func startRelayFallbackRouteClient(
        role: NatFriendlyRouteRole,
        peerID: String,
        plan: NatRelayFallbackSmokePlan,
        sessionID: String
    ) -> NatSmokeWorker<NatFriendlyRouteReport> {
        startNatLocalhostRouteClient(.init(
            role: role,
            peerID: peerID,
            rendezvousPort: plan.rendezvousPort,
            relayPort: plan.relayPort,
            sessionID: sessionID,
            durationSeconds: 1
        ))
    }
}

// swiftlint:disable:next type_name
/// Provides deterministic NatRendezvousForwarderLauncherLocalhostSmoke coverage without requiring external NAT traversal and relay setup infrastructure.
public enum NatRendezvousForwarderLauncherLocalhostSmoke {
    public static func run() throws -> NatRendezvousForwarderLauncherReport {
        let ports = try availableNatRendezvousPorts(count: 2)
        return try NatRendezvousForwarderLauncherRunner.run(
            configuration: NatRendezvousForwarderLauncherConfiguration(
                bindHost: "127.0.0.1",
                rendezvousPort: ports[0],
                forwarderPort: ports[1],
                sessionID: "localhost-forwarder-launcher-smoke",
                expectedPeerCount: 2,
                timeoutSeconds: 1,
                outputPath: "stdout"
            )
        )
    }
}

private struct NatFailedDirectRendezvousRunRequest {
    let bindHost: String
    let port: UInt16
    let sessionID: String
    let peerEndpoint: NatEndpoint
    let expectedPeerCount: Int
    let timeoutSeconds: Int
}

private struct NatRelayFallbackSmokePlan: Sendable {
    let rendezvousPort: UInt16
    let relayPort: UInt16
    let failedDirectEndpoint: NatEndpoint

    static func localhost() throws -> NatRelayFallbackSmokePlan {
        let ports = try availableNatRendezvousPorts(count: 3)
        return NatRelayFallbackSmokePlan(
            rendezvousPort: ports[0],
            relayPort: ports[1],
            failedDirectEndpoint: NatEndpoint(host: "127.0.0.1", port: ports[2])
        )
    }
}

private struct NatFailedDirectRendezvousState {
    var registrations: [String: NatRendezvousRegistration] = [:]
}

// swiftlint:disable:next type_name
private struct NatFailedDirectRegistrationResponseRequest {
    let registrationRequest: NatRendezvousRegistrationRequest
    let observedEndpoint: NatEndpoint
    let socket: Int32
    let destination: sockaddr_in
    let runRequest: NatFailedDirectRendezvousRunRequest
    let registrationCount: Int
}

private enum NatFailedDirectRendezvousRunner {
    static func run(
        request runRequest: NatFailedDirectRendezvousRunRequest,
        onReady: (() -> Void)? = nil
    ) throws -> NatRendezvousReport {
        let socket = try makeUdpSocket(receiveTimeoutSeconds: 1)
        defer { close(socket) }
        try bindIPv4(socket, host: runRequest.bindHost, port: runRequest.port.bigEndian)
        onReady?()

        var state = NatFailedDirectRendezvousState()
        let deadline = MonotonicDeadline(seconds: Double(runRequest.timeoutSeconds))

        while deadline.hasTimeRemaining && state.registrations.count < runRequest.expectedPeerCount {
            guard let datagram = try receiveRendezvousDatagram(socket: socket) else {
                continue
            }
            try handleRegistrationDatagram(
                datagram,
                socket: socket,
                request: runRequest,
                state: &state
            )
        }

        return report(request: runRequest, state: state)
    }

    private static func handleRegistrationDatagram(
        _ datagram: (data: Data, source: sockaddr_in),
        socket: Int32,
        request runRequest: NatFailedDirectRendezvousRunRequest,
        state: inout NatFailedDirectRendezvousState
    ) throws {
        guard let request = try? JSONDecoder().decode(
            NatRendezvousRegistrationRequest.self,
            from: datagram.data
        ), request.sessionID == runRequest.sessionID else {
            return
        }

        let observedEndpoint = endpoint(from: datagram.source)
        state.registrations[request.peerID] = NatRendezvousRegistration(
            peerID: request.peerID,
            localEndpoint: request.localEndpoint,
            observedExternalEndpoint: observedEndpoint,
            registeredAt: currentNatTimestamp()
        )
        try sendRegistrationResponse(.init(
            registrationRequest: request,
            observedEndpoint: observedEndpoint,
            socket: socket,
            destination: datagram.source,
            runRequest: runRequest,
            registrationCount: state.registrations.count
        ))
    }

    private static func sendRegistrationResponse(
        _ request: NatFailedDirectRegistrationResponseRequest
    ) throws {
        let response = NatRendezvousRegistrationResponse(
            sessionID: request.registrationRequest.sessionID,
            peerID: request.registrationRequest.peerID,
            observedExternalEndpoint: request.observedEndpoint,
            peerEndpoint: request.runRequest.peerEndpoint,
            registeredPeerCount: request.registrationCount,
            sessionComplete: request.registrationCount >= request.runRequest.expectedPeerCount
        )
        try sendRendezvousDatagram(
            try JSONEncoder().encode(response),
            socket: request.socket,
            destination: request.destination
        )
    }

    private static func report(
        request runRequest: NatFailedDirectRendezvousRunRequest,
        state: NatFailedDirectRendezvousState
    ) -> NatRendezvousReport {
        var input = NatRendezvousReportInput()
        input.id = "nat-failed-direct-rendezvous-\(Int(Date().timeIntervalSince1970))"
        input.capturedAt = currentNatTimestamp()
        input.endpoint = NatEndpoint(host: runRequest.bindHost, port: runRequest.port)
        input.sessionID = runRequest.sessionID
        input.mode = .relayFallback
        input.expectedPeerCount = runRequest.expectedPeerCount
        input.registrations = state.registrations.values.sorted { $0.peerID < $1.peerID }
        input.completedPeerResponses = state.registrations.count
        input.verdict = .partial
        input.notes = "Localhost relay fallback smoke forced direct traversal to a closed UDP endpoint " +
            "before relay use."
        return NatRendezvousReport(input)
    }
}
