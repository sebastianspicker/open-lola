import Foundation
import Testing

@testable import OpenLolaCore

@Test
func audioOpusCeltLowDelayPacketEncodesThroughUdpMediaEnvelope() throws {
    let nested = AudioOpusCeltLowDelayPacket(
        header: AudioOpusCeltLowDelayPacketHeader(
            streamID: 1,
            sequenceNumber: 7,
            senderFrameIndex: 840,
            senderHostTimeNanoseconds: 9_000,
            channelCount: 2
        ),
        payload: Data([0x01, 0x02, 0x03, 0x04])
    )
    let media = UdpMediaPacket(
        header: UdpMediaPacketHeader(
            payloadType: .audioOpusCeltLowDelayFrame,
            streamID: 1,
            sequenceNumber: 7,
            timestampNanoseconds: 9_000
        ),
        payload: try nested.encoded()
    )

    let decodedMedia = try UdpMediaPacket.decode(try media.encoded())
    let decodedNested = try AudioOpusCeltLowDelayPacket.decode(decodedMedia.payload)

    #expect(decodedMedia.header.payloadType == .audioOpusCeltLowDelayFrame)
    #expect(decodedNested.header.streamID == 1)
    #expect(decodedNested.header.sequenceNumber == 7)
    #expect(decodedNested.header.frameCount == 120)
    #expect(decodedNested.header.sampleRateHertz == 48_000)
    #expect(decodedNested.payload == Data([0x01, 0x02, 0x03, 0x04]))
}

@Test
func audioOpusCeltLowDelayPacketRejectsUnsupportedShape() {
    let packet = AudioOpusCeltLowDelayPacket(
        header: AudioOpusCeltLowDelayPacketHeader(
            streamID: 1,
            sequenceNumber: 7,
            senderFrameIndex: 840,
            senderHostTimeNanoseconds: 9_000,
            sampleRateHertz: 44_100,
            channelCount: 2
        ),
        payload: Data([0x01])
    )

    #expect(throws: AudioOpusCeltLowDelayPacketError.invalidSampleRate(44_100)) {
        _ = try packet.encoded()
    }
}

@Test
func audioOpusCeltLowDelayPacketUsesCheckedReadersOnly() throws {
    let source = try readAudioOpusPacketRepositoryText(
        "Sources/OpenLolaCore/Network/UDP/AudioOpusCeltLowDelayPacket.swift"
    )

    #expect(source.contains("try readCheckedOpusPacketUInt16LE"))
    #expect(source.contains("try readCheckedOpusPacketUInt32LE"))
    #expect(source.contains("try readCheckedOpusPacketUInt64LE"))
    #expect(!source.contains("readUdpPcmUInt16LE"))
    #expect(!source.contains("readUdpPcmUInt32LE"))
    #expect(!source.contains("readUdpPcmUInt64LE"))
}

private func readAudioOpusPacketRepositoryText(_ relativePath: String) throws -> String {
    let current = URL(fileURLWithPath: #filePath)
    let repositoryRoot = current
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let url = repositoryRoot.appendingPathComponent(relativePath)
    return try String(contentsOf: url, encoding: .utf8)
}
