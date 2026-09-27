// Verifies borrowed packet parsing while preserving public DataProtocol and owned-result behavior.
import Dispatch
import Foundation
import OpenLolaSessionDomain
@testable import OpenLolaTransport
import Testing

@Test func borrowedMediaDecodePreservesNestedPacketAndOwnsReturnedPayloads() throws {
    let nested = UdpPcmV2Packet(
        header: .init(
            stream: .init(streamID: 5),
            timing: .init(sequenceNumber: 9, senderFrameIndex: 12, senderHostTimeNanoseconds: 77),
            format: .init(
                sampleRateHertz: 48_000,
                framesPerPacket: 1,
                totalChannelCount: 1,
                sampleFormat: .float32LittleEndian,
                metadataRevision: 2,
                packingMode: .interleavedChannelRange
            ),
            fragment: .init(channelOffset: 0, channelsInFragment: 1, fragmentIndex: 0, fragmentCount: 1)
        ),
        payload: Data([1, 2, 3, 4])
    )
    let packet = UdpMediaPacket(
        header: .init(
            payloadType: .audioPcmV2,
            streamID: 5,
            sequenceNumber: 9,
            timestampNanoseconds: 77
        ),
        payload: try nested.encoded()
    )
    var encoded = try packet.encoded()
    let decoded = try UdpMediaPacket.decodeWithNestedPayload(encoded)
    encoded.resetBytes(in: encoded.startIndex..<encoded.endIndex)

    #expect(decoded.packet == packet)
    guard case .audioPcmV2(let decodedNested) = decoded.decodedPayload else {
        Issue.record("expected decoded PCM v2 payload")
        return
    }
    #expect(decodedNested == nested)
}

@Test func packetDecodersRetainSlicedAndMultiRegionDataProtocolBehavior() throws {
    let packet = UdpMediaPacket(
        header: .init(
            payloadType: .keepalive,
            streamID: 4,
            sequenceNumber: 11,
            timestampNanoseconds: 99
        ),
        payload: Data([8, 7, 6])
    )
    let encoded = try packet.encoded()
    var padded = Data([0xFF])
    padded.append(encoded)
    padded.append(0xEE)
    let slice = padded.dropFirst().dropLast()
    #expect(try decodeGenericMediaPacket(slice) == packet)

    let split = encoded.count / 2
    var regions = DispatchData.empty
    regions.append(dispatchData(encoded.prefix(split)))
    regions.append(dispatchData(encoded.suffix(from: split)))
    #expect(try decodeGenericMediaPacket(regions) == packet)
}

@Test func borrowedMediaDecodePreservesOuterErrorPrecedence() throws {
    #expect(throws: UdpMediaPacketError.truncatedPacket(byteCount: 3)) {
        _ = try UdpMediaPacket.decode(Data([0, 0, 0]))
    }
    var invalidMagic = Data(repeating: 0, count: UdpMediaPacketHeader.byteCount)
    invalidMagic[4] = UdpMediaPacketHeader.currentVersion &+ 1
    #expect(throws: UdpMediaPacketError.invalidMagic) {
        _ = try UdpMediaPacket.decode(invalidMagic)
    }
    invalidMagic.replaceSubrange(0..<4, with: UdpMediaPacketHeader.magic)
    #expect(throws: UdpMediaPacketError.unsupportedVersion(UdpMediaPacketHeader.currentVersion &+ 1)) {
        _ = try UdpMediaPacket.decode(invalidMagic)
    }
}

private func decodeGenericMediaPacket<Bytes: DataProtocol>(_ bytes: Bytes) throws -> UdpMediaPacket {
    try UdpMediaPacket.decode(bytes)
}

private func dispatchData<Bytes: DataProtocol>(_ bytes: Bytes) -> DispatchData {
    let data = Data(bytes)
    return data.withUnsafeBytes { DispatchData(bytes: $0) }
}
