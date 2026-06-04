import Darwin
import Dispatch
import Foundation

private enum NatRelayClient {
    static func register(
        socket: Int32,
        configuration: NatFriendlyRouteRunConfiguration,
        relayEndpoint: NatEndpoint,
        debug: inout DebugTrace
    ) throws {
        try connectUdpSocket(socket, host: relayEndpoint.host, port: relayEndpoint.port.bigEndian)
        let request = NatRelayRegistrationRequest(
            sessionID: configuration.sessionID,
            peerID: configuration.peerID
        )
        try sendConnectedDatagram(try JSONEncoder().encode(request), socket: socket)
        debug.record(
            event: "nat-relay-fallback-registered",
            fields: ["relayEndpoint": endpointDescription(relayEndpoint)]
        )
    }
}

private struct NatDirectTraversalResult {
    let succeeded: Bool
    let rttMicroseconds: Double?
    let keepaliveAttempts: Int
}

private struct NatFriendlyRouteAttemptResult {
    let directTraversalResult: NatDirectTraversalResult
    let loopback: UdpPcmLoopbackReport?
    let compatibilityMode: NatFriendlyCompatibilityMode
    let relayUsed: Bool
}

private struct NatFriendlyRouteMetrics {
    let directTraversalRtt: Double?
    let relayFallbackRtt: Double?
    let addedLatency: Double
    let loopbackSucceeded: Bool
}

struct NatTraversalKeepaliveMessage: Codable {
    var magic: String
    var sessionID: String
    var peerID: String
    var sequence: UInt64
    var sentAtNanoseconds: UInt64
    var ackSequence: UInt64?
}

private enum NatDirectTraversalRunner {
    static func establish(
        socket: Int32,
        configuration: NatFriendlyRouteRunConfiguration,
        peerEndpoint: NatEndpoint,
        debug: inout DebugTrace
    ) throws -> NatDirectTraversalResult {
        debug.record(
            event: "nat-direct-connect-attempt",
            fields: ["peerEndpoint": endpointDescription(peerEndpoint)]
        )
        try connectUdpSocket(socket, host: peerEndpoint.host, port: peerEndpoint.port.bigEndian)
        try setNonBlocking(socket)
        debug.record(
            event: "nat-direct-connected",
            fields: ["peerEndpoint": endpointDescription(peerEndpoint)]
        )

        let sequence = UInt64.random(in: 1...UInt64.max)
        let deadline = try routeDeadlineNanoseconds(durationSeconds: configuration.durationSeconds)
        var attempts = 0
        var lastSend: UInt64 = 0
        var sawPeerKeepalive = false
        var rttMicroseconds: Double?

        let keepaliveIntervalNanoseconds = natKeepaliveIntervalNanoseconds(
            milliseconds: configuration.keepaliveIntervalMilliseconds
        )
        let perAttemptTimeoutNanoseconds = keepaliveIntervalNanoseconds
        while DispatchTime.now().uptimeNanoseconds < deadline {
            let now = DispatchTime.now().uptimeNanoseconds
            // Uptime is monotonic UInt64; wrapping subtraction preserves elapsed-time checks across overflow.
            if now &- lastSend >= perAttemptTimeoutNanoseconds {
                let message = NatTraversalKeepaliveMessage(
                    magic: NatProtocolMagic.keepalive,
                    sessionID: configuration.sessionID,
                    peerID: configuration.peerID,
                    sequence: sequence,
                    sentAtNanoseconds: now,
                    ackSequence: sawPeerKeepalive ? sequence : nil
                )
                try sendConnectedDatagram(try JSONEncoder().encode(message), socket: socket)
                attempts += 1
                lastSend = now
                debug.record(
                    event: "nat-keepalive-sent",
                    fields: ["attempt": "\(attempts)", "sequence": "\(sequence)"]
                )
            }

            if let received = try receiveNatTraversalDatagramIfAvailable(socket: socket),
               let message = try? JSONDecoder().decode(
                   NatTraversalKeepaliveMessage.self,
                   from: received
               ),
               message.magic == NatProtocolMagic.keepalive,
               message.sessionID == configuration.sessionID,
               // `configuration.peerID` is this client's local ID; the connected UDP socket
               // already restricts packets to the rendezvous-selected peer endpoint.
               !message.peerID.isEmpty,
               message.peerID != configuration.peerID {
                sawPeerKeepalive = true
                debug.record(
                    event: "nat-keepalive-received",
                    fields: ["peerID": message.peerID, "sequence": "\(message.sequence)"]
                )
                let acknowledgement = NatTraversalKeepaliveMessage(
                    magic: NatProtocolMagic.keepalive,
                    sessionID: configuration.sessionID,
                    peerID: configuration.peerID,
                    sequence: sequence,
                    sentAtNanoseconds: DispatchTime.now().uptimeNanoseconds,
                    ackSequence: message.sequence
                )
                try sendConnectedDatagram(try JSONEncoder().encode(acknowledgement), socket: socket)
                if let ackSequence = message.ackSequence, ackSequence == sequence {
                    rttMicroseconds = Double(
                        DispatchTime.now().uptimeNanoseconds - message.sentAtNanoseconds
                    ) / 1_000
                    break
                }
            }

            if sawPeerKeepalive {
                break
            }
            try waitForReadableSocket(socket: socket, timeoutMicroseconds: 1_000)
        }

        debug.record(
            event: "nat-direct-traversal-finished",
            fields: [
                "succeeded": "\(sawPeerKeepalive)",
                "attempts": "\(attempts)",
                "rttMicroseconds": rttMicroseconds.map { "\($0)" } ?? "unknown"
            ]
        )
        return NatDirectTraversalResult(
            succeeded: sawPeerKeepalive,
            rttMicroseconds: rttMicroseconds,
            keepaliveAttempts: attempts
        )
    }
}

public enum NatFriendlyRouteRunner {
    public static func run(
        configuration: NatFriendlyRouteRunConfiguration
    ) throws -> (report: NatFriendlyRouteReport, debugTrace: DebugTrace?) {
        var debug = DebugTrace()
        recordRouteStart(configuration: configuration, debug: &debug)
        let clientResult = try NatRendezvousClient.openRegisteredSocket(
            configuration: NatRendezvousClientConfiguration(
                sessionID: configuration.sessionID,
                peerID: configuration.peerID,
                localEndpoint: NatEndpoint(
                    host: configuration.bindHost,
                    port: configuration.localUdpPort
                ),
                rendezvousEndpoint: NatEndpoint(
                    host: configuration.rendezvousHost,
                    port: configuration.rendezvousPort
                ),
                timeoutSeconds: configuration.durationSeconds
            )
        )
        defer { close(clientResult.socket) }
        let observedEndpoint = clientResult.response?.observedExternalEndpoint
        let peerEndpoint = clientResult.response?.peerEndpoint
        recordRendezvousRegistration(
            clientResult: clientResult,
            observedEndpoint: observedEndpoint,
            peerEndpoint: peerEndpoint,
            debug: &debug
        )
        let attempt = try runRouteAttempt(
            socket: clientResult.socket,
            configuration: configuration,
            localEndpoint: clientResult.localEndpoint,
            peerEndpoint: peerEndpoint,
            debug: &debug
        )
        let report = makeNatFriendlyRouteReport(
            configuration: configuration,
            localEndpoint: clientResult.localEndpoint,
            observedEndpoint: observedEndpoint,
            peerEndpoint: peerEndpoint,
            attempt: attempt
        )
        return (report, configuration.debugOutputPath == nil ? nil : debug)
    }

    private static func recordRouteStart(
        configuration: NatFriendlyRouteRunConfiguration,
        debug: inout DebugTrace
    ) {
        debug.record(
            event: "nat-route-start",
            fields: [
                "role": configuration.role.rawValue,
                "sessionID": configuration.sessionID,
                "peerID": configuration.peerID
            ]
        )
    }

    private static func recordRendezvousRegistration(
        clientResult: NatRegisteredSocket,
        observedEndpoint: NatEndpoint?,
        peerEndpoint: NatEndpoint?,
        debug: inout DebugTrace
    ) {
        debug.record(
            event: "nat-rendezvous-registration",
            fields: [
                "attempts": "\(clientResult.attempts)",
                "observedExternalEndpoint": observedEndpoint.map(endpointDescription) ?? "none",
                "peerEndpoint": peerEndpoint.map(endpointDescription) ?? "none"
            ]
        )
    }

    private static func runRouteAttempt(
        socket: Int32,
        configuration: NatFriendlyRouteRunConfiguration,
        localEndpoint: NatEndpoint,
        peerEndpoint: NatEndpoint?,
        debug: inout DebugTrace
    ) throws -> NatFriendlyRouteAttemptResult {
        let directTraversalResult: NatDirectTraversalResult
        var loopback: UdpPcmLoopbackReport?
        var compatibilityMode = NatFriendlyCompatibilityMode.directTraversal
        var relayUsed = false
        guard let peerEndpoint else {
            return noPeerRouteAttemptResult()
        }
        directTraversalResult = try NatDirectTraversalRunner.establish(
            socket: socket,
            configuration: configuration,
            peerEndpoint: peerEndpoint,
            debug: &debug
        )
        if directTraversalResult.succeeded {
            loopback = try runDirectTraversalLoopback(
                socket: socket,
                configuration: configuration,
                localEndpoint: localEndpoint,
                peerEndpoint: peerEndpoint,
                debug: &debug
            )
        } else if let relayEndpoint = relayEndpoint(from: configuration) {
            loopback = try runRelayFallbackLoopback(
                socket: socket,
                configuration: configuration,
                localEndpoint: localEndpoint,
                peerEndpoint: relayEndpoint,
                debug: &debug
            )
            compatibilityMode = .relayFallback
            relayUsed = true
        }
        return NatFriendlyRouteAttemptResult(
            directTraversalResult: directTraversalResult,
            loopback: loopback,
            compatibilityMode: compatibilityMode,
            relayUsed: relayUsed
        )
    }

    private static func noPeerRouteAttemptResult() -> NatFriendlyRouteAttemptResult {
        NatFriendlyRouteAttemptResult(
            directTraversalResult: NatDirectTraversalResult(
                succeeded: false,
                rttMicroseconds: nil,
                keepaliveAttempts: 0
            ),
            loopback: nil,
            compatibilityMode: .directTraversal,
            relayUsed: false
        )
    }

    private static func runDirectTraversalLoopback(
        socket: Int32,
        configuration: NatFriendlyRouteRunConfiguration,
        localEndpoint: NatEndpoint,
        peerEndpoint: NatEndpoint,
        debug: inout DebugTrace
    ) throws -> UdpPcmLoopbackReport {
        try drainNatTraversalKeepalives(socket: socket, debug: &debug)
        return try runNatRouteLoopback(
            socket: socket,
            configuration: configuration,
            localEndpoint: localEndpoint,
            peerEndpoint: peerEndpoint,
            debug: &debug
        )
    }

    private static func runRelayFallbackLoopback(
        socket: Int32,
        configuration: NatFriendlyRouteRunConfiguration,
        localEndpoint: NatEndpoint,
        peerEndpoint: NatEndpoint,
        debug: inout DebugTrace
    ) throws -> UdpPcmLoopbackReport {
        debug.record(
            event: "nat-relay-fallback-start",
            fields: ["relayEndpoint": endpointDescription(peerEndpoint)]
        )
        try NatRelayClient.register(
            socket: socket,
            configuration: configuration,
            relayEndpoint: peerEndpoint,
            debug: &debug
        )
        var loopback = try runNatRouteLoopback(
            socket: socket,
            configuration: configuration,
            localEndpoint: localEndpoint,
            peerEndpoint: peerEndpoint,
            debug: &debug
        )
        loopback.notes = "UDP PCM loopback measured through the self-hosted UDP relay fallback. This is compatibility evidence only."
        return loopback
    }

    private static func runNatRouteLoopback(
        socket: Int32,
        configuration: NatFriendlyRouteRunConfiguration,
        localEndpoint: NatEndpoint,
        peerEndpoint: NatEndpoint,
        debug: inout DebugTrace
    ) throws -> UdpPcmLoopbackReport {
        let loopbackConfiguration = makeNatLoopbackConfiguration(
            configuration: configuration,
            localEndpoint: localEndpoint,
            peerEndpoint: peerEndpoint
        )
        if configuration.role == .sender {
            sleepRouteMicroseconds(200_000)
        }
        return try UdpPcmLoopbackEstablishedSocketRunner.run(
            socket: socket,
            configuration: loopbackConfiguration,
            debug: &debug
        )
    }

    private static func makeNatFriendlyRouteReport(
        configuration: NatFriendlyRouteRunConfiguration,
        localEndpoint: NatEndpoint,
        observedEndpoint: NatEndpoint?,
        peerEndpoint: NatEndpoint?,
        attempt: NatFriendlyRouteAttemptResult
    ) -> NatFriendlyRouteReport {
        let routeMetrics = natFriendlyRouteMetrics(
            configuration: configuration,
            attempt: attempt
        )
        return NatFriendlyRouteReport(
            id: "nat-friendly-route-\(configuration.peerID)-\(Int(Date().timeIntervalSince1970))",
            capturedAt: currentNatTimestamp(),
            sessionID: configuration.sessionID,
            peerID: configuration.peerID,
            role: configuration.role,
            rendezvousEndpoint: NatEndpoint(
                host: configuration.rendezvousHost,
                port: configuration.rendezvousPort
            ),
            localEndpoint: localEndpoint,
            compatibilityMode: attempt.compatibilityMode,
            rawP2PPreferred: true,
            traversal: NatTraversalEvidence(
                observedExternalEndpoint: observedEndpoint,
                peerEndpoint: peerEndpoint,
                directCandidateDiscovered: peerEndpoint != nil,
                directTraversalSucceeded: attempt.directTraversalResult.succeeded && routeMetrics.loopbackSucceeded,
                relayUsed: attempt.relayUsed,
                keepaliveIntervalMilliseconds: configuration.keepaliveIntervalMilliseconds,
                directTraversalRttMicroseconds: routeMetrics.directTraversalRtt,
                relayFallbackRttMicroseconds: routeMetrics.relayFallbackRtt,
                rawRouteRttMicroseconds: configuration.rawRouteRttMicroseconds,
                addedLatencyMicroseconds: routeMetrics.addedLatency
            ),
            loopback: attempt.loopback,
            verdict: .partial,
            notes: attempt.compatibilityMode == .relayFallback
                ? "NAT-friendly relay fallback after failed direct traversal. Relay evidence is compatibility-only; raw direct P2P remains the fastest-path default."
                : "NAT-friendly direct traversal handoff. Raw direct P2P remains the fastest-path default unless measured evidence promotes this path."
        )
    }
}

private func natFriendlyRouteMetrics(
    configuration: NatFriendlyRouteRunConfiguration,
    attempt: NatFriendlyRouteAttemptResult
) -> NatFriendlyRouteMetrics {
    let activeRouteRtt = attempt.loopback?.metrics.rtt.p50Microseconds
        ?? attempt.directTraversalResult.rttMicroseconds
    let directTraversalRtt = attempt.relayUsed
        ? attempt.directTraversalResult.rttMicroseconds
        : activeRouteRtt
    return NatFriendlyRouteMetrics(
        directTraversalRtt: directTraversalRtt,
        relayFallbackRtt: attempt.relayUsed ? attempt.loopback?.metrics.rtt.p50Microseconds : nil,
        addedLatency: addedLatencyMicroseconds(
            directTraversalRtt: activeRouteRtt,
            rawRouteRtt: configuration.rawRouteRttMicroseconds
        ),
        loopbackSucceeded: attempt.loopback.map(loopbackPathSucceeded) ?? false
    )
}

private func loopbackPathSucceeded(_ report: UdpPcmLoopbackReport) -> Bool {
    report.metrics.byteExactEcho && report.metrics.packetsEchoed > 0
}

private func natKeepaliveIntervalNanoseconds(milliseconds: Int) -> UInt64 {
    let (value, overflow) = UInt64(milliseconds).multipliedReportingOverflow(by: 1_000_000)
    return overflow ? UInt64.max : value
}
