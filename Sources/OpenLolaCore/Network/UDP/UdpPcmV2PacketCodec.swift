// Implements UdpPcmV2PacketCodec encoding and decoding, keeping wire representation apart from transport lifetime.
import Foundation

/// Defines the UdpPcmV2Packet wire representation shared by codecs and UDP media transport.
public struct UdpPcmV2Packet: PacketCodec {
    public static let maxPayloadByteCount = UdpPcmPacket.maxPayloadByteCount

    public var header: UdpPcmV2PacketHeader
    public var payload: Data

    public init(header: UdpPcmV2PacketHeader, payload: Data) {
        var header = header
        header.payloadByteCount = UInt32(payload.count)
        self.header = header
        self.payload = payload
    }

    public static func decode<Bytes: DataProtocol>(_ data: Bytes) throws -> UdpPcmV2Packet {
        let bytes = [UInt8](data)
        guard bytes.count >= UdpPcmV2PacketHeader.byteCount else {
            throw UdpPcmV2PacketError.truncatedPacket(byteCount: bytes.count)
        }
        let header = try decodedV2Header(from: bytes)
        try validateHeaderShape(header)
        _ = try validatedV2PayloadByteCount(bytes: bytes, header: header)
        return UdpPcmV2Packet(
            header: header,
            payload: Data(bytes[UdpPcmV2PacketHeader.byteCount...])
        )
    }

    public func encoded() throws -> Data {
        try validatePayload()

        var data = Data()
        data.reserveCapacity(UdpPcmV2PacketHeader.byteCount + payload.count)
        data.append(contentsOf: UdpPcmV2PacketHeader.magic)
        data.append(header.version)
        data.append(header.sampleFormat.rawValue)
        data.append(header.packingMode.wireValue)
        data.append(0)
        appendUdpAudioPacketHeaderPrefix(header, to: &data)
        appendUdpPcmUInt16LE(header.totalChannelCount, to: &data)
        appendUdpPcmUInt16LE(header.channelOffset, to: &data)
        appendUdpPcmUInt16LE(header.channelsInFragment, to: &data)
        appendUdpPcmUInt16LE(header.fragmentIndex, to: &data)
        appendUdpPcmUInt16LE(header.fragmentCount, to: &data)
        appendUdpPcmUInt16LE(0, to: &data)
        appendUdpPcmUInt32LE(header.metadataRevision, to: &data)
        appendUdpPcmUInt32LE(UInt32(payload.count), to: &data)
        appendUdpPcmUInt32LE(UdpPcmV2PacketHeader.headerGuard, to: &data)
        // Reserved trailer bytes keep the v2 header at the documented 80-byte wire length.
        data.append(contentsOf: repeatElement(0, count: UdpPcmV2PacketHeader.reservedPaddingByteCount))
        data.append(payload)
        return data
    }

    private func validatePayload() throws {
        var header = header
        header.payloadByteCount = UInt32(payload.count)
        try validateHeaderShape(header)
        guard payload.count <= Self.maxPayloadByteCount else {
            throw UdpPcmV2PacketError.payloadTooLarge(payload.count)
        }
        let expected = expectedV2PayloadByteCount(header)
        if payload.count != expected {
            throw UdpPcmV2PacketError.payloadLengthMismatch(
                expected: expected,
                actual: payload.count
            )
        }
    }
}

extension UdpPcmV2PacketHeader: UdpAudioPacketHeaderPrefixProviding {
    var udpAudioFrameCount: UInt32 { framesPerPacket }
}

/// Enumerates failures that callers must handle when working with UDP media transport.
public enum UdpPcmV2PacketizerError: Error, Equatable, Sendable {
    case invalidModeProtocol(AudioTransportProtocolVersion)
    case missingFragments
    case payloadLengthMismatch(expected: Int, actual: Int)
    case fragmentPlanMismatch(String)
    case packetExceedsMtu(packetByteCount: Int, maxTransmissionUnitBytes: Int)
}

private func decodedV2Header(from bytes: [UInt8]) throws -> UdpPcmV2PacketHeader {
    try validateV2HeaderPrefix(bytes)
    let sampleFormat = try decodedV2SampleFormat(bytes)
    let packingMode = try decodedV2PackingMode(bytes)
    let fields = try decodedV2HeaderFields(from: bytes)
    guard fields.headerGuard == UdpPcmV2PacketHeader.headerGuard else {
        throw UdpPcmV2PacketError.invalidHeaderGuard
    }
    return UdpPcmV2PacketHeader(
        stream: .init(version: bytes[4], streamID: fields.streamID),
        timing: .init(
            sequenceNumber: fields.sequenceNumber,
            senderFrameIndex: fields.senderFrameIndex,
            senderHostTimeNanoseconds: fields.senderHostTimeNanoseconds
        ),
        format: .init(
            sampleRateHertz: fields.sampleRateHertz,
            framesPerPacket: fields.framesPerPacket,
            totalChannelCount: fields.totalChannelCount,
            sampleFormat: sampleFormat,
            metadataRevision: fields.metadataRevision,
            packingMode: packingMode
        ),
        fragment: .init(
            channelOffset: fields.channelOffset,
            channelsInFragment: fields.channelsInFragment,
            fragmentIndex: fields.fragmentIndex,
            fragmentCount: fields.fragmentCount
        ),
        payloadByteCount: fields.payloadByteCount
    )
}

private func validateV2HeaderPrefix(_ bytes: [UInt8]) throws {
    guard Array(bytes[0..<4]) == UdpPcmV2PacketHeader.magic else {
        throw UdpPcmV2PacketError.invalidMagic
    }
    let version = bytes[4]
    guard version == UdpPcmV2PacketHeader.currentVersion else {
        throw UdpPcmV2PacketError.unsupportedVersion(version)
    }
}

private func decodedV2SampleFormat(_ bytes: [UInt8]) throws -> UdpPcmSampleFormat {
    let formatValue = bytes[5]
    guard let sampleFormat = UdpPcmSampleFormat(rawValue: formatValue) else {
        throw UdpPcmV2PacketError.unsupportedSampleFormat(formatValue)
    }
    return sampleFormat
}

private func decodedV2PackingMode(_ bytes: [UInt8]) throws -> AudioWirePackingMode {
    let packingValue = bytes[6]
    guard let packingMode = AudioWirePackingMode(wireValue: packingValue) else {
        throw UdpPcmV2PacketError.unsupportedPackingMode(packingValue)
    }
    return packingMode
}

private struct UdpPcmV2DecodedHeaderFields {
    var streamID: UInt32
    var sequenceNumber: UInt64
    var senderFrameIndex: UInt64
    var senderHostTimeNanoseconds: UInt64
    var sampleRateHertz: UInt32
    var framesPerPacket: UInt32
    var totalChannelCount: UInt16
    var channelOffset: UInt16
    var channelsInFragment: UInt16
    var fragmentIndex: UInt16
    var fragmentCount: UInt16
    var metadataRevision: UInt32
    var payloadByteCount: UInt32
    var headerGuard: UInt32
}

private func decodedV2HeaderFields(from bytes: [UInt8]) throws -> UdpPcmV2DecodedHeaderFields {
    UdpPcmV2DecodedHeaderFields(
        streamID: try readCheckedUdpPcmUInt32LE(bytes, offset: 8),
        sequenceNumber: try readCheckedUdpPcmUInt64LE(bytes, offset: 12),
        senderFrameIndex: try readCheckedUdpPcmUInt64LE(bytes, offset: 20),
        senderHostTimeNanoseconds: try readCheckedUdpPcmUInt64LE(bytes, offset: 28),
        sampleRateHertz: try readCheckedUdpPcmUInt32LE(bytes, offset: 36),
        framesPerPacket: try readCheckedUdpPcmUInt32LE(bytes, offset: 40),
        totalChannelCount: try readCheckedUdpPcmUInt16LE(bytes, offset: 44),
        channelOffset: try readCheckedUdpPcmUInt16LE(bytes, offset: 46),
        channelsInFragment: try readCheckedUdpPcmUInt16LE(bytes, offset: 48),
        fragmentIndex: try readCheckedUdpPcmUInt16LE(bytes, offset: 50),
        fragmentCount: try readCheckedUdpPcmUInt16LE(bytes, offset: 52),
        metadataRevision: try readCheckedUdpPcmUInt32LE(bytes, offset: 56),
        payloadByteCount: try readCheckedUdpPcmUInt32LE(bytes, offset: 60),
        headerGuard: try readCheckedUdpPcmUInt32LE(bytes, offset: 64)
    )
}

private func validatedV2PayloadByteCount(
    bytes: [UInt8],
    header: UdpPcmV2PacketHeader
) throws -> Int {
    let actualPayloadByteCount = bytes.count - UdpPcmV2PacketHeader.byteCount
    let declaredPayloadByteCount = Int(header.payloadByteCount)
    try validateV2DeclaredPayloadLength(
        declaredPayloadByteCount,
        actualPayloadByteCount: actualPayloadByteCount,
        packetByteCount: bytes.count
    )
    guard declaredPayloadByteCount <= UdpPcmV2Packet.maxPayloadByteCount else {
        throw UdpPcmV2PacketError.payloadTooLarge(declaredPayloadByteCount)
    }
    let expectedPayloadByteCount = expectedV2PayloadByteCount(header)
    guard expectedPayloadByteCount == declaredPayloadByteCount else {
        throw UdpPcmV2PacketError.payloadLengthMismatch(
            expected: expectedPayloadByteCount,
            actual: declaredPayloadByteCount
        )
    }
    return declaredPayloadByteCount
}

private func validateV2DeclaredPayloadLength(
    _ declaredPayloadByteCount: Int,
    actualPayloadByteCount: Int,
    packetByteCount: Int
) throws {
    if actualPayloadByteCount > declaredPayloadByteCount {
        throw UdpPcmV2PacketError.oversizedPacket(
            expected: UdpPcmV2PacketHeader.byteCount + declaredPayloadByteCount,
            actual: packetByteCount
        )
    }
    if actualPayloadByteCount != declaredPayloadByteCount {
        throw UdpPcmV2PacketError.payloadLengthMismatch(
            expected: declaredPayloadByteCount,
            actual: actualPayloadByteCount
        )
    }
}

private func validateHeaderShape(_ header: UdpPcmV2PacketHeader) throws {
    try validateHeaderIdentity(header)
    guard header.totalChannelCount > 0 else {
        throw UdpPcmV2PacketError.invalidTotalChannelCount(header.totalChannelCount)
    }
    guard header.channelsInFragment > 0,
          Int(header.channelOffset) + Int(header.channelsInFragment)
            <= Int(header.totalChannelCount) else {
        throw UdpPcmV2PacketError.invalidChannelRange(
            totalChannelCount: header.totalChannelCount,
            channelOffset: header.channelOffset,
            channelsInFragment: header.channelsInFragment
        )
    }
    guard header.fragmentCount > 0 else {
        throw UdpPcmV2PacketError.invalidFragmentCount(header.fragmentCount)
    }
    guard header.fragmentIndex < header.fragmentCount else {
        throw UdpPcmV2PacketError.invalidFragmentIndex(
            index: header.fragmentIndex,
            count: header.fragmentCount
        )
    }
    guard header.framesPerPacket > 0 else {
        throw UdpPcmV2PacketError.invalidFrameCount(header.framesPerPacket)
    }
    guard header.sampleRateHertz > 0 else {
        throw UdpPcmV2PacketError.invalidSampleRate(header.sampleRateHertz)
    }
    try validateHeaderTiming(header)
}

private func validateHeaderIdentity(_ header: UdpPcmV2PacketHeader) throws {
    guard header.version == UdpPcmV2PacketHeader.currentVersion else {
        throw UdpPcmV2PacketError.unsupportedVersion(header.version)
    }
    guard header.streamID > 0 else {
        throw UdpPcmV2PacketError.invalidStreamID(header.streamID)
    }
}

private func validateHeaderTiming(_ header: UdpPcmV2PacketHeader) throws {
    guard header.senderHostTimeNanoseconds > 0 else {
        throw UdpPcmV2PacketError.invalidTimestamp(header.senderHostTimeNanoseconds)
    }
}
