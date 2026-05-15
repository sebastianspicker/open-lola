import Darwin

typealias LoLaReceivedControlMessage = (
    message: String,
    senderHost: String,
    senderPort: UInt16,
    bytesTransferred: Int,
    opaqueDatagram: LoLaOpaqueControlDatagram?,
    failure: LoLaControlExchangeAttempt?
)

typealias LoLaParsedControlMessage = (
    parsed: (name: String, fields: [String: String]),
    failure: LoLaControlExchangeAttempt?
)

struct LoLaExchangeState {
    var sentMessages: [String] = []
    var receivedMessages: [String] = []
    var opaqueControlDatagrams: [LoLaOpaqueControlDatagram] = []
    var bytesTransferred = 0

    mutating func recordSent(_ message: String, byteCount: Int) {
        bytesTransferred += byteCount
        sentMessages.append(message)
    }

    func success(parsedMessageName: String?, fields: [String: String]) -> LoLaControlExchangeAttempt {
        lolaControlAttemptSuccess(
            sentMessages: sentMessages,
            receivedMessages: receivedMessages,
            opaqueControlDatagrams: opaqueControlDatagrams,
            bytesTransferred: bytesTransferred,
            parsedMessageName: parsedMessageName,
            fields: fields
        )
    }
}

func sendLoLaControlAttempt(
    configuration: ExternalConnectorSessionConfiguration
) throws -> LoLaControlExchangeAttempt {
    guard !configuration.peer.isEmpty else {
        throw ExternalConnectorSessionError.lolaRequiresPeerForTx
    }
    let descriptor = try makeExternalConnectorUdpSocket()
    defer { close(descriptor) }
    if shouldBindLoLaTransmitControlPort(configuration) {
        try bindLoLaTransmitControlPort(socket: descriptor, configuration: configuration)
    }
    try setExternalConnectorReceiveTimeout(socket: descriptor, seconds: configuration.durationSeconds)

    var state = LoLaExchangeState()
    let sessionID = try lolaControlSessionID(configuration.sessionID)
    let advertisedSourceIP = try lolaControlAdvertisedSourceIP(configuration)

    try sendLoLaStatusCheck(
        configuration: configuration,
        socket: descriptor,
        state: &state,
        advertisedSourceIP: advertisedSourceIP,
        sessionID: sessionID
    )

    let statusAck = receiveLoLaOutgoingControlMessage(
        socket: descriptor,
        state: state,
        destinationPort: configuration.controlPort
    )
    if let failure = statusAck.failure {
        guard isLoLaReceiveTimedOutFailure(failure) else { return failure }
        return try sendLoLaQuickConnectFallback(
            configuration: configuration,
            socket: descriptor,
            advertisedSourceIP: advertisedSourceIP,
            state: state
        )
    }
    let parsedStatusAck = parseLoLaOutgoingControlMessage(
        statusAck,
        state: &state
    )
    if let failure = parsedStatusAck.failure { return failure }
    if let failure = validateLoLaStatusAck(
        parsedStatusAck,
        received: statusAck,
        state: state,
        configuration: configuration,
        advertisedSourceIP: advertisedSourceIP,
        sessionID: sessionID
    ) { return failure }

    try sendLoLaQuickConnect(configuration: configuration, socket: descriptor, state: &state, sourceIP: advertisedSourceIP)

    let quickConnectAck = receiveLoLaOutgoingControlMessage(
        socket: descriptor,
        state: state,
        destinationPort: configuration.controlPort,
        parsedMessageName: parsedStatusAck.parsed.name,
        fields: parsedStatusAck.parsed.fields
    )
    if let failure = quickConnectAck.failure { return failure }
    let parsedQuickConnectAck = parseLoLaOutgoingControlMessage(
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
        configuration: configuration,
        sourceIP: advertisedSourceIP
    ) { return failure }

    return state.success(
        parsedMessageName: parsedQuickConnectAck.parsed.name,
        fields: parsedQuickConnectAck.parsed.fields
    )
}

private func sendLoLaQuickConnectFallback(
    configuration: ExternalConnectorSessionConfiguration,
    socket descriptor: Int32,
    advertisedSourceIP: String,
    state: LoLaExchangeState
) throws -> LoLaControlExchangeAttempt {
    var state = state
    try sendLoLaQuickConnect(
        configuration: configuration,
        socket: descriptor,
        state: &state,
        sourceIP: advertisedSourceIP
    )

    let quickConnectAck = receiveLoLaOutgoingControlMessage(
        socket: descriptor,
        state: state,
        destinationPort: configuration.controlPort
    )
    if let failure = quickConnectAck.failure { return failure }
    let parsedQuickConnectAck = parseLoLaOutgoingControlMessage(
        quickConnectAck,
        state: &state
    )
    if let failure = parsedQuickConnectAck.failure { return failure }
    if let failure = try validateLoLaQuickConnectAck(
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

private func sendLoLaStatusCheck(
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
    let byteCount = try sendExternalConnectorUdp(
        checkStatus,
        socket: descriptor,
        host: configuration.peer,
        port: configuration.controlPort
    )
    state.recordSent(checkStatus, byteCount: byteCount)
}

private func sendLoLaQuickConnect(
    configuration: ExternalConnectorSessionConfiguration,
    socket descriptor: Int32,
    state: inout LoLaExchangeState,
    sourceIP: String
) throws {
    let quickConnect = try lolaQuickConnectMessage(configuration: configuration, sourceIP: sourceIP)
    let byteCount = try sendExternalConnectorUdp(
        quickConnect,
        socket: descriptor,
        host: configuration.peer,
        port: configuration.controlPort
    )
    state.recordSent(quickConnect, byteCount: byteCount)
}

private func receiveLoLaOutgoingControlMessage(
    socket descriptor: Int32,
    state: LoLaExchangeState,
    destinationPort: UInt16,
    parsedMessageName: String? = nil,
    fields: [String: String] = [:]
) -> LoLaReceivedControlMessage {
    receiveLoLaControlMessage(
        socket: descriptor,
        sentMessages: state.sentMessages,
        receivedMessages: state.receivedMessages,
        bytesTransferred: state.bytesTransferred,
        destinationPort: destinationPort,
        parsedMessageName: parsedMessageName,
        fields: fields
    )
}

private func parseLoLaOutgoingControlMessage(
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

private func validateLoLaStatusAck(
    _ parsedStatusAck: LoLaParsedControlMessage,
    received statusAck: LoLaReceivedControlMessage,
    state: LoLaExchangeState,
    configuration: ExternalConnectorSessionConfiguration,
    advertisedSourceIP: String,
    sessionID: Int
) -> LoLaControlExchangeAttempt? {
    lolaOutgoingHandshakeFailure(
        sentMessages: state.sentMessages,
        receivedMessages: state.receivedMessages,
        opaqueControlDatagrams: state.opaqueControlDatagrams,
        bytesTransferred: state.bytesTransferred,
        parsedMessageName: parsedStatusAck.parsed.name,
        fields: parsedStatusAck.parsed.fields,
        message: statusAck.message,
        expectedName: "/MESG_CHECKLOLASTATUS_ACK",
        expectedFields: lolaExpectedStatusAckFields(
            sourceIP: advertisedSourceIP,
            destinationIP: configuration.peer,
            sessionID: sessionID
        )
    )
}

private func validateLoLaQuickConnectAck(
    _ parsedQuickConnectAck: LoLaParsedControlMessage,
    received quickConnectAck: LoLaReceivedControlMessage,
    state: LoLaExchangeState,
    configuration: ExternalConnectorSessionConfiguration,
    sourceIP: String
) throws -> LoLaControlExchangeAttempt? {
    lolaOutgoingHandshakeFailure(
        sentMessages: state.sentMessages,
        receivedMessages: state.receivedMessages,
        opaqueControlDatagrams: state.opaqueControlDatagrams,
        bytesTransferred: state.bytesTransferred,
        parsedMessageName: parsedQuickConnectAck.parsed.name,
        fields: parsedQuickConnectAck.parsed.fields,
        message: quickConnectAck.message,
        expectedName: "/MESG_QUICKCONN_ACK",
        expectedFields: try lolaExpectedQuickConnectFields(configuration: configuration, sourceIP: sourceIP)
    )
}
