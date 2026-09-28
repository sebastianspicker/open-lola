import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
// Retains a negotiated LoLa control transport through media and closes it with terminal protocol messages.
import Darwin

final class LoLaControlSocketLease {
    let descriptor: Int32

    init(descriptor: Int32) {
        self.descriptor = descriptor
    }

    deinit {
        close(descriptor)
    }
}

/// One runner owns this reference from handshake completion through terminal cleanup.
/// It is not shared or called concurrently; the unchecked conformance preserves the
/// existing Sendable handshake-attempt boundary used by asynchronous receiver tests.
final class LoLaControlTerminalSession: @unchecked Sendable {
    private let sourceIP: String
    private let destinationIP: String
    private let sessionID: Int
    private let send: (String) throws -> Int
    private let duplicateSocket: (() throws -> Int32)?
    private var finished = false

    init(
        sourceIP: String,
        destinationIP: String,
        sessionID: Int,
        send: @escaping (String) throws -> Int,
        duplicateSocketForRetryResponder: (() throws -> Int32)? = nil
    ) {
        self.sourceIP = sourceIP
        self.destinationIP = destinationIP
        self.sessionID = sessionID
        self.send = send
        self.duplicateSocket = duplicateSocketForRetryResponder
    }

    /// Transfers ownership of a duplicate descriptor to the retry responder loop.
    /// The terminal session keeps its original descriptor for STOP and DISCONNECT.
    func duplicateSocketForRetryResponder() throws -> Int32 {
        guard let duplicateSocket else {
            throw ExternalConnectorSessionError.socketFailed(
                "negotiated UDP control socket unavailable for retry responder"
            )
        }
        return try duplicateSocket()
    }

    func finish(exchange: inout LoLaControlExchange) -> String? {
        guard !finished else { return nil }
        finished = true

        let messages = [
            LoLaCompatibilityControlMessage.stopAudioSignal(
                sourceIP: sourceIP,
                destinationIP: destinationIP,
                sessionID: sessionID
            ),
            LoLaCompatibilityControlMessage.disconnect(
                sourceIP: sourceIP,
                destinationIP: destinationIP,
                sessionID: sessionID
            )
        ]
        var failures: [String] = []
        for message in messages {
            do {
                let byteCount = try send(message)
                exchange.bytesTransferred += byteCount
                exchange.sentMessages.append(message)
                exchange.sentMessage = message
            } catch {
                let name = message.split(separator: ";").first ?? "message"
                failures.append("terminal LoLa control \(name) failed: \(error)")
            }
        }
        return failures.isEmpty ? nil : failures.joined(separator: "; ")
    }
}

func makeLoLaControlTerminalSession(
    configuration: ExternalConnectorSessionConfiguration,
    exchange: LoLaControlExchange,
    send: @escaping (String) throws -> Int,
    duplicateSocketForRetryResponder: (() throws -> Int32)? = nil
) throws -> LoLaControlTerminalSession {
    let sourceIP = exchange.fields["DSTIP"] ?? configuration.localHost
    let destinationIP: String
    switch configuration.role {
    case .tx, .txRx:
        destinationIP = configuration.peer
    case .rx:
        destinationIP = exchange.fields["SRCIP"] ?? configuration.peer
    }
    return LoLaControlTerminalSession(
        sourceIP: sourceIP,
        destinationIP: destinationIP,
        sessionID: try lolaControlSessionID(configuration.sessionID),
        send: send,
        duplicateSocketForRetryResponder: duplicateSocketForRetryResponder
    )
}

func lolaCombinedRuntimeError(_ errors: [String?]) -> String? {
    let values = errors.compactMap { $0 }
    return values.isEmpty ? nil : values.joined(separator: "; ")
}
