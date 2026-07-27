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
