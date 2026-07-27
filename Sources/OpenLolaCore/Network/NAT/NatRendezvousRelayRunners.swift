// Coordinates NAT traversal execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
import Darwin
import Foundation

private struct NatRendezvousRunnerState {
    var registrations: [String: NatRendezvousRegistration] = [:]
    var completedPeerIDs = Set<String>()
    var skippedDatagrams = NatSkippedDatagramCounts()
}

private struct NatRendezvousResponseSendRequest {
    let registrationRequest: NatRendezvousRegistrationRequest
    let observedEndpoint: NatEndpoint
    let peerEndpoints: [NatEndpoint]
    let registrationCount: Int
    let sessionComplete: Bool
    let socket: Int32
    let destination: sockaddr_in
}

/// Runs NatRendezvousRunner while keeping its stateful execution separate from report validation.
public enum NatRendezvousRunner {
    public static func run(
        configuration: NatRendezvousRunConfiguration,
        onReady: (() -> Void)? = nil
    ) throws -> NatRendezvousReport {
        let socket = try bindRendezvousSocket(configuration)
        var state = NatRendezvousRunnerState()
        onReady?()
        defer { close(socket) }
        try runRendezvousLoop(socket: socket, configuration: configuration, state: &state)
        return rendezvousReport(configuration: configuration, state: state)
    }

    private static func bindRendezvousSocket(
        _ configuration: NatRendezvousRunConfiguration
    ) throws -> Int32 {
        let socket = try makeUdpSocket(receiveTimeoutSeconds: 1)
        do {
            try bindIPv4(socket, host: configuration.bindHost, port: configuration.port.bigEndian)
            return socket
        } catch {
            close(socket)
            throw error
        }
    }

    private static func runRendezvousLoop(
        socket: Int32,
        configuration: NatRendezvousRunConfiguration,
        state: inout NatRendezvousRunnerState
    ) throws {
        let deadline = MonotonicDeadline(seconds: Double(configuration.timeoutSeconds))

        while deadline.hasTimeRemaining {
            guard let datagram = try receiveRendezvousDatagram(socket: socket) else {
                continue
            }
            try handleRendezvousDatagram(
                datagram,
                socket: socket,
                configuration: configuration,
                state: &state
            )
            if rendezvousSessionIsComplete(configuration: configuration, state: state) {
                break
            }
        }
    }

    private static func handleRendezvousDatagram(
        _ datagram: (data: Data, source: sockaddr_in),
        socket: Int32,
        configuration: NatRendezvousRunConfiguration,
        state: inout NatRendezvousRunnerState
    ) throws {
        guard let request = decodeRendezvousRequest(datagram.data, skippedDatagrams: &state.skippedDatagrams) else {
            return
        }
        guard request.sessionID == configuration.sessionID else {
            state.skippedDatagrams.wrongSession += 1
            return
        }

        let observedEndpoint = endpoint(from: datagram.source)
        _ = recordNatRendezvousRegistration(
            peerID: request.peerID,
            localEndpoint: request.localEndpoint,
            observedEndpoint: observedEndpoint,
            registrations: &state.registrations
        )
        let peerEndpoints = rendezvousPeerEndpoints(for: request.peerID, registrations: state.registrations)
        if !peerEndpoints.isEmpty {
            state.completedPeerIDs.insert(request.peerID)
        }
        try sendRendezvousResponse(NatRendezvousResponseSendRequest(
            registrationRequest: request,
            observedEndpoint: observedEndpoint,
            peerEndpoints: peerEndpoints,
            registrationCount: state.registrations.count,
            sessionComplete: state.registrations.count >= configuration.expectedPeerCount,
            socket: socket,
            destination: datagram.source
        ))
    }

    private static func decodeRendezvousRequest(
        _ data: Data,
        skippedDatagrams: inout NatSkippedDatagramCounts
    ) -> NatRendezvousRegistrationRequest? {
        do {
            return try JSONDecoder().decode(NatRendezvousRegistrationRequest.self, from: data)
        } catch {
            skippedDatagrams.malformed += 1
            return nil
        }
    }

    private static func rendezvousPeerEndpoints(
        for peerID: String,
        registrations: [String: NatRendezvousRegistration]
    ) -> [NatEndpoint] {
        registrations
            .filter { $0.key != peerID }
            .sorted { $0.key < $1.key }
            .map(\.value.observedExternalEndpoint)
    }

    private static func sendRendezvousResponse(_ request: NatRendezvousResponseSendRequest) throws {
        let response = NatRendezvousRegistrationResponse(
            sessionID: request.registrationRequest.sessionID,
            peerID: request.registrationRequest.peerID,
            observedExternalEndpoint: request.observedEndpoint,
            peerEndpoint: request.peerEndpoints.first,
            peerEndpoints: request.peerEndpoints,
            registeredPeerCount: request.registrationCount,
            sessionComplete: request.sessionComplete
        )
        try sendRendezvousDatagram(
            try JSONEncoder().encode(response),
            socket: request.socket,
            destination: request.destination
        )
    }

    private static func rendezvousSessionIsComplete(
        configuration: NatRendezvousRunConfiguration,
        state: NatRendezvousRunnerState
    ) -> Bool {
        let expectedPeerCount = configuration.expectedPeerCount
        guard state.registrations.count >= expectedPeerCount else {
            return false
        }
        return expectedPeerCount <= 1 || state.completedPeerIDs.count >= expectedPeerCount
    }

    private static func rendezvousReport(
        configuration: NatRendezvousRunConfiguration,
        state: NatRendezvousRunnerState
    ) -> NatRendezvousReport {
        var input = NatRendezvousReportInput()
        input.id = "nat-rendezvous-\(Int(Date().timeIntervalSince1970))"
        input.capturedAt = currentNatTimestamp()
        input.endpoint = NatEndpoint(host: configuration.bindHost, port: configuration.port)
        input.sessionID = configuration.sessionID
        input.mode = configuration.mode
        input.expectedPeerCount = configuration.expectedPeerCount
        input.registrations = state.registrations.values.sorted { $0.peerID < $1.peerID }
        input.completedPeerResponses = state.completedPeerIDs.count
        input.skippedDatagrams = state.skippedDatagrams
        input.verdict = .partial
        input.notes = "Self-hosted UDP rendezvous listener. It records observed endpoints peer candidates; "
            + "media-path validation remains raw UDP loopback reports."
        return NatRendezvousReport(input)
    }
}

/// Registers a peer with the UDP rendezvous endpoint and returns its observed endpoint and peer candidates.
public enum NatRendezvousClient {
    public static func register(
        configuration: NatRendezvousClientConfiguration
    ) throws -> NatRendezvousClientResult {
        let registered = try openRegisteredSocket(configuration: configuration)
        defer { close(registered.socket) }
        return NatRendezvousClientResult(
            localEndpoint: registered.localEndpoint,
            response: registered.response,
            attempts: registered.attempts
        )
    }

    static func openRegisteredSocket(
        configuration: NatRendezvousClientConfiguration
    ) throws -> NatRegisteredSocket {
        let socket = try boundNatClientSocket(configuration: configuration)
        var succeeded = false
        defer {
            if !succeeded {
                closeUdpSocket(socket)
            }
        }
        let localEndpoint = NatEndpoint(
            host: configuration.localEndpoint.host,
            port: UInt16(bigEndian: try boundPort(socket))
        )
        let requestData = try natRendezvousClientRequestData(
            configuration: configuration,
            localEndpoint: localEndpoint
        )
        let registration = try awaitNatRendezvousRegistrationResponse(
            socket: socket,
            configuration: configuration,
            requestData: requestData
        )
        succeeded = true
        return NatRegisteredSocket(
            socket: socket,
            localEndpoint: localEndpoint,
            response: registration.response,
            attempts: registration.attempts
        )
    }

    private static func boundNatClientSocket(
        configuration: NatRendezvousClientConfiguration
    ) throws -> Int32 {
        let socket = try makeUdpSocket(receiveTimeoutSeconds: 1)
        var succeeded = false
        defer {
            if !succeeded {
                closeUdpSocket(socket)
            }
        }
        try bindIPv4(
            socket,
            host: configuration.localEndpoint.host,
            port: configuration.localEndpoint.port.bigEndian
        )
        succeeded = true
        return socket
    }

    private static func natRendezvousClientRequestData(
        configuration: NatRendezvousClientConfiguration,
        localEndpoint: NatEndpoint
    ) throws -> Data {
        let request = NatRendezvousRegistrationRequest(
            sessionID: configuration.sessionID,
            peerID: configuration.peerID,
            localEndpoint: localEndpoint
        )
        return try JSONEncoder().encode(request)
    }

    private static func awaitNatRendezvousRegistrationResponse(
        socket: Int32,
        configuration: NatRendezvousClientConfiguration,
        requestData: Data
    ) throws -> (response: NatRendezvousRegistrationResponse?, attempts: Int) {
        let deadline = MonotonicDeadline(seconds: Double(configuration.timeoutSeconds))
        var attempts = 0
        var latestResponse: NatRendezvousRegistrationResponse?

        while deadline.hasTimeRemaining {
            attempts += 1
            try sendDatagram(
                requestData,
                socket: socket,
                host: configuration.rendezvousEndpoint.host,
                port: configuration.rendezvousEndpoint.port.bigEndian
            )
            if let responseData = try receiveRendezvousResponse(socket: socket),
               let response = try? JSONDecoder().decode(NatRendezvousRegistrationResponse.self, from: responseData),
               natRendezvousRegistrationResponseIsUsable(response, configuration: configuration) {
                latestResponse = response
                if response.peerEndpoint != nil || response.peerEndpoints?.isEmpty == false {
                    break
                }
            }
            try waitForReadableSocket(socket: socket, timeoutMicroseconds: 100_000)
        }

        return (latestResponse, attempts)
    }
}

func natRendezvousRegistrationResponseIsUsable(
    _ response: NatRendezvousRegistrationResponse,
    configuration: NatRendezvousClientConfiguration
) -> Bool {
    guard response.sessionID == configuration.sessionID,
          response.peerID == configuration.peerID,
          natEndpointIsUsable(response.observedExternalEndpoint),
          response.registeredPeerCount > 0 else {
        return false
    }
    if let peerEndpoint = response.peerEndpoint,
       !natEndpointIsUsable(peerEndpoint) {
        return false
    }
    if let peerEndpoints = response.peerEndpoints,
       peerEndpoints.contains(where: { !natEndpointIsUsable($0) }) {
        return false
    }
    return true
}

private func natEndpointIsUsable(_ endpoint: NatEndpoint) -> Bool {
    !endpoint.host.isEmpty && endpoint.port > 0
}
