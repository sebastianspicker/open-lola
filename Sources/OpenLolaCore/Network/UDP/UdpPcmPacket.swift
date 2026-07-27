// Defines UDP media packet, frame, or monitor values and conversion helpers so producers and consumers agree on their exchanged representation.
import Darwin
import Foundation

/// Selects the PCM scalar representation encoded in a UDP packet.
public enum UdpPcmSampleFormat: UInt8, Codable, Equatable, Sendable {
    case int16LittleEndian = 1
    case float32LittleEndian = 2

    public var bytesPerSample: Int {
        switch self {
        case .int16LittleEndian:
            2
        case .float32LittleEndian:
            4
        }
    }
}

/// Defines the UdpPcmPacketHeader wire representation shared by codecs and UDP media transport.
public struct UdpPcmPacketHeader: Codable, Equatable, Sendable {
    public static let magic = [UInt8]("OLPC".utf8)
    public static let currentVersion: UInt8 = 1
    public static let byteCount = 48
    public static let headerGuard: UInt32 = 0x3143_504C

    public var version: UInt8
    public var sequenceNumber: UInt64
    public var senderFrameIndex: UInt64
    public var senderHostTimeNanoseconds: UInt64
    public var sampleRateHertz: UInt32
    public var framesPerPacket: UInt32
    public var channelCount: UInt16
    public var sampleFormat: UdpPcmSampleFormat
    public var payloadByteCount: UInt32

    public struct Transport: Equatable, Sendable {
        public var version: UInt8
        public var sequenceNumber: UInt64
        public var senderFrameIndex: UInt64
        public var senderHostTimeNanoseconds: UInt64

        public init(
            version: UInt8 = UdpPcmPacketHeader.currentVersion,
            sequenceNumber: UInt64,
            senderFrameIndex: UInt64,
            senderHostTimeNanoseconds: UInt64
        ) {
            self.version = version
            self.sequenceNumber = sequenceNumber
            self.senderFrameIndex = senderFrameIndex
            self.senderHostTimeNanoseconds = senderHostTimeNanoseconds
        }
    }

    public struct Format: Equatable, Sendable {
        public var sampleRateHertz: UInt32
        public var framesPerPacket: UInt32
        public var channelCount: UInt16
        public var sampleFormat: UdpPcmSampleFormat

        public init(
            sampleRateHertz: UInt32,
            framesPerPacket: UInt32,
            channelCount: UInt16,
            sampleFormat: UdpPcmSampleFormat
        ) {
            self.sampleRateHertz = sampleRateHertz
            self.framesPerPacket = framesPerPacket
            self.channelCount = channelCount
            self.sampleFormat = sampleFormat
        }
    }

    public init(transport: Transport, format: Format, payloadByteCount: UInt32 = 0) {
        version = transport.version
        sequenceNumber = transport.sequenceNumber
        senderFrameIndex = transport.senderFrameIndex
        senderHostTimeNanoseconds = transport.senderHostTimeNanoseconds
        sampleRateHertz = format.sampleRateHertz
        framesPerPacket = format.framesPerPacket
        channelCount = format.channelCount
        sampleFormat = format.sampleFormat
        self.payloadByteCount = payloadByteCount
    }
}

/// Enumerates failures that callers must handle when working with UDP media transport.
public enum UdpPcmPacketError: Error, Equatable, Sendable {
    case truncatedPacket(byteCount: Int)
    case oversizedPacket(expected: Int, actual: Int)
    case invalidMagic
    case unsupportedVersion(UInt8)
    case unsupportedSampleFormat(UInt8)
    case invalidChannelCount(UInt16)
    case invalidFrameCount(UInt32)
    case invalidSampleRate(UInt32)
    case invalidTimestamp(UInt64)
    case payloadLengthMismatch(expected: Int, actual: Int)
    case payloadTooLarge(Int)
    case invalidHeaderGuard
}

/// Defines the UdpPcmPacket wire representation shared by codecs and UDP media transport.
public struct UdpPcmPacket: PacketCodec {
    public static let maxPayloadByteCount = 1_048_576

    public var header: UdpPcmPacketHeader
    public var payload: Data

    public init(header: UdpPcmPacketHeader, payload: Data) {
        var header = header
        header.payloadByteCount = UInt32(payload.count)
        self.header = header
        self.payload = payload
    }

    public static func silence(
        sequenceNumber: UInt64,
        senderFrameIndex: UInt64,
        senderHostTimeNanoseconds: UInt64,
        mode: UdpPcmPacketMode
    ) -> UdpPcmPacket {
        UdpPcmPacket(
            header: UdpPcmPacketHeader(
                transport: .init(
                    sequenceNumber: sequenceNumber,
                    senderFrameIndex: senderFrameIndex,
                    senderHostTimeNanoseconds: senderHostTimeNanoseconds
                ),
                format: .init(
                    sampleRateHertz: UInt32(mode.sampleRateHertz),
                    framesPerPacket: UInt32(mode.framesPerPacket),
                    channelCount: UInt16(mode.channelCount),
                    sampleFormat: mode.sampleFormat
                )
            ),
            payload: Data(repeating: 0, count: mode.payloadByteCount)
        )
    }

    public func matches(_ mode: UdpPcmPacketMode) -> Bool {
        header.sampleRateHertz == UInt32(mode.sampleRateHertz)
            && header.framesPerPacket == UInt32(mode.framesPerPacket)
            && header.channelCount == UInt16(mode.channelCount)
            && header.sampleFormat == mode.sampleFormat
            && payload.count == mode.payloadByteCount
    }

    public static func decode<Bytes: DataProtocol>(_ data: Bytes) throws -> UdpPcmPacket {
        let bytes = [UInt8](data)
        let header = try decodeHeader(from: bytes)
        let payload = try decodePayload(from: bytes, header: header)
        return UdpPcmPacket(header: header, payload: payload)
    }

    private static func decodeHeader(from bytes: [UInt8]) throws -> UdpPcmPacketHeader {
        try validateHeaderPrefix(bytes)
        let fields = try readHeaderFields(from: bytes)
        try validateHeaderFields(fields)

        return UdpPcmPacketHeader(
            transport: .init(
                version: fields.version,
                sequenceNumber: fields.sequenceNumber,
                senderFrameIndex: fields.senderFrameIndex,
                senderHostTimeNanoseconds: fields.senderHostTimeNanoseconds
            ),
            format: .init(
                sampleRateHertz: fields.sampleRateHertz,
                framesPerPacket: fields.framesPerPacket,
                channelCount: fields.channelCount,
                sampleFormat: fields.sampleFormat
            ),
            payloadByteCount: fields.payloadByteCount
        )
    }

    private static func validateHeaderPrefix(_ bytes: [UInt8]) throws {
        guard bytes.count >= UdpPcmPacketHeader.byteCount else {
            throw UdpPcmPacketError.truncatedPacket(byteCount: bytes.count)
        }
        guard Array(bytes[0..<4]) == UdpPcmPacketHeader.magic else {
            throw UdpPcmPacketError.invalidMagic
        }
    }

    private static func readHeaderFields(from bytes: [UInt8]) throws -> UdpPcmDecodedHeaderFields {
        let version = bytes[4]
        let formatValue = bytes[5]
        guard let sampleFormat = UdpPcmSampleFormat(rawValue: formatValue) else {
            throw UdpPcmPacketError.unsupportedSampleFormat(formatValue)
        }

        let channelCount = try readCheckedUdpPcmPacketUInt16LE(bytes, offset: 6)
        let framesPerPacket = try readCheckedUdpPcmPacketUInt32LE(bytes, offset: 8)
        let sampleRateHertz = try readCheckedUdpPcmPacketUInt32LE(bytes, offset: 12)
        let sequenceNumber = try readCheckedUdpPcmPacketUInt64LE(bytes, offset: 16)
        let senderFrameIndex = try readCheckedUdpPcmPacketUInt64LE(bytes, offset: 24)
        let senderHostTimeNanoseconds = try readCheckedUdpPcmPacketUInt64LE(bytes, offset: 32)
        let payloadByteCount = try readCheckedUdpPcmPacketUInt32LE(bytes, offset: 40)
        let headerGuard = try readCheckedUdpPcmPacketUInt32LE(bytes, offset: 44)

        return UdpPcmDecodedHeaderFields(
            version: version,
            sampleFormat: sampleFormat,
            channelCount: channelCount,
            framesPerPacket: framesPerPacket,
            sampleRateHertz: sampleRateHertz,
            sequenceNumber: sequenceNumber,
            senderFrameIndex: senderFrameIndex,
            senderHostTimeNanoseconds: senderHostTimeNanoseconds,
            payloadByteCount: payloadByteCount,
            headerGuard: headerGuard
        )
    }

    private static func validateHeaderFields(_ fields: UdpPcmDecodedHeaderFields) throws {
        guard fields.version == UdpPcmPacketHeader.currentVersion else {
            throw UdpPcmPacketError.unsupportedVersion(fields.version)
        }
        guard fields.channelCount > 0 else {
            throw UdpPcmPacketError.invalidChannelCount(fields.channelCount)
        }
        guard fields.framesPerPacket > 0 else {
            throw UdpPcmPacketError.invalidFrameCount(fields.framesPerPacket)
        }
        guard fields.sampleRateHertz > 0 else {
            throw UdpPcmPacketError.invalidSampleRate(fields.sampleRateHertz)
        }
        guard fields.senderHostTimeNanoseconds > 0 else {
            throw UdpPcmPacketError.invalidTimestamp(fields.senderHostTimeNanoseconds)
        }
        guard fields.headerGuard == UdpPcmPacketHeader.headerGuard else {
            throw UdpPcmPacketError.invalidHeaderGuard
        }
    }

    private static func decodePayload(from bytes: [UInt8], header: UdpPcmPacketHeader) throws -> Data {
        try validatePayloadByteCounts(bytes, header: header)
        return Data(bytes.dropFirst(UdpPcmPacketHeader.byteCount))
    }

    private static func validatePayloadByteCounts(
        _ bytes: [UInt8],
        header: UdpPcmPacketHeader
    ) throws {
        let declaredPayloadByteCount = Int(header.payloadByteCount)
        let actualPayloadByteCount = bytes.count - UdpPcmPacketHeader.byteCount
        let declaredPacketByteCount = UdpPcmPacketHeader.byteCount + declaredPayloadByteCount
        if actualPayloadByteCount > declaredPayloadByteCount {
            throw UdpPcmPacketError.oversizedPacket(
                expected: declaredPacketByteCount,
                actual: bytes.count
            )
        }
        if actualPayloadByteCount != declaredPayloadByteCount {
            throw UdpPcmPacketError.payloadLengthMismatch(
                expected: declaredPayloadByteCount,
                actual: actualPayloadByteCount
            )
        }
        guard declaredPayloadByteCount <= maxPayloadByteCount else {
            throw UdpPcmPacketError.payloadTooLarge(declaredPayloadByteCount)
        }

        let expectedPayloadByteCount = Int(header.framesPerPacket)
            * Int(header.channelCount)
            * header.sampleFormat.bytesPerSample
        guard expectedPayloadByteCount == declaredPayloadByteCount else {
            throw UdpPcmPacketError.payloadLengthMismatch(
                expected: expectedPayloadByteCount,
                actual: declaredPayloadByteCount
            )
        }
    }

    public func encoded() throws -> Data {
        try validatePayload()

        var data = Data()
        data.reserveCapacity(UdpPcmPacketHeader.byteCount + payload.count)
        data.append(contentsOf: UdpPcmPacketHeader.magic)
        data.append(header.version)
        data.append(header.sampleFormat.rawValue)
        appendUdpPcmUInt16LE(header.channelCount, to: &data)
        appendUdpPcmUInt32LE(header.framesPerPacket, to: &data)
        appendUdpPcmUInt32LE(header.sampleRateHertz, to: &data)
        appendUdpPcmUInt64LE(header.sequenceNumber, to: &data)
        appendUdpPcmUInt64LE(header.senderFrameIndex, to: &data)
        appendUdpPcmUInt64LE(header.senderHostTimeNanoseconds, to: &data)
        appendUdpPcmUInt32LE(UInt32(payload.count), to: &data)
        appendUdpPcmUInt32LE(UdpPcmPacketHeader.headerGuard, to: &data)
        data.append(payload)
        return data
    }

    private func validatePayload() throws {
        guard header.version == UdpPcmPacketHeader.currentVersion else {
            throw UdpPcmPacketError.unsupportedVersion(header.version)
        }
        guard header.channelCount > 0 else {
            throw UdpPcmPacketError.invalidChannelCount(header.channelCount)
        }
        guard header.framesPerPacket > 0 else {
            throw UdpPcmPacketError.invalidFrameCount(header.framesPerPacket)
        }
        guard header.sampleRateHertz > 0 else {
            throw UdpPcmPacketError.invalidSampleRate(header.sampleRateHertz)
        }
        guard header.senderHostTimeNanoseconds > 0 else {
            throw UdpPcmPacketError.invalidTimestamp(header.senderHostTimeNanoseconds)
        }
        guard payload.count <= Self.maxPayloadByteCount else {
            throw UdpPcmPacketError.payloadTooLarge(payload.count)
        }

        let expectedPayloadByteCount = Int(header.framesPerPacket)
            * Int(header.channelCount)
            * header.sampleFormat.bytesPerSample
        if payload.count != expectedPayloadByteCount {
            throw UdpPcmPacketError.payloadLengthMismatch(
                expected: expectedPayloadByteCount,
                actual: payload.count
            )
        }
    }
}

private struct UdpPcmDecodedHeaderFields {
    var version: UInt8
    var sampleFormat: UdpPcmSampleFormat
    var channelCount: UInt16
    var framesPerPacket: UInt32
    var sampleRateHertz: UInt32
    var sequenceNumber: UInt64
    var senderFrameIndex: UInt64
    var senderHostTimeNanoseconds: UInt64
    var payloadByteCount: UInt32
    var headerGuard: UInt32
}

/// Enumerates failures that callers must handle when working with UDP media transport.
public enum UdpPcmSequenceError: Error, Equatable, Sendable {
    case unexpectedSequence(expected: UInt64, actual: UInt64)
    case unexpectedFrameIndex(expected: UInt64, actual: UInt64)
}

/// Requires strictly consecutive sequence numbers and sender frame indexes.
/// This tracker is valid only on lossless paths such as loopback or CI; real
/// network use needs a gap-tolerant wrapper that can classify packet loss.
public struct UdpPcmSequenceTracker: Sendable {
    private var nextSequenceNumber: UInt64?
    private var nextFrameIndex: UInt64?

    public init() {}

    public mutating func accept(_ packet: UdpPcmPacket) throws {
        if let nextSequenceNumber, packet.header.sequenceNumber != nextSequenceNumber {
            throw UdpPcmSequenceError.unexpectedSequence(
                expected: nextSequenceNumber,
                actual: packet.header.sequenceNumber
            )
        }
        if let nextFrameIndex, packet.header.senderFrameIndex != nextFrameIndex {
            throw UdpPcmSequenceError.unexpectedFrameIndex(
                expected: nextFrameIndex,
                actual: packet.header.senderFrameIndex
            )
        }

        nextSequenceNumber = packet.header.sequenceNumber &+ 1
        nextFrameIndex = packet.header.senderFrameIndex &+ UInt64(packet.header.framesPerPacket)
    }
}

/// Enumerates failures that callers must handle when working with UDP media transport.
public enum UdpPcmHexFixtureError: Error, Equatable, Sendable {
    case nonASCII
    case oddDigitCount
    case invalidByte(String)
}

/// Provides deterministic UdpPcmHexFixture coverage without requiring external UDP media transport infrastructure.
public enum UdpPcmHexFixture {
    public static func decode(_ data: Data) throws -> Data {
        guard let text = String(data: data, encoding: .ascii) else {
            throw UdpPcmHexFixtureError.nonASCII
        }

        let compact = text.filter { !$0.isWhitespace }
        guard compact.count.isMultiple(of: 2) else {
            throw UdpPcmHexFixtureError.oddDigitCount
        }

        var bytes = Data()
        var index = compact.startIndex
        while index < compact.endIndex {
            let nextIndex = compact.index(index, offsetBy: 2)
            let byteText = String(compact[index..<nextIndex])
            guard let byte = UInt8(byteText, radix: 16) else {
                throw UdpPcmHexFixtureError.invalidByte(byteText)
            }
            bytes.append(byte)
            index = nextIndex
        }
        return bytes
    }
}
