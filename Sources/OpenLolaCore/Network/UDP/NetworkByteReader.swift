enum NetworkByteReader {
    static func readUInt16BE(_ bytes: [UInt8], offset: Int) -> UInt16 {
        UInt16(bytes[offset]) << 8 | UInt16(bytes[offset + 1])
    }

    static func readUInt32BE(_ bytes: [UInt8], offset: Int) -> UInt32 {
        UInt32(bytes[offset]) << 24
            | UInt32(bytes[offset + 1]) << 16
            | UInt32(bytes[offset + 2]) << 8
            | UInt32(bytes[offset + 3])
    }

    static func readUInt16LE(_ bytes: [UInt8], offset: Int) -> UInt16 {
        UInt16(bytes[offset])
            | UInt16(bytes[offset + 1]) << 8
    }

    static func readUInt32LE(_ bytes: [UInt8], offset: Int) -> UInt32 {
        UInt32(bytes[offset])
            | UInt32(bytes[offset + 1]) << 8
            | UInt32(bytes[offset + 2]) << 16
            | UInt32(bytes[offset + 3]) << 24
    }

    static func readUInt64LE(_ bytes: [UInt8], offset: Int) -> UInt64 {
        UInt64(readUInt32LE(bytes, offset: offset))
            | UInt64(readUInt32LE(bytes, offset: offset + 4)) << 32
    }
}
