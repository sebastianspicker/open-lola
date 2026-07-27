// Encodes and decodes UltraGrid audio headers and PCM payloads with layout validation.
import Foundation

/// Encodes the UltraGrid audio header fields for stream, buffer, sample format, rate, and channels.
public struct UltraGridAudioPayloadHeader: Codable, Equatable, Sendable, UltraGridPayloadHeaderPrefixFields {
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
        let prefix = try UltraGridPayloadHeaderPrefix.decode(bytes, minimumByteCount: byteCount)
        let word3 = readUltraGridUInt32BE(bytes, offset: 12)
        return try validatedUltraGridPayloadHeader(
            UltraGridAudioPayloadHeader(
                substreamID: prefix.substreamID,
                bufferNumber: prefix.bufferNumber,
                payloadOffset: prefix.payloadOffset,
                payloadByteCount: prefix.payloadByteCount,
                quantizationBits: UInt8(word3 & UInt32(maxQuantizationBits)),
                sampleRateHertz: word3 >> 6,
                audioTag: readUltraGridUInt32BE(bytes, offset: 16)
            ),
            validate: { try $0.validate() }
        )
    }

    public func encoded() throws -> Data {
        try validate()
        var data = try encodeUltraGridPayloadHeaderPrefix(self, reservingCapacity: Self.byteCount)
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

/// Pairs an UltraGrid audio header with PCM bytes and validates their declared sample layout.
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
