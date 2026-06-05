import Darwin

struct LoLaReceivedControlMessage {
    var message: String
    var senderHost: String
    var senderPort: UInt16
    var bytesTransferred: Int
    var opaqueDatagram: LoLaOpaqueControlDatagram?
    var failure: LoLaControlExchangeAttempt?

    init(
        message: String,
        senderHost: String,
        senderPort: UInt16,
        bytesTransferred: Int,
        opaqueDatagram: LoLaOpaqueControlDatagram? = nil,
        failure: LoLaControlExchangeAttempt? = nil
    ) {
        self.message = message
        self.senderHost = senderHost
        self.senderPort = senderPort
        self.bytesTransferred = bytesTransferred
        self.opaqueDatagram = opaqueDatagram
        self.failure = failure
    }
}

struct LoLaParsedControlMessage {
    var parsed: (name: String, fields: [String: String])
    var failure: LoLaControlExchangeAttempt?
}

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

private struct LoLaStatusAckValidationContext {
    var state: LoLaExchangeState
    var configuration: ExternalConnectorSessionConfiguration
    var advertisedSourceIP: String
    var sessionID: Int
}

protocol LoLaOutgoingControlTransport: AnyObject {
    func prepare(configuration: ExternalConnectorSessionConfiguration) throws
    func send(_ message: String, host: String, port: UInt16) throws -> Int
    func receive(
        state: LoLaExchangeState,
        destinationPort: UInt16,
        parsedMessageName: String?,
        fields: [String: String]
    ) -> LoLaReceivedControlMessage
}

private final class DarwinLoLaOutgoingControlTransport: LoLaOutgoingControlTransport {
    private let descriptor: Int32

    init() throws {
        descriptor = try makeExternalConnectorUdpSocket()
    }

    deinit {
        close(descriptor)
    }

    func prepare(configuration: ExternalConnectorSessionConfiguration) throws {
        if shouldBindLoLaTransmitControlPort(configuration) {
            try bindLoLaTransmitControlPort(socket: descriptor, configuration: configuration)
        }
        try setExternalConnectorReceiveTimeout(socket: descriptor, seconds: configuration.durationSeconds)
    }

    func send(_ message: String, host: String, port: UInt16) throws -> Int {
        try sendExternalConnectorUdp(message, socket: descriptor, host: host, port: port)
    }

    func receive(
        state: LoLaExchangeState,
        destinationPort: UInt16,
        parsedMessageName: String?,
        fields: [String: String]
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
}

func sendLoLaControlAttempt(
    configuration: ExternalConnectorSessionConfiguration
) throws -> LoLaControlExchangeAttempt {
    try sendLoLaControlAttempt(
        configuration: configuration,
        transport: try DarwinLoLaOutgoingControlTransport()
    )
}

func sendLoLaControlAttempt(
    configuration: ExternalConnectorSessionConfiguration,
    transport: LoLaOutgoingControlTransport
) throws -> LoLaControlExchangeAttempt {
    guard !configuration.peer.isEmpty else {
        throw ExternalConnectorSessionError.lolaRequiresPeerForTx
    }
    try transport.prepare(configuration: configuration)

    var state = LoLaExchangeState()
    let sessionID = try lolaControlSessionID(configuration.sessionID)
    let advertisedSourceIP = try lolaControlAdvertisedSourceIP(configuration)

    let parsedStatusAck = try completeLoLaStatusCheckPhase(
        configuration: configuration,
        transport: transport,
        state: &state,
        advertisedSourceIP: advertisedSourceIP,
        sessionID: sessionID
    )

    if let failure = parsedStatusAck.failure { return failure }

    let parsedQuickConnectAck = try completeLoLaQuickConnectPhase(
        configuration: configuration,
        transport: transport,
        state: &state,
        advertisedSourceIP: advertisedSourceIP,
        parsedStatusAck: parsedStatusAck
    )
    if let failure = parsedQuickConnectAck.failure { return failure }

    return state.success(
        parsedMessageName: parsedQuickConnectAck.parsed.name,
        fields: parsedQuickConnectAck.parsed.fields
    )
}

private func completeLoLaStatusCheckPhase(
    configuration: ExternalConnectorSessionConfiguration,
    transport: LoLaOutgoingControlTransport,
    state: inout LoLaExchangeState,
    advertisedSourceIP: String,
    sessionID: Int
) throws -> LoLaParsedControlMessage {
    try sendLoLaStatusCheck(
        configuration: configuration,
        transport: transport,
        state: &state,
        advertisedSourceIP: advertisedSourceIP,
        sessionID: sessionID
    )

    let statusAck = receiveLoLaOutgoingControlMessage(
        transport: transport,
        state: state,
        destinationPort: configuration.controlPort
    )
    if let failure = statusAck.failure {
        guard isLoLaReceiveTimedOutFailure(failure) else {
            return LoLaParsedControlMessage(parsed: ("", [:]), failure: failure)
        }
        let fallback = try sendLoLaQuickConnectFallback(
            configuration: configuration,
            transport: transport,
            advertisedSourceIP: advertisedSourceIP,
            state: state
        )
        return LoLaParsedControlMessage(parsed: ("", [:]), failure: fallback)
    }

    let parsedStatusAck = parseLoLaOutgoingControlMessage(statusAck, state: &state)
    if parsedStatusAck.failure != nil { return parsedStatusAck }
    let validationContext = LoLaStatusAckValidationContext(
        state: state,
        configuration: configuration,
        advertisedSourceIP: advertisedSourceIP,
        sessionID: sessionID
    )
    if let failure = validateLoLaStatusAck(parsedStatusAck, received: statusAck, context: validationContext) {
        return LoLaParsedControlMessage(parsed: parsedStatusAck.parsed, failure: failure)
    }
    return parsedStatusAck
}

private func completeLoLaQuickConnectPhase(
    configuration: ExternalConnectorSessionConfiguration,
    transport: LoLaOutgoingControlTransport,
    state: inout LoLaExchangeState,
    advertisedSourceIP: String,
    parsedStatusAck: LoLaParsedControlMessage
) throws -> LoLaParsedControlMessage {
    try sendLoLaQuickConnect(
        configuration: configuration,
        transport: transport,
        state: &state,
        sourceIP: advertisedSourceIP
    )
    let quickConnectAck = receiveLoLaOutgoingControlMessage(
        transport: transport,
        state: state,
        destinationPort: configuration.controlPort,
        parsedMessageName: parsedStatusAck.parsed.name,
        fields: parsedStatusAck.parsed.fields
    )
    if let failure = quickConnectAck.failure {
        return LoLaParsedControlMessage(parsed: parsedStatusAck.parsed, failure: failure)
    }
    let parsedQuickConnectAck = parseLoLaOutgoingControlMessage(
        quickConnectAck,
        state: &state,
        parsedMessageName: parsedStatusAck.parsed.name,
        fields: parsedStatusAck.parsed.fields
    )
    if parsedQuickConnectAck.failure != nil { return parsedQuickConnectAck }
    if let failure = try validateLoLaQuickConnectAck(
        parsedQuickConnectAck,
        received: quickConnectAck,
        state: state,
        configuration: configuration,
        sourceIP: advertisedSourceIP
    ) {
        return LoLaParsedControlMessage(parsed: parsedQuickConnectAck.parsed, failure: failure)
    }
    return parsedQuickConnectAck
}

private func sendLoLaQuickConnectFallback(
    configuration: ExternalConnectorSessionConfiguration,
    transport: LoLaOutgoingControlTransport,
    advertisedSourceIP: String,
    state: LoLaExchangeState
) throws -> LoLaControlExchangeAttempt {
    var state = state
    try sendLoLaQuickConnect(
        configuration: configuration,
        transport: transport,
        state: &state,
        sourceIP: advertisedSourceIP
    )

    let quickConnectAck = receiveLoLaOutgoingControlMessage(
        transport: transport,
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
    transport: LoLaOutgoingControlTransport,
    state: inout LoLaExchangeState,
    advertisedSourceIP: String,
    sessionID: Int
) throws {
    let checkStatus = LoLaCompatibilityControlMessage.checkStatus(
        sourceIP: advertisedSourceIP,
        destinationIP: configuration.peer,
        sessionID: sessionID
    )
    let byteCount = try transport.send(
        checkStatus,
        host: configuration.peer,
        port: configuration.controlPort
    )
    state.recordSent(checkStatus, byteCount: byteCount)
}

private func sendLoLaQuickConnect(
    configuration: ExternalConnectorSessionConfiguration,
    transport: LoLaOutgoingControlTransport,
    state: inout LoLaExchangeState,
    sourceIP: String
) throws {
    let quickConnect = try lolaQuickConnectMessage(configuration: configuration, sourceIP: sourceIP)
    let byteCount = try transport.send(
        quickConnect,
        host: configuration.peer,
        port: configuration.controlPort
    )
    state.recordSent(quickConnect, byteCount: byteCount)
}

private func receiveLoLaOutgoingControlMessage(
    transport: LoLaOutgoingControlTransport,
    state: LoLaExchangeState,
    destinationPort: UInt16,
    parsedMessageName: String? = nil,
    fields: [String: String] = [:]
) -> LoLaReceivedControlMessage {
    transport.receive(
        state: state,
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
    context: LoLaStatusAckValidationContext
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

private func validateLoLaQuickConnectAck(
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
