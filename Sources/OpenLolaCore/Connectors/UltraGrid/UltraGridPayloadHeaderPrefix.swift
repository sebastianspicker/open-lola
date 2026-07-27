// Defines the fixed UltraGrid payload header prefix used to identify packet framing and payload boundaries.
import Foundation

/// The common 12-byte prefix shared by UltraGrid audio, video, and FEC headers.
struct UltraGridPayloadHeaderPrefix: Sendable {
    let substreamID: UInt16
    let bufferNumber: UInt32
    let payloadOffset: UInt32
    let payloadByteCount: UInt32

    static func decode(_ bytes: [UInt8], minimumByteCount: Int) throws -> Self {
        guard bytes.count >= minimumByteCount else {
            throw UltraGridCompatibilityError.truncatedPayload(byteCount: bytes.count)
        }

        let packedStreamAndBuffer = readUltraGridUInt32BE(bytes, offset: 0)
        return Self(
            substreamID: UltraGridPayloadHeaderPacking.unpackSubstream(packedStreamAndBuffer),
            bufferNumber: UltraGridPayloadHeaderPacking.unpackBufferNumber(packedStreamAndBuffer),
            payloadOffset: readUltraGridUInt32BE(bytes, offset: 4),
            payloadByteCount: readUltraGridUInt32BE(bytes, offset: 8)
        )
    }

    func encoded(reservingCapacity capacity: Int) throws -> Data {
        var data = Data()
        data.reserveCapacity(capacity)
        appendUltraGridUInt32BE(
            try UltraGridPayloadHeaderPacking.packSubstreamAndBuffer(
                substreamID: substreamID,
                bufferNumber: bufferNumber
            ),
            to: &data
        )
        appendUltraGridUInt32BE(payloadOffset, to: &data)
        appendUltraGridUInt32BE(payloadByteCount, to: &data)
        return data
    }
}

protocol UltraGridPayloadHeaderPrefixFields {
    var substreamID: UInt16 { get }
    var bufferNumber: UInt32 { get }
    var payloadOffset: UInt32 { get }
    var payloadByteCount: UInt32 { get }
}

func encodeUltraGridPayloadHeaderPrefix<Header: UltraGridPayloadHeaderPrefixFields>(
    _ header: Header,
    reservingCapacity: Int
) throws -> Data {
    try UltraGridPayloadHeaderPrefix(
        substreamID: header.substreamID,
        bufferNumber: header.bufferNumber,
        payloadOffset: header.payloadOffset,
        payloadByteCount: header.payloadByteCount
    ).encoded(reservingCapacity: reservingCapacity)
}

func validatedUltraGridPayloadHeader<Header>(
    _ header: Header,
    validate: (Header) throws -> Void
) throws -> Header {
    try validate(header)
    return header
}
