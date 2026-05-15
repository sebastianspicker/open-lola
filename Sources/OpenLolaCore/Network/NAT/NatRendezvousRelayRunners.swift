import Darwin
import Dispatch
import Foundation

public enum NatRendezvousRunner {
    public static func run(
        configuration: NatRendezvousRunConfiguration,
        onReady: (() -> Void)? = nil
    ) throws -> NatRendezvousReport {
        let socket = try makeUdpSocket(receiveTimeoutSeconds: 1)
        defer { close(socket) }
        try bindIPv4(socket, host: configuration.bindHost, port: configuration.port.bigEndian)
        onReady?()

        var registrations: [String: NatRendezvousRegistration] = [:]
        var completedPeerIDs = Set<String>()
        let deadline = Date().addingTimeInterval(Double(configuration.timeoutSeconds))

        while Date() < deadline {
            guard let datagram = try receiveRendezvousDatagram(socket: socket) else {
                continue
            }
            guard let request = try? JSONDecoder().decode(
                NatRendezvousRegistrationRequest.self,
                from: datagram.data
            ), request.sessionID == configuration.sessionID else {
                continue
            }

            let observedEndpoint = endpoint(from: datagram.source)
            _ = recordNatRendezvousRegistration(
                peerID: request.peerID,
                localEndpoint: request.localEndpoint,
                observedEndpoint: observedEndpoint,
                registrations: &registrations
            )
            let peerEndpoints = registrations
                .filter { $0.key != request.peerID }
                .sorted { $0.key < $1.key }
                .map(\.value.observedExternalEndpoint)
            let peerEndpoint = peerEndpoints.first
            if !peerEndpoints.isEmpty {
                completedPeerIDs.insert(request.peerID)
            }

            let response = NatRendezvousRegistrationResponse(
                sessionID: request.sessionID,
                peerID: request.peerID,
                observedExternalEndpoint: observedEndpoint,
                peerEndpoint: peerEndpoint,
                peerEndpoints: peerEndpoints,
                registeredPeerCount: registrations.count,
                sessionComplete: registrations.count >= configuration.expectedPeerCount
            )
            try sendRendezvousDatagram(
                try JSONEncoder().encode(response),
                socket: socket,
                destination: datagram.source
            )

            let expectedPeerCount = configuration.expectedPeerCount
            if registrations.count >= expectedPeerCount,
               (expectedPeerCount <= 1 || completedPeerIDs.count >= expectedPeerCount) {
                break
            }
        }

        return NatRendezvousReport(
            id: "nat-rendezvous-\(Int(Date().timeIntervalSince1970))",
            capturedAt: currentNatTimestamp(),
            endpoint: NatEndpoint(host: configuration.bindHost, port: configuration.port),
            sessionID: configuration.sessionID,
            mode: configuration.mode,
            expectedPeerCount: configuration.expectedPeerCount,
            registrations: registrations.values.sorted { $0.peerID < $1.peerID },
            completedPeerResponses: completedPeerIDs.count,
            verdict: .partial,
            notes: "Self-hosted UDP rendezvous listener. It records observed endpoints and peer candidates; media-path validation remains with the raw UDP loopback reports."
        )
    }
}

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
        let localEndpoint = NatEndpoint(
            host: configuration.localEndpoint.host,
            port: UInt16(bigEndian: try boundPort(socket))
        )
        let request = NatRendezvousRegistrationRequest(
            sessionID: configuration.sessionID,
            peerID: configuration.peerID,
            localEndpoint: localEndpoint
        )
        let requestData = try JSONEncoder().encode(request)
        let deadline = Date().addingTimeInterval(Double(configuration.timeoutSeconds))
        var attempts = 0
        var latestResponse: NatRendezvousRegistrationResponse?

        while Date() < deadline {
            attempts += 1
            try sendDatagram(
                requestData,
                socket: socket,
                host: configuration.rendezvousEndpoint.host,
                port: configuration.rendezvousEndpoint.port.bigEndian
            )
            if let responseData = try receiveRendezvousResponse(socket: socket),
               let response = try? JSONDecoder().decode(
                   NatRendezvousRegistrationResponse.self,
                   from: responseData
               ),
               natRendezvousRegistrationResponseIsUsable(response, configuration: configuration) {
               latestResponse = response
                if response.peerEndpoint != nil || response.peerEndpoints?.isEmpty == false {
                    break
                }
            }
            try waitForReadableSocket(socket: socket, timeoutMicroseconds: 100_000)
        }

        let registered = NatRegisteredSocket(
            socket: socket,
            localEndpoint: localEndpoint,
            response: latestResponse,
            attempts: attempts
        )
        succeeded = true
        return registered
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

public enum NatRelayRunner {
    public static func run(
        configuration: NatRelayRunConfiguration,
        onReady: (() -> Void)? = nil
    ) throws -> NatRelayReport {
        let socket = try makeUdpSocket(receiveTimeoutSeconds: 1)
        defer { close(socket) }
        try bindIPv4(socket, host: configuration.bindHost, port: configuration.port.bigEndian)
        onReady?()

        var registrations: [String: NatRelayRegistration] = [:]
        var endpointsByPeerID: [String: NatEndpoint] = [:]
        var forwardedDatagrams = 0
        let deadline = Date().addingTimeInterval(Double(configuration.timeoutSeconds))

        while Date() < deadline {
            guard let datagram = try receiveRendezvousDatagram(socket: socket, byteCount: 65_535) else {
                continue
            }
            let sourceEndpoint = endpoint(from: datagram.source)

            if let request = try? JSONDecoder().decode(
                NatRelayRegistrationRequest.self,
                from: datagram.data
            ), request.magic == NatProtocolMagic.relayRegistration,
               request.sessionID == configuration.sessionID {
                _ = recordNatRelayRegistration(
                    peerID: request.peerID,
                    sourceEndpoint: sourceEndpoint,
                    registrations: &registrations,
                    endpointsByPeerID: &endpointsByPeerID
                )
                continue
            }

            guard let sourcePeerID = endpointsByPeerID.first(where: { $0.value == sourceEndpoint })?.key,
                  let destination = endpointsByPeerID
                    .filter({ $0.key != sourcePeerID })
                    .sorted(by: { $0.key < $1.key })
                    .first?
                    .value else {
                continue
            }

            try sendDatagram(
                datagram.data,
                socket: socket,
                host: destination.host,
                port: destination.port.bigEndian
            )
            forwardedDatagrams += 1
        }

        return NatRelayReport(
            id: "nat-relay-\(Int(Date().timeIntervalSince1970))",
            capturedAt: currentNatTimestamp(),
            endpoint: NatEndpoint(host: configuration.bindHost, port: configuration.port),
            sessionID: configuration.sessionID,
            expectedPeerCount: configuration.expectedPeerCount,
            registrations: registrations.values.sorted { $0.peerID < $1.peerID },
            forwardedDatagrams: forwardedDatagrams,
            verdict: .partial,
            notes: "Self-hosted UDP relay fallback. This is compatibility evidence only and cannot satisfy the fastest-path PASS gate."
        )
    }
}

func recordNatRendezvousRegistration(
    peerID: String,
    localEndpoint: NatEndpoint,
    observedEndpoint: NatEndpoint,
    registrations: inout [String: NatRendezvousRegistration]
) -> Bool {
    guard natPeerIDIsSafe(peerID) else {
        return false
    }
    guard registrations[peerID] == nil else {
        return false
    }
    registrations[peerID] = NatRendezvousRegistration(
        peerID: peerID,
        localEndpoint: localEndpoint,
        observedExternalEndpoint: observedEndpoint,
        registeredAt: currentNatTimestamp()
    )
    return true
}

func recordNatRelayRegistration(
    peerID: String,
    sourceEndpoint: NatEndpoint,
    registrations: inout [String: NatRelayRegistration],
    endpointsByPeerID: inout [String: NatEndpoint]
) -> Bool {
    guard natPeerIDIsSafe(peerID) else {
        return false
    }
    guard registrations[peerID] == nil else {
        return false
    }
    registrations[peerID] = NatRelayRegistration(
        peerID: peerID,
        observedRelayEndpoint: sourceEndpoint,
        registeredAt: currentNatTimestamp()
    )
    endpointsByPeerID[peerID] = sourceEndpoint
    return true
}

func natPeerIDIsSafe(_ peerID: String) -> Bool {
    let trimmed = peerID.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed == peerID,
          !peerID.isEmpty,
          peerID.count <= 128 else {
        return false
    }
    return peerID.allSatisfy { character in
        character.isLetter || character.isNumber || character == "-" || character == "_" || character == "."
    }
}

public enum NatRendezvousForwarderLauncherRunner {
    public static let performanceWarning =
        "WARNING: Built-in UDP rendezvous/forwarder mode may degrade performance versus raw direct P2P. Use it only as F12 compatibility evidence until raw-vs-NAT latency is measured."

    public static func run(
        configuration: NatRendezvousForwarderLauncherConfiguration
    ) throws -> NatRendezvousForwarderLauncherReport {
        let rendezvousConfiguration = NatRendezvousRunConfiguration(
            bindHost: configuration.bindHost,
            port: configuration.rendezvousPort,
            sessionID: configuration.sessionID,
            mode: .directTraversal,
            expectedPeerCount: configuration.expectedPeerCount,
            timeoutSeconds: configuration.timeoutSeconds,
            outputPath: configuration.outputPath
        )
        let forwarderConfiguration = NatRelayRunConfiguration(
            bindHost: configuration.bindHost,
            port: configuration.forwarderPort,
            sessionID: configuration.sessionID,
            expectedPeerCount: configuration.expectedPeerCount,
            timeoutSeconds: configuration.timeoutSeconds,
            outputPath: configuration.outputPath
        )

        let rendezvousDone = DispatchSemaphore(value: 0)
        let forwarderDone = DispatchSemaphore(value: 0)
        let rendezvousResult = NatSmokeResultBox<NatRendezvousReport>()
        let forwarderResult = NatSmokeResultBox<NatRelayReport>()

        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try NatRendezvousRunner.run(configuration: rendezvousConfiguration) }
            rendezvousResult.set(result)
            rendezvousDone.signal()
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try NatRelayRunner.run(configuration: forwarderConfiguration) }
            forwarderResult.set(result)
            forwarderDone.signal()
        }

        let waitTimeout = DispatchTime.now() + .seconds(configuration.timeoutSeconds + 3)
        guard rendezvousDone.wait(timeout: waitTimeout) == .success else {
            throw NatRendezvousSmokeError.timedOut("rendezvous launcher")
        }
        guard forwarderDone.wait(timeout: .now() + .seconds(3)) == .success else {
            throw NatRendezvousSmokeError.timedOut("UDP forwarder launcher")
        }
        guard let rendezvous = rendezvousResult.get() else {
            throw NatRendezvousSmokeError.timedOut("rendezvous launcher result")
        }
        guard let forwarder = forwarderResult.get() else {
            throw NatRendezvousSmokeError.timedOut("UDP forwarder launcher result")
        }

        let report = NatRendezvousForwarderLauncherReport(
            id: "nat-rendezvous-forwarder-\(Int(Date().timeIntervalSince1970))",
            capturedAt: currentNatTimestamp(),
            sessionID: configuration.sessionID,
            bindHost: configuration.bindHost,
            expectedPeerCount: configuration.expectedPeerCount,
            rendezvousReport: try rendezvous.get(),
            forwarderReport: try forwarder.get(),
            performanceWarning: performanceWarning,
            verdict: .partial,
            notes: "Combined launcher for the self-hosted UDP rendezvous listener and UDP forwarder. This is operator convenience only; raw direct P2P remains the fastest-path default."
        )
        try report.validate()
        return report
    }
}
