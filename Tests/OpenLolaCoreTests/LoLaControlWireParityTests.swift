// Verifies ASCII LoLa control framing against the connector protocol oracle.
import Testing

@testable import OpenLolaCore

@Test
func lolaControlTextEscapesPunctuationWithoutAcceptingRawTXTDelimiters() throws {
    let text = "ready; wait: 50%"
    let message = LoLaCompatibilityControlMessage.chat(
        sourceIP: "192.0.2.20",
        destinationIP: "192.0.2.10",
        sessionID: 7,
        text: text
    )

    #expect(message.hasSuffix("TXT:ready%3B wait%3A 50%25"))
    #expect(try LoLaCompatibilityControlMessage.parse(message).fields["TXT"] == text)
    #expect(throws: (any Error).self) {
        _ = try LoLaCompatibilityControlMessage.parse(
            "/MESG_CHAT;SRCIP:192.0.2.20;DSTIP:192.0.2.10;SID:7;TXT:ready; wait"
        )
    }
}

@Test
func lolaControlParserRequiresCanonicalSIDAndUniqueASCIIFields() throws {
    let canonical = try LoLaCompatibilityControlMessage.parse(
        "/MESG_CHECKLOLASTATUS;SRCIP:192.0.2.20;DSTIP:192.0.2.10;SID:+0007;"
    )

    #expect(canonical.fields["SID"] == "7")
    for message in [
        "/MESG_CHECKLOLASTATUS;SRCIP:192.0.2.20;SRCIP:192.0.2.21;SID:7",
        "/MESG_CHECKLOLASTATUS;SRCIP:192.0.2.20;DSTIP:192.0.2.10",
        "/MESG_CHECKLOLASTATUS;SRCIP:192.0.2.20;DSTIP:192.0.2.10;SID:+",
        "/MESG_CHAT;SRCIP:192.0.2.20;DSTIP:192.0.2.10;SID:7;TXT:café",
        "/MESG_QUICKCONN;SRCIP:192.0.2.20;DSTIP:192.0.2.10;SID:7;SR:44100;BPS:16;CHNLS:2"
    ] {
        #expect(throws: (any Error).self) {
            _ = try LoLaCompatibilityControlMessage.parse(message)
        }
    }
}

@Test
func lolaControlDatagramsAreASCIIAndExactlyBoundedWithoutTruncation() throws {
    let message = "/MESG_CHECKLOLASTATUS;SRCIP:192.0.2.20;DSTIP:192.0.2.10;SID:7;"
    let datagram = try lolaControlDatagramBytes(message)

    #expect(datagram.count == lolaControlDatagramByteCount)
    #expect(Array(datagram.prefix(message.utf8.count)) == Array(message.utf8))
    #expect(datagram[message.utf8.count] == 0)
    #expect(throws: (any Error).self) {
        _ = try lolaControlDatagramBytes(message + String(repeating: "x", count: lolaControlDatagramByteCount))
    }
    #expect(throws: (any Error).self) {
        _ = try lolaControlDatagramBytes(message + "café")
    }
}

@Test(arguments: ["SR", "BPS", "CHNLS"])
func lolaQuickConnectRejectsIncompatibleAudioInsteadOfMirroringIt(_ changedField: String) throws {
    let configuration = ExternalConnectorSessionConfiguration(.init(
        connector: .lola,
        role: .rx,
        peer: "192.0.2.20",
        outputPath: "/tmp/lola-wire-parity.json"
    ) { input in
        input.localHost = "192.0.2.10"
        input.sampleRateHertz = 44_100
        input.channels = 2
        input.sessionID = "7"
    })
    var receivedFields = [
        "SRCIP": "192.0.2.20",
        "DSTIP": "192.0.2.10",
        "SID": "7",
        "SR": "44100",
        "BPS": "16",
        "CHNLS": "2"
    ]
    receivedFields[changedField] = changedField == "SR" ? "48000" : "1"

    #expect(throws: (any Error).self) {
        _ = try lolaQuickConnectAck(
            configuration: configuration,
            receivedFields: receivedFields,
            senderHost: "192.0.2.20"
        )
    }
}

@Test
func lolaQuickConnectAckUsesLocalCompatibleAudioSettings() throws {
    let configuration = ExternalConnectorSessionConfiguration(.init(
        connector: .lola,
        role: .rx,
        peer: "192.0.2.20",
        outputPath: "/tmp/lola-wire-parity.json"
    ) { input in
        input.localHost = "192.0.2.10"
        input.sampleRateHertz = 44_100
        input.channels = 2
        input.sessionID = "7"
    })
    let ack = try lolaQuickConnectAck(
        configuration: configuration,
        receivedFields: [
            "SRCIP": "192.0.2.20",
            "DSTIP": "192.0.2.10",
            "SID": "7",
            "SR": "44100",
            "BPS": "16",
            "CHNLS": "2"
        ],
        senderHost: "192.0.2.20"
    )
    let parsed = try LoLaCompatibilityControlMessage.parse(ack)

    #expect(parsed.fields["SR"] == "44100")
    #expect(parsed.fields["BPS"] == "16")
    #expect(parsed.fields["CHNLS"] == "2")
}
