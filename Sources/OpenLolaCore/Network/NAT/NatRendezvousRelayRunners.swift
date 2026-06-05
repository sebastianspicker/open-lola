import Darwin
import Dispatch
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

private struct NatRelayRunnerState {
    var registrations: [String: NatRelayRegistration] = [:]
    var endpointsByPeerID: [String: NatEndpoint] = [:]
    var forwardedDatagrams = 0
    var skippedDatagrams = NatSkippedDatagramCounts()
}

private struct NatRelayRegistrationHandling {
    let consumedDatagram: Bool
    let countedMalformed: Bool
}

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
        NatRendezvousReport(
            id: "nat-rendezvous-\(Int(Date().timeIntervalSince1970))",
            capturedAt: currentNatTimestamp(),
            endpoint: NatEndpoint(host: configuration.bindHost, port: configuration.port),
            sessionID: configuration.sessionID,
            mode: configuration.mode,
            expectedPeerCount: configuration.expectedPeerCount,
            registrations: state.registrations.values.sorted { $0.peerID < $1.peerID },
            completedPeerResponses: state.completedPeerIDs.count,
            skippedDatagrams: state.skippedDatagrams,
            verdict: .partial,
            notes: "Self-hosted UDP rendezvous listener. It records observed endpoints and peer candidates; "
                + "media-path validation remains with the raw UDP loopback reports."
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

public enum NatRelayRunner {
    public static func run(
        configuration: NatRelayRunConfiguration,
        onReady: (() -> Void)? = nil
    ) throws -> NatRelayReport {
        let socket = try makeUdpSocket(receiveTimeoutSeconds: 1)
        defer { close(socket) }
        try bindIPv4(socket, host: configuration.bindHost, port: configuration.port.bigEndian)
        onReady?()

        var state = NatRelayRunnerState()
        try runRelayLoop(socket: socket, configuration: configuration, state: &state)
        return natRelayReport(configuration: configuration, state: state)
    }

    private static func runRelayLoop(
        socket: Int32,
        configuration: NatRelayRunConfiguration,
        state: inout NatRelayRunnerState
    ) throws {
        let deadline = MonotonicDeadline(seconds: Double(configuration.timeoutSeconds))

        while deadline.hasTimeRemaining {
            guard let datagram = try receiveRendezvousDatagram(socket: socket, byteCount: 65_535) else {
                continue
            }
            try handleRelayDatagram(datagram, socket: socket, configuration: configuration, state: &state)
        }
    }

    private static func handleRelayDatagram(
        _ datagram: (data: Data, source: sockaddr_in),
        socket: Int32,
        configuration: NatRelayRunConfiguration,
        state: inout NatRelayRunnerState
    ) throws {
        let sourceEndpoint = endpoint(from: datagram.source)
        let registrationHandling = relayRegistrationHandled(
            datagram,
            sourceEndpoint: sourceEndpoint,
            configuration: configuration,
            state: &state
        )
        if registrationHandling.consumedDatagram {
            return
        }
        guard let destination = relayDestination(for: sourceEndpoint, state: state) else {
            recordUnroutableRelayDatagram(
                datagram,
                countedMalformed: registrationHandling.countedMalformed,
                skippedDatagrams: &state.skippedDatagrams
            )
            return
        }

        try sendDatagram(
            datagram.data,
            socket: socket,
            host: destination.host,
            port: destination.port.bigEndian
        )
        state.forwardedDatagrams += 1
    }

    private static func relayRegistrationHandled(
        _ datagram: (data: Data, source: sockaddr_in),
        sourceEndpoint: NatEndpoint,
        configuration: NatRelayRunConfiguration,
        state: inout NatRelayRunnerState
    ) -> NatRelayRegistrationHandling {
        guard let request = try? JSONDecoder().decode(NatRelayRegistrationRequest.self, from: datagram.data) else {
            return NatRelayRegistrationHandling(consumedDatagram: false, countedMalformed: false)
        }
        guard request.magic == NatProtocolMagic.relayRegistration else {
            return NatRelayRegistrationHandling(
                consumedDatagram: false,
                countedMalformed: recordMalformedRelayControlIfUnknownSource(sourceEndpoint, state: &state)
            )
        }
        guard request.sessionID == configuration.sessionID else {
            state.skippedDatagrams.wrongSession += 1
            return NatRelayRegistrationHandling(consumedDatagram: true, countedMalformed: false)
        }
        if !recordNatRelayRegistration(
            peerID: request.peerID,
            sourceEndpoint: sourceEndpoint,
            registrations: &state.registrations,
            endpointsByPeerID: &state.endpointsByPeerID
        ) {
            state.skippedDatagrams.wrongPeer += 1
        }
        return NatRelayRegistrationHandling(consumedDatagram: true, countedMalformed: false)
    }

    private static func recordMalformedRelayControlIfUnknownSource(
        _ sourceEndpoint: NatEndpoint,
        state: inout NatRelayRunnerState
    ) -> Bool {
        if state.endpointsByPeerID.first(where: { $0.value == sourceEndpoint }) == nil {
            state.skippedDatagrams.malformed += 1
            return true
        }
        return false
    }

    private static func relayDestination(
        for sourceEndpoint: NatEndpoint,
        state: NatRelayRunnerState
    ) -> NatEndpoint? {
        guard let sourcePeerID = state.endpointsByPeerID.first(where: { $0.value == sourceEndpoint })?.key else {
            return nil
        }
        return state.endpointsByPeerID
            .filter { $0.key != sourcePeerID }
            .sorted { $0.key < $1.key }
            .first?
            .value
    }

    private static func recordUnroutableRelayDatagram(
        _ datagram: (data: Data, source: sockaddr_in),
        countedMalformed: Bool,
        skippedDatagrams: inout NatSkippedDatagramCounts
    ) {
        skippedDatagrams.wrongPeer += 1
        if !countedMalformed, datagram.data.first == UInt8(ascii: "{") {
            skippedDatagrams.malformed += 1
        }
    }

    private static func natRelayReport(
        configuration: NatRelayRunConfiguration,
        state: NatRelayRunnerState
    ) -> NatRelayReport {
        NatRelayReport(
            id: "nat-relay-\(Int(Date().timeIntervalSince1970))",
            capturedAt: currentNatTimestamp(),
            endpoint: NatEndpoint(host: configuration.bindHost, port: configuration.port),
            sessionID: configuration.sessionID,
            expectedPeerCount: configuration.expectedPeerCount,
            registrations: state.registrations.values.sorted { $0.peerID < $1.peerID },
            forwardedDatagrams: state.forwardedDatagrams,
            skippedDatagrams: state.skippedDatagrams,
            verdict: .partial,
            notes: "Self-hosted UDP relay fallback. This is compatibility evidence only and cannot satisfy "
                + "the fastest-path PASS gate."
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
        "WARNING: Built-in UDP rendezvous/forwarder mode may degrade performance versus raw direct P2P. "
        + "Use it only as F12 compatibility evidence until raw-vs-NAT latency is measured."

    public static func run(
        configuration: NatRendezvousForwarderLauncherConfiguration
    ) throws -> NatRendezvousForwarderLauncherReport {
        let rendezvousConfiguration = launcherRendezvousConfiguration(configuration)
        let forwarderConfiguration = launcherForwarderConfiguration(configuration)
        let rendezvousDone = DispatchSemaphore(value: 0)
        let forwarderDone = DispatchSemaphore(value: 0)
        let rendezvousResult = NatSmokeResultBox<NatRendezvousReport>()
        let forwarderResult = NatSmokeResultBox<NatRelayReport>()

        startRendezvousLauncherWorker(
            configuration: rendezvousConfiguration,
            result: rendezvousResult,
            done: rendezvousDone
        )
        startForwarderLauncherWorker(
            configuration: forwarderConfiguration,
            result: forwarderResult,
            done: forwarderDone
        )

        let results = try waitForForwarderLauncherResults(
            configuration: configuration,
            rendezvousDone: rendezvousDone,
            forwarderDone: forwarderDone,
            rendezvousResult: rendezvousResult,
            forwarderResult: forwarderResult
        )
        return try forwarderLauncherReport(configuration: configuration, results: results)
    }

    private static func launcherRendezvousConfiguration(
        _ configuration: NatRendezvousForwarderLauncherConfiguration
    ) -> NatRendezvousRunConfiguration {
        NatRendezvousRunConfiguration(
            bindHost: configuration.bindHost,
            port: configuration.rendezvousPort,
            sessionID: configuration.sessionID,
            mode: .directTraversal,
            expectedPeerCount: configuration.expectedPeerCount,
            timeoutSeconds: configuration.timeoutSeconds,
            outputPath: configuration.outputPath
        )
    }

    private static func launcherForwarderConfiguration(
        _ configuration: NatRendezvousForwarderLauncherConfiguration
    ) -> NatRelayRunConfiguration {
        NatRelayRunConfiguration(
            bindHost: configuration.bindHost,
            port: configuration.forwarderPort,
            sessionID: configuration.sessionID,
            expectedPeerCount: configuration.expectedPeerCount,
            timeoutSeconds: configuration.timeoutSeconds,
            outputPath: configuration.outputPath
        )
    }

    private static func startRendezvousLauncherWorker(
        configuration: NatRendezvousRunConfiguration,
        result: NatSmokeResultBox<NatRendezvousReport>,
        done: DispatchSemaphore
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            result.set(Result { try NatRendezvousRunner.run(configuration: configuration) })
            done.signal()
        }
    }

    private static func startForwarderLauncherWorker(
        configuration: NatRelayRunConfiguration,
        result: NatSmokeResultBox<NatRelayReport>,
        done: DispatchSemaphore
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            result.set(Result { try NatRelayRunner.run(configuration: configuration) })
            done.signal()
        }
    }

    private static func waitForForwarderLauncherResults(
        configuration: NatRendezvousForwarderLauncherConfiguration,
        rendezvousDone: DispatchSemaphore,
        forwarderDone: DispatchSemaphore,
        rendezvousResult: NatSmokeResultBox<NatRendezvousReport>,
        forwarderResult: NatSmokeResultBox<NatRelayReport>
    ) throws -> (
        rendezvous: Result<NatRendezvousReport, Error>,
        forwarder: Result<NatRelayReport, Error>
    ) {
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
        return (rendezvous, forwarder)
    }

    private static func forwarderLauncherReport(
        configuration: NatRendezvousForwarderLauncherConfiguration,
        results: (rendezvous: Result<NatRendezvousReport, Error>, forwarder: Result<NatRelayReport, Error>)
    ) throws -> NatRendezvousForwarderLauncherReport {
        let report = NatRendezvousForwarderLauncherReport(
            id: "nat-rendezvous-forwarder-\(Int(Date().timeIntervalSince1970))",
            capturedAt: currentNatTimestamp(),
            sessionID: configuration.sessionID,
            bindHost: configuration.bindHost,
            expectedPeerCount: configuration.expectedPeerCount,
            rendezvousReport: try results.rendezvous.get(),
            forwarderReport: try results.forwarder.get(),
            performanceWarning: performanceWarning,
            verdict: .partial,
            notes: "Combined launcher for the self-hosted UDP rendezvous listener and UDP forwarder. "
                + "This is operator convenience only; raw direct P2P remains the fastest-path default."
        )
        try report.validate()
        return report
    }
}
