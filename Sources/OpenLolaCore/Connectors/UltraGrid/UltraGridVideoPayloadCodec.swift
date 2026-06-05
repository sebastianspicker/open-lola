import Foundation

public struct UltraGridFourCC: Codable, Equatable, Sendable {
    public var rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public init(_ text: String) throws {
        let bytes = Array(text.utf8)
        guard bytes.count == 4 else {
            throw UltraGridCompatibilityError.unsupportedMode("fourcc-\(text)")
        }
        rawValue = UInt32(bytes[0]) << 24
            | UInt32(bytes[1]) << 16
            | UInt32(bytes[2]) << 8
            | UInt32(bytes[3])
    }
}

public struct UltraGridVideoPayloadHeader: Codable, Equatable, Sendable {
    public static let byteCount = 24

    public var substreamID: UInt16
    public var bufferNumber: UInt32
    public var payloadOffset: UInt32
    public var payloadByteCount: UInt32
    public var width: UInt16
    public var height: UInt16
    public var fourCC: UltraGridFourCC
    public var interlace: UInt8
    public var frameRateNumerator: UInt16
    public var frameRateDenominator: UInt8
    public var fd: Bool
    public var fi: Bool

    public init(
        substreamID: UInt16 = 0,
        bufferNumber: UInt32,
        payloadOffset: UInt32,
        payloadByteCount: UInt32,
        geometry: UltraGridVideoPayloadGeometry,
        timing: UltraGridVideoPayloadTiming
    ) {
        self.substreamID = substreamID
        self.bufferNumber = bufferNumber
        self.payloadOffset = payloadOffset
        self.payloadByteCount = payloadByteCount
        self.width = geometry.width
        self.height = geometry.height
        self.fourCC = geometry.fourCC
        self.interlace = timing.interlace
        self.frameRateNumerator = timing.frameRateNumerator
        self.frameRateDenominator = timing.frameRateDenominator
        self.fd = timing.fd
        self.fi = timing.fi
    }

    public static func decode(_ bytes: [UInt8]) throws -> UltraGridVideoPayloadHeader {
        guard bytes.count >= byteCount else {
            throw UltraGridCompatibilityError.truncatedPayload(byteCount: bytes.count)
        }
        let word0 = readUltraGridUInt32BE(bytes, offset: 0)
        let resolution = readUltraGridUInt32BE(bytes, offset: 12)
        let timing = readUltraGridUInt32BE(bytes, offset: 20)
        let header = UltraGridVideoPayloadHeader(
            substreamID: UltraGridPayloadHeaderPacking.unpackSubstream(word0),
            bufferNumber: UltraGridPayloadHeaderPacking.unpackBufferNumber(word0),
            payloadOffset: readUltraGridUInt32BE(bytes, offset: 4),
            payloadByteCount: readUltraGridUInt32BE(bytes, offset: 8),
            geometry: UltraGridVideoPayloadGeometry(
                width: UInt16(resolution & 0xffff),
                height: UInt16((resolution >> 16) & 0xffff),
                fourCC: UltraGridFourCC(rawValue: readUltraGridUInt32BE(bytes, offset: 16))
            ),
            timing: UltraGridVideoPayloadTiming(
                interlace: UInt8(timing & 0x7),
                frameRateNumerator: UInt16((timing >> 3) & 0x03ff),
                frameRateDenominator: UInt8((timing >> 13) & 0x0f),
                fd: (timing & (1 << 17)) != 0,
                fi: (timing & (1 << 18)) != 0
            )
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
        appendUltraGridUInt32BE((UInt32(height) << 16) | UInt32(width), to: &data)
        appendUltraGridUInt32BE(fourCC.rawValue, to: &data)
        let timing = UInt32(interlace & 0x7)
            | (UInt32(frameRateNumerator & 0x03ff) << 3)
            | (UInt32(frameRateDenominator & 0x0f) << 13)
            | (fd ? (1 << 17) : 0)
            | (fi ? (1 << 18) : 0)
        appendUltraGridUInt32BE(timing, to: &data)
        return data
    }

    public func validate() throws {
        _ = try UltraGridPayloadHeaderPacking.packSubstreamAndBuffer(
            substreamID: substreamID,
            bufferNumber: bufferNumber
        )
        try validateUltraGridPositive(Int(payloadByteCount), "video.payloadByteCount")
        try validateUltraGridPositive(Int(width), "video.width")
        try validateUltraGridPositive(Int(height), "video.height")
        try validateUltraGridPositive(Int(frameRateNumerator), "video.frameRateNumerator")
        guard interlace <= 0x7 else {
            throw UltraGridCompatibilityError.invalidField("video.interlace", Int(interlace))
        }
    }
}

public struct UltraGridVideoPayloadGeometry: Codable, Equatable, Sendable {
    public var width: UInt16
    public var height: UInt16
    public var fourCC: UltraGridFourCC

    public init(width: UInt16, height: UInt16, fourCC: UltraGridFourCC) {
        self.width = width
        self.height = height
        self.fourCC = fourCC
    }
}

public struct UltraGridVideoPayloadTiming: Codable, Equatable, Sendable {
    public var interlace: UInt8
    public var frameRateNumerator: UInt16
    public var frameRateDenominator: UInt8
    public var fd: Bool
    public var fi: Bool

    public init(
        interlace: UInt8 = 0,
        frameRateNumerator: UInt16,
        frameRateDenominator: UInt8 = 0,
        fd: Bool = false,
        fi: Bool = false
    ) {
        self.interlace = interlace
        self.frameRateNumerator = frameRateNumerator
        self.frameRateDenominator = frameRateDenominator
        self.fd = fd
        self.fi = fi
    }
}

public struct UltraGridVideoRawFragmentPayload: PacketCodec {
    public static let headerByteCount = UltraGridVideoPayloadHeader.byteCount

    public var header: UltraGridVideoPayloadHeader
    public var fragmentPayload: Data

    public var width: UInt16 { header.width }
    public var height: UInt16 { header.height }
    public var frameRate: UInt16 { header.frameRateNumerator }
    public var frameID: UInt32 { header.bufferNumber }
    public var payloadOffset: UInt32 { header.payloadOffset }
    public var framePayloadByteCount: UInt32 { header.payloadByteCount }

    public init(header: UltraGridVideoPayloadHeader, fragmentPayload: Data) {
        self.header = header
        self.fragmentPayload = fragmentPayload
    }

    public static func decode<Bytes: DataProtocol>(_ data: Bytes) throws -> UltraGridVideoRawFragmentPayload {
        let bytes = [UInt8](data)
        let header = try UltraGridVideoPayloadHeader.decode(bytes)
        let payload = Data(bytes[headerByteCount..<bytes.count])
        let endOffset = Int(header.payloadOffset) + payload.count
        guard endOffset <= Int(header.payloadByteCount) else {
            throw UltraGridCompatibilityError.invalidPayloadLength(
                expected: Int(header.payloadByteCount),
                actual: endOffset
            )
        }
        return UltraGridVideoRawFragmentPayload(header: header, fragmentPayload: payload)
    }

    public func encoded() throws -> Data {
        try header.validate()
        let endOffset = Int(header.payloadOffset) + fragmentPayload.count
        guard endOffset <= Int(header.payloadByteCount) else {
            throw UltraGridCompatibilityError.invalidPayloadLength(
                expected: Int(header.payloadByteCount),
                actual: endOffset
            )
        }
        var data = try header.encoded()
        data.append(fragmentPayload)
        return data
    }
}

public struct UltraGridRTPJPEGHeader: Codable, Equatable, Sendable {
    public static let byteCount = 8
    public static let maxFragmentOffset = 0x00ff_ffff

    public var typeSpecific: UInt8
    public var fragmentOffset: UInt32
    public var type: UInt8
    public var quantization: UInt8
    public var widthBlocks: UInt8
    public var heightBlocks: UInt8

    public init(
        typeSpecific: UInt8 = 0,
        fragmentOffset: UInt32,
        type: UInt8,
        quantization: UInt8,
        widthBlocks: UInt8,
        heightBlocks: UInt8
    ) {
        self.typeSpecific = typeSpecific
        self.fragmentOffset = fragmentOffset
        self.type = type
        self.quantization = quantization
        self.widthBlocks = widthBlocks
        self.heightBlocks = heightBlocks
    }

    public static func decode(_ bytes: [UInt8]) throws -> UltraGridRTPJPEGHeader {
        guard bytes.count >= byteCount else {
            throw UltraGridCompatibilityError.truncatedPayload(byteCount: bytes.count)
        }
        let fragmentOffset = (UInt32(bytes[1]) << 16) | (UInt32(bytes[2]) << 8) | UInt32(bytes[3])
        let header = UltraGridRTPJPEGHeader(
            typeSpecific: bytes[0],
            fragmentOffset: fragmentOffset,
            type: bytes[4],
            quantization: bytes[5],
            widthBlocks: bytes[6],
            heightBlocks: bytes[7]
        )
        try header.validate()
        return header
    }

    public func encoded() throws -> Data {
        try validate()
        var data = Data()
        data.reserveCapacity(Self.byteCount)
        data.append(typeSpecific)
        data.append(UInt8((fragmentOffset >> 16) & 0xff))
        data.append(UInt8((fragmentOffset >> 8) & 0xff))
        data.append(UInt8(fragmentOffset & 0xff))
        data.append(type)
        data.append(quantization)
        data.append(widthBlocks)
        data.append(heightBlocks)
        return data
    }

    public func validate() throws {
        guard fragmentOffset <= Self.maxFragmentOffset else {
            throw UltraGridCompatibilityError.invalidField("jpeg.fragmentOffset", Int(fragmentOffset))
        }
        try validateUltraGridPositive(Int(widthBlocks), "jpeg.widthBlocks")
        try validateUltraGridPositive(Int(heightBlocks), "jpeg.heightBlocks")
    }
}

public struct UltraGridRTPJPEGPayload: PacketCodec {
    public static let headerByteCount = UltraGridRTPJPEGHeader.byteCount

    public var header: UltraGridRTPJPEGHeader
    public var scanPayload: Data

    public init(header: UltraGridRTPJPEGHeader, scanPayload: Data) {
        self.header = header
        self.scanPayload = scanPayload
    }

    public static func decode<Bytes: DataProtocol>(_ data: Bytes) throws -> UltraGridRTPJPEGPayload {
        let bytes = [UInt8](data)
        let header = try UltraGridRTPJPEGHeader.decode(bytes)
        let payload = Data(bytes[headerByteCount..<bytes.count])
        try validateScanPayload(payload, fragmentOffset: header.fragmentOffset)
        return UltraGridRTPJPEGPayload(header: header, scanPayload: payload)
    }

    public func encoded() throws -> Data {
        try header.validate()
        try Self.validateScanPayload(scanPayload, fragmentOffset: header.fragmentOffset)
        var data = try header.encoded()
        data.append(scanPayload)
        return data
    }

    private static func validateScanPayload(_ payload: Data, fragmentOffset: UInt32) throws {
        guard !payload.isEmpty else {
            throw UltraGridCompatibilityError.invalidField("jpeg.scanPayload", 0)
        }
        let endOffset = Int(fragmentOffset) + payload.count
        guard endOffset <= UltraGridRTPJPEGHeader.maxFragmentOffset + 1 else {
            throw UltraGridCompatibilityError.invalidPayloadLength(
                expected: UltraGridRTPJPEGHeader.maxFragmentOffset + 1,
                actual: endOffset
            )
        }
    }
}

public struct UltraGridRTPH264Payload: PacketCodec {
    public var payload: Data

    public init(payload: Data) throws {
        try Self.validate(payload)
        self.payload = payload
    }

    public static func decode<Bytes: DataProtocol>(_ data: Bytes) throws -> UltraGridRTPH264Payload {
        try UltraGridRTPH264Payload(payload: Data(data))
    }

    public func encoded() throws -> Data {
        try Self.validate(payload)
        return payload
    }

    private static func validate(_ payload: Data) throws {
        guard let first = payload.first else {
            throw UltraGridCompatibilityError.truncatedPayload(byteCount: 0)
        }
        let forbiddenBitSet = (first & 0x80) != 0
        guard !forbiddenBitSet else {
            throw UltraGridCompatibilityError.invalidField("h264.forbiddenZeroBit", 1)
        }
        let nalType = first & 0x1f
        switch nalType {
        case 1...23:
            return
        case 24:
            try validateSTAPA(payload)
        case 28:
            try validateFUA(payload)
        case 0:
            throw UltraGridCompatibilityError.invalidField("h264.nalUnitType", 0)
        default:
            throw UltraGridCompatibilityError.unsupportedMode("h264-nal-unit-type-\(nalType)")
        }
    }

    private static func validateSTAPA(_ payload: Data) throws {
        var offset = 1
        var nalUnitCount = 0
        while offset < payload.count {
            guard offset + 2 <= payload.count else {
                throw UltraGridCompatibilityError.truncatedPayload(byteCount: payload.count - offset)
            }
            let length = (Int(payload[offset]) << 8) | Int(payload[offset + 1])
            offset += 2
            guard length > 0 else {
                throw UltraGridCompatibilityError.invalidField("h264.stapA.nalUnitLength", 0)
            }
            guard offset + length <= payload.count else {
                throw UltraGridCompatibilityError.invalidPayloadLength(
                    expected: offset + length,
                    actual: payload.count
                )
            }
            try validateSingleNAL(payload[offset])
            offset += length
            nalUnitCount += 1
        }
        guard nalUnitCount > 0 else {
            throw UltraGridCompatibilityError.invalidField("h264.stapA.nalUnitCount", 0)
        }
    }

    private static func validateFUA(_ payload: Data) throws {
        guard payload.count >= 3 else {
            throw UltraGridCompatibilityError.truncatedPayload(byteCount: payload.count)
        }
        let fuHeader = payload[1]
        let start = (fuHeader & 0x80) != 0
        let end = (fuHeader & 0x40) != 0
        guard !(start && end) else {
            throw UltraGridCompatibilityError.invalidField("h264.fuA.startAndEnd", 1)
        }
        try validateSingleNAL(fuHeader & 0x1f)
    }

    private static func validateSingleNAL(_ headerOrType: UInt8) throws {
        let nalType = headerOrType & 0x1f
        guard (1...23).contains(nalType) else {
            throw UltraGridCompatibilityError.invalidField("h264.nalUnitType", Int(nalType))
        }
    }
}
