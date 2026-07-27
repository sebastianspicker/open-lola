// Coordinates NAT traversal execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
import Darwin
import Dispatch
import Foundation

private struct NatRelayRunnerState {
    var registrations: [String: NatRelayRegistration] = [:]
    var endpointsByPeerID: [String: NatEndpoint] = [:]
    var forwardedDatagrams = 0
    var forwardingBackpressureDrops = 0
    var skippedDatagrams = NatSkippedDatagramCounts()
}

private struct NatRelayRegistrationHandling {
    let consumedDatagram: Bool
    let countedMalformed: Bool
}

/// Runs NatRelayRunner while keeping its stateful execution separate from report validation.
public enum NatRelayRunner {
    public static func run(
        configuration: NatRelayRunConfiguration,
        onReady: (() -> Void)? = nil
    ) throws -> NatRelayReport {
        let socket = try makeUdpSocket(
            receiveTimeoutSeconds: 1,
            bufferProfile: .realtimeAudio
        )
        defer { close(socket) }
        try bindIPv4(socket, host: configuration.bindHost, port: configuration.port.bigEndian)
        try setNonBlocking(socket)
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
        var receiveBuffer = [UInt8](repeating: 0, count: 65_535)

        while deadline.hasTimeRemaining {
            let remainingMicrosecondsDouble = max(
                1,
                (deadline.remainingSeconds * 1_000_000).rounded(.up)
            )
            let remainingMicroseconds = remainingMicrosecondsDouble >= Double(UInt64.max)
                ? UInt64.max
                : UInt64(remainingMicrosecondsDouble)
            _ = try waitForReadableSocket(
                socket: socket,
                timeoutMicroseconds: remainingMicroseconds
            )
            var drained = 0
            while drained < 64, deadline.hasTimeRemaining,
                  let datagram = try receiveRendezvousDatagram(
                    socket: socket,
                    byteCount: receiveBuffer.count,
                    buffer: &receiveBuffer
                  ) {
                drained += 1
                try handleRelayDatagram(datagram, socket: socket, configuration: configuration, state: &state)
            }
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

        let sendResult = try trySendDatagram(
            datagram.data,
            socket: socket,
            host: destination.host,
            port: destination.port.bigEndian,
            nonBlocking: true
        )
        if sendResult == .sent {
            state.forwardedDatagrams += 1
        } else {
            state.forwardingBackpressureDrops += 1
        }
    }

    private static func relayRegistrationHandled(
        _ datagram: (data: Data, source: sockaddr_in),
        sourceEndpoint: NatEndpoint,
        configuration: NatRelayRunConfiguration,
        state: inout NatRelayRunnerState
    ) -> NatRelayRegistrationHandling {
        guard natRelayShouldAttemptRegistrationDecode(
            sourceEndpoint: sourceEndpoint,
            data: datagram.data,
            endpointsByPeerID: state.endpointsByPeerID
        ) else {
            return NatRelayRegistrationHandling(consumedDatagram: false, countedMalformed: false)
        }
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
        guard natRelayRegistrationCapacityAllows(
            peerID: request.peerID,
            expectedPeerCount: configuration.expectedPeerCount,
            registrations: state.registrations
        ) else {
            state.skippedDatagrams.wrongPeer += 1
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
        var input = NatRelayReportInput()
        input.id = "nat-relay-\(Int(Date().timeIntervalSince1970))"
        input.capturedAt = currentNatTimestamp()
        input.endpoint = NatEndpoint(host: configuration.bindHost, port: configuration.port)
        input.sessionID = configuration.sessionID
        input.expectedPeerCount = configuration.expectedPeerCount
        input.registrations = state.registrations.values.sorted { $0.peerID < $1.peerID }
        input.forwardedDatagrams = state.forwardedDatagrams
        input.forwardingBackpressureDrops = state.forwardingBackpressureDrops
        input.skippedDatagrams = state.skippedDatagrams
        input.verdict = .partial
        input.notes = "Self-hosted UDP relay fallback. This compatibility evidence only and cannot satisfy "
            + "the fastest-path PASS gate."
        return NatRelayReport(input)
    }
}

func natRelayShouldAttemptRegistrationDecode(
    sourceEndpoint: NatEndpoint,
    data: Data,
    endpointsByPeerID: [String: NatEndpoint]
) -> Bool {
    guard endpointsByPeerID.values.contains(sourceEndpoint) == false else {
        return false
    }
    return data.first == UInt8(ascii: "{")
}

func natRelayRegistrationCapacityAllows(
    peerID: String,
    expectedPeerCount: Int,
    registrations: [String: NatRelayRegistration]
) -> Bool {
    registrations[peerID] != nil || registrations.count < max(1, expectedPeerCount)
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
    // A source endpoint identifies exactly one relay peer. Allowing aliases
    // makes source lookup ambiguous and can route media back to its sender.
    guard !endpointsByPeerID.values.contains(sourceEndpoint) else {
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

/// Runs NatRendezvousForwarderLauncherRunner while keeping its stateful execution separate from report validation.
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
