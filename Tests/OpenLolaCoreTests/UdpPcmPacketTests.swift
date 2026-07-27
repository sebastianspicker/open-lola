// Verifies that UDP PCM packet fixtures decode and reencode byte for byte.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func udpPcmPacketFixturesDecodeAndReencodeByteForByte() throws {
    let int16Data = try loadPacketFixture(named: "valid-stereo-int16")
    let int16Packet = try UdpPcmPacket.decode(int16Data)

    #expect(int16Packet.header.version == UdpPcmPacketHeader.currentVersion)
    #expect(int16Packet.header.sequenceNumber == 7)
    #expect(int16Packet.header.senderFrameIndex == 128)
    #expect(int16Packet.header.senderHostTimeNanoseconds == 1_000_000_000)
    #expect(int16Packet.header.sampleRateHertz == 48_000)
    #expect(int16Packet.header.framesPerPacket == 2)
    #expect(int16Packet.header.channelCount == 2)
    #expect(int16Packet.header.sampleFormat == .int16LittleEndian)
    #expect(int16Packet.payload == Data([0xE8, 0x03, 0x18, 0xFC, 0xD0, 0x07, 0x30, 0xF8]))

    let float32Data = try loadPacketFixture(named: "valid-stereo-float32")
    let float32Packet = try UdpPcmPacket.decode(float32Data)

    #expect(float32Packet.header.sequenceNumber == 8)
    #expect(float32Packet.header.senderFrameIndex == 130)
    #expect(float32Packet.header.sampleFormat == .float32LittleEndian)
    #expect(float32Packet.header.payloadByteCount == 16)

    let packet = UdpPcmPacket(
        header: UdpPcmPacketHeader(
            transport: .init(sequenceNumber: 7, senderFrameIndex: 128, senderHostTimeNanoseconds: 1_000_000_000),
            format: .init(sampleRateHertz: 48_000, framesPerPacket: 2, channelCount: 2, sampleFormat: .int16LittleEndian)
        ),
        payload: Data([0xE8, 0x03, 0x18, 0xFC, 0xD0, 0x07, 0x30, 0xF8])
    )

    #expect(try packet.encoded() == int16Data)

    for fixtureName in ["valid-stereo-int16", "valid-stereo-float32"] {
        let fixtureData = try loadPacketFixture(named: fixtureName)
        let packet = try UdpPcmPacket.decode(fixtureData)

        #expect(try packet.encoded() == fixtureData)
    }
}

@Test
func udpPcmParserRejectsMalformedPacketsAndInvalidHelperRanges() throws {
    let valid = try loadPacketFixture(named: "valid-stereo-int16")

    try expectMalformedUdpPcmPacketRejections(valid: valid)
    expectUdpPcmHasBytesRejectsInvalidRanges()
    try expectZeroTimestampEncodingRejected()
}

private func expectMalformedUdpPcmPacketRejections(valid: Data) throws {
    try expectPacketError(.invalidMagic) {
        var data = valid
        data[0] = 0
        _ = try UdpPcmPacket.decode(data)
    }
    try expectPacketError(.unsupportedVersion(2)) {
        var data = valid
        data[4] = 2
        _ = try UdpPcmPacket.decode(data)
    }
    try expectPacketError(.truncatedPacket(byteCount: 12)) {
        _ = try UdpPcmPacket.decode(valid.prefix(12))
    }
    for byteCount in 0..<UdpPcmPacketHeader.byteCount {
        try expectPacketError(.truncatedPacket(byteCount: byteCount)) {
            _ = try UdpPcmPacket.decode(valid.prefix(byteCount))
        }
    }
    try expectPacketError(.oversizedPacket(expected: valid.count, actual: valid.count + 1)) {
        var data = valid
        data.append(0)
        _ = try UdpPcmPacket.decode(data)
    }
    try expectPacketError(.invalidSampleRate(0)) {
        var data = valid
        data.replaceSubrange(12..<16, with: [0, 0, 0, 0])
        _ = try UdpPcmPacket.decode(data)
    }
    try expectPacketError(.invalidChannelCount(0)) {
        var data = valid
        data.replaceSubrange(6..<8, with: [0, 0])
        _ = try UdpPcmPacket.decode(data)
    }
    try expectPacketError(.unsupportedSampleFormat(99)) {
        var data = valid
        data[5] = 99
        _ = try UdpPcmPacket.decode(data)
    }
    let wrongGuard = try loadPacketFixture(named: "wrong-guard")
    try expectPacketError(.invalidHeaderGuard) {
        _ = try UdpPcmPacket.decode(wrongGuard)
    }
    try expectPacketError(.payloadLengthMismatch(expected: 12, actual: 8)) {
        var data = valid
        data.replaceSubrange(40..<44, with: [12, 0, 0, 0])
        _ = try UdpPcmPacket.decode(data)
    }
}

private func expectUdpPcmHasBytesRejectsInvalidRanges() {
    #expect(!udpPcmHasBytes([1, 2, 3], offset: 0, count: 4))
    #expect(!udpPcmHasBytes([1, 2, 3], offset: 3, count: 1))
    #expect(!udpPcmHasBytes([1, 2, 3], offset: -1, count: 1))
    #expect(!udpPcmHasBytes([1, 2, 3], offset: 0, count: -1))
    #expect(udpPcmHasBytes([1, 2, 3], offset: 1, count: 2))
}

private func expectZeroTimestampEncodingRejected() throws {
    let packet = UdpPcmPacket(
        header: UdpPcmPacketHeader(
            transport: .init(sequenceNumber: 1, senderFrameIndex: 0, senderHostTimeNanoseconds: 0),
            format: .init(sampleRateHertz: 48_000, framesPerPacket: 2, channelCount: 2, sampleFormat: .int16LittleEndian)
        ),
        payload: Data(repeating: 0, count: 8)
    )

    try expectPacketError(.invalidTimestamp(0)) {
        _ = try packet.encoded()
    }
}

@Test
func udpPcmSequenceTrackerRejectsSkippedSequence() throws {
    let packet = try UdpPcmPacket.decode(loadPacketFixture(named: "valid-stereo-int16"))
    var tracker = UdpPcmSequenceTracker()

    try tracker.accept(packet)

    var skipped = packet
    skipped.header.sequenceNumber = 9
    skipped.header.senderFrameIndex = 132

    #expect(throws: UdpPcmSequenceError.unexpectedSequence(expected: 8, actual: 9)) {
        try tracker.accept(skipped)
    }
}

@Test
func udpPcmSmokeDecodedPayloadMatchesTransmittedPayload() throws {
    let testVector = (0..<256).map { Float32($0) / 256.0 }
    let payload = udpPcmFloat32Payload(testVector)
    let packet = UdpPcmPacket(
        header: UdpPcmPacketHeader(
            transport: .init(sequenceNumber: 1, senderFrameIndex: 0, senderHostTimeNanoseconds: 1),
            format: .init(sampleRateHertz: 48_000, framesPerPacket: 128, channelCount: 2, sampleFormat: .float32LittleEndian)
        ),
        payload: payload
    )

    let decoded = try UdpPcmPacket.decode(try packet.encoded())

    #expect(decoded.payload == payload)
    #expect(try udpPcmFloat32Samples(decoded.payload) == testVector)
}

@Test
func udpPcmSmokeThreePacketSequenceIsAccepted() throws {
    var tracker = UdpPcmSequenceTracker()

    try tracker.accept(udpPcmInt16TestPacket(sequenceNumber: 1, senderFrameIndex: 0))
    try tracker.accept(udpPcmInt16TestPacket(sequenceNumber: 2, senderFrameIndex: 2))
    try tracker.accept(udpPcmInt16TestPacket(sequenceNumber: 3, senderFrameIndex: 4))
}

@Test
func udpPcmSmokeSequenceGapIsRejected() throws {
    var tracker = UdpPcmSequenceTracker()

    try tracker.accept(udpPcmInt16TestPacket(sequenceNumber: 1, senderFrameIndex: 0))

    #expect(throws: UdpPcmSequenceError.unexpectedSequence(expected: 2, actual: 3)) {
        try tracker.accept(udpPcmInt16TestPacket(sequenceNumber: 3, senderFrameIndex: 4))
    }
}

@Test
func udpPcmSequenceTrackerAcceptsWrapAroundFromMaxToZero() throws {
    var tracker = UdpPcmSequenceTracker()

    try tracker.accept(udpPcmInt16TestPacket(
        sequenceNumber: UInt64.max,
        senderFrameIndex: UInt64.max - 1
    ))
    try tracker.accept(udpPcmInt16TestPacket(sequenceNumber: 0, senderFrameIndex: 0))
}

@Test
func udpPcmSequenceTrackerRejectsSkipAcrossWrapBoundary() throws {
    var tracker = UdpPcmSequenceTracker()

    try tracker.accept(udpPcmInt16TestPacket(
        sequenceNumber: UInt64.max - 1,
        senderFrameIndex: UInt64.max - 3
    ))
    try tracker.accept(udpPcmInt16TestPacket(
        sequenceNumber: UInt64.max,
        senderFrameIndex: UInt64.max - 1
    ))

    #expect(throws: UdpPcmSequenceError.unexpectedSequence(expected: 0, actual: 1)) {
        try tracker.accept(udpPcmInt16TestPacket(sequenceNumber: 1, senderFrameIndex: 3))
    }
}

@Test
func udpPcmLocalhostSmokeRoundTripsPacket() throws {
    let packet = try UdpPcmLocalhostSmoke.run()

    #expect(packet.header.sequenceNumber == 1)
    #expect(packet.header.senderHostTimeNanoseconds > 1)
    #expect(packet.header.framesPerPacket == 2)
    #expect(packet.header.channelCount == 2)
    #expect(packet.header.sampleFormat == .int16LittleEndian)
}

private func udpPcmFloat32Payload(_ samples: [Float32]) -> Data {
    var payload = Data()
    payload.reserveCapacity(samples.count * MemoryLayout<UInt32>.size)
    for sample in samples {
        var bits = sample.bitPattern.littleEndian
        withUnsafeBytes(of: &bits) {
            payload.append(contentsOf: $0)
        }
    }
    return payload
}

private func udpPcmFloat32Samples(_ payload: Data) throws -> [Float32] {
    guard payload.count.isMultiple(of: MemoryLayout<UInt32>.size) else {
        throw UdpPcmPacketError.payloadLengthMismatch(
            expected: payload.count + (MemoryLayout<UInt32>.size - payload.count % MemoryLayout<UInt32>.size),
            actual: payload.count
        )
    }
    return stride(from: 0, to: payload.count, by: MemoryLayout<UInt32>.size).map { offset in
        let word = payload[offset..<(offset + MemoryLayout<UInt32>.size)].enumerated().reduce(UInt32(0)) {
            $0 | (UInt32($1.element) << UInt32($1.offset * 8))
        }
        return Float32(bitPattern: word)
    }
}

private func udpPcmInt16TestPacket(sequenceNumber: UInt64, senderFrameIndex: UInt64) -> UdpPcmPacket {
    UdpPcmPacket(
        header: UdpPcmPacketHeader(
            transport: .init(sequenceNumber: sequenceNumber, senderFrameIndex: senderFrameIndex, senderHostTimeNanoseconds: max(1, sequenceNumber)),
            format: .init(sampleRateHertz: 48_000, framesPerPacket: 2, channelCount: 2, sampleFormat: .int16LittleEndian)
        ),
        payload: Data([0, 0, 1, 0, 255, 255, 0, 128])
    )
}

private func loadPacketFixture(named name: String) throws -> Data {
    let url = try packetFixtureURL(named: name)
    return try UdpPcmHexFixture.decode(Data(contentsOf: url))
}

private func packetFixtureURL(named name: String) throws -> URL {
    let validURL = Bundle.module.url(
        forResource: name,
        withExtension: "hex",
        subdirectory: "UdpPcmPackets/valid"
    )
    let invalidURL = Bundle.module.url(
        forResource: name,
        withExtension: "hex",
        subdirectory: "UdpPcmPackets/invalid"
    )
    let rootURL = Bundle.module.url(
        forResource: name,
        withExtension: "hex",
        subdirectory: nil
    )

    return try #require(validURL ?? invalidURL ?? rootURL)
}

private func expectPacketError(
    _ expected: UdpPcmPacketError,
    operation: () throws -> Void
) throws {
    do {
        try operation()
    } catch let error as UdpPcmPacketError {
        #expect(error == expected)
        return
    }

    Issue.record("Expected \(expected)")
}

private func expectV2PacketError(
    _ expected: UdpPcmV2PacketError,
    operation: () throws -> Void
) throws {
    do {
        try operation()
    } catch let error as UdpPcmV2PacketError {
        #expect(error == expected)
        return
    }

    Issue.record("Expected \(expected)")
}

private func requirePacketCodec<T: PacketCodec>(_ type: T.Type) {}

private func expectPacketCodecRoundTrip<T: PacketCodec>(_ packet: T) throws {
    #expect(try T.decode(try packet.encoded()) == packet)
}
