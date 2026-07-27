// Verifies that LoLa control transport parser accepts TCP and UDP.
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
        "--control-transport", "tcp"
    ])
    let udp = try ExternalConnectorSessionConfiguration.parse([
        "--connector", "lola",
        "--role", "tx",
        "--peer", "192.0.2.20",
        "--output", "/tmp/lola-udp.json",
        "--control-transport", "udp"
    ])

    #expect(tcp.controlTransport == .tcp)
    #expect(udp.controlTransport == .udp)
    #expect(try ExternalConnectorLaunchPlan.build(configuration: tcp).arguments.contains("tcp"))
}

@Test
func lolaTcpControlLoopbackExchangesQuickConnectAck() async throws {
    try await SocketHeavyTestGate.shared.run {
        let controlPort = try freeExternalConnectorTcpTestPort()
        let audioPort = try freeExternalConnectorUdpTestPort()
        let videoPort = try freeExternalConnectorUdpTestPort()
        let ports = LoLaTcpControlTestPorts(control: controlPort, audio: audioPort, video: videoPort)
        let receiver = makeLoLaTcpControlConfiguration(.init(
            role: .rx,
            peer: "",
            outputPath: "/tmp/lola-tcp-rx.json",
            durationSeconds: 8,
            sessionID: "77",
            ports: ports
        ))
        let transmitter = makeLoLaTcpControlConfiguration(.init(
            role: .tx,
            peer: "127.0.0.1",
            outputPath: "/tmp/lola-tcp-tx.json",
            durationSeconds: 8,
            sessionID: "77",
            ports: ports
        ))
        let receiverReady = ExternalConnectorReadinessGate()
        let waitForRxReport = runExternalConnectorSessionInBackground(
            receiver,
            onLoLaControlReady: { Task { await receiverReady.signal() } }
        )
        try #require(await receiverReady.wait(timeout: .seconds(3)))

        let txReport = try ExternalConnectorSessionRunner.run(configuration: transmitter)
        let acceptedRxReport = try waitForRxReport()

        try assertQuickConnectAckControl(txReport)
        try acceptedRxReport.validate()
        #expect(txReport.lolaControl?.fields["SID"] == "77")
        #expect(acceptedRxReport.lolaControl?.parsedMessageName == "/MESG_QUICKCONN")
        #expect(acceptedRxReport.lolaControl?.sentMessages.count == 2)
        #expect(acceptedRxReport.lolaControl?.receivedMessages.count == 2)
    }
}

@Test
func externalConnectorTcpListenerReadinessTimesOutWithoutPeer() async throws {
    try await SocketHeavyTestGate.shared.run {
        let listener = try makeExternalConnectorTcpSocket()
        defer { Darwin.close(listener) }
        try bindExternalConnectorTcp(socket: listener, host: "127.0.0.1", port: 0)
        guard listen(listener, 1) == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }

        #expect(try !waitForExternalConnectorTcpConnection(socket: listener, timeoutSeconds: 1))
    }
}

@Test
func lolaTcpControlReportsPeerHalfCloseAsSocketFailure() async throws {
    let controlPort = try freeExternalConnectorTcpTestPort()
    let audioPort = try freeExternalConnectorUdpTestPort()
    let videoPort = try freeExternalConnectorUdpTestPort()
    let listener = try makeHalfCloseTcpListener(port: controlPort)
    defer { Darwin.close(listener) }
    async let server: Void = acceptAndHalfClose(listener)
    let transmitter = makeLoLaTcpControlConfiguration(.init(
        role: .tx,
        peer: "127.0.0.1",
        outputPath: "/tmp/lola-tcp-half-close-tx.json",
        durationSeconds: 2,
        sessionID: "78",
        ports: .init(control: controlPort, audio: audioPort, video: videoPort)
    ))

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
    try await withLoLaTestTcpSocketPair { writeSocket, readSocket in
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
}

@Test
func lolaTcpReceiveRejectsInvalidUTF8ControlDatagram() async throws {
    try await withLoLaTestTcpSocketPair { writeSocket, readSocket in
        let invalidDatagram = [UInt8](repeating: 0xFF, count: lolaControlDatagramByteCount)
        try invalidDatagram.withUnsafeBytes { rawBuffer in
            let sent = Darwin.send(writeSocket, rawBuffer.baseAddress, rawBuffer.count, 0)
            guard sent == rawBuffer.count else {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
            }
        }

        #expect(throws: ExternalConnectorSessionError.malformedLoLaControlMessage("invalid UTF-8 TCP control datagram")) {
            _ = try receiveExternalConnectorTcp(
                socket: readSocket,
                bufferSize: lolaControlDatagramByteCount
            )
        }
    }
}

@Test
func lolaTcpSendRetriesPartialWritesUntilControlDatagramIsComplete() throws {
    let datagram = lolaControlDatagramBytes("/MESG_CHECKLOLASTATUS\0TXT=partial\0")
    var sendLimits = [128, 257, datagram.count]
    var chunks: [Data] = []

    let sent = try sendExternalConnectorTcpBytes(datagram, socket: -1) { _, buffer, byteCount, _ in
        guard !sendLimits.isEmpty else { return -1 }
        let sent = min(sendLimits.removeFirst(), byteCount)
        chunks.append(Data(bytes: buffer, count: sent))
        return sent
    }

    #expect(sent == datagram.count)
    #expect(sendLimits.isEmpty)
    #expect(Data(chunks.flatMap { $0 }) == Data(datagram))
}

private func freeExternalConnectorUdpTestPort() throws -> UInt16 {
    try freeLoLaTestPort(.udp)
}

private struct LoLaTcpControlTestPorts {
    let control: UInt16
    let audio: UInt16
    let video: UInt16
}

private struct LoLaTcpControlConfigurationFixture {
    let role: ExternalConnectorSessionRole
    let peer: String
    let outputPath: String
    let durationSeconds: Int
    let sessionID: String
    let ports: LoLaTcpControlTestPorts
}

private func makeLoLaTcpControlConfiguration(
    _ fixture: LoLaTcpControlConfigurationFixture
) -> ExternalConnectorSessionConfiguration {
    ExternalConnectorSessionConfiguration(.init(
        connector: .lola,
        role: fixture.role,
        peer: fixture.peer,
        outputPath: fixture.outputPath
    ) { input in
        input.localHost = "127.0.0.1"
        input.dryRun = false
        input.mediaMode = .audioVideo
        input.controlTransport = .tcp
        input.durationSeconds = fixture.durationSeconds
        input.controlPort = fixture.ports.control
        input.audioPort = fixture.ports.audio
        input.videoPort = fixture.ports.video
        input.sessionID = fixture.sessionID
        input.videoWidth = 16
        input.videoHeight = 16
        input.videoFrameRate = 60
        input.videoBitsPerPixel = 8
    })
}

private func makeHalfCloseTcpListener(port: UInt16) throws -> Int32 {
    let descriptor = try openLoLaTestSocket(.tcp)
    do {
        try bindLoLaTestSocket(descriptor, host: "127.0.0.1", port: port, reuseAddress: true)
    } catch {
        Darwin.close(descriptor)
        throw error
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
    try freeLoLaTestPort(.tcp)
}
