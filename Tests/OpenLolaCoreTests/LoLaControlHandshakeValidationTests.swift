import Darwin
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func lolaUdpTransmitRejectsQuickConnectAckWithWrongSession() async throws {
    try await SocketHeavyTestGate.shared.run {
        let controlPort = try freeLoLaHandshakeUdpPort()
        let configuration = ExternalConnectorSessionConfiguration(
            connector: .lola,
            role: .tx,
            peer: "127.0.0.1",
            localHost: "127.0.0.1",
            outputPath: "/tmp/lola-wrong-sid-ack.json",
            dryRun: false,
            durationSeconds: 3,
            controlPort: controlPort,
            sessionID: "42"
        )

        let peerReady = DispatchSemaphore(value: 0)
        async let peer = wrongSessionQuickAckUdpPeer(port: controlPort, ready: peerReady)
        try waitForLoLaHandshakePeerReady(peerReady)
        let attempt = try runLoLaControlExchangeAttempt(configuration: configuration)
        _ = try await peer

        #expect(attempt.runtimeError?.contains("malformedLoLaControlMessage") == true)
        #expect(attempt.exchange.parsedMessageName == "/MESG_QUICKCONN_ACK")
        #expect(attempt.exchange.fields["SID"] == "43")
    }
}

@Test
func lolaUdpReceiveRejectsNonHandshakeMessageAsConnectionSuccess() async throws {
    try await SocketHeavyTestGate.shared.run {
        let controlPort = try freeLoLaHandshakeUdpPort()
        let configuration = ExternalConnectorSessionConfiguration(
            connector: .lola,
            role: .rx,
            peer: "127.0.0.1",
            localHost: "127.0.0.1",
            outputPath: "/tmp/lola-chat-not-connect.json",
            dryRun: false,
            durationSeconds: 3,
            controlPort: controlPort,
            sessionID: "42"
        )

        let receiver = Task {
            try runLoLaControlExchangeAttempt(configuration: configuration)
        }
        let attempt = try await sendLoLaHandshakeUdpMessageUntilAttemptCompletes(
            LoLaCompatibilityControlMessage.chat(
                sourceIP: "127.0.0.1",
                destinationIP: "127.0.0.1",
                sessionID: 42,
                text: "not a handshake"
            ),
            receiver: receiver,
            host: "127.0.0.1",
            port: controlPort
        )

        #expect(attempt.runtimeError?.contains("malformedLoLaControlMessage") == true)
        #expect(attempt.exchange.parsedMessageName == "/MESG_CHAT")
    }
}

@Test
func lolaTcpTransmitRejectsQuickConnectAckWithWrongSession() async throws {
    let controlPort = try freeLoLaHandshakeTcpPort()
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .tx,
        peer: "127.0.0.1",
        localHost: "127.0.0.1",
        outputPath: "/tmp/lola-tcp-wrong-sid-ack.json",
        dryRun: false,
        controlTransport: .tcp,
        durationSeconds: 3,
        controlPort: controlPort,
        sessionID: "42"
    )

    let peerReady = DispatchSemaphore(value: 0)
    async let peer = wrongSessionQuickAckTcpPeer(port: controlPort, ready: peerReady)
    try waitForLoLaHandshakePeerReady(peerReady)
    let attempt = try runLoLaControlExchangeAttempt(configuration: configuration)
    _ = try await peer

    #expect(attempt.runtimeError?.contains("malformedLoLaControlMessage") == true)
    #expect(attempt.exchange.parsedMessageName == "/MESG_QUICKCONN_ACK")
    #expect(attempt.exchange.fields["SID"] == "43")
}

@Test
func lolaTcpReceiveRejectsNonHandshakeMessageAsConnectionSuccess() async throws {
    let controlPort = try freeLoLaHandshakeTcpPort()
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .rx,
        peer: "127.0.0.1",
        localHost: "127.0.0.1",
        outputPath: "/tmp/lola-tcp-chat-not-connect.json",
        dryRun: false,
        controlTransport: .tcp,
        durationSeconds: 3,
        controlPort: controlPort,
        sessionID: "42"
    )

    async let receiver = runLoLaControlExchangeAttempt(configuration: configuration)
    try await sendLoLaHandshakeTcpMessageWhenReady(
        LoLaCompatibilityControlMessage.chat(
            sourceIP: "127.0.0.1",
            destinationIP: "127.0.0.1",
            sessionID: 42,
            text: "not a handshake"
        ),
        host: "127.0.0.1",
        port: controlPort
    )
    let attempt = try await receiver

    #expect(attempt.runtimeError?.contains("malformedLoLaControlMessage") == true)
    #expect(attempt.exchange.parsedMessageName == "/MESG_CHAT")
}

@Test
func lolaRetryResponderDoesNotAckMalformedStatusRetry() throws {
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .txRx,
        peer: "127.0.0.1",
        localHost: "127.0.0.1",
        outputPath: "/tmp/lola-malformed-retry.json",
        dryRun: false,
        sessionID: "42"
    )
    let message = "/MESG_CHECKLOLASTATUS;SRCIP:127.0.0.1;DSTIP:127.0.0.1;"
    let parsed = try LoLaCompatibilityControlMessage.parse(message)

    #expect(try lolaRetryResponderAck(
        configuration: configuration,
        message: message,
        parsed: parsed,
        senderHost: "127.0.0.1"
    ) == nil)
}

@Test
func lolaReceivedControlParserAccumulatesTransferredBytes() throws {
    let message = LoLaCompatibilityControlMessage.quickConnect(
        sourceIP: "192.0.2.10",
        destinationIP: "192.0.2.20",
        sessionID: 7,
        sampleRateHertz: 44_100,
        bitsPerSample: 16,
        channels: 2
    )
    let received = LoLaReceivedControlMessage(
        message: message,
        senderHost: "192.0.2.10",
        senderPort: 7_000,
        bytesTransferred: 1_024,
        opaqueDatagram: nil,
        failure: nil
    )
    var receivedMessages: [String] = []
    var bytesTransferred = 512
    var opaqueControlDatagrams: [LoLaOpaqueControlDatagram] = []

    let parsed = parseReceivedLoLaControlMessage(
        received,
        sentMessages: [],
        receivedMessages: &receivedMessages,
        bytesTransferred: &bytesTransferred,
        opaqueControlDatagrams: &opaqueControlDatagrams
    )

    #expect(parsed.failure == nil)
    #expect(parsed.parsed.name == "/MESG_QUICKCONN")
    #expect(receivedMessages == [message])
    #expect(bytesTransferred == 1_536)
    #expect(opaqueControlDatagrams.isEmpty)
}

@Test
func lolaTxRxAcceptsPeerSpecificVideoProfileInQuickConnectAck() throws {
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .txRx,
        peer: "192.168.178.47",
        localHost: "192.168.178.46",
        outputPath: "/tmp/lola-txrx-video-profile.json",
        mediaMode: .video,
        videoWidth: 1_280,
        videoHeight: 720,
        videoFrameRate: 25,
        videoBitsPerPixel: 8,
        sessionID: "0"
    )
    let message = "/MESG_QUICKCONN_ACK;SRCIP:192.168.178.47;DSTIP:192.168.178.46;SID:0;SR:44100;BPS:16;CHNLS:2;FPS:25;BPP:8;X:640;Y:480;COMP:0;BAYER:1"
    let parsed = try LoLaCompatibilityControlMessage.parse(message)

    let failure = try lolaOutgoingHandshakeFailure(
        sentMessages: [],
        receivedMessages: [message],
        bytesTransferred: message.utf8.count,
        parsedMessageName: parsed.name,
        fields: parsed.fields,
        message: message,
        expectedName: "/MESG_QUICKCONN_ACK",
        expectedFields: lolaExpectedQuickConnectFields(
            configuration: configuration,
            sourceIP: "192.168.178.46"
        )
    )

    #expect(failure == nil)
}

@Test
func lolaHandshakeValidationNormalizesIPv4Fields() throws {
    let message = "/MESG_CHECKLOLASTATUS_ACK;SRCIP:192.0.2.10:7000;DSTIP: 192.0.2.20 ;SID:7"
    let parsed = try LoLaCompatibilityControlMessage.parse(message)

    let outgoingFailure = lolaOutgoingHandshakeFailure(
        sentMessages: [],
        receivedMessages: [message],
        bytesTransferred: message.utf8.count,
        parsedMessageName: parsed.name,
        fields: parsed.fields,
        message: message,
        expectedName: "/MESG_CHECKLOLASTATUS_ACK",
        expectedFields: [
            "SRCIP": "192.0.2.10",
            "DSTIP": "192.0.2.20",
            "SID": "7",
        ]
    )
    let incomingFailure = lolaIncomingHandshakeFailure(
        sentMessages: [],
        receivedMessages: [message],
        bytesTransferred: message.utf8.count,
        parsedMessageName: "/MESG_CHECKLOLASTATUS",
        fields: [
            "SRCIP": "192.0.2.10:7000",
            "DSTIP": " 192.0.2.20 ",
            "SID": "7",
        ],
        message: message,
        expectedName: "/MESG_CHECKLOLASTATUS",
        localHost: "192.0.2.20",
        requiresMediaFields: false
    )

    #expect(outgoingFailure == nil)
    #expect(incomingFailure == nil)
}

@Test
func lolaSockaddrIPv4GuardRejectsShortSockaddrBeforeFamilyUse() {
    var short = sockaddr()
    short.sa_len = UInt8(MemoryLayout<sockaddr>.size - 1)
    short.sa_family = UInt8(AF_INET)

    var ipv4 = sockaddr_in()
    ipv4.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    ipv4.sin_family = sa_family_t(AF_INET)

    withUnsafePointer(to: &short) { pointer in
        #expect(!lolaSockaddrCarriesIPv4(pointer))
    }
    withUnsafePointer(to: &ipv4) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            #expect(lolaSockaddrCarriesIPv4($0))
        }
    }
}

private func wrongSessionQuickAckUdpPeer(port: UInt16, ready: DispatchSemaphore) throws -> [String] {
    let descriptor = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
    guard descriptor >= 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    defer { Darwin.close(descriptor) }
    try bindLoLaHandshakeUdpSocket(descriptor, host: "127.0.0.1", port: port)
    try setLoLaHandshakeUdpTimeout(descriptor, seconds: 6)
    ready.signal()

    let status = try receiveLoLaHandshakeUdpMessage(socket: descriptor)
    let statusFields = try LoLaCompatibilityControlMessage.parse(status.message).fields
    let statusAck = LoLaCompatibilityControlMessage.checkStatusAck(
        sourceIP: statusFields["DSTIP"] ?? "127.0.0.1",
        destinationIP: statusFields["SRCIP"] ?? status.senderHost,
        sessionID: Int(statusFields["SID"] ?? "0") ?? 0
    )
    try sendLoLaHandshakeUdpMessage(statusAck, socket: descriptor, host: status.senderHost, port: status.senderPort)

    let quickConnect = try receiveLoLaHandshakeUdpMessage(socket: descriptor)
    let quickFields = try LoLaCompatibilityControlMessage.parse(quickConnect.message).fields
    let wrongAck = LoLaCompatibilityControlMessage.quickConnectAck(
        sourceIP: quickFields["DSTIP"] ?? "127.0.0.1",
        destinationIP: quickFields["SRCIP"] ?? quickConnect.senderHost,
        sessionID: 43,
        sampleRateHertz: Int(quickFields["SR"] ?? "44100") ?? 44_100,
        bitsPerSample: Int(quickFields["BPS"] ?? "16") ?? 16,
        channels: Int(quickFields["CHNLS"] ?? "2") ?? 2,
        videoFrameRate: Int(quickFields["FPS"] ?? "0") ?? 0,
        videoBitsPerPixel: Int(quickFields["BPP"] ?? "0") ?? 0,
        videoWidth: Int(quickFields["X"] ?? "0") ?? 0,
        videoHeight: Int(quickFields["Y"] ?? "0") ?? 0,
        videoCompression: Int(quickFields["COMP"] ?? "0") ?? 0,
        videoBayer: Int(quickFields["BAYER"] ?? "0") ?? 0
    )
    try sendLoLaHandshakeUdpMessage(
        wrongAck,
        socket: descriptor,
        host: quickConnect.senderHost,
        port: quickConnect.senderPort
    )
    return [status.message, quickConnect.message]
}

private func freeLoLaHandshakeUdpPort() throws -> UInt16 {
    let descriptor = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
    guard descriptor >= 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    defer { Darwin.close(descriptor) }
    try bindLoLaHandshakeUdpSocket(descriptor, host: "127.0.0.1", port: 0)
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

private func wrongSessionQuickAckTcpPeer(port: UInt16, ready: DispatchSemaphore) throws -> [String] {
    let listener = Darwin.socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
    guard listener >= 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    defer { Darwin.close(listener) }
    try bindLoLaHandshakeTcpSocket(listener, host: "127.0.0.1", port: port)
    guard Darwin.listen(listener, 1) == 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    ready.signal()

    let connection = Darwin.accept(listener, nil, nil)
    guard connection >= 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    defer { Darwin.close(connection) }
    let status = try receiveLoLaHandshakeTcpMessage(socket: connection)
    let statusFields = try LoLaCompatibilityControlMessage.parse(status).fields
    try sendLoLaHandshakeTcpMessage(
        LoLaCompatibilityControlMessage.checkStatusAck(
            sourceIP: statusFields["DSTIP"] ?? "127.0.0.1",
            destinationIP: statusFields["SRCIP"] ?? "127.0.0.1",
            sessionID: Int(statusFields["SID"] ?? "0") ?? 0
        ),
        socket: connection
    )

    let quickConnect = try receiveLoLaHandshakeTcpMessage(socket: connection)
    let quickFields = try LoLaCompatibilityControlMessage.parse(quickConnect).fields
    try sendLoLaHandshakeTcpMessage(
        LoLaCompatibilityControlMessage.quickConnectAck(
            sourceIP: quickFields["DSTIP"] ?? "127.0.0.1",
            destinationIP: quickFields["SRCIP"] ?? "127.0.0.1",
            sessionID: 43,
            sampleRateHertz: Int(quickFields["SR"] ?? "44100") ?? 44_100,
            bitsPerSample: Int(quickFields["BPS"] ?? "16") ?? 16,
            channels: Int(quickFields["CHNLS"] ?? "2") ?? 2,
            videoFrameRate: Int(quickFields["FPS"] ?? "0") ?? 0,
            videoBitsPerPixel: Int(quickFields["BPP"] ?? "0") ?? 0,
            videoWidth: Int(quickFields["X"] ?? "0") ?? 0,
            videoHeight: Int(quickFields["Y"] ?? "0") ?? 0,
            videoCompression: Int(quickFields["COMP"] ?? "0") ?? 0,
            videoBayer: Int(quickFields["BAYER"] ?? "0") ?? 0
        ),
        socket: connection
    )
    return [status, quickConnect]
}

private func freeLoLaHandshakeTcpPort() throws -> UInt16 {
    let descriptor = Darwin.socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
    guard descriptor >= 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    defer { Darwin.close(descriptor) }
    try bindLoLaHandshakeTcpSocket(descriptor, host: "127.0.0.1", port: 0)
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

private func bindLoLaHandshakeTcpSocket(_ socket: Int32, host: String, port: UInt16) throws {
    var reuse: Int32 = 1
    _ = setsockopt(socket, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))
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

private func sendLoLaHandshakeTcpMessage(_ message: String, host: String, port: UInt16) throws {
    let descriptor = Darwin.socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
    guard descriptor >= 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    defer { Darwin.close(descriptor) }
    var destination = sockaddr_in()
    destination.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    destination.sin_family = sa_family_t(AF_INET)
    destination.sin_port = port.bigEndian
    guard inet_pton(AF_INET, host, &destination.sin_addr) == 1 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    let connectResult = withUnsafePointer(to: &destination) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            Darwin.connect(descriptor, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    guard connectResult == 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    try sendLoLaHandshakeTcpMessage(message, socket: descriptor)
}

private func sendLoLaHandshakeTcpMessageWhenReady(_ message: String, host: String, port: UInt16) async throws {
    let deadline = ContinuousClock.now + .seconds(3)
    var lastError: Error?

    while ContinuousClock.now < deadline {
        do {
            try sendLoLaHandshakeTcpMessage(message, host: host, port: port)
            return
        } catch {
            lastError = error
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    throw lastError ?? NSError(domain: NSPOSIXErrorDomain, code: Int(ETIMEDOUT))
}

private func sendLoLaHandshakeTcpMessage(_ message: String, socket: Int32) throws {
    let bytes = [UInt8](message.utf8)
    let sent = bytes.withUnsafeBytes { rawBuffer in
        Darwin.send(socket, rawBuffer.baseAddress, rawBuffer.count, 0)
    }
    guard sent == bytes.count else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
}

private func receiveLoLaHandshakeTcpMessage(socket: Int32) throws -> String {
    var buffer = [UInt8](repeating: 0, count: 4096)
    let received = Darwin.recv(socket, &buffer, buffer.count, 0)
    guard received > 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    return String(decoding: buffer[0..<received], as: UTF8.self)
}

private func bindLoLaHandshakeUdpSocket(_ socket: Int32, host: String, port: UInt16) throws {
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

private func receiveLoLaHandshakeUdpMessage(
    socket: Int32
) throws -> (message: String, senderHost: String, senderPort: UInt16) {
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
        try loLaHandshakeHostString(sender.sin_addr),
        UInt16(bigEndian: sender.sin_port)
    )
}

private func sendLoLaHandshakeUdpMessage(_ message: String, host: String, port: UInt16) throws {
    let descriptor = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
    guard descriptor >= 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    defer { Darwin.close(descriptor) }
    try sendLoLaHandshakeUdpMessage(message, socket: descriptor, host: host, port: port)
}

private func sendLoLaHandshakeUdpMessageUntilAttemptCompletes(
    _ message: String,
    receiver: Task<LoLaControlExchangeAttempt, Error>,
    host: String,
    port: UInt16
) async throws -> LoLaControlExchangeAttempt {
    try await withThrowingTaskGroup(of: LoLaControlExchangeAttempt?.self) { group in
        group.addTask {
            try await receiver.value
        }
        group.addTask {
            let deadline = ContinuousClock.now + .seconds(3)
            while !Task.isCancelled, ContinuousClock.now < deadline {
                try sendLoLaHandshakeUdpMessage(message, host: host, port: port)
                try await Task.sleep(for: .milliseconds(10))
            }
            return nil
        }

        while let result = try await group.next() {
            if let attempt = result {
                group.cancelAll()
                return attempt
            }
        }
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(ETIMEDOUT))
    }
}

private func sendLoLaHandshakeUdpMessage(_ message: String, socket: Int32, host: String, port: UInt16) throws {
    var destination = sockaddr_in()
    destination.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    destination.sin_family = sa_family_t(AF_INET)
    destination.sin_port = port.bigEndian
    guard inet_pton(AF_INET, host, &destination.sin_addr) == 1 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    let bytes = [UInt8](message.utf8)
    let sent = try bytes.withUnsafeBytes { rawBuffer in
        try withUnsafePointer(to: &destination) { pointer in
            try pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                let result = Darwin.sendto(
                    socket,
                    rawBuffer.baseAddress,
                    rawBuffer.count,
                    0,
                    socketAddress,
                    socklen_t(MemoryLayout<sockaddr_in>.size)
                )
                guard result == rawBuffer.count else {
                    throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
                }
                return result
            }
        }
    }
    _ = sent
}

private func setLoLaHandshakeUdpTimeout(_ socket: Int32, seconds: Int) throws {
    var timeout = timeval(tv_sec: seconds, tv_usec: 0)
    let status = setsockopt(socket, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
    guard status == 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
}

private func waitForLoLaHandshakePeerReady(_ ready: DispatchSemaphore) throws {
    guard ready.wait(timeout: .now() + .seconds(3)) == .success else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(ETIMEDOUT))
    }
}

private func loLaHandshakeHostString(_ address: in_addr) throws -> String {
    var address = address
    var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
    guard inet_ntop(AF_INET, &address, &buffer, socklen_t(buffer.count)) != nil else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    let endIndex = buffer.firstIndex(of: 0) ?? buffer.endIndex
    return String(decoding: buffer[..<endIndex].map(UInt8.init), as: UTF8.self)
}
