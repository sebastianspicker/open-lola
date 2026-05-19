import Foundation

public enum UltraGridCompatibilityPayloadType: UInt8, Codable, Equatable, Sendable {
    case video = 20
    case audio = 21
}

public enum UltraGridRTPPayloadClassification: Equatable, Sendable {
    case audioPCM
    case audioEncrypted
    case videoRaw
    case videoFEC
    case videoEncrypted
    case videoJPEG
    case videoH264
}

public enum UltraGridNegotiatedCodec: String, Codable, Equatable, Sendable {
    case pcmAudio = "pcm-audio"
    case rawVideo = "raw-video"
    case jpeg
    case h264
}

public struct UltraGridRTPPayloadRegistry: Codable, Equatable, Sendable {
    public var dynamicPayloads: [UInt8: UltraGridNegotiatedCodec]

    public init(dynamicPayloads: [UInt8: UltraGridNegotiatedCodec] = [:]) throws {
        for payloadType in dynamicPayloads.keys {
            guard (96...127).contains(payloadType) else {
                throw UltraGridCompatibilityError.invalidField("rtp.dynamicPayloadType", Int(payloadType))
            }
        }
        self.dynamicPayloads = dynamicPayloads
    }

    public static let `default` = try! UltraGridRTPPayloadRegistry()

    public func codec(for payloadType: UInt8) -> UltraGridNegotiatedCodec? {
        if payloadType == UltraGridCompatibilityPayloadType.audio.rawValue {
            return .pcmAudio
        }
        if payloadType == UltraGridCompatibilityPayloadType.video.rawValue {
            return .rawVideo
        }
        return dynamicPayloads[payloadType]
    }
}

public enum UltraGridPCMAudioTag {
    public static let littleEndianPCM: UInt32 = 1
    public static let bigEndianPCM: UInt32 = 9_999
}

public enum UltraGridPayloadHeaderPacking {
    public static let bufferNumberBitCount: UInt32 = 22
    public static let substreamIDMask: UInt32 = 0x03ff
    public static let bufferNumberMask: UInt32 = 0x003f_ffff

    public static func packSubstreamAndBuffer(substreamID: UInt16, bufferNumber: UInt32) throws -> UInt32 {
        guard substreamID <= substreamIDMask else {
            throw UltraGridCompatibilityError.invalidField("substreamID", Int(substreamID))
        }
        guard bufferNumber <= bufferNumberMask else {
            throw UltraGridCompatibilityError.invalidField("bufferNumber", Int(bufferNumber))
        }
        return (bufferNumber << 10) | UInt32(substreamID)
    }

    public static func unpackSubstream(_ word: UInt32) -> UInt16 {
        UInt16(word & substreamIDMask)
    }

    public static func unpackBufferNumber(_ word: UInt32) -> UInt32 {
        (word >> 10) & bufferNumberMask
    }
}

func validateUltraGridPositive(_ value: Int, _ field: String) throws {
    guard value > 0 else {
        throw UltraGridCompatibilityError.invalidField(field, value)
    }
}

func uint16(_ value: Int, _ field: String) throws -> UInt16 {
    guard value > 0, value <= Int(UInt16.max) else {
        throw UltraGridCompatibilityError.invalidField(field, value)
    }
    return UInt16(value)
}

func uint32(_ value: Int, _ field: String) throws -> UInt32 {
    guard value > 0, value <= Int(UInt32.max) else {
        throw UltraGridCompatibilityError.invalidField(field, value)
    }
    return UInt32(value)
}

func readUltraGridUInt32BE(_ bytes: [UInt8], offset: Int) -> UInt32 {
    NetworkByteReader.readUInt32BE(bytes, offset: offset)
}

func appendUltraGridUInt32BE(_ value: UInt32, to data: inout Data) {
    data.append(UInt8((value >> 24) & 0xff))
    data.append(UInt8((value >> 16) & 0xff))
    data.append(UInt8((value >> 8) & 0xff))
    data.append(UInt8(value & 0xff))
}
