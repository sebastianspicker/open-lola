import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
// Handles LoLaControlExchangeAttempts control exchange, keeping control-plane details distinct from media data flow.
import Darwin
import Dispatch
import Foundation
import OpenLolaSessionDomain

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
            reusing: try terminalSession.duplicateSocketForRetryResponder(),
            terminalSession: terminalSession
        )
    } catch {
        return lolaControlRetryResponderFailure(configuration: configuration, error: error)
    }
}

private func startLoLaControlRetryResponder(
    configuration: ExternalConnectorSessionConfiguration,
    reusing descriptor: Int32,
    terminalSession: LoLaControlTerminalSession? = nil
) -> LoLaControlRetryResponderReport {
    do {
        try setExternalConnectorReceiveTimeout(socket: descriptor, seconds: 1)
        startLoLaControlRetryResponderLoop(
            descriptor: descriptor,
            configuration: configuration,
            terminalSession: terminalSession
        )
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
    configuration: ExternalConnectorSessionConfiguration,
    terminalSession: LoLaControlTerminalSession?
) {
    DispatchQueue.global(qos: .userInitiated).async {
        defer { close(keepAliveDescriptor) }
        let deadline = MonotonicDeadline(seconds: TimeInterval(max(1, configuration.durationSeconds)))
        while deadline.hasTimeRemaining, !(terminalSession?.cancellation.isCancelled ?? false) {
            do {
                try answerLoLaControlRetryMessageIfAvailable(
                    socket: keepAliveDescriptor,
                    configuration: configuration,
                    terminalSession: terminalSession
                )
            } catch {
                return
            }
        }
    }
}

private func answerLoLaControlRetryMessageIfAvailable(
    socket keepAliveDescriptor: Int32,
    configuration: ExternalConnectorSessionConfiguration,
    terminalSession: LoLaControlTerminalSession?
) throws {
    let received: ExternalConnectorUdpReceiveResult
    let parsed: (name: String, fields: [String: String])
    do {
        guard try waitForReadableSocket(socket: keepAliveDescriptor, timeoutMicroseconds: 50_000) else { return }
        received = try receiveExternalConnectorUdp(socket: keepAliveDescriptor, bufferSize: 4096)
        parsed = try LoLaControlDatagramDecoder.decode(received.payload)
    } catch {
        return
    }
    if lolaRetryResponderHandlePeerDisconnect(
        configuration: configuration,
        message: received.message,
        parsed: parsed,
        senderHost: received.senderHost,
        senderPort: received.senderPort,
        terminalSession: terminalSession
    ) {
        return
    }
    if let terminalSession {
        guard !terminalSession.cancellation.isCancelled,
              received.senderPort == configuration.controlPort,
              lolaIPv4AddressMatches(received.senderHost, expected: terminalSession.destinationIP),
              parsed.fields["SID"] == String(terminalSession.sessionID) else { return }
    }
    if let response = try lolaRetryResponderAck(
        configuration: configuration,
        message: received.message,
        parsed: parsed,
        senderHost: received.senderHost
    ) {
        // A refused ACK must leave the responder alive for the peer's next retry.
        _ = try? sendExternalConnectorUdp(
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
            rawDatagram: received.payload,
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
            parsed: try decodeLoLaReceivedControlDatagram(received),
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

func decodeLoLaReceivedControlDatagram(
    _ received: LoLaReceivedControlMessage
) throws -> (name: String, fields: [String: String]) {
    if let rawDatagram = received.rawDatagram {
        return try LoLaControlDatagramDecoder.decode(rawDatagram)
    }
    return try LoLaCompatibilityControlMessage.parse(received.message)
}

func parseLoLaControlMessage(
    _ received: LoLaReceivedControlMessage,
    sentMessages: [String],
    receivedMessages: inout [String],
    bytesTransferred: inout Int,
    transferredBytes: Int,
    parsedMessageName: String? = nil,
    fields: [String: String] = [:]
) -> LoLaParsedControlMessage {
    receivedMessages.append(received.message)
    bytesTransferred += transferredBytes
    do {
        return LoLaParsedControlMessage(parsed: try decodeLoLaReceivedControlDatagram(received), failure: nil)
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
        runtimeError: lolaControlAttemptRuntimeErrorText(runtimeError),
        isTimeout: isLoLaTimeoutError(runtimeError)
    )
}

/// Report text for a control failure. A peer REJECT is the peer's own
/// decision, so the report carries its reason instead of a Swift enum dump.
func lolaControlAttemptRuntimeErrorText(_ error: Error) -> String {
    if case let ExternalConnectorSessionError.peerRejected(reason) = error {
        return reason.isEmpty
            ? "peer rejected QUICKCONN"
            : "peer rejected QUICKCONN: \(reason)"
    }
    return String(describing: error)
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
