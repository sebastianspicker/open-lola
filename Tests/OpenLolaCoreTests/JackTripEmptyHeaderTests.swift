import Foundation
import Testing

@testable import OpenLolaCore

@Test
func jackTripEmptyHeaderModeCarriesRawPlanarPCMWithExplicitTemplate() throws {
    let packet = try JackTripAudioPacket(
        header: JackTripDefaultHeader(
            timestampMicroseconds: 1,
            sequenceNumber: 2,
            bufferSizeSamples: 2,
            sampleRate: .hz48000,
            bitResolution: .bit16,
            incomingChannelsFromNetwork: 2,
            outgoingChannelsToNetwork: JackTripCompatibility.matchingOutgoingChannelSentinel
        ),
        planarAudioPayload: Data([1, 0, 2, 0, 3, 0, 4, 0])
    )

    let encoded = try JackTripAudioPayloadCodec.encodeDatagram([packet], headerMode: .empty)

    #expect(encoded == packet.planarAudioPayload)
    let decoded = try #require(try JackTripAudioPayloadCodec.decodeDatagram(
        encoded,
        headerMode: .empty,
        emptyHeaderTemplate: packet.header
    ).first)
    #expect(decoded.planarAudioPayload == packet.planarAudioPayload)
    #expect(decoded.header.bufferSizeSamples == 2)
    #expect(decoded.header.payloadChannelCount == 2)
    #expect(throws: JackTripCompatibilityError.unsupportedMode("empty-header-missing-template")) {
        _ = try JackTripAudioPayloadCodec.decodeDatagram(encoded, headerMode: .empty)
    }
}

@Test
func jackTripSessionParserAcceptsEmptyHeaderSelection() throws {
    let configuration = try ExternalConnectorSessionConfiguration.parse([
        "--connector", "jacktrip",
        "--role", "tx",
        "--peer", "203.0.113.10",
        "--output", "/tmp/jacktrip-empty-header.json",
        "--jacktrip-header", "empty",
    ])

    #expect(configuration.jackTrip.packetHeaderMode == .empty)
}

@Test
func jackTripRunnerPropagatesEmptyHeaderModeAndRejectsEmptyHeaderRedundancy() throws {
    let report = try JackTripCompatibilityRunner.run(
        configuration: ExternalConnectorSessionConfiguration(
            connector: .jackTrip,
            role: .tx,
            peer: "203.0.113.20",
            outputPath: "/tmp/jacktrip-empty-header.json",
            dryRun: true,
            peerAudioPort: 4464,
            mediaPacketCount: 1,
            jackTrip: JackTripRunConfiguration(packetHeaderMode: .empty)
        )
    )

    try report.validate()
    #expect(report.datagrams.allSatisfy { $0.headerMode == .empty })
    #expect(!report.unsupportedModes.contains("empty-header"))
    #expect(throws: ExternalConnectorSessionError.unsupportedRuntimeMode("jacktrip-empty-header-redundancy")) {
        _ = try JackTripCompatibilityRunner.buildDatagrams(
            configuration: ExternalConnectorSessionConfiguration(
                connector: .jackTrip,
                role: .tx,
                peer: "203.0.113.20",
                outputPath: "/tmp/jacktrip-empty-header-redundancy.json",
                peerAudioPort: 4464,
                jackTrip: JackTripRunConfiguration(redundancy: 2, packetHeaderMode: .empty)
            )
        )
    }
}

@Test
func jackTripJamLinkHeaderModeCarriesCompactHeaderAndPlanarPCM() throws {
    let packet = try JackTripAudioPacket(
        header: JackTripDefaultHeader(
            timestampMicroseconds: 0x0102_0304,
            sequenceNumber: 0x1122,
            bufferSizeSamples: 2,
            sampleRate: .hz48000,
            bitResolution: .bit16,
            incomingChannelsFromNetwork: 2,
            outgoingChannelsToNetwork: JackTripCompatibility.matchingOutgoingChannelSentinel
        ),
        planarAudioPayload: Data([1, 0, 2, 0, 3, 0, 4, 0])
    )

    let encoded = try JackTripAudioPayloadCodec.encodeDatagram([packet], headerMode: .jamLink)

    #expect(encoded.prefix(JackTripJamLinkHeader.byteCount) == Data([
        0x02, 0x20,
        0x22, 0x11,
        0x04, 0x03, 0x02, 0x01,
    ]))
    let decoded = try #require(try JackTripAudioPayloadCodec.decodeDatagram(
        encoded,
        headerMode: .jamLink
    ).first)
    #expect(decoded.planarAudioPayload == packet.planarAudioPayload)
    #expect(decoded.header.sequenceNumber == 0x1122)
    #expect(decoded.header.bufferSizeSamples == 2)
    #expect(decoded.header.payloadChannelCount == 2)
    #expect(decoded.header.sampleRate == .hz48000)
}

@Test
func jackTripJamLinkModeRejectsUnrepresentableHeadersAndMalformedPackets() throws {
    let unsupportedBitDepth = try JackTripAudioPacket(
        header: JackTripDefaultHeader(
            timestampMicroseconds: 1,
            sequenceNumber: 1,
            bufferSizeSamples: 2,
            sampleRate: .hz48000,
            bitResolution: .bit24,
            incomingChannelsFromNetwork: 2,
            outgoingChannelsToNetwork: JackTripCompatibility.matchingOutgoingChannelSentinel
        ),
        planarAudioPayload: Data(repeating: 0, count: 12)
    )
    #expect(throws: JackTripCompatibilityError.unsupportedMode("jamlink-bit-resolution-24")) {
        _ = try JackTripAudioPayloadCodec.encodeDatagram([unsupportedBitDepth], headerMode: .jamLink)
    }

    let non16BitCommon = Data([
        0x02, 0x10,
        0x01, 0x00,
        0x01, 0x00, 0x00, 0x00,
        0x00, 0x00,
    ])
    #expect(throws: JackTripCompatibilityError.unsupportedMode("jamlink-non-16-bit")) {
        _ = try JackTripAudioPayloadCodec.decodeDatagram(non16BitCommon, headerMode: .jamLink)
    }
}

@Test
func jackTripRunnerPropagatesJamLinkHeaderMode() throws {
    let configuration = try ExternalConnectorSessionConfiguration.parse([
        "--connector", "jacktrip",
        "--role", "tx",
        "--peer", "203.0.113.10",
        "--output", "/tmp/jacktrip-jamlink-header.json",
        "--jacktrip-header", "jamlink",
    ])
    let report = try JackTripCompatibilityRunner.run(configuration: configuration)

    try report.validate()
    #expect(configuration.jackTrip.packetHeaderMode == .jamLink)
    #expect(report.datagrams.allSatisfy { $0.headerMode == .jamLink })
    #expect(!report.unsupportedModes.contains("jamlink-header"))
}
