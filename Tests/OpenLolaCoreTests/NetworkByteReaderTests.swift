// Verifies that network byte reader centralizes readable range checks for unchecked reads.
import Testing

@testable import OpenLolaCore

@Test
func networkByteReaderCentralizesReadableRangeChecksForUncheckedReads() {
    let bytes: [UInt8] = [0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde, 0xf0]

    #expect(NetworkByteReader.hasBytes(bytes, offset: 0, count: 8))
    #expect(NetworkByteReader.hasBytes(bytes, offset: 6, count: 2))
    #expect(!NetworkByteReader.hasBytes(bytes, offset: -1, count: 1))
    #expect(!NetworkByteReader.hasBytes(bytes, offset: 7, count: 2))
    #expect(!NetworkByteReader.hasBytes(bytes, offset: 0, count: -1))

    #expect(NetworkByteReader.readUInt16BE(bytes, offset: 0) == 0x1234)
    #expect(NetworkByteReader.readUInt32BE(bytes, offset: 0) == 0x12345678)
    #expect(NetworkByteReader.readUInt16LE(bytes, offset: 0) == 0x3412)
    #expect(NetworkByteReader.readUInt32LE(bytes, offset: 0) == 0x78563412)
    #expect(NetworkByteReader.readUInt64LE(bytes, offset: 0) == 0xf0debc9a78563412)
}
