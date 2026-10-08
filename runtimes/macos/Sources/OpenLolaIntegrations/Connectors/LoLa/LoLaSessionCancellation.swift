import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
// Shares a peer-initiated LoLa session end between the control retry responder and the media loop.
import Foundation

/// Longest a cancellable media receive waits on its sockets before it checks
/// the cancellation flag again.
let lolaSessionCancellationPollSeconds: TimeInterval = 0.05

/// Set once by the control retry responder thread and read by the media loop
/// thread; every access goes through `lock`.
final class LoLaSessionCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var storedReason: String?
    private var storedPeerMessage: String?

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return storedReason != nil
    }

    var reason: String? {
        lock.lock()
        defer { lock.unlock() }
        return storedReason
    }

    /// The validated control message that ended the session, for the report.
    var peerMessage: String? {
        lock.lock()
        defer { lock.unlock() }
        return storedPeerMessage
    }

    /// The first cancellation wins; later calls keep the original reason.
    func cancel(reason: String, peerMessage: String? = nil) {
        lock.lock()
        defer { lock.unlock() }
        guard storedReason == nil else { return }
        storedReason = reason
        storedPeerMessage = peerMessage
    }
}

/// Cancels the session when the pinned peer sends `/MESG_DISCONNECT` from its
/// control port with the negotiated SRCIP/DSTIP/SID. Returns true when the
/// datagram ended the session.
func lolaRetryResponderHandlePeerDisconnect(
    configuration: ExternalConnectorSessionConfiguration,
    message: String,
    parsed: (name: String, fields: [String: String]),
    senderHost: String,
    senderPort: UInt16,
    terminalSession: LoLaControlTerminalSession?
) -> Bool {
    // Both peers use the same control port, and the Rust station pins the
    // full source address; a datagram from any other port is not the peer.
    guard parsed.name == "/MESG_DISCONNECT", let terminalSession,
          senderPort == configuration.controlPort else {
        return false
    }
    let mismatch = lolaIncomingHandshakeFailure(
        context: LoLaHandshakeValidationFailureContext(
            sentMessages: [],
            receivedMessages: [message],
            opaqueControlDatagrams: [],
            bytesTransferred: message.utf8.count,
            parsedMessageName: parsed.name,
            fields: parsed.fields,
            message: message
        ),
        expectedName: "/MESG_DISCONNECT",
        localHost: configuration.localHost,
        requiresMediaFields: false,
        senderHost: senderHost,
        peer: configuration.peer
    )
    guard mismatch == nil,
          lolaIPv4AddressMatches(parsed.fields["SRCIP"], expected: terminalSession.destinationIP),
          parsed.fields["SID"] == String(terminalSession.sessionID) else {
        return false
    }
    terminalSession.cancellation.cancel(reason: "peer disconnected", peerMessage: message)
    return true
}

/// Bounds capture readiness and sleep waits so all media workers observe peer shutdown.
func loLaCancellationWaitDeadline(_ deadline: DispatchTime) -> DispatchTime {
    let poll = DispatchTime.now() + lolaSessionCancellationPollSeconds
    return DispatchTime(uptimeNanoseconds: min(deadline.uptimeNanoseconds, poll.uptimeNanoseconds))
}

func loLaCancellableMediaSleepUntil(_ deadline: DispatchTime, cancellation: LoLaSessionCancellation) {
    while !cancellation.isCancelled, DispatchTime.now().uptimeNanoseconds < deadline.uptimeNanoseconds {
        loLaUdpMediaSleepUntil(loLaCancellationWaitDeadline(deadline))
    }
}
