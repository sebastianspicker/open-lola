// Shared LoLa control handshake validation helpers keep multi-file test scenarios deterministic.
import Darwin
import Foundation

@testable import OpenLolaCore

func loLaQuickConnectMediaFields(
    fields: [String: String],
    senderHost: String,
    sessionID: Int? = nil
) -> LoLaCompatibilityMediaFields {
    let session = LoLaControlSessionFields(
        sourceIP: fields["DSTIP"] ?? "127.0.0.1",
        destinationIP: fields["SRCIP"] ?? senderHost,
        sessionID: sessionID ?? Int(fields["SID"] ?? "0") ?? 0
    )
    let audio = LoLaCompatibilityAudioFields(
        sampleRateHertz: Int(fields["SR"] ?? "44100") ?? 44_100,
        bitsPerSample: Int(fields["BPS"] ?? "16") ?? 16,
        channels: Int(fields["CHNLS"] ?? "2") ?? 2
    )
    let video = LoLaCompatibilityVideoFields(
        frameRate: Int(fields["FPS"] ?? "0") ?? 0,
        bitsPerPixel: Int(fields["BPP"] ?? "0") ?? 0,
        dimensions: LoLaCompatibilityVideoDimensions(
            width: Int(fields["X"] ?? "0") ?? 0,
            height: Int(fields["Y"] ?? "0") ?? 0
        ),
        compression: Int(fields["COMP"] ?? "0") ?? 0,
        bayer: Int(fields["BAYER"] ?? "0") ?? 0
    )
    return LoLaCompatibilityMediaFields(session: session, audio: audio, video: video)
}

func wrongSessionQuickAckUdpPeer(port: UInt16, ready: DispatchSemaphore) throws -> [String] {
    try withLoLaTestSocket(.udp) { descriptor in
        try bindLoLaTestSocket(descriptor, host: "127.0.0.1", port: port)
        try setLoLaTestSocketReceiveTimeout(descriptor, seconds: 6)
        ready.signal()

        let status = try receiveLoLaTestUdpDatagram(socket: descriptor)
        let statusMessage = loLaTestLossyUTF8String(status.bytes)
        let statusFields = try LoLaCompatibilityControlMessage.parse(statusMessage).fields
        let statusAck = LoLaCompatibilityControlMessage.checkStatusAck(
            sourceIP: statusFields["DSTIP"] ?? "127.0.0.1",
            destinationIP: statusFields["SRCIP"] ?? status.senderHost,
            sessionID: Int(statusFields["SID"] ?? "0") ?? 0
        )
        try sendLoLaHandshakeUdpMessage(
            statusAck,
            socket: descriptor,
            host: status.senderHost,
            port: status.senderPort
        )

        let quickConnect = try receiveLoLaTestUdpDatagram(socket: descriptor)
        let quickConnectMessage = loLaTestLossyUTF8String(quickConnect.bytes)
        let quickFields = try LoLaCompatibilityControlMessage.parse(quickConnectMessage).fields
        let wrongAck = LoLaCompatibilityControlMessage.quickConnectAck(
            loLaQuickConnectMediaFields(
                fields: quickFields,
                senderHost: quickConnect.senderHost,
                sessionID: 43
            )
        )
        try sendLoLaHandshakeUdpMessage(
            wrongAck,
            socket: descriptor,
            host: quickConnect.senderHost,
            port: quickConnect.senderPort
        )
        return [statusMessage, quickConnectMessage]
    }
}

func freeLoLaHandshakeUdpPort() throws -> UInt16 {
    try freeLoLaTestPort(.udp)
}

func wrongSessionQuickAckTcpPeer(port: UInt16, ready: DispatchSemaphore) throws -> [String] {
    try withLoLaTestSocket(.tcp) { listener in
        try bindLoLaTestSocket(listener, host: "127.0.0.1", port: port, reuseAddress: true)
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
                loLaQuickConnectMediaFields(fields: quickFields, senderHost: "127.0.0.1", sessionID: 43)
            ),
            socket: connection
        )
        return [status, quickConnect]
    }
}

func freeLoLaHandshakeTcpPort() throws -> UInt16 {
    try freeLoLaTestPort(.tcp)
}

private func sendLoLaHandshakeTcpMessage(_ message: String, host: String, port: UInt16) throws {
    try withLoLaTestSocket(.tcp) { descriptor in
        var destination = try loLaTestIPv4Address(host: host, port: port)
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
}

func sendLoLaHandshakeTcpMessageWhenReady(_ message: String, host: String, port: UInt16) async throws {
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
    return loLaTestLossyUTF8String(Array(buffer[0..<received]))
}

private func sendLoLaHandshakeUdpMessage(_ message: String, host: String, port: UInt16) throws {
    try withLoLaTestSocket(.udp) { descriptor in
        try sendLoLaHandshakeUdpMessage(message, socket: descriptor, host: host, port: port)
    }
}

func sendLoLaHandshakeUdpMessageUntilAttemptCompletes(
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
    try sendLoLaTestUdpBytes([UInt8](message.utf8), socket: socket, host: host, port: port)
}

func waitForLoLaHandshakePeerReady(_ ready: DispatchSemaphore) throws {
    guard ready.wait(timeout: .now() + .seconds(3)) == .success else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(ETIMEDOUT))
    }
}
