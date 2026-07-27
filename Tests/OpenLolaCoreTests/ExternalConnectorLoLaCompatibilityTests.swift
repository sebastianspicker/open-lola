// Verifies that LoLa launch plan uses recovered control and media defaults.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func lolaLaunchPlanUsesRecoveredControlAndMediaDefaults() throws {
    let configuration = ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .tx,
  peer: "192.0.2.20",
  outputPath: "/tmp/lola-session.json"
) { input in
  input.localHost = "192.0.2.10"
  input.sessionID = "1"
})

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
    #expect(plan.sourceReferences.contains("docs/reverse-engineering-boundary.md"))
    #expect(plan.sourceReferences.contains("docs/compatibility-scope.md"))
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
func lolaWireFrameRoundTripsRecoveredEnvelope() throws {
 let payload = Data(repeating: 0x55, count: 256)
 let frame = try testLoLaWireFrame(payload: payload)

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
func lolaWireFrameAcceptsZeroEnvelopePaddingAndRejectsNonZeroTrailingBytes() throws {
 let paddedPayload = Data([0x10, 0x20, 0x30, 0x40])
 let paddedFrame = try testLoLaWireFrame(payload: paddedPayload)
 var padded = try paddedFrame.encoded()
 padded.append(Data(repeating: 0, count: 64 - padded.count))

 let decodedPadded = try LoLaCompatibilityWireFrame.decode(padded)

 #expect(padded.count == 64)
 #expect(decodedPadded.payload == paddedPayload)
 #expect(decodedPadded == paddedFrame)

 var nonZeroTrailing = try paddedFrame.encoded()
 nonZeroTrailing.append(0x99)

 #expect(throws: LoLaCompatibilityWireFrameError.nonZeroTrailingBytes(
 expectedEndOffset: nonZeroTrailing.count - 1,
 actualByteCount: nonZeroTrailing.count
 )) {
 _ = try LoLaCompatibilityWireFrame.decode(nonZeroTrailing)
 }
}

@Test
func lolaWireFrameIgnoresVariableIPv4Identification() throws {
 let variableIDFrame = try testLoLaWireFrame(
 payload: Data(repeating: 0, count: 128),
 destinationPort: 19798
 )
 var variableIDEncoded = try variableIDFrame.encoded()
 variableIDEncoded[18] = 0x99
 variableIDEncoded[19] = 0x99
 variableIDEncoded[24] = 0
 variableIDEncoded[25] = 0
 let checksum = testIPv4Checksum([UInt8](variableIDEncoded[14..<34]))
 variableIDEncoded[24] = UInt8(checksum >> 8)
 variableIDEncoded[25] = UInt8(checksum & 0xff)

 let decodedVariableID = try LoLaCompatibilityWireFrame.decode(variableIDEncoded)

 #expect(decodedVariableID == variableIDFrame)
}

func testLoLaWireFrame(
    payload: Data,
    destinationPort: UInt16 = 19788,
    sourcePort: UInt16 = 19788
) throws -> LoLaCompatibilityWireFrame {
 try LoLaCompatibilityWireFrame(
 destinationMAC: LoLaEthernetAddress(octets: [0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]),
 sourceMAC: LoLaEthernetAddress(octets: [0x00, 0x11, 0x22, 0x33, 0x44, 0x55]),
 sourceIP: LoLaIPv4Address(octets: [192, 0, 2, 10]),
 destinationIP: LoLaIPv4Address(octets: [192, 0, 2, 20]),
   sourcePort: sourcePort,
 destinationPort: destinationPort,
 payload: payload
 )
}

private func testIPv4Checksum(_ bytes: [UInt8]) -> UInt16 {
    var sum: UInt32 = 0
    for (offset, byte) in bytes.enumerated() {
        let shift = offset.isMultiple(of: 2) ? 8 : 0
        sum += UInt32(byte) << UInt32(shift)
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
func lolaQuickConnectControlMessageUsesRecoveredTemplate() throws {
 let quickConnect = LoLaCompatibilityControlMessage.quickConnect(LoLaCompatibilityMediaFields(
 session: LoLaControlSessionFields(
 sourceIP: "192.0.2.10",
 destinationIP: "192.0.2.20",
 sessionID: 1
 ),
 audio: LoLaCompatibilityAudioFields(
 sampleRateHertz: 44_100,
 bitsPerSample: 16,
 channels: 2
 )
 ))

 let parsedQuickConnect = try LoLaCompatibilityControlMessage.parse(quickConnect)

 #expect(quickConnect.contains("SRCIP:192.0.2.10"))
 #expect(!quickConnect.contains("SRCIP=192.0.2.10"))
 #expect(!quickConnect.hasSuffix(";"))
 #expect(parsedQuickConnect.name == "/MESG_QUICKCONN")
 #expect(parsedQuickConnect.fields["SRCIP"] == "192.0.2.10")
 #expect(parsedQuickConnect.fields["DSTIP"] == "192.0.2.20")
 #expect(parsedQuickConnect.fields["SID"] == "1")
 #expect(parsedQuickConnect.fields["SR"] == "44100")
 #expect(parsedQuickConnect.fields["BPS"] == "16")
 #expect(parsedQuickConnect.fields["CHNLS"] == "2")
}

@Test
func lolaStatusControlMessagesUseRecoveredTemplatesAndRejectUnknownKinds() throws {
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

 #expect(throws: ExternalConnectorSessionError.malformedLoLaControlMessage(
 "/MESG_UNKNOWN;SRCIP:192.0.2.10;DSTIP:192.0.2.20;SID:1"
 )) {
 _ = try LoLaCompatibilityControlMessage.parse(
 "/MESG_UNKNOWN;SRCIP:192.0.2.10;DSTIP:192.0.2.20;SID:1"
 )
 }
}

@Test
func lolaVideoQuickConnectControlMessageUsesRecoveredTemplate() throws {
 let videoQuickConnect = LoLaCompatibilityControlMessage.quickConnect(LoLaCompatibilityMediaFields(
 session: LoLaControlSessionFields(
 sourceIP: "192.0.2.10",
 destinationIP: "192.0.2.20",
 sessionID: 1
 ),
 audio: LoLaCompatibilityAudioFields(
 sampleRateHertz: 44_100,
 bitsPerSample: 16,
 channels: 2
 ),
 video: LoLaCompatibilityVideoFields(
 frameRate: 30,
 bitsPerPixel: 24,
 dimensions: LoLaCompatibilityVideoDimensions(width: 1920, height: 1080)
 )
 ))

 let parsedVideoQuickConnect = try LoLaCompatibilityControlMessage.parse(videoQuickConnect)

 #expect(parsedVideoQuickConnect.fields["FPS"] == "30")
 #expect(parsedVideoQuickConnect.fields["BPP"] == "24")
 #expect(parsedVideoQuickConnect.fields["X"] == "1920")
 #expect(parsedVideoQuickConnect.fields["Y"] == "1080")
}

@Test
func lolaQuickConnectAckControlMessageUsesRecoveredTemplate() throws {
 let quickConnectAck = LoLaCompatibilityControlMessage.quickConnectAck(LoLaCompatibilityMediaFields(
 session: LoLaControlSessionFields(
 sourceIP: "192.0.2.20",
 destinationIP: "192.0.2.10",
 sessionID: 1
 ),
 audio: LoLaCompatibilityAudioFields(
 sampleRateHertz: 44_100,
 bitsPerSample: 16,
 channels: 2
 ),
 video: LoLaCompatibilityVideoFields(
 frameRate: 60,
 bitsPerPixel: 24,
 dimensions: LoLaCompatibilityVideoDimensions(width: 1280, height: 720)
 )
 ))

 let parsedQuickConnectAck = try LoLaCompatibilityControlMessage.parse(quickConnectAck)

 #expect(parsedQuickConnectAck.name == "/MESG_QUICKCONN_ACK")
 #expect(parsedQuickConnectAck.fields["SRCIP"] == "192.0.2.20")
 #expect(parsedQuickConnectAck.fields["DSTIP"] == "192.0.2.10")
 #expect(parsedQuickConnectAck.fields["SID"] == "1")
 #expect(parsedQuickConnectAck.fields["FPS"] == "60")
 #expect(parsedQuickConnectAck.fields["X"] == "1280")
 #expect(parsedQuickConnectAck.fields["Y"] == "720")
}

@Test
func lolaSessionControlMessagesUseRecoveredTemplates() throws {
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
        "--media-packets", "2"
    ])

    #expect(configuration.rawLinkInterface == "en0")
    #expect(configuration.sourceMAC?.octets == [0x02, 0x4c, 0x6f, 0x4c, 0x61, 0x00])
    #expect(configuration.destinationMAC?.octets == [0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff])
    #expect(configuration.mediaPacketCount == 2)
}
@Test
func lolaSessionRawLinkDryRunCarriesMediaFramesThroughSessionReport() throws {
    let sourceMAC = try LoLaEthernetAddress(octets: [0x02, 0x4c, 0x6f, 0x4c, 0x61, 0x00])
    let destinationMAC = try LoLaEthernetAddress(octets: [0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff])
    let report = try ExternalConnectorSessionRunner.run(configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .tx,
  peer: "192.0.2.20",
  outputPath: "/tmp/lola-raw-session.json"
) { input in
  input.localHost = "192.0.2.10"
  input.dryRun = true
  input.mediaMode = .audioVideo
  input.videoWidth = 16
  input.videoHeight = 16
  input.videoBitsPerPixel = 8
  input.rawLinkInterface = "en0"
  input.sourceMAC = sourceMAC
  input.destinationMAC = destinationMAC
  input.mediaPacketCount = 2
}))

    try report.validate()
    #expect(report.dryRun)
    #expect(report.lolaMedia?.id == "lola-raw-link-tx-en0")
    #expect(report.lolaMedia?.audioFrameCount == 2)
    #expect(report.lolaMedia?.videoFrameCount == 4)
    #expect(report.lolaMedia?.realLinkTransmitted == false)
    let decodedDestinationMAC = try LoLaCompatibilityWireFrame
        .decode(report.lolaMedia?.frames[0].encodedFrame ?? Data())
        .destinationMAC
        .octets
    #expect(decodedDestinationMAC == [
        0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff
    ])
    #expect(report.plan.arguments.contains("--raw-link-interface"))
    #expect(report.plan.protocolFacts.contains { $0.contains("macOS BPF raw-link runner") })
}
