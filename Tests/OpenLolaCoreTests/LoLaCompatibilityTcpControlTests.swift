import Darwin
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func lolaControlTransportParserAcceptsTcpAndUdp() throws {
    let tcp = try ExternalConnectorSessionConfiguration.parse([
        "--connector", "lola",
        "--role", "tx",
        "--peer", "192.0.2.20",
        "--output", "/tmp/lola-tcp.json",
        "--control-transport", "tcp",
    ])
    let udp = try ExternalConnectorSessionConfiguration.parse([
        "--connector", "lola",
        "--role", "tx",
        "--peer", "192.0.2.20",
        "--output", "/tmp/lola-udp.json",
        "--control-transport", "udp",
    ])

    #expect(tcp.controlTransport == .tcp)
    #expect(udp.controlTransport == .udp)
    #expect(try ExternalConnectorLaunchPlan.build(configuration: tcp).arguments.contains("tcp"))
}

@Test
func lolaTcpControlLoopbackExchangesQuickConnectAck() async throws {
    let controlPort = try freeExternalConnectorTcpTestPort()
    let audioPort = try freeExternalConnectorUdpTestPort()
    let videoPort = try freeExternalConnectorUdpTestPort()
    let receiver = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .rx,
        peer: "",
        localHost: "127.0.0.1",
        outputPath: "/tmp/lola-tcp-rx.json",
        dryRun: false,
        mediaMode: .audioVideo,
        controlTransport: .tcp,
        durationSeconds: 8,
        controlPort: controlPort,
        audioPort: audioPort,
        videoPort: videoPort,
        sessionID: "77"
    )
    let transmitter = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .tx,
        peer: "127.0.0.1",
        localHost: "127.0.0.1",
        outputPath: "/tmp/lola-tcp-tx.json",
        dryRun: false,
        mediaMode: .audioVideo,
        controlTransport: .tcp,
        durationSeconds: 8,
        controlPort: controlPort,
        audioPort: audioPort,
        videoPort: videoPort,
        sessionID: "77"
    )

    async let rxReport = ExternalConnectorSessionRunner.run(configuration: receiver)
    let txReport = try await runLoLaTcpTransmitterWhenReceiverIsReady(transmitter)
    let acceptedRxReport = try await rxReport

    try txReport.validate()
    try acceptedRxReport.validate()
    #expect(txReport.lolaControl?.parsedMessageName == "/MESG_QUICKCONN_ACK")
    #expect(txReport.lolaControl?.sentMessages.count == 2)
    #expect(txReport.lolaControl?.receivedMessages.count == 2)
    #expect(txReport.lolaControl?.fields["SID"] == "77")
    #expect(acceptedRxReport.lolaControl?.parsedMessageName == "/MESG_QUICKCONN")
    #expect(acceptedRxReport.lolaControl?.sentMessages.count == 2)
    #expect(acceptedRxReport.lolaControl?.receivedMessages.count == 2)
}

@Test
func lolaTcpControlReportsPeerHalfCloseAsSocketFailure() async throws {
    let controlPort = try freeExternalConnectorTcpTestPort()
    let audioPort = try freeExternalConnectorUdpTestPort()
    let videoPort = try freeExternalConnectorUdpTestPort()
    let listener = try makeHalfCloseTcpListener(port: controlPort)
    defer { Darwin.close(listener) }
    async let server: Void = acceptAndHalfClose(listener)
    let transmitter = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .tx,
        peer: "127.0.0.1",
        localHost: "127.0.0.1",
        outputPath: "/tmp/lola-tcp-half-close-tx.json",
        dryRun: false,
        mediaMode: .audioVideo,
        controlTransport: .tcp,
        durationSeconds: 2,
        controlPort: controlPort,
        audioPort: audioPort,
        videoPort: videoPort,
        sessionID: "78"
    )

    let report = try ExternalConnectorSessionRunner.run(configuration: transmitter)
    _ = try await server

    try report.validate()
    #expect(report.verdict == .fail)
    #expect(report.runtimeError?.contains("tcp peer closed connection") == true)
}

@Test
func lolaTcpReceiveAccumulatesFragmentedControlDatagram() async throws {
    let message = "/MESG_CHECKLOLASTATUS_ACK\0TXT=ok\0"
    let datagram = lolaControlDatagramBytes(message)
    var sockets: [Int32] = [0, 0]
    guard Darwin.socketpair(AF_UNIX, SOCK_STREAM, 0, &sockets) == 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    defer {
        Darwin.close(sockets[0])
        Darwin.close(sockets[1])
    }
    let writeSocket = sockets[0]
    let readSocket = sockets[1]

    async let writer: Void = sendFragmentedTcpDatagram(
        datagram,
        firstByteCount: 128,
        socket: writeSocket
    )
    let received = try receiveExternalConnectorTcp(
        socket: readSocket,
        bufferSize: lolaControlDatagramByteCount
    )
    _ = try await writer

    #expect(received.bytesTransferred == lolaControlDatagramByteCount)
    #expect(received.message.hasPrefix(message))
}

@Test
func lolaControlSocketsGuardReuseOptionFailures() throws {
    let udpSource = try readLoLaTcpControlSource(
        "Sources/OpenLolaCore/Connectors/LoLa/LoLaControlExchangeRuntime.swift"
    )
    let tcpSource = try readLoLaTcpControlSource(
        "Sources/OpenLolaCore/Connectors/LoLa/LoLaTcpControlExchangeRuntime.swift"
    )

    #expect(!udpSource.contains("_ = setsockopt(descriptor, SOL_SOCKET, SO_REUSEADDR"))
    #expect(!udpSource.contains("_ = setsockopt(descriptor, SOL_SOCKET, SO_REUSEPORT"))
    #expect(!tcpSource.contains("_ = setsockopt(socket, SOL_SOCKET, SO_REUSEADDR"))
    #expect(udpSource.contains("udp setsockopt SO_REUSEADDR"))
    #expect(udpSource.contains("udp setsockopt SO_REUSEPORT"))
    #expect(tcpSource.contains("tcp setsockopt SO_REUSEADDR"))
}

private func freeExternalConnectorUdpTestPort() throws -> UInt16 {
    let descriptor = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
    guard descriptor >= 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    defer { Darwin.close(descriptor) }

    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = 0
    address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
    let bindResult = withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            Darwin.bind(descriptor, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    guard bindResult == 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }

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

private func runLoLaTcpTransmitterWhenReceiverIsReady(
    _ configuration: ExternalConnectorSessionConfiguration
) async throws -> ExternalConnectorSessionReport {
    let deadline = ContinuousClock.now + .seconds(3)
    var lastReport: ExternalConnectorSessionReport?
    while ContinuousClock.now < deadline {
        let report = try ExternalConnectorSessionRunner.run(configuration: configuration)
        if report.lolaControl?.parsedMessageName == "/MESG_QUICKCONN_ACK" {
            return report
        }
        lastReport = report
        try await Task.sleep(for: .milliseconds(10))
    }
    if let lastReport {
        return lastReport
    }
    throw NSError(domain: NSPOSIXErrorDomain, code: Int(ETIMEDOUT))
}

private func makeHalfCloseTcpListener(port: UInt16) throws -> Int32 {
    let descriptor = Darwin.socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
    guard descriptor >= 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    var reuse: Int32 = 1
    _ = setsockopt(descriptor, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))
    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = port.bigEndian
    address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
    let bindResult = withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            Darwin.bind(descriptor, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    guard bindResult == 0 else {
        Darwin.close(descriptor)
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    guard listen(descriptor, 1) == 0 else {
        Darwin.close(descriptor)
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    return descriptor
}

private func acceptAndHalfClose(_ listener: Int32) throws {
    let connection = accept(listener, nil, nil)
    guard connection >= 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    var buffer = [UInt8](repeating: 0, count: 4096)
    _ = recv(connection, &buffer, buffer.count, 0)
    _ = Darwin.shutdown(connection, SHUT_WR)
    usleep(100_000)
    Darwin.close(connection)
}

private func sendFragmentedTcpDatagram(
    _ bytes: [UInt8],
    firstByteCount: Int,
    socket: Int32
) async throws {
    try bytes.withUnsafeBytes { rawBuffer in
        guard let baseAddress = rawBuffer.baseAddress else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(EINVAL))
        }
        let firstSent = Darwin.send(socket, baseAddress, firstByteCount, 0)
        guard firstSent == firstByteCount else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        usleep(50_000)
        let remainderAddress = baseAddress.advanced(by: firstByteCount)
        let remainderCount = rawBuffer.count - firstByteCount
        let secondSent = Darwin.send(socket, remainderAddress, remainderCount, 0)
        guard secondSent == remainderCount else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
    }
}

private func freeExternalConnectorTcpTestPort() throws -> UInt16 {
    let descriptor = Darwin.socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
    guard descriptor >= 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    defer { Darwin.close(descriptor) }

    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = 0
    address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
    let bindResult = withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            Darwin.bind(descriptor, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    guard bindResult == 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }

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

private func readLoLaTcpControlSource(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
