import Foundation
import Testing

@testable import OpenLolaCore

@Test
func lolaLaunchPlanUsesRecoveredControlAndMediaDefaults() throws {
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .tx,
        peer: "192.0.2.20",
        localHost: "192.0.2.10",
        outputPath: "/tmp/lola-session.json",
        sessionID: "1"
    )

    let plan = try ExternalConnectorLaunchPlan.build(configuration: configuration)

    #expect(plan.launchKind == .internalLoLaControl)
    #expect(plan.controlPort == 7000)
    #expect(plan.audioPort == 19788)
    #expect(plan.videoPort == 19798)
    #expect(plan.mediaProfile.mode == .audioVideo)
    #expect(plan.mediaProfile.audioEnabled)
    #expect(plan.mediaProfile.videoEnabled)
    #expect(plan.sampleRateHertz == 44_100)
    #expect(plan.framesPerPacket == 64)
    #expect(plan.protocolFacts.contains { $0.contains("/MESG_*") })
    #expect(plan.protocolFacts.contains { $0.contains("42-byte Ethernet/IPv4/UDP") })
    #expect(plan.protocolFacts.contains { $0.contains("variable decoded IPv4 IDs") })
    #expect(plan.sourceReferences.contains("docs/reverse-engineering/README.md"))
    #expect(plan.sourceReferences.contains("docs/background/open-lola-compatibility-scope.md"))
    #expect(plan.sourceReferences.allSatisfy { !$0.hasPrefix("private/") })
    #expect(plan.sourceReferences.allSatisfy { !$0.hasPrefix("archive/") })
}

@Test
func lolaMediaModelUsesRecoveredStaticEnvelopeFacts() throws {
    #expect(LoLaCompatibilityMediaModel.wirePayloadOffset == (
        LoLaCompatibilityMediaModel.ethernetHeaderByteCount
            + LoLaCompatibilityMediaModel.ipv4HeaderByteCount
            + LoLaCompatibilityMediaModel.udpHeaderByteCount
    ))
    #expect(LoLaCompatibilityMediaModel.wirePayloadOffset == 0x2a)
    #expect(LoLaCompatibilityMediaModel.fragmentPayloadOffset == 0x21)
    #expect(LoLaCompatibilityMediaModel.fragmentMarker == 0xeeeeeeee)
    #expect(LoLaCompatibilityMediaModel.ipv4Identification == 0x1337)
    #expect(LoLaCompatibilityMediaModel.videoRingSlotCount == 30)
    #expect(try LoLaCompatibilityMediaModel.audioPayloadByteCount(channels: 2) == 256)
    #expect(try LoLaCompatibilityMediaModel.audioWireFrameByteCount(channels: 2) == 1_108)
    #expect(try LoLaCompatibilityMediaModel.samplesPerPacketPerChannel(bitsPerSample: 16) == 64)
    #expect(LoLaCompatibilityMediaModel.mediaBpfFilter(
        sourceHost: "10.0.0.1",
        destinationHost: "10.0.0.2",
        audioPort: 19788,
        videoPort: 19798
    ) == "ip and src host 10.0.0.1 and dst host 10.0.0.2 and (udp port 19788 or udp port 19798)")
    #expect(LoLaCompatibilityMediaModel.evidenceBoundary.contains("Source-level clean-room LoLa media grammar"))
}

@Test
func lolaWireFrameRoundTripsRecoveredEthernetIPv4UdpEnvelope() throws {
    let payload = Data(repeating: 0x55, count: 256)
    let frame = try LoLaCompatibilityWireFrame(
        destinationMAC: LoLaEthernetAddress(octets: [0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]),
        sourceMAC: LoLaEthernetAddress(octets: [0x00, 0x11, 0x22, 0x33, 0x44, 0x55]),
        sourceIP: LoLaIPv4Address(octets: [192, 0, 2, 10]),
        destinationIP: LoLaIPv4Address(octets: [192, 0, 2, 20]),
        sourcePort: 19788,
        destinationPort: 19788,
        payload: payload
    )

    let encoded = try frame.encoded()
    let decoded = try LoLaCompatibilityWireFrame.decode(encoded)

    #expect(encoded.count == LoLaCompatibilityMediaModel.wirePayloadOffset + payload.count)
    #expect(encoded[12] == 0x08)
    #expect(encoded[13] == 0x00)
    #expect(encoded[14] == 0x45)
    #expect(encoded[18] == 0x13)
    #expect(encoded[19] == 0x37)
    #expect(encoded[23] == 0x11)
    #expect(encoded[34] == 0x4d)
    #expect(encoded[35] == 0x4c)
    #expect(encoded[42] == 0x55)
    #expect(decoded == frame)
}

@Test
func lolaWireFrameDecodeAcceptsEthernetPadding() throws {
    let payload = Data([0x10, 0x20, 0x30, 0x40])
    let frame = try LoLaCompatibilityWireFrame(
        destinationMAC: LoLaEthernetAddress(octets: [0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]),
        sourceMAC: LoLaEthernetAddress(octets: [0x00, 0x11, 0x22, 0x33, 0x44, 0x55]),
        sourceIP: LoLaIPv4Address(octets: [192, 0, 2, 10]),
        destinationIP: LoLaIPv4Address(octets: [192, 0, 2, 20]),
        sourcePort: 19788,
        destinationPort: 19788,
        payload: payload
    )
    var padded = try frame.encoded()
    padded.append(Data(repeating: 0, count: 64 - padded.count))

    let decoded = try LoLaCompatibilityWireFrame.decode(padded)

    #expect(padded.count == 64)
    #expect(decoded.payload == payload)
    #expect(decoded == frame)
}

@Test
func lolaWireFrameAcceptsNonRecoveredIPv4Identification() throws {
    let frame = try LoLaCompatibilityWireFrame(
        destinationMAC: LoLaEthernetAddress(octets: [0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]),
        sourceMAC: LoLaEthernetAddress(octets: [0x00, 0x11, 0x22, 0x33, 0x44, 0x55]),
        sourceIP: LoLaIPv4Address(octets: [192, 0, 2, 10]),
        destinationIP: LoLaIPv4Address(octets: [192, 0, 2, 20]),
        sourcePort: 19788,
        destinationPort: 19798,
        payload: Data(repeating: 0, count: 128)
    )
    var encoded = try frame.encoded()
    encoded[18] = 0x99
    encoded[19] = 0x99
    encoded[24] = 0
    encoded[25] = 0
    let checksum = testIPv4Checksum([UInt8](encoded[14..<34]))
    encoded[24] = UInt8(checksum >> 8)
    encoded[25] = UInt8(checksum & 0xff)

    let decoded = try LoLaCompatibilityWireFrame.decode(encoded)

    #expect(decoded == frame)
}

private func testIPv4Checksum(_ bytes: [UInt8]) -> UInt16 {
    var sum: UInt32 = 0
    var index = 0
    while index + 1 < bytes.count {
        sum += UInt32(UInt16(bytes[index]) << 8 | UInt16(bytes[index + 1]))
        index += 2
    }
    if index < bytes.count {
        sum += UInt32(UInt16(bytes[index]) << 8)
    }
    while (sum >> 16) != 0 {
        sum = (sum & 0xffff) + (sum >> 16)
    }
    return UInt16(~sum & 0xffff)
}

@Test
func lolaMediaModelRejectsInvalidAudioSizingInputs() throws {
    #expect(throws: ExternalConnectorSessionError.invalidPositiveInteger("channels", "0")) {
        _ = try LoLaCompatibilityMediaModel.audioPayloadByteCount(channels: 0)
    }
    #expect(throws: ExternalConnectorSessionError.invalidPositiveInteger("channels", "257")) {
        _ = try LoLaCompatibilityMediaModel.audioPayloadByteCount(channels: 257)
    }
    #expect(throws: ExternalConnectorSessionError.invalidPositiveInteger("bitsPerSample", "7")) {
        _ = try LoLaCompatibilityMediaModel.samplesPerPacketPerChannel(bitsPerSample: 7)
    }
}

@Test
func lolaQuickConnectMessageUsesRecoveredFields() throws {
    let message = LoLaCompatibilityControlMessage.quickConnect(
        sourceIP: "192.0.2.10",
        destinationIP: "192.0.2.20",
        sessionID: 1,
        sampleRateHertz: 44_100,
        bitsPerSample: 16,
        channels: 2
    )

    let parsed = try LoLaCompatibilityControlMessage.parse(message)

    #expect(message.contains("SRCIP:192.0.2.10"))
    #expect(!message.contains("SRCIP=192.0.2.10"))
    #expect(!message.hasSuffix(";"))
    #expect(parsed.name == "/MESG_QUICKCONN")
    #expect(parsed.fields["SRCIP"] == "192.0.2.10")
    #expect(parsed.fields["DSTIP"] == "192.0.2.20")
    #expect(parsed.fields["SID"] == "1")
    #expect(parsed.fields["SR"] == "44100")
    #expect(parsed.fields["BPS"] == "16")
    #expect(parsed.fields["CHNLS"] == "2")
}

@Test
func lolaStatusMessagesUseRecoveredFields() throws {
    let status = LoLaCompatibilityControlMessage.checkStatus(
        sourceIP: "192.0.2.10",
        destinationIP: "192.0.2.20",
        sessionID: 1
    )
    let ack = LoLaCompatibilityControlMessage.checkStatusAck(
        sourceIP: "192.0.2.20",
        destinationIP: "192.0.2.10",
        sessionID: 1
    )

    let parsedStatus = try LoLaCompatibilityControlMessage.parse(status)
    let parsedAck = try LoLaCompatibilityControlMessage.parse(ack)

    #expect(parsedStatus.name == "/MESG_CHECKLOLASTATUS")
    #expect(status.hasSuffix(";"))
    #expect(ack.hasSuffix(";"))
    #expect(parsedStatus.fields["SRCIP"] == "192.0.2.10")
    #expect(parsedStatus.fields["DSTIP"] == "192.0.2.20")
    #expect(parsedStatus.fields["SID"] == "1")
    #expect(parsedAck.name == "/MESG_CHECKLOLASTATUS_ACK")
    #expect(parsedAck.fields["SRCIP"] == "192.0.2.20")
    #expect(parsedAck.fields["DSTIP"] == "192.0.2.10")
    #expect(parsedAck.fields["SID"] == "1")
}

@Test
func lolaControlParserRejectsUnknownMessageKinds() {
    #expect(throws: ExternalConnectorSessionError.malformedLoLaControlMessage(
        "/MESG_UNKNOWN;SRCIP:192.0.2.10;DSTIP:192.0.2.20;SID:1"
    )) {
        _ = try LoLaCompatibilityControlMessage.parse(
            "/MESG_UNKNOWN;SRCIP:192.0.2.10;DSTIP:192.0.2.20;SID:1"
        )
    }
}

@Test
func lolaQuickConnectMessageCarriesVideoCapabilityFields() throws {
    let message = LoLaCompatibilityControlMessage.quickConnect(
        sourceIP: "192.0.2.10",
        destinationIP: "192.0.2.20",
        sessionID: 1,
        sampleRateHertz: 44_100,
        bitsPerSample: 16,
        channels: 2,
        videoFrameRate: 30,
        videoBitsPerPixel: 24,
        videoWidth: 1920,
        videoHeight: 1080
    )

    let parsed = try LoLaCompatibilityControlMessage.parse(message)

    #expect(parsed.fields["FPS"] == "30")
    #expect(parsed.fields["BPP"] == "24")
    #expect(parsed.fields["X"] == "1920")
    #expect(parsed.fields["Y"] == "1080")
}

@Test
func lolaQuickConnectAckMessageCarriesReceivedMediaFields() throws {
    let message = LoLaCompatibilityControlMessage.quickConnectAck(
        sourceIP: "192.0.2.20",
        destinationIP: "192.0.2.10",
        sessionID: 1,
        sampleRateHertz: 44_100,
        bitsPerSample: 16,
        channels: 2,
        videoFrameRate: 60,
        videoBitsPerPixel: 24,
        videoWidth: 1280,
        videoHeight: 720
    )

    let parsed = try LoLaCompatibilityControlMessage.parse(message)

    #expect(parsed.name == "/MESG_QUICKCONN_ACK")
    #expect(parsed.fields["SRCIP"] == "192.0.2.20")
    #expect(parsed.fields["DSTIP"] == "192.0.2.10")
    #expect(parsed.fields["SID"] == "1")
    #expect(parsed.fields["FPS"] == "60")
    #expect(parsed.fields["X"] == "1280")
    #expect(parsed.fields["Y"] == "720")
}

@Test
func lolaControlMessagesCoverVisibleRecoveredTemplates() throws {
    let reject = LoLaCompatibilityControlMessage.reject(
        sourceIP: "192.0.2.20",
        destinationIP: "192.0.2.10",
        sessionID: 7,
        text: "busy"
    )
    let disconnect = LoLaCompatibilityControlMessage.disconnect(
        sourceIP: "192.0.2.20",
        destinationIP: "192.0.2.10",
        sessionID: 7
    )
    let switchOn = LoLaCompatibilityControlMessage.switchOnBounceBack(
        sourceIP: "192.0.2.20",
        destinationIP: "192.0.2.10",
        sessionID: 7
    )
    let switchOff = LoLaCompatibilityControlMessage.switchOffBounceBack(
        sourceIP: "192.0.2.20",
        destinationIP: "192.0.2.10",
        sessionID: 7
    )
    let chat = LoLaCompatibilityControlMessage.chat(
        sourceIP: "192.0.2.20",
        destinationIP: "192.0.2.10",
        sessionID: 7,
        text: "ready"
    )
    let sendSignal = LoLaCompatibilityControlMessage.sendAudioSignal(
        sourceIP: "192.0.2.20",
        destinationIP: "192.0.2.10",
        sessionID: 7
    )
    let stopSignal = LoLaCompatibilityControlMessage.stopAudioSignal(
        sourceIP: "192.0.2.20",
        destinationIP: "192.0.2.10",
        sessionID: 7
    )

    #expect(reject == "/MESG_REJECT;SRCIP:192.0.2.20;DSTIP:192.0.2.10;SID:7;TXT:busy")
    #expect(disconnect == "/MESG_DISCONNECT;SRCIP:192.0.2.20;DSTIP:192.0.2.10;SID:7;")
    #expect(switchOn == "/MESG_SWITCH_ON_BB;SRCIP:192.0.2.20;DSTIP:192.0.2.10;SID:7;")
    #expect(switchOff == "/MESG_SWITCH_OFF_BB;SRCIP:192.0.2.20;DSTIP:192.0.2.10;SID:7;")
    #expect(chat == "/MESG_CHAT;SRCIP:192.0.2.20;DSTIP:192.0.2.10;SID:7;TXT:ready")
    #expect(sendSignal == "/MESG_SEND_AUDIO_SIGNAL;SRCIP:192.0.2.20;DSTIP:192.0.2.10;SID:7")
    #expect(stopSignal == "/MESG_STOP_AUDIO_SIGNAL;SRCIP:192.0.2.20;DSTIP:192.0.2.10;SID:7")
    #expect(try LoLaCompatibilityControlMessage.parse(reject).fields["TXT"] == "busy")
    #expect(try LoLaCompatibilityControlMessage.parse(chat).fields["TXT"] == "ready")
}

@Test
func lolaSessionParserAcceptsRawLinkMediaOptions() throws {
    let configuration = try ExternalConnectorSessionConfiguration.parse([
        "--connector", "lola",
        "--role", "tx",
        "--peer", "192.0.2.20",
        "--local-host", "192.0.2.10",
        "--output", "/tmp/lola-raw-session.json",
        "--raw-link-interface", "en0",
        "--source-mac", "02:4c:6f:4c:61:00",
        "--destination-mac", "aa:bb:cc:dd:ee:ff",
        "--media-packets", "2",
    ])

    #expect(configuration.rawLinkInterface == "en0")
    #expect(configuration.sourceMAC?.octets == [0x02, 0x4c, 0x6f, 0x4c, 0x61, 0x00])
    #expect(configuration.destinationMAC?.octets == [0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff])
    #expect(configuration.mediaPacketCount == 2)
}

@Test
func lolaSessionRawLinkDryRunCarriesMediaFramesThroughSessionReport() throws {
    let report = try ExternalConnectorSessionRunner.run(configuration: ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .tx,
        peer: "192.0.2.20",
        localHost: "192.0.2.10",
        outputPath: "/tmp/lola-raw-session.json",
        dryRun: true,
        mediaMode: .audioVideo,
        videoWidth: 16,
        videoHeight: 16,
        videoBitsPerPixel: 8,
        rawLinkInterface: "en0",
        sourceMAC: try LoLaEthernetAddress(octets: [0x02, 0x4c, 0x6f, 0x4c, 0x61, 0x00]),
        destinationMAC: try LoLaEthernetAddress(octets: [0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]),
        mediaPacketCount: 2
    ))

    try report.validate()
    #expect(report.dryRun)
    #expect(report.lolaMedia?.id == "lola-raw-link-tx-en0")
    #expect(report.lolaMedia?.audioFrameCount == 2)
    #expect(report.lolaMedia?.videoFrameCount == 4)
    #expect(report.lolaMedia?.realLinkTransmitted == false)
    #expect(try LoLaCompatibilityWireFrame.decode(report.lolaMedia?.frames[0].encodedFrame ?? Data()).destinationMAC.octets == [
        0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff,
    ])
    #expect(report.plan.arguments.contains("--raw-link-interface"))
    #expect(report.plan.protocolFacts.contains { $0.contains("macOS BPF raw-link runner") })
}
