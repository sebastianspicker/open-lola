import Foundation
import Testing

@testable import OpenLolaCore

@Test
func udpPcmV2PacketizerCarriesMadiMetadataAcrossFragments() throws {
    let fragments = try UdpPcmV2FragmentPlanner.plan(
        UdpPcmV2FragmentPlanRequest(
            streamID: 5,
            totalChannelCount: 16,
            framesPerPacket: 32,
            sampleRateHertz: 48_000,
            sampleFormat: .float32LittleEndian,
            maxTransmissionUnitBytes: 1_200,
            maxFragmentsPerDeadline: 16,
            metadataRevision: 77,
            packingMode: .interleavedChannelRange
        )
    )
    let mode = AudioTransportMode(
        protocolVersion: .udpPcmV2,
        sampleRateHertz: 48_000,
        framesPerPacket: 32,
        channelCount: 16,
        sampleFormat: .float32LittleEndian,
        latencyProfile: .safeLowLatency,
        rxBufferProfile: .direct,
        maxTransmissionUnitBytes: 1_200,
        channelOrder: AudioChannelSet.defaultInput(count: 16).sortedByStableSourceIndex,
        fragments: fragments
    )
    let payload = Data((0..<mode.framesPerPacket
        * mode.channelCount
        * mode.sampleFormat.bytesPerSample).map { UInt8($0 % 251) })

    let packets = try UdpPcmV2Packetizer.packetize(
        payload,
        sequenceNumber: 12,
        senderFrameIndex: 384,
        senderHostTimeNanoseconds: 1_000,
        mode: mode
    )

    #expect(packets.count == 2)
    #expect(packets.map(\.header.streamID) == [5, 5])
    #expect(packets.map(\.header.metadataRevision) == [77, 77])
    #expect(packets.map(\.header.channelOffset) == [0, 8])
    #expect(packets.map(\.header.channelsInFragment) == [8, 8])
    #expect(packets.map(\.header.fragmentIndex) == [0, 1])
}

@Test
func udpPcmV2FragmentPlannerRejectsByteCountOverflow() {
    #expect(throws: UdpPcmV2FragmentPlanningError.arithmeticOverflow("bytesPerChannel")) {
        _ = try UdpPcmV2FragmentPlanner.plan(
            UdpPcmV2FragmentPlanRequest(
                streamID: 1,
                totalChannelCount: 2,
                framesPerPacket: Int.max,
                sampleRateHertz: 48_000,
                sampleFormat: .float32LittleEndian,
                maxTransmissionUnitBytes: Int.max,
                maxFragmentsPerDeadline: 16,
                metadataRevision: 0,
                packingMode: .interleavedChannelRange
            )
        )
    }
}

@Test
func udpPcmV2FragmentPlannerRejectsPlannedChannelCapacityOverflow() {
    #expect(throws: UdpPcmV2FragmentPlanningError.arithmeticOverflow("plannedChannelCapacity")) {
        _ = try UdpPcmV2FragmentPlanner.plan(
            UdpPcmV2FragmentPlanRequest(
                streamID: 1,
                totalChannelCount: Int.max,
                framesPerPacket: 1,
                sampleRateHertz: 48_000,
                sampleFormat: .int16LittleEndian,
                maxTransmissionUnitBytes: UdpPcmV2PacketHeader.byteCount + 4,
                maxFragmentsPerDeadline: Int.max,
                metadataRevision: 0,
                packingMode: .interleavedChannelRange
            )
        )
    }
}

@Test
func udpPcmV2FragmentPlannerThrowsInsteadOfPreconditioningCoverage() throws {
    let source = try readUdpPcmV2RepositorySource(
        "Sources/OpenLolaCore/Network/UDP/UdpPcmV2FragmentPlanner.swift"
    )

    #expect(source.contains("case channelCoverageMismatch(planned: Int, expected: Int)"))
    #expect(source.contains("guard plannedChannelCount == request.totalChannelCount else"))
    #expect(source.contains("throw UdpPcmV2FragmentPlanningError.channelCoverageMismatch("))
    #expect(!source.contains("precondition("))
}

@Test
func udpPcmV2PacketRoundTripPreservesHeaderAndPayload() throws {
    let packet = validUdpPcmV2Packet()

    let decoded = try UdpPcmV2Packet.decode(packet.encoded())

    #expect(decoded == packet)
}

@Test
func udpPcmV2PacketDecodeRejectsEveryTruncatedHeaderBoundary() throws {
    let encoded = try validUdpPcmV2Packet().encoded()

    for byteCount in 0..<UdpPcmV2PacketHeader.byteCount {
        #expect(throws: UdpPcmV2PacketError.truncatedPacket(byteCount: byteCount)) {
            _ = try UdpPcmV2Packet.decode(encoded.prefix(byteCount))
        }
    }
}

@Test
func udpPcmV2PacketDecodeRejectsHeaderGuardMismatch() throws {
    var encoded = try validUdpPcmV2Packet().encoded()
    encoded[64] = 0

    #expect(throws: UdpPcmV2PacketError.invalidHeaderGuard) {
        _ = try UdpPcmV2Packet.decode(encoded)
    }
}

@Test
func udpPcmV2PacketUsesPrivateCheckedReadersOnly() throws {
    let source = try readUdpPcmV2PacketSource()
    let helperSource = try readUdpPcmV2RepositorySource(
        "Sources/OpenLolaCore/Network/UDP/NetworkByteReader.swift"
    )
    let mediaSource = try readUdpPcmV2RepositorySource(
        "Sources/OpenLolaCore/Network/UDP/UdpMediaTransport.swift"
    )
    let rtpSource = try readUdpPcmV2RepositorySource(
        "Sources/OpenLolaCore/Network/RTP/AES67ST2110L24Transport.swift"
    )

    #expect(source.contains("private func readCheckedUdpPcmUInt16LE"))
    #expect(source.contains("private func readCheckedUdpPcmUInt32LE"))
    #expect(source.contains("private func readCheckedUdpPcmUInt64LE"))
    #expect(helperSource.contains("enum NetworkByteReader"))
    #expect(helperSource.contains("static func readUInt16BE"))
    #expect(helperSource.contains("static func readUInt32LE"))
    #expect(source.contains("NetworkByteReader.readUInt16LE"))
    #expect(mediaSource.contains("NetworkByteReader.readUInt64LE"))
    #expect(rtpSource.contains("NetworkByteReader.readUInt32BE"))
    #expect(!source.contains("func readUdpPcmUInt16LE"))
    #expect(!source.contains("func readUdpPcmUInt32LE"))
    #expect(!source.contains("func readUdpPcmUInt64LE"))
}

@Test
func udpPcmV2PacketDecodeRejectsDeclaredPayloadLengthMismatch() throws {
    var encoded = try validUdpPcmV2Packet().encoded()
    encoded.removeLast()

    #expect(throws: UdpPcmV2PacketError.payloadLengthMismatch(expected: 128, actual: 127)) {
        _ = try UdpPcmV2Packet.decode(encoded)
    }
}

@Test
func udpPcmV2PacketDecodeRejectsInvalidMagic() throws {
    var encoded = try validUdpPcmV2Packet().encoded()
    encoded[0] = UInt8(ascii: "X")

    #expect(throws: UdpPcmV2PacketError.invalidMagic) {
        _ = try UdpPcmV2Packet.decode(encoded)
    }
}

@Test
func udpPcmV2PacketDecodeRejectsZeroChannelCount() throws {
    var encoded = try validUdpPcmV2Packet().encoded()
    encoded[44] = 0
    encoded[45] = 0

    #expect(throws: UdpPcmV2PacketError.invalidTotalChannelCount(0)) {
        _ = try UdpPcmV2Packet.decode(encoded)
    }
}

@Test
func udpPcmV2PacketDecodeRejectsFragmentIndexAtCount() throws {
    var encoded = try validUdpPcmV2Packet().encoded()
    encoded[50] = 1
    encoded[51] = 0
    encoded[52] = 1
    encoded[53] = 0

    #expect(throws: UdpPcmV2PacketError.invalidFragmentIndex(index: 1, count: 1)) {
        _ = try UdpPcmV2Packet.decode(encoded)
    }
}

@Test
func udpPcmV2ReassemblerCompletesOutOfOrderFragmentsAndAccountsDuplicates() throws {
    let mode = try sixteenChannelMode()
    let payload = Data((0..<mode.framesPerPacket
        * mode.channelCount
        * mode.sampleFormat.bytesPerSample).map { UInt8($0 % 251) })
    let packets = try UdpPcmV2Packetizer.packetize(
        payload,
        sequenceNumber: 77,
        senderFrameIndex: 2_464,
        senderHostTimeNanoseconds: 10_000,
        mode: mode
    )

    let result = try UdpPcmV2FragmentReassembler.reassemble([
        packets[1],
        packets[0],
        packets[1],
    ])

    #expect(result.sequenceNumber == 77)
    #expect(result.missingFragmentIndices.isEmpty)
    #expect(result.duplicateFragmentIndices == [1])
    #expect(result.payload == payload)
}

@Test
func udpPcmV2ReassemblerRejectsStreamMismatch() throws {
    let mode = try sixteenChannelMode()
    let payload = Data(repeating: 1, count: mode.framesPerPacket
        * mode.channelCount
        * mode.sampleFormat.bytesPerSample)
    var packets = try UdpPcmV2Packetizer.packetize(
        payload,
        sequenceNumber: 78,
        senderFrameIndex: 2_496,
        senderHostTimeNanoseconds: 11_000,
        mode: mode
    )
    packets[1].header.streamID = 99

    #expect(throws: UdpPcmV2FragmentReassemblyError.inconsistentDeadline("streamID")) {
        _ = try UdpPcmV2FragmentReassembler.reassemble(packets)
    }
}

@Test
func udpPcmV2ReassemblerRejectsOutOfRangeFragmentPayloadCopy() throws {
    let packet = UdpPcmV2Packet(
        header: UdpPcmV2PacketHeader(
            streamID: 5,
            sequenceNumber: 79,
            senderFrameIndex: 2_528,
            senderHostTimeNanoseconds: 12_000,
            sampleRateHertz: 48_000,
            framesPerPacket: 32,
            totalChannelCount: 16,
            channelOffset: 15,
            channelsInFragment: 2,
            fragmentIndex: 0,
            fragmentCount: 1,
            sampleFormat: .float32LittleEndian,
            metadataRevision: 77,
            packingMode: .interleavedChannelRange
        ),
        payload: Data(repeating: 1, count: 32 * 2 * 4)
    )

    #expect(throws: UdpPcmV2FragmentReassemblyError.invalidFragmentPayload(index: 0)) {
        _ = try UdpPcmV2FragmentReassembler.reassemble([packet])
    }
}

@Test
func udpPcmV2PacketizerRejectsOutOfRangeFragmentPayloadCopy() throws {
    var mode = try sixteenChannelMode()
    mode.fragments = [
        UdpPcmV2ChannelFragmentPlan(
            streamID: 5,
            totalChannelCount: 16,
            channelOffset: 15,
            channelsInFragment: 2,
            fragmentIndex: 0,
            fragmentCount: 1,
            framesPerPacket: 32,
            sampleRateHertz: 48_000,
            sampleFormat: .float32LittleEndian,
            metadataRevision: 77,
            packingMode: .interleavedChannelRange,
            payloadByteCount: 32 * 2 * 4,
            packetByteCount: UdpPcmV2PacketHeader.byteCount + (32 * 2 * 4)
        ),
    ]
    let payload = Data(repeating: 1, count: mode.framesPerPacket
        * mode.channelCount
        * mode.sampleFormat.bytesPerSample)

    #expect(throws: UdpPcmV2PacketizerError.fragmentPlanMismatch("fragmentPayloadBounds")) {
        _ = try UdpPcmV2Packetizer.packetize(
            payload,
            sequenceNumber: 80,
            senderFrameIndex: 2_560,
            senderHostTimeNanoseconds: 13_000,
            mode: mode
        )
    }
}

@Test
func udpPcmV2PacketizerChecksFragmentPayloadBoundsImmediatelyBeforeCopy() throws {
    let source = try readUdpPcmV2PacketSource()
    let sourceEnd = try #require(source.range(of: "let sourceEnd = try checkedV2PacketizerSum("))
    let destinationEnd = try #require(source.range(of: "let destinationEnd = try checkedV2PacketizerSum("))
    let boundsGuard = try #require(source.range(of: "guard sourceEnd <= sourceBytes.count,"))
    let copyCall = try #require(source.range(of: "memcpy("))

    #expect(sourceEnd.lowerBound < boundsGuard.lowerBound)
    #expect(destinationEnd.lowerBound < boundsGuard.lowerBound)
    #expect(boundsGuard.lowerBound < copyCall.lowerBound)
    #expect(source.contains("destinationEnd <= destinationBytes.count"))
    #expect(source.contains("fragmentPayloadBounds"))
}

private func sixteenChannelMode() throws -> AudioTransportMode {
    let fragments = try UdpPcmV2FragmentPlanner.plan(
        UdpPcmV2FragmentPlanRequest(
            streamID: 5,
            totalChannelCount: 16,
            framesPerPacket: 32,
            sampleRateHertz: 48_000,
            sampleFormat: .float32LittleEndian,
            maxTransmissionUnitBytes: 1_200,
            maxFragmentsPerDeadline: 16,
            metadataRevision: 77,
            packingMode: .interleavedChannelRange
        )
    )
    return AudioTransportMode(
        protocolVersion: .udpPcmV2,
        sampleRateHertz: 48_000,
        framesPerPacket: 32,
        channelCount: 16,
        sampleFormat: .float32LittleEndian,
        latencyProfile: .safeLowLatency,
        rxBufferProfile: .direct,
        maxTransmissionUnitBytes: 1_200,
        channelOrder: AudioChannelSet.defaultInput(count: 16).sortedByStableSourceIndex,
        fragments: fragments
    )
}

private func readUdpPcmV2PacketSource() throws -> String {
    try readUdpPcmV2RepositorySource("Sources/OpenLolaCore/Network/UDP/UdpPcmV2Packet.swift")
}

private func readUdpPcmV2RepositorySource(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(
        contentsOf: root.appendingPathComponent(relativePath),
        encoding: .utf8
    )
}

private func validUdpPcmV2Packet() -> UdpPcmV2Packet {
    UdpPcmV2Packet(
        header: UdpPcmV2PacketHeader(
            streamID: 7,
            sequenceNumber: 42,
            senderFrameIndex: 1_344,
            senderHostTimeNanoseconds: 9_000,
            sampleRateHertz: 48_000,
            framesPerPacket: 32,
            totalChannelCount: 2,
            channelOffset: 0,
            channelsInFragment: 2,
            fragmentIndex: 0,
            fragmentCount: 1,
            sampleFormat: .int16LittleEndian,
            metadataRevision: 3,
            packingMode: .interleavedChannelRange
        ),
        payload: Data((0..<128).map(UInt8.init))
    )
}
