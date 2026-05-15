import Foundation
import Testing

@testable import OpenLolaCore

@Test
func lolaMediaSessionBuildsAudioVideoTransmitFramesWithRecoveredEnvelope() throws {
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .tx,
        peer: "192.0.2.20",
        localHost: "192.0.2.10",
        outputPath: "/tmp/lola-media-tx.json",
        mediaMode: .audioVideo,
        channels: 2,
        videoWidth: 16,
        videoHeight: 16,
        videoBitsPerPixel: 8
    )

    let frames = try LoLaCompatibilityMediaSession.buildTransmitFrames(
        configuration: configuration,
        frameCountPerStream: 1
    )

    #expect(frames.count == 3)
    #expect(frames[0].stream == .audio)
    #expect(frames[0].packetKind == .audioFragment)
    #expect(frames[0].sourcePort == 19788)
    #expect(frames[0].payloadByteCount == 1066)
    #expect(frames[0].envelopeValidated)
    #expect(frames[0].payloadConfidence.contains("recovered audio fragment"))
    #expect(frames[1].stream == .video)
    #expect(frames[1].packetKind == .videoPrelude)
    #expect(frames[1].sourcePort == 19798)
    #expect(frames[1].envelopeValidated)
    #expect(frames[1].payloadConfidence.contains("recovered video prelude"))
    #expect(frames[2].stream == .video)
    #expect(frames[2].packetKind == .videoFragment)
    #expect(frames[2].fragmentIndex == 0)
    #expect(frames[2].finalFragment == true)
}

@Test
func lolaVideoProbeSendsPreludeBeforeRecoveredFragments() throws {
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .tx,
        peer: "192.0.2.20",
        localHost: "192.0.2.10",
        outputPath: "/tmp/lola-video-probe.json",
        mediaMode: .video,
        videoWidth: 16,
        videoHeight: 16,
        videoBitsPerPixel: 8
    )

    let frame = try #require(LoLaCompatibilityMediaSession.buildTransmitFrames(
        configuration: configuration,
        frameCountPerStream: 1
    ).first)
    let decoded = try LoLaCompatibilityWireFrame.decode(frame.encodedFrame)

    #expect(frame.stream == LoLaCompatibilityMediaStream.video)
    #expect(frame.packetKind == .videoPrelude)
    #expect(decoded.payload.count == 0x40)
    #expect(decoded.payload[0..<12] == Data([
        0xfd, 0xfd, 0xfd, 0xfd,
        0xdf, 0xdf, 0xdf, 0xdf,
        0xaa, 0xaa, 0xaa, 0xaa,
    ]))
    #expect(frame.fragmentIndex == nil)
    #expect(frame.fragmentCount == 1)
    #expect(frame.payloadConfidence.contains("source-level"))
}

@Test
func lolaGeneratedVideoPayloadPathStaysDefault() throws {
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .tx,
        peer: "192.0.2.20",
        localHost: "192.0.2.10",
        outputPath: "/tmp/lola-generated-default.json",
        mediaMode: .video,
        videoWidth: 16,
        videoHeight: 16,
        videoBitsPerPixel: 8
    )
    let frames = try LoLaCompatibilityMediaSession.buildTransmitFrames(
        configuration: configuration,
        frameCountPerStream: 1
    )
    let prelude = try #require(LoLaCompatibilityMediaCodec.decode(
        LoLaCompatibilityWireFrame.decode(frames[0].encodedFrame).payload
    ).videoPrelude)
    let fragment = try #require(LoLaCompatibilityMediaCodec.decode(
        LoLaCompatibilityWireFrame.decode(frames[1].encodedFrame).payload
    ).normalFragment)
    let body = try LoLaCompatibilityMediaCodec.reassemble(prelude: prelude, fragments: [fragment])

    #expect(configuration.lolaVideoPayload == .generated)
    let expectedPayload = try LoLaVideoPayloadProvider.generatedRawVideoPayload(
        configuration: configuration,
        sequenceNumber: 0
    )
    #expect(body.payload == expectedPayload)
}

@Test
func lolaMediaSessionTransmitAndReceiveReportsStayPartial() throws {
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .tx,
        peer: "192.0.2.20",
        localHost: "192.0.2.10",
        outputPath: "/tmp/lola-media-report.json",
        mediaMode: .audioVideo,
        videoWidth: 16,
        videoHeight: 16,
        videoBitsPerPixel: 8
    )

    let txReport = try LoLaCompatibilityMediaSession.transmitReport(
        configuration: configuration,
        frameCountPerStream: 2
    )
    let rxReport = try LoLaCompatibilityMediaSession.receiveReport(
        configuration: configuration,
        encodedFrames: txReport.frames.map(\.encodedFrame)
    )

    try txReport.validate()
    try rxReport.validate()
    #expect(txReport.verdict == .partial)
    #expect(rxReport.verdict == .partial)
    #expect(!txReport.realLinkTransmitted)
    #expect(!rxReport.realLinkTransmitted)
    #expect(txReport.audioFrameCount == 2)
    #expect(txReport.videoFrameCount >= 2)
    #expect(rxReport.envelopeValidatedFrameCount == txReport.frames.count)
    #expect(rxReport.totalWireBytes == txReport.totalWireBytes)
}

@Test
func lolaMediaSessionReceiveReportsPreserveWireSourceAndDestinationHosts() throws {
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .rx,
        peer: "192.0.2.20",
        localHost: "192.0.2.10",
        outputPath: "/tmp/lola-media-rx-wire-hosts.json",
        mediaMode: .audio
    )
    let payload = try LoLaCompatibilityMediaCodec.audioFragments(sequenceNumber: 7, channels: 2)[0].payload
    let wireFrame = try LoLaCompatibilityWireFrame(
        destinationMAC: LoLaEthernetAddress(octets: [0xff, 0xff, 0xff, 0xff, 0xff, 0xff]),
        sourceMAC: LoLaEthernetAddress(octets: [0x02, 0x4c, 0x6f, 0x4c, 0x61, 0x00]),
        sourceIP: LoLaIPv4Address(octets: [198, 51, 100, 77]),
        destinationIP: LoLaIPv4Address(octets: [192, 0, 2, 10]),
        sourcePort: 19_788,
        destinationPort: 19_788,
        payload: payload
    )

    let report = try LoLaCompatibilityMediaSession.receiveReport(
        configuration: configuration,
        encodedFrames: [wireFrame.encoded()]
    )

    try report.validate()
    let frame = try #require(report.frames.first)
    #expect(frame.sourceHost == "198.51.100.77")
    #expect(frame.destinationHost == "192.0.2.10")
    #expect(frame.sourceHost != configuration.peer)
}

@Test
func lolaMediaSessionReceiveUsesConfiguredVideoPortForNormalFragments() throws {
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .tx,
        peer: "192.0.2.20",
        localHost: "192.0.2.10",
        outputPath: "/tmp/lola-media-custom-video-port.json",
        mediaMode: .video,
        videoPort: 20_001,
        videoWidth: 16,
        videoHeight: 16,
        videoBitsPerPixel: 8
    )
    let txFrames = try LoLaCompatibilityMediaSession.buildTransmitFrames(configuration: configuration)
    let rxReport = try LoLaCompatibilityMediaSession.receiveReport(
        configuration: configuration,
        encodedFrames: txFrames.map(\.encodedFrame)
    )

    try rxReport.validate()
    #expect(rxReport.videoFrameCount == 2)
    #expect(rxReport.audioFrameCount == 0)
    #expect(rxReport.frames.map(\.packetKind) == [.videoPrelude, .videoFragment])
    #expect(rxReport.frames[1].payloadConfidence.contains("video fragment"))
}

@Test
func lolaMediaSessionRejectsPassVerdict() throws {
    var report = try LoLaCompatibilityMediaSession.transmitReport(
        configuration: ExternalConnectorSessionConfiguration(
            connector: .lola,
            role: .tx,
            peer: "192.0.2.20",
            localHost: "192.0.2.10",
            outputPath: "/tmp/lola-media-pass.json"
        )
    )
    report.verdict = .pass

    #expect(throws: ExternalConnectorSessionError.dryRunCannotPass) {
        try report.validate()
    }
}
