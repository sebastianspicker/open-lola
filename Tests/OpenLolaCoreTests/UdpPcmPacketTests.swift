import Foundation
import Testing

@testable import OpenLolaCore

@Test
func validInt16PacketFixtureDecodes() throws {
    let packetData = try loadPacketFixture(named: "valid-stereo-int16")
    let packet = try UdpPcmPacket.decode(packetData)

    #expect(packet.header.version == UdpPcmPacketHeader.currentVersion)
    #expect(packet.header.sequenceNumber == 7)
    #expect(packet.header.senderFrameIndex == 128)
    #expect(packet.header.senderHostTimeNanoseconds == 1_000_000_000)
    #expect(packet.header.sampleRateHertz == 48_000)
    #expect(packet.header.framesPerPacket == 2)
    #expect(packet.header.channelCount == 2)
    #expect(packet.header.sampleFormat == .int16LittleEndian)
    #expect(packet.payload == Data([0xE8, 0x03, 0x18, 0xFC, 0xD0, 0x07, 0x30, 0xF8]))
}

@Test
func validFloat32PacketFixtureDecodes() throws {
    let packetData = try loadPacketFixture(named: "valid-stereo-float32")
    let packet = try UdpPcmPacket.decode(packetData)

    #expect(packet.header.sequenceNumber == 8)
    #expect(packet.header.senderFrameIndex == 130)
    #expect(packet.header.sampleFormat == .float32LittleEndian)
    #expect(packet.header.payloadByteCount == 16)
}

@Test
func udpPcmPacketRoundTripMatchesFixtureBytes() throws {
    let packetData = try loadPacketFixture(named: "valid-stereo-int16")
    let packet = UdpPcmPacket(
        header: UdpPcmPacketHeader(
            sequenceNumber: 7,
            senderFrameIndex: 128,
            senderHostTimeNanoseconds: 1_000_000_000,
            sampleRateHertz: 48_000,
            framesPerPacket: 2,
            channelCount: 2,
            sampleFormat: .int16LittleEndian
        ),
        payload: Data([0xE8, 0x03, 0x18, 0xFC, 0xD0, 0x07, 0x30, 0xF8])
    )

    #expect(try packet.encoded() == packetData)
}

@Test
func udpPcmPacketFixturesReencodeByteForByte() throws {
    for fixtureName in ["valid-stereo-int16", "valid-stereo-float32"] {
        let fixtureData = try loadPacketFixture(named: fixtureName)
        let packet = try UdpPcmPacket.decode(fixtureData)

        #expect(try packet.encoded() == fixtureData)
    }
}

@Test
func networkPacketTypesSharePacketCodecContract() throws {
    requirePacketCodec(UdpPcmPacket.self)
    requirePacketCodec(UdpPcmV2Packet.self)
    requirePacketCodec(UdpMediaPacket.self)
    requirePacketCodec(AudioOpusCeltLowDelayPacket.self)

    let codecSource = try readUdpPcmPacketRepositoryText(
        "Sources/OpenLolaCore/Network/UDP/PacketCodec.swift"
    )
    let udpPcmSource = try readUdpPcmPacketRepositoryText(
        "Sources/OpenLolaCore/Network/UDP/UdpPcmPacket.swift"
    )
    let udpPcmV2Source = try readUdpPcmPacketRepositoryText(
        "Sources/OpenLolaCore/Network/UDP/UdpPcmV2Packet.swift"
    )
    let mediaSource = try readUdpPcmPacketRepositoryText(
        "Sources/OpenLolaCore/Network/UDP/UdpMediaTransport.swift"
    )
    let opusSource = try readUdpPcmPacketRepositoryText(
        "Sources/OpenLolaCore/Network/UDP/AudioOpusCeltLowDelayPacket.swift"
    )

    #expect(codecSource.contains("public protocol PacketCodec"))
    #expect(codecSource.contains("static func decode<Bytes: DataProtocol>(_ data: Bytes) throws -> Self"))
    #expect(codecSource.contains("func encoded() throws -> Data"))
    #expect(udpPcmSource.contains("public struct UdpPcmPacket: PacketCodec"))
    #expect(udpPcmV2Source.contains("public struct UdpPcmV2Packet: PacketCodec"))
    #expect(mediaSource.contains("public struct UdpMediaPacket: PacketCodec"))
    #expect(opusSource.contains("public struct AudioOpusCeltLowDelayPacket: PacketCodec"))
}

@Test
func udpPcmSilencePacketUsesModeDerivedPayloadSize() throws {
    let packet = UdpPcmPacket.silence(
        sequenceNumber: 42,
        senderFrameIndex: 96,
        senderHostTimeNanoseconds: 123_456,
        mode: UdpPcmPacketMode(
            sampleRateHertz: 48_000,
            framesPerPacket: 32,
            channelCount: 2,
            sampleFormat: .int16LittleEndian
        )
    )

    #expect(packet.header.sequenceNumber == 42)
    #expect(packet.header.senderFrameIndex == 96)
    #expect(packet.header.senderHostTimeNanoseconds == 123_456)
    #expect(packet.payload.count == 128)
    #expect(packet.matches(
        UdpPcmPacketMode(
            sampleRateHertz: 48_000,
            framesPerPacket: 32,
            channelCount: 2,
            sampleFormat: .int16LittleEndian
        )
    ))
    #expect(try UdpPcmPacket.decode(try packet.encoded()) == packet)
}

@Test
func udpPcmPacketModeMatchRejectsDifferentRuntimeShape() {
    let packet = UdpPcmPacket.silence(
        sequenceNumber: 42,
        senderFrameIndex: 96,
        senderHostTimeNanoseconds: 123_456,
        mode: UdpPcmPacketMode(
            sampleRateHertz: 48_000,
            framesPerPacket: 32,
            channelCount: 2,
            sampleFormat: .int16LittleEndian
        )
    )

    #expect(!packet.matches(UdpPcmPacketMode(
        sampleRateHertz: 48_000,
        framesPerPacket: 64,
        channelCount: 2,
        sampleFormat: .int16LittleEndian
    )))
    #expect(!packet.matches(UdpPcmPacketMode(
        sampleRateHertz: 48_000,
        framesPerPacket: 32,
        channelCount: 2,
        sampleFormat: .float32LittleEndian
    )))
}

@Test
func udpPcmParserRejectsMalformedPackets() throws {
    let valid = try loadPacketFixture(named: "valid-stereo-int16")

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
}

@Test
func udpPcmByteRangeHelperRejectsCountsLargerThanBuffer() {
    #expect(!udpPcmHasBytes([1, 2, 3], offset: 0, count: 4))
    #expect(!udpPcmHasBytes([1, 2, 3], offset: 3, count: 1))
    #expect(!udpPcmHasBytes([1, 2, 3], offset: -1, count: 1))
    #expect(!udpPcmHasBytes([1, 2, 3], offset: 0, count: -1))
    #expect(udpPcmHasBytes([1, 2, 3], offset: 1, count: 2))
}

@Test
func udpPcmPacketUsesCheckedSharedReadersOnly() throws {
    let source = try readUdpPcmPacketRepositoryText("Sources/OpenLolaCore/Network/UDP/UdpPcmPacket.swift")
    let helpers = try readUdpPcmPacketRepositoryText("Sources/OpenLolaCore/Network/UDP/UdpPcmDataHelpers.swift")

    #expect(source.contains("try readCheckedUdpPcmPacketUInt16LE"))
    #expect(source.contains("try readCheckedUdpPcmPacketUInt32LE"))
    #expect(source.contains("try readCheckedUdpPcmPacketUInt64LE"))
    #expect(!helpers.contains("func readUdpPcmUInt16LE"))
    #expect(!helpers.contains("func readUdpPcmUInt32LE"))
    #expect(!helpers.contains("func readUdpPcmUInt64LE"))
}

@Test
func udpPcmParserRejectsMissingSenderTimestamp() throws {
    let packet = UdpPcmPacket(
        header: UdpPcmPacketHeader(
            sequenceNumber: 1,
            senderFrameIndex: 0,
            senderHostTimeNanoseconds: 0,
            sampleRateHertz: 48_000,
            framesPerPacket: 2,
            channelCount: 2,
            sampleFormat: .int16LittleEndian
        ),
        payload: Data(repeating: 0, count: 8)
    )

    try expectPacketError(.invalidTimestamp(0)) {
        _ = try packet.encoded()
    }
}

@Test
func udpPcmParserRejectsWrongGuardFixture() throws {
    let wrongGuard = try loadPacketFixture(named: "wrong-guard")

    try expectPacketError(.invalidHeaderGuard) {
        _ = try UdpPcmPacket.decode(wrongGuard)
    }
}

@Test
func udpPcmV2PacketRoundTripPreservesFragmentHeader() throws {
    let payload = Data((0..<256).map(UInt8.init))
    let packet = UdpPcmV2Packet(
        header: UdpPcmV2PacketHeader(
            streamID: 9,
            sequenceNumber: 44,
            senderFrameIndex: 1_408,
            senderHostTimeNanoseconds: 2_000_000_000,
            sampleRateHertz: 48_000,
            framesPerPacket: 32,
            totalChannelCount: 64,
            channelOffset: 8,
            channelsInFragment: 2,
            fragmentIndex: 1,
            fragmentCount: 8,
            sampleFormat: .float32LittleEndian,
            metadataRevision: 12,
            packingMode: .interleavedChannelRange
        ),
        payload: payload
    )

    let encoded = try packet.encoded()
    let decoded = try UdpPcmV2Packet.decode(encoded)

    #expect(encoded.count == UdpPcmV2PacketHeader.byteCount + payload.count)
    #expect(decoded == packet)
    #expect(decoded.header.payloadByteCount == UInt32(payload.count))
    #expect(decoded.header.packetByteCount == encoded.count)
}

@Test
func udpPcmV2PacketParserRejectsMalformedPackets() throws {
    let packet = UdpPcmV2Packet(
        header: UdpPcmV2PacketHeader(
            streamID: 1,
            sequenceNumber: 1,
            senderFrameIndex: 0,
            senderHostTimeNanoseconds: 1,
            sampleRateHertz: 48_000,
            framesPerPacket: 2,
            totalChannelCount: 4,
            channelOffset: 0,
            channelsInFragment: 2,
            fragmentIndex: 0,
            fragmentCount: 2,
            sampleFormat: .int16LittleEndian,
            metadataRevision: 0,
            packingMode: .interleavedChannelRange
        ),
        payload: Data(repeating: 0, count: 8)
    )
    let valid = try packet.encoded()

    try expectV2PacketError(.invalidMagic) {
        var data = valid
        data[0] = 0
        _ = try UdpPcmV2Packet.decode(data)
    }
    try expectV2PacketError(.unsupportedVersion(1)) {
        var data = valid
        data[4] = 1
        _ = try UdpPcmV2Packet.decode(data)
    }
    try expectV2PacketError(.unsupportedPackingMode(99)) {
        var data = valid
        data[6] = 99
        _ = try UdpPcmV2Packet.decode(data)
    }
    try expectV2PacketError(.invalidChannelRange(
        totalChannelCount: 4,
        channelOffset: 3,
        channelsInFragment: 2
    )) {
        var data = valid
        data.replaceSubrange(46..<48, with: [3, 0])
        _ = try UdpPcmV2Packet.decode(data)
    }
    try expectV2PacketError(.payloadLengthMismatch(expected: 12, actual: 8)) {
        var data = valid
        data.replaceSubrange(60..<64, with: [12, 0, 0, 0])
        _ = try UdpPcmV2Packet.decode(data)
    }
    try expectV2PacketError(.invalidHeaderGuard) {
        var data = valid
        data.replaceSubrange(64..<68, with: [0, 0, 0, 0])
        _ = try UdpPcmV2Packet.decode(data)
    }
}

@Test
func udpPcmParserRejectsPayloadLengthMismatch() throws {
    let valid = try loadPacketFixture(named: "valid-stereo-int16")

    try expectPacketError(.payloadLengthMismatch(expected: 12, actual: 8)) {
        var data = valid
        data.replaceSubrange(40..<44, with: [12, 0, 0, 0])
        _ = try UdpPcmPacket.decode(data)
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
func udpPcmLocalhostSmokeRoundTripsPacket() throws {
    let packet = try UdpPcmLocalhostSmoke.run()

    #expect(packet.header.sequenceNumber == 1)
    #expect(packet.header.senderHostTimeNanoseconds > 1)
    #expect(packet.header.framesPerPacket == 2)
    #expect(packet.header.channelCount == 2)
    #expect(packet.header.sampleFormat == .int16LittleEndian)
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

private func readUdpPcmPacketRepositoryText(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
