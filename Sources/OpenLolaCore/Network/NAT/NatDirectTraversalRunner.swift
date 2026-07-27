// Coordinates NAT traversal execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
import Dispatch
import Foundation

enum NatDirectTraversalRunner {
    static func establish(
        socket: Int32,
        configuration: NatFriendlyRouteRunConfiguration,
        peerEndpoint: NatEndpoint,
        debug: inout DebugTrace
    ) throws -> NatDirectTraversalResult {
        try prepareConnectedSocket(socket: socket, peerEndpoint: peerEndpoint, debug: &debug)
        let result = try exchangeKeepalives(socket: socket, configuration: configuration, debug: &debug)
        recordTraversalFinished(result, debug: &debug)
        return result
    }

    private static func prepareConnectedSocket(
        socket: Int32,
        peerEndpoint: NatEndpoint,
        debug: inout DebugTrace
    ) throws {
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
    }

    private static func exchangeKeepalives(
        socket: Int32,
        configuration: NatFriendlyRouteRunConfiguration,
        debug: inout DebugTrace
    ) throws -> NatDirectTraversalResult {
        let deadline = try routeDeadlineNanoseconds(durationSeconds: configuration.durationSeconds)
        var state = NatKeepaliveExchangeState(
            sequence: UInt64.random(in: 1...UInt64.max),
            timeoutNanoseconds: natKeepaliveIntervalNanoseconds(
                milliseconds: configuration.keepaliveIntervalMilliseconds
            )
        )
        while DispatchTime.now().uptimeNanoseconds < deadline {
            let now = DispatchTime.now().uptimeNanoseconds
            try sendKeepaliveIfDue(
                socket: socket,
                configuration: configuration,
                now: now,
                state: &state,
                debug: &debug
            )
            try receivePeerKeepaliveIfAvailable(
                socket: socket,
                configuration: configuration,
                state: &state,
                debug: &debug
            )
            if state.sawPeerKeepalive {
                break
            }
            try waitForReadableSocket(socket: socket, timeoutMicroseconds: 1_000)
        }

        return NatDirectTraversalResult(
            succeeded: state.sawPeerKeepalive,
            rttMicroseconds: state.rttMicroseconds,
            keepaliveAttempts: state.attempts
        )
    }

    private static func sendKeepaliveIfDue(
        socket: Int32,
        configuration: NatFriendlyRouteRunConfiguration,
        now: UInt64,
        state: inout NatKeepaliveExchangeState,
        debug: inout DebugTrace
    ) throws {
        // Uptime is monotonic UInt64; wrapping subtraction preserves elapsed-time checks across overflow.
        guard now &- state.lastSend >= state.timeoutNanoseconds else { return }
        let message = NatTraversalKeepaliveMessage(
            magic: NatProtocolMagic.keepalive,
            sessionID: configuration.sessionID,
            peerID: configuration.peerID,
            sequence: state.sequence,
            sentAtNanoseconds: now,
            ackSequence: state.sawPeerKeepalive ? state.sequence : nil
        )
        try sendConnectedDatagram(try JSONEncoder().encode(message), socket: socket)
        state.attempts += 1
        state.lastSend = now
        debug.record(
            event: "nat-keepalive-sent",
            fields: ["attempt": "\(state.attempts)", "sequence": "\(state.sequence)"]
        )
    }

    private static func receivePeerKeepaliveIfAvailable(
        socket: Int32,
        configuration: NatFriendlyRouteRunConfiguration,
        state: inout NatKeepaliveExchangeState,
        debug: inout DebugTrace
    ) throws {
        guard let received = try receiveNatTraversalDatagramIfAvailable(socket: socket),
              let message = try? JSONDecoder().decode(NatTraversalKeepaliveMessage.self, from: received),
              message.magic == NatProtocolMagic.keepalive,
              message.sessionID == configuration.sessionID,
              // `configuration.peerID` is this client's local ID; the connected UDP socket
              // already restricts packets to the rendezvous-selected peer endpoint.
              !message.peerID.isEmpty,
              message.peerID != configuration.peerID else {
            return
        }

        state.sawPeerKeepalive = true
        debug.record(
            event: "nat-keepalive-received",
            fields: ["peerID": message.peerID, "sequence": "\(message.sequence)"]
        )
        let acknowledgement = NatTraversalKeepaliveMessage(
            magic: NatProtocolMagic.keepalive,
            sessionID: configuration.sessionID,
            peerID: configuration.peerID,
            sequence: state.sequence,
            sentAtNanoseconds: DispatchTime.now().uptimeNanoseconds,
            ackSequence: message.sequence
        )
        try sendConnectedDatagram(try JSONEncoder().encode(acknowledgement), socket: socket)
        if let ackSequence = message.ackSequence, ackSequence == state.sequence {
            state.rttMicroseconds = Double(
                DispatchTime.now().uptimeNanoseconds - message.sentAtNanoseconds
            ) / 1_000
        }
    }

    private static func recordTraversalFinished(
        _ result: NatDirectTraversalResult,
        debug: inout DebugTrace
    ) {
        debug.record(
            event: "nat-direct-traversal-finished",
            fields: [
                "succeeded": "\(result.succeeded)",
                "attempts": "\(result.keepaliveAttempts)",
                "rttMicroseconds": result.rttMicroseconds.map { "\($0)" } ?? "unknown"
            ]
        )
    }
}

private func natKeepaliveIntervalNanoseconds(milliseconds: Int) -> UInt64 {
    let (value, overflow) = UInt64(milliseconds).multipliedReportingOverflow(by: 1_000_000)
    return overflow ? UInt64.max : value
}
