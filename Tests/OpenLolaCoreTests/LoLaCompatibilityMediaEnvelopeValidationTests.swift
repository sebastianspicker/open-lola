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
func lolaMediaReceiveRejectsDuplicateVideoPrelude() throws {
    let txConfiguration = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .tx,
        peer: "192.0.2.10",
        localHost: "192.0.2.20",
        outputPath: "/tmp/lola-rx-video-duplicate-prelude-source.json",
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
        outputPath: "/tmp/lola-rx-video-duplicate-prelude.json",
        mediaMode: .video
    )

    #expect(throws: LoLaCompatibilityMediaCodecError.duplicateVideoPrelude(0)) {
        try LoLaCompatibilityMediaSession.receiveReport(
            configuration: rxConfiguration,
            encodedFrames: [encodedFrames[0], encodedFrames[0], encodedFrames[1]]
        )
    }
}

@Test
func lolaAudioVideoReceiveDefaultsCoverCompleteSourceLevelEnvelope() throws {
    let udp = try LoLaUdpMediaReceiveRunConfiguration.parse([
        "--local-host", "192.0.2.10",
        "--peer", "192.0.2.20",
        "--output", "/tmp/lola-udp-media-rx-default-budget.json",
    ])
    let raw = try LoLaRawLinkReceiveRunConfiguration.parse([
        "--interface", "en0",
        "--local-ip", "192.0.2.10",
        "--peer", "192.0.2.20",
        "--output", "/tmp/lola-raw-link-rx-default-budget.json",
    ])

    #expect(udp.maxDatagrams == 3)
    #expect(raw.maxFrames == 3)
}

@Test
func lolaUdpMemoryReceiveFiltersConfiguredMediaPorts() throws {
    let configuration = try LoLaUdpMediaReceiveRunConfiguration.parse([
        "--local-host", "192.0.2.10",
        "--peer", "192.0.2.20",
        "--output", "/tmp/lola-udp-media-rx-port-filtered.json",
        "--dry-run", "false",
        "--packets", "1",
        "--media", "audio",
    ])
    let source = LoLaMemoryUdpMediaReceiver(datagrams: [
        LoLaUdpMediaDatagram(
            stream: .audio,
            port: 9_999,
            sourceHost: "192.0.2.20",
            payload: try LoLaCompatibilityMediaCodec.audioFragments(sequenceNumber: 1, channels: 2)[0].payload
        ),
        LoLaUdpMediaDatagram(
            stream: .audio,
            port: 19_788,
            sourceHost: "192.0.2.20",
            payload: try LoLaCompatibilityMediaCodec.audioFragments(sequenceNumber: 2, channels: 2)[0].payload
        ),
    ])

    let report = try LoLaUdpMediaReceiveRunner.run(configuration: configuration, receiver: source)

    let decoded = try LoLaCompatibilityWireFrame.decode(try #require(report.frames.first).encodedFrame)
    let fragment = try #require(LoLaCompatibilityMediaCodec.decode(decoded.payload).normalFragment)
    #expect(decoded.sourcePort == 19_788)
    #expect(decoded.destinationPort == 19_788)
    #expect(try #require(fragment.body).sequence == 2)
}

@Test
func lolaMediaReceiveRejectsAudioFragmentWithWrongConfiguredChannelBlockSize() throws {
    let txConfiguration = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .tx,
        peer: "192.0.2.10",
        localHost: "192.0.2.20",
        outputPath: "/tmp/lola-rx-audio-size-source.json",
        mediaMode: .audio,
        channels: 1
    )
    let encodedFrame = try LoLaCompatibilityMediaSession.buildTransmitFrames(
        configuration: txConfiguration,
        frameCountPerStream: 1
    )[0].encodedFrame
    let rxConfiguration = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .rx,
        peer: "192.0.2.20",
        localHost: "192.0.2.10",
        outputPath: "/tmp/lola-rx-audio-size.json",
        mediaMode: .audio,
        channels: 2
    )

    #expect(throws: LoLaCompatibilityMediaCodecError.serializedSizeMismatch(expected: 264, actual: 136)) {
        try LoLaCompatibilityMediaSession.receiveReport(
            configuration: rxConfiguration,
            encodedFrames: [encodedFrame]
        )
    }
}

@Test
func lolaMediaReceiveRejectsVideoFragmentWithoutPrelude() throws {
    let txConfiguration = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .tx,
        peer: "192.0.2.10",
        localHost: "192.0.2.20",
        outputPath: "/tmp/lola-rx-video-fragment-source.json",
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
        outputPath: "/tmp/lola-rx-video-fragment.json",
        mediaMode: .video
    )

    #expect(throws: LoLaCompatibilityMediaCodecError.missingVideoPrelude(0)) {
        try LoLaCompatibilityMediaSession.receiveReport(
            configuration: rxConfiguration,
            encodedFrames: [try #require(encodedFrames.last)]
        )
    }
}

@Test
func lolaMediaReceiveRejectsVideoPreludeWithoutFragments() throws {
    let txConfiguration = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .tx,
        peer: "192.0.2.10",
        localHost: "192.0.2.20",
        outputPath: "/tmp/lola-rx-video-prelude-source.json",
        mediaMode: .video
    )
    let encodedFrame = try LoLaCompatibilityMediaSession.buildTransmitFrames(
        configuration: txConfiguration,
        frameCountPerStream: 1
    )[0].encodedFrame
    let rxConfiguration = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .rx,
        peer: "192.0.2.20",
        localHost: "192.0.2.10",
        outputPath: "/tmp/lola-rx-video-prelude.json",
        mediaMode: .video
    )

    #expect(throws: LoLaCompatibilityMediaCodecError.missingFragment(0)) {
        try LoLaCompatibilityMediaSession.receiveReport(
            configuration: rxConfiguration,
            encodedFrames: [encodedFrame]
        )
    }
}

@Test
func lolaVideoReassemblyRejectsBodySequenceMismatch() throws {
    let packets = try LoLaCompatibilityMediaCodec.videoPackets(
        sequenceNumber: 7,
        payload: Data(repeating: 0x11, count: 32)
    )
    let prelude = try #require(LoLaCompatibilityMediaCodec.decode(packets[0].payload).videoPrelude)
    var fragmentPayload = packets[1].payload
    fragmentPayload[LoLaCompatibilityMediaModel.fragmentPayloadOffset] = 8
    let fragment = try #require(LoLaCompatibilityMediaCodec.decode(fragmentPayload).normalFragment)

    #expect(throws: LoLaCompatibilityMediaCodecError.sequenceMismatch(expected: 7, actual: 8)) {
        try LoLaCompatibilityMediaCodec.reassemble(prelude: prelude, fragments: [fragment])
    }
}
