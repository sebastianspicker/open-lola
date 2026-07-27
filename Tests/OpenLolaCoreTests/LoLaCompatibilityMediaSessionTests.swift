// Verifies that LoLa media session builds audio-video transmit frames with recovered envelopes.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func lolaMediaSessionBuildsAudioVideoTransmitFramesWithRecoveredEnvelope() throws {
    let configuration = ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .tx,
  peer: "192.0.2.20",
  outputPath: "/tmp/lola-media-tx.json"
) { input in
  input.localHost = "192.0.2.10"
  input.mediaMode = .audioVideo
  input.channels = 2
  input.videoWidth = 16
  input.videoHeight = 16
  input.videoBitsPerPixel = 8
})

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
    let configuration = ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .tx,
  peer: "192.0.2.20",
  outputPath: "/tmp/lola-media-report.json"
) { input in
  input.localHost = "192.0.2.10"
  input.mediaMode = .audioVideo
  input.videoWidth = 16
  input.videoHeight = 16
  input.videoBitsPerPixel = 8
})

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
    let configuration = ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .rx,
  peer: "192.0.2.20",
  outputPath: "/tmp/lola-media-malformed-rx.json"
) { input in
  input.localHost = "192.0.2.10"
  input.mediaMode = .audioVideo
  input.videoWidth = 16
  input.videoHeight = 16
  input.videoBitsPerPixel = 8
})
    let malformedWireFrame = try lolaCompatibilityTestWireFrame(
        payload: Data([0xfd, 0xfd, 0xfd]),
        sourcePort: configuration.audioPort,
        destinationPort: configuration.audioPort
    )

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
        configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .tx,
  peer: "192.0.2.20",
  outputPath: "/tmp/lola-media-pass.json"
) { input in
  input.localHost = "192.0.2.10"
})
    )
    report.verdict = .pass

    #expect(throws: ExternalConnectorSessionError.dryRunCannotPass) {
        try report.validate()
    }
}
