import Foundation

func udpPcmHasBytes(_ bytes: [UInt8], offset: Int, count: Int) -> Bool {
    guard offset >= 0, count >= 0, offset <= bytes.count else {
        return false
    }
    return count <= bytes.count - offset
}

func readCheckedUdpPcmPacketUInt16LE(_ bytes: [UInt8], offset: Int) throws -> UInt16 {
    guard udpPcmHasBytes(bytes, offset: offset, count: 2) else {
        throw UdpPcmPacketError.truncatedPacket(byteCount: bytes.count)
    }
    return NetworkByteReader.readUInt16LE(bytes, offset: offset)
}

func readCheckedUdpPcmPacketUInt32LE(_ bytes: [UInt8], offset: Int) throws -> UInt32 {
    guard udpPcmHasBytes(bytes, offset: offset, count: 4) else {
        throw UdpPcmPacketError.truncatedPacket(byteCount: bytes.count)
    }
    return NetworkByteReader.readUInt32LE(bytes, offset: offset)
}

func readCheckedUdpPcmPacketUInt64LE(_ bytes: [UInt8], offset: Int) throws -> UInt64 {
    guard udpPcmHasBytes(bytes, offset: offset, count: 8) else {
        throw UdpPcmPacketError.truncatedPacket(byteCount: bytes.count)
    }
    return NetworkByteReader.readUInt64LE(bytes, offset: offset)
}

func appendUdpPcmUInt16LE(_ value: UInt16, to data: inout Data) {
    data.append(UInt8(value & 0xFF))
    data.append(UInt8((value >> 8) & 0xFF))
}

func appendUdpPcmUInt32LE(_ value: UInt32, to data: inout Data) {
    data.append(UInt8(value & 0xFF))
    data.append(UInt8((value >> 8) & 0xFF))
    data.append(UInt8((value >> 16) & 0xFF))
    data.append(UInt8((value >> 24) & 0xFF))
}

func appendUdpPcmUInt64LE(_ value: UInt64, to data: inout Data) {
    appendUdpPcmUInt32LE(UInt32(value & 0xFFFF_FFFF), to: &data)
    appendUdpPcmUInt32LE(UInt32((value >> 32) & 0xFFFF_FFFF), to: &data)
}
