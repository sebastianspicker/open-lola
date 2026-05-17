import Foundation
import Testing

@testable import OpenLolaCore

@Test
func lolaMediaReceiveAcceptsEphemeralSourcePortWhenDestinationPortMatches() throws {
    let payload = try LoLaCompatibilityMediaCodec.audioFragments(sequenceNumber: 1, channels: 2)[0].payload
    let encodedFrame = try LoLaCompatibilityWireFrame(
        destinationMAC: LoLaEthernetAddress(octets: [0xff, 0xff, 0xff, 0xff, 0xff, 0xff]),
        sourceMAC: LoLaEthernetAddress(octets: [0x02, 0x4c, 0x6f, 0x4c, 0x61, 0x00]),
        sourceIP: LoLaIPv4Address(octets: [192, 0, 2, 20]),
        destinationIP: LoLaIPv4Address(octets: [192, 0, 2, 10]),
        sourcePort: 19_789,
        destinationPort: 19_788,
        payload: payload
    ).encoded()
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .rx,
        peer: "192.0.2.20",
        localHost: "192.0.2.10",
        outputPath: "/tmp/lola-rx-port-mismatch.json",
        mediaMode: .audio
    )

    let report = try LoLaCompatibilityMediaSession.receiveReport(configuration: configuration, encodedFrames: [encodedFrame])

    try report.validate()
    let frame = try #require(report.frames.first)
    #expect(report.verdict == .partial)
    #expect(frame.sourcePort == 19_789)
    #expect(frame.destinationPort == 19_788)
}

@Test
func lolaMediaReceiveRejectsUnexpectedMediaPort() throws {
    let payload = try LoLaCompatibilityMediaCodec.audioFragments(sequenceNumber: 1, channels: 2)[0].payload
    let encodedFrame = try LoLaCompatibilityWireFrame(
        destinationMAC: LoLaEthernetAddress(octets: [0xff, 0xff, 0xff, 0xff, 0xff, 0xff]),
        sourceMAC: LoLaEthernetAddress(octets: [0x02, 0x4c, 0x6f, 0x4c, 0x61, 0x00]),
        sourceIP: LoLaIPv4Address(octets: [192, 0, 2, 20]),
        destinationIP: LoLaIPv4Address(octets: [192, 0, 2, 10]),
        sourcePort: 9_999,
        destinationPort: 9_999,
        payload: payload
    ).encoded()
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .rx,
        peer: "192.0.2.20",
        localHost: "192.0.2.10",
        outputPath: "/tmp/lola-rx-unexpected-port.json",
        mediaMode: .audio
    )

    #expect(throws: LoLaCompatibilityMediaCodecError.unexpectedMediaPort(9_999)) {
        try LoLaCompatibilityMediaSession.receiveReport(configuration: configuration, encodedFrames: [encodedFrame])
    }
}

@Test
func lolaMediaReceiveRejectsInvalidVideoEnvelopeSequences() throws {
    let txConfiguration = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .tx,
        peer: "192.0.2.10",
        localHost: "192.0.2.20",
        outputPath: "/tmp/lola-rx-video-envelope-source.json",
        mediaMode: .video
    )
    let encodedFrames = try LoLaCompatibilityMediaSession.buildTransmitFrames(
        configuration: txConfiguration,
        frameCountPerStream: 1
    ).map(\.encodedFrame)
    let rxConfiguration = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .rx,
        peer: "192.0.2.20",
        localHost: "192.0.2.10",
        outputPath: "/tmp/lola-rx-video-envelope.json",
        mediaMode: .video
    )
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
        ),
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
