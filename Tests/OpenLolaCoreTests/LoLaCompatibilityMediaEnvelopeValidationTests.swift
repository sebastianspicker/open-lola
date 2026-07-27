// Verifies that LoLa media receive accepts ephemeral source port when destination port matches.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func lolaMediaReceiveAcceptsEphemeralSourcePortWhenDestinationPortMatches() throws {
    let payload = try LoLaCompatibilityMediaCodec.audioFragments(sequenceNumber: 1, channels: 2)[0].payload
    let encodedFrame = try lolaCompatibilityTestWireFrame(
        payload: payload,
        sourcePort: 19_789,
        destinationPort: 19_788
    )
    let configuration = ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .rx,
  peer: "192.0.2.20",
  outputPath: "/tmp/lola-rx-port-mismatch.json"
) { input in
  input.localHost = "192.0.2.10"
  input.mediaMode = .audio
})

    let report = try LoLaCompatibilityMediaSession.receiveReport(
        configuration: configuration,
        encodedFrames: [encodedFrame]
    )

    try report.validate()
    let frame = try #require(report.frames.first)
    #expect(report.verdict == .partial)
    #expect(frame.sourcePort == 19_789)
    #expect(frame.destinationPort == 19_788)
}

@Test
func lolaMediaReceiveRejectsUnexpectedMediaPort() throws {
    let payload = try LoLaCompatibilityMediaCodec.audioFragments(sequenceNumber: 1, channels: 2)[0].payload
    let encodedFrame = try lolaCompatibilityTestWireFrame(
        payload: payload,
        sourcePort: 9_999,
        destinationPort: 9_999
    )
    let configuration = ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .rx,
  peer: "192.0.2.20",
  outputPath: "/tmp/lola-rx-unexpected-port.json"
) { input in
  input.localHost = "192.0.2.10"
  input.mediaMode = .audio
})

    #expect(throws: LoLaCompatibilityMediaCodecError.unexpectedMediaPort(9_999)) {
        try LoLaCompatibilityMediaSession.receiveReport(configuration: configuration, encodedFrames: [encodedFrame])
    }
}

@Test
func lolaMediaReceiveRejectsInvalidVideoEnvelopeSequences() throws {
    let txConfiguration = ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .tx,
  peer: "192.0.2.10",
  outputPath: "/tmp/lola-rx-video-envelope-source.json"
) { input in
  input.localHost = "192.0.2.20"
  input.mediaMode = .video
})
    let encodedFrames = try LoLaCompatibilityMediaSession.buildTransmitFrames(
        configuration: txConfiguration,
        frameCountPerStream: 1
    ).map(\.encodedFrame)
    let rxConfiguration = ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .rx,
  peer: "192.0.2.20",
  outputPath: "/tmp/lola-rx-video-envelope.json"
) { input in
  input.localHost = "192.0.2.10"
  input.mediaMode = .video
})
    let cases: [(expectedError: LoLaCompatibilityMediaCodecError, frames: [Data])] = [
        (
            .duplicateVideoPrelude(0),
            [encodedFrames[0], encodedFrames[0], encodedFrames[1]]
        ),
        (
            .missingVideoPrelude(0),
            [try #require(encodedFrames.last)]
        ),
        (
            .missingFragment(0),
            [encodedFrames[0]]
        )
    ]

    for testCase in cases {
        #expect(throws: testCase.expectedError) {
            try LoLaCompatibilityMediaSession.receiveReport(
                configuration: rxConfiguration,
                encodedFrames: testCase.frames
            )
        }
    }
}
