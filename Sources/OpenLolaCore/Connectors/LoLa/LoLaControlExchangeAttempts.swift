// Handles LoLaControlExchangeAttempts control exchange, keeping control-plane details distinct from media data flow.
import Darwin
import Dispatch
import Foundation

func startLoLaControlRetryResponder(
    configuration: ExternalConnectorSessionConfiguration
) -> LoLaControlRetryResponderReport {
    do {
        let keepAliveDescriptor = try prepareLoLaControlRetryResponderSocket(configuration: configuration)
        return startLoLaControlRetryResponder(
            configuration: configuration, reusing: keepAliveDescriptor
        )
    } catch {
        return lolaControlRetryResponderFailure(configuration: configuration, error: error)
    }
}

func startLoLaControlRetryResponder(
    configuration: ExternalConnectorSessionConfiguration,
    terminalSession: LoLaControlTerminalSession?
) -> LoLaControlRetryResponderReport {
    do {
        guard let terminalSession else {
            throw ExternalConnectorSessionError.socketFailed(
                "negotiated UDP control socket unavailable for retry responder"
            )
        }
        return startLoLaControlRetryResponder(
            configuration: configuration,
            reusing: try terminalSession.duplicateSocketForRetryResponder()
        )
    } catch {
        return lolaControlRetryResponderFailure(configuration: configuration, error: error)
    }
}

private func startLoLaControlRetryResponder(
    configuration: ExternalConnectorSessionConfiguration,
    reusing descriptor: Int32
) -> LoLaControlRetryResponderReport {
    do {
        try setExternalConnectorReceiveTimeout(socket: descriptor, seconds: 1)
        startLoLaControlRetryResponderLoop(descriptor: descriptor, configuration: configuration)
        return LoLaControlRetryResponderReport(
            started: true,
            localHost: configuration.localHost,
            controlPort: configuration.controlPort,
            timeoutSeconds: configuration.durationSeconds
        )
    } catch {
        close(descriptor)
        return lolaControlRetryResponderFailure(configuration: configuration, error: error)
    }
}

private func lolaControlRetryResponderFailure(
    configuration: ExternalConnectorSessionConfiguration,
    error: Error
) -> LoLaControlRetryResponderReport {
    LoLaControlRetryResponderReport(
        started: false,
        localHost: configuration.localHost,
        controlPort: configuration.controlPort,
        timeoutSeconds: configuration.durationSeconds,
        runtimeError: String(describing: error)
    )
}

private func prepareLoLaControlRetryResponderSocket(
    configuration: ExternalConnectorSessionConfiguration
) throws -> Int32 {
    let descriptor = try makeExternalConnectorUdpSocket()
    try bindExternalConnectorUdp(
        socket: descriptor,
        host: configuration.localHost,
        port: configuration.controlPort
    )
    try setExternalConnectorReceiveTimeout(socket: descriptor, seconds: 1)
    return descriptor
}

private func startLoLaControlRetryResponderLoop(
    descriptor keepAliveDescriptor: Int32,
    configuration: ExternalConnectorSessionConfiguration
) {
    DispatchQueue.global(qos: .userInitiated).async {
        defer { close(keepAliveDescriptor) }
        let deadline = MonotonicDeadline(seconds: TimeInterval(max(1, configuration.durationSeconds)))
        while deadline.hasTimeRemaining {
            do {
                try answerLoLaControlRetryMessageIfAvailable(
                    socket: keepAliveDescriptor,
                    configuration: configuration
                )
            } catch {
                return
            }
        }
    }
}

private func answerLoLaControlRetryMessageIfAvailable(
    socket keepAliveDescriptor: Int32,
    configuration: ExternalConnectorSessionConfiguration
) throws {
    let received: ExternalConnectorUdpReceiveResult
    let parsed: (name: String, fields: [String: String])
    do {
        received = try receiveExternalConnectorUdp(socket: keepAliveDescriptor, bufferSize: 4096)
        parsed = try LoLaCompatibilityControlMessage.parse(received.message)
    } catch {
        return
    }
    if let response = try lolaRetryResponderAck(
        configuration: configuration,
        message: received.message,
        parsed: parsed,
        senderHost: received.senderHost
    ) {
        _ = try sendExternalConnectorUdp(
            response,
            socket: keepAliveDescriptor,
            host: received.senderHost,
            port: received.senderPort
        )
    }
}

func receiveLoLaControlMessage(
    socket: Int32,
    sentMessages: [String],
    receivedMessages: [String],
    bytesTransferred: Int,
    destinationPort: UInt16,
    deadline: MonotonicDeadline? = nil,
    parsedMessageName: String? = nil,
    fields: [String: String] = [:]
) -> LoLaReceivedControlMessage {
    do {
        if let deadline {
            let remainingMicroseconds = UInt64((deadline.remainingSeconds * 1_000_000).rounded(.up))
            guard remainingMicroseconds > 0,
                try waitForReadableSocket(
                    socket: socket, timeoutMicroseconds: remainingMicroseconds)
            else {
                throw ExternalConnectorSessionError.receiveTimedOut
            }
        }
        let received = try receiveExternalConnectorUdp(socket: socket, bufferSize: 4096)
        let opaqueDatagram = received.message.hasPrefix("/MESG_") ? nil : LoLaOpaqueControlDatagram.classify(
            payload: received.payload,
            sourceHost: received.senderHost,
            sourcePort: received.senderPort,
            destinationPort: destinationPort
        )
        return LoLaReceivedControlMessage(
            message: received.message,
            senderHost: received.senderHost,
            senderPort: received.senderPort,
            bytesTransferred: received.bytesTransferred,
            opaqueDatagram: opaqueDatagram,
            failure: nil
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

struct LoLaControlMessageFailureContext {
    var sentMessages: [String]
    var receivedMessages: [String]
    var bytesTransferred: Int
    var parsedMessageName: String?
    var fields: [String: String]
}

private struct LoLaRecordedControlAttemptError: Error, CustomStringConvertible {
    var description: String
}

func lolaControlAttemptRuntimeError(_ attempt: LoLaControlExchangeAttempt) -> Error {
    guard !attempt.isTimeout else {
        return ExternalConnectorSessionError.receiveTimedOut
    }
    return LoLaRecordedControlAttemptError(
        description: attempt.runtimeError ?? "LoLa control receive failed"
    )
}

func lolaReceivedControlMessageFailure(
    context: LoLaControlMessageFailureContext,
    runtimeError: Error
) -> LoLaReceivedControlMessage {
    LoLaReceivedControlMessage(
        message: "",
        senderHost: "",
        senderPort: 0,
        bytesTransferred: 0,
        failure: lolaControlAttemptFailure(
            sentMessages: context.sentMessages,
            receivedMessages: context.receivedMessages,
            bytesTransferred: context.bytesTransferred,
            parsedMessageName: context.parsedMessageName,
            fields: context.fields,
            runtimeError: runtimeError
        )
    )
}

func parseReceivedLoLaControlMessage(
    _ received: LoLaReceivedControlMessage,
    sentMessages: [String],
    receivedMessages: inout [String],
    bytesTransferred: inout Int,
    opaqueControlDatagrams: inout [LoLaOpaqueControlDatagram],
    parsedMessageName: String? = nil,
    fields: [String: String] = [:]
) -> LoLaParsedControlMessage {
    receivedMessages.append(received.message)
    bytesTransferred += received.bytesTransferred
    do {
        return LoLaParsedControlMessage(
            parsed: try LoLaCompatibilityControlMessage.parse(received.message),
            failure: nil
        )
    } catch {
        if let opaqueDatagram = received.opaqueDatagram {
            opaqueControlDatagrams.append(opaqueDatagram)
        }
        return LoLaParsedControlMessage(parsed: ("", [:]), failure: lolaControlAttemptFailure(
            sentMessages: sentMessages,
            receivedMessages: receivedMessages,
            bytesTransferred: bytesTransferred,
            opaqueControlDatagrams: opaqueControlDatagrams,
            parsedMessageName: parsedMessageName,
            fields: fields,
            runtimeError: error
        ))
    }
}

func parseLoLaControlMessage(
    _ message: String,
    sentMessages: [String],
    receivedMessages: inout [String],
    bytesTransferred: inout Int,
    transferredBytes: Int,
    parsedMessageName: String? = nil,
    fields: [String: String] = [:]
) -> LoLaParsedControlMessage {
    receivedMessages.append(message)
    bytesTransferred += transferredBytes
    do {
        return LoLaParsedControlMessage(parsed: try LoLaCompatibilityControlMessage.parse(message), failure: nil)
    } catch {
        return LoLaParsedControlMessage(parsed: ("", [:]), failure: lolaControlAttemptFailure(
            sentMessages: sentMessages,
            receivedMessages: receivedMessages,
            bytesTransferred: bytesTransferred,
            parsedMessageName: parsedMessageName,
            fields: fields,
            runtimeError: error
        ))
    }
}

func lolaControlAttemptSuccess(
    sentMessages: [String],
    receivedMessages: [String],
    opaqueControlDatagrams: [LoLaOpaqueControlDatagram] = [],
    bytesTransferred: Int,
    parsedMessageName: String?,
    fields: [String: String]
) -> LoLaControlExchangeAttempt {
    LoLaControlExchangeAttempt(
        exchange: LoLaControlExchange(
            sentMessage: sentMessages.last,
            receivedMessage: receivedMessages.last,
            sentMessages: sentMessages,
            receivedMessages: receivedMessages,
            opaqueControlDatagrams: opaqueControlDatagrams,
            parsedMessageName: parsedMessageName,
            fields: fields,
            bytesTransferred: bytesTransferred
        ),
        runtimeError: nil,
        isTimeout: false
    )
}

func lolaControlAttemptFailure(
    sentMessages: [String],
    receivedMessages: [String],
    bytesTransferred: Int,
    opaqueControlDatagrams: [LoLaOpaqueControlDatagram] = [],
    parsedMessageName: String? = nil,
    fields: [String: String] = [:],
    runtimeError: Error
) -> LoLaControlExchangeAttempt {
    LoLaControlExchangeAttempt(
        exchange: LoLaControlExchange(
            sentMessage: sentMessages.last,
            receivedMessage: receivedMessages.last,
            sentMessages: sentMessages,
            receivedMessages: receivedMessages,
            opaqueControlDatagrams: opaqueControlDatagrams,
            parsedMessageName: parsedMessageName,
            fields: fields,
            bytesTransferred: bytesTransferred
        ),
        runtimeError: String(describing: runtimeError),
        isTimeout: isLoLaTimeoutError(runtimeError)
    )
}

func isLoLaReceiveTimedOutFailure(_ attempt: LoLaControlExchangeAttempt) -> Bool {
    attempt.isTimeout
}

private func isLoLaTimeoutError(_ error: Error) -> Bool {
    if case ExternalConnectorSessionError.receiveTimedOut = error {
        return true
    }
    return false
}
