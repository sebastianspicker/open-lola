import Foundation

public struct UltraGridFECPayloadHeader: Codable, Equatable, Sendable {
    public static let byteCount = 20

    public var substreamID: UInt16
    public var bufferNumber: UInt32
    public var payloadOffset: UInt32
    public var payloadByteCount: UInt32
    public var k: UInt16
    public var m: UInt16
    public var c: UInt8
    public var seed: UInt32

    public init(
        substreamID: UInt16 = 0,
        bufferNumber: UInt32,
        payloadOffset: UInt32,
        payloadByteCount: UInt32,
        k: UInt16,
        m: UInt16,
        c: UInt8,
        seed: UInt32 = 1
    ) {
        self.substreamID = substreamID
        self.bufferNumber = bufferNumber
        self.payloadOffset = payloadOffset
        self.payloadByteCount = payloadByteCount
        self.k = k
        self.m = m
        self.c = c
        self.seed = seed
    }

    public static func decode<Bytes: DataProtocol>(_ data: Bytes) throws -> UltraGridFECPayloadHeader {
        let bytes = [UInt8](data)
        guard bytes.count >= byteCount else {
            throw UltraGridCompatibilityError.truncatedPayload(byteCount: bytes.count)
        }
        let word0 = readUltraGridUInt32BE(bytes, offset: 0)
        let params = readUltraGridUInt32BE(bytes, offset: 12)
        let header = UltraGridFECPayloadHeader(
            substreamID: UltraGridPayloadHeaderPacking.unpackSubstream(word0),
            bufferNumber: UltraGridPayloadHeaderPacking.unpackBufferNumber(word0),
            payloadOffset: readUltraGridUInt32BE(bytes, offset: 4),
            payloadByteCount: readUltraGridUInt32BE(bytes, offset: 8),
            k: UInt16(params & 0x1fff),
            m: UInt16((params >> 13) & 0x1fff),
            c: UInt8((params >> 26) & 0x3f),
            seed: readUltraGridUInt32BE(bytes, offset: 16)
        )
        try header.validate()
        return header
    }

    public func encoded() throws -> Data {
        try validate()
        var data = Data()
        data.reserveCapacity(Self.byteCount)
        appendUltraGridUInt32BE(
            try UltraGridPayloadHeaderPacking.packSubstreamAndBuffer(
                substreamID: substreamID,
                bufferNumber: bufferNumber
            ),
            to: &data
        )
        appendUltraGridUInt32BE(payloadOffset, to: &data)
        appendUltraGridUInt32BE(payloadByteCount, to: &data)
        let params = UInt32(k) | (UInt32(m) << 13) | (UInt32(c) << 26)
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
        try validateUltraGridPositive(Int(k), "fec.k")
        try validateUltraGridPositive(Int(m), "fec.m")
        guard c <= 63 else {
            throw UltraGridCompatibilityError.invalidField("fec.c", Int(c))
        }
    }
}

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
                k: UInt16(packets.count),
                m: 1,
                c: 2
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
        return (0..<header.k).map { base &+ $0 }
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
