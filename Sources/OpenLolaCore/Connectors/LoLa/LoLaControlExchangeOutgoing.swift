// Handles LoLaControlExchangeOutgoing control exchange, keeping control-plane details distinct from media data flow.
import Darwin
import Foundation

private let maxLoLaOutgoingHandshakeDiscardedDatagrams = 64

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

    mutating func recordDiscarded(
        _ received: LoLaReceivedControlMessage,
        maximumOpaqueDatagrams: Int
    ) {
        bytesTransferred += received.bytesTransferred
        if let opaqueDatagram = received.opaqueDatagram,
            opaqueControlDatagrams.count < maximumOpaqueDatagrams
        {
            opaqueControlDatagrams.append(opaqueDatagram)
        }
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

    func failure(
        parsedMessageName: String?,
        fields: [String: String],
        runtimeError: Error
    ) -> LoLaControlExchangeAttempt {
        lolaControlAttemptFailure(
            sentMessages: sentMessages,
            receivedMessages: receivedMessages,
            bytesTransferred: bytesTransferred,
            opaqueControlDatagrams: opaqueControlDatagrams,
            parsedMessageName: parsedMessageName,
            fields: fields,
            runtimeError: runtimeError
        )
    }
}

protocol LoLaOutgoingControlTransport: AnyObject {
    func prepare(configuration: ExternalConnectorSessionConfiguration) throws
    func send(_ message: String, host: String, port: UInt16) throws -> Int
    func receive(
        state: LoLaExchangeState,
        destinationPort: UInt16,
        deadline: MonotonicDeadline,
        parsedMessageName: String?,
        fields: [String: String]
    ) -> LoLaReceivedControlMessage
}

struct LoLaStatusAckValidationContext {
    var state: LoLaExchangeState
    var configuration: ExternalConnectorSessionConfiguration
    var advertisedSourceIP: String
    var sessionID: Int
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
        deadline: MonotonicDeadline,
        parsedMessageName: String?,
        fields: [String: String]
    ) -> LoLaReceivedControlMessage {
        receiveLoLaControlMessage(
            socket: descriptor,
            sentMessages: state.sentMessages,
            receivedMessages: state.receivedMessages,
            bytesTransferred: state.bytesTransferred,
            destinationPort: destinationPort,
            deadline: deadline,
            parsedMessageName: parsedMessageName,
            fields: fields
        )
    }
}

func sendLoLaControlAttempt(
    configuration: ExternalConnectorSessionConfiguration
) throws -> LoLaControlExchangeAttempt {
    let transport = try DarwinLoLaOutgoingControlTransport()
    var attempt = try sendLoLaControlAttempt(
        configuration: configuration,
        transport: transport
    )
    if attempt.runtimeError == nil {
        attempt.terminalSession = try makeLoLaControlTerminalSession(
            configuration: configuration,
            exchange: attempt.exchange,
            send: { message in
                try transport.send(message, host: configuration.peer, port: configuration.controlPort)
            }
        )
    }
    return attempt
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
    var discardedDatagrams = 0
    do {
        let sessionID = try lolaControlSessionID(configuration.sessionID)
        let advertisedSourceIP = try lolaControlAdvertisedSourceIP(configuration)

        let parsedStatusAck = try completeLoLaStatusCheckPhase(
            configuration: configuration,
            transport: transport,
            state: &state,
            advertisedSourceIP: advertisedSourceIP,
            sessionID: sessionID,
            discardedDatagrams: &discardedDatagrams
        )

        if let failure = parsedStatusAck.failure { return failure }

        let parsedQuickConnectAck = try completeLoLaQuickConnectPhase(
            configuration: configuration,
            transport: transport,
            state: &state,
            advertisedSourceIP: advertisedSourceIP,
            parsedStatusAck: parsedStatusAck,
            discardedDatagrams: &discardedDatagrams
        )
        if let failure = parsedQuickConnectAck.failure { return failure }

        return state.success(
            parsedMessageName: parsedQuickConnectAck.parsed.name,
            fields: parsedQuickConnectAck.parsed.fields
        )
    } catch {
        return state.failure(parsedMessageName: nil, fields: [:], runtimeError: error)
    }
}

private func completeLoLaStatusCheckPhase(
    configuration: ExternalConnectorSessionConfiguration,
    transport: LoLaOutgoingControlTransport,
    state: inout LoLaExchangeState,
    advertisedSourceIP: String,
    sessionID: Int,
    discardedDatagrams: inout Int
) throws -> LoLaParsedControlMessage {
    try sendLoLaStatusCheck(
        configuration: configuration,
        transport: transport,
        state: &state,
        advertisedSourceIP: advertisedSourceIP,
        sessionID: sessionID
    )

    let deadline = MonotonicDeadline(seconds: TimeInterval(max(1, configuration.durationSeconds)))
    let statusAck = try receiveLoLaOutgoingHandshakeMessage(
        transport: transport,
        state: &state,
        destinationPort: configuration.controlPort,
        deadline: deadline,
        discardedDatagrams: &discardedDatagrams
    ) { parsed, received, state in
        validateLoLaStatusAck(
            parsed,
            received: received,
            context: .init(
                state: state,
                configuration: configuration,
                advertisedSourceIP: advertisedSourceIP,
                sessionID: sessionID
            )
        )
    }
    if let failure = statusAck.failure {
        guard isLoLaReceiveTimedOutFailure(failure) else {
            return LoLaParsedControlMessage(parsed: ("", [:]), failure: failure)
        }
        let fallback = try sendLoLaQuickConnectFallback(
            configuration: configuration,
            transport: transport,
            advertisedSourceIP: advertisedSourceIP,
            state: state,
            discardedDatagrams: &discardedDatagrams
        )
        return LoLaParsedControlMessage(parsed: ("", [:]), failure: fallback)
    }

    return statusAck
}

private func completeLoLaQuickConnectPhase(
    configuration: ExternalConnectorSessionConfiguration,
    transport: LoLaOutgoingControlTransport,
    state: inout LoLaExchangeState,
    advertisedSourceIP: String,
    parsedStatusAck: LoLaParsedControlMessage,
    discardedDatagrams: inout Int
) throws -> LoLaParsedControlMessage {
    try sendLoLaQuickConnect(
        configuration: configuration,
        transport: transport,
        state: &state,
        sourceIP: advertisedSourceIP
    )
    let deadline = MonotonicDeadline(seconds: TimeInterval(max(1, configuration.durationSeconds)))
    return try receiveLoLaOutgoingHandshakeMessage(
        transport: transport,
        state: &state,
        destinationPort: configuration.controlPort,
        deadline: deadline,
        discardedDatagrams: &discardedDatagrams,
        parsedMessageName: parsedStatusAck.parsed.name,
        fields: parsedStatusAck.parsed.fields
    ) { parsed, received, state in
        try validateLoLaQuickConnectAck(
            parsed,
            received: received,
            state: state,
            configuration: configuration,
            sourceIP: advertisedSourceIP
        )
    }
}

private func sendLoLaQuickConnectFallback(
    configuration: ExternalConnectorSessionConfiguration,
    transport: LoLaOutgoingControlTransport,
    advertisedSourceIP: String,
    state: LoLaExchangeState,
    discardedDatagrams: inout Int
) throws -> LoLaControlExchangeAttempt {
    var state = state
    try sendLoLaQuickConnect(
        configuration: configuration,
        transport: transport,
        state: &state,
        sourceIP: advertisedSourceIP
    )

    let deadline = MonotonicDeadline(seconds: TimeInterval(max(1, configuration.durationSeconds)))
    let quickConnectAck = try receiveLoLaOutgoingHandshakeMessage(
        transport: transport,
        state: &state,
        destinationPort: configuration.controlPort,
        deadline: deadline,
        discardedDatagrams: &discardedDatagrams
    ) { parsed, received, state in
        try validateLoLaQuickConnectAck(
            parsed,
            received: received,
            state: state,
            configuration: configuration,
            sourceIP: advertisedSourceIP
        )
    }
    if let failure = quickConnectAck.failure { return failure }
    return state.success(
        parsedMessageName: quickConnectAck.parsed.name, fields: quickConnectAck.parsed.fields)
}

func completeLoLaQuickConnectFallbackResponse(
    _ quickConnectAck: LoLaReceivedControlMessage,
    configuration: ExternalConnectorSessionConfiguration,
    sourceIP: String,
    state: inout LoLaExchangeState
) throws -> LoLaControlExchangeAttempt {
    let parsedQuickConnectAck = parseLoLaExchangeControlMessage(quickConnectAck, state: &state)
    if let failure = parsedQuickConnectAck.failure { return failure }
    if let failure = try validateLoLaQuickConnectAck(
        parsedQuickConnectAck,
        received: quickConnectAck,
        state: state,
        configuration: configuration,
        sourceIP: sourceIP
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

private func receiveLoLaOutgoingHandshakeMessage(
    transport: LoLaOutgoingControlTransport,
    state: inout LoLaExchangeState,
    destinationPort: UInt16,
    deadline: MonotonicDeadline,
    discardedDatagrams: inout Int,
    parsedMessageName: String? = nil,
    fields: [String: String] = [:],
    validate: (LoLaParsedControlMessage, LoLaReceivedControlMessage, LoLaExchangeState) throws
        -> LoLaControlExchangeAttempt?
) throws -> LoLaParsedControlMessage {
    while true {
        let received = transport.receive(
            state: state,
            destinationPort: destinationPort,
            deadline: deadline,
            parsedMessageName: parsedMessageName,
            fields: fields
        )
        if let failure = received.failure {
            return LoLaParsedControlMessage(
                parsed: ("", [:]),
                failure: state.failure(
                    parsedMessageName: parsedMessageName,
                    fields: fields,
                    runtimeError: lolaControlAttemptRuntimeError(failure)
                )
            )
        }
        do {
            let candidate = LoLaParsedControlMessage(
                parsed: try LoLaCompatibilityControlMessage.parse(received.message),
                failure: nil
            )
            if try validate(candidate, received, state) == nil {
                return parseLoLaExchangeControlMessage(
                    received,
                    state: &state,
                    parsedMessageName: parsedMessageName,
                    fields: fields
                )
            }
        } catch {
            // The packet is intentionally discarded below. Its full bytes never enter a report.
        }
        state.recordDiscarded(
            received,
            maximumOpaqueDatagrams: maxLoLaOutgoingHandshakeDiscardedDatagrams
        )
        discardedDatagrams += 1
        guard discardedDatagrams <= maxLoLaOutgoingHandshakeDiscardedDatagrams else {
            return LoLaParsedControlMessage(
                parsed: ("", [:]),
                failure: state.failure(
                    parsedMessageName: parsedMessageName,
                    fields: fields,
                    runtimeError: ExternalConnectorSessionError.socketFailed(
                        "too many unexpected LoLa handshake datagrams"
                    )
                ))
        }
    }
}

func parseLoLaExchangeControlMessage(
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

func validateLoLaStatusAck(
    _ parsedStatusAck: LoLaParsedControlMessage,
    received statusAck: LoLaReceivedControlMessage,
    context: LoLaStatusAckValidationContext
) -> LoLaControlExchangeAttempt? {
    validateLoLaOutgoingAck(
        parsedStatusAck,
        received: statusAck,
        state: context.state,
        expectedName: "/MESG_CHECKLOLASTATUS_ACK",
        expectedFields: lolaExpectedStatusAckFields(
            sourceIP: context.advertisedSourceIP,
            destinationIP: context.configuration.peer,
            sessionID: context.sessionID
        ),
        expectedSenderHost: context.configuration.peer,
        expectedSenderPort: context.configuration.controlPort
    )
}

func validateLoLaQuickConnectAck(
    _ parsedQuickConnectAck: LoLaParsedControlMessage,
    received quickConnectAck: LoLaReceivedControlMessage,
    state: LoLaExchangeState,
    configuration: ExternalConnectorSessionConfiguration,
    sourceIP: String
) throws -> LoLaControlExchangeAttempt? {
    validateLoLaOutgoingAck(
        parsedQuickConnectAck,
        received: quickConnectAck,
        state: state,
        expectedName: "/MESG_QUICKCONN_ACK",
        expectedFields: try lolaExpectedQuickConnectFields(configuration: configuration, sourceIP: sourceIP),
        expectedSenderHost: configuration.peer,
        expectedSenderPort: configuration.controlPort
    )
}

func validateLoLaOutgoingAck(
    _ parsedAck: LoLaParsedControlMessage,
    received ack: LoLaReceivedControlMessage,
    state: LoLaExchangeState,
    expectedName: String,
    expectedFields: [String: String],
    expectedSenderHost: String,
    expectedSenderPort: UInt16
) -> LoLaControlExchangeAttempt? {
    lolaOutgoingHandshakeFailure(
        context: LoLaHandshakeValidationFailureContext(
            sentMessages: state.sentMessages,
            receivedMessages: state.receivedMessages,
            opaqueControlDatagrams: state.opaqueControlDatagrams,
            bytesTransferred: state.bytesTransferred,
            parsedMessageName: parsedAck.parsed.name,
            fields: parsedAck.parsed.fields,
            message: ack.message,
            senderHost: ack.senderHost,
            senderPort: ack.senderPort
        ),
        expectedName: expectedName,
        expectedFields: expectedFields,
        expectedSenderHost: expectedSenderHost,
        expectedSenderPort: expectedSenderPort
    )
}
