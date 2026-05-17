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
func lolaMediaReceiveReportFailsMalformedPayloadInsideValidEnvelope() throws {
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .rx,
        peer: "192.0.2.20",
        localHost: "192.0.2.10",
        outputPath: "/tmp/lola-media-malformed-rx.json",
        mediaMode: .audioVideo,
        videoWidth: 16,
        videoHeight: 16,
        videoBitsPerPixel: 8
    )
    let malformedWireFrame = try LoLaCompatibilityWireFrame(
        destinationMAC: LoLaEthernetAddress(octets: [0xff, 0xff, 0xff, 0xff, 0xff, 0xff]),
        sourceMAC: LoLaEthernetAddress(octets: [0x02, 0x4c, 0x6f, 0x4c, 0x61, 0x00]),
        sourceIP: LoLaIPv4Address(octets: [192, 0, 2, 20]),
        destinationIP: LoLaIPv4Address(octets: [192, 0, 2, 10]),
        sourcePort: configuration.audioPort,
        destinationPort: configuration.audioPort,
        payload: Data([0xfd, 0xfd, 0xfd])
    ).encoded()

    let report = try LoLaCompatibilityMediaSession.receiveReport(
        configuration: configuration,
        encodedFrames: [malformedWireFrame]
    )

    try report.validate()
    #expect(report.verdict == .fail)
    #expect(report.runtimeError == "malformed LoLa media payloads: 1")
    #expect(report.envelopeValidatedFrameCount == 1)
    #expect(report.malformedFrameCount == 1)
    #expect(report.frames.first?.packetKind == .malformedFragment)
    #expect(report.frames.first?.payloadConfidence.contains("malformed") == true)
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
