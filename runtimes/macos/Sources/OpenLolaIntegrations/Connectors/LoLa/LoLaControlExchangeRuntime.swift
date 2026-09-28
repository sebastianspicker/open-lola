import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
// Runs LoLa control retries and records each request, response, timeout, and opaque datagram.
import Darwin
import Dispatch
import Foundation
import OpenLolaSessionDomain

let lolaControlDatagramByteCount = 1024
private let maxLoLaStatusRetryMessages = 8
private let maxLoLaIncomingHandshakeDiscardedDatagrams = 64

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
    var terminalSession: LoLaControlTerminalSession?
}

func runLoLaControlExchangeAttempt(
    configuration: ExternalConnectorSessionConfiguration,
    onReceiveReady: (@Sendable () -> Void)? = nil
) throws -> LoLaControlExchangeAttempt {
    do {
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
            return try receiveLoLaControlAttempt(
                configuration: configuration, onReady: onReceiveReady)
        }
    } catch {
        return lolaControlAttemptFailure(
            sentMessages: [],
            receivedMessages: [],
            bytesTransferred: 0,
            runtimeError: error
        )
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
    let socket = LoLaControlSocketLease(descriptor: try makeExternalConnectorUdpSocket())
    let descriptor = socket.descriptor
    try prepareLoLaReceiveControlSocket(descriptor, configuration: configuration)
    onReady?()

    var state = LoLaReceiveControlState()
    let initialStatusDeadline = MonotonicDeadline(
        seconds: TimeInterval(max(1, configuration.durationSeconds))
    )
    var discardedDatagrams = 0
    let initial = receiveLoLaIncomingHandshakeMessage(
        socket: descriptor,
        state: &state,
        configuration: configuration,
        deadline: initialStatusDeadline,
        discardedDatagrams: &discardedDatagrams
    )
    var current = initial.received
    if let failure = current.failure { return failure }
    var parsed = initial.parsed
    if let failure = parsed.failure { return failure }

    do {
        let handshakeDeadline = MonotonicDeadline(
            seconds: TimeInterval(max(1, configuration.durationSeconds))
        )
        let retryResult = try answerLoLaStatusRetries(
            socket: descriptor,
            configuration: configuration,
            state: &state,
            current: &current,
            parsed: &parsed,
            deadline: handshakeDeadline,
            discardedDatagrams: &discardedDatagrams
        )
        if let failure = retryResult { return failure }

        var attempt = try answerLoLaQuickConnect(
            socket: descriptor,
            configuration: configuration,
            state: &state,
            current: current,
            parsed: parsed
        )
        if attempt.runtimeError == nil {
            attempt.terminalSession = try makeLoLaControlTerminalSession(
                configuration: configuration,
                exchange: attempt.exchange,
                send: { [socket] message in
                    try sendExternalConnectorUdp(
                        message,
                        socket: socket.descriptor,
                        host: current.senderHost,
                        port: current.senderPort
                    )
                },
                duplicateSocketForRetryResponder: { [socket] in
                    let duplicateDescriptor = dup(socket.descriptor)
                    guard duplicateDescriptor >= 0 else {
                        throw ExternalConnectorSessionError.socketFailed("dup errno \(errno)")
                    }
                    return duplicateDescriptor
                }
            )
        }
        return attempt
    } catch {
        return state.failure(
            parsedMessageName: parsed.parsed.name,
            fields: parsed.parsed.fields,
            runtimeError: error
        )
    }
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
    deadline: MonotonicDeadline,
    parsed: LoLaParsedControlMessage? = nil
) -> LoLaReceivedControlMessage {
    receiveLoLaControlMessage(
        socket: descriptor,
        sentMessages: state.sentMessages,
        receivedMessages: state.receivedMessages,
        bytesTransferred: state.bytesTransferred,
        destinationPort: configuration.controlPort,
        deadline: deadline,
        parsedMessageName: parsed?.parsed.name,
        fields: parsed?.parsed.fields ?? [:]
    )
}

private func receiveLoLaIncomingHandshakeMessage(
    socket descriptor: Int32,
    state: inout LoLaReceiveControlState,
    configuration: ExternalConnectorSessionConfiguration,
    deadline: MonotonicDeadline,
    discardedDatagrams: inout Int,
    previous: LoLaParsedControlMessage? = nil
) -> (received: LoLaReceivedControlMessage, parsed: LoLaParsedControlMessage) {
    while true {
        let received = receiveLoLaReceiveControlMessage(
            socket: descriptor,
            state: state,
            configuration: configuration,
            deadline: deadline,
            parsed: previous
        )
        if let failure = received.failure {
            let rebuiltFailure = state.failure(
                parsedMessageName: previous?.parsed.name,
                fields: previous?.parsed.fields ?? [:],
                runtimeError: lolaControlAttemptRuntimeError(failure)
            )
            var failedReceived = received
            failedReceived.failure = rebuiltFailure
            return (failedReceived, .init(parsed: ("", [:]), failure: rebuiltFailure))
        }
        do {
            let candidate = LoLaParsedControlMessage(
                parsed: try decodeLoLaReceivedControlDatagram(received),
                failure: nil
            )
            let requiresMediaFields = candidate.parsed.name == "/MESG_QUICKCONN"
            if candidate.parsed.name == "/MESG_CHECKLOLASTATUS" || requiresMediaFields,
                validateLoLaIncomingHandshake(
                    received,
                    parsed: candidate,
                    state: state,
                    expectation: .init(
                        expectedName: candidate.parsed.name,
                        localHost: configuration.localHost,
                        requiresMediaFields: requiresMediaFields,
                        peer: configuration.peer
                    )
                ) == nil
            {
                let parsed = parseLoLaReceiveControlMessage(
                    received, state: &state, previous: previous)
                return (received, parsed)
            }
        } catch {
            // The packet is intentionally discarded below. Its full bytes never enter a report.
        }
        state.recordDiscarded(
            received,
            maximumOpaqueDatagrams: maxLoLaIncomingHandshakeDiscardedDatagrams
        )
        discardedDatagrams += 1
        if discardedDatagrams > maxLoLaIncomingHandshakeDiscardedDatagrams {
            let failure = state.failure(
                parsedMessageName: previous?.parsed.name,
                fields: previous?.parsed.fields ?? [:],
                runtimeError: ExternalConnectorSessionError.socketFailed(
                    "too many unexpected LoLa handshake datagrams"
                )
            )
            var failedReceived = received
            failedReceived.failure = failure
            return (failedReceived, .init(parsed: ("", [:]), failure: failure))
        }
    }
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
    parsed: inout LoLaParsedControlMessage,
    deadline: MonotonicDeadline,
    discardedDatagrams: inout Int
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
        let next = receiveLoLaIncomingHandshakeMessage(
            socket: descriptor,
            state: &state,
            configuration: configuration,
            deadline: deadline,
            discardedDatagrams: &discardedDatagrams,
            previous: parsed
        )
        current = next.received
        if let failure = current.failure { return failure }
        parsed = next.parsed
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
            requiresMediaFields: false,
            peer: configuration.peer
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
            requiresMediaFields: true,
            peer: configuration.peer
        )
    ) { return failure }
    let response: String
    do {
        response = try lolaQuickConnectAck(
            configuration: configuration,
            receivedFields: parsed.parsed.fields,
            senderHost: current.senderHost
        )
    } catch {
        let rejection = try lolaQuickConnectReject(
            configuration: configuration,
            receivedFields: parsed.parsed.fields,
            senderHost: current.senderHost,
            reason: String(describing: error)
        )
        try sendLoLaReceiveAck(rejection, socket: descriptor, state: &state, current: current)
        return state.failure(
            parsedMessageName: parsed.parsed.name,
            fields: parsed.parsed.fields,
            runtimeError: error
        )
    }
    try sendLoLaReceiveAck(response, socket: descriptor, state: &state, current: current)

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
    let peer: String
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
        requiresMediaFields: expectation.requiresMediaFields,
        senderHost: current.senderHost,
        peer: expectation.peer
    )
}
