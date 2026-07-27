// Defines UDP media packet, frame, or monitor values and conversion helpers so producers and consumers agree on their exchanged representation.
import Darwin
import Dispatch
import Foundation

/// Defines the UdpMediaPacketHeader wire representation shared by codecs and UDP media transport.
public struct UdpMediaPacketHeader: Codable, Equatable, Sendable {
    public static let magic = [UInt8]("OLMP".utf8)
    public static let currentVersion: UInt8 = 1
    public static let byteCount = 36
    public static let headerGuard: UInt32 = 0x3150_4D4F

    public var version: UInt8
    public var payloadType: SessionPayloadType
    public var streamID: UInt32
    public var sequenceNumber: UInt64
    public var timestampNanoseconds: UInt64
    public var payloadByteCount: UInt32

    public init(
        version: UInt8 = Self.currentVersion,
        payloadType: SessionPayloadType,
        streamID: UInt32,
        sequenceNumber: UInt64,
        timestampNanoseconds: UInt64,
        payloadByteCount: UInt32 = 0
    ) {
        self.version = version
        self.payloadType = payloadType
        self.streamID = streamID
        self.sequenceNumber = sequenceNumber
        self.timestampNanoseconds = timestampNanoseconds
        self.payloadByteCount = payloadByteCount
    }
}

/// Enumerates failures that callers must handle when working with UDP media transport.
public enum UdpMediaPacketError: Error, Equatable, Sendable {
    case truncatedPacket(byteCount: Int)
    case invalidMagic
    case unsupportedVersion(UInt8)
    case unsupportedPayloadType(UInt8)
    case invalidStreamID(UInt32)
    case invalidTimestamp(UInt64)
    case payloadLengthMismatch(expected: Int, actual: Int)
    case payloadTooLarge(Int)
    case invalidHeaderGuard
    case audioStreamMismatch(expected: UInt32, actual: UInt32)
    case audioSequenceMismatch(expected: UInt64, actual: UInt64)
    case audioTimestampMismatch(expected: UInt64, actual: UInt64)
    case videoStreamMismatch(expected: UInt32, actual: UInt32)
    case videoSequenceMismatch(expected: UInt64, actual: UInt64)
    case videoTimestampMismatch(expected: UInt64, actual: UInt64)
}

/// Enumerates failures that callers must handle when working with UDP media transport.
public struct UdpMediaMalformedDatagramError: Error, Equatable, Sendable {
    public var reason: String

    public init(reason: String) {
        self.reason = reason
    }
}

/// Defines the UdpMediaPacket wire representation shared by codecs and UDP media transport.
public struct UdpMediaPacket: PacketCodec {
    public static let maxPayloadByteCount = UdpPcmPacket.maxPayloadByteCount

    public var header: UdpMediaPacketHeader
    public var payload: Data

    public init(header: UdpMediaPacketHeader, payload: Data) {
        var header = header
        header.payloadByteCount = UInt32(payload.count)
        self.header = header
        self.payload = payload
    }

    public static func decode<Bytes: DataProtocol>(_ data: Bytes) throws -> UdpMediaPacket {
        try decodeWithNestedPayload(data).packet
    }

    public static func decodeWithNestedPayload<Bytes: DataProtocol>(_ data: Bytes) throws -> UdpMediaDecodedPacket {
        let bytes = [UInt8](data)
        let envelope = try decodedEnvelope(from: bytes)
        let packet = UdpMediaPacket(header: envelope.header, payload: envelope.payload)
        let decodedPayload = try packet.decodedNestedPayload()
        return UdpMediaDecodedPacket(packet: packet, decodedPayload: decodedPayload)
    }

    private static func decodedEnvelope(from bytes: [UInt8]) throws -> UdpMediaPacketEnvelope {
        let header = try decodedHeader(from: bytes)
        let payload = try decodedPayload(from: bytes, byteCount: header.payloadByteCount)
        return UdpMediaPacketEnvelope(header: header, payload: payload)
    }

    private static func decodedHeader(from bytes: [UInt8]) throws -> UdpMediaPacketHeader {
        guard bytes.count >= UdpMediaPacketHeader.byteCount else {
            throw UdpMediaPacketError.truncatedPacket(byteCount: bytes.count)
        }
        guard Array(bytes[0..<4]) == UdpMediaPacketHeader.magic else {
            throw UdpMediaPacketError.invalidMagic
        }
        let version = bytes[4]
        guard version == UdpMediaPacketHeader.currentVersion else {
            throw UdpMediaPacketError.unsupportedVersion(version)
        }
        let payloadTypeValue = bytes[5]
        guard let payloadType = SessionPayloadType(rawValue: Int(payloadTypeValue)) else {
            throw UdpMediaPacketError.unsupportedPayloadType(payloadTypeValue)
        }
        let streamID = try readUdpMediaUInt32LE(bytes, offset: 8)
        guard streamID > 0 else {
            throw UdpMediaPacketError.invalidStreamID(streamID)
        }
        let sequenceNumber = try readUdpMediaUInt64LE(bytes, offset: 12)
        let timestampNanoseconds = try readUdpMediaUInt64LE(bytes, offset: 20)
        guard timestampNanoseconds > 0 else {
            throw UdpMediaPacketError.invalidTimestamp(timestampNanoseconds)
        }
        let payloadByteCount = try readUdpMediaUInt32LE(bytes, offset: 28)
        let headerGuard = try readUdpMediaUInt32LE(bytes, offset: 32)
        guard headerGuard == UdpMediaPacketHeader.headerGuard else {
            throw UdpMediaPacketError.invalidHeaderGuard
        }

        return UdpMediaPacketHeader(
            version: version,
            payloadType: payloadType,
            streamID: streamID,
            sequenceNumber: sequenceNumber,
            timestampNanoseconds: timestampNanoseconds,
            payloadByteCount: payloadByteCount
        )
    }

    private static func decodedPayload(from bytes: [UInt8], byteCount: UInt32) throws -> Data {
        let actualPayloadByteCount = bytes.count - UdpMediaPacketHeader.byteCount
        let declaredPayloadByteCount = Int(byteCount)
        guard actualPayloadByteCount == declaredPayloadByteCount else {
            throw UdpMediaPacketError.payloadLengthMismatch(
                expected: declaredPayloadByteCount,
                actual: actualPayloadByteCount
            )
        }
        guard declaredPayloadByteCount <= maxPayloadByteCount else {
            throw UdpMediaPacketError.payloadTooLarge(declaredPayloadByteCount)
        }
        return Data(bytes[UdpMediaPacketHeader.byteCount..<bytes.count])
    }

    public func encoded() throws -> Data {
        try validate()

        var data = Data()
        data.reserveCapacity(UdpMediaPacketHeader.byteCount + payload.count)
        data.append(contentsOf: UdpMediaPacketHeader.magic)
        data.append(header.version)
        data.append(UInt8(header.payloadType.rawValue))
        appendUdpMediaUInt16LE(0, to: &data)
        appendUdpMediaUInt32LE(header.streamID, to: &data)
        appendUdpMediaUInt64LE(header.sequenceNumber, to: &data)
        appendUdpMediaUInt64LE(header.timestampNanoseconds, to: &data)
        appendUdpMediaUInt32LE(UInt32(payload.count), to: &data)
        appendUdpMediaUInt32LE(UdpMediaPacketHeader.headerGuard, to: &data)
        data.append(payload)
        return data
    }

    private func validate() throws {
        guard header.version == UdpMediaPacketHeader.currentVersion else {
            throw UdpMediaPacketError.unsupportedVersion(header.version)
        }
        guard header.streamID > 0 else {
            throw UdpMediaPacketError.invalidStreamID(header.streamID)
        }
        guard header.timestampNanoseconds > 0 else {
            throw UdpMediaPacketError.invalidTimestamp(header.timestampNanoseconds)
        }
        guard payload.count <= Self.maxPayloadByteCount else {
            throw UdpMediaPacketError.payloadTooLarge(payload.count)
        }
        _ = try decodedNestedPayload()
    }

    private func decodedNestedPayload() throws -> UdpMediaDecodedPayload {
        switch header.payloadType {
        case .audioRtpL24:
            let rtp = try RTPPacket.decode(payload)
            try validateNestedPayloadByteCount(try rtp.encoded().count)
            return .audioRtpL24(rtp)
        case .audioPcmV2, .audioOpusCeltLowDelayFrame:
            let audio = try decodedAudioPayload()
            try validateAudioHeader(audio)
            return audio.payload
        case .videoRawFrameFragment, .videoVideoToolboxFragment, .videoJpegXSFrameFragment:
            let video = try decodedVideoPayload()
            try validateVideoHeader(video)
            return .videoFragment(video)
        case .metrics:
            return .metrics(try JSONDecoder().decode(SessionMetricsMessage.self, from: payload))
        case .audioTiming:
            let timing = try JSONDecoder().decode(MediaTimingPacket.self, from: payload)
            try timing.validate()
            return .audioTiming(timing)
        case .keepalive:
            return .keepalive
        }
    }

    private func decodedAudioPayload() throws -> UdpMediaDecodedAudioPayload {
        if header.payloadType == .audioPcmV2 {
            let audio = try UdpPcmV2Packet.decode(payload)
            try validateNestedPayloadByteCount(try audio.encoded().count)
            return UdpMediaDecodedAudioPayload(
                streamID: audio.header.streamID,
                sequenceNumber: audio.header.sequenceNumber,
                timestampNanoseconds: audio.header.senderHostTimeNanoseconds,
                payload: .audioPcmV2(audio)
            )
        }

        let opus = try AudioOpusCeltLowDelayPacket.decode(payload)
        try validateNestedPayloadByteCount(try opus.encoded().count)
        return UdpMediaDecodedAudioPayload(
            streamID: opus.header.streamID,
            sequenceNumber: opus.header.sequenceNumber,
            timestampNanoseconds: opus.header.senderHostTimeNanoseconds,
            payload: .audioOpusCeltLowDelayFrame(opus)
        )
    }

    private func validateAudioHeader(_ audio: UdpMediaDecodedAudioPayload) throws {
        guard audio.streamID == header.streamID else {
            throw UdpMediaPacketError.audioStreamMismatch(
                expected: header.streamID,
                actual: audio.streamID
            )
        }
        guard audio.sequenceNumber == header.sequenceNumber else {
            throw UdpMediaPacketError.audioSequenceMismatch(
                expected: header.sequenceNumber,
                actual: audio.sequenceNumber
            )
        }
        guard audio.timestampNanoseconds == header.timestampNanoseconds else {
            throw UdpMediaPacketError.audioTimestampMismatch(
                expected: header.timestampNanoseconds,
                actual: audio.timestampNanoseconds
            )
        }
    }

    private func decodedVideoPayload() throws -> VideoTransportFragment {
        let video = try VideoTransportFragment.decode(payload)
        try validateNestedPayloadByteCount(try video.encoded().count)
        return video
    }

    private func validateVideoHeader(_ video: VideoTransportFragment) throws {
        guard video.streamID == header.streamID else {
            throw UdpMediaPacketError.videoStreamMismatch(
                expected: header.streamID,
                actual: video.streamID
            )
        }
        guard video.frameSequenceNumber == header.sequenceNumber else {
            throw UdpMediaPacketError.videoSequenceMismatch(
                expected: header.sequenceNumber,
                actual: video.frameSequenceNumber
            )
        }
        guard video.timestampNanoseconds == header.timestampNanoseconds else {
            throw UdpMediaPacketError.videoTimestampMismatch(
                expected: header.timestampNanoseconds,
                actual: video.timestampNanoseconds
            )
        }
    }

    private func validateNestedPayloadByteCount(_ nestedByteCount: Int) throws {
        guard nestedByteCount == payload.count else {
            throw UdpMediaPacketError.payloadLengthMismatch(
                expected: nestedByteCount,
                actual: payload.count
            )
        }
    }
}

private struct UdpMediaPacketEnvelope {
    var header: UdpMediaPacketHeader
    var payload: Data
}

private struct UdpMediaDecodedAudioPayload {
    var streamID: UInt32
    var sequenceNumber: UInt64
    var timestampNanoseconds: UInt64
    var payload: UdpMediaDecodedPayload
}

/// Carries a decoded UDP media payload in its protocol-specific representation.
public enum UdpMediaDecodedPayload: Equatable, Sendable {
    case audioRtpL24(RTPPacket)
    case audioPcmV2(UdpPcmV2Packet)
    case audioOpusCeltLowDelayFrame(AudioOpusCeltLowDelayPacket)
    case videoFragment(VideoTransportFragment)
    case metrics(SessionMetricsMessage)
    case audioTiming(MediaTimingPacket)
    case keepalive
}

/// Defines the UdpMediaDecodedPacket wire representation shared by codecs and UDP media transport.
public struct UdpMediaDecodedPacket: Equatable, Sendable {
    public var packet: UdpMediaPacket
    public var decodedPayload: UdpMediaDecodedPayload

    public init(packet: UdpMediaPacket, decodedPayload: UdpMediaDecodedPayload) {
        self.packet = packet
        self.decodedPayload = decodedPayload
    }
}

/// Represents the UdpMediaMetrics produced by UDP media transport without exposing its execution state.
public struct UdpMediaMetrics: Codable, Equatable, Sendable {
    public var packetsSent: Int = 0
    public var packetsReceived: Int = 0
    public var packetsLost: Int = 0
    public var latePackets: Int = 0
    public var reorderedPackets: Int = 0
    public var duplicatePackets: Int = 0
    public var malformedPackets: Int = 0
    public var jitterMicroseconds: Double = 0
    public var clockSkewEventCount: Int = 0
    public var callbackDurationP99Microseconds: Double = 0
    public var queueDepthPackets: Int = 0
    public var cpuPercent: Double = 0
    public var memoryResidentBytes: UInt64 = 0
    public var packetizationDuration: PerformanceCounterSummary = .empty
    public var depacketizationDuration: PerformanceCounterSummary = .empty

    public init() {}

    public func controlMessage(sessionID: String) -> SessionControlMessage {
        SessionControlMessage.metrics(SessionMetricsMessage(
            sessionID: sessionID,
            delivery: .init(packetsLost: packetsLost, jitterMicroseconds: jitterMicroseconds,
                            latePackets: latePackets,
                            callbackDurationP99Microseconds: callbackDurationP99Microseconds,
                            queueDepthPackets: queueDepthPackets),
            runtime: .init(cpuPercent: cpuPercent, memoryResidentBytes: memoryResidentBytes,
                           underruns: 0, overruns: 0, videoFramesDropped: 0)
        ))
    }
}

private func readUdpMediaUInt16LE(_ bytes: [UInt8], offset: Int) throws -> UInt16 {
    guard udpPcmHasBytes(bytes, offset: offset, count: 2) else {
        throw UdpMediaPacketError.truncatedPacket(byteCount: bytes.count)
    }
    return NetworkByteReader.readUInt16LE(bytes, offset: offset)
}

private func readUdpMediaUInt32LE(_ bytes: [UInt8], offset: Int) throws -> UInt32 {
    guard udpPcmHasBytes(bytes, offset: offset, count: 4) else {
        throw UdpMediaPacketError.truncatedPacket(byteCount: bytes.count)
    }
    return NetworkByteReader.readUInt32LE(bytes, offset: offset)
}

private func readUdpMediaUInt64LE(_ bytes: [UInt8], offset: Int) throws -> UInt64 {
    guard udpPcmHasBytes(bytes, offset: offset, count: 8) else {
        throw UdpMediaPacketError.truncatedPacket(byteCount: bytes.count)
    }
    return NetworkByteReader.readUInt64LE(bytes, offset: offset)
}

private func appendUdpMediaUInt16LE(_ value: UInt16, to data: inout Data) {
    appendUdpPcmUInt16LE(value, to: &data)
}

private func appendUdpMediaUInt32LE(_ value: UInt32, to data: inout Data) {
    appendUdpPcmUInt32LE(value, to: &data)
}

private func appendUdpMediaUInt64LE(_ value: UInt64, to data: inout Data) {
    appendUdpPcmUInt64LE(value, to: &data)
}
