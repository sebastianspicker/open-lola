// Handles LoLaTcpControlExchangeReceive control exchange, keeping control-plane details distinct from media data flow.
import Darwin

func completeLoLaTcpQuickConnect(
    parsed: LoLaParsedControlMessage,
    configuration: ExternalConnectorSessionConfiguration,
    socket: Int32,
    senderHost: String,
    state: inout LoLaExchangeState
) throws -> LoLaControlExchangeAttempt {
    if let failure = lolaIncomingHandshakeFailure(
        context: lolaTcpHandshakeValidationContext(
            sentMessages: state.sentMessages,
            receivedMessages: state.receivedMessages,
            bytesTransferred: state.bytesTransferred,
            parsed: parsed,
            message: state.receivedMessages.last ?? ""
        ),
        expectedName: "/MESG_QUICKCONN", localHost: configuration.localHost, requiresMediaFields: true
    ) { return failure }
    let ack = try lolaQuickConnectAck(
        configuration: configuration,
        receivedFields: parsed.parsed.fields,
        senderHost: senderHost
    )
    state.recordSent(ack, byteCount: try sendExternalConnectorTcp(ack, socket: socket))

    return lolaControlAttemptSuccess(
        sentMessages: state.sentMessages,
        receivedMessages: state.receivedMessages,
        bytesTransferred: state.bytesTransferred,
        parsedMessageName: parsed.parsed.name,
        fields: parsed.parsed.fields
    )
}

enum LoLaTcpInitialControlRead {
    case success(LoLaParsedControlMessage)
    case failure(LoLaControlExchangeAttempt)
}

func receiveInitialLoLaTcpControlMessage(
    socket: Int32,
    configuration: ExternalConnectorSessionConfiguration,
    senderHost: String,
    state: inout LoLaExchangeState
) throws -> LoLaTcpInitialControlRead {
    let firstMessage = receiveParsedLoLaTcpControlMessage(
        socket: socket,
        sentMessages: state.sentMessages,
        receivedMessages: &state.receivedMessages,
        bytesTransferred: &state.bytesTransferred
    )
    switch firstMessage {
    case let .failure(failure):
        return .failure(failure)
    case let .success(received, firstParsed):
        var parsed = firstParsed
        if let failure = try acknowledgeLoLaTcpStatusIfNeeded(
            parsed: &parsed,
            received: received,
            configuration: configuration,
            context: (socket: socket, senderHost: senderHost),
            state: &state
        ) { return .failure(failure) }
        return .success(parsed)
    }
}

private func acknowledgeLoLaTcpStatusIfNeeded(
    parsed: inout LoLaParsedControlMessage,
    received: LoLaReceivedControlMessage,
    configuration: ExternalConnectorSessionConfiguration,
    context: (socket: Int32, senderHost: String),
    state: inout LoLaExchangeState
) throws -> LoLaControlExchangeAttempt? {
    guard parsed.parsed.name == "/MESG_CHECKLOLASTATUS" else { return nil }
    if let failure = lolaIncomingHandshakeFailure(
        context: lolaTcpHandshakeValidationContext(
            sentMessages: state.sentMessages,
            receivedMessages: state.receivedMessages,
            bytesTransferred: state.bytesTransferred,
            parsed: parsed,
            message: received.message
        ),
        expectedName: "/MESG_CHECKLOLASTATUS", localHost: configuration.localHost, requiresMediaFields: false
    ) { return failure }
    let ack = try lolaCheckStatusAck(
        configuration: configuration,
        receivedFields: parsed.parsed.fields,
        senderHost: context.senderHost
    )
    state.recordSent(ack, byteCount: try sendExternalConnectorTcp(ack, socket: context.socket))
    let quickConnect = receiveParsedLoLaTcpControlMessage(
        socket: context.socket,
        sentMessages: state.sentMessages,
        receivedMessages: &state.receivedMessages,
        bytesTransferred: &state.bytesTransferred,
        parsedMessageName: parsed.parsed.name,
        fields: parsed.parsed.fields
    )
    switch quickConnect {
    case let .success(_, quickConnectParsed):
        parsed = quickConnectParsed
        return nil
    case let .failure(failure):
        return failure
    }
}

private enum LoLaTcpParsedControlRead {
    case success(LoLaReceivedControlMessage, LoLaParsedControlMessage)
    case failure(LoLaControlExchangeAttempt)
}

private func receiveParsedLoLaTcpControlMessage(
    socket: Int32,
    sentMessages: [String],
    receivedMessages: inout [String],
    bytesTransferred: inout Int,
    parsedMessageName: String? = nil,
    fields: [String: String] = [:]
) -> LoLaTcpParsedControlRead {
    let message = receiveLoLaTcpControlMessage(
        socket: socket,
        sentMessages: sentMessages,
        receivedMessages: receivedMessages,
        bytesTransferred: bytesTransferred,
        parsedMessageName: parsedMessageName,
        fields: fields
    )
    if let failure = message.failure {
        return .failure(failure)
    }
    let parsed = parseLoLaControlMessage(
        message.message,
        sentMessages: sentMessages,
        receivedMessages: &receivedMessages,
        bytesTransferred: &bytesTransferred,
        transferredBytes: message.bytesTransferred,
        parsedMessageName: parsedMessageName,
        fields: fields
    )
    if let failure = parsed.failure {
        return .failure(failure)
    }
    return .success(message, parsed)
}

private func lolaTcpHandshakeValidationContext(
    sentMessages: [String],
    receivedMessages: [String],
    bytesTransferred: Int,
    parsed: LoLaParsedControlMessage,
    message: String
) -> LoLaHandshakeValidationFailureContext {
    LoLaHandshakeValidationFailureContext(
        sentMessages: sentMessages,
        receivedMessages: receivedMessages,
        opaqueControlDatagrams: [],
        bytesTransferred: bytesTransferred,
        parsedMessageName: parsed.parsed.name,
        fields: parsed.parsed.fields,
        message: message
    )
}

func receiveLoLaTcpControlMessage(
    socket: Int32,
    sentMessages: [String],
    receivedMessages: [String],
    bytesTransferred: Int,
    parsedMessageName: String? = nil,
    fields: [String: String] = [:]
) -> LoLaReceivedControlMessage {
    do {
        let received = try receiveExternalConnectorTcp(socket: socket, bufferSize: 4096)
        return LoLaReceivedControlMessage(
            message: received.message,
            senderHost: "",
            senderPort: 0,
            bytesTransferred: received.bytesTransferred
        )
    } catch {
        return lolaReceivedControlMessageFailure(
            context: .init(
                sentMessages: sentMessages,
                receivedMessages: receivedMessages,
                bytesTransferred: bytesTransferred,
                parsedMessageName: parsedMessageName,
                fields: fields
            ),
            runtimeError: error
        )
    }
}
