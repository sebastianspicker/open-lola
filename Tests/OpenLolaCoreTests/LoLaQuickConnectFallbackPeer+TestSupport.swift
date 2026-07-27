// Shared LoLa qUIck connect fallback peer helpers keep multi-file test scenarios deterministic.
import Darwin
import Foundation

@testable import OpenLolaCore

final class StubLoLaOutgoingControlTransport: LoLaOutgoingControlTransport {
    var prepareCalls = 0
    var receiveCalls = 0
    var sentMessages: [String] = []

    func prepare(configuration: ExternalConnectorSessionConfiguration) throws {
        prepareCalls += 1
    }

    func send(_ message: String, host: String, port: UInt16) throws -> Int {
        sentMessages.append(message)
        return lolaControlDatagramByteCount
    }

    func receive(
        state: LoLaExchangeState,
        destinationPort: UInt16,
        parsedMessageName: String?,
        fields: [String: String]
    ) -> LoLaReceivedControlMessage {
        receiveCalls += 1
        if receiveCalls == 1 {
            return failureMessage(
                state: state,
                parsedMessageName: parsedMessageName,
                fields: fields,
                error: ExternalConnectorSessionError.receiveTimedOut
            )
        }
        do {
            let parsed = try LoLaCompatibilityControlMessage.parse(state.sentMessages.last ?? "")
            let ack = try quickConnectAck(for: parsed, destinationPort: destinationPort)
            return LoLaReceivedControlMessage(
                message: ack,
                senderHost: "203.0.113.20",
                senderPort: destinationPort,
                bytesTransferred: lolaControlDatagramByteCount
            )
        } catch {
            return failureMessage(
                state: state,
                parsedMessageName: parsedMessageName,
                fields: fields,
                error: error
            )
        }
    }

    private func quickConnectAck(
        for parsed: (name: String, fields: [String: String]),
        destinationPort: UInt16
    ) throws -> String {
        try lolaQuickConnectAck(
            configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .tx,
  peer: parsed.fields["SRCIP"] ?? "203.0.113.10",
  outputPath: "/tmp/lola-quickconnect-fallback-stub.json"
) { input in
  input.localHost = parsed.fields["DSTIP"] ?? "203.0.113.20"
  input.dryRun = false
  input.durationSeconds = 1
  input.controlPort = destinationPort
  input.audioPort = 7001
  input.videoPort = 7002
  input.channels = Int(parsed.fields["CHNLS"] ?? "2") ?? 2
  input.sampleRateHertz = Int(parsed.fields["SR"] ?? "48000") ?? 48_000
  input.sessionID = parsed.fields["SID"] ?? "91"
}),
            receivedFields: parsed.fields,
            senderHost: parsed.fields["DSTIP"] ?? "203.0.113.20"
        )
    }

    private func failureMessage(
        state: LoLaExchangeState,
        parsedMessageName: String?,
        fields: [String: String],
        error: Error
    ) -> LoLaReceivedControlMessage {
        LoLaReceivedControlMessage(
            message: "",
            senderHost: "",
            senderPort: 0,
            bytesTransferred: 0,
            failure: lolaControlAttemptFailure(
                sentMessages: state.sentMessages,
                receivedMessages: state.receivedMessages,
                bytesTransferred: state.bytesTransferred,
                parsedMessageName: parsedMessageName,
                fields: fields,
                runtimeError: error
            )
        )
    }
}

func quickConnectOnlyUdpPeer(port: UInt16, ready: DispatchSemaphore) throws -> [String] {
    let descriptor = try makeLoLaFallbackUdpSocket(host: "127.0.0.1", port: port, timeoutSeconds: 8)
    defer { Darwin.close(descriptor) }
    ready.signal()

    let first = try receiveLoLaFallbackUdpMessage(socket: descriptor)
    let second = try receiveLoLaFallbackUdpMessage(socket: descriptor)
    let parsed = try LoLaCompatibilityControlMessage.parse(second.message)
    let ack = LoLaCompatibilityControlMessage.quickConnectAck(
        loLaQuickConnectMediaFields(fields: parsed.fields, senderHost: second.senderHost)
    )
    try sendLoLaFallbackUdpMessage(ack, socket: descriptor, host: second.senderHost, port: second.senderPort)
    return [first.message, second.message]
}

func quickConnectThenRetryUdpPeer(
    bindHost: String,
    destinationHost: String,
    controlPort: UInt16
) throws -> [(message: String, byteCount: Int)] {
    try withLoLaFallbackUdpSocket(
        host: bindHost,
        port: controlPort,
        timeoutSeconds: 0,
        timeoutMicroseconds: 100_000
    ) { descriptor in
        try quickConnectThenRetryUdpReplies(
            socket: descriptor,
            bindHost: bindHost,
            destinationHost: destinationHost,
            controlPort: controlPort
        )
    }
}

func quickConnectThenRetryUdpReplies(
    socket: Int32,
    bindHost: String,
    destinationHost: String,
    controlPort: UInt16
) throws -> [(message: String, byteCount: Int)] {
    let (status, quickConnect) = quickConnectRetryMessages(
        bindHost: bindHost,
        destinationHost: destinationHost
    )
    let firstStatusAck = try sendLoLaFallbackUdpMessageUntilReply(
        status,
        socket: socket,
        host: destinationHost,
        port: controlPort
    )
    let firstQuickAck = try sendLoLaFallbackUdpMessageUntilReply(
        quickConnect,
        socket: socket,
        host: destinationHost,
        port: controlPort
    )
    let retryStatusAck = try sendLoLaFallbackUdpMessageUntilReply(
        status,
        socket: socket,
        host: destinationHost,
        port: controlPort
    )
    let retryQuickAck = try sendLoLaFallbackUdpMessageUntilReply(
        quickConnect,
        socket: socket,
        host: destinationHost,
        port: controlPort
    )

    return [
        (firstStatusAck.message, firstStatusAck.byteCount),
        (firstQuickAck.message, firstQuickAck.byteCount),
        (retryStatusAck.message, retryStatusAck.byteCount),
        (retryQuickAck.message, retryQuickAck.byteCount)
    ]
}

func quickConnectRetryMessages(
    bindHost: String,
    destinationHost: String
) -> (status: String, quickConnect: String) {
    let status = LoLaCompatibilityControlMessage.checkStatus(
        sourceIP: bindHost,
        destinationIP: destinationHost,
        sessionID: 0
    )
    let quickConnect = LoLaCompatibilityControlMessage.quickConnect(retryMediaFields(
        bindHost: bindHost,
        destinationHost: destinationHost
    ))

    return (status, quickConnect)
}

func retryMediaFields(
    bindHost: String,
    destinationHost: String
) -> LoLaCompatibilityMediaFields {
    LoLaCompatibilityMediaFields(
        session: LoLaControlSessionFields(
            sourceIP: bindHost,
            destinationIP: destinationHost,
            sessionID: 0
        ),
        audio: LoLaCompatibilityAudioFields(
            sampleRateHertz: 44_100,
            bitsPerSample: 16,
            channels: 2
        ),
        video: LoLaCompatibilityVideoFields(
            frameRate: 25,
            bitsPerPixel: 8,
            dimensions: LoLaCompatibilityVideoDimensions(width: 640, height: 480),
            bayer: 1
        )
    )
}

func sendPostConnectCommandsThenStatusRetry(
    sourceHost: String,
    destinationHost: String,
    destinationPort: UInt16
) throws -> (message: String, byteCount: Int) {
    let descriptor = try makeLoLaFallbackUdpSocket(
        host: sourceHost,
        port: destinationPort,
        timeoutSeconds: 0,
        timeoutMicroseconds: 100_000
    )
    defer { Darwin.close(descriptor) }

    try sendLoLaFallbackUdpMessage(
        LoLaCompatibilityControlMessage.sendAudioSignal(
            sourceIP: sourceHost,
            destinationIP: destinationHost,
            sessionID: 0
        ),
        socket: descriptor,
        host: destinationHost,
        port: destinationPort
    )
    try sendLoLaFallbackUdpMessage(
        LoLaCompatibilityControlMessage.chat(
            sourceIP: sourceHost,
            destinationIP: destinationHost,
            sessionID: 0,
            text: "REMOTE: test"
        ),
        socket: descriptor,
        host: destinationHost,
        port: destinationPort
    )
    let retryStatus = LoLaCompatibilityControlMessage.checkStatus(
        sourceIP: sourceHost,
        destinationIP: destinationHost,
        sessionID: 0
    )
    let retryStatusAck = try sendLoLaFallbackUdpMessageUntilReply(
        retryStatus,
        socket: descriptor,
        host: destinationHost,
        port: destinationPort
    )
    return (retryStatusAck.message, retryStatusAck.byteCount)
}

func opaqueControlUdpPeer(port: UInt16, ready: DispatchSemaphore) throws -> String {
    let descriptor = try makeLoLaFallbackUdpSocket(host: "127.0.0.1", port: port, timeoutSeconds: 8)
    defer { Darwin.close(descriptor) }
    ready.signal()

    let first = try receiveLoLaFallbackUdpMessage(socket: descriptor)
    try sendLoLaFallbackUdpBytes(
        [UInt8](repeating: 83, count: 1024),
        socket: descriptor,
        host: first.senderHost,
        port: first.senderPort
    )
    return first.message
}

// swiftlint:disable function_body_length
func repeatedStatusThenQuickConnectUdpPeer(
    bindHost: String,
    destinationHost: String,
    controlPort: UInt16
) throws -> [(message: String, byteCount: Int)] {
    try withLoLaFallbackUdpSocket(
        host: bindHost,
        port: controlPort,
        timeoutSeconds: 0,
        timeoutMicroseconds: 100_000
    ) { descriptor in
        let status = LoLaCompatibilityControlMessage.checkStatus(
            sourceIP: bindHost,
            destinationIP: destinationHost,
            sessionID: 0
        )
        let firstAck = try sendLoLaFallbackUdpMessageUntilReply(
            status,
            socket: descriptor,
            host: destinationHost,
            port: controlPort
        )
        let secondAck = try sendLoLaFallbackUdpMessageUntilReply(
            status,
            socket: descriptor,
            host: destinationHost,
            port: controlPort
        )
        let quickConnect = LoLaCompatibilityControlMessage.quickConnect(retryMediaFields(
            bindHost: bindHost,
            destinationHost: destinationHost
        ))
        let quickConnectAck = try sendLoLaFallbackUdpMessageUntilReply(
            quickConnect,
            socket: descriptor,
            host: destinationHost,
            port: controlPort
        )
        return [
            (firstAck.message, firstAck.byteCount),
            (secondAck.message, secondAck.byteCount),
            (quickConnectAck.message, quickConnectAck.byteCount)
        ]
    }
}

// swiftlint:enable function_body_length
