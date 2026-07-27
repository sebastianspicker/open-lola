// Defines UDP media packet, frame, or monitor values and conversion helpers so producers and consumers agree on their exchanged representation.
import Foundation

/// Enumerates failures that callers must handle when working with UDP media transport.
public enum AudioOpusCeltLowDelayPacketError: Error, Equatable, Sendable {
    case truncatedPacket(byteCount: Int)
    case invalidMagic
    case unsupportedVersion(UInt8)
    case invalidStreamID(UInt32)
    case invalidTimestamp(UInt64)
    case invalidSampleRate(UInt32)
    case invalidFrameCount(UInt32)
    case invalidChannelCount(UInt16)
    case payloadLengthMismatch(expected: Int, actual: Int)
    case payloadTooLarge(Int)
    case invalidHeaderGuard
}

/// Defines the AudioOpusCeltLowDelayPacketHeader wire representation shared by codecs and UDP media transport.
public struct AudioOpusCeltLowDelayPacketHeader: Codable, Equatable, Sendable {
    public static let magic = [UInt8]("OLOD".utf8)
    public static let currentVersion: UInt8 = 1
    public static let byteCount = 56
    public static let headerGuard: UInt32 = 0x444F_4C4F

    public var version: UInt8
    public var streamID: UInt32
    public var sequenceNumber: UInt64
    public var senderFrameIndex: UInt64
    public var senderHostTimeNanoseconds: UInt64
    public var sampleRateHertz: UInt32
    public var frameCount: UInt32
    public var channelCount: UInt16
    public var codecByteCount: UInt32

    public struct Stream: Equatable, Sendable {
        public var version: UInt8
        public var streamID: UInt32

        public init(version: UInt8 = AudioOpusCeltLowDelayPacketHeader.currentVersion, streamID: UInt32) {
            self.version = version
            self.streamID = streamID
        }
    }

    public typealias Timing = UdpAudioPacketTiming

    public struct Format: Equatable, Sendable {
        public var sampleRateHertz: UInt32
        public var frameCount: UInt32
        public var channelCount: UInt16

        public init(
            sampleRateHertz: UInt32 = UInt32(OpusCELTLowDelayConstants.sampleRateHertz),
            frameCount: UInt32 = UInt32(OpusCELTLowDelayConstants.frameCount),
            channelCount: UInt16
        ) {
            self.sampleRateHertz = sampleRateHertz
            self.frameCount = frameCount
            self.channelCount = channelCount
        }
    }

    public init(
        stream: Stream,
        timing: Timing,
        format: Format,
        codecByteCount: UInt32 = 0
    ) {
        version = stream.version
        streamID = stream.streamID
        sequenceNumber = timing.sequenceNumber
        senderFrameIndex = timing.senderFrameIndex
        senderHostTimeNanoseconds = timing.senderHostTimeNanoseconds
        sampleRateHertz = format.sampleRateHertz
        frameCount = format.frameCount
        channelCount = format.channelCount
        self.codecByteCount = codecByteCount
    }
}

/// Defines the AudioOpusCeltLowDelayPacket wire representation shared by codecs and UDP media transport.
public struct AudioOpusCeltLowDelayPacket: PacketCodec {
    public var header: AudioOpusCeltLowDelayPacketHeader
    public var payload: Data

    public init(header: AudioOpusCeltLowDelayPacketHeader, payload: Data) {
        var header = header
        header.codecByteCount = UInt32(payload.count)
        self.header = header
        self.payload = payload
    }

    public static func decode<Bytes: DataProtocol>(_ data: Bytes) throws -> AudioOpusCeltLowDelayPacket {
        let bytes = [UInt8](data)
        let header = try decodeHeader(from: bytes)
        try validatePayloadByteCount(bytes, codecByteCount: header.codecByteCount)
        return AudioOpusCeltLowDelayPacket(
            header: header,
            payload: Data(bytes[AudioOpusCeltLowDelayPacketHeader.byteCount..<bytes.count])
        )
    }

    private static func decodeHeader(from bytes: [UInt8]) throws -> AudioOpusCeltLowDelayPacketHeader {
        guard bytes.count >= AudioOpusCeltLowDelayPacketHeader.byteCount else {
            throw AudioOpusCeltLowDelayPacketError.truncatedPacket(byteCount: bytes.count)
        }
        guard Array(bytes[0..<4]) == AudioOpusCeltLowDelayPacketHeader.magic else {
            throw AudioOpusCeltLowDelayPacketError.invalidMagic
        }
        let version = bytes[4]
        guard version == AudioOpusCeltLowDelayPacketHeader.currentVersion else {
            throw AudioOpusCeltLowDelayPacketError.unsupportedVersion(version)
        }
        let streamID = try readCheckedOpusPacketUInt32LE(bytes, offset: 8)
        let sequenceNumber = try readCheckedOpusPacketUInt64LE(bytes, offset: 12)
        let senderFrameIndex = try readCheckedOpusPacketUInt64LE(bytes, offset: 20)
        let senderHostTimeNanoseconds = try readCheckedOpusPacketUInt64LE(bytes, offset: 28)
        let sampleRateHertz = try readCheckedOpusPacketUInt32LE(bytes, offset: 36)
        let frameCount = try readCheckedOpusPacketUInt32LE(bytes, offset: 40)
        let channelCount = try readCheckedOpusPacketUInt16LE(bytes, offset: 44)
        let codecByteCount = try readCheckedOpusPacketUInt32LE(bytes, offset: 48)
        let headerGuard = try readCheckedOpusPacketUInt32LE(bytes, offset: 52)

        guard headerGuard == AudioOpusCeltLowDelayPacketHeader.headerGuard else {
            throw AudioOpusCeltLowDelayPacketError.invalidHeaderGuard
        }
        let header = AudioOpusCeltLowDelayPacketHeader(
            stream: .init(version: version, streamID: streamID),
            timing: .init(
                sequenceNumber: sequenceNumber,
                senderFrameIndex: senderFrameIndex,
                senderHostTimeNanoseconds: senderHostTimeNanoseconds
            ),
            format: .init(
                sampleRateHertz: sampleRateHertz,
                frameCount: frameCount,
                channelCount: channelCount
            ),
            codecByteCount: codecByteCount
        )
        try validateHeader(header)
        return header
    }

    private static func validatePayloadByteCount(_ bytes: [UInt8], codecByteCount: UInt32) throws {
        let actualPayloadByteCount = bytes.count - AudioOpusCeltLowDelayPacketHeader.byteCount
        let declaredPayloadByteCount = Int(codecByteCount)
        guard actualPayloadByteCount == declaredPayloadByteCount else {
            throw AudioOpusCeltLowDelayPacketError.payloadLengthMismatch(
                expected: declaredPayloadByteCount,
                actual: actualPayloadByteCount
            )
        }
        guard declaredPayloadByteCount <= OpusCELTLowDelayConstants.maxEncodedByteCount else {
            throw AudioOpusCeltLowDelayPacketError.payloadTooLarge(declaredPayloadByteCount)
        }
    }

    public func encoded() throws -> Data {
        var header = header
        header.codecByteCount = UInt32(payload.count)
        try Self.validateHeader(header)
        guard payload.count <= OpusCELTLowDelayConstants.maxEncodedByteCount else {
            throw AudioOpusCeltLowDelayPacketError.payloadTooLarge(payload.count)
        }

        var data = Data()
        data.reserveCapacity(AudioOpusCeltLowDelayPacketHeader.byteCount + payload.count)
        data.append(contentsOf: AudioOpusCeltLowDelayPacketHeader.magic)
        data.append(header.version)
        data.append(contentsOf: [0, 0, 0])
        appendUdpAudioPacketHeaderPrefix(header, to: &data)
        appendUdpPcmUInt16LE(header.channelCount, to: &data)
        appendUdpPcmUInt16LE(0, to: &data)
        appendUdpPcmUInt32LE(header.codecByteCount, to: &data)
        appendUdpPcmUInt32LE(AudioOpusCeltLowDelayPacketHeader.headerGuard, to: &data)
        data.append(payload)
        return data
    }

    private static func validateHeader(_ header: AudioOpusCeltLowDelayPacketHeader) throws {
        guard header.streamID > 0 else {
            throw AudioOpusCeltLowDelayPacketError.invalidStreamID(header.streamID)
        }
        guard header.senderHostTimeNanoseconds > 0 else {
            throw AudioOpusCeltLowDelayPacketError.invalidTimestamp(header.senderHostTimeNanoseconds)
        }
        guard header.sampleRateHertz == UInt32(OpusCELTLowDelayConstants.sampleRateHertz) else {
            throw AudioOpusCeltLowDelayPacketError.invalidSampleRate(header.sampleRateHertz)
        }
        guard header.frameCount == UInt32(OpusCELTLowDelayConstants.frameCount) else {
            throw AudioOpusCeltLowDelayPacketError.invalidFrameCount(header.frameCount)
        }
        guard (1...2).contains(Int(header.channelCount)) else {
            throw AudioOpusCeltLowDelayPacketError.invalidChannelCount(header.channelCount)
        }
    }
}

extension AudioOpusCeltLowDelayPacketHeader: UdpAudioPacketHeaderPrefixProviding {
    var udpAudioFrameCount: UInt32 { frameCount }
}

private func readCheckedOpusPacketUInt16LE(_ bytes: [UInt8], offset: Int) throws -> UInt16 {
    guard udpPcmHasBytes(bytes, offset: offset, count: 2) else {
        throw AudioOpusCeltLowDelayPacketError.truncatedPacket(byteCount: bytes.count)
    }
    return UInt16(bytes[offset])
        | UInt16(bytes[offset + 1]) << 8
}

private func readCheckedOpusPacketUInt32LE(_ bytes: [UInt8], offset: Int) throws -> UInt32 {
    guard udpPcmHasBytes(bytes, offset: offset, count: 4) else {
        throw AudioOpusCeltLowDelayPacketError.truncatedPacket(byteCount: bytes.count)
    }
    return UInt32(bytes[offset])
        | UInt32(bytes[offset + 1]) << 8
        | UInt32(bytes[offset + 2]) << 16
        | UInt32(bytes[offset + 3]) << 24
}

private func readCheckedOpusPacketUInt64LE(_ bytes: [UInt8], offset: Int) throws -> UInt64 {
    guard udpPcmHasBytes(bytes, offset: offset, count: 8) else {
        throw AudioOpusCeltLowDelayPacketError.truncatedPacket(byteCount: bytes.count)
    }
    return UInt64(try readCheckedOpusPacketUInt32LE(bytes, offset: offset))
        | UInt64(try readCheckedOpusPacketUInt32LE(bytes, offset: offset + 4)) << 32
}
