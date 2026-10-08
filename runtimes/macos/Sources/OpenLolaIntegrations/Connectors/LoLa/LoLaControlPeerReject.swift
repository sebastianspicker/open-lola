import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
// Accepts a pinned peer's /MESG_REJECT as the terminal answer to an outgoing QUICKCONN.
import Foundation

/// Sender and session fields a `/MESG_REJECT` must carry before the initiator
/// stops re-sending QUICKCONN and surfaces the peer's reason.
struct LoLaPeerRejectExpectation {
    var expectedFields: [String: String]
    var expectedSenderHost: String
    var expectedSenderPort: UInt16
}

func lolaQuickConnectPeerRejectExpectation(
    configuration: ExternalConnectorSessionConfiguration,
    sourceIP: String
) throws -> LoLaPeerRejectExpectation {
    LoLaPeerRejectExpectation(
        expectedFields: lolaExpectedStatusAckFields(
            sourceIP: sourceIP,
            destinationIP: configuration.peer,
            sessionID: try lolaControlSessionID(configuration.sessionID)
        ),
        expectedSenderHost: configuration.peer,
        expectedSenderPort: configuration.controlPort
    )
}

/// Records a validated peer REJECT in `state` and returns it as a terminal
/// failure carrying the unescaped TXT; returns nil for every other datagram.
func lolaTerminalPeerReject(
    _ candidate: LoLaParsedControlMessage,
    received: LoLaReceivedControlMessage,
    state: inout LoLaExchangeState,
    expectation: LoLaPeerRejectExpectation?,
    parsedMessageName: String?,
    fields: [String: String]
) -> LoLaParsedControlMessage? {
    guard let expectation, candidate.parsed.name == "/MESG_REJECT" else {
        return nil
    }
    let mismatch = validateLoLaOutgoingAck(
        candidate,
        received: received,
        state: state,
        expectedName: "/MESG_REJECT",
        expectedFields: expectation.expectedFields,
        expectedSenderHost: expectation.expectedSenderHost,
        expectedSenderPort: expectation.expectedSenderPort
    )
    guard mismatch == nil else {
        return nil
    }
    let parsed = parseLoLaExchangeControlMessage(
        received,
        state: &state,
        parsedMessageName: parsedMessageName,
        fields: fields
    )
    if parsed.failure != nil {
        return parsed
    }
    return LoLaParsedControlMessage(
        parsed: parsed.parsed,
        failure: state.failure(
            parsedMessageName: parsed.parsed.name,
            fields: parsed.parsed.fields,
            runtimeError: ExternalConnectorSessionError.peerRejected(
                reason: parsed.parsed.fields["TXT"] ?? ""
            )
        )
    )
}
