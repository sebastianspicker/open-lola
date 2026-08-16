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

        #expect(udpAttempt.runtimeError?.contains("receiveTimedOut") == true)
        #expect(udpAttempt.exchange.parsedMessageName == "/MESG_CHECKLOLASTATUS_ACK")
        #expect(udpAttempt.exchange.fields["SID"] == "42")
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

    #expect(udpAttempt.runtimeError?.contains("too many unexpected LoLa handshake datagrams") == true)
    #expect(udpAttempt.exchange.parsedMessageName == nil)
    #expect(udpAttempt.exchange.receivedMessages.isEmpty)
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
            message: message,
            senderHost: "192.0.2.47",
            senderPort: configuration.controlPort
        ),
        expectedName: "/MESG_QUICKCONN_ACK",
        expectedFields: lolaExpectedQuickConnectFields(
            configuration: configuration,
            sourceIP: "192.0.2.46"
        ),
        expectedSenderHost: configuration.peer,
        expectedSenderPort: configuration.controlPort
    )

    #expect(failure == nil)
}

@Test
func lolaOutgoingControlAckRejectsUnexpectedSenderHostAndPort() throws {
    let configuration = ExternalConnectorSessionConfiguration(
        .init(
            connector: .lola,
            role: .tx,
            peer: "192.0.2.20",
            outputPath: "/tmp/lola-ack-sender-validation.json"
        ) { input in
            input.localHost = "192.0.2.10"
            input.controlPort = 7_000
        })
    let message = "/MESG_CHECKLOLASTATUS_ACK;SRCIP:192.0.2.20;DSTIP:192.0.2.10;SID:42"
    let parsed = try LoLaCompatibilityControlMessage.parse(message)
    let expectedFields = lolaExpectedStatusAckFields(
        sourceIP: "192.0.2.10",
        destinationIP: configuration.peer,
        sessionID: 42
    )
    func validationFailure(senderHost: String, senderPort: UInt16) -> LoLaControlExchangeAttempt? {
        lolaOutgoingHandshakeFailure(
            context: LoLaHandshakeValidationFailureContext(
                sentMessages: [],
                receivedMessages: [message],
                opaqueControlDatagrams: [],
                bytesTransferred: message.utf8.count,
                parsedMessageName: parsed.name,
                fields: parsed.fields,
                message: message,
                senderHost: senderHost,
                senderPort: senderPort
            ),
            expectedName: "/MESG_CHECKLOLASTATUS_ACK",
            expectedFields: expectedFields,
            expectedSenderHost: configuration.peer,
            expectedSenderPort: configuration.controlPort
        )
    }

    #expect(
        validationFailure(senderHost: "192.0.2.21", senderPort: 7_000)?.runtimeError?
            .contains("expected sender host:192.0.2.20") == true)
    #expect(
        validationFailure(senderHost: configuration.peer, senderPort: 7_001)?.runtimeError?
            .contains("expected sender port:7000") == true)
}

@Test
func lolaIncomingAndRetryHandshakeRejectForgedSourceIP() throws {
    let configuration = ExternalConnectorSessionConfiguration(
        .init(
            connector: .lola,
            role: .rx,
            peer: "192.0.2.20",
            outputPath: "/tmp/lola-forged-srcip.json"
        ) { input in
            input.localHost = "192.0.2.10"
            input.controlPort = 7_000
        })
    let forgedMessage = "/MESG_CHECKLOLASTATUS;SRCIP:192.0.2.21;DSTIP:192.0.2.10;SID:42"
    let forged = try LoLaCompatibilityControlMessage.parse(forgedMessage)
    let forgedContext = LoLaHandshakeValidationFailureContext(
        sentMessages: [],
        receivedMessages: [forgedMessage],
        opaqueControlDatagrams: [],
        bytesTransferred: forgedMessage.utf8.count,
        parsedMessageName: forged.name,
        fields: forged.fields,
        message: forgedMessage
    )

    let forgedFailure = lolaIncomingHandshakeFailure(
        context: forgedContext,
        expectedName: "/MESG_CHECKLOLASTATUS",
        localHost: configuration.localHost,
        requiresMediaFields: false,
        senderHost: configuration.peer,
        peer: configuration.peer
    )
    #expect(forgedFailure?.runtimeError?.contains("expected SRCIP:192.0.2.20") == true)
    #expect(
        try lolaRetryResponderAck(
            configuration: configuration,
            message: forgedMessage,
            parsed: forged,
            senderHost: configuration.peer
        ) == nil)

    let unexpectedPeerFailure = lolaIncomingHandshakeFailure(
        context: forgedContext,
        expectedName: "/MESG_CHECKLOLASTATUS",
        localHost: configuration.localHost,
        requiresMediaFields: false,
        senderHost: "192.0.2.21",
        peer: configuration.peer
    )
    #expect(
        unexpectedPeerFailure?.runtimeError?.contains("expected sender host:192.0.2.20") == true)
}

@Test
func lolaOutgoingUdpDiscardsUnexpectedDatagramsBeforeValidAcknowledgements() async throws {
    try await SocketHeavyTestGate.shared.run {
        let controlPort = try freeLoLaHandshakeUdpPort()
        let configuration = ExternalConnectorSessionConfiguration(
            .init(
                connector: .lola,
                role: .tx,
                peer: "127.0.0.1",
                outputPath: "/tmp/lola-outgoing-discarded-datagrams.json"
            ) { input in
                input.localHost = "127.0.0.1"
                input.dryRun = false
                input.durationSeconds = 3
                input.controlPort = controlPort
                input.sessionID = "42"
            })
        let ready = DispatchSemaphore(value: 0)
        async let peer = invalidDatagramsThenValidOutgoingUdpPeer(port: controlPort, ready: ready)
        try waitForLoLaHandshakePeerReady(ready)
        let attempt = try runLoLaControlExchangeAttempt(configuration: configuration)
        let messages = try await peer

        #expect(attempt.runtimeError == nil)
        #expect(attempt.exchange.parsedMessageName == "/MESG_QUICKCONN_ACK")
        #expect(attempt.exchange.receivedMessages.count == 2)
        #expect(messages[0].hasPrefix("/MESG_CHECKLOLASTATUS"))
        #expect(messages[1].hasPrefix("/MESG_QUICKCONN"))
    }
}

@Test
func lolaIncomingUdpDiscardsForgedAndMalformedDatagramsBeforeValidHandshake() async throws {
    try await SocketHeavyTestGate.shared.run {
        let controlPort = try freeLoLaHandshakeUdpPort()
        let configuration = ExternalConnectorSessionConfiguration(
            .init(
                connector: .lola,
                role: .rx,
                peer: "127.0.0.1",
                outputPath: "/tmp/lola-incoming-discarded-datagrams.json"
            ) { input in
                input.localHost = "127.0.0.1"
                input.dryRun = false
                input.durationSeconds = 3
                input.controlPort = controlPort
                input.sessionID = "42"
            })
        let ready = DispatchSemaphore(value: 0)
        async let peer = invalidDatagramsThenValidIncomingUdpPeer(port: controlPort, ready: ready)
        try waitForLoLaHandshakePeerReady(ready)
        let attempt = try runLoLaControlExchangeAttempt(configuration: configuration)
        let messages = try await peer

        #expect(attempt.runtimeError == nil)
        #expect(attempt.exchange.parsedMessageName == "/MESG_QUICKCONN")
        #expect(attempt.exchange.receivedMessages == messages)
    }
}

@Test
func lolaIncomingUdpBoundsMalformedHandshakeFlood() async throws {
    try await SocketHeavyTestGate.shared.run {
        let controlPort = try freeLoLaHandshakeUdpPort()
        let configuration = ExternalConnectorSessionConfiguration(
            .init(
                connector: .lola,
                role: .rx,
                peer: "127.0.0.1",
                outputPath: "/tmp/lola-incoming-malformed-flood.json"
            ) { input in
                input.localHost = "127.0.0.1"
                input.dryRun = false
                input.durationSeconds = 3
                input.controlPort = controlPort
            })
        let ready = DispatchSemaphore(value: 0)
        async let flood = floodIncomingUdpHandshakeWithMalformedDatagrams(
            port: controlPort, ready: ready)
        try waitForLoLaHandshakePeerReady(ready)
        let attempt = try runLoLaControlExchangeAttempt(configuration: configuration)
        try await flood

        #expect(
            attempt.runtimeError?.contains("too many unexpected LoLa handshake datagrams") == true)
        #expect(attempt.exchange.receivedMessages.isEmpty)
        #expect(attempt.exchange.opaqueControlDatagrams.count <= 64)
        #expect(attempt.exchange.bytesTransferred == 65 * "not a LoLa handshake".utf8.count)
    }
}

@Test
func lolaIncomingUdpPreservesOpaqueDatagramEvidenceWhenDeadlineExpires() async throws {
    try await SocketHeavyTestGate.shared.run {
        let controlPort = try freeLoLaHandshakeUdpPort()
        let configuration = ExternalConnectorSessionConfiguration(.init(
            connector: .lola,
            role: .rx,
            peer: "127.0.0.1",
            outputPath: "/tmp/lola-incoming-opaque-timeout.json"
        ) { input in
            input.localHost = "127.0.0.1"
            input.dryRun = false
            input.durationSeconds = 1
            input.controlPort = controlPort
        })
        let ready = DispatchSemaphore(value: 0)
        async let peer = opaqueDatagramThenTimeoutIncomingUdpPeer(port: controlPort, ready: ready)
        try waitForLoLaHandshakePeerReady(ready)
        let attempt = try runLoLaControlExchangeAttempt(configuration: configuration)
        try await peer

        #expect(attempt.runtimeError?.contains("receiveTimedOut") == true)
        #expect(attempt.exchange.receivedMessages.isEmpty)
        #expect(attempt.exchange.opaqueControlDatagrams.count == 1)
        #expect(attempt.exchange.opaqueControlDatagrams[0].payloadLength == 7)
        #expect(attempt.exchange.bytesTransferred == 7)
    }
}

@Test
func lolaOutgoingUdpPreservesOpaqueDatagramEvidenceWhenDeadlineExpires() throws {
    final class OpaqueThenTimeoutTransport: LoLaOutgoingControlTransport {
        var sentMessages: [String] = []
        var receiveCalls = 0

        func prepare(configuration: ExternalConnectorSessionConfiguration) throws {}

        func send(_ message: String, host: String, port: UInt16) throws -> Int {
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
            receiveCalls += 1
            if receiveCalls == 1 {
                let payload: [UInt8] = [0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd]
                return LoLaReceivedControlMessage(
                    message: String(decoding: payload, as: UTF8.self),
                    senderHost: "203.0.113.20",
                    senderPort: destinationPort,
                    bytesTransferred: payload.count,
                    opaqueDatagram: .classify(
                        payload: payload,
                        sourceHost: "203.0.113.20",
                        sourcePort: destinationPort,
                        destinationPort: destinationPort
                    )
                )
            }
            return LoLaReceivedControlMessage(
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
                    runtimeError: ExternalConnectorSessionError.receiveTimedOut
                )
            )
        }
    }

    let configuration = ExternalConnectorSessionConfiguration(.init(
        connector: .lola,
        role: .tx,
        peer: "203.0.113.20",
        outputPath: "/tmp/lola-outgoing-opaque-timeout.json"
    ) { input in
        input.localHost = "203.0.113.10"
        input.dryRun = false
        input.durationSeconds = 1
        input.controlPort = 7_000
        input.sessionID = "42"
    })
    let attempt = try sendLoLaControlAttempt(
        configuration: configuration,
        transport: OpaqueThenTimeoutTransport()
    )

    #expect(attempt.runtimeError?.contains("receiveTimedOut") == true)
    #expect(attempt.exchange.receivedMessages.isEmpty)
    #expect(attempt.exchange.opaqueControlDatagrams.count == 1)
    #expect(attempt.exchange.opaqueControlDatagrams[0].payloadLength == 7)
    #expect(attempt.exchange.bytesTransferred == (2 * lolaControlDatagramByteCount) + 7)
}

@Test
func lolaIncomingUdpRefreshesTheHandshakeDeadlineAfterDelayedStatus() async throws {
    try await SocketHeavyTestGate.shared.run {
        let controlPort = try freeLoLaHandshakeUdpPort()
        let configuration = ExternalConnectorSessionConfiguration(.init(
            connector: .lola,
            role: .rx,
            peer: "127.0.0.1",
            outputPath: "/tmp/lola-incoming-delayed-status.json"
        ) { input in
            input.localHost = "127.0.0.1"
            input.dryRun = false
            input.durationSeconds = 1
            input.controlPort = controlPort
            input.sessionID = "42"
        })
        let ready = DispatchSemaphore(value: 0)
        async let peer = delayedStatusThenQuickConnectIncomingUdpPeer(port: controlPort, ready: ready)
        try waitForLoLaHandshakePeerReady(ready)
        let attempt = try runLoLaControlExchangeAttempt(configuration: configuration)
        let requesterPort = try await peer

        #expect(requesterPort != 0)
        #expect(attempt.runtimeError == nil)
        #expect(attempt.exchange.parsedMessageName == "/MESG_QUICKCONN")
        #expect(attempt.exchange.sentMessages.count == 2)
    }
}

@Test
func lolaIncomingUdpRejectsValidatedIncompatibleQuickConnectAtRequesterPort() async throws {
    try await SocketHeavyTestGate.shared.run {
        let controlPort = try freeLoLaHandshakeUdpPort()
        let configuration = ExternalConnectorSessionConfiguration(.init(
            connector: .lola,
            role: .rx,
            peer: "127.0.0.1",
            outputPath: "/tmp/lola-incoming-incompatible-quickconn.json"
        ) { input in
            input.localHost = "127.0.0.1"
            input.dryRun = false
            input.durationSeconds = 3
            input.controlPort = controlPort
            input.sessionID = "42"
        })
        let ready = DispatchSemaphore(value: 0)
        async let peer = incompatibleQuickConnectIncomingUdpPeer(port: controlPort, ready: ready)
        try waitForLoLaHandshakePeerReady(ready)
        let attempt = try runLoLaControlExchangeAttempt(configuration: configuration)
        let result = try await peer
        let reject = try LoLaCompatibilityControlMessage.parse(result.replies[1])

        #expect(result.requesterPort != 0)
        #expect(attempt.runtimeError?.contains("incompatible LoLa QuickConn SR:48000") == true)
        #expect(attempt.exchange.parsedMessageName == "/MESG_QUICKCONN")
        #expect(attempt.exchange.sentMessages.count == 2)
        #expect(attempt.exchange.sentMessages.last?.hasPrefix("/MESG_REJECT;") == true)
        #expect(!attempt.exchange.sentMessages.contains { $0.hasPrefix("/MESG_QUICKCONN_ACK") })
        #expect(reject.name == "/MESG_REJECT")
        #expect(reject.fields["SRCIP"] == "127.0.0.1")
        #expect(reject.fields["DSTIP"] == "127.0.0.1")
        #expect(reject.fields["SID"] == "42")
        #expect(reject.fields["TXT"]?.contains("SR:48000") == true)
    }
}

@Test
func lolaRetryResponderReturnsRejectForValidatedIncompatibleQuickConnect() throws {
    let configuration = ExternalConnectorSessionConfiguration(.init(
        connector: .lola,
        role: .rx,
        peer: "127.0.0.1",
        outputPath: "/tmp/lola-retry-incompatible-quickconn.json"
    ) { input in
        input.localHost = "127.0.0.1"
        input.sessionID = "42"
    })
    let message = LoLaCompatibilityControlMessage.quickConnect(
        loLaQuickConnectMediaFields(
            fields: [
                "SRCIP": "127.0.0.1", "DSTIP": "127.0.0.1", "SID": "42",
                "SR": "48000", "BPS": "16", "CHNLS": "2"
            ],
            senderHost: "127.0.0.1"
        )
    )
    let response = try #require(try lolaRetryResponderAck(
        configuration: configuration,
        message: message,
        parsed: try LoLaCompatibilityControlMessage.parse(message),
        senderHost: "127.0.0.1"
    ))
    let reject = try LoLaCompatibilityControlMessage.parse(response)

    #expect(reject.name == "/MESG_REJECT")
    #expect(reject.fields["TXT"]?.contains("SR:48000") == true)
    #expect(!response.hasPrefix("/MESG_QUICKCONN_ACK"))
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
