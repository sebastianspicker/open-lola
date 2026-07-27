// Implements AES67ST2110L24Transport media transport boundary, separating packet I/O from session policy.
import Foundation

/// Defines supported AES67/ST 2110-30 packet timings and derives their frame and duration values.
public enum AES67ST2110L24PacketTime: String, Codable, CaseIterable, Sendable {
    /// 48 frames at 48 kHz: the existing 1 ms Level A packet-time shape.
    case levelA1Millisecond
    /// 6 frames at 48 kHz: the 125 microsecond Level B/C packet-time shape.
    case levelBC125Microseconds

    public var framesPerPacket: Int {
        switch self {
        case .levelA1Millisecond:
            48
        case .levelBC125Microseconds:
            6
        }
    }

    public var microseconds: Int {
        switch self {
        case .levelA1Millisecond:
            1_000
        case .levelBC125Microseconds:
            125
        }
    }

    public var milliseconds: Double {
        Double(microseconds) / 1_000
    }

    var sdpValue: String {
        microseconds % 1_000 == 0 ? "\(microseconds / 1_000)" : "0.125"
    }
}

/// Centralizes AES67/ST 2110-30 L24 payload, clock, channel, and packet-sizing constants.
public enum AES67ST2110L24Profile {
    public static let payloadType: UInt8 = 96
    public static let clockRateHertz = 48_000
    public static let channelCount = 2
    public static let packetTime = AES67ST2110L24PacketTime.levelA1Millisecond
    public static let framesPerPacket = packetTime.framesPerPacket
    public static let packetTimeMilliseconds = packetTime.milliseconds
    public static let payloadByteCount = payloadByteCount(for: packetTime)
    public static let profileName = "aes67-st2110-l24"

    public static func payloadByteCount(for packetTime: AES67ST2110L24PacketTime) -> Int {
        packetTime.framesPerPacket * channelCount * 3
    }

    public static func packetTime(forFramesPerPacket framesPerPacket: Int) -> AES67ST2110L24PacketTime? {
        AES67ST2110L24PacketTime.allCases.first { $0.framesPerPacket == framesPerPacket }
    }
}

/// Enumerates failures that callers must handle when working with RTP-based audio transport.
public enum RTPPacketError: Error, Equatable, Sendable {
    case truncatedPacket(byteCount: Int)
    case unsupportedVersion(UInt8)
    case unsupportedPadding
    case unsupportedExtension
    case unsupportedCSRCCount(UInt8)
    case unsupportedPayloadType(UInt8)
    case invalidSSRC(UInt32)
    case payloadLengthMismatch(expected: Int, actual: Int)
    case sequenceDiscontinuity(expected: UInt16, actual: UInt16)
    case timestampStepMismatch(expected: UInt32, actual: UInt32)
    case ssrcMismatch(expected: UInt32, actual: UInt32)
}

/// Defines the RTPPacketHeader wire representation shared by codecs and RTP-based audio transport.
public struct RTPPacketHeader: Codable, Equatable, Sendable {
    public static let byteCount = 12

    public var payloadType: UInt8
    public var marker: Bool
    public var sequenceNumber: UInt16
    public var timestamp: UInt32
    public var ssrc: UInt32

    public init(
        payloadType: UInt8 = AES67ST2110L24Profile.payloadType,
        marker: Bool = false,
        sequenceNumber: UInt16,
        timestamp: UInt32,
        ssrc: UInt32
    ) {
        self.payloadType = payloadType
        self.marker = marker
        self.sequenceNumber = sequenceNumber
        self.timestamp = timestamp
        self.ssrc = ssrc
    }
}

/// Defines the RTPPacket wire representation shared by codecs and RTP-based audio transport.
public struct RTPPacket: Codable, Equatable, Sendable {
    public var header: RTPPacketHeader
    public var payload: Data

    public init(header: RTPPacketHeader, payload: Data) {
        self.header = header
        self.payload = payload
    }

    /// Decodes the datagrams used by the RTP receive path without first materialising
    /// a second `[UInt8]` copy of the packet.
    public static func decode(_ data: Data) throws -> RTPPacket {
        guard data.count >= RTPPacketHeader.byteCount else {
            throw RTPPacketError.truncatedPacket(byteCount: data.count)
        }
        let version = data[data.startIndex] >> 6
        guard version == 2 else {
            throw RTPPacketError.unsupportedVersion(version)
        }
        guard data[data.startIndex] & 0x20 == 0 else {
            throw RTPPacketError.unsupportedPadding
        }
        guard data[data.startIndex] & 0x10 == 0 else {
            throw RTPPacketError.unsupportedExtension
        }
        let csrcCount = data[data.startIndex] & 0x0f
        guard csrcCount == 0 else {
            throw RTPPacketError.unsupportedCSRCCount(csrcCount)
        }
        let payloadType = data[data.startIndex + 1] & 0x7f
        let marker = (data[data.startIndex + 1] & 0x80) != 0
        let sequenceNumber = readRTPUInt16BE(data, offset: 2)
        let timestamp = readRTPUInt32BE(data, offset: 4)
        let ssrc = readRTPUInt32BE(data, offset: 8)
        guard ssrc != 0 else {
            throw RTPPacketError.invalidSSRC(ssrc)
        }
        return RTPPacket(
            header: RTPPacketHeader(
                payloadType: payloadType,
                marker: marker,
                sequenceNumber: sequenceNumber,
                timestamp: timestamp,
                ssrc: ssrc
            ),
            payload: data.dropFirst(RTPPacketHeader.byteCount)
        )
    }

    public static func decode<Bytes: DataProtocol>(_ data: Bytes) throws -> RTPPacket {
        try decode(Data(data))
    }

    public func encoded() throws -> Data {
        guard header.ssrc != 0 else {
            throw RTPPacketError.invalidSSRC(header.ssrc)
        }
        var data = Data()
        data.reserveCapacity(RTPPacketHeader.byteCount + payload.count)
        data.append(0x80)
        data.append((header.marker ? 0x80 : 0x00) | (header.payloadType & 0x7f))
        appendRTPUInt16BE(header.sequenceNumber, to: &data)
        appendRTPUInt32BE(header.timestamp, to: &data)
        appendRTPUInt32BE(header.ssrc, to: &data)
        data.append(payload)
        return data
    }
}

/// Enumerates failures that callers must handle when working with RTP-based audio transport.
public enum L24PCMCodecError: Error, Equatable, Sendable {
    case invalidFloatPayloadByteCount(Int)
    case invalidL24PayloadByteCount(Int)
    case unsupportedChannelCount(Int)
    case unsupportedFrameCount(Int)
}

/// Converts interleaved stereo Float32 PCM to and from 24-bit big-endian L24 network payloads.
public enum L24PCMCodec {
    public static func encodeFloat32InterleavedStereo<Bytes: DataProtocol>(
        _ payload: Bytes,
        framesPerPacket: Int = AES67ST2110L24Profile.framesPerPacket
    ) throws -> Data {
        let sampleCount = framesPerPacket * AES67ST2110L24Profile.channelCount
        let expectedByteCount = sampleCount * MemoryLayout<Float>.size
        let source = Data(payload)
        guard source.count == expectedByteCount else {
            throw L24PCMCodecError.invalidFloatPayloadByteCount(source.count)
        }
        var l24 = Data()
        l24.count = sampleCount * 3
        try source.withUnsafeBytes { bytes in
            try l24.withUnsafeMutableBytes { output in
                try encodeFloat32InterleavedStereo(bytes, into: output, framesPerPacket: framesPerPacket)
            }
        }
        return l24
    }

    public static func encodeFloat32InterleavedStereo(
        _ payload: UnsafeRawBufferPointer,
        into output: UnsafeMutableRawBufferPointer,
        framesPerPacket: Int = AES67ST2110L24Profile.framesPerPacket
    ) throws {
        let sampleCount = framesPerPacket * AES67ST2110L24Profile.channelCount
        let expectedInputByteCount = sampleCount * MemoryLayout<Float>.size
        let expectedOutputByteCount = sampleCount * 3
        guard payload.count == expectedInputByteCount else {
            throw L24PCMCodecError.invalidFloatPayloadByteCount(payload.count)
        }
        guard output.count >= expectedOutputByteCount else {
            throw L24PCMCodecError.invalidL24PayloadByteCount(output.count)
        }
        guard let inputBase = payload.baseAddress, let outputBase = output.baseAddress else {
            throw L24PCMCodecError.invalidFloatPayloadByteCount(payload.count)
        }
        for sampleIndex in 0..<sampleCount {
            let sample = inputBase.load(fromByteOffset: sampleIndex * MemoryLayout<Float>.size, as: Float.self)
            let clamped = min(max(sample, -1.0), 1.0)
            let scaled = Int32((clamped * 8_388_607.0).rounded())
            let unsigned = UInt32(bitPattern: scaled) & 0xFF_FFFF
            let offset = sampleIndex * 3
            outputBase.storeBytes(of: UInt8((unsigned >> 16) & 0xff), toByteOffset: offset, as: UInt8.self)
            outputBase.storeBytes(of: UInt8((unsigned >> 8) & 0xff), toByteOffset: offset + 1, as: UInt8.self)
            outputBase.storeBytes(of: UInt8(unsigned & 0xff), toByteOffset: offset + 2, as: UInt8.self)
        }
    }

    public static func decodeFloat32InterleavedStereo(
        _ payload: Data,
        framesPerPacket: Int = AES67ST2110L24Profile.framesPerPacket
    ) throws -> Data {
        let sampleCount = framesPerPacket * AES67ST2110L24Profile.channelCount
        let expectedByteCount = sampleCount * 3
        guard payload.count == expectedByteCount else {
            throw L24PCMCodecError.invalidL24PayloadByteCount(payload.count)
        }
        var floats = Data()
        floats.count = sampleCount * MemoryLayout<Float>.size
        try payload.withUnsafeBytes { input in
            try floats.withUnsafeMutableBytes { output in
                try decodeFloat32InterleavedStereo(input, into: output, framesPerPacket: framesPerPacket)
            }
        }
        return floats
    }

    public static func decodeFloat32InterleavedStereo(
        _ payload: UnsafeRawBufferPointer,
        into output: UnsafeMutableRawBufferPointer,
        framesPerPacket: Int = AES67ST2110L24Profile.framesPerPacket
    ) throws {
        let sampleCount = framesPerPacket * AES67ST2110L24Profile.channelCount
        let expectedInputByteCount = sampleCount * 3
        let expectedOutputByteCount = sampleCount * MemoryLayout<Float>.size
        guard payload.count == expectedInputByteCount else {
            throw L24PCMCodecError.invalidL24PayloadByteCount(payload.count)
        }
        guard output.count >= expectedOutputByteCount else {
            throw L24PCMCodecError.invalidFloatPayloadByteCount(output.count)
        }
        guard let inputBase = payload.baseAddress, let outputBase = output.baseAddress else {
            throw L24PCMCodecError.invalidL24PayloadByteCount(payload.count)
        }
        for sampleIndex in 0..<sampleCount {
            let offset = sampleIndex * 3
            var value = UInt32(inputBase.load(fromByteOffset: offset, as: UInt8.self)) << 16
                | UInt32(inputBase.load(fromByteOffset: offset + 1, as: UInt8.self)) << 8
                | UInt32(inputBase.load(fromByteOffset: offset + 2, as: UInt8.self))
            if value & 0x80_0000 != 0 { value |= 0xFF00_0000 }
            let sample = Float(Int32(bitPattern: value)) / 8_388_607.0
            outputBase.storeBytes(of: sample.bitPattern.littleEndian, toByteOffset: sampleIndex * 4, as: UInt32.self)
        }
    }

}

/// Tracks continuity and AES67/ST 2110-30 L24 profile conformance across received RTP packets.
public struct AES67ST2110L24RTPReceiveValidator: Sendable {
    public var expectedSSRC: UInt32?
    public let packetTime: AES67ST2110L24PacketTime
    public private(set) var lostPackets: Int = 0
    private var nextSequenceNumber: UInt16?
    private var nextTimestamp: UInt32?

    public init(
        expectedSSRC: UInt32? = nil,
        packetTime: AES67ST2110L24PacketTime = AES67ST2110L24Profile.packetTime
    ) {
        self.expectedSSRC = expectedSSRC
        self.packetTime = packetTime
    }

    public mutating func validate(_ packet: RTPPacket) throws {
        guard packet.header.payloadType == AES67ST2110L24Profile.payloadType else {
            throw RTPPacketError.unsupportedPayloadType(packet.header.payloadType)
        }
        if let expectedSSRC {
            guard packet.header.ssrc == expectedSSRC else {
                throw RTPPacketError.ssrcMismatch(expected: expectedSSRC, actual: packet.header.ssrc)
            }
        } else {
            expectedSSRC = packet.header.ssrc
        }
        guard packet.payload.count == AES67ST2110L24Profile.payloadByteCount(for: packetTime) else {
            throw RTPPacketError.payloadLengthMismatch(
                expected: AES67ST2110L24Profile.payloadByteCount(for: packetTime),
                actual: packet.payload.count
            )
        }
        try validateSequenceAndTimestamp(packet.header)
        nextSequenceNumber = packet.header.sequenceNumber &+ 1
        nextTimestamp = packet.header.timestamp &+ UInt32(packetTime.framesPerPacket)
    }

    private mutating func validateSequenceAndTimestamp(_ header: RTPPacketHeader) throws {
        if let nextSequenceNumber, header.sequenceNumber != nextSequenceNumber {
            let sequenceGap = Int(UInt16(header.sequenceNumber &- nextSequenceNumber))
            if sequenceGap > 0 && sequenceGap <= 1_024 {
                let skippedFrames = UInt32(sequenceGap) * UInt32(packetTime.framesPerPacket)
                let expectedTimestamp = nextTimestamp.map { $0 &+ skippedFrames }
                if let expectedTimestamp, header.timestamp != expectedTimestamp {
                    throw RTPPacketError.timestampStepMismatch(
                        expected: expectedTimestamp,
                        actual: header.timestamp
                    )
                }
                lostPackets += sequenceGap
            } else {
                throw RTPPacketError.sequenceDiscontinuity(
                    expected: nextSequenceNumber,
                    actual: header.sequenceNumber
                )
            }
        } else if let nextTimestamp, header.timestamp != nextTimestamp {
            throw RTPPacketError.timestampStepMismatch(
                expected: nextTimestamp,
                actual: header.timestamp
            )
        }
    }
}

/// Renders and parses the SDP description for an AES67/ST 2110-30 L24 RTP stream.
public struct AES67ST2110L24SDP: Codable, Equatable, Sendable {
    public var address: String
    public var port: UInt16
    public var direction: MediaStreamDirection
    public var packetTime: AES67ST2110L24PacketTime
    public var ptpEvidenceSummary: String?

    public init(
        address: String,
        port: UInt16,
        direction: MediaStreamDirection = .bidirectional,
        packetTime: AES67ST2110L24PacketTime = AES67ST2110L24Profile.packetTime,
        ptpEvidenceSummary: String? = nil
    ) {
        self.address = address
        self.port = port
        self.direction = direction
        self.packetTime = packetTime
        self.ptpEvidenceSummary = ptpEvidenceSummary
    }

    public func text() -> String {
        var lines = [
            "v=0",
            "o=- 0 0 IN IP4 \(address)",
            "s=open-lola AES67 ST 2110-30 L24",
            "c=IN IP4 \(address)",
            "t=0 0",
            "m=audio \(port) RTP/AVP \(AES67ST2110L24Profile.payloadType)",
            "a=rtpmap:\(AES67ST2110L24Profile.payloadType) " +
"L24/\(AES67ST2110L24Profile.clockRateHertz)/" +
"\(AES67ST2110L24Profile.channelCount)",
            "a=ptime:\(packetTime.sdpValue)",
            "a=maxptime:\(packetTime.sdpValue)",
            "a=\(direction.sdpAttribute)"
        ]
        if let ptpEvidenceSummary, !ptpEvidenceSummary.isEmpty {
            lines.append("a=ts-refclk:ptp=IEEE1588-2019 \(ptpEvidenceSummary)")
            lines.append("a=mediaclk:direct=0")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    public static func parse(_ text: String) throws -> AES67ST2110L24SDP {
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        guard let media = lines.first(where: { $0.hasPrefix("m=audio ") }) else {
            throw AES67ST2110L24SDPError.missingLine("m=audio")
        }
        let mediaParts = media.split(separator: " ").map(String.init)
        guard mediaParts.count >= 4, let port = UInt16(mediaParts[1]) else {
            throw AES67ST2110L24SDPError.invalidLine(media)
        }
        guard mediaParts[2] == "RTP/AVP", mediaParts[3] == "\(AES67ST2110L24Profile.payloadType)" else {
            throw AES67ST2110L24SDPError.unsupportedMedia(media)
        }
        let rtpmap = "a=rtpmap:\(AES67ST2110L24Profile.payloadType) " +
"L24/\(AES67ST2110L24Profile.clockRateHertz)/" +
"\(AES67ST2110L24Profile.channelCount)"
        guard lines.contains(rtpmap) else {
            throw AES67ST2110L24SDPError.unsupportedRTPMap
        }
        guard let packetTime = AES67ST2110L24PacketTime.allCases.first(where: {
            lines.contains("a=ptime:\($0.sdpValue)") && lines.contains("a=maxptime:\($0.sdpValue)")
        }) else {
            throw AES67ST2110L24SDPError.unsupportedPacketTime
        }
        let address = lines.first(where: { $0.hasPrefix("c=IN IP4 ") })?.replacingOccurrences(of: "c=IN IP4 ", with: "")
            ?? "0.0.0.0"
        let direction = lines.compactMap(MediaStreamDirection.init(sdpAttribute:)).first ?? .bidirectional
        let ptp = lines.first(where: { $0.hasPrefix("a=ts-refclk:ptp=") })
        return AES67ST2110L24SDP(
            address: address,
            port: port,
            direction: direction,
            packetTime: packetTime,
            ptpEvidenceSummary: ptp
        )
    }
}

/// Enumerates failures that callers must handle when working with RTP-based audio transport.
public enum AES67ST2110L24SDPError: Error, Equatable, Sendable {
    case missingLine(String)
    case invalidLine(String)
    case unsupportedMedia(String)
    case unsupportedRTPMap
    case unsupportedPacketTime
}

private extension MediaStreamDirection {
    var sdpAttribute: String {
        switch self {
        case .send:
            "sendonly"
        case .receive:
            "recvonly"
        case .bidirectional:
            "sendrecv"
        case .disabled:
            "inactive"
        }
    }

    init?(sdpAttribute line: String) {
        switch line {
        case "a=sendonly":
            self = .send
        case "a=recvonly":
            self = .receive
        case "a=sendrecv":
            self = .bidirectional
        case "a=inactive":
            self = .disabled
        default:
            return nil
        }
    }
}

private func appendFloat32LE(_ value: Float, to data: inout Data) {
    let bitPattern = value.bitPattern
    data.append(UInt8(bitPattern & 0xff))
    data.append(UInt8((bitPattern >> 8) & 0xff))
    data.append(UInt8((bitPattern >> 16) & 0xff))
    data.append(UInt8((bitPattern >> 24) & 0xff))
}

private func readRTPUInt16BE(_ bytes: Data, offset: Int) -> UInt16 {
    let start = bytes.startIndex + offset
    return UInt16(bytes[start]) << 8 | UInt16(bytes[start + 1])
}

private func readRTPUInt32BE(_ bytes: Data, offset: Int) -> UInt32 {
    let start = bytes.startIndex + offset
    return UInt32(bytes[start]) << 24
        | UInt32(bytes[start + 1]) << 16
        | UInt32(bytes[start + 2]) << 8
        | UInt32(bytes[start + 3])
}

private func appendRTPUInt16BE(_ value: UInt16, to data: inout Data) {
    data.append(UInt8((value >> 8) & 0xff))
    data.append(UInt8(value & 0xff))
}

private func appendRTPUInt32BE(_ value: UInt32, to data: inout Data) {
    NetworkByteWriter.appendUInt32BE(value, to: &data)
}
