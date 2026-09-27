import OpenLolaEvidenceModels
import OpenLolaSessionDomain
import OpenLolaContracts
// Performs bounds-checked big- and little-endian integer reads so packet decoders share one byte-order implementation.
import Foundation

package enum NetworkByteReader {
    package static func hasBytes(_ bytes: Data, offset: Int, count: Int) -> Bool {
        guard offset >= 0, count >= 0, offset <= bytes.count else {
            return false
        }
        return count <= bytes.count - offset
    }

    package static func hasBytes(_ bytes: [UInt8], offset: Int, count: Int) -> Bool {
        guard offset >= 0, count >= 0, offset <= bytes.count else {
            return false
        }
        return count <= bytes.count - offset
    }

    package static func readUInt16BE(_ bytes: [UInt8], offset: Int) -> UInt16 {
        precondition(hasBytes(bytes, offset: offset, count: 2), "readUInt16BE requires 2 readable bytes")
        return UInt16(bytes[offset]) << 8 | UInt16(bytes[offset + 1])
    }

    package static func readUInt32BE(_ bytes: [UInt8], offset: Int) -> UInt32 {
        precondition(hasBytes(bytes, offset: offset, count: 4), "readUInt32BE requires 4 readable bytes")
        return UInt32(bytes[offset]) << 24
            | UInt32(bytes[offset + 1]) << 16
            | UInt32(bytes[offset + 2]) << 8
            | UInt32(bytes[offset + 3])
    }

    package static func readUInt16LE(_ bytes: [UInt8], offset: Int) -> UInt16 {
        precondition(hasBytes(bytes, offset: offset, count: 2), "readUInt16LE requires 2 readable bytes")
        return UInt16(bytes[offset])
            | UInt16(bytes[offset + 1]) << 8
    }

    package static func readUInt32LE(_ bytes: [UInt8], offset: Int) -> UInt32 {
        precondition(hasBytes(bytes, offset: offset, count: 4), "readUInt32LE requires 4 readable bytes")
        return UInt32(bytes[offset])
            | UInt32(bytes[offset + 1]) << 8
            | UInt32(bytes[offset + 2]) << 16
            | UInt32(bytes[offset + 3]) << 24
    }

    package static func readUInt64LE(_ bytes: [UInt8], offset: Int) -> UInt64 {
        precondition(hasBytes(bytes, offset: offset, count: 8), "readUInt64LE requires 8 readable bytes")
        return UInt64(readUInt32LE(bytes, offset: offset))
            | UInt64(readUInt32LE(bytes, offset: offset + 4)) << 32
    }

    package static func readUInt16LE(_ bytes: Data, offset: Int) -> UInt16 {
        precondition(hasBytes(bytes, offset: offset, count: 2), "readUInt16LE requires 2 readable bytes")
        let start = bytes.startIndex + offset
        return UInt16(bytes[start]) | UInt16(bytes[start + 1]) << 8
    }

    package static func readUInt32LE(_ bytes: Data, offset: Int) -> UInt32 {
        precondition(hasBytes(bytes, offset: offset, count: 4), "readUInt32LE requires 4 readable bytes")
        let start = bytes.startIndex + offset
        return UInt32(bytes[start])
            | UInt32(bytes[start + 1]) << 8
            | UInt32(bytes[start + 2]) << 16
            | UInt32(bytes[start + 3]) << 24
    }

    package static func readUInt64LE(_ bytes: Data, offset: Int) -> UInt64 {
        precondition(hasBytes(bytes, offset: offset, count: 8), "readUInt64LE requires 8 readable bytes")
        return UInt64(readUInt32LE(bytes, offset: offset))
            | UInt64(readUInt32LE(bytes, offset: offset + 4)) << 32
    }
}

package enum NetworkByteWriter {
    package static func appendUInt32BE(_ value: UInt32, to data: inout Data) {
        data.append(UInt8((value >> 24) & 0xff))
        data.append(UInt8((value >> 16) & 0xff))
        data.append(UInt8((value >> 8) & 0xff))
        data.append(UInt8(value & 0xff))
    }
}
