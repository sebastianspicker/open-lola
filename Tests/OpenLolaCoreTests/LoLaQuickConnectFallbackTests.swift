// Verifies that LoLa fallback loopback alias requirement fails explicitly when unavailable.
import Darwin
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func lolaFallbackLoopbackAliasRequirementFailsExplicitlyWhenUnavailable() throws {
    #expect(throws: LoLaFallbackLoopbackAliasRequirementError.unavailable("127.0.0.2")) {
        try requireSecondaryLoopbackAliasAvailable { false }
    }
}

@Test
func lolaQuickConnectFallbackMessageSequenceIsCoveredWithoutLoopbackAlias() throws {
    let configuration = ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .tx,
  peer: "203.0.113.20",
  outputPath: "/tmp/lola-quickconnect-fallback-stub.json"
) { input in
  input.localHost = "203.0.113.10"
  input.dryRun = false
  input.durationSeconds = 1
  input.controlPort = 7000
  input.audioPort = 7001
  input.videoPort = 7002
  input.channels = 2
  input.sampleRateHertz = 48_000
  input.sessionID = "91"
})
    let transport = StubLoLaOutgoingControlTransport()

    let attempt = try sendLoLaControlAttempt(configuration: configuration, transport: transport)

    #expect(transport.prepareCalls == 1)
    #expect(transport.receiveCalls == 2)
    #expect(attempt.runtimeError == nil)
    #expect(!attempt.isTimeout)
    #expect(attempt.exchange.parsedMessageName == "/MESG_QUICKCONN_ACK")
    #expect(transport.sentMessages.count == 2)
    #expect(transport.sentMessages[0].hasPrefix("/MESG_CHECKLOLASTATUS"))
    #expect(transport.sentMessages[1].hasPrefix("/MESG_QUICKCONN"))
    #expect(attempt.exchange.sentMessages == transport.sentMessages)
    #expect(attempt.exchange.receivedMessages.count == 1)
    #expect(attempt.exchange.bytesTransferred == (transport.sentMessages.count + 1) * lolaControlDatagramByteCount)
}

@Test
func lolaOutgoingControlPreservesAcceptedStatusEvidenceWhenQuickConnectSendFails() throws {
    final class ThrowingQuickConnectTransport: LoLaOutgoingControlTransport {
        func prepare(configuration: ExternalConnectorSessionConfiguration) throws {}

        func send(_ message: String, host: String, port: UInt16) throws -> Int {
            if message.hasPrefix("/MESG_QUICKCONN") {
                throw ExternalConnectorSessionError.socketFailed("injected quick-connect send failure")
            }
            sentMessages.append(message)
            return lolaControlDatagramByteCount
        }

        func receive(
            state: LoLaExchangeState,
            destinationPort: UInt16,
            deadline: MonotonicDeadline,
            parsedMessageName: String?,
            fields: [String: String]
        ) -> LoLaReceivedControlMessage {
            let status = try! LoLaCompatibilityControlMessage.parse(state.sentMessages[0])
            return LoLaReceivedControlMessage(
                message: LoLaCompatibilityControlMessage.checkStatusAck(
                    sourceIP: status.fields["DSTIP"]!,
                    destinationIP: status.fields["SRCIP"]!,
                    sessionID: Int(status.fields["SID"]!)!
                ),
                senderHost: "203.0.113.20",
                senderPort: destinationPort,
                bytesTransferred: lolaControlDatagramByteCount
            )
        }

        var sentMessages: [String] = []
    }

    let configuration = ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .tx,
  peer: "203.0.113.20",
  outputPath: "/tmp/lola-quickconnect-send-failure.json"
) { input in
  input.localHost = "203.0.113.10"
  input.dryRun = false
  input.durationSeconds = 1
  input.controlPort = 7000
  input.sessionID = "91"
})
    let attempt = try sendLoLaControlAttempt(
        configuration: configuration,
        transport: ThrowingQuickConnectTransport()
    )

    #expect(attempt.runtimeError?.contains("injected quick-connect send failure") == true)
    #expect(attempt.exchange.sentMessages.count == 1)
    #expect(attempt.exchange.receivedMessages.count == 1)
    #expect(attempt.exchange.parsedMessageName == nil)
}

@Test
func lolaUdpRetryResponderAcknowledgesEphemeralRequesterPort() async throws {
    try await SocketHeavyTestGate.shared.run {
        let controlPort = try freeLoLaFallbackUdpPort()
        let configuration = ExternalConnectorSessionConfiguration(.init(
            connector: .lola,
            role: .rx,
            peer: "127.0.0.1",
            outputPath: "/tmp/lola-retry-responder-ephemeral-requester.json"
        ) { input in
            input.localHost = "127.0.0.1"
            input.dryRun = false
            input.durationSeconds = 1
            input.controlPort = controlPort
        })
        let responder = startLoLaControlRetryResponder(configuration: configuration)
        try responder.validate()

        let requester = try withLoLaFallbackUdpSocket(
            host: "127.0.0.1",
            port: 0,
            timeoutSeconds: 0,
            timeoutMicroseconds: 100_000
        ) { socket in
            let requesterPort = try boundLoLaTestSocketAddress(socket: socket).port
            let acknowledgment = try sendLoLaFallbackUdpMessageUntilReply(
                LoLaCompatibilityControlMessage.checkStatus(
                    sourceIP: "127.0.0.1", destinationIP: "127.0.0.1", sessionID: 0
                ),
                socket: socket,
                host: "127.0.0.1",
                port: controlPort
            )
            return (requesterPort, acknowledgment)
        }

        #expect(responder.started)
        #expect(requester.0 != 0)
        #expect(requester.0 != controlPort)
        #expect(requester.1.byteCount == 1024)
        #expect(requester.1.message.hasPrefix("/MESG_CHECKLOLASTATUS_ACK"))
    }
}

@Test
func lolaRetainedUdpSocketStartsRetryResponderWithoutRebindingAndStillCleansUp() async throws {
    try await SocketHeavyTestGate.shared.run {
        let controlPort = try freeLoLaFallbackUdpPort()
        let configuration = ExternalConnectorSessionConfiguration(.init(
            connector: .lola,
            role: .rx,
            peer: "127.0.0.1",
            outputPath: "/tmp/lola-retained-retry-responder.json"
        ) { input in
            input.localHost = "127.0.0.1"
            input.dryRun = false
            input.durationSeconds = 1
            input.controlPort = controlPort
            input.sessionID = "0"
        })
        let negotiatedSocket = try makeLoLaFallbackUdpSocket(
            host: configuration.localHost,
            port: controlPort,
            timeoutSeconds: 1
        )
        defer { Darwin.close(negotiatedSocket) }
        var terminalMessages: [String] = []
        let terminalSession = LoLaControlTerminalSession(
            sourceIP: configuration.localHost,
            destinationIP: configuration.peer,
            sessionID: 0,
            send: { message in
                terminalMessages.append(message)
                return message.utf8.count
            },
            duplicateSocketForRetryResponder: {
                let duplicateDescriptor = Darwin.dup(negotiatedSocket)
                guard duplicateDescriptor >= 0 else {
                    throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
                }
                return duplicateDescriptor
            }
        )

        let responder = startLoLaControlRetryResponder(
            configuration: configuration,
            terminalSession: terminalSession
        )
        let acknowledgment = try withLoLaFallbackUdpSocket(
            host: "127.0.0.1",
            port: 0,
            timeoutSeconds: 0,
            timeoutMicroseconds: 100_000
        ) { requester in
            try sendLoLaFallbackUdpMessageUntilReply(
                LoLaCompatibilityControlMessage.checkStatus(
                    sourceIP: "127.0.0.1", destinationIP: "127.0.0.1", sessionID: 0
                ),
                socket: requester,
                host: configuration.localHost,
                port: controlPort
            )
        }
        var exchange = LoLaControlExchange()
        #expect(terminalSession.finish(exchange: &exchange) == nil)

        #expect(responder.started)
        #expect(responder.runtimeError == nil)
        #expect(acknowledgment.message.hasPrefix("/MESG_CHECKLOLASTATUS_ACK"))
        #expect(exchange.sentMessages == terminalMessages)
        #expect(exchange.sentMessages.map { String($0.split(separator: ";").first ?? "") } == [
            "/MESG_STOP_AUDIO_SIGNAL", "/MESG_DISCONNECT"
        ])
    }
}

@Test(.enabled(if: secondaryLoopbackAliasAvailable()))
func lolaUdpTransmitFallsBackToQuickConnectWhenStatusAckTimesOut() async throws {
    try requireSecondaryLoopbackAliasAvailable()
    try await SocketHeavyTestGate.shared.run {
        let fixture = try lolaFallbackFixture(
            role: .tx, outputPath: "/tmp/lola-quickconnect-fallback.json", sessionID: "91"
        )
        let controlPort = fixture.controlPort
        let configuration = fixture.configuration

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

@Test(.enabled(if: secondaryLoopbackAliasAvailable()))
func lolaUdpReceiveKeepsControlSocketAliveForPostConnectRetries() async throws {
    try requireSecondaryLoopbackAliasAvailable()
    try await SocketHeavyTestGate.shared.run {
        let fixture = try lolaFallbackFixture(
            role: .rx, outputPath: "/tmp/lola-control-keepalive-rx.json", sessionID: "0"
        )
        let controlPort = fixture.controlPort
        let configuration = fixture.configuration

        async let receiver = ExternalConnectorSessionRunner.run(configuration: configuration)
        let peerMessages = try quickConnectThenRetryUdpPeer(
            bindHost: "127.0.0.2",
            destinationHost: "127.0.0.1",
            controlPort: controlPort
        )
        let report = try await receiver

        #expect(report.runtimeError == nil)
        #expect(report.lolaControl?.parsedMessageName == "/MESG_QUICKCONN")
        #expect(report.lolaControlRetryResponder?.started == true)
        #expect(report.lolaControlRetryResponder?.runtimeError == nil)
        #expect(report.lolaControl?.sentMessages.suffix(2).map { message in
            String(message.split(separator: ";").first ?? "")
        } == ["/MESG_STOP_AUDIO_SIGNAL", "/MESG_DISCONNECT"])
        #expect(peerMessages.map(\.byteCount) == [1024, 1024, 1024, 1024])
        #expect(peerMessages[2].message.hasPrefix("/MESG_CHECKLOLASTATUS_ACK"))
        #expect(peerMessages[3].message.hasPrefix("/MESG_QUICKCONN_ACK"))
    }
}

@Test(.enabled(if: secondaryLoopbackAliasAvailable()))
func lolaUdpTxRxKeepsControlSocketAliveForPostConnectCommands() async throws {
    try requireSecondaryLoopbackAliasAvailable()
    try await SocketHeavyTestGate.shared.run {
        let fixture = try lolaFallbackFixture(
            role: .txRx, outputPath: "/tmp/lola-control-keepalive-tx-rx.json", sessionID: "0"
        )
        let controlPort = fixture.controlPort
        let configuration = fixture.configuration

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

private func lolaFallbackFixture(
    role: ExternalConnectorSessionRole,
    outputPath: String,
    sessionID: String
) throws -> (configuration: ExternalConnectorSessionConfiguration, controlPort: UInt16) {
    let controlPort = try freeLoLaFallbackUdpPort()
    let audioPort = try freeLoLaFallbackUdpPort()
    let videoPort = try freeLoLaFallbackUdpPort()
    let configuration = ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: role,
  peer: "127.0.0.2",
  outputPath: outputPath
) { input in
  input.localHost = "127.0.0.1"
  input.dryRun = false
  input.durationSeconds = 3
  input.controlPort = controlPort
  input.audioPort = audioPort
  input.videoPort = videoPort
  input.sessionID = sessionID
})
    return (configuration, controlPort)
}

@Test(.enabled(if: secondaryLoopbackAliasAvailable()))
func lolaUdpControlRetryResponderReportsBindFailure() throws {
    let controlPort = try freeLoLaFallbackUdpPort()
    let occupied = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
    guard occupied >= 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    defer { Darwin.close(occupied) }
    try bindLoLaFallbackUdpSocket(occupied, host: "127.0.0.1", port: controlPort)
    let audioPort = try freeLoLaFallbackUdpPort()
    let videoPort = try freeLoLaFallbackUdpPort()

    let report = startLoLaControlRetryResponder(configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .rx,
  peer: "127.0.0.2",
  outputPath: "/tmp/lola-control-keepalive-bind-fail.json"
) { input in
  input.localHost = "127.0.0.1"
  input.dryRun = false
  input.durationSeconds = 1
  input.controlPort = controlPort
  input.audioPort = audioPort
  input.videoPort = videoPort
  input.sessionID = "0"
}))

    #expect(!report.started)
    #expect(report.runtimeError?.contains("bind 127.0.0.1:\(controlPort)") == true)
    try report.validate()
}
