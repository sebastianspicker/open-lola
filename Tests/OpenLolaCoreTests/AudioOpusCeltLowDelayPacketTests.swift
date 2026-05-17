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
func audioOpusCeltLowDelayPacketRejectsMalformedEncodedPackets() throws {
    let packet = AudioOpusCeltLowDelayPacket(
        header: AudioOpusCeltLowDelayPacketHeader(
            streamID: 1,
            sequenceNumber: 7,
            senderFrameIndex: 840,
            senderHostTimeNanoseconds: 9_000,
            channelCount: 2
        ),
        payload: Data([0x01, 0x02, 0x03, 0x04])
    )
    let encoded = try packet.encoded()

    #expect(throws: AudioOpusCeltLowDelayPacketError.truncatedPacket(byteCount: 55)) {
        _ = try AudioOpusCeltLowDelayPacket.decode(encoded.prefix(55))
    }

    var invalidMagic = encoded
    invalidMagic[0] = 0
    #expect(throws: AudioOpusCeltLowDelayPacketError.invalidMagic) {
        _ = try AudioOpusCeltLowDelayPacket.decode(invalidMagic)
    }

    var unsupportedVersion = encoded
    unsupportedVersion[4] = 2
    #expect(throws: AudioOpusCeltLowDelayPacketError.unsupportedVersion(2)) {
        _ = try AudioOpusCeltLowDelayPacket.decode(unsupportedVersion)
    }

    var invalidGuard = encoded
    invalidGuard[52] = 0
    #expect(throws: AudioOpusCeltLowDelayPacketError.invalidHeaderGuard) {
        _ = try AudioOpusCeltLowDelayPacket.decode(invalidGuard)
    }

    let truncatedPayload = encoded.dropLast()
    #expect(throws: AudioOpusCeltLowDelayPacketError.payloadLengthMismatch(
        expected: 4,
        actual: 3
    )) {
        _ = try AudioOpusCeltLowDelayPacket.decode(truncatedPayload)
    }
}
