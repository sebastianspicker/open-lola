import Foundation

public struct UltraGridAudioPayloadHeader: Codable, Equatable, Sendable {
    public static let byteCount = 20
    public static let maxSampleRateHertz = 0x03ff_ffff
    public static let maxQuantizationBits = 0x3f

    public var substreamID: UInt16
    public var bufferNumber: UInt32
    public var payloadOffset: UInt32
    public var payloadByteCount: UInt32
    public var quantizationBits: UInt8
    public var sampleRateHertz: UInt32
    public var audioTag: UInt32

    public init(
        substreamID: UInt16 = 0,
        bufferNumber: UInt32,
        payloadOffset: UInt32,
        payloadByteCount: UInt32,
        quantizationBits: UInt8,
        sampleRateHertz: UInt32,
        audioTag: UInt32 = UltraGridPCMAudioTag.littleEndianPCM
    ) {
        self.substreamID = substreamID
        self.bufferNumber = bufferNumber
        self.payloadOffset = payloadOffset
        self.payloadByteCount = payloadByteCount
        self.quantizationBits = quantizationBits
        self.sampleRateHertz = sampleRateHertz
        self.audioTag = audioTag
    }

    public static func decode(_ bytes: [UInt8]) throws -> UltraGridAudioPayloadHeader {
        guard bytes.count >= byteCount else {
            throw UltraGridCompatibilityError.truncatedPayload(byteCount: bytes.count)
        }
        let word0 = readUltraGridUInt32BE(bytes, offset: 0)
        let word3 = readUltraGridUInt32BE(bytes, offset: 12)
        let header = UltraGridAudioPayloadHeader(
            substreamID: UltraGridPayloadHeaderPacking.unpackSubstream(word0),
            bufferNumber: UltraGridPayloadHeaderPacking.unpackBufferNumber(word0),
            payloadOffset: readUltraGridUInt32BE(bytes, offset: 4),
            payloadByteCount: readUltraGridUInt32BE(bytes, offset: 8),
            quantizationBits: UInt8(word3 & UInt32(maxQuantizationBits)),
            sampleRateHertz: word3 >> 6,
            audioTag: readUltraGridUInt32BE(bytes, offset: 16)
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
        appendUltraGridUInt32BE((sampleRateHertz << 6) | UInt32(quantizationBits), to: &data)
        appendUltraGridUInt32BE(audioTag, to: &data)
        return data
    }

    public func validate() throws {
        _ = try UltraGridPayloadHeaderPacking.packSubstreamAndBuffer(
            substreamID: substreamID,
            bufferNumber: bufferNumber
        )
        guard payloadByteCount > 0 else {
            throw UltraGridCompatibilityError.invalidField("audio.payloadByteCount", Int(payloadByteCount))
        }
        guard quantizationBits > 0, quantizationBits <= Self.maxQuantizationBits else {
            throw UltraGridCompatibilityError.invalidField("audio.quantizationBits", Int(quantizationBits))
        }
        guard sampleRateHertz > 0, sampleRateHertz <= UInt32(Self.maxSampleRateHertz) else {
            throw UltraGridCompatibilityError.invalidField("audio.sampleRateHertz", Int(sampleRateHertz))
        }
        guard audioTag == UltraGridPCMAudioTag.littleEndianPCM || audioTag == UltraGridPCMAudioTag.bigEndianPCM else {
            throw UltraGridCompatibilityError.unsupportedMode("audio-tag-\(audioTag)")
        }
    }
}

public struct UltraGridAudioPayload: PacketCodec {
    public static let headerByteCount = UltraGridAudioPayloadHeader.byteCount

    public var header: UltraGridAudioPayloadHeader
    public var pcmPayload: Data

    public init(header: UltraGridAudioPayloadHeader, pcmPayload: Data) {
        self.header = header
        self.pcmPayload = pcmPayload
    }

    public static func decode<Bytes: DataProtocol>(_ data: Bytes) throws -> UltraGridAudioPayload {
        let bytes = [UInt8](data)
        let header = try UltraGridAudioPayloadHeader.decode(bytes)
        let payload = Data(bytes[headerByteCount..<bytes.count])
        guard payload.count == Int(header.payloadByteCount) else {
            throw UltraGridCompatibilityError.invalidPayloadLength(
                expected: Int(header.payloadByteCount),
                actual: payload.count
            )
        }
        return UltraGridAudioPayload(header: header, pcmPayload: payload)
    }

    public func encoded() throws -> Data {
        var validatedHeader = header
        validatedHeader.payloadByteCount = UInt32(pcmPayload.count)
        var data = try validatedHeader.encoded()
        data.append(pcmPayload)
        return data
    }
}
