import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
// Re-sends an unanswered LoLa handshake datagram at a bounded interval until the negotiation deadline.
import Foundation

/// Interval after which an unanswered handshake datagram is sent again. LoLa
/// control is plain UDP, so one lost request must not consume the whole
/// negotiation window; responders answer every repeat identically.
let lolaHandshakeRetryIntervalSeconds: TimeInterval = 0.5
/// Repeats before the final attempt waits out the remaining deadline. Kept
/// below the responder's own status-retry allowance.
let maxLoLaHandshakeResends = 5

func receiveLoLaOutgoingHandshakeMessageWithRetries(
    transport: LoLaOutgoingControlTransport,
    state: inout LoLaExchangeState,
    destinationPort: UInt16,
    deadline: MonotonicDeadline,
    discardedDatagrams: inout Int,
    parsedMessageName: String? = nil,
    fields: [String: String] = [:],
    peerReject: LoLaPeerRejectExpectation? = nil,
    resend: (inout LoLaExchangeState) throws -> Void,
    validate: (LoLaParsedControlMessage, LoLaReceivedControlMessage, LoLaExchangeState) throws
        -> LoLaControlExchangeAttempt?
) throws -> LoLaParsedControlMessage {
    var resends = 0
    while true {
        let attemptDeadline = resends < maxLoLaHandshakeResends
            ? MonotonicDeadline(seconds: min(deadline.remainingSeconds, lolaHandshakeRetryIntervalSeconds))
            : deadline
        let parsed = try receiveLoLaOutgoingHandshakeMessage(
            transport: transport,
            state: &state,
            destinationPort: destinationPort,
            deadline: attemptDeadline,
            discardedDatagrams: &discardedDatagrams,
            parsedMessageName: parsedMessageName,
            fields: fields,
            peerReject: peerReject,
            validate: validate
        )
        guard let failure = parsed.failure,
              isLoLaReceiveTimedOutFailure(failure),
              resends < maxLoLaHandshakeResends,
              deadline.hasTimeRemaining else {
            return parsed
        }
        resends += 1
        try resend(&state)
    }
}
