// Runs LoLa control retries and records each request, response, timeout, and opaque datagram.
import Darwin
import Dispatch
import Foundation

let lolaControlDatagramByteCount = 1024
private let maxLoLaStatusRetryMessages = 8

/// Records the evidence and outcome for LoLa control retry responder report.
public struct LoLaControlRetryResponderReport: Codable, Equatable, Sendable {
    public var started: Bool
    public var localHost: String
    public var controlPort: UInt16
    public var timeoutSeconds: Int
    public var runtimeError: String?

    public init(
        started: Bool,
        localHost: String,
        controlPort: UInt16,
        timeoutSeconds: Int,
        runtimeError: String? = nil
    ) {
        self.started = started
        self.localHost = localHost
        self.controlPort = controlPort
        self.timeoutSeconds = timeoutSeconds
        self.runtimeError = runtimeError
    }

    public func validate() throws {
        try requireExternalConnectorSessionNonEmpty(localHost, "lolaControlRetryResponder.localHost")
        guard timeoutSeconds > 0 else {
            throw ExternalConnectorSessionError.invalidPositiveInteger(
                "lolaControlRetryResponder.timeoutSeconds",
                String(timeoutSeconds)
            )
        }
        if !started {
            try requireExternalConnectorSessionNonEmpty(
                runtimeError ?? "",
                "lolaControlRetryResponder.runtimeError"
            )
        }
    }
}
func runLoLaControlExchange(
    configuration: ExternalConnectorSessionConfiguration
) throws -> LoLaControlExchange {
    let attempt = try runLoLaControlExchangeAttempt(configuration: configuration)
    if let runtimeError = attempt.runtimeError {
        throw ExternalConnectorSessionError.processLaunchFailed(runtimeError)
    }
    return attempt.exchange
}

struct LoLaControlExchangeAttempt {
    var exchange: LoLaControlExchange
    var runtimeError: String?
    var isTimeout: Bool = false
}

func runLoLaControlExchangeAttempt(
    configuration: ExternalConnectorSessionConfiguration,
    onReceiveReady: (@Sendable () -> Void)? = nil
) throws -> LoLaControlExchangeAttempt {
    if configuration.controlTransport == .tcp {
        return try runLoLaTcpControlExchangeAttempt(
            configuration: configuration,
            onReceiveReady: onReceiveReady
        )
    }
    switch configuration.role {
    case .tx, .txRx:
        return try sendLoLaControlAttempt(configuration: configuration)
    case .rx:
        return try receiveLoLaControlAttempt(configuration: configuration, onReady: onReceiveReady)
    }
}

private struct LoLaReceiveControlState {
    var sentMessages: [String] = []
    var receivedMessages: [String] = []
    var opaqueControlDatagrams: [LoLaOpaqueControlDatagram] = []
    var bytesTransferred = 0

    mutating func recordSent(_ message: String, byteCount: Int) {
        sentMessages.append(message)
        bytesTransferred += byteCount
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

private func receiveLoLaControlAttempt(
    configuration: ExternalConnectorSessionConfiguration,
    onReady: (@Sendable () -> Void)? = nil
) throws -> LoLaControlExchangeAttempt {
    let descriptor = try makeExternalConnectorUdpSocket()
    defer { close(descriptor) }
    try prepareLoLaReceiveControlSocket(descriptor, configuration: configuration)
    onReady?()

    var state = LoLaReceiveControlState()
    var current = receiveLoLaReceiveControlMessage(
        socket: descriptor,
        state: state,
        configuration: configuration
    )
    if let failure = current.failure { return failure }
    var parsed = parseLoLaReceiveControlMessage(current, state: &state)
    if let failure = parsed.failure { return failure }

    let retryResult = try answerLoLaStatusRetries(
        socket: descriptor,
        configuration: configuration,
        state: &state,
        current: &current,
        parsed: &parsed
    )
    if let failure = retryResult { return failure }

    return try answerLoLaQuickConnect(
        socket: descriptor,
        configuration: configuration,
        state: &state,
        current: current,
        parsed: parsed
    )
}

private func prepareLoLaReceiveControlSocket(
    _ descriptor: Int32,
    configuration: ExternalConnectorSessionConfiguration
) throws {
    try bindExternalConnectorUdp(
        socket: descriptor,
        host: configuration.localHost,
        port: configuration.controlPort
    )
    try setExternalConnectorReceiveTimeout(socket: descriptor, seconds: configuration.durationSeconds)
}

private func receiveLoLaReceiveControlMessage(
    socket descriptor: Int32,
    state: LoLaReceiveControlState,
    configuration: ExternalConnectorSessionConfiguration,
    parsed: LoLaParsedControlMessage? = nil
) -> LoLaReceivedControlMessage {
    receiveLoLaControlMessage(
        socket: descriptor,
        sentMessages: state.sentMessages,
        receivedMessages: state.receivedMessages,
        bytesTransferred: state.bytesTransferred,
        destinationPort: configuration.controlPort,
        parsedMessageName: parsed?.parsed.name,
        fields: parsed?.parsed.fields ?? [:]
    )
}

private func parseLoLaReceiveControlMessage(
    _ received: LoLaReceivedControlMessage,
    state: inout LoLaReceiveControlState,
    previous: LoLaParsedControlMessage? = nil
) -> LoLaParsedControlMessage {
    parseReceivedLoLaControlMessage(
        received,
        sentMessages: state.sentMessages,
        receivedMessages: &state.receivedMessages,
        bytesTransferred: &state.bytesTransferred,
        opaqueControlDatagrams: &state.opaqueControlDatagrams,
        parsedMessageName: previous?.parsed.name,
        fields: previous?.parsed.fields ?? [:]
    )
}

private func answerLoLaStatusRetries(
    socket descriptor: Int32,
    configuration: ExternalConnectorSessionConfiguration,
    state: inout LoLaReceiveControlState,
    current: inout LoLaReceivedControlMessage,
    parsed: inout LoLaParsedControlMessage
) throws -> LoLaControlExchangeAttempt? {
    var statusRetryCount = 0
    while parsed.parsed.name == "/MESG_CHECKLOLASTATUS" {
        statusRetryCount += 1
        guard statusRetryCount <= maxLoLaStatusRetryMessages else {
            return state.failure(
                parsedMessageName: parsed.parsed.name,
                fields: parsed.parsed.fields,
                runtimeError: ExternalConnectorSessionError.socketFailed("too many LoLa status retries")
            )
        }
        if let failure = validateLoLaStatusCheck(
            current,
            parsed: parsed,
            state: state,
            configuration: configuration
        ) {
            return failure
        }
        try sendLoLaStatusAck(
            socket: descriptor,
            configuration: configuration,
            state: &state,
            current: current,
            parsed: parsed
        )
        current = receiveLoLaReceiveControlMessage(
            socket: descriptor,
            state: state,
            configuration: configuration,
            parsed: parsed
        )
        if let failure = current.failure { return failure }
        parsed = parseLoLaReceiveControlMessage(current, state: &state, previous: parsed)
        if let failure = parsed.failure { return failure }
    }
    return nil
}

private func validateLoLaStatusCheck(
    _ current: LoLaReceivedControlMessage,
    parsed: LoLaParsedControlMessage,
    state: LoLaReceiveControlState,
    configuration: ExternalConnectorSessionConfiguration
) -> LoLaControlExchangeAttempt? {
    validateLoLaIncomingHandshake(
        current,
        parsed: parsed,
        state: state,
        expectation: LoLaIncomingHandshakeExpectation(
            expectedName: "/MESG_CHECKLOLASTATUS",
            localHost: configuration.localHost,
            requiresMediaFields: false
        )
    )
}

private func sendLoLaStatusAck(
    socket descriptor: Int32,
    configuration: ExternalConnectorSessionConfiguration,
    state: inout LoLaReceiveControlState,
    current: LoLaReceivedControlMessage,
    parsed: LoLaParsedControlMessage
) throws {
    let ack = try lolaCheckStatusAck(
        configuration: configuration,
        receivedFields: parsed.parsed.fields,
        senderHost: current.senderHost
    )
    try sendLoLaReceiveAck(ack, socket: descriptor, state: &state, current: current)
}

private func sendLoLaReceiveAck(
    _ ack: String,
    socket descriptor: Int32,
    state: inout LoLaReceiveControlState,
    current: LoLaReceivedControlMessage
) throws {
    let byteCount = try sendExternalConnectorUdp(
        ack,
        socket: descriptor,
        host: current.senderHost,
        port: current.senderPort
    )
    state.recordSent(ack, byteCount: byteCount)
}

private func answerLoLaQuickConnect(
    socket descriptor: Int32,
    configuration: ExternalConnectorSessionConfiguration,
    state: inout LoLaReceiveControlState,
    current: LoLaReceivedControlMessage,
    parsed: LoLaParsedControlMessage
) throws -> LoLaControlExchangeAttempt {
    if let failure = validateLoLaIncomingHandshake(
        current,
        parsed: parsed,
        state: state,
        expectation: LoLaIncomingHandshakeExpectation(
            expectedName: "/MESG_QUICKCONN",
            localHost: configuration.localHost,
            requiresMediaFields: true
        )
    ) { return failure }
    let ack = try lolaQuickConnectAck(
        configuration: configuration,
        receivedFields: parsed.parsed.fields,
        senderHost: current.senderHost
    )
    try sendLoLaReceiveAck(ack, socket: descriptor, state: &state, current: current)

    return lolaControlAttemptSuccess(
        sentMessages: state.sentMessages,
        receivedMessages: state.receivedMessages,
        opaqueControlDatagrams: state.opaqueControlDatagrams,
        bytesTransferred: state.bytesTransferred,
        parsedMessageName: parsed.parsed.name,
        fields: parsed.parsed.fields
    )
}

private struct LoLaIncomingHandshakeExpectation {
    let expectedName: String
    let localHost: String
    let requiresMediaFields: Bool
}

private func validateLoLaIncomingHandshake(
    _ current: LoLaReceivedControlMessage,
    parsed: LoLaParsedControlMessage,
    state: LoLaReceiveControlState,
    expectation: LoLaIncomingHandshakeExpectation
) -> LoLaControlExchangeAttempt? {
    lolaIncomingHandshakeFailure(
        context: LoLaHandshakeValidationFailureContext(
            sentMessages: state.sentMessages,
            receivedMessages: state.receivedMessages,
            opaqueControlDatagrams: state.opaqueControlDatagrams,
            bytesTransferred: state.bytesTransferred,
            parsedMessageName: parsed.parsed.name,
            fields: parsed.parsed.fields,
            message: current.message
        ),
        expectedName: expectation.expectedName,
        localHost: expectation.localHost,
        requiresMediaFields: expectation.requiresMediaFields
    )
}
