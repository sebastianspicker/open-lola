import Darwin
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func lolaControlParserPreservesUnescapedTextSemicolons() throws {
    let parsed = try LoLaCompatibilityControlMessage.parse(
        "/MESG_CHAT;SRCIP:192.0.2.10;DSTIP:192.0.2.20;SID:4;TXT:hello;truncated-tail"
    )

    #expect(parsed.name == "/MESG_CHAT")
    #expect(parsed.fields["TXT"] == "hello;truncated-tail")
    #expect(parsed.fields["SID"] == "4")
}

@Test
func lolaControlParserDoesNotCarryDeadTruncatedTextFlag() throws {
    let source = try readLoLaQuickConnectSource(
        "Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityControlMessage.swift"
    )

    #expect(source.contains("fields[key] = ([String(pair[1])] + parts[(index + 1)...]).joined(separator: \";\")"))
    #expect(!source.contains("acceptsTruncatedText"))
}

@Test
func lolaControlDatagramsAreAlwaysExactly1024BytesWithLongTextTruncation() throws {
    let message = LoLaCompatibilityControlMessage.chat(
        sourceIP: "192.0.2.10",
        destinationIP: "192.0.2.20",
        sessionID: 4,
        text: String(repeating: "x", count: 2_000)
    )

    let bytes = lolaControlDatagramBytes(message)
    let decoded = String(decoding: bytes, as: UTF8.self)
    let parsed = try LoLaCompatibilityControlMessage.parse(decoded)

    #expect(bytes.count == 1_024)
    #expect(parsed.name == "/MESG_CHAT")
    #expect(parsed.fields["TXT"]?.hasPrefix("x") == true)
}

@Test
func lolaUdpTransmitFallsBackToQuickConnectWhenStatusAckTimesOut() async throws {
    guard secondaryLoopbackAliasAvailable() else { return }
    try await SocketHeavyTestGate.shared.run {
        let controlPort = try freeLoLaFallbackUdpPort()
        let configuration = ExternalConnectorSessionConfiguration(
            connector: .lola,
            role: .tx,
            peer: "127.0.0.2",
            localHost: "127.0.0.1",
            outputPath: "/tmp/lola-quickconnect-fallback.json",
            dryRun: false,
            durationSeconds: 3,
            controlPort: controlPort,
            audioPort: try freeLoLaFallbackUdpPort(),
            videoPort: try freeLoLaFallbackUdpPort(),
            sessionID: "91"
        )

        let peerReady = DispatchSemaphore(value: 0)
        async let peer = quickConnectOnlyUdpPeer(port: controlPort, ready: peerReady)
        try waitForLoLaFallbackUdpPeerReady(peerReady)
        let attempt = try runLoLaControlExchangeAttempt(configuration: configuration)
        let peerMessages = try await peer

        #expect(attempt.runtimeError == nil)
        #expect(attempt.exchange.parsedMessageName == "/MESG_QUICKCONN_ACK")
        #expect(attempt.exchange.sentMessages.count == 2)
        #expect(attempt.exchange.receivedMessages.count == 1)
        #expect(attempt.exchange.sentMessages[0].hasPrefix("/MESG_CHECKLOLASTATUS"))
        #expect(attempt.exchange.sentMessages[1].hasPrefix("/MESG_QUICKCONN"))
        #expect(peerMessages[0].hasPrefix("/MESG_CHECKLOLASTATUS"))
        #expect(peerMessages[1].hasPrefix("/MESG_QUICKCONN"))
    }
}

@Test
func lolaUdpControlAttemptRecordsOpaqueControlDatagrams() async throws {
    try await SocketHeavyTestGate.shared.run {
        let controlPort = try freeLoLaFallbackUdpPort()
        let configuration = ExternalConnectorSessionConfiguration(
            connector: .lola,
            role: .tx,
            peer: "127.0.0.1",
            localHost: "127.0.0.1",
            outputPath: "/tmp/lola-opaque-control.json",
            dryRun: false,
            durationSeconds: 3,
            controlPort: controlPort,
            audioPort: try freeLoLaFallbackUdpPort(),
            videoPort: try freeLoLaFallbackUdpPort(),
            sessionID: "92"
        )

        let peerReady = DispatchSemaphore(value: 0)
        async let peer = opaqueControlUdpPeer(port: controlPort, ready: peerReady)
        try waitForLoLaFallbackUdpPeerReady(peerReady)
        let attempt = try runLoLaControlExchangeAttempt(configuration: configuration)
        _ = try await peer

        #expect(attempt.runtimeError?.contains("malformedLoLaControlMessage") == true)
        #expect(attempt.exchange.opaqueControlDatagrams.count == 1)
        let opaque = try #require(attempt.exchange.opaqueControlDatagrams.first)
        #expect(opaque.classification == "opaque-control-datagram")
        #expect(opaque.destinationPort == controlPort)
        #expect(opaque.payloadLength == 1024)
        #expect(opaque.firstByte == 83)
        #expect(opaque.hexPrefix.hasPrefix("53535353"))
    }
}

@Test
func lolaUdpReceiveAcksRepeatedStatusChecksBeforeQuickConnect() async throws {
    guard secondaryLoopbackAliasAvailable() else { return }
    try await SocketHeavyTestGate.shared.run {
        let controlPort = try freeLoLaFallbackUdpPort()
        let configuration = ExternalConnectorSessionConfiguration(
            connector: .lola,
            role: .rx,
            peer: "127.0.0.1",
            localHost: "127.0.0.1",
            outputPath: "/tmp/lola-repeated-status-rx.json",
            dryRun: false,
            durationSeconds: 8,
            controlPort: controlPort,
            audioPort: try freeLoLaFallbackUdpPort(),
            videoPort: try freeLoLaFallbackUdpPort(),
            sessionID: "0"
        )

        async let receiver = runLoLaControlExchangeAttempt(configuration: configuration)
        let peerMessages = try repeatedStatusThenQuickConnectUdpPeer(
            bindHost: "127.0.0.2",
            destinationHost: "127.0.0.1",
            controlPort: controlPort
        )
        let attempt = try await receiver

        #expect(attempt.runtimeError == nil)
        #expect(attempt.exchange.parsedMessageName == "/MESG_QUICKCONN")
        #expect(attempt.exchange.receivedMessages.count == 3)
        #expect(attempt.exchange.sentMessages.count == 3)
        #expect(attempt.exchange.sentMessages[0].hasPrefix("/MESG_CHECKLOLASTATUS_ACK"))
        #expect(attempt.exchange.sentMessages[1].hasPrefix("/MESG_CHECKLOLASTATUS_ACK"))
        #expect(attempt.exchange.sentMessages[2].hasPrefix("/MESG_QUICKCONN_ACK"))
        #expect(peerMessages[0].message.hasPrefix("/MESG_CHECKLOLASTATUS_ACK"))
        #expect(peerMessages[1].message.hasPrefix("/MESG_CHECKLOLASTATUS_ACK"))
        #expect(peerMessages[2].message.hasPrefix("/MESG_QUICKCONN_ACK"))
        #expect(peerMessages.map(\.byteCount) == [1024, 1024, 1024])
    }
}

@Test
func lolaUdpReceiveKeepsControlSocketAliveForPostConnectRetries() async throws {
    guard secondaryLoopbackAliasAvailable() else { return }
    try await SocketHeavyTestGate.shared.run {
        let controlPort = try freeLoLaFallbackUdpPort()
        let configuration = ExternalConnectorSessionConfiguration(
            connector: .lola,
            role: .rx,
            peer: "127.0.0.2",
            localHost: "127.0.0.1",
            outputPath: "/tmp/lola-control-keepalive-rx.json",
            dryRun: false,
            durationSeconds: 3,
            controlPort: controlPort,
            audioPort: try freeLoLaFallbackUdpPort(),
            videoPort: try freeLoLaFallbackUdpPort(),
            sessionID: "0"
        )

        async let receiver = ExternalConnectorSessionRunner.run(configuration: configuration)
        let peerMessages = try quickConnectThenRetryUdpPeer(
            bindHost: "127.0.0.2",
            destinationHost: "127.0.0.1",
            controlPort: controlPort
        )
        let report = try await receiver

        #expect(report.runtimeError == nil)
        #expect(report.lolaControl?.parsedMessageName == "/MESG_QUICKCONN")
        #expect(peerMessages.map(\.byteCount) == [1024, 1024, 1024, 1024])
        #expect(peerMessages[2].message.hasPrefix("/MESG_CHECKLOLASTATUS_ACK"))
        #expect(peerMessages[3].message.hasPrefix("/MESG_QUICKCONN_ACK"))
    }
}

@Test
func lolaUdpTxRxKeepsControlSocketAliveForPostConnectCommands() async throws {
    guard secondaryLoopbackAliasAvailable() else { return }
    try await SocketHeavyTestGate.shared.run {
        let controlPort = try freeLoLaFallbackUdpPort()
        let configuration = ExternalConnectorSessionConfiguration(
            connector: .lola,
            role: .txRx,
            peer: "127.0.0.2",
            localHost: "127.0.0.1",
            outputPath: "/tmp/lola-control-keepalive-tx-rx.json",
            dryRun: false,
            durationSeconds: 3,
            controlPort: controlPort,
            audioPort: try freeLoLaFallbackUdpPort(),
            videoPort: try freeLoLaFallbackUdpPort(),
            sessionID: "0"
        )

        #expect(shouldStartLoLaControlRetryResponder(configuration: configuration))

        let responder = startLoLaControlRetryResponder(configuration: configuration)
        try responder.validate()
        #expect(responder.started)
        #expect(responder.runtimeError == nil)
        let retryStatusAck = try sendPostConnectCommandsThenStatusRetry(
            sourceHost: "127.0.0.2",
            destinationHost: "127.0.0.1",
            destinationPort: controlPort
        )

        #expect(retryStatusAck.byteCount == 1024)
        #expect(retryStatusAck.message.hasPrefix("/MESG_CHECKLOLASTATUS_ACK"))
    }
}

@Test
func lolaControlRetryResponderRepliesToPeerControlPort() async throws {
    guard secondaryLoopbackAliasAvailable() else { return }
    try await SocketHeavyTestGate.shared.run {
        let controlPort = try freeLoLaFallbackUdpPort()
        let receiver = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard receiver >= 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        defer { Darwin.close(receiver) }
        try bindLoLaFallbackUdpSocket(receiver, host: "127.0.0.2", port: controlPort)
        try setLoLaFallbackUdpTimeout(receiver, seconds: 2)

        let responder = startLoLaControlRetryResponder(configuration: ExternalConnectorSessionConfiguration(
            connector: .lola,
            role: .txRx,
            peer: "127.0.0.2",
            localHost: "127.0.0.1",
            outputPath: "/tmp/lola-control-keepalive-peer-port.json",
            dryRun: false,
            durationSeconds: 2,
            controlPort: controlPort,
            audioPort: try freeLoLaFallbackUdpPort(),
            videoPort: try freeLoLaFallbackUdpPort(),
            sessionID: "0"
        ))
        try responder.validate()
        #expect(responder.started)

        let sender = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard sender >= 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        defer { Darwin.close(sender) }
        try bindLoLaFallbackUdpSocket(sender, host: "127.0.0.2", port: 0)
        try sendLoLaFallbackUdpMessage(
            LoLaCompatibilityControlMessage.checkStatus(
                sourceIP: "127.0.0.2",
                destinationIP: "127.0.0.1",
                sessionID: 0
            ),
            socket: sender,
            host: "127.0.0.1",
            port: controlPort
        )

        let retryStatusAck = try receiveLoLaFallbackUdpMessage(socket: receiver)
        #expect(retryStatusAck.byteCount == 1024)
        #expect(retryStatusAck.senderPort == controlPort)
        #expect(retryStatusAck.message.hasPrefix("/MESG_CHECKLOLASTATUS_ACK"))
    }
}

@Test
func lolaUdpControlRetryResponderReportsBindFailure() throws {
    let controlPort = try freeLoLaFallbackUdpPort()
    let occupied = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
    guard occupied >= 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    defer { Darwin.close(occupied) }
    try bindLoLaFallbackUdpSocket(occupied, host: "127.0.0.1", port: controlPort)

    let report = startLoLaControlRetryResponder(configuration: ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .rx,
        peer: "127.0.0.2",
        localHost: "127.0.0.1",
        outputPath: "/tmp/lola-control-keepalive-bind-fail.json",
        dryRun: false,
        durationSeconds: 1,
        controlPort: controlPort,
        audioPort: try freeLoLaFallbackUdpPort(),
        videoPort: try freeLoLaFallbackUdpPort(),
        sessionID: "0"
    ))

    #expect(!report.started)
    #expect(report.runtimeError?.contains("bind 127.0.0.1:\(controlPort)") == true)
    try report.validate()
}

private func quickConnectOnlyUdpPeer(port: UInt16, ready: DispatchSemaphore) throws -> [String] {
    let descriptor = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
    guard descriptor >= 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    defer { Darwin.close(descriptor) }
    try bindLoLaFallbackUdpSocket(descriptor, host: "127.0.0.1", port: port)
    try setLoLaFallbackUdpTimeout(descriptor, seconds: 8)
    ready.signal()

    let first = try receiveLoLaFallbackUdpMessage(socket: descriptor)
    let second = try receiveLoLaFallbackUdpMessage(socket: descriptor)
    let parsed = try LoLaCompatibilityControlMessage.parse(second.message)
    let ack = LoLaCompatibilityControlMessage.quickConnectAck(
        sourceIP: parsed.fields["DSTIP"] ?? "127.0.0.1",
        destinationIP: parsed.fields["SRCIP"] ?? second.senderHost,
        sessionID: Int(parsed.fields["SID"] ?? "0") ?? 0,
        sampleRateHertz: Int(parsed.fields["SR"] ?? "44100") ?? 44_100,
        bitsPerSample: Int(parsed.fields["BPS"] ?? "16") ?? 16,
        channels: Int(parsed.fields["CHNLS"] ?? "2") ?? 2,
        videoFrameRate: Int(parsed.fields["FPS"] ?? "0") ?? 0,
        videoBitsPerPixel: Int(parsed.fields["BPP"] ?? "0") ?? 0,
        videoWidth: Int(parsed.fields["X"] ?? "0") ?? 0,
        videoHeight: Int(parsed.fields["Y"] ?? "0") ?? 0,
        videoCompression: Int(parsed.fields["COMP"] ?? "0") ?? 0,
        videoBayer: Int(parsed.fields["BAYER"] ?? "0") ?? 0
    )
    try sendLoLaFallbackUdpMessage(ack, socket: descriptor, host: second.senderHost, port: second.senderPort)
    return [first.message, second.message]
}

private func quickConnectThenRetryUdpPeer(
    bindHost: String,
    destinationHost: String,
    controlPort: UInt16
) throws -> [(message: String, byteCount: Int)] {
    let descriptor = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
    guard descriptor >= 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    defer { Darwin.close(descriptor) }
    try bindLoLaFallbackUdpSocket(descriptor, host: bindHost, port: controlPort)
    try setLoLaFallbackUdpTimeout(descriptor, seconds: 0, microseconds: 100_000)

    let status = LoLaCompatibilityControlMessage.checkStatus(
        sourceIP: bindHost,
        destinationIP: destinationHost,
        sessionID: 0
    )
    let quickConnect = LoLaCompatibilityControlMessage.quickConnect(
        sourceIP: bindHost,
        destinationIP: destinationHost,
        sessionID: 0,
        sampleRateHertz: 44_100,
        bitsPerSample: 16,
        channels: 2,
        videoFrameRate: 25,
        videoBitsPerPixel: 8,
        videoWidth: 640,
        videoHeight: 480,
        videoBayer: 1
    )

    let firstStatusAck = try sendLoLaFallbackUdpMessageUntilReply(
        status,
        socket: descriptor,
        host: destinationHost,
        port: controlPort
    )
    let firstQuickAck = try sendLoLaFallbackUdpMessageUntilReply(
        quickConnect,
        socket: descriptor,
        host: destinationHost,
        port: controlPort
    )
    let retryStatusAck = try sendLoLaFallbackUdpMessageUntilReply(
        status,
        socket: descriptor,
        host: destinationHost,
        port: controlPort
    )
    let retryQuickAck = try sendLoLaFallbackUdpMessageUntilReply(
        quickConnect,
        socket: descriptor,
        host: destinationHost,
        port: controlPort
    )

    return [
        (firstStatusAck.message, firstStatusAck.byteCount),
        (firstQuickAck.message, firstQuickAck.byteCount),
        (retryStatusAck.message, retryStatusAck.byteCount),
        (retryQuickAck.message, retryQuickAck.byteCount),
    ]
}

private func sendPostConnectCommandsThenStatusRetry(
    sourceHost: String,
    destinationHost: String,
    destinationPort: UInt16
) throws -> (message: String, byteCount: Int) {
    let descriptor = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
    guard descriptor >= 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    defer { Darwin.close(descriptor) }
    try bindLoLaFallbackUdpSocket(descriptor, host: sourceHost, port: destinationPort)
    try setLoLaFallbackUdpTimeout(descriptor, seconds: 0, microseconds: 100_000)

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

private func opaqueControlUdpPeer(port: UInt16, ready: DispatchSemaphore) throws -> String {
    let descriptor = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
    guard descriptor >= 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    defer { Darwin.close(descriptor) }
    try bindLoLaFallbackUdpSocket(descriptor, host: "127.0.0.1", port: port)
    try setLoLaFallbackUdpTimeout(descriptor, seconds: 8)
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

private func repeatedStatusThenQuickConnectUdpPeer(
    bindHost: String,
    destinationHost: String,
    controlPort: UInt16
) throws -> [(message: String, byteCount: Int)] {
    let descriptor = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
    guard descriptor >= 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    defer { Darwin.close(descriptor) }
    try bindLoLaFallbackUdpSocket(descriptor, host: bindHost, port: controlPort)
    try setLoLaFallbackUdpTimeout(descriptor, seconds: 0, microseconds: 100_000)

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

    let quickConnect = LoLaCompatibilityControlMessage.quickConnect(
        sourceIP: bindHost,
        destinationIP: destinationHost,
        sessionID: 0,
        sampleRateHertz: 44_100,
        bitsPerSample: 16,
        channels: 2,
        videoFrameRate: 25,
        videoBitsPerPixel: 8,
        videoWidth: 640,
        videoHeight: 480,
        videoBayer: 1
    )
    let quickConnectAck = try sendLoLaFallbackUdpMessageUntilReply(
        quickConnect,
        socket: descriptor,
        host: destinationHost,
        port: controlPort
    )

    return [
        (firstAck.message, firstAck.byteCount),
        (secondAck.message, secondAck.byteCount),
        (quickConnectAck.message, quickConnectAck.byteCount),
    ]
}

private func freeLoLaFallbackUdpPort() throws -> UInt16 {
    let descriptor = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
    guard descriptor >= 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    defer { Darwin.close(descriptor) }
    try bindLoLaFallbackUdpSocket(descriptor, host: "127.0.0.1", port: 0)
    var bound = sockaddr_in()
    var length = socklen_t(MemoryLayout<sockaddr_in>.size)
    let nameResult = withUnsafeMutablePointer(to: &bound) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            Darwin.getsockname(descriptor, socketAddress, &length)
        }
    }
    guard nameResult == 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    return UInt16(bigEndian: bound.sin_port)
}

private func secondaryLoopbackAliasAvailable() -> Bool {
    let descriptor = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
    guard descriptor >= 0 else {
        return false
    }
    defer { Darwin.close(descriptor) }
    return (try? bindLoLaFallbackUdpSocket(descriptor, host: "127.0.0.2", port: 0)) != nil
}

private func bindLoLaFallbackUdpSocket(_ socket: Int32, host: String, port: UInt16) throws {
    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = port.bigEndian
    guard inet_pton(AF_INET, host, &address.sin_addr) == 1 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    let result = withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            Darwin.bind(socket, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    guard result == 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
}

private func receiveLoLaFallbackUdpMessage(
    socket: Int32
) throws -> (message: String, senderHost: String, senderPort: UInt16, byteCount: Int) {
    var buffer = [UInt8](repeating: 0, count: 4096)
    var sender = sockaddr_in()
    var senderLength = socklen_t(MemoryLayout<sockaddr_in>.size)
    let received = withUnsafeMutablePointer(to: &sender) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            Darwin.recvfrom(socket, &buffer, buffer.count, 0, socketAddress, &senderLength)
        }
    }
    guard received > 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    return (
        String(decoding: buffer[0..<received], as: UTF8.self),
        try loLaFallbackHostString(sender.sin_addr),
        UInt16(bigEndian: sender.sin_port),
        received
    )
}

private func sendLoLaFallbackUdpMessage(_ message: String, socket: Int32, host: String, port: UInt16) throws {
    try sendLoLaFallbackUdpBytes([UInt8](message.utf8), socket: socket, host: host, port: port)
}

private func sendLoLaFallbackUdpMessageUntilReply(
    _ message: String,
    socket: Int32,
    host: String,
    port: UInt16,
    deadline: DispatchTime = .now() + .seconds(3)
) throws -> (message: String, senderHost: String, senderPort: UInt16, byteCount: Int) {
    var lastTransientError: Error?
    while DispatchTime.now() < deadline {
        try sendLoLaFallbackUdpMessage(message, socket: socket, host: host, port: port)
        do {
            return try receiveLoLaFallbackUdpMessage(socket: socket)
        } catch {
            guard isTransientLoLaFallbackUdpReceiveError(error) else {
                throw error
            }
            lastTransientError = error
        }
    }
    if let lastTransientError {
        throw lastTransientError
    }
    throw NSError(domain: NSPOSIXErrorDomain, code: Int(ETIMEDOUT))
}

private func sendLoLaFallbackUdpBytes(_ bytes: [UInt8], socket: Int32, host: String, port: UInt16) throws {
    var destination = sockaddr_in()
    destination.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    destination.sin_family = sa_family_t(AF_INET)
    destination.sin_port = port.bigEndian
    guard inet_pton(AF_INET, host, &destination.sin_addr) == 1 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    let sent = try bytes.withUnsafeBytes { rawBuffer in
        try withUnsafePointer(to: &destination) { pointer in
            try pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                let result = retryLoLaFallbackUdpSend {
                    Darwin.sendto(
                        socket,
                        rawBuffer.baseAddress,
                        rawBuffer.count,
                        0,
                        socketAddress,
                        socklen_t(MemoryLayout<sockaddr_in>.size)
                    )
                }
                guard result == rawBuffer.count else {
                    throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
                }
                return result
            }
        }
    }
    _ = sent
}

private func retryLoLaFallbackUdpSend(_ send: () -> Int) -> Int {
    var lastErrno: Int32 = 0
    for attempt in 0..<6 {
        let result = send()
        if result >= 0 {
            return result
        }
        lastErrno = errno
        guard lastErrno == EAGAIN || lastErrno == EWOULDBLOCK, attempt < 5 else {
            errno = lastErrno
            return result
        }
        usleep(5_000)
    }
    errno = lastErrno
    return -1
}
private func setLoLaFallbackUdpTimeout(_ socket: Int32, seconds: Int, microseconds: Int32 = 0) throws {
    var timeout = timeval(tv_sec: seconds, tv_usec: microseconds)
    let status = setsockopt(socket, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
    guard status == 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
}

private func isTransientLoLaFallbackUdpReceiveError(_ error: Error) -> Bool {
    let nsError = error as NSError
    guard nsError.domain == NSPOSIXErrorDomain else {
        return false
    }
    return nsError.code == Int(EAGAIN)
        || nsError.code == Int(EWOULDBLOCK)
        || nsError.code == Int(ETIMEDOUT)
}

private func waitForLoLaFallbackUdpPeerReady(_ ready: DispatchSemaphore) throws {
    guard ready.wait(timeout: .now() + 3) == .success else {
        Issue.record("LoLa fallback UDP peer did not bind before the control attempt started")
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(ETIMEDOUT))
    }
}

private func loLaFallbackHostString(_ address: in_addr) throws -> String {
    var address = address
    var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
    guard inet_ntop(AF_INET, &address, &buffer, socklen_t(buffer.count)) != nil else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    let endIndex = buffer.firstIndex(of: 0) ?? buffer.endIndex
    return String(decoding: buffer[..<endIndex].map(UInt8.init), as: UTF8.self)
}

private func readLoLaQuickConnectSource(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
