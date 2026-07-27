// Implements UltraGridFEC media protection behavior, keeping transform policy separate from socket I/O.
import Foundation

/// Encodes the UltraGrid FEC header fields that locate a parity block within a protected payload.
public struct UltraGridFECPayloadHeader: Codable, Equatable, Sendable, UltraGridPayloadHeaderPrefixFields {
    public static let byteCount = 20

    public var substreamID: UInt16
    public var bufferNumber: UInt32
    public var payloadOffset: UInt32
    public var payloadByteCount: UInt32
    public var sourceCount: UInt16
    public var repairCount: UInt16
    public var codingId: UInt8
    public var seed: UInt32

    enum CodingKeys: String, CodingKey {
        case substreamID
        case bufferNumber
        case payloadOffset
        case payloadByteCount
        case sourceCount = "k"
        case repairCount = "m"
        case codingId = "c"
        case seed
    }

    public init(
        substreamID: UInt16 = 0,
        bufferNumber: UInt32,
        payloadOffset: UInt32,
        payloadByteCount: UInt32,
        sourceCount: UInt16,
        repairCount: UInt16,
        codingId: UInt8,
        seed: UInt32 = 1
    ) {
        self.substreamID = substreamID
        self.bufferNumber = bufferNumber
        self.payloadOffset = payloadOffset
        self.payloadByteCount = payloadByteCount
        self.sourceCount = sourceCount
        self.repairCount = repairCount
        self.codingId = codingId
        self.seed = seed
    }

    public static func decode<Bytes: DataProtocol>(_ data: Bytes) throws -> UltraGridFECPayloadHeader {
        let bytes = [UInt8](data)
        let prefix = try UltraGridPayloadHeaderPrefix.decode(bytes, minimumByteCount: byteCount)
        let params = readUltraGridUInt32BE(bytes, offset: 12)
        let header = UltraGridFECPayloadHeader(
            substreamID: prefix.substreamID,
            bufferNumber: prefix.bufferNumber,
            payloadOffset: prefix.payloadOffset,
            payloadByteCount: prefix.payloadByteCount,
            sourceCount: UInt16(params & 0x1fff),
            repairCount: UInt16((params >> 13) & 0x1fff),
            codingId: UInt8((params >> 26) & 0x3f),
            seed: readUltraGridUInt32BE(bytes, offset: 16)
        )
        try header.validate()
        return header
    }

    public func encoded() throws -> Data {
        try validate()
        var data = try encodeUltraGridPayloadHeaderPrefix(self, reservingCapacity: Self.byteCount)
        let params = UInt32(sourceCount) | (UInt32(repairCount) << 13) | (UInt32(codingId) << 26)
        appendUltraGridUInt32BE(params, to: &data)
        appendUltraGridUInt32BE(seed, to: &data)
        return data
    }

    public func validate() throws {
        _ = try UltraGridPayloadHeaderPacking.packSubstreamAndBuffer(
            substreamID: substreamID,
            bufferNumber: bufferNumber
        )
        try validateUltraGridPositive(Int(payloadByteCount), "fec.payloadByteCount")
        try validateUltraGridPositive(Int(sourceCount), "fec.k")
        try validateUltraGridPositive(Int(repairCount), "fec.m")
        guard codingId <= 63 else {
            throw UltraGridCompatibilityError.invalidField("fec.c", Int(codingId))
        }
    }
}

/// Pairs an UltraGrid FEC header with repair bytes used to recover a protected media block.
public struct UltraGridFECPayload: PacketCodec {
    public static let headerByteCount = UltraGridFECPayloadHeader.byteCount

    public var header: UltraGridFECPayloadHeader
    public var repairPayload: Data

    public init(header: UltraGridFECPayloadHeader, repairPayload: Data) {
        self.header = header
        self.repairPayload = repairPayload
    }

    public static func decode<Bytes: DataProtocol>(_ data: Bytes) throws -> UltraGridFECPayload {
        let bytes = [UInt8](data)
        let header = try UltraGridFECPayloadHeader.decode(bytes)
        return UltraGridFECPayload(
            header: header,
            repairPayload: Data(bytes[headerByteCount..<bytes.count])
        )
    }

    public func encoded() throws -> Data {
        var data = try header.encoded()
        data.append(repairPayload)
        return data
    }
}

enum UltraGridFECRecovery {
    static func parityPacket(
        protecting packets: [RTPPacket],
        sequenceNumber: UInt16,
        timestamp: UInt32,
        ssrc: UInt32
    ) throws -> RTPPacket {
        guard let first = packets.first else {
            throw UltraGridCompatibilityError.invalidField("fec.protectedPacketCount", 0)
        }
        let firstFragment = try UltraGridVideoRawFragmentPayload.decode(first.payload)
        let parity = packets.reduce(Data()) { current, packet in
            xor(current, packet.payload)
        }
        let payload = try UltraGridFECPayload(
            header: UltraGridFECPayloadHeader(
                bufferNumber: firstFragment.frameID,
                payloadOffset: UInt32(first.header.sequenceNumber),
                payloadByteCount: UInt32(packets.count),
                sourceCount: UInt16(packets.count),
                repairCount: 1,
                codingId: 2
            ),
            repairPayload: parity
        ).encoded()
        return RTPPacket(
            header: RTPPacketHeader(
                payloadType: UltraGridCompatibility.fecPayloadType,
                marker: true,
                sequenceNumber: sequenceNumber,
                timestamp: timestamp,
                ssrc: ssrc
            ),
            payload: payload
        )
    }

    static func recoverVideoFragments(from packets: [RTPPacket]) throws -> [UltraGridVideoRawFragmentPayload] {
        var rawPackets: [UInt16: RTPPacket] = [:]
        var fragments: [UltraGridVideoRawFragmentPayload] = []
        var fecPayloads: [UltraGridFECPayload] = []
        for packet in packets {
            if packet.header.payloadType == UltraGridCompatibility.fecPayloadType {
                fecPayloads.append(try UltraGridFECPayload.decode(packet.payload))
            } else {
                let fragment = try UltraGridVideoRawFragmentPayload.decode(packet.payload)
                rawPackets[packet.header.sequenceNumber] = packet
                fragments.append(fragment)
            }
        }
        guard let fec = fecPayloads.first else {
            return fragments
        }
        guard let missingSequence = missingProtectedSequence(fec.header, rawPackets) else {
            return fragments
        }
        var recovered = fec.repairPayload
        for sequence in protectedSequences(fec.header) where sequence != missingSequence {
            guard let packet = rawPackets[sequence] else {
                throw UltraGridCompatibilityError.reassemblyIncomplete(missing: [sequence])
            }
            recovered = xor(recovered, packet.payload)
        }
        let trimmed = try trimRecoveredPayload(recovered, sequence: missingSequence, rawPackets: rawPackets)
        fragments.append(try UltraGridVideoRawFragmentPayload.decode(trimmed))
        return fragments
    }

    private static func missingProtectedSequence(
        _ header: UltraGridFECPayloadHeader,
        _ rawPackets: [UInt16: RTPPacket]
    ) -> UInt16? {
        let missing = protectedSequences(header).filter { rawPackets[$0] == nil }
        return missing.count == 1 ? missing[0] : nil
    }

    private static func protectedSequences(_ header: UltraGridFECPayloadHeader) -> [UInt16] {
        let base = UInt16(truncatingIfNeeded: header.payloadOffset)
        return (0..<header.sourceCount).map { base &+ $0 }
    }

    private static func trimRecoveredPayload(
        _ payload: Data,
        sequence: UInt16,
        rawPackets: [UInt16: RTPPacket]
    ) throws -> Data {
        let header = try UltraGridVideoPayloadHeader.decode([UInt8](payload))
        let length = try recoveredPayloadLength(header, sequence: sequence, rawPackets: rawPackets)
        guard payload.count >= length else {
            throw UltraGridCompatibilityError.truncatedPayload(byteCount: payload.count)
        }
        return Data(payload.prefix(length))
    }

    private static func recoveredPayloadLength(
        _ header: UltraGridVideoPayloadHeader,
        sequence: UInt16,
        rawPackets: [UInt16: RTPPacket]
    ) throws -> Int {
        let existing = try rawPackets.values
            .map { try UltraGridVideoRawFragmentPayload.decode($0.payload) }
            .sorted { $0.payloadOffset < $1.payloadOffset }
        let offsets = existing.map(\.payloadOffset).filter { $0 > header.payloadOffset }
        let nextOffset = offsets.min() ?? header.payloadByteCount
        guard nextOffset > header.payloadOffset else {
            throw UltraGridCompatibilityError.reassemblyIncomplete(missing: [sequence])
        }
        return UltraGridVideoRawFragmentPayload.headerByteCount + Int(nextOffset - header.payloadOffset)
    }

    private static func xor(_ lhs: Data, _ rhs: Data) -> Data {
        let count = max(lhs.count, rhs.count)
        var output = Data(count: count)
        for index in 0..<count {
            let left = index < lhs.count ? lhs[lhs.index(lhs.startIndex, offsetBy: index)] : 0
            let right = index < rhs.count ? rhs[rhs.index(rhs.startIndex, offsetBy: index)] : 0
            output[output.index(output.startIndex, offsetBy: index)] = left ^ right
        }
        return output
    }
}
