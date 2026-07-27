// Handles LoLaControlExchangeAttempts control exchange, keeping control-plane details distinct from media data flow.
import Darwin
import Dispatch
import Foundation

func startLoLaControlRetryResponder(
    configuration: ExternalConnectorSessionConfiguration
) -> LoLaControlRetryResponderReport {
    do {
        let keepAliveDescriptor = try prepareLoLaControlRetryResponderSocket(configuration: configuration)
        startLoLaControlRetryResponderLoop(descriptor: keepAliveDescriptor, configuration: configuration)
        return LoLaControlRetryResponderReport(
            started: true,
            localHost: configuration.localHost,
            controlPort: configuration.controlPort,
            timeoutSeconds: configuration.durationSeconds
        )
    } catch {
        return LoLaControlRetryResponderReport(
            started: false,
            localHost: configuration.localHost,
            controlPort: configuration.controlPort,
            timeoutSeconds: configuration.durationSeconds,
            runtimeError: String(describing: error)
        )
    }
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
            answerLoLaControlRetryMessageIfAvailable(
                socket: keepAliveDescriptor,
                configuration: configuration
            )
        }
    }
}

private func answerLoLaControlRetryMessageIfAvailable(
    socket keepAliveDescriptor: Int32,
    configuration: ExternalConnectorSessionConfiguration
) {
    do {
        let received = try receiveExternalConnectorUdp(socket: keepAliveDescriptor, bufferSize: 4096)
        let parsed = try LoLaCompatibilityControlMessage.parse(received.message)
        if let ack = try lolaRetryResponderAck(
            configuration: configuration,
            message: received.message,
            parsed: parsed,
            senderHost: received.senderHost
        ) {
            _ = try sendExternalConnectorUdp(
                ack,
                socket: keepAliveDescriptor,
                host: received.senderHost,
                port: configuration.controlPort
            )
        }
    } catch {
        return
    }
}

func receiveLoLaControlMessage(
    socket: Int32,
    sentMessages: [String],
    receivedMessages: [String],
    bytesTransferred: Int,
    destinationPort: UInt16,
    parsedMessageName: String? = nil,
    fields: [String: String] = [:]
) -> LoLaReceivedControlMessage {
    do {
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
