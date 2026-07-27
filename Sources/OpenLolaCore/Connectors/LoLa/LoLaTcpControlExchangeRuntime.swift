// Runs the LoLa TCP control handshake with bounded connect, send, receive, and close behavior.
import Darwin

private struct LoLaTcpPostStatusAckContext {
    var configuration: ExternalConnectorSessionConfiguration
    var socket: Int32
    var advertisedSourceIP: String
    var sessionID: Int
}

func runLoLaTcpControlExchangeAttempt(
    configuration: ExternalConnectorSessionConfiguration,
    onReceiveReady: (@Sendable () -> Void)? = nil
) throws -> LoLaControlExchangeAttempt {
    switch configuration.role {
    case .tx, .txRx:
        return try sendLoLaTcpControlAttempt(configuration: configuration)
    case .rx:
        return try receiveLoLaTcpControlAttempt(
            configuration: configuration,
            onReady: onReceiveReady
        )
    }
}

private func sendLoLaTcpControlAttempt(
    configuration: ExternalConnectorSessionConfiguration
) throws -> LoLaControlExchangeAttempt {
    guard !configuration.peer.isEmpty else {
        throw ExternalConnectorSessionError.lolaRequiresPeerForTx
    }
    let descriptor = try makeExternalConnectorTcpSocket()
    defer { close(descriptor) }
    let sessionID = try lolaControlSessionID(configuration.sessionID)
    do {
        try prepareOutgoingLoLaTcpControlSocket(configuration: configuration, socket: descriptor)
    } catch {
        return lolaControlAttemptFailure(
            sentMessages: [],
            receivedMessages: [],
            bytesTransferred: 0,
            runtimeError: error
        )
    }

    var state = LoLaExchangeState()
    let advertisedSourceIP = try lolaControlAdvertisedSourceIP(configuration)
    try sendLoLaTcpStatusCheck(
        configuration: configuration,
        socket: descriptor,
        state: &state,
        advertisedSourceIP: advertisedSourceIP,
        sessionID: sessionID
    )

    return try sendLoLaTcpQuickConnectAfterStatusCheck(
        configuration: configuration,
        socket: descriptor,
        advertisedSourceIP: advertisedSourceIP,
        sessionID: sessionID,
        state: &state
    )
}

private func sendLoLaTcpQuickConnectAfterStatusCheck(
    configuration: ExternalConnectorSessionConfiguration,
    socket descriptor: Int32,
    advertisedSourceIP: String,
    sessionID: Int,
    state: inout LoLaExchangeState
) throws -> LoLaControlExchangeAttempt {
    let statusAck = receiveLoLaTcpOutgoingControlMessage(socket: descriptor, state: state)
    if let failure = statusAck.failure {
        guard isLoLaReceiveTimedOutFailure(failure) else { return failure }
        return try sendLoLaTcpQuickConnectFallback(
            configuration: configuration,
            socket: descriptor,
            advertisedSourceIP: advertisedSourceIP,
            state: state
        )
    }
    let parsedStatusAck = parseLoLaExchangeControlMessage(statusAck, state: &state)
    if let failure = parsedStatusAck.failure { return failure }
    return try sendLoLaTcpQuickConnectAfterStatusAck(
        context: LoLaTcpPostStatusAckContext(
            configuration: configuration,
            socket: descriptor,
            advertisedSourceIP: advertisedSourceIP,
            sessionID: sessionID
        ),
        state: &state,
        parsedStatusAck,
        received: statusAck
    )
}

private func sendLoLaTcpQuickConnectAfterStatusAck(
    context: LoLaTcpPostStatusAckContext,
    state: inout LoLaExchangeState,
    _ parsedStatusAck: LoLaParsedControlMessage,
    received statusAck: LoLaReceivedControlMessage
) throws -> LoLaControlExchangeAttempt {
    if let failure = validateLoLaStatusAck(
        parsedStatusAck,
        received: statusAck,
        context: .init(
            state: state,
            configuration: context.configuration,
            advertisedSourceIP: context.advertisedSourceIP,
            sessionID: context.sessionID
        )
    ) { return failure }

    try sendLoLaTcpQuickConnect(
        configuration: context.configuration,
        socket: context.socket,
        state: &state,
        sourceIP: context.advertisedSourceIP
    )

    let quickConnectAck = receiveLoLaTcpOutgoingControlMessage(
        socket: context.socket,
        state: state,
        parsedMessageName: parsedStatusAck.parsed.name,
        fields: parsedStatusAck.parsed.fields
    )
    if let failure = quickConnectAck.failure { return failure }
    let parsedQuickConnectAck = parseLoLaExchangeControlMessage(
        quickConnectAck,
        state: &state,
        parsedMessageName: parsedStatusAck.parsed.name,
        fields: parsedStatusAck.parsed.fields
    )
    if let failure = parsedQuickConnectAck.failure { return failure }
    if let failure = try validateLoLaQuickConnectAck(
        parsedQuickConnectAck,
        received: quickConnectAck,
        state: state,
        configuration: context.configuration,
        sourceIP: context.advertisedSourceIP
    ) { return failure }

    return state.success(
        parsedMessageName: parsedQuickConnectAck.parsed.name,
        fields: parsedQuickConnectAck.parsed.fields
    )
}

private func prepareOutgoingLoLaTcpControlSocket(
    configuration: ExternalConnectorSessionConfiguration,
    socket descriptor: Int32
) throws {
    try connectExternalConnectorTcp(
        socket: descriptor,
        host: configuration.peer,
        port: configuration.controlPort,
        timeoutSeconds: configuration.durationSeconds
    )
    try setExternalConnectorTcpTimeout(socket: descriptor, seconds: configuration.durationSeconds)
}

private func sendLoLaTcpQuickConnectFallback(
    configuration: ExternalConnectorSessionConfiguration,
    socket descriptor: Int32,
    advertisedSourceIP: String,
    state: LoLaExchangeState
) throws -> LoLaControlExchangeAttempt {
    var state = state
    try sendLoLaTcpQuickConnect(
        configuration: configuration,
        socket: descriptor,
        state: &state,
        sourceIP: advertisedSourceIP
    )

    let quickConnectAck = receiveLoLaTcpOutgoingControlMessage(
        socket: descriptor,
        state: state
    )
    if let failure = quickConnectAck.failure { return failure }
    return try completeLoLaQuickConnectFallbackResponse(
        quickConnectAck,
        configuration: configuration,
        sourceIP: advertisedSourceIP,
        state: &state
    )
}

private func sendLoLaTcpStatusCheck(
    configuration: ExternalConnectorSessionConfiguration,
    socket descriptor: Int32,
    state: inout LoLaExchangeState,
    advertisedSourceIP: String,
    sessionID: Int
) throws {
    let checkStatus = LoLaCompatibilityControlMessage.checkStatus(
        sourceIP: advertisedSourceIP,
        destinationIP: configuration.peer,
        sessionID: sessionID
    )
    let byteCount = try sendExternalConnectorTcp(checkStatus, socket: descriptor)
    state.recordSent(checkStatus, byteCount: byteCount)
}

private func sendLoLaTcpQuickConnect(
    configuration: ExternalConnectorSessionConfiguration,
    socket descriptor: Int32,
    state: inout LoLaExchangeState,
    sourceIP: String
) throws {
    let quickConnect = try lolaQuickConnectMessage(configuration: configuration, sourceIP: sourceIP)
    let byteCount = try sendExternalConnectorTcp(quickConnect, socket: descriptor)
    state.recordSent(quickConnect, byteCount: byteCount)
}

private func receiveLoLaTcpOutgoingControlMessage(
    socket descriptor: Int32,
    state: LoLaExchangeState,
    parsedMessageName: String? = nil,
    fields: [String: String] = [:]
) -> LoLaReceivedControlMessage {
    receiveLoLaTcpControlMessage(
        socket: descriptor,
        sentMessages: state.sentMessages,
        receivedMessages: state.receivedMessages,
        bytesTransferred: state.bytesTransferred,
        parsedMessageName: parsedMessageName,
        fields: fields
    )
}

private func receiveLoLaTcpControlAttempt(
    configuration: ExternalConnectorSessionConfiguration,
    onReady: (@Sendable () -> Void)?
) throws -> LoLaControlExchangeAttempt {
    let listener = try makeExternalConnectorTcpSocket()
    defer { close(listener) }
    try bindExternalConnectorTcp(socket: listener, host: configuration.localHost, port: configuration.controlPort)
    guard listen(listener, 1) == 0 else {
        throw ExternalConnectorSessionError.socketFailed("listen")
    }
    onReady?()
    guard try waitForExternalConnectorTcpConnection(
        socket: listener,
        timeoutSeconds: configuration.durationSeconds
    ) else {
        return lolaControlAttemptFailure(
            sentMessages: [],
            receivedMessages: [],
            bytesTransferred: 0,
            runtimeError: ExternalConnectorSessionError.receiveTimedOut
        )
    }

    var peer = sockaddr_in()
    var peerLength = socklen_t(MemoryLayout<sockaddr_in>.size)
    let connection = withUnsafeMutablePointer(to: &peer) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            accept(listener, socketAddress, &peerLength)
        }
    }
    guard connection >= 0 else {
        let acceptError = errno
        let runtimeError: ExternalConnectorSessionError = acceptError == EAGAIN || acceptError == EWOULDBLOCK
            ? .receiveTimedOut
            : .socketFailed("tcp accept errno \(acceptError)")
        return lolaControlAttemptFailure(
            sentMessages: [],
            receivedMessages: [],
            bytesTransferred: 0,
            runtimeError: runtimeError
        )
    }
    defer { close(connection) }
    try setExternalConnectorTcpTimeout(socket: connection, seconds: configuration.durationSeconds)
    let senderHost = try externalConnectorTcpHostString(peer.sin_addr)

    var state = LoLaExchangeState()
    let firstMessage = try receiveInitialLoLaTcpControlMessage(
        socket: connection,
        configuration: configuration,
        senderHost: senderHost,
        state: &state
    )
    switch firstMessage {
    case let .failure(failure):
        return failure
    case let .success(parsed):
        return try completeLoLaTcpQuickConnect(
            parsed: parsed,
            configuration: configuration,
            socket: connection,
            senderHost: senderHost,
            state: &state
        )
    }
}
