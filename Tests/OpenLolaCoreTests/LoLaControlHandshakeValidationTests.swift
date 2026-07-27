// Verifies that LoLa transmit rejects a quick-connect ACK with the wrong session.
import Darwin
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func lolaTransmitRejectsQuickConnectAckWithWrongSession() async throws {
    try await SocketHeavyTestGate.shared.run {
        let udpControlPort = try freeLoLaHandshakeUdpPort()
        let udpConfiguration = ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .tx,
  peer: "127.0.0.1",
  outputPath: "/tmp/lola-wrong-sid-ack.json"
) { input in
  input.localHost = "127.0.0.1"
  input.dryRun = false
  input.durationSeconds = 3
  input.controlPort = udpControlPort
  input.sessionID = "42"
})

        let udpPeerReady = DispatchSemaphore(value: 0)
        async let udpPeer = wrongSessionQuickAckUdpPeer(port: udpControlPort, ready: udpPeerReady)
        try waitForLoLaHandshakePeerReady(udpPeerReady)
        let udpAttempt = try runLoLaControlExchangeAttempt(configuration: udpConfiguration)
        _ = try await udpPeer

        #expect(udpAttempt.runtimeError?.contains("malformedLoLaControlMessage") == true)
        #expect(udpAttempt.exchange.parsedMessageName == "/MESG_QUICKCONN_ACK")
        #expect(udpAttempt.exchange.fields["SID"] == "43")
    }

    let controlPort = try freeLoLaHandshakeTcpPort()
    let configuration = ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .tx,
  peer: "127.0.0.1",
  outputPath: "/tmp/lola-tcp-wrong-sid-ack.json"
) { input in
  input.localHost = "127.0.0.1"
  input.dryRun = false
  input.controlTransport = .tcp
  input.durationSeconds = 3
  input.controlPort = controlPort
  input.sessionID = "42"
})

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
func lolaReceiveRejectsNonHandshakeMessageAsConnectionSuccess() async throws {
    try await SocketHeavyTestGate.shared.run {
        try await expectUdpChatRejectedAsHandshakeSuccess()
    }
    try await expectTcpChatRejectedAsHandshakeSuccess()
}

private func expectUdpChatRejectedAsHandshakeSuccess() async throws {
    let udpControlPort = try freeLoLaHandshakeUdpPort()
    let udpConfiguration = ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .rx,
  peer: "127.0.0.1",
  outputPath: "/tmp/lola-chat-not-connect.json"
) { input in
  input.localHost = "127.0.0.1"
  input.dryRun = false
  input.durationSeconds = 3
  input.controlPort = udpControlPort
  input.sessionID = "42"
})

    let receiver = Task {
        try runLoLaControlExchangeAttempt(configuration: udpConfiguration)
    }
    let udpAttempt = try await sendLoLaHandshakeUdpMessageUntilAttemptCompletes(
        LoLaCompatibilityControlMessage.chat(
            sourceIP: "127.0.0.1",
            destinationIP: "127.0.0.1",
            sessionID: 42,
            text: "not a handshake"
        ),
        receiver: receiver,
        host: "127.0.0.1",
        port: udpControlPort
    )

    #expect(udpAttempt.runtimeError?.contains("malformedLoLaControlMessage") == true)
    #expect(udpAttempt.exchange.parsedMessageName == "/MESG_CHAT")
}

private func expectTcpChatRejectedAsHandshakeSuccess() async throws {
    let controlPort = try freeLoLaHandshakeTcpPort()
    let configuration = ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .rx,
  peer: "127.0.0.1",
  outputPath: "/tmp/lola-tcp-chat-not-connect.json"
) { input in
  input.localHost = "127.0.0.1"
  input.dryRun = false
  input.controlTransport = .tcp
  input.durationSeconds = 3
  input.controlPort = controlPort
  input.sessionID = "42"
})

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
func lolaTxRxAcceptsPeerSpecificVideoProfileInQuickConnectAck() throws {
    let configuration = ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .txRx,
  peer: "192.0.2.47",
  outputPath: "/tmp/lola-txrx-video-profile.json"
) { input in
  input.localHost = "192.0.2.46"
  input.mediaMode = .video
  input.videoWidth = 1_280
  input.videoHeight = 720
  input.videoFrameRate = 25
  input.videoBitsPerPixel = 8
  input.sessionID = "0"
})
    let message = "/MESG_QUICKCONN_ACK;SRCIP:192.0.2.47;DSTIP:192.0.2.46;SID:0;SR:44100;" +
        "BPS:16;CHNLS:2;FPS:25;BPP:8;X:640;Y:480;COMP:0;BAYER:1"
    let parsed = try LoLaCompatibilityControlMessage.parse(message)

    let failure = try lolaOutgoingHandshakeFailure(
        context: LoLaHandshakeValidationFailureContext(
            sentMessages: [],
            receivedMessages: [message],
            opaqueControlDatagrams: [],
            bytesTransferred: message.utf8.count,
            parsedMessageName: parsed.name,
            fields: parsed.fields,
            message: message
        ),
        expectedName: "/MESG_QUICKCONN_ACK",
        expectedFields: lolaExpectedQuickConnectFields(
            configuration: configuration,
            sourceIP: "192.0.2.46"
        )
    )

    #expect(failure == nil)
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
