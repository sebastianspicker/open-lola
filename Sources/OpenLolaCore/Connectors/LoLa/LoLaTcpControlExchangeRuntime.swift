import Darwin

private struct LoLaTcpPostStatusAckContext {
    var configuration: ExternalConnectorSessionConfiguration
    var socket: Int32
    var advertisedSourceIP: String
    var sessionID: Int
}

private struct LoLaTcpStatusAckValidationContext {
    var state: LoLaExchangeState
    var configuration: ExternalConnectorSessionConfiguration
    var advertisedSourceIP: String
    var sessionID: Int
}

func runLoLaTcpControlExchangeAttempt(
    configuration: ExternalConnectorSessionConfiguration
) throws -> LoLaControlExchangeAttempt {
    switch configuration.role {
    case .tx, .txRx:
        return try sendLoLaTcpControlAttempt(configuration: configuration)
    case .rx:
        return try receiveLoLaTcpControlAttempt(configuration: configuration)
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
        return lolaControlAttemptFailure(sentMessages: [], receivedMessages: [], bytesTransferred: 0, runtimeError: error)
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
    let parsedStatusAck = parseLoLaTcpOutgoingControlMessage(statusAck, state: &state)
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
    if let failure = validateLoLaTcpStatusAck(
        parsedStatusAck,
        received: statusAck,
        context: LoLaTcpStatusAckValidationContext(
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
    let parsedQuickConnectAck = parseLoLaTcpOutgoingControlMessage(
        quickConnectAck,
        state: &state,
        parsedMessageName: parsedStatusAck.parsed.name,
        fields: parsedStatusAck.parsed.fields
    )
    if let failure = parsedQuickConnectAck.failure { return failure }
    if let failure = try validateLoLaTcpQuickConnectAck(
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
    try sendLoLaTcpQuickConnect(configuration: configuration, socket: descriptor, state: &state, sourceIP: advertisedSourceIP)

    let quickConnectAck = receiveLoLaTcpOutgoingControlMessage(
        socket: descriptor,
        state: state
    )
    if let failure = quickConnectAck.failure { return failure }
    let parsedQuickConnectAck = parseLoLaTcpOutgoingControlMessage(quickConnectAck, state: &state)
    if let failure = parsedQuickConnectAck.failure { return failure }
    if let failure = try validateLoLaTcpQuickConnectAck(
        parsedQuickConnectAck,
        received: quickConnectAck,
        state: state,
        configuration: configuration,
        sourceIP: advertisedSourceIP
    ) { return failure }

    return state.success(
        parsedMessageName: parsedQuickConnectAck.parsed.name,
        fields: parsedQuickConnectAck.parsed.fields
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

private func parseLoLaTcpOutgoingControlMessage(
    _ received: LoLaReceivedControlMessage,
    state: inout LoLaExchangeState,
    parsedMessageName: String? = nil,
    fields: [String: String] = [:]
) -> LoLaParsedControlMessage {
    parseReceivedLoLaControlMessage(
        received,
        sentMessages: state.sentMessages,
        receivedMessages: &state.receivedMessages,
        bytesTransferred: &state.bytesTransferred,
        opaqueControlDatagrams: &state.opaqueControlDatagrams,
        parsedMessageName: parsedMessageName,
        fields: fields
    )
}

private func validateLoLaTcpStatusAck(
    _ parsedStatusAck: LoLaParsedControlMessage,
    received statusAck: LoLaReceivedControlMessage,
    context: LoLaTcpStatusAckValidationContext
) -> LoLaControlExchangeAttempt? {
    lolaOutgoingHandshakeFailure(
        context: LoLaHandshakeValidationFailureContext(
            sentMessages: context.state.sentMessages,
            receivedMessages: context.state.receivedMessages,
            opaqueControlDatagrams: context.state.opaqueControlDatagrams,
            bytesTransferred: context.state.bytesTransferred,
            parsedMessageName: parsedStatusAck.parsed.name,
            fields: parsedStatusAck.parsed.fields,
            message: statusAck.message
        ),
        expectedName: "/MESG_CHECKLOLASTATUS_ACK",
        expectedFields: lolaExpectedStatusAckFields(
            sourceIP: context.advertisedSourceIP,
            destinationIP: context.configuration.peer,
            sessionID: context.sessionID
        )
    )
}

private func validateLoLaTcpQuickConnectAck(
    _ parsedQuickConnectAck: LoLaParsedControlMessage,
    received quickConnectAck: LoLaReceivedControlMessage,
    state: LoLaExchangeState,
    configuration: ExternalConnectorSessionConfiguration,
    sourceIP: String
) throws -> LoLaControlExchangeAttempt? {
    lolaOutgoingHandshakeFailure(
        context: LoLaHandshakeValidationFailureContext(
            sentMessages: state.sentMessages,
            receivedMessages: state.receivedMessages,
            opaqueControlDatagrams: state.opaqueControlDatagrams,
            bytesTransferred: state.bytesTransferred,
            parsedMessageName: parsedQuickConnectAck.parsed.name,
            fields: parsedQuickConnectAck.parsed.fields,
            message: quickConnectAck.message
        ),
        expectedName: "/MESG_QUICKCONN_ACK",
        expectedFields: try lolaExpectedQuickConnectFields(configuration: configuration, sourceIP: sourceIP)
    )
}

private func receiveLoLaTcpControlAttempt(
    configuration: ExternalConnectorSessionConfiguration
) throws -> LoLaControlExchangeAttempt {
    let listener = try makeExternalConnectorTcpSocket()
    defer { close(listener) }
    try bindExternalConnectorTcp(socket: listener, host: configuration.localHost, port: configuration.controlPort)
    guard listen(listener, 1) == 0 else {
        throw ExternalConnectorSessionError.socketFailed("listen")
    }
    try setExternalConnectorTcpTimeout(socket: listener, seconds: configuration.durationSeconds)

    var peer = sockaddr_in()
    var peerLength = socklen_t(MemoryLayout<sockaddr_in>.size)
    let connection = withUnsafeMutablePointer(to: &peer) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            accept(listener, socketAddress, &peerLength)
        }
    }
    guard connection >= 0 else {
        return lolaControlAttemptFailure(sentMessages: [], receivedMessages: [], bytesTransferred: 0, runtimeError: ExternalConnectorSessionError.receiveTimedOut)
    }
    defer { close(connection) }
    try setExternalConnectorTcpTimeout(socket: connection, seconds: configuration.durationSeconds)
    let senderHost = try externalConnectorTcpHostString(peer.sin_addr)

    var sentMessages: [String] = []
    var receivedMessages: [String] = []
    var bytesTransferred = 0
    let first = receiveLoLaTcpControlMessage(socket: connection, sentMessages: sentMessages, receivedMessages: receivedMessages, bytesTransferred: bytesTransferred)
    if let failure = first.failure { return failure }
    var parsed = parseLoLaControlMessage(first.message, sentMessages: sentMessages, receivedMessages: &receivedMessages, bytesTransferred: &bytesTransferred, transferredBytes: first.bytesTransferred)
    if let failure = parsed.failure { return failure }

    if parsed.parsed.name == "/MESG_CHECKLOLASTATUS" {
        if let failure = lolaIncomingHandshakeFailure(
            context: lolaTcpHandshakeValidationContext(
                sentMessages: sentMessages,
                receivedMessages: receivedMessages,
                bytesTransferred: bytesTransferred,
                parsed: parsed,
                message: first.message
            ),
            expectedName: "/MESG_CHECKLOLASTATUS", localHost: configuration.localHost, requiresMediaFields: false
        ) { return failure }
        let ack = try lolaCheckStatusAck(configuration: configuration, receivedFields: parsed.parsed.fields, senderHost: senderHost)
        bytesTransferred += try sendExternalConnectorTcp(ack, socket: connection)
        sentMessages.append(ack)
        let quickConnect = receiveLoLaTcpControlMessage(
            socket: connection,
            sentMessages: sentMessages,
            receivedMessages: receivedMessages,
            bytesTransferred: bytesTransferred,
            parsedMessageName: parsed.parsed.name,
            fields: parsed.parsed.fields
        )
        if let failure = quickConnect.failure { return failure }
        parsed = parseLoLaControlMessage(
            quickConnect.message,
            sentMessages: sentMessages,
            receivedMessages: &receivedMessages,
            bytesTransferred: &bytesTransferred,
            transferredBytes: quickConnect.bytesTransferred,
            parsedMessageName: parsed.parsed.name,
            fields: parsed.parsed.fields
        )
        if let failure = parsed.failure { return failure }
    }

    if let failure = lolaIncomingHandshakeFailure(
        context: lolaTcpHandshakeValidationContext(
            sentMessages: sentMessages,
            receivedMessages: receivedMessages,
            bytesTransferred: bytesTransferred,
            parsed: parsed,
            message: receivedMessages.last ?? ""
        ),
        expectedName: "/MESG_QUICKCONN", localHost: configuration.localHost, requiresMediaFields: true
    ) { return failure }
    let ack = try lolaQuickConnectAck(configuration: configuration, receivedFields: parsed.parsed.fields, senderHost: senderHost)
    bytesTransferred += try sendExternalConnectorTcp(ack, socket: connection)
    sentMessages.append(ack)

    return lolaControlAttemptSuccess(
        sentMessages: sentMessages,
        receivedMessages: receivedMessages,
        bytesTransferred: bytesTransferred,
        parsedMessageName: parsed.parsed.name,
        fields: parsed.parsed.fields
    )
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

private func receiveLoLaTcpControlMessage(
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
        return LoLaReceivedControlMessage(message: "", senderHost: "", senderPort: 0, bytesTransferred: 0, failure: lolaControlAttemptFailure(
            sentMessages: sentMessages,
            receivedMessages: receivedMessages,
            bytesTransferred: bytesTransferred,
            parsedMessageName: parsedMessageName,
            fields: fields,
            runtimeError: error
        ))
    }
}

private func makeExternalConnectorTcpSocket() throws -> Int32 {
    let descriptor = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
    guard descriptor >= 0 else {
        throw ExternalConnectorSessionError.socketFailed("tcp socket")
    }
    return descriptor
}

private func connectExternalConnectorTcp(
    socket: Int32,
    host: String,
    port: UInt16,
    timeoutSeconds: Int
) throws {
    var address = try externalConnectorTcpAddress(host: host, port: port)
    let flags = fcntl(socket, F_GETFL, 0)
    guard flags >= 0, fcntl(socket, F_SETFL, flags | O_NONBLOCK) >= 0 else {
        throw ExternalConnectorSessionError.socketFailed("fcntl")
    }
    defer { _ = fcntl(socket, F_SETFL, flags) }

    let result = withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            connect(socket, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    if result == 0 { return }
    guard errno == EINPROGRESS else {
        throw ExternalConnectorSessionError.socketFailed("tcp connect errno \(errno)")
    }

    var writeSet = fd_set()
    openLolaFDZero(&writeSet)
    try openLolaRequireFileDescriptorFitsFDSet(socket, context: "tcp connect")
    try openLolaFDSet(socket, set: &writeSet)
    var timeout = timeval(tv_sec: max(1, timeoutSeconds), tv_usec: 0)
    let ready = select(socket + 1, nil, &writeSet, nil, &timeout)
    guard ready > 0 else {
        throw ready == 0
            ? ExternalConnectorSessionError.receiveTimedOut
            : ExternalConnectorSessionError.socketFailed("tcp connect select errno \(errno)")
    }
    var socketError: Int32 = 0
    var socketErrorLength = socklen_t(MemoryLayout<Int32>.size)
    guard getsockopt(socket, SOL_SOCKET, SO_ERROR, &socketError, &socketErrorLength) == 0 else {
        throw ExternalConnectorSessionError.socketFailed("tcp connect getsockopt errno \(errno)")
    }
    guard socketError == 0 else {
        throw ExternalConnectorSessionError.socketFailed("tcp connect errno \(socketError)")
    }
}

private func bindExternalConnectorTcp(socket: Int32, host: String, port: UInt16) throws {
    var reuse: Int32 = 1
    guard setsockopt(socket, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size)) == 0 else {
        throw ExternalConnectorSessionError.socketFailed("tcp setsockopt SO_REUSEADDR errno \(errno)")
    }
    var address = try externalConnectorTcpAddress(host: host, port: port)
    let result = withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            Darwin.bind(socket, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    guard result == 0 else {
        throw ExternalConnectorSessionError.socketFailed("tcp bind \(host):\(port) errno \(errno)")
    }
}

typealias ExternalConnectorTcpSendFunction = (
    _ socket: Int32,
    _ buffer: UnsafeRawPointer,
    _ byteCount: Int,
    _ flags: Int32
) -> Int

func externalConnectorTcpDarwinSend(
    socket: Int32,
    buffer: UnsafeRawPointer,
    byteCount: Int,
    flags: Int32
) -> Int {
    Darwin.send(socket, buffer, byteCount, flags)
}

func sendExternalConnectorTcpBytes(
    _ bytes: [UInt8],
    socket: Int32,
    send: ExternalConnectorTcpSendFunction = externalConnectorTcpDarwinSend
) throws -> Int {
    return try bytes.withUnsafeBytes { rawBuffer in
        guard let baseAddress = rawBuffer.baseAddress else {
            throw ExternalConnectorSessionError.socketFailed("empty tcp send buffer")
        }
        var sentByteCount = 0
        while sentByteCount < rawBuffer.count {
            let remainingByteCount = rawBuffer.count - sentByteCount
            let sent = send(socket, baseAddress.advanced(by: sentByteCount), remainingByteCount, 0)
            if sent > 0, sent <= remainingByteCount {
                sentByteCount += sent
                continue
            }
            if sent < 0 {
                let savedErrno = errno
                if savedErrno == EINTR {
                    continue
                }
                throw ExternalConnectorSessionError.socketFailed("tcp send errno \(savedErrno)")
            }
            throw ExternalConnectorSessionError.socketFailed("tcp send")
        }
        return sentByteCount
    }
}

private func sendExternalConnectorTcp(_ message: String, socket: Int32) throws -> Int {
    try sendExternalConnectorTcpBytes(lolaControlDatagramBytes(message), socket: socket)
}

func receiveExternalConnectorTcp(
    socket: Int32,
    bufferSize: Int
) throws -> (message: String, bytesTransferred: Int) {
    let targetByteCount = max(1, min(bufferSize, lolaControlDatagramByteCount))
    var messageBytes: [UInt8] = []
    messageBytes.reserveCapacity(targetByteCount)
    var buffer = [UInt8](repeating: 0, count: targetByteCount)
    while messageBytes.count < targetByteCount {
        let remainingByteCount = targetByteCount - messageBytes.count
        let received = recv(socket, &buffer, remainingByteCount, 0)
        let savedErrno = errno
        if received == 0 {
            _ = Darwin.shutdown(socket, SHUT_RDWR)
            throw ExternalConnectorSessionError.socketFailed("tcp peer closed connection")
        }
        guard received > 0 else {
            throw savedErrno == EAGAIN || savedErrno == EWOULDBLOCK
                ? ExternalConnectorSessionError.receiveTimedOut
                : ExternalConnectorSessionError.socketFailed("tcp recv errno \(savedErrno)")
        }
        messageBytes.append(contentsOf: buffer[0..<received])
        let message = try decodeExternalConnectorTcpMessage(messageBytes)
        if !message.contains("\0"),
           (try? LoLaCompatibilityControlMessage.parse(message)) != nil {
            return (message, messageBytes.count)
        }
    }
    return (try decodeExternalConnectorTcpMessage(messageBytes), messageBytes.count)
}

private func decodeExternalConnectorTcpMessage(_ messageBytes: [UInt8]) throws -> String {
    guard let message = String(bytes: messageBytes, encoding: .utf8) else {
        throw ExternalConnectorSessionError.malformedLoLaControlMessage("invalid UTF-8 TCP control datagram")
    }
    return message
}

private func setExternalConnectorTcpTimeout(socket: Int32, seconds: Int) throws {
    var timeout = timeval(tv_sec: max(1, seconds), tv_usec: 0)
    guard setsockopt(socket, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size)) == 0 else {
        throw ExternalConnectorSessionError.socketFailed("tcp setsockopt receive")
    }
    guard setsockopt(socket, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size)) == 0 else {
        throw ExternalConnectorSessionError.socketFailed("tcp setsockopt send")
    }
}

private func externalConnectorTcpAddress(host: String, port: UInt16) throws -> sockaddr_in {
    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = port.bigEndian
    guard inet_pton(AF_INET, host, &address.sin_addr) == 1 else {
        throw ExternalConnectorSessionError.socketFailed("tcp inet_pton \(host)")
    }
    return address
}

private func externalConnectorTcpHostString(_ address: in_addr) throws -> String {
    try lolaInetNtopString(address, failurePrefix: "tcp inet_ntop")
}
